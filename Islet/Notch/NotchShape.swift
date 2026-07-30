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
    func path(in rect: CGRect) -> Path {
        // 71-REVIEW CR-01 gap closure — clamp both radii HERE, the one path builder every
        // caller (blobShape/wingsShape/mediaWingsOrToast/resumePreviewWings) routes through,
        // rather than at each call site. Unclamped, a radius pair whose sum exceeds rect.height
        // (vertical self-intersection — the corner-radius-nudge freeze this phase's on-device
        // UAT hit) or whose doubled sum exceeds rect.width (horizontal self-intersection,
        // reachable via the sibling leading/trailing/margin Wing Tuner nudges, which have no
        // floor) produces a path that folds back on itself. Scaling both radii by the same
        // factor (rather than clamping the sum by shrinking just one) preserves the top:bottom
        // ratio the shape is designed around.
        let top = max(topCornerRadius, 0)
        let bottom = max(bottomCornerRadius, 0)
        let sum = top + bottom
        let maxSum = max(min(rect.height, rect.width / 2), 0)
        let scale = sum > 0 ? min(maxSum / sum, 1) : 1
        let topR = top * scale
        let bottomR = bottom * scale
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.minX + topR, y: rect.minY + topR),
                       control: CGPoint(x: rect.minX + topR, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + topR, y: rect.maxY - bottomR))
        p.addQuadCurve(to: CGPoint(x: rect.minX + topR + bottomR, y: rect.maxY),
                       control: CGPoint(x: rect.minX + topR, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - topR - bottomR, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - topR, y: rect.maxY - bottomR),
                       control: CGPoint(x: rect.maxX - topR, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - topR, y: rect.minY + topR))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY),
                       control: CGPoint(x: rect.maxX - topR, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        return p
    }
}
