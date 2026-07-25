# Phase 64: Quick Notes + Obsidian Export - Context

**Gathered:** 2026-07-25
**Status:** Ready for planning

<domain>
## Phase Boundary

The user captures a typed note from a menu-bar surface and it is appended, timestamped, to ONE fixed `.md` file inside a user-chosen Obsidian vault folder — created if missing, never overwritten or corrupted, working with Obsidian.app closed. The same surface shows a local, unencrypted recent-notes list. This is a **menu-bar-only feature**: it has zero participation in `IslandResolver`, `SelectedView`, or the notch UI (see D-13).

**Requirements (locked via REQUIREMENTS.md, not re-discussed here):**
- **NOTES-01:** User can quickly capture a typed text note from a menu-bar flyout, mirroring the existing Clipboard History submenu.
- **NOTES-02:** Each captured note is appended, with a timestamp, to one fixed `.md` file inside a user-chosen Obsidian vault folder — file created if missing, never overwritten/corrupted, append works while Obsidian.app is closed.
- **NOTES-03:** A local, **unencrypted** recent-notes list is shown in the same flyout, most-recent-first. Plaintext is deliberate — the notes are destined for a plaintext vault file anyway, so no AES-GCM parity with Clipboard History is needed.

**Out of scope (locked in REQUIREMENTS.md / research):**
- Obsidian Local REST API plugin integration — plain file append is the standard lightweight pattern; requiring a community plugin raises the bar past what quick capture should need.
- Daily-note mode (append to `YYYY-MM-DD.md` instead of one fixed file), tag autocomplete from the vault, Markdown formatting shortcuts — explicitly outside this milestone's fixed-file scope.

</domain>

<decisions>
## Implementation Decisions

