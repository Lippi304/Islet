---
phase: 48-audio-output-switcher-ui-wiring
plan: 01
subsystem: audio
tags: [coreaudio, swiftui, published-state, output-switcher]

# Dependency graph
requires:
  - phase: 47-audio-output-switcher-pure-seam
    provides: AudioOutputDevice, AudioOutputMonitor, sortedAudioOutputDevices, hasVolumeControl(deviceUID:)
provides:
  - "setSystemVolume(_ target: Float) -> (percent: Int, muted: Bool)? in VolumeReader.swift — absolute-set volume write path"
  - "4 new @Published sibling fields on IslandPresentationState: outputPanelOpen, outputDevices, outputCurrentVolumeFraction, outputHasVolumeControl"
  - "AudioOutputMonitor started unconditionally at launch in NotchWindowController, its device-list callback keeps presentationState.output* live"
affects: [48-02-audio-output-switcher-ui, 48-03-audio-output-switcher-controller-handlers]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Absolute-set CoreAudio volume write mirrors the existing relative adjustSystemVolume(increase:) guarded Get/Set/auto-(un)mute shape, defensively re-clamping its input"
    - "Controller-owned @Published sibling state on IslandPresentationState (mirrors hoveredQuickActionButtonIndex/secondary precedent) for cross-view, cross-controller-geometry state that must stay in lockstep"
    - "Unconditional monitor start (no activityEnabled Settings-toggle gate), mirrors startOSDInterceptor()'s precedent for always-available system features"

key-files:
  created: []
  modified:
    - Islet/Notch/VolumeReader.swift
    - Islet/Notch/IslandPresentationState.swift
    - Islet/Notch/NotchWindowController.swift

key-decisions:
  - "setSystemVolume(_:) does NOT read currentVolume first (unlike adjustSystemVolume) — it clamps the incoming target directly, since the caller (a future drag gesture) already computes an absolute 0...1 fraction rather than a relative step"
  - "handleAudioOutputDevicesChanged(_:) has no DispatchQueue.main.async wrapper — AudioOutputMonitor's own callback already hops to main (Phase 47 Pitfall 5), confirmed again here rather than re-guarded defensively"

requirements-completed: [OUTPUT-04]

# Metrics
duration: 15min
completed: 2026-07-19
---

# Phase 48 Plan 01: Data-Layer Foundation Summary

**Absolute-set CoreAudio volume write path, 4 new controller-owned @Published output-panel fields, and AudioOutputMonitor started unconditionally with its live device-list callback wired into presentationState.**

## Performance

- **Duration:** ~15 min
- **Completed:** 2026-07-19
- **Tasks:** 3 completed
- **Files modified:** 3

## Accomplishments
- `VolumeReader.swift` gains `setSystemVolume(_ target: Float)`, the absolute-set counterpart to `adjustSystemVolume(increase:)`, closing the gap PATTERNS.md flagged — same guarded Get/Set/auto-(un)mute discipline, defensively re-clamped, never force-unwraps or partially applies a change.
- `IslandPresentationState` gains 4 new sibling `@Published` fields (`outputPanelOpen`, `outputDevices`, `outputCurrentVolumeFraction`, `outputHasVolumeControl`) with an explicit controller-writes/view-reads ownership contract documented inline, mirroring the `hoveredQuickActionButtonIndex` precedent.
- `AudioOutputMonitor` (Phase 47) now starts unconditionally at launch in `NotchWindowController.start(isFirstLaunch:)`, mirroring `startOSDInterceptor()`'s own no-Settings-toggle precedent; its device-list callback (`handleAudioOutputDevicesChanged(_:)`) keeps `presentationState.outputDevices`/`outputHasVolumeControl`/`outputCurrentVolumeFraction` live on every delivery (initial snapshot + every connect/disconnect/default-change event), satisfying OUTPUT-04 at its source. Teardown wired in `deinit` via `audioOutputMonitor?.stop()`.

## Task Commits

Each task was committed atomically:

1. **Task 1: VolumeReader.swift — absolute-set volume function** - `516c8a2` (feat)
2. **Task 2: IslandPresentationState — output panel sibling state** - `2fa4a02` (feat)
3. **Task 3: NotchWindowController — AudioOutputMonitor lifecycle + device-list handler** - `0e16fcc` (feat)

_No TDD tasks in this plan._

## Files Created/Modified
- `Islet/Notch/VolumeReader.swift` - Added `setSystemVolume(_:)`, absolute-set volume write path for the draggable slider
- `Islet/Notch/IslandPresentationState.swift` - Added 4 output-panel `@Published` sibling fields
- `Islet/Notch/NotchWindowController.swift` - Added `audioOutputMonitor` property, `startAudioOutputMonitor()`, `handleAudioOutputDevicesChanged(_:)`, call site in `start(isFirstLaunch:)`, teardown in `deinit`

## Decisions Made
- `setSystemVolume(_:)` skips the `currentVolume` Get that `adjustSystemVolume` performs — it clamps the caller's target fraction directly rather than computing a delta, since the drag gesture (Plan 48-02) already produces an absolute 0...1 value.
- `handleAudioOutputDevicesChanged(_:)` intentionally omits a `DispatchQueue.main.async` wrapper, relying on `AudioOutputMonitor`'s own confirmed main-hop (Phase 47 Pitfall 5) rather than re-guarding defensively — matches the plan's explicit interface note.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 48-02 (`NotchPillView` UI) can now read `presentationState.outputPanelOpen`/`outputDevices`/`outputCurrentVolumeFraction`/`outputHasVolumeControl` directly.
- Plan 48-03 (controller handlers) can now call `setSystemVolume(_:)` from `handleVolumeChange(_:)` and write `presentationState.outputPanelOpen` from `handleToggleOutputPanel()`.
- Real hardware connect/disconnect behavior remains to be exercised end-to-end once Plan 48-02/48-03's UI exists (Plan 48-03's own on-device checkpoint, per the plan's verification section).

---
*Phase: 48-audio-output-switcher-ui-wiring*
*Completed: 2026-07-19*

## Self-Check: PASSED

All 3 modified source files and the SUMMARY.md itself found on disk; all 3 task commit hashes (516c8a2, 2fa4a02, 0e16fcc) found in git log.
