# Phase 58: Menu Wiring & UI Assembly - Research

**Researched:** 2026-07-23
**Domain:** AppKit `NSMenu`/`NSMenuItem` + `NSHostingView` (SwiftUI-in-menu), `NSPasteboard` write-back, macOS menu-bar app assembly
**Confidence:** HIGH (architecture/pitfalls grounded in direct codebase reads; the one genuinely new AppKit technique — SwiftUI rows inside `NSMenuItem` — is MEDIUM, corroborated by multiple independent sources but not an official Apple sample)

## Summary

Phase 58 is pure assembly: three already-shipped, already-tested subsystems (`ClipboardStore`, `ClipboardFileStore`, `ClipboardMonitor`) get wired for the first time into `AppDelegate`'s existing status-item `NSMenu`. No new business logic is invented here — eviction, encryption, and capture are already correct and unit-tested from Phases 55-57. The actual net-new work is 100% AppKit menu-building: dynamically rebuilding `NSMenuItem`s above the existing Settings…/Check for Updates…/Quit block every time the menu opens, rendering each row as a small `NSHostingView`-wrapped SwiftUI view (per locked research decision — no new panel), wiring ⌘0-⌘9 key equivalents, writing the clicked item back to `NSPasteboard.general` without re-triggering the monitor's own capture, and a destructive-confirm `NSAlert` for "Delete All History" that actually deletes the on-disk encrypted store.

The one real technical risk in this phase — and the reason it's sequenced last — is that `NSMenuItem.view` (the API needed for the `NSHostingView` row) is a known-leaky AppKit abstraction: setting a custom view on an `NSMenuItem` silently disables the menu's automatic highlight-on-hover and click-blink behavior, and — critically for this phase — an `NSMenuItem` with a custom `view` set does **not** reliably fire its `action`/`target` on a mouse click the way a title-only item does. This means click-to-restore and the ⌘0-⌘9 key equivalents need two independently-verified trigger paths (SwiftUI gesture for the mouse click, `NSMenuItem.action`/`target` for the key equivalent), both calling the same restore function. This is a concrete, verifiable-on-device detail the plan must account for, not a hypothetical.

**Primary recommendation:** Build one small `AppDelegate`-owned rebuild method (`rebuildClipboardMenuItems()`) triggered from `NSMenuDelegate.menuNeedsUpdate(_:)`, insert it into the menu at index 0 (before the existing separator + Settings/Check-for-Updates/Quit block per D-15), render each row's content in a tiny reusable `ClipboardRowView: View` hosted via `NSHostingView`, and give every interactive row BOTH a SwiftUI `.onTapGesture` (for mouse clicks, since the custom view intercepts them) AND a matching `NSMenuItem.action`/`target`/`keyEquivalent` (so ⌘0-⌘9 works even though the menu is open and the mouse never clicked that row).

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CLIP-01 | User sees a menu-bar dropdown listing the last ~20-30 copied text/image items, oldest automatically evicted past the cap | `ClipboardStore.append`/`cap` already implement FIFO eviction (`Islet/Clipboard/ClipboardStore.swift:13,25`) — this phase only renders `ClipboardStore.items` into `NSMenuItem`s on `menuNeedsUpdate`; no new eviction logic needed |
| CLIP-02 | Clicking an entry copies it back to the system clipboard (no auto-paste) | `NSPasteboard.general.writeObjects`/`.setString` write-back, tagged with `ClipboardMonitor.restoreMarkerType` (already defined at `Islet/Clipboard/ClipboardMonitor.swift:18`) so the monitor's own poll doesn't re-ingest it — see Code Examples |
| CLIP-03 | The first 10 entries are directly selectable via ⌘0-⌘9 | `NSMenuItem.keyEquivalent` = `"0"`...`"9"` on the first 10 rebuilt rows; default `keyEquivalentModifierMask` is already `.command` (Apple docs), no explicit mask needed — see Common Pitfalls for the custom-`view` interaction caveat |
| CLIP-05 | "Delete All History" clears the entire history, with a confirmation dialog | Native `NSAlert` (destructive-styled Delete button, per D-informational/FEATURES.md), then `ClipboardStore.clear()` + `ClipboardFileStore.save([], ...)` so the on-disk `index.json.enc`/image files are actually rewritten empty, not just the in-memory array reset (Pitfall: "Delete All History only clearing memory," PITFALLS.md) |

## User Constraints (from CONTEXT.md)

<user_constraints>

### Locked Decisions

