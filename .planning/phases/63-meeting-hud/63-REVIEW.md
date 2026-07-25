---
phase: 63-meeting-hud
reviewed: 2026-07-25T00:00:00Z
depth: standard
files_reviewed: 10
files_reviewed_list:
  - Islet/Notch/MeetingActivity.swift
  - Islet/Notch/MicMuteController.swift
  - Islet/Notch/MeetingMonitor.swift
  - Islet/Notch/IslandResolver.swift
  - Islet/Notch/NotchPillView.swift
  - Islet/Notch/NotchWindowController.swift
  - IsletTests/MeetingActivityTests.swift
  - IsletTests/MicMuteControllerTests.swift
  - IsletTests/MeetingMonitorManualSpike.swift
  - IsletTests/IslandResolverTests.swift
findings:
  critical: 3
  warning: 7
  info: 5
  total: 15
status: issues_found
---

# Phase 63: Code Review Report

**Reviewed:** 2026-07-25
**Depth:** standard
**Files Reviewed:** 10
**Status:** issues_found

## Summary

Reviewed the Phase 63 Meeting-HUD surface: the three new files (`MeetingActivity.swift`,
`MicMuteController.swift`, `MeetingMonitor.swift`), the `.meeting` additions to
`IslandResolver.swift` (case, `isPersistent`, `dropsWhileCallStands`, `updateHead`), the
`meetingWings` render path plus shared geometry constants in `NotchPillView.swift`, and the
monitor lifecycle / mute-tap / settings / hot-zone wiring in `NotchWindowController.swift`.

The pure layer (`MeetingActivity`, the elapsed-label helper, its tests) is clean and correctly
clamps. The CoreAudio Get/Set discipline in `MicMuteController` is sound: every access is
guarded by `AudioObjectHasProperty` and the Set is genuinely the last step, so a failure never
partially applies. Listener registration/deregistration in `MeetingMonitor` is symmetric and
correctly stores the *listened* device rather than re-deriving it at teardown. Render and
click-through geometry do share the `meetingMuteIconTrailingEdgeOffset` constant, and the
resulting zone over-covers the icon rather than under-covering it.

The serious problems are not in the CoreAudio boilerplate — they are in state lifetime:

1. `MeetingActivity.isMuted` is sampled exactly once, at call start, and never refreshed. The
   HUD can assert "muted" for a live microphone for the entire call.
2. The new `dropsWhileCallStands` rule, combined with `updateHead`'s same-category guard, makes
   the queue silently swallow *state transitions* of whatever persistent transient the call
   displaced — leaving a permanently stuck stale Download/Timer head after the call ends.
3. A `.meeting` queued behind a non-persistent head can be evicted by the `maxDepth` overflow,
   and the monitor's once-per-transition dedup means it will never be re-emitted for that call.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: `isMuted` is sampled once and never refreshed — the HUD can show "muted" for a live mic

**File:** `Islet/Notch/NotchWindowController.swift:2447`, `Islet/Notch/MeetingMonitor.swift:157-171,194-199`
**Issue:**
`MeetingActivity.isMuted` is populated exactly once, from `readSystemInputMuted()` at the moment
the call is detected (`NotchWindowController.swift:2447`). Nothing ever re-reads it afterwards
except the user's own tap on the icon (`handleMuteTap`):

- there is no listener registered on `kAudioDevicePropertyMute` anywhere (grep confirms the
  selector appears only in `MicMuteController.swift`);
- `MeetingMonitor.evaluate()` only compares the detection AND-gate and returns early unless the
  nil ↔ non-nil edge flips, so neither the 5s poll nor the HAL listener refreshes mute;
- `retargetInputListener()` re-points the *device-is-running* listener on a default-input-device
  change but never re-reads mute for the new device.

The device-change path is the exact scenario this file itself calls out at
`MeetingMonitor.swift:78-79` ("AirPods connect mid-call"). Concrete failure: the user taps the
HUD's mute icon while on the built-in mic (HUD shows `mic.slash.fill`, red), then connects
AirPods. The default input device becomes the AirPods, whose `kAudioDevicePropertyMute` is
independent and unmuted. The HUD keeps rendering "muted" for the rest of the call while the
microphone is live. The same staleness occurs for the macOS hardware mic-mute key or any other
process writing the property.

