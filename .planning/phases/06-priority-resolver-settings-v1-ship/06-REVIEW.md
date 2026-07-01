---
status: issues_found
files_reviewed: 8
findings:
  critical: 0
  warning: 2
  info: 3
  total: 5
---

# Code Review: Phase 06 (gap closure 06-07..06-12)

Scope: fresh standard-depth review of the 06-07..06-12 gap-closure fixes only, diffed
against `b591530` (the commit immediately preceding the first gap-closure fix, `8300bdc`).
The originally-supplied diff base (`dff3fafc...`) turned out to be an orphaned checkpoint
commit unrelated to this branch's history (not an ancestor of HEAD), so it produced a
useless "everything is a new file" diff; `b591530..HEAD` was used instead to isolate the
actual gap-closure changes.

Files reviewed in full:
- Islet/Notch/NotchWindowController.swift
- Islet/Notch/IslandResolver.swift
- IsletTests/IslandResolverTests.swift
- Islet/Notch/NotchPillView.swift
- Islet/Notch/NowPlayingPresentation.swift
- IsletTests/NowPlayingPresentationTests.swift
- Islet/Notch/NowPlayingMonitor.swift
- scripts/release.sh

## Summary

The gap-closure fixes are largely correct and each addressed a real, previously-reported
defect:

- **NowPlayingService protocol extraction (fb7eeb7)**: sound. `NotchWindowController` holds
  `nowPlayingMonitor` typed as `NowPlayingService`, not the concrete class; the protocol
  surface matches exactly what the controller calls; `nonisolated func stop()` is correctly
  mirrored in both the protocol and the conformer. No leaked implementation details.
- **`TrackSnapshot.hasArtwork` deletion (bf502a4)**: verified dead — it was written in
  `NowPlayingMonitor.swift` but never read anywhere in the pre-gap-closure codebase. No
  behavior change; deletion is clean (no leftover references anywhere in the tree).
