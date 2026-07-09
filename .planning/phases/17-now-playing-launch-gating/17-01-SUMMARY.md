---
phase: 17-now-playing-launch-gating
plan: 01
subsystem: ui
tags: [swiftui, appkit, notch, now-playing, state-machine]

# Dependency graph
requires:
  - phase: 06-priority-resolver-device-activity
    provides: "IslandResolver.resolve(...) pure priority arbiter and nowPlayingHealthGate(...) precedent to mirror"
  - phase: 04-now-playing-media-controls
    provides: "NowPlayingState, NowPlayingPresentation, NotchWindowController.handleNowPlaying(...)"
provides:
  - "NowPlayingState.hasPlayedSinceLaunch flag (default false, set once on first .playing, never reset)"
  - "IslandResolver.nowPlayingLaunchGate(hasPlayedSinceLaunch:nowPlaying:) pure TOTAL helper"
  - "resolve(...) updated signature gating only the non-expanded ambient branch"
  - "NotchWindowController wiring: currentPresentation() threads the flag, handleNowPlaying flips it BEFORE renderPresentation()"
  - "4 new IslandResolverTests.swift regression tests + 7 existing calls updated"
affects: [18-song-change-toast]

# Tech tracking
tech-stack:
  added: []
  patterns: ["pure-seam gate helper mirroring nowPlayingHealthGate", "flag-flip-before-render ordering discipline in handleNowPlaying"]

key-files:
  created: []
  modified:
    - Islet/Notch/NowPlayingState.swift
    - Islet/Notch/IslandResolver.swift
    - IsletTests/IslandResolverTests.swift
    - Islet/Notch/NotchWindowController.swift

key-decisions:
  - "Gate implemented as a new resolve(...) parameter (hasPlayedSinceLaunch: Bool) rather than a second nowPlaying input — smaller diff, keeps resolve() the single self-contained arbiter (D-05)"
  - "Flag flip placed BEFORE the withAnimation/renderPresentation() block in handleNowPlaying (not inside the post-render switch), so the triggering .playing snapshot's own render already reflects the lifted gate"

patterns-established:
  - "nowPlayingLaunchGate(...) — TOTAL pure helper mirroring nowPlayingHealthGate's shape, gates one input to resolve()'s non-expanded branch only"

requirements-completed: []  # NOW-04 NOT marked complete — Task 3 (on-device checkpoint) is pending human verification

# Metrics
duration: ~20min (Tasks 1-2; Task 3 pending)
completed: 2026-07-09
---

# Phase 17 Plan 01: Now Playing Launch Gating Summary

**hasPlayedSinceLaunch flag + nowPlayingLaunchGate pure helper gate the ambient Now Playing wings glance until a real Play is observed this Islet session — checkpoint pending on-device verification.**

## Performance

- **Duration:** ~20 min (Tasks 1-2 automated; Task 3 is an on-device human-verify checkpoint, not yet performed)
- **Completed (Tasks 1-2):** 2026-07-09T11:18:37Z
- **Tasks:** 2 of 3 complete (Task 3 checkpoint reached, awaiting on-device verification)
- **Files modified:** 4

## Accomplishments
- Added `NowPlayingState.hasPlayedSinceLaunch: Bool = false`, orthogonal to `presentation`, mirroring `isHealthy`'s pattern
- Added `IslandResolver.nowPlayingLaunchGate(hasPlayedSinceLaunch:nowPlaying:) -> NowPlayingPresentation`, a TOTAL pure helper mirroring `nowPlayingHealthGate`'s shape
- Extended `resolve(...)`'s signature with `hasPlayedSinceLaunch: Bool` (positioned after `nowPlayingHealthy`, before `isExpanded`), applied ONLY inside the non-expanded branch — the `isExpanded` branch body is byte-for-byte unchanged (D-03)
- Wired `currentPresentation()` to thread `nowPlayingState.hasPlayedSinceLaunch` into every `resolve(...)` call
- Wired `handleNowPlaying(_:_:)` to flip the flag `true` (guarded by `if case .playing = p`) BEFORE the `withAnimation`/`renderPresentation()` block — critical ordering fix flagged by the planner's checker: had the flip lived inside the post-render `switch p` block instead, the very snapshot that lifts the gate would itself render gated
- Added 4 new regression tests to `IslandResolverTests.swift` and updated all 7 pre-existing `resolve(...)` calls with `hasPlayedSinceLaunch: true` to preserve their already-lifted-gate semantics

## Task Commits

Each task was committed atomically (Task 1 followed RED→GREEN per its `tdd="true"` attribute):

1. **Task 1 (RED): failing regression coverage** - `aa2c01c` (test)
2. **Task 1 (GREEN): flag + gate helper + resolve() signature** - `65cb784` (feat)
3. **Task 2: wire controller (flag flip + thread into resolve)** - `5a408fa` (feat)

