import XCTest
@testable import Islet

// Phase 47 / D-01 + D-02: the PURE audio-output-device presentation seam. Like
// OSDActivityTests/NowPlayingPresentationTests, isOutputCapableDevice(...) and
// sortedAudioOutputDevices(...) are total, framework-free functions — no CoreAudio, no
// AppKit — so the classification/ordering logic is verified deterministically by an
// automated agent in milliseconds. AudioOutputMonitor (Plan 47-02, system glue) is the only
// caller feeding in real CoreAudio-derived facts.
final class AudioOutputPresentationTests: XCTestCase {

    // MARK: - AudioOutputDevice identity (Pitfall 4)

    func testDeviceIdIsUID() {
        let device = AudioOutputDevice(uid: "abc-uid", name: "MacBook Pro Speakers", isDefault: true)
        XCTAssertEqual(device.id, "abc-uid")
    }

    // MARK: - isOutputCapableDevice(outputChannelCount:) — D-01

    func testOutputCapableWithPositiveChannelCount() {
        // A normal stereo output device, or an AirPlay/aggregate device CoreAudio reports
        // with >0 output channels — D-01 scope includes these kinds, not just physical hardware.
        XCTAssertTrue(isOutputCapableDevice(outputChannelCount: 2))
    }

    func testNotOutputCapableWithZeroChannelCount() {
        // A mic-only input device, or a device CoreAudio reports with zero output channels.
        XCTAssertFalse(isOutputCapableDevice(outputChannelCount: 0))
    }

    func testNotOutputCapableWithNegativeChannelCount() {
        // Defensive floor — a malformed/negative channel-count read from the glue layer is
        // never treated as capable, matching osdVolumeActivity's clamp discipline.
        XCTAssertFalse(isOutputCapableDevice(outputChannelCount: -1))
    }
}
