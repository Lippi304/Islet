# Phase 64: Quick Notes + Obsidian Export - Research

**Researched:** 2026-07-25
**Domain:** Native macOS menu-bar capture UI (`NSPopover` anchored to `NSStatusItem`) + atomic external-file append (`FileHandle`) into a user-chosen, non-sandboxed folder
**Confidence:** MEDIUM-HIGH (grounded in direct reads of the live codebase — `AppDelegate.swift`, `ClipboardStore.swift`, `ClipboardFileStore.swift`, `ViewSwitcherState.swift`, `ActivitySettings.swift`, `SettingsView.swift`, `project.pbxproj` — plus WebSearch-verified AppKit/Foundation platform mechanics; `NSPopover`/`FileHandle`/`NSOpenPanel` have ZERO precedent anywhere in this codebase today, so the popover-focus and tail-read mechanics below are genuinely new territory, not copy-paste from an existing file)

## Summary

Phase 64 builds a **menu-bar-only** feature (D-13 locks this: zero `IslandResolver`/`SelectedView`/notch participation) with three real subsystems: (1) an `NSPopover` anchored to the existing `statusItem` for multi-line capture — the first `NSPopover` in this codebase, chosen specifically because `NSMenu`'s own submenu tracking loop starves embedded views of real keyboard focus (the exact problem Phase 58's `clipboardHotkeyMonitor` had to work around); (2) a genuinely new append-only file-write subsystem (`FileHandle.seekToEndOfFile()` + `write(_:)`, never read-modify-write) targeting a user-chosen Obsidian vault folder, with a tail-read of the target file to decide whether today's `## YYYY-MM-DD` heading already exists; (3) a plaintext local recent-notes store that is a near-verbatim copy of `ClipboardStore`/`ClipboardFileStore` with the `CryptoKit`/Keychain layer removed.

The highest-uncertainty item CONTEXT.md did not fully resolve is D-01's own premise: an `NSPopover` shown from a status item is **not automatically guaranteed to become key window and hand real keyboard focus to an embedded text view** — this is a well-documented AppKit gotcha (see Pitfall 10 below), distinct from, but adjacent to, the `NSMenu` keyEquivalent problem D-01 already cites. This needs a short on-device focus-and-Cmd+Return spike before or during Wave 1, not an assumption carried into the UI-SPEC unverified.

