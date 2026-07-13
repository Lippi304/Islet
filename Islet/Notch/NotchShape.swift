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
    // SHAPE-01 (v1.5) — D-01/D-05 REVISED AGAIN 2026-07-13 (round 6, on-device UAT): the
    // concave-sweep design (round 5) pulled the ENTIRE top edge outside the narrow band down
    // by `flareDepth` before reaching the rect's real width — on a real notch that reads as
    // "not at the screen edge at all", since every prior round (and the whole pre-Phase-29
    // app) has the top edge flush with the true screen/notch top across its FULL width, no
    // exceptions. That flush-top invariant is restored below: the flat top run always spans
    // `rect.minX...rect.maxX` at `rect.minY`, full width, exactly like the `topFlareWidth == 0`
    // branch. The flare now reads purely as a curved outward "shoulder" bulge that starts right
    // where the flush top ends and merges back into the EXISTING topCornerRadius corner
    // transition's own endpoint — un-shifted, no y-offset applied to it — so everything
    // downstream (the straight walls + bottom corners) is untouched. `topFlareWidth` is once
    // again an added OUTWARD MARGIN (how far past rect.minX/rect.maxX the shoulder bulges), the
    // same semantic the pre-round-5 property used, not a band width. Defaults to `0` (today's
    // flush edge, no bulge) so `collapsedIsland`/`mediaWingsOrToast`, which never pass it, stay
    // pixel-identical (Success Criterion #2).
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

        // Flared path (round 6 — flush-top shoulder bulge). `bulge` is how far past
        // rect.minX/rect.maxX the shoulder swings out before curving back in.
        let bulge = topFlareWidth

        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY)) // FULL-WIDTH flush top run — never recessed

        // RIGHT shoulder bulge: (rect.maxX, rect.minY) -> the topCornerRadius transition's own
        // UNCHANGED, un-shifted endpoint (rect.maxX - topCornerRadius, rect.minY +
        // topCornerRadius). A CUBIC addCurve (not a quad) is required here — a quad curve has a
        // single control point and can only arc toward it, producing one simple bow; a real
        // "swing out past the edge, then curve back in" shoulder needs two independent control
        // points pulling in different directions, which only a cubic Bezier provides.
        p.addCurve(to: CGPoint(x: rect.maxX - topCornerRadius, y: rect.minY + topCornerRadius),
                   control1: CGPoint(x: rect.maxX + bulge, y: rect.minY + topCornerRadius * 0.15),
                   control2: CGPoint(x: rect.maxX + bulge * 0.25, y: rect.minY + topCornerRadius * 0.9))

        // Downstream math from here is 100% the existing, unmodified topCornerRadius/
        // bottomCornerRadius corner + wall geometry (identical to the topFlareWidth == 0 branch
        // above, just re-entered after the bulge instead of after a plain quad curve).
        p.addLine(to: CGPoint(x: rect.maxX - topCornerRadius, y: rect.maxY - bottomCornerRadius))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - topCornerRadius - bottomCornerRadius, y: rect.maxY),
                       control: CGPoint(x: rect.maxX - topCornerRadius, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + topCornerRadius + bottomCornerRadius, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX + topCornerRadius, y: rect.maxY - bottomCornerRadius),
                       control: CGPoint(x: rect.minX + topCornerRadius, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + topCornerRadius, y: rect.minY + topCornerRadius))

        // LEFT shoulder bulge — mirror of the right, closing the path back at the flush top's
        // start (rect.minX, rect.minY).
        p.addCurve(to: CGPoint(x: rect.minX, y: rect.minY),
                   control1: CGPoint(x: rect.minX - bulge * 0.25, y: rect.minY + topCornerRadius * 0.9),
                   control2: CGPoint(x: rect.minX - bulge, y: rect.minY + topCornerRadius * 0.15))
        return p
    }
}
