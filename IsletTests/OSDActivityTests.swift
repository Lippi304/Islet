import XCTest
@testable import Islet

// Phase 39 / HUD-03/HUD-04: the PURE volume/brightness→presentation seam. Like
// FocusActivityTests and PowerActivityTests, osdVolumeActivity(...)/osdBrightnessActivity(...)
// are total, framework-free functions — no CGEventTap, no CoreAudio, no DisplayServices — so
// the mapping (including V5 clamp behavior) is verified deterministically by an automated
// agent in milliseconds. VolumeReader/BrightnessReader (later plans, system glue) own the
// real hardware reads and feed raw values in here.
final class OSDActivityTests: XCTestCase {

    func testVolumeMapsInRange() {
        XCTAssertEqual(osdVolumeActivity(percent: 50, hardwareMuted: false),
                        .volume(percent: 50, hardwareMuted: false))
    }

    func testVolumeClampsAboveRange() {
        // V5 clamp, out-of-range high.
        XCTAssertEqual(osdVolumeActivity(percent: 150, hardwareMuted: false),
                        .volume(percent: 100, hardwareMuted: false))
    }

    func testVolumeClampsBelowRange() {
        // V5 clamp, out-of-range low.
        XCTAssertEqual(osdVolumeActivity(percent: -10, hardwareMuted: false),
                        .volume(percent: 0, hardwareMuted: false))
    }

    func testBrightnessMapsInRangeAndClamps() {
        XCTAssertEqual(osdBrightnessActivity(percent: 42), .brightness(percent: 42))
        XCTAssertEqual(osdBrightnessActivity(percent: 200), .brightness(percent: 100))
    }

    func testIsMutedHardwareMutePath() {
        // D-03 path 1: hardware mute.
        XCTAssertTrue(OSDActivity.volume(percent: 50, hardwareMuted: true).isMuted)
    }

    func testIsMutedZeroLevelPath() {
        // D-03 path 2: zero level (RESEARCH Open Question 3).
        XCTAssertTrue(OSDActivity.volume(percent: 0, hardwareMuted: false).isMuted)
    }

    func testIsMutedFalseWhenNeitherPath() {
        XCTAssertFalse(OSDActivity.volume(percent: 50, hardwareMuted: false).isMuted)
    }

    func testBrightnessNeverMuted() {
        // Brightness has no muted state, per 39-UI-SPEC.md.
        XCTAssertFalse(OSDActivity.brightness(percent: 50).isMuted)
    }
}
