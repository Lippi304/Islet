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
func powerActivity(from r: PowerReading) -> ChargingActivity? {
    guard r.isPresent else { return nil }
    let p = min(max(r.percent, 0), 100)
    if r.isOnAC {
        if r.isCharging { return .charging(percent: p) }
        return .full(percent: p)
    }
    return .onBattery(percent: p)
}

// Category of an activity, IGNORING the percent number. nil maps to .none so the
// debounce can compare "kind of splash" without re-firing on every percent tick.
private enum SplashCategory: Equatable { case none, charging, full, onBattery }

private func splashCategory(_ activity: ChargingActivity?) -> SplashCategory {
    switch activity {
    case .none:           return .none
    case .charging:       return .charging
    case .full:           return .full
    case .onBattery:      return .onBattery
    }
}

// Pure splash-debounce predicate (Pitfall 4): true only when the CATEGORY changed
// (charging/full/onBattery, ignoring the percent number), so a pure % tick within the
// same category does NOT re-fire a splash. A nil→activity edge fires (first real
// reading); an activity→nil edge does NOT (clearing the splash is not a new splash).
func shouldTriggerSplash(previous: ChargingActivity?, next: ChargingActivity?) -> Bool {
    let prev = splashCategory(previous)
    let nextCat = splashCategory(next)
    return prev != nextCat && nextCat != .none
}
