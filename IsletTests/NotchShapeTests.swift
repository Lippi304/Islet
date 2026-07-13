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

    func testNonZeroTopFlareWidthKeepsTheTopEdgeFlushAcrossFullWidth() {
        // The hard regression this round fixes: the flat top run must span the shape's FULL
        // width, flush at rect.minY -- never recessed downward the way the round-5 concave sweep
        // was outside its narrow band. Points near both top corners, just below the very top
        // edge, must already be filled at full width.
        let flaredPath = NotchShape(topCornerRadius: 6, bottomCornerRadius: 14, topFlareWidth: 60)
            .path(in: rect).cgPath
        let nearLeftEdge = CGPoint(x: rect.minX + 1, y: rect.minY + 0.5)
        let nearRightEdge = CGPoint(x: rect.maxX - 1, y: rect.minY + 0.5)
        XCTAssertTrue(flaredPath.contains(nearLeftEdge, using: .winding),
                      "The top edge must be flush (filled) near the left corner, full width -- not recessed downward.")
        XCTAssertTrue(flaredPath.contains(nearRightEdge, using: .winding),
                      "The top edge must be flush (filled) near the right corner, full width -- not recessed downward.")
    }

    func testFlaredPathTopBoundsStaysAtRectMinY() {
        // The bounding box's own top must sit exactly at rect.minY -- proving no part of the top
        // edge is pulled down/away from the true screen edge, the exact user-reported bug this
        // round fixes ("Gar nicht mehr am Rand dran").
        let bounds = NotchShape(topCornerRadius: 6, bottomCornerRadius: 14, topFlareWidth: 60)
            .path(in: rect).cgPath.boundingBox
        XCTAssertEqual(bounds.minY, rect.minY, accuracy: 0.01,
                       "The flared path's topmost point must stay at rect.minY -- flush with the true screen edge.")
    }

    func testNonZeroTopFlareWidthBulgesPastTheRectWidth() {
        // Unlike the round-5 concave sweep (which stayed within the rect), the shoulder bulge
        // genuinely extends past rect.minX/rect.maxX -- this is the visible "flare" itself.
        let bounds = NotchShape(topCornerRadius: 6, bottomCornerRadius: 14, topFlareWidth: 60)
            .path(in: rect).cgPath.boundingBox
        XCTAssertLessThan(bounds.minX, rect.minX,
                          "The shoulder bulge must extend past the rect's left edge.")
        XCTAssertGreaterThan(bounds.maxX, rect.maxX,
                             "The shoulder bulge must extend past the rect's right edge.")
    }

    func testFlaredPathStaysClosedAndNonEmpty() {
        // Mirrors testCustomRadiiProduceAClosedNonEmptyPath, with a non-zero topFlareWidth.
        let path = NotchShape(topCornerRadius: 6, bottomCornerRadius: 14, topFlareWidth: 60).path(in: rect)
        let cgBounds = path.cgPath.boundingBox
        XCTAssertFalse(path.cgPath.isEmpty, "Flared closed pill path must be non-empty.")
        XCTAssertGreaterThan(cgBounds.width, 0, "The flared closed path needs a positive-width bounding box.")
        XCTAssertGreaterThan(cgBounds.height, 0, "The flared closed path needs a positive-height bounding box.")
    }

    func testFlaredPathShoulderMergesAtTheUnshiftedTopCornerRadiusEndpoint() {
        // The shoulder bulge must merge back into the topCornerRadius transition's own UNCHANGED,
        // un-shifted endpoint (rect.maxX - topCornerRadius, rect.minY + topCornerRadius) -- not a
        // flareDepth-shifted position (the round-5 bug this round fixes). The straight wall
        // immediately below that endpoint must already be at the plain unflared x-position,
        // proving the downstream corner/wall geometry is byte-identical to the topFlareWidth == 0
        // case, only the bulge above it differs.
        let topCornerRadius: CGFloat = 6
        let flaredPath = NotchShape(topCornerRadius: topCornerRadius, bottomCornerRadius: 14, topFlareWidth: 60)
            .path(in: rect).cgPath
        let onTheUnflaredWall = CGPoint(x: rect.minX + topCornerRadius, y: rect.minY + topCornerRadius + 1)
        XCTAssertTrue(flaredPath.contains(onTheUnflaredWall, using: .winding),
                      "Just below the shoulder's merge point, the straight wall must already sit at the plain unflared x-position.")
    }
}
