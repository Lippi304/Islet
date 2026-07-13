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
3. **Task 3: On-device UAT** - IN PROGRESS (checkpoint:human-verify; round 1 found the camera-notch
   overlap bug documented above, fixed at `cff1a12`; round 2 found the switcher-pill suppression
   bug documented below, fixed at `3326f1f` — awaiting round 3 approval)

## Files Created/Modified
- `Islet/Notch/NotchWindowController.swift` - resolver/geometry wiring (Task 1) + handlers/makeRootView wiring (Task 2)

## Decisions Made
- Task 1's `viewSwitcherState`/`calendarViewState` property declarations were already present on disk from Plan 28-03's deliberate forward-looking scaffold (that plan's own comment states it only needed the properties to exist so `makeRootView`'s non-defaulted params would compile). This plan verified via the plan's own acceptance-criteria greps that the properties existed exactly once, then focused Task 1's actual new work on the resolver call, the `showsSwitcherRow(for:)` helper, the `visibleContentZone()` shelf-check fix, and the `positionAndShow` geometry union — matching the plan's literal file-level intent without redundant edits.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Calendar full view overlapped the camera notch on first on-device UAT pass**
- **Found during:** Task 3 (on-device UAT, round 1) — user reported the month grid's top rows
  hidden behind the physical camera, while the switcher pill/shelf row below rendered correctly.
- **Root cause:** `calendarFullView`'s `blobShape(...)` call omitted an explicit `height:`, so
  its `content()` slot defaulted to `.frame(height: Self.expandedSize.height, alignment: .center)`
  (144pt, centered). The real month-grid + day-list content (header + a worst-case 6-row
  `LazyVGrid` of 28×28pt cells) is ~216-220pt tall — well over 144pt — and centering an
  oversized child in a `.frame()` (a layout proposal, not a clip) spills the overflow equally
  above AND below the box. The upward half landed directly under the camera cutout, because the
  panel's `.overlay(alignment: .top)` pins flush to the notch. Same regression class already
  fixed twice before in this file (Phase 21 SHELF-06, Phase 26 onboarding) — see the inline
  comments at `NotchPillView.swift` around `isOnboardingPresentation`/`onboardingSize`.
- **Fix:** Mirrored the established onboarding pattern rather than reinventing it:
  - Added `NotchPillView.calendarContentHeight` (266pt, math documented inline: 32pt top
    camera-clearance + 20pt header + 8pt spacing + 188pt worst-case 6-row grid + 18pt bottom
    inset for the `bottomCornerRadius: 32` curve). 28×28pt cells / 4pt gaps were kept exactly
    as spec'd (D-locked minimums per 28-UI-SPEC.md) rather than shrunk to fit the old 144pt box —
    the math shows a legible 6-row grid genuinely needs ~220pt of content height, so a
    dedicated taller reserved size (route (b) from the bugfix brief) was the correct choice
    over trying to compress the grid into the original box (route (a)).
  - `calendarFullView`'s `blobShape(...)` call now passes `alignment: .top` and
    `height: Self.calendarContentHeight`, plus a `.padding(.top, 32)` on its content — the
    exact same "top-pin + camera-clearance padding" convention `mediaExpanded` already uses.
  - Added `isCalendarPresentation` (mirrors `isOnboardingPresentation`) so `body`'s outer
    `.frame` never clips shorter than `blobShape`'s own now-taller visible shape.
  - `NotchWindowController.positionAndShow` unions a `calendarFrame` reservation (mirrors
    `onboardingFrame`/`wings`) into the static panel-geometry union, unconditionally.
  - `NotchWindowController.visibleContentZone` gets a matching `isCalendarActive` branch —
    reuses the `presentationState.presentation` enum switch directly (matching the existing
    `showsSwitcherRow(for:)` idiom) rather than adding a redundant controller-level bool
    alongside `isOnboardingActive`.
  - All three call sites (SwiftUI content frame, static panel reservation, dynamic
    click-through zone) now agree on the same `calendarContentHeight` value.
