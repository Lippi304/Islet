---
phase: 63
plan: 02
subsystem: meeting-hud
tags: [meeting, detection, coreaudio, nsworkspace, spike, on-device]
requires:
  - 63-01 (MeetingReading value type, defaultInputDeviceID/readSystemInputMuted/toggleSystemInputMute)
provides:
  - MeetingMonitor (the single detection surface — Zoom/Teams running AND default input device active)
  - once-per-transition onChange(MeetingReading?) contract Plan 63-04's controller depends on
  - documented on-device GO verdict unblocking Plans 63-03 and 63-04
affects:
  - Plan 63-03 (ActiveTransient.meeting resolver/view wiring reads MeetingMonitor's onChange)
  - Plan 63-04 (controller calls preempt/removeAll straight from onChange — safe only because of the dedup)
tech-stack:
  added: []
  patterns:
    - "One fragile system surface, one file (D-03) — CapsLockMonitor / AudioOutputMonitor sibling"
    - "CapsLockMonitor's lastState dedup: onChange only on a real transition, never per tick"
    - "CoreAudio block listener + DispatchQueue.main.async hop (AudioObjectAddPropertyListenerBlock delivers off-main)"
    - "Manual Cmd-U-only spike harness (AudioOutputMonitorManualSpike template)"
key-files:
  created:
    - Islet/Notch/MeetingMonitor.swift
    - IsletTests/MeetingMonitorManualSpike.swift
  modified:
    - Islet.xcodeproj/project.pbxproj
decisions:
  - "Input-scope kAudioDevicePropertyDeviceIsRunningSomewhere verified on-device before writing the monitor (Global and Output answer too; Input keeps scope discipline consistent with MicMuteController)"
  - "Added a kAudioHardwarePropertyDefaultInputDevice listener + listener re-targeting (Rule 2) — without it a mid-session default-input change strands the listener on the old device and leaks it at stop()"
  - "Spike substituted Discord for Zoom/Teams (neither installed on the validation machine); production targetBundleIDs unchanged"
  - "Production bundle IDs us.zoom.xos / com.microsoft.teams2 / com.microsoft.teams remain UNVERIFIED against real installs — risk accepted, carried into 63-03"
metrics:
  duration: 25min + on-device checkpoint
  completed: 2026-07-25
---

# Phase 63 Plan 02: MeetingMonitor Detection Heuristic + On-Device Spike Summary

`MeetingMonitor` — the one file carrying 100% of the meeting-detection risk (D-03) — detects a call
as the AND of "a target conferencing app is running" and "the default input device is running
somewhere", fires `onChange` exactly once per real transition, and was validated on real hardware
with a **GO** verdict including the hard TCC-prompt gate.

## What Was Built

### Task 1 — `Islet/Notch/MeetingMonitor.swift`

`@MainActor final class MeetingMonitor`, lifecycle shape cloned from `CapsLockMonitor`
(`nonisolated(unsafe)` stored tokens, idempotent `start()` guard, `nonisolated func stop()`, empty
`deinit` because the owner drives teardown).

Detection is one `evaluate()` funnel — the AND of:

- **(a) app running:** `NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier.map(targetBundleIDs.contains) ?? false }`, default set `["us.zoom.xos", "com.microsoft.teams2", "com.microsoft.teams"]` (D-01: new Teams *and* classic Teams both listed, they coexist in the wild).
- **(b) mic active:** `kAudioDevicePropertyDeviceIsRunningSomewhere`, `mScope: kAudioDevicePropertyScopeInput`, on the device returned by `defaultInputDeviceID()` — **reused from `MicMuteController.swift`, never re-implemented** (`grep -c "func defaultInputDeviceID" MeetingMonitor.swift` == 0).

Four event sources feed that one funnel: NSWorkspace `didLaunchApplicationNotification` /
`didTerminateApplicationNotification` observers, a CoreAudio block listener on the input device's
running-somewhere property, a listener on `kAudioHardwarePropertyDefaultInputDevice`, and a 5s
`Timer` poll fallback at `CapsLockMonitor.healthCheckTimer`'s cadence. The CoreAudio block hops to
`DispatchQueue.main.async` before touching any stored state (CoreAudio invokes it on an internal
queue; `@MainActor` does not retroactively isolate a system-framework callback).

**Dedup (the contract Plan 63-04 depends on):** `evaluate()` guards
`detected != (lastReading != nil)` and returns silently on a non-transition, so `onChange` fires
exactly once per real call-start/call-end. This is what lets 63-04's handler call
`transientQueue.preempt(_:)` / `removeAll(where:)` directly without duplicate-entry risk.

**T-63-04 lifecycle:** `stop()` removes the identical block reference from both the system object and
the *stored* `listenedDeviceID` (not whatever happens to be default at teardown time), invalidates
the poll timer, and drops both NSWorkspace observers.

### Task 1 — `IsletTests/MeetingMonitorManualSpike.swift`

Mirrors `AudioOutputMonitorManualSpike.swift` verbatim in shape: `MANUAL SPIKE — DO NOT RUN VIA
xcodebuild test` header, `@MainActor func testManualDetectionHeuristic()`, `[MeetingSpike]` console
prints, `RunLoop.current.run(until: Date().addingTimeInterval(180))`, `monitor.stop()`, trivial
always-green assertion pointing at the real human-read criteria. It exercises
`readSystemInputMuted()` / `toggleSystemInputMute()` first (and toggles back, so the machine's mic
state is restored) so the human can watch for an unexpected TCC dialog.

### Task 2 — On-device spike checkpoint

Verdict recorded verbatim below.

## On-Device Spike Verdict — GO

**Substitution:** The validation machine had neither Zoom nor Teams installed. The spike was re-targeted to Discord (`com.hnc.Discord`) — a native voice-call app producing the identical signal shape (target app running AND default-input device active). Committed as `63e6db1`; `MeetingMonitor`'s production default `targetBundleIDs` is UNCHANGED. The spike file carries a `SPIKE SUBSTITUTION` comment documenting how to swap back.

**Results across three runs on macOS Darwin 27.0.0:**

| Check | Result |
|---|---|
| TCC Microphone permission prompt (Pitfall 2 / A1 hard gate) | **PASS — no prompt appeared.** `readSystemInputMuted()` returned `false`, `toggleSystemInputMute()` returned `Optional(true)`, state restored. Confirmed on all three runs. |
| Detection on real voice call (Discord voice channel joined) | PASS — `detected=true` at 01:57:59, within ~5s of the mic going live |
| Detection clears on leaving the call | PASS — `detected=false` at 01:58:19 |
| Once-per-transition dedup, no flapping | PASS — exactly four transitions logged (true 01:57:59 / false 01:58:19 / true 01:58:29 / false 01:58:49), perfectly alternating, zero duplicate fires while a state held |
| Mic test without joining a call (D-07 accepted false positive) | FIRES `detected=true` — accepted per D-07, recorded as expected behaviour, not a failure |
| Mic active with NO target app running (target app quit, Voice Memos recording) | PASS — monitor stayed completely silent for the whole ~39s window; the app-running half of the AND gate holds |
| Google Meet in a browser tab (MEET-03 negative) | PASS — never fired |

**Explicitly NOT validated:** that the literal production bundle IDs `us.zoom.xos`, `com.microsoft.teams2`, `com.microsoft.teams` match real installs — neither app was available on the validation machine. These are publicly documented, stable identifiers; the risk is accepted and carried forward. First real Zoom/Teams call will confirm.

**Verdict: GO.** Plans 63-03 and 63-04 may proceed. No `NSMicrophoneUsageDescription` or permission flow is required.

Note for the record: an earlier run produced no `[MeetingSpike]` output at all because the test host
launched without the test executing — that run was discarded and re-done, not counted as a silent
pass.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing critical functionality] Default-input-device listener + listener re-targeting**
- **Found during:** Task 1
- **Issue:** The plan specifies one listener, on `kAudioDevicePropertyDeviceIsRunningSomewhere` for
  the device `defaultInputDeviceID()` returns at `start()`. The default input device changes at
  runtime (AirPods connecting mid-call is the common case). With only that listener, the monitor
  would keep listening to the old device — and `stop()` would remove the listener from whatever
  device happened to be default at teardown, leaking the real registration (a T-63-04 lifecycle leak
  across repeated Settings toggle on/off).
