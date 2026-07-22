# Feature Research

**Domain:** macOS menu-bar clipboard history manager (v1.9 addition to Islet, replacing CopyClip)
**Researched:** 2026-07-22
**Confidence:** MEDIUM-HIGH (CopyClip/Maccy/Paste feature claims verified across multiple sources incl. GitHub issues and vendor sites; exact CopyClip internals inferred from its own UI conventions since it's closed-source)

> Supersedes the prior FEATURES.md content (Now Playing "like" button + audio output switcher, v1.7 candidate research, dated 2026-07-19) — that scope is a different, still-paused milestone; its content is preserved in git history, not here. This file is scoped entirely to v1.9 (Clipboard History).

## Feature Landscape

### Table Stakes (Users Expect These)

These map directly to what the user already confirmed during milestone discussion — none of this is optional for v1.9.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Recent-items list, MRU order | Every clipboard manager (CopyClip, Maccy, Clipy, Flycut) shows newest copy first | LOW | Prepend on capture; no sort logic needed beyond insertion order |
| Item count cap (~20-30) with FIFO eviction | CopyClip's free tier shows 20 in the menu; matches user's confirmed 20-30 cap | LOW | A bounded array/ring buffer — evict oldest past the cap, no pagination needed |
| Click-to-restore (copy to pasteboard, no auto-paste) | Confirmed against user's CopyClip screenshot; this is CopyClip's actual behavior, not an assumption | LOW | Write item back to `NSPasteboard.general`; do NOT synthesize a Cmd+V keystroke into the frontmost app |
| Text preview with single-line truncation + ellipsis | Every reviewed app (CopyClip, Maccy, Clipy) truncates long text to one line in the row | LOW | Standard `NSString`/SwiftUI `.lineLimit(1)` + `.truncationMode(.tail)`; no need for multi-line preview logic |
| Image support (not just text) | User explicitly confirmed text + images; CopyClip 2 and Paste both support image clips | MEDIUM | Needs a thumbnail render path for the menu row — see storage note in Anti-Features |
| ⌘0–⌘9 quick-select key equivalents | Directly visible in the user's CopyClip reference screenshot; long-standing CopyClip convention | LOW | `NSMenuItem.keyEquivalent` on the first 10 rows only — a cosmetic/muscle-memory feature for the exact app being replaced |
| Persistence across relaunch + reboot | User explicitly confirmed this as deliberately different from the session-only Shelf | LOW-MEDIUM | Small on-disk store (see Anti-Features re: no DB needed at this scale); load on launch, save on each capture |
| Sensitive-content exclusion via `org.nspasteboard.ConcealedType`/`TransientType` | Confirmed by user; also the de-facto standard convention respected by CopyQ, and referenced directly on nspasteboard.org | LOW | Check pasteboard types for these two UTIs before capturing; skip silently, no user-facing prompt needed |
| "Delete All History" action | Confirmed by user; present in CopyClip ("Delete All History" menu item), Alfred ("Clear Clipboard History"), and effectively every competitor | LOW | See UX Conventions section below for confirmation-dialog norm |
| Pasteboard-monitoring via `NSPasteboard.general.changeCount` polling | macOS has no native "clipboard changed" notification API — every reviewed app (Maccy, Clipy, Flycut) polls `changeCount`; project's own `DragApproachDetector` already does this pattern | LOW-MEDIUM | Reuse the existing polling pattern already in the codebase rather than inventing a new mechanism (see PROJECT.md Key Context) |

### Differentiators (Competitive Advantage — mostly out of scope for v1.9)

These set CopyClip/Maccy/Paste apart from a bare-bones history. The user has explicitly scoped search/filter OUT of v1.9; flagged here only for the "Future Requirements" backlog.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Search/filter across history | Maccy's headline feature ("keyboard-first... instant text search"); CopyClip 2 also offers it | MEDIUM | **Explicitly deferred by user for v1.9.** Flag for v2: worth building the data model so full text is stored (not just a pre-truncated preview string) now, so search doesn't require a migration later |
| Pin/favorite items to top | CopyClip 2 (⇧⌘P), Paste's "pinboards" both offer this | LOW-MEDIUM | **Not requested for v1.9.** Flag for v2 — cheap to add later (a boolean flag + stable sort) if the data model already keeps items as discrete records with stable IDs rather than a flat rolling log |
| Categorized/typed history (separate text vs. image sections, or custom pinboards) | Paste's multi-pinboard model | MEDIUM-HIGH | Not requested; adds real UI complexity (tabs/sections) disproportionate to a 20-30 item cap. Not worth flagging for v2 unless the item cap itself grows substantially |
| Cross-device sync (iCloud) | Paste 5.0's rebuilt sync engine, shared pinboards | HIGH | **Do not flag as a near-term v2 candidate.** Clipboard content is uniquely sensitive (passwords near-misses, personal data) — sync introduces E2E-encryption and multi-device conflict-resolution scope disproportionate to this app's local-utility positioning. Maccy's own philosophy (no cloud, no telemetry) is closer to Islet's existing local-only architecture |
| Per-app exclude list (beyond the nspasteboard convention) | CopyClip lets users manually exclude specific source apps from capture | LOW-MEDIUM | Worth a v2 flag: the nspasteboard convention only covers apps that opt in (mostly password managers); a manual per-app blocklist is a reasonable, cheap follow-up for apps that don't mark sensitive data correctly |
| Per-item delete (not just Delete All) | Common in Maccy/Clipy via right-click/context menu | LOW | User only confirmed "Delete All History." Worth a v2 flag since it's a small addition (single row-remove) once the base UI exists, but do not build it speculatively now — YAGNI until requested |

### Anti-Features (Commonly Requested, Often Problematic)

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|------------------|-------------|
| SQLite/Core Data-backed history store | "Proper" persistence layers feel more robust; Maccy itself uses SQLite/SwiftData | At a 20-30 item cap this is pure over-engineering — no query performance problem exists to solve. Maccy's own GitHub issue #1097 shows the *real* pain point in these apps only appears at 30,000+ items (UI rendering all rows at once), which is irrelevant here | A capped in-memory array persisted as a small JSON/plist manifest + individual image files on disk. Simple, fast, trivially inspectable |
| Full pasteboard-type coverage (RTF, RTFD, HTML, file URLs, custom UTIs) from day one | "What if someone copies a file / rich text?" | Every additional UTI is another capture path, preview renderer, and restore path to test and maintain; CopyClip's actual reference (and the user's confirmed scope) is plain text + images only | Capture only `public.utf8-plain-text` and image types (PNG/TIFF) for v1.9; anything else silently falls through (matches Flycut's own stated limitation: "isn't designed for copying images or tables" in its base form) |
| A brand-new custom popover/panel UI for the dropdown | Feels more "modern" (Maccy 2.0, Paste both use custom windows) | The existing status-item menu (Settings…/Check for Updates/Quit from Phase 0) is already a plain NSMenu, and the user explicitly said this is additive to that menu, NOT a new Island/notch view. Building a parallel NSPanel here duplicates the app's existing menu-bar interaction model for no benefit at a 20-30 item cap | Extend the existing NSMenu with custom `NSMenuItem`s (an `NSHostingView` wrapping a small SwiftUI row for preview + thumbnail). See UI section below for the full tradeoff |
| Cloud sync / shared history | Feels "modern," competitors (Paste) offer it | Massively expands scope: needs an account system, E2E encryption for what is inherently sensitive data, conflict resolution across devices — nothing the user asked for and inconsistent with Islet's local-only posture | Local-only persistence, matching Maccy's explicit "no cloud sync, no telemetry" positioning |
| Building search/indexing infrastructure now "to be ready for v2" | Seems efficient to build once | Speculative work for an explicitly deferred feature; risks over-designing the data model around a feature that may change shape before v2 is actually planned | Just don't pre-truncate the underlying stored text (store the full string, only truncate at render time) — that alone is enough runway for v2 search without building the search feature itself now |
| Unbounded/full-resolution image storage | "Don't lose quality" | Clipboard images (especially from screenshots) can be several MB each; even at a 20-30 item cap, unbounded full-res storage adds up and slows the menu (rendering large images in row previews) | Store a compressed/downscaled thumbnail for the menu row; if full-res restore-to-pasteboard is needed, keep the original once and only thumbnail for display — do not generate multiple derivative sizes speculatively |

## Feature Dependencies

```
Pasteboard-monitoring seam (changeCount polling)
    └──requires──> Sensitive-content check (org.nspasteboard types)
                       └──feeds into──> Capture + capped history store
                                            └──feeds into──> Menu row rendering (text truncation / image thumbnail)
                                            └──feeds into──> Click-to-restore
                                            └──feeds into──> ⌘0-⌘9 key equivalents (first 10 rows only)
                                            └──feeds into──> Delete All History

[Search (v2, deferred)] ──requires full stored text, not just preview──> Capture + capped history store
[Pin/favorite (v2, deferred)] ──requires discrete item records with stable IDs──> Capture + capped history store
```

### Dependency Notes

- **Everything depends on the pasteboard-monitoring seam existing first** — it's the one genuinely new subsystem (no existing code does this; `DragApproachDetector`'s polling pattern is the closest precedent, not a reusable implementation).
- **Sensitive-content check must run inside the capture path, not as a post-filter** — items must never reach the history store to begin with (no "capture then hide" step, since that would still risk exposure in the persisted file).
- **Search and Pin are the two deferred features that actually constrain today's data model.** Neither needs to be built now, but the history store should keep full text (not pre-truncated strings) and stable per-item identity (not just a flat rolling array with no IDs) so v2 doesn't require a data migration.