Task 3 (checkpoint:human-verify, gate="blocking") has NOT been performed — this SUMMARY documents Tasks 1-2 only.

## Files Created/Modified
- `Islet/Notch/NowPlayingState.swift` - added `hasPlayedSinceLaunch: Bool = false` field
- `Islet/Notch/IslandResolver.swift` - added `nowPlayingLaunchGate(...)` helper, extended `resolve(...)` signature, gated the non-expanded ambient branch only
- `IsletTests/IslandResolverTests.swift` - 4 new tests (`testNowPlayingLaunchGateForcesNoneWhenNotYetPlayed`, `testGatedPausedNotExpandedIsIdle`, `testGatedPausedExpandedStillShowsRealState`, `testGateLiftedPausedNotExpandedShowsWings`) + 7 existing calls updated with `hasPlayedSinceLaunch: true`
- `Islet/Notch/NotchWindowController.swift` - `currentPresentation()` threads the flag into `resolve(...)`; `handleNowPlaying(_:_:)` flips the flag before the render call

## Decisions Made
- Chose "gate inside `resolve`'s non-expanded branch via a new parameter" (mechanism 2 from `17-PATTERNS.md`) over "gate before resolve with a second nowPlaying input" — smaller diff, keeps `resolve(...)` the single self-contained arbiter (D-05), and matches the codebase's `nowPlayingHealthGate` precedent exactly.
- Placed the flag flip in `handleNowPlaying` BEFORE the `withAnimation`/`renderPresentation()` block rather than inside the post-render `switch p { case .playing: ... }` block — the plan explicitly flagged the latter as a checker-caught bug (the triggering snapshot would itself render gated). Verified via a line-order check (`hasPlayedSinceLaunch = true` appears before the `renderPresentation()` call, both within the same `handleNowPlaying` invocation).

## Deviations from Plan

None — plan executed exactly as written. Both Task 1 and Task 2 automated `<verify>` commands passed:
- Task 1: `xcodebuild build` reported `BUILD FAILED` (expected — controller call site outdated, resolved by Task 2)
- Task 2: `xcodebuild build` reported `BUILD SUCCEEDED`, and the line-order check confirmed the flag flip precedes the render call within the same `handleNowPlaying` invocation

One wording adjustment during Task 2: the inline comment explaining the ordering originally repeated the literal string `renderPresentation()` before the real call, which would have confused the plan's own line-order grep check (it matches on the first occurrence of that literal string, including inside comments). Reworded the comment to say "the render call" instead, without changing any logic — not a deviation from the plan's *behavior*, just a comment-wording fix to keep the automated verification unambiguous.

## Issues Encountered

`xcodebuild test` was not run (per project memory `xcodebuild-test-headless-hang`: the test target hosts the full `Islet.app`, which boots `NSPanel`/MediaRemote/IOBluetooth and hangs headless). The `xcodebuild build` gate was used as the automated proxy per the plan's own `<verify>` commands; the 4 new `IslandResolverTests.swift` cases have NOT yet been compiler-verified or run — that is deferred to the on-device Cmd-U step inside Task 3's checkpoint, per the plan's `<what-built>` note.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

**Task 3 is an unresolved `checkpoint:human-verify` gate (`gate="blocking"`) — this plan is NOT complete.** The on-device verification (Cmd-U test run + 5 manual launch/expand/play/pause/relaunch scenarios) described in the plan's Task 3 must be performed and approved before:
- `requirements-completed` can include NOW-04
- STATE.md / ROADMAP.md can be advanced past this plan
- Phase 18 (song-change toast) can safely build on this gating state

See `.planning/phases/17-now-playing-launch-gating/17-01-PLAN.md` Task 3 for the exact checkpoint content (what-built / how-to-verify / resume-signal).

## Self-Check: PASSED

- FOUND: Islet/Notch/NowPlayingState.swift (hasPlayedSinceLaunch field present)
- FOUND: Islet/Notch/IslandResolver.swift (nowPlayingLaunchGate helper + resolve() signature present)
- FOUND: IsletTests/IslandResolverTests.swift (4 new tests + 7 updated calls present)
- FOUND: Islet/Notch/NotchWindowController.swift (flag threading + flip-before-render present)
- FOUND commit aa2c01c (test: RED)
- FOUND commit 65cb784 (feat: GREEN — flag + helper)
- FOUND commit 5a408fa (feat: controller wiring)
- BUILD SUCCEEDED confirmed after Task 2

---
*Phase: 17-now-playing-launch-gating*
*Completed (Tasks 1-2 only): 2026-07-09 — Task 3 checkpoint pending*