This is worse than a cosmetic desync: the HUD's entire stated purpose (63-UI-SPEC's
"read-after-write, never an optimistic local flip") is to be the truthful mute indicator, and a
false "you are muted" is a privacy-affecting misrepresentation. The read-after-write discipline
is correctly applied to the *write* path but not to the *state* path.

**Fix:** Register a mute listener alongside the running-somewhere listener on the same device
(the retarget path already owns add/remove symmetry), and re-read mute whenever the device
changes or the poll fires. Minimum viable version — refresh mute from the existing poll and
retarget path and push it through `updateHead`:

```swift
// MeetingMonitor.swift — widen the emitted reading instead of only signalling transitions.
struct MeetingReading: Equatable {
    let detectedAt: Date
    let isMuted: Bool
}

private func evaluate() {
    let detected = isTargetAppRunning() && isInputRunning()
    let muted = detected ? readSystemInputMuted() : false
    if detected != (lastReading != nil) {
        lastReading = detected ? MeetingReading(detectedAt: Date(), isMuted: muted) : nil
        onChange(lastReading)
    } else if let last = lastReading, last.isMuted != muted {
        // mute changed under us (device switch / hardware key / another app)
        lastReading = MeetingReading(detectedAt: last.detectedAt, isMuted: muted)
        onMuteChange(muted)          // controller: transientQueue.updateHead(.meeting(...)) + render
    }
}
```

Registering an actual `kAudioDevicePropertyMute` listener in `retargetInputListener()` (same
block, same add/remove pairing already implemented there) is the responsive version; the poll
above is the floor.

---

### CR-02: `dropsWhileCallStands` swallows state transitions of the displaced persistent head — permanently stuck stale HUD after the call

**File:** `Islet/Notch/IslandResolver.swift:385-389,420-426,441-452`; `Islet/Notch/NotchWindowController.swift:550-557,1018-1024`
**Issue:**
`preempt(.meeting(...))` pushes an already-standing *persistent* head to `pending[0]`
(`IslandResolver.swift:423-424`). While the meeting head stands:

- `updateHead(_:)` no-ops for any other category (`default: break`, line 450), and
- `preempt(_:)`/`enqueue(_:)` drop everything (`dropsWhileCallStands`, lines 385-389).

So every subsequent transition of the displaced transient is lost, while the stale copy sits in
`pending` waiting to be promoted when the call ends. Two reachable, non-recoverable outcomes:

1. **Download.** A `.downloadProgress(.inProgress)` head is displaced by a call start. The
   download finishes mid-call: `downloadCoordinator.replaceHead` calls
   `transientQueue.updateHead(.downloadProgress(.done))` (`NotchWindowController.swift:552`),
   which hits `default: break` because the head is `.meeting`. Call ends →
   `removeAll(.meeting)` promotes the stale `.inProgress` entry. `.inProgress` is
   `isPersistent`, so `scheduleActivityDismiss()` returns immediately and the frozen progress
   spinner stands **forever**. This is the same class of defect the code already fixed once
   (the `removeInProgress` "cancelling left the spinner running forever" comment at line 535).

2. **Timer / Pomodoro.** A `.timer(.running(deadline:))` head is displaced by a call start. The
   deadline elapses mid-call: `handleTimerDeadlineReached()` calls
   `transientQueue.updateHead(.timer(splash))` (no-op, head is `.meeting`) and then
   `transientQueue.preempt(.timer(next))` for the next Pomodoro segment — **dropped outright**
   by `dropsWhileCallStands`. `timerActivityState` and `timerMonitor` advance internally, so
   the queue and the session state diverge. Call ends → the stale `.timer(.running(pastDeadline))`
   is promoted, renders `00:00`, is `isRunningOrPaused` → `isPersistent` → never self-elapses,
   and never updates again because `TimerMonitor` already fired. Stuck forever.

