# Phase 64: Quick Notes + Obsidian Export - Pattern Map

**Mapped:** 2026-07-25
**Files analyzed:** 11 (7 new, 4 modified)
**Analogs found:** 8 / 11 (3 genuinely novel — no analog, RESEARCH.md's own recommendation is the reference)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `Islet/QuickNotes/QuickNote.swift` (new) | model | CRUD (value type) | `Islet/Clipboard/ClipboardItem.swift` | exact |
| `Islet/QuickNotes/QuickNotesStore.swift` (new) | store (pure reducer) | CRUD | `Islet/Clipboard/ClipboardStore.swift` | exact (minus dedupe branch, plus D-17 `remove(id:)`) |
| `Islet/QuickNotes/QuickNotesFileStore.swift` (new) | service (persistence) | file-I/O | `Islet/Clipboard/ClipboardFileStore.swift` | exact (minus `CryptoKit`/Keychain) |
| `Islet/QuickNotes/QuickNotesVaultWriter.swift` (new) | service (external file append) | file-I/O | none in-codebase — first `FileHandle` usage anywhere in Islet | no analog (use RESEARCH.md Pattern 3 verbatim) |
| `Islet/QuickNotes/QuickNotesFormatter.swift` (new) | utility (pure transform) | transform | none — first D-05-shaped formatter | no analog (use RESEARCH.md D-05 spec verbatim) |
| `Islet/QuickNotes/QuickNotesPopoverView.swift` (new) | component (SwiftUI) | request-response (user input → store mutation) | `ClipboardRowView`/`ClipboardHoverState`/`ClipboardRowContainerView` (`AppDelegate.swift:561-624`) for the row; no analog for the popover shell itself (first `NSPopover` in the codebase) | role-match (row), no-analog (popover shell — use RESEARCH.md Pattern 1/2) |
| `Islet/AppDelegate.swift` (modified) | controller (AppKit shell) | event-driven (menu/status-item wiring) | itself — extend the existing `menu`/`NSMenuDelegate` machinery | exact (same file, established convention) |
| `Islet/SettingsView.swift` (modified) | component (SwiftUI settings) | request-response (toggle + folder picker) | `focusPermissionExplanationView`/`osdPermissionExplanationView`/`capsLockPermissionExplanationView` (`SettingsView.swift:661-751`) + their `.popover` wiring (`SettingsView.swift:408-416`) | exact |
| `Islet/ActivitySettings.swift` (modified) | config | CRUD (key declaration) | itself — `quickNotesKey` already exists (line 40); only a new `vaultFolderPathKey` string needs adding | exact |
| `IsletTests/QuickNotesStoreTests.swift` (new) | test | CRUD | `IsletTests/ClipboardStoreTests.swift` | exact |
| `IsletTests/QuickNotesFileStoreTests.swift` (new) | test | file-I/O | `IsletTests/ClipboardFileStoreTests.swift` | exact (drop the encryption-specific assertions) |

## Pattern Assignments

### `Islet/QuickNotes/QuickNote.swift` (model, CRUD)

**Analog:** `Islet/Clipboard/ClipboardItem.swift` (full file, 22 lines)

```swift
import Foundation

struct ClipboardItem: Equatable, Codable {
    let id: UUID
    var kind: Kind
    var timestamp: Date

    enum Kind: Equatable, Codable {
        case text(String)
        case image(Data)
    }
}
```

**Delta for `QuickNote`:** no `Kind` enum — a note is always plain text (no image branch). Shape becomes:
```swift
struct QuickNote: Equatable, Codable {
    let id: UUID
    var text: String
    var timestamp: Date
}
```

---

### `Islet/QuickNotes/QuickNotesStore.swift` (store, CRUD)

**Analog:** `Islet/Clipboard/ClipboardStore.swift` (full file, 31 lines)

```swift
struct ClipboardStore: Equatable {
    private(set) var items: [ClipboardItem] = []
    let cap = 30   // D-01: plain inline let, not configurable, not shared

    mutating func append(_ item: ClipboardItem) {
        if let index = items.firstIndex(where: { $0.kind == item.kind }) {
            items.remove(at: index)
            items.append(item)
            return
        }
        items.append(item)
        if items.count > cap { items.removeFirst() }   // D-01: FIFO evict oldest past cap
    }

    mutating func clear() {
        items.removeAll()
    }
}
```

**Delta for `QuickNotesStore` (per CONTEXT D-14/D-17/D-18 + discretion note):**
- Same `private(set) var items`, same `cap = 30`, same FIFO `removeFirst()` past cap.
- Drop the `firstIndex(where: kind ==)` dedupe branch entirely — `append` is a plain append (discretion: "append is the simpler default for notes").
- Add `mutating func remove(id: UUID) { items.removeAll { $0.id == id } }` for D-17's per-row delete. No `clear()`/"delete all" method needed (D-17: no "Delete All").
- Zero `AppKit`/`FileManager` — pure value type, identical discipline.

---

### `Islet/QuickNotes/QuickNotesFileStore.swift` (service, file-I/O)

**Analog:** `Islet/Clipboard/ClipboardFileStore.swift` (full file, 115 lines)

**Storage root pattern** (lines 25-30):
```swift
enum ClipboardFileStore {
    static func storageRoot() -> URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("IsletClipboard", isDirectory: true)
    }
```

**Load-never-throws discipline** (lines 32-40):
```swift
    // D-04: any single failure along this chain (missing file, corrupted
    // ciphertext, wrong key, malformed JSON) returns [] — never throws, never
    // crashes.
    static func load(root: URL, key: SymmetricKey) -> [ClipboardItem] {
        let indexURL = root.appendingPathComponent("index.json.enc")
        guard let combined = try? Data(contentsOf: indexURL),
              let plaintext = try? decrypt(combined, using: key),
              let records = try? JSONDecoder().decode([ClipboardItemRecord].self, from: plaintext)
        else { return [] }
        ...
```

**Save pattern** (lines 64-92, encryption calls only — strip these for QuickNotes):
```swift
    static func save(_ items: [ClipboardItem], root: URL, key: SymmetricKey) throws {
        ...
        let plaintext = try JSONEncoder().encode(records)
        let encryptedIndex = try encrypt(plaintext, using: key)
        try encryptedIndex.write(to: root.appendingPathComponent("index.json.enc"))
        ...
    }
```

**Delta for `QuickNotesFileStore` (D-18 — plaintext, no `CryptoKit`, no Keychain, no image-file sweep since notes have no image branch):**
```swift
enum QuickNotesFileStore {
    static func storageRoot() -> URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("IsletQuickNotes", isDirectory: true)
    }

    static func load(root: URL) -> [QuickNote] {
        let indexURL = root.appendingPathComponent("index.json")
        guard let data = try? Data(contentsOf: indexURL),
              let notes = try? JSONDecoder().decode([QuickNote].self, from: data)
        else { return [] }
        return notes
    }

    static func save(_ notes: [QuickNote], root: URL) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(notes)
        try data.write(to: root.appendingPathComponent("index.json"))
    }
}
```
No `ClipboardItemRecord`-style intermediate Codable shape is needed — `QuickNote` itself is `Codable` and has no image-filename indirection to encode around.

---

### `Islet/QuickNotes/QuickNotesVaultWriter.swift` (service, file-I/O — NO analog, genuinely new)

No existing file in this codebase uses `FileHandle`, `NSOpenPanel`, or append-only external-file writes — this is confirmed by `grep -rn "NSPopover|NSOpenPanel|FileHandle" Islet/` returning zero hits (re-verified: only the phrase appears in `.planning/` research docs, not in `Islet/` source). Build directly from RESEARCH.md's own Pattern 3 (composed from Foundation's `FileHandle` docs + this phase's locked D-05/D-06/D-07 spec) — treat that pattern as the reference implementation, not an existing codebase analog:

```swift
enum QuickNotesVaultWriter {
    struct WriteError: Error { let underlying: Error }

    static func append(note text: String, to fileURL: URL, at date: Date) throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: fileURL.path) {
            fm.createFile(atPath: fileURL.path, contents: nil)
        }
        let handle = try FileHandle(forWritingTo: fileURL)
        defer { try? handle.close() }

        let tailInfo = try readTail(of: fileURL, windowBytes: 4096)
        let today = isoDate(date)
        var payload = ""

        if tailInfo.sizeBytes > 0 && !tailInfo.endsWithNewline {
            payload += "\n"
        }
        if tailInfo.lastHeadingDate != today {
            if tailInfo.sizeBytes > 0 { payload += "\n" }
            payload += "## \(today)\n\n"
        }
        payload += formatEntry(text: text, at: date)

        handle.seekToEndOfFile()
        handle.write(Data(payload.utf8))
    }

    private static func readTail(of fileURL: URL, windowBytes: Int) throws
        -> (sizeBytes: UInt64, endsWithNewline: Bool, lastHeadingDate: String?) {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }
        let size = try handle.seekToEnd()
        guard size > 0 else { return (0, true, nil) }

        let offset = size > UInt64(windowBytes) ? size - UInt64(windowBytes) : 0
        try handle.seek(toOffset: offset)
        let tailData = handle.readDataToEndOfFile()
        let tailString = String(decoding: tailData, as: UTF8.self)

        let endsWithNewline = tailData.last == 0x0A
        let lines = tailString.split(separator: "\n", omittingEmptySubsequences: false)
        let lastHeadingLine = lines.last { $0.hasPrefix("## ") }
        let lastHeadingDate = lastHeadingLine.map { String($0.dropFirst(3)) }

        return (size, endsWithNewline, lastHeadingDate)
    }
}
```
Full source: `.planning/phases/64-quick-notes-obsidian-export/64-RESEARCH.md` lines 244-301 (Pattern 3). D-07 constraint: never read-modify-write the whole file — only this bounded tail read + a pure append.

---

### `Islet/QuickNotes/QuickNotesFormatter.swift` (utility, transform — NO analog)

No existing formatter in this codebase produces D-05's exact `## YYYY-MM-DD` / `- HH:mm text` / 2-space-indented-continuation shape. Pure function, no `FileHandle`/AppKit — treat D-05's CONTEXT.md code block (lines 33-43) as the literal target string, not an illustration:
```
## 2026-07-25

- 14:32 Erste Notiz, kurz.
- 14:47 Längere Notiz mit
  zweiter Zeile eingerückt.
```
Signature suggestion (mirrors the pure, no-side-effect discipline of `ClipboardStore`/`ActivitySettings.accent(for:)`):
```swift
enum QuickNotesFormatter {
    static func isoDate(_ date: Date) -> String { /* "yyyy-MM-dd" */ }
    static func formatEntry(text: String, at date: Date) -> String {
        // "- HH:mm " + first line, each subsequent line prefixed with 2 spaces, trailing "\n"
    }
}
```

---

### `Islet/QuickNotes/QuickNotesPopoverView.swift` (component, request-response)

**Analog for the recent-notes row (hover + click):** `ClipboardRowView`/`ClipboardHoverState`/`ClipboardRowContainerView`, `Islet/AppDelegate.swift:557-624`

```swift
final class ClipboardHoverState: ObservableObject {
    @Published var isHovering = false
}

final class ClipboardRowContainerView: NSView {
    let hoverState = ClipboardHoverState()
    private var trackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) { hoverState.isHovering = true }
    override func mouseExited(with event: NSEvent) { hoverState.isHovering = false }
}

struct ClipboardRowView: View {
    static let rowWidth: CGFloat = 260
    let item: ClipboardItem
    let onSelect: () -> Void
    @ObservedObject var hoverState: ClipboardHoverState

    var body: some View {
        HStack(spacing: 6) {
            // ... content ...
            Spacer()
        }
        .padding(.horizontal, 14)
        .frame(width: ClipboardRowView.rowWidth, height: 22, alignment: .leading)
        .contentShape(Rectangle())
        .background(hoverState.isHovering ? Color.primary.opacity(0.08) : Color.clear)
        .onTapGesture { onSelect() }
    }
}
```

**Important divergence per 64-UI-SPEC.md:** since D-04 lands the notes list **inside the popover** (not an `NSMenuItem.view`), the notes list does NOT need `ClipboardRowContainerView`'s `NSTrackingArea` workaround — UI-SPEC's own Interaction Notes say to mirror `ClipboardRowView`'s hover pattern for consistency, but 64-UI-SPEC.md line 96 explicitly notes plain SwiftUI hosting is fine outside `NSMenuItem.view`'s quirks; a plain SwiftUI `.onHover` is legitimate here (the `NSMenuItem.view`-specific `mouseExited`-reliability bug this codebase hit does not apply inside a normal `NSPopover`-hosted view). Row height is NOT fixed at 22pt (64-UI-SPEC.md Spacing Scale) — size-to-content instead, since notes can wrap multi-line.

**No analog for the popover shell itself** — first `NSPopover` in the codebase. Build directly from RESEARCH.md Pattern 1 (`AppDelegate` owns `quickNotesPopover`, `show(relativeTo:of:preferredEdge:)`, `makeFirstResponder` dispatched async per Pitfall 10) and Pattern 2 (`Button(...).keyboardShortcut(.return, modifiers: .command)` for Cmd+Return submit alongside the `TextEditor`). Full source: 64-RESEARCH.md lines 178-232.

---

### `Islet/AppDelegate.swift` (modified — controller, event-driven)

**Menu-item wiring pattern to extend** (`AppDelegate.swift:109-123`):
```swift
menu = NSMenu()
menu.addItem(withTitle: "Settings…",
             action: #selector(openSettings), keyEquivalent: ",")
menu.addItem(withTitle: "Check for Updates…",
             action: #selector(checkForUpdates), keyEquivalent: "")
menu.addItem(.separator())
menu.addItem(withTitle: "Quit Islet",
             action: #selector(quit), keyEquivalent: "q")
for item in menu.items { item.target = self }
menu.delegate = self
statusItem.menu = menu
```
Add `menu.addItem(withTitle: "New Note…", action: #selector(openQuickNotesPopover), keyEquivalent: "")` before the separator (per RESEARCH.md Code Example 1).

**Click-routing constraint to respect** (`AppDelegate.swift:209-224`, `applyMenuBarClickRouting`):
```swift
private func applyMenuBarClickRouting(isLicensed: Bool) {
    if isLicensed {
        statusItem.menu = menu
        statusItem.button?.action = nil
    } else {
        statusItem.menu = nil
        statusItem.button?.target = self
        statusItem.button?.action = #selector(openSettings)
    }
}
```
Any new popover-open entry point lives inside `menu` (the licensed-only path) — it must not fire while `statusItem.menu = nil` in the locked-license state; no separate wiring needed since it's just one more `NSMenuItem` inside the existing `menu`.

**Identifier-prefix dynamic-section pattern (only relevant if a later revision moves the list back into `NSMenu`)** — `menuNeedsUpdate`, `AppDelegate.swift:414-481`: removal via `menu.items.removeAll { $0.identifier?.rawValue.hasPrefix("clip.") == true }`, own prefix required for a second dynamic section per CONTEXT.md's explicit warning ("must use its own identifier prefix, e.g. `note.`, so the two dynamic sections cannot clobber each other"). **Not needed for the D-04-chosen shape** (list lives inside the popover, not the menu) — recorded here only in case a future revision reopens D-04.

**Local event-monitor pattern (why D-01 avoids `NSMenu` for the input)** — `clipboardHotkeyMonitor`, `AppDelegate.swift:32-38` and `menuWillOpen`/`menuDidClose`, `AppDelegate.swift:483-508`: this is the evidence trail cited by D-01/D-15, not a pattern to copy — Quick Notes deliberately has no Cmd+0-9 recall (D-15), so no equivalent local monitor is needed for the notes list itself.

---

### `Islet/SettingsView.swift` (modified — component, request-response)

**Card registration already exists** (lines 242-245) — only `onOptionsTap` needs wiring, from `nil` to a folder-picker action:
```swift
ActivityCardData(id: "quickNotes", title: "Quick Notes",
                  description: "Capture a quick text note straight into your Obsidian vault.",
                  icon: "note.text", iconColor: .secondary,
                  isOn: $quickNotesEnabled, isNew: true, onOptionsTap: nil),
```

**`onOptionsTap` + `.popover` wiring pattern to mirror** (`SettingsView.swift:185-194` declaration site, `:408-416` popover attachment, `:661-688` explanation view body):
```swift
ActivityCardData(id: "focus", title: "Focus Mode", ...,
                  onOptionsTap: { showFocusPermissionExplanation = true }),
...
categorySection(title: "System-HUDs", cards: systemHUDCards)
    .popover(isPresented: $showFocusPermissionExplanation) {
        focusPermissionExplanationView
    }
...
private var focusPermissionExplanationView: some View {
    VStack(alignment: .leading, spacing: 8) {
        Text("Allow Focus Status Access")
            .font(.system(size: 15, weight: .semibold))
        Text("Islet needs permission to detect when Focus or Do Not Disturb is on.")
            .font(.system(size: 12))
            .lineSpacing(12 * 0.4)
        HStack {
            Button("Not Now") { showFocusPermissionExplanation = false }
            Spacer()
            Button("Continue") { ... }
                .keyboardShortcut(.defaultAction)
        }
    }
    .padding(16)
    .frame(width: 280)
}
```
**Delta for Quick Notes' vault-folder picker (D-08/D-09/D-10/D-11):** the popover body is NOT a permission-explanation (no Continue/system-settings deep link) — it hosts an `NSOpenPanel` folder picker (directory mode, per RESEARCH.md Code Example 2) plus a current-path display `Text`. `onOptionsTap: { showQuickNotesVaultPicker = true }` on the `quickNotes` card (line 245), a new `@State private var showQuickNotesVaultPicker = false` alongside the existing 3 (lines 43/52/56), and a new `.popover(isPresented: $showQuickNotesVaultPicker) { quickNotesVaultPickerView }` attached to `categorySection(title: "Produktivität", cards: productivityCards)` (line 418) — mirroring exactly how the System-HUDs section attaches its 3 popovers at lines 408-416, not a new generic per-card popover router (the project's own established anti-pattern to avoid, per RESEARCH.md).

