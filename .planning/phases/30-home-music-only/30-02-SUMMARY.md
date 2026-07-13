---
phase: 30-home-music-only
plan: 02
subsystem: ui
tags: [swiftui, mediaremote, controller, hover]

# Dependency graph
requires:
  - phase: 30-home-music-only (plan 01)
    provides: "NowPlayingState.lastKnownTrack sticky data contract (LastPlayedTrack struct), IslandPresentation.homeLastPlayed/.homeEmpty cases"
provides:
  - "handleNowPlaying() populates lastKnownTrack with real title/artist/artwork on every .playing snapshot"
  - "TransportButton View struct with hover-triggered rounded-rectangle background (D-05)"
affects: [30-03-checkpoint-uat]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Capture-before-mutate discipline extended to lastKnownTrack, mirroring hadPlayedSinceLaunch/previous/previousPosition"
    - "Function-to-View-struct conversion when @State is needed (transportButton -> TransportButton)"

key-files:
  created: []
  modified:
    - Islet/Notch/NotchWindowController.swift
    - Islet/Notch/NotchPillView.swift

key-decisions:
  - "lastKnownTrack capture placed immediately before the existing artwork nil-clear branch, using the same art ?? nowPlayingState.artwork latency fallback, per plan's explicit Pitfall-1 ordering requirement"

patterns-established: []

requirements-completed: [HOME-02]

# Metrics
duration: 6min
completed: 2026-07-14
---

# Phase 30 Plan 02: NotchWindowController lastKnownTrack Capture & Transport Hover Summary

**`handleNowPlaying()` now feeds Plan 01's `.homeLastPlayed` state real title/artist/artwork data, and all 3 real transport buttons show a D-05 rounded-rectangle hover background.**

## Performance

- **Duration:** ~6 min (commit-to-commit)
- **Started:** 2026-07-14 (Task 1 commit)
- **Completed:** 2026-07-14 (Task 2 commit)
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- `handleNowPlaying()` captures `nowPlayingState.lastKnownTrack = LastPlayedTrack(...)` on every real `.playing` snapshot, placed before the existing artwork nil-clear branch (Pitfall 1) and using the same `art ?? nowPlayingState.artwork` latency fallback as the artwork field itself.
- `lastKnownTrack` is never cleared by `handleNowPlaying()` — confirmed by `grep -c "nowPlayingState.lastKnownTrack = nil"` returning `0` — so it survives the transition to `.paused`/`.none` exactly as Plan 01's `.homeLastPlayed` resolver branch requires.
- `transportButton(_:action:)` converted from a plain function to a private `TransportButton: View` struct holding `@State private var isHovering`, rendering a `RoundedRectangle(cornerRadius: 8, style: .continuous)` background (white 12% opacity on hover, clear otherwise) behind the existing icon, wrapped in a 32x32 frame with `.onHover`.
- All 3 real transport buttons (`backward.fill`/`onPrevious`, `playpause.fill`/`onTogglePlayPause`, `forward.fill`/`onNext`) construct `TransportButton(systemName:action:)`; the 2 reserved Shuffle/Repeat `Color.clear` placeholder slots are untouched.

## Task Commits

1. **Task 1: Capture lastKnownTrack in handleNowPlaying()** - `ed06314` (feat)
2. **Task 2: Transport-button hover background (D-05)** - `6a7ea79` (feat)

## Files Created/Modified
- `Islet/Notch/NotchWindowController.swift` - Added `lastKnownTrack` capture inside `handleNowPlaying()`'s existing spring block, before the artwork nil-clear branch
- `Islet/Notch/NotchPillView.swift` - Replaced `transportButton(_:action:)` function with `TransportButton: View` struct (hover state + rounded-rectangle background); updated 3 call sites in `mediaExpanded`

## Decisions Made
- Followed the plan's exact ordering requirement (capture before the `if let art { ... }` nil-clear block) rather than placing it after — verified by reading the surrounding lines post-edit, not just grep line number.
- No deviation from the plan's locked hover-background values (8pt corner radius, white 12% opacity, 32x32 outer frame) — these are documented in 30-UI-SPEC.md as tunable defaults, left as specified since no on-device UAT feedback exists yet for this plan.

## Deviations from Plan

None - plan executed exactly as written. Both tasks' acceptance-criteria greps and the `xcodebuild build -project Islet.xcodeproj -scheme Islet -configuration Debug` gate passed after each task.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- `lastKnownTrack` is now genuinely populated and sticky; Plan 03's on-device checkpoint can verify Home's last-played state shows real title/artist/cover art with the new hover background on the 3 transport buttons.
- No blockers carried forward.

---
*Phase: 30-home-music-only*
*Completed: 2026-07-14*

## Self-Check: PASSED

All modified files verified present on disk; both commit hashes (ed06314, 6a7ea79) verified in git log.
