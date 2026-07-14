---
phase: 33-weather-widget-redesign
plan: 1
subsystem: weather
tags: [swift, weatherkit, corelocation, swiftui, xcodegen]

# Dependency graph
requires:
  - phase: 14-basic-outfit-weather-calendar-date
    provides: WeatherService/WeatherKitService seam, BasicOutfitState, ActivitySettings key namespace
provides:
  - "DailyForecast model (date/category/high/low) for every .daily WeatherKit entry"
  - "WeatherGlance extended with high/low temperatures"
  - "WeatherService.fetchCurrentAndForecast — single combined weather(for:including:.current,.daily) call, replaces fetchCurrent entirely"
  - "WeatherService.resolvePlaceName — CLGeocoder reverse-geocode seam, settles nil on any failure (D-02)"
  - "BasicOutfitState.forecast/.locationName published fields"
  - "ActivitySettings.weatherExtendedKey, plain default-false Bool"
affects: [33-02-weather-widget-redesign, weather-view-layer]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Combined multi-dataset WeatherKit fetch via weather(for:including:_:) tuple return, avoiding doubled quota (Pitfall 1)"
    - "CLGeocoder reverse-geocode reusing the existing CLLocation already obtained for weather, no new permission ask"

key-files:
  created:
    - IsletTests/WeatherServiceTests.swift
  modified:
    - Islet/Weather/WeatherService.swift
    - Islet/Notch/BasicOutfitState.swift
    - Islet/ActivitySettings.swift
    - Islet/Notch/NotchWindowController.swift
    - Islet.xcodeproj/project.pbxproj

key-decisions:
  - "fetchCurrent fully removed (not deprecated/shimmed) — grep confirmed refreshWeather() was its only caller"
  - "resolvePlaceName returns nil (not the 'Local' string) on any failure — the fallback substitution is explicitly a Plan 33-02 view-layer concern"
  - "NotchWindowController.refreshWeather() rewired to fetchCurrentAndForecast in THIS plan (Rule 3 fix), not deferred to 33-02 as the plan text suggested, because 33-01's own verification requires a green `xcodebuild build`"

patterns-established:
  - "TDD RED/GREEN required regenerating Islet.xcodeproj via `xcodegen generate` first — new test files are invisible to the build until the XcodeGen-managed project is regenerated"

requirements-completed: [WEATHER-01, WEATHER-02]

# Metrics
duration: ~25min
completed: 2026-07-14
---

# Phase 33 Plan 1: Weather Data Foundation Summary

**Single combined WeatherKit fetch (current + daily forecast, one network call) plus a CLGeocoder reverse-geocode seam, threaded through `BasicOutfitState` and gated by a new Settings key — the pure data layer for the Weather widget redesign.**

## Performance

- **Duration:** ~25 min
- **Completed:** 2026-07-14T23:49:58Z
- **Tasks:** 2
- **Files modified:** 5 (1 created)

## Accomplishments
- `DailyForecast` model and 4-field `WeatherGlance` (category/temperature/high/low) added to `WeatherService.swift`
- `fetchCurrentAndForecast` makes exactly ONE `weather(for:including: .current, .daily)` call — no doubled WeatherKit quota
- `resolvePlaceName` reverse-geocodes via `CLGeocoder`, settling `nil` on any error/empty locality (D-02)
- `fetchCurrent` fully removed from the protocol and `WeatherKitService` — zero remaining references anywhere in the codebase
- `BasicOutfitState.forecast`/`.locationName` published fields, mirroring the existing weather/calendar ownership contract
- `ActivitySettings.weatherExtendedKey` added for the future extended-forecast Settings toggle
- 3 new `WeatherServiceTests` (fake-conformer pattern, no real I/O) prove the one-call contract and geocode round-trips

## Task Commits

Each task was committed atomically (Task 1 followed the RED/GREEN TDD cycle):

1. **Task 1 RED: WeatherServiceTests (failing)** - `aee97c0` (test)
2. **Task 1 GREEN: Combined fetch + reverse-geocode seam** - `0271c2c` (feat)
3. **Task 2: BasicOutfitState + ActivitySettings wiring** - `a7bd67f` (feat)

**Plan metadata:** committed separately by this agent (see below)

## Files Created/Modified
- `Islet/Weather/WeatherService.swift` - `DailyForecast`, 4-field `WeatherGlance`, `fetchCurrentAndForecast`, `resolvePlaceName`; `fetchCurrent` removed
- `IsletTests/WeatherServiceTests.swift` - `FakeWeatherService` fake-conformer + 3 tests (one-call contract, geocode round-trip, geocode nil-on-failure)
- `Islet/Notch/BasicOutfitState.swift` - `forecast`/`locationName` published fields
- `Islet/ActivitySettings.swift` - `weatherExtendedKey`
- `Islet/Notch/NotchWindowController.swift` - `refreshWeather()` rewired from `fetchCurrent` to `fetchCurrentAndForecast` (forecast/locationName consumption deferred to Plan 33-02)
- `Islet.xcodeproj/project.pbxproj` - regenerated via `xcodegen generate` to register the new test file

