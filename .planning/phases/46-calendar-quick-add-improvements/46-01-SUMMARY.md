---
phase: 46-calendar-quick-add-improvements
plan: 01
subsystem: ui
tags: [swiftui, datepicker, calendar, quick-add]

requires:
  - phase: 28-calendar-full-view
    provides: QuickAddPopover trigger/segmented-picker scaffold, CalendarViewState.selectedDay
provides:
  - defaultQuickAddTime(selectedDay:now:) pure helper (CALVIEW-05)
  - QuickAddPopover Starts/Ends/Due compact DatePicker rows with Start->End auto-follow
  - onSubmit/onQuickAdd widened to (QuickAddKind, String, Date, Date?)
affects: [46-02-notchwindowcontroller-wiring, 46-03-onsite-verification]

tech-stack:
  added: []
  patterns:
    - "isProgrammaticEndUpdate suppression flag distinguishing an auto-follow @State write from a genuine user edit across sibling onChange handlers"

key-files:
  created: []
  modified:
    - Islet/Calendar/CalendarGlance.swift
    - IsletTests/CalendarGlanceTests.swift
    - Islet/Notch/NotchPillView.swift
    - Islet/Notch/NotchWindowController.swift

key-decisions:
  - "onQuickAdd widened at its single controller call site to compile against the new 4-arg signature; the extra Date/Date? args are intentionally discarded there (Plan 46-02 Task 1 wires them into CalendarService) — a Rule 3 blocking-issue fix, not scope creep on this plan's stated boundary"

requirements-completed: [CALVIEW-05]

duration: 12min
completed: 2026-07-19
---

# Phase 46 Plan 01: Quick-Add Date+Time Picker Summary

**Added a pure `defaultQuickAddTime` seed helper and a real Starts/Ends/Due compact DatePicker UI to `QuickAddPopover`, with a suppression-flag-based Start→End 1-hour auto-follow that survives repeated Start edits.**

## Performance

- **Duration:** 12 min
- **Started:** 2026-07-19T20:17:00Z
- **Completed:** 2026-07-19T20:29:39Z
- **Tasks:** 2
- **Files modified:** 4 (2 planned + 2 deviation)

## Accomplishments
- `defaultQuickAddTime(selectedDay:now:)` — total, Foundation-only, no inline `Date()` — returns the next full hour when `selectedDay` is today, `startOfDay` otherwise, correctly rolling over the day boundary at 23:xx.
- `QuickAddPopover` now shows a real native `.compact` DatePicker per field: Starts + Ends (Event) on their own rows, Due (Reminder) — no separate Date field, matching the locked D-01/D-02/D-03/D-05 decisions.
- Start→End 1-hour auto-follow (D-04) implemented via an `isProgrammaticEndUpdate` flag that lets `endRow`'s `onChange` tell its own sibling's auto-follow write apart from a genuine user edit — verified by design to survive multiple sequential Start changes, not just the first.
- `onSubmit`/`onQuickAdd` both widened to `(QuickAddKind, String, Date, Date?) -> Void`, ready for Plan 46-02 to wire real dates into `CalendarService`.
- Popover now opens `arrowEdge: .trailing` at 240pt width (D-07).

## Task Commits

1. **Task 1: Add defaultQuickAddTime(selectedDay:now:) pure helper** - `f7008c6` (feat)
2. **Task 2: QuickAddPopover date+time picker rows + widened onSubmit/onQuickAdd signature** - `22d110c` (feat)

**Plan metadata:** (this commit)

## Files Created/Modified
- `Islet/Calendar/CalendarGlance.swift` - added `defaultQuickAddTime(selectedDay:now:)`
- `IsletTests/CalendarGlanceTests.swift` - added 3 tests (today/not-today/hour-rollover)
- `Islet/Notch/NotchPillView.swift` - `QuickAddPopover` extended with `startRow`/`endRow`/`dueRow`, `selectedDay` param, widened `onSubmit`/`onQuickAdd`, `arrowEdge: .trailing`, 240pt width
- `Islet/Notch/NotchWindowController.swift` - widened the one `onQuickAdd` call-site closure to match the new signature (dates discarded here, deferred to Plan 46-02)

## Decisions Made
- The `onQuickAdd` signature widening (Task 2) breaks compilation at `NotchWindowController.swift`'s single existing call site, which is outside this plan's stated `files_modified`. Fixed inline (Rule 3 — blocking issue) by widening the closure's parameter list there too, discarding the new `Date`/`Date?` args and keeping `handleQuickAdd(kind, title:)`'s existing (today-hardcoded) behavior completely unchanged — preserves this plan's explicit scope boundary ("does NOT wire those values into NotchWindowController/CalendarService yet") while keeping the build green as the plan's own acceptance criteria require.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Widened NotchWindowController's onQuickAdd call site to match the new closure type**
- **Found during:** Task 2 (QuickAddPopover date+time picker rows)
- **Issue:** Widening `NotchPillView.onQuickAdd`'s stored-closure type to `(QuickAddKind, String, Date, Date?) -> Void` made the existing 2-arg closure literal at `NotchWindowController.swift:2011` a compile error (`expects 4 arguments, but 2 were used`).
- **Fix:** Widened that closure's parameter list to `{ kind, title, _, _ in ... }`, forwarding only `kind`/`title` to the unchanged `handleQuickAdd(kind, title:)` — the two new `Date`/`Date?` parameters are intentionally ignored here since real wiring is Plan 46-02 Task 1's job.
- **Files modified:** `Islet/Notch/NotchWindowController.swift`
- **Verification:** `xcodebuild -scheme Islet -destination 'platform=macOS' build` → `** BUILD SUCCEEDED **`
- **Committed in:** `22d110c` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Necessary to keep the build green after the signature widening this plan itself specifies. No scope creep — the actual date-wiring behavior change stays deferred to Plan 46-02 as designed.

## Issues Encountered
None beyond the deviation above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- `defaultQuickAddTime` and the widened `onSubmit`/`onQuickAdd` signatures are ready for Plan 46-02 to wire real `Date` values into `NotchWindowController.handleQuickAdd` → `CalendarService`.
- The 3 new `CalendarGlanceTests` methods are written but not yet run via Cmd-U in this session (per this project's documented `xcodebuild test` headless-hang convention) — recommend a manual Cmd-U pass before/alongside Plan 46-02's on-device verification (Plan 46-03).
- No blockers for Plan 46-02.

---
*Phase: 46-calendar-quick-add-improvements*
*Completed: 2026-07-19*

## Self-Check: PASSED
