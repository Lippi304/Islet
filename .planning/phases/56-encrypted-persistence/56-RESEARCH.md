# Phase 56: Encrypted Persistence - Research

**Researched:** 2026-07-22
**Domain:** Local file encryption at rest (CryptoKit AES-GCM), Keychain key storage, FileManager-based JSON+blob persistence on macOS
**Confidence:** HIGH

## Summary

This phase has zero new external dependencies — everything needed is a first-party Apple system framework (`CryptoKit`, `Security`, `Foundation`) already implicitly available to the target (macOS 15 deployment target, confirmed in `project.yml`). The codebase already contains two directly-reusable architectural precedents that cover 100% of this phase's structural needs: `ShelfFileStore.swift` (hardened-delete-under-root pattern, standalone enum with real FileManager I/O) and `KeychainLicenseStore.swift` (SecItem upsert shape with defensive nil-fallback). This phase is almost entirely "assemble known patterns," not "discover new architecture."

The only genuinely new API surface is `CryptoKit.AES.GCM`. Its API is small, stable since introduction (iOS 13/macOS 10.15), and unchanged in current Xcode/SDK — `AES.GCM.seal(_:using:)` returns a `SealedBox` whose `.combined` property (nonce + ciphertext + tag concatenated) is the single `Data` blob to write to disk; `AES.GCM.open(_:using:)` on a `SealedBox(combined:)` reverses it and throws `CryptoKitError.authenticationFailure` on any tampering or wrong key. A raw 256-bit `SymmetricKey`'s `withUnsafeBytes` gives the `Data` to store in Keychain (mirroring exactly how `KeychainLicenseStore` stores a `Codable` payload as `Data`).

**Primary recommendation:** Build `ClipboardFileStore` as a standalone enum (not a method on `ClipboardStore`) rooted under `FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("IsletClipboard")`, mirroring `ShelfFileStore`'s shape exactly but swapping `NSTemporaryDirectory()` for the Application Support URL and adding a sibling `KeychainClipboardKeyStore` (mirroring `KeychainLicenseStore`) that stores/reads a raw AES-256 `SymmetricKey` as Keychain `Data`, generating one via `SymmetricKey(size: .bits256)` on first use if absent.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| AES-GCM encrypt/decrypt of index+images | App logic (CryptoKit) | — | Pure computation, no I/O; belongs next to the file store call site, not inside `ClipboardStore` (keeps the pure value type untouched per Phase 55's design) |
| AES key generation/storage | Security framework (Keychain) | App logic (key caching) | Mirrors `KeychainLicenseStore`/`LicenseManager`'s read-once-cache split — Keychain read is I/O, must not sit on a hot path |
| JSON index + image file I/O | App logic (`FileManager`) | — | `ShelfFileStore` precedent: a standalone enum, not a method on the pure model type |
| Delete-path validation | App logic (`ClipboardFileStore`) | — | Security-critical guard, must live at the same layer as the I/O it guards (mirrors `ShelfFileStore.deleteSessionCopy`) |
| Round-trip contract (save → reload same items/order) | App logic (`ClipboardFileStore`) | Pure model (`ClipboardStore`/`ClipboardItem` `Codable`) | Store persists; model defines the `Codable` shape being persisted |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `CryptoKit` | System framework, macOS 10.15+ (target: macOS 15) | `AES.GCM.seal`/`AES.GCM.open`, `SymmetricKey` | Apple's own audited crypto API — the exact library named in PRIV-02's requirement text; no alternative considered |
| `Security` (`SecItemAdd`/`SecItemCopyMatching`/`SecItemDelete`) | System framework | Keychain storage for the raw AES key | Already used identically by `KeychainLicenseStore.swift`; zero new API surface for the team |
| `Foundation` (`FileManager`, `JSONEncoder`/`JSONDecoder`) | System framework | JSON index read/write, directory management | Already used identically by `ShelfFileStore.swift` and `ClipboardItem`'s existing `Codable` conformance |

