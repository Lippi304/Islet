---
phase: 72-calendar-redesign-native-calendar-clone
plan: 04
subsystem: ui
tags: [swiftui, eventkit, calendar, hover-affordances, notch-panel]

# Dependency graph
requires:
  - phase: 72-01
    provides: CalendarService.updateEvent/deleteEvent, EventInput.id
  - phase: 72-03
    provides: onEventEdit/onEventDelete report-intent closures, EventRow, EventEditPopover
provides:
  - "handleEventEdit/handleEventDelete controller handlers, wired to the real CalendarService update/delete calls"
  - "Single-day agenda list (today/selected day only) — supersedes Plan 72-03's whole-month day-grouped agenda"
  - "Month/Year picker popover (D-13) for direct month/year jumps"
  - "4 new white hover affordances: day-cell ring (D-14), circular chevron hover (D-15), agenda-row outline (D-16), + Add border (D-17)"
  - "On-device UAT approval closing CALVIEW-08/09"
affects: [calendar-view, notch-panel-hover-mechanics]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Absolute-value report closures (onCalendarMonthYearSelect) mirror onCalendarDaySelect's 'report a Date, no math in the view' shape rather than onCalendarMonthChange's delta shape, when the caller already knows the exact target"
    - "Local @State isHovering per-cell view structs (DayCell, ChevronHoverButton) for hover affordances inside a ForEach, mirroring EventRow/TransportButton's established pattern"

key-files:
  created: []
  modified:
    - Islet/Notch/NotchWindowController.swift
    - Islet/Notch/NotchPillView.swift
    - Islet/Calendar/CalendarGlance.swift
    - IsletTests/CalendarGlanceTests.swift
    - .planning/phases/72-calendar-redesign-native-calendar-clone/72-CONTEXT.md

key-decisions:
  - "D-01/D-02 superseded: agenda reverted from whole-month day-grouped to single-day (today/selected), after real on-device UAT found the whole-month version didn't match what the user wanted"
  - "D-13: Month/Year label opens a Month/Year picker popover (reuses QuickAddPopover's chrome)"
  - "D-14: white circle hover-ring on month-grid day cells"
  - "D-15: circular white hover background on prev/next chevrons, mirroring the Now Playing transport-button hover pattern"
  - "D-16: white outline hover border on agenda event rows, distinct from the existing hover-reveal delete icon"
  - "D-17: white hover border on the + Add button"

patterns-established:
  - "When a view already knows the exact target value (not a delta), report it via a plain closure mirroring onCalendarDaySelect rather than reusing a delta-based closure and doing math in the view"

requirements-completed: [CALVIEW-08, CALVIEW-09]

# Metrics
duration: 53min
completed: 2026-07-31
---

# Phase 72 Plan 04: Event CRUD Wiring + On-Device UAT (with live Task 2 design revision) Summary

**Wired handleEventEdit/handleEventDelete to real CalendarService calls, then reverted the whole-month agenda to single-day and added 5 new white hover affordances after real on-device UAT found the original whole-month design didn't match what the user wanted — re-verified and approved.**

## Performance

- **Duration:** ~53 min (23:28–00:21)
- **Started:** 2026-07-30T23:28:25+02:00
- **Completed:** 2026-07-31T00:21:02+02:00
- **Tasks:** 2 (Task 1 automated wiring, Task 2 on-device UAT — required one live design revision before final approval)
- **Files modified:** 5 (`NotchWindowController.swift`, `NotchPillView.swift`, `CalendarGlance.swift`, `CalendarGlanceTests.swift`, `72-CONTEXT.md`)

## Accomplishments

