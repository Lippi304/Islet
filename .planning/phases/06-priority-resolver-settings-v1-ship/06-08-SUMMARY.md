---
phase: 06-priority-resolver-settings-v1-ship
plan: 08
subsystem: notch-controller
tags: [swift, swiftui, appkit, mediaremote, now-playing, gap-closure]

# Dependency graph
requires:
  - phase: 06-priority-resolver-settings-v1-ship (plan 07)
    provides: handleDevice/scheduleDeviceBatteryRefresh/flushTransients/currentPresentation fixes this plan's edits sit below in the same file
provides:
  - startNowPlayingMonitor's runHealthCheck completion can never downgrade an isHealthy flag the persistent stream already proved true
  - handleHoverEnter/handleHoverExit pause/resume mediaDismissWorkItem the same way they already do for the charging dismissWorkItem
  - handleNowPlaying only (re)arms the paused-media 15s countdown on a genuine presentation transition, debouncing duplicate .paused emissions
affects: [priority-resolver-settings-v1-ship phase closure, Now Playing reliability (NOW-01/02/03)]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "One-shot health/verification probes must guard against downgrading state a persistent stream has already proven — guard healthy || !isHealthy, mirroring PowerSourceMonitor's single-source-of-truth discipline"
    - "Hover-pause of an auto-dismiss timer is now applied uniformly to both dismissWorkItem (charging) and mediaDismissWorkItem (now playing) in handleHoverEnter/handleHoverExit"

key-files:
  created: []
  modified:
    - Islet/Notch/NotchWindowController.swift

key-decisions:
  - "The health-check race fix stays entirely at the controller call site (startNowPlayingMonitor); NowPlayingMonitor.swift's runHealthCheck signature and implementation are untouched, confirmed via git diff --stat returning no output"
  - "Finding 8's debounce compares the OUTGOING presentation captured before mutation against the newly-mapped presentation via NowPlayingPresentation's existing Equatable conformance — no new state or persisted flag added"

requirements-completed: []  # NOW-01/02/03 already marked complete in Phase 4; this plan is a gap-closure fix, checkpoint (Task 3) still pending human on-device verification

# Metrics
duration: ~15min (Tasks 1-2; Task 3 checkpoint pending)
completed: 2026-07-01
---

# Phase 06 Plan 08: Now-Playing Reliability Gap Closure (Tasks 1-2) Summary

**Three confirmed Now-Playing reliability bugs fixed in the controller/glue layer: a launch-time health-check race that could silently overwrite a stream-proven healthy flag back to false, hover not pausing the paused-media 15s auto-dismiss (unlike the existing charging-splash hover-pause), and duplicate `.paused` emissions restarting that countdown indefinitely.**

## Performance

- **Duration:** ~15 min for Tasks 1-2 (automated); Task 3 is an on-device human-verify checkpoint, not yet run
- **Started:** 2026-07-01 (per orchestrator dispatch, worktree wave 2)
- **Completed:** Tasks 1-2 complete; Task 3 PAUSED at checkpoint
- **Tasks:** 2 of 3 completed (Task 3 is a blocking human-verify checkpoint)
- **Files modified:** 1

## Accomplishments

