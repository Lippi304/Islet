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

requirements-completed: [CALVIEW-01, CALVIEW-03, CALVIEW-04]  # Approved by user after round 6 on-device UAT -- see Checkpoint Status below.

# Metrics
duration: 5min
completed: 2026-07-13
---

# Phase 28 Plan 04: Calendar Full View Controller Wiring Summary

**NotchWindowController now feeds the live switcher selection into the pure resolver, reserves panel geometry for the switcher row, and implements the switcher/month-nav/day-select/quick-add handlers — Calendar Full View is complete and APPROVED after a 6-round on-device UAT arc.**

## Performance

- **Duration:** ~5 min (Tasks 1-2); Task 3 (on-device UAT) ran 6 rounds across the same session
- **Started:** 2026-07-13T01:41:50+02:00
- **Completed (Tasks 1-2):** 2026-07-13T01:45:54+02:00
- **Task 3 approved:** 2026-07-13 (round 6, after fixing the switcher icon hit-test area)
- **Tasks:** 3 of 3 complete
- **Files modified:** 1 (Task 1-2 scope); see Deviations below for the additional files touched during the UAT-driven fix rounds

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
3. **Task 3: On-device UAT** - APPROVED (checkpoint:human-verify; 6 rounds — round 1 found the
   camera-notch overlap bug, fixed at `cff1a12`; round 2 found the switcher-pill suppression bug,
   fixed at `3326f1f`; round 4 found the resolver-precedence bug plus a user-confirmed scope
   expansion (smart Home, new Weather tab, calendar visual pass), fixed/added at `b46c4eb`/
   `c301a03`/`fecebff`; round 5 found calendar density/misclick issues and added a dedicated Tray
   view, fixed at `53be4d6`/`73f170f`; round 6 found the switcher icon hit-test bug, fixed at
   `1edf772` — user typed "approved" after round 6 re-verification)

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

**3. [Genuine scope expansion, user-confirmed] Round 4 — resolver precedence bug + "smart Home"
reversal + new Weather tab + calendar visual pass**
- **Found during:** Task 3 (on-device UAT, round 4) — user reported "clicking Calendar shows
  nothing" and "navigation disappears during music" as real bugs, and additionally requested a
  genuine scope expansion beyond this phase's original locked design. The orchestrator asked
  two explicit clarifying questions before any code was written; the user's answers are the
  authorization for this round (not a guess) — see `28-CONTEXT.md`'s round-4 addendum for the
  full traceable record.
- **Root cause (the bug half):** `IslandResolver.resolve(...)`'s `isExpanded` branch checked
  Now-Playing BEFORE `selectedView` — once `nowPlaying != .none` (true even while merely
  PAUSED, not just actively playing) Calendar became permanently unreachable via the switcher,
  because the resolver never reached the `selectedView == .calendar` check at all.
- **Fix:**
  - `resolve(...)` now checks `selectedView == .calendar`/`.weather` BEFORE Now-Playing; only
    `selectedView == .home` still falls through to the Now-Playing-wins-over-idle branch (the
    "smart Home" behavior below). Tray is untouched (still no resolver case — its force-reveal
    is the existing additive `ShelfViewState.forcedByTray`/`isVisible` strip, layered under any
    presentation regardless of playback state).
  - **"Smart Home" (deliberate, user-confirmed reversal):** `.planning/research/inspiration/
    notes.md` originally locked "Islet should keep its current default... not copy Droppy's
    music-default." The user re-decided this on-device during round 4: Home now shows
    Now-Playing controls when something is playing, and the idle date/time glance otherwise —
    confirmed explicitly via the orchestrator's clarifying question, documented as a dated
    addendum in `28-CONTEXT.md` rather than silently overwriting the old note.
  - **New 4th switcher tab: Weather**, order Home/Tray/Calendar/Weather (existing three
    untouched). `SelectedView.weather` + `IslandPresentation.weatherExpanded` added.
    `weatherFullView` renders ONLY the existing current-conditions data
    (`WeatherGlance`/`WeatherKitService` — category + temperature, no forecast anywhere in the
    codebase), reusing `weatherIcon(for:)` and the existing `.formatted(.measurement(...))`
    temperature string verbatim rather than reinventing them. Fits inside the existing
    `expandedSize.height` (144pt) base, so — unlike `calendarExpanded` — no new geometry
    constant/union member was needed at any of the three geometry call sites beyond
    `showsSwitcherRow`, which already governs the switcher-row reservation uniformly for every
    case in that set. An explicit "Wetter nicht verfügbar" empty state mirrors
    `mediaUnavailable`'s existing tone/style. **Whether a real forecast is wanted is an open
    follow-up question for the user — not decided or silently built in this round.**
  - **Calendar visual pass, with a real caveat:** before restyling, all 31 PNGs in
    `.planning/research/inspiration/` were inspected directly (not trusted from `notes.md`'s
    numbering, which the orchestrator had already found mismatched). Every one of the 31 files
    is a Droppy **Settings** screenshot (General/Droplets/Shelf/Basket/Clipboard/Lock
    Screen/Droppy Cloud/HUDs/Theming/Accessibility/License/About) — none show the live
    notch-overlay switcher pill or the calendar month-grid view `notes.md` cites (images 5-7,
    10, 12). No genuine calendar/switcher reference photo exists in this project's assets.
    Applied the closest faithful substitute instead of inventing an unrelated style: Droppy's
    own dominant, product-wide visual language actually visible in the real screenshots —
    circular/capsule badges (License's "Trial Active" chip, the Lock Screen "Rounded" battery/
    weather rings) and rounded-card row containers (every Settings row on file). Selected day
    now gets a filled circle behind the number, today gets a thin ring, days with events get a
    small dot — all inside the existing 28×28pt D-locked cell (no `calendarContentHeight`
    change); day-list event rows now sit in a subtle rounded card.