- `handleEventEdit`/`handleEventDelete` controller handlers added, forwarding straight to `CalendarService.updateEvent`/`deleteEvent` and refreshing the month on completion (mirrors `handleQuickAdd`'s exact shape); wired into the `NotchPillView(...)` call site via `onEventEdit`/`onEventDelete`.
- Real on-device UAT (first round) found the whole-month day-grouped agenda from Plan 72-03 didn't match the user's actual intent — paused, revised `72-CONTEXT.md`'s D-01/D-02 (marked superseded, not silently overwritten), and reworked the agenda to single-day (today/selected day only, replacing rather than scrolling on a grid tap).
- Removed the now-dead `eventsByDay(events:calendar:)` function (Plan 72-01) and its 4 unit tests once nothing else called it (confirmed via grep).
- Added 5 new decisions (D-13–D-17) and their implementations: a Month/Year picker popover on the month/year label, and 4 white hover affordances (day-cell ring, circular chevron hover, agenda-row outline, "+ Add" border).
- Second on-device UAT round approved all 14 (revised) verification steps — real Calendar.app round-trip for create/edit/delete confirmed, visual fidelity confirmed, all new hover affordances confirmed working.

## Task Commits

1. **Task 1: handleEventEdit/handleEventDelete handlers + NotchPillView closure wiring (D-09)** - `74d9a55` (feat)
2. **Task 2 revision: revise agenda to single-day + add hover affordances (D-01/D-02 revision, D-13-D-17)** - `c3856de` (fix) — live design revision required before the checkpoint could be approved; not part of the original plan text but driven directly by the real on-device UAT reaction

**Plan metadata:** (this commit)

## Files Created/Modified

- `Islet/Notch/NotchWindowController.swift` - `handleEventEdit`/`handleEventDelete` handlers, `handleCalendarMonthYearSelect` handler (D-13), `NotchPillView(...)` closure wiring for `onEventEdit`/`onEventDelete`/`onCalendarMonthYearSelect`
- `Islet/Notch/NotchPillView.swift` - single-day `dayListColumn`/`dayEventsList` (replacing whole-month `dayGroupedAgenda`), `MonthYearPickerButton` (D-13), `DayCell` (D-14), `ChevronHoverButton` (D-15), `EventRow` hover outline (D-16), `QuickAddPopover` trigger hover border (D-17)
- `Islet/Calendar/CalendarGlance.swift` - removed dead `eventsByDay(events:calendar:)`
- `IsletTests/CalendarGlanceTests.swift` - removed the 4 now-obsolete `eventsByDay` unit tests
- `.planning/phases/72-calendar-redesign-native-calendar-clone/72-CONTEXT.md` - D-01/D-02 marked superseded with a "Revised 2026-07-31" note; D-13–D-17 added

## Decisions Made

See `key-decisions` in frontmatter above — full rationale recorded in `72-CONTEXT.md`'s "Revised 2026-07-31" section.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 4 pattern, but resolved via live user decision rather than a Claude-initiated ask] Whole-month agenda reverted to single-day after on-device UAT**
- **Found during:** Task 2's first on-device UAT round
- **Issue:** Plan 72-03's whole-month day-grouped agenda (D-01/D-02) with scroll-to-day, as built exactly per its own plan text, did not match what the user actually wanted once seen live on real hardware.
- **Fix:** User provided explicit revised decisions (D-01/D-02 superseded + D-13–D-17 new) in the same session; implemented all 6 changes, updated `72-CONTEXT.md` to record the supersession rather than silently overwriting the original decisions.
- **Files modified:** `Islet/Notch/NotchPillView.swift`, `Islet/Notch/NotchWindowController.swift`, `Islet/Calendar/CalendarGlance.swift`, `IsletTests/CalendarGlanceTests.swift`, `.planning/phases/72-calendar-redesign-native-calendar-clone/72-CONTEXT.md`
- **Verification:** Full build + test suite clean (587 tests, 7 pre-existing failures, zero new); second on-device UAT round approved all 14 revised verification steps.
- **Committed in:** `c3856de`

**2. [Rule 3 - Blocking, dead-code cleanup] Removed `eventsByDay` and its tests**
- **Found during:** the same revision (Task 2 round 1 fallout)
- **Issue:** `eventsByDay(events:calendar:)` (Plan 72-01) had exactly one caller (the whole-month agenda), which no longer exists after the D-01/D-02 revision — left in place it would be dead code.
- **Fix:** Grepped for all callers first (confirmed zero remaining), then removed the function and its 4 unit tests.
- **Files modified:** `Islet/Calendar/CalendarGlance.swift`, `IsletTests/CalendarGlanceTests.swift`
- **Verification:** Build clean, test count dropped 591→587 (exactly the 4 removed tests), no new failures.
- **Committed in:** `c3856de`

---

**Total deviations:** 2 auto-fixed (1 live-user-driven design revision, 1 dead-code cleanup as a direct consequence)
**Impact on plan:** The revision was driven by the user's real reaction during the plan's own checkpoint gate — exactly what `checkpoint:human-verify` exists to catch. No scope creep beyond what the user explicitly requested in-session.

## Issues Encountered

None beyond the design revision documented above (which is the intended function of the on-device UAT checkpoint, not an unplanned problem).

## Deferred Issues

**Intermittent hover-detection latency (D-14/D-15/D-16/D-17), non-blocking.** Reported during the approving UAT round: hover states are sometimes detected with a slight delay rather than perfectly live, reportedly worse when another app is running fullscreen and smoother otherwise. The hover mechanics themselves are confirmed correct and approved as-built — this reads as a Space-switch/mouse-tracking overhead issue for Islet's always-on-top overlay window while a fullscreen Space is active elsewhere (a known category of issue for notch-style panels), not a bug in this plan's `.onHover` code. Logged in `deferred-items.md` for a future follow-up; not a blocker for this phase.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 72 (Calendar Redesign — Native Calendar Clone) is functionally complete: CALVIEW-08 (two-column layout with a working single-day agenda) and CALVIEW-09 (visual fidelity to the native macOS Calendar widget reference, plus 4 new hover affordances) both on-device approved.
- No blockers for Phase 73 (Timer Redesign) — Calendar work is fully isolated from the timer subsystem.
- The intermittent hover-latency observation (see Deferred Issues) is worth a dedicated look if it recurs elsewhere in the notch panel, since it likely isn't specific to this phase's code.

---
*Phase: 72-calendar-redesign-native-calendar-clone*
*Completed: 2026-07-31*

## Self-Check: PASSED

- FOUND: `Islet/Notch/NotchWindowController.swift`
- FOUND: `Islet/Notch/NotchPillView.swift`
- FOUND: `.planning/phases/72-calendar-redesign-native-calendar-clone/72-04-SUMMARY.md`
- FOUND: `.planning/phases/72-calendar-redesign-native-calendar-clone/72-CONTEXT.md`
- FOUND commit: `74d9a55`
- FOUND commit: `c3856de`