- Finding 6 closed: `startNowPlayingMonitor`'s `runHealthCheck` completion now guards with `healthy || !self.nowPlayingState.isHealthy` before writing `isHealthy`, so the one-shot probe's own 3s timeout can no longer overwrite a `true` the persistent stream (`handleNowPlaying`) already proved via a real snapshot. The first "nicht verfügbar" determination before any stream data arrives still works exactly as before (probe's `false` applies when the flag isn't already `true`). `handleNowPlaying`/`handleAdapterTerminated` remain the sole authority for flipping the flag back to `false` on an actual stream death. `NowPlayingMonitor.swift` is untouched (confirmed via `git diff --stat` returning no output).
- Finding 7 closed: `handleHoverEnter` now cancels `mediaDismissWorkItem` immediately alongside the existing charging `dismissWorkItem?.cancel()`; `handleHoverExit` symmetrically re-arms `scheduleMediaDismiss(after: pausedTimeout)` when `nowPlayingState.presentation` is genuinely `.paused` (mirroring the existing `if chargingState.activity != nil { scheduleActivityDismiss() }` resume pattern). Hovering the expanded transport controls while a paused glance is showing can no longer let the ~15s auto-dismiss fire under the pointer.
- Finding 8 closed: `handleNowPlaying` captures `let previous = nowPlayingState.presentation` before overwriting it, then only calls `scheduleMediaDismiss(after: pausedTimeout)` in the `.paused` branch when `previous != p` (using `NowPlayingPresentation`'s existing `Equatable` conformance). A repeated identical `.paused(title:artist:)` emission for the same track (the documented artwork-latency re-emission case) no longer restarts the countdown; a genuine transition into paused or a paused→paused change to a different track still (re)arms it.
- Build verified after each task: `xcodegen generate && xcodebuild build -scheme Islet -destination 'platform=macOS'` → `BUILD SUCCEEDED` both times.

## Task Commits

Each task was committed atomically:

1. **Task 1: Fix the launch-time health-check race** - `736964e` (fix)
2. **Task 2: Hover-pause the media dismiss timer and debounce duplicate .paused emissions** - `088aae2` (fix)

Task 3 (checkpoint:human-verify, gate="blocking") has NOT run — no files change in that task; it is an on-device verification step. This SUMMARY documents Tasks 1-2 only, per the checkpoint pause (same pattern as 06-07-SUMMARY.md).

## Files Created/Modified

- `Islet/Notch/NotchWindowController.swift` — `startNowPlayingMonitor`'s `runHealthCheck` completion gated (Finding 6); `handleHoverEnter`/`handleHoverExit` pause/resume `mediaDismissWorkItem` (Finding 7); `handleNowPlaying` captures `previous` and debounces the `.paused` branch's `scheduleMediaDismiss` call (Finding 8)

## Decisions Made

- Kept all three fixes as controller-call-site changes only — no edits to `NowPlayingMonitor.swift`'s public surface or `NowPlayingPresentation.swift`'s pure `nowPlayingPresentation(from:)` seam, per the plan's explicit constraint.
- Placed the Finding-7 hover-pause comment BEFORE both `dismissWorkItem?.cancel()` and `mediaDismissWorkItem?.cancel()` lines (rather than between them) so the two cancel calls stay textually adjacent, matching the plan's acceptance-criteria grep expectation.

## Deviations from Plan

None — plan executed exactly as written for Tasks 1-2. One minor self-correction during execution: an early comment placement for Finding 7 landed between the two `.cancel()` calls, which would have broken the acceptance criterion's `grep -A1` adjacency check. Reworded/repositioned the comment before committing so the two `.cancel()` lines are adjacent. Not tracked as a Rule 1-4 deviation since no shipped behavior was affected — caught and fixed before the Task 2 commit.

## Known Stubs

None — no stub/placeholder patterns introduced.

## Threat Flags

None — this plan's `<threat_model>` (T-06-16, disposition `accept`) already covers all three fixes as pure timing/ordering changes to existing internal `@Published` state (`isHealthy`, `mediaDismissWorkItem`) and a read of an already-`Equatable` internal enum. No new external input surface, no new persisted state, no new trust boundary was introduced by the Task 1-2 changes.

## Checkpoint Status

**PAUSED at Task 3** (`type="checkpoint:human-verify"`, `gate="blocking"`). This is a standard (non-auto-mode) checkpoint per `.planning/config.json`'s `workflow.auto_advance: false` — execution stops here per the checkpoint protocol; a fresh agent (or the orchestrator) must resume after the human performs the on-device verification described in the plan's Task 3 `<how-to-verify>` block:

1. Play music continuously for 30+ seconds while expanding/collapsing the island — confirm it never shows "Now Playing nicht verfügbar" while media keeps actively playing (Finding 6, re-verify of 06-UAT Test 6).
2. Pause playback, expand the island, hover the transport controls for longer than 15s — the paused glance must not disappear while the pointer sits on it; moving away should collapse it shortly after (Finding 7).
3. With the same paused track, best-effort trigger a metadata re-emission without resuming — the paused glance should not reset its 15s timer on every re-emission (Finding 8, best-effort — log observations).

## Next Steps

- Resume this plan by running Task 3's on-device verification and typing "approved" (or describing any issue found) at the checkpoint's resume-signal.
- No STATE.md / ROADMAP.md updates were made by this worktree agent — the orchestrator owns those writes centrally after the wave (and after this checkpoint resolves).

## Self-Check: PASSED

- FOUND: Islet/Notch/NotchWindowController.swift
- FOUND: commit 736964e
- FOUND: commit 088aae2
