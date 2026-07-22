---
phase: 35-liquid-glass-material
reviewed: 2026-07-16T14:38:00Z
depth: standard
files_reviewed: 5
files_reviewed_list:
  - Islet/ActivitySettings.swift
  - Islet/Notch/LiquidGlassShader.metal
  - Islet/Notch/LiquidGlassShader.swift
  - Islet/Notch/NotchPillView.swift
  - Islet/SettingsView.swift
findings:
  critical: 1
  warning: 2
  info: 0
  total: 3
status: issues_found
---

# Phase 35: Code Review Report

**Reviewed:** 2026-07-16T14:38:00Z
**Depth:** standard
**Files Reviewed:** 5
**Status:** issues_found

## Summary

Reviewed the full Liquid Glass material feature end-to-end: the Metal shader
(`liquidGlassEdgeFalloff`/`liquidGlassDistortion`/`liquidGlassEdgeOpacity`), its
Swift shader-argument wiring (`LiquidGlassParameters`, `liquidGlassChannelShaders`),
the island-shell compositing in `NotchPillView.swift` (`islandFill`,
`liquidGlassEffectLayer`, `liquidGlassRimMask`, and all 4 call sites: collapsed
pill, `blobShape`, `wingsShape`, `mediaWingsOrToast`), and the Settings-side
material preference plumbing (`ActivitySettings.swift`, `SettingsView.swift`).

The round-4 remediation (`liquidGlassRimMask` + 4 `.colorEffect(rimMask)` sites)
is internally consistent: the mask reuses the same `borderWidth`/`blurWidth` band
as the frost layer (D-18), the edge/center opacity direction is inverted
correctly (full visibility at rim, invisible at center — verified against the
`liquidGlassEdgeOpacity` Metal formula), and the layering order (base material →
frost → 3 masked fringe passes → masked white-wash, all *behind* the foreground
content overlay) matches the documented design intent. Shader argument lists at
every call site line up positionally with the Metal function signatures — no
argument-order mismatches found. `maxSampleOffset` values are conservative
over-estimates of actual per-channel displacement, never under-estimates, so no
sampling-clip risk.

One real functional bug was found: `SettingsView.swift`'s new Liquid-Glass-style
window background (D-08/D-09) is wired unconditionally — it never reads the
`materialStyle` preference it sits right next to, so it renders identically
regardless of whether the user picked Gradient, Solid Black, or Liquid Glass.
Two maintainability warnings (shader-argument duplication risk, and duplicate
shape reconstruction risk) round out the findings.

## Critical Issues

### CR-01: Settings window's Liquid Glass background ignores the user's Appearance Style preference

**File:** `Islet/SettingsView.swift:140-163`
**Issue:** The doc comment above this `.background(...)` block explicitly states the design intent: "D-08 approved extending Liquid Glass to the Settings window... D-09 calls for the CALMER variant here." This describes *conditionally* extending the user's chosen material style into Settings. However, the actual `.background(...)` implementation never reads `materialStyle` — it unconditionally applies the frosted gradient + `.ultraThinMaterial` + rim-light stroke look on every render, regardless of whether the user selected `.gradient`, `.solidBlack`, or `.liquidGlass` in the "Appearance Style" picker (`systemSection`, line 281).

`materialStyle` is declared at line 51 and is only ever read by the `Picker(selection: $materialStyle)` binding at line 281 — it is never consulted to gate the background. Confirmed via grep: `materialStyle` has exactly one functional read site in the whole file (the Picker), and zero conditional branches anywhere.

Contrast this with `NotchPillView.swift`, where every Liquid Glass surface (`islandFill`, `liquidGlassEffectLayer`) strictly gates on `materialStyle == .liquidGlass` and is pixel-identical to the pre-Phase-35 look otherwise. Settings does not honor the same contract: a user who explicitly picks "Solid Black" (presumably because they dislike the glass look) still gets the frosted glass window chrome in Settings.

