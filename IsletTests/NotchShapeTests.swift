import XCTest
import SwiftUI
@testable import Islet

// ISL-01: the NotchShape draws a real, closed pill path that stays WITHIN the rect
// it is asked to fill (so the pill never spills outside the notch frame the panel
// gives it). The pixel-perfect hug over the physical notch is a MANUAL check in
// Plan 03 — here we only assert structural correctness without a live window.
final class NotchShapeTests: XCTestCase {

    private let rect = CGRect(x: 0, y: 0, width: 200, height: 32)

    func testPathIsNonEmpty() {
        let path = NotchShape().path(in: rect)
        XCTAssertFalse(path.isEmpty, "NotchShape must produce a non-empty path.")
        XCTAssertFalse(path.cgPath.isEmpty, "The backing CGPath must be non-empty.")
    }

    func testPathStaysWithinItsRect() {
        let bounds = NotchShape().path(in: rect).boundingRect
        XCTAssertLessThanOrEqual(bounds.width, rect.width,
                                 "The path must not be wider than the rect it fills.")
        XCTAssertLessThanOrEqual(bounds.height, rect.height,
                                 "The path must not be taller than the rect it fills.")
        XCTAssertGreaterThanOrEqual(bounds.minX, rect.minX - 0.0001,
                                    "The path must not extend left of the rect.")
        XCTAssertGreaterThanOrEqual(bounds.minY, rect.minY - 0.0001,
                                    "The path must not extend above the rect.")
    }

    func testCustomRadiiProduceAClosedNonEmptyPath() {
        // The default radii are top: 6 / bottom: 14 (ISL-01); a closed pill path
        // must have a non-empty bounding box for those radii.
        let path = NotchShape(topCornerRadius: 6, bottomCornerRadius: 14).path(in: rect)
        let cgBounds = path.cgPath.boundingBox
        XCTAssertFalse(path.cgPath.isEmpty, "Closed pill path must be non-empty.")
        XCTAssertGreaterThan(cgBounds.width, 0, "The closed path needs a positive-width bounding box.")
        XCTAssertGreaterThan(cgBounds.height, 0, "The closed path needs a positive-height bounding box.")
    }

    // SHAPE-01 (v1.5, Phase 29): topFlareWidth default + path geometry.
    //
    // D-01/D-05 REVISED AGAIN 2026-07-13 (round 6, on-device UAT): the round-5 concave sweep
    // pulled the top edge away from the true screen/notch edge outside its narrow band, which
    // read as "not at the edge at all" on a real device. The flare is now a curved outward
    // "shoulder" bulge that starts only AFTER a full-width flush top run (matching every other
    // round and the pre-Phase-29 shape) and merges back into the existing topCornerRadius
    // transition's own unshifted endpoint. `topFlareWidth` is once again the fixed OUTWARD
    // MARGIN (how far past rect.minX/rect.maxX the shoulder bulges) — see NotchShape.swift's
    // doc comment.
    //
    // ROUND 7 (on-device UAT again): round 6's cubic curve crammed the bulge AND the
    // topCornerRadius corner-cut into the same 6pt of vertical room, which erased the corner
    // rounding (same failure class as round 4) and rendered as a perfectly square corner with
    // no visible bulge either. `bulgeDepth` (NotchShape.swift) now gives the bulge its own
    // vertical span, so the corner-cut curve's endpoint is SHIFTED DOWN by `bulgeDepth` instead
    // of sitting at `rect.minY + topCornerRadius` — the tests below use `topCornerRadius: 6,
    // bottomCornerRadius: 6` (wingsShape's real, tightest call-site combo, at wingsShape's real
    // 290x32 size) instead of round 6's `bottomCornerRadius: 14` at 200x32, which was never an
    // actual flared call site and is too short to fit `bulgeDepth` (15) + `topCornerRadius` (6)
    // + `bottomCornerRadius` (14) without inverting the wall.

    func testTopFlareWidthDefaultsToZero() {
        XCTAssertEqual(NotchShape().topFlareWidth, 0,
                        "topFlareWidth must default to 0, matching topCornerRadius/bottomCornerRadius's existing default-value pattern.")
    }

    func testTopFlareWidthZeroIsIdenticalToOmittedDefault() {
        // Explicit topFlareWidth: 0 must equal today's exact shape (D-03/Success Criterion #2):
        // collapsedIsland and mediaWingsOrToast never pass topFlareWidth, so their omitted-default
        // path must be byte-identical (by bounding box) to an explicit zero.
        let explicitZero = NotchShape(topCornerRadius: 6, bottomCornerRadius: 14, topFlareWidth: 0)
            .path(in: rect).cgPath.boundingBox
        let omittedDefault = NotchShape(topCornerRadius: 6, bottomCornerRadius: 14)
            .path(in: rect).cgPath.boundingBox
        XCTAssertEqual(explicitZero, omittedDefault,
                       "topFlareWidth: 0 must produce an identical bounding box to omitting the argument entirely.")
    }

