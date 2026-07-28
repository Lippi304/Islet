import XCTest
@testable import Islet

// Phase 66 Plan 02 / MENUBAR-01/02/03, T-66-01 — pure clamp coverage.
// clampedExpandedSpacerLength must never produce a negative or runaway
// NSStatusItem.length regardless of candidate/screenWidth input.
final class MenuBarOverflowClampTests: XCTestCase {

    func testClampsDownToScreenWidthWhenCandidateExceedsIt() {
        XCTAssertEqual(clampedExpandedSpacerLength(candidate: 2000, screenWidth: 1512), 1512)
    }

    func testCandidateStandsWhenScreenIsWiderThanIt() {
        XCTAssertEqual(clampedExpandedSpacerLength(candidate: 2000, screenWidth: 3840), 2000)
    }

    func testZeroScreenWidthNeverProducesNegativeOrRunawayLength() {
        XCTAssertEqual(clampedExpandedSpacerLength(candidate: 2000, screenWidth: 0), 0)
    }

    func testNegativeCandidateNeverProducesNegativeLength() {
        XCTAssertEqual(clampedExpandedSpacerLength(candidate: -5, screenWidth: 1512), 0)
    }
}
