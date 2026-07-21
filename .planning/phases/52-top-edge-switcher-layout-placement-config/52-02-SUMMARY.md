---
phase: 52-top-edge-switcher-layout-placement-config
plan: 02
subsystem: ui
tags: [swiftui, appstorage, notch-geometry, view-switcher, matched-geometry-effect]

# Dependency graph
requires:
  - phase: 52-01
    provides: SelectedView(String/Hashable/CaseIterable), orderedSlotIcons(...), ActivitySettings.SwitcherLayout enum + switcher keys, topEdgeCutoutGap(...)
  - phase: 45-view-switcher-morph-fix
    provides: tabContentView single-call-site structural-identity fix, tabWidth/tabHeight pattern
provides:
  - NotchPillView.orderedSlotViews / icon(for:) — the one shared ordering+icon source both switcherRow (pill) and topEdgeSwitcherRow (top-edge) read
  - NotchPillView.switcherRow now data-driven (ForEach over orderedSlotViews, always 4 children)
  - NotchPillView.totalHeight — internal computed property, the pill-layout-only switcherRowHeight gate mirrored from blobShape's showsPillRow
  - NotchPillView.topEdgeSwitcherRow / topEdgeCutoutWidth — the new top-edge icon row itself
  - NotchWindowController.visibleContentZone()'s switcherHeight now gated on switcherLayout == .pill
affects: [52-03-settings-ui, 52-04-on-device-uat]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "blobShape's showsPillRow = showSwitcher && switcherLayout == .pill — splits 'reserve switcher-sized content height' (baseHeight, layout-independent) from 'show the pill row' (layout-dependent), preventing the Pitfall-1 content-height regression"
    - "Three-site height-math fix: blobShape's showsPillRow, body's totalHeight, and NotchWindowController.visibleContentZone()'s layout-gated switcherHeight all read the same switcherLayout signal independently, no shared plumbing"
    - "topEdgeSwitcherRow computes its own hasNotch/cutout geometry independently (selectTargetScreen + topEdgeCutoutGap), no controller plumbing, mirroring NotchWindowController.currentBuiltin()'s existing pattern"

key-files:
  created: []
  modified:
    - Islet/Notch/NotchPillView.swift
    - Islet/Notch/NotchWindowController.swift
    - IsletTests/NotchPillViewTests.swift

key-decisions:
  - "icon(for:) extracted once and reused verbatim by both switcherRow and topEdgeSwitcherRow (D-03) — exactly one place maps SelectedView to (systemName, action)"
  - "blobShape's switcherLayout parameter defaults to .pill so the 2 other blobShape call sites (quickActionPickerView, onboardingCarousel) — both already passing showSwitcher: false or omitting it — need zero changes; only tabContentView passes a real value"

requirements-completed: []

# Metrics
duration: 20min
completed: 2026-07-21
---

# Phase 52 Plan 02: Top-Edge Switcher Rendering (NotchPillView) Summary

**switcherRow's icon order is now data-driven from 4 slot @AppStorage values, blobShape/totalHeight's height math correctly excludes only the pill row's height in top-edge mode (content-box height unchanged), and a new topEdgeSwitcherRow renders 4 icons flanking the camera cutout using the real notch-cutout-gap formula.**

## Performance

- **Duration:** 20 min
- **Started:** 2026-07-21 (continuation of Plan 52-01, same session)
- **Completed:** 2026-07-21T17:03:53+02:00
- **Tasks:** 3 completed
- **Files modified:** 3

