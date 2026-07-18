---
phase: 35-liquid-glass-material
plan: 7
subsystem: ui
tags: [swiftui, metal, shader, liquid-glass, material]

# Dependency graph
requires:
  - phase: 35-liquid-glass-material (plan 06)
    provides: liquidGlassEdgeOpacity colorEffect shader + LiquidGlassParameters.edgeOpacity/centerOpacity/fringeOpacity fields
  - phase: 35-liquid-glass-material (plan 03)
    provides: liquidGlassEffectLayer overlay wired at all 4 island-shell fill sites
provides:
  - islandFill .liquidGlass branch returning a real translucent .ultraThinMaterial ShapeStyle
  - liquidGlassEffectLayer base warp layer filled with translucent .ultraThinMaterial + edge-weighted opacity ramp via liquidGlassEdgeOpacity
  - chromatic-fringe passes reading parameters.fringeOpacity (no hardcoded 0.10 literal)
affects: [35-08]

# Tech tracking
tech-stack:
  added: []
  patterns: ["SwiftUI .colorEffect(...) chained immediately after .distortionEffect(...) on the same layer to post-process the already-warped result's alpha"]

key-files:
  created: []
  modified:
    - Islet/Notch/NotchPillView.swift

key-decisions:
  - "D-10 applied at BOTH opaque-base locations the on-device UAT rejection traced the bug to: islandFill's .liquidGlass branch AND liquidGlassEffectLayer's own base warp fill"
  - "D-11's edge-weighted opacity ramp implemented as a second shader pass (liquidGlassEdgeOpacity) chained after the existing distortionEffect, reusing Plan 35-06's shared falloff curve — no second independent falloff invented"
  - "Blur radius itself stays uniform (SwiftUI has no spatially-varying-blur-within-one-Material primitive) -- only opacity is spatially ramped; documented as a known gap for Plan 35-08's on-device UAT to assess"

requirements-completed: [GLASS-01]

# Metrics
duration: 20min
completed: 2026-07-16
---

# Phase 35 Plan 7: Wire Translucent Material + Edge-Opacity Ramp into NotchPillView Summary

**Replaced both opaque `gradientMaterial` bases (`islandFill`'s `.liquidGlass` branch and `liquidGlassEffectLayer`'s own warp fill) with a real translucent `.ultraThinMaterial`, then layered Plan 35-06's `liquidGlassEdgeOpacity` colorEffect shader on top to ramp alpha from transparent-at-the-edge to opaque-at-the-center — closing the 35-UAT.md Test 1 "flat opaque grey" rejection at its root cause.**

## Performance

- **Duration:** ~20 min
- **Completed:** 2026-07-16
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments
- `islandFill`'s `.liquidGlass` case now returns `AnyShapeStyle(.ultraThinMaterial)` — a live-blurring, `NSVisualEffectView`-backed SwiftUI `Material` — instead of the opaque `gradientMaterial` it previously duplicated from `.gradient`. `.gradient`/`.solidBlack` remain byte-for-byte unchanged.
- `liquidGlassEffectLayer`'s base warp layer now fills `.ultraThinMaterial` (was `Self.gradientMaterial`), warped by the existing `.distortionEffect()` shader, then alpha-ramped by a new `.colorEffect(...)` call invoking `liquidGlassEdgeOpacity` with `parameters.edgeOpacity`/`parameters.centerOpacity` — the edge of the shape reads visibly more transparent than the interior, matching `reference-transparency-target.png`.
- All 3 chromatic-fringe passes (red/green/blue) now read `parameters.fringeOpacity` instead of the hardcoded `0.10` literal, so Plan 35-06's retuned per-state values (0.15 collapsed / 0.20 expanded) take effect.
- `matchedGeometryEffect`-before-`.frame` ordering at all 4 island-shell fill sites verified untouched (regression guard re-checked after both tasks).

## Task Commits

Each task was committed atomically:

1. **Task 1: islandFill .liquidGlass branch — translucent Material (D-10, location 1 of 2)** - `6ea147a` (feat)
2. **Task 2: liquidGlassEffectLayer — translucent base + edge-weighted opacity + fringeOpacity wiring (D-10 location 2, D-11)** - `429627d` (feat)

## Files Created/Modified
- `Islet/Notch/NotchPillView.swift` — `islandFill`'s `.liquidGlass` case; `liquidGlassEffectLayer`'s base fill, new `.colorEffect(...)` call, and the 3 fringe passes' opacity source

## Decisions Made
- Both of D-10's two flagged opaque-base locations were fixed in this plan (islandFill branch in Task 1, liquidGlassEffectLayer's own base fill in Task 2) — the overlay's base fill is the one that actually reads on-screen (it fully covers `islandFill`'s own fill beneath it), but `islandFill`'s branch was kept translucent too for defensiveness/consistency per D-10's explicit instruction to fix both locations.
- D-11's "opacity/blur" phrasing implemented as an opacity-only ramp — SwiftUI has no primitive for a spatially-varying blur radius within a single `Material` fill. `.ultraThinMaterial` already supplies uniform live blur throughout (a strict improvement over the fully opaque prior state), and the opacity ramp is the verifiable, on-screen-observable part of the "desktop bleeds through at the edge" effect. Flagged as a gap for Plan 35-08's on-device UAT to assess, not silently claimed as fully solved.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Grep acceptance-criteria false positive from an explanatory code comment**
- **Found during:** Task 2 (grep verification of `shape.fill(.ultraThinMaterial)` count)
- **Issue:** A doc comment explaining that the overlay's own fill (not `islandFill`'s branch) is the visually dominant surface literally quoted `shape.fill(.ultraThinMaterial)`, making the acceptance-criteria grep return 2 instead of the expected 1 (the one real call site).
- **Fix:** Reworded the comment to describe the surface without reproducing the literal call syntax.
- **Files modified:** `Islet/Notch/NotchPillView.swift`
- **Verification:** `grep -c "shape.fill(.ultraThinMaterial)"` now returns 1, matching the plan's acceptance criteria.
- **Committed in:** `429627d` (part of Task 2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 3) — same false-positive class Plan 35-06 hit and documented (doc comments quoting the literal code pattern under grep-verified acceptance criteria).
**Impact on plan:** Comment-wording only; no functional change. No scope creep.

## Issues Encountered
None.

## User Setup Required
None — no external service configuration required.

## Next Phase Readiness
`islandFill` and `liquidGlassEffectLayer` both now render a genuinely translucent, edge-weighted surface for `.liquidGlass`, with `.gradient`/`.solidBlack` unchanged and the `matchedGeometryEffect`/`.frame` ordering regression guard intact at all 4 sites. Ready for Plan 35-08's on-device UAT — including explicit verification of the documented blur-uniformity gap (opacity ramps, blur radius does not) and the overall visual result against `reference-transparency-target.png`.

---
*Phase: 35-liquid-glass-material*
*Completed: 2026-07-16*

## Self-Check: PASSED

Verified `Islet/Notch/NotchPillView.swift` exists with both edits present; both task commits (`6ea147a`, `429627d`) confirmed in `git log --oneline`.
