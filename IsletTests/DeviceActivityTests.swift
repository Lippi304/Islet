import XCTest
@testable import Islet

// Phase 5 / DEV-01 + DEV-02: the PURE device→presentation seam. Like
// PowerActivity and NowPlayingPresentation, deviceActivity(from:), deviceGlyph(name:classMajor:),
// deviceLabel(name:address:) and shouldShowDeviceSplash(...) are total, framework-free
// functions — no IOBluetooth, no AppKit — so the riskiest classification logic (D-01
// all-devices glyph mapping, D-02 generic fallback, D-03 connect/disconnect distinction,
// nil-name fallback, D-04 at-launch burst suppression + reconnect-flap debounce) is verified
// deterministically by an automated agent in milliseconds. Plan 02 owns the real IOBluetooth
// notifications and lifts a DeviceReading out of the connect/disconnect callbacks to feed here.
//
// The burst/debounce predicate is PURE and timestamp-parameterized (callers pass `now` +
// the last-seen state in), never a Timer/clock read — so these tests are deterministic.
final class DeviceActivityTests: XCTestCase {

    // MARK: deviceActivity(from:) — connected / disconnected classification (DEV-01 / DEV-02)

    func testAudioConnectedMapsToConnectedWithSpecificGlyph() {
        // DEV-01 / D-01: an audio-class connected device → .connected; D-02: AirPods name → a
        // specific (non-generic) glyph.
        let r = DeviceReading(name: "AirPods Pro", classMajor: 0x04, address: "00-11-22-33-44-55", connected: true)
        XCTAssertEqual(deviceActivity(from: r), .connected(name: "AirPods Pro", glyph: .airpodsPro, battery: nil))
    }

    func testPeripheralConnectedMapsToConnectedGenericGlyph() {
        // DEV-01 / D-01: a peripheral-class (mouse) connect ALSO splashes (no class gate);
        // D-02: an unmatched non-audio name → .generic fallback glyph.
        let r = DeviceReading(name: "Magic Mouse", classMajor: 0x05, address: "AA-BB-CC-DD-EE-FF", connected: true)
        XCTAssertEqual(deviceActivity(from: r), .connected(name: "Magic Mouse", glyph: .generic, battery: nil))
    }

    func testDisconnectedMapsToDisconnected() {
        // DEV-02 / D-03: same data, distinguished state — a disconnect → .disconnected.
        let r = DeviceReading(name: "AirPods Pro", classMajor: 0x04, address: "00-11-22-33-44-55", connected: false)
        XCTAssertEqual(deviceActivity(from: r), .disconnected(name: "AirPods Pro", glyph: .airpodsPro))
    }

    func testNilNameFallsBackToAddress() {
        // DEV-01/02 / Pitfall 3: nil name + non-nil address → the label falls back to the
        // address string; the glyph still resolves (audio class → .headphones).
        let r = DeviceReading(name: nil, classMajor: 0x04, address: "00-11-22-33-44-55", connected: true)
        XCTAssertEqual(deviceActivity(from: r), .connected(name: "00-11-22-33-44-55", glyph: .headphones, battery: nil))
    }

    func testNilNameAndNilAddressFallsBackToPlaceholder() {
        // Pitfall 3 worst case: nil name AND nil address → a non-empty placeholder label,
        // never empty/crash; an unknown peripheral → .generic glyph.
        let r = DeviceReading(name: nil, classMajor: 0x05, address: nil, connected: true)
        XCTAssertEqual(deviceActivity(from: r), .connected(name: "Bluetooth Device", glyph: .generic, battery: nil))
    }

    func testEmptyNameFallsBackToAddress() {
        // Pitfall 3: an empty (non-nil) name string must still fall back to the address,
        // never present an empty label.
        let r = DeviceReading(name: "", classMajor: 0x05, address: "AA-BB-CC-DD-EE-FF", connected: true)
        XCTAssertEqual(deviceActivity(from: r), .connected(name: "AA-BB-CC-DD-EE-FF", glyph: .generic, battery: nil))
    }

    // MARK: deviceActivity(from:) — battery threading (post-checkpoint, DEV-01)