## Accomplishments
- `switcherRow`'s hardcoded 4-button HStack is now a `ForEach` over `orderedSlotViews` (always exactly 4 children — Phase 45 structural-identity rule preserved), defaulting to today's exact Home/Tray/Calendar/Weather order and reflecting the 4 slot `@AppStorage` overrides live, no relaunch (SWITCH-04).
- `blobShape` gained a `switcherLayout` parameter and a `showsPillRow = showSwitcher && switcherLayout == .pill` split, so top-edge mode's content area keeps `switcherContentHeight` (196pt) exactly as pill mode does — only the pill row's own `+switcherRowHeight` (44pt) and the `switcherRow` view itself are omitted (D-06). The same gate is mirrored in the extracted `totalHeight` computed property (body's outer `.frame`) and in `NotchWindowController.visibleContentZone()`'s `switcherHeight` — the three-site fix RESEARCH.md flagged.
- `topEdgeSwitcherRow` renders 4 `navCircleButton`s split 2-and-2 around a `Color.clear` center spacer sized via `topEdgeCutoutGap(...)` (never `auxLeftWidth + auxRightWidth`), reusing `orderedSlotViews`/`icon(for:)` from Task 1 so both layouts share one ordering source (D-03). Wired into `blobShape`'s `content()` overlay, gated on `showSwitcher && switcherLayout == .topEdge`, rendering inside the already-reserved `cameraClearance` band with zero extra height.

## Task Commits

Each task was committed atomically:

1. **Task 1: Data-driven switcherRow (D-03)** — `282467e` (feat)
2. **Task 2: Height-math three-site fix (Pitfall 1, D-06)** — `4d7f70b` (fix)
3. **Task 3: topEdgeSwitcherRow view + wiring (D-04/D-05, SWITCH-03)** — `1ced860` (feat)

## Files Created/Modified
- `Islet/Notch/NotchPillView.swift` — 4 slot `@AppStorage` vars, `switcherLayout` `@AppStorage`, `orderedSlotViews`/`icon(for:)`, data-driven `switcherRow`, `blobShape`'s `switcherLayout`/`showsPillRow`, extracted `totalHeight`, `topEdgeCutoutWidth`/`topEdgeSwitcherRow`
- `Islet/Notch/NotchWindowController.swift` — `visibleContentZone()`'s `switcherHeight` now reads `ActivitySettings.SwitcherLayout` (`?? .pill` fallback, T-52-02) alongside the existing `switcherRowShowing` boolean
- `IsletTests/NotchPillViewTests.swift` — `testOrderedSlotViewsDefaultsToTodaysPillOrder`, `testOrderedSlotViewsReflectsUserDefaultsOverride`, `testTotalHeightExcludesSwitcherRowHeightOnlyInTopEdgeLayout`

## Decisions Made
None beyond what's captured in `key-decisions` above — plan executed exactly as written, following the plan's own literal task text (parameter names, gate expressions, insertion points) throughout.

## Deviations from Plan

**1. [Cosmetic, not a Rule 1-4 deviation] Reworded `topEdgeCutoutWidth`'s doc comment to avoid a double grep match**
- **Found during:** Task 3 acceptance-criteria verification
- **Issue:** The plan's acceptance criterion `grep -c "topEdgeCutoutGap(" Islet/Notch/NotchPillView.swift == 1` expects exactly one occurrence, but my first-draft doc comment above `topEdgeCutoutWidth` also spelled out `topEdgeCutoutGap(...)` by name, producing 2 matches (1 comment + 1 real call).
- **Fix:** Reworded the comment to say "Plan 52-01's pure NotchGeometry helper below" instead of naming the function directly — zero code/behavior change, purely a comment wording fix so the grep-based acceptance check (and any future automated verifier reusing the same pattern) sees exactly the 1 real call site.
- **Files modified:** `Islet/Notch/NotchPillView.swift`
- **Commit:** `1ced860` (folded into Task 3's commit, not a separate commit — caught before Task 3 was committed)

## Issues Encountered
None. Debug build green after every task; targeted test runs (`NotchPillViewTests`, `NotchGeometryTests`) green throughout — 27/27 tests passing after Task 3, zero regressions in `testShelfStripVisibleIsAlwaysFalse`/`testTabWidthHeightMatchesKnownPerCaseValues` or any pre-existing `NotchGeometryTests` case.

## User Setup Required

None — no external service configuration required.

## Known Stubs

None. `topEdgeSwitcherRow` is fully wired to live `@AppStorage` slot state and real notch geometry; nothing renders from hardcoded/mock data.

## Threat Flags

None beyond what the plan's own `<threat_model>` already anticipated (T-52-02, the `?? .pill` fallback on `NotchWindowController`'s manual `SwitcherLayout(rawValue:)` read — implemented exactly as specified).

## Next Phase Readiness

The rendering layer is complete and self-consistent: `switcherRow` reorders from 4 slot values, `topEdgeSwitcherRow` exists and reuses `navCircleButton`/`orderedSlotViews`/`icon(for:)` verbatim, and the click-through geometry (`NotchWindowController.visibleContentZone()`) shrinks in lockstep with the rendered content in top-edge mode. However, **there is currently no way to actually reach `.topEdge` layout or a non-default slot assignment from the running app** — `switcherLayout`/the 4 slot keys have no Settings UI yet (that's Plan 52-03's "Switcher" sidebar section, D-07). SWITCH-03/SWITCH-04 are therefore intentionally left `Pending` in REQUIREMENTS.md (not marked complete by this plan) — mirrors this project's own Phase 45 SWITCH-01/02 precedent (left Pending until the on-device UAT plan, 52-04, confirms the feature actually works end-to-end on real hardware, including the flagged tight 36pt-in-42pt `cameraClearance` fit, RESEARCH.md Pitfall 3/D-04). Plan 52-03 (Settings UI) can now write against real, tested `@AppStorage` keys with zero forward-declaration.

---
*Phase: 52-top-edge-switcher-layout-placement-config*
*Completed: 2026-07-21*

## Self-Check: PASSED

All 4 modified/created files (this SUMMARY.md, `NotchPillView.swift`, `NotchWindowController.swift`, `NotchPillViewTests.swift`) verified present on disk; all 3 task commits (282467e, 4d7f70b, 1ced860) verified present in git log.
