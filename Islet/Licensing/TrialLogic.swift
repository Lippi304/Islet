import Foundation

// Phase 10 / TRIAL-01 + D-10 — the PURE trial-classification seam (Pattern 1).
//
// Like PowerActivity.swift's powerActivity(from:), this is a plain enum + a total
// function importing ONLY Foundation — no Security/Keychain, no AppKit/SwiftUI here.
// `now` is ALWAYS a passed-in parameter, never an internal system-clock read, so the
// riskiest classification logic (the exact 3-day active/expired boundary) is
// unit-tested in milliseconds. TrialManager.swift (the Keychain-backed glue this
// file is wrapped by) owns the real Keychain read and lifts a start date out to
// feed in here.

enum TrialStatus: Equatable {
    case active(daysRemaining: Int)
    case expired
}

// TOTAL pure mapping. The boundary is exclusive: elapsed must be STRICTLY less
// than trialLength to remain active (elapsed == trialLength is already expired).
// daysRemaining is always rounded up and clamped to a minimum of 1 so an
// almost-elapsed-but-still-active trial never displays "0 days remaining".
func trialStatus(startDate: Date, now: Date, trialLength: TimeInterval) -> TrialStatus {
    let elapsed = now.timeIntervalSince(startDate)
    guard elapsed < trialLength else { return .expired }
    let remaining = trialLength - elapsed
    let days = Int((remaining / 86400).rounded(.up))
    return .active(daysRemaining: max(days, 1))
}
