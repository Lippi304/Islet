---
phase: 72-calendar-redesign-native-calendar-clone
reviewed: 2026-07-31T00:00:00Z
depth: standard
files_reviewed: 5
files_reviewed_list:
  - Islet/Calendar/CalendarGlance.swift
  - Islet/Calendar/CalendarService.swift
  - Islet/Notch/NotchPillView.swift
  - Islet/Notch/NotchWindowController.swift
  - IsletTests/CalendarGlanceTests.swift
findings:
  critical: 0
  warning: 3
  info: 2
  total: 5
status: issues_found
---

# Phase 72: Code Review Report

**Reviewed:** 2026-07-31
**Depth:** standard
**Files Reviewed:** 5
**Status:** issues_found

## Summary

Reviewed the phase-72 calendar redesign: the pure `CalendarGlance.swift` seam (`daysInMonth`,
`events(on:)`, `defaultQuickAddTime`, `nextRelevantEvent`, `nextUpcomingEvent`), the
`EventKitService` CRUD implementation, the month-grid + single-day-agenda view code in
`NotchPillView.swift` (including the mid-execution D-01/D-02 revert back to a single-day agenda
and the 5 new hover affordances: `DayCell`, `ChevronHoverButton`, `MonthYearPickerButton`,
`EventRow`'s hover outline, and `QuickAddPopover`'s hover border), the controller-side handlers in
`NotchWindowController.swift`, and the existing unit tests.

The pure functions in `CalendarGlance.swift` are correct, total (never force-unwrap/crash on
empty input), and well covered by `CalendarGlanceTests.swift`. The "No events today" empty-state
string (which now shows for an arbitrary selected day, not just literally "today") was checked
against `72-UI-SPEC.md`'s Copywriting Contract — it is an intentional, spec-mandated string, not a
bug.

The most notable gaps are in the newly-added `EventEditPopover` (no time-ordering validation
before writing to EventKit) and in the controller's calendar-month fetch/navigation handlers (no
guard against out-of-order async completions on rapid navigation). Neither is a crash or security
issue, but both can produce visibly wrong state in the UI/underlying calendar data.

## Warnings

### WR-01: Rapid month navigation can apply a stale fetch result over a newer one

**File:** `Islet/Notch/NotchWindowController.swift:2391-2458`
**Issue:** `handleCalendarMonthChange`, `handleCalendarMonthYearSelect`, and `handleSwitcherSelect`
all call `refreshCalendarMonth()`, which fires a brand-new `Task` via
`calendarService.fetchMonth(containing:completion:)` on every call, with no request
generation/token to discard stale results. Each `Task` starts with
`await store.requestFullAccessToEvents()` (an async suspension point), so two fetches issued
back-to-back (e.g. the user double-clicks the "next month" chevron, or clicks the chevron twice
before the first fetch settles) are not guaranteed to complete in the order they were issued. If
the first (now-stale) fetch settles after the second, its completion handler
(`self?.calendarViewState.monthEvents = events`) unconditionally overwrites `monthEvents` with the
wrong month's events while `visibleMonth`/`selectedDay` already reflect the newer month — the grid
header and day list go out of sync until the user navigates again.
**Fix:** Add a monotonically increasing request token, capture it at fetch time, and only apply
the result if it's still current:
```swift
private var calendarFetchToken = 0

private func refreshCalendarMonth() {
    calendarFetchToken += 1
    let token = calendarFetchToken
    calendarService.fetchMonth(containing: calendarViewState.visibleMonth) { [weak self] events in
        guard let self, token == self.calendarFetchToken else { return }
        self.calendarViewState.monthEvents = events
    }
}
```

### WR-02: No start/end ordering validation before creating or updating an event

