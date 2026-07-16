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
struct LiquidGlassParameters {
    var borderWidth: CGFloat
    var blurWidth: CGFloat
    var distortionScale: CGFloat
    var redOffset: CGFloat
    var greenOffset: CGFloat
    var blueOffset: CGFloat
    var saturation: CGFloat
    var backgroundOpacity: CGFloat

    static let collapsed = LiquidGlassParameters(
        borderWidth: 0.15,
        blurWidth: 2.5,
        distortionScale: -5,
        redOffset: 0,
        greenOffset: 0.5,
        blueOffset: 1,
        saturation: 1.0,
        backgroundOpacity: 0.04
    )

    static let expanded = LiquidGlassParameters(
        borderWidth: 0.11,
        blurWidth: 7,
        distortionScale: -13,
        redOffset: 0,
        greenOffset: 1.25,
        blueOffset: 2.5,
        saturation: 1.08,
        backgroundOpacity: 0.07
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
