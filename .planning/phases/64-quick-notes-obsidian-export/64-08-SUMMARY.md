---
phase: 64-quick-notes-obsidian-export
plan: 08
subsystem: ui
tags: [swiftui, appkit, nspopover, filemanager, obsidian-vault, nsevent-global-monitor]

# Dependency graph
requires:
  - phase: 64-quick-notes-obsidian-export (Plan 06)
    provides: Fixed QuickNotesController/openQuickNotesPopover() shape (focus token, vaultConfigured guard); handoff note flagging vault-file-reconciliation as this plan's scope to confirm
  - phase: 64-quick-notes-obsidian-export (Plan 07)
    provides: QuickNote.fileName, QuickNotesVaultWriter.removeEntry/listMarkdownFiles, ActivitySettings.quickNotesDefaultFileName/quickNotesSelectedFileNameKey
provides:
  - Quick Notes popover file-picker (QuickNotesController.availableFiles/selectedFileName/onSelectFile) targeting any .md file in the vault folder, not just a fixed filename
  - Per-note vault-delete: removes the matching line from the note's OWN stored file (note.fileName), occurrence-ranked to disambiguate byte-identical duplicates, with a real failure guard (T-64-15)
  - Vault-to-local reconciliation on popover open: notes deleted directly in the vault file (outside the app) are pruned from the local recent-notes list too (additional scope, user-approved)
  - "New File…" inline name-prompt in the file picker, letting new vault files be created (lazily, on first note) directly from the popover (additional scope, user-approved)
  - Recent-notes list filtered to the currently selected file only, not all files' notes mixed together (additional scope, user-approved)
  - Reliable popover outside-click/app-switch auto-dismiss, closed in two rounds: an NSApplication.didResignActiveNotification observer (round 1, covers Cmd+Tab-style app switches) plus a global NSEvent mouse-down monitor (round 2, covers a direct click on an already-visible background app's window that didResignActiveNotification alone didn't reliably catch)
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Occurrence-by-append-order duplicate disambiguation: quickNotesStore.items is stored in the same order notes were appended to the vault file, so counting earlier same-fileName/same-formatted-entry items before a given note yields the correct physical line to target — reused identically for both single-note delete (handleQuickNoteDelete) and bulk vault reconciliation (reconcileQuickNotesWithVault)"
    - "AppDelegate as single source of truth for QuickNotesPopoverView's error copy: the view renders controller.errorMessage directly instead of a hardcoded string, since two distinct failure messages (save vs. delete) now exist"
    - "Inline plain-TextField name-prompt (not NSAlert/sheet) for a quick filename entry, matching this codebase's existing convention (e.g. NotchPillView's calendar quick-add TextField) — no NSAlert-based text-entry precedent exists anywhere in Islet"
    - "Single refreshQuickNotesList() helper as the ONLY call site that assigns quickNotesController.notes — a display projection (quickNotesStore.items filtered by selectedFileName, reversed), never the source of truth; every mutation site (initial load, submit, delete, reconciliation, file selection) routes through it instead of duplicating the filter"
    - "Two independent, complementary popover-dismiss mechanisms rather than one 'do everything' mechanism: NSApplication.didResignActiveNotification (fires on a genuine active-app switch, e.g. Cmd+Tab) and a global NSEvent mouse-down monitor (fires on any click landing in another app's window, including one already visible in the background) — a global monitor structurally never sees clicks inside this app's own hosted SwiftUI Menu (Apple's documented contract: it only receives events targeted at OTHER applications), so it cannot regress the Menu's own click handling"

key-files:
  created: []
  modified:
    - Islet/QuickNotes/QuickNotesPopoverView.swift
    - Islet/AppDelegate.swift
    - Islet/QuickNotes/QuickNotesStore.swift

