---
phase: 47-audio-output-switcher-pure-seam-monitor
plan: 03
subsystem: audio
tags: [coreaudio, xctest, manual-spike, hal]

# Dependency graph
requires:
  - phase: 47-audio-output-switcher-pure-seam-monitor (47-02)
    provides: AudioOutputMonitor (event-driven CoreAudio device monitor, start/stop/setDefaultOutput/hasVolumeControl)
provides:
  - Manual Cmd-U spike harness proving AudioOutputMonitor against real hardware
  - Fixed AudioObjectGetPropertyData qualifier-data pattern for kAudioHardwarePropertyTranslateUIDToDevice
  - On-device confirmation of Pitfall 4 (UID stability across BT reconnect) and Pitfall 8 (confirm-after-set)
  - hasVolumeControl results for 4 real device types (built-in, Bluetooth, USB, external-monitor)
affects: [48-audio-output-switcher-ui-wiring]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "CoreAudio qualifier-data calling convention for AudioObjectGetPropertyData translate-UID-to-device calls (inQualifierData/inQualifierDataSize carry input, ioData carries only output) — the deprecated AudioValueTranslation-wrapped-in-ioData pattern trips HAL's 'wrong data size' validation on modern macOS"

key-files:
  created:
    - IsletTests/AudioOutputMonitorManualSpike.swift
  modified:
    - Islet/Notch/AudioOutputMonitor.swift

key-decisions:
  - "resolveDeviceID(uid:) rewritten to pass the UID as AudioObjectGetPropertyData qualifier data instead of an AudioValueTranslation ioData struct — the latter is the deprecated AudioHardwareGetProperty-era pattern and silently failed with HAL 'wrong data size' on this hardware, root-causing resolveDeviceID always returning nil"
  - "D-03's 2-distinct-Bluetooth-device verification scope accepted as single-device (Jabra Elite 8 Active only) — user has no second Bluetooth output device available; documented as a scope limitation, not silently dropped"

patterns-established: []

requirements-completed: [D-03]

# Metrics
duration: multi-session (2 rounds of on-device Cmd-U testing, one mid-checkpoint bug fix)
completed: 2026-07-20
---

# Phase 47 Plan 03: On-Device AudioOutputMonitor Verification Summary

**Manual Cmd-U spike harness proved AudioOutputMonitor against real hardware, surfaced and fixed a HAL "wrong data size" bug in resolveDeviceID's UID-translation call, then re-verified clean on-device: stable UIDs across a Bluetooth reconnect, a confirmed-after-set default-output switch, and hasVolumeControl results for built-in/Bluetooth/USB/external-monitor devices.**

## Performance

- **Duration:** multi-session (2 rounds of on-device Cmd-U testing separated by one bug-fix round)
- **Tasks:** 2 (Task 1 auto, Task 2 blocking human-verify checkpoint)
- **Files modified:** 3 (1 created, 1 fixed, 1 project-file regen)

## Accomplishments
- `IsletTests/AudioOutputMonitorManualSpike.swift` — Cmd-U-only XCTest harness exercising `AudioOutputMonitor.start()/setDefaultOutput()/hasVolumeControl()/stop()` against real CoreAudio hardware, printing uid/name/isDefault/hasVolumeControl to the console
- Root-caused and fixed a real bug found during the first on-device round: `resolveDeviceID(uid:)` used the deprecated `AudioValueTranslation`-wrapped-in-`ioData` pattern for `kAudioHardwarePropertyTranslateUIDToDevice`, which HAL rejected as "wrong data size" — `resolveDeviceID` always returned `nil`, so `hasVolumeControl` always reported `false` and `setDefaultOutput`'s switch never confirmed
- Second on-device round (post-fix) confirmed all 8 D-03 verification steps pass on real hardware

## Task Commits

Each task was committed atomically:

