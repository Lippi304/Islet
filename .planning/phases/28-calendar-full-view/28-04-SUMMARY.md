---
phase: 28-calendar-full-view
plan: 04
subsystem: ui
tags: [swiftui, appkit, eventkit, notchwindowcontroller, calendar]

# Dependency graph
requires:
  - phase: 28-02
    provides: CalendarService.fetchMonth/createEvent/createReminder (EventKitService)
  - phase: 28-03
    provides: NotchPillView switcher pill + calendarFullView render layer, ViewSwitcherState/CalendarViewState/QuickAddKind, IslandResolver selectedView param + .calendarExpanded case, ShelfViewState.forcedByTray/isVisible
provides:
  - "Controller-layer wiring: currentPresentation() feeds viewSwitcherState.selectedView into resolve(...)"
  - "showsSwitcherRow(for:) helper mirroring NotchPillView's own pattern"
  - "visibleContentZone()'s 3rd/final shelf-visibility call site reading through ShelfViewState.isVisible, plus switcherHeight added to content size"
  - "positionAndShow(on:) reserves switcherRowHeight unconditionally in the panel geometry union"
  - "handleSwitcherSelect/handleCalendarMonthChange/handleCalendarDaySelect/handleQuickAdd controller handlers"
  - "makeRootView wiring of the 4 new NotchPillView closures"
affects: [phase-28-verification, future-calendar-work]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "New IslandPresentation-driven geometry/visibility branches always add a matching helper (showsSwitcherRow) that mirrors the view layer's own predicate exactly, so controller and view can never disagree"
    - "Every shelf/switcher visibility check across the whole controller reads through the single ShelfViewState.isVisible source of truth, not a raw .items.isEmpty check (CR-01 discipline)"

key-files:
  created: []
  modified:
    - Islet/Notch/NotchWindowController.swift

key-decisions:
  - "Task 1's property declarations (viewSwitcherState/calendarViewState) were already present from Plan 28-03's forward-looking scaffold, per that file's own comment ('this plan (28-03) only needs the properties to exist'). This plan's Task 1 only needed to wire the resolver call, add showsSwitcherRow(for:), fix the 3rd shelf-visibility call site, and extend the panel geometry union — verified via the plan's acceptance-criteria greps before committing, no redundant work done."

patterns-established: []

requirements-completed: []  # CALVIEW-01/03/04 code-complete but NOT yet marked done -- see Checkpoint Status below; requirements are only marked complete once the on-device UAT checkpoint (Task 3) is approved.

# Metrics
duration: 5min
completed: 2026-07-13
---

# Phase 28 Plan 04: Calendar Full View Controller Wiring Summary

**NotchWindowController now feeds the live switcher selection into the pure resolver, reserves panel geometry for the switcher row, and implements the switcher/month-nav/day-select/quick-add handlers — Calendar Full View is code-complete pending on-device UAT.**

## Performance

- **Duration:** ~5 min (Tasks 1-2 only; Task 3 is a human-verify checkpoint, not yet run)
- **Started:** 2026-07-13T01:41:50+02:00
- **Completed (Tasks 1-2):** 2026-07-13T01:45:54+02:00
- **Tasks:** 2 of 3 complete (Task 3 is the on-device UAT checkpoint — awaiting user)
- **Files modified:** 1

## Accomplishments
- `currentPresentation()` now passes `selectedView: viewSwitcherState.selectedView` into `resolve(...)`, so a Calendar switcher selection actually reaches the resolver's `.calendarExpanded` branch (added in Plan 28-03)
- `visibleContentZone()`'s shelf-visibility check — the 3rd and final call site of the project's Pitfall 3 hazard — now reads `shelfViewState.isVisible` instead of the raw `.items.isEmpty` check, closing the CR-01 click-through-defeat risk across the whole controller
- `positionAndShow(on:)` reserves `NotchPillView.switcherRowHeight` unconditionally in the panel's static geometry union, alongside the existing `shelfRowHeight` reservation, so the panel never needs a live resize when the switcher row first appears
- Four new controller handlers (`handleSwitcherSelect`, `handleCalendarMonthChange`, `handleCalendarDaySelect`, `handleQuickAdd`) route all Calendar Full View interaction through the SAME `calendarService`/`shelfViewState` properties the rest of the controller already uses — no second EventKit integration introduced (CALVIEW-04)
- `makeRootView(theme:)` wires the 4 new `NotchPillView` closures, completing the compile-time contract Plan 28-03 left non-defaulted

## Task Commits

Each task was committed atomically:

1. **Task 1: State ownership + resolver/click-through/panel-geometry wiring** - `152aba4` (feat)
2. **Task 2: Switcher/month-nav/day-select/quick-add handlers + makeRootView wiring** - `26f32f8` (feat)
3. **Task 3: On-device UAT** - NOT STARTED (checkpoint:human-verify, awaiting user)

## Files Created/Modified
- `Islet/Notch/NotchWindowController.swift` - resolver/geometry wiring (Task 1) + handlers/makeRootView wiring (Task 2)

## Decisions Made
- Task 1's `viewSwitcherState`/`calendarViewState` property declarations were already present on disk from Plan 28-03's deliberate forward-looking scaffold (that plan's own comment states it only needed the properties to exist so `makeRootView`'s non-defaulted params would compile). This plan verified via the plan's own acceptance-criteria greps that the properties existed exactly once, then focused Task 1's actual new work on the resolver call, the `showsSwitcherRow(for:)` helper, the `visibleContentZone()` shelf-check fix, and the `positionAndShow` geometry union — matching the plan's literal file-level intent without redundant edits.

## Deviations from Plan

None — plan executed exactly as written. All 5 acceptance-criteria greps for Task 1 and all 6 for Task 2 passed on the first attempt; the Debug build gate passed after each task with zero compile errors.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Checkpoint Status

**Task 3 (on-device UAT) has NOT been executed.** This plan is `autonomous: false` and Task 3 is a `checkpoint:human-verify` gate covering all 4 of this phase's ROADMAP Success Criteria and CALVIEW-01/02/03/04. Per the executor's protocol, execution stopped here — see the CHECKPOINT REACHED block in the final response for the full walkthrough the user needs to run (Cmd-R build + 9-step manual verification + Cmd-U regression pass).

**Until Task 3 is approved:**
- `requirements-completed` in this SUMMARY's frontmatter is intentionally left empty — CALVIEW-01/02/03/04 should NOT be marked complete in REQUIREMENTS.md/ROADMAP.md until the user types "approved".
- Phase 28 (and v1.4) should NOT be considered shipped.

## Next Phase Readiness

- Tasks 1-2 are code-complete and committed; the Debug build is green.
- Task 3 (on-device UAT) is the sole remaining item for Phase 28 and the entire v1.4 milestone.
- A follow-up agent (or the user directly) should run Cmd-R in Xcode and walk through the 9 `how-to-verify` steps in `28-04-PLAN.md`'s Task 3, then report "approved" or the specific issue found.

---
*Phase: 28-calendar-full-view*
*Completed: 2026-07-13 (Tasks 1-2 only; Task 3 pending)*
