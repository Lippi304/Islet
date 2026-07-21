---
phase: 53-hover-to-resume-idle-preview
plan: 02
subsystem: ui
tags: [swiftui, appkit, now-playing, mediaremote, hover-interaction, on-device-uat]

# Dependency graph
requires:
  - phase: 53-hover-to-resume-idle-preview (Plan 01)
    provides: idleOrResumePreview/resumePreviewWings render branch, handleResumeTap()/inferred-failure timeout, widened collapsedInteractiveZone()
provides:
  - On-device UAT verdict (approved) for all 4 ROADMAP Phase 53 success criteria, confirmed against both Debug and Release builds
  - D-02 design supersession discovered live during this UAT: static "play.fill" glyph replaces the bouncing equalizer bars in the idle-hover preview's success-path right slot
affects: [v1.8-milestone-close]

# Tech tracking
tech-stack:
  added: []
  patterns: []

key-files:
  created:
    - .planning/phases/53-hover-to-resume-idle-preview/53-02-SUMMARY.md
  modified:
    - Islet/Notch/NotchPillView.swift (fix commit 581c94e, mid-UAT: resumePreviewWings static play glyph)
    - .planning/phases/53-hover-to-resume-idle-preview/53-CONTEXT.md (D-02 marked superseded)
    - .planning/phases/53-hover-to-resume-idle-preview/53-01-SUMMARY.md (Deviations section updated)
    - .planning/REQUIREMENTS.md (RESUME-01/RESUME-02 -> Complete)
    - .planning/ROADMAP.md (Phase 53 checkbox + SC#1 wording + Wave 2 plan item + v1.8 progress line)

key-decisions:
  - "D-02 superseded live during on-device UAT: the user's real reaction (\"die bars sich im idle zustand bewegen macht keinen Sinn\") found animated equalizer bars during idle-hover misleading (implies live playback that isn't happening). Fixed by showing a static `play.fill` SF Symbol glyph in the right slot instead of reusing mediaWingsRow/EqualizerBars(isPlaying: true) for the success path; D-03's failure text still occupies the same slot on a failed resume. The LIVE nowPlayingWings state (post-successful-resume) is unaffected — bars still bounce there because playback is then genuinely live."
  - "RESUME-01's success-criterion wording (ROADMAP.md) updated in place to describe the static play glyph rather than equalizer bars, with the supersession explicitly called out rather than silently rewritten."

patterns-established: []

requirements-completed: [RESUME-01, RESUME-02]

# Metrics
duration: single session (2 rounds: initial checkpoint presented static-bars build, mid-UAT fix applied, corrected build re-verified and approved)
completed: 2026-07-21
---

# Phase 53 Plan 02: Full On-Device UAT Summary

**On-device UAT (Debug + Release) approved all 4 ROADMAP Phase 53 success criteria for the hover-to-resume idle preview, closing RESUME-01/RESUME-02 — with one live design correction along the way: the idle-hover preview's right slot now shows a static play glyph instead of the originally-shipped bouncing equalizer bars, since animated bars while nothing was playing read as misleading.**

## Performance

- **Duration:** single session — checkpoint presented once, a design-mismatch fix landed mid-flow (orchestrator-applied, not a re-execution of this plan's own tasks), rebuilt, re-presented, approved
- **Completed:** 2026-07-21
- **Tasks:** 1 (checkpoint:human-verify, gate=blocking)
- **Files modified:** 0 by this plan's own execution (Task 1 is verification-only per its threat_model); 1 source file fixed out-of-band by the orchestrator in response to live UAT feedback (`Islet/Notch/NotchPillView.swift`, commit `581c94e`)

## Accomplishments

- Both Debug and Release builds were built/rebuilt clean ahead of and after the mid-UAT fix (`xcodebuild build -configuration Debug` / `-configuration Release`, both `** BUILD SUCCEEDED **`)
- Full 7-step on-device checklist walked by the user against real notched hardware; result: **approved** for both Debug and Release
- Live design mismatch caught and fixed within this UAT round: bouncing equalizer bars in the idle-hover preview looked like live playback when nothing was actually playing — replaced with a static `play.fill` glyph (D-02 in `53-CONTEXT.md` marked superseded)
- All 4 ROADMAP Phase 53 success criteria confirmed true on-device (SC#1 with the corrected static-glyph visual, SC#2 gate, SC#3 resume-click, SC#4 failure feedback)
- Full-width hit-testing (no dead click-through zones near either edge), no-expansion-on-click (D-01), and the collapsed-hover regression check (secondary bubble, charging/device wings, plain click-to-expand) all confirmed with no regressions
- RESUME-01/RESUME-02 marked Complete in REQUIREMENTS.md; Phase 53 checkbox marked complete in ROADMAP.md — v1.8 milestone now 3/3 phases shipped (100%), pending only a formal `/gsd:complete-milestone` pass

## Task Commits

This plan's own Task 1 is verification-only (checkpoint:human-verify, gate=blocking) — no code commit is produced by this plan's execution itself, matching this project's established precedent for pure on-device-UAT plans (e.g. 45-02, 51-01 Task 3).

The one source-code fix surfaced during this UAT round was applied and committed directly by the orchestrator, not as a task of this plan:
- `581c94e` — `fix(53-01): replace bouncing equalizer with static play glyph in resume preview`

_No TDD tasks in this plan; the plan's own output is this SUMMARY.md plus the REQUIREMENTS.md/ROADMAP.md updates below, committed together as this plan's closing docs commit._

## Files Created/Modified

- `.planning/phases/53-hover-to-resume-idle-preview/53-02-SUMMARY.md` — this file
- `.planning/REQUIREMENTS.md` — RESUME-01/RESUME-02 rows and traceability table entries flipped Pending → Complete; footer note added recording Phase 53's completion and the D-02 supersession
- `.planning/ROADMAP.md` — Phase 53 checkbox marked complete; SC#1 wording updated to describe the static play glyph (supersession explicitly noted, not silently rewritten); Wave 2's `53-02-PLAN.md` list item checked; v1.8 progress line updated to 3/3 (100%)
- `Islet/Notch/NotchPillView.swift` (out-of-band fix, commit `581c94e`, not part of this plan's own task list) — `resumePreviewWings` now renders a static `"play.fill"` SF Symbol in the success-path right slot instead of reusing `mediaWingsRow`/`EqualizerBars(isPlaying: true)`
- `.planning/phases/53-hover-to-resume-idle-preview/53-CONTEXT.md` (same commit) — D-02 marked superseded
- `.planning/phases/53-hover-to-resume-idle-preview/53-01-SUMMARY.md` (same commit) — Deviations section updated to record the supersession

## Decisions Made

- **On-device UAT verdict:** User reported **"approved"** for all 7 checklist steps, walked against both the Debug and the Release build, after the mid-UAT static-play-glyph fix landed. This is the terminal verification gate for Phase 53 per the plan's own `<verification>` section — no further automated command applies beyond the Debug/Release build gates.
- **D-02 superseded:** Animated equalizer bars in the idle-hover preview (the original Plan 53-01 implementation, per D-02's literal text "bars animate identically to the live-playing state") were found misleading in real usage — bouncing bars imply audio is currently playing, which isn't true for an idle-hover preview of a *stopped* track. The fix keeps the preview's left slot (album art) and overall footprint/position unchanged, only replacing the right slot's content for the success path. The failure path (D-03, "Wiedergabe nicht möglich") is unaffected — it already occupied the same right slot. The genuinely-live `nowPlayingWings` state (reached after a successful resume click) is also unaffected — its bars still bounce, because at that point playback really is live.
- **REQUIREMENTS.md/ROADMAP.md updated in the same pass** rather than deferred to a separate cleanup, per this plan's own `<success_criteria>` and the checkpoint_handling instructions for the "approved" outcome.

## Deviations from Plan

**1. [Rule 1 - Bug, applied out-of-band by the orchestrator, not this plan's own task list] Static play glyph replaces bouncing equalizer bars in the idle-hover preview**
- **Found during:** Task 1's first on-device UAT round (step 2, SC#1 preview visual)
- **Issue:** The idle-hover preview's right slot showed animated `EqualizerBars(isPlaying: true)` per Plan 53-01's D-02 ("bars animate identically to the live-playing state") — but on real hardware this reads as "audio is currently playing," which is false for a preview of a stopped/paused track. User's live reaction: "die bars sich im idle zustand bewegen macht keinen Sinn."
- **Fix:** `resumePreviewWings` (Islet/Notch/NotchPillView.swift) now renders a static `"play.fill"` SF Symbol glyph in that slot for the success path instead of reusing `mediaWingsRow`/`EqualizerBars`. D-03's failure text is unchanged (same slot, replaces the glyph on a failed resume). D-02 in `53-CONTEXT.md` marked superseded.
- **Files modified:** `Islet/Notch/NotchPillView.swift`, `.planning/phases/53-hover-to-resume-idle-preview/53-CONTEXT.md`, `.planning/phases/53-hover-to-resume-idle-preview/53-01-SUMMARY.md`
- **Commit:** `581c94e`
- **Note on attribution:** This fix was applied directly by the orchestrator (not generated by this plan's own execution flow, which is verification-only per its `<threat_model>`) after relaying the user's live on-device reaction. It is documented here because this plan's re-presented checkpoint and final "approved" verdict cover the corrected behavior, and closing RESUME-01/RESUME-02 depends on it.

No other deviations — the rest of the checklist (SC#2 gate, full-width hit-testing, SC#3/SC#4 resume-click across all 4 Spotify/Apple Music combinations, no-expansion-on-click, regression check, failure-timeout feel) passed as originally specified in the plan.

## Issues Encountered

None beyond the D-02 design mismatch above, which was resolved within this same UAT round.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- All 4 ROADMAP Phase 53 success criteria and both `must_haves.artifacts`/`must_haves.truths` entries confirmed true on-device (Debug + Release).
- RESUME-01/RESUME-02 marked Complete in REQUIREMENTS.md; Phase 53 checkbox marked complete in ROADMAP.md.
- v1.8 milestone (Settings Redesign & Island Navigation) is now 3/3 phases complete (100%) — formal `/gsd:complete-milestone` for v1.8 is the only remaining step, not part of this plan's own scope.
- No blockers carried forward.

---
*Phase: 53-hover-to-resume-idle-preview*
*Completed: 2026-07-21*

## Self-Check: PASSED
Commit `581c94e` confirmed in git log; `.planning/REQUIREMENTS.md` RESUME-01/RESUME-02 rows confirmed Complete; `.planning/ROADMAP.md` Phase 53 checkbox confirmed `[x]`; this SUMMARY.md confirmed on disk.