**`NSOpenPanel` call (RESEARCH.md Code Example 2, `64-RESEARCH.md:381-391`):**
```swift
@objc private func chooseQuickNotesVaultFolder() {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = false
    panel.prompt = "Choose"
    panel.message = "Choose your Obsidian vault folder"
    guard panel.runModal() == .OK, let url = panel.url else { return }
    UserDefaults.standard.set(url.path, forKey: "quickNotes.vaultFolderPath")   // D-09: plain path, no bookmark
}
```

---

### `Islet/ActivitySettings.swift` (modified — config)

**Existing key already present** (line 40): `static let quickNotesKey = "activity.quickNotes"` — already in `defaultsToFalseKeys` (line 55). **No change needed for the toggle itself.**

**New key needed:** a vault-folder-path key, following this file's own `domain.key` naming convention (line 40 pattern: `"activity.<name>"`; this is a path, not a toggle, so follow the `switcher.slot.*`-style dotted convention instead, e.g. `static let quickNotesVaultFolderPathKey = "quickNotes.vaultFolderPath"`, matching RESEARCH.md's own Code Examples 2/3 literal key string). This is a plain `String` UserDefaults value (D-09: no security-scoped bookmark), not a `Bool`, so it does NOT go in `defaultsToFalseKeys`.

---

