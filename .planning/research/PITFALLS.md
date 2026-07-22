# Pitfalls Research

**Domain:** macOS clipboard-history feature (NSPasteboard polling + persistence) added to an existing menu-bar agent (Islet)
**Researched:** 2026-07-22
**Confidence:** MEDIUM-HIGH (verified against Maccy's open-source implementation, the nspasteboard.org spec, real Bitwarden/1Password GitHub issues, and Apple's macOS 15.4/26 pasteboard-privacy changes; some items — the new OS-level pasteboard access prompt — are recent enough that behavior on directly-notarized non-sandboxed apps isn't fully documented yet)

## Critical Pitfalls

### Pitfall 1: Self-capture loop on "click-to-restore"

**What goes wrong:**
The feature's own "click an entry → copies it back onto `NSPasteboard.general`" action (click-to-restore, not auto-paste, per this milestone's spec) increments `changeCount` exactly like any other copy. A naive poll loop sees that change on its very next tick and re-adds the restored item as a brand-new history entry — duplicating it, bumping it to the top, and in the worst case (if eviction + restore both touch state) creating a feedback loop that never settles.

**Why it happens:**
The poll loop has no way to distinguish "the user copied something in another app" from "I just wrote to the pasteboard myself" — `NSPasteboard` gives you a `changeCount`, not provenance. This is invisible in dev testing if the copy-back is tested only once per session; it shows up the moment someone restores an item, then restores a second one right after.

**How to avoid:**
Mirror Maccy's proven pattern (`p0deje/Maccy/Clipboard.swift`, MIT-licensed, verified against the actual source): before writing the restored value back, tag the write with a private marker pasteboard type (e.g. `com.islet.clipboardhistory.restored`, matching Maccy's own `.fromMaccy` type), and have the poll's ingestion step skip any item whose types include that marker. The cheapest correct version, if a custom type feels like overkill: wrap the restore call in a single flag (`isRestoringFromHistory = true`), set it immediately before writing, clear it after the write call returns, and have the poll handler's changeCount-diff branch check-and-skip while the flag is set — since both happen synchronously on the main thread there is no race window as long as polling runs on the same run loop as the restore call. The marker-type approach is more robust (also survives cases where something else copies in the brief window between the flag set/clear), so prefer it.

**Warning signs:**
Clicking an old entry causes it to jump to the top of the list as a "new" duplicate entry instead of just being copied silently; rapid restore-then-restore produces runaway duplicate growth.

**Phase to address:**
The polling/monitoring task, in the same commit that introduces click-to-restore — this is not a separable follow-up fix, since a bare polling implementation without this guard demonstrates the bug on the very first manual test.

---

### Pitfall 2: Over-aggressive polling interval, and the "clipboard manager causes system instability" folklore

**What goes wrong:**
Community reports of clipboard managers "destabilizing macOS" (CopyClip, Alfred, various Clipy forks) are almost never traced to a documented Apple pasteboard bug. Investigation of an actual open-source implementation (Maccy) and general pasteboard-server crash reports shows the pattern is instead: (a) polling far too frequently (sub-100ms) on the mistaken belief that faster polling reduces missed clips — the system pasteboard server has no rate limit, but every needless main-thread poll that also calls `.types`/`.data(forType:)` on large payloads (multi-MB images) adds up; (b) doing pasteboard reads off the main thread — `NSPasteboard` is an AppKit type and is not documented as safe to call from a background thread/queue; (c) synchronously decoding full pasteboard content (images especially) inline on every timer tick regardless of whether `changeCount` actually changed, rather than gating the expensive work behind the cheap counter check.

**Why it happens:**
Developers new to this domain assume the pasteboard needs "watching" the way a file needs watching, and either poll too fast, or do the heavy content read (image decode, thumbnail generation) inline on the timer callback instead of gating all real work behind a `changeCount` diff check first.

**How to avoid:**
1. Gate every tick behind a cheap `changeCount` comparison first — only if it changed do you touch `.types` or `.data(forType:)`.
2. Use Maccy's shipped default of 500ms (`clipboardCheckInterval`, user-configurable down to 100ms) as the reference safe interval — verified from Maccy's actual source (`Maccy/Clipboard.swift`). There is no Apple-published "minimum safe interval"; 500ms is the community-converged default across mature clipboard managers and imposes negligible CPU/battery cost for a single `Int` comparison per tick.
3. Do all pasteboard reads and history-array mutations on the main thread/run loop (matching the existing `DragApproachDetector` pasteboard-polling seam already in this codebase) — do not spin this on a background `DispatchQueue`.
4. Never hold onto the raw `NSPasteboardItem` returned by `pasteboard.pasteboardItems` past the current tick — extract only the primitive data/string/image bytes you need and let the pasteboard-owned object go, rather than retaining references in the history model.

