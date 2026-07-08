---
phase: 14-basic-outfit-weather-calendar-date-display-with-weather-driv
plan: 03

subsystem: services
tags: [swiftui, weatherkit, eventkit, corelocation, protocol-isolation]

# Dependency graph
requires:
  - phase: 14-01
    provides: "WeatherCategory.from(_:) pure classifier, EventInput/CalendarGlance + nextRelevantEvent(events:now:) pure selection seam"
provides:
  - "LocationProvider — one-shot CLLocationManager wrapper, requestOnce(completion:)"
  - "WeatherService protocol + WeatherGlance + WeatherKitService conformer"
  - "CalendarService protocol + EventKitService conformer"
  - "BasicOutfitState — the @Published data holder 14-04's controller will inject into the view"
affects: [14-04]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Protocol-isolation for fragile externals: one AnyObject protocol, one final class conformer, mirrors LicenseService.swift/NowPlayingMonitor.swift"
    - "Silent-degradation contract: completion(nil) on any denial/failure, never a retry loop, never surfaced to the view (D-01/D-03)"

key-files:
  created:
    - Islet/Location/LocationProvider.swift
    - Islet/Weather/WeatherService.swift
    - Islet/Calendar/CalendarService.swift
    - Islet/Notch/BasicOutfitState.swift
  modified: []

key-decisions:
  - "LocationProvider is a pure one-shot wrapper (requestLocation() only) — no significant-location-change monitoring, matching RESEARCH.md's Don't Hand-Roll guidance"
  - "WeatherGlance carries WeatherKit's own Measurement<UnitTemperature> directly — no manual unit conversion; render layer formats locale-aware"
  - "EventKitService reads ALL active calendars (store.calendars(for: .event)) with no per-calendar filter, per D-02"

patterns-established:
  - "Permission-gated external services settle nil on denial/failure with zero retry — this plan's three services all follow LicenseService.swift's file-header CONTRACT comment convention"

requirements-completed: [WEATHER-01, CAL-01]

duration: 6min
completed: 2026-07-08
---

# Phase 14 Plan 03: Location/Weather/Calendar Services + BasicOutfitState Summary

**Three permission-gated, protocol-isolated external services (CoreLocation one-shot, WeatherKit fetch, EventKit fetch) plus the minimal `BasicOutfitState` published model, none yet wired into the controller.**

## Performance

- **Duration:** 6 min
- **Started:** 2026-07-08T12:29:00Z (approx.)
- **Completed:** 2026-07-08T12:35:09Z
- **Tasks:** 3/3 completed
- **Files modified:** 4 created, 0 modified

## Accomplishments
- `LocationProvider` — one-shot `CLLocationManagerDelegate` wrapper that settles `nil` on any denial/restriction/failure with no retry (D-01)
- `WeatherService`/`WeatherKitService` — fetches current weather, maps through 14-01's `WeatherCategory.from(_:)`, settles `nil` on any thrown error
- `CalendarService`/`EventKitService` — queries all active calendars, maps `EKEvent` to `EventInput` (untrusted title passed through as plain `String`), uses 14-01's `nextRelevantEvent(events:now:)`, settles `nil` on access denial
- `BasicOutfitState` — a minimal 2-property `@Published` holder with zero fetch logic, mirroring `NowPlayingState`'s shape

## Task Commits

Each task was committed atomically:

1. **Task 1: LocationProvider — one-shot device location (D-01)** - `c559275` (feat)
2. **Task 2: WeatherService — protocol + WeatherGlance + WeatherKitService conformer (D-01/D-06)** - `38bd6ef` (feat)
3. **Task 3: CalendarService (D-02/D-03) + BasicOutfitState** - `c69654a` (feat)

## Files Created/Modified
- `Islet/Location/LocationProvider.swift` - One-shot `requestOnce(completion:)`, no persistent tracking
- `Islet/Weather/WeatherService.swift` - `WeatherService` protocol, `WeatherGlance`, `WeatherKitService`
- `Islet/Calendar/CalendarService.swift` - `CalendarService` protocol, `EventKitService`
- `Islet/Notch/BasicOutfitState.swift` - `@Published weather`/`@Published calendar` holder

## Decisions Made
- Verified `project.yml` already carries `INFOPLIST_KEY_NSLocationWhenInUseUsageDescription`, `INFOPLIST_KEY_NSCalendarsUsageDescription`, and `INFOPLIST_KEY_NSCalendarsFullAccessUsageDescription` (added ahead of this plan) — no missing usage-description gap that would hard-crash the first permission prompt (mirrors the project's prior `NSBluetoothAlwaysUsageDescription` finding).
- `Islet/Islet.entitlements` already carries `com.apple.developer.weatherkit` — no entitlement gap for `WeatherKitService`.

## Deviations from Plan

None — plan executed exactly as written. One wording tweak: `LocationProvider.swift`'s file-header comment originally referenced the literal string `startUpdatingLocation` in prose, which collided with the acceptance-criteria grep expecting a zero count for that string; reworded to "no continuous updates" to preserve the same meaning without a false-positive match. Not a deviation rule (no code/behavior change), just comment wording.

## Issues Encountered
None.

## Next Phase Readiness
- 14-04's controller can now inject `LocationProvider`, `WeatherKitService`, `EventKitService`, and `BasicOutfitState` — wiring them into `NotchWindowController` and the coarse refresh timer is the next plan's scope.

## Self-Check: PASSED

- FOUND: Islet/Location/LocationProvider.swift
- FOUND: Islet/Weather/WeatherService.swift
- FOUND: Islet/Calendar/CalendarService.swift
- FOUND: Islet/Notch/BasicOutfitState.swift
- FOUND commit: c559275
- FOUND commit: 38bd6ef
- FOUND commit: c69654a
- `xcodebuild build -scheme Islet` succeeded after each task and after the final task.

---
*Phase: 14-basic-outfit-weather-calendar-date-display-with-weather-driv*
*Plan: 03*
*Completed: 2026-07-08*