### `IsletTests/QuickNotesStoreTests.swift` (test, CRUD)

**Analog:** `IsletTests/ClipboardStoreTests.swift` (full file, 70 lines) — one test method per behavior, fresh `var store = ...Store()` per test, no setUp/tearDown, no mocking framework:
```swift
final class ClipboardStoreTests: XCTestCase {
    func testAppendPast30ItemsEvictsOldest() {
        var store = ClipboardStore()
        for i in 0...30 {
            let item = ClipboardItem(id: UUID(), kind: .text("item-\(i)"),
                                      timestamp: Date(timeIntervalSinceReferenceDate: Double(i)))
            store.append(item)
        }
        XCTAssertEqual(store.items.count, 30)
        XCTAssertFalse(store.items.contains(where: { $0.kind == .text("item-0") }))
    }
    ...
    func testClearEmptiesStore() { ... }
}
```
**Delta:** drop the two dedupe-behavior tests (`testAppendDuplicate...`) since `QuickNotesStore.append` has no dedupe branch; add a `testRemoveByIdDeletesOnlyThatEntry` test for D-17's new `remove(id:)` method (no analog in `ClipboardStore`, since Clipboard has no per-row delete yet).

---

### `IsletTests/QuickNotesFileStoreTests.swift` (test, file-I/O)

