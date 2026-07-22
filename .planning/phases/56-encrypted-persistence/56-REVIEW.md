---
phase: 56-encrypted-persistence
reviewed: 2026-07-22T20:14:00Z
depth: standard
files_reviewed: 4
files_reviewed_list:
  - Islet/AppDelegate.swift
  - Islet/Clipboard/ClipboardFileStore.swift
  - Islet/Clipboard/KeychainClipboardKeyStore.swift
  - IsletTests/ClipboardFileStoreTests.swift
findings:
  critical: 1
  warning: 3
  info: 2
  total: 6
status: issues_found
---

# Phase 56: Code Review Report

**Reviewed:** 2026-07-22T20:14:00Z
**Depth:** standard
**Files Reviewed:** 4
**Status:** issues_found

## Summary

Reviewed the AES-GCM encrypted clipboard persistence layer (`ClipboardFileStore`, `KeychainClipboardKeyStore`), its DEBUG-only spike wiring in `AppDelegate`, and the accompanying test suite. The nonce handling is correct (CryptoKit's `AES.GCM.seal` generates a fresh random nonce per call, and the combined representation round-trips it), and the path-traversal guard on orphan deletion (`deleteOrphanedImageFile`) is sound and well-tested.

The most serious issue is that both the encrypted index file and the encrypted image files are written with plain (non-atomic) `Data.write(to:)`, so a crash or power loss mid-write can leave `index.json.enc` truncated/corrupted — which silently degrades to "no items" per the store's own `try?`-swallowing design (D-04), and on the *next* successful save, the orphan-sweep will then delete every previously-saved image file because none of them appear in the (now apparently empty) item list. This turns a transient crash into permanent, total loss of clipboard history. There are also two Keychain-related gaps: a non-atomic delete-then-add upsert with no synchronization around the read-then-create-then-write flow, and an accessibility class that does not actually enforce the "device-only" guarantee the code comment claims.

## Critical Issues

### CR-01: Non-atomic writes to index.json.enc and image files risk full data loss on crash

**File:** `Islet/Clipboard/ClipboardFileStore.swift:79` and `Islet/Clipboard/ClipboardFileStore.swift:86`
**Issue:** `save()` writes both the per-item encrypted image blobs and the encrypted index with plain `Data.write(to:)`, which has no `.atomic` option and performs a direct in-place write. If the process is killed (crash, force-quit, power loss, `SIGKILL`) mid-write, `index.json.enc` can be left truncated. On the next `load()`, `AES.GCM.open` (or even `SealedBox(combined:)`) will fail on the truncated ciphertext, and per the documented D-04 behavior this collapses to an empty `[]` — i.e. the entire clipboard history appears to have vanished. Worse: on the *next* successful `save()` call, the orphan-sweep logic (lines 88-91) will treat every existing image file as unreferenced (because the caller's in-memory item list was rebuilt from the now-corrupted, effectively-empty load) and delete them — turning a transient write interruption into permanent, unrecoverable loss of all previously stored clipboard images. This is exactly the "mid-save crash must never leave a referenced-but-missing file" risk the code's own comment (lines 60-63) calls out, except the direction that's unguarded (corrupt the file that's already there) is worse than the one that is guarded (write order for new files).
**Fix:**
```swift
try encrypted.write(to: imagesDir.appendingPathComponent(filename), options: .atomic)
...
try encryptedIndex.write(to: root.appendingPathComponent("index.json.enc"), options: .atomic)
```
`.atomic` writes to a temp file in the same directory and renames over the destination, so a crash mid-write either leaves the old file completely intact or the new file completely intact — never a partial/corrupted file.

## Warnings

### WR-01: KeychainClipboardKeyStore key upsert is not atomic and readOrCreateKey() has no synchronization

**File:** `Islet/Clipboard/KeychainClipboardKeyStore.swift:29-50`
**Issue:** `write()` does `SecItemDelete` then `SecItemAdd` (lines 37-42) with no rollback path. If `SecItemAdd` fails after the delete has already removed the prior item (e.g. keychain locked, disk full, ACL/entitlement issue), the previously-stored encryption key is now permanently gone — `write` just returns `false` and the caller has no way to recover the deleted key, silently orphaning every clipboard item ever encrypted with it. Separately, `readOrCreateKey()` (lines 45-50) is a plain read-then-write with no lock/actor isolation: two concurrent callers (e.g. once this is wired into a real background clipboard-monitoring queue rather than only the current sequential DEBUG menu clicks) that both observe `read() == nil` will each generate a *different* random `SymmetricKey` and both call `write()`; whichever `write()` runs last silently becomes the persisted key while the other caller keeps using an in-memory key that no longer matches what's on disk, causing that caller's subsequent encrypt/decrypt calls to fail.
**Fix:** Serialize `readOrCreateKey()` (e.g. a `NSLock`/serial `DispatchQueue`, or make `KeychainClipboardKeyStore` an actor) so only one caller ever performs the read-check-create-write sequence at a time. For `write()`, prefer `SecItemUpdate` when the item already exists and only fall back to delete+add when it doesn't, so a failed add never destroys a previously-valid key.

### WR-02: Keychain accessibility constant does not enforce the stated "device-only" guarantee

**File:** `Islet/Clipboard/KeychainClipboardKeyStore.swift:40`
**Issue:** The file's header comment (lines 5-10) explicitly states this key is meant to be "device-only ... since clipboard content is personal and this milestone has no cross-Mac sync mechanism," and relies on `kSecAttrSynchronizable = false` (line 41) to justify that claim. However `kSecAttrSynchronizable` only opts the item out of iCloud Keychain sync — it does not prevent the item from being included in an encrypted Time Machine backup or a Migration Assistant transfer, both of which can restore the key (and, since the encrypted clipboard files live under Application Support, the ciphertext too) onto a different Mac. `kSecAttrAccessibleAfterFirstUnlock` (used here) is included in such backups; only the `...ThisDeviceOnly` variant is excluded.
**Fix:**
```swift
attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
```

### WR-03: No concurrency guard around ClipboardFileStore's shared-file I/O

**File:** `Islet/Clipboard/ClipboardFileStore.swift:64-101`
**Issue:** `save()` and `load()` are plain, non-isolated `static` functions that read/write the same `index.json.enc` and `images/` directory with no locking or actor isolation. The phase's own review focus calls out Swift concurrency correctness, and while today's only caller (`AppDelegate`'s DEBUG spike menu) is effectively serialized by AppKit's main-thread menu dispatch, nothing in `ClipboardFileStore` itself prevents two concurrent `save()` calls (e.g. once real clipboard-change monitoring lands on a background timer/queue) from interleaving: one call's orphan-sweep (lines 88-91) could delete an image file that a second, concurrently-running `save()` just wrote and is about to reference in its own index write, producing a load-time miss for that item.
**Fix:** Isolate `ClipboardFileStore`'s mutating operations behind a single serial queue or actor (or document/enforce single-writer-at-a-time at the call site) before this is wired into anything that can call `save()`/`load()` from more than one execution context.

## Info

### IN-01: Force-unwrap on FileManager URL lookup

**File:** `Islet/Clipboard/ClipboardFileStore.swift:28`
**Issue:** `storageRoot()` force-unwraps the first result of `FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)`. In practice macOS always returns exactly one URL for this domain, but every other force-unwrap-free path in this file (and the sibling `ShelfFileStore`) is written defensively; this is the one spot that would crash the app rather than degrade gracefully if the assumption ever broke.
**Fix:** `.first ?? FileManager.default.temporaryDirectory` (or similar graceful fallback) instead of `!`.

### IN-02: Debug spike print statement doesn't reflect save success/failure

**File:** `Islet/AppDelegate.swift:289-291`
**Issue:** `debugSpikeSeedClipboardData` swallows the `save()` error with `try?` (line 289) and then unconditionally prints `"seeded \(items.count) items"` (line 290) regardless of whether the save actually succeeded — making this manual verification tool misleading exactly when it's most needed (diagnosing a save failure).
**Fix:**
```swift
do {
    try ClipboardFileStore.save(items, root: ClipboardFileStore.storageRoot(), key: KeychainClipboardKeyStore().readOrCreateKey())
    print("[Spike-Clipboard] seeded \(items.count) items to \(ClipboardFileStore.storageRoot().path)")
} catch {
    print("[Spike-Clipboard] save failed: \(error)")
}
```

---

_Reviewed: 2026-07-22T20:14:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
