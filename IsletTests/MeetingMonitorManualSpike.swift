import XCTest
@testable import Islet

// MANUAL SPIKE — DO NOT RUN VIA `xcodebuild test` (the full Islet.app test host hangs
// headless — this project's established xcodebuild-test-headless-hang precedent). Run via
// Xcode Cmd-U for THIS single test method only, then read the Xcode console and follow the
// 7-step on-device verification checklist in 63-02-PLAN.md Task 2.
final class MeetingMonitorManualSpike: XCTestCase {

    @MainActor
    func testManualDetectionHeuristic() {
        // Pitfall 2 / Assumption A1 go/no-go: exercise MicMuteController's read + toggle FIRST and
        // watch for a system Microphone permission dialog. If a TCC prompt appears anywhere during
        // this run, the whole phase is a NO-GO — Plans 63-03/63-04 would need
        // NSMicrophoneUsageDescription plus a real permission flow added before proceeding.
        print("[MeetingSpike] about to read+toggle system input mute — NO TCC prompt expected")
        let muted = readSystemInputMuted()
        let toggled = toggleSystemInputMute()
        if toggled != nil { _ = toggleSystemInputMute() }   // restore the machine's original mic state.
        print("[MeetingSpike] mic read/toggle succeeded, no TCC prompt expected — read=\(muted) toggledTo=\(String(describing: toggled))")

        var monitor: MeetingMonitor!
        monitor = MeetingMonitor(onChange: { reading in
            print("[MeetingSpike] detected=\(reading != nil) at=\(Date()) reading=\(String(describing: reading))")
        })
        monitor.start()

        // 3-minute window for the human to work through 63-02-PLAN.md Task 2's checklist: join/leave
        // a real Zoom call, mic-test without joining (the accepted D-07 false positive), an unrelated
        // mic app with Zoom/Teams closed, Teams, and a browser-tab Google Meet (MEET-03 negative).
        RunLoop.current.run(until: Date().addingTimeInterval(180))

        monitor.stop()

        // Always green — the real pass/fail criteria is the human-read console output plus Task 2's
        // on-device checkpoint, never this trivial assertion.
        XCTAssertTrue(true, "manual spike — see console output and 63-02-PLAN.md Task 2 for the real pass/fail criteria")
    }
}
