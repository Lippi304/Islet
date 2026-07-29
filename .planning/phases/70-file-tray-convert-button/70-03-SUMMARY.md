---
phase: 70-file-tray-convert-button
plan: 03
subsystem: controller
tags: [swift, appkit, drag-drop, image-conversion]

# Dependency graph
requires:
  - phase: 70-01
    provides: "ImageConversionService.swift (ImageFormat enum, convert, isImageFile), computeQuickActionButtonFrames(card:count:), IslandPresentationState.isShowingConvertFormats"
  - phase: 70-02
    provides: "NotchPillView.swift Convert chip + formatTileRow() (view layer only, no controller wiring)"
provides:
  - "NotchWindowController.handleDragApproachEnd(): stage-first hit-test branch, D-06 enabled-gate on all 4 main-row buttons, format-tile dispatch"
  - "NotchWindowController.handleQuickActionConvert(to:): real per-item ImageIO conversion + shelfCoordinator.append landing"
  - "NotchWindowController.isConvertEnabled / airDropAvailable / mailAvailable: controller-side gate flags"
affects: [70-04-file-tray-convert-button]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Controller-side enabled gate computed independently of the view's identical inline expression (never threaded as a value) — the controller needs its own copy since it's the one place a release point is actually dispatched"
    - "Stage-first hit-test branch: handleDragApproachEnd() checks presentationState.isShowingConvertFormats BEFORE indexing into the switch, so the same quickActionButtonFrames array serves two different button semantics depending on stage"

key-files:
  created: []
  modified:
    - Islet/Notch/NotchWindowController.swift

key-decisions:
  - "computeQuickActionButtonFrames's call site updated to count: 4 (not a second call site for the format-tile row) — main row (4 buttons) and format-tile row (4 tiles) are both exactly 4 equal-width items in the identical card, so one call/one array serves both stages"
  - "handleQuickActionConvert mirrors ShelfFileStore.makeSessionCopy's staging convention (NSTemporaryDirectory()/IsletShelf/<uuid>/) directly rather than calling that function, since it only does a byte copy and cannot transcode"

patterns-established: []

requirements-completed: [D-01, D-03, D-04, D-05, D-06]

# Metrics
duration: ~20min
completed: 2026-07-29
---

# Phase 70 Plan 03: Convert Button Controller Wiring Summary

**`handleDragApproachEnd()` now branches on the format-tile stage before indexing, gates all 4 main-row buttons behind their enabled flag (closing the dormant D-06 bug), and `handleQuickActionConvert(to:)` performs the real per-item ImageIO conversion + Tray landing — closing out the deferred `NotchWindowController.swift:1446` compile error from Plan 70-01.**

## Performance

- **Duration:** ~20 min
- **Started:** 2026-07-29 (immediately after 70-02)
- **Completed:** 2026-07-29
- **Tasks:** 2/2 completed
- **Files modified:** 1

## Accomplishments
- Fixed the dormant D-06 bug for ALL 4 main-row buttons (Drop/AirDrop/Mail/Convert), not just Convert: a release on a dimmed/disabled button is now correctly a no-op
- Convert tap enters the format-tile stage without committing (no discard, no dismiss) — D-01
- Format-tile release converts the whole batch via `ImageConversionService.convert` and lands successes in Tray via the exact same `shelfCoordinator.append` call `handleQuickActionDrop()` already uses — D-03/D-04
- Every dismiss/discard path (off-target release, `discardPendingDrop()`, a fresh drop's arm branch) resets `isShowingConvertFormats` so no stale stage leaks across drops
- Closed the Plan 70-01-deferred `computeQuickActionButtonFrames(card:)` call site — updated to `count: 4`, one call serves both stages
- Full project build succeeds; full XCTest suite green (580 tests, 7 pre-existing unrelated failures, 0 new)

## Task Commits

Each task was committed atomically:

1. **Task 1: D-06 gate fix + Convert stage-entry dispatch + format-tile hit-test branch** - `d571443` (feat)
2. **Task 2: handleQuickActionConvert(to:) — real conversion-and-landing flow + stage-flag resets** - `2738a4f` (feat)

_Task 1's own `xcodebuild build` verification step genuinely failed with exactly one error ("cannot find 'handleQuickActionConvert' in scope") — this is the plan's own acknowledged transitional state (Task 1's action text explicitly says the function is "implemented in Task 2 of this plan"), the same deferred-build-error pattern Plan 70-01 established. Confirmed it was the ONLY error before committing Task 1, then closed it in Task 2._

## Files Created/Modified
- `Islet/Notch/NotchWindowController.swift` — `airDropAvailable`/`mailAvailable` constants, `isConvertEnabled` computed property, `computeQuickActionButtonFrames` call site updated to `count: 4`, `handleDragApproachEnd()` stage-first hit-test branch with D-06 gates on all 4 main-row cases, new `handleQuickActionConvert(to:)`, `isShowingConvertFormats` resets in `discardPendingDrop()`, the off-target-release branch, and `recheckDragAcceptRegion()`'s arm branch

## Decisions Made
- `isConvertEnabled` is computed independently on the controller side (not threaded from the view) — mirrors D-05's own precedent from Plan 70-02, since the controller needs its own gate at hit-test time regardless of what the view renders.
- `handleQuickActionConvert` stages converted files at `NSTemporaryDirectory()/IsletShelf/<uuid>/`, matching `ShelfFileStore.makeSessionCopy`'s exact convention, but does not call that function directly (it only performs a byte copy and cannot transcode).

## Deviations from Plan

### Auto-fixed Issues

None — plan executed exactly as written, including its own acknowledged Task-1/Task-2 forward-reference (see Task Commits note above).

**Total deviations:** 0.

## Issues Encountered

**Pre-existing test failures (not a regression):** the full suite run after Task 2 shows 7 failures (4x `LicenseStateTests`, 3x `SettingsViewTests`), none touching any file this plan modified. `LicenseStateTests` (4) and two of the three `SettingsViewTests` failures (`testProductivityCardsAllNew`, `testSystemHUDCardsExistingBeforeNew`) were already documented pre-existing in `65-quick-actions-bar/deferred-items.md` and `67.1-.../deferred-items.md`. The third, `testSystemHUDCardsCount`, was separately already documented pre-existing in `62-timer-pomodoro/deferred-items.md` — this project's various phase summaries had cited "6 pre-existing failures" without ever reconciling that third SettingsViewTests failure into a single running count; the real total across the codebase's existing deferred-items.md files is 7, and none are new here. Confirmed via `git diff` reasoning: none of `SettingsView.swift`, `ActivityCard.swift`, or the license subsystem was touched by either of this plan's two commits.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- `NotchWindowController.swift` compiles clean; the project-wide build error deferred since Plan 70-01 is fully closed.
- Convert's full stack (view → stage flag → controller dispatch → real ImageIO conversion → Tray landing) is wired end-to-end and ready for Plan 70-04's on-device UAT checkpoint.

---
*Phase: 70-file-tray-convert-button*
*Completed: 2026-07-29*

## Self-Check: PASSED

All modified files confirmed present on disk; both task commits (`d571443`, `2738a4f`) confirmed in git log.
