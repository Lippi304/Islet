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

    // MARK: expandedNotchFrame (ISL-04)

    func testExpandedNotchFrameCentersOnMidXAndPinsTop() {
        // collapsed pill at origin-screen: x 610, y 944, 292x38 (== notchFrame output).
        // expandedSize 360x72. The expanded frame stays centered on the collapsed
        // midX (756) and pinned to the same top edge (maxY 982, bottom-left origin):
        //   x = 756 - 180 = 576, y = 982 - 72 = 910.
        let collapsed = CGRect(x: 610, y: 944, width: 292, height: 38)
        let expandedSize = CGSize(width: 360, height: 72)
        let frame = expandedNotchFrame(collapsed: collapsed, expandedSize: expandedSize)
        XCTAssertEqual(frame.midX, collapsed.midX, accuracy: 0.0001)
        XCTAssertEqual(frame.midX, 756, accuracy: 0.0001)
        XCTAssertEqual(frame.maxY, collapsed.maxY, accuracy: 0.0001)
        XCTAssertEqual(frame.maxY, 982, accuracy: 0.0001)
        XCTAssertEqual(frame.origin.x, 576, accuracy: 0.0001)
        XCTAssertEqual(frame.origin.y, 910, accuracy: 0.0001)
        XCTAssertEqual(frame.width, 360, accuracy: 0.0001)
        XCTAssertEqual(frame.height, 72, accuracy: 0.0001)
    }

    func testExpandedNotchFrameOnNonZeroOriginScreen() {
        // Built-in screen placed to the right in the arrangement: collapsed pill at
        // x 2530 (midX 2676). Expanding keeps that midX and the same top edge.
        //   x = 2676 - 180 = 2496, y = 982 - 72 = 910.
        let collapsed = CGRect(x: 2530, y: 944, width: 292, height: 38)
        let expandedSize = CGSize(width: 360, height: 72)
        let frame = expandedNotchFrame(collapsed: collapsed, expandedSize: expandedSize)
        XCTAssertEqual(frame.midX, 2676, accuracy: 0.0001)
        XCTAssertEqual(frame.midX, collapsed.midX, accuracy: 0.0001)
        XCTAssertEqual(frame.origin.x, 2496, accuracy: 0.0001)
        XCTAssertEqual(frame.origin.y, 910, accuracy: 0.0001)
    }

    func testExpandedNotchFrameDegenerateEqualsCollapsed() {
        // Degenerate case: expandedSize == collapsed.size → no jump, frame == collapsed.
        let collapsed = CGRect(x: 610, y: 944, width: 292, height: 38)
        let frame = expandedNotchFrame(collapsed: collapsed, expandedSize: collapsed.size)
        XCTAssertEqual(frame, collapsed)
    }
}
