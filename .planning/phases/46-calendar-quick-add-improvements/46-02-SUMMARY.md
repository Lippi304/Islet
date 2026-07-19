---
phase: 46-calendar-quick-add-improvements
plan: 02
subsystem: ui
tags: [swiftui, calendar, quick-add, layout]

requires:
  - phase: 46-calendar-quick-add-improvements
    plan: 01
    provides: QuickAddPopover Starts/Ends/Due DatePicker rows, widened onSubmit/onQuickAdd (QuickAddKind, String, Date, Date?)
provides:
  - handleQuickAdd(_:title:start:end:) forwarding real picked dates to CalendarService
  - "+ Add" trigger at the day-list column's left edge
  - dayEventsList 12pt/8pt row padding + 8pt spacing
  - calendarWidth (472) and dedicated calendarContentHeight (220) constants
affects: [46-03-onsite-verification]

tech-stack:
  added: []
  patterns:
    - "Per-tab tabHeight override (calendarContentHeight) mirroring the existing trayContentHeight/weatherContentHeight precedent — switcherContentHeight stays the shared default for Home/default cases"

key-files:
  created: []
  modified:
    - Islet/Notch/NotchWindowController.swift
    - Islet/Notch/NotchPillView.swift
    - IsletTests/NotchPillViewTests.swift

key-decisions:
  - "No deviations from plan — both tasks implemented exactly as specified in 46-02-PLAN.md's <interfaces> block"

requirements-completed: [CALVIEW-05, CALVIEW-06, CALVIEW-07]

duration: 9min
completed: 2026-07-19
---

# Phase 46 Plan 02: NotchWindowController Wiring + Layout Polish Summary

**Wired QuickAddPopover's real picked Start/End/Due dates into `CalendarService.createEvent`/`createReminder` (closing Plan 46-01's loop), flipped the "+ Add" trigger to the day-list column's left edge, bumped day-list row padding, and gave Calendar its own 472x220 size independent of the shared switcher constant.**

## Performance

- **Duration:** 9 min
- **Completed:** 2026-07-19
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- `handleQuickAdd(_ kind: QuickAddKind, title: String, start: Date, end: Date?)` replaces the old hardcoded `calendarViewState.selectedDay`/`day.addingTimeInterval(3600)` path — Events and Reminders now save with the user's actual picked dates (CALVIEW-05). The `end ?? start.addingTimeInterval(3600)` fallback is defensive only (QuickAddPopover's Event submit always supplies a real `end`).
- The `onQuickAdd` wiring closure at the `NotchPillView` construction site forwards all 4 arguments through, closing the gap Plan 46-01 deliberately left open.
- `dayListColumn`'s "+ Add" trigger `HStack` reordered — `QuickAddPopover` now renders first (left edge, next to the month-grid/day-list divider), `Spacer()` pushes remaining space right, instead of the previous right-edge/clipped placement (CALVIEW-06, D-06).
- `dayEventsList` row padding bumped from 8h/5v/6-spacing to 12h/8v/8-spacing (CALVIEW-07, D-09) — no change to the row's background fill, corner radius, or title truncation modifiers.
- New `static let calendarContentHeight: CGFloat = 220` added alongside `calendarWidth`, replacing `switcherContentHeight` in `tabHeight`'s `.calendarExpanded` case only; `switcherContentHeight` (196) is untouched and still serves the `default:` (Home/NowPlaying) case via `homeContentHeight`. `calendarWidth` bumped 460 -> 472 (D-08/D-10).
- `NotchPillViewTests.testTabWidthHeightMatchesKnownPerCaseValues`'s Calendar assertion updated in lockstep to 472/220.

## Task Commits

1. **Task 1: Wire real picked dates into NotchWindowController.handleQuickAdd** - `5cdc192` (feat)
2. **Task 2: Button placement, row padding, calendarWidth/calendarContentHeight + regression test update** - `4b004b1` (feat)

**Plan metadata:** (this commit)

## Files Created/Modified
- `Islet/Notch/NotchWindowController.swift` - `handleQuickAdd` widened to accept/forward `start`/`end`; `onQuickAdd` closure wiring updated to pass all 4 args
- `Islet/Notch/NotchPillView.swift` - `dayListColumn`'s trigger `HStack` order flipped; `dayEventsList` padding/spacing bumped; `calendarWidth` 460->472; new `calendarContentHeight` constant (220); `tabHeight`'s `.calendarExpanded` case now reads it
- `IsletTests/NotchPillViewTests.swift` - Calendar regression assertion updated to 472/220

## Decisions Made
None beyond what the plan specified — both tasks matched the `<interfaces>` block's exact pre-confirmed current state with zero drift.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Plan 46-03 (on-device verification, checkpoint-driven) can now confirm: the real end-to-end create-event/create-reminder flow with picked dates, the button's visible left-edge position with no clipping, the roomier row padding actually rendering without cramping, and D-07's forced-trailing popover direction re-verified at the button's new position.
- Debug build green after both tasks; `xcodebuild -scheme Islet -destination 'platform=macOS' build` succeeds.
- No blockers for Plan 46-03.

---
*Phase: 46-calendar-quick-add-improvements*
*Completed: 2026-07-19*

## Self-Check: PASSED
