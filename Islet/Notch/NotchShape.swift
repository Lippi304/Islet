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
    // SHAPE-01 (v1.5, Phase 29) — FINAL, user-confirmed direction after two reverted detours
    // (a monotonic narrow-to-wide funnel, then a "shoulder bulge" that read as "eine Kugel"/a
    // ball-knob on-device — see 29-CONTEXT.md's "Post-D-01/D-05 implementation detour and final
    // confirmation" section for the full history). Both detours put the interesting geometry at
    // the shape's OUTER top corners; that was backwards. The physical MacBook camera notch sits
    // in the HORIZONTAL CENTER of the shape, not at its edges. So: the WIDE SIDES (left/right of
    // the camera) stay perfectly FLUSH with `rect.minY`, exactly like the pre-Phase-29 shape
    // always has — nothing changes there. `topFlareWidth` is now the width of a NARROW dip/notch
    // centered on `rect.midX`, matching the physical camera's own footprint, that recedes
    // downward by a shallow `notchDepth` with smooth quad-curve transitions on both sides. This
    // is a "dimple," not a taper or a bulge — the outer corners' `topCornerRadius` transition is
    // completely untouched. Defaults to `0`, which degenerates the flared branch entirely — the
    // guard below keeps `collapsedIsland`/`mediaWingsOrToast` (which never pass this)
    // byte-identical to the pre-Phase-29 path.
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

        // Flared path — everything is IDENTICAL to the unflared branch above (same corner/wall/
        // bottom geometry, same starting move) except the final top-edge close, which is now a
        // flush→dip→flush run instead of one straight line. The outer corners never move.
        let notchHalfWidth = topFlareWidth / 2
        let notchLeftX = rect.midX - notchHalfWidth
        let notchRightX = rect.midX + notchHalfWidth

        // Shallow "dimple" depth — gentle, not a deep recess (D-02: exact value is on-device
        // discretion). Clamped so a tiny rect can never invert the dip.
        let desiredNotchDepth: CGFloat = 8
        let notchDepth = min(desiredNotchDepth, rect.height / 2)

        // Each side of the dip is a smooth S-curve (two quad curves, sharing a tangent at their
        // midpoint) so the transition reads as continuous rather than a hard corner: flush-flat
        // in, floor-flat out. `transitionRadius` is the horizontal span each half of the S
        // consumes; clamped so the flat notch floor can never invert even for a narrow notch.
        let transitionRadius = min(notchDepth, notchHalfWidth / 4)
        let rightMidX = notchRightX - transitionRadius
        let leftMidX = notchLeftX + transitionRadius
        let floorRightX = notchRightX - 2 * transitionRadius
        let floorLeftX = notchLeftX + 2 * transitionRadius
        let floorY = rect.minY + notchDepth
        let midY = rect.minY + notchDepth / 2

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

        // Top edge: flush run (right side) → smooth dip down → flat notch floor → smooth dip
        // back up → flush run (left side), closing back at the path's start point.
        p.addLine(to: CGPoint(x: notchRightX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rightMidX, y: midY), control: CGPoint(x: rightMidX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: floorRightX, y: floorY), control: CGPoint(x: rightMidX, y: floorY))
        p.addLine(to: CGPoint(x: floorLeftX, y: floorY))
        p.addQuadCurve(to: CGPoint(x: leftMidX, y: midY), control: CGPoint(x: leftMidX, y: floorY))
        p.addQuadCurve(to: CGPoint(x: notchLeftX, y: rect.minY), control: CGPoint(x: leftMidX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        return p
    }
}
