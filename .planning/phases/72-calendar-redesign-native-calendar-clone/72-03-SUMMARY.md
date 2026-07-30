---
phase: 72-calendar-redesign-native-calendar-clone
plan: 03
subsystem: ui
tags: [swiftui, calendar, notchpillview, eventkit]

# Dependency graph
requires:
  - phase: 72-01
    provides: EventInput.id, eventsByDay(events:calendar:), CalendarService.updateEvent/deleteEvent
  - phase: 72-02
    provides: monthGridColumn/weekdayHeaderRow visual redesign (same file, sequenced first)
provides:
  - "dayGroupedAgenda(_:) — whole-month, day-grouped, ScrollViewReader-scrollable agenda replacing the old single-selected-day dayEventsList"
  - "EventRow — local-hover event row (hover-reveal delete, tap-to-edit, full-title tooltip)"
  - "EventEditPopover — pre-filled Event edit form (Save button), content-only popover presented by EventRow"
  - "onEventEdit/onEventDelete closure properties on NotchPillView"
affects: [72-04]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Content-only popover struct (no own isPresented/trigger) presented via a parent view's own .popover(isPresented:) — used when the parent (EventRow) already owns the presentation state, diverging from QuickAddPopover's self-contained trigger+popover shape"
    - "@Environment(\\.dismiss) to close a view-owned .popover from inside pre-filled form content, instead of a locally-owned isShowing flag"

key-files:
  created: []
  modified:
    - Islet/Notch/NotchPillView.swift

key-decisions:
  - "EventEditPopover does NOT carry its own @State isShowing/chip-trigger Button, diverging from the plan's literal wording — EventRow already owns the .popover(isPresented: $isShowingEdit) binding and passes EventEditPopover as pure content; giving it a second, independent isShowing would create a broken nested-popover-inside-a-popover shape. Seeding happens on .onAppear (the correct hook for content-based presentation) instead of .onChange(of: isShowing), preserving the same 'seed fresh values every open' behavior QuickAddPopover has via its own trigger-owned onChange."
  - "QuickAddPopover's submit button font bumped 14 -> 13px (UI-SPEC's 4-size typography scale) alongside introducing EventEditPopover's Save button at 13px from the start"

requirements-completed: [CALVIEW-08]

# Metrics
duration: 40min
completed: 2026-07-30
---

# Phase 72 Plan 03: Whole-month Agenda + Event Edit/Delete Summary

**Rebuilt the day-list column into a `ScrollViewReader`-driven, whole-month, day-grouped agenda (`dayGroupedAgenda`) with a hover-reveal-delete/tap-to-edit `EventRow` and a pre-filled `EventEditPopover`, wired through new `onEventEdit`/`onEventDelete` report-intent closures.**

## Performance

- **Duration:** ~40 min
- **Started:** 2026-07-30T22:58:00Z (approx, per STATE.md session start)
- **Completed:** 2026-07-30T23:25:00Z (includes ~8min full XCTest suite run)
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments
- `dayListColumn` now computes `eventsByDay(events:calendar:)` groups over the WHOLE visible month instead of filtering to the selected day; `monthEvents == nil` still renders nothing (Pitfall 4), empty groups show the empty state (now "No events this month")
- New `dayGroupedAgenda(_:)` wraps the agenda `ScrollView` in a `ScrollViewReader`; each day header carries `.id(group.day)` (the real `Date`, never a formatted `String`) so a month-grid tap scrolls there via `.onChange(of: calendarViewState.selectedDay)` — never re-fetches/re-filters `monthEvents`
- New private `EventRow` struct mirrors `TransportButton`'s local `@State private var isHovering` pattern: hover reveals a trailing trash icon (immediate delete, no confirm dialog, D-08), a `.help(event.title)` native tooltip shows the full untruncated title (D-12), and a tap (outside the trash icon's own `Button` hit area) opens a pre-filled edit popover
- New private `EventEditPopover` struct: Event-only edit form (no kind/Type picker), seeded from the tapped `EventInput`'s real `title`/`start`/`end` via `.onAppear`, reuses the trimmed-empty-title guard, submit button reads exactly "Save" (distinct from "Add Event"/"Add Reminder")
- New `onEventEdit`/`onEventDelete` closure properties on `NotchPillView` (defaulted no-op, matching `onQuickAdd`'s convention) — `EventRow`'s trash tap and edit-Save both forward through these to whatever controller wires them next (Plan 72-04)

## Task Commits

Each task was committed atomically:

1. **Task 1: Whole-month day-grouped scrollable agenda + hover-delete EventRow extraction (D-01/D-02/D-08/D-12)** - `a387b7b` (feat)
2. **Task 2: EventEditPopover (D-07) + onEventEdit/onEventDelete closures + row wiring** - `9aa7f53` (feat)

**Plan metadata:** (this commit)

## Files Created/Modified
- `Islet/Notch/NotchPillView.swift` — replaced `dayListColumn`'s single-day filter + `dayEventsList` with `eventsByDay`-driven `dayGroupedAgenda`; added `EventRow` (near `TransportButton`) and `EventEditPopover` (sibling of `QuickAddPopover`); added `onEventEdit`/`onEventDelete` closure properties; bumped `QuickAddPopover`'s submit button font 14->13px

## Decisions Made
- **EventEditPopover shape diverges from the plan's literal wording** — see Deviations below. Functionally correct per the plan's own concrete "Wire EventRow" wiring instructions (EventRow owns `isShowingEdit` and presents `EventEditPopover` as content); the plan's separate sentence asking for EventEditPopover to also carry its own `isShowing`/chip-trigger would have produced a broken nested popover if taken literally.
- D-01/D-02/D-07/D-08/D-09/D-12 were all pre-resolved in 72-CONTEXT.md/72-UI-SPEC.md — this plan just implemented them.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] EventEditPopover built as content-only, not a self-contained trigger+popover**
- **Found during:** Task 2 implementation
- **Issue:** The plan's action text asks for `EventEditPopover` to mirror `QuickAddPopover`'s "chip-trigger Button/.popover(isPresented:) pattern" AND to carry its own `@State private var isShowing`, but the plan's own separate "Wire EventRow" paragraph has `EventRow` own `.popover(isPresented: $isShowingEdit) { EventEditPopover(event: event, onSave: onEdit) }` — i.e. `EventEditPopover` is used as pure CONTENT of a popover `EventRow` already presents. Implementing both literally (a second, independent `isShowing`-driven `.popover` inside the content already being shown by a popover) would either never fire or produce a broken nested-popover-inside-a-popover.
- **Fix:** Implemented `EventEditPopover` as content-only (no `isShowing`, no trigger `Button`) — seeds `title`/`startTime`/`endTime` via `.onAppear` (the correct hook when a parent view owns presentation) instead of `.onChange(of: isShowing)`, and dismisses itself via the standard `@Environment(\.dismiss)` action after a successful Save. This preserves the plan's actual required behavior (fresh values every time the popover opens, "Save" submits and closes) without the broken double-popover structure.
- **Files modified:** Islet/Notch/NotchPillView.swift (within Task 2's own scope)
- **Verification:** `xcodebuild build -scheme Islet -destination 'platform=macOS'` succeeded; manual code-path trace confirms `EventRow`'s tap sets `isShowingEdit = true`, its `.popover` presents `EventEditPopover` fresh each time (so `.onAppear` fires per-presentation), and Save calls `dismiss()` which closes that same popover.
- **Committed in:** `9aa7f53` (Task 2 commit)

### Documentation-only grep-count mismatches (not functional defects)

**2. "No events this month" grep returns 3, not the plan's expected 1**
- Two of the three matches are this plan's own new inline comments mentioning the string by name (documenting the copy change); only one is the real `Text("No events this month")` — confirmed via `grep -n` inspection. Same class of false-negative documented in 72-02-SUMMARY.md for `weekdayHeaderRow`.

**3. `grep -c "size: 14, weight: .semibold, design: .rounded"` returns 1, not the plan's expected 0**
- The plan's acceptance criterion assumed only `QuickAddPopover`'s submit button used this exact font spec (now bumped to 13px, per plan). A second, unrelated pre-existing occurrence exists in `OnboardingDoneStep`'s `Toggle("Launch Islet at login", ...)` label (Phase 26 code, completely unrelated to this plan's calendar-agenda scope) — confirmed via `grep -n` that this is the sole remaining match and it predates this plan. Not touched (Scope Boundary — out of scope for this plan).

