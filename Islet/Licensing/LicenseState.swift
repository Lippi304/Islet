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

// Phase 15 / P15-ITEM4 — DI seam mirroring TrialManager/LicenseManager's own
// protocol-typed collaborator pattern. These extensions keep LicenseManager.swift
// and TrialManager.swift untouched; the protocols exist solely so LicenseState's
// precedence logic is testable with fakes instead of only on-device.
protocol LicenseManaging: AnyObject {
    var isLicensed: Bool { get }
}

protocol TrialStatusProviding: AnyObject {
    func trialStartDate() -> Date?
}

extension LicenseManager: LicenseManaging {}
extension TrialManager: TrialStatusProviding {}

final class LicenseState {
    static let shared = LicenseState()

    private let licenseManager: LicenseManaging
    private let trialManager: TrialStatusProviding

    init(licenseManager: LicenseManaging = LicenseManager.shared, trialManager: TrialStatusProviding = TrialManager.shared) {
        self.licenseManager = licenseManager
        self.trialManager = trialManager
    }

    // Phase 11 / TRIAL-03 — in-memory session entitlement. Set to `true` by the
    // SettingsView activate flow (Plan 02) after StubLicenseService returns `.success`.
    // INTENTIONALLY NOT persisted to UserDefaults/Keychain this phase (T-11-02 / Pitfall 1):
    // a stored bool is a trivially-flippable entitlement bypass, so the flag resets to
    // `false` on every launch. Real persisted entitlement is Phase 12's concern.
    var sessionActivated = false

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

        // Phase 12 / LIC-02 — persisted (survives-relaunch, offline) entitlement. Sits AFTER
        // the DEBUG override and BEFORE sessionActivated so a real activation's Keychain
        // record is honored even without an in-memory session flag (e.g. after relaunch).
        // LicenseManager reads the Keychain ONCE and caches in memory, so this hot-path read
        // (updateVisibility()) never re-hits the Keychain (memory 2401 flood mitigation).
        if licenseManager.isLicensed { return .licensed }

        // TRIAL-03: in-memory session activation short-circuits to .licensed. Sits AFTER
        // the DEBUG override (so forceExpired/forceLicensed still win in dev) and BEFORE the
        // trial computation. `isEntitled` already maps `.licensed → true`, so no change there.
        if sessionActivated { return .licensed }

        guard let start = trialManager.trialStartDate() else {
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
        trialManager.trialStartDate()?.addingTimeInterval(TrialManager.trialLength)
    }
}
