import XCTest
import AppKit
@testable import Islet

// ISL-02 / D-07: the overlay window must be a borderless, non-activating panel that
// never becomes key/main, ignores mouse events (fully click-through in Phase 1),
// sits above normal windows at .statusBar level, joins all Spaces and sits above
// fullscreen-auxiliary content, and is transparent with no shadow.
//
// Constructing an NSPanel touches AppKit window machinery, which must run on the
// main thread, so the whole case is @MainActor.
@MainActor
final class NotchPanelTests: XCTestCase {

    private func makePanel() -> NotchPanel {
        NotchPanel(contentRect: NSRect(x: 0, y: 0, width: 200, height: 32))
    }

    func testPanelIsNonActivating() {
        let panel = makePanel()
        XCTAssertTrue(panel.styleMask.contains(.nonactivatingPanel),
                      "Panel must be a non-activating panel so it never activates the app (D-07).")
    }

    func testPanelNeverBecomesKeyOrMain() {
        let panel = makePanel()
        XCTAssertFalse(panel.canBecomeKey, "A non-activating overlay must never take key focus (D-07).")
        XCTAssertFalse(panel.canBecomeMain, "A non-activating overlay must never become main (D-07).")
    }

    func testPanelLevelIsStatusBar() {
        // Recorded explicitly: Plan 03 may bump this vs the Tahoe menu bar (A2);
        // keep this assertion in sync with whatever level ships.
        let panel = makePanel()
        XCTAssertEqual(panel.level, .statusBar)
    }

    func testPanelJoinsAllSpacesAboveFullscreenAux() {
        let panel = makePanel()
        XCTAssertTrue(panel.collectionBehavior.contains(.canJoinAllSpaces),
                      "ISL-02: the island must be visible across all Spaces.")
        XCTAssertTrue(panel.collectionBehavior.contains(.fullScreenAuxiliary),
                      "ISL-02: the island must sit above fullscreen-auxiliary content.")
    }

    func testPanelIsClickThrough() {
        let panel = makePanel()
        XCTAssertTrue(panel.ignoresMouseEvents,
                      "Phase 1 is fully click-through (D-07) — clicks pass through to the UI beneath.")
    }

    func testPanelIsTransparentWithoutShadow() {
        let panel = makePanel()
        XCTAssertEqual(panel.backgroundColor, NSColor.clear,
                       "The window itself is transparent; the pill draws the black.")
        XCTAssertFalse(panel.hasShadow, "No drop shadow around the notch.")
    }
}