    func testConnectedThreadsValidBattery() {
        // A connect carrying a valid battery % → it rides onto the .connected case for the wing's
        // BatteryIndicator (this is the Jabra path: IOBluetoothDevice.batteryPercentSingle).
        let r = DeviceReading(name: "Jabra Elite 8 Active", classMajor: 0x04,
                              address: "50-c2-75-65-8a-a4", connected: true, battery: 50)
        XCTAssertEqual(deviceActivity(from: r), .connected(name: "Jabra Elite 8 Active", glyph: .headphones, battery: 50))
    }

    func testConnectedDropsSentinelBatteryToNil() {
        // 0 / out-of-range is the common "no data" value for non-reporting devices — it must map to
        // nil so the view falls back to the connection sign, never renders a bogus 0%.
        for sentinel in [0, -1, 255, 1000] {
            let r = DeviceReading(name: "Mouse", classMajor: 0x05, address: "AA", connected: true, battery: sentinel)
            XCTAssertEqual(deviceActivity(from: r), .connected(name: "Mouse", glyph: .generic, battery: nil),
                           "battery \(sentinel) should be dropped to nil")
        }
    }

    func testBatteryBoundaryValuesKept() {
        // 1 and 100 are the inclusive valid bounds — both kept.
        let lo = DeviceReading(name: "X", classMajor: 0x04, address: "A", connected: true, battery: 1)
        let hi = DeviceReading(name: "X", classMajor: 0x04, address: "A", connected: true, battery: 100)
        XCTAssertEqual(deviceActivity(from: lo), .connected(name: "X", glyph: .headphones, battery: 1))
        XCTAssertEqual(deviceActivity(from: hi), .connected(name: "X", glyph: .headphones, battery: 100))
    }

    // MARK: deviceGlyph(name:classMajor:) — the D-02 name/class → glyph table

    func testGlyphAirPodsProMatchesBeforeAirPods() {
        // D-02: the more-specific "AirPods Pro" substring must win over the bare "AirPods".
        XCTAssertEqual(deviceGlyph(name: "Niklas' AirPods Pro", classMajor: 0x04), .airpodsPro)
    }

    func testGlyphAirPodsMaxMatches() {
        // D-02: "AirPods Max" → .airpodsMax.
        XCTAssertEqual(deviceGlyph(name: "AirPods Max", classMajor: 0x04), .airpodsMax)
    }

    func testGlyphPlainAirPodsMatches() {
        // D-02: a bare "AirPods" (no Pro/Max) → .airpods.
        XCTAssertEqual(deviceGlyph(name: "AirPods", classMajor: 0x04), .airpods)
    }

    func testGlyphBeatsMatches() {
        // D-02: a "Beats" name → .beats.
        XCTAssertEqual(deviceGlyph(name: "Beats Studio Pro", classMajor: 0x04), .beats)
    }

    func testGlyphAudioClassUnmatchedNameFallsToHeadphones() {
        // D-02: an audio-class device with an unmatched name → .headphones (generic audio).
        XCTAssertEqual(deviceGlyph(name: "Sony WH-1000XM5", classMajor: 0x04), .headphones)
    }

    func testGlyphPeripheralMapsToGeneric() {
        // D-01/D-02: a peripheral-class device (non-audio) → .generic (NOT gated out, just generic glyph).
        XCTAssertEqual(deviceGlyph(name: "Magic Keyboard", classMajor: 0x05), .generic)
    }

    func testGlyphUnknownNameMapsToGeneric() {
        // D-02: an unknown name + non-audio class → .generic fallback.
        XCTAssertEqual(deviceGlyph(name: "Some Random Gadget", classMajor: 0x00), .generic)
    }

    func testGlyphNilNameAudioClassFallsToHeadphones() {
        // Pitfall 3 + D-02: a nil name on an audio-class device still resolves to .headphones.
        XCTAssertEqual(deviceGlyph(name: nil, classMajor: 0x04), .headphones)
    }

    // MARK: deviceLabel(name:address:) — the nil-name fallback chain (Pitfall 3)

