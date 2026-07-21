---
phase: 52-top-edge-switcher-layout-placement-config
plan: 01
subsystem: ui
tags: [swiftui, appstorage, notch-geometry, view-switcher]

# Dependency graph
requires:
  - phase: 45-view-switcher-morph-fix
    provides: SelectedView enum, ViewSwitcherState, existing switcherRow ordering
  - phase: 15-16-notchgeometry-di-seams
    provides: notchSize(...) pure geometry function
provides:
  - SelectedView is @AppStorage-compatible (String/Equatable/Hashable/CaseIterable)
  - orderedSlotIcons(leftOuter:leftInner:rightInner:rightOuter:) shared slot-ordering function
  - ActivitySettings.SwitcherLayout enum (.pill/.topEdge) + switcherLayoutKey
  - 4 independent per-slot @AppStorage keys (switcherSlotLeftOuterKey/LeftInnerKey/RightInnerKey/RightOuterKey)
  - topEdgeCutoutGap(...) pure function for the real camera-cutout width
affects: [52-02-notchpillview-rendering, 52-03-settings-ui]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "One shared ordering-projection function (orderedSlotIcons) consumed by both switcher layouts, per D-03"
    - "One-key-per-value @AppStorage convention extended to 4 independent slot keys (never a single encoded array)"

key-files:
  created: []
  modified:
    - Islet/Notch/ViewSwitcherState.swift
    - Islet/ActivitySettings.swift
    - Islet/Notch/NotchGeometry.swift
    - IsletTests/NotchPillViewTests.swift
    - IsletTests/ActivitySettingsTests.swift
    - IsletTests/NotchGeometryTests.swift

key-decisions:
  - "orderedSlotIcons(...) does no deduplication/validation — duplicate slot assignments are intentionally allowed, matching this codebase's no-Picker-validation convention"
  - "topEdgeCutoutGap(...) is a thin wrapper around notchSize(...).width, not a reimplementation, so the two never drift"

patterns-established:
  - "SelectedView(rawValue:) / SwitcherLayout(rawValue:) both return nil on corrupted UserDefaults values — every READ site in Plans 52-02/52-03 must apply a `?? .home` / `?? .pill` fallback (T-52-01)"

requirements-completed: [SWITCH-03, SWITCH-04]

# Metrics
duration: 25min
completed: 2026-07-21
---

# Phase 52 Plan 01: Top-Edge Switcher Data/Config Contracts Summary

**SelectedView made @AppStorage-compatible with a shared orderedSlotIcons(...) projection, ActivitySettings gained a SwitcherLayout enum + 4 independent per-slot keys, and NotchGeometry gained topEdgeCutoutGap(...) reusing notchSize(...)'s verified camera-cutout-width formula.**

## Performance

- **Duration:** 25 min
- **Started:** 2026-07-21T14:48:01Z
- **Completed:** 2026-07-21T14:52:03Z
- **Tasks:** 3 completed
- **Files modified:** 6

## Accomplishments
- `SelectedView` is now `String, Equatable, Hashable, CaseIterable` with zero behavior change at existing call sites; `orderedSlotIcons(...)` is the single shared left-to-right ordering source Plan 52-02 will consume for both the pill and top-edge switcher layouts.
- `ActivitySettings.SwitcherLayout` (.pill default, .topEdge alternate) plus `switcherLayoutKey` and 4 independent per-slot keys (`switcherSlotLeftOuterKey`/`LeftInnerKey`/`RightInnerKey`/`RightOuterKey`) exist, following the codebase's one-key-per-value `@AppStorage` convention, with a bare `SwitcherLayout` typealias mirroring `WeatherStyle`/`MaterialStyle`.
- `topEdgeCutoutGap(...)` gives the future top-edge row the correct camera-cutout width (reusing `notchSize(...)`'s verified formula), never the sum of the two side strips.

## Task Commits

Each task was committed atomically:

1. **Task 1: SelectedView @AppStorage-compatible + orderedSlotIcons pure function** - `243647a` (feat)
2. **Task 2: ActivitySettings SwitcherLayout enum + switcher keys** - `365c8ef` (feat)
3. **Task 3: NotchGeometry topEdgeCutoutGap pure function** - `d1e9ded` (feat)

## Files Created/Modified
- `Islet/Notch/ViewSwitcherState.swift` - SelectedView raw-value enum + orderedSlotIcons(...) free function
- `Islet/ActivitySettings.swift` - SwitcherLayout enum, switcherLayoutKey, 4 slot keys, bare typealias
- `Islet/Notch/NotchGeometry.swift` - topEdgeCutoutGap(...) pure function
- `IsletTests/NotchPillViewTests.swift` - orderedSlotIcons default/duplicate cases + rawValue round-trip test
- `IsletTests/ActivitySettingsTests.swift` - SwitcherLayout parsing/corrupted-fallback + key-name tests
- `IsletTests/NotchGeometryTests.swift` - topEdgeCutoutGap real-width and nil-fallback tests

## Decisions Made
None beyond what's captured in `key-decisions` above — plan executed exactly as written.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

All 3 contracts (`SelectedView`/`orderedSlotIcons`, `ActivitySettings.SwitcherLayout`+slot keys, `topEdgeCutoutGap`) are landed, unit-tested (39 new/existing test assertions across the 3 targeted test files, all green), and the Debug build is green. Plan 52-02 (NotchPillView top-edge rendering) and Plan 52-03 (Settings UI) can now write against real types instead of forward-declared ones. No blockers.

---
*Phase: 52-top-edge-switcher-layout-placement-config*
*Completed: 2026-07-21*

## Self-Check: PASSED

All 6 modified source/test files and the SUMMARY.md itself verified present on disk; all 4 commits (243647a, 365c8ef, d1e9ded, 73f6fff) verified present in git log.
