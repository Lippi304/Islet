import SwiftUI

// ISL-01 — the asymmetric rounded-pill silhouette of the physical notch.
//
// The real notch has SMALL top corners and LARGER bottom corners ("hanging" pill):
// flat top edge, quad-curved corners, rounded bottom. macOS does not expose the
// hardware corner radius, so these constants approximate it (prior-art defaults:
// top ≈ 6, bottom ≈ 14). They are tunable in dev (D-01/D-02) via a visible tint.
struct NotchShape: Shape {
    // Plain CGFloat stored properties → SwiftUI's Shape animation INTERPOLATES these
    // across the Phase-2 collapsed↔expanded morph (ISL-04). NotchPillView passes a
    // larger bottom radius for the expanded blob via this same initializer; the path
    // math below is unchanged, so the silhouette stays valid at every interpolated step.
    var topCornerRadius: CGFloat = 6
    var bottomCornerRadius: CGFloat = 14
    // SHAPE-01 (v1.5) — D-01/D-05 REVISED 2026-07-13 during Task 3 on-device UAT: the original
    // "subtle outward widen" read as imperceptible on-device. The user provided a concrete
    // reference (Droppy's shelf widget) and confirmed the flare should be a PRONOUNCED CONCAVE
    // sweep instead: the top edge stays NARROW (a fixed width matching the physical notch
    // cutout, D-05) for a short flat run, then curves outward/downward — like the neck of a
    // wine glass opening into its bowl — until it reaches the presentation's own already-
    // existing full rect width, at which point the UNCHANGED topCornerRadius transition takes
    // over exactly as it always has. `topFlareWidth` is now that fixed NARROW TOP-BAND WIDTH
    // (not an added outward margin, as the pre-revision version of this property was). Defaults
    // to `0` (today's flush top edge, no band/no flare) so `collapsedIsland`/`mediaWingsOrToast`,
    // which never pass it, stay pixel-identical (Success Criterion #2).
    var topFlareWidth: CGFloat = 0
    func path(in rect: CGRect) -> Path {
        var p = Path()
        guard topFlareWidth > 0 else {
            // Byte-identical to the pre-SHAPE-01 path (verified by regression test) — the hard
            // invariant for collapsedIsland/mediaWingsOrToast, which never pass topFlareWidth.
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addQuadCurve(to: CGPoint(x: rect.minX + topCornerRadius, y: rect.minY + topCornerRadius),
                           control: CGPoint(x: rect.minX + topCornerRadius, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.minX + topCornerRadius, y: rect.maxY - bottomCornerRadius))
            p.addQuadCurve(to: CGPoint(x: rect.minX + topCornerRadius + bottomCornerRadius, y: rect.maxY),
                           control: CGPoint(x: rect.minX + topCornerRadius, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.maxX - topCornerRadius - bottomCornerRadius, y: rect.maxY))
            p.addQuadCurve(to: CGPoint(x: rect.maxX - topCornerRadius, y: rect.maxY - bottomCornerRadius),
                           control: CGPoint(x: rect.maxX - topCornerRadius, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.maxX - topCornerRadius, y: rect.minY + topCornerRadius))
            p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY),
                           control: CGPoint(x: rect.maxX - topCornerRadius, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            return p
        }

        // Flared path (D-01/D-05 revised). `bandWidth` is clamped to rect.width defensively (a
        // future presentation narrower than the fixed band constant must not invert the shape).
        // `flareDepth` is how far DOWN (y) the sweep travels before reaching the full rect width —
        // capped at 20pt and at 35% of the rect's own height so short presentations (the 32pt-tall
        // wings strip) still leave room for the corner radii + a straight wall beneath the sweep.
        let bandWidth = min(topFlareWidth, rect.width)
        let bandLeft = rect.midX - bandWidth / 2
        let bandRight = rect.midX + bandWidth / 2
        let flareDepth = min(20, rect.height * 0.35)
        // Where the full rect width is reached — i.e. where the UNCHANGED topCornerRadius
        // transition begins, shifted down from rect.minY by flareDepth.
        let topY = rect.minY + flareDepth

        p.move(to: CGPoint(x: bandLeft, y: rect.minY))
        p.addLine(to: CGPoint(x: bandRight, y: rect.minY)) // the narrow flat top-band run

        // RIGHT concave sweep: band edge -> (rect.maxX, topY), where the existing topCornerRadius
        // corner curve takes over. This uses a CUBIC addCurve, deliberately deviating from
        // 29-PATTERNS.md's quad-curve-only convention (documented there for the earlier, now-
        // superseded straight-widen design): a quad curve has a single control point and can only
        // bulge toward it, producing one simple arc. The Droppy-reference "wine glass" profile
        // needs an S-shaped curve that stays close to the narrow neck for most of the depth and
        // then flares rapidly only near the bottom — that requires two independent control
        // points, which only a cubic Bezier provides (D-02 fallback, 29-CONTEXT.md).
        p.addCurve(to: CGPoint(x: rect.maxX, y: topY),
                   control1: CGPoint(x: bandRight, y: rect.minY + flareDepth * 0.8),
                   control2: CGPoint(x: rect.maxX, y: rect.minY + flareDepth * 0.2))

        // Existing topCornerRadius transition — UNCHANGED math, shifted down by flareDepth.
        p.addQuadCurve(to: CGPoint(x: rect.maxX - topCornerRadius, y: topY + topCornerRadius),
                       control: CGPoint(x: rect.maxX - topCornerRadius, y: topY))
        p.addLine(to: CGPoint(x: rect.maxX - topCornerRadius, y: rect.maxY - bottomCornerRadius))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - topCornerRadius - bottomCornerRadius, y: rect.maxY),
                       control: CGPoint(x: rect.maxX - topCornerRadius, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + topCornerRadius + bottomCornerRadius, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX + topCornerRadius, y: rect.maxY - bottomCornerRadius),
                       control: CGPoint(x: rect.minX + topCornerRadius, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + topCornerRadius, y: topY + topCornerRadius))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: topY),
                       control: CGPoint(x: rect.minX + topCornerRadius, y: topY))

        // LEFT concave sweep — mirror of the right sweep, closing the path back at the band.
        p.addCurve(to: CGPoint(x: bandLeft, y: rect.minY),
                   control1: CGPoint(x: rect.minX, y: rect.minY + flareDepth * 0.2),
                   control2: CGPoint(x: bandLeft, y: rect.minY + flareDepth * 0.8))
        return p
    }
}