- **Files modified:** `Islet/Notch/ViewSwitcherState.swift`, `Islet/Notch/IslandResolver.swift`,
  `IsletTests/IslandResolverTests.swift`, `Islet/Notch/NotchPillView.swift`,
  `Islet/Notch/NotchWindowController.swift`,
  `.planning/phases/28-calendar-full-view/28-UI-SPEC.md`,
  `.planning/phases/28-calendar-full-view/28-CONTEXT.md`
- **Commits:** `b46c4eb` (resolver + weather case + tests), `c301a03` (weather tab UI + calendar
  visual pass), `fecebff` (docs)
- **Verification:** `xcodebuild build` (Debug) — BUILD SUCCEEDED. `xcodebuild build-for-testing`
  — TEST BUILD SUCCEEDED (full `Cmd-U` run, including the new `IslandResolverTests` methods,
  is left for the on-device UAT round per this project's established `xcodebuild test`
  headless-hang precedent — the test bundle hosts inside the full `Islet.app`, which boots
  `NSPanel`/MediaRemote/IOBluetooth and hangs non-interactively).

**4. [Rule 1 - Bug, plus user-directed density/UX fixes] Round 5 — calendar grid density,
misclick/notch-close root-cause fix, dedicated Tray view**
- **Found during:** Task 3 (on-device UAT, round 5) — user attached two GENUINE Droppy
  notch-overlay reference screenshots (unlike round 4's 31 Settings-only images) and reported
  three issues: the calendar grid was too spacious vs. the event list, a real intermittent
  misclick/notch-close bug when switching tabs, and Tray should be a dedicated files-only view
  instead of the additive shelf-strip-under-Home behavior.
- **1. Calendar density:** `NotchPillView.calendarCellSize`/`calendarCellGap` shrunk from
  28×28pt/4px (round 4, never actually validated against a real reference) to 18×18pt/2px,
  matching the real Droppy reference's tight, small, numeral-only cells and automatically
  freeing width for `dayListColumn` (an HStack sibling with no fixed width of its own — a
  smaller grid column leaves more of the 360pt content box for the list). Day-number font
  9px (was 11px), has-events dot 2px (was 3px).
- **2. Root cause of the misclick/notch-close bug:** `blobShape`'s `content()` box used a
  PER-CASE height (144pt for Home/Weather/NowPlaying, 266pt for Calendar), and the switcher row
  is stacked immediately after `content()` in the same VStack — so the switcher pill's
  on-screen Y position shifted by ~122pt depending on which tab was active. A click landing
  where the switcher USED to be (before the layout reflow settled, e.g. clicking twice quickly)
  could miss it entirely and collapse the island instead of switching tabs.
- **Fix:** `NotchPillView.calendarContentHeight` renamed to `switcherContentHeight` (196pt,
  recomputed for the new grid density) and made the ONE shared content-box height for EVERY
  switcher-row presentation. `blobShape` itself now forces `baseHeight` to this constant
  whenever `showSwitcher` is true, regardless of any `height:` a caller passes — centralizing
  the decision in one place makes it structurally impossible for a future switcher-row caller
  to reintroduce per-case drift. Home (`expandedIsland`) and `mediaUnavailable` gained
  `alignment: .top` + `.padding(.top, 32)` for consistency with the convention
  `mediaExpanded`/`calendarFullView`/`weatherFullView` already used (shorter content now
  top-aligns with empty transparent space below it, above the switcher row, instead of
  centering). `NotchWindowController.positionAndShow`'s separate `calendarFrame` panel-geometry
  union collapsed into the single `expandedFrame` reservation (now sized off
  `switcherContentHeight`); `visibleContentZone()`'s `isCalendarActive`-only branch collapsed
  into the already-computed `switcherRowShowing` boolean. This is the 4th time this session a
  "mismatched reserved height across presentations" bug class was hit (shelf, onboarding,
  calendar-round-2, now the switcher row itself) — fixed this time at the true root (one
  shared constant enforced inside `blobShape`) rather than another per-case patch.
- **3. Tray dedicated view:** `IslandResolver.swift` gained a new `.trayExpanded` case, checked
  at the same priority tier as Calendar/Weather (before Now-Playing) — supersedes the
  28-03/28-04 D-02 reconciliation where Tray had no resolver case and instead
  force-revealed the additive shelf strip under whichever OTHER presentation was active.
  `NotchPillView.trayFullView` renders the shelf items full-size via the EXISTING
  `shelfRow(_:)`/`ShelfItemView` building blocks (not reinvented) with a dedicated empty state
  ("No files yet" / "Drag files onto the notch to add them here."), mirroring
  `calendarEmptyState`'s heading+body tone. `ShelfViewState.forcedByTray` — dead now that Tray
  always resolves to `.trayExpanded` — was removed; `isVisible` simplified to `!items.isEmpty`.
  Phase 24's auto-reveal-on-drop under OTHER tabs is unaffected (it never depended on
  `forcedByTray`).
