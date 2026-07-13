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
    // SHAPE-01 (v1.5) — fixed, identical-across-all-presentations outward widen of the
    // top edge, expanded-only (D-05). Defaults to 0 (today's flush top edge) so
    // `collapsedIsland`/`mediaWingsOrToast`, which never pass it, stay pixel-identical.
    var topFlareWidth: CGFloat = 0
    func path(in rect: CGRect) -> Path {
        var p = Path()
        // The flare brackets the UNCHANGED topCornerRadius corners below with a pair of
        // new bridging quad-curves: at topFlareWidth == 0 both bridges are degenerate
        // (start == control == end), collapsing to a no-op and reproducing today's exact
        // path; at a non-zero value they widen the top edge outward before curving back
        // in to meet the existing corner geometry.
        let flareStart = CGPoint(x: rect.minX - topFlareWidth, y: rect.minY)
        let flareEnd = CGPoint(x: rect.maxX + topFlareWidth, y: rect.minY)
        p.move(to: flareStart)
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY), control: flareStart)
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
        p.addQuadCurve(to: flareEnd, control: flareEnd)
        p.addLine(to: flareStart)
        return p
    }
}
