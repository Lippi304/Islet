import Foundation
import Security
import CryptoKit

// Phase 56 / D-05 — the Keychain persistence glue for the clipboard's AES-256
// SymmetricKey. Mirrors Islet/Licensing/KeychainLicenseStore.swift's SecItem
// read/write shape exactly, with one deliberate divergence: this key is
// device-only (kSecAttrSynchronizable = false), since clipboard content is
// personal and this milestone has no cross-Mac sync mechanism, whereas the
// license key is fine to sync (tied to a purchase, not private data).
struct KeychainClipboardKeyStore {
    private let service = "com.lippi304.islet.clipboard"
    private let account = "encryptionKey"

    func read() -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return SymmetricKey(data: data)
    }

    @discardableResult
    func write(_ key: SymmetricKey) -> Bool {
        let payload = key.withUnsafeBytes { Data($0) }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = payload
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        attributes[kSecAttrSynchronizable as String] = false
        return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
    }

    func readOrCreateKey() -> SymmetricKey {
        if let existing = read() { return existing }
        let newKey = SymmetricKey(size: .bits256)
        write(newKey)
        return newKey
    }
}
