import XCTest
@testable import Islet

// Phase 38 / HUD-05: the PURE focus→presentation seam. Like PowerActivityTests and
// DeviceActivity's own tests, focusActivity(from:) is a total, framework-free function —
// no Intents, no FileManager — so the mapping is verified deterministically by an
// automated agent in milliseconds. FocusModeMonitor.swift (Plan 38-03, system glue) owns
// the real Focus-status detection and feeds a Bool in here.
final class FocusActivityTests: XCTestCase {

    func testFocusedMapsToOn() {
        // D-09: a focused reading maps to the single .on case.
        XCTAssertEqual(focusActivity(from: true), .on)
    }

    func testNotFocusedMapsToNil() {
        // D-09: Focus Off has no distinct rendered state — mirrors powerActivity(from:)'s
        // "nil is a legitimate no-op result" convention. There is no .off case.
        XCTAssertNil(focusActivity(from: false))
    }
}
