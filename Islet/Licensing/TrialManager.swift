import Foundation
import Security

// Phase 10 / TRIAL-01 + D-10 — the THIN Keychain persistence glue.
//
// This is the ONLY file in the phase that touches `Security`/`kSecClass*`. Like
// PowerSourceMonitor.swift (the ONLY file that touches a system power framework),
// it is a thin system-call wrapper — NOT a pure fixture-tested seam; the real
// KeychainTrialStore Security-framework calls are verified on-device, while the
// injectable KeychainStore protocol seam here makes the surrounding BOOLEAN LOGIC
// (first-launch detection, earliest-of-two reconciliation) unit-testable with a
// fake in-memory store (TrialManagerTests.swift), never touching real Keychain I/O
// during automated test runs.

protocol KeychainStore {
    func read() -> Date?
    @discardableResult func write(_ date: Date) -> Bool
    func delete()
}

// The real Security-framework-backed implementation (D-10: survives `defaults delete`
// and app reinstall — a Keychain item is independent of the app bundle/plist lifecycle).
struct KeychainTrialStore: KeychainStore {
    private let service = "com.lippi304.islet.trial"
    private let account = "trialStartDate"

    func read() -> Date? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        // DEFENSIVE: every optional cast has a graceful nil-fallback — a missing or
        // malformed Keychain item never force-unwraps or crashes.
        guard status == errSecSuccess,
              let data = result as? Data,
              let timestamp = TimeInterval(String(data: data, encoding: .utf8) ?? "")
        else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }

    @discardableResult
    func write(_ date: Date) -> Bool {
        guard let payload = String(date.timeIntervalSince1970).data(using: .utf8) else { return false }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        // Delete-then-add is the simplest correct upsert for a single-item store (no
        // update-vs-add branching); this write happens once per app lifetime so
        // simplicity wins over efficiency.
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = payload
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
    }

    func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

final class TrialManager {
    static let shared = TrialManager(keychain: KeychainTrialStore())

    // D-09: the SOLE authoritative trial length, identical in DEBUG and Release —
    // no shortened DEBUG variant is ever introduced. debugResetTrial() (reset only)
    // is the sole DEBUG testing seam.
    static let trialLength: TimeInterval = 3 * 86400

    private static let mirrorKey = "trialStartDateMirror"

    private let keychain: KeychainStore
    private let defaults: UserDefaults

    // Gap closure (Plan 10-04 manual verification): the trial start date is immutable
    // for the life of the process (aside from the two write points below), but
    // `updateVisibility()` reads `LicenseState.isEntitled` on every hover/click/drag —
    // far more often than the "rare system notification" frequency this file's
    // original design assumed. On an ad-hoc-signed dev build, that burst of live
    // Keychain reads each independently triggered a macOS authorization prompt,
    // producing an unusable flood. Caching after the first read removes the Keychain
    // call from the hot path entirely; both write points below keep the cache in sync.
    private var cachedStartDate: Date?
    private var hasCachedStartDate = false

    init(keychain: KeychainStore, defaults: UserDefaults = .standard) {
        self.keychain = keychain
        self.defaults = defaults
    }

    // Pitfall 5: when both stores disagree, the EARLIEST of the two known dates wins
    // for enforcement — a user editing only the UserDefaults mirror to a later date
    // can never extend the trial that way.
    func trialStartDate() -> Date? {
        if hasCachedStartDate { return cachedStartDate }

        let keychainDate = keychain.read()
        let mirrorDate = (defaults.object(forKey: Self.mirrorKey) as? Double).map(Date.init(timeIntervalSince1970:))

        let resolved: Date?
        switch (keychainDate, mirrorDate) {
        case let (.some(k), .some(m)):
            resolved = min(k, m)
        case let (.some(k), .none):
            resolved = k
        case let (.none, .some(m)):
            resolved = m
        case (.none, .none):
            resolved = nil
        }

        cachedStartDate = resolved
        hasCachedStartDate = true
        return resolved
    }

    @discardableResult
    func recordFirstLaunchIfNeeded(now: Date = Date()) -> Bool {
        guard trialStartDate() == nil else { return false }
        keychain.write(now)
        defaults.set(now.timeIntervalSince1970, forKey: Self.mirrorKey)
        cachedStartDate = now
        hasCachedStartDate = true
        return true
    }

    #if DEBUG
    // DEBUG-only testing seam (D-09): reset, never a shortened trial length.
    func debugResetTrial() {
        keychain.delete()
        defaults.removeObject(forKey: Self.mirrorKey)
        cachedStartDate = nil
        hasCachedStartDate = false
    }
    #endif
}