- **Files modified:** `Islet/Notch/NotchPillView.swift`, `Islet/Notch/NotchWindowController.swift`,
  `Islet/Notch/IslandResolver.swift`, `Islet/Shelf/ShelfViewState.swift`,
  `IsletTests/IslandResolverTests.swift`, `.planning/phases/28-calendar-full-view/28-UI-SPEC.md`,
  `.planning/phases/28-calendar-full-view/28-CONTEXT.md`
- **Commits:** `53be4d6` (resolver + shelf state + tests), `73f170f` (density + shared height +
  Tray view)
- **Verification:** `xcodebuild build` (Debug) — BUILD SUCCEEDED. `xcodebuild build-for-testing`
  — TEST BUILD SUCCEEDED (includes the new `IslandResolverTests` Tray-precedence methods). Full
  `Cmd-U` run and on-device UAT left for the round-5 re-verification, per this project's
  established `xcodebuild test` headless-hang precedent.

**5. [Rule 1 - Bug] Round 6 — switcher icon ring/padding area not tappable, only the glyph itself**
- **Found during:** Task 3 (on-device UAT, round 6) — user reported clicking directly on a
  switcher icon's glyph switches tabs, but clicking elsewhere within the same visible circle
  (the ring/padding around the glyph) closes the notch instead.
- **Root cause:** `navCircleButton`'s `Button` used `.buttonStyle(.plain)` with a
  `Color.clear` background for every non-selected/non-filled icon (3 of the 4 circles at any
  given time). SwiftUI's hit-testing under `.plain` only counts opaque pixels as part of a
  Button's tappable region when the background is transparent — the clear circle fill/ring
  area is not hit-tested as part of the Button at all. A click landing there fell through to
  `blobShape`'s ancestor `.onTapGesture { onClick() }` (which intentionally covers the
  switcher/shelf rows' empty space), collapsing the island instead of switching tabs.
- **Fix:** Added `.contentShape(Circle())` to the Button's label in `navCircleButton`, after
  the existing `.background`/`.overlay` modifiers — the standard, minimal SwiftUI fix that
  explicitly declares the full `navCircleDiameter`-sized circle as the hit-test region
  regardless of fill transparency.
- **Files modified:** `Islet/Notch/NotchPillView.swift`
- **Commit:** `1edf772`
- **Verification:** `xcodebuild build` (Debug) — BUILD SUCCEEDED.

All other Task 1/2 acceptance-criteria greps passed on the first attempt; the Debug build gate
passed after each task with zero compile errors (and again after every subsequent round's
bugfixes/scope-expansion changes).

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Checkpoint Status

**APPROVED.** The user typed "approved" after round 6 on-device re-verification, confirming all
4 of this phase's ROADMAP Success Criteria and CALVIEW-01/02/03/04 are observably true. This plan
is `autonomous: false` and Task 3 was a `checkpoint:human-verify` gate; per the executor's
protocol, execution paused after each round's fix until the user's explicit approval was
received.

### The 6-round UAT arc, summarized

