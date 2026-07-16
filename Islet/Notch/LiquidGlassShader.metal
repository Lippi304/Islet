#include <metal_stdlib>
using namespace metal;

// D-01 — Islet's first Metal shader. Ports the "Liquid Glass" edge-warp technique
// from reference-GlassSurface.md's SVG `feDisplacementMap` filter: a per-pixel
// displacement that warps most strongly right at the shape's rounded edge and
// fades to near-zero toward the interior. This function is the base geometric
// warp shared by the primary fill pass AND the 3 chromatic-fringe (R/G/B) passes
// (LiquidGlassShader.swift's `liquidGlassChannelShaders(...)` calls this same
// function 4 times with different `distortionScale` values per channel).
//
// D-10/D-11 (Plan 35-06): a second stitchable colorEffect function,
// `liquidGlassEdgeOpacity` below, now shares this file. Both functions drive
// their per-pixel math off the SAME `liquidGlassEdgeFalloff` helper (extracted
// from this function's original Steps 1-5) — one source of truth for "how
// close to the edge is this pixel", per D-11's explicit instruction not to
// invent a second independent falloff curve.
//
// topCornerRadius/bottomCornerRadius are passed in verbatim from NotchShape's
// own stored properties at the call site (UI-SPEC hard constraint: "Never a
// free value — read from the shape") — never hardcoded here.

// Shared edge-falloff helper (extracted from liquidGlassDistortion's original
// Steps 1-5 — pure extraction, D-01's warp math is unaffected by this refactor).
// Returns `t`: 0.0 = right at the shape boundary (full effect), 1.0 = interior
// (no effect). Reference equivalent: the displacement map's brightness value
// at a given pixel (bright near edge, dark at center), softened by `blurWidth`
// exactly as the reference's `blur` parameter softens its displacement map.
static float liquidGlassEdgeFalloff(
    float2 position,
    float2 size,
    float topCornerRadius,
    float bottomCornerRadius,
    float borderWidth,
    float blurWidth
) {
    // Step 1 — approximate NotchShape's asymmetric hanging-pill silhouette
    // (small top corners, larger bottom corners) for the warp math by linearly
    // blending the two radii by vertical position: top edge (y=0) uses
    // topCornerRadius, bottom edge (y=size.y) uses bottomCornerRadius.
    // Reference equivalent: the displacement map's `rx="${borderRadius}"` on
    // the generated SVG rounded rects (generateDisplacementMap()).
    float t01 = size.y > 0.0 ? clamp(position.y / size.y, 0.0, 1.0) : 0.0;
    float effectiveRadius = mix(topCornerRadius, bottomCornerRadius, t01);

    // Step 2 — standard rounded-box signed distance field to the shape
    // boundary (reference equivalent: the displacement map's rounded-rect
    // shape itself, rasterized then blurred).
    float2 halfSize = size * 0.5;
    float2 q = abs(position - halfSize) - (halfSize - effectiveRadius);
    float dist = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - effectiveRadius;

    // Step 3 — inward "edge closeness": positive inside the shape, growing
    // toward the center. Reference equivalent: the displacement map's
    // brightness value at a given pixel (bright near edge, dark at center).
    float edgeDist = -dist;

    // Step 4 — width of the warp band. Mirrors the reference's
    // `edgeSize = min(actualWidth, actualHeight) * (borderWidth * 0.5)`, but
    // uses the full `borderWidth` fraction directly since this port folds the
    // reference's separate `brightness`/`opacity` center-tone controls into
    // this one falloff curve (Step 5) — no separate `brightness` parameter
    // (see 35-UI-SPEC.md Material/Shader Contract table note).
    float edgeSize = min(size.x, size.y) * borderWidth;

    // Step 5 — transition from full effect at the boundary (t=0) to none
    // once `blurWidth` points past the border band (t=1). `blurWidth`
    // softens the transition exactly as the reference's `blur` parameter
    // softens its displacement map (generateDisplacementMap()'s
    // `filter:blur(${blur}px)`).
    return smoothstep(0.0, edgeSize + blurWidth, edgeDist);
}

// Scaffolding step (Plan 35-02): this function compiles but is not yet called
// from any SwiftUI view — Plan 35-03 wires it into the island shell's
// `.distortionEffect()` modifier stack.
[[ stitchable ]] float2 liquidGlassDistortion(
    float2 position,
    float2 size,
    float topCornerRadius,
    float bottomCornerRadius,
    float borderWidth,
    float blurWidth,
    float distortionScale
) {
    float t = liquidGlassEdgeFalloff(position, size, topCornerRadius, bottomCornerRadius, borderWidth, blurWidth);

    // Step 6 — outward direction from the shape's center, epsilon-guarded
    // against the zero-vector case at dead center (T-35-04: prevents a
    // NaN/undefined direction on a degenerate zero-size view).
    float2 halfSize = size * 0.5;
    float2 fromCenter = position - halfSize;
    float2 dir = normalize(fromCenter + float2(1e-4, 1e-4));

    // Step 7 — apply the warp. Reference equivalent: `feDisplacementMap`'s
    // per-channel `scale = distortionScale + offset` (LiquidGlassShader.swift
    // supplies distortionScale already summed with the per-channel offset).
    return position + dir * (1.0 - t) * distortionScale;
}

// D-10/D-11 (Plan 35-06) — per-pixel opacity ramp for the translucent Material
// base: this multiplies the Material base's per-pixel alpha down to
// `edgeOpacity` right at the rounded edge (desktop visibly bleeds through,
// matching `reference-transparency-target.png`) and up to `centerOpacity`
// toward the interior (keeps foreground content legible per D-03), driven by
// the IDENTICAL `liquidGlassEdgeFalloff` curve the warp shader above uses —
// one source of truth for "how close to the edge is this pixel", per D-11's
// explicit instruction not to invent a second independent falloff curve.
//
// SwiftUI `.colorEffect(_:)` per-pixel color-transform signature — NEVER the
// stitchable-float2 signature liquidGlassDistortion above uses; colorEffect
// shaders return `half4`, never a position.
//
// Scaffolding step (Plan 35-06): this function compiles but is not yet called
// from any SwiftUI view — Plan 35-07 wires it into NotchPillView.swift's
// material base.
[[ stitchable ]] half4 liquidGlassEdgeOpacity(
    float2 position,
    half4 color,
    float2 size,
    float topCornerRadius,
    float bottomCornerRadius,
    float borderWidth,
    float blurWidth,
    float edgeOpacity,
    float centerOpacity
) {
    float t = liquidGlassEdgeFalloff(position, size, topCornerRadius, bottomCornerRadius, borderWidth, blurWidth);
    float alpha = mix(edgeOpacity, centerOpacity, t);
    return half4(color.rgb, color.a * half(alpha));
}
