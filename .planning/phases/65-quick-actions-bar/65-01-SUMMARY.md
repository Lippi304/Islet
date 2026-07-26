---
phase: 65-quick-actions-bar
plan: 01
subsystem: ui
tags: [swiftui, resolver, appstorage, tdd]

requires:
  - phase: 34-quick-action-destination-picker
    provides: precedent for a "QuickAction*"-prefixed naming collision to avoid (PendingDrop/quickActionPicker)
provides:
  - QuickActionsBarCatalog.Action (9-case enum, .none sentinel) + orderedQuickActionsBarSlots(_:) pure projection
  - 16 new ActivitySettings keys (8 slot keys + 8 launch-target keys), independent AppStorage namespace
  - SelectedView.quickActions (5th switcher-tab case)
  - IslandPresentation.quickActionsBarExpanded, resolve() branch, showsSwitcherRow(for:) inclusion
  - NotchPillView's presentationSwitch + icon(for:) updated to exhaustively cover the 2 new enum cases
affects: [65-02, 65-03, 65-04, 65-05, 65-06, 65-07, 65-08]

tech-stack:
  added: []
  patterns:
    - "Fixed 8-slot catalog + per-slot independent AppStorage keys (mirrors switcherSlot* convention), never a single encoded array"
    - "Pure ordering-projection function (orderedQuickActionsBarSlots) mirroring orderedSlotIcons's single-source-of-truth role"
    - "Enum case + its exhaustive-switch consumers landed in the same commit to keep the build green at every commit boundary"

key-files:
  created:
    - Islet/Notch/QuickActionsBar/QuickActionsBarCatalog.swift
  modified:
    - Islet/ActivitySettings.swift
    - Islet/Notch/ViewSwitcherState.swift
    - Islet/Notch/IslandResolver.swift
    - Islet/Notch/NotchPillView.swift
    - IsletTests/IslandResolverTests.swift
    - Islet.xcodeproj/project.pbxproj

key-decisions:
  - "D-01 confirmed: Quick Actions bar is a 5th switcher-tab catalog entry (selectedView-driven, isExpanded tier), never an ActiveTransient — same precedence tier as Calendar/Weather/Tray/Timer"
  - "QuickActionsBarCatalog.Action.none is the unconfigured-slot sentinel (not Optional), mirroring WeatherStyle's safe-default-on-corruption convention"

patterns-established:
  - "Pattern: QuickActionsBar* naming prefix — every new type in this phase must avoid the bare QuickAction* namespace already used by Phase 34's PendingDrop/quickActionPicker"

requirements-completed: [QACTION-01, QACTION-02]

duration: 25min
completed: 2026-07-26
---

# Phase 65 Plan 01: Quick Actions Bar Contract Summary

**QuickActionsBarCatalog data model (9-case Action enum + 8-slot ordering projection), 16 new ActivitySettings AppStorage keys, and the .quickActionsBarExpanded resolver case wired end-to-end through resolve()/showsSwitcherRow/NotchPillView's two exhaustive switches**

## Performance

- **Duration:** ~25 min
- **Completed:** 2026-07-26T00:44:17Z
- **Tasks:** 2 completed
- **Files modified:** 6 (1 created, 5 modified)

## Accomplishments
- `QuickActionsBarCatalog.Action` (9 cases incl. `.none`) + `orderedQuickActionsBarSlots(_:)` pure projection, established as the single contract file every downstream Quick Actions Bar plan builds against
- 16 new `ActivitySettings` keys (8 slot + 8 launch-target), independent per-position AppStorage namespace
- `.quickActionsBarExpanded` resolver case landed TDD-style (RED test commit, then GREEN implementation commit), verified by 4 new XCTest cases plus the full 96-test `IslandResolverTests` suite
- `NotchPillView.swift`'s `presentationSwitch` and `icon(for:)` both updated in the SAME commit as the new enum cases, so the full-scheme build never had a broken intermediate state

## Task Commits

Each task was committed atomically:

1. **Task 1: QuickActionsBarCatalog.swift contract + ActivitySettings 8-slot key namespace** - `982da79` (feat)
2. **Task 2: .quickActionsBarExpanded resolver case + SelectedView.quickActions (TDD)** - `682fce4` (test, RED) → `7741a08` (feat, GREEN)

**Plan metadata:** _pending final docs commit_

## Files Created/Modified
- `Islet/Notch/QuickActionsBar/QuickActionsBarCatalog.swift` - New file: `Action` enum (9 cases) + `orderedQuickActionsBarSlots(_:)`
- `Islet/ActivitySettings.swift` - 16 new `quickActionsBarSlot*`/`quickActionsBarSlot*LaunchTarget` keys
- `Islet/Notch/ViewSwitcherState.swift` - `SelectedView.quickActions` case added
- `Islet/Notch/IslandResolver.swift` - `.quickActionsBarExpanded` case, `resolve()` branch, `showsSwitcherRow(for:)` inclusion, reserved-slot comment updated to "LANDED (65-01)"
- `Islet/Notch/NotchPillView.swift` - `presentationSwitch`'s grouped case arm + `icon(for:)`'s exhaustive switch both extended
- `IsletTests/IslandResolverTests.swift` - 4 new XCTest cases
- `Islet.xcodeproj/project.pbxproj` - regenerated via `xcodegen generate` to register the new file/directory in the build target

## Decisions Made
- D-01 (Quick Actions bar is a 5th switcher-tab, not an always-visible strip) confirmed exactly as the plan specified — no deviation from the locked resolver-tier placement.
- No new architectural decisions beyond what the plan and its interfaces already locked.

## Deviations from Plan

None - plan executed exactly as written. `xcodegen generate` was run per the plan's own explicit Task 1 instruction (not an ad-hoc deviation) so the new file's `PBXFileReference`/`PBXBuildFile` entries land in the same commit as the file itself.

## Issues Encountered

Full-suite `xcodebuild test -project Islet.xcodeproj -scheme Islet` (this plan's own `<verification>` requirement) surfaced 2 pre-existing failures in `IsletTests/SettingsViewTests.swift` (`testProductivityCardsAllNew`, `testSystemHUDCardsExistingBeforeNew`). Confirmed via `git diff 8342959 HEAD -- Islet/SettingsView.swift IsletTests/SettingsViewTests.swift` (zero diff) that neither file was touched by any commit in this plan — out of scope per the executor's scope-boundary rule, left unfixed and logged in `.planning/phases/65-quick-actions-bar/deferred-items.md` for whichever later 65-* plan next touches `SettingsView.swift`. The scoped `IslandResolverTests` suite (this plan's actual acceptance target) is 96/96 green.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

`QuickActionsBarCatalog.Action`, the 16 `ActivitySettings` keys, and `.quickActionsBarExpanded` are now a stable contract — Plan 02 (action helpers) and later plans (NotchPillView content, SettingsView wiring) can build directly against them without re-deriving the shape. No blockers.

---
*Phase: 65-quick-actions-bar*
*Completed: 2026-07-26*
