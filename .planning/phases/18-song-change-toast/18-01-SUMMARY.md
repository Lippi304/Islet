---
phase: 18-song-change-toast
plan: 01
subsystem: ui
tags: [swiftui, xctest, pure-seam, foundation-only]

# Dependency graph
requires:
  - phase: 17-now-playing-launch-gating
    provides: hasPlayedSinceLaunch (NowPlayingState) + nowPlayingLaunchGate(...) pattern this plan mirrors
provides:
  - TrackToast value type + songChangeToastContent(previous:current:hasPlayedSinceLaunch:) pure detection function
  - NowPlayingState.songChangeToast published field (separate from presentation, D-03)
  - songChangeToastGate(activeTransient:isExpanded:toastEnabled:) pure suppression gate (D-02/D-04/NOW-06)
  - ActivitySettings.songChangeToastKey + SettingsView Activities-tab Toggle, default true
affects: [18-02-controller-ui-wiring]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Toast suppression modeled as a standalone pure gate function outside resolve()/IslandPresentation, deliberately diverging from RESEARCH.md's Architectural Responsibility Map (see 18-01-PLAN.md objective + inline doc comments for the full reconciliation)"

key-files:
  created: []
  modified:
    - Islet/Notch/NowPlayingPresentation.swift
    - Islet/Notch/NowPlayingState.swift
    - Islet/Notch/IslandResolver.swift
    - Islet/ActivitySettings.swift
    - Islet/SettingsView.swift
    - IsletTests/NowPlayingPresentationTests.swift
    - IsletTests/IslandResolverTests.swift

key-decisions:
  - "songChangeToastGate(...) is a standalone pure function, never called by resolve(...) — the toast is a separate @Published field the controller (Plan 02) reads directly, per CONTEXT.md's explicit discretion note and 18-RESEARCH.md's own resolved Open Question #1"

requirements-completed: [NOW-05, NOW-06]

# Metrics
duration: ~15min
completed: 2026-07-09
---

# Phase 18 Plan 01: Song-Change Toast Pure Seam + Settings Toggle Summary

**Pure, unit-tested Foundation-only detection/suppression seam for the song-change toast (TrackToast + songChangeToastContent + songChangeToastGate) plus the NOW-06 Settings toggle — no user-observable behavior ships yet, this locks the contracts Plan 02 wires against.**

## Performance

- **Duration:** ~15 min
- **Completed:** 2026-07-09T13:11:15Z
- **Tasks:** 3 completed
- **Files modified:** 7

## Accomplishments
- `TrackToast` + `songChangeToastContent(previous:current:hasPlayedSinceLaunch:)` in `NowPlayingPresentation.swift`, reusing `isSameTrack(_:_:)` verbatim, with 5 new regression tests (genuine change, genuine change from paused, same-track play/pause, first-track-after-launch, stop)
- `NowPlayingState.songChangeToast: TrackToast?` published field, stored separately from `presentation` (D-03 rapid-skip safety)
- `songChangeToastGate(activeTransient:isExpanded:toastEnabled:)` in `IslandResolver.swift` as a standalone pure function outside `resolve(...)`/`IslandPresentation`, with 5 new regression tests (D-02 charging, D-02 device, D-04 expanded, NOW-06 toggle-off, the single allow case)
- `ActivitySettings.songChangeToastKey` + `SettingsView` Activities-tab `Toggle("Song-Change Toast", ...)` positioned between "Now Playing" and "Devices", default-true `@AppStorage`

## Task Commits

Each task was committed atomically (TDD tasks split into test → feat commits):

1. **Task 1: TrackToast + songChangeToastContent(...) pure detection function**
   - `a7a9e5a` (test) — RED: 5 failing tests added
   - `d0816e6` (feat) — GREEN: TrackToast + songChangeToastContent(...) + NowPlayingState field implemented
2. **Task 2: songChangeToastGate(...) pure suppression gate (D-02/D-04/NOW-06)**
   - `71c98b9` (test) — RED: 5 failing tests added
   - `913b705` (feat) — GREEN: songChangeToastGate(...) implemented
3. **Task 3: NOW-06 Settings toggle — songChangeToastKey + Activities tab Toggle**
   - `1768711` (feat)

_TDD tasks 1 and 2 each produced two commits (test → feat); no refactor commit was needed in either case (the GREEN implementation matched the plan's exact minimal-diff spec on the first pass)._

## Files Created/Modified
- `Islet/Notch/NowPlayingPresentation.swift` - Added `TrackToast` struct + `songChangeToastContent(...)` pure function
- `Islet/Notch/NowPlayingState.swift` - Added `songChangeToast: TrackToast?` published field
- `Islet/Notch/IslandResolver.swift` - Added `songChangeToastGate(...)` pure suppression gate
- `Islet/ActivitySettings.swift` - Added `songChangeToastKey` constant
- `Islet/SettingsView.swift` - Added `songChangeToastEnabled` @AppStorage binding + Activities-tab Toggle
- `IsletTests/NowPlayingPresentationTests.swift` - 5 new regression tests for `songChangeToastContent(...)`
- `IsletTests/IslandResolverTests.swift` - 5 new regression tests for `songChangeToastGate(...)`

## Decisions Made
- Confirmed and executed the plan's pre-documented deviation from 18-RESEARCH.md's Architectural Responsibility Map: `songChangeToastGate(...)` stays outside `resolve(...)`/`IslandPresentation` entirely, as a standalone pure function the controller (Plan 02) will call directly. This is safe because its two live inputs are read from the exact same state `resolve(...)` itself consumes, so the two can never disagree. Full rationale lives in `18-01-PLAN.md`'s `<objective>` section and in the function's own doc comment.

## Deviations from Plan

None - plan executed exactly as written. All acceptance criteria (exact test method names/order, exact grep counts, exact `Section("Activities")` toggle order, `isSameTrack(...)` reuse, zero touched pre-existing `resolve(...)` call sites) were verified before each commit.

## Issues Encountered

None. Note on verification method: this codebase's known constraint (`xcodebuild test` hangs in headless/non-interactive environments due to a Bluetooth TCC-authorization wait — see project memory `xcodebuild-test-headless-hang`) means the RED/GREEN gates for both TDD tasks were verified via `xcodebuild build-for-testing` (which compiles the `IsletTests` target without running it) rather than a live `xcodebuild test` run. RED was confirmed by an actual `TEST BUILD FAILED` (undefined symbols) before each implementation, and GREEN by `TEST BUILD SUCCEEDED` after. A full Cmd-U run to execute the new tests is still recommended per this plan's `<verification>` step 2, but is a manual on-device step per this project's established `xcodebuild test` limitation.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Plan 02 can now wire the controller/UI layer against the exact contracts locked here: call `songChangeToastContent(...)` on each now-playing callback (with the PRE-callback `hasPlayedSinceLaunch` value), gate the result through `songChangeToastGate(...)`, set `NowPlayingState.songChangeToast` when both pass, and read `ActivitySettings.songChangeToastKey` via `activityEnabled(...)` as the gate's `toastEnabled` input. No blockers.

---
*Phase: 18-song-change-toast*
*Completed: 2026-07-09*

## Self-Check: PASSED

All 7 modified files and all 6 commit hashes verified present.