### Supporting
None — no supporting libraries needed. `ClipboardItem`/`ClipboardStore` (Phase 55) are already `Codable`/`Equatable` and require no changes to be persisted.

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `AES.GCM` (CryptoKit) | `ChaChaPoly` (CryptoKit) | Both are authenticated-encryption AEAD ciphers with the same CryptoKit API shape; PRIV-02 explicitly names AES-GCM, no reason to diverge |
| Raw `SymmetricKey` stored as Keychain `Data` | `SecKey`/Keychain-native asymmetric key generation | Unnecessary complexity — AES-GCM needs a symmetric key, and `KeychainLicenseStore`'s existing "store arbitrary `Data`" upsert shape already fits a raw symmetric key with no new Keychain item class |
| One JSON index file + separate image files (per ROADMAP.md line 147) | A single encrypted archive (index+images combined) | ROADMAP explicitly specifies the split; also keeps D-06's per-item eviction cleanup a simple single-file delete rather than a full-archive rewrite |

**Installation:**
No package manager step required — `import CryptoKit`, `import Security`, `import Foundation` are all available with zero project.yml/Package.swift changes (same reason `KeychainLicenseStore.swift` needed no `Security` framework linking step: system frameworks with a Swift overlay are auto-linked).

**Version verification:** N/A — these are OS-bundled system frameworks, not versioned package-manager dependencies. `CryptoKit` has been API-stable for `AES.GCM`/`SymmetricKey` since its 2019 introduction; no deprecations affect this phase at the macOS 15 deployment target `[VERIFIED: WebSearch cross-referenced against Apple Developer Forums code samples, API unchanged]`.

## Package Legitimacy Audit

**Not applicable.** This phase installs zero external packages (no npm/pip/cargo/SPM third-party dependencies). All APIs used (`CryptoKit`, `Security`, `Foundation`) are first-party Apple system frameworks bundled with the OS/SDK. The Package Legitimacy Gate protocol is scoped to externally-installed packages and does not apply here.

## Architecture Patterns

### System Architecture Diagram

```
App launch
  │
  ▼
ClipboardFileStore.load(root:)  ──► KeychainClipboardKeyStore.readOrCreateKey()
  │                                        │
  │                                        ▼
  │                                  Keychain (SecItemCopyMatching / SecItemAdd)
  │                                  kSecAttrAccessibleAfterFirstUnlock,
  │                                  kSecAttrSynchronizable = false (D-05)
  ▼
Read index.json.enc from
  <AppSupport>/IsletClipboard/
  │
  ├─ decrypt fails / file missing / key missing ──► return empty [ClipboardItem] (D-04, no throw)
  │
  ▼
AES.GCM.open(SealedBox(combined:), using: key)
  │
  ▼
JSONDecoder → [ClipboardItemRecord] (index metadata: id, kind-tag, timestamp, imageFilename?)
  │
  ├─ text item ──► content inline in JSON (already encrypted as part of the index blob)
  │
  └─ image item ──► read <AppSupport>/IsletClipboard/images/<uuid>.enc
                      │
                      ▼
                    AES.GCM.open(...) using the SAME key ──► Data ──► ClipboardItem.Kind.image

  ▼
[ClipboardItem] fed into ClipboardStore.items (in-memory)


ClipboardStore mutation (append/evict/clear, Phase 55 pure logic)
  │
  ▼
ClipboardFileStore.save(store.items, root:)
  │
  ├─ diff against what's currently on disk (D-06): compute the set of image files
  │    present on disk that have no corresponding item.id in the new items array
  │
  ├─ for each item.kind == .image: encrypt Data, write <uuid>.enc to images/
  ├─ for the whole item list: encode [ClipboardItemRecord] → JSON → encrypt → write index.json.enc
  └─ for each stale image file found in the diff: ClipboardFileStore.deleteItemFile(at:)
       │
       ▼
     validate target path .hasPrefix(storageRoot.path + "/") (SC#3, mirrors ShelfFileStore)
       │
       ▼
     FileManager.default.removeItem(at:)
```

