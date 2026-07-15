import XCTest
import AppKit
@testable import Islet

// Phase 24 / SHELF-01 / SHELF-02 — unit coverage for isWithinDragAcceptRegion's pure geometry
// math (Wave 0 gap closure per 24-VALIDATION.md). Mirrors DragDropSupportTests.swift's
// fixture-free convention: one test method per behavior, no setUp/tearDown, no mocking.
final class DragApproachGeometryTests: XCTestCase {

    func testPointInsideZoneAtOrBelowMaxYReturnsTrue() {
        let zone = CGRect(x: 0, y: 0, width: 200, height: 100)
        XCTAssertTrue(isWithinDragAcceptRegion(CGPoint(x: 100, y: 50), zone: zone, maxY: 90))
    }

    func testPointInsideZoneAboveMaxYReturnsFalse() {
        let zone = CGRect(x: 0, y: 0, width: 200, height: 100)
        XCTAssertFalse(isWithinDragAcceptRegion(CGPoint(x: 100, y: 95), zone: zone, maxY: 90))
    }

    func testPointOutsideZoneReturnsFalseRegardlessOfMaxY() {
        let zone = CGRect(x: 0, y: 0, width: 200, height: 100)
        XCTAssertFalse(isWithinDragAcceptRegion(CGPoint(x: 300, y: 50), zone: zone, maxY: 90))
    }

    func testNilZoneReturnsFalse() {
        XCTAssertFalse(isWithinDragAcceptRegion(CGPoint(x: 100, y: 50), zone: nil, maxY: 90))
    }

    func testNilMaxYReturnsFalse() {
        let zone = CGRect(x: 0, y: 0, width: 200, height: 100)
        XCTAssertFalse(isWithinDragAcceptRegion(CGPoint(x: 100, y: 50), zone: zone, maxY: nil))
    }

    // Phase 34 (UAT revision, D-11/D-12) — unit coverage for
    // computeQuickActionButtonFrames(card:)'s pure geometry math (34-RESEARCH.md Pattern 3).
    // Mirrors this file's own fixture-free convention: one test method per behavior.

    func testReturnsExactlyThreeFrames() {
        let card = CGRect(x: 0, y: 0, width: 420, height: 117)
        XCTAssertEqual(computeQuickActionButtonFrames(card: card).count, 3)
    }

    func testAllThreeFramesHaveEqualWidth() {
        let card = CGRect(x: 0, y: 0, width: 420, height: 117)
        let frames = computeQuickActionButtonFrames(card: card)
        let expectedWidth: CGFloat = (420 - 2 * 16 - 2 * 16) / 3
        for frame in frames {
            XCTAssertEqual(frame.width, expectedWidth, accuracy: 0.01)
        }
    }

    func testFirstFrameStartsAtHorizontalInset() {
        let card = CGRect(x: 0, y: 0, width: 420, height: 117)
        let frames = computeQuickActionButtonFrames(card: card)
        XCTAssertEqual(frames[0].minX, card.minX + 16)
    }

    func testLastFrameEndsAtInsetFromRightEdge() {
        let card = CGRect(x: 0, y: 0, width: 420, height: 117)
        let frames = computeQuickActionButtonFrames(card: card)
        XCTAssertEqual(frames[2].maxX, card.maxX - 16, accuracy: 0.01)
    }

    func testFirstFrameSitsAtBottomInsetAboveCardOrigin() {
        let card = CGRect(x: 0, y: 0, width: 420, height: 117)
        let frames = computeQuickActionButtonFrames(card: card)
        XCTAssertEqual(frames[0].minY, card.minY + 16)
    }

    func testOffsetIsIdenticalOnNonZeroOriginCard() {
        let zeroOriginCard = CGRect(x: 0, y: 0, width: 420, height: 117)
        let offsetCard = CGRect(x: 1000, y: 500, width: 420, height: 117)
        let zeroFrames = computeQuickActionButtonFrames(card: zeroOriginCard)
        let offsetFrames = computeQuickActionButtonFrames(card: offsetCard)
        XCTAssertEqual(offsetFrames[1].minX - offsetCard.minX, zeroFrames[1].minX - zeroOriginCard.minX)
    }
}
