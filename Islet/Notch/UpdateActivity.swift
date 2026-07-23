import Foundation

// Phase 60 / UPDATE-01 — the PURE update-available presentation seam (Pattern 1).
//
// Like FocusActivity and OSDActivity, this is a plain value importing ONLY Foundation —
// no Sparkle. AppDelegate.swift's SPUUpdaterDelegate callback (a later Plan 60 wave) is
// the ONLY caller; it lifts `SUAppcastItem.displayVersionString` into `version` here
// (D-04). Net-new to this phase — not a reskin of any deleted Phase 40 code.
struct UpdateActivity: Equatable {
    let version: String
}
