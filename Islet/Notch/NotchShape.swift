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

        // Flared path (round 7 — shoulder bulge gets its own vertical depth). `bulge` is how
        // far past rect.minX/rect.maxX the shoulder swings out before curving back in.
        //
        // Round 6's single cubic curve crammed BOTH the outward swing (~14pt) AND the
        // topCornerRadius corner-cut (6pt radius) into just 6pt of vertical room. Sampling the
        // actual rendered geometry (not just "build succeeded") proved that curve's two
        // control points, both pulled outward within that tiny span, made the corner-cut notch
        // get re-filled by the bulge's own path, erasing the rounding entirely (same failure
        // class as round 4/`8f69742`) while ALSO capping the visible bulge far short of `bulge`
        // (~6.8pt actual vs 14pt requested) since there wasn't room for the curve to swing out
        // properly. `bulgeDepth` below decouples the two: the bulge gets its own dedicated span
        // to swing out and back BEFORE the (byte-identical, just y-shifted) topCornerRadius
        // corner-cut curve begins. Geometrically verified (not just built) via a throwaway
        // CGPath.contains scan across the tightest real call site (wingsShape's 290x32 rect) —
        // confirms: zero winding/evenOdd disagreements (a simple, non-self-overlapping path),
        // the corner-cut notch surviving intact at its new (shifted) location, and the bulge's
        // own boundary tracing one smooth outward hump reaching the full `bulge` extent.
        let bulge = topFlareWidth
        // ROUND 9 (stroke-diagnostic on-device UAT 2026-07-13) — the ACTUAL defect the bright
        // green stroke outline exposed: a CGPath element-by-element inspection (moveTo/lineTo/
        // quadCurve, checked for NaN/infinite coordinates and degenerate zero-length segments)
        // proves this path was ALWAYS a valid, continuous, closed 13-element contour — the
        // stroke gap was never a path-construction bug. The real defect lived one layer up, in
        // NotchPillView's `blobShape`/`wingsShape`: they gave this Shape a `.frame()` no wider
        // than the LOGICAL pill width, but the shoulder bulge below deliberately paints
        // `bulge` points PAST that width on each side (`rect.maxX + bulge`, `rect.minX - bulge`)
        // — those pixels have no backing store in a frame that size, so the fill AND the
        // diagnostic stroke silently never drew there, while the corner-cut curve just inside
        // the wall (well within frame bounds) rendered fine — exactly "sides fine, gap at top."
        // `blobShape`/`wingsShape` now give this shape a render canvas widened by `2 * bulge`
        // (see that file's own doc comment), so `rect` here is that WIDER canvas, not the
        // logical pill rect. `r` below recovers the logical pill rect by insetting the wide
        // canvas by `bulge` on each side — every wall/corner-radius computation stays the exact
        // pre-existing math (same shape, same width), while the bulge/apex points reach back out
        // to the canvas's own true edges (`rect.minX`/`rect.maxX`) — now WITHIN the render target.
        let r = rect.insetBy(dx: bulge, dy: 0)
        // ROUND 8 (post-diagnostic pacing fix, on-device UAT 2026-07-13): the diagnostic round
        // confirmed the mechanism itself (bulge + red fill both rendered exactly as expected on
        // real hardware). The remaining complaint was PACING, not visibility: a single small
        // hardcoded `bulgeDepth` (15, before the diagnostic bumped it to 18) had to serve BOTH
        // the tall `blobShape()` presentations (Home/Tray/Calendar/Weather, 240pt+ of vertical
        // room) AND the tight `wingsShape()` strip (290x32, only 32pt total) — sized to just barely
        // fit the tightest case, it made every presentation's taper read as an abrupt "poof out,
        // snap back" even where there was plenty of room for a slow, graceful curve. `bulgeDepth`
        // is now ADAPTIVE per-rect: a generous target on tall presentations, safely clamped so it
        // never eats into (or inverts) the straight wall beneath it on tight ones. The 0.7 reserves
        // 30% of the rect's own height (plus both corner radii) as an untouchable wall floor —
        // never `bulgeDepth + topCornerRadius + bottomCornerRadius > rect.height`.
        let desiredBulgeDepth: CGFloat = 45
        let bulgeDepth = min(desiredBulgeDepth, max(0, rect.height * 0.7 - topCornerRadius - bottomCornerRadius))

        // The apex (the outward peak) sits at 30% of `bulgeDepth`, not the midpoint. On-device
        // feedback specifically named the RETURN leg (bulge -> back to normal width) as the
        // abrupt "snap" ("geht raus, aber dann sofort wieder zurück, nicht der langsame Übergang").
        // Moving the apex earlier gives the return leg ~70% of the available depth to resolve
        // gradually (the graceful "wine glass neck" taper), while the initial outward swing stays
        // comparatively quick — matching the reported shape exactly (quick out, slow back) rather
        // than splitting the depth evenly between both legs.
        let apexFraction: CGFloat = 0.3

        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY)) // FULL-WIDTH flush top run — never recessed

        // RIGHT shoulder: two chained quad curves sharing an on-curve apex at the outward peak
        // (r.maxX + bulge, r.minY + bulgeDepth * apexFraction) swing the edge out and back
        // to touch x == r.maxX again at y == r.minY + bulgeDepth — then the topCornerRadius
        // corner-cut curve continues from there, an EXACT copy of the unflared branch's own
        // corner math above, just shifted down by bulgeDepth (its shape, and therefore the
        // rounding it cuts, is untouched). Note r.maxX + bulge == rect.maxX exactly (the
        // canvas's own true edge) — the peak reaches the widened render canvas, never past it.
        let rightApex = CGPoint(x: r.maxX + bulge, y: r.minY + bulgeDepth * apexFraction)
        p.addQuadCurve(to: rightApex, control: CGPoint(x: r.maxX + bulge, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY + bulgeDepth),
                       control: CGPoint(x: r.maxX + bulge, y: r.minY + bulgeDepth))
        p.addQuadCurve(to: CGPoint(x: r.maxX - topCornerRadius, y: r.minY + bulgeDepth + topCornerRadius),
                       control: CGPoint(x: r.maxX - topCornerRadius, y: r.minY + bulgeDepth))

        // Downstream math from here is 100% the existing, unmodified topCornerRadius/
        // bottomCornerRadius corner + wall geometry (identical to the topFlareWidth == 0 branch
        // above, just re-entered after the bulge+corner-cut instead of after a plain quad curve
        // — only the wall's start point moved down by bulgeDepth, its end/shape is untouched).
        p.addLine(to: CGPoint(x: r.maxX - topCornerRadius, y: r.maxY - bottomCornerRadius))
        p.addQuadCurve(to: CGPoint(x: r.maxX - topCornerRadius - bottomCornerRadius, y: r.maxY),
                       control: CGPoint(x: r.maxX - topCornerRadius, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + topCornerRadius + bottomCornerRadius, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.minX + topCornerRadius, y: r.maxY - bottomCornerRadius),
                       control: CGPoint(x: r.minX + topCornerRadius, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + topCornerRadius, y: r.minY + bulgeDepth + topCornerRadius))

        // LEFT shoulder — exact mirror of the right, traversed in reverse (wall -> corner-cut
        // -> bulge -> close at the flush top's start).
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.minY + bulgeDepth),
                       control: CGPoint(x: r.minX + topCornerRadius, y: r.minY + bulgeDepth))
        let leftApex = CGPoint(x: r.minX - bulge, y: r.minY + bulgeDepth * apexFraction)
        p.addQuadCurve(to: leftApex, control: CGPoint(x: r.minX - bulge, y: r.minY + bulgeDepth))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.minY), control: CGPoint(x: r.minX - bulge, y: r.minY))
        return p
    }
}
