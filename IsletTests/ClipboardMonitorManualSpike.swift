import XCTest
@testable import Islet

// MANUAL SPIKE — DO NOT RUN VIA `xcodebuild test` (the full Islet.app test host hangs
// headless — this project's established xcodebuild-test-headless-hang precedent). Run
// via Xcode Cmd-U for THIS single test method only, then read the Xcode console and
// follow the on-device verification steps in 57-02-PLAN.md Task 2.
final class ClipboardMonitorManualSpike: XCTestCase {

    @MainActor
    func testManualPollingAndClassification() {
        var monitor: ClipboardMonitor!
        monitor = ClipboardMonitor(onChange: { item in
            print("[ClipboardMonitorSpike] captured kind=\(item.kind) timestamp=\(item.timestamp)")
        })
        monitor.start()

        // Window for the developer to manually copy text and image content while
        // watching the console (mirrors AudioOutputMonitorManualSpike's 45-second
        // manual-interaction window).
        RunLoop.current.run(until: Date().addingTimeInterval(45))

        monitor.stop()

        // Always green — the real pass/fail criteria is the human-read console output
        // plus 57-02-PLAN.md Task 2's on-device checkpoint, never this trivial assertion.
        XCTAssertTrue(true, "manual spike — see console output and 57-02-PLAN.md Task 2 for the real pass/fail criteria")
    }
}