    func testLabelPrefersName() {
        XCTAssertEqual(deviceLabel(name: "AirPods Pro", address: "00-11-22-33-44-55"), "AirPods Pro")
    }

    func testLabelFallsBackToAddressWhenNameNil() {
        XCTAssertEqual(deviceLabel(name: nil, address: "00-11-22-33-44-55"), "00-11-22-33-44-55")
    }

    func testLabelFallsBackToPlaceholderWhenBothNil() {
        XCTAssertEqual(deviceLabel(name: nil, address: nil), "Bluetooth Device")
    }

    // MARK: shouldShowDeviceSplash(...) — D-04 at-launch burst + reconnect-flap debounce (pure)

    func testGenuinePostLaunchConnectSplashes() {
        // D-04: a device not in the at-launch suppression set, never seen before → splash.
        let show = shouldShowDeviceSplash(address: "00-11-22-33-44-55", connected: true,
                                          now: 100.0, lastShown: [:],
                                          debounce: 2.5, suppressedAtLaunch: [])
        XCTAssertTrue(show)
    }

    func testAtLaunchAlreadyConnectedDeviceSuppressed() {
        // D-04: a device in the at-launch "already connected" set firing connect → NO splash.
        let show = shouldShowDeviceSplash(address: "00-11-22-33-44-55", connected: true,
                                          now: 0.5, lastShown: [:],
                                          debounce: 2.5, suppressedAtLaunch: ["00-11-22-33-44-55"])
        XCTAssertFalse(show)
    }

    func testReconnectWithinDebounceWindowSuppressed() {
        // D-04 / Pitfall 2: a repeat connect for the SAME address within the debounce window → NO splash.
        let show = shouldShowDeviceSplash(address: "00-11-22-33-44-55", connected: true,
                                          now: 101.0, lastShown: ["00-11-22-33-44-55": 100.0],
                                          debounce: 2.5, suppressedAtLaunch: [])
        XCTAssertFalse(show)
    }

    func testReconnectAfterDebounceWindowSplashes() {
        // D-04: a connect for the SAME address AFTER the debounce window elapses → splash.
        let show = shouldShowDeviceSplash(address: "00-11-22-33-44-55", connected: true,
                                          now: 103.0, lastShown: ["00-11-22-33-44-55": 100.0],
                                          debounce: 2.5, suppressedAtLaunch: [])
        XCTAssertTrue(show)
    }

    func testDisconnectOfShownDeviceSplashes() {
        // DEV-02: a disconnect (outside any debounce window) → splash (the disconnect cue).
        let show = shouldShowDeviceSplash(address: "00-11-22-33-44-55", connected: false,
                                          now: 200.0, lastShown: [:],
                                          debounce: 2.5, suppressedAtLaunch: [])
        XCTAssertTrue(show)
    }

    func testFlappingDisconnectWithinWindowSuppressed() {
        // D-04 / Pitfall 2: a flapping disconnect for the SAME address within the window → NO splash.
        let show = shouldShowDeviceSplash(address: "00-11-22-33-44-55", connected: false,
                                          now: 201.0, lastShown: ["00-11-22-33-44-55": 200.0],
                                          debounce: 2.5, suppressedAtLaunch: [])
        XCTAssertFalse(show)
    }

    func testDisconnectNotSuppressedByAtLaunchSet() {
        // D-04: the at-launch suppression is for the CONNECT burst only; a genuine disconnect
        // of an at-launch device must still splash (the user removed it).
        let show = shouldShowDeviceSplash(address: "00-11-22-33-44-55", connected: false,
                                          now: 0.5, lastShown: [:],
                                          debounce: 2.5, suppressedAtLaunch: ["00-11-22-33-44-55"])
        XCTAssertTrue(show)
    }

    func testNilAddressConnectStillSplashes() {
        // A connect with a nil address (no identity to debounce on) → splash, never crash.
        let show = shouldShowDeviceSplash(address: nil, connected: true,
                                          now: 100.0, lastShown: [:],
                                          debounce: 2.5, suppressedAtLaunch: [])
        XCTAssertTrue(show)
    }
}
