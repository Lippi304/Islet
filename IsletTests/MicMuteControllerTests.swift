import XCTest
@testable import Islet

// Phase 63 / MEET-02 — MicMuteController runs against this machine's REAL CoreAudio hardware
// (like AudioOutputPresentationTests' device-facing checks): there is no injectable seam and
// none is wanted (D-04 scope discipline — mute read+toggle only, nothing else). So these tests
// assert the ONE property that actually matters: every entry point degrades to a safe default
// instead of crashing, whatever hardware happens to be attached to the CI/dev machine
// (T-63-01 — a Bluetooth input device may not implement kAudioDevicePropertyMute at all).
final class MicMuteControllerTests: XCTestCase {

    func testDefaultInputDeviceIDDoesNotCrash() {
        // nil (no default input device) is a legitimate outcome, not a failure.
        _ = defaultInputDeviceID()
    }

    func testReadSystemInputMutedDoesNotCrashAndIsStable() {
        let first = readSystemInputMuted()
        let second = readSystemInputMuted()
        // Pure read — two back-to-back calls with no toggle in between must agree.
        XCTAssertEqual(first, second)
    }

    func testToggleSystemInputMuteNeverPartiallyAppliesAndRestores() {
        let original = readSystemInputMuted()

        guard let toggled = toggleSystemInputMute() else {
            // nil = a Get/Set guard failed (e.g. no default input device, or the device does
            // not implement kAudioDevicePropertyMute). The contract is that NOTHING changed.
            XCTAssertEqual(readSystemInputMuted(), original,
                           "a nil toggle must never have partially applied a change")
            return
        }

        XCTAssertNotEqual(toggled, original, "a successful toggle must flip the muted state")
        XCTAssertEqual(readSystemInputMuted(), toggled,
                       "the post-toggle read must agree with the value toggle reported")

        // Never leave the dev machine's mic in a state this test created.
        let restored = toggleSystemInputMute()
        XCTAssertEqual(restored, original)
        XCTAssertEqual(readSystemInputMuted(), original)
    }
}