**Fix:** The drop rule must not apply to *refreshes of an entry already in the queue*. Route
same-category updates past the guard, and reconcile `pending` instead of only the head:

```swift
// IslandResolver.swift — refresh an entry that is already queued, even while a call stands.
mutating func updateHead(_ t: ActiveTransient) {
    // ... existing head cases ...
    // NEW: if the head is .meeting but the same category sits in `pending`, refresh it there.
    if case .meeting = head, let i = pending.firstIndex(where: { sameCategory($0, t) }) {
        pending[i] = t
    }
}
```
plus, in `dropsWhileCallStands`, let a transient through when `pending` already holds an entry
of the same category (it is an update, not an interruption). Alternatively — and simpler —
have `handleMeetingActivityChange` drop the displaced persistent head instead of stashing it
(`pending` is cleared on call start), which matches the stated requirement "nothing surfaces
late once the call ends" far more literally than the current implementation does.

---

### CR-03: A queued `.meeting` can be silently evicted by the `maxDepth` overflow and never re-emitted

**File:** `Islet/Notch/IslandResolver.swift:393-400`; `Islet/Notch/MeetingMonitor.swift:194-199`
**Issue:**
When a call starts while a **non-persistent** head stands (charging splash, device splash, OSD,
caps-lock, update), `preempt` falls through to `enqueue` (`IslandResolver.swift:422`), which
appends `.meeting` to `pending`. `enqueue` then bounds the list by dropping the **oldest**
entry:

```swift
pending.append(t)
if pending.count > maxDepth { pending.removeFirst() }   // line 397-398
```

The oldest entry can be the just-queued `.meeting`. Trigger: head = charging splash,
pending = `[.meeting]`; a device connects → pending = `[.meeting, .device]`; caps-lock toggles →
pending = `[.meeting, .device, .capsLock]` → count 3 > 2 → `removeFirst()` evicts `.meeting`.

Recovery is impossible: `MeetingMonitor.evaluate()` fires `onChange` only on a nil ↔ non-nil
edge (line 196), and `lastReading` stays non-nil for the whole call, so neither the 5s poll nor
any HAL/NSWorkspace event will ever re-emit the reading. The Meeting HUD is gone for the entire
call — for a persistent, user-facing indicator this is a silent total failure, not a dropped
splash.

**Fix:** Either make `.meeting` bypass the FIFO bound (it is the highest-value persistent
entry), or drop the *newest* pending entry on overflow rather than the oldest:

```swift
mutating func enqueue(_ t: ActiveTransient) -> Bool {
    if dropsWhileCallStands(t) { return false }
    if head == nil { head = t; return true }
    if head == t || pending.contains(t) { return false }
    if pending.count >= maxDepth {
        // never evict a queued call HUD — it is fire-once and never re-emitted.
        if let i = pending.lastIndex(where: { if case .meeting = $0 { return false }; return true }) {
            pending.remove(at: i)
        } else { return false }
    }
    pending.append(t)
    return false
}
```

Add a regression test alongside `testNothingInterruptsAStandingMeetingHead` asserting that a
`.meeting` queued behind a non-persistent head survives two further enqueues.

---

## Warnings

### WR-01: `handleMuteTap()` mutates the real system mic *before* validating that a meeting head stands

**File:** `Islet/Notch/NotchWindowController.swift:2472-2475`
**Issue:** The side effect precedes the guard:

```swift
guard let newMuted = toggleSystemInputMute() else { return }   // system-wide write happens HERE
guard case .meeting(let m) = transientQueue.head else { return } // validation happens after
```

If the call ends (or the HUD is flushed by a Settings toggle) in the window between the view
rendering the icon and the tap being delivered, the machine's system-wide input mute is flipped
and the function returns without any UI update — the user has silently muted or unmuted their
microphone with zero feedback and no visible indicator to notice it by. Every other tap handler
in this file validates first.

**Fix:** Swap the order so the write is never issued without a live meeting head.

