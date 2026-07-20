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
// D-10/D-11 (Plan 35-06, post-UAT material pivot) [SUPERSEDED round 3 by
// D-12/D-13/D-14/D-15, Plan 35-09]: this file also now backs a SECOND
// colorEffect shader, `liquidGlassEdgeOpacity` (LiquidGlassShader.metal).
// Round 2 (D-10/D-11) applied it to the translucent Material's OWN alpha,
// which read as uniformly bright since `.ultraThinMaterial` has no inherent
// dark tint (35-UAT.md Test 1 Round 2: "Es ist immer noch so hell."). Round 3
// (D-12/D-13/D-14/D-15) keeps `liquidGlassEdgeOpacity`'s formula byte-for-byte
// unchanged but repoints it at a solid dark FROST layer (`Self.gradientMaterial`
// in `NotchPillView.swift`) instead: `edgeOpacity`/`centerOpacity` now describe
// the frost's alpha — near-opaque toward the center (D-15: allowed as dark as
// `.solidBlack`), thin/transparent right at the rounded edge (D-12/D-13) — so
// the warped `.ultraThinMaterial` backdrop underneath is only ever revealed
// through a narrow rim, never washed uniformly across the whole surface.
// `fringeOpacity` centralizes the chromatic-fringe passes' own opacity
// (previously hardcoded inline as `Color.red/green/blue.opacity(0.10)` in
// NotchPillView.swift — Plan 35-07 updated that call site to read this field
// instead), unaffected by the round-3 pivot.
struct LiquidGlassParameters {
    var borderWidth: CGFloat
    var blurWidth: CGFloat
    var distortionScale: CGFloat
    var redOffset: CGFloat
    var greenOffset: CGFloat
    var blueOffset: CGFloat
    var saturation: CGFloat
    var backgroundOpacity: CGFloat
    /// D-13 (supersedes D-11) — alpha the solid dark FROST layer (`Self.gradientMaterial`
    /// in `NotchPillView.swift`) mixes toward right at the rounded edge — low, so the
    /// warped `.ultraThinMaterial` backdrop bleeds through in a narrow rim (D-12/D-14).
    var edgeOpacity: CGFloat
    /// D-13 (supersedes D-11) — alpha the frost layer mixes toward at the interior — high,
    /// near-opaque, allowed as dark as `.solidBlack` (D-15).
    var centerOpacity: CGFloat
    /// D-11 — chromatic-fringe (R/G/B) passes' own opacity, centralized here
    /// (replaces NotchPillView.swift's hardcoded `Color.red/green/blue.opacity(0.10)`).
    var fringeOpacity: CGFloat

    // Round-3 retune (D-12/D-13/D-14/D-15, Plan 35-09): narrower borderWidth/blurWidth
    // shrink the shared rim band (D-14: thin sliver, not a broad soft gradient) for both
    // the distortion warp and the frost reveal; lower edgeOpacity/higher centerOpacity make
    // the frost read as transparent right at the edge and near-opaque toward the interior.
    // On-device-tunable starting points per CONTEXT.md's Claude's Discretion grant — final
    // values pending Plan 35-10's on-device UAT, same as every previous round.
    // Round-5 retune (debug session liquid-glass-grey-rim-regression, 2026-07-16):
    // redOffset/greenOffset/blueOffset had been frozen at their original Plan 35-02
    // scaffolding values since before ANY on-device UAT ran, never revisited when
    // round-3 shrank borderWidth/blurWidth (the rim band the offsets must separate
    // WITHIN). Old blueOffset was only ~26% of the rim band width, so ~74% of the
    // visible rim showed all 3 chromatic-fringe passes fully overlapping — which
    // `.blendMode(.screen)` renders as white/grey, not color. Widened so channel
    // separation covers most of the band (blueOffset ~= band width), leaving only
    // the innermost sliver near the mask's falloff as a white highlight (matches
    // D-17's "white wash reads as rim highlight" intent). fringeOpacity nudged up
    // to keep the now-thinner per-channel color visible against the dark frost.
    static let collapsed = LiquidGlassParameters(
        borderWidth: 0.07,
        blurWidth: 1.2,
        distortionScale: -5,
        redOffset: 0,
        greenOffset: 1.4,
        blueOffset: 2.8,
        saturation: 1.0,
        backgroundOpacity: 0.05,
        edgeOpacity: 0.08, centerOpacity: 0.90, fringeOpacity: 0.20
    )

    static let expanded = LiquidGlassParameters(
        borderWidth: 0.05,
        blurWidth: 2.5,
        distortionScale: -13,
        redOffset: 0,
        greenOffset: 3.5,
        blueOffset: 7,
        saturation: 1.08,
        backgroundOpacity: 0.08,
        edgeOpacity: 0.10, centerOpacity: 0.92, fringeOpacity: 0.25
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
