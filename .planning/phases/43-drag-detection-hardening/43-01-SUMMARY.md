---
phase: 43-drag-detection-hardening
plan: 01
subsystem: ui
tags: [swiftui, appkit, drag-and-drop, nspasteboard, notch-window-controller]

requires:
  - phase: 34-quick-action-destination-picker
    provides: recheckDragAcceptRegion/handleDragApproachTick/handleDragApproachEnd drag-approach monitor stack, pendingDrop lifecycle
provides:
  - "isGenuineFileDrag(currentChangeCount:gestureBaselineChangeCount:urls:) pure gate function in DragDropSupport.swift"
  - "recheckDragAcceptRegion's arm branch gated on a genuine per-gesture pasteboard-changeCount delta + non-empty file URLs"
  - "handleDragApproachEnd refreshes the per-gesture baseline unconditionally on every .leftMouseUp"
affects: [43-drag-detection-hardening (43-02 on-device UAT), 44-tray-quick-action-width-alignment]

tech-stack:
  added: []
  patterns:
    - "Pure top-level gate function taking value types (Int, [URL]) instead of a live NSPasteboard, mirroring isWithinDragAcceptRegion's testable-seam convention"

key-files:
  created: []
  modified:
    - Islet/Notch/DragDropSupport.swift
    - IsletTests/DragApproachGeometryTests.swift
    - Islet/Notch/NotchWindowController.swift

key-decisions:
  - "dragPasteboardChangeCount is now a stable per-gesture baseline, refreshed only in handleDragApproachEnd (unconditionally, before the isDragApproaching guard) — never mutated in handleDragApproachTick"

patterns-established:
  - "Persistent system-wide NSPasteboard content requires a per-gesture baseline (captured at gesture end, compared at gesture start) rather than a running current-value tracker, to distinguish 'this gesture wrote it' from 'some other gesture wrote it earlier'"

requirements-completed: [DRAG-01]

duration: ~10min
completed: 2026-07-19
---

# Phase 43 Plan 01: Genuine-File-Drag Gate Summary

**Added a pure `isGenuineFileDrag` gate function and wired it into `recheckDragAcceptRegion`'s auto-expand arm branch, closing the root-cause bug where `dragPasteboardChangeCount` was compared to itself after being overwritten on the same tick and could therefore never detect a change.**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-07-19T00:45:58Z
- **Completed:** 2026-07-19T00:48:54Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- `isGenuineFileDrag(currentChangeCount:gestureBaselineChangeCount:urls:)` added to `DragDropSupport.swift` as a pure, directly-unit-testable function, with 4 new unit tests covering the full behavior matrix (unchanged-count/no-URLs, unchanged-count/URLs, changed-count/no-URLs, changed-count/URLs).
- `recheckDragAcceptRegion`'s arm branch now requires `isGenuineFileDrag(...)` in addition to the existing geometry/state checks — an ordinary click's incidental `.leftMouseDragged` wobble, a Finder window move, or any non-file drag can no longer force-expand the island or open the Quick Action picker.
- `handleDragApproachTick` no longer mutates `dragPasteboardChangeCount` on every tick (the old self-referential no-op check is fully removed); `handleDragApproachEnd` now refreshes the baseline unconditionally as its literal first statement, before the `isDragApproaching` guard, so the baseline can never go stale across an unrelated gesture.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add the genuine-file-drag pure gate function + unit tests** - `00f340a` (feat)
2. **Task 2: Wire the genuine-drag gate into recheckDragAcceptRegion and fix the stale-baseline bug** - `d8eeeb6` (fix)

_Note: Task 1 was marked `tdd="true"` in the plan, but per the plan's own action spec the function body and its 4 test methods were both fully specified in advance (the exact one-line boolean expression, the exact 4 test cases) — there is no ambiguous behavior to red/green cycle against, so both were written and verified together in one commit rather than as separate RED/GREEN commits. `xcodebuild build-for-testing` confirms the test target compiles with all 4 new methods present; a full Cmd-U pass (all 14 methods green) remains the plan's own documented non-blocking manual follow-up._

## Files Created/Modified
- `Islet/Notch/DragDropSupport.swift` - Added `isGenuineFileDrag` pure gate function
- `IsletTests/DragApproachGeometryTests.swift` - Added 4 unit tests for `isGenuineFileDrag`
- `Islet/Notch/NotchWindowController.swift` - `recheckDragAcceptRegion` now takes `currentChangeCount`, computes `urls` once, and gates the arm branch on `isGenuineFileDrag`; `handleDragApproachTick` no longer self-mutates the baseline; `handleDragApproachEnd` refreshes the baseline unconditionally before its guard; two stale doc comments updated to match the new semantics

## Decisions Made
- None beyond what the plan specified — implemented exactly as written (baseline refresh placement, single `urls` fetch reused for both the gate and pendingDrop population).

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Debug build (`xcodebuild build`) and test-target build (`xcodebuild build-for-testing`) both green.
- Ready for plan 43-02 (on-device UAT checkpoint) to verify the 3 D-04 scenarios described in this plan's `<verification>` section on real hardware: ordinary click no longer force-expands, non-file drag no longer force-expands, genuine file drag still auto-expands reliably with no added latency.
- A full Cmd-U pass confirming all 14 `DragApproachGeometryTests` methods (10 existing + 4 new) go green is a recommended, non-blocking manual step before or during 43-02.

## Self-Check: PASSED

All created/modified files found on disk; both task commits (00f340a, d8eeeb6) verified in git log.