key-decisions:
  - "Vault-file reconciliation (deferred from Plan 64-06, per its handoff note) is implemented in this plan as an additional task (Task 3), beyond 64-08-PLAN.md's own locked Task 1/2 scope — explicitly approved by the coordinator for this execution, not a silent scope addition"
  - "QuickNotesStore gains prune(keepingIDs:) rather than exposing items for direct external mutation — mirrors remove(id:)'s existing shape for a bulk case"
  - "reconcileQuickNotesWithVault runs BEFORE the file-listing/selection-restore logic in openQuickNotesPopover(), so a pruned note's fileName can never end up stale in the availableFiles computation"
  - "\"New File…\" does NOT create the file on disk directly — it only adds the typed name to availableFiles and selects it; the existing submit path (QuickNotesVaultWriter.append) already lazily creates a nonexistent file on its first write, so no new file-creation code path was needed"
  - "Outside-click/app-switch dismiss regression fixed in two rounds. Round 1 (checkpoint feedback during this plan's original execution): an explicit NSApplication.didResignActiveNotification observer, deliberately not a custom NSEvent mouse-down monitor at the time, to avoid risking a regression in the just-built file-picker Menu's own tracking session. Round 2 (this session, reported after round-1 approval): on-device testing found didResignActiveNotification doesn't reliably fire for a direct click on an ALREADY-VISIBLE background app's window (only confirmed reliable for Cmd+Tab-style switches) — closed the gap with a global NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) monitor. This is safe against the original Menu-regression concern because a global monitor's documented Apple contract is that it only ever receives events landing in ANOTHER application's windows — a click inside this app's own Menu is a same-app event and structurally never reaches it."

requirements-completed: [NOTES-01, NOTES-02]

# Metrics
duration: ~60min (incl. 3 rounds of on-device checkpoint re-verification, the last for the dismiss-bug root-cause fix)
completed: 2026-07-25
---

# Phase 64 Plan 08: Quick Notes Vault File-Picker, Vault-Delete & Reconciliation Summary

**Popover file-picker (with inline "New File…" creation and per-file note filtering) targeting any .md file in the vault folder, per-note vault-delete with occurrence-ranked duplicate disambiguation and a genuine failure guard, two-way vault/local-list reconciliation, and a two-round fix for the popover's outside-click/app-switch auto-dismiss (a documented SwiftUI-Menu-vs-NSPopover.transient interop gap) — all additional scope beyond the plan's own two tasks folded in before final on-device approval.**

## Performance

- **Duration:** ~60 min automated work across 3 rounds of on-device checkpoint feedback
- **Completed:** 2026-07-25
- **Tasks:** 7 automated tasks (2 from the locked plan + 5 additional-scope tasks/fixes) + 1 consolidated checkpoint, approved
- **Files modified:** 3 (`QuickNotesPopoverView.swift`, `AppDelegate.swift`, `QuickNotesStore.swift`)

## Accomplishments