**Warning signs:**
Noticeable CPU usage from Activity Monitor for the app while idle; UI stutter in the frontmost app right after a copy; growing memory footprint that correlates with copy frequency rather than history-array size.

**Phase to address:**
The polling task (initial implementation) — set the interval and the changeCount-gate structurally correct from the start; do not ship at a faster-than-500ms interval "to feel more responsive" without a specific, tested reason.

---

### Pitfall 3: `@Published` array holding full-resolution image data in memory

**What goes wrong:**
Storing full TIFF/PNG `NSImage` data for every image copy directly in the `@Published` history array (the natural "just append to the array" implementation) means 20-30 items can easily reach tens to hundreds of MB in memory if the user copies several full-resolution screenshots or photos — and because it's `@Published`, every mutation (even evicting the oldest text item) re-triggers SwiftUI diffing over the entire array, including large image payloads, on the main thread.

**Why it happens:**
The path of least resistance — "capture what's on the pasteboard, put it in the array" — doesn't distinguish "the thing to persist/restore" from "the thing to render in the dropdown list," and a first-time implementation has no reason to think about the difference until memory pressure or UI jank actually shows up on real hardware.

**How to avoid:**
- Store a small (e.g. 64-128pt) downsampled thumbnail `NSImage`/`Data` in the in-memory `@Published` model for list rendering — never the original resolution.
- Write the full-resolution image bytes to disk (Application Support, not memory) at capture time, keyed by a UUID; the in-memory model holds only the thumbnail + a file reference. Restore-to-pasteboard reads the full file back in at click time, not continuously.
- Cap total on-disk footprint implicitly via the existing 20-30 item eviction — delete the backing file when an item is evicted (mirroring the existing `ShelfFileStore`/`deleteSessionCopy` pattern already in the codebase for file cleanup, including its recent "validate delete target lives under our own root" hardening — reuse that same discipline here, don't recursively delete without a path-containment check).
- Never persist raw TIFF from `NSImage.tiffRepresentation` if avoidable — encode to a compressed format (PNG/HEIC/JPEG) before writing to disk to keep both disk and thumbnail-generation cost bounded.

**Warning signs:**
Memory footprint growing noticeably after copying several images; visible scroll/hover lag in the status-item dropdown once a few image entries exist; app memory not shrinking after the 20-30 item cap evicts old items (indicates a retain-cycle or the full data is still cached somewhere after eviction).

**Phase to address:**
The persistence/storage task must establish "thumbnail in memory, full image on disk" as the model shape from day one — retrofitting this after an in-memory-only version ships means migrating existing persisted history, which is unnecessary churn to build twice.

---

### Pitfall 4: Concealed/transient/autogenerated marker checking is necessary but not sufficient

**What goes wrong:**
`org.nspasteboard.ConcealedType`/`TransientType`/`AutoGeneratedType` is an opt-in, voluntary convention, not an OS-enforced flag — checking `pasteboardItem.types.contains(.concealed)` (or the equivalent raw UTI string) is the correct first-line check and will correctly exclude apps that follow the convention (1Password sets its own custom UTI `com.agilebits.onepassword`; LastPass sets `org.nspasteboard.TransientType`). But it is verifiably unreliable as the *only* line of defense: Bitwarden's own GitHub issue tracker (`bitwarden/clients#326`, `bitwarden/desktop#350`, `bitwarden/clients#17404`) documents that its browser-extension password-copy path sets a generic `public.utf8-plain-text` type with **no** concealed/transient marker at all — meaning a naive marker-only check will still capture and persist a plaintext password copied via Bitwarden's browser extension. The same gap applies to any terminal copying a token, a `git`/crash-log output containing a secret, or a personal message pasted from a text editor — none of these are ever marked, because the marker convention only covers apps that deliberately implement it (a subset of password managers), not "any text a user happens to consider sensitive."

**Why it happens:**
Developers read the nspasteboard.org spec, implement the type check, and consider sensitive-content handling "done" — the spec's existence creates false confidence that all sensitive-content sources participate, when in practice only a subset of well-behaved apps do, and even among password managers, adoption is inconsistent (Bitwarden's own case, confirmed via its own open issue tracker).

