---
phase: 35-liquid-glass-material
plan: 9
subsystem: liquid-glass-material
tags: [swiftui, metal, shader, material, glass]
dependency-graph:
  requires: []
  provides: [glass-01-frost-over-material-compositing]
  affects: [35-10-on-device-uat]
tech-stack:
  added: []
  patterns:
    - "Solid dark frost layer (Self.gradientMaterial) composited IN FRONT of a warped translucent Material backdrop, with the frost's own alpha (not the material's) ramped by an edge-falloff colorEffect shader"
key-files:
  created: []
  modified:
    - Islet/Notch/LiquidGlassShader.swift
    - Islet/Notch/NotchPillView.swift
decisions:
  - "D-12/D-13/D-14/D-15 round-3 pivot implemented exactly as specified: zero .metal file changes, only which SwiftUI layer consumes liquidGlassEdgeOpacity and the LiquidGlassParameters numeric starting points changed"
metrics:
  duration: ~20min
  completed: 2026-07-16
---

# Phase 35 Plan 9: Liquid Glass Frost-Over-Material Compositing Summary

Restructured the Liquid Glass material so a solid dark frost layer (`Self.gradientMaterial`, reused from the pre-round-2 `.gradient` style) sits in front of the warped `.ultraThinMaterial` backdrop, with the frost's own alpha — not the material's — ramped by the unchanged `liquidGlassEdgeOpacity` shader, so the backdrop bleeds through only at a narrow, opacity-ramped rim instead of washing uniformly bright across the whole surface.

## What Was Built

**Task 1 (`LiquidGlassShader.swift`):** Retuned `LiquidGlassParameters.collapsed`/`.expanded` per D-13/D-14/D-15 — narrower `borderWidth`/`blurWidth` (thinner shared rim band for both the distortion warp and the frost reveal) and lower `edgeOpacity`/higher `centerOpacity` (frost reads transparent at the very edge, near-`.solidBlack`-opaque toward the interior). Doc comments updated to note D-12/D-13/D-14/D-15 supersede D-10/D-11 and that `edgeOpacity`/`centerOpacity` now describe the frost layer's alpha, not the Material's own alpha. Zero `.metal` file edits — `liquidGlassEdgeOpacity`'s formula is reused byte-for-byte, confirmed via `git diff` returning 0 lines against the plan's base commit.

**Task 2 (`NotchPillView.swift`):** `islandFill`'s `.liquidGlass` branch now returns `Self.gradientMaterial` (identical literal to `.gradient`'s branch) instead of raw `.ultraThinMaterial`. `liquidGlassEffectLayer`'s `ZStack` split the former single material+ramp layer into two: the warped `.ultraThinMaterial` backdrop at the back (no `colorEffect` chained to it anymore), and a new `shape.fill(Self.gradientMaterial).colorEffect(liquidGlassEdgeOpacity, ...)` frost layer immediately in front of it, now carrying the edge-opacity ramp. The 3 chromatic-fringe passes, `.saturation`, the trailing white-wash `.overlay`, `.clipShape`, and `.allowsHitTesting(false)` are all byte-for-byte unchanged.

## Deviations from Plan

None — plan executed exactly as written. All 15 acceptance-criteria greps (6 in Task 1, 9 in Task 2) and both `xcodebuild build -scheme Islet -destination 'platform=macOS'` verifications passed on first attempt; no auto-fixes needed.

## Verification

- `xcodebuild build -scheme Islet -destination 'platform=macOS'` — BUILD SUCCEEDED (both tasks)
- `grep -A1 'matchedGeometryEffect(id: "island", in: ns)' Islet/Notch/NotchPillView.swift | grep -c '\.frame('` → 4 (regression guard: the 4 island-shell call sites' own `.matchedGeometryEffect`/`.frame` ordering untouched)
- `grep -c 'return AnyShapeStyle(.ultraThinMaterial)' Islet/Notch/NotchPillView.swift` → 0 (round-2 regression fully reverted from `islandFill`)
- `git diff <plan-base> -- Islet/Notch/LiquidGlassShader.metal` → 0 lines (zero shader-file changes, per D-13)

## Known Stubs

None.

## Threat Flags

None — pure local rendering change, same trust boundary as every prior Phase 35 plan (per the plan's own threat_model: no network, no external input, no new data storage).

## Self-Check: PASSED

- FOUND: Islet/Notch/LiquidGlassShader.swift (modified, exists)
- FOUND: Islet/Notch/NotchPillView.swift (modified, exists)
- FOUND: commit 0d19a37 (Task 1: retune LiquidGlassParameters)
- FOUND: commit 7bfcbdb (Task 2: frost-over-material compositing)
