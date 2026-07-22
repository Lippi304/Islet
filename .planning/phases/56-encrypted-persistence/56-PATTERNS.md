# Phase 56: Encrypted Persistence - Pattern Map

**Mapped:** 2026-07-22
**Files analyzed:** 4 (2 required, 2 optional-per-research)
**Analogs found:** 4 / 4

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|-----------------|---------------|
| `Islet/Clipboard/ClipboardFileStore.swift` | service (file I/O) | file-I/O | `Islet/Shelf/ShelfFileStore.swift` | exact (same shape: standalone enum, hardened delete under root, injectable `root:` param) |
| `Islet/Clipboard/KeychainClipboardKeyStore.swift` | service (Keychain I/O) | CRUD (upsert/read/delete single item) | `Islet/Licensing/KeychainLicenseStore.swift` | exact (same SecItem query/upsert shape, only payload type differs) |
| `IsletTests/ClipboardFileStoreTests.swift` | test | file-I/O | `IsletTests/ShelfFileStoreTests.swift` | exact (fixturesDir setUp/tearDown convention, real-disk-I/O test shape) |
| `IsletTests/KeychainClipboardKeyStoreTests.swift` (optional, research-recommended) | test | CRUD | `IsletTests/ShelfFileStoreTests.swift` (structure) + `KeychainLicenseStore` (subject) | role-match |

No `ClipboardItemRecord` type is listed as a separate file — RESEARCH.md's "Recommended Project Structure" allows nesting it inside `ClipboardFileStore.swift`; treat it as part of that file, not a separate pattern target.

## Pattern Assignments

### `Islet/Clipboard/ClipboardFileStore.swift` (service, file-I/O)

**Analog:** `Islet/Shelf/ShelfFileStore.swift` (57 lines, read in full)

**Imports pattern** (line 1):
```swift
import Foundation
```
Add `import CryptoKit` for AES.GCM/SymmetricKey (new to this file, no precedent needed — API is stable/small per RESEARCH.md).

**File header comment convention** (lines 3-8 of `ShelfFileStore.swift`):
```swift
// Phase 19 / SHELF-08 (D-03/D-04/D-05) — the ONE place in the codebase that performs
// real FileManager/NSTemporaryDirectory() I/O for the shelf (19-PATTERNS.md confirmed
// zero prior art), kept as a small standalone helper (not a method on ShelfLogic) so
// ShelfLogic itself stays a pure, side-effect-free reducer — mirrors how
// DeviceCoordinator performs IOBluetooth IO around TransientQueue's pure calls rather
// than putting IO inside TransientQueue itself.
```
`ClipboardFileStore.swift` should open with an equivalent header citing Phase 56/D-04/D-05/D-06 and explicitly stating `ClipboardStore` stays pure (mirrors this rationale, adapted).

**Standalone enum + static funcs, no stored state** (lines 13, 20, 49 shape):
```swift
enum ShelfFileStore {
    static func makeSessionCopy(of sourceURL: URL, id: UUID) throws -> URL { ... }
    static func deleteSessionCopy(at localURL: URL) { ... }
}
```
`ClipboardFileStore` mirrors this exactly: `enum ClipboardFileStore { static func load(root:key:) -> [ClipboardItem]; static func save(_:root:key:) throws; ... }`. The `root: URL` parameter is what makes SC#1's injectable-root test possible (RESEARCH.md Pattern 1) — do not hardcode the Application Support URL inside `load`/`save` themselves; pass it in, with a separate `static func storageRoot() -> URL` for production call sites (see RESEARCH.md Code Examples, lines 264-269).

