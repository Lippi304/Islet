import Foundation

// Phase 11 / TRIAL-03 — the license-activation SEAM. This mirrors the
// `NowPlayingService` protocol-isolation convention (NowPlayingMonitor.swift:35-47):
// a fragile/replaceable external is quarantined behind ONE `AnyObject` protocol with a
// single `final class` conformer, and every caller holds the PROTOCOL type — never the
// concrete class. Phase 12's real `PolarLicenseService` (URLSession → Polar.sh) is then a
// one-file drop-in with ZERO protocol change.
//
// CONTRACT — completion is ALWAYS delivered on the MAIN thread. This stub already runs
// on main (it completes via `DispatchQueue.main.asyncAfter`); Phase 12's URLSession
// implementation MUST hop back to main before calling `completion`. Callers (SettingsView,
// Plan 02) rely on this to mutate SwiftUI `@State`/`LicenseState` without a manual main-hop.
//
// SECURITY — the `ISLET-DEMO-OK` magic key (D-05) is a DEBUG-only SCAFFOLD, not a shipped
// credential (threat T-11-01). The comparison is `#if DEBUG`-gated: in a Release build the
// scaffold does nothing and every key is rejected. Phase 12 REPLACES this entire file with
// `PolarLicenseService` before Phase 13 distribution, so the scaffold never ships. The key
// string is treated as an opaque untrusted input (T-11-03): trim + `==` compare only, never
// interpolated into any shell/URL/logging sink.
//
// PURITY — `StubLicenseService.activate` returns a verdict and does NOT mutate
// `LicenseState.shared`. The state flip is the caller's job (SettingsView completion
// closure, Plan 02), mirroring the monitor→controller split (NowPlayingMonitor emits,
// NotchWindowController mutates). Keeping the stub free of singleton side effects makes it
// deterministically unit-testable (LicenseServiceTests.swift).

enum LicenseActivationError: Error, Equatable {
    case invalidKey
    // The stub NEVER emits `.unreachable`; it exists NOW so Phase 12's real network path
    // (timeouts / offline) needs ZERO protocol change to report a transport failure (D-05).
    case unreachable(String)
}

/// The real payload validated by the server (or the DEBUG stub) on a successful activation.
/// Phase 15 / D-03: widened from a bare `Void` so the caller can persist what was actually
/// validated instead of fabricating a placeholder (`Islet/Licensing/KeychainLicenseStore.swift`).
struct ValidatedLicense: Equatable {
    let id: String
    let status: String
    let expiresAt: String?
}

protocol LicenseService: AnyObject {
    /// Validate `key` and report the verdict.
    /// - Note: `completion` is ALWAYS delivered on the MAIN thread (contract — see file header).
    func activate(key: String, completion: @escaping (Result<ValidatedLicense, LicenseActivationError>) -> Void)
}

final class StubLicenseService: LicenseService {
    // D-05 magic key — DEBUG scaffold only (see file header / T-11-01).
    static let validKey = "ISLET-DEMO-OK"

    func activate(key: String, completion: @escaping (Result<ValidatedLicense, LicenseActivationError>) -> Void) {
        // D-06: observable ~1s simulated round-trip. This one-shot also GUARANTEES the
        // completion fires on the main thread (mirrors NowPlayingMonitor.swift:107-111).
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            #if DEBUG
            // Opaque untrusted input (T-11-03): trim whitespace, then a plain `==` compare.
            let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
            let verdict: Result<ValidatedLicense, LicenseActivationError> =
                trimmed == Self.validKey
                    ? .success(ValidatedLicense(id: "", status: "granted", expiresAt: nil))
                    : .failure(.invalidKey)
            #else
            // T-11-01: the magic-key scaffold is compiled OUT of Release — nothing validates.
            let verdict: Result<ValidatedLicense, LicenseActivationError> = .failure(.invalidKey)
            #endif
            completion(verdict)
        }
    }
}
