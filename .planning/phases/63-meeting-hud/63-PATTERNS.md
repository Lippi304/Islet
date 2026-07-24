# Phase 63: Meeting-HUD - Pattern Map

**Mapped:** 2026-07-24
**Files analyzed:** 7 (4 new, 3 modified)
**Analogs found:** 7 / 7

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|--------------------|------|-----------|-----------------|----------------|
| `Islet/Notch/MeetingActivity.swift` | model (pure value type) | transform | `Islet/Notch/TimerActivity.swift` + `Islet/Notch/DownloadActivity.swift` | exact |
| `Islet/Notch/MicMuteController.swift` | utility (system glue) | request-response (CoreAudio read/write) | `Islet/Notch/VolumeReader.swift` | exact (same file, scope swap) |
| `Islet/Notch/MeetingMonitor.swift` | service/monitor | event-driven + poll | `Islet/Notch/CapsLockMonitor.swift` (lifecycle) + `Islet/Notch/AudioOutputMonitor.swift` (listener block) | role-match (composite of two) |
| `Islet/Notch/IslandResolver.swift` (MODIFIED) | resolver (pure) | transform | itself — `ActiveTransient.isPersistent`, `resolve()` switch, `TransientQueue.preempt()` | exact (extend existing pattern) |
| `Islet/Notch/NotchPillView.swift` (MODIFIED, new `meetingWings(for:)`) | component (SwiftUI view) | request-response (tap → callback) | `updateWings(for:)` (onTap override) + `downloadWings(for:)`/`capsLockWings(for:)` (margin/leftWidth/rightWidth math) | role-match (first inline-tappable wing, no exact precedent) |
| `Islet/Notch/NotchWindowController.swift` (MODIFIED) | controller | event-driven | `startCapsLockMonitor()`/`handleCapsLockChange(_:)` + `handleSettingsChanged()`'s toggle block | exact |
| `IsletTests/IslandResolverTests.swift` (MODIFIED) | test | unit | itself — existing test file, add `.meeting` cases | exact |

## Pattern Assignments

### `Islet/Notch/MeetingActivity.swift` (NEW — model, transform)

**Analog:** `Islet/Notch/TimerActivity.swift` (full file, 101 lines) and `Islet/Notch/DownloadActivity.swift` (full file, 53 lines)

**File header convention** (`TimerActivity.swift:1-8`):
```swift
import Foundation

// Phase 62 / TIMER-01/TIMER-04 — the PURE countdown/Pomodoro value-type model (Pattern 1),
// mirroring DownloadActivity.swift's shape: plain Foundation-only types + stateless
// helpers, no AppKit/SwiftUI, no `Date()` calls inside any function (every function takes
// plain values), no state across calls. `TimerActivityState`'s stateful pause/resume/
// deadline-math (Plan 62-02) is a SEPARATE, later layer — nothing here holds state.
```
Mirror this exactly for `MeetingActivity.swift`'s header: Foundation-only, no `Date()` inside pure functions, stateful call-start tracking lives in a separate `MeetingActivityState` (mirrors `TimerActivityState`), not in this file.