**File:** `Islet/Notch/NotchPillView.swift:5220-5245` (QuickAddPopover submit), `5322-5363` (new
`EventEditPopover`, particularly the `Save` action at 5336-5341)
**Issue:** Both the quick-add "Add Event" button and the newly-added `EventEditPopover`'s "Save"
button only guard against an empty/whitespace title (`trimmedTitle.isEmpty`) before calling
`onSubmit`/`onSave`. Neither checks that `endTime > startTime`. `QuickAddPopover` mitigates this
somewhat for the common case via the Start→End auto-follow (`endManuallyEdited`), but a user can
still manually set an End time before the Start time (e.g. Start 17:00, End 09:00) and submit.
`EventEditPopover` has no auto-follow at all — both fields are independently editable — so editing
an existing event's End to before its Start is trivially reachable. This writes a
negative-duration event straight into the user's real Calendar via
`EventKitService.createEvent`/`updateEvent`, with no validation at that layer either (see
`CalendarService.swift:153-185`).
**Fix:** Disable the submit/save button (mirroring the existing title-emptiness `.disabled(...)`)
when `kind == .event && endTime <= startTime`, e.g.:
```swift
.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (kind == .event && endTime <= startTime))
```
and the equivalent unconditional check in `EventEditPopover` (`endTime <= startTime`).

### WR-03: `EventInput.id` fallback to `""` can collide across events, breaking `ForEach` identity

**File:** `Islet/Calendar/CalendarService.swift:147-150`, consumed at
`Islet/Notch/NotchPillView.swift:1881` (`ForEach(dayEvents, id: \.id)`)
**Issue:** `mapToEventInput` falls back `ek.eventIdentifier ?? ""` when EventKit hands back a nil
identifier. If two such events land on the same day, both get `id == ""`, and
`ForEach(dayEvents, id: \.id)` in `dayEventsList` will have two elements sharing the same
identity — SwiftUI diffing/animation for that row becomes undefined (potential duplicate-row
render glitches, or edit/delete tapping the wrong row after a re-sort). The existing comment
documents `""` as the intended "degrade update/delete to a no-op" fallback for a single such
event, but doesn't account for the list-identity collision when more than one occurs.
**Fix:** Use a per-event unique fallback instead of a shared constant, e.g. fall back to
`ek.eventIdentifier ?? UUID().uuidString`, or synthesize an identity from `ek.calendarItemIdentifier`
if present.

## Info

### IN-01: `MonthYearPickerButton`'s default `@State` values are hardcoded and will go stale

**File:** `Islet/Notch/NotchPillView.swift:1764-1765`
**Issue:** `@State private var pickedMonth = 1` and `@State private var pickedYear = 2026` are
magic-number placeholders that only matter for the brief window before
`.onChange(of: isShowing)` (line 1777-1782) recomputes them from `visibleMonth`. In practice they
are always overwritten before the popover content is shown, so this is not currently reachable as
a user-visible bug, but the hardcoded `2026` will silently read as "wrong" to a future reader/
maintainer once the year rolls over, with no compiler warning.
**Fix:** Seed from `Calendar.current.component(.year, from: Date())` instead of a literal, e.g.
`@State private var pickedYear = Calendar.current.component(.year, from: Date())`.

### IN-02: `dueRow`'s DatePicker silently shares `startTime` with the Event flow's "Starts" field

**File:** `Islet/Notch/NotchPillView.swift:5299-5310`
**Issue:** The Reminder "Due" field is bound to the same `$startTime` state the Event "Starts"
field uses (`dueRow` vs. `startRow`). This is presumably intentional (one shared time field,
switched by `kind`), but nothing in the code documents that `startTime` is deliberately dual-
purposed as "Due date" when `kind == .reminder`, unlike the rest of the file's habit of a doc
comment at every non-obvious state-sharing decision (e.g. the `endManuallyEdited`/
`isProgrammaticEndUpdate` comments a few lines above). A future edit to `startRow`'s auto-follow
logic could easily leak into the Reminder path without realizing it shares state.
**Fix:** Add a one-line comment on the `startTime` declaration (or on `dueRow`) noting it doubles
as the Reminder due-date field.

---

_Reviewed: 2026-07-31_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
