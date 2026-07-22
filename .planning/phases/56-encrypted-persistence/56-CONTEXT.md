# Phase 56: Encrypted Persistence - Context

**Gathered:** 2026-07-22
**Status:** Ready for planning

<domain>
## Phase Boundary

`ClipboardFileStore` persists the Phase-55 `ClipboardStore` to disk under Application Support, encrypted via `CryptoKit.AES.GCM` with a Keychain-stored key, surviving app relaunch and machine reboot. On-disk layout is JSON index + separate image files (per ROADMAP.md), delete is hardened to only ever remove paths under the clipboard's own storage root (mirrors `ShelfFileStore`'s pattern). No live `NSPasteboard` monitoring (Phase 57) and no menu UI (Phase 58) — this phase is store↔disk round-trip only, proven by an injectable-root unit test and a real kill-and-restart check.

</domain>

<decisions>
## Implementation Decisions

### Corruption / key-loss recovery
- **D-04:** If `ClipboardFileStore` cannot decrypt the on-disk data on launch (corrupted file, or the Keychain key is missing/reset) — treat it exactly like "no history yet." The in-memory `ClipboardStore` starts empty; no crash, no error surfaced (no UI exists yet to show one). No special handling of the unreadable file — it is naturally overwritten the next time a successful save happens. Matches this project's established graceful-degradation convention (`NowPlayingMonitor` clears state and shows a fallback message instead of crashing on Phase 4/NOW-03; `KeychainLicenseStore.read()` treats a missing/malformed Keychain item as absent, `KeychainLicenseStore.swift:44-48`).

