---
phase: 28-calendar-full-view
plan: 03
subsystem: ui
tags: [swiftui, notch-chrome, calendar, eventkit-adjacent, dynamic-island]

# Dependency graph
requires:
  - phase: 28-calendar-full-view (Plan 01)
    provides: ViewSwitcherState/SelectedView, CalendarViewState/QuickAddKind, CalendarGlance.swift's daysInMonth(for:)/events(on:events:) pure functions
provides:
  - ShelfViewState.isVisible — the single source of truth for shelf-row visibility (forcedByTray + !items.isEmpty)
  - IslandPresentation.calendarExpanded + resolve(...) selectedView parameter, ranked below transients/media/onboarding, above expandedIdle
  - NotchPillView switcher pill (Home/Tray/Calendar), calendarFullView (month grid + day list + empty state + quick-add popover)
affects: [28-04 (controller wiring: data fetch, permission requests, panel geometry)]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "blobShape's content -> switcher -> shelf row ordering, both rows independently toggleable and coexisting inside one continuous NotchShape"
    - "QuickAddPopover: file-scope private struct owning its own transient @State (mirrors OnboardingDoneStep's scoping precedent)"

key-files:
  created: []
  modified:
    - Islet/Shelf/ShelfViewState.swift
    - Islet/Notch/IslandResolver.swift
    - IsletTests/IslandResolverTests.swift
    - Islet/Notch/NotchPillView.swift
    - Islet/Notch/NotchWindowController.swift

key-decisions:
  - "NotchWindowController now owns viewSwitcherState/calendarViewState as placeholder instances (mirrors the existing onboardingState precedent) so makeRootView's non-defaulted NotchPillView params compile ahead of Plan 04's real controller wiring"
  - "QuickAddPopover reimplements chipButton's exact visual convention inline rather than calling NotchPillView.chipButton(...) directly — a sibling file-scope private struct has no access to another type's private instance method; UI-SPEC's own wording (\"reuses chipButton's exact existing convention\") supports style-reuse, not necessarily the literal call"
  - "Month grid column width left un-forced (no explicit .frame(width: 190)) — the LazyVGrid's natural 7*28+6*4=220pt width slightly exceeds the UI-SPEC's ~190pt guidance; flagged as an on-device tuning point per the plan's own allowance (\"starting points for on-device tuning\")"

patterns-established:
  - "Pattern 3 (single-arbiter extension): selectedView is a new INPUT to resolve(...), never a parallel if-check in NotchPillView's body"

requirements-completed: [CALVIEW-01, CALVIEW-02, CALVIEW-03]

# Metrics
duration: ~20min
completed: 2026-07-13
---

# Phase 28 Plan 03: Calendar Full View Render Layer Summary

**Home/Tray/Calendar switcher pill + `.calendarExpanded` month grid/day list/empty-state/quick-add, wired into `NotchPillView`'s existing single-arbiter switch, no stubs**

## Performance

- **Duration:** ~20 min
- **Tasks:** 3
- **Files modified:** 5 (2 required an out-of-plan controller-side fix to keep the build green)

## Accomplishments
- `ShelfViewState.isVisible` (`!items.isEmpty || forcedByTray`) is now the ONE source of truth for shelf-row visibility across all 3 read sites in `NotchPillView.swift` — closes the CR-01 click-through regression class ahead of Plan 04's Tray force-reveal wiring
- `IslandPresentation.calendarExpanded` + `resolve(...)`'s new `selectedView` parameter, correctly ranked below transients/media/onboarding and above `expandedIdle` (6 new `IslandResolverTests` cover the full precedence matrix)
- A real, non-stub Calendar Full View: 3-icon switcher pill, month grid (7-column `LazyVGrid`, prev/next navigation), day-list column (loading/empty/populated states via `EventInput?`-nil discipline), and an in-panel quick-add popover (Event/Reminder segmented choice, title field, kind-labeled submit)

## Task Commits

