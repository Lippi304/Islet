import Foundation

// Phase 5 / DEV-01 + DEV-02 — the PURE device→presentation seam (Pattern 1).
//
// Like PowerActivity and NowPlayingPresentation, these are plain values + total
// functions importing ONLY Foundation — no system frameworks (no IOBluetooth, AppKit,
// or SwiftUI here; that wiring lives in Plan 02's BluetoothMonitor + Plan 03's wings
// branch). Tests build DeviceReading by hand, so the riskiest classification logic
// (connected vs disconnected, the name/class→glyph table, the nil-name fallback chain,
// the D-04 at-launch burst suppression + reconnect-flap debounce) is unit-tested in
// milliseconds (RED→GREEN). Plan 02 owns the real IOBluetooth connect/disconnect
// notifications and lifts a DeviceReading out of the callbacks to feed in here.
//
// SECURITY (T-05-01): `name` is UNTRUSTED external input — an attacker-controllable
// string supplied by a remote/paired Bluetooth device. deviceLabel returns it as a
// plain String only; it is NEVER interpolated into a format string or shell. The
// SwiftUI Text in Plan 03 bounds it (.lineLimit(1) + .truncationMode(.tail)).

// The minimal raw reading BluetoothMonitor (Plan 02) lifts out of the IOBluetooth
// connect/disconnect callbacks. Plain values so tests construct it by hand.
struct DeviceReading: Equatable {
    let name: String?        // device.name — UNTRUSTED, may be nil/empty/stale (Pitfall 3)
    let classMajor: UInt32   // device.deviceClassMajor — 0x04 audio / 0x05 peripheral (glyph only)
    let address: String?     // device.addressString — the debounce/identity key
    let connected: Bool      // true = connect notification, false = disconnect (DEV-02)
    // Phase 6 (post-checkpoint): the connected device's battery %, lifted from
    // IOBluetoothDevice.batteryPercentSingle by BluetoothMonitor. nil when the device does not
    // report a battery (most non-Apple HID; many HFP devices DO report it, e.g. Jabra) — the
    // view falls back to a plain connection sign. Only meaningful when `connected == true`.
    var battery: Int? = nil
}

// The device glyph the wings splash renders. D-02: as specific as the device allows,
// with .generic as the universal fallback (Pitfall 7 — a missing SF Symbol is cosmetic).
enum DeviceGlyph: Equatable {
    case airpods       // bare AirPods
    case airpodsPro    // AirPods Pro
    case airpodsMax    // AirPods Max
    case headphones    // any other audio-class device (Sony, generic over-ear, etc.)
    case beats         // Beats-branded
    case generic       // mice, keyboards, controllers, unknown — the D-02 fallback
}

// The presentation the splash renders (D-03: one layout, two distinguished states).
enum DeviceActivity: Equatable {
    case connected(name: String, glyph: DeviceGlyph, battery: Int?)  // active icon + optional battery %
    case disconnected(name: String, glyph: DeviceGlyph)              // dimmed/"Disconnected" state (DEV-02)
}

// The nil-name fallback chain (Pitfall 3): name → address → "Bluetooth Device".
// `name` is UNTRUSTED (T-05-01) — returned as a plain String only, never format/shell.
func deviceLabel(name: String?, address: String?) -> String {
    if let name, !name.isEmpty { return name }
    if let address, !address.isEmpty { return address }
    return "Bluetooth Device"
}

// The D-02 name/class → glyph table (case-insensitive substring match). D-01: the class
// is used ONLY to pick the glyph here, NEVER to gate whether a splash happens. The
// more-specific names ("airpods pro"/"airpods max") are matched before the bare "airpods".
func deviceGlyph(name: String?, classMajor: UInt32) -> DeviceGlyph {
    let n = (name ?? "").lowercased()
    if n.contains("airpods pro") { return .airpodsPro }
    if n.contains("airpods max") { return .airpodsMax }
    if n.contains("airpods")     { return .airpods }
    if n.contains("beats")       { return .beats }
    if classMajor == 0x04        { return .headphones }  // kBluetoothDeviceClassMajorAudio
    return .generic
}

// TOTAL pure mapping. Per D-01 every device is presentable, so this never returns nil in
// practice — the optional mirrors powerActivity(from:) and leaves room for a future filter.
func deviceActivity(from r: DeviceReading) -> DeviceActivity? {
    let label = deviceLabel(name: r.name, address: r.address)
    let glyph = deviceGlyph(name: r.name, classMajor: r.classMajor)
    // A battery reading is only meaningful on connect; a sentinel/out-of-range value is dropped
    // to nil here so the view's "has battery?" check is a simple optional test (DEV-01).
    let battery = (r.battery.map { (1...100).contains($0) } == true) ? r.battery : nil
    return r.connected
        ? .connected(name: label, glyph: glyph, battery: battery)
        : .disconnected(name: label, glyph: glyph)
}

// Pure D-04 burst/debounce predicate — a total function of its arguments. NO Date()/Timer/
// clock read inside (callers pass `now`); the last-shown timestamps are passed in, not
// polled. This preserves the deterministic ms tests and the no-polling guarantee.
//
//   - A connect for an address in `suppressedAtLaunch` → false (D-04 at-launch/wake burst).
//     This applies to CONNECT events only — a genuine disconnect of an at-launch device still
//     splashes (the user removed it).
//   - A repeat connect/disconnect for the SAME address within `debounce` of its last splash
//     → false (D-04 reconnect-flap debounce).
//   - Otherwise → true.
func shouldShowDeviceSplash(address: String?,
                            connected: Bool,
                            now: TimeInterval,
                            lastShown: [String: TimeInterval],
                            debounce: TimeInterval,
                            suppressedAtLaunch: Set<String>) -> Bool {
    if let address {
        if connected && suppressedAtLaunch.contains(address) { return false }
        if let last = lastShown[address], now - last < debounce { return false }
    }
    return true
}