### Recommended Project Structure
```
Islet/Clipboard/
├── ClipboardItem.swift          # Phase 55, unchanged
├── ClipboardStore.swift         # Phase 55, unchanged
├── ClipboardFileStore.swift     # NEW — this phase, mirrors ShelfFileStore.swift
├── ClipboardItemRecord.swift    # NEW (or nested in ClipboardFileStore.swift) — the on-disk
│                                 #   JSON-index Codable shape, separate from ClipboardItem if
│                                 #   image content needs to be excluded from the inline JSON
│                                 #   (image bytes live in their own file, not inline)
└── KeychainClipboardKeyStore.swift  # NEW — mirrors KeychainLicenseStore.swift

<Application Support>/IsletClipboard/
├── index.json.enc                # AES-GCM sealed JSON index (all item metadata + text content)
└── images/
    └── <uuid>.enc                # AES-GCM sealed raw image Data, one file per image item
```

### Pattern 1: Standalone FileStore enum performing real I/O (established precedent)
**What:** A namespacing `enum` with static methods, no stored state, doing `FileManager`/Keychain I/O — never a method on the pure model type.
**When to use:** Any disk-touching operation for a Phase-55-style pure value type.
**Example:**
```swift
// Source: Islet/Shelf/ShelfFileStore.swift (existing codebase pattern, verbatim shape)
enum ClipboardFileStore {
    static func load(root: URL, key: SymmetricKey) -> [ClipboardItem] { ... }
    static func save(_ items: [ClipboardItem], root: URL, key: SymmetricKey) throws { ... }
}
```
The `root: URL` parameter is what makes SC#1's injectable-root round-trip unit test possible — production call sites pass the real Application Support URL, tests pass a throwaway temp directory (exactly like `ShelfFileStoreTests.swift`'s `fixturesDir` pattern).

### Pattern 2: AES-GCM seal/open round trip
**What:** Symmetric authenticated encryption for arbitrary `Data` (JSON blob or raw image bytes).
**When to use:** Every write/read of the index file and every image file.
**Example:**
```swift
// Source: CryptoKit official API, cross-verified via Apple Developer Forums samples
// (https://developer.apple.com/forums/thread/133951, https://dev.to/craftzdog/...)
import CryptoKit

func encrypt(_ plaintext: Data, using key: SymmetricKey) throws -> Data {
    let sealedBox = try AES.GCM.seal(plaintext, using: key)
    guard let combined = sealedBox.combined else {
        throw ClipboardFileStoreError.sealFailed  // nonce not default-size — cannot happen with AES.GCM's default nonce, defensive only
    }
    return combined
}

func decrypt(_ combined: Data, using key: SymmetricKey) throws -> Data {
    let sealedBox = try AES.GCM.SealedBox(combined: combined)
    return try AES.GCM.open(sealedBox, using: key)   // throws CryptoKitError.authenticationFailure on tamper/wrong key
}
```
`sealedBox.combined` is `nonce || ciphertext || tag` as one `Data` blob — this is the entire on-disk file content, no separate nonce/tag bookkeeping needed. `AES.GCM.seal` generates a fresh random nonce internally on every call if none is passed — never reuse a nonce manually.

### Pattern 3: Keychain-stored raw symmetric key (adapting KeychainLicenseStore's shape)
**What:** Store/read a `SymmetricKey`'s raw bytes as a Keychain `Data` item; generate-if-absent on first read.
**When to use:** App launch, before any load/save call.
**Example:**
```swift
// Source: Islet/Licensing/KeychainLicenseStore.swift (existing codebase pattern), adapted
// for raw key Data instead of a Codable struct. CryptoKit SymmetricKey<->Data conversion
// per Apple sample code (https://holyswift.app/cryptographic-keys-and-swift/).
struct KeychainClipboardKeyStore {
    private let service = "com.lippi304.islet.clipboard"
    private let account = "encryptionKey"

    func readOrCreateKey() -> SymmetricKey {
        if let existing = read() { return existing }
        let newKey = SymmetricKey(size: .bits256)
        _ = write(newKey)
        return newKey
    }

    private func read() -> SymmetricKey? {
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
    private func write(_ key: SymmetricKey) -> Bool {
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
        attributes[kSecAttrSynchronizable as String] = false   // D-05: never iCloud-syncable
        return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
    }
}
```

