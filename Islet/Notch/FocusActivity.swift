import Foundation

// Phase 38 / HUD-05 — the PURE focus→presentation seam (Pattern 1).
//
// Like PowerActivity and DeviceActivity, this is a plain value + a total mapping
// function importing ONLY Foundation — no Intents, no FileManager, no system
// frameworks. FocusModeMonitor.swift (system glue, Plan 38-03) is the ONLY caller;
// it owns the real Focus-status detection and lifts a Bool in here.

// The presentation the collapsed HUD renders. Deliberately a single case — no named-
// mode payload (per REQUIREMENTS.md's Out of Scope table) and no `.off` case (D-09:
// Focus Off has no distinct rendered state, so there is nothing to represent).
enum FocusActivity: Equatable {
    case on
}

// TOTAL pure mapping. nil == "no HUD" (mirrors powerActivity(from:)'s "nil is a
// legitimate no-op result" convention).
func focusActivity(from isFocused: Bool) -> FocusActivity? {
    isFocused ? .on : nil
}