**Hardened delete-under-root guard** (lines 49-56, the exact pattern D-06/SC#3 must mirror):
```swift
static func deleteSessionCopy(at localURL: URL) {
    let itemDir = localURL.deletingLastPathComponent().standardizedFileURL
    let shelfRoot = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("IsletShelf", isDirectory: true)
        .standardizedFileURL
    guard itemDir.path.hasPrefix(shelfRoot.path + "/") else { return }
    try? FileManager.default.removeItem(at: itemDir)
}
```
Copy this shape verbatim for the orphaned-image-file cleanup (D-06): standardize both the target file path and the `root` parameter passed into `save`, guard with `hasPrefix(root.path + "/")` before any `removeItem`, and make the delete non-throwing (`try?`) — a URL outside the root (or an already-gone file) is a silent no-op, never an error. Note: `ClipboardFileStore` validates individual **files** under `images/`, not whole `<uuid>/` directories like Shelf does — adapt the guard to the file-level target, same prefix-check logic.

**Path-traversal-safe filename validation** (lines 20-24, only relevant if any filename is derived from untrusted input — RESEARCH.md's Security Domain table notes this phase has no untrusted external input, so this specific guard is likely NOT needed verbatim, but the *principle* — validate before constructing any destination path — still applies to the `item.id.uuidString` → filename mapping):
```swift
let filenameComponent = sourceURL.lastPathComponent
guard filenameComponent != ".", filenameComponent != "..", !filenameComponent.isEmpty else {
    throw ShelfFileStoreError.invalidFilename
}
```

---

### `Islet/Clipboard/KeychainClipboardKeyStore.swift` (service, CRUD/Keychain)

**Analog:** `Islet/Licensing/KeychainLicenseStore.swift` (119 lines, read in full)

**Imports pattern** (lines 1-2):
```swift
import Foundation
import Security
```
Add `import CryptoKit` for `SymmetricKey`.

**Service/account constants + struct shape** (lines 28-30):
```swift
struct KeychainLicenseStore: LicenseStore {
    private let service = "com.lippi304.islet.license"
    private let account = "validatedLicense"
```
Mirror with `service = "com.lippi304.islet.clipboard"` and an account name like `"encryptionKey"` (matches RESEARCH.md Pattern 3 exactly, already drafted there).

**Read with defensive nil-fallback chain** (lines 32-49):
```swift
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
    guard status == errSecSuccess,
          let data = result as? Data,
          let record = try? JSONDecoder().decode(LicenseRecord.self, from: data)
    else { return nil }
    return record
}
```
For the key store, swap the final decode step for `SymmetricKey(data:)` construction (no JSON needed — raw bytes only, per RESEARCH.md's anti-pattern warning against a `Codable` wrapper struct):
```swift
guard status == errSecSuccess, let data = result as? Data else { return nil }
return SymmetricKey(data: data)
```

**Delete-then-add upsert** (lines 51-67):
```swift
@discardableResult
func write(_ record: LicenseRecord) -> Bool {
    guard let payload = try? JSONEncoder().encode(record) else { return false }
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecAttrAccount as String: account
    ]
    SecItemDelete(query as CFDictionary)
    var attributes = query
    attributes[kSecValueData as String] = payload
    attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
    return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
}
```
Reuse verbatim except the payload comes from `key.withUnsafeBytes { Data($0) }` instead of `JSONEncoder().encode`, and **add** `attributes[kSecAttrSynchronizable as String] = false` before the `SecItemAdd` call — this is D-05's explicit, non-negotiable requirement (device-only key, never iCloud-synced) and is the one deliberate divergence from `KeychainLicenseStore`, which has no such line (license key syncing is fine per CONTEXT.md's rationale; clipboard key syncing is not).

**Delete** (lines 69-76) — likely not needed for this phase (no "reset clipboard encryption" UI exists yet), but the shape is available if a debug/reset helper is wanted:
```swift
func delete() {
    let query: [String: Any] = [ ... ]
    SecItemDelete(query as CFDictionary)
}
```

**Generate-if-absent wrapper** — no direct precedent in `KeychainLicenseStore` itself (license flow never generates a key, only stores a server-issued one), but `LicenseManager`'s read-once-cache discipline (lines 88-101) is the precedent for **not** hitting Keychain on every call:
```swift
private var cachedRecord: LicenseRecord?
private var hasCachedRecord = false

var isLicensed: Bool {
    if hasCachedRecord { return cachedRecord?.status == "granted" }
    let record = store.read()
    cachedRecord = record
    hasCachedRecord = true
    return record?.status == "granted"
}
```
RESEARCH.md Pitfall 2 explicitly calls this out: resolve the `SymmetricKey` once (e.g. `readOrCreateKey()` called once by whatever owns the call site) rather than re-querying Keychain on every save/load. Since this phase has no coordinator yet (Phase 57/58 add one), it is acceptable for `ClipboardFileStore.load`/`.save` to simply accept an already-resolved `SymmetricKey` parameter — defer the caching-owner decision, per RESEARCH.md Open Question 2.

---

### `IsletTests/ClipboardFileStoreTests.swift` (test, file-I/O)

**Analog:** `IsletTests/ShelfFileStoreTests.swift` (121 lines, read in full)

**fixturesDir setUp/tearDown convention** (lines 10-24, copy verbatim structure):
```swift
final class ShelfFileStoreTests: XCTestCase {
    private var fixturesDir: URL!

    override func setUp() {
        super.setUp()
        fixturesDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ShelfFileStoreTestsFixtures-\(UUID())", isDirectory: true)
        try? FileManager.default.createDirectory(at: fixturesDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: fixturesDir)
        fixturesDir = nil
        super.tearDown()
    }
```
Rename to `ClipboardFileStoreTestsFixtures-\(UUID())`; this becomes the injectable `root:` passed into `ClipboardFileStore.load`/`.save` for SC#1's round-trip test (production code never touches the real Application Support directory during tests).

**Round-trip / content-integrity assertion shape** (lines 26-37, adapt for save→load instead of copy):
```swift
func testMakeSessionCopyMatchesSourceContents() throws {
    let source = fixturesDir.appendingPathComponent("a.pdf")
    let contents = Data("hello shelf".utf8)
    try contents.write(to: source)

    let id = UUID()
    let localURL = try ShelfFileStore.makeSessionCopy(of: source, id: id)

    XCTAssertNotEqual(localURL, source)
    XCTAssertTrue(FileManager.default.fileExists(atPath: localURL.path))
    XCTAssertEqual(try Data(contentsOf: localURL), contents)
}
```
Adapt as: build `[ClipboardItem]`, call `ClipboardFileStore.save(items, root: fixturesDir, key: testKey)`, then `ClipboardFileStore.load(root: fixturesDir, key: testKey)`, assert the reloaded array equals the original (SC#1).

**Plaintext-absence assertion (SC#2, new — no direct analog, but same fixturesDir setup)**: after `save`, read `index.json.enc` and any `images/*.enc` as raw `Data`, convert to `String(data:encoding:.utf8)` or search bytes, assert known plaintext substrings (e.g. the original text content) are NOT present.

**Delete-path hardening test shape** (lines 75-86, copy structure for D-06's orphan cleanup):
```swift
func testDeleteSessionCopyOutsideShelfRootIsSafeNoOp() throws {
    let realFile = fixturesDir.appendingPathComponent("real-user-file.pdf")
    try Data("do not delete me".utf8).write(to: realFile)

    ShelfFileStore.deleteSessionCopy(at: realFile)

    XCTAssertTrue(FileManager.default.fileExists(atPath: realFile.path))
    XCTAssertEqual(try Data(contentsOf: realFile), Data("do not delete me".utf8))
}
```
Adapt: construct a file path outside `<root>/images/`, call whatever internal delete helper `ClipboardFileStore` exposes (or exercise it indirectly via `save` with a crafted/out-of-contract state if the delete helper is private), assert the file survives (SC#3).

**Idempotent double-delete test shape** (lines 62-73) — reusable pattern if `ClipboardFileStore` exposes a standalone delete function; if the orphan cleanup is only reachable via `save`'s diff logic (no standalone public delete), this test may not have a direct equivalent — note as an open call for the planner.

---

### `IsletTests/KeychainClipboardKeyStoreTests.swift` (optional, test, CRUD)

No direct existing analog file (no `KeychainLicenseStoreTests.swift` was found in this search — RESEARCH.md flags this as "optional but recommended," not required). If planner decides to add it, structure as a plain `XCTestCase` (no fixturesDir needed — Keychain, not disk) exercising: generate-if-absent returns a key, second `readOrCreateKey()` call returns the SAME key (byte-equal), and `kSecAttrSynchronizable` is set false on write (can be asserted indirectly by re-reading via `SecItemCopyMatching` with the same query, or trusted as covered by code review since CryptoKit doesn't expose Keychain attributes back out). RESEARCH.md notes: if omitted, `ClipboardFileStoreTests`'s round-trip test implicitly covers key-store correctness since it depends on a working key store to encrypt/decrypt.

## Shared Patterns

### Graceful degradation on read failure (D-04)
**Source:** `Islet/Licensing/KeychainLicenseStore.swift` lines 44-48 (`guard status == errSecSuccess, ... else { return nil }`), reinforced by CONTEXT.md's citation of `NowPlayingMonitor`'s "clear state, no crash" convention.
**Apply to:** `ClipboardFileStore.load` — every step (file read, `SealedBox(combined:)` construction, `AES.GCM.open`, `JSONDecoder().decode`) must be chained with `try?`/`guard ... else { return [] }`, never propagate a thrown error out of `load`. See RESEARCH.md Code Examples (lines 271-282) for the exact chained-guard shape already drafted.

### Hardened delete-under-root
**Source:** `Islet/Shelf/ShelfFileStore.swift` lines 49-56.
**Apply to:** `ClipboardFileStore`'s D-06 orphan-image cleanup — standardize both target and root, `hasPrefix` guard, non-throwing `try?` removal, silent no-op outside root.

### Standalone enum, no I/O inside the pure model
**Source:** `Islet/Shelf/ShelfFileStore.swift` (whole-file shape) vs. `Islet/Clipboard/ClipboardStore.swift` (pure struct, zero I/O imports).
**Apply to:** Confirms `ClipboardFileStore` must NOT be a method/extension on `ClipboardStore` — keep them in separate files, `ClipboardStore.swift` remains untouched by this phase (per CONTEXT.md Phase Boundary and RESEARCH.md's SC-4 citation).

### Keychain accessibility + service/account naming
**Source:** `Islet/Licensing/KeychainLicenseStore.swift` lines 29-30, 65.
**Apply to:** `KeychainClipboardKeyStore` — same `kSecAttrAccessibleAfterFirstUnlock`, same `com.lippi304.islet.*` service-string namespace convention, distinct account name.

## No Analog Found

None — all four target files have a strong (exact or role-match) existing analog. `CryptoKit.AES.GCM` itself has zero prior art in this codebase (RESEARCH.md confirms), but this is a leaf API call, not a structural/file-organization pattern, so it does not block pattern mapping; use RESEARCH.md's Pattern 2 code example (lines 144-161) directly.

## Metadata

**Analog search scope:** `Islet/Shelf/`, `Islet/Licensing/`, `Islet/Clipboard/`, `IsletTests/` (targeted by RESEARCH.md's own Sources section; no broader glob search needed — RESEARCH.md already identified the exact two analog files and this session confirmed them by direct read).
**Files scanned:** 5 (`ShelfFileStore.swift`, `KeychainLicenseStore.swift`, `ClipboardItem.swift`, `ClipboardStore.swift`, `ShelfFileStoreTests.swift`) — all read in full (each ≤ 121 lines).
**Pattern extraction date:** 2026-07-22