### Anti-Patterns to Avoid
- **Reusing a fixed/zero nonce across saves:** `AES.GCM.seal(_:using:)` without a `nonce:` argument auto-generates a fresh random 12-byte nonce every call — do not pass a fixed nonce or reuse `sealedBox.nonce` across writes; nonce reuse under the same key breaks GCM's authentication guarantee entirely.
- **Storing the key as a `Codable` wrapper struct like `LicenseRecord`:** `SymmetricKey` has no `Codable` conformance; store its raw bytes (`Data`) directly, not a wrapping struct — simpler and there's nothing else worth co-storing (unlike `LicenseRecord`'s multi-field shape).
- **Encrypting each JSON field separately:** Encrypt the whole serialized JSON index as one blob (encode → encrypt → write), not per-field — matches SC#2's "no readable plaintext" bar with the least code and avoids nonce-per-field bookkeeping.
- **Putting FileManager/CryptoKit code inside `ClipboardStore`:** Would violate Phase 55's explicit design goal (SC-4: `ClipboardStore` stays independent of any I/O axis) — keep it in `ClipboardFileStore`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| AES-GCM encryption primitives | Custom AES implementation, custom nonce/tag handling | `CryptoKit.AES.GCM.seal`/`.open` | CryptoKit is Apple-audited, constant-time, hardware-accelerated where available; PRIV-02 explicitly requires it |
| Key derivation / storage | A key file on disk, an obfuscated constant, UserDefaults | Keychain (`Security` framework) via `SecItemAdd`/`SecItemCopyMatching`, mirroring `KeychainLicenseStore` | Same rationale `KeychainLicenseStore`'s own header comment states: entitlement/secret data is NEVER UserDefaults or a flippable value; Keychain survives app reinstall and is OS-encrypted at rest independently |
| Path-traversal-safe delete | A regex/substring check on the filename alone | `standardizedFileURL` + `hasPrefix(root.path + "/")` guard (exact `ShelfFileStore.deleteSessionCopy` pattern) | Filename-only checks miss symlink/`..`-in-directory-component tricks; the existing codebase already solved this correctly once — SC#3 explicitly requires mirroring it, not reinventing it |

**Key insight:** This entire phase is "wire together CryptoKit + the two already-proven codebase patterns (`ShelfFileStore`'s I/O shape, `KeychainLicenseStore`'s Keychain shape)" — there is no novel algorithm to design.

## Common Pitfalls

### Pitfall 1: Treating a decrypt failure as fatal instead of "no history yet"
**What goes wrong:** `AES.GCM.open` throws `CryptoKitError.authenticationFailure` on a corrupted file or wrong/missing key — a naive implementation propagates this as a crash or a startup error dialog.
**Why it happens:** The natural Swift instinct is to `try` and let errors surface.
**How to avoid:** D-04 requires wrapping the entire load path in `try?` (or explicit catch-and-return-empty) at the `ClipboardFileStore.load` boundary — same shape as `KeychainLicenseStore.read()`'s `guard ... else { return nil }` and this project's `NowPlayingMonitor` graceful-degradation precedent. No UI exists yet to show an error (menu wiring is Phase 58), so surfacing one now would be premature scope anyway.
**Warning signs:** Any `try` without a `?`/`catch` on the load path; any thrown error crossing out of `ClipboardFileStore.load`.