- **Fix:** added a listener on `kAudioHardwarePropertyDefaultInputDevice` (system object) and a
  `retargetInputListener()` that stores `listenedDeviceID`, removes from the previous device and
  re-adds on the new one. `stop()` removes from the stored ID.
- **Files modified:** `Islet/Notch/MeetingMonitor.swift`
- **Commit:** `a87803a`

### Design notes (not deviations)

- **Input scope verified before writing, not assumed.** Apple documents
  `kAudioDevicePropertyDeviceIsRunningSomewhere` on the global scope, while the plan mandates
  `kAudioDevicePropertyScopeInput`. A throwaway `swift` probe against this machine's default input
  device (id 78) returned `hasProperty=true getStatus=0` for Input, Global *and* Output — so the
  plan's Input scope is correct as written and no fallback branch was needed. Input also keeps this
  file's scope discipline identical to `MicMuteController.swift`'s Input-only rule.
- **`project.yml` not modified** despite being listed in the plan's `files_modified`. XcodeGen
  discovers sources from the `Islet/` and `IsletTests/` folders (`sources: - path: Islet`), so a new
  `.swift` file needs no recipe change — only `xcodegen generate`, which is what ran.
- **Spike substitution (Discord) is test-only.** `MeetingMonitor`'s production
  `targetBundleIDs` default is untouched; the spike passes `targetBundleIDs:` explicitly and carries
  a comment documenting how to swap back to `MeetingMonitor(onChange:)` for a real Zoom/Teams re-run.

