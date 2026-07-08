---
phase: 14-basic-outfit-weather-calendar-date-display-with-weather-driv
plan: 04
subsystem: ui
tags: [swiftui, weatherkit, eventkit, corelocation, symboleffect, dynamic-island]

# Dependency graph
requires:
  - phase: 14-02
    provides: BasicOutfitState published holder, IslandPresentation.expandedIdle case
  - phase: 14-03
    provides: LocationProvider, WeatherKitService/WeatherService protocol, EventKitService/CalendarService protocol, WeatherCategory, CalendarGlance/nextRelevantEvent
provides:
  - 3-column expandedIdle glance (weather left / time+date center / calendar right) wired end-to-end
  - NotchWindowController-owned weather/calendar/location services behind protocol types
  - 15-minute coarse outfit-refresh Timer with deinit teardown
affects: [14-05 (on-device UAT of the new glance, idle-CPU verification)]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Controller owns fragile external services (WeatherKit/EventKit/CoreLocation) behind AnyObject protocol types, mirrors NowPlayingService/LicenseService isolation convention"
    - "One-shot location request cached in a plain optional (lastLocation), never re-requested on refresh — same 'no retry, no re-nag' discipline as LocationProvider itself"
    - "Either/or column omission via `if let` inside the overlay HStack (no error/placeholder state), mirroring the existing artThumbnail optional-branch pattern"

key-files:
  created: []
  modified:
    - Islet/Notch/NotchPillView.swift
    - Islet/Notch/NotchWindowController.swift
    - Islet.xcodeproj/project.pbxproj

key-decisions:
  - "Regenerated Islet.xcodeproj via xcodegen — 14-03's new Weather/Calendar/Location source files existed on disk but were never added to the pbxproj target, so the project failed to compile with 'cannot find type' errors until regenerated (Rule 3 blocking fix)."

patterns-established:
  - "Weather icon is the ONLY animated element in expandedIdle; idle-CPU safety is by construction (the view/symbolEffect driver only exists while presentation == .expandedIdle, same guarantee as EqualizerBars/ProgressBar)"

requirements-completed: [WEATHER-01, CAL-01, OUTFIT-01]

duration: 25min
completed: 2026-07-08
---

# Phase 14 Plan 04: Outfit Glance Wiring Summary

**Wired `BasicOutfitState` end-to-end: NotchWindowController owns WeatherKit/EventKit/CoreLocation behind protocol types on a 15-min timer, feeding a new 3-column expandedIdle glance (animated weather icon left, static time/date center, calendar right) in NotchPillView.**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-07-08T12:15:00Z
- **Completed:** 2026-07-08T12:42:00Z
- **Tasks:** 2 completed
- **Files modified:** 3 (2 Swift files + regenerated pbxproj)

## Accomplishments
- `expandedIsland` replaced the single date/time placeholder with a 3-column HStack (weatherColumn / centerColumn / calendarColumn) exactly per UI-SPEC.md's Spacing Scale, Typography, and Color contracts
- Weather icon is the sole animated element: 4-case `symbolEffect` switch (`.pulse` for sunny, `.variableColor.iterative` for cloudy/rain/snow), every case explicit with `options: .repeating`
- Calendar event title bounded with `.lineLimit(1)` + `.truncationMode(.tail)` inside a fixed 100pt column (V5 mitigation for untrusted `EKEvent.title`)
- `NotchWindowController` now owns `outfitState`, `weatherService`/`calendarService` (protocol-typed), and `locationProvider`; `startOutfitRefresh()` requests location once, fetches calendar immediately, then arms a 15-min `Timer` driving both refreshes
- `deinit` invalidates the new timer alongside the existing monitor teardown calls

## Task Commits

Each task was committed atomically:

1. **Task 1: NotchPillView — 3-column expandedIsland layout + outfit param** - `f2f744d` (feat)
2. **Task 2: NotchWindowController — own the services, coarse-refresh timer, inject outfitState** - `46e9fb2` (feat)

_No plan-metadata commit — this is a worktree parallel-executor plan; the orchestrator commits STATE.md/ROADMAP.md centrally after the wave merges._

## Files Created/Modified
- `Islet/Notch/NotchPillView.swift` - `outfit: BasicOutfitState` param, 3-column `expandedIsland` overlay, `weatherColumn`/`centerColumn`/`weatherIcon`/`calendarColumn` helpers, all 8 `#Preview` call sites updated
- `Islet/Notch/NotchWindowController.swift` - `outfitState`/`weatherService`/`calendarService`/`locationProvider`/`outfitRefreshTimer`/`lastLocation` properties, `startOutfitRefresh()`/`refreshWeather()`/`refreshCalendar()`, `makeRootView` injection, `deinit` teardown
- `Islet.xcodeproj/project.pbxproj` - regenerated via `xcodegen generate` to add 14-03's Weather/Calendar/Location source files to the build target

## Decisions Made
- Regenerated the Xcode project via `xcodegen` rather than hand-editing the pbxproj — the project already uses folder-path source globbing in `project.yml`, so `xcodegen generate` was the correct, existing-convention fix for the missing file references (not a new tool/process introduced).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Islet.xcodeproj missing 14-03's new source files**
- **Found during:** Task 1 (first `xcodebuild` verification run)
- **Issue:** `Islet/Weather/*.swift`, `Islet/Calendar/*.swift`, and `Islet/Location/LocationProvider.swift` (all created in 14-03) existed on disk but were never added to `Islet.xcodeproj/project.pbxproj`'s target — the build failed with `cannot find type 'WeatherGlance'/'BasicOutfitState'/etc. in scope` the instant this plan's code referenced them.
- **Fix:** Ran `xcodegen generate` (project.yml already globs `path: Islet`, so this was a pure regeneration, no config change needed).
- **Files modified:** `Islet.xcodeproj/project.pbxproj`
- **Verification:** `xcodebuild build -scheme Islet` — BUILD SUCCEEDED
- **Committed in:** `f2f744d` (Task 1 commit, alongside NotchPillView.swift since that's where the missing types first surfaced)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Necessary to make the plan's own acceptance criteria (`xcodebuild build -scheme Islet` succeeds) achievable at all. No scope creep — no code logic changed, only the project's file-reference manifest.

## Issues Encountered
None beyond the pbxproj regeneration above.

## User Setup Required
None - no external service configuration required. (Location/Calendar permission *prompts* will appear on first on-device launch after this plan — that's expected runtime behavior per D-01/D-03, not a setup step; on-device UAT is 14-05's scope.)

## Next Phase Readiness
- `expandedIdle` renders the full D-07 3-column glance; the project builds clean with zero new warnings in the touched files.
- Permission-denial silent omission, idle-CPU verification of the weather-icon animation, and general on-device look/feel are explicitly 14-05's scope (per this plan's own `<verification>` section — headless `xcodebuild` cannot exercise permission prompts or Energy sampling).
- No blockers for 14-05.

---
*Phase: 14-basic-outfit-weather-calendar-date-display-with-weather-driv*
*Completed: 2026-07-08*

## Self-Check: PASSED
