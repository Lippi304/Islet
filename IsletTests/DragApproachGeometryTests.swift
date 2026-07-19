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

    // Phase 44 UAT gap-closure (round 2) — these 6 tests were written against the old
    // (pre-Phase-44) 420x117 flex-fill/bottom-anchor box; that card size is now dead in
    // production (the picker is always NotchPillView.traySize.width-wide since Plan 44-01), and
    // computeQuickActionButtonFrames's formula changed from flex-fill/bottom-anchored to
    // fixed-width/centered/top-anchored (see that function's own comment). Rebuilt against the
    // real production card size, matching testQuickActionButtonFramesFitWithinNewTrayAlignedCard's
    // existing precedent of deriving from NotchPillView constants instead of hardcoded literals.
    private static let productionCard = CGRect(x: 0, y: 0,
                                                 width: NotchPillView.traySize.width,
                                                 height: NotchPillView.trayContentHeight + NotchPillView.switcherRowHeight)

    func testReturnsExactlyThreeFrames() {
        XCTAssertEqual(computeQuickActionButtonFrames(card: Self.productionCard).count, 3)
    }

    func testAllThreeFramesHaveEqualWidth() {
        let frames = computeQuickActionButtonFrames(card: Self.productionCard)
        for frame in frames {
            XCTAssertEqual(frame.width, NotchPillView.quickActionButtonWidth, accuracy: 0.01)
        }
    }

    func testFramesAreCenteredWithEqualMargins() {
        let card = Self.productionCard
        let frames = computeQuickActionButtonFrames(card: card)
        let leftMargin = frames[0].minX - card.minX
        let rightMargin = card.maxX - frames[2].maxX
        XCTAssertEqual(leftMargin, rightMargin, accuracy: 0.01)
    }

    func testFramesStayWithinHorizontalBounds() {
        let card = Self.productionCard
        let frames = computeQuickActionButtonFrames(card: card)
        XCTAssertGreaterThanOrEqual(frames[0].minX, card.minX)
        XCTAssertLessThanOrEqual(frames[2].maxX, card.maxX)
    }

    func testFirstFrameTopEdgeSitsCameraClearanceBelowCardTop() {
        let card = Self.productionCard
        let frames = computeQuickActionButtonFrames(card: card)
        XCTAssertEqual(frames[0].maxY, card.maxY - NotchPillView.cameraClearance, accuracy: 0.01)
    }

    func testOffsetIsIdenticalOnNonZeroOriginCard() {
        let zeroOriginCard = Self.productionCard
        let offsetCard = zeroOriginCard.offsetBy(dx: 1000, dy: 500)
        let zeroFrames = computeQuickActionButtonFrames(card: zeroOriginCard)
        let offsetFrames = computeQuickActionButtonFrames(card: offsetCard)
        XCTAssertEqual(offsetFrames[1].minX - offsetCard.minX, zeroFrames[1].minX - zeroOriginCard.minX)
        XCTAssertEqual(offsetFrames[1].minY - offsetCard.minY, zeroFrames[1].minY - zeroOriginCard.minY)
    }

    // Phase 44 / TRAY-06/DRAG-02 (D-08) — lock-in coverage: computeQuickActionButtonFrames still
    // produces 3 in-bounds button frames now that the picker card grew from 420x117 to the real
    // Tray-aligned footprint (650x189). Built from the real production constants (not hardcoded
    // literals) so this test tracks NotchPillView.traySize/trayContentHeight/switcherRowHeight if
    // they ever change again, rather than silently going stale against a fixed number.
    func testQuickActionButtonFramesFitWithinNewTrayAlignedCard() {
        let card = CGRect(x: 0, y: 0,
                           width: NotchPillView.traySize.width,
                           height: NotchPillView.trayContentHeight + NotchPillView.switcherRowHeight)
        let frames = computeQuickActionButtonFrames(card: card)
        XCTAssertEqual(frames.count, 3)
        for frame in frames {
            XCTAssertGreaterThanOrEqual(frame.minX, card.minX)
            XCTAssertLessThanOrEqual(frame.maxX, card.maxX)
            XCTAssertGreaterThanOrEqual(frame.minY, card.minY)
            XCTAssertLessThanOrEqual(frame.maxY, card.maxY)
        }
    }

    // Phase 43 / DRAG-01 (D-01/D-02) — unit coverage for isGenuineFileDrag's 4 behavior cases.

    func testUnchangedCountWithURLsReturnsFalse() {
        XCTAssertFalse(isGenuineFileDrag(currentChangeCount: 5, gestureBaselineChangeCount: 5,
                                          urls: [URL(fileURLWithPath: "/tmp/test.txt")]))
    }

    func testChangedCountWithNoURLsReturnsFalse() {
        XCTAssertFalse(isGenuineFileDrag(currentChangeCount: 6, gestureBaselineChangeCount: 5, urls: []))
    }

    func testChangedCountWithURLsReturnsTrue() {
        XCTAssertTrue(isGenuineFileDrag(currentChangeCount: 6, gestureBaselineChangeCount: 5,
                                         urls: [URL(fileURLWithPath: "/tmp/test.txt")]))
    }

    func testUnchangedCountWithNoURLsReturnsFalse() {
        XCTAssertFalse(isGenuineFileDrag(currentChangeCount: 5, gestureBaselineChangeCount: 5, urls: []))
    }
}
