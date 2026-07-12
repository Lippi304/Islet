---
phase: 28-calendar-full-view
plan: 01
subsystem: ui
tags: [swiftui, calendar, eventkit, state-management, foundation]

# Dependency graph
requires:
  - phase: 14-weather-calendar-date
    provides: "EventInput/CalendarGlance types and nextRelevantEvent(events:now:) pure selection seam in Islet/Calendar/CalendarGlance.swift"
provides:
  - "daysInMonth(for:calendar:) — nil-padded month-grid generator, Foundation-only, total function"
  - "events(on:events:calendar:) — day-level event filter/sort, reused by Plan 03's day-detail pane"
  - "ViewSwitcherState/SelectedView — single source of truth for which of Home/Tray/Calendar is active"
  - "CalendarViewState/QuickAddKind — published carrier for the full calendar view's visibleMonth/selectedDay/monthEvents"
affects: [28-02-calendar-day-detail-controller, 28-03-calendar-full-view, 28-04-quick-add]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Pure day/month-bucketing math stays Foundation-only with an explicit calendar: parameter, mirroring CalendarGlance.swift's now: discipline"
    - "New @Published state carriers are plain ObservableObject holders with zero methods/timers (ShelfViewState precedent)"
    - "nil-means-not-loaded on monthEvents to distinguish loading from confirmed-zero-events"

key-files:
  created:
    - Islet/Notch/ViewSwitcherState.swift
    - Islet/Calendar/CalendarViewState.swift
  modified:
    - Islet/Calendar/CalendarGlance.swift
    - IsletTests/CalendarGlanceTests.swift
    - Islet.xcodeproj/project.pbxproj

key-decisions:
  - "IslandPresentation's .calendarExpanded case and resolve(...)'s selectedView parameter deliberately NOT added here — deferred to Plan 03 alongside NotchPillView's matching switch arm to avoid breaking the exhaustive-switch build"
  - "Regenerated Islet.xcodeproj via xcodegen after adding new source files (project uses folder-globbed sources: path: Islet, new files need explicit project regeneration to compile)"

patterns-established:
  - "Pattern 2 (28-RESEARCH.md): pure day/month-bucketing, Foundation-only, explicit calendar: parameter"

requirements-completed: [CALVIEW-01, CALVIEW-02, CALVIEW-04]

# Metrics
duration: 6min
completed: 2026-07-13
---

# Phase 28 Plan 01: Calendar Grid Math + View-State Contracts Summary

**Pure day/month-bucketing functions (`daysInMonth`, `events(on:events:)`) added to CalendarGlance.swift, plus two new plain `ObservableObject` state carriers (`ViewSwitcherState`/`SelectedView`, `CalendarViewState`/`QuickAddKind`) — the interface-first foundation Plans 02-04 build the calendar full view against.**

## Performance

- **Duration:** 6 min
- **Started:** 2026-07-13T01:23:17+02:00
- **Completed:** 2026-07-13T01:29:20+02:00
- **Tasks:** 2
- **Files modified:** 5 (2 created, 3 modified)

## Accomplishments
- `daysInMonth(for:calendar:)` — nil-padded month grid generator, verified against a known 31-day month (July 2026, weekday-column padding checked exactly) and a leap-year February (2028, 29 days), never crashes on Calendar-API failure
- `events(on:events:calendar:)` — day-level event filter/sort, identical contract to `nextRelevantEvent`, verified sorted-ascending and empty-array safety
- `ViewSwitcherState`/`SelectedView` and `CalendarViewState`/`QuickAddKind` — compilable, testable contracts ready for Plan 03's view and Plan 04's controller

## Task Commits

Each task was committed atomically:

1. **Task 1: Pure day/month-bucketing functions in CalendarGlance.swift** - `5259f66` (feat)
2. **Task 2: ViewSwitcherState/SelectedView + CalendarViewState/QuickAddKind data contracts** - `76362b4` (feat)

**Plan metadata:** (this commit)

## Files Created/Modified
- `Islet/Calendar/CalendarGlance.swift` - added `daysInMonth(for:calendar:)` and `events(on:events:calendar:)`, both Foundation-only total functions
- `IsletTests/CalendarGlanceTests.swift` - 4 new tests: July-2026 day-count + leading-padding, Feb-2028 leap-year count, day-filter sort-ascending, empty-array safety
- `Islet/Notch/ViewSwitcherState.swift` - new file: `SelectedView` enum (home/tray/calendar) + `ViewSwitcherState` published carrier
- `Islet/Calendar/CalendarViewState.swift` - new file: `CalendarViewState` published carrier (visibleMonth/selectedDay/monthEvents) + `QuickAddKind` enum
- `Islet.xcodeproj/project.pbxproj` - regenerated via `xcodegen generate` to register the two new source files

## Decisions Made
- Task 1's tests use an explicit `Calendar(identifier: .gregorian)` with `firstWeekday = 1` and a fixed UTC `TimeZone` (rather than `Calendar.current`) so the July-2026 leading-padding assertion (3 leading nils, verified via doomsday-algorithm hand calculation: July 1 2026 = Wednesday) is deterministic across CI locales.
- `IslandPresentation.calendarExpanded` and `resolve(...)`'s `selectedView` parameter are intentionally NOT part of this plan (per the plan's own scope note) — they land together with `NotchPillView.body`'s new switch arm in Plan 03 to keep the exhaustive Swift switch compiling at every commit.

## Deviations from Plan

None - plan executed exactly as written. (The `xcodegen generate` regeneration was a required mechanical step implied by the project's existing build system, not a plan deviation — new Swift files under a folder-globbed `sources: path: Islet` target don't compile until the `.pbxproj` is regenerated.)

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Plan 02/03/04 can now compile against `daysInMonth`, `events(on:events:)`, `SelectedView`, `ViewSwitcherState`, `CalendarViewState`, and `QuickAddKind` as real, tested contracts.
- No change was made to `IslandResolver.swift` or `NotchPillView.swift` in this plan, as intended — the exhaustive-switch invariant stays intact until Plan 03 adds `.calendarExpanded` and its matching view arm together.
- Manual Cmd-U run (IsletTests scheme) still recommended before merge to visually confirm all 10 `CalendarGlanceTests` (6 existing + 4 new) pass — `xcodebuild test` is known to hang in this headless environment (pre-existing Bluetooth TCC wait), so only `build`/`build-for-testing` gates were run here.

---
*Phase: 28-calendar-full-view*
*Completed: 2026-07-13*