- **Files modified:** `Islet/Notch/NotchPillView.swift`, `Islet/Notch/NotchWindowController.swift`
- **Commit:** `cff1a12`
- **Visual fidelity:** the existing grid-left/day-list-right layout, divider, color-dot +
  title + time event rows, and "+ Add" quick-add popover already matched the Droppy reference
  (`notes.md` images 6-7) structurally per the original 28-UI-SPEC.md — this fix only corrects
  the geometry (content now grows downward, clear of the camera, instead of overlapping it).
  No further visual restructuring was needed; the on-device UAT round 2 should confirm the
  restored clearance reads as polished as the other views.

**2. [Rule 1 - Bug] Switcher pill disappeared while Now Playing was expanded, on second on-device UAT pass**
- **Found during:** Task 3 (on-device UAT, round 2) — user reported "Jetzt keine Navigation mehr
  vorhanden" ("now there's no navigation anymore") while music was playing, with a screenshot
  showing the Now Playing expanded view (album art + transport controls) but no Home/Tray/Calendar
  switcher pill below it.
- **Root cause:** Not a regression from the round-2 geometry fix (`cff1a12` never touched
  `showsSwitcherRow`). It was existing, deliberately-implemented behavior from 28-03/28-04's
  original design: `28-UI-SPEC.md`'s switcher-pill Visibility row scoped the pill to
  `.expandedIdle`/`.calendarExpanded` only, treating `.nowPlayingExpanded` (the full media view)
  the same as the brief Charging/Device splash and the small collapsed Now-Playing wings glance.
  On real on-device use, media playback is a long-lived, user-entered state — not a transient —
  so suppressing navigation while music plays is a genuine UX bug, not a display artifact.
- **Fix:** Extended both mirrored `showsSwitcherRow` implementations (the `NotchPillView.swift`
  computed property and its lockstep-mirrored `NotchWindowController.swift` free function) to also
  return `true` for `.nowPlayingExpanded` (covers both the healthy/playing case and the "nicht
  verfügbar" case — both are full-expanded, user-entered, non-transient states). Updated
  `mediaExpanded`'s and `mediaUnavailable`'s own `blobShape(...)` call sites to pass
  `showSwitcher: true` so the row actually renders inside their content, not just the geometry
  predicates. No new geometry constants were needed: the outer SwiftUI `.frame` already grows
  generically off `showsSwitcherRow`, and the AppKit panel's static reservation (`positionAndShow`)
  already unconditionally reserves `switcherRowHeight` as a worst-case union regardless of
  presentation — both picked up the fix automatically. `28-UI-SPEC.md`'s Visibility row amended to
  match the corrected, final behavior.
- **Files modified:** `Islet/Notch/NotchPillView.swift`, `Islet/Notch/NotchWindowController.swift`,
  `.planning/phases/28-calendar-full-view/28-UI-SPEC.md`
- **Commit:** `3326f1f`

All other Task 1/2 acceptance-criteria greps passed on the first attempt; the Debug build gate
passed after each task with zero compile errors (and again after both bugfixes).

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Checkpoint Status

**Task 3 (on-device UAT) round 1 found a real bug (camera-notch overlap on the calendar view);
round 2 found a second real bug (switcher pill missing during Now Playing expanded) — both now
fixed, round 3 is pending.** This plan is `autonomous: false` and Task 3 is a
`checkpoint:human-verify` gate covering all 4 of this phase's ROADMAP Success Criteria and
CALVIEW-01/02/03/04. Per the executor's protocol, execution stopped here again after the fix —
see the CHECKPOINT REACHED block in the final response for the full walkthrough the user needs
to re-run (Cmd-R build + manual verification + Cmd-U regression pass), with special attention to
confirming: (1) the month grid's top row still clears the camera notch with a visible gap, and
(2) the switcher pill (Home/Tray/Calendar) now stays visible while music is playing (Now Playing
expanded view), while still correctly disappearing during the brief Charging/Device-connect
splash and the small collapsed Now-Playing glance (before clicking to expand it).

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