**How to avoid:**
- Implement the `types.contains(...)` check for `org.nspasteboard.ConcealedType`, `TransientType`, `AutoGeneratedType` as the baseline filter (this is required scope) — this alone correctly excludes 1Password/LastPass/any well-behaved password manager.
- Treat this as necessary-but-incomplete: do not present it to the user as "your passwords are safe" — any user-facing copy should say "marked-sensitive copies are excluded," not "sensitive data is excluded."
- Since this gap is inherent to the convention (not fixable at the polling layer), the mitigation belongs in the persistence layer (Pitfall 5): treat everything captured as potentially sensitive at rest, since marker-based filtering demonstrably lets real secrets through today.
- A content-sniffing heuristic (flagging strings that look like tokens/API keys) is a plausible future differentiator, not v1.9 scope (the milestone explicitly has no search/filter UI) — do not build this speculatively now.

**Warning signs:**
None visible in normal testing — this pitfall doesn't fail loudly, it silently succeeds at capturing content it shouldn't. The only way to "detect" it during dev is to deliberately test against a known-non-compliant source (e.g. copy a fake password-looking string from a terminal, or research a Bitwarden-browser-extension-style copy) and confirm it does show up in history despite the marker check being correctly implemented — this is expected, not a bug in the marker-check code itself.

**Phase to address:**
The capture/filtering task must implement the marker check (required requirement). The persistence task (Pitfall 5) must independently treat all captured content as sensitive-by-default regardless of marker status, since the marker check cannot be made airtight.

---

### Pitfall 5: Storing clipboard history at rest unencrypted

**What goes wrong:**
Clipboard content is disproportionately likely to contain secrets even without any app ever setting a concealed marker — this project's own CopyClip reference screenshot (captured during the milestone discussion) already shows tokens/commands sitting in plaintext history. A naive persistence implementation (plist, JSON file, or raw `FileManager` writes in Application Support) stores this at rest exactly as captured, in a location any other process running as the same user (or anyone with local disk/Time Machine backup access) can read without any additional permission — no sandbox, no Keychain, no TCC gate protects a plain file on disk.

**Why it happens:**
"Just write it to a JSON file" is the natural, simplest persistence approach, and nothing in the implementation path forces a developer to think about at-rest confidentiality the way, say, a password field visibly demands it — the sensitivity of clipboard data is easy to underestimate because most day-to-day copies (a URL, a sentence) are genuinely harmless, until the one crash log or token copy sits in that same file indefinitely.

**How to avoid:**
- Given Pitfall 4 establishes the marker check cannot fully exclude secrets, treat the persisted history file itself as sensitive data and encrypt it at rest. The practical, low-effort mechanism for a non-sandboxed macOS app: encrypt the serialized blob with a symmetric key (`CryptoKit.AES.GCM`), with the key itself stored in the macOS Keychain (`kSecClassGenericPassword`), not hardcoded or derived from anything guessable. The Keychain item is protected by the OS and tied to the user's login keychain, matching the pattern already validated and shipped in this project's own trial/license persistence (Phase 10: "start timestamp persisted to the Keychain, survives `defaults delete` and reinstall").
- Do not ship even a temporary plaintext version during development that a real user could end up running — write encrypted from the first version, since retrofitting encryption onto an already-shipped plaintext format means a migration step existing users' history must survive.
- "Delete All History" must actually delete the on-disk encrypted blob (and any per-image files from Pitfall 3), not just clear the in-memory array — otherwise the encryption's at-rest guarantee is undermined by a delete that doesn't actually delete.
- This is proportionate effort for a hobby/personal-budget, first-time-programmer project: `CryptoKit` is a first-party, zero-dependency framework (ships with the OS, no new library, no server, no license cost) — squarely within scope, not gold-plating.

**Warning signs:**
Opening the persisted history file directly (text editor / `cat` / `plutil`) shows readable clip content — this is the direct, testable check: after copying a fake "token"-looking string and quitting the app, the on-disk file should be unreadable ciphertext, not plaintext.