### Capture surface
- **D-01:** Typing happens in a **popover anchored to the menu-bar status item**, not inside the `NSMenu` submenu. A `New Note…` menu item closes the menu and opens the popover. Rationale (user-chosen after being shown the tradeoff): `NSMenu` runs its own event-tracking loop and does not route key events to embedded views — the project already hit this exact class of problem in Phase 58, where nested-submenu `keyEquivalents` never fired and had to be worked around with a local event monitor (`clipboardHotkeyMonitor`, `AppDelegate.swift:33-38`). A popover gets real keyboard focus with no hack. Accepted cost: one extra click, and the popover is new UI with no existing component to reuse.
- **D-02:** The input is **multi-line**. Enter inserts a newline; **Cmd+Enter submits**. User explicitly wanted room for more than one sentence, accepting that this forces a multi-line answer in the `.md` format (resolved in D-05).
- **D-03 (Claude's discretion):** Whether the popover closes on submit or stays open with a cleared field — decide at UI-spec time, consistent with the app's other popover/flyout behavior.
- **D-04 (Claude's discretion):** Whether the recent-notes list lives inside the same popover (input on top, list below, menu keeps only a single `Quick Notes…` item) or stays as an `NSMenu` anchor+submenu of `NSHostingView` rows next to a `New Note…` item. Both satisfy NOTES-03's "same flyout". Note that D-15 (no Cmd+0-9) removes the main reason the Clipboard-style submenu shape was needed.

### Note format in the `.md` file
- **D-05:** Entry format is a **day heading plus a bullet-with-time**, continuation lines indented under the bullet:
  ```markdown
  ## 2026-07-25

  - 14:32 Erste Notiz, kurz.
  - 14:47 Längere Notiz mit
    zweiter Zeile eingerückt.

  ## 2026-07-26

  - 09:12 Nächster Tag.
  ```
  `## YYYY-MM-DD` is written once per day (ISO date), each note is `- HH:mm <text>` (24-hour), and every line after the first of a multi-line note is indented two spaces so Obsidian renders it as part of the same list item. User selected this over an H2-per-note and a bold-timestamp-plus-`---` variant, both of which would have been pure appends with no existence check.
- **D-06:** To decide whether today's `## YYYY-MM-DD` heading already exists, the app **reads the tail of the file before appending** and checks whether the last `## YYYY-MM-DD` line is today's date. Chosen over remembering the last-written date in `UserDefaults`, which goes wrong the moment the user edits the vault file by hand, deletes it, or works from a second machine.
- **D-07 (constraint, not a preference):** Reading to make the D-06 decision is fine — the **write** must still be append-only (`FileHandle.seekToEndOfFile()` + `write(_:)`), never read-modify-write-whole-file. Per `.planning/research/PITFALLS.md` Pitfall 7, this file is a real, valuable, externally-edited Obsidian document; a truncating write destroys the user's own notes, not just Islet's data. The tail read must also handle a file that ends without a trailing newline (a hand-edited vault file often does).

### Vault target & failure state
- **D-08:** The user picks a **folder** via `NSOpenPanel` (directory mode); the filename is **fixed** (`Islet Notes.md`, exact name at Claude's discretion). **Claude's call** — the user delegated this one ("nimm du was du am besten findest"). Rationale: NOTES-02/SC#2 require the file be created if missing, and a file-mode open panel cannot select a non-existent file — it would force a second save-panel flow. Folder + fixed name is the shortest path that satisfies the criterion literally. A rename field in Settings is a trivial later addition, deliberately not built now.
- **D-09:** Islet is **not sandboxed** (`ENABLE_APP_SANDBOX = NO`, verified in `project.pbxproj`), so the chosen path is stored as a plain path — **no security-scoped bookmarks**. The macOS TCC prompt for protected folders (`~/Documents` etc.) still applies and must be expected on first write.
- **D-10:** The folder picker lives in the **Settings grid card** (Phase 59 `SETTINGS-04` pattern), alongside the feature's on/off toggle. Consistent with every other v1.10 activity. Per `SETTINGS-05` the toggle **defaults OFF**.
- **D-11:** Path validity is checked **when the popover opens**, not on first write. The user sees a broken vault path before typing, rather than after composing a whole note. Cost is one cheap `FileManager` check per open.
- **D-12 (locked rule — data-loss guard, NOT a style choice):** A note whose write **failed** must never appear in the recent-notes list. If it did, the user would see it there and believe it reached the vault. On failure the typed text stays in the input field and nothing is recorded as saved. The *visual presentation* of the failure (inline error row in the popover vs. modal `NSAlert`) is Claude's discretion — the guard itself is not.

### Top-edge switcher conflict (SC#4 — the explicitly required documented decision)
- **D-13:** **Quick Notes gets no notch surface at all.** No new `SelectedView` case, no `IslandResolver`/`IslandPresentation`/`ActiveTransient` entry, and the 4-slot top-edge switcher model is untouched. The feature lives entirely in the menu bar (status item → menu → popover), with a Settings card for its toggle and vault path.
  - **Why this resolves the conflict rather than dodging it:** `.planning/research/PITFALLS.md` Pitfall 6 classifies every new v1.10 feature into (a) a new `ActiveTransient` competing for the FIFO head, (b) a new ambient case parallel to `CalendarCountdown`/`NowPlaying`, or (c) a Settings/menu-only feature with **no resolver participation at all** — and names Quick Notes in category (c) explicitly, alongside Menübar-Overflow and the Quick Actions bar. Adding a case would grow `IslandResolver` for a feature that never needs arbitration.
  - **Alternatives considered and rejected:** a fixed 6th switcher icon mirroring Phase 62's Timer treatment (`ViewSwitcherState.swift:13-19` — Timer is a fixed 5th case deliberately excluded from the four configurable slots) would either duplicate the D-01 popover behind a second entry point or demand a second, in-notch input surface; growing the configurable slot model from 4 to 5 would touch `orderedSlotIcons`, every `@AppStorage` slot key, the four Settings dropdowns and existing-user migration — a change affecting all four existing tabs for one feature that does not need it.

### Recent-notes list
- **D-14:** Cap is **30 entries with FIFO eviction**, matching `ClipboardStore.cap` exactly. Eviction only affects the local list — the entry stays in the vault `.md` file forever.
- **D-15:** **No Cmd+0-9 quick recall** for notes. The digits are already taken by Clipboard History in the same menu bar; a second list competing for the same ten keys would need modifier disambiguation for no real gain.
- **D-16:** Clicking a row does **nothing** — the list is pure display, confirming the last notes landed. Explicitly not the Clipboard History behavior (which copies to the pasteboard) and not a load-back-into-the-field behavior (which would have appended a duplicate entry, since the format is append-only and old lines are never edited).
- **D-17:** Individual notes are **deletable from the list** (per-row control, e.g. on hover). This is new behavior that Clipboard History does not currently have. **No "Delete All" item** — the user was offered the Clipboard-style `confirmDeleteAllHistory` equivalent and did not select it; per-row deletion covers the need. Deleting only ever touches the local list, **never** the vault `.md` file.
- **D-18:** Local persistence mirrors `ClipboardFileStore`'s shape (JSON index under Application Support, load-failure returns `[]` rather than throwing) but is **plaintext — no `CryptoKit`, no Keychain key**, per NOTES-03. The store logic itself should mirror `ClipboardStore`'s pure-value-type discipline (no `FileManager`/AppKit in the reducer).

### Claude's Discretion
- Popover behavior after submit — close vs. stay open with cleared field (D-03).
- Where the recent-notes list renders — inside the popover vs. `NSMenu` submenu (D-04).
- Exact fixed filename for the vault file (D-08, suggested `Islet Notes.md`).
- Visual presentation of a write/path failure — inline error row vs. modal alert (D-12); the "never show a failed note as saved" rule itself is locked.
- Whether duplicate-note handling mirrors `ClipboardStore`'s move-to-newest dedupe or simply appends — no user preference stated; append is the simpler default for notes.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Research (mechanism + risk, done ahead of this milestone)
- `.planning/research/FEATURES.md` §4 (lines 46-55) — Quick Notes' expected behavior, table stakes, deferred differentiators, the "Obsidian Local REST API as hard dependency" anti-feature, and the note that no canonical Obsidian timestamp convention exists (which is what D-05 resolves).
- `.planning/research/PITFALLS.md` Pitfall 7 (lines 142-153) — non-atomic append / corrupted vault file / silently-failed write; the direct source of D-07, D-09, D-11 and D-12. **Read this before writing any file-append code.**
- `.planning/research/PITFALLS.md` Pitfall 6 (lines ~57-71) — the resolver-growth pitfall that classifies Quick Notes as a menu-only feature with no `IslandResolver` participation; the evidence behind D-13.
- `.planning/research/PITFALLS.md` Pitfall 5 (lines ~82-89) — new v1.10 `@AppStorage` keys default to `false`, explicit per-key declaration, no data-driven default inference, and the key-collision warning (`activity.<name>` convention). Applies to this phase's new toggle key.

### Prior phase precedent (patterns this phase copies)
- `.planning/phases/58-menu-wiring-ui-assembly/` — the Clipboard History production wiring whose flyout shape, persistence pattern and UAT-driven submenu revision this phase mirrors. The Phase 58 UAT finding that nested-submenu `keyEquivalents` never fire is the direct reason for D-01.
- `.planning/phases/62-timer-pomodoro/62-CONTEXT.md` — Phase 62's "fixed extra icon, not a configurable slot" treatment of Timer, the alternative D-13 rejected.

### Codebase (exact integration points, verified by reading the live files)
- `Islet/AppDelegate.swift:110-123` — the `NSMenu` construction and `statusItem.menu` wiring where a `New Note…` item is added.
- `Islet/AppDelegate.swift:414-472` — `menuNeedsUpdate` (`NSMenuDelegate`): identifier-prefix removal (`clip.`, never positional index math), the anchor + submenu of `NSHostingView` rows, the explicit-frame requirement on `NSMenuItem.view`, and the sibling `Delete All History` item. The exact template if D-04 lands on the submenu shape — and note the phase must use its own identifier prefix (e.g. `note.`) so the two dynamic sections cannot clobber each other.
- `Islet/AppDelegate.swift:32-38` — `clipboardHotkeyMonitor` and the comment explaining why nested submenu `keyEquivalents` never fire (evidence for D-01, and why D-15 avoids reopening this).
- `Islet/AppDelegate.swift:210-222` — `applyMenuBarClickRouting`: `statusItem.menu` and `button.action` are mutually exclusive, and the D-05 license-locked click state nils the menu. Any new menu entry point must survive this routing.
- `Islet/Clipboard/ClipboardStore.swift` — pure-value-type store with `cap = 30` and FIFO eviction; the shape for D-14 (dedupe behavior is the one place to deliberately diverge, per D-18/discretion).
- `Islet/Clipboard/ClipboardFileStore.swift` — persistence shape to mirror **minus** the `CryptoKit` sealing and the Keychain key (D-18); note its load-never-throws / returns-`[]` discipline.
- `Islet/Notch/ViewSwitcherState.swift:13-26` — the 5-case `SelectedView` and `orderedSlotIcons`' fixed 4 parameters; the code D-13 deliberately leaves untouched.
- `Islet/ActivitySettings.swift` — per-key `@AppStorage` declarations; the new Quick Notes toggle key follows the `activity.<name>` convention and defaults `false`.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `menuNeedsUpdate`'s dynamic-section pattern (identifier-prefix removal + rebuild, `NSHostingView` rows with explicit frames inside `NSMenuItem.view`) — directly reusable for the notes list if D-04 lands on the submenu shape.
- `ClipboardStore` — pure reducer with cap + FIFO eviction; a notes store is the same shape with the dedupe branch dropped.
- `ClipboardFileStore` — load/save discipline (never throws on load, corrupted input yields `[]`) reusable verbatim with the encryption layer removed.
- Phase 59's Settings-grid card pattern — the vault-folder picker and on/off toggle drop into it without new Settings chrome.

### Established Patterns
- New v1.10 activity toggles are individually declared `@AppStorage` keys defaulting to `false` — never a data-driven default table (Pitfall 5).
- Risk-isolated file I/O lives in one dedicated store type, kept out of the pure reducer (`ShelfFileStore`/`ShelfLogic`, `ClipboardFileStore`/`ClipboardStore`) — the vault-append code follows the same split.
- Menu-only features stay out of `IslandResolver` entirely (Pitfall 6 category (c)) — D-13 is this phase applying that rule.

### Integration Points
- `AppDelegate.menu` — a `New Note…` item, plus the notes list section if D-04 chooses the submenu shape (own identifier prefix, not `clip.`).
- New popover/panel controller owned by `AppDelegate` — the D-01 capture surface; must coexist with `applyMenuBarClickRouting`'s locked-click state.
- New vault-append store (`FileHandle.seekToEndOfFile()`, tail read for the day heading) — the only genuinely new subsystem in this phase.
- New local notes store + plaintext file store under Application Support.
- Settings grid — one new card: toggle (default OFF) + vault-folder picker + current-path display.
- `IslandResolver` / `ViewSwitcherState` — **deliberately untouched** (D-13).

</code_context>

<specifics>
## Specific Ideas

The user selected the `.md` entry format from a rendered preview rather than describing it, so D-05's code block is the literal target output — downstream agents should treat it as the spec, not an illustration.

No reference app or screenshot was supplied for the popover's visual design.

</specifics>

<deferred>
## Deferred Ideas

- **Global hotkey for note capture** — offered as a capture-surface option (popover reachable without opening the menu at all) and not chosen. Would need hotkey registration plus conflict handling; more scope than the success criteria require.
- **User-editable vault filename** — D-08 fixes the filename. A Settings text field with `.md`-extension validation is a small later addition.
- **"Delete All" for the notes list** — offered, not selected; per-row deletion (D-17) covers it.
- **Per-row delete for Clipboard History** — D-17 gives the notes list per-row deletion that Clipboard History does not have. Bringing Clipboard History to parity is a separate concern, not this phase.
- **Editing a note after it was written** — out of reach by construction: the vault file is append-only, so nothing in this phase can revise an already-written line.

### Reviewed Todos (not folded)
Three todos matched Phase 64 on the scoring heuristic; all three were reviewed and rejected as unrelated to Quick Notes:
- `2026-07-19-calendar-month-grid-polish.md` — calendar month-grid arrows/day-numbers/event-hover; unrelated UI area.
- `2026-07-19-quick-action-disabled-state-has-no-controller-gate.md` — matched on the word "quick"; belongs to Phase 65 (Quick Actions bar), not Quick Notes.
- `2026-07-19-island-briefly-disappears-during-click-through.md` — notch click-through behavior; this phase touches no notch surface at all (D-13).

</deferred>

---

*Phase: 64-Quick-Notes-Obsidian-Export*
*Context gathered: 2026-07-25*