### Pitfall 2: Encrypting the JSON index and images with different/inconsistent keys or re-deriving a key per call
**What goes wrong:** If key retrieval isn't cached/consistent, a save could accidentally use a different key instance than a later load (e.g. if `readOrCreateKey()` is called fresh each time and Keychain write silently failed, producing a new key different from what encrypted existing data).
**Why it happens:** Read-Keychain-per-call without caching, combined with a silent write failure, can desync "the key used to encrypt" from "the key retrieved to decrypt."
**How to avoid:** Follow `LicenseManager`'s read-once-cache discipline — resolve the key once (e.g. at `ClipboardFileStore`'s owning coordinator's init) and pass it explicitly into `load`/`save`, rather than each call independently calling Keychain. This also keeps Keychain access off any hot path, matching the project's documented auth-prompt-flood precedent (project memory 2401, cited in `KeychainLicenseStore.swift`).
**Warning signs:** `SecItemCopyMatching` called inside a loop or on every save/load instead of once per app session.

### Pitfall 3: D-06 diff-and-delete logic deleting files that are still referenced
**What goes wrong:** A naive "delete everything in `images/` not matching current item IDs" implemented incorrectly (e.g. comparing against a stale in-memory snapshot, or running before the new index write completes) could delete an image file whose item is still present, corrupting a valid entry.
**Why it happens:** Save-then-diff ordering matters — if the stale-file sweep runs against the OLD on-disk items list instead of the NEW in-memory `items` array being saved, live files can be misidentified as orphaned.
**How to avoid:** Compute the "files to delete" set purely from `Set(diskImageFilenames).subtracting(Set(newItems.compactMap { imageFilename(for: $0) }))` — always diff against the incoming `items` array being saved, never against what was previously on disk. Write the new index/image files FIRST, delete orphans LAST, so a crash mid-save never leaves a referenced file missing.
**Warning signs:** Any deletion step that runs before all new files for the current save are confirmed written.

### Pitfall 4: JSON index storing image bytes inline instead of as separate files
**What goes wrong:** ROADMAP.md explicitly specifies "JSON index + image files" as separate on-disk artifacts (line 147, line 972-984 context) — encoding `ClipboardItem.Kind.image(Data)` directly via `ClipboardItem`'s existing `Codable` conformance (which base64-encodes `Data` inline in JSON) would violate that split and bloat the index file with every image's bytes.
**Why it happens:** `ClipboardItem` is already `Codable` from Phase 55, so it's tempting to just `JSONEncoder().encode(items)` directly without an intermediate record type.
**How to avoid:** Define a separate on-disk record shape (`ClipboardItemRecord` or similar) that stores `id`, `kind` tag (`"text"`/`"image"`), `timestamp`, inline `text` content when applicable, and only an `imageFilename` (not the bytes) when the kind is image. This is exactly what Claude's Discretion in CONTEXT.md calls out as open ("exact on-disk JSON index shape... as long as round-trip contract holds").
**Warning signs:** `JSONEncoder().encode(store.items)` called directly without a translation step; index file size scaling with image byte count.

## Code Examples

