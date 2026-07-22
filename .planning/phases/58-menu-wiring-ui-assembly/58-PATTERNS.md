# Phase 58: Menu Wiring & UI Assembly - Pattern Map

**Mapped:** 2026-07-23
**Files analyzed:** 1 (single file, modified in place)
**Analogs found:** 1 / 1 (self-analog: the same file's own existing sections are the closest and only relevant precedent)

## File Classification

This phase touches exactly **one** file — `Islet/AppDelegate.swift` — modified in place, not split into new files (per RESEARCH.md's "Recommended Project Structure": no new `ClipboardMenuBuilder` type, no new SwiftUI file required, though a `ClipboardRowView: View` struct may be added inline or as a small addition to `Islet/Clipboard/`, Claude's discretion).

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|--------------------|------|-----------|-----------------|----------------|
| `Islet/AppDelegate.swift` — static menu construction → `NSMenuDelegate.menuNeedsUpdate(_:)` dynamic rebuild | controller (app-shell/menu-bar) | CRUD (read `ClipboardStore.items`, mutate on delete-all) + event-driven (menu-open callback) | `Islet/AppDelegate.swift:94-107` (existing static `NSMenu` construction, same file) | exact (self-analog) |
| `Islet/AppDelegate.swift` — production `ClipboardMonitor` start + `onChange` wiring | service/event-driven wiring | event-driven (pasteboard poll → append → persist) | `Islet/AppDelegate.swift:315-325` (`debugSpikeStartClipboardMonitor`, same file, DEBUG-only) | exact (self-analog, DEBUG→production mirror) |
| `Islet/AppDelegate.swift` — `ClipboardRowView: View` (new SwiftUI struct, hosted via `NSHostingView` inside `NSMenuItem.view`) | component (SwiftUI view) | request-response (render item → tap → restore) | `Islet/Notch/NotchWindowController.swift:1164` (`panel.contentView = NSHostingView(rootView: makeRootView(theme:))`) | role-match (NSHostingView usage exists, but hosting a *panel's contentView* not an *NSMenuItem.view* — first-of-kind for the menu-item case, RESEARCH.md flags this explicitly) |
| `Islet/AppDelegate.swift` — Delete-All `NSAlert` confirm + on-disk clear | controller (destructive action) | request-response | `Islet/AppDelegate.swift:365-369` (`debugSpikeCheckPasteboardAccessBehavior`'s `NSAlert`, same file, DEBUG-only, single-button informational — not destructive-styled) | role-match (only existing `NSAlert` in codebase; no destructive-button precedent to confirm against — RESEARCH.md Assumption A1) |

## Pattern Assignments

### `Islet/AppDelegate.swift` — Static menu construction (the base to extend)

**Analog:** same file, lines 94-107

**Imports pattern** (lines 1-3, top of file — already sufficient, no new imports needed):
```swift
import SwiftUI
import AppKit
import Sparkle
```
`SwiftUI` is already imported (needed for `NSHostingView(rootView:)` and any new `ClipboardRowView: View`). No new import required.

**Core menu-construction pattern** (lines 94-107):
```swift
// The dropdown menu shown when the status item is clicked.
menu = NSMenu()
menu.addItem(withTitle: "Settings…",
             action: #selector(openSettings), keyEquivalent: ",")
// Phase 40 / HUD-06 — sits between "Settings…" and the separator (40-UI-SPEC.md Menu
// Item Contract).
menu.addItem(withTitle: "Check for Updates…",
             action: #selector(checkForUpdates), keyEquivalent: "")
menu.addItem(.separator())
menu.addItem(withTitle: "Quit Islet",
             action: #selector(quit), keyEquivalent: "q")
// Menu items send their actions to this delegate.
for item in menu.items { item.target = self }
statusItem.menu = menu
```
**Apply to:** the new clipboard section must be *inserted above* this exact block (D-15) — do not rebuild this block, only insert new `NSMenuItem`s at index 0 and a trailing `.separator()` before it. The `item.target = self` convention (menu items send actions to `AppDelegate` itself, no separate coordinator) is the established codebase idiom — mirror it for every new clipboard `NSMenuItem` (`restoreClipboardItem(_:)`, `confirmDeleteAllHistory`).

**Menu-item-per-line style:** every existing item uses `NSMenu.addItem(withTitle:action:keyEquivalent:)` (the convenience initializer), not `NSMenuItem(title:action:keyEquivalent:)` + `menu.addItem(_:)` separately — except where a `.view`/`.representedObject`/`.identifier` must be set post-construction, which forces the explicit-init + `insertItem(_:at:)` shape shown in RESEARCH.md's Pattern 1 code example. Use `addItem`'s convenience form only for the plain title-only items (Delete All History has no custom view, so it can use the convenience form too).

---

### `Islet/AppDelegate.swift` — DEBUG spike hook → production `ClipboardMonitor` wiring

**Analog:** same file, lines 315-338 (`debugSpikeStartClipboardMonitor` / `debugSpikeStopClipboardMonitor`)

**Construction pattern to mirror** (lines 315-325):
```swift
@MainActor @objc private func debugSpikeStartClipboardMonitor() {
    guard debugClipboardMonitor == nil else {
        print("[Spike-ClipboardMonitor] already running")
        return
    }
    debugClipboardMonitor = ClipboardMonitor(onChange: { item in
        print("[Spike-ClipboardMonitor] captured kind=\(item.kind) timestamp=\(item.timestamp)")
    })
    debugClipboardMonitor?.start()
    print("[Spike-ClipboardMonitor] monitor started")
}
```
**Stop/teardown shape to mirror** (lines 330-338):
```swift
@MainActor @objc private func debugSpikeStopClipboardMonitor() {
    guard let monitor = debugClipboardMonitor else {
        print("[Spike-ClipboardMonitor] not running")
        return
    }
    monitor.stop()
    debugClipboardMonitor = nil
    print("[Spike-ClipboardMonitor] monitor stopped")
}
```

**What must change for production wiring** (per RESEARCH.md Pitfall 3 — do not just lightly edit the DEBUG closure in place):
- New non-`#if DEBUG` stored property, e.g. `private var clipboardMonitor: ClipboardMonitor?` and `private var clipboardStore = ClipboardStore()`, declared alongside the other lifetime-owned properties (mirrors `notchController`/`updaterController` declaration style at lines 6-26).
- Start unconditionally inside `applicationDidFinishLaunching` (same call site as `controller.start(isFirstLaunch:)` at line 133, or immediately after), NOT from a debug-menu `@objc` action.
- The `onChange` closure body must do real work, not `print()`: `clipboardStore.append(item)` → `try? ClipboardFileStore.save(clipboardStore.items, root: ClipboardFileStore.storageRoot(), key: KeychainClipboardKeyStore().readOrCreateKey())`. No explicit menu-rebuild call needed — `menuNeedsUpdate(_:)` re-reads `clipboardStore.items` fresh on next open.
- Existing DEBUG hooks (lines 315-338) may be left in place for developer convenience or deleted — either is fine, but they must not be the *only* code path that starts the monitor (RESEARCH.md warning sign: debug menu "works" while production path never wires).
- Persisted state must be loaded at launch too: `clipboardStore` should be seeded from `ClipboardFileStore.load(root:key:)` before the monitor starts (mirrors `debugSpikePrintClipboardReload`'s load call at lines 306-307), so history survives relaunch.

**Apply to:** the single new "start the real monitor" call site in `applicationDidFinishLaunching`, plus the `onChange` closure that is this phase's actual net-new business glue (append → persist).

---

### `Islet/AppDelegate.swift` — new `NSMenuDelegate.menuNeedsUpdate(_:)` (dynamic rebuild)

**Analog:** RESEARCH.md's Pattern 1 (no direct codebase analog exists — `grep -rn "NSMenuDelegate" Islet` returns zero matches, confirmed by RESEARCH.md). The closest structural precedent is the static-menu-construction block above (same `addItem`/`item.target = self` idiom), extended with `NSMenuItem.identifier`-tagged insert/remove for idempotent rebuild.

**Core pattern (from RESEARCH.md, ready to adapt):**
```swift
extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.items.removeAll { $0.identifier?.rawValue.hasPrefix("clip.") == true }

        var insertionIndex = 0
        let items = clipboardStore.items.reversed() // MRU: newest first — ClipboardStore.append
                                                      // pushes newest to the END (ClipboardStore.swift:24)

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
                menuItem.view = NSHostingView(rootView: ClipboardRowView(item: item, onSelect: { [weak self] in self?.restore(item) }))
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
        // existing Settings…/Check for Updates…/separator/Quit items (lines 96-104) are
        // untouched and now correctly pushed below (D-15).
    }
}
```
**Apply to:** `AppDelegate` gains `NSMenuDelegate` conformance (`menu.delegate = self` must be set once, alongside `statusItem.menu = menu` at line 107) and this new extension. Anti-pattern to avoid (RESEARCH.md): never remove/reinsert by positional index math — the static block's item count is fixed but the clipboard section's isn't; identifier-prefix removal is the only robust approach.

---

### `Islet/AppDelegate.swift` — new `ClipboardRowView: View` hosted via `NSHostingView`

**Analog:** `Islet/Notch/NotchWindowController.swift:1164` — `panel.contentView = NSHostingView(rootView: makeRootView(theme: theme))`

**Imports pattern:** `SwiftUI` already imported at `AppDelegate.swift:1` — no change needed. `NotchWindowController.swift`'s own `makeRootView` (defined at line 2260) is a `private func` returning `some View`, mirroring the "build a small View-returning helper, host it via NSHostingView" shape — same idiom applies to `ClipboardRowView`, just as a `struct: View` instead of a factory method, since each row needs its own instance state (the `item`).

**Core NSHostingView-hosting pattern to mirror** (`NotchWindowController.swift:1157-1170`):
```swift
let panel = self.panel ?? NotchPanel(contentRect: panelFrame)
if self.panel == nil {
    let theme = currentTheme()
    appliedTheme = theme
    panel.contentView = NSHostingView(rootView: makeRootView(theme: theme))
    self.panel = panel
    ...
}
```
This is the codebase's only existing `NSHostingView` construction — `NSHostingView(rootView: <SwiftUI View value>)` assigned directly to an AppKit container property (`panel.contentView`). The pattern for this phase is structurally identical but assigns to `NSMenuItem.view` instead of `NSPanel.contentView` — **first-of-kind usage, no prior codebase precedent for the menu-item case** (RESEARCH.md's flagged MEDIUM-confidence risk area: Pitfall 1, custom `.view` breaks click routing).

**New row view (from RESEARCH.md, ready to adapt):**
```swift
struct ClipboardRowView: View {
    let item: ClipboardItem
    let onSelect: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            switch item.kind {
            case .text(let text):
                Text(text).lineLimit(1).truncationMode(.tail)
            case .image(let data):
                if let nsImage = NSImage(data: data) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .frame(width: 18, height: 18)   // D-10
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                Text("Image")
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .frame(height: 22)
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }   // mouse-click path — required because NSMenuItem.action
                                        // does not reliably fire once .view is set (Pitfall 1)
        .onHover { hovering in /* manual highlight tint */ }
    }
}
```
**Apply to:** every clip row's `NSMenuItem.view` assignment inside `menuNeedsUpdate(_:)`. **Critical constraint from RESEARCH.md Pitfall 1:** keep BOTH the SwiftUI `.onTapGesture` (mouse click) AND the `NSMenuItem.action`/`target`/`keyEquivalent` (⌘0-⌘9 keyboard path) — they are independently-verified trigger paths, not redundant. Verify the keyEquivalent-still-fires-with-`.view`-set assumption (A2) on-device early, per RESEARCH.md's Open Question 1.

---

### `Islet/AppDelegate.swift` — click-to-restore write-back (new, no direct analog — first real producer)

**Analog:** `Islet/Clipboard/ClipboardMonitor.swift:18` (defines `restoreMarkerType`, the contract this phase's write must honor) + `AppDelegate.swift:349-356` (`debugSpikeSimulateSelfCaptureWrite`, DEBUG-only, simulates but never really produces a marker-tagged restore write)

**Marker-type contract to honor** (`ClipboardMonitor.swift:13-18`):
```swift
// The private marker type Phase 58's real click-to-restore write will tag itself
// with, so poll() never re-ingests its own future write (Pitfall 1's self-capture
// loop, Maccy's proven marker-type fix).
static let restoreMarkerType = NSPasteboard.PasteboardType("com.islet.clipboardhistory.restored")
```

**Simulated-write shape to mirror for real production write** (`AppDelegate.swift:349-356`):
```swift
@objc private func debugSpikeSimulateSelfCaptureWrite() {
    let item = NSPasteboardItem()
    item.setString("simulated restored content", forType: .string)
    item.setData(Data(), forType: ClipboardMonitor.restoreMarkerType)
    NSPasteboard.general.clearContents()
    NSPasteboard.general.writeObjects([item])
    print("[Spike-ClipboardMonitor] wrote self-capture-marker test item to NSPasteboard.general — the running monitor must NOT print a captured line for this")
}
```
**Apply to:** the new `restore(_ item: ClipboardItem)` method — same `NSPasteboardItem()` → `setString`/`setData` → `setData(Data(), forType: ClipboardMonitor.restoreMarkerType)` → `clearContents()` → `writeObjects([...])` shape, but branching on `item.kind` (`.text`/`.image`) instead of the DEBUG hook's hardcoded string, and dropping the `print()` (production, not a spike). RESEARCH.md's Code Examples section has the full text/image-branching version ready to adapt — no need to re-derive.

---

### `Islet/AppDelegate.swift` — Delete-All confirm `NSAlert`

**Analog:** `AppDelegate.swift:358-373` (`debugSpikeCheckPasteboardAccessBehavior`, the only existing `NSAlert` in the codebase)

**Existing NSAlert shape** (lines 364-369):
```swift
let alert = NSAlert()
alert.messageText = "Clipboard Access"
alert.informativeText = "Islet checks your clipboard to show recent copies. This is a one-time explanation (spike placeholder — Phase 58 will replace this with final copy)."
alert.addButton(withTitle: "OK")
alert.runModal()
```
**Divergence for this phase:** this existing alert is single-button/informational (no destructive styling, no Cancel branch). The Delete-All alert needs two buttons + a destructive-styled Delete + branching on `runModal()`'s return value — no codebase precedent for that exact shape (RESEARCH.md Assumption A1: `hasDestructiveAction` is `[ASSUMED]`, not verified against this codebase). Use RESEARCH.md's ready-made example:
```swift
@objc private func confirmDeleteAllHistory() {
    let alert = NSAlert()
    alert.messageText = "Delete all clipboard history?"
    alert.informativeText = "This cannot be undone."
    alert.addButton(withTitle: "Delete")
    alert.buttons.first?.hasDestructiveAction = true
    alert.addButton(withTitle: "Cancel")
    guard alert.runModal() == .alertFirstButtonReturn else { return }

    clipboardStore.clear()
    try? ClipboardFileStore.save([], root: ClipboardFileStore.storageRoot(),
                                  key: KeychainClipboardKeyStore().readOrCreateKey())
}
```
**Apply to:** the "Delete All History" `NSMenuItem`'s action. Must call BOTH `clipboardStore.clear()` (in-memory, `ClipboardStore.swift:28-30`) AND `ClipboardFileStore.save([], ...)` (on-disk — RESEARCH.md Pitfall 2: `ClipboardStore.clear()` alone leaves `index.json.enc` untouched, since it's deliberately a pure/side-effect-free reducer per Phase 55's design).

---

### `Islet/AppDelegate.swift` — pasteboard-access explanation `NSAlert` (D-11/D-12/D-13, timing change only)

**Analog:** same DEBUG alert as above (`AppDelegate.swift:358-373`), reused for real timing (first menu open, not first captured item) and real copy (not the marked placeholder string at line 367).

**What changes:** trigger point moves from a DEBUG menu action (`debugSpikeCheckPasteboardAccessBehavior`) to inside `menuNeedsUpdate(_:)`, gated by a persisted (not just in-session) one-time flag — the existing `debugHasShownPasteboardAccessExplanation` is a `#if DEBUG`-only, non-persisted `Bool` (resets every relaunch); production needs a `UserDefaults`-backed flag so it only shows once per install (mirrors `TrialManager.shared.recordFirstLaunchIfNeeded()`'s persisted-flag idiom at line 56, though that's a different subsystem — same "write a UserDefaults key so it only fires once ever" shape). Copy must be drafted fresh per D-13 (short, plain-language, mentions sensitive/password-manager copies are never captured) — replacing the explicit "spike placeholder — Phase 58 will replace this with final copy" string at line 367.

---

## Shared Patterns

### Menu item → AppDelegate target/action idiom
**Source:** `AppDelegate.swift:106` (`for item in menu.items { item.target = self }`) and `AppDelegate.swift:259` (identical loop for the DEBUG menu)
**Apply to:** every new clipboard `NSMenuItem` (`restoreClipboardItem(_:)`, `confirmDeleteAllHistory`). No separate coordinator/builder object — `AppDelegate` is both the menu owner and the action target, matching this file's own consistent style across both its production and DEBUG menus. RESEARCH.md's "Claude's Discretion" note on this (pasteboard-alert trigger site) is already resolved by this existing convention: keep it on `AppDelegate` directly, no new coordinator type.

### Graceful degradation on malformed data (never force-unwrap)
**Source:** `ClipboardFileStore.swift:35-40` (D-04 — load failures return `[]`, never throw/crash) and `ClipboardMonitor.swift`'s `NSImage(data:)`-style optional handling
**Apply to:** the new `ClipboardRowView`'s image-thumbnail rendering (`if let nsImage = NSImage(data: data)`) and the restore write's image branch — never force-unwrap pasteboard/image data, matching the established graceful-degradation discipline across Phases 55-57.

### `#if DEBUG` isolation boundary
**Source:** `AppDelegate.swift:28-38` (debug-only stored properties) and `:226-374` (the entire DEBUG-only method block)
**Apply to:** any new debug/spike-only code this phase might add stays inside `#if DEBUG...#endif`; all production wiring (monitor start, menu rebuild, restore, delete-all) must live OUTSIDE any DEBUG guard — this is the exact boundary RESEARCH.md's Pitfall 3 warns about crossing incorrectly.

### Reused-as-is subsystems (no pattern extraction needed — call directly)
**Source:** `ClipboardStore.swift` (append/clear), `ClipboardFileStore.swift` (load/save/storageRoot), `KeychainClipboardKeyStore.swift` (readOrCreateKey)
**Apply to:** every read/write of clipboard state in the new `AppDelegate` code. These three files are complete, unit-tested, and require zero modification — this phase only calls their existing public API (`ClipboardStore.append(_:)`, `.clear()`, `.items`; `ClipboardFileStore.load(root:key:)`, `.save(_:root:key:)`, `.storageRoot()`; `KeychainClipboardKeyStore().readOrCreateKey()`).

## No Analog Found

| File/Element | Role | Data Flow | Reason |
|---------------|------|-----------|--------|
| `NSHostingView` hosted inside `NSMenuItem.view` specifically | component | request-response | Only existing `NSHostingView` usage in the codebase hosts a *panel's* `contentView` (`NotchWindowController.swift:1164,2437`), never an `NSMenuItem.view` — first-of-kind for this codebase. RESEARCH.md's Pattern 2 + Pitfall 1 are the best available guidance (externally corroborated, MEDIUM confidence), not a local precedent. |
| Destructive-styled two-button `NSAlert` (`hasDestructiveAction`) | controller | request-response | Only existing `NSAlert` in the codebase (`AppDelegate.swift:358-373`) is single-button/informational — no local precedent for destructive-styling or Cancel/Delete branching. RESEARCH.md Assumption A1 flags this as `[ASSUMED]`, verify via Xcode autocomplete/docs at build time. |
| `NSMenuDelegate` conformance | controller | event-driven | Zero matches for `NSMenuDelegate` anywhere in the codebase (confirmed via grep in RESEARCH.md) — this phase establishes the pattern for the first time; RESEARCH.md's Pattern 1 is the only available template. |

## Metadata

**Analog search scope:** `Islet/AppDelegate.swift` (full file read), `Islet/Clipboard/*.swift` (all 5 files, full read), `Islet/Notch/NotchWindowController.swift` (targeted grep + read around `NSHostingView` usage, lines 1145-1174 and 2260 signature only — 2812-line file, non-overlapping targeted reads per large-file protocol)
**Files scanned:** 7 (`AppDelegate.swift`, `ClipboardStore.swift`, `ClipboardItem.swift`, `ClipboardMonitor.swift`, `ClipboardFileStore.swift`, `KeychainClipboardKeyStore.swift`, `NotchWindowController.swift`)
**Pattern extraction date:** 2026-07-23