**Analog:** `IsletTests/ClipboardFileStoreTests.swift` (full file, 109 lines) — `fixturesDir` setUp/tearDown against `NSTemporaryDirectory()`, one behavior per test:
```swift
final class ClipboardFileStoreTests: XCTestCase {
    private var fixturesDir: URL!

    override func setUp() {
        super.setUp()
        fixturesDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ClipboardFileStoreTestsFixtures-\(UUID())", isDirectory: true)
        try? FileManager.default.createDirectory(at: fixturesDir, withIntermediateDirectories: true)
    }
    override func tearDown() {
        try? FileManager.default.removeItem(at: fixturesDir)
        fixturesDir = nil
        super.tearDown()
    }
    func testSaveThenLoadRoundTripsTextAndImageItems() throws { ... }
    func testLoadReturnsEmptyArrayOnCorruptedIndex() throws { ... }
}
```
**Delta:** keep the round-trip and corrupted-input tests (`testSaveThenLoadRoundTrips...`, `testLoadReturnsEmptyArrayOnCorruptedIndex`) adapted to plain JSON (no key parameter, no `AES.GCM`). Drop `testEncryptedFilesContainNoReadablePlaintext` (inverted — plaintext IS the point, D-18) and `testLoadReturnsEmptyArrayWithWrongKey` (no key exists). Drop the orphaned-image-file tests entirely — `QuickNote` has no image branch, no `images/` directory to sweep.

