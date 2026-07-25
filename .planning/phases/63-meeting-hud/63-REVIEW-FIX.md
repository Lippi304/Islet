---
phase: 63-meeting-hud
fixed_at: 2026-07-25T12:20:00Z
review_path: .planning/phases/63-meeting-hud/63-REVIEW.md
iteration: 1
findings_in_scope: 10
fixed: 9
skipped: 1
status: partial
---

# Phase 63: Code Review Fix Report

**Fixed at:** 2026-07-25
**Source review:** `.planning/phases/63-meeting-hud/63-REVIEW.md`
**Iteration:** 1

**Summary:**
- Findings in scope: 10 (CR-01..CR-03, WR-01..WR-07 — Info findings out of scope)
- Fixed: 9
- Skipped: 1 (WR-06 — the suggested fix does not compile against the real call site)

**Verification performed:**
- Every edited file re-read after editing (Tier 1).
- `xcrun swiftc -parse` on every edited file after every edit (Tier 2, syntax).
- `xcodebuild build -scheme Islet` → **BUILD SUCCEEDED** (full type-check of the app target).
- `xcodebuild build-for-testing -scheme Islet` → **TEST BUILD SUCCEEDED** (type-checks the test target too).
- `xcodebuild test-without-building` could **not** execute in this environment: the runner
  reports "Islet encountered an error (The test runner hung before establishing connection)"
  before any test code runs. Islet is an `LSUIElement` NSPanel overlay app and the agent has no
  interactive GUI session. The unit tests (existing + the ones added below) therefore compile
  but were **not executed** — run them from Xcode.

## Fixed Issues

### CR-01: `isMuted` sampled once and never refreshed

**Files modified:** `Islet/Notch/MeetingActivity.swift`, `Islet/Notch/MeetingMonitor.swift`, `Islet/Notch/NotchWindowController.swift`, `IsletTests/MeetingActivityTests.swift`
**Commit:** `34ba6ff`
**Applied fix:** `MeetingReading` now carries `isMuted`. `MeetingMonitor.evaluate()` re-reads mute
on every evaluation and emits a second kind of change — a mute flip *while the same call stands* —
keeping the existing nil↔non-nil dedup untouched. `handleMeetingActivityChange` takes mute from
the reading instead of a one-shot `readSystemInputMuted()`, and routes a mid-call emission through
`updateHead` + `renderPresentation()` (in-place payload refresh) rather than `preempt`, which
would have pushed the old `.meeting` head into `pending`.

**Deviation from the review's suggestion:** the review offered a poll-based floor and a
`kAudioDevicePropertyMute` listener as the responsive version. Only the floor was implemented, so
external mute changes (hardware key, device swap, another app) converge within the existing 5s
poll rather than instantly. The unbounded staleness — the actual defect — is gone; the remaining
gap is latency. Adding the listener means two more CoreAudio add/remove pairings on a device that
may not implement the property at all (T-63-01), which is a meaningfully larger leak surface for
a latency-only win. **Deferred, not rejected.**

*Requires human verification:* the 5s convergence and the mid-call in-place refresh are on-device
behaviours (mute from Control Center during a call, then watch the HUD glyph).

---

### CR-02 / CR-03: a call parked what it displaced, and could itself be evicted from the queue

**Files modified:** `Islet/Notch/IslandResolver.swift`, `IsletTests/IslandResolverTests.swift`
**Commit:** `839fd84`
**Applied fix:** one rule in `TransientQueue.preempt(_:)` closes both findings — a `.meeting`
always takes the head immediately and clears `pending` outright:

- **CR-02** — the displaced persistent head is no longer parked at `pending[0]`, so it can no
  longer be promoted stale after the call (the frozen download spinner / the 00:00 timer that
  `TimerMonitor` would never update again). This is also the literal reading of the UAT
  requirement the drop rule came from: "nothing surfaces late once the call ends".
- **CR-03** — a call that always takes the head can never sit in `pending`, so `enqueue`'s
  `maxDepth` "drop the oldest" bound can never evict it.

**Deviation from the review's suggestion:** the review's primary CR-02 fix (reconcile `pending`
inside `updateHead`) and CR-03 fix (a `.meeting`-skipping eviction scan) were **not** used. The
review itself named the drop-instead-of-park alternative as "simpler" and closer to the stated
requirement, and it happens to subsume CR-03 as well — one 5-line branch instead of two separate
special cases in two methods.

