import XCTest
import CoreGraphics
@testable import Islet

// ISL-05: pure true-fullscreen detection (Pattern 6). The signal is safe-area
// collapse on a STILL-PRESENT built-in display — a true-fullscreen app reclaims
// the menu-bar/notch band, so the built-in stops reporting its notch safe area.
// A merely maximized window leaves the safe area intact (D-09: maximized does NOT
// count). An ABSENT built-in is clamshell, NOT fullscreen (nil → false). Fixtures
// are hand-built ScreenDescriptors — no live NSScreen, no AppKit observers (those
// are Plan 02-04).
final class FullscreenDetectorTests: XCTestCase {

    // MARK: Fixtures

    private func notchedBuiltin() -> ScreenDescriptor {
        // Normal desktop OR a merely maximized window: notch safe area intact.
        ScreenDescriptor(uuid: "builtin",
                         frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
                         safeAreaTop: 38,
                         auxLeftWidth: 612,
                         auxRightWidth: 612,
                         isBuiltin: true)
    }

    private func collapsedBuiltin() -> ScreenDescriptor {
        // True-fullscreen app reclaimed the band: the notch safe area is gone while
        // the built-in display is STILL present.
        ScreenDescriptor(uuid: "builtin",
                         frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
                         safeAreaTop: 0,
                         auxLeftWidth: nil,
                         auxRightWidth: nil,
                         isBuiltin: true)
    }

    // MARK: Tests

    func testNotchedBuiltinIsNotFullscreen() {
        // Safe area intact → normal desktop or merely maximized (D-09 maximized ≠ fullscreen).
        XCTAssertFalse(isTrueFullscreen(builtin: notchedBuiltin()))
    }

    func testCollapsedSafeAreaBuiltinIsFullscreen() {
        // Present but safe area collapsed → true-fullscreen reclaimed the band.
        XCTAssertTrue(isTrueFullscreen(builtin: collapsedBuiltin()))
    }

    func testNilBuiltinIsNotFullscreen() {
        // Absent built-in is CLAMSHELL, handled by selectTargetScreen→nil — NOT
        // fullscreen. They are different inputs; nil maps to false here.
        XCTAssertFalse(isTrueFullscreen(builtin: nil))
    }
}
