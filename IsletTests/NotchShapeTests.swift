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

    // SHAPE-01 (v1.5, Phase 29) — FINAL, user-confirmed design: the wide sides of the top edge
    // stay FLUSH with `rect.minY` exactly like the pre-Phase-29 shape, and only a narrow band
    // centered on `rect.midX` (matching the physical camera footprint) dips DOWN by a shallow
    // amount, with smooth quad-curve transitions. This replaces two reverted detours (a
    // monotonic narrow-to-wide funnel, then a "shoulder bulge" that read as "eine Kugel"/a
    // ball-knob on-device) that both put the geometry at the OUTER corners instead of the
    // CENTER — see 29-CONTEXT.md's "Post-D-01/D-05 implementation detour and final
    // confirmation" section for the full history.
    //
    // Tests below use wingsShape's real, tightest call-site combo (topCornerRadius: 6,
    // bottomCornerRadius: 6, topFlareWidth: 179) at wingsShape's real 290x32 size.
    private let wingsRect = CGRect(x: 0, y: 0, width: 290, height: 32)
    private let wingsTopCornerRadius: CGFloat = 6
    private let wingsBottomCornerRadius: CGFloat = 6
    private let wingsFlareWidth: CGFloat = 179

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

    func testWideSidesStayFlushWithTheTopEdge() {
        // The defining structural change vs. both reverted detours: near the OUTER corners
        // (away from the centered camera notch), the top edge must be flush at rect.minY --
        // exactly like the unflared shape. This is the "wide sides never move" invariant.
        let flaredPath = NotchShape(topCornerRadius: wingsTopCornerRadius, bottomCornerRadius: wingsBottomCornerRadius, topFlareWidth: wingsFlareWidth)
            .path(in: wingsRect).cgPath
        let justInsideLeftWall = CGPoint(x: wingsRect.minX + wingsTopCornerRadius + 1, y: wingsRect.minY + 0.1)
        let justInsideRightWall = CGPoint(x: wingsRect.maxX - wingsTopCornerRadius - 1, y: wingsRect.minY + 0.1)
        XCTAssertTrue(flaredPath.contains(justInsideLeftWall, using: .winding),
                      "Just past the left corner curve, at the very top edge, must be filled -- the wide side is flush, unchanged from the unflared shape.")
        XCTAssertTrue(flaredPath.contains(justInsideRightWall, using: .winding),
                      "Just before the right corner curve, at the very top edge, must be filled -- the wide side is flush, unchanged from the unflared shape.")
    }

    func testCenteredNotchDipsBelowTheTopEdge() {
        // The defining new geometry: directly under rect.midX (the physical camera), the shape
        // must NOT be filled at rect.minY (a recess exists there) but MUST be filled a little
        // further down (the notch floor), proving the dip is real and centered.
        let flaredPath = NotchShape(topCornerRadius: wingsTopCornerRadius, bottomCornerRadius: wingsBottomCornerRadius, topFlareWidth: wingsFlareWidth)
            .path(in: wingsRect).cgPath
        let centerAtTopEdge = CGPoint(x: wingsRect.midX, y: wingsRect.minY + 0.1)
        let centerAtNotchFloor = CGPoint(x: wingsRect.midX, y: wingsRect.minY + 7.9)
        XCTAssertFalse(flaredPath.contains(centerAtTopEdge, using: .winding),
                       "Directly under the camera, at the true top edge, must NOT be filled -- the notch has receded here.")
        XCTAssertTrue(flaredPath.contains(centerAtNotchFloor, using: .winding),
                      "Directly under the camera, at the notch's own (shallow) floor depth, must be filled.")
    }

    func testFlaredPathBoundingBoxNeverExceedsTheRect() {
        // The centered dip is a pure inward recess -- it must never widen the shape beyond the
        // rect it was given, no horizontal overflow, no render-canvas widening needed upstream.
        let bounds = NotchShape(topCornerRadius: wingsTopCornerRadius, bottomCornerRadius: wingsBottomCornerRadius, topFlareWidth: wingsFlareWidth)
            .path(in: wingsRect).cgPath.boundingBox
        XCTAssertGreaterThanOrEqual(bounds.minX, wingsRect.minX - 0.01,
                                    "The flared path must never extend left of the rect it was given.")
        XCTAssertLessThanOrEqual(bounds.maxX, wingsRect.maxX + 0.01,
                                 "The flared path must never extend right of the rect it was given.")
    }

    func testFlaredPathReachesTheRectsFullWidth() {
        // The flush wide sides must still reach the rect's own left/right edges (via the
        // unmodified topCornerRadius corner curves) -- the dip only affects the center.
        let bounds = NotchShape(topCornerRadius: wingsTopCornerRadius, bottomCornerRadius: wingsBottomCornerRadius, topFlareWidth: wingsFlareWidth)
            .path(in: wingsRect).cgPath.boundingBox
        XCTAssertEqual(bounds.minX, wingsRect.minX, accuracy: 0.5,
                       "The flush left side must still reach the rect's own left edge.")
        XCTAssertEqual(bounds.maxX, wingsRect.maxX, accuracy: 0.5,
                       "The flush right side must still reach the rect's own right edge.")
    }

    func testFlaredPathStaysClosedAndNonEmpty() {
        // Mirrors testCustomRadiiProduceAClosedNonEmptyPath, with a non-zero topFlareWidth.
        let path = NotchShape(topCornerRadius: wingsTopCornerRadius, bottomCornerRadius: wingsBottomCornerRadius, topFlareWidth: wingsFlareWidth).path(in: wingsRect)
        let cgBounds = path.cgPath.boundingBox
        XCTAssertFalse(path.cgPath.isEmpty, "Flared closed pill path must be non-empty.")
        XCTAssertGreaterThan(cgBounds.width, 0, "The flared closed path needs a positive-width bounding box.")
        XCTAssertGreaterThan(cgBounds.height, 0, "The flared closed path needs a positive-height bounding box.")
    }

    func testFlaredPathHasNoNaNOrDegenerateSegments() {
        // Permanent regression guard for genuine path-construction defects (NaN/infinite
        // coordinates, or a degenerate zero-length line segment). Enumerates every CGPath
        // element directly rather than trusting a manual code trace, so a future geometry
        // change that silently introduces a NaN or a zero-length segment fails a test instead
        // of only showing up as an on-device visual gap.
        let path = NotchShape(topCornerRadius: wingsTopCornerRadius, bottomCornerRadius: wingsBottomCornerRadius, topFlareWidth: wingsFlareWidth)
            .path(in: wingsRect).cgPath
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

    func testOuterCornersAreUnchangedFromTheUnflaredShape() {
        // The final design leaves the outer topCornerRadius corner-cut completely untouched --
        // unlike both reverted detours, it is never shifted down. Its bounding box (by
        // comparison to the unflared shape's own corner region) must match, proving the corner
        // geometry is byte-identical regardless of topFlareWidth.
        let flaredCorner = NotchShape(topCornerRadius: wingsTopCornerRadius, bottomCornerRadius: wingsBottomCornerRadius, topFlareWidth: wingsFlareWidth)
            .path(in: wingsRect).cgPath
        let unflaredCorner = NotchShape(topCornerRadius: wingsTopCornerRadius, bottomCornerRadius: wingsBottomCornerRadius, topFlareWidth: 0)
            .path(in: wingsRect).cgPath
        let cornerNotchMidpoint = CGPoint(x: wingsRect.maxX - wingsTopCornerRadius / 2,
                                          y: wingsRect.minY + wingsTopCornerRadius / 2)
        XCTAssertEqual(flaredCorner.contains(cornerNotchMidpoint, using: .winding),
                       unflaredCorner.contains(cornerNotchMidpoint, using: .winding),
                       "The outer corner-cut's own fillet region must render identically with and without the centered notch -- the outer corners never move.")
        let justInsideTheWall = CGPoint(x: wingsRect.maxX - wingsTopCornerRadius - 5,
                                        y: wingsRect.minY + wingsTopCornerRadius / 2)
        XCTAssertTrue(flaredCorner.contains(justInsideTheWall, using: .winding),
                      "Just inside the wall at the corner's own (unshifted) height, the fill must still be present.")
    }

    func testFlaredPathHasNoSelfOverlap() {
        // A self-intersecting or self-overlapping path produces DIFFERENT results under the
        // winding vs even-odd fill rules at some points. Scanning a grid across the whole
        // flared bounding box and requiring the two rules to always agree is a cheap, general
        // proxy for "this is a simple, non-self-crossing polygon."
        let path = NotchShape(topCornerRadius: wingsTopCornerRadius, bottomCornerRadius: wingsBottomCornerRadius, topFlareWidth: wingsFlareWidth)
            .path(in: wingsRect).cgPath
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