Note the review's CR-03 snippet also contained a latent bug: `if let i = pending.lastIndex(where:
{ if case .meeting = $0 { return false }; return true })` evicts the newest **non-meeting** entry,
but its `else { return false }` path silently drops the incoming transient without appending —
not what the surrounding comment describes.

**Tests:** `testMeetingOutranksLowerRankedPersistentTransients` was updated (it encoded the buggy
contract — it asserted the displaced head is resumed by `advance()` after the call), and
`testMeetingIsNeverQueuedBehindANonPersistentHead` was added as the CR-03 regression the review
asked for. Both compile; neither could be executed here (see Verification above).

*Requires human verification:* this changes queue semantics — an incoming call now cuts short the
tail of a standing ~3s charging/device splash instead of queueing behind it. Deliberate, and
consistent with "a live call must not be interrupted by ANYTHING", but it is a user-visible
behaviour change that the unit tests could not be run against here.

---

### WR-01: `handleMuteTap()` wrote the system mic before validating the head

**Files modified:** `Islet/Notch/NotchWindowController.swift`
**Commit:** `a5d34a2`
**Applied fix:** the two guards swapped, exactly as suggested — the `.meeting` head is validated
before `toggleSystemInputMute()` issues the system-wide write.

---

### WR-02: no debounce restarted the call timer at 00:00 on a transient input gap

**Files modified:** `Islet/Notch/MeetingMonitor.swift`
**Commit:** `4d8cc90`
**Applied fix:** `lastCallStart` / `lastEndedAt` survive the nil gap; a re-detection within a
10s grace window reuses the previous `callStart` instead of minting a new one.

**Deviation from the review's suggestion:** the review's snippet keys the grace window off the
previous *callStart* (`lastDetectedAt.map { Date().timeIntervalSince($0) < 10 ? $0 : Date() }`),
which is wrong on the edge case that matters — a call that has been running longer than 10s and
then genuinely drops would never resume its counter, while the whole point is bridging a gap
*after* a long-running call. Keying off the falling edge (`lastEndedAt`) instead makes the window
mean what the comment says: "the detection gap was short".

---

### WR-03: unchecked `OSStatus` on the default-input-device listener registration

**Files modified:** `Islet/Notch/MeetingMonitor.swift`
**Commit:** `3f28dd5`
**Applied fix:** the return value is now checked and a DEBUG message is printed on failure, as
suggested. It reports rather than bails — the 5s poll still converges and `stop()`'s matching
`Remove` on a never-added listener is a harmless no-op.

---

### WR-04: `stop()` left `lastReading` set, breaking the "idempotent and symmetric" contract

**Files modified:** `Islet/Notch/MeetingMonitor.swift`
**Commit:** `a7540af`
**Applied fix:** `stop()` clears `lastReading` plus the WR-02 gap state. Those three properties
became `nonisolated(unsafe)`, matching the five already annotated that way in this file for
exactly this reason (`stop()` is `nonisolated` — see WR-06 below).

---

### WR-05: the meeting hot-zone widen made ~112pt of menu bar unclickable for the whole call

**Files modified:** `Islet/Notch/NotchPillView.swift`, `Islet/Notch/NotchWindowController.swift`
**Commit:** `1d40115`
**Applied fix:** `collapsedInteractiveZone()` keeps its single contiguous rect (it is the *hover*
zone; a hole in it would make the enter/exit edge detection flap). Interactivity is narrowed
separately in `syncClickThrough()` to `meetingClickThroughZones()` — the pill plus the mute
icon's real footprint — so the ~84pt band between them stays click-through. `handlePointer()`
now re-syncs click-through on every raw pointer tick while a call stands, reusing the mechanism
the expanded branch already documents, because that inner boundary is never crossed by the coarse
hot-zone enter/exit edges. A new `NotchPillView.meetingMuteIconWidth` static feeds both the render
and the zone, with an `assert` in `meetingWings(for:)` tying it to the locally-derived width.

**Deviation from the review's suggestion:** the review's snippet ends in
`CGRect(...).union(hotZone)`. That does **not** work — `CGRect.union` of two disjoint rects is
their *bounding box*, which reproduces the exact over-wide band the fix is meant to remove. Hence
the array-of-rects approach, scoped to `syncClickThrough()` so the hover zone stays contiguous.

*Requires human verification:* click-through geometry is on-device-only. Check that (a) the mute
icon still receives taps when approached from either side, and (b) a menu-bar extra sitting right
of the notch stays clickable during a call.

---

### WR-07: `MicMuteControllerTests` mutated the real system mic with no failure-path restore

**Files modified:** `IsletTests/MicMuteControllerTests.swift`
**Commit:** `abc7ca8`
**Applied fix:** `addTeardownBlock` registered before the first toggle, as suggested. It re-reads
before acting (no-op when the body already restored) and never asserts, so a teardown failure
cannot mask the real one.

---

## Skipped Issues

### WR-06: `nonisolated func stop()` performs teardown with no thread guarantee

**File:** `Islet/Notch/MeetingMonitor.swift:114-137`
**Reason:** skipped — the finding's premise is factually wrong, and both suggested fixes are worse
than the status quo.

The review states "the only callers are main-actor (`NotchWindowController.swift:2790,3289`), so
it is latent". Line 3289 is **inside `NotchWindowController`'s `deinit`**, which is nonisolated
(the file's own `TimerMonitor` comment spells this out: "deinit can't be @MainActor in Swift 5
mode"). So:

- The primary suggestion — *drop `nonisolated`* — **would not compile**: calling a main-actor
  method synchronously from a nonisolated `deinit` is an isolation error.
- The alternative — `DispatchQueue.main.sync { tearDown() }` — needs `MainActor.assumeIsolated`
  to type-check at all, and introduces a blocking main-queue hop inside a `deinit`, i.e. a real
  deadlock risk traded for a latent one.

`nonisolated func stop()` + `nonisolated(unsafe)` stored properties is also the project-wide
convention for this exact reason — `CapsLockMonitor`, `DownloadMonitor`, `AudioOutputMonitor` and
`TimerMonitor` are all identical, each with a comment naming the nonisolated deinit as the cause.
Changing only `MeetingMonitor` would make it the odd one out without removing the pattern.

If the underlying concern (a `Timer.invalidate()` reaching a non-main thread) is worth acting on,
it is a **project-wide** change to the monitor teardown convention, not a Phase 63 fix — it
belongs in `deferred-items.md`, not in this review cycle.

**Original issue:** `stop()` mutates five `nonisolated(unsafe)` properties and calls
`NSWorkspace.removeObserver` / `Timer.invalidate()` with no thread guarantee, and the
`nonisolated(unsafe)` annotations opt out of the data-race checking that would catch it.

---

## Not Applied (out of scope)

IN-01 through IN-05 were not touched — `fix_scope` was `critical_warning`. IN-04 (the mute icon
has an accessibility label but no `.isButton` trait or `.accessibilityAction`, making the HUD's
only interactive control unreachable by VoiceOver) is a two-line fix and is the most worthwhile
of the five if a follow-up pass is wanted.

---

_Fixed: 2026-07-25_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