Task 3 took 6 rounds to reach approval, and each round found a genuine issue rather than a false
alarm — worth reading in full below, but in short: round 1 caught the calendar month-grid
overlapping the physical camera notch (a `.frame()` centering overflow, fixed by top-pinning the
content with explicit camera-clearance padding, mirroring the existing onboarding-view pattern).
Round 2 caught the Home/Tray/Calendar switcher pill disappearing while Now Playing was expanded
(originally-designed behavior that turned out to be a real UX bug once music is a long-lived,
user-entered state — extended `showsSwitcherRow` to cover `.nowPlayingExpanded`). Round 4 caught
a resolver-precedence bug that made Calendar permanently unreachable via the switcher whenever
Now-Playing was non-`.none` (even paused) — fixed by checking `selectedView` before Now-Playing in
`IslandResolver.resolve(...)` — and, in the same round, the user confirmed a genuine scope
expansion: "smart Home" (Home now shows Now-Playing controls when something is playing, the idle
glance otherwise — a deliberate reversal of the phase's original locked decision) plus an
entirely new 4th switcher tab, Weather, showing current-conditions-only data reused verbatim from
the existing `WeatherGlance`/`WeatherKitService`. Round 5, working from real Droppy reference
screenshots for the first time, tightened the calendar grid density (28×28pt → 18×18pt cells),
root-caused and fixed an intermittent misclick/notch-close bug (the switcher row's on-screen
position was shifting per-presentation because each view reserved a different content height —
unified into one shared `switcherContentHeight` constant enforced inside `blobShape` itself), and
added a dedicated Tray view (files-only, its own resolver case, replacing the earlier
additive-shelf-strip-under-Home behavior). Round 6 caught a hit-testing bug where only a switcher
icon's glyph pixels — not the full circular tap target around it — registered clicks, fixed with
a single `.contentShape(Circle())`. Round 5's re-verification then held clean into round 6, and
round 6's fix was the last change needed before approval.

The walkthrough the user ran covered (verbatim, for the historical record):
1. The month grid's top row still clears the camera notch with a visible gap (round 1 fix
   still holds).
2. The switcher pill now shows **4 icons** (Home/Tray/Calendar/Weather) and stays visible while
   music is playing (round 2 fix still holds), while still correctly disappearing during the
   brief Charging/Device-connect splash and the small collapsed Now-Playing glance.
3. **Calendar and Weather are reachable via the switcher even while music is actively
   playing** (round 4 precedence fix) — click Calendar or Weather while a track plays and
   confirm the island morphs to that view, not to the Now-Playing controls.
4. **Home is "smart"**: with music playing, clicking Home shows the Now-Playing controls;
   with nothing playing, clicking Home shows the idle date/time glance.
5. The new Weather tab renders the current temperature/icon/category, or the "Wetter nicht
   verfügbar" empty state if no weather data is available — confirm this is understood as
   **current-conditions-only** (no forecast), and decide whether a real forecast (a new
   WeatherKit call + new data model) is wanted as a separate follow-up.
6. **(round 5) Calendar grid density** — the month grid now uses small, tight 18×18pt cells
   with a 2px gap (was 28×28pt/4px), matching the two real Droppy reference screenshots this
   round, and the day-list column visibly has more room now that the grid column is narrower.
7. **(round 5) Rapid tab-switching stress test** — click rapidly back and forth between all 4
   switcher icons (Home → Tray → Calendar → Weather → Home, several times in a row, including
   double-clicking a tab right after switching to it) and confirm every click is recognized as
   landing ON the notch — the island should never silently collapse instead of switching. This
   directly re-exercises the misclick/notch-close bug's root cause (the switcher pill's
   on-screen position now stays perfectly constant across every tab).
8. **(round 5) Tray is now a dedicated files-only view** — click Tray and confirm it shows
   ONLY the shelf files (or the "No files yet" empty state if the shelf is empty), not the Home
   glance with a shelf strip appended below it. Then, WHILE on a DIFFERENT tab (Home, Calendar,
   or Weather), drag a file onto the notch and confirm Phase 24's auto-reveal-on-drop still
   works — the shelf strip should appear appended below that tab's content, unrelated to
   explicit Tray navigation.
9. The calendar month grid's visual pass — a filled circle on the selected day, a thin ring on
   today, a small dot under days with events, and rounded-card day-list rows — reads as
   intentional polish (now validated against real Droppy reference screenshots as of round 5).

All 9 points above were confirmed by the user on round 6 re-verification, plus round 6's own
switcher icon hit-test fix. **The user typed "approved."**

- `requirements-completed` in this SUMMARY's frontmatter now lists CALVIEW-01/03/04 — the
  orchestrator will mark them complete in REQUIREMENTS.md/ROADMAP.md.
- Phase 28 (and the v1.4 milestone it completes) is shipped.

## Next Phase Readiness

- Tasks 1-2 are code-complete and committed; the Debug build is green (verified again after
  every UAT-driven fix round, through round 6).
- Task 3 (on-device UAT) is APPROVED — all 4 ROADMAP Success Criteria and CALVIEW-01/02/03/04
  are confirmed observably true on-device.
- Open follow-up (not blocking this phase): is a real weather forecast wanted for the new
  Weather tab, or is current-conditions-only sufficient? Left as a decision for a future phase.

---
*Phase: 28-calendar-full-view*
*Completed: 2026-07-13 (all 3 tasks complete; Task 3 on-device UAT approved after 6 rounds)*
