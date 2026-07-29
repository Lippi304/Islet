---
phase: 70-file-tray-convert-button
plan: 02
subsystem: ui
tags: [swiftui, quick-action-picker, image-conversion]

# Dependency graph
requires:
  - phase: 70-01
    provides: "ImageConversionService.swift (ImageFormat enum, isImageFile), IslandPresentationState.isShowingConvertFormats stage flag"
provides:
  - "quickActionButtonRow(_ pendingDrop: PendingDrop) — 4th 'Convert' chip, enabled state computed inline from pendingDrop.items every render (D-05)"
  - "formatTileRow() — JPG/PNG/HEIC/TIFF format-tile row, shared 'photo' icon, always enabled"
  - "quickActionPickerView(pendingDrop: PendingDrop) — 2-stage Group{if/else} branch on isShowingConvertFormats, same card geometry for both stages"
affects: [70-03-file-tray-convert-button, 70-04-file-tray-convert-button]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "2-stage card render: Group{if/else} on a controller-owned stage flag, wrapped OUTSIDE both branches with the shared .padding modifiers — reuses the same conditional-rendering shape already proven elsewhere in NotchPillView.swift rather than inventing a new one"

key-files:
  created: []
  modified:
    - Islet/Notch/NotchPillView.swift

key-decisions:
  - "Convert's enabled: computed inline as `pendingDrop.items.allSatisfy { ImageConversionService.isImageFile($0.originalURL) }` directly in the HStack call — never a stored/threaded Bool, matching D-05 and avoiding the exact dead-flag pattern airDropAvailable/mailAvailable fell into"
  - "formatTileRow() takes no PendingDrop parameter — all 4 format tiles are unconditionally enabled (the gate already happened at the main row's Convert chip), so it needs no drop-content awareness"

patterns-established: []

requirements-completed: [D-01, D-02, D-05]

# Metrics
duration: ~15min
completed: 2026-07-29
---

# Phase 70 Plan 02: Convert Button + Format-Tile Row (View Layer) Summary

**NotchPillView's Quick Action Picker now renders a 4th dimmed-per-drop-content Convert chip and, on a controller-owned stage flip, a 4-tile JPG/PNG/HEIC/TIFF format row — both reusing the existing `quickActionButton` component verbatim, zero new card geometry.**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-07-29 (immediately after 70-01)
- **Completed:** 2026-07-29
- **Tasks:** 2/2 completed
- **Files modified:** 1

## Accomplishments
- `quickActionButtonRow(_:)` now binds the real `PendingDrop` payload at the render switch and renders a 4th "Convert" chip whose `enabled:` state is computed fresh every render, never cached
- `formatTileRow()` renders the 4 JPG/PNG/HEIC/TIFF tiles with one shared `photo` icon (per 70-UI-SPEC.md's resolved Open Question 1), label text as the only differentiator
- `quickActionPickerView(pendingDrop:)` swaps between the two rows in-place inside the identical `blobShape` call — no card resize for either stage

## Task Commits

Each task was committed atomically:

1. **Task 1: Bind PendingDrop at the render switch, add the Convert chip to the main row** - `c95a37c` (feat)
2. **Task 2: Format-tile row + 2-stage branch inside quickActionPickerView** - `a742169` (feat)

## Files Created/Modified
- `Islet/Notch/NotchPillView.swift` - `case .quickActionPicker(let pendingDrop):` now binds the payload; `quickActionButtonRow(_ pendingDrop: PendingDrop)` adds the Convert chip; new `formatTileRow()`; `quickActionPickerView(pendingDrop:)` branches on `presentationState.isShowingConvertFormats`

## Decisions Made
- No new stored `var convertAvailable: Bool` was added (confirmed via grep, count 0) — Convert's enable state is the first genuinely dynamic `enabled:` flag in this component and is deliberately computed inline to avoid reproducing the `airDropAvailable`/`mailAvailable` dead-flag pattern the phase's own D-06 flags as a bug class.

## Deviations from Plan

### Auto-fixed Issues

None — plan executed exactly as written.

### Minor note (non-issue)

- The plan's Task 2 acceptance criterion `grep -c "presentationState.isShowingConvertFormats"` expected `1`; actual count is `2` because the descriptive comment added above `quickActionPickerView(pendingDrop:)` also mentions the property name in prose. The functional criterion (the `Group`'s `if` condition reading `presentationState.isShowingConvertFormats` exactly once) is met — this is a comment-text match, not a duplicated code path. Not tracked as a Rule 1-4 deviation since it changes no behavior.
- Per this plan's own explicit context ("NotchWindowController.swift currently has ONE known, deliberately-deferred compile error... Do not touch NotchWindowController.swift — that is plan 70-03's job"), the full project build still fails with exactly that one pre-existing error (`NotchWindowController.swift:1446:94: missing argument for parameter 'count'`). `Islet/Notch/NotchPillView.swift` itself introduces zero new compile errors — verified by confirming the full-build error count stayed at 1 both before and after this plan's two tasks landed.

**Total deviations:** 0 auto-fixed. Two documentation notes above, no code impact.

## Issues Encountered

None beyond the pre-existing, plan-documented deferred build error inherited from Plan 70-01 (see Deviations above) — expected to close when Plan 70-03 lands.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- `quickActionButtonRow(_:)`, `formatTileRow()`, and `quickActionPickerView(pendingDrop:)` are all in place for Plan 70-03 to wire the controller-side hit-test dispatch (D-06 gate fix), the `isShowingConvertFormats` stage-flag writes, and the deferred `NotchWindowController.swift:1446` call-site fix.
- **Blocker for full-project build/test verification:** unchanged from 70-01 — the project will not build or run tests until Plan 70-03's call-site update lands. This is expected, not a new blocker.

---
*Phase: 70-file-tray-convert-button*
*Completed: 2026-07-29*

## Self-Check: PASSED

All modified files confirmed present on disk; both task commits (`c95a37c`, `a742169`) confirmed in git log.