- **`isSameTrack` / artwork retention (d2f3d32 / cb849f8)**: the comparison logic is correct
  (ignores the playing/paused axis, requires both sides non-`.none`, requires exact
  title+artist equality) and `handleNowPlaying`'s gating (`if let art { ... } else if p ==
  .none || !isSameTrack(previous, p) { artwork = nil }`) is correct for all four traced
  cases (art arrives, same-track nil, different-track nil, stop). Test coverage in
  `NowPlayingPresentationTests.swift` actually exercises the four meaningful branches.
- **Tap-gesture rescoping (ee1df46)**: traced every `IslandPresentation` case in the `body`
  switch against the `wingsShape`/per-case `.onTapGesture` additions — all seven cases have
  a working tap-to-toggle, none are dead zones, and the transport button row inside
  `mediaExpanded` is provably outside any tap gesture's hit area (own `.onTapGesture` is
  scoped to the top HStack only, never the enclosing VStack or the button row).
- **`presentTransientChange()` / `wingsShape()` extraction (0e05213)**: behavior-preserving;
  correctly excluded from `scheduleActivityDismiss`'s own work-item body as documented.
- **Dead `DeviceActivityState.swift` deletion (3690e77 / ae2dfa4)**: verified dead — no
  references remain anywhere in the tree.
- **`scripts/release.sh`**: `set -euo pipefail`, all variables quoted, no untrusted input,
  no injection surface. The Step 3b / Step 6 two-staple flow and the ad-hoc-vs-real-cert
  banner logic are internally consistent with Step 3's signing branch.

Two real logic defects were found in the Finding 3 / Finding 4 gap-closure fixes
themselves (see Warnings below), plus three lower-severity documentation/coverage gaps.

## Warnings

### WR-1: Device battery-refresh FIFO can desync from the transient queue, polling the wrong device's battery

**File:** `Islet/Notch/NotchWindowController.swift:112-118, 752-773, 883-901`

**Issue:** The Finding 4 fix tracks devices that need a deferred post-connect battery poll
in `pendingDeviceAddresses: [String]`, described as a "best-effort FIFO mirroring the
TransientQueue's own pending order for `.device` entries ONLY." `triggerDeviceBatteryRefreshIfPromoted()`
blindly takes `pendingDeviceAddresses.first` and polls that address for whatever device is
now `transientQueue.head` — it never checks that the address actually belongs to the
promoted device (there is no way to check: `ActiveTransient.device` carries no address, only
`name`/`glyph`/`battery`).

The two lists can legitimately fall out of sync: `pendingDeviceAddresses` is appended to
**only** on a `reading.connected == true` reading that got enqueued-behind-head (line 758),
but `transientQueue`'s own `pending` array also accepts **disconnect** transients for a
different device via the exact same `enqueue()` call, and its `maxDepth`-bound eviction
(`removeAll(where:)`/`enqueue`'s `if pending.count > maxDepth { pending.removeFirst() }`)
can silently drop the *queue's* oldest pending entry without ever touching
`pendingDeviceAddresses`. Concrete repro:

1. Charging is head (some other transient owns the splash).
2. Device A connects → enqueued behind charging → `pendingDeviceAddresses = [A]`,
   `queue.pending = [device(A-connected)]`.
3. Device B connects → enqueued behind charging → `pendingDeviceAddresses = [A, B]`,
   `queue.pending = [device(A-connected), device(B-connected)]` (at `maxDepth`).
4. Device A disconnects → this is a **new, distinct** `ActiveTransient` value
   (`.device(.disconnected(...))` ≠ `.device(.connected(...))`), so it is not deduped; it
   is appended and the queue evicts its now-oldest pending entry
   (`device(A-connected)`) to stay within `maxDepth`. The disconnect append does **not**
   touch `pendingDeviceAddresses` (its append site is gated on `reading.connected`, a
   disconnect reading is `false`). Result: `queue.pending = [device(B-connected),
   device(A-disconnected)]` but `pendingDeviceAddresses` is still `[A, B]`.
5. Charging's ~3s elapses → `advance()` promotes `device(B-connected)` to head.
   `triggerDeviceBatteryRefreshIfPromoted()` sees `.device(.connected)` at head (true) and
   pops `pendingDeviceAddresses.first == "A"` — polling **A's** battery and, if a fresh
   reading differs from B's old cached battery, applying it to the head under **B's**
   `name`/`glyph`. The splash now shows device B's name with device A's battery percentage.

**Fix:** Give `ActiveTransient.device` (or a wrapper) an address so promotion can be
verified against the actual promoted device, e.g. carry the address alongside
`DeviceActivity` in the queue, or key `pendingDeviceAddresses` off of matching against the
currently-promoted head's identity instead of FIFO position:
```swift
// e.g. store (address, DeviceActivity) pairs and match by comparing the promoted
// DeviceActivity value, not by trusting FIFO order:
private var pendingDeviceBatteryPolls: [(address: String, activity: DeviceActivity)] = []

