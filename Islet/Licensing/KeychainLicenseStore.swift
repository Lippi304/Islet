import Foundation
import Security

// Phase 12 / LIC-02 + D-07/D-01 — the THIN Keychain persistence glue for the validated
// license. Mirrors Islet/Licensing/TrialManager.swift (KeychainStore/KeychainTrialStore/
// TrialManager) exactly: same SecItem* upsert shape, same injectable-protocol-seam +
// read-once-cache discipline. Only the service string and the stored value type change
// (a Codable LicenseRecord instead of a Date) — the whole point is that entitlement is
// NEVER a flippable Bool and NEVER UserDefaults (honors T-11-02 / T-12-01).

protocol LicenseStore {
    func read() -> LicenseRecord?
    @discardableResult func write(_ record: LicenseRecord) -> Bool
    func delete()
}

// The proof-of-purchase record persisted in the Keychain. NOT a bare Bool — status is a
// string so a missing/corrupt/non-"granted" record is indistinguishable from "not licensed".
struct LicenseRecord: Codable {
    let key: String
    let licenseID: String
    let status: String
    let validatedAt: Date
}

// The real Security-framework-backed implementation (survives `defaults delete` and app
// reinstall — a Keychain item is independent of the app bundle/plist lifecycle).
struct KeychainLicenseStore: LicenseStore {
    private let service = "com.lippi304.islet.license"
    private let account = "validatedLicense"

    func read() -> LicenseRecord? {
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
              let record = try? JSONDecoder().decode(LicenseRecord.self, from: data)
        else { return nil }
        return record
    }

    @discardableResult
    func write(_ record: LicenseRecord) -> Bool {
        guard let payload = try? JSONEncoder().encode(record) else { return false }
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

final class LicenseManager {
    static let shared = LicenseManager(store: KeychainLicenseStore())

    private let store: LicenseStore

    // Gap-closure precedent (TrialManager.swift lines 87-96): the persisted license read
    // must never sit on the hover/click hot path — cache after the first read so
    // updateVisibility() never triggers a live Keychain call (auth-prompt flood risk,
    // project memory 2401).
    private var cachedRecord: LicenseRecord?
    private var hasCachedRecord = false

    init(store: LicenseStore) {
        self.store = store
    }

    var isLicensed: Bool {
        if hasCachedRecord { return cachedRecord?.status == "granted" }
        let record = store.read()
        cachedRecord = record
        hasCachedRecord = true
        return record?.status == "granted"
    }

    @discardableResult
    func recordValidation(key: String, validated: ValidatedLicense) -> Bool {
        let record = LicenseRecord(key: key, licenseID: validated.id, status: validated.status, validatedAt: Date())
        let wrote = store.write(record)
        cachedRecord = record
        hasCachedRecord = true
        return wrote
    }

    #if DEBUG
    func debugResetLicense() {
        store.delete()
        cachedRecord = nil
        hasCachedRecord = false
    }
    #endif
}
