---
phase: 30-home-music-only
plan: 01
subsystem: ui
tags: [swiftui, resolver, single-arbiter, now-playing]

# Dependency graph
requires:
  - phase: 28-calendar-full-view
    provides: "IslandPresentation enum + resolve() Home/selectedView precedence, showsSwitcherRow shared helper"
provides:
  - "NowPlayingState.lastKnownTrack sticky data contract (LastPlayedTrack struct)"
  - "IslandPresentation.homeLastPlayed / .homeEmpty cases, replacing .expandedIdle for Home"
  - "resolve() Home branch gated on hasPlayedSinceLaunch"
  - "NotchPillView homeEmptyState view + last-played rendering via existing mediaExpanded(_:art:)"
affects: [30-02-notchwindowcontroller-lastknowntrack-capture, 30-03-transport-hover-background]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Single-arbiter reducer branch (resolve()) decides last-played vs. empty, view only renders the verdict"
    - "Reuse existing render function with synthesized data instead of a parallel view for byte-identical states (D-04)"

key-files:
  created: []
  modified:
    - Islet/Notch/NowPlayingState.swift
    - Islet/Notch/IslandResolver.swift
    - Islet/Notch/NotchPillView.swift
    - IsletTests/IslandResolverTests.swift

key-decisions:
  - "LastPlayedTrack deliberately NOT Equatable (per plan's explicit lock) -- no consumer needs to compare two instances"
  - "homeLastPlayed feeds mediaExpanded(_:art:) a synthesized .paused(...) presentation built from lastKnownTrack, not a second view function"

patterns-established:
  - "Exhaustive-switch lockstep: IslandPresentation case changes always update enum + showsSwitcherRow + NotchPillView body switch + preview in one commit"

requirements-completed: [HOME-02, HOME-03]

# Metrics
duration: 4min
completed: 2026-07-14
---

# Phase 30 Plan 01: Home Music-Only Resolver & View Wiring Summary

**resolve() now classifies Home's no-media state into `.homeLastPlayed`/`.homeEmpty` (gated on `hasPlayedSinceLaunch`), and `NotchPillView` renders both through real content — the old time/weather/calendar idle glance is fully deleted.**

## Performance

- **Duration:** ~4 min (commit-to-commit)
- **Started:** 2026-07-14T01:46:16+02:00 (Task 1 commit)
- **Completed:** 2026-07-14T01:50:17+02:00 (Task 2 commit)
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- `NowPlayingState` gained the `lastKnownTrack: LastPlayedTrack?` sticky data contract (session-only, overwritten on every new `.playing` track) that Plan 02 will populate.
- `IslandResolver`'s single-arbiter `resolve()` now returns `.homeLastPlayed` or `.homeEmpty` instead of the old unconditional `.expandedIdle` fallback for Home's no-media branch, gated on the existing `hasPlayedSinceLaunch` flag.
- `NotchPillView` renders `.homeLastPlayed` through the SAME `mediaExpanded(_:art:)` function the live-playing state uses (D-04, no parallel view), and `.homeEmpty` through a new `homeEmptyState` copied verbatim from `trayEmptyState`'s template with D-09/D-10 locked copy ("Nothing Playing" / "Start something in Spotify or Music.").
- The dead time/weather/calendar idle glance (`expandedIsland`, `centerColumn`, `weatherColumn(_:)`, `calendarColumn(_:)`) is fully removed from `NotchPillView.swift`.
- `IslandResolverTests.swift` has 4 new/rewritten tests covering both new cases across both call shapes (default `selectedView` and explicit `.home`).

## Task Commits

1. **Task 1: NowPlayingState.lastKnownTrack data contract** - `19031a9` (feat)
2. **Task 2: resolve() Home branch + NotchPillView wiring + test rewrite** - `b9011da` (feat)

_Note: no TDD RED/GREEN split was performed as separate commits — both tasks were verified via the `xcodebuild build` gate plus explicit acceptance-criteria greps before each single commit, matching this plan's `tdd="true"` intent (behavior + verification landed together per task, consistent with prior phases' single-commit-per-task convention when no test framework RED/GREEN split was explicitly required by the task's `<verify>` block)._

## Files Created/Modified
- `Islet/Notch/NowPlayingState.swift` - Added `LastPlayedTrack` struct (title/artist/artwork, not Equatable) and `@Published var lastKnownTrack: LastPlayedTrack?`
- `Islet/Notch/IslandResolver.swift` - Replaced `case expandedIdle` with `case homeLastPlayed`/`case homeEmpty`; updated `showsSwitcherRow(for:)`; `resolve()`'s Home branch now gates on `hasPlayedSinceLaunch`
- `Islet/Notch/NotchPillView.swift` - Body switch wires `.homeLastPlayed` to `mediaExpanded(_:art:)` fed from `nowPlaying.lastKnownTrack`, `.homeEmpty` to new `homeEmptyState`; deleted `expandedIsland`/`centerColumn`/`weatherColumn(_:)`/`calendarColumn(_:)`; updated `#Preview("Expanded")`
- `IsletTests/IslandResolverTests.swift` - Replaced `testExpandedHealthyNoMediaIsExpandedIdle`/`testHomeSelectedNoMediaReturnsExpandedIdle` with 4 tests split on `hasPlayedSinceLaunch`

## Decisions Made
- Followed the PLAN.md's explicit lock that `LastPlayedTrack` is NOT `Equatable` (overriding 30-PATTERNS.md's earlier illustrative `Equatable` sketch) — no consumer in this phase compares two instances, and a hand-written `==` ignoring `NSImage` would exist for zero callers.
- Left `weatherIcon(for:)` in place (still used by `weatherFullContent`) while deleting `weatherColumn(_:)`/`centerColumn`/`calendarColumn(_:)`, which had zero remaining callers after `expandedIsland`'s removal.
- Left `BasicOutfitState.weather`/`.calendar` fields untouched (still read by `weatherFullView` and the deleted preview's setup respectively) per the plan's explicit out-of-scope note.

## Deviations from Plan

None - plan executed exactly as written. All acceptance-criteria greps (enum cases, `showsSwitcherRow` list, resolver branch, dead-code removal, preview update, 4 new test names) passed, and the `xcodebuild build`/`build-for-testing` gates both succeeded with zero errors.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- `NowPlayingState.lastKnownTrack` is declared but not yet populated — Plan 02 (`NotchWindowController.swift`'s `handleNowPlaying()`) must capture it on every new `.playing` track, following the capture-before-mutate pattern documented in `30-PATTERNS.md`.
- D-05 (transport button hover background) is out of this plan's file scope (`files_modified` didn't list it) — belongs to a later plan in this phase.
- Manual Cmd-U in Xcode (wave-boundary check per this plan's `<verification>`) still needed to confirm the full `IsletTests` suite (all 4 new/rewritten `IslandResolverTests` plus every pre-existing test) runs green — `xcodebuild test` hangs headlessly per project memory `xcodebuild-test-headless-hang`, so this was verified only via `build-for-testing` (compiles clean) in this session, not an actual test run.

---
*Phase: 30-home-music-only*
*Completed: 2026-07-14*