## Decisions Made
- `resolvePlaceName` settles `nil` (not "Local") on failure — the string fallback is explicitly out of scope for this plan's service layer, per the plan's own `<behavior>` spec
- Kept `CLGeocoder` over `MKReverseGeocodingRequest` (research-confirmed: the replacement needs macOS 26.0+, project targets 15.0)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Rewired `NotchWindowController.refreshWeather()` to `fetchCurrentAndForecast`**
- **Found during:** Task 1 (build verification after removing `fetchCurrent`)
- **Issue:** The plan's own task text says `refreshWeather()`'s rewiring "is rewired to `fetchCurrentAndForecast` in Plan 33-02" — but removing `fetchCurrent` in THIS plan broke `xcodebuild build` immediately, and both Task 1's acceptance criteria and the plan's overall `<verification>` section require a zero-error build at the end of 33-01, not 33-02.
- **Fix:** Rewired the one call site to `fetchCurrentAndForecast`, consuming only the `WeatherGlance` (ignoring the forecast tuple member) — kept minimal since forecast/locationName view-layer consumption is still Plan 33-02's job.
- **Files modified:** Islet/Notch/NotchWindowController.swift
- **Verification:** `xcodebuild build -scheme Islet -destination 'platform=macOS'` succeeds with zero errors
- **Committed in:** `0271c2c` (Task 1 GREEN commit)

**2. [Rule 3 - Blocking] Regenerated Xcode project via `xcodegen generate`**
- **Found during:** Task 1 RED phase
- **Issue:** This is an XcodeGen-managed project (`project.yml` is the source of truth); a newly created `IsletTests/WeatherServiceTests.swift` file was invisible to `xcodebuild build-for-testing` until the `.xcodeproj` was regenerated — the new test file wasn't part of any compile job.
- **Fix:** Ran `xcodegen generate`, which picked up the new file via its `Islet`/`IsletTests` source-path globs.
- **Files modified:** Islet.xcodeproj/project.pbxproj
- **Verification:** New test file appeared in the `SwiftDriverJobDiscovery` compile job list on the next build-for-testing run
- **Committed in:** `aee97c0` (Task 1 RED commit)

---

**Total deviations:** 2 auto-fixed (both Rule 3 — blocking build issues)
**Impact on plan:** Both fixes were required to keep the plan's own zero-error-build verification true at the end of this plan. No scope creep — no forecast/locationName view-layer wiring was added ahead of Plan 33-02.

## Issues Encountered
- Initial `WeatherServiceTests.swift` draft imported `WeatherKit` directly, colliding with the file's own `WeatherService` protocol name (`WeatherKit.WeatherService` vs. `Islet.WeatherService` — ambiguous lookup). Fixed before the RED commit by dropping the unnecessary `import WeatherKit` (the test file only needs `Islet`'s own types plus `CoreLocation`/`Foundation`).
- `xcodebuild build -scheme Islet` alone does NOT compile the `IsletTests` target — used `xcodebuild build-for-testing` to verify the test file compiles. Actually running the tests (`xcodebuild test`) is not attempted per project memory (`xcodebuild-test-headless-hang` — the full `IsletTests` bundle boots the full `Islet.app`, which hangs on a Bluetooth TCC wait in a headless/non-interactive environment). Manual Cmd-U remains the correct way to execute the 3 new `WeatherServiceTests`, consistent with this project's established test-execution convention.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- `DailyForecast`, extended `WeatherGlance`, `fetchCurrentAndForecast`, `resolvePlaceName`, `BasicOutfitState.forecast`/`.locationName`, and `ActivitySettings.weatherExtendedKey` are all in place for Plan 33-02 (view/panel-geometry layer) to consume.
- Plan 33-02 still owns: `NotchWindowController.refreshWeather()`'s forecast/locationName consumption into `BasicOutfitState`, the compact/extended card UI, the Settings toggle wiring, and the panel-frame/click-through geometry updates (Pattern 2/3 from RESEARCH.md).
- Manual Cmd-U run of the 3 new `WeatherServiceTests` (plus the full `IsletTests` suite) is recommended before/alongside Plan 33-02's own on-device verification — not run in this automated pass due to the known headless-hang limitation.

---
*Phase: 33-weather-widget-redesign*
*Completed: 2026-07-14*

## Self-Check: PASSED

All 6 claimed files found on disk; all 4 claimed commit hashes found in git log.