## MVP Definition

### Launch With (v1.9)

- [ ] Pasteboard-monitoring polling seam (`changeCount`) — nothing else works without it
- [ ] Sensitive-content exclusion (`org.nspasteboard.ConcealedType`/`TransientType`) — must be in the capture path from day one, not bolted on later
- [ ] Capped history store (~20-30 items, FIFO eviction), text + image, full text retained (not pre-truncated)
- [ ] Menu rows: single-line truncated text preview / image thumbnail, click-to-restore to pasteboard
- [ ] ⌘0-⌘9 key equivalents on the first 10 rows
- [ ] "Delete All History" menu action with a standard destructive-confirmation alert
- [ ] Persistence across relaunch/reboot (simple JSON/plist manifest + image files, no database)

### Add After Validation (v1.x, if requested)

- [ ] Per-item delete (single row removal) — small addition once the base list UI exists
- [ ] Per-app manual exclude list — cheap follow-up to the nspasteboard convention

### Future Consideration (v2+, explicitly deferred by user for v1.9)

- [ ] Search/filter across history — data model already supports it (full text retained); build the UI later
- [ ] Pin/favorite items to top — data model already supports it (stable item IDs); build the sort/UI later
- [ ] Categorized/typed history or multiple pinboards — only worth it if the item cap itself grows well past 20-30
- [ ] Cross-device sync — deliberately not recommended even for v2 given the sensitivity of clipboard data and Islet's local-only positioning

