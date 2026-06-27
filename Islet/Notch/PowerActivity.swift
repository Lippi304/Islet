import Foundation

// Phase 3 / CHG-01 + CHG-02 — the PURE power→presentation seam (Pattern 1).
//
// Like NotchGeometry and NotchInteractionState, these are plain values + total
// functions: NO `import IOKit`, NO `import AppKit`, NO `import SwiftUI`. Tests build
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
    return nil // RED placeholder — implemented in GREEN
}

// Pure splash-debounce predicate (Pitfall 4): true only when the CATEGORY changed
// (charging/full/onBattery, ignoring the percent number), so a pure % tick within the
// same category does NOT re-fire a splash.
func shouldTriggerSplash(previous: ChargingActivity?, next: ChargingActivity?) -> Bool {
    return false // RED placeholder — implemented in GREEN
}
