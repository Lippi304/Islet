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
    // D-01/D-05 REVISED 2026-07-13 during Task 3 on-device UAT: the flare is now a pronounced
    // CONCAVE sweep (narrow top-band -> full rect width -> unchanged topCornerRadius transition),
    // not the earlier straight-line outward widen. `topFlareWidth` is now the fixed NARROW
    // TOP-BAND WIDTH itself (not an added margin) — see NotchShape.swift's doc comment.

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

    func testNonZeroTopFlareWidthReachesTheFullRectWidthBelowTheBand() {
        // The concave sweep still converges on rect.minX/rect.maxX (the presentation's own full
        // width, unchanged) — only the TOP of the shape narrows, the overall silhouette does not
        // bulge past the rect the way the earlier (superseded) straight-widen design did.
        let bounds = NotchShape(topCornerRadius: 6, bottomCornerRadius: 14, topFlareWidth: 60)
            .path(in: rect).cgPath.boundingBox
        XCTAssertEqual(bounds.minX, rect.minX, accuracy: 0.01,
                       "The flared path must still reach the rect's left edge (full width) below the band.")
        XCTAssertEqual(bounds.maxX, rect.maxX, accuracy: 0.01,
                       "The flared path must still reach the rect's right edge (full width) below the band.")
    }

    func testNonZeroTopFlareWidthProducesANarrowTopBand() {
        // Just below the very top edge, only the narrow center band is filled -- a point well
        // outside the band (but still well inside the rect horizontally) must NOT be part of the
        // shape yet, proving the top reads as a narrow neck, not a full-width flat top.
        let flaredPath = NotchShape(topCornerRadius: 6, bottomCornerRadius: 14, topFlareWidth: 60)
            .path(in: rect).cgPath
        let centerOfBand = CGPoint(x: rect.midX, y: rect.minY + 0.5)
        XCTAssertTrue(flaredPath.contains(centerOfBand, using: .winding),
                      "The center of the narrow top-band must be filled.")
        let wellOutsideBand = CGPoint(x: rect.minX + 10, y: rect.minY + 0.5)
        XCTAssertFalse(flaredPath.contains(wellOutsideBand, using: .winding),
                       "A point near the rect's edge, just below the top, must NOT be filled yet -- the top band is narrow, not full-width.")
    }

    func testFlaredPathStaysClosedAndNonEmpty() {
        // Mirrors testCustomRadiiProduceAClosedNonEmptyPath, with a non-zero topFlareWidth.
        let path = NotchShape(topCornerRadius: 6, bottomCornerRadius: 14, topFlareWidth: 60).path(in: rect)
        let cgBounds = path.cgPath.boundingBox
        XCTAssertFalse(path.cgPath.isEmpty, "Flared closed pill path must be non-empty.")
        XCTAssertGreaterThan(cgBounds.width, 0, "The flared closed path needs a positive-width bounding box.")
        XCTAssertGreaterThan(cgBounds.height, 0, "The flared closed path needs a positive-height bounding box.")
    }

    func testFlaredPathStillCutsAwayTheTopCornerRoundingNotch() {
        // The topCornerRadius corner curve is UNCHANGED math, just shifted down by flareDepth to
        // where the sweep converges on the full rect width. This proves the corner is still
        // visibly rounded (not flattened to square) at that (shifted) transition point, even with
        // a non-zero topFlareWidth -- regression coverage for the round-4 zero-tangent bug that
        // erased corner rounding in the earlier (superseded) straight-widen design.
        let topCornerRadius: CGFloat = 6
        let flaredPath = NotchShape(topCornerRadius: topCornerRadius, bottomCornerRadius: 14, topFlareWidth: 60)
            .path(in: rect).cgPath
        let flareDepth = min(20, rect.height * 0.35)
        let topY = rect.minY + flareDepth
        // Just inside the left edge, barely below where the sweep reaches full width -- this
        // point sits in the "notch" topCornerRadius cuts away; if the corner rounding were
        // erased (flattened to square), this point would incorrectly report as inside the fill.
        let notchPoint = CGPoint(x: rect.minX + 1, y: topY + 0.5)
        XCTAssertFalse(flaredPath.contains(notchPoint, using: .winding),
                       "The topCornerRadius notch must stay cut away (corner still rounded) even when topFlareWidth > 0.")
    }
}