**Fix:**
```swift
.background(
    Group {
        if materialStyle == .liquidGlass {
            ZStack {
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.25), location: 0.0),
                        .init(color: .black.opacity(0.15), location: 0.65),
                        .init(color: .black.opacity(0.05), location: 1.0),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                Color.clear.background(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
            }
        } else {
            // whatever the pre-Phase-35 background was for .gradient/.solidBlack
        }
    }
)
```
If instead the *actual* intent was "always show the calmer glass chrome in
Settings regardless of the user's island material choice," the doc comment
(and D-08/D-09's phrasing) needs to be corrected to say so explicitly — as
written it reads as a bug, not a documented decision.

## Warnings

### WR-01: Duplicated shader-argument construction for `liquidGlassEdgeOpacity`

**File:** `Islet/Notch/NotchPillView.swift:321-330, 349-361`
**Issue:** `liquidGlassRimMask(shape:size:parameters:)` and the inline `Shader(...)` built for the frost layer's `.colorEffect(...)` (inside `liquidGlassEffectLayer`) both hand-construct a call into `"liquidGlassEdgeOpacity"` with the identical 5-argument prefix (`size, topCornerRadius, bottomCornerRadius, borderWidth, blurWidth`), differing only in the trailing `edgeOpacity`/`centerOpacity` values. Because this argument list is duplicated rather than shared, a future edit to one call site (e.g., reordering arguments, or adding a new shader parameter) can silently desync from the other — the compiler cannot catch a Metal `[[stitchable]]` argument-order mismatch, so this would fail silently at runtime (wrong values bound to wrong parameters) rather than at compile time.

**Fix:**
```swift
private func liquidGlassOpacityShader(shape: NotchShape, size: CGSize, parameters: LiquidGlassParameters,
                                        edgeOpacity: CGFloat, centerOpacity: CGFloat) -> Shader {
    Shader(
        function: .init(library: .default, name: "liquidGlassEdgeOpacity"),
        arguments: [
            .float2(size), .float(shape.topCornerRadius), .float(shape.bottomCornerRadius),
            .float(parameters.borderWidth), .float(parameters.blurWidth),
            .float(edgeOpacity), .float(centerOpacity)
        ]
    )
}
// frost layer: liquidGlassOpacityShader(shape:size:parameters:edgeOpacity: parameters.edgeOpacity, centerOpacity: parameters.centerOpacity)
// rim mask:    liquidGlassOpacityShader(shape:size:parameters:edgeOpacity: 1.0, centerOpacity: 0.0)
```

### WR-02: `NotchShape` reconstructed independently for the visible fill and the effect-layer overlay

**File:** `Islet/Notch/NotchPillView.swift:715-729, 1873-1882`
**Issue:** `blobShape` and `wingsShape` correctly build the shape once (`let shape = NotchShape(...)`) and reuse the same `shape` value for both the visible `.fill(...)` and the `liquidGlassEffectLayer(shape: shape, ...)` overlay, guaranteeing the rim mask always aligns with the actually-rendered edge. `collapsedIsland` and `mediaWingsOrToast` do not follow this pattern: they construct `NotchShape()` / `NotchShape(topCornerRadius: 6, bottomCornerRadius: toast != nil ? 16 : 6)` twice — once for the visible fill, once again (separately) for the `liquidGlassEffectLayer` call. The two constructions currently use identical literal arguments, so there is no visible bug today, but this is a divergence trap: if either call site's corner-radius arguments are edited without updating the other (e.g., a future on-device tuning pass on the toast shape), the rim mask's edge-falloff geometry would silently stop matching the rendered shape's real edge.

**Fix:** Hoist a single `let shape = NotchShape(...)` in `collapsedIsland` and `mediaWingsOrToast`, mirroring `blobShape`/`wingsShape`, and pass that same local to both the `.fill(...)` shape and `liquidGlassEffectLayer(shape:...)`.

---

_Reviewed: 2026-07-16T14:38:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