    // Round 7's tests use wingsShape's REAL call-site combo (topCornerRadius: 6,
    // bottomCornerRadius: 6, topFlareWidth: 14) at wingsShape's REAL 290x32 size -- the
    // tightest actual flared call site, and the one `bulgeDepth`'s safety margin was
    // specifically checked against (NotchShape.swift's doc comment).
    private let wingsRect = CGRect(x: 0, y: 0, width: 290, height: 32)
    private let wingsTopCornerRadius: CGFloat = 6
    private let wingsBottomCornerRadius: CGFloat = 6
    private let wingsFlareWidth: CGFloat = 14

    // ROUND 9 (stroke-diagnostic on-device UAT 2026-07-13) — the ACTUAL bug this round fixed:
    // NotchPillView's blobShape/wingsShape now give NotchShape a render CANVAS widened by
    // `2 * topFlareWidth` (not the logical pill width), because the shoulder bulge deliberately
    // paints `topFlareWidth` points past the logical pill edges (NotchShape.swift's own round-9
    // comment) — a `.frame()` no wider than the logical width has no backing pixels there, which
    // is why the bulge/flush-top region silently never rendered (every earlier "flat, no bulge"
    // report) despite the path itself always being a valid, continuous, closed contour (proved
    // via CGPath element-by-element inspection, see the two new tests below). `path(in:)` now
    // insets the given rect by `topFlareWidth` internally to recover the logical pill rect, so
    // every flared-branch test below must call `.path(in:)` with the WIDENED canvas rect,
    // matching production — `wingsCanvasRect` expands `wingsRect` by exactly that margin, so
    // `path(in:)`'s internal inset lands back on `wingsRect` unchanged and every existing
    // point/bounds expectation below (still expressed in terms of `wingsRect`) stays correct.
    private var wingsCanvasRect: CGRect {
        wingsRect.insetBy(dx: -wingsFlareWidth, dy: 0)
    }

    func testNonZeroTopFlareWidthKeepsTheTopEdgeFlushAcrossFullWidth() {
        // The hard regression a prior round fixed: the flat top run must span the shape's FULL
        // width, flush at rect.minY -- never recessed downward the way the round-5 concave sweep
        // was outside its narrow band. Points near both top corners, just below the very top
        // edge, must already be filled at full width.
        let flaredPath = NotchShape(topCornerRadius: wingsTopCornerRadius, bottomCornerRadius: wingsBottomCornerRadius, topFlareWidth: wingsFlareWidth)
            .path(in: wingsCanvasRect).cgPath
        let nearLeftEdge = CGPoint(x: wingsRect.minX + 1, y: wingsRect.minY + 0.5)
        let nearRightEdge = CGPoint(x: wingsRect.maxX - 1, y: wingsRect.minY + 0.5)
        XCTAssertTrue(flaredPath.contains(nearLeftEdge, using: .winding),
                      "The top edge must be flush (filled) near the left corner, full width -- not recessed downward.")
        XCTAssertTrue(flaredPath.contains(nearRightEdge, using: .winding),
                      "The top edge must be flush (filled) near the right corner, full width -- not recessed downward.")
    }

    func testFlaredPathTopBoundsStaysAtRectMinY() {
        // The bounding box's own top must sit exactly at rect.minY -- proving no part of the top
        // edge is pulled down/away from the true screen edge, the exact user-reported bug a
        // prior round fixed ("Gar nicht mehr am Rand dran").
        let bounds = NotchShape(topCornerRadius: wingsTopCornerRadius, bottomCornerRadius: wingsBottomCornerRadius, topFlareWidth: wingsFlareWidth)
            .path(in: wingsCanvasRect).cgPath.boundingBox
        XCTAssertEqual(bounds.minY, wingsRect.minY, accuracy: 0.01,
                       "The flared path's topmost point must stay at rect.minY -- flush with the true screen edge.")
    }