---

## Shared Patterns

### Menu-bar status item + menu (single instance, reused not duplicated)
**Source:** `Islet/AppDelegate.swift:80, 109-123`
**Apply to:** the "New Note…" `NSMenuItem` — added to the existing `statusItem`/`menu`, never a second `NSStatusItem` (that pattern is reserved for genuinely separate concerns like the `#if DEBUG` status item, `AppDelegate.swift:44-53`).

### Risk-isolated file I/O kept out of the pure reducer
**Source:** `ClipboardStore.swift` (pure) / `ClipboardFileStore.swift` (I/O), same split as `ShelfLogic`/`ShelfFileStore`
**Apply to:** `QuickNotesStore.swift` (pure, zero `FileManager`/AppKit) / `QuickNotesFileStore.swift` (all local persistence I/O) / `QuickNotesVaultWriter.swift` (all external vault-file I/O) — three-way split, not two, because the vault write and the local-list persistence are genuinely separate concerns (D-17: deleting a local entry never touches the vault).

### Load-never-throws / returns-`[]` on any failure
**Source:** `ClipboardFileStore.load` (`ClipboardFileStore.swift:32-40`)
**Apply to:** `QuickNotesFileStore.load` — corrupted JSON, missing file, any decode failure all collapse to `[]`, never a thrown error surfaced to the caller.

