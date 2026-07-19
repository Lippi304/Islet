---
phase: 47-audio-output-switcher-pure-seam-monitor
plan: 02
subsystem: infra
tags: [coreaudio, audiotoolbox, swift, macos, monitor]

# Dependency graph
requires:
  - phase: 47-01
    provides: AudioOutputDevice struct, isOutputCapableDevice(outputChannelCount:), sortedAudioOutputDevices(_:) — the pure presentation seam this plan's glue layer calls
provides:
  - AudioOutputMonitor — event-driven CoreAudio glue enumerating real output-capable devices, tracking connect/disconnect/default-output changes
  - setDefaultOutput(_:completion:) with Pitfall 8 confirm-after-set discipline
  - hasVolumeControl(deviceUID:) with Pitfall 7 guarded-property discipline
affects: [48-audio-output-switcher-ui-wiring]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "AudioObjectPropertyListenerBlock retained on the instance (not a token object) so stop() can remove the identical block reference"
    - "resolveDeviceID(uid:) re-resolves a stable UID to a live AudioDeviceID immediately before every write (Pitfall 4), never a cached ID"
    - "Confirm-after-set: after AudioObjectSetPropertyData succeeds, delay-reread the value before reporting success (Pitfall 8)"

key-files:
  created: [Islet/Notch/AudioOutputMonitor.swift]
  modified: []

key-decisions:
  - "listenerBlock stored as nonisolated(unsafe) (not just private var) — required so nonisolated func stop() can read/clear it, mirroring BluetoothMonitor's nonisolated(unsafe) token fields"

patterns-established:
  - "CoreAudio block-listener retention: store the AudioObjectPropertyListenerBlock itself as the identity token (no OS-issued handle exists, unlike IOBluetoothUserNotification)"

requirements-completed: [D-01, D-03]

# Metrics
duration: 12min
completed: 2026-07-19
---

# Phase 47 Plan 02: AudioOutputMonitor Summary

**Event-driven CoreAudio glue (AudioOutputMonitor) enumerating real output devices via kAudioHardwarePropertyDevices, with confirm-after-set default-output switching and guarded per-device volume-control detection.**

## Performance

- **Duration:** 12 min
- **Started:** 2026-07-19T21:28:00Z
- **Completed:** 2026-07-19T21:40:35Z
- **Tasks:** 2
- **Files modified:** 1 (new)

## Accomplishments
- `AudioOutputMonitor` mirrors `BluetoothMonitor`'s idempotent-start/full-teardown-stop shape exactly, with every listener callback hopping to main via `DispatchQueue.main.async` before touching state (Pitfall 5)
- `currentDevices()` enumerates the live system device list via the guarded "get size, then get data" CoreAudio idiom, keyed by `kAudioDevicePropertyDeviceUID` (never `AudioDeviceID`, Pitfall 4), filtered through `isOutputCapableDevice(outputChannelCount:)` and returned via `sortedAudioOutputDevices(_:)`
- `setDefaultOutput(_:completion:)` re-resolves the target UID immediately before the write, then re-reads the default device 0.3s later to confirm the switch actually stuck rather than trusting the write call's return status alone (Pitfall 8 — guards the documented AirPods-handoff silent-override bug)
- `hasVolumeControl(deviceUID:)` never claims volume support without an `AudioObjectHasProperty` guard on `kAudioHardwareServiceDeviceProperty_VirtualMainVolume`, falling back to a per-channel check (Pitfall 7)
- Zero coupling to `BluetoothMonitor` (grep-verified 0 occurrences of the literal string, including comments); `VolumeReader.swift` completely unmodified (Pitfall 6 / Anti-Pattern 3)

## Task Commits

Each task was committed atomically:

1. **Task 1: AudioOutputMonitor class shape + idempotent start/stop + device enumeration** - `48a5693` (feat)
2. **Task 2: setDefaultOutput(_:completion:) + hasVolumeControl(deviceUID:)** - `aefb955` (feat)

**Plan metadata:** (this commit)

## Files Created/Modified
- `Islet/Notch/AudioOutputMonitor.swift` - Event-driven CoreAudio device-list monitor: idempotent start/stop, live device enumeration, default-output switching with confirm-after-set, per-device volume-control detection

## Decisions Made
- `listenerBlock` declared `private nonisolated(unsafe)` (plan specified plain `private var`) — required by the Swift compiler so `nonisolated func stop()` can read and clear it without a main-actor isolation error; matches the exact pattern the plan's own interface excerpt already uses for `BluetoothMonitor.connectToken`. Not a scope change, just the concrete Swift 6 concurrency annotation the design already implied.

## Deviations from Plan

None - plan executed exactly as written (the `nonisolated(unsafe)` annotation above is a mechanical Swift-compiler requirement to satisfy the plan's own stated `nonisolated func stop()` design, not a design deviation).

## Issues Encountered
None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
`AudioOutputMonitor` is buildable and ready for Plan 47-03's on-device spike (real device enumeration, live connect/disconnect, and per-device volume-property support against actual hardware — none of which is unit-testable and is explicitly out of scope for this plan per its own `<verification>` section). No `NotchWindowController`/`NotchPillView` wiring exists yet — that is Phase 48's UI-wiring scope.

---
*Phase: 47-audio-output-switcher-pure-seam-monitor*
*Completed: 2026-07-19*

## Self-Check: PASSED

- FOUND: Islet/Notch/AudioOutputMonitor.swift
- FOUND: .planning/phases/47-audio-output-switcher-pure-seam-monitor/47-02-SUMMARY.md
- FOUND: 48a5693 (Task 1 commit)
- FOUND: aefb955 (Task 2 commit)
- FOUND: b957b38 (docs commit)
