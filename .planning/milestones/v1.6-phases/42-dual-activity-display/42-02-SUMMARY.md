---
phase: 42-dual-activity-display
plan: 02
subsystem: ui
tags: [notch-window-controller, hot-zone, click-through, appkit, spike]

# Dependency graph
requires:
  - phase: 40-update-available-hud-sparkle-integration
    provides: "40-03's precedent finding that NotchWindowController.hotZone can fail to cover wing-tier-adjacent overlay content (badge-tap regression root cause)"
provides:
  - "Confirmed on-device answer: today's collapsed-tier hotZone does NOT cover wing-tier tap targets — click passes through"
affects: [42-dual-activity-display/42-04]

# Tech tracking
tech-stack:
  added: []
  patterns: []

key-files:
  created: []
  modified: []

key-decisions:
  - "Confirmed (not assumed) that Plan 42-04 Task 2 must widen the collapsed/wing-tier click-through zone before the secondary-bubble tap target (D-12) can work"

patterns-established: []

requirements-completed: []

# Metrics
duration: N/A (single on-device checkpoint, no build/code work)
completed: 2026-07-18
---

# Phase 42 Plan 02: On-Device Hot-Zone Spike Summary

**Confirmed on real hardware: today's `NotchWindowController.hotZone` does NOT cover wing-tier content — clicks on the outer edge of an existing wing pass straight through, reproducing the exact Phase 40-03 badge-tap mechanism.**

## Performance

- **Tasks:** 1 (checkpoint:human-verify)
- **Files modified:** 0 (verification-only plan, by design)

## Accomplishments
- Resolved 42-RESEARCH.md's single highest-risk open item (Pitfall 2 / Open Question 1) before any secondary-bubble code exists
- Established a hard, on-device-confirmed input for Plan 42-04 Task 2, replacing what would otherwise have been a guess baked into the bubble's implementation

## Task Commits

1. **Task 1: On-device spike — does tapping the far outer edge of an existing wing register a click?** — checkpoint:human-verify, no code changes (files_modified stays empty per plan design)

**Plan metadata:** (this commit)

## Files Created/Modified
None — this plan makes zero code changes by design.

## On-Device Finding

**Outcome: "passes through."**

- **Wing tested:** Countdown (deliberately chosen over Charging because it stays visible longer than the brief connect-only animation, giving more time to test).
- **Area tested:** the user tested the general outer area of the wing away from the physical camera/notch — not narrowly isolated to a single named left/right flank. Reporting this at the granularity actually observed rather than inventing a more precise left-vs-right split than what was verified.
- **Result:** clicking the outer/far edge content of the wing did NOT register a click (no expand/collapse toggle). Only clicking directly behind/near the camera — inside the small existing `hotZone` rect (`NotchWindowController.swift:995`, fixed to the ~179×32pt collapsed-pill frame) — triggered expand/collapse.

**What this confirms:** the exact mechanism behind the Phase 40-03 badge-tap regression (`hotZone` not covering a wing-tier-adjacent overlay's real screen position) already affects TODAY's shipped wings (Countdown confirmed; Charging/Device share the same `hotZone`/`handlePointer(at:)` code path per `NotchWindowController.swift:1207-1240`, so the same gap is expected there too, though not independently re-tested this plan).

## Decisions Made

- **Plan 42-04 Task 2 must widen the collapsed/wing-tier click-through zone** (mirroring `visibleContentZone()`'s existing per-presentation-aware pattern already used for the expanded tier) — this is no longer optional or TBD. Without this widening, the secondary bubble's own tap target (D-12) would inherit the same swallowed-click defect the moment it renders outside the small fixed hot-zone rect.

## Deviations from Plan

None - plan executed exactly as written. The checkpoint's `<resume-signal>` asked to name "which of the two flanks (left/right)" tested; the user's actual report described the general outer area rather than a single isolated flank. Rather than fabricate a more precise claim than was verified, this SUMMARY records the granularity actually reported — the "passes through" outcome itself is unambiguous and answers the plan's core question.

## Issues Encountered
None.

## Next Phase Readiness

Plan 42-04 Task 2 now has a certain (not guessed) requirement: widen the collapsed/wing-tier click-through hot-zone before wiring the secondary bubble's tap target. No blockers for starting 42-03/42-04.

---
*Phase: 42-dual-activity-display*
*Completed: 2026-07-18*

## Self-Check: PASSED
