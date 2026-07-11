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
}
