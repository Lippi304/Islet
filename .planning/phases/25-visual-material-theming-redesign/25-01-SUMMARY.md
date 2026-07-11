---
phase: 25-visual-material-theming-redesign
plan: 01
subsystem: ui
tags: [swiftui, gradient, animation, spring, notch]

# Dependency graph
requires:
  - phase: 23-shell-parity-rewrite
    provides: NotchPillView.swift / NotchWindowController.swift shell chrome this plan reskins
provides:
  - Shared black-to-~50%-transparent vertical gradient material (`islandMaterial`) across collapsed pill, expanded island, and all activity wings
  - Rounder expanded-blob bottom corner radius (20pt to 32pt)
  - Retuned spring animation (response 0.35 to 0.6, damping 0.65 to 0.62) for a slower, single-overshoot morph
affects: [26-onboarding-flow, 27-settings-sidebar-redesign, 28-calendar-full-view]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Single static-let ShapeStyle source of truth (islandMaterial) reused across all fill sites instead of duplicating gradient stops"
    - "collapsedFill computed var widened to `some ShapeStyle` opaque return type to support both Color (DEBUG) and LinearGradient (release) branches"

key-files:
  created: []
  modified:
    - Islet/Notch/NotchPillView.swift
    - Islet/Notch/NotchWindowController.swift

key-decisions:
  - "Gradient stops (0.0 black, 0.65 black, 1.0 black@50%) and corner radius 32pt confirmed correct as-planned on first on-device pass — no on-device retuning needed"
  - "springDamping 0.62 confirmed to produce exactly one visible overshoot-and-settle bounce, no contingency animatableData change needed on NotchShape.swift"

patterns-established: []

requirements-completed: [VISUAL-01, VISUAL-02]

# Metrics
duration: ~9min (Task 1-2 execution) + on-device UAT
completed: 2026-07-11
---

# Phase 25 Plan 01: Gradient Material + Spring Retune Summary

**Shared black-to-transparent vertical gradient material and a slower single-overshoot spring across the notch shell chrome (collapsed pill, expanded island, activity wings), replacing flat `Color.black` and the old 0.35/0.65 spring — confirmed correct on real notch hardware with zero code changes needed after UAT.**

## Performance

- **Duration:** ~9 min (Tasks 1-2), plus on-device UAT session
- **Started:** 2026-07-11T11:10:00Z (approx, Task 1 commit)
- **Completed:** 2026-07-11T11:19:17Z
- **Tasks:** 3 (2 auto + 1 checkpoint:human-verify)
- **Files modified:** 2

## Accomplishments
- One shared `islandMaterial` `LinearGradient` (3-stop: black at 0.0, black at 0.65, black@50% at 1.0) now drives all 4 fill sites in `NotchPillView.swift` (collapsed pill, expanded blob, wings, media wings/toast) instead of flat `Color.black`
- Expanded-blob bottom corner radius raised 20pt to 32pt at all 3 call sites (`expandedIsland`, `mediaExpanded`, `mediaUnavailable`) in lock-step
- Spring animation retuned (`springResponse` 0.35 to 0.6, `springDamping` 0.65 to 0.62) across all 13 existing `withAnimation(.spring(...))` call sites via the shared constants
- On-device UAT (7-point checklist: gradient depth, pure black/no grey, corner roundness, spring feel, no morph artifacts, rapid hover-enter/exit, activity-content regression) passed on first attempt — user replied "approved"

## Task Commits

Each task was committed atomically:

1. **Task 1: Shared gradient material + expanded-blob corner radius** - `f3a95ad` (feat)
2. **Task 2: Spring animation retune** - `d135142` (feat)
3. **Task 3: On-device UAT (checkpoint:human-verify)** - no code commit; user verification only, result "approved"

**Plan metadata:** (this commit) `docs(25-01): complete gradient material + spring retune plan`

## Files Created/Modified
- `Islet/Notch/NotchPillView.swift` - Added `islandMaterial` gradient, swapped 4 fill sites from `Color.black`, raised `bottomCornerRadius` 20 to 32 at 3 expanded-blob call sites
- `Islet/Notch/NotchWindowController.swift` - Retuned `springResponse` (0.35 to 0.6) and `springDamping` (0.65 to 0.62)

## Decisions Made
- Task 1's planned gradient stop values and 32pt corner radius were validated as-is on-device; no iteration needed (D-01/D-02/D-08 confirmed correct on first pass)
- Task 2's planned spring constants (0.6/0.62) produced the intended single-overshoot feel; no iteration needed (D-05/D-06/D-07 confirmed correct on first pass)
- NotchShape.swift's documented contingency (`animatableData` conformance) was NOT applied — no corner-snap artifact was observed during the morph (check 5 of the UAT passed clean)

## Deviations from Plan

None - plan executed exactly as written. Both auto tasks matched their acceptance criteria on first build, and the on-device UAT passed all 7 checks without requiring any of the plan's documented contingency fixes.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Phase 25's only plan (25-01) is complete: VISUAL-01 and VISUAL-02 requirements are fully implemented and on-device verified. Note: the ROADMAP scope for Phase 25 originally also referenced a "Theming settings section" (VISUAL-03) per STATE.md's roadmap-evolution note, but VISUAL-03 is not present in this plan's frontmatter `requirements` field — no work against it was in scope here. Confirm VISUAL-03's status against REQUIREMENTS.md before closing out Phase 25 entirely.

---
*Phase: 25-visual-material-theming-redesign*
*Completed: 2026-07-11*