**Phase to address:**
The persistence task, from its first implementation — this must not be a "harden later" item, since real user clipboard history (containing exactly the tokens/commands this project's own CopyClip reference screenshot showed) would already be at rest, unencrypted, the moment even one plaintext version ships to a real user.

---

### Pitfall 6: Assuming a special entitlement is needed for pasteboard access (this project is NOT App Sandboxed)

**What goes wrong:**
Some developers, having read about App Sandbox `com.apple.security.temporary-exception.*` entitlements or the newer per-app pasteboard `accessBehavior` privacy prompt, spend time hunting for an "entitlement to add" before pasteboard reads work — when for this project's actual distribution model (direct download, Developer-ID signed + notarized, explicitly NOT sandboxed, NOT App-Store-distributed per `.planning/PROJECT.md` Constraints — the same reason MediaRemote already forced this distribution path) there is no entitlement gate at all for reading `NSPasteboard.general`. Full, unrestricted programmatic pasteboard access is the default for any non-sandboxed macOS app, and always has been — no entitlement, sandboxed or not, changes that baseline for a non-sandboxed app.

**Why it happens:**
Sandboxed-app documentation (Mac App Store apps) prominently discusses pasteboard entitlement nuances, and that documentation is what search results surface first, creating a false impression that entitlements are universally required.

**How to avoid:**
Confirm no entitlement work is needed for the core read/write pasteboard access itself — `Islet.entitlements` needs no new key for this feature. The one genuinely new consideration for this exact OS generation (macOS 26 "Tahoe", the project's target OS per existing PROJECT.md references to "macOS 26 menu bar") is Apple's newly-shipped pasteboard-privacy preview (introduced as a developer preview in macOS 15.4, rolling out more broadly around macOS 26): the OS can show a system alert the first time an app programmatically reads the general pasteboard outside of a direct user paste-gesture, and exposes a per-app `NSPasteboard.accessBehavior` (always-allow / never-allow / ask) that the user controls in System Settings. Since a clipboard-history feature's entire premise is "read the pasteboard without a user-initiated paste gesture," a background poll is precisely the pattern this system is designed to flag. Concretely: (a) check `NSPasteboard.general.accessBehavior` at launch, and if it is not `.always`, show a one-time in-app explanation before the feature starts polling (mirroring how the project already handles Bluetooth/Calendar/Reminders/Focus permission surfaces elsewhere), rather than silently polling and surprising the user with an unexplained system prompt; (b) do not assume this is a signing/entitlement problem if a prompt or restriction appears on macOS 26 hardware — it is a runtime user-consent gate, orthogonal to code signing, and the fix is UX (explain, point to System Settings), not an Info.plist/entitlements change.

**Warning signs:**
An unexpected system alert about pasteboard access appears the first time the feature runs on a real Mac; history stops updating silently on some user's machine despite no crash or error in the app's own logs (indicates the user denied pasteboard access in System Settings and the app isn't checking/surfacing `accessBehavior`).

**Phase to address:**
The polling/monitoring task should include the `accessBehavior` check as part of its initial on-device verification checklist (this is exactly the class of "looks done but isn't" issue this project's own retrospectives repeatedly flag — permission surfaces that only manifest on real hardware, matching the pattern already seen with Focus Mode's `NSFocusStatusUsageDescription`/Communication Notifications entitlement in Phase 38 and Bluetooth TCC in `BluetoothMonitor`). No entitlements file change is needed; a Settings/onboarding explanation and a runtime `accessBehavior` check are.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|-----------------|------------------|
| Skip the self-capture guard (Pitfall 1), ship "click restores, sometimes duplicates" | Faster initial implementation | Visible, embarrassing bug on the very first restore-then-restore test | Never — this is cheap to do correctly from the start |
| Store full-resolution images in the `@Published` array "for now" | Simpler initial data model | Memory bloat + UI jank once real users copy screenshots; requires a data-model migration later | Never for the shipped version — acceptable only for a throwaway spike, not the actual feature |
| Plaintext JSON persistence "we'll encrypt later" | Faster to get persistence working end-to-end | Any real user's already-captured tokens/logs sit unencrypted, and the eventual migration must handle existing plaintext files without losing history | Never — `CryptoKit` + Keychain-stored key is not meaningfully harder than plaintext JSON, do it once |
| Marker-only sensitive-content filtering, no framing to the user about its limits | Satisfies the literal requirement quickly | Users may believe "sensitive copies are excluded" applies to all secrets, when Bitwarden's own browser extension proves otherwise | Acceptable as the only *filtering* mechanism (nothing else is feasible), but pair with mandatory at-rest encryption (Pitfall 5) so the gap is covered by depth, not by an unfounded promise |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|-----------------|-------------------|
| `NSPasteboard.general` polling | Reading pasteboard content on every timer tick regardless of `changeCount` | Gate all content reads behind a `changeCount` diff; only decode/copy data when it actually changed |
| Existing `DragApproachDetector` pasteboard seam | Building a second, independent polling timer/loop for clipboard history without reusing the established pattern | Follow the same polling shape (timer cadence, main-thread discipline) already established in `DragApproachDetector`, to avoid two competing pasteboard-read code paths |
| Existing `ShelfFileStore`/`deleteSessionCopy` pattern | Writing a second, independent file-deletion routine for evicted clipboard images without the same path-containment validation `ShelfFileStore` was hardened to include | Reuse or directly mirror the "validate delete target lives under our own storage root" check already fixed in Phase 19, rather than reintroducing the same class of bug in a new file store |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|-----------------|
| Sub-100ms polling interval | Elevated idle CPU, warm fan, faster battery drain | Default to 500ms (Maccy's proven default), gated behind `changeCount` | Immediately noticeable on a laptop running on battery, not just "at scale" |
| Full-resolution image storage in `@Published` array | SwiftUI re-diffs large image data on every unrelated mutation (e.g. evicting a text item) | Thumbnail in memory, full image on disk (Pitfall 3) | Breaks as soon as a user copies 2-3 full-resolution screenshots into a 20-30 item history |
| Re-encoding/writing to disk synchronously on the main thread during a poll tick | Momentary UI hitch right after a large image copy | Do image thumbnail generation + disk write off the main thread (background queue), only marshal the small in-memory thumbnail back to the `@Published` model on the main thread | Any image copy of non-trivial size (a few MB+) |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Marker-only sensitive-content filtering treated as complete | Plaintext secrets from non-compliant sources (e.g. Bitwarden's browser extension, terminal token copies) persisted in history | Implement the marker check (required) but pair with mandatory at-rest encryption (Pitfall 5) as defense in depth |
| Unencrypted persistence file | Any local process/user or backup snapshot can read the user's full clipboard history, including inadvertently-captured secrets | Encrypt the serialized history with `CryptoKit.AES.GCM`, key stored in Keychain — same pattern already shipped for license/trial data (Phase 10) |
| "Delete All History" only clearing the in-memory array | Encrypted-at-rest guarantee undermined if the on-disk blob (and any per-item image files) survive a user-initiated delete | Delete action must remove the on-disk encrypted store and all backing image files, not just reset the `@Published` array |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-------------------|
| Silent system pasteboard-access prompt with no in-app context | User sees an unexplained macOS permission alert and may deny it, silently breaking the feature with no visible error in the app | Show a one-time in-app explanation before first pasteboard poll on macOS 26+, matching the project's existing permission-surface UX pattern (Focus Mode, Bluetooth, Calendar) |
| Restoring an old entry visibly re-adds it to the top as "new" | Confusing, makes the history list feel broken/duplicated | Fix via the self-capture guard (Pitfall 1) — restoring must be a true no-op for history-list purposes |
| Overselling "sensitive copies are excluded" in Settings copy or onboarding | False sense of security if a user assumes ALL secrets (not just marker-compliant ones) are excluded | Word any user-facing description carefully ("copies marked sensitive by the source app are excluded") and let at-rest encryption cover the residual risk silently, without over-promising |

## "Looks Done But Isn't" Checklist

- [ ] **Click-to-restore:** Often missing the self-capture guard — verify by restoring an entry, then immediately restoring a second entry, and confirming neither creates a duplicate top-of-list entry.
- [ ] **Sensitive-content exclusion:** Often verified only against a compliant app (a system password field or 1Password) — verify additionally against a known non-compliant source (a terminal copy of a fake token) and confirm at-rest encryption (not the marker filter) is what protects that case.
- [ ] **Image storage:** Often verified only with small test images — verify by copying several full-resolution screenshots and checking both memory footprint (Activity Monitor) and that eviction actually frees the backing disk file, not just the in-memory thumbnail.
- [ ] **Persistence across relaunch/reboot:** Often verified only for relaunch — verify a genuine reboot (not just quit/relaunch) survives, since some persistence bugs only surface across a full logout/login cycle.
- [ ] **Delete All History:** Often clears only the visible list — verify the on-disk encrypted file (and any per-image files) are actually gone afterward, not just the in-memory array.
- [ ] **Pasteboard access prompt (macOS 26):** Often untested until real hardware — verify on-device whether the system pasteboard-access alert appears, and that the app's own explanation (if any) is shown first or at least doesn't contradict it.

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|----------------|------------------|
| Self-capture duplicate loop shipped | LOW | Add the self-capture guard (marker type or flag); existing duplicate entries can be de-duplicated on next launch by a one-time cleanup pass (compare content+timestamp proximity) |
| Full-resolution images stored in memory/persisted | MEDIUM | Requires a data-model migration: on next launch, regenerate thumbnails from existing full images, move full images to disk, rewrite the persisted store in the new encrypted format |
| Plaintext persistence already shipped | MEDIUM | One-time migration: read the old plaintext file, re-serialize through the new `CryptoKit`-encrypted path, delete the old plaintext file (the practical bar is "don't ship a second plaintext copy going forward," not guaranteed secure-erase on SSD/APFS, which isn't reliably achievable anyway) |
| Missing pasteboard-access-prompt handling | LOW | Add the `accessBehavior` check and one-time explanation in a follow-up patch; no data migration needed, purely additive UX |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|-------------------|----------------|
| 1. Self-capture loop on restore | Polling/monitoring implementation task | Restore-then-restore manual test produces no duplicate entries |
| 2. Over-aggressive polling / thread discipline | Polling/monitoring implementation task | Activity Monitor idle-CPU check; changeCount-gate code review |
| 3. Full-resolution images in `@Published`/at rest | Persistence/storage implementation task | Memory check after copying several full-res screenshots; confirm on-disk thumbnail vs. full-image split |
| 4. Marker check incomplete for real secrets | Capture/filtering task (marker check) + Persistence task (encryption as backstop) | Test against a known non-compliant source (a terminal token-looking copy) and confirm encryption still protects it at rest |
| 5. Unencrypted persistence at rest | Persistence/storage implementation task | Inspect the on-disk file directly (`cat`/`plutil`) and confirm ciphertext, not plaintext |
| 6. Pasteboard-access entitlement confusion / macOS 26 prompt | Polling/monitoring implementation task, on-device UAT | On-device check on macOS 26 hardware for the system prompt; confirm no entitlements file change was needed |

## Sources

- [Maccy/Maccy/Clipboard.swift](https://github.com/p0deje/Maccy/blob/master/Maccy/Clipboard.swift) — verified open-source implementation of changeCount polling, self-copy marker type, `ignoredTypes` (autoGenerated/concealed/transient) filtering, and the default 500ms `clipboardCheckInterval`
- [NSPasteboard.org — Identifying and Handling Transient or Special Data on the Clipboard](https://nspasteboard.org/) — the org.nspasteboard.* convention spec itself
- [Bitwarden desktop#350 — Clipboard data is not marked as concealed on macOS](https://github.com/bitwarden/desktop/issues/350)
- [Bitwarden clients#326 — Set pasteboard type for clipboard contents](https://github.com/bitwarden/clients/issues/326)
- [Bitwarden clients#17404 — Browser extension does not set pasteboard type for copied text](https://github.com/bitwarden/clients/issues/17404)
- [Michael Tsai — Pasteboard Privacy Preview in macOS 15.4](https://mjtsai.com/blog/2025/05/12/pasteboard-privacy-preview-in-macos-15-4/) — `NSPasteboard.accessBehavior`, system prompt on programmatic pasteboard reads
- [MacRumors — Apple to Block Mac Apps From Secretly Accessing Your Clipboard](https://www.macrumors.com/2025/05/12/apple-mac-apps-clipboard-change/)
- [9to5Mac — macOS 16 to enable clipboard privacy protection](https://9to5mac.com/2025/05/12/macos-16-clipboard-privacy-protection/)
- Project's own `.planning/PROJECT.md` — existing `DragApproachDetector` pasteboard-polling precedent, `ShelfFileStore`/`deleteSessionCopy` path-containment hardening (Phase 19), Keychain-backed trial persistence precedent (Phase 10), Constraints (direct notarized distribution, not sandboxed, not App Store), Context (first-time-programmer builder skill)

---
*Pitfalls research for: macOS clipboard-history menu-bar feature (Islet v1.9)*
*Researched: 2026-07-22*
