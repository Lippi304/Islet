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

        // WR-07 (63-REVIEW.md) — this test mutates the REAL machine-wide input mute, so the
        // restore must run on EVERY exit path, not only the happy one at the end of the method.
        // A crash, an XCTFail-triggered early exit, or any future `return` added above it would
        // otherwise leave the dev/CI machine's microphone in a state this test created. The
        // teardown re-reads before acting so it is a no-op when the body already restored it, and
        // it never asserts — a teardown that fails would only mask the real failure.
        addTeardownBlock {
            if readSystemInputMuted() != original { _ = toggleSystemInputMute() }
        }

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

        // Never leave the dev machine's mic in a state this test created. The teardown block
        // above is the backstop if this line (or the assertions below it) never runs.
        let restored = toggleSystemInputMute()
        XCTAssertEqual(restored, original)
        XCTAssertEqual(readSystemInputMuted(), original)
    }
}