### Full save/load round trip shape (illustrative, not final implementation)
```swift
// Source: composed from CryptoKit official docs + existing ShelfFileStore.swift/
// KeychainLicenseStore.swift codebase patterns — not from a single external reference.
enum ClipboardFileStore {
    static func storageRoot() -> URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("IsletClipboard", isDirectory: true)
    }

    static func load(root: URL, key: SymmetricKey) -> [ClipboardItem] {
        let indexURL = root.appendingPathComponent("index.json.enc")
        guard let combined = try? Data(contentsOf: indexURL),
              let sealedBox = try? AES.GCM.SealedBox(combined: combined),
              let plaintext = try? AES.GCM.open(sealedBox, using: key),
              let records = try? JSONDecoder().decode([ClipboardItemRecord].self, from: plaintext)
        else { return [] }   // D-04: any failure = empty history, never a crash

        return records.compactMap { record in
            record.toClipboardItem(imagesDir: root.appendingPathComponent("images"), key: key)
        }
    }

    static func save(_ items: [ClipboardItem], root: URL, key: SymmetricKey) throws {
        try FileManager.default.createDirectory(at: root.appendingPathComponent("images"),
                                                   withIntermediateDirectories: true)
        // ... write new image files, write new index, then diff-and-delete orphans (D-06) ...
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|---------------|--------|
| Manual CommonCrypto/OpenSSL AES-GCM bindings | `CryptoKit.AES.GCM` | Since iOS 13/macOS 10.15 (2019) | Type-safe, no C interop, no manual nonce/tag byte-slicing — this project targets macOS 15, far past this cutover, no legacy concern |

**Deprecated/outdated:** None relevant — `CryptoKit`'s `AES.GCM` API has had no breaking changes since introduction; nothing to flag.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `AES.GCM.seal`/`.open` and `SymmetricKey` API shapes are unchanged in the current SDK (cross-verified via WebSearch against multiple 2023-2025-dated tutorials, not Context7 since Context7 was not queried for this system-framework API) | Architecture Patterns, Code Examples | Low — this is a stable, years-old system API; if wrong, compile errors surface immediately at implementation time, not a silent runtime bug |

**If this table is empty:** N/A — one low-risk assumption logged above; everything else is either directly verified against this codebase's own files (`ShelfFileStore.swift`, `KeychainLicenseStore.swift`, `ClipboardItem.swift`, `ClipboardStore.swift`, `project.yml`) or cited from CONTEXT.md decisions.

## Open Questions

1. **Exact on-disk `ClipboardItemRecord` field names/shape**
   - What we know: Must round-trip faithfully (SC#1) and keep image bytes out of the JSON index (Pitfall 4).
   - What's unclear: Whether `imageFilename` should be the item's own `UUID.uuidString` (simplest, guaranteed-unique, no extra bookkeeping) or something else.
   - Recommendation: Use `item.id.uuidString` as both the JSON index key and the on-disk image filename (e.g. `images/<uuid>.enc`) — matches `ShelfFileStore`'s existing `id.uuidString`-as-directory-name convention exactly, and CONTEXT.md's Claude's Discretion explicitly leaves this open with that as an implied option.

2. **Where the resolved `SymmetricKey` is cached/owned (which type calls `readOrCreateKey()` once)**
   - What we know: Should be read once per app session (Pitfall 2), analogous to `LicenseManager`'s `cachedRecord`/`hasCachedRecord` pattern.
   - What's unclear: This phase has no coordinator/manager type yet (Phase 57/58 add the monitor and menu wiring) — the planner must decide whether `ClipboardFileStore` itself lazily caches the key internally (e.g. a `static var` or a small owning struct) or whether key resolution is deferred to whatever thin coordinator Phase 57/58 introduces.
   - Recommendation: For this phase's scope (store↔disk round-trip only, per CONTEXT.md's Phase Boundary), it's acceptable for `ClipboardFileStore.load`/`.save` to accept an already-resolved `SymmetricKey` as a parameter (as shown in Code Examples above) — this keeps `ClipboardFileStore` itself stateless/testable and defers the "who owns the cached key across app lifetime" decision to whichever phase introduces the first long-lived coordinator (likely Phase 57 or 58), rather than inventing a new manager type prematurely.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CLIP-04 | Clipboard history persists across app relaunch and system reboot | `ClipboardFileStore.save`/`.load` round trip against a real Application Support root (not `NSTemporaryDirectory()`, which does not survive reboot) — see Architecture Patterns, System Architecture Diagram |
| PRIV-02 | The persisted history is encrypted at rest (CryptoKit AES-GCM, key in Keychain) | CryptoKit `AES.GCM.seal`/`.open` pattern (Pattern 2) + `KeychainClipboardKeyStore` (Pattern 3), directly satisfying the requirement's named technology choices |
</phase_requirements>

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| CryptoKit.framework | AES-GCM encrypt/decrypt | Yes (system framework, macOS 10.15+) | Bundled with macOS 15 SDK/deployment target | — |
| Security.framework | Keychain key storage | Yes (system framework) | Bundled with macOS SDK | — |
| Application Support directory access | On-disk storage root | Yes (`FileManager.default.urls(for:in:)`, no entitlement needed for app-sandboxed or non-sandboxed local access) | — | — |

No missing dependencies — this phase requires no installation step of any kind.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (existing, `IsletTests` bundle target) |
| Config file | `project.yml` (`IsletTests` target, `type: bundle.unit-test`, hosted in `Islet` app for `@testable import`) |
| Quick run command | `xcodebuild test -scheme Islet -only-testing:IsletTests/ClipboardFileStoreTests` |
| Full suite command | `xcodebuild test -scheme Islet` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CLIP-04 | Save then reload against same injectable root reproduces same items/order (SC#1) | unit | `xcodebuild test -scheme Islet -only-testing:IsletTests/ClipboardFileStoreTests` | ❌ Wave 0 |
| CLIP-04 | Full kill-and-restart against real persisted data reloads same history (SC#4) | manual/on-device | N/A — requires actual process restart, not automatable in XCTest | ❌ Wave 0 (on-device checkpoint, not a test file) |
| PRIV-02 | On-disk index+image files show no readable plaintext when inspected raw (SC#2) | unit | `xcodebuild test -scheme Islet -only-testing:IsletTests/ClipboardFileStoreTests` (assert raw file bytes do NOT contain known plaintext substrings) | ❌ Wave 0 |
| PRIV-02 (SC#3, delete-path hardening) | Delete target validated under storage root before removal, mirrors `ShelfFileStore` | unit | `xcodebuild test -scheme Islet -only-testing:IsletTests/ClipboardFileStoreTests` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `xcodebuild test -scheme Islet -only-testing:IsletTests/ClipboardFileStoreTests`
- **Per wave merge:** `xcodebuild test -scheme Islet`
- **Phase gate:** Full suite green before `/gsd:verify-work`, plus one on-device kill-and-restart checkpoint for SC#4 (cannot be captured by an XCTest process, since it requires a real separate process launch against already-persisted disk state — mirrors this project's established on-device-checkpoint precedent for behavior that can't be unit-tested in-process).

### Wave 0 Gaps
- [ ] `IsletTests/ClipboardFileStoreTests.swift` — covers CLIP-04 (SC#1 round-trip) and PRIV-02 (SC#2 plaintext-absence, SC#3 delete-path hardening), following `ShelfFileStoreTests.swift`'s setUp/tearDown fixturesDir convention (an intentional deviation from the fixture-free convention, same rationale: real disk I/O needs a throwaway root)
- [ ] `IsletTests/KeychainClipboardKeyStoreTests.swift` — optional but recommended: covers key generate-if-absent and read-back consistency (no direct SC# maps to it, but it underpins SC#2's key availability); if omitted, `ClipboardFileStoreTests` implicitly covers this via the round-trip test needing a working key store
- [ ] Framework install: none — `IsletTests` target and scheme already exist and are wired for `xcodebuild test -scheme Islet`

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | Not applicable — no user-facing auth in this phase |
| V3 Session Management | No | Not applicable |
| V4 Access Control | Yes | Delete-path validated under storage root (`hasPrefix` guard on `standardizedFileURL`, mirrors `ShelfFileStore.deleteSessionCopy`) — prevents path-traversal/parent-directory deletion (SC#3) |
| V5 Input Validation | Partial | No untrusted external input in this phase (all data originates from the app's own `ClipboardStore`, not user-supplied file paths) — the delete-path guard (V4 above) is the relevant control |
| V6 Cryptography | Yes | `CryptoKit.AES.GCM` (256-bit `SymmetricKey`), key stored in Keychain with `kSecAttrAccessibleAfterFirstUnlock` and `kSecAttrSynchronizable = false` (D-05) — never hand-rolled, never a hardcoded/derived-from-constant key |

### Known Threat Patterns for CryptoKit + Keychain + FileManager (macOS)

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Path traversal in delete target (e.g. a crafted/corrupted stored path pointing outside the storage root) | Tampering | `standardizedFileURL` + `hasPrefix(root.path + "/")` guard before any `removeItem` call (SC#3, `ShelfFileStore` precedent) |
| Nonce reuse across AES-GCM encryptions under the same key | Tampering / Information Disclosure | Never pass an explicit fixed `nonce:` to `AES.GCM.seal` — let CryptoKit generate a fresh random nonce every call (default behavior); `.combined` already bundles the per-call nonce with the ciphertext |
| AES key exfiltration via iCloud Keychain sync to another device | Information Disclosure | `kSecAttrSynchronizable = false` on the Keychain item (D-05, explicit user decision) |
| Corrupted/tampered ciphertext silently accepted as valid plaintext | Tampering | GCM's built-in authentication tag: `AES.GCM.open` throws on any tamper — never catch-and-proceed with partial/failed decryption, always fail to "empty history" (D-04) |
| Decrypt failure treated as a crash, creating a DoS via a single corrupted file | Denial of Service | D-04's graceful-degradation contract: any load failure returns empty `[ClipboardItem]`, never propagates as a fatal error |

## Sources

### Primary (HIGH confidence)
- `Islet/Shelf/ShelfFileStore.swift` (this codebase) — hardened-delete-under-root pattern, standalone enum I/O shape
- `Islet/Licensing/KeychainLicenseStore.swift` (this codebase) — SecItem upsert shape, defensive nil-fallback, `kSecAttrAccessibleAfterFirstUnlock` precedent
- `Islet/Clipboard/ClipboardItem.swift`, `Islet/Clipboard/ClipboardStore.swift` (this codebase) — the exact value types/contract being persisted
- `IsletTests/ShelfFileStoreTests.swift` (this codebase) — fixturesDir setUp/tearDown test convention for real-disk-I/O coverage
- `.planning/ROADMAP.md` lines 147, 972-984 — phase scoping, on-disk layout spec (JSON index + separate image files)
- `.planning/phases/56-encrypted-persistence/56-CONTEXT.md` — D-04/D-05/D-06 locked decisions
- `project.yml` — macOS 15 deployment target (confirms CryptoKit/Security framework availability with zero linking changes), `IsletTests` scheme/target wiring

### Secondary (MEDIUM confidence)
- [How to encrypt/decrypt with AES-GCM using CryptoKit in Swift - DEV Community](https://dev.to/craftzdog/how-to-encrypt-decrypt-with-aes-gcm-using-cryptokit-in-swift-24h1) — `AES.GCM.seal`/`.combined`/`SealedBox(combined:)`/`.open` code shape, cross-verified against Apple Developer Forums threads
- [Cryptographic Keys and Swift - Holy Swift](https://holyswift.app/cryptographic-keys-and-swift/) — `SymmetricKey.withUnsafeBytes`/`SymmetricKey(data:)` conversion pattern
- [AES256 decryption in iOS - Apple Developer Forums](https://developer.apple.com/forums/thread/133951) — official-forum-adjacent confirmation of the seal/open round-trip shape

### Tertiary (LOW confidence)
None used — all CryptoKit claims cross-verified across 2+ independent sources plus training-knowledge agreement.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — zero new external dependencies, all system frameworks already implicitly available at the project's macOS 15 deployment target
- Architecture: HIGH — directly derived from two existing, working, tested patterns already in this exact codebase (`ShelfFileStore`, `KeychainLicenseStore`)
- Pitfalls: HIGH — D-04/D-05/D-06 are user-locked decisions with explicit precedent citations in CONTEXT.md; CryptoKit-specific pitfalls (nonce reuse, auth-failure handling) are well-documented, stable API behavior

**Research date:** 2026-07-22
**Valid until:** No practical expiry — CryptoKit's `AES.GCM` API and this codebase's `ShelfFileStore`/`KeychainLicenseStore` precedents are stable; re-research only needed if Phase 55's `ClipboardItem`/`ClipboardStore` shapes change before Phase 56 executes.
