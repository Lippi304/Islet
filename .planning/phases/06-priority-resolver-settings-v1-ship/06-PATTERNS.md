# Phase 6: Priority Resolver, Settings & v1 Ship - Pattern Map (Gap Closure)

**Mapped:** 2026-07-01
**Run type:** Gap-closure (Phase 6 is already implemented; this maps the CURRENT, already-committed
code for the 8 confirmed bugs found by ultrareview + local workflow-backed review, plus the original
phase file list for completeness).
**Files analyzed:** 9 (4 gap-closure targets + 5 supporting analogs/consumers)
**Analogs found:** 9 / 9 (all files already exist — this is bug-fix-in-place, not new-file creation;
"analog" below means "the sibling pattern already established elsewhere in the same file/quartet that
the fix must conform to")

## File Classification

| File (bug target) | Role | Data Flow | Sibling/Analog Pattern | Match Quality |
|---|---|---|---|---|
| `Islet/Notch/NotchWindowController.swift` — `currentPresentation()` | controller (pure-ish read) | request-response | `handleSettingsChanged()` (same file, correctly forces `.none`) | exact — fix by symmetry within same file |
| `Islet/Notch/NotchWindowController.swift` — `handleDevice()` nil-address guard | controller | event-driven | `shouldShowDeviceSplash(...)` pure contract in `DeviceActivity.swift` | exact — caller must honor callee's contract |
| `Islet/Notch/NotchWindowController.swift` — `scheduleDeviceBatteryRefresh()` identity | controller | event-driven / polling | `PowerSourceMonitor`/`handlePower` category-tick pattern (same-category-only update) | role-match — needs an identity key `DeviceActivity`/`ActiveTransient` don't carry |
| `Islet/Notch/NotchWindowController.swift` — `handlePower`/`handleDevice`/`scheduleActivityDismiss` enqueue-render-dismiss triplet | controller | event-driven | itself (3x duplicated) | exact — extract shared helper |
| `Islet/Notch/NotchWindowController.swift` — `handleHoverEnter`/`handleHoverExit`/`handlePointer` hot-zone | controller (AppKit glue) | event-driven | `positionAndShow(on:)` (hotZone/expandedZone computation) | exact — same file, same zone state |
| `Islet/Notch/NotchPillView.swift` — redundant `@ObservedObject var charging` | component (SwiftUI view) | request-response | `nowPlaying: NowPlayingState` (kept ObservedObject, but WITH a documented live-read reason: `.artwork`) | exact — compare against the one that's legitimately kept |
| `Islet/Notch/NotchPillView.swift` — duplicated wings skeleton (`wings(for:)`/`mediaWings`/`deviceWings`) | component (SwiftUI view) | transform | itself (3x duplicated) | exact — extract shared helper |
| `Islet/Notch/NowPlayingMonitor.swift` — health-check race vs persistent stream | service (thin system glue) | event-driven / streaming | `PowerSourceMonitor.start()` (single source of truth, no parallel probe) | role-match — NowPlayingMonitor runs TWO independent probes where Power only runs one |
| `Islet/Notch/DeviceActivityState.swift` — dead/unread `@Published` | model | CRUD (write-only) | `ChargingActivityState` / `NowPlayingState` (both ARE read by the view) | exact — compare against the two live siblings |

## Pattern Assignments

### Bug 1 — `currentPresentation()` stale `isHealthy` flag (NotchWindowController.swift:349-356)

**Current code (the bug):**
```swift
// Islet/Notch/NotchWindowController.swift lines 349-356
private func currentPresentation() -> IslandPresentation {
    let npEnabled = activityEnabled(ActivitySettings.nowPlayingKey)
    let np = npEnabled ? nowPlayingState.presentation : .none   // D-09 disabled NP → forced .none
    return resolve(activeTransient: transientQueue.head,
                   nowPlaying: np,
                   nowPlayingHealthy: nowPlayingState.isHealthy,   // BUG: not gated by npEnabled
                   isExpanded: interaction.isExpanded)
}
```
**Why it's a bug:** when Now Playing is toggled off, `np` is correctly forced to `.none`, but
`nowPlayingHealthy` is NOT forced — it still reads the LAST live value of `nowPlayingState.isHealthy`
(which is whatever it was before `nowPlayingMonitor?.stop()` ran in `handleSettingsChanged()`, line
777). If that stale flag happens to be `false` (e.g. the bridge was mid-outage when the user disabled
NP), `resolve(...)`'s `isExpanded` branch (`IslandResolver.swift` lines 43-46) can select
`.nowPlayingExpanded(nowPlaying, healthy: false)` — i.e. "nicht verfügbar" — even though `nowPlaying`
itself is `.none`/D-09-forced-off and the correct rendering should fall through to `.expandedIdle`
(date/time). `resolve` checks `!nowPlayingHealthy` BEFORE `nowPlaying != .none`, so a stale `false`
short-circuits the correct idle branch.

**Analog / correct pattern already in the same file:** `handleSettingsChanged()` (lines 774-781)
already knows how to fully neutralize a disabled Now-Playing: it clears `presentation` AND `artwork`.
The fix is symmetry — `currentPresentation()` must force `nowPlayingHealthy` to `true` (or otherwise
neutral) exactly like it forces `np` to `.none`, since a disabled activity must be INVISIBLE to the
resolver, not silently degraded:
```swift
// Pattern to apply (mirror the existing `npEnabled ? ... : .none` gating on the SAME line):
let npEnabled = activityEnabled(ActivitySettings.nowPlayingKey)
let np = npEnabled ? nowPlayingState.presentation : .none
let healthy = npEnabled ? nowPlayingState.isHealthy : true   // disabled → never "unavailable"
return resolve(activeTransient: transientQueue.head, nowPlaying: np,
               nowPlayingHealthy: healthy, isExpanded: interaction.isExpanded)
```
**Test to extend:** `IsletTests/IslandResolverTests.swift` already covers `resolve(...)` directly
(`testUnhealthyExpandedShowsUnavailable`, line 58) — this bug is in the CALLER
(`currentPresentation()`), not the pure `resolve` function, so it needs a new controller-level test or
a `handleSettingsChanged`-style unit test, not a resolver test.

---

### Bug 2 — nil-address device-splash regression (`handleDevice`, NotchWindowController.swift:654-666)

**Current code (the bug):**
```swift
// Islet/Notch/NotchWindowController.swift lines 654-666
private func handleDevice(_ reading: DeviceReading) {
    let now = Date().timeIntervalSinceReferenceDate

    // EDGE detection (post-checkpoint fix): ...
    guard let addr = reading.address else { return }   // BUG: drops every nil-address reading
    if reading.connected {
        ...
```
**Why it's a bug:** the pure contract this caller must honor lives in `DeviceActivity.swift`:
```swift
// Islet/Notch/DeviceActivity.swift lines 94-105 — shouldShowDeviceSplash's OWN doc/contract
// says address is OPTIONAL and the function is TOTAL for `address: String?`:
func shouldShowDeviceSplash(address: String?, connected: Bool, now: TimeInterval,
                            lastShown: [String: TimeInterval], debounce: TimeInterval,
                            suppressedAtLaunch: Set<String>) -> Bool {
    if let address {
        if connected && suppressedAtLaunch.contains(address) { return false }
        if let last = lastShown[address], now - last < debounce { return false }
    }
    return true   // <-- nil address falls through to TRUE: "show it, just can't dedup/debounce it"
}
```
and `deviceLabel`/`deviceActivity(from:)` (same file, lines 52-56, 73-82) both handle `address: nil`
gracefully — `deviceLabel` falls back to `"Bluetooth Device"` when BOTH name and address are absent.
The pure seam was explicitly designed (and unit-tested — see `DeviceActivityTests.swift`) to support
addressless devices; `handleDevice`'s `guard let addr = reading.address else { return }` silently
regresses that contract by dropping the reading before any of the pure functions ever run, so an
addressless connect/disconnect (e.g. a device that doesn't expose a MAC over this SDK path) never
splashes at all — DEV-01/DEV-02 requirement violated for that class of device.

**Analog / correct pattern:** the EDGE-dedup logic (`connectedDeviceAddresses` Set) genuinely NEEDS an
address to dedup repeat-connect noise (documented at lines 657-661, the "post-checkpoint fix" for
IOBluetooth re-firing). The fix must split the two concerns instead of one blanket guard: dedup-by-
address is best-effort (skip it, don't reject, when `addr == nil`); the debounce/splash-gate call
(`shouldShowDeviceSplash`) and `deviceActivity(from:)` must still run for nil-address readings, mirroring
how the pure layer already treats nil as "can't dedup, but still show." Concretely: branch on
`reading.address` only for the SET-based edge tracking, and fall through to the shared
`shouldShowDeviceSplash`/`deviceActivity` path unconditionally (as the pure functions already expect).

**Test to extend:** `IsletTests/DeviceActivityTests.swift` (182 LOC) already exercises
`shouldShowDeviceSplash` and `deviceActivity(from:)` with nil addresses at the pure-seam level (per the
review finding, the "unit test" contradicted by this controller guard) — a symmetric
`handleDevice`-level fixture/manual check should confirm the nil-address path is no longer dropped
before reaching the pure seam.

---

### Bug 3 — `scheduleDeviceBatteryRefresh` identity matching (NotchWindowController.swift:707-728)

**Current code (the bug):**
```swift
// Islet/Notch/NotchWindowController.swift lines 707-728
private func scheduleDeviceBatteryRefresh(address: String, attempt: Int = 0) {
    deviceBatteryWork?.cancel()
    guard attempt < 6 else { return }
    let work = DispatchWorkItem { [weak self] in
        guard let self else { return }
        // Stop once the device is no longer the standing splash (advanced / dismissed).
        guard case .device(.connected(let name, let glyph, let old))? = self.transientQueue.head else { return }
        if let monitor = self.bluetoothMonitor,
           let fresh = monitor.battery(forAddress: address), fresh != old {
            let updated = DeviceActivity.connected(name: name, glyph: glyph, battery: fresh)
            self.deviceState.activity = updated
            self.transientQueue.updateHead(.device(updated))
            ...
```
**Why it's a bug:** the guard only checks that the queue head IS `.device(.connected(...))` — it does
NOT check that the head is STILL the SAME device the poll was scheduled for. `DeviceActivity.connected`
carries `name`/`glyph`/`battery` but NOT the `address` used to key the poll. If device A connects
(scheduling a refresh for `address: A`), then within the ~3.6s poll window (6 attempts × 0.6s) device A
disconnects and device B connects (becoming the new head, ALSO `.device(.connected(...))`), the pending
poll for A's battery will match B's head (since the guard only pattern-matches the category, not an
identity) and can overwrite B's splash with A's re-read battery value under B's `name`/`glyph` — a
cross-device data leak into the wrong splash. Only ONE `deviceBatteryWork` item exists (line 107,
"cancelled/replaced per connect"), so `scheduleDeviceBatteryRefresh(address: addr)` in `handleDevice`
(line 697) DOES cancel the OLD poll when a NEW connect fires — but the race window is between the poll
firing (async, on the main queue) and the NEXT connect event's `handleDevice` call also landing on main;
in the interval the mismatched-identity read can occur before the cancel + reschedule executes, or (more
concretely) whenever the SAME address's stale delayed poll refires after the device disconnects and a
DIFFERENT device with a different address becomes head in between.

**Analog / correct pattern:** `handlePower`'s category-tick refresh (lines 597-604) has the SAME
"only touch the head if it's still my category" shape but is safe because charging has only ONE
possible identity per category (there's only one internal battery). The device case needs an
address-carrying identity check that charging doesn't need. The fix should either (a) thread `address`
into `DeviceActivity.connected` (touches the pure seam + its tests — bigger), or (b) track the
address of the CURRENTLY-POLLED device as a separate controller-owned property (e.g.
`private var pollingAddress: String?` set alongside `deviceBatteryWork`) and compare it before applying
the poll result — mirroring how `deviceLastShown[addr]` is already an address-keyed side table
(line 86) rather than touching the enum. Option (b) is the smaller, more local fix and matches the
existing "controller keeps address-keyed side dictionaries, pure enum stays address-free" convention
already used for `deviceLastShown`.

---

### Bug 4 — duplicated enqueue/render/dismiss sequences (NotchWindowController.swift)

**Current code (the duplication — 3 near-identical triplets):**
```swift
// Triplet A — handlePower, lines 590-596
if changed {
    withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
        renderPresentation()
    }
    updateVisibility()           // Pattern 6 — the SOLE show/hide site (fullscreen gate)
    scheduleActivityDismiss()    // D-09 — the ~3s one-shot that advances the queue
}

// Triplet B — handleDevice, lines 688-693
if changed {
    withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
        renderPresentation()
    }
    updateVisibility()                            // Pattern 6 — the SOLE show/hide site
    scheduleActivityDismiss()                     // shared ~3s one-shot (advances the queue)
}

// Triplet C — scheduleActivityDismiss's own advance branch, lines 619-627 (render+visibility, then
// conditionally re-arms itself instead of calling scheduleActivityDismiss externally)
_ = self.transientQueue.advance()
withAnimation(.spring(response: self.springResponse, dampingFraction: self.springDamping)) {
    self.syncActivityModels()
    self.renderPresentation()
}
self.updateVisibility()
if self.transientQueue.head != nil { self.scheduleActivityDismiss() }
```
**Why it's flagged:** three call sites hand-roll the same "spring-wrap renderPresentation, call the
sole updateVisibility(), (re)arm the shared dismiss" sequence with only cosmetic comment differences —
a classic extract-method target that the review correctly flags as duplication risk (a future 4th
transient source, or a fix to one triplet not mirrored to the other two, silently diverges behavior).

**Analog / correct pattern:** the file ALREADY has the discipline of one shared timing primitive
(`scheduleActivityDismiss`, itself documented as "generalized from a single charging splash to the
transient QUEUE" at line 607) — the natural next step (already implied by the file's own comments,
e.g. "Pattern 6 — the SOLE show/hide site" repeated 3x) is a single private helper, e.g.:
```swift
// Suggested consolidation (matches the file's existing "ONE place" discipline for updateVisibility):
private func presentTransientChange() {
    withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
        renderPresentation()
    }
    updateVisibility()
    scheduleActivityDismiss()
}
```
called from `handlePower`'s `if changed { presentTransientChange() }` and `handleDevice`'s
`if changed { presentTransientChange() }`. `scheduleActivityDismiss`'s internal advance-branch is
allowed to stay distinct (it conditionally re-arms rather than unconditionally scheduling), but should
at minimum reuse the render+visibility half if a helper is extracted at that granularity.

---

### Bug 5 — hover hot-zone sizing (`handlePointer`/`handleHoverEnter`/`handleHoverExit`, NotchWindowController.swift:447-544)

**Current code (relevant zone state + computation):**
```swift
// Islet/Notch/NotchWindowController.swift lines 180-190 (state) + 423-427 (computation) + 447-466 (use)
private var hotZone: CGRect?
private var expandedZone: CGRect?
...
// positionAndShow(on:), lines 423-427:
hotZone = collapsedFrame.insetBy(dx: -hotZonePadding, dy: -hotZonePadding)
expandedZone = panelFrame.insetBy(dx: -hotZonePadding, dy: -hotZonePadding)
...
// handlePointer, lines 447-466:
private func handlePointer(at point: CGPoint) {
    let activeZone = interaction.isExpanded ? (expandedZone ?? hotZone) : hotZone
    guard let zone = activeZone else { return }
    let inside = zone.contains(point)
    if inside && !pointerInZone {
        pointerInZone = true
        handleHoverEnter()
    } else if !inside && pointerInZone {
        pointerInZone = false
        handleHoverExit()
    }
}
```
**What to check when fixing:** `expandedZone` is computed from `panelFrame.insetBy(...)` where
`panelFrame = expandedFrame.union(wings)` (line 421) — i.e. it is sized to the UNION of the downward
expand AND the sideways wings, even though while `.expanded` the wings presentations (`.charging`/
`.device`/`.nowPlayingWings`) can't simultaneously be showing (the resolver is a single-arbiter
switch — Pattern 6/`IslandResolver.swift`). This makes `expandedZone` LARGER than the actually-visible
expanded content in some cases, or (the more likely regression direction per the review) the padding
(`hotZonePadding = 6`, line 197) applied uniformly to a UNION rect may not correctly cover the real
visible bounds of `.nowPlayingExpanded`/`.expandedIdle` (which render at `expandedSize` 360×128, not the
wings' 290×32) — the fix should re-derive `expandedZone` from what CAN actually be showing while
`isExpanded == true` (i.e. `expandedFrame` alone, since wings never render while expanded per the
resolver), not the panel's full union with the wings frame.

**Analog / correct pattern:** `hotZone` (the collapsed case) is derived from EXACTLY the frame that's
visible when collapsed (`collapsedFrame`) — the same discipline (zone == the frame of what's ACTUALLY
rendered in that phase) should apply to `expandedZone`; deriving it from the wider `panelFrame` union
is the mismatch to correct.

---

### Bug 6 — redundant `@ObservedObject var charging` (NotchPillView.swift:28, :736)

**Current code (the redundant subscription):**
```swift
// Islet/Notch/NotchPillView.swift lines 21-28
// CHG-01 / Pattern 2 — the SEPARATE charging-splash model (Plan 01). ...
@ObservedObject var charging: ChargingActivityState
```
grep confirms **zero** reads of `charging.` inside the view body (only a comment mentions it, line 38)
— the `switch presentation { case .charging(let a): wings(for: a) ... }` (line 133-134) receives the
`ChargingActivity` value DIRECTLY from the `IslandPresentation` enum case, never from
`charging.activity`.

**Analog — the ONE sibling that correctly stays `@ObservedObject` with a documented reason:**
```swift
// Islet/Notch/NotchPillView.swift lines 40-44 — nowPlaying is KEPT and the comment says why:
// `nowPlaying.artwork` is still read for the media cases (the resolver passes only the
// presentation enum, not the NSImage), and `charging`/`nowPlaying` are still @ObservedObject
// so an artwork/standing-% mutation re-renders the same case. The PRECEDENCE decision is gone.
@ObservedObject var nowPlaying: NowPlayingState
```
and indeed `nowPlaying.artwork` IS read at lines 138, 140, 238, 386, 400. `charging` has no equivalent
side-channel read — the comment's justification ("so an artwork/standing-% mutation re-renders")
applies to `nowPlaying.artwork` but NOT to `charging`, since the % IS already carried inside the
`IslandPresentation.charging(ChargingActivity)` case payload itself (the resolver re-renders on every
`renderPresentation()` call, including the in-place `% tick` path in `handlePower`, lines 597-604, which
already calls `renderPresentation()` unconditionally). **Fix:** remove `@ObservedObject var charging:
ChargingActivityState` from `NotchPillView` and its `makeRootView(accentIndex:)` call site
(`NotchWindowController.swift` line 736), OR keep the property but change it from `@ObservedObject` to
a plain unobserved reference if some other file/preview still needs the type — confirm no `#Preview`
block references it before removing outright.

---

### Bug 7 — duplicated wings-shape skeleton (`wings(for:)`/`mediaWings`/`deviceWings`, NotchPillView.swift:197-300)

**Current code (the 3x-duplicated skeleton):**
```swift
// wings(for:) — lines 205-220
return NotchShape(topCornerRadius: 6, bottomCornerRadius: 6)
    .fill(Color.black)
    .matchedGeometryEffect(id: "island", in: ns)
    .frame(width: Self.wingsSize.width, height: Self.wingsSize.height)
    .overlay(
        HStack(spacing: 0) { /* charging-specific content */ }
        .frame(width: Self.wingsSize.width, height: Self.wingsSize.height)
    )

// mediaWings — lines 232-245 (IDENTICAL skeleton, mediaWingsSize, media-specific HStack content)
// deviceWings — lines 267-285 (IDENTICAL skeleton, deviceWingsSize, device-specific HStack content)
```
**Why it's flagged:** all three wings functions repeat the exact same 5-line
`NotchShape → .fill → .matchedGeometryEffect → .frame → .overlay(HStack...frame)` skeleton, differing
only in the HStack's inner content and (nominally) the size constant — though `wingsSize`,
`mediaWingsSize`, and `deviceWingsSize` are ALL `CGSize(width: 290, height: 32)` (lines 114-116, "ONE
uniform 290 pt width across all three wing glances... so the island reads consistently"), so the size
is not even actually varying — pure duplication.

**Analog / correct pattern:** extract a shared `wingsShape<Content: View>(@ViewBuilder content: () ->
Content) -> some View` helper that owns the `NotchShape`/`.fill`/`.matchedGeometryEffect`/`.frame`
skeleton once, and have each of the three call sites pass only their distinct `HStack` content:
```swift
// Suggested consolidation:
private func wingsShape<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    NotchShape(topCornerRadius: 6, bottomCornerRadius: 6)
        .fill(Color.black)
        .matchedGeometryEffect(id: "island", in: ns)
        .frame(width: Self.wingsSize.width, height: Self.wingsSize.height)   // now the ONE size constant
        .overlay(content().frame(width: Self.wingsSize.width, height: Self.wingsSize.height))
}
// wings(for:) becomes: wingsShape { HStack(spacing: 0) { ...charging content... } }
// mediaWings becomes:  wingsShape { HStack(spacing: 0) { ...media content... } }
// deviceWings becomes: wingsShape { HStack(spacing: 0) { ...device content... } }
```
Note: `mediaWingsSize`/`deviceWingsSize`/`wingsSize` can likely collapse to ONE constant too (they are
already numerically identical per the D-checkpoint comment), but that is a separate, smaller cleanup the
planner may fold into the same task.

---

### Bug 8 — health-check race vs persistent stream (NowPlayingMonitor.swift)

**Current code (the two independent, concurrently-running probes):**
```swift
// Islet/Notch/NowPlayingMonitor.swift lines 55-69 — the PERSISTENT stream (start())
func start() {
    controller.onTrackInfoReceived = { [weak self] info in ... self.onSnapshot(snap, p.artwork) }
    controller.onListenerTerminated = { [weak self] in self?.onTerminated() }
    controller.startListening()   // ONE persistent `loop` child
}

// Islet/Notch/NowPlayingMonitor.swift lines 83-95 — the SEPARATE one-shot health probe
func runHealthCheck(then setHealthy: @escaping (Bool) -> Void) {
    var settled = false
    controller.getTrackInfo { info in            // spawns its OWN perl child (per the file's own
        if settled { return }                     // header comment, line 20-22: "getTrackInfo{...}
        settled = true                             // is the ONE-SHOT (it re-spawns perl per call)")
        setHealthy(true)
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
        if settled { return }
        settled = true
        setHealthy(false)
    }
}
```
**And the call site that races them (NotchWindowController.swift lines 309-321):**
```swift
private func startNowPlayingMonitor() {
    guard nowPlayingMonitor == nil else { return }
    let np = NowPlayingMonitor(
        onSnapshot: { [weak self] snap, art in self?.handleNowPlaying(snap, art) },
        onTerminated: { [weak self] in self?.handleAdapterTerminated() })
    nowPlayingMonitor = np
    np.start()                                    // starts the PERSISTENT stream child
    np.runHealthCheck { [weak self] healthy in     // ALSO starts a SEPARATE one-shot child
        guard let self else { return }
        self.nowPlayingState.isHealthy = healthy   // last-write-wins against handleNowPlaying below
        self.renderPresentation()
    }
}
```
**Why it's a race:** `handleNowPlaying` (`NotchWindowController.swift` line 833) sets
`nowPlayingState.isHealthy = true` on EVERY successful stream emission — which is a strictly stronger,
more current health signal than the one-shot probe. But both write the SAME `@Published var isHealthy`
with no ordering guarantee: if the persistent stream emits first (proving health), and THEN the
separate `getTrackInfo` one-shot probe's OWN perl child independently times out or errors (e.g. under
system load, spawning two perl processes back-to-back is exactly the kind of contention that could make
the second one slower/fail), `runHealthCheck`'s completion can fire `setHealthy(false)` AFTER the stream
already proved `true` — reverting a working feed to the "nicht verfügbar" state while the app is
actively receiving live snapshots. The file's own header (lines 27-33) documents that the health probe
is a "synthesized" workaround specifically because a distinct `test` subcommand isn't exposed — it does
NOT document that the probe's outcome should ever be allowed to overwrite a LATER, more authoritative
stream-derived `true`.

**Analog / correct pattern:** `PowerSourceMonitor` (the sibling quartet member) has exactly ONE source
of truth per property — `readCurrentPower()` is called both at `start()` (line 92) and on every live
IOPS notification (line 82), and there is never a second, independently-racing probe for the same state.
The fix should make the one-shot health probe NEVER downgrade a health flag the persistent stream has
already promoted to `true` — e.g. gate `setHealthy(false)` in the timeout branch on
`nowPlayingState.isHealthy != true` at the call site, or have `runHealthCheck`'s `then` closure only
ever be allowed to set `true` (a monotonic "at least one success ever" flag) while `handleNowPlaying`/
`handleAdapterTerminated` remain the sole authority for flipping it back to `false` on ACTUAL stream
death (which is what `handleAdapterTerminated`, line 886, already correctly does via `onTerminated`).

---

### Bug 9 — `DeviceActivityState.swift` dead/unread state

**Current code (the entire file — 15 lines, unchanged from Phase-5):**
```swift
// Islet/Notch/DeviceActivityState.swift
import Foundation
final class DeviceActivityState: ObservableObject {
    @Published var activity: DeviceActivity?
}
```
**Confirmed dead by cross-reference:**
- `NotchWindowController` constructs it (line 64: `private let deviceState = DeviceActivityState()`)
  and WRITES to `deviceState.activity` in 5 places (lines 638, 640, 686, 717, 808) to "keep the model
  in sync with the head" (line 686's own comment).
- `NotchWindowController.makeRootView(accentIndex:)` (lines 735-746) passes `interaction`, `charging`,
  `nowPlaying`, `presentationState` to `NotchPillView` — **`deviceState` is never passed**. Confirmed by
  grep: the only `NotchPillView(` construction site in the file omits it entirely.
- `NotchPillView` has no `device`/`deviceState` property at all (confirmed: `@ObservedObject`
  declarations are only `interaction`, `charging`, `nowPlaying`, `presentationState` — lines 19-51).

So `DeviceActivityState` is maintained (written 5x, with real per-mutation bookkeeping cost) but has
**zero observers** — it is pure dead weight, unlike `chargingState` (Bug 6, ALSO unread by the view but
at least passed to it) or `nowPlayingState` (genuinely read for `.artwork`).

**Analog — compare against the two siblings that ARE (or, per Bug 6, SHOULD remain) load-bearing:**
`NowPlayingState` (`Islet/Notch/NowPlayingState.swift`) is read for `.artwork` in the view; it is the
correct shape for "a model that must stay `@Published` + passed to the view." `DeviceActivityState`
matches neither shape — its only reads are internal to the controller itself (line 713, in
`scheduleDeviceBatteryRefresh`'s guard, reading `transientQueue.head`, NOT `deviceState.activity`), so
even the controller's own read path bypasses this model.

**Fix direction:** either (a) delete `deviceState`/`DeviceActivityState.swift` entirely and have the 5
write sites become no-ops removed (the `IslandPresentationState`/`TransientQueue` already carry
everything the view needs, per Bug 6's finding that the resolver's enum payload is sufficient), or (b)
if a future feature needs a directly-observable device model (independent of the transient queue), wire
it INTO `NotchPillView` the same way `nowPlaying` is wired, with a documented reason like the
`nowPlaying.artwork` comment. Given Bug 6 already establishes the resolver-enum-is-sufficient pattern,
(a) — delete — is the pattern-consistent choice; the planner should decide scope (deleting touches 6+
call sites across the controller).

---

## Shared Patterns

### The "ONE place" discipline (applies to Bugs 1, 4, 5)
**Source:** `NotchWindowController.swift`'s own repeated self-documentation — `updateVisibility()` is
called "Pattern 6/7 — the SOLE show/hide site" (lines 365-372, repeated in 6+ call-site comments);
`scheduleActivityDismiss()` is "the ONE one-shot dismiss, generalized... to the transient QUEUE" (line
607). Every gap-closure fix in this file should preserve or extend this discipline (single source of
truth per concern) rather than adding a second competing path.
**Apply to:** Bug 1 (health flag must have ONE authority — the stream, not two independent writers),
Bug 4 (the triplet should become ONE helper), Bug 5 (zone should derive from ONE actually-visible frame
per phase).

### Pure-seam-first classification (applies to Bugs 2, 3, 9)
**Source:** `DeviceActivity.swift` / `PowerActivity.swift` / `NowPlayingPresentation.swift` — all three
document themselves as "TOTAL pure functions... imported ONLY Foundation... unit-tested in ms" with the
system-framework glue (`BluetoothMonitor`/`PowerSourceMonitor`/`NowPlayingMonitor`) kept thin and
deferring to the pure seam for all classification logic.
**Apply to:** Bug 2 — the controller must not add classification logic (a nil-address reject) that the
pure seam doesn't have; Bug 3 — identity-tracking belongs in a controller-owned side table (like
`deviceLastShown`), not smuggled into the pure `DeviceActivity` enum; Bug 9 — if `DeviceActivityState`
is kept, it must earn its place the same way `NowPlayingState` did (an actual, documented view-level
read), not just mirror the model shape without a consumer.

### Existing test scaffolding to extend
**Source:** `IsletTests/IslandResolverTests.swift` (pure resolver + queue, 14 tests already green) and
`IsletTests/DeviceActivityTests.swift` (pure device seam, 182 LOC). Bugs 1/2/3/8 are all in the
CONTROLLER/GLUE layer (not the pure seams), which per the project's own Validation Architecture
(06-RESEARCH.md, "Test Framework" section) is verified on-device/manually, not via new XCTest files —
the planner should write manual UAT steps for these 4, and only add XCTest coverage where the fix can
be pushed down into a pure function (e.g. Bug 1's `let healthy = npEnabled ? ... : true` could be
factored into a tiny pure helper and unit-tested; Bug 3's identity check likewise).

## No Analog Found

None — all 9 bug-fix targets are modifications to existing, already-implemented files; every fix has a
concrete sibling/analog pattern within the same file or the same activity "quartet" (Power/NowPlaying/
Device) to conform to, as detailed above.

## Metadata

**Analog search scope:** `Islet/Notch/*.swift`, `Islet/*.swift`, `IsletTests/*.swift` (all read/grepped
this session; no directories outside `Islet`/`IsletTests` are relevant to this native macOS app).
**Files scanned:** 27 Swift source files enumerated; 9 read in full or via targeted non-overlapping
`Read`/`Grep` passes (`NotchWindowController.swift` 927 lines in 3 non-overlapping reads,
`NotchPillView.swift` 665 lines in 3 non-overlapping reads, `NowPlayingMonitor.swift` 96 lines,
`DeviceActivityState.swift` 15 lines, `IslandResolver.swift` 110 lines, `BluetoothMonitor.swift` 158
lines, `DeviceActivity.swift` 105 lines, `PowerSourceMonitor.swift` 112 lines, `ChargingActivityState.swift`
12 lines, `IslandPresentationState.swift` 21 lines, `ActivitySettings.swift` 44 lines — all full-file,
no re-reads).
**Pattern extraction date:** 2026-07-01