Each task was committed atomically:

1. **Task 1: ShelfViewState.isVisible/forcedByTray** - `e24cc3f` (feat)
2. **Task 2: IslandResolver .calendarExpanded + switcher pill + calendarFullView grid/list** - `d7d22f2` (feat)
3. **Task 3: Quick-add popover** - `3ac1cf5` (feat)

**Plan metadata:** (this commit, docs)

## Files Created/Modified
- `Islet/Shelf/ShelfViewState.swift` - `forcedByTray` + computed `isVisible`
- `Islet/Notch/IslandResolver.swift` - `.calendarExpanded` case + `selectedView` param on `resolve(...)`
- `IsletTests/IslandResolverTests.swift` - 6 new tests covering the selectedView precedence matrix
- `Islet/Notch/NotchPillView.swift` - switcher pill, `calendarFullView` (month grid + day list + empty state), `QuickAddPopover`
- `Islet/Notch/NotchWindowController.swift` - owns placeholder `viewSwitcherState`/`calendarViewState` instances so the non-defaulted `NotchPillView` params compile (Rule 3 blocking-issue fix, out of this plan's declared file list)

## Decisions Made
- See `key-decisions` in frontmatter above (NotchWindowController placeholder ownership; QuickAddPopover style-reuse vs. literal call; month-grid column width left un-forced pending on-device tuning).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] NotchWindowController.makeRootView needed viewSwitcherState/calendarViewState arguments**
- **Found during:** Task 2, first build attempt after adding the two new non-defaulted `NotchPillView` properties
- **Issue:** `NotchPillView`'s constructor call in `NotchWindowController.swift` (not in this plan's declared `files_modified`) failed to compile once `viewSwitcherState`/`calendarViewState` became required parameters
- **Fix:** Added `private let viewSwitcherState = ViewSwitcherState()` and `private let calendarViewState = CalendarViewState()` to `NotchWindowController`, mirroring the exact placeholder-ownership pattern already documented for `onboardingState` (26-04's precedent: "this plan only needs the property to exist so makeRootView's non-defaulted param compiles"), and passed them into the constructor call
- **Files modified:** `Islet/Notch/NotchWindowController.swift`
- **Verification:** `xcodebuild build` succeeds; `xcodebuild build-for-testing` succeeds
- **Committed in:** `d7d22f2` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Necessary to keep every commit a compiling increment (plan's own stated design goal). No scope creep — the two properties are inert placeholders; Plan 04 replaces them with real controller wiring.

## Issues Encountered
None beyond the deviation above.

## User Setup Required
None - no external service configuration required.

## Known Stubs
- `NotchWindowController.viewSwitcherState`/`calendarViewState` are inert placeholder instances (never mutated, never fed real EventKit data or switcher taps) — `onSwitcherSelect`/`onCalendarMonthChange`/`onCalendarDaySelect`/`onQuickAdd` all remain wired to their `NotchPillView` no-op defaults. This is explicitly Plan 04's scope ("wire real controller behavior — data fetch, permission requests, panel geometry"), not a gap in this plan: the render layer is fully non-stub (real grid math, real event filtering, real empty-state branching once `monthEvents` is populated), only the data feed and interaction wiring are deferred.

## Next Phase Readiness
- The full Calendar Full View render layer compiles and is reachable via `.calendarExpanded` — ready for Plan 04 to wire `EventKitService` month fetches, lazy Reminders permission requests, and real switcher/day-nav/quick-add controller handlers on top
- Full on-device rendering verification (switcher tap actually navigating, real month data, real quick-add round-trip) is deferred to Plan 04's checkpoint per this plan's own `<verification>` section
- Flag for on-device tuning during Plan 04/05: the month-grid column's natural width (~220pt) vs. UI-SPEC's ~190pt guidance, and the 44pt switcher-row / 28×28pt grid-cell starting sizes

---
*Phase: 28-calendar-full-view*
*Completed: 2026-07-13*
