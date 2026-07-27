import XCTest
@testable import Islet

// MANUAL SPIKE — DO NOT RUN VIA `xcodebuild test` (the full Islet.app test host hangs
// headless — this project's established xcodebuild-test-headless-hang precedent). Run via
// Xcode Cmd-U for THIS single test method only, then read the Xcode console and follow the
// 8-step on-device verification checklist in 66-01-PLAN.md's checkpoint task.
final class MenuBarOverflowManualSpike: XCTestCase {

    @MainActor
    func testManualMechanism() {
        print("[MenuBarOverflowSpike] AXIsProcessTrusted() = \(AXIsProcessTrusted())")
        print("[MenuBarOverflowSpike][diag] CGPreflightScreenCaptureAccess() = \(CGPreflightScreenCaptureAccess())")

        let windows = MenuBarOverflowBridging.menuBarItemWindows()
        print("[MenuBarOverflowSpike] found \(windows.count) other-process menu-bar-item window(s):")
        for window in windows {
            print("[MenuBarOverflowSpike]   bundleID=\(window.bundleIdentifier) windowID=\(window.windowID) frame=\(window.frame)")
        }

        guard let target = windows.first else {
            print("[MenuBarOverflowSpike] No third-party menu-bar icon window found (expected if " +
                  "Accessibility is denied, or if no other app currently has a status item) — " +
                  "confirms the window-list read degrades to an empty result rather than crashing.")
            RunLoop.current.run(until: Date().addingTimeInterval(180))
            XCTAssertTrue(true, "manual spike — see console output and 66-01-PLAN.md's checkpoint task for the real pass/fail criteria")
            return
        }

        print("[MenuBarOverflowSpike] Human: note which menu-bar icon this is (bundleID=\(target.bundleIdentifier)) — it is about to move.")
        print("[MenuBarOverflowSpike] before frame: \(target.frame)")

        let destinationX = target.frame.minX - 200
        let moved = MenuBarOverflowBridging.moveMenuBarItem(windowID: target.windowID, toX: destinationX)
        print("[MenuBarOverflowSpike] moveMenuBarItem returned \(moved)")

        if let after = MenuBarOverflowBridging.currentFrame(windowID: target.windowID) {
            print("[MenuBarOverflowSpike] after frame: \(after)")
        } else {
            print("[MenuBarOverflowSpike] after frame: unavailable (window may have been recreated)")
        }

        print("""
        [MenuBarOverflowSpike] HUMAN CHECK (Pitfall 2 — the central question): after the move \
        above, look at the menu bar — did an adjacent visible icon shift left to fill the \
        vacated position (RECLAIMED — real space returned), or does the position just sit \
        empty/covered by the frontmost app's own menu titles when you switch apps (OCCLUDED)? \
        Report which one you observed.
        """)

        print("[MenuBarOverflowSpike] 180s window starting now. During this time, also work " +
              "through 66-01-PLAN.md's checkpoint steps 6-8: (6) revoke Accessibility for the " +
              "Xcode test host in System Settings and confirm a fresh window-list read below " +
              "returns empty/no crash; (7) sleep/wake the Mac once and confirm a subsequent " +
              "read still succeeds; (8) quit and relaunch the target app once and confirm its " +
              "NEW window ID appears at its new default position, not a stale reference.")

        RunLoop.current.run(until: Date().addingTimeInterval(180))

        let windowsAfterRunLoop = MenuBarOverflowBridging.menuBarItemWindows()
        print("[MenuBarOverflowSpike] post-window re-read: \(windowsAfterRunLoop.count) other-process menu-bar-item window(s) found (permission-denied / sleep-wake / relaunch should each degrade gracefully here, never crash):")
        for window in windowsAfterRunLoop {
            print("[MenuBarOverflowSpike]   bundleID=\(window.bundleIdentifier) windowID=\(window.windowID) frame=\(window.frame)")
        }

        // Always green — the real pass/fail criteria is the human-read console output plus
        // 66-01-PLAN.md's checkpoint checklist, never this trivial assertion.
        XCTAssertTrue(true, "manual spike — see console output and 66-01-PLAN.md's checkpoint task for the real pass/fail criteria")
    }
}
