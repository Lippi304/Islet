import Foundation

// Phase 3 / CHG-01 + CHG-02 — the PURE power→presentation seam (Pattern 1).
//
// Like NotchGeometry and NotchInteractionState, these are plain values + total
// functions importing ONLY Foundation — no system frameworks (no IOKit, AppKit, or
// SwiftUI here; that wiring lives in Plan 03). Tests build
// PowerReading by hand, so the riskiest classification logic (charging vs full vs
// on-battery vs no-battery, percent clamping, splash debounce) is unit-tested in
// milliseconds. Plan 03 owns the real IOPS read + run-loop source and lifts a
// PowerReading out of the IOPS dictionary to feed in here.

// The minimal raw reading PowerSourceMonitor (Plan 03) lifts out of the IOPS dict.
// Plain values so tests construct it by hand (mirrors ScreenDescriptor's role).
struct PowerReading: Equatable {
    let isPresent: Bool      // false → no readable battery (desktop / empty source list)
    let isOnAC: Bool         // kIOPSPowerSourceStateKey == "AC Power"
    let isCharging: Bool     // kIOPSIsChargingKey
    let isCharged: Bool      // kIOPSIsChargedKey (true at full on AC)
    let percent: Int         // 0...100, clamped
}

// The presentation the splash renders (D-04: one glyph, three states).
enum ChargingActivity: Equatable {
    case charging(percent: Int)   // on AC, actively charging → bolt glyph
    case full(percent: Int)       // on AC, charged / plugged-but-full → full (green) glyph
    case onBattery(percent: Int)  // unplugged → plain battery glyph (CHG-02)
}

// TOTAL pure mapping. nil == "no splash" (no readable battery → graceful no-op).
//
// 36-01 on-device UAT round 3 — root cause confirmed via real hardware trace: macOS's
// "Optimized Battery Charging" (battery health management) can hold `kIOPSIsChargingKey`
// false for the ENTIRE time a Mac sits on AC below 100%, not just a brief connect-negotiation
// beat (that was round 2's — wrong — hypothesis, see the removed 0.6s settle re-poll). Apple's
// own menu-bar battery icon shows this same "connected, not actively drawing charge current"
// state with no bolt overlay, so the raw IOKit flag is a poor proxy for what the user means by
// "charging". Product decision from that trace: show "Charging" whenever plugged into AC and
// not yet topped off, keyed off `isCharged` (kIOPSIsChargedKey — "is the battery full") rather
// than the flaky `isCharging` (kIOPSIsChargingKey — "is current actively flowing right now").
func powerActivity(from r: PowerReading) -> ChargingActivity? {
    guard r.isPresent else { return nil }
    let p = min(max(r.percent, 0), 100)
    if r.isOnAC {
        if r.isCharged { return .full(percent: p) }
        return .charging(percent: p)
    }
    return .onBattery(percent: p)
}

// Pure CONNECT-edge predicate: true ONLY when the device transitions from not-on-AC
// (no reading or on battery) to on-AC (charging or full) — i.e. the user just plugged in
// the charger. Product decision from on-device UAT: the splash fires ONLY on connect, NOT
// on unplug, and NOT on within-AC changes (charging↔full as the battery tops off). So:
//   onBattery / none  → charging / full  → fire   (connect — the only animated moment)
//   charging / full   → onBattery        → no fire (unplug — CHG-02's on-battery cue dropped)
//   charging ↔ full   → no fire (still plugged; reaching/leaving full is not a new connect)
//   activity → nil    → no fire (clearing a standing splash is not a new splash)
func shouldTriggerSplash(previous: ChargingActivity?, next: ChargingActivity?) -> Bool {
    isOnAC(next) && !isOnAC(previous)
}

// A charging/full presentation means the adapter is connected; onBattery / no reading is not.
private func isOnAC(_ activity: ChargingActivity?) -> Bool {
    switch activity {
    case .charging, .full: return true
    case .onBattery, .none: return false
    }
}
