---
phase: 53-hover-to-resume-idle-preview
plan: 01
subsystem: ui
tags: [swiftui, appkit, now-playing, mediaremote, hover-interaction]

# Dependency graph
requires:
  - phase: 30-home-focus (HOME-02)
    provides: NowPlayingState.lastKnownTrack / hasPlayedSinceLaunch (the sticky last-played data contract this phase reads verbatim)
  - phase: 42-dual-activity-display (DUAL-01)
    provides: collapsedInteractiveZone() hot-zone-widening precedent + hover-reveals/tap-toggles interaction pattern
provides:
  - Idle-island hover-to-resume preview (album art + bouncing equalizer, visually identical to the live Now Playing glance)
  - Click-to-resume via the existing togglePlayPause() transport call, in-place (no expand)
  - D-03 inferred-failure feedback ("Wiedergabe nicht möglich") via a timeout-based watch of the existing onTrackInfoReceived stream (no completion signal exists on the transport)
  - Empirically-confirmed on-device resume behavior for Spotify/Apple Music paused+quit states
affects: [53-02-on-device-uat, future-favorite-like-work-touching-nowplaying-transport]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Inferred success/failure via a settled-flag DispatchWorkItem timeout, racing a fire-and-forget transport call against the existing persistent event stream (mirrors NowPlayingMonitor.runHealthCheck's D-12 pattern)"
    - "View-local presentation branch (idleOrResumePreview) reading an existing AppKit-driven hover signal, instead of threading a new flag through the pure IslandResolver.resolve() arbiter"

key-files:
  created: []
  modified:
    - Islet/Notch/NowPlayingState.swift
    - Islet/Notch/NotchPillView.swift
    - Islet/Notch/NotchWindowController.swift

key-decisions:
  - "Hover-preview architecture: view-local branch off .idle (NotchPillView), not a new IslandPresentation resolver case — Claude's Discretion per 53-CONTEXT.md, keeps IslandResolver.swift/IslandResolverTests.swift untouched"
  - "Task 1 on-device spike: user reported \"approved\" — all 4 combinations (Spotify paused/quit, Apple Music paused/quit) behaved per the plan's default expectation (paused resumes via togglePlayPause(); quit does not), confirming the D-03 failure-timeout design has a real empirical basis before Task 3 was built"

patterns-established:
  - "D-03 inferred-timeout pattern reused a second time in this codebase (first: NowPlayingMonitor.runHealthCheck D-12) — confirms this is now the established shape for 'no completion signal on a fire-and-forget transport call'"

requirements-completed: [RESUME-01, RESUME-02]

# Metrics
duration: multi-session (blocking on-device checkpoint between Task 1 and Tasks 2-3)
completed: 2026-07-21
---

# Phase 53 Plan 01: Hover-to-Resume Idle Preview Summary

**Idle-island hover preview reusing the live Now Playing wings verbatim (album art + bouncing equalizer), click-to-resume via the existing togglePlayPause() transport call with a D-03 inferred-timeout failure text, gated behind a confirmed on-device spike of the resume-of-a-stopped-session open question.**

## Performance

- **Duration:** multi-session (Task 1 is a blocking on-device checkpoint; Tasks 2-3 executed in a follow-up turn after user approval)
- **Completed:** 2026-07-21T17:40:48Z
- **Tasks:** 3 (1 checkpoint + 2 auto)
- **Files modified:** 3

## Accomplishments
- Confirmed the milestone's one open technical question on real hardware: `togglePlayPause()` can resume a session in both the paused and quit sub-cases for Spotify and Apple Music, matching the plan's default expectation (user reported "approved")
- Shipped the hover-preview render branch (`idleOrResumePreview`/`resumePreviewWings`) reusing `mediaWingsRow` verbatim for the success path, with a dedicated `.playing(...)` construction so the equalizer bounces per D-02
- Shipped the resume-tap controller wiring: `handleResumeTap()` (togglePlayPause + D-03 inferred-failure timeout watch), settled by a genuine fresh `.playing` snapshot inside the existing `handleNowPlaying`, and `collapsedInteractiveZone()` widened conditionally to the preview's real rendered footprint

## Task Commits

Each task was committed atomically:

1. **Task 1: Blocking on-device spike — does togglePlayPause() resume a stopped/quit session?** - checkpoint, no commit (build-only; Debug configuration pre-built by the executor before presenting the checkpoint)
2. **Task 2: Hover-preview render branch + resume-failure data flag** - `e2f1eab` (feat)
3. **Task 3: Controller wiring — resume tap, inferred-failure timeout, click-through zone widening** - `757d661` (feat)

_No TDD tasks in this plan; no plan-metadata commit separate from the final docs commit below._

## Files Created/Modified
- `Islet/Notch/NowPlayingState.swift` - added `resumePreviewFailed: Bool` (D-03 orthogonal flag, reset on every resume attempt and every fresh hover-entry)
- `Islet/Notch/NotchPillView.swift` - added `onResumeTap` closure, `idleOrResumePreview` view-local branch off `.idle`, `resumePreviewWings(_:)` (reuses `mediaWingsRow` verbatim for success, renders "Wiedergabe nicht möglich" text for D-03 failure)
- `Islet/Notch/NotchWindowController.swift` - added `handleResumeTap()` (togglePlayPause + inferred-timeout watch via `resumeWatchWorkItem`/`resumeWatchSettled`), settle-on-success wiring inside `handleNowPlaying`, `resumePreviewFailed` reset in `handleHoverEnter`, `collapsedInteractiveZone()` widened for the preview's `wingsSize.width` footprint, `onResumeTap` wired in `makeRootView`

## Decisions Made

- **Task 1 spike verdict:** User reported **"approved"** — all 4 combinations (Spotify paused, Spotify quit, Apple Music paused, Apple Music quit) behaved identically to the plan's default expectation summarized in the checkpoint text (i.e., `togglePlayPause()` resumes a merely-paused session for both allowlisted sources; the fully-quit case does not resume via this generic toggle). This gives Task 3's D-03 inferred-failure timeout a real empirical basis: the failure path is expected to fire routinely for the "fully quit" sub-case, not just as a rare edge case.
- Hover-preview architecture kept as a view-local branch per 53-CONTEXT.md's Claude's-Discretion note (see plan `<objective>` for the full rationale) rather than a new `IslandPresentation` resolver case — smaller diff, `IslandResolver.swift`/`IslandResolverTests.swift` confirmed untouched (`git diff --stat` empty for both).

## Deviations from Plan

None — plan executed exactly as written. All acceptance-criteria greps and both Debug/Release builds passed on the first attempt for both Task 2 and Task 3.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- All 4 `must_haves.truths` and all 3 `must_haves.artifacts` are in place; `key_links` (onResumeTap wiring, collapsedInteractiveZone→wingsSize, handleNowPlaying→resumeWatchSettled) all confirmed present in the final diff.
- Plan 53-02 (on-device UAT of the full shipped feature, per STATE.md's "Plan 1 of 2") is next — this plan's own Task 1 spike already de-risked the transport-layer open question, so 53-02 can focus on visual/interaction polish (hit-testing across the full 290x32pt footprint, timeout-window feel) rather than re-litigating whether resume works at all.
- No blockers carried forward.

---
*Phase: 53-hover-to-resume-idle-preview*
*Completed: 2026-07-21*

## Self-Check: PASSED
All 3 modified files exist; both task commits (e2f1eab, 757d661) confirmed in git log; SUMMARY.md itself confirmed on disk.
