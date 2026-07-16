import SwiftUI

// D-04 — tunable parameter contract for the Liquid Glass distortion shader
// (LiquidGlassShader.metal's `liquidGlassDistortion`). Two fixed starting
// points — collapsed pill vs. expanded island/wings — rather than a
// continuous size-driven interpolation: cheaper to build correctly while
// still satisfying the UI-SPEC's "visibly different intensity" requirement.
// Values below are midpoints of 35-UI-SPEC.md's Material/Shader Contract
// table ranges — on-device-tunable starting points per CONTEXT.md's Claude's
// Discretion grant, expected to be adjusted during Plan 35-03/35-05's UAT.
//
// Note: the UI-SPEC table's `brightness` row (map center brightness) has no
// field here — it's folded into the shader's edge-falloff curve instead (see
// LiquidGlassShader.metal Step 5's `smoothstep` transition, which already
// asymptotes toward near-zero displacement at the interior).
//
// D-10/D-11 (Plan 35-06, post-UAT material pivot): this file also now backs
// a SECOND colorEffect shader, `liquidGlassEdgeOpacity` (LiquidGlassShader.metal),
// which replaces the opaque `gradientMaterial` base with a real translucent
// Material and ramps its per-pixel alpha from `edgeOpacity` at the rounded
// edge to `centerOpacity` toward the interior. `fringeOpacity` centralizes the
// chromatic-fringe passes' own opacity (previously hardcoded inline as
// `Color.red/green/blue.opacity(0.10)` in NotchPillView.swift — Plan 35-07
// updates that call site to read this field instead). `backgroundOpacity`/
// `fringeOpacity`'s pre-revision values (0.04/0.07/0.10) were calibrated
// against a fully opaque base and read as barely-visible now that the base
// itself is translucent — the values below are bumped up per the CONTEXT.md
// retuning note, on-device-tunable starting points to be verified during
// Plan 35-08's UAT.
struct LiquidGlassParameters {
    var borderWidth: CGFloat
    var blurWidth: CGFloat
    var distortionScale: CGFloat
    var redOffset: CGFloat
    var greenOffset: CGFloat
    var blueOffset: CGFloat
    var saturation: CGFloat
    var backgroundOpacity: CGFloat
    /// D-11 — alpha `liquidGlassEdgeOpacity` mixes toward right at the rounded edge.
    var edgeOpacity: CGFloat
    /// D-11 — alpha `liquidGlassEdgeOpacity` mixes toward at the interior.
    var centerOpacity: CGFloat
    /// D-11 — chromatic-fringe (R/G/B) passes' own opacity, centralized here
    /// (replaces NotchPillView.swift's hardcoded `Color.red/green/blue.opacity(0.10)`).
    var fringeOpacity: CGFloat

    static let collapsed = LiquidGlassParameters(
        borderWidth: 0.15,
        blurWidth: 2.5,
        distortionScale: -5,
        redOffset: 0,
        greenOffset: 0.5,
        blueOffset: 1,
        saturation: 1.0,
        backgroundOpacity: 0.05,
        edgeOpacity: 0.15, centerOpacity: 0.55, fringeOpacity: 0.15
    )

    static let expanded = LiquidGlassParameters(
        borderWidth: 0.11,
        blurWidth: 7,
        distortionScale: -13,
        redOffset: 0,
        greenOffset: 1.25,
        blueOffset: 2.5,
        saturation: 1.08,
        backgroundOpacity: 0.08,
        edgeOpacity: 0.20, centerOpacity: 0.70, fringeOpacity: 0.20
    )
}

// The base geometric warp plus the 3 independently-offset chromatic-fringe
// passes (D-01) — `base` drives the main gradient-fill pass, `red`/`green`/
// `blue` are recombined (screen-blend, per reference-GlassSurface.md) to
// produce the rainbow edge fringe. Scaffolding step: nothing consumes these
// yet, Plan 35-03 wires them into the island shell's `.distortionEffect()`
// modifier stack.
struct LiquidGlassChannelShaders {
    let base: Shader
    let red: Shader
    let green: Shader
    let blue: Shader
}

// Builds all 4 Shader values from ONE distortionScale + per-channel offset,
// mirroring the reference component's `scale = distortionScale + offset`
// formula (reference-GlassSurface.md).
func liquidGlassChannelShaders(
    size: CGSize,
    topCornerRadius: CGFloat,
    bottomCornerRadius: CGFloat,
    parameters: LiquidGlassParameters
) -> LiquidGlassChannelShaders {
    let base = Shader(
        function: .init(library: .default, name: "liquidGlassDistortion"),
        arguments: [
            .float2(size),
            .float(topCornerRadius),
            .float(bottomCornerRadius),
            .float(parameters.borderWidth),
            .float(parameters.blurWidth),
            .float(parameters.distortionScale)
        ]
    )
    let red = Shader(
        function: .init(library: .default, name: "liquidGlassDistortion"),
        arguments: [
            .float2(size),
            .float(topCornerRadius),
            .float(bottomCornerRadius),
            .float(parameters.borderWidth),
            .float(parameters.blurWidth),
            .float(parameters.distortionScale + parameters.redOffset)
        ]
    )
    let green = Shader(
        function: .init(library: .default, name: "liquidGlassDistortion"),
        arguments: [
            .float2(size),
            .float(topCornerRadius),
            .float(bottomCornerRadius),
            .float(parameters.borderWidth),
            .float(parameters.blurWidth),
            .float(parameters.distortionScale + parameters.greenOffset)
        ]
    )
    let blue = Shader(
        function: .init(library: .default, name: "liquidGlassDistortion"),
        arguments: [
            .float2(size),
            .float(topCornerRadius),
            .float(bottomCornerRadius),
            .float(parameters.borderWidth),
            .float(parameters.blurWidth),
            .float(parameters.distortionScale + parameters.blueOffset)
        ]
    )

    return LiquidGlassChannelShaders(base: base, red: red, green: green, blue: blue)
}