1. **Task 1: Manual on-device spike harness** — `2e2398b` (feat)
2. **Mid-checkpoint bug fix** (applied by the orchestrator during Task 2's on-device round, not by this executor) — `f6e9613` (fix)
3. **Paused-at-checkpoint state record** — `e14c0a3` (docs)

**Plan metadata:** (this commit — docs: complete plan)

## Files Created/Modified
- `IsletTests/AudioOutputMonitorManualSpike.swift` — manual-only Cmd-U harness, never run via `xcodebuild test`
- `Islet/Notch/AudioOutputMonitor.swift` — `resolveDeviceID(uid:)` fixed to use the qualifier-data calling convention
- `Islet.xcodeproj/project.pbxproj` — xcodegen regeneration to register the new test file

## Decisions Made
- Qualifier-data pattern (`inQualifierData`/`inQualifierDataSize` carrying the UID, `ioData` holding only the `AudioDeviceID` output) is now this codebase's correct pattern for any future `AudioObjectGetPropertyData` call that translates an input value to an output — the `AudioValueTranslation` ioData-wrapper pattern is deprecated and fails HAL validation on this hardware/macOS version.
- D-03's "2 distinct Bluetooth devices" scope accepted as single-device coverage (Jabra Elite 8 Active) — the user has no second Bluetooth output device on hand. User explicitly confirmed and chose to proceed rather than block on unavailable hardware.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added `@MainActor` to the spike's test method**
- **Found during:** Task 1, `xcodebuild build-for-testing` compile check (beyond the plan's literal `xcodebuild build` acceptance command)
- **Issue:** `AudioOutputMonitor`'s `init`/`start()`/`setDefaultOutput()`/`hasVolumeControl()` are all `@MainActor`-isolated; calling them from a synchronous, non-isolated XCTest method failed to compile with 4 actor-isolation errors
- **Fix:** Added `@MainActor` to `testManualDeviceEnumerationAndSwitch()`
- **Files modified:** `IsletTests/AudioOutputMonitorManualSpike.swift`
- **Verification:** `xcodebuild build-for-testing -scheme Islet` succeeded after the fix
- **Committed in:** `2e2398b` (Task 1 commit)

**2. [Rule 1 - Bug, applied by orchestrator mid-checkpoint] Fixed `resolveDeviceID(uid:)`'s HAL "wrong data size" failure**
- **Found during:** Task 2's first on-device round — HAL logged "wrong data size" for every `kAudioHardwarePropertyTranslateUIDToDevice` call
- **Issue:** UID passed wrapped in a deprecated `AudioValueTranslation` struct as `ioData`; the modern `AudioObjectGetPropertyData` call expects the UID as qualifier data with `ioData` holding only the `AudioDeviceID` output. `resolveDeviceID` always returned `nil`, cascading into `hasVolumeControl` always reporting `false` and `setDefaultOutput`'s confirm-after-set always failing.
- **Fix:** Rewrote the call to pass the UID via `inQualifierData`/`inQualifierDataSize`, `ioData` now holds only the `AudioDeviceID` output
- **Files modified:** `Islet/Notch/AudioOutputMonitor.swift`
- **Verification:** Build green; second on-device round confirmed `hasVolumeControl` and `setDefaultOutput` both work correctly against real devices
- **Applied by:** orchestrator directly, not this executor agent (mid-checkpoint, between the two on-device test rounds)
- **Committed in:** `f6e9613`

---

**Total deviations:** 2 auto-fixed (1 blocking compile fix by this executor, 1 real bug fixed by the orchestrator mid-checkpoint)
**Impact on plan:** Both fixes necessary for the harness/monitor to function at all. No scope creep.

## Issues Encountered
None beyond the two deviations above.

## On-Device Verification Results (Task 2, 8 steps)

1. Built-in speakers (MacBook Air) printed with real uid/name, `isDefault=true` initially, `hasVolumeControl` result present. ✓
2/3. Bluetooth device "Jabra Elite 8 Active" (uid=`50-C2-75-65-8A-A4:output`) — two full disconnect+reconnect cycles observed. Also exercised: Elgato Wave XLR Pro USB Aux (USB/wired, `hasVolumeControl=true`), HP 25x (external monitor output, `hasVolumeControl=false` — plausible, no BT MAC-style UID), MacBook Air built-in speakers (`hasVolumeControl=true`).
4. **Pitfall 4 regression check CONFIRMED:** `uid=50-C2-75-65-8A-A4:output` (Jabra) identical across both disconnect+reconnect cycles — no duplicate/stale UID.
5. **Pitfall 8 confirm-after-set CONFIRMED:** `[AudioOutputSpike] switch result: true` printed; the subsequent device-list snapshot shows the target device (Elgato) with `isDefault=true`, matching the automatic switch target.
6. No crash, no hang, no main-thread-checker purple warning across two full ~60s test runs (both "Test Case ... passed").
7. `hasVolumeControl` results recorded: Elgato USB=true, Built-in speakers=true, Jabra Bluetooth=true, HP 25x external monitor=false — this is Phase 48's authoritative input for which devices get a real slider vs. a disabled one.

**Known scope limitation (user-confirmed, accepted):** D-03 specified 2 distinct Bluetooth devices to catch codec/implementation differences. Only one Bluetooth output device (Jabra Elite 8 Active) was available for testing — no second BT device exists in this environment. User explicitly confirmed and accepted single-BT-device coverage rather than block on hardware they don't own.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Phase 47 (Audio Output Switcher — Pure Seam + Monitor) is now fully complete: the pure seam (47-01), the monitor (47-02, plus its on-device-surfaced HAL fix in this plan), and its on-device proof (47-03) are all done. `hasVolumeControl` results for 4 real device types are recorded above as Phase 48's authoritative slider-vs-disabled input. Phase 48 (UI Wiring) can proceed with confidence, carrying forward the documented single-BT-device D-03 scope limitation.

---
*Phase: 47-audio-output-switcher-pure-seam-monitor*
*Completed: 2026-07-20*

## Self-Check: PASSED