```swift
private func handleMuteTap() {
    guard case .meeting(let m) = transientQueue.head else { return }
    guard let newMuted = toggleSystemInputMute() else { return }
    transientQueue.updateHead(.meeting(MeetingActivity(callStart: m.callStart, isMuted: newMuted)))
    ...
}
```

---

### WR-02: No debounce means a transient input-device gap restarts the call timer at 00:00

**File:** `Islet/Notch/MeetingMonitor.swift:181-199`
**Issue:** `evaluate()` fires `onChange(nil)` the instant `isInputRunning()` reads false, and the
next detection creates a **new** `MeetingReading(detectedAt: Date())`, which becomes a new
`callStart`. Switching the default input device mid-call (AirPods connect — the scenario the
retarget listener exists for) produces exactly this gap: `retargetInputListener()` re-points to
the new device, `evaluate()` runs immediately, and the conferencing app has not yet re-opened a
stream on it, so `isRunningSomewhere` is false for one evaluation. Result: the HUD disappears
and reappears with the elapsed counter reset to `00:00` — the one number the HUD exists to show.

D-08's "no debounce" applies to *show* latency; a rising-edge-only debounce on the *falling*
edge keeps the immediate-show guarantee.

**Fix:** Debounce only the non-detected transition, or preserve `callStart` across a short gap:

```swift
private var lastDetectedAt: Date?   // survives a brief drop

private func evaluate() {
    let detected = isTargetAppRunning() && isInputRunning()
    guard detected != (lastReading != nil) else { return }
    if detected {
        // ponytail: reuse the previous callStart if the gap was under ~10s — a device swap,
        // not a new call.
        let start = lastDetectedAt.map { Date().timeIntervalSince($0) < 10 ? $0 : Date() } ?? Date()
        lastDetectedAt = start
        lastReading = MeetingReading(detectedAt: start)
    } else {
        lastReading = nil
    }
    onChange(lastReading)
}
```

---

### WR-03: `AudioObjectAddPropertyListenerBlock`'s OSStatus is ignored for the default-input-device listener

**File:** `Islet/Notch/MeetingMonitor.swift:84`
**Issue:** `retargetInputListener()` correctly guards its registration
(`guard AudioObjectAddPropertyListenerBlock(...) == noErr else { return }`, line 169), but the
system-object registration in `start()` discards the return value entirely. If it fails,
`listenerBlock` is still stored, `stop()` will call `Remove` on a listener that was never added
(harmless but misleading), and default-input-device changes go unnoticed until the coarse 5s
poll — with no signal anywhere that the event path is dead. The inconsistency between the two
sites is exactly the kind of asymmetry the file's own header claims to have eliminated.

**Fix:**

```swift
if AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject),
                                       &defaultInputAddr, nil, block) != noErr {
    // degraded to poll-only device re-targeting — make it visible rather than silent.
    #if DEBUG
    print("[MeetingMonitor] default-input-device listener registration failed; relying on the 5s poll")
    #endif
}
```

---

### WR-04: `stop()` does not reset `lastReading`, breaking the documented "idempotent and symmetric" contract

**File:** `Islet/Notch/MeetingMonitor.swift:114-137`
**Issue:** The header comment at lines 23-26 states `start()/stop()` are "idempotent and
symmetric". `stop()` clears `pollTimer`, both listener registrations, `workspaceObservers`,
`listenedDeviceID`, `listenerBlock` and `running` — but leaves `lastReading` non-nil. A
subsequent `start()` on the same instance calls `evaluate()`, finds `detected == (lastReading != nil)`,
and returns silently: an already-active call is never re-emitted, so the HUD never comes back.

Today the controller sidesteps this by discarding the instance
(`meetingMonitor?.stop(); meetingMonitor = nil`, `NotchWindowController.swift:2790`), so the
defect is latent — but it is one call site away from being live, and it directly contradicts the
class's own documented contract.

**Fix:** `lastReading = nil` in `stop()`. One line; restores the stated invariant.

---

### WR-05: The meeting hot-zone widen makes ~112pt of menu bar right of the notch unclickable for the whole call