---

**Total deviations:** 1 auto-fixed bug (broken double-popover shape, fixed before commit), 2 documentation-only grep-count false negatives (both confirmed non-functional by inspection).
**Impact on plan:** No scope creep. Task 2's actual required behavior (pre-filled edit popover, "Save" button, immediate close-on-save) is delivered exactly as intended; the deviation only concerns the internal Swift structure needed to make that behavior actually work.

## Issues Encountered

**Full XCTest suite: 591 tests, 9 failures** — 7 are the pre-existing, already-documented baseline (4x `LicenseStateTests`, 3x `SettingsViewTests`, unchanged since Phase 71/Plan 72-01/72-02). The remaining 2 (`CalendarGlanceTests.testEndedEventTodayIsSkippedInFavorOfUpcomingOne`, `CalendarGlanceTests.testMultipleRelevantEventsTodayReturnsEarliestStarting`) are a **pre-existing, time-of-day-dependent test flake** in Phase 14's `nextRelevantEvent` tests — both use the real wall-clock `Date()` as `now` and add 1-2 hours to build an event's `start`, which crosses midnight into the next calendar day whenever the suite runs late at night (as it did here, ~23:15-23:24 local). Neither test, nor `nextRelevantEvent`/`CalendarGlance.swift` itself, was touched by either of this plan's two commits (both touch only `Islet/Notch/NotchPillView.swift`). Confirmed via a targeted `-only-testing:IsletTests/CalendarGlanceTests` run showing the identical 2 failures with the identical `isToday: false` vs expected `true` mismatch, driven entirely by the real clock at execution time. Logged in `deferred-items.md`, not fixed (out of scope for this plan's files).

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness

Build clean (`xcodebuild build -scheme Islet -destination 'platform=macOS'` succeeded after both tasks). The whole-month agenda, hover-delete, tap-to-edit popover, and full-title tooltip are all in place, driven by `onEventEdit`/`onEventDelete` closures that are currently still no-ops at the `NotchWindowController` level (that wiring is Plan 72-04's job, matching the existing `onQuickAdd` precedent from Phase 28/46). Interactive hover/scroll/popover behavior itself is manual-only verification (no SwiftUI snapshot/interaction-test infra in this project) — deferred to Plan 72-04's consolidated on-device UAT, per this plan's own scope.

Ready for Plan 72-04 (controller wiring + consolidated on-device UAT).

---
*Phase: 72-calendar-redesign-native-calendar-clone*
*Completed: 2026-07-30*

## Self-Check: PASSED
- FOUND: Islet/Notch/NotchPillView.swift
- FOUND: .planning/phases/72-calendar-redesign-native-calendar-clone/72-03-SUMMARY.md
- FOUND: .planning/phases/72-calendar-redesign-native-calendar-clone/deferred-items.md
- FOUND commit: a387b7b
- FOUND commit: 9aa7f53
