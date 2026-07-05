import XCTest
@testable import Islet

// ISL-05 / Pattern 7: the ONE visibility decision. Every "should the pill be
// visible right now?" input (clamshell/target from Phase 1, fullscreen from
// Phase 2, license entitlement from Phase 10 D-11) converges into
// shouldShow(hasTarget:hideInFullscreen:isFullscreen:isLicensed:).
// hideInFullscreen is the single gating flag (D-10): default true ships the hide;
// a future Phase-6 settings toggle flips it. isLicensed (D-11, LIC-03) is a new
// dominant AND-term: an unlicensed/expired-trial state always hides, regardless
// of every other input. Pure boolean algebra, no AppKit.
final class VisibilityDecisionTests: XCTestCase {

    func testTargetPresentNotFullscreenShows() {
        // Normal: target present, not fullscreen, licensed → show.
        XCTAssertTrue(shouldShow(hasTarget: true, hideInFullscreen: true, isFullscreen: false, isLicensed: true))
    }

    func testTargetPresentFullscreenWithHideFlagHides() {
        // D-09: hide for fullscreen when the gating flag is on (default).
        XCTAssertFalse(shouldShow(hasTarget: true, hideInFullscreen: true, isFullscreen: true, isLicensed: true))
    }

    func testTargetPresentFullscreenWithHideFlagOffShows() {
        // D-10: flag OFF → island stays visible in fullscreen (the future toggle's ON-behavior).
        XCTAssertTrue(shouldShow(hasTarget: true, hideInFullscreen: false, isFullscreen: true, isLicensed: true))
    }

    func testNoTargetHidesEvenWhenNotFullscreen() {
        // No built-in target (clamshell/external) → hide regardless of fullscreen.
        XCTAssertFalse(shouldShow(hasTarget: false, hideInFullscreen: true, isFullscreen: false, isLicensed: true))
    }

    func testNoTargetHidesEvenInFullscreen() {
        // No target → hide; fullscreen is moot.
        XCTAssertFalse(shouldShow(hasTarget: false, hideInFullscreen: true, isFullscreen: true, isLicensed: true))
    }

    func testNoTargetHidesWithHideFlagOff() {
        // No target dominates even with the hide flag off.
        XCTAssertFalse(shouldShow(hasTarget: false, hideInFullscreen: false, isFullscreen: false, isLicensed: true))
    }

    // MARK: D-11 — isLicensed is a dominant AND-term over every other condition.

    func testUnlicensedHidesEvenWhenTargetPresentAndNotFullscreen() {
        // Unlicensed dominates even the "everything else says show" case.
        XCTAssertFalse(shouldShow(hasTarget: true, hideInFullscreen: true, isFullscreen: false, isLicensed: false))
    }

    func testUnlicensedHidesEvenWithHideFlagOff() {
        // Unlicensed dominates with the fullscreen-hide flag off too.
        XCTAssertFalse(shouldShow(hasTarget: true, hideInFullscreen: false, isFullscreen: false, isLicensed: false))
    }

    func testUnlicensedHidesRegardlessOfNoTargetOrFullscreen() {
        // Unlicensed + no-target, both hide reasons present.
        XCTAssertFalse(shouldShow(hasTarget: false, hideInFullscreen: true, isFullscreen: true, isLicensed: false))
    }
}
