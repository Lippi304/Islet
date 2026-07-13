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
    // SHAPE-01 (v1.5, Phase 29) — D-01/D-05 final design (after a "shoulder bulge" detour
    // that read as "eine Kugel"/a ball-knob on-device — see 29-CONTEXT.md's "Post-D-01/D-05
    // implementation detour" section for the full history): `topFlareWidth` is the total
    // width of a fixed, NARROW top band (matching the physical notch cutout), centered on the
    // rect. The path sweeps monotonically outward from that band down to the rect's own full
    // width, then merges into the unmodified topCornerRadius corner transition — no outward
    // overflow past rect.minX/rect.maxX, unlike the earlier shoulder-bulge design. Trade-off
    // (explicitly confirmed by the user): only the narrow band touches `rect.minY` flush; the
    // wide body sits `flareDepth` below the true screen edge, matching the Droppy reference
    // exactly. Defaults to `0`, which degenerates the flared branch entirely — the guard below
    // keeps `collapsedIsland`/`mediaWingsOrToast` (which never pass this) byte-identical to the
    // pre-Phase-29 path.
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

        // Flared path — a monotonic narrow-to-wide funnel, never wider than `rect` itself.
        let bandHalfWidth = topFlareWidth / 2
        let bandLeftX = rect.midX - bandHalfWidth
        let bandRightX = rect.midX + bandHalfWidth

        // How far down the sweep gets before the (unmodified) topCornerRadius corner-cut
        // begins, shifted down by this amount. Adaptive per rect so the tightest real call
        // site (wingsShape, 290x32, corners 6/6) never inverts its own straight wall — a small
        // floor is reserved below the corner-cut/bottom-corner combo.
        let desiredFlareDepth: CGFloat = 18
        let flareDepth = min(desiredFlareDepth, max(0, rect.height - topCornerRadius - bottomCornerRadius - 4))

        p.move(to: CGPoint(x: bandLeftX, y: rect.minY))
        p.addLine(to: CGPoint(x: bandRightX, y: rect.minY))   // narrow flat band, flush with rect.minY

        // RIGHT sweep: ONE continuous quad curve (control.x shares the band edge's x, so x
        // never reverses direction) from the band out to the rect's own full width, then the
        // EXACT unmodified topCornerRadius corner-curve, merely shifted down by flareDepth.
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + flareDepth),
                       control: CGPoint(x: bandRightX, y: rect.minY + flareDepth))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - topCornerRadius, y: rect.minY + flareDepth + topCornerRadius),
                       control: CGPoint(x: rect.maxX - topCornerRadius, y: rect.minY + flareDepth))

        // Downstream math is 100% the existing, unmodified topCornerRadius/bottomCornerRadius
        // wall + corner geometry — identical to the topFlareWidth == 0 branch above, just
        // re-entered after the sweep+corner-cut instead of after a plain quad curve.
        p.addLine(to: CGPoint(x: rect.maxX - topCornerRadius, y: rect.maxY - bottomCornerRadius))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - topCornerRadius - bottomCornerRadius, y: rect.maxY),
                       control: CGPoint(x: rect.maxX - topCornerRadius, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + topCornerRadius + bottomCornerRadius, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX + topCornerRadius, y: rect.maxY - bottomCornerRadius),
                       control: CGPoint(x: rect.minX + topCornerRadius, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + topCornerRadius, y: rect.minY + flareDepth + topCornerRadius))

        // LEFT sweep — exact mirror of the right, corner-curve first then the sweep back up
        // to the band's left edge.
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY + flareDepth),
                       control: CGPoint(x: rect.minX + topCornerRadius, y: rect.minY + flareDepth))
        p.addQuadCurve(to: CGPoint(x: bandLeftX, y: rect.minY),
                       control: CGPoint(x: bandLeftX, y: rect.minY + flareDepth))
        return p
    }
}
