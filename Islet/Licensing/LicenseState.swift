import Foundation

// Phase 10 / TRIAL-01 + LIC-03 — app-wide license/trial status, the single source
// of truth NotchWindowController (Plan 02) and AppDelegate/SettingsView (Plan 03)
// read. Only a DEBUG override can produce `.licensed` in this phase — the real
// Polar.sh validation path is Phase 12; this is intentionally just the stub shape.
//
// Per Pitfall 4, the DEBUG override is gated on BOTH sides: the constants/enum
// below AND the read-site inside `status` (mirrors NotchWindowController.swift's
// `didLogFirstHover` discipline — the whole probe, not just its trigger, is
// compiled out of Release).

enum LicenseStatus: Equatable {
    case trial(daysRemaining: Int)
    case trialExpired
    case licensed
}

final class LicenseState {
    static let shared = LicenseState()

    private init() {}

    #if DEBUG
    static let debugOverrideKey = "debug.licenseOverride"

    enum DebugOverride: String {
        case forceExpired
        case forceLicensed
    }
    #endif

    var status: LicenseStatus {
        #if DEBUG
        if let raw = UserDefaults.standard.string(forKey: Self.debugOverrideKey),
           let override = DebugOverride(rawValue: raw) {
            switch override {
            case .forceExpired: return .trialExpired
            case .forceLicensed: return .licensed
            }
        }
        #endif

        guard let start = TrialManager.shared.trialStartDate() else {
            // Should not happen after recordFirstLaunchIfNeeded() has run, but never
            // crash on unexpected state — default to a fresh, fully active trial.
            return .trial(daysRemaining: 3)
        }

        switch trialStatus(startDate: start, now: Date(), trialLength: TrialManager.trialLength) {
        case .active(let daysRemaining):
            return .trial(daysRemaining: daysRemaining)
        case .expired:
            return .trialExpired
        }
    }

    var isEntitled: Bool {
        switch status {
        case .trial, .licensed: return true
        case .trialExpired: return false
        }
    }

    var trialExpiryDate: Date? {
        TrialManager.shared.trialStartDate()?.addingTimeInterval(TrialManager.trialLength)
    }
}