    func testNonZeroTopFlareWidthBulgesPastTheRectWidth() {
        // Unlike the round-5 concave sweep (which stayed within the rect), the shoulder bulge
        // genuinely extends past rect.minX/rect.maxX by roughly the full `topFlareWidth` -- this
        // is the visible "flare" itself, and the exact regression round 6's cramped 6pt-tall
        // cubic curve failed (it only reached ~half the requested extent).
        let bounds = NotchShape(topCornerRadius: wingsTopCornerRadius, bottomCornerRadius: wingsBottomCornerRadius, topFlareWidth: wingsFlareWidth)
            .path(in: wingsCanvasRect).cgPath.boundingBox
        XCTAssertLessThan(bounds.minX, wingsRect.minX,
                          "The shoulder bulge must extend past the rect's left edge.")
        XCTAssertGreaterThan(bounds.maxX, wingsRect.maxX,
                             "The shoulder bulge must extend past the rect's right edge.")
        XCTAssertEqual(bounds.minX, wingsRect.minX - wingsFlareWidth, accuracy: 0.5,
                       "The bulge must reach roughly the full topFlareWidth extent on the left, not collapse to a fraction of it.")
        XCTAssertEqual(bounds.maxX, wingsRect.maxX + wingsFlareWidth, accuracy: 0.5,
                       "The bulge must reach roughly the full topFlareWidth extent on the right, not collapse to a fraction of it.")
    }

    func testFlaredPathStaysClosedAndNonEmpty() {
        // Mirrors testCustomRadiiProduceAClosedNonEmptyPath, with a non-zero topFlareWidth.
        let path = NotchShape(topCornerRadius: wingsTopCornerRadius, bottomCornerRadius: wingsBottomCornerRadius, topFlareWidth: wingsFlareWidth).path(in: wingsCanvasRect)
        let cgBounds = path.cgPath.boundingBox
        XCTAssertFalse(path.cgPath.isEmpty, "Flared closed pill path must be non-empty.")
        XCTAssertGreaterThan(cgBounds.width, 0, "The flared closed path needs a positive-width bounding box.")
        XCTAssertGreaterThan(cgBounds.height, 0, "The flared closed path needs a positive-height bounding box.")
    }

    func testFlaredPathStaysWithinTheCanvasItIsGiven() {
        // ROUND 9 REGRESSION TEST — the actual bug this round fixed. Before this fix,
        // NotchPillView gave the shape a `.frame()` sized to only the LOGICAL pill width
        // (wingsRect), while the shoulder bulge painted `topFlareWidth` points past it on each
        // side -- those pixels have no backing store in a frame that size, so the bulge/
        // flush-top region silently never rendered (the fill) and showed a stroke gap (the
        // diagnostic overlay), even though the path itself was always a valid, continuous,
        // closed contour (see the CGPath inspection test below). This is the direct contract
        // check: given the WIDENED canvas NotchPillView now actually supplies, the path's own
        // bounding box must fit entirely within it -- no coordinate may fall outside the render
        // target, on either edge.
        let bounds = NotchShape(topCornerRadius: wingsTopCornerRadius, bottomCornerRadius: wingsBottomCornerRadius, topFlareWidth: wingsFlareWidth)
            .path(in: wingsCanvasRect).cgPath.boundingBox
        XCTAssertGreaterThanOrEqual(bounds.minX, wingsCanvasRect.minX - 0.01,
                                    "The flared path must not extend left of the canvas it was actually given -- those pixels would silently never draw (the round-9 bug).")
        XCTAssertLessThanOrEqual(bounds.maxX, wingsCanvasRect.maxX + 0.01,
                                 "The flared path must not extend right of the canvas it was actually given -- those pixels would silently never draw (the round-9 bug).")
    }

    func testFlaredPathHasNoNaNOrDegenerateSegments() {
        // Permanent regression guard for genuine path-construction defects (NaN/infinite
        // coordinates from an unexpected division or min/max combination, or a degenerate
        // zero-length line segment) -- the class of bug the round-9 stroke diagnostic was
        // originally suspected of exposing. Enumerates every CGPath element directly (the same
        // check that was run by hand during round-9 triage) rather than trusting a manual code
        // trace, so a future geometry change that silently introduces a NaN or a zero-length
        // segment fails a test instead of only showing up as an on-device visual gap.
        let path = NotchShape(topCornerRadius: wingsTopCornerRadius, bottomCornerRadius: wingsBottomCornerRadius, topFlareWidth: wingsFlareWidth)
            .path(in: wingsCanvasRect).cgPath
        var lastPoint: CGPoint?
        var elementCount = 0
        path.applyWithBlock { elementPtr in
            let element = elementPtr.pointee
            elementCount += 1
            func assertFinite(_ points: [CGPoint]) {
                for point in points {
                    XCTAssertTrue(point.x.isFinite && point.y.isFinite,
                                   "Path element \(elementCount) has a non-finite coordinate: \(point).")
                }
            }
            switch element.type {
            case .moveToPoint:
                assertFinite([element.points[0]])
                lastPoint = element.points[0]
            case .addLineToPoint:
                let end = element.points[0]
                assertFinite([end])
                if let last = lastPoint {
                    XCTAssertNotEqual(last, end, "Path element \(elementCount) is a degenerate zero-length line at \(end).")
                }
                lastPoint = end
            case .addQuadCurveToPoint:
                assertFinite([element.points[0], element.points[1]])
                lastPoint = element.points[1]
            case .addCurveToPoint:
                assertFinite([element.points[0], element.points[1], element.points[2]])
                lastPoint = element.points[2]
            case .closeSubpath:
                break
            @unknown default:
                break
            }
        }
        XCTAssertGreaterThan(elementCount, 0, "The flared path must contain at least one drawing element.")
    }