## Verification

| Check | Result |
|-------|--------|
| `xcodebuild build -scheme Islet -configuration Debug` | BUILD SUCCEEDED |
| `xcodebuild build-for-testing -scheme Islet -configuration Debug` (compiles the spike without the headless test-host hang) | TEST BUILD SUCCEEDED |
| `grep -c "us.zoom.xos"` >= 1 | 1 |
| `grep -c "com.microsoft.teams2"` >= 1 | 2 |
| `grep -c "\"com.microsoft.teams\""` >= 1 | 1 |
| `grep -c "kAudioDevicePropertyDeviceIsRunningSomewhere"` >= 1 | 3 |
| `grep -c "DispatchQueue.main.async"` >= 1 | 3 |
| `grep -c "func defaultInputDeviceID"` == 0 (reused, not duplicated) | 0 |
| `grep -c "DO NOT RUN VIA"` in the spike == 1 | 1 |
| On-device 7-step checkpoint | GO (see verdict above) |

## Known Stubs

None. `MeetingMonitor` is complete and self-contained. It is deliberately not instantiated by
`NotchWindowController` yet — resolver/view wiring is Plan 63-03's scope by design.

## Carried-Forward Risk

The production bundle IDs were never matched against a real Zoom or Teams install (neither app
exists on the validation machine). If Plan 63-03's on-device UAT shows no detection with a real
Zoom/Teams call, the first thing to check is the bundle ID — run
`osascript -e 'id of app "zoom.us"'` (or read `Contents/Info.plist`'s `CFBundleIdentifier`) on a
machine that has it installed, rather than re-debugging the heuristic.

## Threat Flags

None. No new network endpoint, auth path, file access, or trust boundary. T-63-04 (listener/timer
lifecycle leak) is mitigated as planned, and the Rule-2 re-targeting fix above closes the one
leak path the plan's literal single-listener design would have left open. T-63-03 (local bundle-ID
spoofing) stays `accept` per the plan. T-63-05 (spike console logging) stays `accept` — the spike
logs only booleans, timestamps and a bundle ID, never runs under `xcodebuild test`, and never ships
in Release.

## Commits

| Commit | Type | Description |
|--------|------|-------------|
| `a87803a` | feat | MeetingMonitor detection heuristic + manual spike harness |
| `63e6db1` | test | target Discord in manual spike as Zoom/Teams stand-in |

## Next

Plan 63-03 may proceed: wire `ActiveTransient.meeting(MeetingActivity)` into the resolver/view on top
of `MeetingMonitor`'s once-per-transition `onChange`. MEET-01/MEET-03 stay **Pending** in
REQUIREMENTS.md until the phase's own on-device UAT confirms the shipped HUD end-to-end — matching
this project's Phase 45 / 52-03 / 53-01 precedent of not closing requirements on an infrastructure
plan.

## Self-Check: PASSED

All 3 claimed files exist on disk; all 3 claimed commit hashes exist in git history.
