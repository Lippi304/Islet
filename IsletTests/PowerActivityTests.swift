import XCTest
@testable import Islet

// Phase 3 / CHG-01 + CHG-02: the PURE power→presentation seam. Like NotchGeometry
// and NotchInteractionState, powerActivity(from:) and shouldTriggerSplash(previous:next:)
// are total, framework-free functions — no IOKit, no AppKit — so the riskiest
// classification logic (charging vs full vs on-battery vs no-battery, percent clamping,
// splash debounce) is verified deterministically by an automated agent in milliseconds.
// Plan 03 owns the real IOPS read + run-loop source and feeds PowerReading values in here.
final class PowerActivityTests: XCTestCase {

    // MARK: powerActivity(from:) — the locked classification matrix

    func testChargingMapsToCharging() {
        // CHG-01: on AC, actively charging → .charging with the live percent.
        let r = PowerReading(isPresent: true, isOnAC: true, isCharging: true, isCharged: false, percent: 47)
        XCTAssertEqual(powerActivity(from: r), .charging(percent: 47))
    }

    func testChargedMapsToFull() {
        // CHG-01: on AC and reported charged (kIOPSIsChargedKey) → .full.
        let r = PowerReading(isPresent: true, isOnAC: true, isCharging: false, isCharged: true, percent: 100)
        XCTAssertEqual(powerActivity(from: r), .full(percent: 100))
    }

    func testOnACNotChargingMapsToFull() {
        // The "distinguish charging from plugged-but-full" criterion: on AC but NOT
        // charging and NOT (yet) flagged charged still presents as .full — there is no
        // charge in progress, so we never show the bolt.
        let r = PowerReading(isPresent: true, isOnAC: true, isCharging: false, isCharged: false, percent: 100)
        XCTAssertEqual(powerActivity(from: r), .full(percent: 100))
    }

    func testOnBatteryMapsToOnBattery() {
        // CHG-02: unplugged → .onBattery (plain battery glyph).
        let r = PowerReading(isPresent: true, isOnAC: false, isCharging: false, isCharged: false, percent: 63)
        XCTAssertEqual(powerActivity(from: r), .onBattery(percent: 63))
    }

    func testNoBatteryMapsToNil() {
        // Locked no-op criterion: a desktop / empty power-source list has no readable
        // battery → nil → no splash (graceful no-op).
        let r = PowerReading(isPresent: false, isOnAC: true, isCharging: false, isCharged: false, percent: 0)
        XCTAssertNil(powerActivity(from: r))
    }

    func testPercentClampedLow() {
        // A malformed low reading must never produce a negative percent.
        let r = PowerReading(isPresent: true, isOnAC: true, isCharging: true, isCharged: false, percent: -5)
        XCTAssertEqual(powerActivity(from: r), .charging(percent: 0))
    }

    func testPercentClampedHigh() {
        // A malformed high reading must never exceed 100.
        let r = PowerReading(isPresent: true, isOnAC: true, isCharging: true, isCharged: false, percent: 150)
        XCTAssertEqual(powerActivity(from: r), .charging(percent: 100))
    }

    // MARK: shouldTriggerSplash(previous:next:) — category-transition debounce (Pitfall 4)

    func testTransitionTriggersSplash() {
        // Plug-in: onBattery → charging is a category change → fire the splash.
        XCTAssertTrue(shouldTriggerSplash(previous: .onBattery(percent: 50), next: .charging(percent: 51)))
    }

    func testUnplugTransitionTriggersSplash() {
        // CHG-02 unplug: charging → onBattery is a category change → fire the splash.
        XCTAssertTrue(shouldTriggerSplash(previous: .charging(percent: 80), next: .onBattery(percent: 80)))
    }

    func testSameCategoryTickDoesNotTrigger() {
        // Pure % tick within the same category must NOT re-fire a splash.
        XCTAssertFalse(shouldTriggerSplash(previous: .charging(percent: 46), next: .charging(percent: 47)))
    }

    func testNilToActivityTriggers() {
        // First reading after launch that resolves to a real activity → fire.
        XCTAssertTrue(shouldTriggerSplash(previous: nil, next: .charging(percent: 20)))
    }

    func testActivityToNilDoesNotTrigger() {
        // Clearing the splash (activity → nil) is not itself a new splash.
        XCTAssertFalse(shouldTriggerSplash(previous: .charging(percent: 20), next: nil))
    }
}
