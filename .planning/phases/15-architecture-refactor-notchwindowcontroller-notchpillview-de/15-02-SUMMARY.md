---
phase: 15-architecture-refactor-notchwindowcontroller-notchpillview-de
plan: 02
subsystem: infra
tags: [swift, corelocation, di, protocol-seam, mainactor, timer-gating]

# Dependency graph
requires:
  - phase: 14-basic-outfit-weather-calendar-date-display-with-weather-driv
    provides: BasicOutfitState, WeatherService/CalendarService protocol pattern, NotchWindowController's outfit-refresh timer
provides:
  - LocationService protocol + LocationProvider conformance (zero body change)
  - BasicOutfitState marked @MainActor
  - NotchWindowController.locationProvider stored as the protocol type
  - isCurrentlyVisible-gated 15-min outfit-refresh timer (D-06)
  - LocationServiceTests.swift proving the seam is fake-injectable
affects: [16-notchwindowcontroller-devicecoordinator-extraction]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Protocol-isolation for fragile externals (LocationService mirrors WeatherService/CalendarService/LicenseService) — one AnyObject protocol, one final class conformer, main-thread CONTRACT comment"
    - "isCurrentlyVisible flag set inside updateVisibility()'s shown/hidden branches, consumed by a Timer guard to stop background work while the island is hidden"

key-files:
  created:
    - IsletTests/LocationServiceTests.swift
  modified:
    - Islet/Location/LocationProvider.swift
    - Islet/Notch/BasicOutfitState.swift
    - Islet/Notch/NotchWindowController.swift
    - Islet.xcodeproj/project.pbxproj

key-decisions:
  - "LocationProvider's body (requestOnce, delegate callbacks) left byte-identical — only the protocol declaration + conformance were added, preserving D-01's silent-omission contract untouched"
  - "wasVisible captured as the first line of updateVisibility() so the hidden-to-visible refresh trigger fires exactly once per transition, not on every call while already visible"

patterns-established:
  - "New DI seams for fragile/external-facing classes follow the WeatherService/CalendarService/LicenseService template verbatim (protocol above class, CONTRACT comment, zero call-site behavior change)"

requirements-completed: [P15-ITEM3, P15-ITEM5]

# Metrics
duration: 6min
completed: 2026-07-08
---

# Phase 15 Plan 02: LocationService Protocol Seam + Outfit-Refresh Visibility Gate Summary

**LocationProvider now conforms to a LocationService protocol seam (mirroring WeatherService/CalendarService), BasicOutfitState is @MainActor, and the 15-minute outfit-refresh Timer no longer fires WeatherKit/EventKit calls while the island is hidden.**

## Performance

- **Duration:** 6 min (task commits 19:18:11 → 19:19:17 CEST, plus on-device checkpoint verification by the user)
- **Started:** 2026-07-08T17:18:11Z
- **Completed:** 2026-07-08T17:24:40Z
- **Tasks:** 3 (2 auto + 1 checkpoint:human-verify)
- **Files modified:** 4 (1 created)

## Accomplishments
- `LocationService` protocol added with a main-thread CONTRACT comment; `LocationProvider` conforms with zero body changes (D-01's silent-omission contract untouched)
- `BasicOutfitState` marked `@MainActor`, matching `WeatherService`/`CalendarService`'s documented main-thread delivery contract
- `NotchWindowController.locationProvider` now stored as the `LocationService` protocol type
- Closed the "arbiter gap": the 15-min outfit-refresh `Timer` now early-returns while the island is hidden (fullscreen or expired trial) via a new `isCurrentlyVisible` flag set inside `updateVisibility()`'s shown/hidden branches; a hidden-to-visible transition resumes weather/calendar refresh immediately instead of waiting for the next 15-min tick
- `IsletTests/LocationServiceTests.swift` added — proves `LocationProvider: LocationService` compiles and a `FakeLocationService` can be injected in place of the concrete CLLocationManager-backed class
- User completed the 5-step on-device checkpoint (Xcode Debug run, fullscreen/expired-license hide, timer-fire-while-hidden check, resume-on-show check, `expandedIdle` visual regression check) and confirmed **approved**

## Task Commits

Each task was committed atomically:

1. **Task 1: Protocolize LocationProvider, mark BasicOutfitState @MainActor, add LocationServiceTests** - `193206c` (feat)
2. **Task 2: Wire the protocol type into the controller and close the arbiter visibility gap** - `494dcce` (fix)
3. **Task 3: On-device arbiter gap check** - verification-only checkpoint, no code changes; confirmed "approved" by the user against the 5 `<how-to-verify>` steps in the plan

## Files Created/Modified
- `Islet/Location/LocationProvider.swift` - Added `LocationService` protocol + main-thread CONTRACT comment; `LocationProvider` now conforms alongside `CLLocationManagerDelegate`
- `Islet/Notch/BasicOutfitState.swift` - Added `@MainActor`
- `Islet/Notch/NotchWindowController.swift` - `locationProvider` stored as `LocationService`; new `isCurrentlyVisible` flag; `updateVisibility()` sets it true/false and fires an immediate refresh on the hidden→visible edge; the outfit-refresh `Timer`'s repeating closure now guards on `isCurrentlyVisible`
- `IsletTests/LocationServiceTests.swift` - New: `FakeLocationService` + 2 tests proving the protocol conformance and fake-injectability
- `Islet.xcodeproj/project.pbxproj` - Regenerated via `xcodegen generate` to pick up the new test file

## Decisions Made
- LocationProvider's existing delegate methods stayed byte-identical — only the protocol declaration and `LocationService` conformance were added, per the plan's explicit "no other change" instruction (D-01's contract preserved)
- `wasVisible` captured as the very first line of `updateVisibility()`, before the license-driven `midInteraction` early return, so the resume-refresh trigger correctly reflects the pre-call state on every invocation

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- `LocationService` seam is now consistent with `WeatherService`/`CalendarService`/`LicenseService`'s established DI pattern, ready for Phase 16's coordinator extraction to build on
- The outfit-refresh timer no longer leaks WeatherKit/EventKit calls while hidden (T-15-01 closed)
- `xcodebuild build-for-testing` passes; full `IsletTests` suite (including the new `LocationServiceTests`) confirmed green via the user's on-device Cmd-U pass during the Task 3 checkpoint
- No blockers for Phase 16

---
*Phase: 15-architecture-refactor-notchwindowcontroller-notchpillview-de*
*Completed: 2026-07-08*
