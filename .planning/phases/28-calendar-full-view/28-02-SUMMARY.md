---
phase: 28-calendar-full-view
plan: 02
subsystem: calendar
tags: [eventkit, calendar, reminders, swift]

# Dependency graph
requires:
  - phase: 14-basic-outfit (weather+calendar+date)
    provides: CalendarService/EventKitService protocol seam and EventInput/CalendarGlance types
provides:
  - "fetchMonth(containing:completion:) — month-range event fetch for the full calendar grid"
  - "createEvent(title:start:end:completion:) — Calendar event creation, no new permission work"
  - "createReminder(title:dueDate:completion:) — Reminder creation with lazy, first-use-only Reminders permission request"
  - "project.yml Reminders Info.plist keys (NSRemindersUsageDescription, NSRemindersFullAccessUsageDescription)"
affects: [28-03 (calendar month-grid view), 28-04 (quick-add controller wiring)]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "EventKit write paths (createEvent/createReminder) wrapped in do/catch, settling completion(false) on any thrown error — never crash"
    - "Reminders permission requested lazily from exactly one call site (createReminder), mirroring LocationProvider.requestOnce's silent-degrade-on-denial shape"

key-files:
  created: []
  modified:
    - Islet/Calendar/CalendarService.swift
    - project.yml
    - Islet.xcodeproj/project.pbxproj (xcodegen regeneration after project.yml change)

key-decisions:
  - "fetchMonth/createEvent/createReminder all reuse the single existing EKEventStore instance (self.store) — no second store introduced, preserving CALVIEW-04's single-EventKit-layer requirement"
  - "createReminder is the ONLY call site in the codebase permitted to call requestFullAccessToReminders() — verified structurally via grep count == 1"

patterns-established:
  - "CalendarService protocol now has 4 methods (fetchUpcoming, fetchMonth, createEvent, createReminder), all on the single EventKitService conformer — no second service"

requirements-completed: [CALVIEW-03, CALVIEW-04]

# Metrics
duration: 12min
completed: 2026-07-13
---

# Phase 28 Plan 02: Calendar Full View — EventKit Service Extension Summary

**Extended the existing single CalendarService/EventKitService seam with month-range fetch, event creation, and lazy-permission Reminder creation — zero new services, zero new EKEventStore instances.**

## Performance

- **Duration:** 12 min
- **Started:** 2026-07-12T23:17:00Z
- **Completed:** 2026-07-12T23:29:20Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- `fetchMonth(containing:completion:)` added to `CalendarService`/`EventKitService`, widening `fetchUpcoming`'s existing predicate-based fetch to a full calendar month, settling `[]` (never `nil`) on Calendar access denial
- `createEvent(title:start:end:completion:)` added — constructs and saves an `EKEvent` via the existing store, no new permission work needed (D-06)
- `createReminder(title:dueDate:completion:)` added — the ONLY call site in the codebase that requests Reminders access, fired lazily on first invocation, mirroring `LocationProvider.requestOnce`'s silent-degrade shape
- `project.yml` gained both required Reminders Info.plist keys (`NSRemindersUsageDescription` + `NSRemindersFullAccessUsageDescription`), preventing D-05's Pitfall 2 (adding only one silently breaks first-touch access)

## Task Commits

Each task was committed atomically:

1. **Task 1: fetchMonth(containing:completion:) — month-range event fetch** - `416977d` (feat)
2. **Task 2: createEvent + createReminder (lazy Reminders permission) + project.yml keys** - `a2569be` (feat)

_Note: no TDD tasks in this plan (autonomous plan type)._

## Files Created/Modified
- `Islet/Calendar/CalendarService.swift` - Added `fetchMonth`, `createEvent`, `createReminder` to the protocol and `EventKitService` conformer
- `project.yml` - Added `INFOPLIST_KEY_NSRemindersUsageDescription` and `INFOPLIST_KEY_NSRemindersFullAccessUsageDescription`
- `Islet.xcodeproj/project.pbxproj` - Regenerated via `xcodegen generate` after the project.yml change (existing repo convention — pbxproj is committed alongside project.yml edits)

## Decisions Made
- Reused the code shapes already vetted in `28-RESEARCH.md`'s Code Examples section verbatim (fetchMonth, lazy Reminders permission request) rather than redesigning — plan explicitly called for this
- Ran `xcodegen generate` after the project.yml edit and committed the regenerated `project.pbxproj` alongside it, since the build system requires this to pick up the new Info.plist keys and this repo's git history shows project.pbxproj is always committed together with project.yml changes

## Deviations from Plan

None - plan executed exactly as written. The `project.pbxproj` regeneration was mechanically required by the project.yml change (not a plan deviation) and follows this repo's established convention (verified via `git log` on that file).

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

`CalendarService` now exposes all 4 methods (`fetchUpcoming`, `fetchMonth`, `createEvent`, `createReminder`) needed for the full calendar view (Plan 03) and quick-add controller wiring (Plan 04). Manual on-device UAT of the quick-add round-trip and Reminders permission-prompt timing is deferred to Plan 04's checkpoint task, as specified in this plan's `<verification>` section, once the UI (Plan 03) and controller wiring (Plan 04) exist to actually trigger these methods.

---
*Phase: 28-calendar-full-view*
*Completed: 2026-07-13*
