import XCTest
@testable import Islet

// Phase 65 Plan 04 / QACTION-03 — FocusToggleAction has no injectable seam for
// INFocusStatusCenter/Process (like MicMuteControllerTests' real-hardware discipline), so these
// tests exercise the ONE piece that's meaningfully pure: the before/after comparison. The
// authorization-gated no-crash checks mirror testDefaultInputDeviceIDDoesNotCrash's "a legitimate
// outcome, not a failure" pattern for a machine without Focus authorization granted.
//
// @MainActor mirrors DeviceCoordinatorTests'/NotchPillViewTests' precedent: FocusToggleAction
// itself is @MainActor (it calls FocusModeMonitor.isAuthorized, which is MainActor-isolated).
@MainActor
final class FocusToggleActionTests: XCTestCase {

    func testFocusStateChangedReturnsTrueWhenStatesDiffer() {
        XCTAssertTrue(FocusToggleAction.focusStateChanged(before: true, after: false))
        XCTAssertTrue(FocusToggleAction.focusStateChanged(before: false, after: true))
    }

    func testFocusStateChangedReturnsFalseWhenStatesMatch() {
        XCTAssertFalse(FocusToggleAction.focusStateChanged(before: true, after: true))
        XCTAssertFalse(FocusToggleAction.focusStateChanged(before: false, after: false))
    }

    func testIsConfirmedOnDoesNotCrash() {
        // A legitimate outcome (not authorized / no data yet) is `false`, not a crash.
        _ = FocusToggleAction.isConfirmedOn
    }

    func testToggleDoesNotCrashAndReportsFalseWhenUnauthorized() {
        let expectation = expectation(description: "onResult called")
        FocusToggleAction.toggle { result in
            // On a machine without Focus authorization granted, toggle must call onResult(false)
            // synchronously rather than crash or hang.
            if !FocusModeMonitor.isAuthorized {
                XCTAssertFalse(result)
            }
            expectation.fulfill()
        }
        waitForExpectations(timeout: 2)
    }
}
