---
phase: 44-tray-quick-action-width-alignment
plan: 01
subsystem: ui
tags: [swiftui, appkit, nspanel, geometry, notch]

# Dependency graph
requires:
  - phase: 32-tray-widening
    provides: NotchPillView.traySize/trayContentHeight/switcherRowHeight constants this plan reuses
  - phase: 34-quick-action-destination-picker
    provides: the quickActionPickerFrame/contentSize/quickActionPickerView geometry sites this plan corrects
provides:
  - Quick Action picker (during-drag Drop/AirDrop/Mail card) now renders at the exact same width AND height as the real widened Tray view across all 3 geometry sites (panel reservation, click-through contentSize, SwiftUI blobShape call)
  - Lock-in unit test proving computeQuickActionButtonFrames stays in-bounds at the new 650x189 card size
affects: [45-view-switcher-morph-fix]

# Tech tracking
tech-stack:
  added: []
  patterns: ["geometry three-site rule (reuse existing static constants at all 3 sizing sites instead of introducing new numbers)"]

key-files:
  created: []
  modified:
    - Islet/Notch/NotchWindowController.swift
    - Islet/Notch/NotchPillView.swift
    - IsletTests/DragApproachGeometryTests.swift

key-decisions:
  - "Reused NotchPillView.traySize.width / trayContentHeight + switcherRowHeight at all 3 sites rather than inventing new width/height numbers (D-03/D-04/D-05)"
  - "Deleted the now-orphaned quickActionPickerContentHeight constant instead of leaving it dead (per CONTEXT.md's Claude's Discretion note, option 1)"

patterns-established: []

requirements-completed: [TRAY-06, DRAG-02]

# Metrics
duration: 10min
completed: 2026-07-19
---

# Phase 44 Plan 01: Quick Action Picker Width/Height Alignment Summary

**Quick Action picker's panel reservation, click-through contentSize, and blobShape call all switched from a hardcoded 420x117pt box to the real Tray's 650x189pt footprint (NotchPillView.traySize.width / trayContentHeight + switcherRowHeight), closing the visible size mismatch between the during-drag preview and the landed Tray state.**

## Performance

- **Duration:** 10 min
- **Started:** 2026-07-19T13:01:00Z
- **Completed:** 2026-07-19T13:11:00Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- All 3 geometry sites (`quickActionPickerFrame` reservation in `positionAndShow()`, the `.quickActionPicker` `contentSize` branch, and `quickActionPickerView()`'s `blobShape` call) now agree pixel-for-pixel on `NotchPillView.traySize.width` / `NotchPillView.trayContentHeight + NotchPillView.switcherRowHeight`
- Removed the orphaned `quickActionPickerContentHeight` constant with zero dangling references left in either file
- Added `testQuickActionButtonFramesFitWithinNewTrayAlignedCard`, proving the 3 Drop/AirDrop/Mail button frames stay fully in-bounds now that the card grew from 420x117 to 650x189

## Task Commits

1. **Task 1: Align the picker's three geometry sites to Tray's real footprint** - `e8b32b8` (fix)
2. **Task 2: Lock in button-frame geometry at the new Tray-aligned dimensions** - `7a76862` (test)

**Plan metadata:** (this commit)

## Files Created/Modified
- `Islet/Notch/NotchWindowController.swift` - `quickActionPickerFrame` reservation and `.quickActionPicker` `contentSize` branch now use `NotchPillView.traySize.width` / `NotchPillView.trayContentHeight + NotchPillView.switcherRowHeight` instead of `expandedSize.width` / the deleted `quickActionPickerContentHeight`
- `Islet/Notch/NotchPillView.swift` - `quickActionPickerView()`'s `blobShape` call now passes `width: Self.traySize.width, height: Self.trayContentHeight + Self.switcherRowHeight`; the orphaned `quickActionPickerContentHeight` constant and its doc comment are deleted
- `IsletTests/DragApproachGeometryTests.swift` - new `testQuickActionButtonFramesFitWithinNewTrayAlignedCard` lock-in test, built from the real production constants rather than hardcoded literals

## Decisions Made
- Reused existing `traySize`/`trayContentHeight`/`switcherRowHeight` constants at all 3 sites (this codebase's own established "geometry three-site rule," already proven by `trayFrame`/`.trayExpanded`) rather than introducing new numbers
- `quickActionPickerContentHeight` deleted outright rather than kept as a dead constant, since no call site references it after the edits

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Debug build and test-build both green. On-device D-08 verification (CR-01/CR-02 click-through trace + visual button tap-zone re-check) is covered by the follow-up checkpoint plan (44-02), not this plan — ready to proceed to 44-02.

---
*Phase: 44-tray-quick-action-width-alignment*
*Completed: 2026-07-19*
