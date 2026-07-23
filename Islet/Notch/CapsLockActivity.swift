import Foundation

// Phase 60 / CAPS-01 — the PURE caps-lock→presentation seam (Pattern 1).
//
// Like FocusActivity and OSDActivity, this is a plain value + a total mapping function
// importing ONLY Foundation — no AppKit/NSEvent. CapsLockMonitor.swift (system glue, a
// later Plan 60 wave) is the ONLY caller; it owns the real NSEvent-based caps-lock
// detection and lifts a Bool in here.

// The presentation the collapsed HUD renders. TWO cases (unlike FocusActivity's single
// `.on`) — D-03 requires both ON and OFF states to render their own HUD.
enum CapsLockActivity: Equatable {
    case on
    case off
}

// TOTAL pure mapping. Every toggle produces a HUD — no nil "no-op" case (unlike
// focusActivity(from:), which returns nil for "no HUD").
func capsLockActivity(isOn: Bool) -> CapsLockActivity {
    isOn ? .on : .off
}