### Keychain key sync scope
- **D-05:** The clipboard's AES-GCM key is explicitly device-only — set `kSecAttrSynchronizable = false` (or omit + rely on the non-syncable default, whichever is the more explicit/intentional form during implementation) when writing the key to Keychain. Never iCloud-syncable. Rationale (user's explicit choice): unlike the license key (`KeychainLicenseStore`, fine to sync since it's tied to a purchase, not private data), clipboard content is genuinely personal, and this milestone has no cross-Mac data-sync mechanism for the JSON index itself — syncing only the key would buy nothing and only add exposure.

### Orphaned file cleanup on eviction
- **D-06:** When `ClipboardStore.append` evicts the oldest item past the 30-item cap (D-01), or D-02's dedupe removes-and-reinserts an existing item, the evicted/removed item's on-disk image file is deleted immediately as part of the same save — not left for a later sweep. `ClipboardFileStore`'s save path must diff against what's currently on disk and remove files for items no longer present in the store. Rationale (user's explicit choice): keeps image disk usage bounded to ~30 items at all times, same "never leak beyond what's live" discipline as `ShelfFileStore.deleteSessionCopy` (`Islet/Shelf/ShelfFileStore.swift:49-56`). Text-only items have no on-disk file to clean up (JSON index entry is simply omitted on next save).

### Carried forward from Phase 55 (not re-discussed) [informational]
Already implemented in `ClipboardStore.swift` by Phase 55 — listed here for background only. Phase 56's plans correctly leave `ClipboardStore.swift` untouched; these are not decisions this phase needs to (re-)implement.
- **D-01** [informational]: Cap = 30 items, FIFO eviction (`ClipboardStore.swift:13,25`).
- **D-02** [informational]: Re-copying existing content moves it to the top with a refreshed timestamp — never duplicates, never silently no-ops (`ClipboardStore.swift:18-26`).
- **D-03** [informational]: No size cap or truncation on individual items — `ClipboardFileStore` encrypts/persists content of any size unconditionally. Already explicitly scoped to cover Phase 56 in the original Phase 55 discussion.

### Claude's Discretion
- Exact on-disk JSON index shape (field names, whether image file paths are stored as relative filenames vs. UUIDs) — as long as the round-trip contract holds (SC#1) and the delete-path validation mirrors `ShelfFileStore` (SC#3).
- Application Support subfolder naming convention (e.g. `IsletClipboard/` under `FileManager.default.urls(for: .applicationSupportDirectory, ...)`) — mirrors `ShelfFileStore`'s `IsletShelf` naming under `NSTemporaryDirectory()`, adapted for a persistent (not session-temp) root.
- Whether `kSecAttrSynchronizable` is set to `false` explicitly or left at its (already non-syncable) default — implementation detail as long as the key never syncs via iCloud Keychain (D-05's actual requirement).
- Keychain accessibility attribute for the new AES key (e.g. `kSecAttrAccessibleAfterFirstUnlock`, mirroring `KeychainLicenseStore.swift:65`) — no reason cited to diverge from the existing precedent.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Roadmap & Requirements
- `.planning/ROADMAP.md` §"Phase 56: Encrypted Persistence" (lines 972-984) — goal, success criteria, explicit precedent citation (`ShelfFileStore`'s hardened delete pattern)
- `.planning/ROADMAP.md` line 147 — original one-line scoping note: "ClipboardFileStore: Application Support JSON index + image files, CryptoKit AES-GCM encryption with Keychain-stored key, survives relaunch/reboot"
- `.planning/REQUIREMENTS.md` §"Privacy & Security" (CLIP-04, PRIV-02) — persistence-across-relaunch/reboot and encryption-at-rest requirements this phase satisfies at the store/filestore layer (menu display is Phase 58)

### Phase 55 (prerequisite, data model this phase persists)
- `.planning/phases/55-clipboard-data-model-store/55-CONTEXT.md` — D-01/D-02/D-03 decisions this phase builds on
- `Islet/Clipboard/ClipboardItem.swift` — the value type being persisted (`id`, `kind` text/image, `timestamp`)
- `Islet/Clipboard/ClipboardStore.swift` — the append/evict/clear contract `ClipboardFileStore` must round-trip faithfully

No external ADRs/specs beyond the project's own planning docs.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Islet/Shelf/ShelfFileStore.swift` — the direct architectural precedent: a standalone `enum` (not a method on the pure logic type) doing real `FileManager` I/O, with a security-hardened delete that validates the target path lives under the store's own root before removing anything (lines 49-56). `ClipboardFileStore` should mirror this shape, rooted under Application Support instead of `NSTemporaryDirectory()`.
- `Islet/Licensing/KeychainLicenseStore.swift` — the direct Keychain precedent: `SecItemCopyMatching`/`SecItemAdd`/`SecItemDelete` with a defensive nil-fallback on every optional cast (lines 32-49), delete-then-add upsert (lines 51-67). Reuse this shape for storing/reading the raw AES key `Data`.

### Established Patterns
- No existing `CryptoKit`/`AES.GCM` or Application Support directory usage anywhere in the codebase — this phase is genuinely new ground for both, no prior art to diverge from or match beyond general project conventions (defensive nil-fallbacks, graceful degradation over crashes).
- Delete-path validation precedent: `ShelfFileStore.deleteSessionCopy` standardizes both the target and root paths, then checks `hasPrefix` before removing anything — a URL outside the store's root is a silent no-op, never an error (`ShelfFileStore.swift:49-56`). `ClipboardFileStore`'s delete/cleanup logic (D-06) must follow the same guard shape.

### Integration Points
- Phase 57 (`ClipboardMonitor`, live pasteboard polling) will call into whatever save/append surface this phase establishes.
- Phase 58 (menu wiring) is the first place any decrypt/read failure (D-04) or the empty-history state becomes visible to the user — this phase does not need to communicate the failure anywhere, just fail safely.

</code_context>

<specifics>
## Specific Ideas

No specific UI/visual references — this phase has no UI surface (menu wiring is Phase 58). All specifics captured above are architectural (D-04/D-05/D-06).

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

### Reviewed Todos (not folded)
- `2026-07-19-calendar-month-grid-polish.md`, `2026-07-19-island-briefly-disappears-during-click-through.md`, `2026-07-19-quick-action-disabled-state-has-no-controller-gate.md` — matched by the todo/phase matcher (generic keyword overlap on "phase"/"day") but all are UI-domain issues unrelated to encrypted disk persistence. Not presented individually — same false-positive judgment as Phase 55's cross-reference.

</deferred>

---

*Phase: 56-Encrypted Persistence*
*Context gathered: 2026-07-22*
