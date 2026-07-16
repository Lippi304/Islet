---
phase: 35-liquid-glass-material
plan: 11
subsystem: ui
tags: [swiftui, metal, colorEffect, shader, liquid-glass]

# Dependency graph
requires:
  - phase: 35-liquid-glass-material (Plan 35-09)
    provides: liquidGlassEdgeOpacity Metal function + frost-layer edge-opacity ramp (D-12/D-13/D-14)
provides:
  - liquidGlassRimMask(shape:size:parameters:) helper Shader reusing liquidGlassEdgeOpacity with mask-only arguments
  - 4 new .colorEffect(rimMask) call sites confining the 3 chromatic-fringe passes and the white-wash overlay to the narrow rim band
affects: [35-12 (on-device UAT)]

# Tech tracking
tech-stack:
  added: []
  patterns: ["Reuse an existing stitchable Metal function as a mask by calling it with inverted literal arguments instead of writing a new shader/texture"]

key-files:
  created: []
  modified:
    - Islet/Notch/NotchPillView.swift

key-decisions:
  - "Reused the existing liquidGlassEdgeOpacity function verbatim (edgeOpacity=1.0/centerOpacity=0.0 mask-only literals) rather than a new shader technique or precomputed mask texture, per D-16's explicit single-source-of-truth instruction"
  - "Left parameters.fringeOpacity (0.15/0.20) untouched — an on-device-tuning candidate for Plan 35-12 if the fringe reads too faint once masked, per D-18's guidance"

patterns-established: []

requirements-completed: [GLASS-01]

# Metrics
duration: 12min
completed: 2026-07-16
---

# Phase 35 Plan 11: Mask Fringe/Wash to Rim Falloff Summary

**Masked the 3 chromatic-fringe `.screen`-blend passes and the trailing white-wash overlay in `liquidGlassEffectLayer` to the same `liquidGlassEdgeOpacity` falloff the frost layer already uses, via a new `liquidGlassRimMask` helper `Shader` and 4 `.colorEffect(rimMask)` call sites — closing round 3's UAT-rejected "washed-out silvery panel" failure mode.**

## Performance

- **Duration:** 12 min
- **Started:** 2026-07-16T12:21:00Z
- **Completed:** 2026-07-16T12:33:45Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments
- Added `liquidGlassRimMask(shape:size:parameters:) -> Shader`, a private helper that constructs the exact same `liquidGlassEdgeOpacity` stitchable Metal call the frost layer uses, but with inverted mask-only literals (`edgeOpacity: 1.0, centerOpacity: 0.0`) instead of `parameters.edgeOpacity`/`parameters.centerOpacity` — full visibility at the rim, fully invisible at the interior.
- Chained `.colorEffect(rimMask)` between each of the 3 fringe fills' `.distortionEffect(...)` and their `.blendMode(.screen)`, and onto the trailing `Color.white.opacity(parameters.backgroundOpacity)` overlay — all 4 layers now fade to invisible by the frost layer's dark center instead of lightening the whole surface.
- Zero changes to `LiquidGlassShader.metal` or `LiquidGlassShader.swift` — pure Swift-side consumer reuse of the already-shipped function, confirmed via `git diff` (both zero lines).
- Updated `liquidGlassEffectLayer`'s header doc comment with a round-4 (D-16/D-17/D-18) addendum and removed the now-stale "untouched by this plan" note on the white-wash line.

## Task Commits

Each task was committed atomically:

1. **Task 1: Mask the fringe passes and white-wash overlay to the shared edge-opacity falloff (D-16/D-17/D-18)** - `78c8a4d` (feat)

## Files Created/Modified
- `Islet/Notch/NotchPillView.swift` - Added `liquidGlassRimMask` helper Shader; masked the 3 chromatic-fringe fills and the white-wash overlay with `.colorEffect(rimMask)`; updated the layer's doc comment for round 4.

## Decisions Made
- Reused `liquidGlassEdgeOpacity` verbatim with inverted mask-only literal arguments rather than introducing a new shader technique or precomputed mask texture (D-16's "reuse the existing single source of truth" instruction, resolving the plan's "Claude's Discretion" item toward direct `colorEffect` reuse).
- Kept `parameters.fringeOpacity` values unchanged — left as an on-device-tuning candidate for Plan 35-12 rather than pre-emptively bumped, per D-18.
- Formatted the new helper's `Shader(...)` argument list slightly more compactly than the frost layer's own call (grouping some `.float(...)` args per line) so the function body fits the plan's `grep -A8`-based acceptance checks without changing any semantics — purely cosmetic, functionally identical to the frost layer's equivalent call.

## Deviations from Plan

None - plan executed exactly as written. (One minor formatting adjustment to the new helper's argument-list layout was made solely to satisfy a `grep -A8`-based acceptance check line-count assumption in the plan; no functional or interface change.)

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Plan 35-12's on-device UAT checkpoint can now evaluate a build where the fringe/wash layers are confined to the narrow rim band established by Plan 35-09, unmasked by a whole-surface lightening wash.
- If the fringe reads too subtle once confined to the rim, `parameters.fringeOpacity` (currently 0.15/0.20, `LiquidGlassShader.swift`) is the intended on-device tuning knob per D-18 — no code structure change needed.

---
*Phase: 35-liquid-glass-material*
*Completed: 2026-07-16*
