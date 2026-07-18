---
phase: 42-dual-activity-display
plan: 01
subsystem: ui
tags: [swift, resolver, pure-function, dynamic-island]

# Dependency graph
requires:
  - phase: 41-calendar-countdown-hud
    provides: CalendarCountdownActivity + resolve()'s .calendarCountdown ambient case
provides:
  - "SecondaryActivity enum (Foundation-only, Equatable)"
  - "resolveSecondary(primary:nowPlaying:) -> SecondaryActivity? pure function"
  - "IslandPresentationState.secondary: SecondaryActivity? published carrier"
affects: [42-02-dual-activity-display, 42-03-dual-activity-display, 42-04-dual-activity-display]

# Tech tracking
tech-stack:
  added: []
  patterns: ["pure reducer takes prior reducer's own output as input to structurally guarantee agreement, rather than re-deriving the same live facts a second time"]

key-files:
  created: []
  modified:
    - Islet/Notch/IslandResolver.swift
    - Islet/Notch/IslandPresentationState.swift
    - IsletTests/IslandResolverTests.swift

key-decisions:
  - "resolveSecondary(primary:nowPlaying:) intentionally does NOT take activeTransient/isExpanded as parameters — D-10/D-04's guarantees fall out of primary's own shape instead of re-checking those inputs a second time"

patterns-established:
  - "Secondary-activity output as an additive, structurally-can't-disagree companion to resolve()'s primary verdict"

requirements-completed: [DUAL-01]

# Metrics
duration: 10min
completed: 2026-07-18
---

# Phase 42 Plan 01: Secondary Activity Resolver Contract Summary

**`SecondaryActivity` enum + `resolveSecondary(primary:nowPlaying:)` pure function added to `IslandResolver.swift`, plus `IslandPresentationState.secondary` published carrier — establishes the dual-activity contract Plans 42-03/42-04 consume.**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-07-18T19:09:00Z
- **Completed:** 2026-07-18T19:14:07Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- `SecondaryActivity` enum (`.nowPlaying(NowPlayingPresentation)`) added as a Foundation-only, Equatable value type
- `resolveSecondary(primary:nowPlaying:)` TOTAL pure function added directly after `resolve(...)`, structurally unable to disagree with `resolve()`'s own primary verdict since it consumes that verdict as its `primary` input rather than re-deriving `activeTransient`/`isExpanded` facts independently
- `IslandPresentationState.secondary: SecondaryActivity?` published field added, defaulting to `nil`, mirroring `hoveredQuickActionButtonIndex`'s controller-owned/view-is-pure-consumer convention
- 5 new XCTest methods added covering D-01/D-02/D-03/D-04/D-10, all confirmed compiling via `xcodebuild build-for-testing` (project convention: `xcodebuild test` hangs headlessly, so Cmd-U remains the manual pass/fail gate — build-for-testing was used here as the best available automated proxy)

## Task Commits

Each task was committed atomically (TDD RED/GREEN split for Task 1):

1. **Task 1 RED: failing tests for resolveSecondary** - `68f1339` (test)
2. **Task 1 GREEN: resolveSecondary pure function** - `3e2238e` (feat)
3. **Task 2: IslandPresentationState.secondary field** - `5c7fff0` (feat)

**Plan metadata:** (this commit, following SUMMARY.md creation)

## Files Created/Modified
- `Islet/Notch/IslandResolver.swift` - `SecondaryActivity` enum + `resolveSecondary(primary:nowPlaying:)` added after `resolve(...)`, before `nowPlayingHealthGate`
- `Islet/Notch/IslandPresentationState.swift` - `@Published var secondary: SecondaryActivity? = nil` added below `hoveredQuickActionButtonIndex`
- `IsletTests/IslandResolverTests.swift` - 5 new test methods under `// MARK: Phase 42 / DUAL-01 — Secondary Activity`

## Decisions Made
- None beyond what the plan specified — `resolveSecondary` implemented exactly per the plan's `<action>` spec (guard `primary == .calendarCountdown`, guard `nowPlaying != .none`, return `.nowPlaying(nowPlaying)`).

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

`xcodebuild -scheme Islet build` (the plan's specified `<verify>` command) does not compile the `IsletTests` target at all — confirmed by observing `BUILD SUCCEEDED` on the RED commit despite `resolveSecondary` not yet existing anywhere in the codebase at that point. This matches this project's known, pre-documented limitation (`xcodebuild test` hangs headlessly due to a Bluetooth TCC-authorization wait in `BluetoothMonitor`, so test execution is gated to manual Cmd-U). To get real automated signal on the test file itself, `xcodebuild build-for-testing` was used instead (compiles the test target without executing it, and does not hit the hang) — it confirmed the RED state would have failed to compile, and confirmed the GREEN state compiles clean with all 5 new tests present. Manual Cmd-U execution to observe green checkmarks is still owed to the user per the plan's acceptance criteria and could not be performed by this agent.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- The `SecondaryActivity`/`resolveSecondary(primary:nowPlaying:)`/`IslandPresentationState.secondary` interface is now live exactly as specified in this plan's `<interfaces>` section — Plans 42-03 (view rendering) and 42-04 (controller wiring) can consume it without further codebase exploration.
- **Recommended before merging onward:** run Cmd-U in Xcode on `IslandResolverTests.swift` to get the real pass/fail signal this plan's acceptance criteria call for (`build-for-testing` only proves compilation, not correctness) — the 5 new tests are `testResolveSecondaryReturnsNowPlayingWhenCountdownIsPrimaryAndMediaLive`, `testResolveSecondaryNilWhenOnlyCountdownLive`, `testResolveSecondaryNilWhenOnlyNowPlayingLive`, `testResolveSecondaryNilWhenTransientStanding`, `testResolveSecondaryNilWhenExpanded`.
- No blockers for Plan 42-02/42-03/42-04.

---
*Phase: 42-dual-activity-display*
*Completed: 2026-07-18*