    // ROUND 8 (post-diagnostic pacing fix) -- `bulgeDepth` is no longer a flat hardcoded
    // constant; it is adaptive per-rect (see NotchShape.swift's round-8 comment). This helper
    // mirrors that EXACT formula so this file's own tests never go stale again the way the
    // round-7 hardcoded `bulgeDepth: CGFloat = 15` did after the diagnostic round changed it --
    // must stay in sync with NotchShape.swift's `path(in:)`.
    private func expectedBulgeDepth(rectHeight: CGFloat, topCornerRadius: CGFloat, bottomCornerRadius: CGFloat) -> CGFloat {
        let desiredBulgeDepth: CGFloat = 45
        return min(desiredBulgeDepth, max(0, rectHeight * 0.7 - topCornerRadius - bottomCornerRadius))
    }

    func testFlaredPathCornerRoundingSurvivesTheBulge() {
        // ROUND 7 regression test: the actual bug this round fixes. Round 6's cubic curve
        // crammed the outward bulge AND the topCornerRadius corner-cut into the same 6pt of
        // vertical room, and the bulge's own path re-filled the corner-cut notch -- rendering as
        // a perfectly square corner with NO rounding at all (confirmed via a throwaway
        // CGPath.contains scan during diagnosis: round 6's geometry included a point at the
        // corner-cut's own halfway mark that a working rounded corner must EXCLUDE).
        //
        // With `bulgeDepth` giving the corner-cut its own shifted-down span, that same halfway
        // point -- shifted down by `bulgeDepth` -- must now be EXCLUDED (outside the fill),
        // proving the topCornerRadius rounding survives the bulge.
        let bulgeDepth = expectedBulgeDepth(rectHeight: wingsRect.height, topCornerRadius: wingsTopCornerRadius, bottomCornerRadius: wingsBottomCornerRadius)
        let flaredPath = NotchShape(topCornerRadius: wingsTopCornerRadius, bottomCornerRadius: wingsBottomCornerRadius, topFlareWidth: wingsFlareWidth)
            .path(in: wingsCanvasRect).cgPath
        let cornerNotchMidpoint = CGPoint(x: wingsRect.maxX - wingsTopCornerRadius / 2,
                                          y: wingsRect.minY + bulgeDepth + wingsTopCornerRadius / 2)
        XCTAssertFalse(flaredPath.contains(cornerNotchMidpoint, using: .winding),
                       "The corner-cut's own notch (shifted down by bulgeDepth) must stay excluded from the fill -- proving the rounding was not erased by the bulge (the exact round-6 regression).")
        // And just inside the wall, at the same height, must still be filled -- confirms this
        // is a real diagonal fillet, not an accidentally-empty shape.
        let justInsideTheWall = CGPoint(x: wingsRect.maxX - wingsTopCornerRadius - 5,
                                        y: wingsRect.minY + bulgeDepth + wingsTopCornerRadius / 2)
        XCTAssertTrue(flaredPath.contains(justInsideTheWall, using: .winding),
                      "Just inside the wall at the same height, the fill must still be present.")
    }

    func testFlaredPathHasNoSelfOverlap() {
        // ROUND 7 diagnosis tool, kept as a permanent regression guard: a self-intersecting or
        // self-overlapping path produces DIFFERENT results under the winding vs even-odd fill
        // rules at some points (nonzero winding can double-count an overlapped region while
        // even-odd cancels it back out). Scanning a grid across the whole flared bounding box
        // and requiring the two rules to always agree is a cheap, general proxy for "this is a
        // simple, non-self-crossing polygon" -- exactly what round 6's cramped cubic curve was
        // not.
        let path = NotchShape(topCornerRadius: wingsTopCornerRadius, bottomCornerRadius: wingsBottomCornerRadius, topFlareWidth: wingsFlareWidth)
            .path(in: wingsCanvasRect).cgPath
        let bounds = path.boundingBox
        var x = bounds.minX - 1
        while x <= bounds.maxX + 1 {
            var y = bounds.minY - 1
            while y <= bounds.maxY + 1 {
                let pt = CGPoint(x: x, y: y)
                XCTAssertEqual(path.contains(pt, using: .winding), path.contains(pt, using: .evenOdd),
                               "winding/evenOdd disagree at \(pt) -- the path self-overlaps somewhere.")
                y += 2
            }
            x += 2
        }
    }
}
