# Phase 64: Quick Notes + Obsidian Export - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-25
**Phase:** 64-quick-notes-obsidian-export
**Areas discussed:** Capture surface, Note format in the `.md`, Vault target & failure state, Top-edge switcher conflict (SC#4), Recent-notes list

---

## Capture surface

### Where does the user type the note?

| Option | Description | Selected |
|--------|-------------|----------|
| Popover at the status item | Menu item `New Note…` closes the menu and opens a small popover under the menu-bar icon. Real keyboard focus, no `NSMenu` hack, multi-line possible. Costs one extra click and is new UI. | ✓ |
| TextField inside the submenu | First row of the Quick Notes submenu is a `TextField` in an `NSHostingView`. Literally "typed in the flyout", but needs a focus hack against `NSMenu`'s event tracking plus manual Enter/Escape handling. | |
| Global hotkey → popover | Same popover, additionally reachable via a system-wide hotkey without opening the menu. Fastest capture, but costs hotkey registration + conflict handling. | |

**User's choice:** Popover at the status item
**Notes:** Presented with the concrete precedent that Phase 58 already hit this class of problem — nested-submenu `keyEquivalents` never fire, which is why `clipboardHotkeyMonitor` exists.

### Multi-line or single-line, and what submits?

| Option | Description | Selected |
|--------|-------------|----------|
| Multi-line, Cmd+Enter submits | `TextEditor`, Enter = newline, Cmd+Enter = submit. Fits Obsidian usage; forces a multi-line answer in the `.md` format. | ✓ |
| Single-line, Enter submits | One `TextField`, one line. Fastest capture, no format ambiguity, but long thoughts don't fit. | |
| Multi-line, Enter submits | Field can show multiple lines but Enter still sends; Shift+Enter for a break. Compromise, but Shift+Enter isn't obvious to many users. | |

**User's choice:** Multi-line, Cmd+Enter submits

### What happens right after submit?

| Option | Description | Selected |
|--------|-------------|----------|
| Popover closes | Clearest "it's saved" signal; reopening needed to add another note. | |
| Stays open, field clears | Focus stays, the new note appears at the top of the recent list. Good for several notes in a row. | |
| You decide | Claude picks at UI-spec time. | ✓ |

**User's choice:** Claude's discretion

### Where does the recent-notes list live, now that typing moved to a popover?

| Option | Description | Selected |
|--------|-------------|----------|
| Both in the popover | Input on top, list below. One place for everything; menu keeps only a `Quick Notes…` item. Deviates from the Clipboard History shape. | |
| List in the menu submenu, input in the popover | Exact Clipboard History shape for the list (anchor + submenu rows, Cmd+0-9 possible) plus a `New Note…` item. Maximum code reuse, two separate places. | |
| You decide | Claude picks at UI-spec time. | ✓ |

**User's choice:** Claude's discretion
**Notes:** The later "no Cmd+0-9" decision removes the main advantage the submenu shape had here.

---

## Note format in the `.md`

### What does an appended entry look like?

| Option | Description | Selected |
|--------|-------------|----------|
| Bullet with time under a day heading | `## YYYY-MM-DD` once per day, then `- HH:mm text`, continuation lines indented. Compact, renders as a clean Obsidian list. Requires a "does today's heading exist?" check before appending. | ✓ |
| H2 heading per note | `## YYYY-MM-DD HH:mm` per note, body below. Pure append, never checks anything — simplest and safest write path. Makes the file visually longer and floods Obsidian's outline. | |
| Flat with bold timestamp + `---` | Bold timestamp, text, `---` separator. No outline clutter, still a pure append. | |

**User's choice:** Bullet with time under a day heading (selected from a rendered preview)
**Notes:** The preview the user selected is treated as the literal target output in CONTEXT.md D-05, not as an illustration.

### How does the app know whether today's day heading already exists?

| Option | Description | Selected |
|--------|-------------|----------|
| Read the file tail | Read the last few KB before each append and check whether the last `## YYYY-MM-DD` line is today. Stays correct even if the user edits the vault file by hand. Write remains append-only. | ✓ |
| Remember the last date in `UserDefaults` | No file access needed. Wrong as soon as the user edits/deletes the file or works from a second machine — heading then missing or duplicated. | |
| You decide | Claude picks during research/planning. | |

**User's choice:** Read the file tail
**Notes:** Flagged explicitly that Pitfall 7 forbids read-modify-**write**-whole-file, not reading — the write stays `seekToEndOfFile()`.

---

## Vault target & failure state

### What exactly does the user pick?

| Option | Description | Selected |
|--------|-------------|----------|
| Folder picker, fixed filename | `NSOpenPanel` in directory mode; the app creates `Islet Notes.md` inside. Fewest clicks, and file-created-if-missing is trivially correct. Can't name the file or target an existing note. | ✓ (Claude's call) |
| Folder picker + filename field | Folder via panel, filename as a Settings text field with a default. More control, one more field plus validation. | |
| File picker | `NSOpenPanel` in file mode, pick an existing `.md`. Most control, but an open panel cannot select a non-existent file — "create if missing" would need a second save panel. | |