private func triggerDeviceBatteryRefreshIfPromoted() {
    guard case .device(let promoted) = transientQueue.head, case .connected = promoted,
          let idx = pendingDeviceBatteryPolls.firstIndex(where: { $0.activity == promoted })
    else { return }
    let addr = pendingDeviceBatteryPolls.remove(at: idx).address
    scheduleDeviceBatteryRefresh(address: addr)
}
```

### WR-2: `flushTransients` unconditionally resets the shared dismiss timer even when the surviving head is unchanged

**File:** `Islet/Notch/NotchWindowController.swift:874-901`

**Issue:** The Finding 3 fix changed `flushTransients` to always `dismissWorkItem?.cancel()`
then, if any head remains, unconditionally call `scheduleActivityDismiss()` for a fresh
~3s window. This correctly fixes the original bug (a *promoted* survivor inheriting a
stale, partially-elapsed timer), but it does not distinguish "the head was just promoted by
this removal" from "the head was never touched by this removal at all." If the disabled
category's queue entries were only in `pending` (never the head) — e.g. toggling Charging
off while a Device splash is currently standing with no charging entries queued — the
still-standing, **unaffected** Device splash has its dismiss timer cancelled and restarted
from a full 3s, silently extending its on-screen time by however much of its original
window had already elapsed. This is a real (if cosmetic) behavior change: an unrelated
settings toggle now perturbs the timing of a splash that has nothing to do with it.

**Fix:** Only re-arm when the head actually changed as a result of the removal:
```swift
let oldHead = transientQueue.head
transientQueue.removeAll(where: matches)
...
dismissWorkItem?.cancel()
if transientQueue.head != oldHead, transientQueue.head != nil {
    triggerDeviceBatteryRefreshIfPromoted()
    scheduleActivityDismiss()
} else if transientQueue.head != nil {
    // head unchanged — nothing to reschedule; but we already cancelled the
    // in-flight timer above, so it must still be re-armed for the surviving head,
    // just without resetting elapsed time (or restructure to avoid the
    // cancel in this branch in the first place).
}
```
(The minimal fix is to only `dismissWorkItem?.cancel()` + `scheduleActivityDismiss()` when
`transientQueue.head` differs from what it was before `removeAll`, and otherwise leave the
existing timer running untouched.)

## Info

### IN-1: Stale comment claims `NotchPillView` still observes `chargingState` for rendering

**File:** `Islet/Notch/NotchWindowController.swift:50-58`

**Issue:** The comment on `chargingState` says "the wings layout observes" it and that
"the view's @ObservedObject still re-renders an in-place % update inside the same wings
case." This was true before this gap-closure wave, but commit `3690e77` (bundled with
this same gap-closure effort) removed `NotchPillView`'s `charging: ChargingActivityState`
parameter entirely (confirmed: `NotchPillView.swift` no longer declares or accepts a
`charging` property). Percent-tick rendering now flows exclusively through
`presentationState` (the resolver's verdict). `chargingState.activity` is written in
several places but the **only** remaining read is `if chargingState.activity != nil` in
`handleHoverExit()` (line 583) to decide whether to resume the dismiss timer — it no
longer drives any view rendering. The comment should be updated to avoid misleading future
maintainers (this is a first-time-programmer project per CLAUDE.md, where comments carry
real teaching weight) into thinking the view observes this model.

**Fix:** Update the comment, e.g.:
```swift
// Phase 6 note: charging is no longer the RENDER driver — the resolver's TransientQueue is,
// and NotchPillView no longer observes this model at all (its `charging` parameter was
// removed in 3690e77). chargingState is kept only as a "is a charging splash currently
// standing" signal for handleHoverExit's dismiss-timer resume check.
```

### IN-2: `TransientQueue.removeAll(where:)` has no direct unit test

**File:** `IsletTests/IslandResolverTests.swift`

**Issue:** `IslandResolverTests.swift` thoroughly covers `resolve(...)`, `nowPlayingHealthGate(...)`,
`enqueue`, `advance`, and the bound/dedup behavior, but `TransientQueue.removeAll(where:)` —
the pure reducer that `flushTransients` depends on, and whose promotion semantics are exactly
what Finding 3's bug (WR-2 above) interacts with — has no test at all. Given the pure
seam is specifically designed to make this kind of coordination logic "verified
deterministically... in milliseconds" (per the file's own header), this is a real coverage
gap for a function that gap-closure work depends on.

**Fix:** Add tests for `removeAll(where:)` covering: removing a non-matching category
leaves the head untouched, removing a matching head promotes the next pending entry,
removing a matching head with no pending clears to `nil`, and removing matches from
`pending` only (head untouched) leaves the head as-is.

### IN-3: `mediaExpanded`'s transport-row spacers and reserved corners are now non-interactive dead zones

**File:** `Islet/Notch/NotchPillView.swift:404-423`

**Issue:** The Finding 15 fix intentionally scopes the tap-to-toggle gesture on
`mediaExpanded` to only the top (art/title/artist/bars) HStack, explicitly to keep it off
the transport `Button`s. The tradeoff is documented in the code comment, but its effect is
that the bottom control row's `Spacer()`s and the two reserved `Color.clear` Shuffle/Repeat
placeholder boxes are now dead-to-tap regions that previously (pre-fix) collapsed the
island on tap. This is a correct and reasonable tradeoff (better than the alternative
ambiguity bug), but flagging per the review's explicit "no dead zones" check — worth a
deliberate product decision rather than an incidental side effect, since a user tapping
near (but not on) a transport button in the bottom row will now get no response at all.
No fix required if this is the intended UX; otherwise consider giving the `Spacer` regions
their own `.onTapGesture { onClick() }` (they are provably not `Button`s, so no ambiguity
risk).

---

_Reviewed: 2026-07-02T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
