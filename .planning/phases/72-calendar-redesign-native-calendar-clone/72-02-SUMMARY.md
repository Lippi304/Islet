---
phase: 72-calendar-redesign-native-calendar-clone
plan: 02
subsystem: ui
tags: [swiftui, calendar, notchpillview]

# Dependency graph
requires:
  - phase: 72-01
    provides: EventInput.id, eventsByDay grouping, CalendarService.updateEvent/deleteEvent
provides:
  - Locale-aware weekday header row above the month grid (rotatedWeekdaySymbols/weekdayHeaderRow)
  - Inverted today/selected badge styling (today=filled red, selected=red ring, mutually exclusive)
  - Tightened month-header chevron spacing (8pt from month label instead of row's outer edges)
  - Red month/year label, 11px day-number font, 22x22pt day cell (up from 9px/18pt)
affects: [72-03, 72-04]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Locale-aware weekday symbols via Calendar.veryShortWeekdaySymbols rotated by calendar.firstWeekday (never a hardcoded weekday-letter array)"

key-files:
  created: []
  modified:
    - Islet/Notch/NotchPillView.swift

key-decisions:
  - "D-03: today badge and selected badge are mutually exclusive on one cell; today (filled red circle) wins visually over selected (red ring) when a day is both"
  - "D-04: has-events dot indicator left untouched (KEEP, out of scope)"
  - "D-05: month/year label recolored white -> red"
  - "D-10: chevrons centered 8pt from month label instead of the row's outer edges"
  - "D-11: day-number font 9->11px, calendarCellSize 18->22pt"

patterns-established:
  - "weekdayHeaderRow reuses Self.calendarCellSize/calendarCellGap symbolically so it stays column-aligned with the LazyVGrid beneath it after future cell-size changes"

requirements-completed: [CALVIEW-09]

# Metrics
duration: 25min
completed: 2026-07-30
---

# Phase 72 Plan 02: Month-grid visual redesign Summary

**Added a net-new locale-aware weekday-letter header row, inverted the today/selected day-badge colors to red, tightened chevron spacing, and bumped the day-number font/cell size in `monthGridColumn` to match the macOS Calendar reference.**

## Performance

- **Duration:** 25 min
- **Started:** 2026-07-30T20:52:00Z
- **Completed:** 2026-07-30T23:01:00Z (includes ~8min full XCTest suite run)
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments
- New `rotatedWeekdaySymbols`/`weekdayHeaderRow` pair renders a locale-aware Su-Mo-Tu... (or locale equivalent) header row above the day grid, column-aligned via shared `Self.calendarCellSize`/`calendarCellGap`
- Chevrons now sit 8pt from the month/year label (was pinned to the row's outer edges via bare `Spacer()`s)
- Today badge is a solid red circle; a different selected day gets a thin red ring; the two never coexist on one cell (today wins)
- Month/year label is red; day-number font bumped 9->11px inside a 22x22pt cell (was 18x18pt); has-events dot untouched

## Task Commits

Each task was committed atomically:

1. **Task 1: Weekday header row (net-new) + chevron spacing (D-10)** - `29254d3` (feat)
2. **Task 2: Badge swap (D-03) + red month-label/badge accent (D-05) + font/cell-size bump (D-11)** - `118738d` (feat)

**Plan metadata:** (this commit)

## Files Created/Modified
- `Islet/Notch/NotchPillView.swift` - Added `rotatedWeekdaySymbols`/`weekdayHeaderRow`, centered chevron group, red month label, inverted today/selected badge colors, bumped day-number font (9->11px) and `calendarCellSize` (18->22pt)

## Decisions Made
None beyond what the plan already specified (D-03/D-04/D-05/D-10/D-11 all pre-resolved in 72-CONTEXT.md/72-UI-SPEC.md; this plan just implemented them).

## Deviations from Plan

None - plan executed exactly as written. Two of the plan's own grep-based acceptance criteria were false negatives worth noting (not deviations, verified manually instead):
- `grep -n "weekdayHeaderRow"` returns 3 occurrences (doc comment + property definition + call site), not the plan's expected 2 — the extra hit is a comment mentioning the property by name, not a functional issue.
- `grep -n "hasEvents" | grep -c "Circle().fill(Color.white.opacity(0.6))"` returns 0 because that code was already formatted across two lines (`Circle()` / `.fill(...)`) before this plan touched anything — confirmed via `git diff` that the has-events dot block is untouched by either commit (D-04 preserved).

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness

Build clean (`xcodebuild build -scheme Islet -destination 'platform=macOS'` succeeded after both tasks). Full suite: 591 tests, 7 failures — identical failure set to Phase 71 Plan 01's and Phase 72 Plan 01's documented pre-existing baseline (4x `LicenseStateTests` + 3x `SettingsViewTests`, confirmed via `git log` to be untouched by this plan's commits). Zero new failures. Full visual comparison against `reference-macos-calendar-widgets.png` is deferred to Plan 72-04's consolidated on-device UAT, per this plan's own scope.

Ready for Plan 72-03 (whole-month agenda rebuild, out of this plan's scope per D-04).

---
*Phase: 72-calendar-redesign-native-calendar-clone*
*Completed: 2026-07-30*

## Self-Check: PASSED
- FOUND: Islet/Notch/NotchPillView.swift
- FOUND: .planning/phases/72-calendar-redesign-native-calendar-clone/72-02-SUMMARY.md
- FOUND commit: 29254d3
- FOUND commit: 118738d