## UX Conventions: "Delete All History"

Reviewed pattern across CopyClip, Alfred's "Clear Clipboard History," and general macOS HIG guidance on destructive actions:

- **A single native confirmation alert (`NSAlert`), not a custom multi-step flow.** Destructive + irreversible data loss = confirm once, plainly: "Delete all clipboard history? This cannot be undone." with Cancel / Delete (destructive-styled) buttons.
- **No "don't ask again" checkbox.** This is an infrequent, deliberate action — suppressing the confirmation isn't something these apps offer, and it isn't worth the extra state to track.
- **The action itself stays a single menu item** ("Delete All History" in CopyClip's own dropdown, sitting below the item list) — no separate "history management" sub-window needed for v1.9's scope.

## Menu-Bar Dropdown UI: NSMenu vs. Custom Popover/Panel

This directly determines how the new history rows get added to Islet's existing status-item menu.

**What the reviewed apps actually do:**
- **CopyClip, Clipy, Flycut:** plain `NSMenu` with standard `NSMenuItem`s. The ⌘0-⌘9 key equivalents visible in the user's CopyClip screenshot are literally `NSMenuItem.keyEquivalent` — this is a strong signal CopyClip itself never left NSMenu.
- **Maccy 1.x:** also plain `NSMenu` — and hit real friction at scale: crashes on repeated "Select," couldn't resize, didn't render over password fields, full-screen apps, or Spotlight. Maccy 2.0 (2024) did a full rewrite to SwiftUI + `NSPanel` specifically to fix these.
- **Paste:** doesn't use a menu at all — it's a full custom floating window/launcher, because its feature set (multi-column pinboards, drag-and-drop, rich image grids, sync) genuinely needs arbitrary SwiftUI layout that NSMenu can't provide.

**Tradeoff:**

| | NSMenu (extend existing) | Custom NSPanel/popover |
|---|---|---|
| Effort | Low — reuses the status item's existing menu (Settings…/Quit already live there) | Medium-high — new window management, click-outside-dismiss, focus-safety, full-screen/Spotlight edge cases all need reimplementing |
| System feel | Free — looks/behaves like every other menu-bar dropdown | Must be manually tuned to avoid feeling like "a floating app" |
| Scrolling for long lists | Automatic scroll arrows once content exceeds screen height — a non-issue at a 20-30 item cap | Must build your own scroll view |
| Known failure mode | AppKit `NSMenu` quirks emerge at *large* scale (Maccy's issues appeared with heavy interactive manipulation and eventually 30k+ item histories) — irrelevant at 20-30 items | None specific, but is strictly more code to own |
| Row customization | Achievable via `NSHostingView`-wrapped SwiftUI content per `NSMenuItem` — sufficient for a preview + thumbnail row | Full arbitrary SwiftUI, needed only if search boxes, multi-column layouts, or drag-and-drop are required |

**Recommendation:** Extend the existing status-item `NSMenu` with custom `NSMenuItem` rows (an `NSHostingView` wrapping a small SwiftUI view per row for text truncation + image thumbnail), rather than introducing a new `NSPanel`/popover. This matches the user's explicit "additive to the existing menu-bar status item, not a new Island view" decision, matches CopyClip's own approach (the app being replaced), and avoids the class of problems (Maccy 2.0's rewrite motivation) that only bite at scales far beyond this app's 20-30 item cap. Revisit only if v2 adds an inline search text field inside the dropdown — that's the one interaction NSMenu handles poorly and is the actual trigger that pushed Maccy to NSPanel.

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|----------------------|----------|
| Pasteboard-monitoring seam | HIGH | MEDIUM | P1 |
| Sensitive-content exclusion | HIGH | LOW | P1 |
| Capped history store (text+image, persistent) | HIGH | MEDIUM | P1 |
| Click-to-restore | HIGH | LOW | P1 |
| Text truncation / image thumbnail preview | HIGH | LOW | P1 |
| ⌘0-⌘9 key equivalents | MEDIUM | LOW | P1 |
| Delete All History (with confirm) | HIGH | LOW | P1 |
| Per-item delete | MEDIUM | LOW | P2 |
| Per-app manual exclude list | LOW-MEDIUM | LOW-MEDIUM | P2 |
| Search/filter | HIGH (per competitor emphasis) | MEDIUM | P3 (explicitly deferred) |
| Pin/favorite | MEDIUM | LOW-MEDIUM | P3 (explicitly deferred) |
| Cross-device sync | LOW (not requested, conflicts with app positioning) | HIGH | Not recommended |

## Competitor Feature Analysis

| Feature | CopyClip | Maccy | Paste | Islet v1.9 approach |
|---------|----------|-------|-------|----------------------|
| UI shell | Plain NSMenu | NSMenu (1.x) → NSPanel/SwiftUI (2.x) | Custom floating window | Extend existing NSMenu (see above) |
| History cap | 20 shown / 80-9999 stored depending on tier | Configurable, effectively unbounded (with known perf issues past 30k) | Unlimited (iCloud-synced) | Fixed ~20-30, FIFO eviction |
| Quick-select | ⌘1-9, ⌘0 | Keyboard-driven search+select | Keyboard shortcuts + pinboard switching | ⌘0-⌘9 on first 10 rows |
| Search | Yes (CopyClip 2) | Yes, core feature | Yes | Deferred (v2 candidate) |
| Pin/favorite | Yes (⇧⌘P) | No | Yes (pinboards) | Deferred (v2 candidate) |
| Sync | No | No (explicitly, by design) | Yes (iCloud) | Not planned — inconsistent with local-only positioning |
| Sensitive-content handling | Manual per-app exclude list | Respects nspasteboard convention | Unclear from sources | nspasteboard convention (table stakes); manual exclude list is a v2 flag |
| Storage | Unknown (closed source) | SQLite/SwiftData (2.x) | Unknown, iCloud-backed | Simple JSON/plist + image files, no DB needed at this cap |

## Sources

- [CopyClip 2 - Clipboard Manager - App Store](https://apps.apple.com/us/app/copyclip-2-clipboard-manager/id1020812363?mt=12) — item limits, ⌘1-9/⌘0 shortcuts, pin (⇧⌘P), per-app exclude, search
- [An Excellent Free Clipboard Manager for Mac is CopyClip - OS X Daily](https://osxdaily.com/2023/08/28/free-clipboard-manager-for-mac-copyclip/) — free-tier history size (80 stored / 20 shown)
- [Maccy (open source) — GitHub](https://github.com/p0deje/Maccy) — architecture, MIT license, privacy-first/no-cloud positioning
- [Maccy 2.0 rewrite coverage — AlternativeTo](https://alternativeto.net/news/2024/9/macos-clipboard-manager-maccy-has-released-a-major-2-0-update-with-a-complete-rewrite) — NSMenu → SwiftUI/NSPanel rewrite, Core Data → SwiftData
- [Maccy GitHub Issue #1097 — large history UI performance](https://github.com/p0deje/Maccy/issues/1097) — confirms perf bottleneck is UI rendering, not storage; only manifests at 30k+ items
- [Paste app official blog — best clipboard manager 2026](https://pasteapp.io/blog/best-clipboard-manager-for-mac) / [Paste 5.0 shared pinboards, sync — AlternativeTo](https://alternativeto.net/news/2025/5/clipboard-manager-paste-5-0-adds-shared-pinboards-rebuilt-sync-engine-and-performance-gains) — pinboards, sync engine, shared pinboards
- [NSPasteboard.org](https://nspasteboard.org/) and [NSPasteboard/NSPasteboard.org GitHub index](https://github.com/NSPasteboard/NSPasteboard.org/blob/main/index.md) — `org.nspasteboard.ConcealedType`/`TransientType`/`AutoGeneratedType` convention, authoritative source for the sensitive-content exclusion pattern
- [Flycut (Clipboard manager) — softwar.io](https://flycut-clipboard-manager.softwar.io/) — plain-text/developer-focused scope, explicit non-support for images/tables in its base design
- [Fleetings Pixels — how to build a Mac menu bar app with NSPopover](https://fleetingpixels.com/articles/2020/how-to-create-a-mac-menu-bar-app-with-nspopover/) and [Multi Blog — pushing the limits of NSStatusItem](https://multi.app/blog/pushing-the-limits-nsstatusitem) — NSMenu vs. NSPopover tradeoffs for menu-bar apps
- Project context: `.planning/PROJECT.md` (Milestone In Progress: v1.9 Clipboard History) — confirmed scope, existing status-item menu, `DragApproachDetector` polling precedent

---
*Feature research for: macOS menu-bar clipboard history (Islet v1.9)*
*Researched: 2026-07-22*
