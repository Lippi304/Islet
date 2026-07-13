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

    // SHAPE-01 (v1.5, Phase 29) — D-01/D-05 final design: a fixed NARROW top band, sweeping
    // monotonically outward (never reversing) down to the shape's own full rect width, then
    // merging into the unmodified topCornerRadius corner transition. This replaces an earlier
    // "shoulder bulge" design (swing-out-then-back past the rect) that read as "eine Kugel"/a
    // ball-knob on-device — see 29-CONTEXT.md's "Post-D-01/D-05 implementation detour" section.
    //
    // Tests below use wingsShape's real, tightest call-site combo (topCornerRadius: 6,
    // bottomCornerRadius: 6, topFlareWidth: 179) at wingsShape's real 290x32 size, since that is
    // the site the flareDepth safety clamp (NotchShape.swift) is specifically checked against.
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

    func testFlatTopRunIsNarrowBandNotFullWidth() {
        // The defining structural change vs. the earlier shoulder-bulge design: the flush run at
        // rect.minY spans only the narrow band, NOT the full rect width. Just outside the band on
        // either side, at y ≈ rect.minY, the path must NOT be filled yet (the sweep hasn't widened
        // out that far at the very top).
        let flaredPath = NotchShape(topCornerRadius: wingsTopCornerRadius, bottomCornerRadius: wingsBottomCornerRadius, topFlareWidth: wingsFlareWidth)
            .path(in: wingsRect).cgPath
        let bandHalfWidth = wingsFlareWidth / 2
        let justInsideBand = CGPoint(x: wingsRect.midX - bandHalfWidth + 1, y: wingsRect.minY + 0.1)
        let justOutsideBand = CGPoint(x: wingsRect.minX + 1, y: wingsRect.minY + 0.1)
        XCTAssertTrue(flaredPath.contains(justInsideBand, using: .winding),
                      "Just inside the narrow band, at the very top edge, must be filled.")
        XCTAssertFalse(flaredPath.contains(justOutsideBand, using: .winding),
                       "Near the rect's own left edge, at the very top, must NOT be filled -- the top run is a narrow band, not full width (unlike the reverted shoulder-bulge design).")
    }

    func testFlaredPathBoundingBoxNeverExceedsTheRect() {
        // Structural change from the shoulder-bulge design (which deliberately bulged PAST
        // rect.minX/rect.maxX): the monotonic sweep design never widens beyond the rect it was
        // given -- no horizontal overflow, no render-canvas widening needed anywhere upstream.
        let bounds = NotchShape(topCornerRadius: wingsTopCornerRadius, bottomCornerRadius: wingsBottomCornerRadius, topFlareWidth: wingsFlareWidth)
            .path(in: wingsRect).cgPath.boundingBox
        XCTAssertGreaterThanOrEqual(bounds.minX, wingsRect.minX - 0.01,
                                    "The flared path must never extend left of the rect it was given.")
        XCTAssertLessThanOrEqual(bounds.maxX, wingsRect.maxX + 0.01,
                                 "The flared path must never extend right of the rect it was given.")
    }

    func testFlaredPathReachesTheRectsFullWidth() {
        // The sweep must actually converge to the rect's own full width lower down (not stop
        // short) -- confirms the funnel completes, it doesn't just stay narrow forever.
        let bounds = NotchShape(topCornerRadius: wingsTopCornerRadius, bottomCornerRadius: wingsBottomCornerRadius, topFlareWidth: wingsFlareWidth)
            .path(in: wingsRect).cgPath.boundingBox
        XCTAssertEqual(bounds.minX, wingsRect.minX, accuracy: 0.5,
                       "The sweep must reach the rect's own left edge.")
        XCTAssertEqual(bounds.maxX, wingsRect.maxX, accuracy: 0.5,
                       "The sweep must reach the rect's own right edge.")
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

    // The flareDepth safety clamp mirrors NotchShape.swift's `path(in:)` formula exactly, so
    // this file's expectations never go stale if that formula's constants change.
    private func expectedFlareDepth(rectHeight: CGFloat, topCornerRadius: CGFloat, bottomCornerRadius: CGFloat) -> CGFloat {
        let desiredFlareDepth: CGFloat = 18
        return min(desiredFlareDepth, max(0, rectHeight - topCornerRadius - bottomCornerRadius - 4))
    }

    func testFlaredPathCornerRoundingSurvivesTheSweep() {
        // The topCornerRadius corner-cut, shifted down by flareDepth, must still carve a real
        // fillet -- not get erased or overlapped by the sweep above it (the exact failure class
        // an earlier round of this design hit before flareDepth existed as its own dedicated span).
        let flareDepth = expectedFlareDepth(rectHeight: wingsRect.height, topCornerRadius: wingsTopCornerRadius, bottomCornerRadius: wingsBottomCornerRadius)
        let flaredPath = NotchShape(topCornerRadius: wingsTopCornerRadius, bottomCornerRadius: wingsBottomCornerRadius, topFlareWidth: wingsFlareWidth)
            .path(in: wingsRect).cgPath
        let cornerNotchMidpoint = CGPoint(x: wingsRect.maxX - wingsTopCornerRadius / 2,
                                          y: wingsRect.minY + flareDepth + wingsTopCornerRadius / 2)
        XCTAssertFalse(flaredPath.contains(cornerNotchMidpoint, using: .winding),
                       "The corner-cut's own notch (shifted down by flareDepth) must stay excluded from the fill -- proving the rounding survives the sweep.")
        // And just inside the wall, at the same height, must still be filled -- confirms this
        // is a real diagonal fillet, not an accidentally-empty shape.
        let justInsideTheWall = CGPoint(x: wingsRect.maxX - wingsTopCornerRadius - 5,
                                        y: wingsRect.minY + flareDepth + wingsTopCornerRadius / 2)
        XCTAssertTrue(flaredPath.contains(justInsideTheWall, using: .winding),
                      "Just inside the wall at the same height, the fill must still be present.")
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
