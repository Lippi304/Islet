---
phase: 35-liquid-glass-material
plan: 6
subsystem: ui
tags: [swiftui, metal, shader, liquid-glass, material]

# Dependency graph
requires:
  - phase: 35-liquid-glass-material (plan 02)
    provides: liquidGlassDistortion warp shader + LiquidGlassParameters contract
provides:
  - liquidGlassEdgeFalloff shared Metal helper (extracted from liquidGlassDistortion, identical numeric behavior)
  - liquidGlassEdgeOpacity stitchable colorEffect Metal function (D-10/D-11 opacity ramp)
  - LiquidGlassParameters.edgeOpacity/centerOpacity/fringeOpacity fields with retuned .collapsed/.expanded values
affects: [35-07, 35-08]

# Tech tracking
tech-stack:
  added: []
  patterns: ["Shared Metal helper function reused by multiple stitchable shaders to avoid duplicated falloff math (single source of truth)"]

key-files:
  created: []
  modified:
    - Islet/Notch/LiquidGlassShader.metal
    - Islet/Notch/LiquidGlassShader.swift

key-decisions:
  - "liquidGlassEdgeFalloff extracted verbatim from liquidGlassDistortion's Steps 1-5 -- D-01's warp numeric output is unaffected by the refactor"
  - "liquidGlassEdgeOpacity reuses the identical falloff curve rather than inventing a second one, per D-11"
  - "backgroundOpacity/fringeOpacity bumped 0.04/0.07/0.10 -> 0.05/0.08 (+new fringeOpacity 0.15/0.20) per CONTEXT.md retuning note -- old values were calibrated against the opaque base D-10/D-11 removes"

patterns-established:
  - "Metal shader helper extraction: shared per-pixel geometry math lives in a plain (non-stitchable) static function; stitchable entry points call it, never duplicate it"

requirements-completed: [GLASS-01]

# Metrics
duration: 15min
completed: 2026-07-16
---

# Phase 35 Plan 6: Edge-Falloff Extraction + liquidGlassEdgeOpacity Shader Summary

**Extracted liquidGlassDistortion's edge-falloff math into a shared Metal helper and added a second colorEffect shader (liquidGlassEdgeOpacity) plus retuned LiquidGlassParameters fields, giving Plan 35-07 a ready-to-call opacity-ramp contract for the translucent material pivot (D-10/D-11).**

## Performance

- **Duration:** ~15 min
- **Completed:** 2026-07-16
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- `liquidGlassEdgeFalloff` shared static helper in `LiquidGlassShader.metal`, extracted from `liquidGlassDistortion`'s original Steps 1-5 with zero numeric behavior change (pure extraction, D-01 unaffected)
- `liquidGlassEdgeOpacity` new `[[ stitchable ]]` colorEffect function that mixes `edgeOpacity`/`centerOpacity` alpha using the identical falloff curve — one source of truth per D-11
- `LiquidGlassParameters` gained `edgeOpacity`/`centerOpacity`/`fringeOpacity` fields, with `.collapsed`/`.expanded` retuned (`backgroundOpacity` 0.04/0.07 → 0.05/0.08; new fields 0.15/0.55/0.15 collapsed, 0.20/0.70/0.20 expanded) — collapsed stays visibly subtler than expanded at every field (D-04)

## Task Commits

Each task was committed atomically:

1. **Task 1: Extract shared edge-falloff + add liquidGlassEdgeOpacity colorEffect function** - `f027e4b` (feat)
2. **Task 2: LiquidGlassParameters edgeOpacity/centerOpacity/fringeOpacity fields + retuned constants** - `8957ef8` (feat)

_Note: no TDD tasks in this plan (Metal shader / Swift struct scaffolding, not behavior-testable via XCTest in isolation)._

## Files Created/Modified
- `Islet/Notch/LiquidGlassShader.metal` - Extracted `liquidGlassEdgeFalloff` helper; added `liquidGlassEdgeOpacity` colorEffect function
- `Islet/Notch/LiquidGlassShader.swift` - Added `edgeOpacity`/`centerOpacity`/`fringeOpacity` fields to `LiquidGlassParameters`, retuned `.collapsed`/`.expanded`, updated top-of-file doc comment to reference both shaders

## Decisions Made
- Extraction verified as behavior-preserving by inspection: `liquidGlassDistortion`'s Steps 6-7 (direction + warp application) are textually unchanged; only Steps 1-5 moved into `liquidGlassEdgeFalloff` verbatim.
- `liquidGlassEdgeOpacity`'s parameter order/types were chosen to match SwiftUI's `.colorEffect(_:)` signature exactly (`float2 position, half4 color, ...` returning `half4`), distinct from `liquidGlassDistortion`'s `.distortionEffect()` signature (`float2 position, ... -> float2`) — both share the same `liquidGlassEdgeFalloff` call.
- Retuned constants (`backgroundOpacity`/new opacity fields) follow the CONTEXT.md "Claude's Discretion — on-device tuning" grant; final values remain pending Plan 35-08's on-device UAT.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Grep acceptance-criteria false positive from an explanatory code comment**
- **Found during:** Task 1 (grep verification of `[[ stitchable ]]` count)
- **Issue:** A doc comment on `liquidGlassEdgeOpacity` explaining the signature contrast with `liquidGlassDistortion` literally quoted `[[ stitchable ]] float2`, making the acceptance-criteria grep for stitchable-attribute count return 3 instead of the expected 2 (the two real `[[ stitchable ]]` attributes).
- **Fix:** Reworded the comment to describe the contrast without reproducing the literal attribute syntax.
- **Files modified:** `Islet/Notch/LiquidGlassShader.metal`
- **Verification:** `grep -c "\[\[ *stitchable *\]\]"` now returns 2, matching the plan's acceptance criteria.
- **Committed in:** `f027e4b` (part of Task 1 commit)

---

**Total deviations:** 1 auto-fixed (Rule 3)
**Impact on plan:** Comment-wording only; no functional change. No scope creep.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
`liquidGlassEdgeOpacity` and the retuned `LiquidGlassParameters` fields compile cleanly and are ready for Plan 35-07 to wire into `NotchPillView.swift`'s material base (translucent `Material` fill + edge-opacity ramp replacing the opaque `gradientMaterial`). Neither new function nor new field is consumed anywhere yet, confirmed by design (interface-first scaffolding step per plan's must_haves).

---
*Phase: 35-liquid-glass-material*
*Completed: 2026-07-16*

## Self-Check: PASSED

All created/modified files verified present on disk; both task commits (`f027e4b`, `8957ef8`) confirmed in git log.