**User's choice:** "Nimm du was du am besten findest" — delegated to Claude
**Notes:** Claude chose the folder picker with a fixed filename and stated the reason: SC#2 requires the file be created if missing, which a file-mode panel structurally cannot express. A rename field was noted as a cheap later addition.

### Where does the picker live?

| Option | Description | Selected |
|--------|-------------|----------|
| Settings grid card (Phase 59) | Card with on/off toggle plus "choose vault folder…". Consistent with every other v1.10 activity; popover points at Settings when unconfigured. | ✓ |
| Inline in the popover on first use | Popover itself shows a "choose vault folder…" button instead of the text field when no path is set. No Settings detour, but more popover states. | |
| You decide | Claude picks at UI-spec time. | |

**User's choice:** Settings grid card

### The vault folder is gone or unwritable — what does the user see?

| Option | Description | Selected |
|--------|-------------|----------|
| Error row in the popover, text stays | Red line in the popover; the typed note stays in the field and is NOT added to the recent list, so it can never look saved. No interrupting popup. | |
| Modal alert | `NSAlert` with a "choose folder…" button opening the panel directly. Unmistakable, but interrupts — and Phase 58 already has a modal alert in the same menu bar. | |
| You decide | Claude picks at UI-spec time. | ✓ |

**User's choice:** Claude's discretion for the *presentation*
**Notes:** Claude locked the underlying rule regardless: a note whose write failed must never appear in the recent list. That is a data-loss guard, not a style choice, and is recorded as D-12.

### When is the path checked?

| Option | Description | Selected |
|--------|-------------|----------|
| When the popover opens | Problem is visible before typing. Costs one cheap `FileManager` check per open. | ✓ |
| Only on the write attempt | Pitfall 7's minimal formulation. Less code, but the user composes a whole note before learning it has nowhere to go. | |

**User's choice:** When the popover opens

---

## Top-edge switcher conflict (SC#4)

### Does Quick Notes get a surface in the notch?

| Option | Description | Selected |
|--------|-------------|----------|
| No — menu bar only | No `SelectedView` case, no `IslandResolver` entry, 4-slot model untouched. Exactly what Pitfall 6 recommends for this feature category. Settings card still exists. | ✓ |
| Fixed 6th icon like Timer | Mirrors Phase 62's fixed non-assignable icon. Clicking it either duplicates the popover or demands a whole second in-notch input surface. | |
| Grow the slot model to 5 | Makes Quick Notes slot-assignable. Touches `orderedSlotIcons`, every `@AppStorage` slot key, the Settings dropdowns and existing-user migration — affecting all four existing tabs. | |

**User's choice:** No — menu bar only
**Notes:** This is the decision SC#4 requires to exist in writing before implementation plans are drafted. Recorded with full rationale and rejected alternatives as D-13.

---

## Recent-notes list

### What happens when a row is clicked?

| Option | Description | Selected |
|--------|-------------|----------|
| Copy to the pasteboard | 1:1 Clipboard History behavior; same mental model for both lists, barely any new code. | |
| Load back into the input field | Fills the popover field with the old text. Submitting would append a *second* entry — it cannot edit the old line, since the format is append-only. | |
| Nothing — pure display | The list only confirms the last notes landed. Least code; the click going nowhere is slightly inconsistent next to the clickable Clipboard list. | ✓ |

**User's choice:** Nothing — pure display

### Deletion and cap (multi-select)

| Option | Description | Selected |
|--------|-------------|----------|
| Cap 30 like Clipboard History | Same limit, same FIFO eviction. Evicted notes stay in the vault file forever. | ✓ |
| "Delete All" like Clipboard | A confirmed clear of the local list only, mirroring `confirmDeleteAllHistory`. | |
| Individual notes deletable | Per-row delete control on hover. New behavior Clipboard History does not have. | ✓ |

**User's choice:** Cap 30 + per-row deletion; "Delete All" deliberately not selected

### Cmd+0-9 quick recall like Clipboard History?

| Option | Description | Selected |
|--------|-------------|----------|
| No | The digits are already taken by Clipboard History in the same menu bar; two lists competing for ten keys would need modifier disambiguation. | ✓ |
| Yes, with a different modifier | e.g. Cmd+Shift+0-9. Needs the Phase 58 event monitor extended and adds another shortcut to remember. | |

**User's choice:** No

---

## Claude's Discretion

- Popover behavior after submit — close vs. stay open with a cleared field.
- Where the recent-notes list renders — inside the popover vs. `NSMenu` submenu.
- Exact fixed vault filename (suggested `Islet Notes.md`).
- Visual presentation of a write/path failure — inline error row vs. modal alert. The "never show a failed note as saved" rule is locked, not discretionary.
- Duplicate-note handling — mirror `ClipboardStore`'s move-to-newest dedupe, or simply append.
- Which vault-target picker shape to use — explicitly delegated by the user ("nimm du was du am besten findest"); Claude chose folder + fixed filename.

## Deferred Ideas

- Global hotkey for note capture — offered, not chosen; more scope than the success criteria require.
- User-editable vault filename in Settings.
- "Delete All" for the notes list — offered, not selected; per-row deletion covers it.
- Per-row deletion for Clipboard History (parity with what the notes list gets).
- Editing a note after it was written — structurally out of reach; the vault file is append-only.
