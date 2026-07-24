# Phase 63: Meeting-HUD - Research

**Researched:** 2026-07-24
**Domain:** macOS native app detection heuristics (NSWorkspace + CoreAudio) + notch-overlay resolver/wings integration
**Confidence:** MEDIUM-HIGH (architecture/integration HIGH — grounded in direct reads of live code; detection heuristic MEDIUM — community-pattern, no public API, requires the phase's own on-device spike per D-03)

## Summary

Meeting-HUD combines two independently well-understood primitives into one feature with a genuinely uncertain middle layer. The two edges are solid: (1) detecting whether Zoom/Teams is *running* via `NSWorkspace.runningApplications` bundle-ID matching is a standard, fully public API with zero risk, and (2) reading/writing the system-wide input-device mute via `AudioObjectGetPropertyData`/`AudioObjectSetPropertyData` with `kAudioDevicePropertyMute` is the exact same CoreAudio pattern this codebase already ships twice over (`VolumeReader.swift`'s output-device read/write, `AudioOutputMonitor.swift`'s device enumeration) — only the scope (`kAudioDevicePropertyScopeInput`) and target selector (`kAudioHardwarePropertyDefaultInputDevice`) change. The uncertain middle is "is a call actually active, not just the app open" — there is no public API for this on macOS, and the codebase's own locked heuristic (app running AND mic in use, via `kAudioDevicePropertyDeviceIsRunningSomewhere`) is a documented community pattern, not an Apple-sanctioned check. This is exactly what D-03's on-device spike exists to validate before the full HUD ships.

Architecturally this phase is close to pure wiring: `IslandResolver.swift`'s `ActiveTransient.isPersistent`/`TransientQueue.preempt()` generalization Phase 62 already built handles the new `.meeting` case with zero further resolver-engine changes — this phase only adds one more `if case` line to `isPersistent` and slots `.meeting` into the priority switch. The one genuinely new engineering surface is the inline-tappable mute icon (D-09/D-10): every existing collapsed wing routes its entire tap area through `wingsShape`'s single `onTapGesture(onTap ?? onClick)`, and `onClick` always expands to Home. Meeting-HUD needs the *opposite* default (tapping the wing background does nothing) with one carved-out interactive sub-region (the mute icon) — both are achievable using `wingsShape`'s already-supported `onTap:` override parameter (used today only by `updateWings`) plus a nested `.onTapGesture` directly on the icon subview, which SwiftUI hit-tests before the parent gesture.

**Primary recommendation:** Build `MeetingMonitor` (process+mic heuristic, isolated per D-03) and `MicMuteController` (shared, CoreAudio input-mute primitive mirroring `VolumeReader.swift`'s existing output-mute pattern exactly) as two new pure-glue files; wire `.meeting(MeetingActivity)` into `IslandResolver` at the reserved rank-TBD slot (between `.device` and `.focus` per D-05); override `wingsShape`'s `onTap:` to a no-op for the meeting wing and give only the mute icon its own nested tap gesture. Run the on-device detection spike (real Zoom/Teams call, mic settings-only test, other apps using mic) before finalizing MeetingMonitor's heuristic thresholds.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Call-active detection (app running + mic in use) | Native app / system glue (`MeetingMonitor`) | — | No browser/network tier exists; this is a local NSWorkspace + CoreAudio HAL query, mirrors `NowPlayingMonitor`/`BluetoothMonitor`/`CapsLockMonitor`'s existing "one fragile system surface, one file" isolation |
| System-wide mic mute read/write | Native app / system glue (`MicMuteController`) | — | CoreAudio HAL property on the default INPUT device; same tier as the existing `VolumeReader.swift` output-mute primitive, just a different device/scope |
| Call-timer elapsed-time computation | Pure app state (`MeetingActivity`/`MeetingActivityState`, Foundation-only) | — | Mirrors `TimerActivity.swift`/`DownloadActivity.swift`'s "Pattern 1" pure value-type + stateless-helper convention — no Date() calls inside pure functions, deadline math lives in a separate stateful layer |
| Presentation priority / preemption | `IslandResolver.swift` (pure resolver) | `NotchWindowController` (owns `TransientQueue`/`ActiveTransient` state across time) | Same split every other activity in this codebase already uses; Phase 62 already generalized the exact mechanism Meeting-HUD needs (`isPersistent`/`preempt()`) |
| Collapsed wing rendering + inline mute tap target | SwiftUI (`NotchPillView.swift`) | `NotchWindowController` (click-through hot-zone gating) | Rendering + hit-testing-within-the-zone is SwiftUI's job; the controller's `hotZone`/`collapsedInteractiveZone()` only gates whether the OS panel accepts mouse events over that screen region at all — it does not itself distinguish "tap the icon" from "tap elsewhere" |
| Settings toggle (Live-Activity card) | SwiftUI (`SettingsView.swift`) + `ActivitySettings` (`@AppStorage`) | — | `meetingHUDKey` already exists in `ActivitySettings.swift` (Phase 59), already in `defaultsToFalseKeys` — no new Settings infra needed, only wiring |

## User Constraints (from CONTEXT.md)

<user_constraints>

### Locked Decisions

**Detection (locked by prior research, not re-asked)**
- D-01: Detection heuristic = target app running (`NSWorkspace.runningApplications`, bundle IDs `us.zoom.xos` / `com.microsoft.teams2`) AND microphone in use (`kAudioDevicePropertyDeviceIsRunningSomewhere` on the default input device, CoreAudio `AudioHardware.h`).
- D-02: Mute mechanism = system-wide hardware mute via `AudioObjectSetPropertyData` with `kAudioDevicePropertyMute` on the input device, NOT any Zoom/Teams-specific API.
- D-03: Detection risk isolated behind one `MeetingMonitor` file with an on-device spike + documented go/no-go before the full HUD is built.
- D-04: Mute action shares a new `MicMuteController` with the future Quick Actions bar (Phase 65) — build the CoreAudio mute primitive once, invoke from both call sites.

**Priority rank**
- D-05: Meeting-HUD is high priority in `IslandResolver`/`TransientQueue` — preempts Focus, OSD, Download-Progress, Caps Lock, Update-Available, and Timer. Only Charging and Device outrank it. New rank slot lands directly after `.device`, before `.focus`.
- D-06: Meeting-HUD is a persistent transient (`isPersistent == true` while the call is active) — reuses Phase 62's generalized `ActiveTransient.isPersistent`/`TransientQueue.preempt()` path.

**Trigger sensitivity**
- D-07: Show trigger is immediate — no debounce/grace period. False-positive risk (e.g. testing mic in Zoom's own settings before joining) accepted as a known tradeoff, not a target for the spike to "fix" unless on-device testing shows it's actually disruptive.
- D-08: Hide/dismiss trigger is immediate, symmetric with D-07 — no lingering dismiss window.

**Collapsed interaction**
- D-09: The mute control is directly tappable inline on the collapsed HUD — no expand-then-tap step. First collapsed HUD with an actual tap target embedded in it. Planning/research must scope the collapsed hot-zone widening needed to cover just the mute icon's tap area.
- D-10: Meeting-HUD is collapsed-only, always — no `.meetingExpanded` presentation case. Tapping anywhere on the HUD other than the mute icon does nothing.

**Visual design**
- D-11 (Claude's discretion): Call-active icon (camera vs. phone vs. other SF Symbol) — pick during UI-spec.
- D-12 (Claude's discretion): Mute-button visual state (icon swap only vs. icon swap + red-when-muted color signal) — pick during UI-spec.
- D-13: Timer format is plain mm:ss always, rolling past 59:59 for calls over an hour (e.g. "75:32") — explicitly NOT switching to h:mm:ss.

### Claude's Discretion
- Exact SF Symbol for the call-active icon (D-11).
- Exact mute-button visual treatment — icon-only vs. icon+color (D-12).
- Spike methodology/tooling for validating the detection heuristic on real hardware, and the specific go/no-go criteria.
- Exact mechanism for generalizing `ActiveTransient.isPersistent`'s case-matching to include the new `.meeting` case (already-generalized per Phase 62, this is just wiring in the new case).

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope. (True in-app mute reflection and Google Meet support were already out-of-scope items from REQUIREMENTS.md, not new deferrals from this discussion.)

</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| MEET-01 | While Zoom or Teams (native app) is running AND the microphone is active, the notch shows a call-timer HUD (elapsed mm:ss) | Detection heuristic (§Standard Stack, §Architecture Patterns Pattern 1), spike protocol (§Common Pitfalls Pitfall 1), `IslandResolver` wiring (§Architecture Patterns Pattern 2) |
| MEET-02 | Tapping the Meeting-HUD's mute control toggles the system-wide microphone mute (not the in-app mute state) via a shared `MicMuteController` | `MicMuteController` design mirroring `VolumeReader.swift` (§Code Examples), inline-tap wing pattern (§Architecture Patterns Pattern 3) |
| MEET-03 | Google Meet (browser-based) is explicitly not detected in v1.10 — documented as a known limitation, not silently missing | §Common Pitfalls Pitfall 5, §Known Constraints (inline below) |

</phase_requirements>

## Project Constraints (from CLAUDE.md)

- **Analyse vor Aktion**: read the full affected file before any Edit/Write, even for seemingly simple changes — applies directly to `IslandResolver.swift`, `NotchPillView.swift`, `NotchWindowController.swift`, all of which are large, heavily-commented files with load-bearing precedent this phase must not silently break.
- **Keine Abkürzungen**: no shortcuts on the detection spike — D-03's go/no-go must be genuinely run on real hardware, not assumed from research alone.
- **Parallelarbeit**: independent research/investigation should run in parallel where possible (already applied in this research pass).
- **Kommunikationsstil**: short, precise answers; no unnecessary summarizing; German if the user writes German; no emojis unless requested.
- **GSD Workflow**: this phase must go through discuss-phase (done) → plan-phase (this research feeds it) → execute-phase → verify-work, in that order.
- **Code-Qualität**: change only what's needed; no speculative abstractions (e.g. do not build `MicMuteController` more generically than Meeting-HUD + Quick Actions Phase 65 needs); no unnecessary comments/docstrings in unrelated code; security-first (no injection vectors — not directly applicable here since no shell/AppleScript is used, only CoreAudio HAL calls).

## Standard Stack

### Core

| API | Source | Purpose | Why Standard |
|-----|--------|---------|---------------|
| `NSWorkspace.shared.runningApplications` | AppKit (public) | Detect whether Zoom/Teams process is running, by `bundleIdentifier` | Already used elsewhere in this codebase (`AppDelegate.swift:63`, `NowPlayingMonitor.swift`) for exactly this "is X running" check pattern; zero permission required, zero risk |
| `AudioObjectGetPropertyData`/`kAudioDevicePropertyDeviceIsRunningSomewhere` | CoreAudio `AudioHardware.h` (public) | Read whether ANY app currently has the default input device active (mic in use) | [CITED: Apple Developer Forums thread 741026, cited in `.planning/research/FEATURES.md`] — documented HAL property; standard technique used by community "is mic in use" indicator apps |
| `AudioObjectGetPropertyData`/`kAudioDevicePropertyMute` scope `kAudioDevicePropertyScopeInput` | CoreAudio `AudioHardware.h` (public) | Read current system input mute state | [VERIFIED: codebase] — same selector already used for OUTPUT scope in `Islet/Notch/VolumeReader.swift:42-49`; only the scope and target device change |
| `AudioObjectSetPropertyData`/`kAudioDevicePropertyMute` scope `kAudioDevicePropertyScopeInput` | CoreAudio `AudioHardware.h` (public) | Toggle system input mute | [VERIFIED: codebase] — same selector already used for OUTPUT scope in `VolumeReader.swift:164-190` (`toggleSystemMute()`) |
| `kAudioHardwarePropertyDefaultInputDevice` | CoreAudio `AudioHardware.h` (public) | Resolve the current default INPUT `AudioDeviceID` (the target of every mute/mic-in-use call above) | [VERIFIED: codebase] — `VolumeReader.swift:14-24`'s `defaultOutputDeviceID()` is the exact structural template, just swap the selector from `...DefaultOutputDevice` to `...DefaultInputDevice` |

No new SPM/third-party dependencies — every API above is a public Apple framework already linked (`CoreAudio`, `AudioToolbox`, `AppKit`), matching the milestone's "zero new third-party dependencies" finding in `.planning/research/SUMMARY.md`.

### Supporting

| API | Purpose | When to Use |
|-----|---------|-------------|
| `DispatchSourceTimer` (via a new `MeetingMonitor`-owned lightweight poll, or CoreAudio property-listener callbacks) | Re-check "is Zoom/Teams running" + "is mic in use" on a cadence | Process-running is not event-driven (no NSWorkspace launch/quit notification is guaranteed to fire promptly for every app-quit path); mic-in-use CAN be event-driven via `AudioObjectAddPropertyListenerBlock` on `kAudioDevicePropertyDeviceIsRunningSomewhere` (mirrors `AudioOutputMonitor.swift`'s existing block-listener pattern) — combine an event-driven mic listener with a coarse (few-second) poll for app-running state, not a tight timer for both signals |
| `NSWorkspace.didLaunchApplicationNotification` / `didTerminateApplicationNotification` | Event-driven app-running edge detection | Prefer this over polling for the "app launched/quit" edge specifically — reduces reliance on a poll loop for at least one half of the AND condition; still needs the mic-active signal to actually fire the HUD |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `NSWorkspace.runningApplications` bundle-ID check | `CGWindowListCopyWindowInfo` window-title matching (e.g. "Zoom Meeting") | Explicitly rejected by prior research (`PITFALLS.md` Pitfall 1) — window titles are unversioned UI strings that change silently across app updates; process-running is the stable half of the signal, window-title matching would be the fragile half and isn't needed given the mic-active AND condition already narrows false positives |
| `kAudioDevicePropertyDeviceIsRunningSomewhere` | Polling `AVCaptureDevice` authorization/active state | `AVCaptureDevice` requires the app to itself be an active capture session participant or hold Camera/Mic TCC authorization to observe reliably; the CoreAudio HAL property is a system-wide observation that works without the observing app itself opening any audio session — the correct, lower-privilege choice here |
| Building `MicMuteController` as Meeting-HUD-only | Building it now shared with Quick Actions (Phase 65) from day one | Locked by D-04 — build once, used by both; do not defer the shared shape to Phase 65 and then have to refactor Meeting-HUD's own mute call site later |

**Installation:** No new packages. All APIs ship with `CoreAudio`/`AudioToolbox`/`AppKit`, already imported elsewhere in this codebase.

**Version verification:** Not applicable — no versioned dependency, only Apple system frameworks already linked in the project (see `Islet/Notch/VolumeReader.swift`'s existing `import CoreAudio` / `import AudioToolbox`).

## Package Legitimacy Audit

Not applicable — this phase installs zero external packages (no SPM dependency, no CLI tool, no pip/npm/cargo package). All APIs used are Apple system frameworks already linked in the Xcode project (`CoreAudio`, `AudioToolbox`, `AppKit`). The Package Legitimacy Gate protocol is skipped per its own scope ("Every phase that installs external packages...").

## Architecture Patterns

### System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│  System (macOS)                                                      │
│  ┌──────────────┐        ┌──────────────────────────┐                │
│  │ NSWorkspace  │        │ CoreAudio HAL             │                │
│  │ .running     │        │  - kAudioDevicePropertyDeviceIsRunning-   │
│  │  Applications│        │    Somewhere (input device, read)          │
│  │ (bundle IDs) │        │  - kAudioDevicePropertyMute                │
│  └──────┬───────┘        │    (input device, read+write)              │
│         │                └──────────┬───────────────┬────────────────┘
│         │                           │               │
│         ▼                           ▼               │
│  ┌──────────────────────────────────────────┐        │
│  │  MeetingMonitor (new, @MainActor)         │        │
│  │  poll/listen: appRunning AND micInUse     │        │
│  │  -> onChange(MeetingActivity?)            │        │
│  └──────────────────┬─────────────────────────┘        │
│                      │ (raw signal)                     │
│                      ▼                                  │
│  ┌──────────────────────────────────────────┐          │
│  │  MeetingActivityState (new, pure/Foundation)│        │
│  │  computes elapsed mm:ss from call-start Date│        │
│  └──────────────────┬─────────────────────────┘        │
│                      │ MeetingActivity                  │
│                      ▼                                  │
│  ┌──────────────────────────────────────────┐          │
│  │  IslandResolver.swift                     │          │
│  │  - ActiveTransient.meeting(MeetingActivity)│          │
│  │  - isPersistent: true while call active    │          │
│  │  - TransientQueue.preempt() (Phase 62      │          │
│  │    generalization, reused unmodified)      │          │
│  └──────────────────┬─────────────────────────┘          │
│                      │ IslandPresentation.meeting(...)    │
│                      ▼                                    │
│  ┌──────────────────────────────────────────┐            │
│  │  NotchPillView.meetingWings(for:)          │            │
│  │  - elapsed mm:ss text                      │            │
│  │  - mute icon: nested .onTapGesture          │◄──────┐   │
│  │    (calls onMuteTap, does NOT call onClick) │       │   │
│  │  - background: wingsShape(onTap: {}) (no-op)│       │   │
│  └──────────────────┬─────────────────────────┘        │   │
│                      │ user taps mute icon              │   │
│                      ▼                                  │   │
│  ┌──────────────────────────────────────────┐           │   │
│  │  MicMuteController (new, shared)          │───────────┘   │
│  │  toggleInputMute() -> writes              │                │
│  │  kAudioDevicePropertyMute (input, write)  │────────────────┘
│  └────────────────────────────────────────────┘
└─────────────────────────────────────────────────────────────────────┘
```

A reader traces the primary use case left-to-right/top-to-bottom: system signals (NSWorkspace + CoreAudio) feed `MeetingMonitor`, which produces a raw on/off + call-start signal; `MeetingActivityState` turns that into a displayable `MeetingActivity` (elapsed time); `IslandResolver` decides whether/how it's shown given everything else competing for the notch; `NotchPillView` renders it with exactly one interactive sub-region (the mute icon), which calls back into the shared `MicMuteController` — closing the loop by writing the same CoreAudio property `MeetingMonitor` could theoretically also observe (note: `MeetingMonitor`'s own detection heuristic does NOT depend on mute state, only on `...IsRunningSomewhere`, so muting/unmuting during a call does not affect call detection — worth confirming explicitly during the spike).

### Recommended Project Structure

```
Islet/Notch/
├── MeetingActivity.swift        # NEW — Pattern 1: pure value types (MeetingActivity enum,
│                                 #   raw MeetingReading struct) + stateless helpers
│                                 #   (elapsed-time formatting, mirrors TimerActivity.swift/
│                                 #   DownloadActivity.swift's shape)
├── MeetingActivityState.swift   # NEW — Pattern 2: @Published stateful holder (call-start
│                                 #   Date, elapsed-time tick), mirrors ChargingActivityState/
│                                 #   TimerActivityState's shape
├── MeetingMonitor.swift          # NEW — the ONLY file touching NSWorkspace-for-Zoom/Teams +
│                                 #   the mic-active CoreAudio listener; isolates ALL detection
│                                 #   risk per D-03 (mirrors NowPlayingMonitor/BluetoothMonitor/
│                                 #   CapsLockMonitor's "one fragile surface, one file" rule)
├── MicMuteController.swift       # NEW — shared CoreAudio input-mute primitive (D-04); the
│                                 #   ONLY file with kAudioDevicePropertyMute on scope Input;
│                                 #   mirrors VolumeReader.swift's exact function shapes but
│                                 #   targets the default INPUT device instead of output
├── IslandResolver.swift          # MODIFIED — new .meeting(MeetingActivity) case in both
│                                 #   IslandPresentation and ActiveTransient; isPersistent
│                                 #   extended one more `if case`; resolve()'s switch gets one
│                                 #   more collapsed-only branch at the D-05 rank slot
├── NotchPillView.swift           # MODIFIED — new meetingWings(for:) function (mirrors
│                                 #   downloadWings/timerWings' margin/leftWidth/rightWidth
│                                 #   pattern), wingsShape(onTap: {}) override + nested tap
│                                 #   gesture on the mute icon subview
└── NotchWindowController.swift   # MODIFIED — startMeetingMonitor() (mirrors
                                  #   startCapsLockMonitor()/startDownloadMonitor()'s exact
                                  #   idempotent-guard shape), handleMeetingActivityChange(),
                                  #   handleMuteTap() wired to MicMuteController
```

### Pattern 1: Pure value-type activity model (mirrors `TimerActivity.swift`/`DownloadActivity.swift`)

**What:** `MeetingActivity` is a plain `Equatable` enum/struct carrying only the data needed to render (elapsed time or a deadline-equivalent), with zero `Date()` calls inside any pure function — mirrors this codebase's established "Pattern 1" convention verbatim.
**When to use:** Every new activity type in this codebase (Charging, Device, Timer, Download all follow this).
**Example:**
```swift
// Source: mirrors Islet/Notch/TimerActivity.swift and DownloadActivity.swift structure (existing codebase pattern)
struct MeetingActivity: Equatable {
    let callStart: Date       // when the call was first detected
    let isMuted: Bool         // current system input mute state, read from MicMuteController
}

// Pure helper — same mm:ss-only convention Timer/CalendarCountdown already use (D-13: no
// h:mm:ss branch even past 59:59, rolling minutes instead, e.g. "75:32").
func meetingElapsedLabel(callStart: Date, now: Date) -> String {
    let elapsed = max(0, Int(now.timeIntervalSince(callStart)))
    return String(format: "%02d:%02d", elapsed / 60, elapsed % 60)
}
```

### Pattern 2: `ActiveTransient.isPersistent` + `TransientQueue.preempt()` — the exact reuse point (D-06)

**What:** Phase 62 already generalized `isPersistent` from a single hardcoded `.focus` check to a pattern-matched set of cases, and `preempt()` from a single hardcoded `.focus`-only guard to `currentHead.isPersistent` (any persistent case). Meeting-HUD needs ZERO changes to `preempt()` itself — only a new `if case` line in `isPersistent`.
**When to use:** This exact spot, `IslandResolver.swift:141-153`.
**Example:**
```swift
// Source: Islet/Notch/IslandResolver.swift:141-153 (current code, read directly)
extension ActiveTransient {
    var isPersistent: Bool {
        if case .focus = self { return true }
        if case .downloadProgress(.inProgress) = self { return true }
        if case .timer(let t) = self, t.isRunningOrPaused { return true }
        // NEW for Phase 63 (D-06): a live meeting call never self-elapses while active.
        if case .meeting = self { return true }
        return false
    }
}
```
The `preempt()` function at `IslandResolver.swift:386-391` needs NO changes — its `guard let currentHead = head, currentHead.isPersistent else { return enqueue(t) }` already checks the generalized property, not a hardcoded case list.

### Pattern 3: `wingsShape`'s `onTap:` override + nested tap gesture — the inline-tappable mute control (D-09/D-10)

**What:** `wingsShape<Content: View>(leftWidth:rightWidth:onTap:content:)` (`NotchPillView.swift:2660-2707`) already supports an optional `onTap` override (used today only by `updateWings` to trigger Sparkle's install flow instead of the universal expand-to-Home). Meeting-HUD needs this override set to a no-op closure (D-10: "tapping anywhere on the HUD other than the mute icon does nothing" — explicitly NOT nil, which would fall through to the universal `onClick` expand-to-Home every other wing uses), plus a second, INNER `.onTapGesture` directly on the mute icon `Image` — SwiftUI hit-tests the deepest view under the pointer first, so a tap landing on the icon's frame is consumed there and never reaches the outer `wingsShape`-level gesture.
**When to use:** `meetingWings(for:)`, the new function this phase adds.
**Example:**
```swift
// Source: pattern derived from wingsShape's existing onTap: parameter
// (Islet/Notch/NotchPillView.swift:2660-2707) and updateWings' existing non-nil-override
// call site (:3276) — both read directly from the live codebase.
private func meetingWings(for activity: MeetingActivity, onMuteTap: @escaping () -> Void) -> some View {
    // ... leftWidth/rightWidth math mirrors downloadWings/timerWings exactly (§Common Pitfalls
    // notes the margin-tuning history to reuse, not re-derive from scratch) ...
    return wingsShape(leftWidth: leftWidth, rightWidth: rightWidth, onTap: {}) {  // D-10: no-op, NOT nil
        HStack(spacing: 0) {
            // ... call icon + mm:ss label (non-interactive) ...
            Image(systemName: activity.isMuted ? "mic.slash.fill" : "mic.fill")
                .frame(width: iconWidth, height: Self.wingsSize.height, alignment: .center)
                .contentShape(Rectangle())          // ensures the WHOLE icon frame is tappable, not just opaque pixels
                .onTapGesture { onMuteTap() }        // D-09: consumed here, never bubbles to wingsShape's onTap
        }
    }
}
```
**Verify during planning/spike:** confirm on-device that SwiftUI's nested-gesture hit-test priority behaves as expected inside this specific view chain (`wingsShape`'s `.overlay(content())` + `.onTapGesture` combination is unusual — most SwiftUI gesture-priority guidance assumes a plain view tree, not an overlay-wrapped shape). If the nested gesture does NOT reliably win, the fallback is `.highPriorityGesture(TapGesture().onEnded { onMuteTap() })` on the icon instead of plain `.onTapGesture`.

### Pattern 4: `MicMuteController` mirrors `VolumeReader.swift`'s existing shape exactly, swapped to input scope

**What:** `VolumeReader.swift` already has the complete guarded-Get/Set/never-force-unwrap pattern for `kAudioDevicePropertyMute`, just scoped to `kAudioDevicePropertyScopeOutput` and `kAudioHardwarePropertyDefaultOutputDevice`. `MicMuteController` is a near-literal copy with those two identifiers swapped to their Input equivalents.
**When to use:** `MicMuteController.swift`, new file.
**Example:**
```swift
// Source: adapted from Islet/Notch/VolumeReader.swift:14-24 and :164-190 (toggleSystemMute()),
// read directly from the live codebase — same guarded-call discipline, safe default never
// force-unwraps, scope swapped Output -> Input throughout.
import CoreAudio
import AudioToolbox

private func defaultInputDeviceID() -> AudioDeviceID? {
    var deviceID = AudioDeviceID(0)
    var deviceIDSize = UInt32(MemoryLayout<AudioDeviceID>.size)
    var inputAddr = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultInputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain)
    guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &inputAddr, 0, nil, &deviceIDSize, &deviceID) == noErr
    else { return nil }
    return deviceID
}

func readSystemInputMuted() -> Bool {
    guard let deviceID = defaultInputDeviceID() else { return false }
    var muted: UInt32 = 0
    var mutedSize = UInt32(MemoryLayout<UInt32>.size)
    var muteAddr = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyMute,
        mScope: kAudioDevicePropertyScopeInput,   // <-- the one scope change vs. VolumeReader
        mElement: kAudioObjectPropertyElementMain)
    guard AudioObjectGetPropertyData(deviceID, &muteAddr, 0, nil, &mutedSize, &muted) == noErr
    else { return false }
    return muted == 1
}

func toggleSystemInputMute() -> Bool? {
    guard let deviceID = defaultInputDeviceID() else { return nil }
    var muteAddr = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyMute,
        mScope: kAudioDevicePropertyScopeInput,
        mElement: kAudioObjectPropertyElementMain)
    var currentMuted: UInt32 = 0
    var mutedSize = UInt32(MemoryLayout<UInt32>.size)
    guard AudioObjectGetPropertyData(deviceID, &muteAddr, 0, nil, &mutedSize, &currentMuted) == noErr
    else { return nil }
    var newMuted: UInt32 = currentMuted == 1 ? 0 : 1
    guard AudioObjectSetPropertyData(deviceID, &muteAddr, 0, nil, mutedSize, &newMuted) == noErr
    else { return nil }
    return newMuted == 1
}
```

### Anti-Patterns to Avoid

- **Detecting the in-app Zoom/Teams mute state:** explicitly out of scope (REQUIREMENTS.md, locked). Do not attempt Accessibility/window-scraping to read Zoom's own mute button state — no reliable technique exists, and it would violate D-02's explicit "not any Zoom/Teams-specific API" mandate.
- **Polling both signals on the same tight timer:** mic-in-use has a real event-driven CoreAudio listener API (`AudioObjectAddPropertyListenerBlock` on `kAudioDevicePropertyDeviceIsRunningSomewhere`, exactly like `AudioOutputMonitor.swift` already does for device-list changes) — use it, don't poll it. Only the "is the app process still running" half needs any polling/notification fallback, and `NSWorkspace`'s launch/terminate notifications cover most of that for free.
- **Letting the mute tap bubble to `onClick`:** if `wingsShape`'s `onTap:` is left at its default `nil`, tapping ANYWHERE on the meeting wing — including the mute icon, before the inner gesture is even wired — will expand to Home per every other wing's existing behavior. The no-op override must be explicit, not assumed.
- **Building `MicMuteController` more broadly than needed:** per Ponytail/CLAUDE.md discipline, only build read + toggle for the input device's mute property — do not add volume read/write, device enumeration, or other CoreAudio surface `MicMuteController` doesn't need; `AudioOutputMonitor.swift`/`VolumeReader.swift` already own those for the output side and Meeting-HUD/Quick Actions have no output-side need.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|--------------|-----|
| System-wide mic mute toggle | A custom AppleScript/`osascript` shell-out, or an Accessibility-based UI click on Zoom's own mute button | CoreAudio `AudioObjectSetPropertyData`/`kAudioDevicePropertyMute` (input scope) | Documented public HAL property, already proven in this exact codebase for output; AppleScript/Accessibility routes are strictly more fragile and were explicitly rejected by prior research for the in-app-mute case (no dictionary support exists) |
| "Is Zoom in a call" detection | Custom window-title OCR/scraping, private Zoom SDK integration | The locked D-01 heuristic (process running AND mic active) | No public API exists for true call-state; the community-pattern proxy signal is the best available approach, already researched and locked — do not attempt a "smarter" detection this phase wasn't scoped for |
| Elapsed-time formatting | A custom Date/Calendar-component formatter | Plain integer div/mod on `TimeInterval`, matching `Timer`/`CalendarCountdown`'s existing mm:ss convention (D-13) | This codebase already has this exact pattern proven twice (Timer, CalendarCountdown) — reuse the shape, don't reinvent |

**Key insight:** every piece of this feature already has a near-identical precedent living in this exact codebase (output-mute → input-mute, TimerActivity/DownloadActivity → MeetingActivity, CapsLockMonitor/AudioOutputMonitor → MeetingMonitor). The only genuinely novel work is (a) the detection heuristic's real-world reliability, which requires the spike, and (b) the inline-tappable wing region, which requires careful nested-gesture verification on-device.

## Runtime State Inventory

Not applicable — Phase 63 is a greenfield feature addition (new files + new resolver case), not a rename/refactor/migration. No stored data, live service config, OS-registered state, secret/env-var renames, or stale build artifacts are implicated.

## Common Pitfalls

### Pitfall 1: The detection heuristic's false-positive/false-negative surface is wider than "app open + mic on"

**What goes wrong:** The locked D-01 heuristic (`app running AND mic in use`) will false-positive whenever the mic is active for ANY reason while Zoom/Teams happens to also be running — testing mic settings inside Zoom before joining a call (explicitly flagged as an accepted tradeoff by D-07), a totally unrelated app (Voice Memos, a dictation session, another video-call app) using the mic while Zoom/Teams is merely open in the background, or Zoom/Teams running with a *different* window (e.g. the chat/contacts view) while some other process independently uses the mic. It will false-negative if a user is in a real call but on a Bluetooth mic where `kAudioDevicePropertyDeviceIsRunningSomewhere` behaves differently (per `.planning/research/FEATURES.md`'s own note that this property's reliability on Bluetooth mics is less confirmed than on built-in/wired).

**Why it happens:** There is no public API that distinguishes "this app is in an active call" from "this app happens to be running while something touches the mic" — the AND condition narrows the false-positive surface from "any app running" to "this specific pair of conditions," but does not eliminate it, and D-07 explicitly accepts this rather than requiring a debounce fix.

**How to avoid:** Run D-03's spike against the actual accepted-risk scenarios, not just the happy path: (1) real Zoom call with mic on — must show; (2) Zoom running, no call, mic tested in Zoom's own audio settings — will show per D-07's accepted tradeoff, confirm this is genuinely what happens and document it; (3) Zoom running, mic used by an unrelated app (e.g. Voice Memos) — will also show per the same heuristic, confirm and document as a known limitation rather than something to "fix" this phase; (4) Teams running via each of the two possible bundle IDs (see Pitfall 4 below) with mic active — must show for both if both are supported.

**Warning signs:** A plan that treats D-01's heuristic as if it were 100% accurate rather than a documented best-effort proxy; missing explicit go/no-go documentation from the spike; no on-device test of the Zoom-settings-mic-test false-positive case D-07 already anticipates.

### Pitfall 2: `kAudioDevicePropertyDeviceIsRunningSomewhere` TCC-permission status is unverified for this project

**What goes wrong:** [ASSUMED — see Assumptions Log] Reading device-property state and toggling mute via CoreAudio HAL calls is widely believed NOT to require the Microphone privacy (TCC) permission — this project's own `VolumeReader.swift` already reads/writes `kAudioDevicePropertyMute` (output scope) today with zero `NSMicrophoneUsageDescription` in the project and zero microphone entitlement declared (`Islet.entitlements` confirmed to have none). However, this has not been independently re-verified for the INPUT-scope case specifically in this session — a plausible but unconfirmed risk is that the very FIRST HAL call touching the input device (even a pure property read) could itself trigger a TCC microphone prompt on some macOS version, which would be a surprising and disruptive UX moment if it isn't anticipated (an unprompted permission dialog appearing the instant Zoom opens, from a non-activating panel that can't easily surface it — mirrors the exact class of problem `PITFALLS.md` Pitfall 8 already flags for Quick Actions' AppleScript targets).

**Why it happens:** Apple's TCC boundary is drawn around actually *capturing* audio (opening an `AVCaptureSession`/tap), not around querying HAL device properties — but this project has never made an INPUT-scope CoreAudio call before, only OUTPUT-scope, so there is no direct precedent inside this codebase confirming input-scope behaves identically.

**How to avoid:** Confirm during D-03's on-device spike, as an explicit checklist item: run `MicMuteController`'s read/write calls on a machine where Islet has never been granted Microphone access, and confirm NO system permission prompt appears. If one does appear, this becomes a go/no-go blocker requiring either an `NSMicrophoneUsageDescription` + a first-use permission flow (mirroring the existing `focusPermissionStatusHint`/`osdPermissionStatusHint` pattern in `ActivitySettings.swift`) or a scope re-think.

**Warning signs:** Any implementation plan that adds `MicMuteController` without an explicit on-device "confirm no TCC prompt fires" checklist item.

### Pitfall 3: `kAudioDevicePropertyMute` may not exist on every input device (some Bluetooth mics)

**What goes wrong:** Not every input device implements `kAudioDevicePropertyMute` (mirrors `AudioOutputMonitor.swift`'s own Pitfall-7-documented discipline of never claiming volume support without an `AudioObjectHasProperty` guard first, on the output side). A blind `AudioObjectSetPropertyData` call on an input device that lacks this property will fail (`noErr` guard already prevents a crash per the existing discipline) but may silently no-op the mute toggle with no user-visible feedback if the failure isn't surfaced.

**How to avoid:** Guard every `MicMuteController` call with `AudioObjectHasProperty` before attempting Get/Set, exactly mirroring `AudioOutputMonitor.hasVolumeControl(deviceUID:)`'s existing pattern; if unsupported, the mute icon should reflect a disabled/unavailable state rather than silently doing nothing on tap (same "prefer showing nothing/disabled over confidently-wrong state" convention `PITFALLS.md`'s UX Pitfalls table already establishes for this milestone).

**Warning signs:** No `AudioObjectHasProperty` guard anywhere in `MicMuteController`; a mute tap that produces no visible change and no error state.

### Pitfall 4: D-01's locked bundle-ID list may miss classic Microsoft Teams

**What goes wrong:** D-01 locks `com.microsoft.teams2` as the Teams bundle ID. [CITED: web research this session] Microsoft ships TWO distinct, currently-coexisting Teams bundle IDs: `com.microsoft.teams2` ("new Teams", process name `MSTeams`) and `com.microsoft.teams` ("Teams classic", the older Electron-based app, process name `Teams`) — both remain in active use, and which one a given user has installed depends on their organization's rollout timing. A user still on Teams classic would never trigger Meeting-HUD at all, appearing as a silent total feature failure for that user, not a narrow edge case.

**Why it happens:** D-01 was locked from `.planning/research/FEATURES.md`'s prior research pass, which only cited the new-Teams bundle ID; the classic-Teams bundle ID coexistence wasn't surfaced at that time.

**How to avoid:** This is a locked decision (D-01) — per this agent's scope, do not silently override it. Flag explicitly (see Open Questions below) for the user/planner to confirm whether `com.microsoft.teams` (classic) should be added to the detection list alongside `com.microsoft.teams2`. Given both are one-line additions to the same `NSWorkspace.runningApplications` filter, this is low-cost to include defensively even if classic Teams is rare among this project's actual user base — but it is a genuine decision, not implicitly Claude's to make unilaterally since D-01 is explicitly locked, not marked Claude's Discretion.

**Warning signs:** MeetingMonitor's bundle-ID array contains only `com.microsoft.teams2`, with no comment acknowledging the classic-Teams gap.

### Pitfall 5: Google Meet (MEET-03) needs an explicit "why not" surfaced somewhere, not just silent absence

**What goes wrong:** A user joining a Google Meet call in a browser will see nothing happen and, per the codebase's own established "silent degrade" convention (used for Focus/Location per `PITFALLS.md`), may reasonably conclude the feature is broken rather than understanding it's an intentional scope boundary — unlike Focus/Location's silent-degrade cases (which are genuinely ambiguous signals), Google Meet's absence is a KNOWN, documentable limitation, not an uncertain one.

**How to avoid:** MEET-03 requires this be "documented as a known limitation, not silently missing" — interpret this as a documentation/changelog/Settings-copy requirement (e.g. the Settings card's one-line description for Meeting-HUD should say "Zoom & Teams calls" rather than an unqualified "video calls," and release notes/README should note the browser-based exclusion explicitly), not a code requirement — there is no reliable code-level signal to build against for a browser tab, and Islet has no browser extension. Confirm during UI-spec what the Settings card copy says.

**Warning signs:** A Settings card description implying broader call support than Zoom/Teams native apps actually deliver; no mention of the Google Meet limitation anywhere user-facing.

## Code Examples

### Wiring `.meeting` into `IslandResolver`'s priority switch (D-05: after `.device`, before `.focus`)

```swift
// Source: pattern extends Islet/Notch/IslandResolver.swift:183-199 (resolve()'s existing
// switch, read directly from the live codebase)
switch activeTransient {
case .charging(let a): return .charging(a)           // D-02 rank 1
case .device(let d):   return .device(d)             // D-02 rank 2
case .meeting(let m) where !isExpanded: return .meeting(m)   // NEW Phase 63 / D-05 rank 3, collapsed-only (D-10)
case .meeting: break                                  // expanded — but D-10 says this never actually happens
                                                        // since Meeting-HUD is collapsed-only, always; confirm
                                                        // during planning whether this branch is even reachable
                                                        // or whether the controller should simply never expand
                                                        // while a meeting transient is head (mirrors how OSD/
                                                        // CapsLock/Download/Update all still technically have
                                                        // this fallthrough today even though none of them have
                                                        // a dedicated expanded case either)
case .focus(let f) where !isExpanded: return .focus(f) // existing rank 4 (was rank 3), shifts down one
// ... rest unchanged, every existing rank comment shifts by one ...
```

### `MeetingMonitor` skeleton (mirrors `CapsLockMonitor.swift`'s lifecycle shape)

```swift
// Source: lifecycle skeleton pattern mirrors Islet/Notch/CapsLockMonitor.swift (read directly)
// and Islet/Notch/AudioOutputMonitor.swift's block-listener registration (read directly).
@MainActor
final class MeetingMonitor {
    private nonisolated(unsafe) var running = false
    private nonisolated(unsafe) var listenerBlock: AudioObjectPropertyListenerBlock?
    private nonisolated(unsafe) var pollTimer: Timer?
    private let targetBundleIDs: Set<String>   // D-01: ["us.zoom.xos", "com.microsoft.teams2", /* classic Teams? — Open Question */]
    private let onChange: (MeetingReading?) -> Void

    init(targetBundleIDs: Set<String>, onChange: @escaping (MeetingReading?) -> Void) {
        self.targetBundleIDs = targetBundleIDs
        self.onChange = onChange
    }

    func start() {
        guard !running else { return }
        running = true
        // Event-driven half: CoreAudio mic-active listener (mirrors AudioOutputMonitor's
        // AudioObjectAddPropertyListenerBlock registration).
        // Coarse-poll half: re-check NSWorkspace.runningApplications on a several-second
        // cadence (app-launch/terminate notifications can supplement but don't replace this,
        // since a false-negative here just means a slightly delayed HUD, not incorrect data).
        evaluate()
    }

    private func evaluate() {
        let appRunning = NSWorkspace.shared.runningApplications
            .contains { app in app.bundleIdentifier.map(targetBundleIDs.contains) ?? false }
        let micActive = readMicInUse()   // kAudioDevicePropertyDeviceIsRunningSomewhere
        onChange(appRunning && micActive ? MeetingReading(detectedAt: Date()) : nil)
    }

    nonisolated func stop() { /* mirrors CapsLockMonitor.stop() teardown shape */ }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|-------------------|---------------|--------|
| Direct `dlopen` of private frameworks for system integrations | Public CoreAudio HAL / NSWorkspace APIs only | N/A — this phase never touches a private framework | Meeting-HUD, unlike the project's Now Playing feature, has zero private-API surface at all; the "detection uncertainty" is a heuristic-accuracy problem, not an API-availability problem |

**Deprecated/outdated:** None specific to this phase — all APIs used (`NSWorkspace`, CoreAudio HAL) are current, stable, unchanged public surface with no known deprecation path.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|----------------|
| A1 | Reading `kAudioDevicePropertyDeviceIsRunningSomewhere`/`kAudioDevicePropertyMute` on the default INPUT device does not require Microphone TCC permission | Common Pitfalls Pitfall 2 | An unexpected system permission prompt fires the first time Zoom/Teams opens with mic active, from a non-activating panel that can't easily surface/explain it to the user — disruptive first-run UX, needs a documented go/no-go outcome from the spike either way |
| A2 | The nested `.onTapGesture` on the mute icon will reliably win hit-testing priority over `wingsShape`'s outer `.onTapGesture`, given the specific `.overlay(content())` view-composition this codebase uses | Architecture Patterns Pattern 3 | If SwiftUI's hit-testing doesn't behave as expected in this specific overlay chain, taps on the mute icon could incorrectly fall through to the no-op background tap (D-10) or, worse, if the no-op override is somehow bypassed, to the universal expand-to-Home — either way the mute control silently fails to toggle, a MEET-02-breaking regression |
| A3 | `com.microsoft.teams2` alone (per D-01, locked) is sufficient Teams coverage, without also matching classic Teams' `com.microsoft.teams` | Common Pitfalls Pitfall 4 | Users still on Teams classic get zero Meeting-HUD functionality with Teams calls, a silent total feature miss for that subset of users — flagged as an Open Question below since D-01 is locked and not this agent's to unilaterally override |

## Open Questions

1. **Should `com.microsoft.teams` (classic Teams) be added alongside `com.microsoft.teams2` in the detection bundle-ID list?**
   - What we know: D-01 locks only `com.microsoft.teams2`; both bundle IDs are real, currently-coexisting apps per this session's web research.
   - What's unclear: Whether D-01 was written with awareness of the classic/new Teams split, or whether it simply cited the more commonly-referenced modern bundle ID without considering the split.
   - Recommendation: Surface this explicitly to the user/planner before finalizing `MeetingMonitor`'s bundle-ID constant — a one-line addition (`Set<String>` literal), low cost either way, but a real product decision (does this project's actual user base still run classic Teams?) rather than an obvious default.

2. **Does the mic-active CoreAudio property listener require any permission/entitlement not already present, or is it genuinely zero-permission like the existing output-side code?**
   - What we know: `VolumeReader.swift`/`AudioOutputMonitor.swift` already do output-scope CoreAudio calls with zero microphone-related entitlement or Info.plist key present.
   - What's unclear: Whether input-scope specifically differs (Assumption A1).
   - Recommendation: First checklist item of D-03's on-device spike — run `MicMuteController`'s read/write against a fresh/never-granted Islet install and confirm no TCC dialog appears.

3. **Is `wingsShape`'s nested-gesture hit-testing behavior confirmed to prioritize inner content over the outer `onTapGesture`, specifically in this codebase's `.overlay(content())` composition?**
   - What we know: SwiftUI's general documented behavior is that the topmost/deepest view under the pointer captures a tap gesture first; `updateWings` already proves `onTap:` overrides work at the wing level.
   - What's unclear: Whether a SECOND, nested gesture inside `content()` reliably wins over the wing-level `onTapGesture`, given the specific `.overlay()`+`.frame(alignment: .leading)` chain `wingsShape` uses (Assumption A2) — no existing wing in this codebase has a nested interactive sub-region to serve as a direct precedent.
   - Recommendation: Verify with a minimal on-device SwiftUI test (or during the phase's own build/UAT) before committing to this exact mechanism; if it fails, `.highPriorityGesture` on the icon is the documented fallback.

## Environment Availability

Not applicable — this phase has no external tool/service/runtime dependency beyond APIs already linked into the Xcode project (CoreAudio, AudioToolbox, AppKit) and the ability to install/run Zoom.us and Microsoft Teams on the development machine for the D-03 spike (developer-provided, not something to probe programmatically).

## Validation Architecture

> `.planning/config.json`'s `workflow.nyquist_validation` was not read as a distinct file this session, but per this project's own established convention across Phases 60-62 (heavy on-device UAT checkpoints, `IslandResolver`/`TransientQueue` unit-tested in milliseconds since they're pure/Foundation-only), the following mirrors that pattern.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | XCTest (`IsletTests` target — confirmed present in the project structure) |
| Config file | Standard Xcode test target, no separate config file |
| Quick run command | `xcodebuild test -scheme Islet -only-testing:IsletTests/IslandResolverTests` (pure resolver logic, milliseconds) |
| Full suite command | `xcodebuild test -scheme Islet` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|---------------------|--------------|
| MEET-01 | `.meeting` case resolves at the correct rank (D-05), preempts Focus/OSD/Download/CapsLock/Update/Timer, is preempted only by Charging/Device | unit | `xcodebuild test -only-testing:IsletTests/IslandResolverTests` | ❌ Wave 0 — new test cases needed in the existing `IslandResolverTests.swift` file (file exists, new cases needed) |
| MEET-01 | `ActiveTransient.meeting(...).isPersistent == true` while active | unit | same as above | ❌ Wave 0 — new assertion |
| MEET-01 | Real Zoom/Teams call + mic on shows the HUD; app-open-only does not | manual-only | On-device spike checklist (D-03) | N/A — cannot be automated, no way to simulate a real call/mic state in CI |
| MEET-02 | Tapping the mute icon toggles system input mute and the icon reflects new state | manual-only | On-device UAT checklist | N/A — CoreAudio HAL writes affect the real machine's audio state, not safely automatable in CI |
| MEET-02 | `MicMuteController`'s guarded Get/Set never crashes on an unsupported device | unit | New `MicMuteControllerTests.swift` (mirrors `VolumeReader` test conventions if any exist — verify) | ❌ Wave 0 — need to confirm whether `VolumeReader.swift` has an existing test file to mirror |
| MEET-03 | Google Meet in a browser never triggers the HUD | manual-only | On-device spike checklist (negative case) | N/A |

### Sampling Rate
- **Per task commit:** `xcodebuild test -only-testing:IsletTests/IslandResolverTests` (fast, pure-logic subset)
- **Per wave merge:** `xcodebuild test -scheme Islet` (full suite)
- **Phase gate:** Full suite green + on-device D-03 spike go/no-go documented + on-device UAT (MEET-01/02/03 checklist) before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `IslandResolverTests.swift` — add `.meeting` rank/preemption/isPersistent test cases (file exists, needs new cases)
- [ ] New `MicMuteControllerTests.swift` — guarded-call safety tests (never crash on missing property); verify whether an existing `VolumeReaderTests.swift`-equivalent exists to mirror first
- [ ] No new framework install needed — XCTest already wired

## Security Domain

> `security_enforcement` config value not directly confirmed this session (absent = enabled per protocol default); Meeting-HUD's security surface is narrow but real given it toggles a system audio property.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|----------------|---------|--------------------|
| V2 Authentication | No | No auth surface — local single-user desktop feature |
| V3 Session Management | No | N/A |
| V4 Access Control | No | N/A — no data access control boundary |
| V5 Input Validation | Marginal | `MeetingMonitor`'s bundle-ID matching is against a fixed, hardcoded `Set<String>`, never user input — no injection surface. `MicMuteController` takes no external input at all (a plain toggle call) |
| V6 Cryptography | No | N/A |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|-----------------------|
| A malicious/compromised local process spoofing its bundle identifier to masquerade as Zoom/Teams | Spoofing | Out of realistic threat model for a personal single-user hobby app on the user's own machine — `NSWorkspace.runningApplications`' `bundleIdentifier` is the same string macOS itself trusts for Gatekeeper/notarization purposes; not independently re-verifiable by third-party code, and this project's own established threat-model scope (per prior phases' T-NN entries) has never treated local-process spoofing as in-scope |
| A crash/force-unwrap on a malformed/missing CoreAudio property causing a denial-of-service (the notch feature crashing the whole app) | Denial of Service | Mirrors `VolumeReader.swift`/`AudioOutputMonitor.swift`'s existing "guarded call, safe default, never force-unwrap" discipline — `MicMuteController`/`MeetingMonitor` must follow the identical pattern, verified via Pitfall 3's `AudioObjectHasProperty` guard requirement |

## Sources

### Primary (HIGH confidence)
- Direct code reads: `Islet/Notch/IslandResolver.swift`, `Islet/Notch/AudioOutputMonitor.swift`, `Islet/Notch/VolumeReader.swift`, `Islet/Notch/CapsLockMonitor.swift`, `Islet/Notch/TimerActivity.swift`, `Islet/Notch/DownloadActivity.swift`, `Islet/Notch/NotchPillView.swift` (wingsShape, downloadWings, timerWings, onClick), `Islet/Notch/NotchWindowController.swift` (hotZone/collapsedInteractiveZone/handleClick/startCapsLockMonitor/startDownloadMonitor), `Islet/ActivitySettings.swift`, `Islet/Islet.entitlements` — all read directly this session, current as of the live repo state
- `.planning/phases/63-meeting-hud/63-CONTEXT.md` — locked decisions, canonical refs
- `.planning/phases/62-timer-pomodoro/62-CONTEXT.md`, `.planning/phases/61-download-progress/61-CONTEXT.md` — precedent phases this one directly builds on

### Secondary (MEDIUM confidence)
- `.planning/research/FEATURES.md` §1, `.planning/research/PITFALLS.md` Pitfall 1/8, `.planning/research/SUMMARY.md` — prior milestone-level research this phase's D-01/D-02/D-03/D-04 decisions were locked from
- [GitHub Issue: New Microsoft Teams (com.microsoft.teams2) not detected · pasrom/meeting-transcriber#84](https://github.com/pasrom/meeting-transcriber/issues/84) — corroborates the classic/new Teams bundle-ID split (Pitfall 4)
- [Microsoft Teams name change on MacOS – MSB365](https://www.msb365.blog/?p=5429) — corroborates `com.microsoft.teams` (classic) vs `com.microsoft.teams2` (new) bundle ID distinction

### Tertiary (LOW confidence)
- WebSearch result on `kAudioDevicePropertyDeviceIsRunningSomewhere`/TCC microphone permission (Assumption A1) — no single authoritative Apple statement found this session confirming HAL property queries never trigger Microphone TCC; inferred from this codebase's own existing zero-permission output-side precedent plus general community understanding, flagged explicitly in the Assumptions Log for spike-time verification

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — every API traced to an existing, working precedent in this exact codebase (VolumeReader, AudioOutputMonitor)
- Architecture: HIGH — IslandResolver/TransientQueue integration verified against live, current code; Phase 62's generalization confirmed to need zero further changes beyond one new `if case`
- Pitfalls: MEDIUM — detection-heuristic reliability (Pitfall 1) and TCC-permission status (Pitfall 2) both genuinely require the phase's own on-device spike to resolve, not resolvable from research alone; nested-gesture hit-testing (Pattern 3 / A2) has no existing in-codebase precedent to verify against

**Research date:** 2026-07-24
**Valid until:** 30 days (stable Apple system APIs, no fast-moving dependency) — EXCEPT the Zoom/Teams bundle-ID assumptions (D-01, A3), which should be re-confirmed if either app ships a major version change before this phase executes