- The Quick Notes popover now shows a `Menu`-based file picker above the `TextEditor`, listing every real `.md` file in the chosen vault folder (plus the fixed default filename even if it doesn't exist yet) — disabled when the vault isn't configured, matching the existing TextEditor/Save-button guard.
- The error banner renders `controller.errorMessage` directly instead of a hardcoded save-specific string, since a second distinct failure message (delete) now exists — `AppDelegate` is the single source of truth for both exact copy strings.
- `openQuickNotesPopover()` lists real vault files on every open (never cached) and self-heals the persisted file selection back to the default if the previously selected file was renamed/deleted.
- New notes are targeted at and stamped with whichever file is currently selected (`quickNotesController.selectedFileName`), reversing the original fixed-filename design (D-08 reversal, as scoped).
- Per-row delete now removes the matching line from the note's OWN stored vault file (`note.fileName`, not necessarily the currently selected file), with an occurrence rank computed from `quickNotesStore.items`' append order so a byte-identical duplicate entry is never deleted at the wrong physical line. A genuine I/O failure during vault removal surfaces a new error banner ("Couldn't delete from vault — check your vault folder in Settings.") and leaves the note in the local list untouched — mirroring D-12's existing save-failure data-loss guard.
- **Additional scope 1 (user-approved):** `reconcileQuickNotesWithVault`, called on every popover open, re-reads each distinct vault file referenced by the local notes and prunes any note whose formatted entry is no longer present in its own file's content — so a note deleted directly in the vault (Obsidian, a text editor, Finder trash, etc.) also disappears from Islet's recent-notes list. A vault file that can't be read at all is treated as "unknown," never "deleted," avoiding a false-positive data-loss scenario.
- **Additional scope 2 (user-approved):** the file-picker `Menu` gains a "New File…" item. Picking it reveals an inline `TextField`-based name prompt (Add/Cancel); the typed name is trimmed and given a `.md` suffix if missing, then added to `availableFiles` and selected — the file itself is created lazily on the first submitted note via the existing append path, no new file-creation code was needed.
- **Additional scope 3 (user-approved bug fix):** the recent-notes list was showing every note across every vault file, ignoring the file picker's current selection. Fixed via a single `refreshQuickNotesList()` helper — the sole place `quickNotesController.notes` is assigned — filtering `quickNotesStore.items` down to `note.fileName == selectedFileName`.
- **Additional scope 4/5 (user-approved bug fix, two rounds):** clicking another application while the popover was open stopped auto-dismissing it once the file-picker `Menu` was added (a documented SwiftUI-Menu-vs-`NSPopover.behavior = .transient` interop gap). Round 1 fixed the Cmd+Tab-style app-switch case via an `NSApplication.didResignActiveNotification` observer. Round 2 (this session) found on-device that clicking directly on an ALREADY-VISIBLE background app's window didn't reliably fire that same notification — closed via a global `NSEvent` mouse-down monitor (`.leftMouseDown`/`.rightMouseDown`/`.otherMouseDown`) that closes the popover on any click landing in another application's window. The global monitor is safe against regressing the Menu: Apple's own documented contract is that a global monitor only ever receives events targeted at OTHER applications, so a click inside this app's own hosted Menu is structurally invisible to it.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add file-picker UI and new error-copy binding to QuickNotesPopoverView** - `36084bf` (feat)
2. **Task 2: Wire file listing, per-file submit targeting, and vault-delete with failure guard in AppDelegate** - `c0891d9` (feat)
3. **Task 3 (additional scope, user-approved): Reconcile local Quick Notes list against vault file on popover open** - `44c3ad3` (feat)
4. **Task 4 (additional scope, user-approved): Add "New File…" option to the Quick Notes file picker** - `c16add9` (feat)
5. **Task 5 (additional scope, user-approved bug fix, round 1): Restore outside-click/app-switch auto-dismiss on the popover via didResignActiveNotification** - `8a65d74` (fix)
6. **Task 6 (additional scope, user-approved bug fix): Filter the recent-notes list by the currently selected file** - `39848d4` (fix)
7. **Task 7 (additional scope, user-approved bug fix, round 2): Reliably dismiss popover when any background window is clicked, via a global NSEvent mouse-down monitor** - `7abdb7f` (fix)

## Files Created/Modified

- `Islet/QuickNotes/QuickNotesPopoverView.swift` - `QuickNotesController` gains `availableFiles`/`selectedFileName`/`onSelectFile`/`onCreateFile`; a `Menu`-based file picker (with a "New File…" item + inline name TextField) rendered above the `TextEditor`; error banner now renders `controller.errorMessage` directly
- `Islet/AppDelegate.swift` - `openQuickNotesPopover()` reconciles the local list against the vault, lists real `.md` files, and self-heals the persisted selection; `applicationDidFinishLaunching` wires `onSelectFile`/`onCreateFile`, registers the `didResignActiveNotification` deactivation observer AND a global mouse-down monitor (`quickNotesOutsideClickMonitor`) for the popover-dismiss fix; `handleQuickNoteSubmit` targets/stamps the selected file; `handleQuickNoteDelete` computes an occurrence rank and removes the matching vault line with a failure guard; new `reconcileQuickNotesWithVault(vaultFolderPath:)` prunes notes deleted directly in the vault; new `refreshQuickNotesList()` is the sole place `quickNotesController.notes` is assigned, filtering by `selectedFileName`
- `Islet/QuickNotes/QuickNotesStore.swift` - new `prune(keepingIDs:)` bulk-delete method, mirroring the existing `remove(id:)`'s shape

## Decisions Made

See `key-decisions` in frontmatter above — summarized:
- Vault-file reconciliation, deferred from Plan 64-06 per its own handoff note, is built here as an additional Task 3, explicitly approved for this execution rather than silently added.
- `QuickNotesStore.prune(keepingIDs:)` added instead of exposing `items` for direct external mutation, keeping the store's existing encapsulation.
- Reconciliation runs before file-listing/selection-restore in `openQuickNotesPopover()` so a pruned note can never leave a stale `fileName` reference in the computed `availableFiles`.
- "New File…" reuses the existing lazy-create-on-first-write behavior of `QuickNotesVaultWriter.append` instead of adding a new file-creation code path.
- The recent-notes list is a display-only filter (`quickNotesStore.items.filter { $0.fileName == selectedFileName }`) computed fresh by one shared helper; delete (id-based, reads `note.fileName`) and reconciliation (iterates all notes/files) both read from the full, unfiltered `quickNotesStore.items` and were unaffected beyond routing their final list-refresh through the same helper.
- The outside-click-dismiss fix ended up needing TWO complementary mechanisms rather than one: `didResignActiveNotification` for genuine app-switch transitions (Cmd+Tab), plus a global `NSEvent` mouse-down monitor for a direct click on an already-visible background window that the notification-based approach alone didn't reliably catch. Kept both rather than replacing round 1 with round 2, since each covers a distinct real-world trigger path confirmed on-device.

## Deviations from Plan

### Additional Scope (user-approved, not deviations from the locked plan itself)

**1. Vault-to-local reconciliation on popover open**
- **Requested by:** the coordinator, citing 64-06-SUMMARY.md's explicit handoff note and on-device UAT feedback during Plan 64-06.
- **What was built:** `AppDelegate.reconcileQuickNotesWithVault(vaultFolderPath:)`, called from `openQuickNotesPopover()` before the file-listing logic, plus `QuickNotesStore.prune(keepingIDs:)`.
- **Files modified:** `Islet/AppDelegate.swift`, `Islet/QuickNotes/QuickNotesStore.swift`
- **Verification:** build green, all existing unit tests pass; on-device checkpoint (round 1) confirmed.
- **Committed in:** `44c3ad3`

**2. "New File…" option in the file picker**
- **Requested by:** the coordinator, during checkpoint review, before on-device verification of the plan's original tasks.
- **What was built:** a `Divider` + "New File…" `Button` inside the existing `Menu`; an inline `TextField`-based name prompt (Add/Cancel); `QuickNotesController.onCreateFile` wired in `AppDelegate` to add the typed (and `.md`-suffixed) name to `availableFiles` and select it.
- **Files modified:** `Islet/QuickNotes/QuickNotesPopoverView.swift`, `Islet/AppDelegate.swift`
- **Verification:** build green; on-device checkpoint (round 1) confirmed.
- **Committed in:** `c16add9`

**3. Outside-click/app-switch auto-dismiss regression fix — round 1**
- **Requested by:** the coordinator, during checkpoint review — a real regression caused by this plan's own Task 1 (the file-picker `Menu`).
- **What was built:** `quickNotesPopoverDeactivationObserver`, an `NSApplication.didResignActiveNotification` observer registered in `applicationDidFinishLaunching` that explicitly closes `quickNotesPopover` when the app deactivates.
- **Files modified:** `Islet/AppDelegate.swift`
- **Verification:** build green; on-device checkpoint (round 1) confirmed Cmd+Tab-style app-switch dismissal restored.
- **Committed in:** `8a65d74`

**4. Recent-notes list not filtered by the selected file**
- **Requested by:** the coordinator, during on-device checkpoint testing — a real functional bug found while verifying the file-picker.
- **What was built:** `AppDelegate.refreshQuickNotesList()`, the sole call site now assigning `quickNotesController.notes`, filtering `quickNotesStore.items` by `fileName == selectedFileName` before reversing.
- **Files modified:** `Islet/AppDelegate.swift`
- **Verification:** build green, all existing unit tests pass; on-device checkpoint (round 1) confirmed.
- **Committed in:** `39848d4`

**5. Outside-click/app-switch auto-dismiss regression fix — round 2 (root cause)**
- **Requested by:** the user, in a follow-up session after round 1's checkpoint was otherwise approved — round 1's fix (`didResignActiveNotification`) turned out to only reliably cover a genuine active-app-switch transition (confirmed working for Cmd+Tab), not a direct click on an already-visible background app's window (the popover stayed open in that specific case, and it has no other way to close).
- **What was built:** `quickNotesOutsideClickMonitor`, a global `NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown])` monitor registered alongside the round-1 observer, closing the popover on any click landing in another application's window. Kept as a genuine root-cause fix rather than a symptom patch: it directly implements NSPopover's own broken "close on outside click" semantics (broken by the hosted SwiftUI `Menu`, a documented AppKit/SwiftUI interop gap) rather than trying to special-case background-window clicks. Regression-safe by construction — a global monitor's documented Apple contract is that it only ever receives events targeted at OTHER applications, so it structurally cannot see (and cannot break) a click inside this app's own Menu.
- **Files modified:** `Islet/AppDelegate.swift`
- **Verification:** build green; on-device checkpoint (round 2, this session) confirmed all 3 focused checks — background-window click closes the popover, the file-picker Menu still works normally (no premature close), and Cmd+Tab dismissal still works.
- **Committed in:** `7abdb7f`

---

**Total deviations:** 0 conventional Rule 1-3 auto-fixes during the plan's own two tasks; 3 genuine Rule-1 bug fixes (items 3-5 above, all found via on-device checkpoint review across two sessions) and 2 explicitly-approved additional-scope tasks (items 1-2 above).
**Impact on plan:** No unrequested scope creep — every addition was directed by the coordinator/user with an explicit rationale and is fully documented here. The dismiss-bug fix required two rounds because the first round's fix, while reasonable and itself on-device-confirmed for its own test case (Cmd+Tab), didn't cover every real-world trigger of the underlying symptom — exactly what an on-device checkpoint gate is designed to catch.

## Issues Encountered

None of the 7 tasks failed to build or broke an existing test. All existing Quick Notes unit tests (`QuickNotesStoreTests`, `QuickNotesFormatterTests`, `QuickNotesVaultWriterTests`, `QuickNotesFileStoreTests`) continue to pass unchanged after every task. The outside-click-dismiss bug needed two on-device rounds to fully close: round 1's `didResignActiveNotification`-based fix was a reasonable hypothesis that held up for its own tested case (Cmd+Tab) but didn't generalize to every "click into any other window" path, which only surfaced via a fresh on-device report after round 1 was otherwise approved. Like the rest of this popover's focus/dismiss behavior (see Plan 64-06's own multi-round on-device UAT history), this class of AppKit-window-interaction bug needed real on-device confirmation rather than being catchable by the build or unit-test suite. This app-focus/dismiss behavior has no unit-test coverage by established project convention (per 64-RESEARCH.md's NOTES-03 test-shape note) — it's SwiftUI/AppKit-render-facing state, verified on-device instead.

## User Setup Required

None - no external service configuration required.

## Known Stubs

None found — scanned all three modified files for hardcoded empty values, placeholder text, and unwired data sources; none present. The file picker's `availableFiles`/`selectedFileName` are real, live-computed values, not stubs. "New File…" doesn't stub file creation — it correctly relies on the existing lazy-create-on-first-write behavior already present in `QuickNotesVaultWriter.append`.

## Checkpoint Status: APPROVED

The plan's `checkpoint:human-verify` task (gate="blocking") was run across 3 rounds and fully approved. Round 1/2 covered the plan's original 6-step checklist plus vault-reconciliation, "New File…" creation, the initial outside-click/app-switch dismiss fix, and per-file list filtering. Round 3 (this session) covered 3 focused re-checks after the dismiss-bug root-cause fix: (1) clicking directly on an already-visible background app's window now closes the popover, (2) the file-picker Menu still works normally with no premature close, (3) Cmd+Tab dismissal still works. User confirmed: "approved — all 3 checks pass."

## Next Phase Readiness

- Phase 64 (Quick Notes + Obsidian Export) is now fully shipped: NOTES-01, NOTES-02, NOTES-03 all complete (see `REQUIREMENTS.md`).
- No known open issues or deferred items for this feature.

---
*Phase: 64-quick-notes-obsidian-export*
*Completed: 2026-07-25*

## Self-Check: PASSED

All modified files exist (`Islet/QuickNotes/QuickNotesPopoverView.swift`, `Islet/AppDelegate.swift`, `Islet/QuickNotes/QuickNotesStore.swift`, this SUMMARY.md); all 7 referenced commit hashes (`36084bf`, `c0891d9`, `44c3ad3`, `c16add9`, `8a65d74`, `39848d4`, `7abdb7f`) confirmed present in git history.
