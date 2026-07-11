---
phase: 23-shell-parity-rewrite
plan: 01
subsystem: infra
tags: [swift, appkit, nspanel, nsdraggingdestination, xctest]

# Dependency graph
requires:
  - phase: 22-drag-in
    provides: the abandoned NSDraggingDestination spike scaffold this plan removes
provides:
  - A clean NotchPanel with zero Phase-22 drag residue for Phase 24 to build DragApproachDetector against
  - A unit-level regression guard (testPanelHasNoDraggingDestinationResidue) preventing reintroduction
affects: [23-02-notchwindowcontroller-rewrite, 24-drag-in]

# Tech tracking
tech-stack:
  added: []
  patterns: []

key-files:
  created: []
  modified:
    - Islet/Notch/NotchPanel.swift
    - IsletTests/NotchPanelTests.swift

key-decisions:
  - "D-01 executed literally: NSDraggingDestination conformance, registerForDraggedTypes call, and all 4 drag stub methods deleted entirely; no named extension seam left for Phase 24"

patterns-established: []

requirements-completed: [ARCH-01]

# Metrics
duration: 5min
completed: 2026-07-11
---

# Phase 23 Plan 01: NotchPanel Drag-Scaffold Removal Summary

**Deleted the Phase-22 `NSDraggingDestination` spike (conformance + `registerForDraggedTypes` + 4 stub methods) from `NotchPanel.swift`, byte-preserving every other panel-construction property, and added a unit regression guard.**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-07-11T01:29:00Z (approx, prior task commit as baseline)
- **Completed:** 2026-07-11T01:34:04Z
- **Tasks:** 2/2 completed
- **Files modified:** 2

## Accomplishments
- `NotchPanel` no longer conforms to `NSDraggingDestination`; zero drag-related code remains in the file
- Every other construction property (styleMask, `ignoresMouseEvents` start value, level, collectionBehavior, `canBecomeKey`/`canBecomeMain`, `isReleasedWhenClosed`, `isOpaque`/`backgroundColor`/`hasShadow`) verified byte-identical to before
- New `testPanelHasNoDraggingDestinationResidue` unit test added to `NotchPanelTests.swift`, all 6 pre-existing tests untouched

## Task Commits

Each task was committed atomically:

1. **Task 1: Delete the D-01 NSDraggingDestination scaffold from NotchPanel.swift** - `6b4ceef` (fix)
2. **Task 2: Add regression assertion to NotchPanelTests.swift** - `0db2892` (test)

## Files Created/Modified
- `Islet/Notch/NotchPanel.swift` - Dropped `NSDraggingDestination` conformance, `registerForDraggedTypes([.fileURL])` call, and the 4 stub drag-delegate methods (`draggingEntered`, `draggingUpdated`, `draggingExited`, `performDragOperation`) plus their SPIKE comment block. All other lines unchanged.
- `IsletTests/NotchPanelTests.swift` - Added `testPanelHasNoDraggingDestinationResidue()` asserting `!(panel is NSDraggingDestination)`.

## Decisions Made
- Followed D-01 (locked decision) literally: fully clean deletion, no named seam/hook left behind for Phase 24's `DragApproachDetector`.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None. The `grep -c "canBecomeKey\|canBecomeMain\|collectionBehavior = \[.canJoinAllSpaces"` acceptance check returned 4 instead of the plan's expected 3 — this is because a pre-existing, unmodified comment on line 27 ("`canBecomeKey==false` makes that focus-safe") also matches the grep pattern. Confirmed by reading the file directly: no code line was added, removed, or altered beyond the plan's exact deletion boundary. Not a deviation from the plan's actual intent.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

`Islet/Notch/NotchPanel.swift` is now a clean, drag-free panel shell ready for Phase 24's `DragApproachDetector` to build against from scratch. `xcodebuild -project Islet.xcodeproj -scheme Islet -configuration Debug build` succeeds after both tasks. Full Cmd-U test execution (including the new regression test) remains deferred to the phase-gate consolidated UAT in Plan 23-04, per project convention (`xcodebuild test` hangs headlessly).

## Self-Check: PASSED

- FOUND: Islet/Notch/NotchPanel.swift
- FOUND: IsletTests/NotchPanelTests.swift
- FOUND: 6b4ceef (git log)
- FOUND: 0db2892 (git log)

---
*Phase: 23-shell-parity-rewrite*
*Completed: 2026-07-11*
