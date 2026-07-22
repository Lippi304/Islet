# Phase 56: Encrypted Persistence - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-22
**Phase:** 56-Encrypted Persistence
**Areas discussed:** Corruption/key-loss recovery, Keychain key sync scope, Orphaned file cleanup on eviction

---

## Corruption / key-loss recovery

| Option | Description | Selected |
|--------|-------------|----------|
| Silently start empty | Treat it like "no history yet" — no crash, no error UI, next successful save overwrites the unreadable file. Matches NowPlayingMonitor/KeychainLicenseStore graceful-degradation convention. | ✓ |
| Leave the corrupt file untouched | Show empty history but don't overwrite the on-disk file until a new save happens — no real benefit since content is encrypted and unrecoverable without the original key. | |
| You decide | Claude picks during planning. | |

**User's choice:** Silently start empty (recommended)
**Notes:** No follow-up — confirmed as final on first pass.

---

## Keychain key sync scope

| Option | Description | Selected |
|--------|-------------|----------|
| Device-only, non-syncable | `kSecAttrSynchronizable = false` — clipboard history never decryptable on another Mac even with iCloud Keychain on. | ✓ |
| Allow iCloud sync | Key syncs like a normal Keychain item — but no matching data-sync mechanism exists for the JSON index itself, so syncing only the key buys nothing. | |

**User's choice:** Device-only, non-syncable (recommended)
**Notes:** No follow-up — confirmed as final on first pass.

---

## Orphaned file cleanup on eviction

| Option | Description | Selected |
|--------|-------------|----------|
| Delete immediately | Disk usage for images stays bounded to ~30 items; save path diffs against previous on-disk state and removes files for items no longer present. | ✓ |
| Leave orphaned files, sweep later | Simpler save path, but stray image files accumulate on disk with no cleanup mechanism planned this milestone. | |

**User's choice:** Delete immediately (recommended)
**Notes:** No follow-up — confirmed as final on first pass.

---

## Claude's Discretion

- Exact on-disk JSON index shape (field names, image path representation)
- Application Support subfolder naming convention
- Whether `kSecAttrSynchronizable = false` is set explicitly or left at its non-syncable default
- Keychain accessibility attribute for the new AES key (defaults to mirroring `KeychainLicenseStore`'s `kSecAttrAccessibleAfterFirstUnlock` absent a reason to diverge)

## Deferred Ideas

None — discussion stayed within phase scope. Three UI-domain todos (calendar month-grid polish, island disappearing during click-through, Quick Action disabled-state gate) were surfaced by the automated todo/phase matcher but judged false positives (generic keyword overlap, not persistence-related) and not presented to the user individually.
