import XCTest
@testable import Islet

// ISL-05 / Pattern 7: the ONE visibility decision. Every "should the pill be
// visible right now?" input (clamshell/target from Phase 1, fullscreen from
// Phase 2) converges into shouldShow(hasTarget:hideInFullscreen:isFullscreen:).
// hideInFullscreen is the single gating flag (D-10): default true ships the hide;
// a future Phase-6 settings toggle flips it. Pure boolean algebra, no AppKit.
final class VisibilityDecisionTests: XCTestCase {

    func testTargetPresentNotFullscreenShows() {
        // Normal: target present, not fullscreen → show.
        XCTAssertTrue(shouldShow(hasTarget: true, hideInFullscreen: true, isFullscreen: false))
    }

    func testTargetPresentFullscreenWithHideFlagHides() {
        // D-09: hide for fullscreen when the gating flag is on (default).
        XCTAssertFalse(shouldShow(hasTarget: true, hideInFullscreen: true, isFullscreen: true))
    }

    func testTargetPresentFullscreenWithHideFlagOffShows() {
        // D-10: flag OFF → island stays visible in fullscreen (the future toggle's ON-behavior).
        XCTAssertTrue(shouldShow(hasTarget: true, hideInFullscreen: false, isFullscreen: true))
    }

    func testNoTargetHidesEvenWhenNotFullscreen() {
        // No built-in target (clamshell/external) → hide regardless of fullscreen.
        XCTAssertFalse(shouldShow(hasTarget: false, hideInFullscreen: true, isFullscreen: false))
    }

    func testNoTargetHidesEvenInFullscreen() {
        // No target → hide; fullscreen is moot.
        XCTAssertFalse(shouldShow(hasTarget: false, hideInFullscreen: true, isFullscreen: true))
    }

    func testNoTargetHidesWithHideFlagOff() {
        // No target dominates even with the hide flag off.
        XCTAssertFalse(shouldShow(hasTarget: false, hideInFullscreen: false, isFullscreen: false))
    }
}