**File:** `Islet/Notch/NotchWindowController.swift:1761-1765`
**Issue:** While a `.meeting` head stands, `collapsedInteractiveZone()` returns a rect extending
to `hotZone.maxX + 104`, and `syncClickThrough()` sets `panel?.ignoresMouseEvents = !pointerInZone`
(line 1947-1949) for the collapsed case. The wing's own background is an explicit no-op
(`onTap: {}`, `NotchPillView.swift:3611`), so any click in that band that is not on the 20pt mute
icon is swallowed with no effect and never reaches the menu-bar extra underneath.

Every prior widen in this function is bounded to a *transient* presentation (the ~3s secondary
bubble, the idle hover preview). Meeting is the first `isPersistent` presentation to widen the
zone, so this band is dead for the entire duration of a call — potentially hours. Menu-bar
extras commonly sit immediately right of the notch.

**Fix:** Narrow the widen to the mute icon's actual footprint instead of the full band, so the
~84pt between the notch edge and the icon stays click-through:

```swift
if case .meeting = presentationState.presentation {
    let iconFar  = hotZone.maxX + NotchPillView.meetingMuteIconTrailingEdgeOffset
    let iconNear = iconFar - NotchPillView.meetingMuteIconWidth - hotZonePadding   // add the constant
    return CGRect(x: iconNear, y: hotZone.minY, width: iconFar - iconNear, height: hotZone.height)
        .union(hotZone)   // keep the pill itself interactive
}
```
Note this changes the zone from one contiguous rect to a union — if `handlePointer`'s
enter/exit edge logic cannot tolerate the gap, the alternative is to keep the wide rect but
forward unhandled clicks (the wing background's `onTap`) instead of no-op'ing them.

---

### WR-06: `nonisolated func stop()` performs NSWorkspace and CoreAudio teardown with no thread guarantee

**File:** `Islet/Notch/MeetingMonitor.swift:114-137`
**Issue:** `stop()` is `nonisolated` specifically so a future owner's `nonisolated deinit` can
call it (line 113). In that scenario it would mutate five `nonisolated(unsafe)` stored properties
and call `NSWorkspace.shared.notificationCenter.removeObserver` and
`Timer.invalidate()` off the main thread. `Timer.invalidate()` is documented as valid only on
the thread that installed the timer, and the `nonisolated(unsafe)` annotations explicitly opt out
of the data-race checking that would otherwise catch this. Today the only callers are main-actor
(`NotchWindowController.swift:2790,3289`), so it is latent — but the annotation exists precisely
to permit the unsafe call.

**Fix:** Either drop `nonisolated` (the two real call sites are already main-actor) or make the
teardown explicitly main-thread-safe:

```swift
nonisolated func stop() {
    if Thread.isMainThread { tearDown() }
    else { DispatchQueue.main.sync { tearDown() } }
}
```

---

### WR-07: `MicMuteControllerTests` mutates the machine's real system-wide input mute with no failure-path guarantee

**File:** `IsletTests/MicMuteControllerTests.swift:24-43`
**Issue:** `testToggleSystemInputMuteNeverPartiallyAppliesAndRestores` toggles the real
system-wide microphone mute and relies on a second toggle at the end of the method to restore
it. There is no `addTeardownBlock`, so:

- a crash, a thrown error, or an early `return` on any future edit leaves the dev/CI machine's
  microphone in a state the test created;
- the restore itself is unchecked-for-success — if the second `toggleSystemInputMute()` returns
  `nil` (device disconnected between the two calls), `XCTAssertEqual(restored, original)` fails
  *and* the machine stays muted;
- the test is order-dependent with any concurrent process (Control Center, the mic-mute key)
  touching the same property, which makes it flaky rather than deterministic.

This is in scope because it affects test reliability and leaves persistent side effects on the
host.

**Fix:** Register the restore as a teardown block so it runs on every exit path:

```swift
func testToggleSystemInputMuteNeverPartiallyAppliesAndRestores() {
    let original = readSystemInputMuted()
    addTeardownBlock {
        if readSystemInputMuted() != original { _ = toggleSystemInputMute() }
    }
    ...
}
```

---

## Info

### IN-01: Redundant double main hop in the NSWorkspace observers

**File:** `Islet/Notch/MeetingMonitor.swift:91-93`
**Issue:** The observer is already registered with `queue: .main`, then the body wraps the call
in a further `DispatchQueue.main.async`. This costs an extra run-loop turn per launch/terminate
event and, more importantly, obscures the reason the *CoreAudio* hop at line 71 is genuinely
required (that one is invoked on a HAL thread; this one is not).
**Fix:** Drop the inner `DispatchQueue.main.async` and call `self?.evaluate()` directly, or drop
`queue: .main` and keep the explicit hop — pick one and comment which invariant it upholds.

### IN-02: The click-through widen is applied to the padded, width-fudged `hotZone`, not the raw cutout

**File:** `Islet/Notch/NotchWindowController.swift:1762`
**Issue:** `meetingMuteIconTrailingEdgeOffset` (104) is measured from the *unfudged* notch edge
(`meetingWings` derives its geometry from `interaction.collapsedNotchSize`, published with
`widthFudge: 0` at `NotchWindowController.swift:1323-1327`), but it is added to `hotZone.maxX`,
which already carries `widthFudge: 4` plus `hotZonePadding` (6). The zone therefore over-covers
the icon by ~8pt. The direction is safe, but the comment at line 1756-1757 claims the constant is
"derived 1:1 from NotchPillView's own render geometry", which it is not.
**Fix:** Either apply the offset to `hotZone.insetBy(dx: hotZonePadding, dy: hotZonePadding).maxX`
(the true collapsed frame) or amend the comment to state the deliberate over-cover and its size.

### IN-03: Render and click-through geometry read the notch width from two different sources

**File:** `Islet/Notch/NotchPillView.swift:3586`, `Islet/Notch/NotchWindowController.swift:1762`
**Issue:** `meetingWings` reads `interaction.collapsedNotchSize?.width ?? Self.collapsedSize.width`
(a 200pt fallback), while `collapsedInteractiveZone()` reads `hotZone` (derived from
`notchFrame`). The shared static covers only the *offset*, not the notch width itself, so the
"single source of truth" claim in both comments is partial. On any screen where `notchFrame`
resolves but `notchSize` returns nil, the wing renders against the 200pt fallback while the
click zone is sized to the real frame, and the two desync.
**Fix:** Have `meetingWings` and the hot-zone math trace to one published value, or add an
assertion that `collapsedNotchSize` is non-nil whenever `hotZone` is non-nil.

### IN-04: The mute icon has an accessibility label but no button trait or action

**File:** `Islet/Notch/NotchPillView.swift:3646-3653`
**Issue:** The tappable glyph carries `.accessibilityLabel("Mute Microphone")` but no
`.accessibilityAddTraits(.isButton)` and no `.accessibilityAction`. VoiceOver announces it as an
image, and the `.onTapGesture` is not exposed as an activatable element — the one interactive
control in the HUD is unreachable by assistive tech.
**Fix:** Add `.accessibilityAddTraits(.isButton)` and `.accessibilityAction { onMuteTap() }`
alongside the existing label.

### IN-05: Empty `deinit` leaks the timer, both observers and both CoreAudio listeners if an owner forgets `stop()`

**File:** `Islet/Notch/MeetingMonitor.swift:139-142`
**Issue:** The `deinit` is intentionally empty and relies entirely on the owner calling `stop()`.
This matches the codebase convention, but unlike the pure-Timer monitors this class holds two
CoreAudio block registrations that survive the object's deallocation and keep firing on HAL
threads (the block's `[weak self]` prevents a crash, so the leak is silent and undetectable).
**Fix:** Add a DEBUG-only assertion so a forgotten `stop()` is caught in development:

```swift
deinit {
    #if DEBUG
    assert(!running, "MeetingMonitor deallocated without stop() — CoreAudio listeners leaked")
    #endif
}
```

---

_Reviewed: 2026-07-25_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