### `@AppStorage`/`UserDefaults` key declared once, shared verbatim
**Source:** `ActivitySettings.swift` (every key, e.g. line 40 `quickNotesKey`)
**Apply to:** the new vault-folder-path key — declare once in `ActivitySettings.swift`, read from both `SettingsView.swift` (folder picker + path display) and `AppDelegate.swift`/`QuickNotesVaultWriter` call site (path validity check, D-11) — never redefine the string literal at a second call site.

### Settings card `onOptionsTap` → `.popover` (not a generic per-card router)
**Source:** `SettingsView.swift:185-194` (declaration), `:408-416` (attachment), `:661-751` (3 existing explanation-view bodies)
**Apply to:** the Quick Notes vault-folder-picker popover — exactly the same 3-part wiring (state Bool, `onOptionsTap` closure setting it true, `.popover(isPresented:)` attached to the category section), never a shared/generic item-based popover dispatcher.

### `data-loss guard`: a failed operation must never appear to have succeeded
**Source:** D-12 (locked rule, CONTEXT.md) — no direct codebase precedent (this is a NEW discipline for this phase), but conceptually parallel to `ClipboardFileStore`'s `try?`-swallowing discipline in `AppDelegate.swift:163` (`try? ClipboardFileStore.save(...)`) — Clipboard's save failures are already silently tolerated (append succeeded in-memory regardless of disk-write outcome), which is the OPPOSITE of what D-12 requires. **Do not copy that swallow-and-continue shape for Quick Notes** — `QuickNotesVaultWriter.append` must be checked with a real `do/catch`, and `QuickNotesStore.append` must only run inside the `catch`-free success path.

## No Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| `Islet/QuickNotes/QuickNotesVaultWriter.swift` | service | file-I/O | First `FileHandle`-based append-only writer in the codebase (confirmed via `grep -rn FileHandle Islet/` → zero hits outside `.planning/`); build from 64-RESEARCH.md Pattern 3, not a codebase analog |
| `Islet/QuickNotes/QuickNotesFormatter.swift` | utility | transform | First D-05-shaped day-heading/bullet formatter; no existing Markdown-generation code anywhere in `Islet/` |
| `Islet/QuickNotes/QuickNotesPopoverView.swift` (popover shell only, not the row) | component | request-response | First `NSPopover` anchored to `NSStatusItem` in the codebase (confirmed via `grep -rn NSPopover\|NSOpenPanel Islet/` → zero hits outside `.planning/`); build from 64-RESEARCH.md Pattern 1/2 |

## Metadata

**Analog search scope:** `Islet/Clipboard/`, `Islet/AppDelegate.swift`, `Islet/SettingsView.swift`, `Islet/ActivityCard.swift`, `Islet/ActivitySettings.swift`, `Islet/Notch/ViewSwitcherState.swift`, `IsletTests/Clipboard*Tests.swift`
**Files scanned:** 10 source files + 2 test files read in full; `grep -rn` sweeps for `NSPopover`/`NSOpenPanel`/`FileHandle` across `Islet/` confirmed zero prior usage
**Pattern extraction date:** 2026-07-25