**Primary recommendation:** Build one `NSPopover` (not an `NSMenu` submenu) containing a single SwiftUI view: a multi-line `TextEditor` up top, a `Cmd+Return`-bound submit `Button`, and a `ScrollView` of recent-notes rows below it (mirrors D-04's "same popover, list below" option) — reusing `ClipboardStore`'s pure-reducer shape and `ClipboardFileStore`'s load-never-throws persistence discipline verbatim minus encryption, plus one genuinely new `QuickNotesVaultWriter` (or similarly named) type that owns the `FileHandle` append + tail-read logic in complete isolation from the pure reducer, exactly matching this codebase's existing "risky I/O lives in one dedicated file, kept out of the pure reducer" convention (`ClipboardFileStore` next to `ClipboardStore`, `ShelfFileStore` next to `ShelfLogic`).

## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Typing happens in a popover anchored to the menu-bar status item, not inside the `NSMenu` submenu. A "New Note…" menu item closes the menu and opens the popover. Rationale: `NSMenu` runs its own event-tracking loop and does not route key events to embedded views — this project already hit this exact class of problem in Phase 58 (`clipboardHotkeyMonitor`, `AppDelegate.swift:33-38`). A popover gets real keyboard focus with no hack. Accepted cost: one extra click, and the popover is new UI with no existing component to reuse.
- **D-02:** The input is multi-line. Enter inserts a newline; Cmd+Enter submits.
- **D-03 (Claude's discretion):** Whether the popover closes on submit or stays open with a cleared field.
- **D-04 (Claude's discretion):** Whether the recent-notes list lives inside the same popover (input on top, list below) or stays as an `NSMenu` anchor+submenu of `NSHostingView` rows next to a "New Note…" item. Note D-15 (no Cmd+0-9) removes the main reason the Clipboard-style submenu shape was needed.
- **D-05:** Entry format is a day heading plus bullet-with-time, continuation lines indented under the bullet:
  ```markdown
  ## 2026-07-25

  - 14:32 Erste Notiz, kurz.
  - 14:47 Längere Notiz mit
    zweiter Zeile eingerückt.

  ## 2026-07-26

  - 09:12 Nächster Tag.
  ```
  `## YYYY-MM-DD` written once per day (ISO date), each note is `- HH:mm <text>` (24-hour), every line after the first of a multi-line note indented two spaces.
- **D-06:** To decide whether today's `## YYYY-MM-DD` heading already exists, the app reads the tail of the file before appending and checks whether the last `## YYYY-MM-DD` line is today's date. Chosen over remembering the last-written date in `UserDefaults`.
- **D-07 (constraint, not a preference):** The write must still be append-only (`FileHandle.seekToEndOfFile()` + `write(_:)`), never read-modify-write-whole-file. The tail read must also handle a file that ends without a trailing newline.
- **D-08:** The user picks a folder via `NSOpenPanel` (directory mode); the filename is fixed (`Islet Notes.md`, exact name at Claude's discretion).
- **D-09:** Islet is not sandboxed (`ENABLE_APP_SANDBOX = NO`, verified), so the chosen path is stored as a plain path — no security-scoped bookmarks. The macOS TCC prompt for protected folders (`~/Documents` etc.) still applies and must be expected on first write.
- **D-10:** The folder picker lives in the Settings grid card (Phase 59 `SETTINGS-04` pattern), alongside the feature's on/off toggle. Per `SETTINGS-05` the toggle defaults OFF.
- **D-11:** Path validity is checked when the popover opens, not on first write.
- **D-12 (locked rule — data-loss guard, NOT a style choice):** A note whose write failed must never appear in the recent-notes list. On failure the typed text stays in the input field and nothing is recorded as saved. Visual presentation of the failure is Claude's discretion; the guard itself is not.
- **D-13:** Quick Notes gets no notch surface at all. No new `SelectedView` case, no `IslandResolver`/`IslandPresentation`/`ActiveTransient` entry, and the 4-slot top-edge switcher model is untouched.
- **D-14:** Cap is 30 entries with FIFO eviction, matching `ClipboardStore.cap` exactly. Eviction only affects the local list — the entry stays in the vault `.md` file forever.
- **D-15:** No Cmd+0-9 quick recall for notes.
- **D-16:** Clicking a row does nothing — the list is pure display.
- **D-17:** Individual notes are deletable from the list (per-row control). No "Delete All" item. Deleting only ever touches the local list, never the vault `.md` file.
- **D-18:** Local persistence mirrors `ClipboardFileStore`'s shape (JSON index under Application Support, load-failure returns `[]`) but is plaintext — no `CryptoKit`, no Keychain key.

### Claude's Discretion

- Popover behavior after submit — close vs. stay open with cleared field (D-03).
- Where the recent-notes list renders — inside the popover vs. `NSMenu` submenu (D-04).
- Exact fixed filename for the vault file (D-08, suggested `Islet Notes.md`).
- Visual presentation of a write/path failure — inline error row vs. modal alert (D-12); the guard itself is locked.
- Whether duplicate-note handling mirrors `ClipboardStore`'s move-to-newest dedupe or simply appends — append is the simpler default for notes.

### Deferred Ideas (OUT OF SCOPE)

- Global hotkey for note capture.
- User-editable vault filename (D-08 fixes the filename).
- "Delete All" for the notes list.
- Per-row delete for Clipboard History (parity is a separate concern).
- Editing a note after it was written (vault file is append-only by construction).
- Obsidian Local REST API plugin integration — out of scope per REQUIREMENTS.md and `research/FEATURES.md` (plain append is the standard lightweight pattern).
- Daily-note mode, tag autocomplete, Markdown formatting shortcuts.

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| NOTES-01 | User can quickly capture a typed text note from a menu-bar flyout, mirroring the existing Clipboard History submenu | Architecture Patterns §1-2 (popover wiring), Code Examples §1; `AppDelegate.swift:109-123` menu-item pattern verified live |
| NOTES-02 | Each captured note is appended, with a timestamp, to one fixed `.md` file inside a user-chosen Obsidian vault folder — file created if missing, never overwritten/corrupted, append works while Obsidian.app is closed | Architecture Patterns §3 (vault writer), Code Examples §2-3, Common Pitfalls (Pitfall 7 inherited + Pitfall 11 new), Don't Hand-Roll |
| NOTES-03 | A local, unencrypted recent-notes list is shown in the same flyout, most-recent-first | Architecture Patterns §4 (`QuickNotesStore`/`QuickNotesFileStore`), Don't Hand-Roll (reuse `ClipboardStore` shape minus crypto) |

## Architectural Responsibility Map

Islet has no web/server tiers; the closest analog for this native menu-bar-agent app is: **Menu-bar/AppKit shell** (status item, menu, popover — owned by `AppDelegate`), **SwiftUI presentation layer** (views hosted inside AppKit containers), **App-owned local storage** (Application Support JSON, the `Database/Storage` analog), and **External user storage** (the Obsidian vault `.md` file — outside the app's control, analogous to a third-party API/CDN boundary the app writes to but does not own).

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Note capture input (typing, Cmd+Enter submit) | AppKit shell (`NSPopover` + hosted SwiftUI) | — | D-01 locks this outside `NSMenu`; the popover is owned by `AppDelegate`, same as the status item and menu today |
| Menu wiring ("New Note…" item) | AppKit shell (`AppDelegate`/`NSMenu`) | — | Extends the existing `menu`/`NSMenuDelegate` machinery already in `AppDelegate.swift` |
| Vault file append (`.md`, timestamped) | External user storage (Obsidian vault, outside app sandbox/ownership) | App-owned local storage (path string persisted in `UserDefaults` per D-09) | The `.md` file itself is the user's own document; Islet only ever appends, never owns or reads it beyond the tail-check |
| Day-heading tail-read check (D-06) | App-owned local storage logic (reads the external file, but the DECISION logic is Islet's own) | External user storage (the bytes being read) | The read is a one-time query against external state to inform a local decision; it is not a persistent Islet-owned cache |
| Recent-notes list persistence (D-18) | App-owned local storage (Application Support JSON) | — | Identical tier to `ClipboardFileStore` today — plaintext instead of `CryptoKit`-sealed |
| Recent-notes list display, per-row delete | SwiftUI presentation layer (hosted inside the same popover per D-04 recommendation) | — | Pure display + local-list-only mutation (D-16/D-17); never touches the vault file |
| Settings toggle + vault-folder picker | SwiftUI presentation layer (`SettingsView.swift`'s existing `ActivityCard`/grid) | AppKit shell (`NSOpenPanel`) | D-10 locks this into the Phase 59 grid card pattern; the folder picker itself is a one-shot AppKit sheet triggered from SwiftUI |
| Notch/`IslandResolver` participation | **None — explicitly excluded (D-13)** | — | The whole feature is out-of-tier for the notch/resolver entirely; this is the tier map's own confirmation of D-13, not a contradiction of it |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `AppKit` (`NSPopover`, `NSStatusItem`, `NSOpenPanel`) | Ships with macOS SDK | Capture-surface anchoring, folder picker | Already the project's established pattern for all menu-bar/window-shell work (per `CLAUDE.md`'s own stack doc: "AppKit... only for the window shell and a few system hooks") — no alternative considered, this is the only API surface that can anchor UI to an `NSStatusItem` |
| `SwiftUI` (`TextEditor`, `ScrollView`, `Button`) | Ships with macOS SDK | Popover content view (input + recent-notes list) | Matches "build ~95% of visible app here" convention already established project-wide; hosted via `NSHostingController`/`NSHostingView` exactly like `ClipboardRowView` today |
| `Foundation` (`FileHandle`, `FileManager`, `Date`/`DateFormatter`) | Ships with macOS SDK | Atomic vault append, tail read, day-heading formatting | D-07 explicitly locks `FileHandle.seekToEndOfFile()` + `write(_:)` — no third-party file-I/O library considered or needed |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `Combine`/`@Published` (via `ObservableObject`) | Ships with SwiftUI | Recent-notes list reactivity inside the popover | Same pattern already used for `ClipboardHoverState`; optional — a plain `@State` array refreshed on popover-open is equally valid given D-16's "pure display" scope |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `NSPopover` anchored to `NSStatusItem` | `NSMenu` submenu of `NSHostingView` rows (Clipboard History's own shape) | Rejected by D-01 — nested-submenu `keyEquivalents`/text-input never reliably get keyboard focus, the exact bug Phase 58 had to route around |
| `FileHandle.seekToEndOfFile()` + `write(_:)` | Low-level POSIX `open(path, O_APPEND\|O_WRONLY\|O_CREAT)` + `write()` | POSIX `O_APPEND` gives a true OS-level atomic seek+write guarantee that `FileHandle`'s two-step `seekToEndOfFile()`+`write()` technically does not (see Pitfall 11) — **not adopted**: D-07 explicitly locks the `FileHandle` API by name, and the project's own `PITFALLS.md` Technical Debt table already accepts the residual risk as fine for a single-process, single-writer app; documented here only so the planner knows the caveat exists, not as a call to violate the locked decision |
| Storing the vault path as a plain string (D-09) | Security-scoped bookmark (`NSURL.bookmarkData(options: .withSecurityScope, ...)`) | Rejected — only meaningful inside App Sandbox; Islet is confirmed non-sandboxed (`ENABLE_APP_SANDBOX = NO`, `project.pbxproj:895,1057`), so a plain persisted path is correct and simpler |

## Package Legitimacy Audit

**Not applicable.** This phase installs zero external packages (no SPM/CocoaPods/npm additions) — every type used (`NSPopover`, `NSStatusItem`, `NSOpenPanel`, `FileHandle`, `TextEditor`) ships with the macOS SDK the project already links against. `slopcheck`/registry verification was not run because there is nothing to verify; no package-based `checkpoint:human-verify` gating is needed for this phase.

## Architecture Patterns

### System Architecture Diagram

```
[Status-item click]
        │
        ▼
  NSMenu (existing `menu`)
        │  "New Note…" item selected
        ▼
  AppDelegate.openQuickNotesPopover()
        │
        ▼
  NSPopover (new) ── contentViewController = NSHostingController(QuickNotesPopoverView)
        │
        ├──▶ [TextEditor: multi-line input] ──Cmd+Return──▶ submit()
        │                                                       │
        │                                                       ▼
        │                                     QuickNotesStore.append(note)  (pure reducer,
        │                                        cap=30, FIFO evict — mirrors ClipboardStore)
        │                                                       │
        │                                     ┌─────────────────┴─────────────────┐
        │                                     ▼                                   ▼
        │                     QuickNotesFileStore.save(...)          QuickNotesVaultWriter.append(...)
        │                     (Application Support JSON,               (tail-read for day heading D-06 →
        │                      plaintext, D-18)                         FileHandle.seekToEndOfFile()+write,
        │                     └─ never touches the vault file           D-07 — the ONLY writer of the
        │                                                                external .md file)
        │                                                                        │
        │                                                          success ──────┴────── failure
        │                                                              │                    │
        │                                                              ▼                    ▼
        │                                                  note appears in list      D-12: note NEVER
        │                                                  (D-12 satisfied)           added to list;
        │                                                                              text stays in field
        ▼
  [ScrollView: recent notes, most-recent-first, per-row delete (D-17)]
        │  row hover → delete button
        ▼
  QuickNotesStore.remove(id)  (local list only — vault .md file untouched)
```

### Recommended Project Structure

```
Islet/
├── AppDelegate.swift              # + "New Note…" menu item, popover show/close wiring
├── QuickNotes/                    # new group, mirrors Islet/Clipboard/'s shape exactly
│   ├── QuickNote.swift            # value type: id, text, timestamp (mirrors ClipboardItem)
│   ├── QuickNotesStore.swift      # pure reducer: append/remove/cap=30 FIFO (mirrors ClipboardStore)
│   ├── QuickNotesFileStore.swift  # local JSON persistence, PLAINTEXT (mirrors ClipboardFileStore minus CryptoKit)
│   ├── QuickNotesVaultWriter.swift# NEW subsystem: FileHandle append + tail-read day-heading check (D-06/D-07)
│   ├── QuickNotesFormatter.swift  # pure: note text + Date -> D-05's exact "- HH:mm text" / indented-continuation string
│   └── QuickNotesPopoverView.swift# SwiftUI: TextEditor + submit button + recent-notes ScrollView
└── SettingsView.swift             # existing quickNotes ActivityCard (Phase 59) gains onOptionsTap for the
                                    # NSOpenPanel folder picker + current-path display (D-10)
```

### Pattern 1: NSPopover anchored to a status-item button (D-01)

**What:** Show a popover relative to the status item's own button, not a submenu.
**When to use:** Any capture surface needing real keyboard focus from the menu bar.
**Example:**
```swift
// Source: WebSearch-verified AppKit pattern (shaheengandhi.com/using-nspopover-with-nsstatusitem/,
// Apple NSPopover docs) — MEDIUM confidence, cross-referenced across 2+ independent sources,
// no Context7 entry exists for AppKit (not a versioned third-party library)
private lazy var quickNotesPopover: NSPopover = {
    let popover = NSPopover()
    popover.behavior = .transient          // auto-closes on outside click, matches D-03's "stays open on submit" only via explicit re-show logic, not accidental persistence
    popover.contentViewController = NSHostingController(rootView: QuickNotesPopoverView(...))
    return popover
}()

@objc private func openQuickNotesPopover() {
    guard let button = statusItem.button else { return }
    quickNotesPopover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    // Pitfall 10 (below): explicitly make the hosted text view first responder —
    // NSPopover's window becoming key does NOT automatically mean the SwiftUI
    // TextEditor inside it becomes first responder on every macOS version.
    DispatchQueue.main.async {
        quickNotesPopover.contentViewController?.view.window?.makeFirstResponder(
            quickNotesPopover.contentViewController?.view
        )
    }
}
```

### Pattern 2: Cmd+Return submit alongside a multi-line TextEditor (D-02)

**What:** A `Button` with `.keyboardShortcut(.return, modifiers: .command)` submits; plain Return inside the `TextEditor` inserts a newline (SwiftUI's default `TextEditor` behavior — no extra work needed for D-02's newline half).
**When to use:** Any multi-line capture form needing a non-conflicting submit shortcut.
**Example:**
```swift
// Source: WebSearch-verified (sarunw.com/posts/swiftui-keyboard-shortcuts,
// developer.apple.com/forums/thread/694107) — MEDIUM confidence; flag for on-device
// verification per Pitfall 10, since Return-consuming focused text views are a known
// source of keyboardShortcut() routing edge cases on macOS
struct QuickNotesPopoverView: View {
    @State private var text = ""
    var body: some View {
        VStack {
            TextEditor(text: $text)   // Return = newline, default TextEditor behavior
            Button("Save") { submit() }
                .keyboardShortcut(.return, modifiers: .command)
                .buttonStyle(.plain)
                .opacity(0)            // invisible; the visible affordance can be a
                                       // separate styled button/label, this one only
                                       // exists to own the Cmd+Return shortcut binding
        }
    }
}
```

### Pattern 3: Append-only vault write with day-heading tail check (D-05/D-06/D-07)

**What:** Read only the tail of the target file to decide whether a new `## YYYY-MM-DD` heading is needed, then append via `FileHandle`, never rewriting existing bytes.
**When to use:** Any external-file append where the file may be large, externally edited, and must never be corrupted.
**Example:**
```swift
// Source: Composed from Foundation FileHandle docs (developer.apple.com/documentation/foundation/filehandle)
// + this project's own locked D-05/D-06/D-07 format spec — CITED (no third-party library, Apple's own
// FileHandle API), tail-read algorithm itself is this research's own design, not copied from an external
// source — treat the exact byte-window size and UTF-8-boundary handling below as [ASSUMED], verify on-device
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

        // D-07: handle a hand-edited file with no trailing newline before appending
        // anything at all — never let a new line concatenate onto an existing one.
        if tailInfo.sizeBytes > 0 && !tailInfo.endsWithNewline {
            payload += "\n"
        }

        if tailInfo.lastHeadingDate != today {
            // D-05: blank line before a NEW day heading, except at the very start of
            // an empty/new file (no leading blank line on a brand-new vault file).
            if tailInfo.sizeBytes > 0 { payload += "\n" }
            payload += "## \(today)\n\n"
        }

        payload += formatEntry(text: text, at: date)   // "- HH:mm text\n" + 2-space-indented continuations

        handle.seekToEndOfFile()
        handle.write(Data(payload.utf8))
    }

    // Reads only the last `windowBytes` of the file — never the whole file — to find
    // the last "## YYYY-MM-DD" line and check for a trailing newline (D-06/D-07).
    private static func readTail(of fileURL: URL, windowBytes: Int) throws
        -> (sizeBytes: UInt64, endsWithNewline: Bool, lastHeadingDate: String?) {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }
        let size = try handle.seekToEnd()
        guard size > 0 else { return (0, true, nil) }

        let offset = size > UInt64(windowBytes) ? size - UInt64(windowBytes) : 0
        try handle.seek(toOffset: offset)
        let tailData = handle.readDataToEndOfFile()
        // Drop a possibly-truncated leading multi-byte UTF-8 sequence rather than
        // force-decoding raw bytes that may not start on a character boundary.
        let tailString = String(decoding: tailData, as: UTF8.self)

        let endsWithNewline = tailData.last == 0x0A
        let lines = tailString.split(separator: "\n", omittingEmptySubsequences: false)
        let lastHeadingLine = lines.last { $0.hasPrefix("## ") }
        let lastHeadingDate = lastHeadingLine.map { String($0.dropFirst(3)) }

        return (size, endsWithNewline, lastHeadingDate)
    }
}
```

### Anti-Patterns to Avoid

- **Read-modify-write-whole-file for the day-heading check:** Reading the ENTIRE vault file into memory to search for the last heading defeats the purpose of an append-only design and risks touching/rewriting bytes on save — always tail-read a bounded window (D-07's explicit constraint).
- **A single generic "activity file writer" shared with unrelated features:** Quick Notes' vault writer is uniquely scoped to one fixed file with one specific format (D-05) — do not generalize it into a reusable "any external file append" utility the way `FileWatcher` is shared between Download-Progress/Coding-Progress (per `research/FEATURES.md`); those two share a **read/watch** primitive, this phase has a **write** primitive with domain-specific formatting logic that doesn't generalize.
- **Trusting `NSMenu`'s `keyEquivalent`/`menuNeedsUpdate` submenu-row pattern for the input field:** That's exactly the mechanism D-01 rejected; do not fall back to it "for consistency with Clipboard History" — the whole reason this phase's capture surface differs from Clipboard History's is the text-input requirement.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Recent-notes list reducer (append/cap/evict) | A new bespoke store type from scratch | Copy `ClipboardStore`'s exact shape (pure struct, `cap = 30`, FIFO `removeFirst()`) minus the D-02 dedupe branch | Already written, already tested, already the established project convention — divergence risk is near-zero when copying a working pattern verbatim |
| Local JSON persistence with load-never-throws discipline | A new persistence layer | Copy `ClipboardFileStore`'s `load`/`save` shape, strip `CryptoKit`/Keychain calls | D-18 explicitly calls for this; the "corrupted input → `[]`, never throw" discipline is exactly what a beginner-owned codebase needs reused, not reinvented |
| Menu-bar status item + click routing | A new status-item wiring pattern | Reuse the existing `statusItem`/`menu` already owned by `AppDelegate` — just add one more `NSMenuItem` | One `NSStatusItem` per app is standard; a second status item (like the `#if DEBUG` one) is reserved for genuinely separate concerns, not warranted here |
| Settings toggle + card | A new Settings UI paradigm | Reuse Phase 59's `ActivityCardData`/`ActivityCard`/`categorySection` — the `quickNotes` card **already exists** in `productivityCards` (`SettingsView.swift:242-245`) with `onOptionsTap: nil`; this phase's only Settings work is wiring `onOptionsTap` to the `NSOpenPanel` folder picker + a current-path display, mirroring Focus/OSD/Caps-Lock's existing `onOptionsTap: { showXPermissionExplanation = true }` popover pattern | The card registration is DONE (Phase 59 shipped it) — this phase does not need to touch `productivityCards`' array shape, only wire the already-present `onOptionsTap` closure |

**Key insight:** This phase's only genuinely novel code is the vault writer (`QuickNotesVaultWriter`) and the popover shell (`NSPopover` + hosted SwiftUI). Every other piece — the reducer, the local persistence, the Settings card, the status-item menu — has a direct, working, already-shipped precedent in this exact codebase. Resist rewriting any of those from scratch; a near-identical copy with the documented deltas (no dedupe, no crypto, `onOptionsTap` wired) is the correct amount of code.

## Common Pitfalls

### Pitfall 10 (NEW — not in `research/PITFALLS.md`): NSPopover shown from a status item does not reliably hand keyboard focus to an embedded text view

**What goes wrong:** D-01's entire rationale is "a popover gets real keyboard focus with no hack" — but `NSPopover`'s interaction with a **status-item-anchored** window (as opposed to a popover anchored inside a normal app window) is a documented AppKit rough edge: the popover's backing window can fail to become key, or become key without properly routing first-responder status into a SwiftUI-hosted `TextEditor`, leaving the user able to SEE the input field but not type into it without an extra click.

**Why it happens:** `NSStatusBarWindow` (the invisible window backing the status item) and the popover's own window have an unusual parent/owner relationship compared to a popover shown from a normal window's toolbar/view — multiple independent sources (Stack Overflow threads, a dedicated blog post on exactly this combination) document needing an explicit `makeFirstResponder` call, sometimes deferred to the next run-loop tick, to reliably get keyboard focus flowing.

**How to avoid:**
- Explicitly call `window?.makeFirstResponder(...)` on the popover's content view/text view immediately after `show(relativeTo:of:preferredEdge:)`, dispatched via `DispatchQueue.main.async` if a same-tick call proves unreliable on-device (per Pattern 1's code example).
- Treat this as a genuine open question requiring an on-device spike BEFORE the UI-SPEC is finalized, not an assumption baked into task acceptance criteria — if focus genuinely never lands reliably, the fallback is `popover.behavior = .applicationDefined` with manual key-window management, a materially bigger change worth knowing about early.
- Test specifically: open the popover, do NOT click inside it, start typing immediately — confirm characters land in the `TextEditor`. This is the literal failure mode reported in the wild.

**Warning signs:** A popover that visually shows the text field but requires an extra click before typing works. Cmd+Return firing but the typed text being empty because keystrokes never reached the `TextEditor` at all.

**Phase to address:** Phase 64, ideally as an early Wave 1 spike task before the rest of the popover UI is built out, mirroring this project's own established "spike risky AppKit mechanics before building the full feature" discipline (Focus Mode, Volume/Brightness OSD suppression).

---

### Pitfall 11 (NEW — refines `research/PITFALLS.md` Pitfall 7 with a Foundation-API-level nuance): `FileHandle.seekToEndOfFile()` + `write(_:)` is NOT the same OS-level atomic guarantee as `O_APPEND`

**What goes wrong:** D-07 locks `FileHandle.seekToEndOfFile()` + `write(_:)` as the append mechanism, and this is the right call for Islet's single-process, single-writer use case — but it's worth the planner knowing precisely WHY it's safe here and not silently assuming it's atomic in the POSIX sense. `seekToEndOfFile()` and `write(_:)` are two separate syscalls; a POSIX file opened with `O_APPEND` gets the kernel's own atomic "seek-to-current-end-and-write" guarantee even under concurrent writers, whereas `FileHandle`'s two-step sequence has a — here, purely theoretical, single-process — window between the seek and the write.

**Why it happens:** `FileHandle` intentionally exposes a simpler, higher-level API than raw POSIX `open()` flags; most Swift developers (and most WebSearch-able tutorials) treat "seek to end, then write" as equivalent to true atomic append without the OS-level distinction being called out.

**How to avoid:**
- No code change required — `research/PITFALLS.md`'s own Technical Debt Patterns table already accepts this exact risk as fine ("Quick Notes append uses simple FileHandle seek-to-end without a lock/mutex against concurrent Islet-internal writes... Acceptable — Islet is single-process and the UI can only realistically originate one capture at a time").
- Document this explicitly as a known, accepted limitation in the phase's plan (not left implicit) so a future contributor doesn't "fix" it into unnecessary complexity, and so nobody assumes this pattern is safe if a second writer (e.g. a future background hook, mirroring Coding-Progress's file-writer) is ever added to the SAME file.
- If a future phase ever adds a second writer to this specific file, that is the trigger to revisit this pitfall and switch to POSIX `O_APPEND` or an explicit lock — not before.

**Warning signs:** Any future PR that adds a second code path writing to the same vault file without re-examining this note.

**Phase to address:** Phase 64 (documentation only, no code change needed); re-examine only if a second writer to the same file is ever proposed.

---

### Pitfall 7 (inherited from `research/PITFALLS.md`, re-verified against the live, still-non-sandboxed codebase): non-atomic append / corrupted vault file / silently-failed write

Re-confirmed still applicable and unchanged: `ENABLE_APP_SANDBOX = NO` verified live at `project.pbxproj:895,1057` (not stale). The three concrete risks — (1) read-modify-write corruption, (2) revoked/moved-folder silent failure, (3) Obsidian's own file-watcher reacting oddly to writes while the note is open in Obsidian's editor — are all still live risks for this phase and are the direct source of D-07/D-09/D-11/D-12. See `.planning/research/PITFALLS.md` lines 142-157 for the full writeup; not reproduced here in full to avoid drift between two copies of the same guidance — the planner should treat that file as the canonical source and this RESEARCH.md as the phase-specific application of it (Pitfalls 10/11 above are the genuinely NEW additions this phase's own research surfaced).

## Code Examples

### 1. "New Note…" menu item wiring (extends the existing `AppDelegate.swift:109-123` pattern)

```swift
// Source: this codebase's own live AppDelegate.swift pattern (verified 2026-07-25), extended
// per D-01 — HIGH confidence, direct code read, not inferred
menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
menu.addItem(withTitle: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "")
menu.addItem(withTitle: "New Note…", action: #selector(openQuickNotesPopover), keyEquivalent: "")
menu.addItem(.separator())
menu.addItem(withTitle: "Quit Islet", action: #selector(quit), keyEquivalent: "q")
```

### 2. NSOpenPanel folder picker for the vault path (D-08)

```swift
// Source: Apple's own NSOpenPanel API shape (developer.apple.com/documentation/appkit/nsopenpanel) —
// HIGH confidence, standard/stable API, no version-specific behavior; directory-mode configuration
// is the well-known pattern for "pick a folder, not a file"
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

### 3. Path-validity check on popover open (D-11)

```swift
// Source: FileManager standard API — HIGH confidence
private func vaultPathIsValid() -> Bool {
    guard let path = UserDefaults.standard.string(forKey: "quickNotes.vaultFolderPath") else { return false }
    var isDirectory: ObjCBool = false
    return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| N/A — this is new-to-codebase infrastructure, not a migration off an older pattern | `NSPopover`+`FileHandle` as designed above | — | No prior Islet implementation to compare against; the "state of the art" for this phase is purely external (Obsidian ecosystem convention, verified in `research/FEATURES.md` §4: plain `.md` file append is the standard lightweight capture pattern real Obsidian tools use, vs. requiring the Local REST API community plugin — explicitly rejected as an anti-feature) |

**Deprecated/outdated:** Nothing to deprecate — greenfield subsystem within this codebase.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `NSPopover.show(relativeTo:of:preferredEdge:)` from a status-item button reliably becomes key window and can be made to route keyboard focus to an embedded SwiftUI `TextEditor` via `makeFirstResponder` | Pattern 1, Pitfall 10 | If focus genuinely never lands reliably, D-01's entire premise ("popover gets real keyboard focus with no hack") is false, and the phase needs a fallback focus strategy or a different capture-surface decision revisited with the user |
| A2 | `Button(...).keyboardShortcut(.return, modifiers: .command)` fires reliably even while a sibling `TextEditor` in the same view hierarchy holds first responder | Pattern 2 | If Cmd+Return is swallowed by the focused `TextEditor` instead of reaching the button, D-02's submit mechanism doesn't work as specified and needs an `NSEvent` local monitor fallback (mirroring `clipboardHotkeyMonitor`'s own precedent for exactly this class of problem) |
| A3 | A 4096-byte tail-read window is sufficient to always find the most recent `## YYYY-MM-DD` heading in realistic vault-file usage | Pattern 3 (`readTail`) | If a single day accumulates more than ~4KB of notes (dozens of long multi-line entries in one day), the tail window could miss the heading and incorrectly re-write a duplicate heading for the same day; low real-world likelihood for a "quick capture" feature but not verified against an actual large file on-device |
| A4 | The macOS TCC "would like to access files in your X folder" prompt fires on first WRITE (not first read/pick) for a non-sandboxed app, even after the folder was already selected via `NSOpenPanel` | User Constraints (D-09, carried from CONTEXT.md) | If the prompt instead fires at panel-selection time, or never fires at all for a non-sandboxed app with an already-approved Terminal/other-app grant (per one WebSearch finding: "if Terminal has Downloads access, every unsandboxed app does too"), the UX sequencing assumed in D-09/D-11 (check validity on popover-open, expect a prompt on first write) may need adjustment — this is genuinely a training-knowledge-plus-WebSearch claim, not independently confirmed via an official Apple TCC document in this research pass |

**If this table is empty:** N/A — 4 assumptions logged above, all flagged for on-device verification during Phase 64 rather than treated as settled fact.

## Open Questions

1. **Does `NSPopover.behavior = .transient` conflict with D-03's "stays open with cleared field" recommendation?**
   - What we know: `.transient` auto-closes the popover on an outside click/Escape, which is desirable baseline dismiss behavior and does NOT itself close the popover on the user's own Cmd+Return submit (that's app-code-driven, not automatic).
   - What's unclear: Whether SwiftUI's `TextEditor` losing/regaining focus mid-interaction could be misread by AppKit as an "outside interaction" and trigger an unwanted auto-dismiss — this class of false-dismiss is a known category of `NSPopover`+embedded-text-field bug per the same sources behind Pitfall 10.
   - Recommendation: Adopt D-03 = "stays open, field cleared, list updates" (this research's recommendation, see Summary) and treat any false-dismiss found during the Pitfall 10 on-device spike as a joint fix, not a separate investigation.

2. **Exact vault-write failure surfaces Islet should distinguish (D-12's "visual presentation... Claude's discretion" still needs an enumerated failure list).**
   - What we know: D-12 locks the RULE (failed writes never appear in the list); CONTEXT.md defers the exact failure UI.
   - What's unclear: Whether "folder no longer exists," "folder exists but is not writable (permission revoked)," and "disk full / other I/O error" need distinguishable messages, or one generic "couldn't save — check your vault folder in Settings" suffices for v1.10's scope.
   - Recommendation: One generic inline error state is sufficient for this milestone (matches the project's existing "silent degrade, don't over-specify permission-tier UX" convention used for Focus/Location) — do not build a failure-reason taxonomy unless UAT surfaces a real need for one.

## Environment Availability

Skipped — this phase has no external tool/service/runtime dependency beyond the Xcode toolchain the project already builds with. Notably, **Obsidian.app itself is not a runtime dependency**: the feature writes plain UTF-8 `.md` text to a user-chosen folder and works identically whether or not Obsidian is installed, running, or even exists on the machine — Obsidian is only what makes the output *useful*, never a precondition for the write to succeed (this is the direct implication of NOTES-02's "append works even while Obsidian.app is closed" success criterion, generalized one step further: Obsidian need not be installed at all).

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | XCTest, `IsletTests` target (`@testable import Islet`) |
| Config file | `Islet.xcodeproj` / `project.yml` (xcodegen-managed), no separate test config |
| Quick run command | `xcodebuild -project Islet.xcodeproj -scheme Islet build` (build-only — **do not** run `xcodebuild test` headlessly; it hangs in this repo due to a Bluetooth TCC-authorization wait in `BluetoothMonitor`, documented in `PROJECT.md` line 425 and reconfirmed at Phase 56/58/59) |
| Full suite command | Manual Cmd-U in Xcode (interactive session required) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| NOTES-01 | Popover opens from "New Note…" menu item, text is typeable, Cmd+Return submits | manual-only (on-device UAT — AppKit window-focus behavior is not headlessly observable) | N/A — checklist item in the phase's UAT plan; this is the Pitfall 10 spike itself | — |
| NOTES-01/03 | `QuickNotesStore.append`/`.remove` — cap=30 FIFO eviction, per-row delete never touches the vault file | unit | `xcodebuild build` (compiles) + manual Cmd-U: `QuickNotesStoreTests.swift`, mirrors `ClipboardStoreTests.swift`'s exact shape | ❌ Wave 0 — new file |
| NOTES-02 | `QuickNotesFormatter` produces D-05's EXACT string (day heading once per day, `- HH:mm text`, 2-space-indented continuation lines) | unit | `QuickNotesFormatterTests.swift` — pure function, no FileHandle/disk I/O needed for this half of the logic | ❌ Wave 0 — new file |
| NOTES-02 | `QuickNotesVaultWriter`'s tail-read correctly detects an existing today-heading vs. a stale one vs. an empty file vs. a file with no trailing newline (D-06/D-07) | unit | `QuickNotesVaultWriterTests.swift` — write fixture files to a `NSTemporaryDirectory()` URL, assert `readTail`/`append` output byte-for-byte against D-05's spec | ❌ Wave 0 — new file; this is the single highest-value test in the phase given Pitfall 7/11's data-loss stakes |
| NOTES-02 | A note whose write fails is never added to `QuickNotesStore` (D-12) | unit | Inject a deliberately-unwritable target path (e.g. a file URL inside a nonexistent directory) into the append flow, assert `QuickNotesStore.items` unchanged after a caught error | ❌ Wave 0 — new file |
| NOTES-02 | Interrupt-mid-write / existing vault content survives an app-level crash simulation | manual-only (on-device UAT, mirrors `research/PITFALLS.md`'s own "Looks Done But Isn't" checklist item for this exact pitfall) | N/A — checklist item: kill the app process mid-append in a debug build, confirm prior vault content intact | — |
| NOTES-02 | macOS TCC prompt on first write to a protected folder (Documents etc.) appears and, once granted, persists across relaunch | manual-only (on-device UAT — TCC prompts are not headlessly triggerable) | N/A — checklist item, also resolves Assumption A4 | — |
| NOTES-03 | Recent-notes list renders most-recent-first, plaintext, matches Clipboard History's visual list pattern | manual-only (SwiftUI render verification via on-device visual check, not a unit-testable behavior in this project's existing test-shape convention — matches how `SettingsView`'s card-render checks are handled, per Phase 59 precedent) | N/A — checklist item | — |

### Sampling Rate

- **Per task commit:** `xcodebuild -project Islet.xcodeproj -scheme Islet build` (build-only, matches the repo-wide headless-test-hang workaround)
- **Per wave merge:** Manual Cmd-U in Xcode for the full `IsletTests` suite (existing `ClipboardStoreTests`/`ClipboardFileStoreTests` as regression baseline, new `QuickNotes*Tests`)
- **Phase gate:** On-device UAT (popover-focus spike, Cmd+Return submit, TCC-prompt flow, mid-write-interrupt survival, Obsidian-open-during-write behavior) before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `IsletTests/QuickNotesStoreTests.swift` — covers NOTES-01/NOTES-03 (append/remove/cap/FIFO)
- [ ] `IsletTests/QuickNotesFileStoreTests.swift` — covers NOTES-03 (load-never-throws, plaintext round-trip; mirrors `ClipboardFileStoreTests.swift`'s shape minus encryption assertions)
- [ ] `IsletTests/QuickNotesFormatterTests.swift` — covers NOTES-02 (D-05's exact string format, including multi-line indentation)
- [ ] `IsletTests/QuickNotesVaultWriterTests.swift` — covers NOTES-02 (D-06/D-07 tail-read + append correctness against real temp-directory fixture files) — **highest-priority new test given the data-loss stakes Pitfall 7/11 describe**
- [ ] No new test framework/config needed — `IsletTests` target and XCTest already fully cover this phase's testing needs

## Security Domain

`security_enforcement` is absent from `.planning/config.json` (defaults to enabled). Unlike Phase 59 (zero new attack surface), this phase DOES introduce two genuinely new surfaces worth a real ASVS pass: free-form user text input, and a write to a user-chosen path outside the app's own sandbox/container.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | N/A — no auth surface, single local user |
| V3 Session Management | No | N/A |
| V4 Access Control | No | N/A — no multi-user/permission-tier concept in this feature |
| V5 Input Validation | Partial | Note text is free-form and intentionally unvalidated/unsanitized (it's meant to become literal Markdown in the user's own vault — that IS the feature); the one real validation surface is the FOLDER PATH, and it is never user-TYPED — it only ever comes from `NSOpenPanel`'s own return value (D-08), so there is no path-injection/traversal surface to defend against the way there would be if a user typed an arbitrary path string |
| V6 Cryptography | No (deliberately) | N/A — D-18/NOTES-03 explicitly locks plaintext, no `CryptoKit`, no Keychain; this is a documented, user-facing product decision (notes are destined for a plaintext vault file anyway), not an oversight |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Vault file corruption from a non-atomic write (own bug, not an external attacker) | Tampering (of the user's own valuable data, by Islet itself) | `FileHandle.seekToEndOfFile()` + `write(_:)`, never read-modify-write (D-07); tail-only reads (Pattern 3) |
| Silent write failure after folder access is revoked/moved | Repudiation-adjacent (the app "claims" a note was saved when it wasn't) | D-12's locked guard — failed writes never enter the recent-notes list; D-11's popover-open path check |
| A stored vault path later resolving to an unexpected location if the folder is deleted and a new unrelated folder is later created at the same path | Tampering (low severity — writes would land in a folder the user no longer intends, but the user themselves chose the original path) | Re-verify the stored path resolves to a directory on each popover-open (D-11), not just at initial pick time — matches `research/PITFALLS.md`'s own Security Mistakes table entry for this exact risk |

## Sources

### Primary (HIGH confidence)

- Direct code read: `Islet/AppDelegate.swift` (full relevant sections: status item setup, menu wiring, `menuNeedsUpdate`/`NSMenuDelegate`, `ClipboardRowView`/`ClipboardRowContainerView`, `applyMenuBarClickRouting`) — confirms exact integration points and the D-01 rationale's own evidence trail
- Direct code read: `Islet/Clipboard/ClipboardStore.swift`, `Islet/Clipboard/ClipboardFileStore.swift` — confirms the exact reuse-shape for `QuickNotesStore`/`QuickNotesFileStore`
- Direct code read: `Islet/Notch/ViewSwitcherState.swift` — confirms D-13's "untouched" claim against the live `SelectedView`/`orderedSlotIcons` code
- Direct code read: `Islet/ActivitySettings.swift` — confirms `quickNotesKey` already exists (Phase 59), defaults to `false` via `defaultsToFalseKeys`
- Direct code read: `Islet/SettingsView.swift` — confirms the `quickNotes` `ActivityCardData` card already exists in `productivityCards` (line 242-245) with `onOptionsTap: nil`, and the exact `onOptionsTap`-popover pattern used by Focus/OSD/Caps-Lock cards this phase should mirror
- `grep ENABLE_APP_SANDBOX Islet.xcodeproj/project.pbxproj` — confirms `NO` at both Debug/Release build configs (lines 895, 1057), re-verifying D-09's premise against the live project file, not just CONTEXT.md's citation
- `grep -rn NSPopover|NSOpenPanel|FileHandle Islet/` — confirms zero existing usage of any of these three APIs anywhere in the codebase, establishing this phase's genuinely-new-infrastructure status
- `.planning/ROADMAP.md` lines 1135-1148 — Phase 64's exact Goal/Success-Criteria wording
- `.planning/REQUIREMENTS.md` lines 102-104, 228-230 — NOTES-01/02/03 exact wording and traceability status
- `.planning/research/PITFALLS.md` Pitfall 7 (lines 142-157), Pitfall 6 (lines 118-136, category-(c) classification), Technical Debt Patterns table (lines 198-205), Security Mistakes table (lines 225-231) — direct source of D-07/D-09/D-11/D-12/D-13 and this research's Pitfall 11
- `.planning/research/FEATURES.md` §4 (lines 46-55) — Quick Notes' expected behavior, Obsidian ecosystem convention, anti-feature framing
- `.planning/phases/59-settings-redesign/59-RESEARCH.md` — exact Validation Architecture / Security Domain section format and the `xcodebuild test` headless-hang workaround convention this document reuses verbatim

### Secondary (MEDIUM confidence)

- [Using NSPopover with NSStatusItem — shaheengandhi.com](https://shaheengandhi.com/using-nspopover-with-nsstatusitem/) — corroborates the `show(relativeTo:of:preferredEdge:)` pattern and the known keyboard-focus friction (Pitfall 10)
- [NSPopover — Apple Developer Documentation](https://developer.apple.com/documentation/AppKit/NSPopover) — official API reference for `.behavior`, `show(relativeTo:of:preferredEdge:)`
- [How to add Keyboard Shortcuts in SwiftUI — sarunw.com](https://sarunw.com/posts/swiftui-keyboard-shortcuts/) and [Button.keyboardShortcut(.defaultAction) doesn't properly work on macOS Monterey — Apple Developer Forums](https://developer.apple.com/forums/thread/694107) — corroborate Pattern 2's `keyboardShortcut(.return, modifiers: .command)` approach and its known focus-routing edge cases (Assumption A2)
- [seekToEndOfFile() — Apple Developer Documentation](https://developer.apple.com/documentation/foundation/filehandle/1411311-seektoendoffile) — official reference confirming the two-call (`seek`+`write`) shape behind Pitfall 11
- [Every unsandboxed app has Full Disk Access if Terminal does — lapcatsoftware.com](https://lapcatsoftware.com/articles/FullDiskAccess.html) — corroborates (with caveats, hence Assumption A4) that non-sandboxed-app TCC behavior for protected folders can differ from the sandboxed-app norm most documentation assumes

### Tertiary (LOW confidence)

- General WebSearch synthesis on `FileHandle` append semantics (no single authoritative source found stating the `O_APPEND`-vs-two-call distinction explicitly for Swift's `FileHandle` — this research's own inference from the documented POSIX behavior, flagged as Assumption-adjacent even though not listed in the Assumptions Log since it changes no locked decision, only adds context)

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH — every API is first-party Apple SDK, already the project's established convention, no version ambiguity
- Architecture: MEDIUM-HIGH — the reuse patterns (`ClipboardStore`/`ClipboardFileStore`/Settings card) are HIGH confidence (direct code reads); the two genuinely new mechanisms (`NSPopover` focus behavior, `FileHandle` tail-read algorithm) are MEDIUM — real platform capability, but the exact on-device behavior needs the Pitfall 10 spike before being treated as settled
- Pitfalls: MEDIUM-HIGH — Pitfall 7 is HIGH (re-verified against live, unchanged codebase state); Pitfalls 10/11 are MEDIUM (WebSearch-corroborated across 2+ independent sources each, but neither is a Context7-indexed or single-canonical-doc claim)

**Research date:** 2026-07-25
**Valid until:** 30 days (stable Apple SDK APIs; the one fast-moving risk is a macOS TCC-policy change affecting Assumption A4, which is already flagged for on-device re-verification regardless of research age)