**Core value type + isPersistent seam** (`TimerActivity.swift:30-44`):
```swift
enum TimerActivity: Equatable {
    case running(deadline: Date, context: TimerContext)
    case paused(remaining: TimeInterval, context: TimerContext)
    case completed
    case segmentDone(finishedPhase: TimerPhase, cycle: Int)
}

extension TimerActivity {
    // The exact seam ActiveTransient.isPersistent (Islet/Notch/IslandResolver.swift) reads.
    var isRunningOrPaused: Bool {
        switch self {
        case .running, .paused: return true
        case .completed, .segmentDone: return false
        }
    }
}
```
For `MeetingActivity`, per D-06 the case is unconditionally persistent while active (no sub-state split like Timer's running/paused vs completed) — a plain struct is sufficient:
```swift
struct MeetingActivity: Equatable {
    let callStart: Date
    let isMuted: Bool
}
```

**Pure formatting helper, mm:ss only (D-13)** (`TimerActivity.swift` — mirrors the `parseCustomDurationSeconds`/label style; exact target format already given in RESEARCH.md Pattern 1):
```swift
func meetingElapsedLabel(callStart: Date, now: Date) -> String {
    let elapsed = max(0, Int(now.timeIntervalSince(callStart)))
    return String(format: "%02d:%02d", elapsed / 60, elapsed % 60)
}
```
No h:mm:ss branch — D-13 explicitly locks plain rolling mm:ss past 59:59 (e.g. "75:32"), matching `DownloadActivity.swift`'s "one pure helper, no state" shape and Timer's own mm:ss convention.

**Raw-reading struct convention** (`DownloadActivity.swift:24-33`, mirrors `DeviceReading`):
```swift
struct DownloadReading: Equatable {
    let path: String
    let kind: DownloadEventKind
    let fileID: UInt64?
    let renamedTo: String?
}
```
`MeetingMonitor` needs an equivalent plain reading struct (e.g. `MeetingReading`, per RESEARCH.md's skeleton) so tests can construct it by hand without touching CoreAudio/NSWorkspace.

---

### `Islet/Notch/MicMuteController.swift` (NEW — utility, request-response)

**Analog:** `Islet/Notch/VolumeReader.swift` (full file, 191 lines) — near-literal copy, Output → Input scope swap only.

**Imports + header convention** (`VolumeReader.swift:1-7`):
```swift
import CoreAudio
import AudioToolbox

// Phase 39 Plan 03 / HUD-03 — thin CoreAudio glue, isolated per "one fragile system surface,
// one file" convention. Mirrors PowerSourceMonitor.readCurrentPower()'s defensive-optional-cast
// discipline: every step is guarded and a missing/malformed value never force-unwraps or
// crashes, falling back to a safe (0, false) reading instead.
```

**Device-ID resolution pattern** (`VolumeReader.swift:14-24`, `defaultOutputDeviceID()`):
```swift
private func defaultOutputDeviceID() -> AudioDeviceID? {
    var deviceID = AudioDeviceID(0)
    var deviceIDSize = UInt32(MemoryLayout<AudioDeviceID>.size)
    var outputAddr = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain)
    guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &outputAddr, 0, nil, &deviceIDSize, &deviceID) == noErr
    else { return nil }
    return deviceID
}
```
Copy verbatim, swap `kAudioHardwarePropertyDefaultOutputDevice` → `kAudioHardwarePropertyDefaultInputDevice` and rename to `defaultInputDeviceID()`.

**Guarded read pattern** (`VolumeReader.swift:26-50`, `readSystemVolume()`) — same guard-else-return-safe-default shape reused for `readSystemInputMuted()`, only reading `kAudioDevicePropertyMute` with `mScope: kAudioDevicePropertyScopeInput` instead of `.Output`. Safe default on any guard failure is `false` (never muted), matching `readSystemVolume()`'s `(0, false)` fallback discipline.

**Guarded toggle pattern** (`VolumeReader.swift:164-190`, `toggleSystemMute()`):
```swift
func toggleSystemMute() -> (percent: Int, muted: Bool)? {
    guard let deviceID = defaultOutputDeviceID() else { return nil }
    var muteAddr = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyMute,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain)
    ...
    var currentMuted: UInt32 = 0
    var mutedSize = UInt32(MemoryLayout<UInt32>.size)
    guard AudioObjectGetPropertyData(deviceID, &muteAddr, 0, nil, &mutedSize, &currentMuted) == noErr
    else { return nil }
    var newMuted: UInt32 = currentMuted == 1 ? 0 : 1
    guard AudioObjectSetPropertyData(deviceID, &muteAddr, 0, nil, mutedSize, &newMuted) == noErr
    else { return nil }
    return (Int((currentVolume * 100).rounded()), newMuted == 1)
}
```
`toggleSystemInputMute()` mirrors this exactly (scope swapped), returning `Bool?` (just the new mute state) since Meeting-HUD has no volume-percent concept on the input side — per RESEARCH.md's own `toggleSystemInputMute()` skeleton (Pattern 4), already drafted verbatim there.

**Pitfall 3 guard not yet present in `VolumeReader.swift`:** neither `readSystemVolume()` nor `toggleSystemMute()` calls `AudioObjectHasProperty` before Get/Set (they rely on the Get/Set call itself failing with non-`noErr` on an unsupported device). `MicMuteController` should follow the SAME discipline (guarded Get/Set, safe default, never force-unwrap) — no stricter pre-check is required than what `VolumeReader.swift` already does, since its existing pattern already never crashes on a missing property.

---

### `Islet/Notch/MeetingMonitor.swift` (NEW — service/monitor, event-driven + poll)

**Analog A (lifecycle skeleton):** `Islet/Notch/CapsLockMonitor.swift` (full file, 104 lines)

**Class shape + idempotent start/stop** (`CapsLockMonitor.swift:12-30, 49-56, 90-97`):
```swift
@MainActor
final class CapsLockMonitor {
    private nonisolated(unsafe) var monitorToken: Any?
    private nonisolated(unsafe) var healthCheckTimer: Timer?
    private var lastCapsLockState: Bool?
    private let onChange: (Bool) -> Void

    init(onChange: @escaping (Bool) -> Void) { self.onChange = onChange }

    func start() {
        guard monitorToken == nil else { return }
        guard Self.isAccessibilityTrusted else { armHealthCheck(); return }
        install()
    }

    nonisolated func stop() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
        if let token = monitorToken {
            NSEvent.removeMonitor(token)
            monitorToken = nil
        }
    }

    deinit {
        // Empty by design — the owning NotchWindowController's own @MainActor deinit calls stop().
    }
}
```
`MeetingMonitor` mirrors: `@MainActor final class`, `nonisolated(unsafe)` stored tokens/timer, `private let onChange: (MeetingReading?) -> Void`, idempotent `start()` guard, `nonisolated func stop()`, empty `deinit`. Dedup-against-last-state discipline (`lastCapsLockState`, `CapsLockMonitor.swift:22-27,64-67`) is directly relevant: `MeetingMonitor` should only call `onChange` on an actual on/off transition, not every poll/listener tick, mirroring `guard isOn != self.lastCapsLockState else { return }`.

**Analog B (event-driven CoreAudio listener):** `Islet/Notch/AudioOutputMonitor.swift:28-59`
```swift
func start() {
    guard !running else { return }
    running = true
    let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.onDevicesChanged(self.currentDevices())
        }
    }
    listenerBlock = block
    var devicesAddr = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain)
    AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &devicesAddr, nil, block)
    onDevicesChanged(currentDevices())   // initial snapshot without waiting for the first event
}

nonisolated func stop() {
    if let block = listenerBlock {
        var devicesAddr = AudioObjectPropertyAddress(...)
        AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &devicesAddr, nil, block)
    }
}
```
**Critical detail (already flagged in the comment at `AudioOutputMonitor.swift:32-36`):** `AudioObjectAddPropertyListenerBlock` delivers the block on a CoreAudio-internal dispatch queue, NOT main — `@MainActor` on the class does not retroactively isolate it. `MeetingMonitor`'s mic-active listener MUST hop to `DispatchQueue.main.async` before touching stored state or calling `onChange`, exactly like this block does. Retain the `listenerBlock` for teardown (same reason `AudioOutputMonitor` retains it — `AudioObjectRemovePropertyListenerBlock` requires the identical block reference).

For the `kAudioDevicePropertyDeviceIsRunningSomewhere` listener (mic-in-use signal), use `mScope: kAudioDevicePropertyScopeInput` and the resolved input `AudioDeviceID` (via a device-ID lookup mirroring `defaultInputDeviceID()` from `MicMuteController`) instead of `kAudioObjectSystemObject`/global scope — `AudioOutputMonitor`'s two listeners are both registered on the system object because they watch device-list/default-device changes; the mic-in-use property is scoped to a specific device.

**App-running half:** use `NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier.map(targetBundleIDs.contains) ?? false }` (bundle IDs per D-01, flag classic-Teams `com.microsoft.teams` as an open question already resolved per CONTEXT.md line 26 — both `us.zoom.xos`, `com.microsoft.teams2`, `com.microsoft.teams` are now locked). Combine with `NSWorkspace.didLaunchApplicationNotification`/`didTerminateApplicationNotification` for the edge-driven half, plus a coarse poll fallback per RESEARCH.md's Supporting Stack table — no existing monitor in this codebase currently does exactly this combination; RESEARCH.md's `MeetingMonitor` skeleton (Code Examples section, already drafted) is the concrete template to follow.

---

### `Islet/Notch/IslandResolver.swift` (MODIFIED — resolver, transform)

**Analog:** itself — extend the existing generalized pattern, do not touch `preempt()`.

**`isPersistent` extension point** (`IslandResolver.swift:141-153`, current live code):
```swift
extension ActiveTransient {
    var isPersistent: Bool {
        if case .focus = self { return true }
        if case .downloadProgress(.inProgress) = self { return true }
        if case .timer(let t) = self, t.isRunningOrPaused { return true }
        return false
    }
}
```
Add one line per D-06: `if case .meeting = self { return true }` — a live meeting call never self-elapses while active, same shape as `.focus`.

**New case additions:**
- `IslandPresentation` enum (`IslandResolver.swift:97-119`) — add `case meeting(MeetingActivity)` at the D-05 rank comment position (currently `.device` is rank 2, `.focus` is rank 3 — insert `.meeting` between them, shifting `.focus` and everything below down one rank, per the reserved comment at line 88).
- `ActiveTransient` enum (`IslandResolver.swift:123-132`) — add `case meeting(MeetingActivity)` in the same relative position.

**`resolve()`'s switch** (`IslandResolver.swift:183-199`) — insert between the `.device` and `.focus` cases:
```swift
case .device(let d):   return .device(d)             // D-02 rank 2
case .meeting(let m) where !isExpanded: return .meeting(m)   // NEW Phase 63 / D-05 rank 3, collapsed-only (D-10)
case .meeting: break                                  // D-10: Meeting-HUD is collapsed-only, always — confirm whether this branch is reachable or should be dropped
case .focus(let f) where !isExpanded: return .focus(f) // existing rank 3, shifts to rank 4
```

**`TransientQueue.preempt()`** (`IslandResolver.swift:386-391`) — NO changes needed:
```swift
mutating func preempt(_ t: ActiveTransient) -> Bool {
    guard let currentHead = head, currentHead.isPersistent else { return enqueue(t) }
    head = t
    pending.insert(currentHead, at: 0)
    return true
}
```
Already generalized past a hardcoded `.focus` check (Phase 62) — `isPersistent`'s new `.meeting` case flows through this unmodified, confirmed by direct read.

**`TransientQueue.updateHead(_:)`** (`IslandResolver.swift:406-416`) — if Meeting-HUD needs an in-place refresh (e.g. mute-state flip without re-arming any dismiss timer, or elapsed-time tick — though elapsed-time is likely computed at render time from `callStart`, not pushed on every tick), add `case (.meeting, .meeting): head = t` alongside the existing `(.timer, .timer)`/`(.osd, .osd)` cases.

**Priority-table doc comment** (`IslandResolver.swift:58-92`) — update the Tier 1 ranked list (line 70-73) and the "Meeting HUD (Phase 63)" reserved-slot comment (line 88) to reflect the landed rank, mirroring how Phase 60/61/62 each updated their own line in this same table once landed (see the "LANDED" annotations already present for Caps Lock/Update/Download/Timer).

---

### `Islet/Notch/NotchPillView.swift` (MODIFIED — new `meetingWings(for:)`, component)

**Analog A (margin/leftWidth/rightWidth math template):** `downloadWings(for:)` (`NotchPillView.swift:3343-3394`) and `capsLockWings(for:)` (`NotchPillView.swift:3229-3264`) — both establish the `rawNotchHalfWidth`/`margin`/`cameraBlockWidth`/`leftWidth`/`rightWidth`/assert pattern. Reuse `capsLockWings`' proven `margin: 65` if the mute icon sits beside a text-length label (mirrors the Pomodoro-vs-plain-Countdown margin split in `timerWings`, `NotchPillView.swift:3406-3426`); reuse `downloadWings`' `margin: 20` if the content is icon-only (mm:ss digits + one icon), per the on-device tuning history documented in both functions' comments (do not re-derive from scratch — follow the "Caps Lock Off"-class-vs-icon-only-class distinction those comments already establish).

**Analog B (onTap override — the exact mechanism D-09/D-10 need):** `updateWings(for:)` (`NotchPillView.swift:3300`):
```swift
return wingsShape(leftWidth: leftWidth, rightWidth: rightWidth, onTap: onUpdateTap) {
    ...
}
```
This is the ONLY existing call site passing a non-nil `onTap:` override. For Meeting-HUD, per D-10 pass an explicit **no-op** closure (`onTap: {}`), NOT `onUpdateTap`-style real action and NOT `nil` — `nil` falls through to `wingsShape`'s default `onClick` (expand-to-Home), which D-10 explicitly forbids for taps outside the mute icon.

**`wingsShape` itself** (`NotchPillView.swift:2660-2710`, full function) — the shared shape/overlay/tap-gesture wrapper every wing calls:
```swift
private func wingsShape<Content: View>(
    leftWidth: CGFloat = Self.wingsSize.width / 2,
    rightWidth: CGFloat = Self.wingsSize.width / 2,
    onTap: (() -> Void)? = nil,
    @ViewBuilder content: () -> Content
) -> some View {
    ...
    .overlay(content().frame(width: size.width, height: size.height, alignment: .leading))
    .alignmentGuide(HorizontalAlignment.center) { _ in leftWidth }
    .onTapGesture { (onTap ?? onClick)() }
}
```
Confirms: the outer gesture is `.onTapGesture` on the whole shape; the inner `content()` is composed via `.overlay(...)`, exactly the "unusual" composition RESEARCH.md's Pattern 3 / Assumption A2 flags as needing on-device verification for nested-gesture hit-test priority. No existing wing has a second, nested `.onTapGesture` inside `content()` — this is genuinely new. Add the mute icon's own `.onTapGesture` directly on its `Image`, with `.contentShape(Rectangle())` first (ensures the full icon frame — not just opaque pixels — is tappable), per RESEARCH.md's drafted example. If hit-testing doesn't prioritize the inner gesture correctly on-device, fall back to `.highPriorityGesture(TapGesture().onEnded { onMuteTap() })` (RESEARCH.md's documented fallback).

**Icon convention for a boolean-state toggle icon** (`downloadWings`, `NotchPillView.swift:3369-3386`) — `Image(systemName:)` with `.font(.system(size:weight:))`, `.symbolRenderingMode(.monochrome)` or `.hierarchical`, `.frame(width: iconWidth, height: Self.wingsSize.height, alignment: .center)` is the established per-icon frame convention to copy for the mute glyph (`mic.fill`/`mic.slash.fill` per D-12's discretion).

---

### `Islet/Notch/NotchWindowController.swift` (MODIFIED — controller, event-driven)

**Analog:** `startCapsLockMonitor()` / `handleCapsLockChange(_:)` / the `handleSettingsChanged()` toggle block — all three read directly, all three are the closest 1:1 precedent (idempotent monitor start, preempt-or-enqueue transient handler, live settings toggle wiring).

**Idempotent monitor start** (`NotchWindowController.swift:836-841`):
```swift
private func startCapsLockMonitor() {
    guard capsLockMonitor == nil else { return }
    let monitor = CapsLockMonitor { [weak self] isOn in self?.handleCapsLockChange(isOn) }
    capsLockMonitor = monitor
    monitor.start()
}
```
`startMeetingMonitor()` mirrors this exactly: `guard meetingMonitor == nil else { return }`, construct with a `targetBundleIDs` set and an `onChange` closure calling a new `handleMeetingActivityChange(_:)`.

**Transient handler (preempt-if-focus-else-enqueue shape)** (`NotchWindowController.swift:2356-2367`):
```swift
private func handleCapsLockChange(_ isOn: Bool) {
    let activity = capsLockActivity(isOn: isOn)
    let changed: Bool
    if case .focus = transientQueue.head {
        changed = transientQueue.preempt(.capsLock(activity))
    } else {
        changed = transientQueue.enqueue(.capsLock(activity))
    }
    if changed { presentTransientChange() }
}
```
Per D-05, Meeting-HUD outranks Focus/OSD/Download/CapsLock/Update/Timer (only Charging/Device outrank it) — so `handleMeetingActivityChange` should **always call `preempt(.meeting(...))`**, not the conditional `if case .focus` guard `handleCapsLockChange` uses (that guard exists because Caps Lock only needs to preempt a *persistent* Focus head specifically, not every head). Since `.meeting` is itself `isPersistent`, `preempt()`'s own generalized guard (`currentHead.isPersistent`) already does the right thing regardless of which persistent case (Focus, Download-in-progress, Timer) currently holds the head — call `transientQueue.preempt(.meeting(activity))` unconditionally when a meeting becomes active, and use `transientQueue.removeAll(where:)` (see `IslandResolver.swift:423-428`) or an equivalent "clear this transient" call when the meeting ends (D-08's immediate-hide symmetric with D-07's immediate-show — no debounce either direction).

**Live settings toggle wiring** (`NotchWindowController.swift:2677-2695`, the `handleSettingsChanged()` block for Caps Lock/Download):
```swift
if activityEnabled(ActivitySettings.capsLockKey) {
    startCapsLockMonitor()
} else if capsLockMonitor != nil {
    capsLockMonitor?.stop(); capsLockMonitor = nil
    flushTransients(.capsLock)
}
```
Add an equivalent block for `ActivitySettings.meetingHUDKey` (already defined and already in `defaultsToFalseKeys`, confirmed at `Islet/ActivitySettings.swift:39,55` — no Settings-infra changes needed, only this wiring plus the initial `if activityEnabled(...) { startCapsLockMonitor() }`-style call at launch, mirrored from line 662-667's pattern).

**Mute-tap handler:** new `handleMuteTap()` calls `MicMuteController.toggleSystemInputMute()` and updates the standing `.meeting` head's `isMuted` field via `transientQueue.updateHead(.meeting(updatedActivity))` (mirrors the `(.timer, .timer): head = t` in-place-refresh case, `IslandResolver.swift:413`) — no `presentTransientChange()` re-trigger needed since this doesn't change WHICH transient is shown, only its payload.

---

### `IsletTests/IslandResolverTests.swift` (MODIFIED — test, unit)

**Analog:** itself (existing file) — add new test functions following its established naming convention (e.g. `testMeetingRankAboveFocus`, `testMeetingIsPersistent`, `testPreemptGeneralizedForMeetingHead`, mirroring the file's own `testPreemptNowGeneralizedForDownloadProgressHead` cited in `IslandResolver.swift:385`). This file was NOT read in full this session (out of scope for pattern extraction — its existing test-naming convention is inferred from the one function name cited directly in `IslandResolver.swift`'s own comments); the planner/executor should read it directly before adding cases, per CLAUDE.md's "Analyse vor Aktion."

## Shared Patterns

### CoreAudio guarded-call discipline (safe default, never force-unwrap)
**Source:** `Islet/Notch/VolumeReader.swift` (every function in the file)
**Apply to:** `MicMuteController.swift`, and `MeetingMonitor.swift`'s mic-in-use read
```swift
guard AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &value) == noErr
else { return <safe default> }
```
Every CoreAudio call in this codebase follows this exact guard-else-safe-default shape — no force-unwraps, no crashes on a missing/malformed property (Pitfall 3 in RESEARCH.md).

### One fragile-system-surface, one file
**Source:** `Islet/Notch/CapsLockMonitor.swift`, `Islet/Notch/AudioOutputMonitor.swift`, `Islet/Notch/NowPlayingMonitor.swift`, `Islet/Notch/BluetoothMonitor.swift`
**Apply to:** `MeetingMonitor.swift` (isolates ALL NSWorkspace+CoreAudio detection risk per D-03), `MicMuteController.swift` (isolates ALL input-mute CoreAudio surface)
Each fragile OS-integration point in this codebase lives in exactly one file; if the detection heuristic or an OS API breaks, the fix is a one-file swap.

### Idempotent monitor start / owner-driven stop, `nonisolated(unsafe)` token storage
**Source:** `Islet/Notch/CapsLockMonitor.swift:12-30, 49-56, 90-97` (full lifecycle)
**Apply to:** `MeetingMonitor.swift`
```swift
@MainActor
final class SomeMonitor {
    private nonisolated(unsafe) var token: Any?
    func start() { guard token == nil else { return }; /* install */ }
    nonisolated func stop() { /* teardown, clear token */ }
    deinit { /* empty — owner's deinit calls stop() */ }
}
```

### `transientQueue.preempt()` for a persistent transient — generalized, no further resolver changes
**Source:** `Islet/Notch/IslandResolver.swift:141-153` (`isPersistent`), `:386-391` (`preempt`)
**Apply to:** `NotchWindowController.handleMeetingActivityChange(_:)`
Only ONE new line is needed in `isPersistent` (`if case .meeting = self { return true }`); `preempt()` itself is already generalized past Phase 62 and needs zero changes.

### Live settings toggle → monitor start/stop → `flushTransients`
**Source:** `Islet/Notch/NotchWindowController.swift:2677-2695` (Caps Lock / Download blocks in `handleSettingsChanged()`)
**Apply to:** the new Meeting-HUD block in `handleSettingsChanged()`
```swift
if activityEnabled(ActivitySettings.<key>) {
    start<X>Monitor()
} else if <x>Monitor != nil {
    <x>Monitor?.stop(); <x>Monitor = nil
    flushTransients(.<case>)
}
```

### `wingsShape`'s `onTap:` override for a non-default-expand wing
**Source:** `Islet/Notch/NotchPillView.swift:2660-2710` (`wingsShape`), `:3300` (`updateWings`'s call site, the only non-nil `onTap:` precedent)
**Apply to:** `meetingWings(for:)` — pass `onTap: {}` (explicit no-op per D-10), never `nil` (falls through to expand-to-Home) and never a real action at the wing level (only the nested mute-icon gesture should do anything).

## No Analog Found

None. Every file this phase touches has at least a role-match analog already living in this codebase — RESEARCH.md's own conclusion ("every piece of this feature already has a near-identical precedent") is confirmed by this pattern-mapping pass. The two genuinely novel surfaces (nested-gesture hit-testing inside `wingsShape`'s overlay composition, and the detection heuristic's real-world reliability) have no code-level analog to copy — those require the phase's own on-device spike (D-03) and on-device SwiftUI verification, not a pattern the planner can lift from elsewhere.

## Metadata

**Analog search scope:** `Islet/Notch/` (all 51 files listed), `Islet/ActivitySettings.swift`, `IsletTests/` (existence check only)
**Files scanned (read in full or targeted):** `IslandResolver.swift` (429 lines, full), `VolumeReader.swift` (191 lines, full), `CapsLockMonitor.swift` (104 lines, full), `TimerActivity.swift` (101 lines, full), `DownloadActivity.swift` (53 lines, full), `ActivitySettings.swift` (213 lines, full), `AudioOutputMonitor.swift` (lines 1-70 of 239), `NotchPillView.swift` (lines 2660-2780 and 3229-3458 of 4723, targeted), `NotchWindowController.swift` (lines 830-909, 2350-2400, 2649-2700 of 3221, targeted)
**Pattern extraction date:** 2026-07-24