- **D-10 (Image entry appearance):** Image copies render as a small thumbnail (~16-20pt, inline with row height — same height as a standard single-line `NSMenuItem`, not an enlarged row), not a generic icon + "Image" label.
- **D-11 (Pasteboard-access explanation timing):** The one-time pasteboard-access explanation is shown on first menu open (not on first captured item) — supersedes Phase 57's D-07 placeholder.
- **D-12 (Pasteboard-access explanation mechanism):** Presented as a native `NSAlert` (same mechanism Phase 57's spike proved works), not an inline menu row.
- **D-13 (Pasteboard-access explanation copy):** Claude drafts the actual copy — short, plain-language, explains why Islet reads the pasteboard and that sensitive/password-manager copies are never captured. No specific wording dictated by the user.
- **D-14 (Empty state):** Before anything has been copied, the clipboard section shows a single disabled, non-clickable placeholder row ("No items yet" or equivalent) rather than hiding the section entirely. "Delete All History" is naturally disabled/absent while history is empty (Claude's discretion on exact mechanism).
- **D-15 (Section placement):** The clipboard history section (rows + "Delete All History") sits ABOVE the existing Settings…/Check for Updates…/Quit block, separated by a standard `NSMenuItem.separator()`. The existing three items keep their current relative order, just pushed below the new section.
- **[informational] NSMenu extension, not a new panel:** Extend the existing status-item `NSMenu` with custom `NSMenuItem` rows (`NSHostingView`-wrapped SwiftUI content for text truncation + thumbnail), rather than a new `NSPanel`/popover.
- **[informational] Text truncation:** Text entries use single-line truncation + ellipsis (`.lineLimit(1)` / `.truncationMode(.tail)`) — full untruncated text stays stored for future search support (already the case — `ClipboardItem.Kind.text` stores the full string, never pre-truncated).
- **[informational] Delete-All confirmation copy:** Single native `NSAlert` — "Delete all clipboard history? This cannot be undone." with Cancel / Delete (destructive-styled) buttons, no "don't ask again" checkbox.
- **[informational] ⌘0-⌘9 scope:** Standard `NSMenuItem.keyEquivalent` on the first 10 rows only, active while the menu is open — not a global hotkey.

### Claude's Discretion

- Exact SwiftUI row layout inside the `NSHostingView` (spacing, font size, truncation length in characters) — as long as it reads as a single-line row matching the surrounding native `NSMenuItem`s in height/style.
- Whether the disabled empty-state row and/or "Delete All History" use a literal `isEnabled = false` `NSMenuItem` vs. omission — implementation detail.
- Whether the pasteboard-access `NSAlert` is triggered from `AppDelegate` directly or a new coordinator method — mirrors whatever shape Phase 56/57's spike-hook-to-real-wiring transition naturally suggests during planning.

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope. Search/filter and per-item delete remain explicitly deferred to a future milestone per `.planning/research/FEATURES.md`, not raised again during this discussion.

</user_constraints>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Menu construction/rebuild (`NSMenu`, `NSMenuItem`) | Native App Shell (AppKit, `AppDelegate`) | — | `AppDelegate` already owns `statusItem`/`menu`; this phase extends that exact object graph, never `NotchWindowController` |
| Row rendering (text truncation, thumbnail) | Native App Shell (SwiftUI hosted via `NSHostingView`) | — | Locked decision: SwiftUI content hosted inside `NSMenuItem.view`, not a new panel |
| Click-to-restore / pasteboard write-back | Native App Shell (AppKit, `NSPasteboard.general`) | — | Direct system API call, no server/network involved |
| History data (items, cap, eviction) | Local Store (`ClipboardStore`, in-memory) | Local Storage (`ClipboardFileStore`, encrypted disk) | Already built (Phase 55/56) — this phase only reads/mutates through their existing public API, never reimplements eviction |
| Live capture (pasteboard polling) | Local Monitor (`ClipboardMonitor`) | — | Already built (Phase 57) — this phase switches its owner from a `#if DEBUG` hook to unconditional production wiring, no change to its internals |
| Delete-all confirmation | Native App Shell (`NSAlert`) | Local Storage (`ClipboardFileStore.save([])`) | UI confirmation lives in AppKit; the actual "delete" must reach disk, not just the in-memory `@Published`-equivalent array |

This is a single-tier feature (a native macOS menu-bar utility) — there is no browser/SSR/API/CDN tier in this codebase. The map above exists to make explicit which of the four already-separated subsystems (`AppDelegate` shell vs. `ClipboardStore` vs. `ClipboardFileStore` vs. `ClipboardMonitor`) owns each new behavior, since misassigning e.g. eviction logic into the menu-rebuild code (instead of leaving it in `ClipboardStore`) would be the most likely tier-boundary mistake for this phase.

## Standard Stack

### Core

No new dependencies. This phase uses only frameworks already imported elsewhere in the codebase:

| Framework | Purpose | Why Standard |
|-----------|---------|---------------|
| `AppKit` (`NSMenu`, `NSMenuItem`, `NSAlert`, `NSPasteboard`) | Menu construction, confirmation dialog, pasteboard write-back | Already imported in `AppDelegate.swift:2` |
| `SwiftUI` (`NSHostingView`) | Row content (truncated text / thumbnail) | Already imported in `AppDelegate.swift:1`; `NSHostingView` already used elsewhere in the codebase (`Islet/Notch/NotchWindowController.swift:1164,2437`) for panel content, though never before inside an `NSMenuItem` |
| `Foundation` | `ClipboardItem`/`ClipboardStore` (existing) | Already the case |

No `npm view`/`pip index`/`cargo search` step applies — this is a Swift/AppKit phase with zero external package dependencies. **Package Legitimacy Audit is not applicable** — no packages are being installed in this phase.

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `NSHostingView`-wrapped SwiftUI rows | Plain `NSMenuItem` with `.image` (a pre-rendered `NSImage` combining text label + thumbnail) | Avoids the highlight/click-handling caveats below entirely, but loses SwiftUI's easy `.lineLimit(1)`/`.truncationMode(.tail)` text layout and dynamic-content re-render — would require manually rasterizing text into an `NSImage` per row on every rebuild. Rejected: user's locked decision (informational, FEATURES.md) already specifies `NSHostingView`, and the project's `NowPlayingMonitor`/`AudioOutputMonitor` precedent already favors SwiftUI content over hand-rolled AppKit drawing wherever content is dynamic. |
| Manual highlight/click handling in `AppDelegate` | Third-party `MenuItemView` (MrAsterisco/MenuItemView, MIT) — a small `NSView` subclass that automates `NSMenuItem`-custom-view highlighting/click-blink | At a handful of rows (≤11: up to 10 clip rows + Delete All), the manual fix (SwiftUI `.onHover` for background tint + `.onTapGesture` for the click) is a few lines and avoids a new dependency — consistent with this project's own stated precedent of not adding a dependency "for a tiny native surface" (REQUIREMENTS.md Out of Scope, re: `SimplyCoreAudio`). Not recommended to add. |

## Package Legitimacy Audit

Not applicable — this phase installs no external packages (Swift/AppKit-only, zero new dependencies).

## Architecture Patterns

### System Architecture Diagram

```
User clicks the status-bar icon (⌥ or plain click)
        │
        ▼
AppDelegate (NSMenuDelegate).menuNeedsUpdate(_:)  ◄── NEW: AppDelegate adopts NSMenuDelegate
        │
        ├─► if pasteboard-access explanation not yet shown this install (D-11/D-12):
        │       show one-time NSAlert BEFORE the menu finishes opening
        │
        ├─► read ClipboardStore.items (already in memory, kept live by ClipboardMonitor.onChange)
        │
        ├─► remove any previously-inserted clipboard NSMenuItems (idempotent rebuild)
        │
        ├─► for each item (up to 30): insert one NSMenuItem
        │       - view = NSHostingView(rootView: ClipboardRowView(item))  [text/thumbnail row]
        │       - if index < 10: keyEquivalent = "\(index)" (Cmd+0-9 via default modifier mask)
        │       - action/target = restoreClipboardItem(_:) — fires on BOTH key equivalent AND
        │         (mirrored) SwiftUI .onTapGesture inside the hosted row
        │       - empty case (D-14): single disabled placeholder row, no items inserted
        │
        ├─► insert "Delete All History" NSMenuItem (disabled/absent if empty, D-14)
        │
        ├─► insert NSMenuItem.separator()   (D-15 boundary)
        │
        └─► existing Settings…/Check for Updates…/separator/Quit Islet block (untouched, now
            pushed below the new section)

User clicks a clip row (mouse) OR presses ⌘0-⌘9 while menu is open
        │
        ▼
restoreClipboardItem(_:) [NEW]
        │
        ├─► NSPasteboard.general.clearContents()
        ├─► writeObjects([...]) tagged with ClipboardMonitor.restoreMarkerType  (self-capture guard)
        └─► (no synthesized Cmd+V — CLIP-02 explicitly forbids auto-paste)

User clicks "Delete All History"
        │
        ▼
NSAlert (destructive-styled Delete / Cancel) [NEW]
        │
        └─► on Delete: ClipboardStore.clear() (in-memory)
                    + ClipboardFileStore.save([], root:, key:) (on-disk index + image files actually
                      rewritten empty — NOT just an in-memory reset)

ClipboardMonitor.onChange (Phase 57, existing) — production wiring in THIS phase
        │
        ▼
AppDelegate: ClipboardStore.append(item) → ClipboardFileStore.save(items, ...) (persist every capture)
```

### Recommended Project Structure

No new files or folders. This phase modifies exactly one existing file:

```
Islet/
├── Clipboard/                      # UNTOUCHED — all 5 files already shipped (Phases 55-57)
│   ├── ClipboardItem.swift
│   ├── ClipboardStore.swift
│   ├── ClipboardFileStore.swift
│   ├── ClipboardMonitor.swift
│   └── KeychainClipboardKeyStore.swift
└── AppDelegate.swift                # MODIFIED — the only file this phase touches
```

Per ARCHITECTURE.md's Pattern 3 (already locked by prior research, not re-litigated): no new `ClipboardMenuBuilder` type. `AppDelegate` adopts `NSMenuDelegate` directly and gains a handful of new private methods/properties, mirroring how `setupDebugMenu()` (`Islet/AppDelegate.swift:230-261`) is already a plain private method on `AppDelegate`, not a separate builder class. If a small pure-logic row-view struct is extracted (`ClipboardRowView: View`), it can live in `AppDelegate.swift` itself or as a small addition to `Islet/Clipboard/` — Claude's discretion at plan time, not a locked decision.

### Pattern 1: `NSMenuDelegate.menuNeedsUpdate(_:)` for dynamic rebuild

**What:** `AppDelegate` conforms to `NSMenuDelegate` (a new conformance — not adopted anywhere in the codebase today; confirmed via `grep -rn "NSMenuDelegate" Islet` returning zero matches) and implements `menuNeedsUpdate(_ menu: NSMenu)`, which AppKit calls immediately before the menu is displayed, every time. Inside, the clipboard section is torn down and rebuilt from `ClipboardStore.items` before the static Settings/Check-for-Updates/Quit block (already built once at launch, `AppDelegate.swift:94-107`).

**When to use:** This is the only menu-open hook that fires reliably before every display — `menuWillOpen(_:)` is an alternative with the same practical effect for this use case; `menuNeedsUpdate(_:)` is Apple's currently-recommended hook specifically because it also fires for key-equivalent-triggered menu validation, which matters here since ⌘0-⌘9 must resolve to the correct item even without a prior mouse-driven open in some edge cases.

**Example:**
```swift
// AppDelegate.swift — statusItem.menu already assigned at line 107; NSMenuDelegate is new.
extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        // Remove any previously inserted clipboard items (tagged for identification —
        // see Pitfall below on why we can't just remove "the first N items" blindly).
        menu.items.removeAll { $0.identifier?.rawValue.hasPrefix("clip.") == true }

        var insertionIndex = 0
        let items = clipboardStore.items.reversed() // MRU: newest first (ClipboardStore.append
                                                      // pushes newest to the END of the array —
                                                      // see ClipboardStore.swift:24 — so render
                                                      // in reverse for newest-first display)

        if items.isEmpty {
            let empty = NSMenuItem(title: "No items yet", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            empty.identifier = NSUserInterfaceItemIdentifier("clip.empty")
            menu.insertItem(empty, at: insertionIndex); insertionIndex += 1
        } else {
            for (index, item) in items.enumerated() {
                let menuItem = NSMenuItem(title: "", action: #selector(restoreClipboardItem(_:)), keyEquivalent: index < 10 ? "\(index)" : "")
                menuItem.target = self
                menuItem.representedObject = item.id
                menuItem.view = NSHostingView(rootView: ClipboardRowView(item: item))
                menuItem.identifier = NSUserInterfaceItemIdentifier("clip.\(item.id)")
                menu.insertItem(menuItem, at: insertionIndex); insertionIndex += 1
            }
        }

        let deleteAll = NSMenuItem(title: "Delete All History", action: #selector(confirmDeleteAllHistory), keyEquivalent: "")
        deleteAll.target = self
        deleteAll.isEnabled = !clipboardStore.items.isEmpty
        deleteAll.identifier = NSUserInterfaceItemIdentifier("clip.deleteAll")
        menu.insertItem(deleteAll, at: insertionIndex); insertionIndex += 1
        menu.insertItem(.separator(), at: insertionIndex)
        // existing Settings…/Check for Updates…/separator/Quit items, still present from
        // applicationDidFinishLaunching, are now correctly pushed below (D-15).
    }
}
```
*Sourced from AppKit's documented `NSMenuDelegate` contract and this file's own existing menu-construction style (`AppDelegate.swift:94-107`); the tagged-`identifier`-based removal is a direct fix for the pitfall below, not boilerplate.*

### Pattern 2: SwiftUI row content, hosted via `NSHostingView`, with dual click paths

**What:** A tiny `View` (e.g. `ClipboardRowView`) renders the truncated text or thumbnail (D-10: ~16-20pt inline thumbnail) at native single-line `NSMenuItem` height. Because setting `NSMenuItem.view` disables AppKit's automatic click routing to the item's `action` (see Pitfall 1 below), the row's own SwiftUI content must independently call the restore closure on `.onTapGesture`, while the `NSMenuItem`'s own `action`/`target`/`keyEquivalent` (set in Pattern 1 above) independently handles the ⌘0-⌘9 keyboard path. Both paths call the exact same underlying function (`restoreClipboardItem`-equivalent) so there is only one place that knows how to write to the pasteboard.

**When to use:** Any time a custom `NSMenuItem.view` needs both a working mouse-click path and a working `keyEquivalent` path simultaneously — this is exactly the situation here (CLIP-02 needs mouse click, CLIP-03 needs ⌘0-⌘9).

**Example:**
```swift
struct ClipboardRowView: View {
    let item: ClipboardItem
    let onSelect: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            switch item.kind {
            case .text(let text):
                Text(text)
                    .lineLimit(1)
                    .truncationMode(.tail)
            case .image(let data):
                if let nsImage = NSImage(data: data) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .frame(width: 18, height: 18)   // D-10: ~16-20pt inline thumbnail
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                Text("Image")
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .frame(height: 22)  // matches standard single-line NSMenuItem height
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }   // the mouse-click path — the NSMenuItem's own
                                        // action does NOT reliably fire once .view is set
        .onHover { hovering in
            // manual highlight, since the custom view disables AppKit's automatic one
        }
    }
}
```
*Shape corroborated by multiple independent sources describing the `NSMenuItem.view` highlight/click limitation (see Sources) — not an official Apple sample, hence MEDIUM confidence on the exact mechanism, though the underlying limitation itself is well-documented across sources.*

### Anti-Patterns to Avoid

- **Removing "the first N items" positionally to rebuild the clipboard section:** Since the static Settings/Check-for-Updates/Quit block already exists at fixed positions from `applicationDidFinishLaunching`, and the clipboard section's item count varies (0 to 31 items: up to 30 rows + Delete All), rebuilding by index math is fragile. Tag inserted items with `NSMenuItem.identifier` and remove-then-reinsert by identifier prefix (Pattern 1) instead.
- **Relying solely on `NSMenuItem.action`/`target` for mouse clicks on a custom-`view` item:** Per Pitfall 1 below, this silently does nothing on some macOS versions/configurations once `.view` is set — always pair with an explicit SwiftUI gesture handler in the hosted content.
- **Auto-pasting into the frontmost app:** CLIP-02 explicitly forbids synthesizing a ⌘V keystroke — only `NSPasteboard.general` is written to; never call `CGEvent`/`NSEvent` keyboard synthesis for this feature.
- **Threading clipboard state through `IslandResolver`/`TransientQueue`/`NotchWindowController`:** Locked architectural decision from prior research (ARCHITECTURE.md Anti-Pattern 1) — this phase's menu wiring stays entirely inside `AppDelegate`, zero imports of the notch-panel presentation layer.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|--------------|-----|
| Custom-view menu-item highlight/click (the underlying AppKit limitation) | A general-purpose "menu item view wrapper" abstraction, or a full custom `NSView` subclass with its own `NSTrackingArea` | The minimal SwiftUI `.onHover`/`.onTapGesture` pair inside the hosted row (Pattern 2) | At ≤11 rows total, the manual fix is a few lines; a general abstraction (or the third-party `MenuItemView` library) is disproportionate scope for this cap, and adding a dependency contradicts this project's own stated precedent (REQUIREMENTS.md Out of Scope: no dependency for a tiny native surface) |
| History eviction / cap enforcement | Any new cap/FIFO logic inside the menu-rebuild code | `ClipboardStore.append`/`cap` (already shipped, Phase 55, `ClipboardStore.swift:13,18-26`) | Already correct and unit-tested — this phase only *renders* `ClipboardStore.items`, never re-implements eviction |
| Encryption / on-disk delete | A new "clear the clipboard file" routine | `ClipboardFileStore.save([], root:, key:)` (already shipped, Phase 56) — saving an empty array already rewrites `index.json.enc` and sweeps orphaned image files via the existing `deleteOrphanedImageFile` logic (`ClipboardFileStore.swift:88-91`) | The existing save/orphan-sweep path already does exactly what "Delete All History" needs; calling it with an empty array is correct and requires zero new file-deletion code |
| Self-capture-loop prevention | A new marker/flag mechanism for the restore write | `ClipboardMonitor.restoreMarkerType` (already defined, `ClipboardMonitor.swift:18`, consumed by `isSelfCaptureMarker` at `ClipboardMonitor.swift:107-109`) | The constant and the consuming guard already exist from Phase 57 — this phase is the first to actually *produce* a write tagged with it (Phase 57's DEBUG hook only simulated one, `AppDelegate.swift:349-356`) |

**Key insight:** Every piece of "real" logic this phase might be tempted to hand-roll (eviction, encryption, delete, self-capture guard) already exists and is already unit-tested from Phases 55-57. The only genuinely new code in this phase is AppKit menu-object-graph construction and the SwiftUI-in-`NSMenuItem` click/highlight workaround — scope discipline here means resisting the urge to re-derive anything the prior three phases already proved correct.

## Common Pitfalls

### Pitfall 1: `NSMenuItem.view` silently breaks highlight AND the classic action/click path

**What goes wrong:** Once `NSMenuItem.view` is set to a custom view (here, an `NSHostingView`), AppKit stops automatically highlighting the row on hover and stops reliably routing a mouse click to the item's `action`/`target` — the item just sits there looking inert on click, with no visible feedback and (depending on macOS version and exactly how the hosted view handles/consumes the mouse-down event) the `action` selector may never fire.

**Why it happens:** `NSMenuItem.view` is designed for "you own 100% of the rendering and interaction," not "AppKit renders your content but still handles the click." This is Apple's documented tradeoff, not a bug, but it's easy to miss until testing an actual click.

**How to avoid:** Give the hosted SwiftUI content its own `.onTapGesture` that calls the restore closure directly (Pattern 2) — do not rely on `NSMenuItem.action` firing from a mouse click on a custom-view item. Do keep `NSMenuItem.action`/`target`/`keyEquivalent` set anyway, since `keyEquivalent`-driven invocation (⌘0-⌘9, CLIP-03) goes through the standard action-sending path and does still work reliably even when `.view` is set — the caveat is specifically about *mouse clicks* on the custom view, not keyboard shortcuts.

**Warning signs:** Clicking a clip row visually does nothing (no highlight, no dismiss, no pasteboard write) even though the row renders correctly; ⌘0-⌘9 works fine while mouse clicks silently fail — this asymmetry is the signature of this exact pitfall.

**Phase to address:** This phase, in the same commit that first wires `NSHostingView` into an `NSMenuItem` — verify both the mouse-click path and the ⌘0-⌘9 path independently on-device (they can pass/fail independently of each other).

### Pitfall 2: "Delete All History" clearing only `ClipboardStore.items`, not the on-disk file

**What goes wrong:** A naive implementation calls `clipboardStore.clear()` (the in-memory reducer) and stops there — the menu correctly shows an empty list, but `index.json.enc` and any per-image `.enc` files on disk are untouched. Relaunching the app (or the file simply persisting on disk) means the "deleted" history reappears, or at minimum the encryption's at-rest guarantee is undermined by data that was supposed to be gone.

**Why it happens:** `ClipboardStore.clear()` (`ClipboardStore.swift:28-30`) is a pure in-memory operation by design (Phase 55 deliberately kept it side-effect-free) — it has no awareness that persistence exists at all. The natural first instinct ("clear the array, done") stops one call short.

**How to avoid:** The Delete-All handler must call both `clipboardStore.clear()` AND `ClipboardFileStore.save([], root: ClipboardFileStore.storageRoot(), key: KeychainClipboardKeyStore().readOrCreateKey())` — the existing `save` function already correctly rewrites `index.json.enc` empty and sweeps every orphaned image file via its existing `deleteOrphanedImageFile` logic (`ClipboardFileStore.swift:88-91`), so no new deletion code is needed, only the second call.

**Warning signs:** After confirming "Delete All History" and reopening the menu, the empty state shows correctly, but inspecting `~/Library/Application Support/IsletClipboard/index.json.enc` directly (or relaunching the app) still shows the old items.

**Phase to address:** This phase — this is explicitly called out in PITFALLS.md's Security Mistakes table (already flagged by prior research, not a new finding).

### Pitfall 3: Converting the Phase 57 DEBUG-only monitor hooks to production wiring without removing the throwaway console sink

**What goes wrong:** Phase 57's `debugSpikeStartClipboardMonitor()` (`AppDelegate.swift:315-325`) constructs `ClipboardMonitor(onChange:)` with a closure that only `print()`s — it never calls `clipboardStore.append(...)` or persists anything. If this phase's real wiring is built by lightly editing that closure in place (still inside `#if DEBUG`, or copy-pasted without removing the print-only body), the feature can *look* wired (compiles, debug menu still works) while the production, always-on path never actually appends/persists/rebuilds the menu.

**Why it happens:** The DEBUG hook is explicitly documented as "the exact `ClipboardMonitor(onChange:)` construction + idempotent start/stop shape this phase's real (non-DEBUG) wiring should mirror" (58-CONTEXT.md's Reusable Assets note) — "mirror the shape" is correct guidance, but it's easy to under-specify "mirror the shape, but the closure body must do real work outside `#if DEBUG`."

**How to avoid:** The real wiring must live outside any `#if DEBUG` guard, must be started unconditionally in `applicationDidFinishLaunching` (not from a debug-menu action), and its `onChange` closure must call `clipboardStore.append(item)` → `ClipboardFileStore.save(...)` → trigger a menu rebuild (or simply rely on `menuNeedsUpdate(_:)` re-reading `clipboardStore.items` fresh on next open — no explicit rebuild-on-capture is needed since the menu already rebuilds on every open). The existing `debugSpikeStartClipboardMonitor`/`debugSpikeStopClipboardMonitor` DEBUG hooks can either be deleted (their job is now done by production code) or left as-is for developer convenience — Claude's discretion, not a locked decision, but they must not be the ONLY path that starts the monitor.

**Warning signs:** The debug menu's "Spike: Start Clipboard Monitor" still exists and "works" (prints to console) while the real menu never shows captured items — indicates the production path was never actually wired, only the debug spike was preserved.

**Phase to address:** This phase — the CONTEXT.md canonical references explicitly flag `AppDelegate.swift:315-337`'s DEBUG hooks as "superseded by real (non-DEBUG) wiring in this phase."

### Pitfall 4: MRU ordering direction mismatch between `ClipboardStore` and the rendered menu

**What goes wrong:** `ClipboardStore.append` (`ClipboardStore.swift:18-26`) appends newest items to the **end** of `items` and evicts from the **front** (`removeFirst()`) — i.e., `items[0]` is the OLDEST entry, `items.last` is the NEWEST. CLIP-01 requires "most recent first" in the rendered menu. A naive `for item in clipboardStore.items` render loop would show oldest-first, backwards from the spec.

**Why it happens:** `ClipboardStore`'s internal array order (oldest-first, append-at-end) is optimized for O(1) FIFO eviction (`removeFirst()`), not for direct display order — these are two different, equally valid conventions that happen to be inverted from each other.

**How to avoid:** Render `clipboardStore.items.reversed()` (or equivalent) when building menu rows — verified directly by reading `ClipboardStore.swift`'s `append` implementation, not assumed.

**Warning signs:** On-device testing shows the oldest captured item at the top of the menu and the just-copied item at the bottom — the literal inverse of CLIP-01's "most recent first" requirement.

**Phase to address:** This phase, verified against the actual `ClipboardStore.swift` source (already done above — this is a `[VERIFIED: codebase]` finding, not speculative).

## Code Examples

### Click-to-restore write-back (text and image), tagged against self-capture

```swift
// AppDelegate.swift — NEW method, called from both the SwiftUI .onTapGesture (Pattern 2)
// and the NSMenuItem's own action (⌘0-⌘9 path).
@objc private func restoreClipboardItem(_ sender: NSMenuItem) {
    guard let id = sender.representedObject as? UUID,
          let item = clipboardStore.items.first(where: { $0.id == id })
    else { return }
    restore(item)
}

private func restore(_ item: ClipboardItem) {
    let pb = NSPasteboard.general
    pb.clearContents()
    let pbItem = NSPasteboardItem()
    switch item.kind {
    case .text(let text):
        pbItem.setString(text, forType: .string)
    case .image(let data):
        // .tiff mirrors ClipboardMonitor's own read priority (ClipboardMonitor.swift:61)
        pbItem.setData(data, forType: .tiff)
    }
    // Self-capture guard (Pitfall 1's mirror in ClipboardMonitor.swift:56-57,107-109):
    // tag this write so the monitor's next poll tick skips re-ingesting it.
    pbItem.setData(Data(), forType: ClipboardMonitor.restoreMarkerType)
    pb.writeObjects([pbItem])
}
```
*Source: `Islet/Clipboard/ClipboardMonitor.swift` (existing `restoreMarkerType`/`isSelfCaptureMarker` contract, already unit-tested per `IsletTests/ClipboardMonitorTests.swift`) — this phase is the first real *producer* of a marker-tagged write; Phase 57's DEBUG hook (`AppDelegate.swift:349-356`) only simulated one for spike verification.*

### Delete All History — destructive confirm + real on-disk delete

```swift
@objc private func confirmDeleteAllHistory() {
    let alert = NSAlert()
    alert.messageText = "Delete all clipboard history?"
    alert.informativeText = "This cannot be undone."
    alert.addButton(withTitle: "Delete")
    alert.buttons.first?.hasDestructiveAction = true   // macOS 11+ destructive styling
    alert.addButton(withTitle: "Cancel")
    guard alert.runModal() == .alertFirstButtonReturn else { return }

    clipboardStore.clear()
    try? ClipboardFileStore.save([], root: ClipboardFileStore.storageRoot(),
                                  key: KeychainClipboardKeyStore().readOrCreateKey())
}
```
*Copy per FEATURES.md's already-researched UX-convention section ("Delete all clipboard history? This cannot be undone." / Cancel / Delete). `alert.buttons.first?.hasDestructiveAction = true` is the standard AppKit destructive-button styling API (`NSAlert.button.hasDestructiveAction`, macOS 11+) — [ASSUMED], not directly verified against this codebase's own prior `NSAlert` usage (the only existing `NSAlert` in the codebase, `AppDelegate.swift:365-369`, is a plain informational alert with a single "OK" button, no destructive-button precedent to confirm against).*

## State of the Art

Not applicable in the "library version" sense (no library). One relevant shift: Apple's macOS 15.4+/26 pasteboard-access privacy prompt (already handled by Phase 57's `ClipboardMonitor.needsAccessExplanation`, `ClipboardMonitor.swift:71-76`) means the one-time explanation this phase must show (D-11/D-12) is reacting to genuinely new OS behavior, not a stale pattern — already correctly scoped by Phase 57, this phase just moves the trigger point from "first captured item" to "first menu open" and replaces the DEBUG placeholder copy (`AppDelegate.swift:367`, explicitly marked "spike placeholder — Phase 58 will replace this with final copy") with real user-facing copy per D-13.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|----------------|
| A1 | `NSAlert.button.hasDestructiveAction` is the correct macOS 11+ API for destructive button styling | Code Examples | Low — cosmetic only; if the API name is wrong, the button simply renders without red/destructive tint, confirmation logic is unaffected. Verify at plan/build time via Xcode autocomplete or a quick Context7/docs check. |
| A2 | An `NSMenuItem` with a custom `.view` set still reliably fires its `action` via `keyEquivalent` (⌘0-⌘9) even though mouse clicks on the same item don't reliably route to `action` | Pitfall 1, Pattern 2 | Medium — if keyEquivalent-driven action dispatch is ALSO unreliable once `.view` is set (not just mouse clicks), CLIP-03 would need the SwiftUI content itself to observe key events, a meaningfully different implementation. This is corroborated across multiple independent sources describing the general `.view` limitation, but none of the sources found during this research explicitly tested the keyEquivalent path in isolation — flag for on-device verification early in this phase's execution, before building the full 10-row wiring. |
| A3 | Default `NSMenuItem.keyEquivalentModifierMask` is `.command`, so `keyEquivalent: "0"`..`"9"` alone yields ⌘0-⌘9 with no explicit mask needed | Phase Requirements (CLIP-03) | Low — [CITED: Apple's "Setting a Menu Item's Key Equivalent" documentation confirms the default mask includes NSCommandKeyMask]; if wrong, symptom is immediately visible on-device (wrong/no modifier triggers the item) and trivially fixed by setting `keyEquivalentModifierMask = .command` explicitly. |
| A4 | The "trial-start notice" referenced in 58-CONTEXT.md's Reusable Assets section ("existing precedent for a one-time `NSAlert`-based explanation shown once per install") does not actually exist as an `NSAlert` in the current codebase — onboarding/permission explanations are implemented as SwiftUI popovers inside `SettingsView.swift` (e.g. lines 40, 566, 599) and the onboarding carousel lives entirely inside the notch panel (`AppDelegate.swift:148`), not as any `NSAlert`. The only `NSAlert` anywhere in the codebase is Phase 57's DEBUG placeholder (`AppDelegate.swift:365-369`). | User Constraints (D-12) | Low — D-12 itself is still directly actionable (Phase 57's own spike already proved an `NSAlert` works for this exact purpose, independent of whether a "trial-start notice" precedent exists elsewhere); this is a discrepancy in 58-CONTEXT.md's stated precedent, not a blocker. Flag for the planner to note D-12's justification rests on Phase 57's spike, not a "trial-start notice" that doesn't exist in `NSAlert` form. |

## Open Questions (RESOLVED: pending on-device confirmation via 58-01 Task 3)

1. **Does `NSMenuItem.action` fire reliably from `keyEquivalent` when `.view` is set, on this project's actual macOS 26 target?**
   - What we know: The general `NSMenuItem.view`-breaks-click-routing limitation is well-corroborated across independent sources (see Sources). Apple's own documentation doesn't explicitly address the keyEquivalent-specific case.
   - What's unclear: Whether ⌘0-⌘9 (CLIP-03) will "just work" via the standard `action`/`target` path once `.view` is set, or whether it also needs a workaround.
   - Recommendation: Verify this narrow question on-device as the very first checkpoint of this phase's execution (before building all 10 rows) — a 1-2 row spike is enough to confirm or refute A2 above, and the fix (if needed) is contained to how key events are captured, not a redesign.
   - Resolution: Deferred by design to 58-01 Task 3 (blocking on-device checkpoint, sequenced specifically before Plan 58-02 proceeds) — this is the exact narrow risk that checkpoint exists to catch.

2. **Exact row height/frame for `NSHostingView` inside `NSMenuItem` to match the surrounding native rows.**
   - What we know: Standard single-line `NSMenuItem`s are ~22pt tall (D-10 references this as the target). `NSHostingView` does not auto-size to fit SwiftUI content by default — an explicit frame (on either the SwiftUI content via `.frame(height:)` or the `NSMenuItem.view`'s own `frame` after construction) is needed.
   - What's unclear: The precise pixel-perfect frame width (menu width is typically driven by the widest item, including the fixed-width Settings/Check-for-Updates/Quit block) — this is a visual-polish detail, not a functional blocker.
   - Recommendation: Claude's Discretion per CONTEXT.md — build with a reasonable estimate (`.frame(height: 22)`, `.padding(.horizontal, 14)` to roughly match native menu-item insets) and refine on-device during this phase's UAT checkpoint, consistent with this project's own repeated pattern of iterating exact AppKit-adjacent pixel values on real hardware rather than research-predicting them.
   - Resolution: Cosmetic, UAT-refined — also covered by 58-01 Task 3's same on-device checkpoint (and the phase-gate UAT in 58-02 Task 3), no separate gate needed.

## Environment Availability

Not applicable — this phase depends only on AppKit/SwiftUI/Foundation/CryptoKit, all already linked and in active use elsewhere in this codebase (confirmed via existing imports in `AppDelegate.swift`, `Islet/Clipboard/*.swift`). No new system tool, service, or external dependency is introduced.

One process caveat carried forward from the existing project (not new to this phase): `xcodebuild test` hangs headlessly in this repo's sandbox due to a pre-existing `BluetoothMonitor` TCC-authorization wait (documented in `.planning/PROJECT.md`, `.planning/phases/09-fullscreen-flash-window-space-retry/deferred-items.md`) — automated test verification for this phase must route through manual Cmd-U in Xcode, matching every prior Clipboard-domain phase's own documented workaround (Phase 56/57 STATE.md notes).

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | XCTest (existing target `IsletTests`, `project.yml:197-228`) |
| Config file | `project.yml` (XcodeGen-managed target definition) |
| Quick run command | Manual Cmd-U in Xcode (headless `xcodebuild test` hangs — see Environment Availability) |
| Full suite command | Manual Cmd-U in Xcode, full `IsletTests` scheme |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|---------------------|--------------|
| CLIP-01 | Menu lists items MRU-first, capped/evicted | unit (rendering-order helper, if extracted as a pure function) + manual on-device UAT (actual `NSMenu` display) | `Cmd-U` (manual) — eviction itself already covered by `IsletTests/ClipboardStoreTests.swift` | ✅ (eviction) / manual UAT (rendering) |
| CLIP-02 | Click restores to pasteboard, no auto-paste, no self-capture duplicate | manual on-device UAT (real `NSPasteboard`/`NSMenu` interaction cannot be meaningfully unit-tested) | `Cmd-U` (self-capture guard logic already covered by `IsletTests/ClipboardMonitorTests.swift`) | ✅ (guard logic) / manual UAT (end-to-end restore) |
| CLIP-03 | ⌘0-⌘9 selects first 10 entries | manual on-device UAT (keyboard-driven `NSMenuItem` interaction) | `Cmd-U` for any extracted pure key-assignment helper; otherwise manual | ❌ — no pure "assign ⌘0-⌘9 to first 10" helper exists yet; Wave 0 gap if this logic is extracted as a testable function (Claude's Discretion) |
| CLIP-05 | Delete All History confirms, then actually deletes on-disk | unit (`ClipboardFileStore.save([], ...)` empties the index — indirectly covered by `IsletTests/ClipboardFileStoreTests.swift`'s existing save/load round-trip tests) + manual on-device UAT (the `NSAlert` confirmation flow itself) | `Cmd-U` | ✅ (save/load) / manual UAT (alert + wiring) |

### Sampling Rate

- **Per task commit:** Manual Cmd-U for any touched unit-testable logic (self-capture guard, eviction, file-store save/load — all pre-existing, should stay green untouched).
- **Per wave merge:** Full manual Cmd-U pass + on-device menu interaction smoke test (open menu, click a row, ⌘-select a row, Delete All).
- **Phase gate:** On-device UAT checkpoint covering all 4 ROADMAP success criteria — this phase's actual verification is inherently manual/on-device (menu rendering, key equivalents, and pasteboard write-back are not meaningfully unit-testable), matching every prior menu/UI-wiring phase in this project (Phase 48, Phase 53, Phase 54).

### Wave 0 Gaps

- None required to start — all underlying logic (`ClipboardStore`, `ClipboardFileStore`, `ClipboardMonitor`) already has test coverage from Phases 55-57 (`IsletTests/ClipboardStoreTests.swift`, `IsletTests/ClipboardFileStoreTests.swift`, `IsletTests/ClipboardMonitorTests.swift`). If the planner chooses to extract pure helper functions for menu-row construction (e.g. a `(index: Int) -> String` key-equivalent assigner, or an MRU-ordering helper — see Pitfall 4), those would be new, easily-testable additions but are not a prerequisite gap; this phase's real verification is on-device by nature (AppKit menu rendering/interaction).

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|----------------|---------|--------------------|
| V2 Authentication | No | No auth surface in this feature |
| V3 Session Management | No | N/A |
| V4 Access Control | No | Single-user local app, no access-control boundary |
| V5 Input Validation | Marginal | Clipboard content is opaque user data (text/image bytes), not parsed/executed — `Text(text)` rendering in SwiftUI is inherently safe (no HTML/script injection surface); no new validation needed beyond what `ClipboardItem`/`ClipboardMonitor` already do |
| V6 Cryptography | Yes (reused, not new) | `CryptoKit.AES.GCM` + Keychain-stored key, already implemented in `ClipboardFileStore`/`KeychainClipboardKeyStore` (Phase 56) — this phase reuses that path as-is for Delete-All (`ClipboardFileStore.save([])`), never hand-rolls new crypto |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|------------------------|
| "Delete All" leaving stale plaintext-adjacent state (encrypted blob deleted from disk but item still resolvable in memory after confirm) | Information Disclosure | Confirm both `clipboardStore.clear()` (in-memory) and `ClipboardFileStore.save([], ...)` (on-disk) complete before the menu next renders — already covered by Pitfall 2 above |
| A malicious/compromised app writing a fake `restoreMarkerType`-tagged pasteboard item to suppress capture of its own sensitive copy | Tampering | Out of scope for this phase — this is Phase 57's threat surface (the marker-type guard itself), not introduced or worsened by this phase's menu wiring; this phase only *produces* legitimate marker-tagged writes, it doesn't change the guard's trust model |
| Restoring an image entry's raw bytes to the pasteboard without validating they're still well-formed image data (e.g. a corrupted/truncated on-disk file post-decrypt) | Denial of Service (crash) | `NSImage(data:)` (used for thumbnail rendering, Code Examples) already fails gracefully to `nil` on malformed data in SwiftUI/AppKit — no force-unwrap should be used when constructing the row thumbnail or the restore write, matching `ClipboardFileStore.load`'s own existing graceful-degradation discipline (D-04, `ClipboardFileStore.swift:35-40`) |

## Sources

### Primary (HIGH confidence)
- Direct source reads: `Islet/AppDelegate.swift` (full file, 384 lines), `Islet/Clipboard/ClipboardItem.swift`, `Islet/Clipboard/ClipboardStore.swift`, `Islet/Clipboard/ClipboardFileStore.swift`, `Islet/Clipboard/ClipboardMonitor.swift`, `Islet/Clipboard/KeychainClipboardKeyStore.swift`, `Islet/Licensing/TrialManager.swift` — all read in full this session, HIGH confidence, not summarized from memory
- `.planning/research/ARCHITECTURE.md`, `.planning/research/PITFALLS.md`, `.planning/research/FEATURES.md`, `.planning/research/SUMMARY.md` — prior dedicated milestone research, already HIGH-confidence per their own metadata, re-verified against actual current code in this session (e.g. confirmed `ClipboardFileStore` already implements the Application Support convention ARCHITECTURE.md recommended)
- `.planning/phases/58-menu-wiring-ui-assembly/58-CONTEXT.md`, `.planning/REQUIREMENTS.md`, `.planning/STATE.md` — locked decisions and requirement definitions
- [Apple Developer Documentation — "Setting a Menu Item's Key Equivalent"](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/MenuList/Articles/SettingMenuKeyEquiv.html) — confirms default `keyEquivalentModifierMask` includes Command

### Secondary (MEDIUM confidence)
- [while (true) { } — "Add a custom view on the Status Bar in macOS with SwiftUI"](https://www.albertopasca.it/whiletrue/add-a-custom-view-on-the-status-bar-in-macos-with-swiftui/) — `NSHostingView` frame-sizing requirement (must be explicitly set, doesn't auto-size)
- [MrAsterisco/MenuItemView (GitHub)](https://github.com/MrAsterisco/MenuItemView) — documents the exact `NSMenuItem.view`-breaks-highlight/click limitation this research's Pitfall 1 is built on; library itself not recommended for adoption (see Don't Hand-Roll), but its problem description is the clearest available characterization of the underlying AppKit limitation

### Tertiary (LOW confidence)
- General web-search corroboration of the `NSMenuItem.view` highlight/click limitation across several blog posts/forum threads — consistent across sources but none are an official Apple sample specifically demonstrating the keyEquivalent-still-works-while-click-doesn't asymmetry (hence Assumption A2 flagged for on-device verification)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — zero new dependencies, entirely existing frameworks already used in this exact codebase
- Architecture: HIGH — grounded in direct reads of the actual `AppDelegate.swift` and all four `Clipboard/` files, plus already-HIGH-confidence prior milestone research re-verified against current code
- Pitfalls: MEDIUM-HIGH — the four pitfalls documented here are either directly derived from reading this codebase's actual source (Pitfalls 2, 3, 4 are `[VERIFIED: codebase]`) or corroborated across multiple independent external sources (Pitfall 1's `NSMenuItem.view` limitation), with the one genuinely unverified sub-claim (A2: keyEquivalent behavior specifically) flagged explicitly for on-device verification early in execution

**Research date:** 2026-07-23
**Valid until:** Effectively indefinite for the AppKit/`NSMenuItem` mechanics (stable API surface, not fast-moving) — the one time-sensitive element (macOS 15.4+/26 pasteboard-access-prompt behavior) is already resolved by Phase 57's on-device-proven `ClipboardMonitor.needsAccessExplanation`, not a fresh unknown in this phase.
