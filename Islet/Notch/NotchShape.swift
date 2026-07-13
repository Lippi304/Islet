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
        // The flare brackets the UNCHANGED topCornerRadius corners below with a pair of plain
        // straight `addLine` bridges (NOT quad curves — a quad curve whose control point equals
        // one of its own endpoints has a zero-length tangent there, which is exactly what the
        // corner rounding regressed to a flat/square corner in an earlier round of this task:
        // the degenerate curve mathematically collapses to a straight line anyway, so drawing it
        // as `addLine` instead removes the zero-tangent degeneracy without changing the resulting
        // shape at all). At topFlareWidth == 0 each bridge is a zero-length line (flareStart/
        // flareEnd collapse onto rect.minX/rect.maxX), reproducing today's exact path; at a
        // non-zero value they widen the top edge outward, then the UNCHANGED corner quad-curves
        // curl back in exactly as before — the corner rounding is untouched by the flare.
        let flareStart = CGPoint(x: rect.minX - topFlareWidth, y: rect.minY)
        let flareEnd = CGPoint(x: rect.maxX + topFlareWidth, y: rect.minY)
        p.move(to: flareStart)
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
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
        p.addLine(to: flareEnd)
        p.addLine(to: flareStart)
        return p
    }
}
