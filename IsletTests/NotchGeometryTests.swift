import XCTest
import CoreGraphics
@testable import Islet

// ISL-01: pure notch-geometry math. These tests exercise hasNotch / notchSize /
// notchFrame with no live NSScreen — every input is hand-built, so the math
// (width formula, +4 fudge, and the AppKit bottom-left coordinate flip from
// Pitfall 1) is verified deterministically by an automated agent.
final class NotchGeometryTests: XCTestCase {

    // MARK: hasNotch

    func testHasNotchTrueWhenInsetAndBothAuxAreasPresent() {
        XCTAssertTrue(hasNotch(safeAreaTop: 38, auxLeftWidth: 600, auxRightWidth: 600))
    }

    func testHasNotchFalseForExternalOrNonNotchScreen() {
        XCTAssertFalse(hasNotch(safeAreaTop: 0, auxLeftWidth: nil, auxRightWidth: nil))
    }

    func testHasNotchFalseWhenAuxDataIncomplete() {
        // Only one auxiliary strip reported → not a real notch.
        XCTAssertFalse(hasNotch(safeAreaTop: 38, auxLeftWidth: nil, auxRightWidth: 600))
    }

    // MARK: notchSize

    func testNotchSizeWidthFormulaAndHeight() throws {
        // width = screenWidth - left - right + widthFudge = 1512 - 612 - 612 + 4 = 292
        // height = safeAreaTop = 38
        let size = notchSize(screenWidth: 1512,
                             safeAreaTop: 38,
                             auxLeftWidth: 612,
                             auxRightWidth: 612,
                             widthFudge: 4)
        let unwrapped = try XCTUnwrap(size)
        XCTAssertEqual(unwrapped.width, 292, accuracy: 0.0001)
        XCTAssertEqual(unwrapped.height, 38, accuracy: 0.0001)
    }

    func testNotchSizeNilWhenAuxMissing() {
        let size = notchSize(screenWidth: 1512,
                             safeAreaTop: 38,
                             auxLeftWidth: nil,
                             auxRightWidth: 612,
                             widthFudge: 4)
        XCTAssertNil(size)
    }

    // MARK: notchFrame

    func testNotchFrameCenteringAndCoordinateFlipAtOrigin() throws {
        // screenFrame origin (0,0) size 1512x982, safeAreaTop 38, aux 612/612, fudge 4.
        // width 292, height 38, x = midX - width/2 = 756 - 146 = 610,
        // y = maxY - height = 982 - 38 = 944 (top edge in AppKit bottom-left coords).
        let frame = try XCTUnwrap(
            notchFrame(screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982),
                       safeAreaTop: 38,
                       auxLeftWidth: 612,
                       auxRightWidth: 612,
                       widthFudge: 4)
        )
        XCTAssertEqual(frame.width, 292, accuracy: 0.0001)
        XCTAssertEqual(frame.height, 38, accuracy: 0.0001)
        XCTAssertEqual(frame.origin.x, 610, accuracy: 0.0001)
        XCTAssertEqual(frame.origin.y, 944, accuracy: 0.0001)
    }

    func testNotchFrameOnScreenWithNonZeroOrigin() throws {
        // Built-in screen positioned to the right in the arrangement: origin (1920,0).
        // x = 1920 + 756 - 146 = 2530, y = 944.
        let frame = try XCTUnwrap(
            notchFrame(screenFrame: CGRect(x: 1920, y: 0, width: 1512, height: 982),
                       safeAreaTop: 38,
                       auxLeftWidth: 612,
                       auxRightWidth: 612,
                       widthFudge: 4)
        )
        XCTAssertEqual(frame.origin.x, 2530, accuracy: 0.0001)
        XCTAssertEqual(frame.origin.y, 944, accuracy: 0.0001)
    }

    func testNotchFrameNilWhenNoNotch() {
        let frame = notchFrame(screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982),
                               safeAreaTop: 0,
                               auxLeftWidth: nil,
                               auxRightWidth: nil,
                               widthFudge: 4)
        XCTAssertNil(frame)
    }
}
