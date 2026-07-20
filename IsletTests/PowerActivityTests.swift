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

    func testOnACNotChargedMapsToCharging() {
        // 36-01 on-device UAT round 3 (confirmed via real hardware trace): macOS's Optimized
        // Battery Charging can hold kIOPSIsChargingKey false for the entire time a Mac sits on
        // AC below 100% — Apple's own battery icon shows this as "connected, no bolt" too. The
        // classification now keys off isCharged (not the flaky isCharging), so on AC + not
        // charged → .charging regardless of the raw isCharging flag.
        let r = PowerReading(isPresent: true, isOnAC: true, isCharging: false, isCharged: false, percent: 96)
        XCTAssertEqual(powerActivity(from: r), .charging(percent: 96))
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

    // MARK: shouldTriggerSplash(previous:next:) — CONNECT-only edge (on-device UAT decision)
    //
    // Product decision after on-device testing: the splash fires ONLY when the charger is
    // plugged in (not-on-AC → on-AC). Unplugging shows NOTHING, and topping off while still
    // plugged (charging → full) shows nothing. Only the connect moment animates.

    func testPlugInWhileDischargingTriggers() {
        // Connect: onBattery → charging (not-AC → AC) → fire the splash.
        XCTAssertTrue(shouldTriggerSplash(previous: .onBattery(percent: 50), next: .charging(percent: 51)))
    }

    func testPlugInAlreadyFullTriggers() {
        // Connect at 100%: onBattery → full (not-AC → AC) → fire the splash.
        XCTAssertTrue(shouldTriggerSplash(previous: .onBattery(percent: 100), next: .full(percent: 100)))
    }

    func testUnplugDoesNotTrigger() {
        // Unplug: charging → onBattery (AC → not-AC). Per the UAT decision the unplug shows
        // NO splash (CHG-02's on-battery indication intentionally dropped — connect-only).
        XCTAssertFalse(shouldTriggerSplash(previous: .charging(percent: 80), next: .onBattery(percent: 80)))
    }

    func testUnplugWhileFullDoesNotTrigger() {
        // Unplug at full: full → onBattery (AC → not-AC) → no splash.
        XCTAssertFalse(shouldTriggerSplash(previous: .full(percent: 100), next: .onBattery(percent: 100)))
    }

    func testTopOffChargingToFullDoesNotTrigger() {
        // Still plugged, battery reaches full: charging → full (AC → AC, no new connect) →
        // no splash (only the connect moment animates, never the top-off).
        XCTAssertFalse(shouldTriggerSplash(previous: .charging(percent: 99), next: .full(percent: 100)))
    }

    func testSameCategoryTickDoesNotTrigger() {
        // Pure % tick within the same category must NOT re-fire a splash.
        XCTAssertFalse(shouldTriggerSplash(previous: .charging(percent: 46), next: .charging(percent: 47)))
    }

    func testNilToOnACTriggers() {
        // First reading after launch that resolves to an on-AC activity → fire (the controller
        // separately suppresses the launch reading via didSeedInitialPower).
        XCTAssertTrue(shouldTriggerSplash(previous: nil, next: .charging(percent: 20)))
    }

    func testNilToOnBatteryDoesNotTrigger() {
        // Launch on battery: nil → onBattery (not-AC) → no splash.
        XCTAssertFalse(shouldTriggerSplash(previous: nil, next: .onBattery(percent: 60)))
    }

    func testActivityToNilDoesNotTrigger() {
        // Clearing the splash (activity → nil) is not itself a new splash.
        XCTAssertFalse(shouldTriggerSplash(previous: .charging(percent: 20), next: nil))
    }
}
