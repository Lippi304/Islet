---
phase: 64-quick-notes-obsidian-export
plan: 08
subsystem: ui
tags: [swiftui, appkit, nspopover, filemanager, obsidian-vault]

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
  - Fix for a Menu-caused regression in the popover's outside-click/app-switch auto-dismiss (additional scope, user-approved)
  - Recent-notes list filtered to the currently selected file only, not all files' notes mixed together (additional scope, user-approved)
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Occurrence-by-append-order duplicate disambiguation: quickNotesStore.items is stored in the same order notes were appended to the vault file, so counting earlier same-fileName/same-formatted-entry items before a given note yields the correct physical line to target — reused identically for both single-note delete (handleQuickNoteDelete) and bulk vault reconciliation (reconcileQuickNotesWithVault)"
    - "AppDelegate as single source of truth for QuickNotesPopoverView's error copy: the view renders controller.errorMessage directly instead of a hardcoded string, since two distinct failure messages (save vs. delete) now exist"
    - "Inline plain-TextField name-prompt (not NSAlert/sheet) for a quick filename entry, matching this codebase's existing convention (e.g. NotchPillView's calendar quick-add TextField) — no NSAlert-based text-entry precedent exists anywhere in Islet"
    - "NSApplication.didResignActiveNotification observer as an explicit supplement to NSPopover.behavior = .transient, restoring app-switch auto-dismiss that a hosted SwiftUI Menu silently breaks — a documented AppKit/SwiftUI interop gap, not something fixable by changing .transient itself"
    - "Single refreshQuickNotesList() helper as the ONLY call site that assigns quickNotesController.notes — a display projection (quickNotesStore.items filtered by selectedFileName, reversed), never the source of truth; every mutation site (initial load, submit, delete, reconciliation, file selection) routes through it instead of duplicating the filter"

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
  - "Outside-click/app-switch dismiss regression fixed via an explicit NSApplication.didResignActiveNotification observer rather than a custom NSEvent mouse-down monitor — a mouse-down monitor risked misfiring while the new file-picker Menu's own tracking session is open (a real regression risk to the just-built Menu), while app-deactivation is orthogonal to in-app menu tracking and directly matches the reported symptom (switching to another app)"

requirements-completed: []  # NOTES-01/NOTES-02 pending checkpoint approval below — not marked complete until on-device UAT confirms

# Metrics
duration: 35min (plus pending on-device checkpoint)
completed: 2026-07-25
---

# Phase 64 Plan 08: Quick Notes Vault File-Picker, Vault-Delete & Reconciliation Summary

**Popover file-picker (with inline "New File…" creation and per-file note filtering) targeting any .md file in the vault folder, per-note vault-delete with occurrence-ranked duplicate disambiguation and a genuine failure guard, two-way vault/local-list reconciliation, and a fix for a Menu-caused outside-click-dismiss regression — all additional scope beyond the plan's own two tasks folded in before the on-device checkpoint.**

## Performance

- **Duration:** ~45 min automated work; a checkpoint (blocking, on-device) is now pending
- **Completed:** 2026-07-25 (automated tasks); checkpoint awaiting on-device confirmation
- **Tasks:** 6 automated tasks (2 from the locked plan + 4 additional-scope tasks) — checkpoint not yet run
- **Files modified:** 3 (`QuickNotesPopoverView.swift`, `AppDelegate.swift`, `QuickNotesStore.swift`)

## Accomplishments

- The Quick Notes popover now shows a `Menu`-based file picker above the `TextEditor`, listing every real `.md` file in the chosen vault folder (plus the fixed default filename even if it doesn't exist yet) — disabled when the vault isn't configured, matching the existing TextEditor/Save-button guard.
- The error banner renders `controller.errorMessage` directly instead of a hardcoded save-specific string, since a second distinct failure message (delete) now exists — `AppDelegate` is the single source of truth for both exact copy strings.
- `openQuickNotesPopover()` lists real vault files on every open (never cached) and self-heals the persisted file selection back to the default if the previously selected file was renamed/deleted.
- New notes are targeted at and stamped with whichever file is currently selected (`quickNotesController.selectedFileName`), reversing the original fixed-filename design (D-08 reversal, as scoped).
- Per-row delete now removes the matching line from the note's OWN stored vault file (`note.fileName`, not necessarily the currently selected file), with an occurrence rank computed from `quickNotesStore.items`' append order so a byte-identical duplicate entry is never deleted at the wrong physical line. A genuine I/O failure during vault removal surfaces a new error banner ("Couldn't delete from vault — check your vault folder in Settings.") and leaves the note in the local list untouched — mirroring D-12's existing save-failure data-loss guard.
- **Additional scope 1 (user-approved, not in the original locked plan):** on every popover open, `reconcileQuickNotesWithVault` re-reads each distinct vault file referenced by the local notes and prunes any note whose formatted entry is no longer present in its own file's content — so a note deleted directly in the vault (Obsidian, a text editor, Finder trash, etc.) also disappears from Islet's recent-notes list. Reuses the exact same occurrence-by-append-order disambiguation logic as the single-note delete path, computed across all notes in one forward pass. A vault file that can't be read at all (missing, permissions error) is treated as "unknown," never "deleted" — nothing is pruned for that file, avoiding a false-positive data-loss scenario.
- **Additional scope 2 (user-approved, requested during checkpoint review):** the file-picker `Menu` gains a "New File…" item (below a `Divider`). Picking it reveals an inline `TextField` (matching this codebase's existing plain-TextField name-prompt convention, no `NSAlert`/sheet precedent exists anywhere in Islet) with Add/Cancel actions. The typed name is trimmed and given a `.md` suffix if missing, then added to `availableFiles` and selected — the file itself is never created directly; the existing submit path lazily creates it on the first note, same as any other selected filename.
- **Additional scope 3 (user-approved, bug fix requested during checkpoint review):** clicking another application while the Quick Notes popover was open used to auto-dismiss it (`NSPopover.behavior = .transient`'s normal outside-interaction contract) — this broke once the file-picker `Menu` was added in Task 1. Root cause: SwiftUI's `Menu` is a documented AppKit/SwiftUI interop gap where a hosted `Menu`'s presence (not necessarily its use) silently disables `.transient`'s own outside-click/app-deactivate detection, even though `.behavior` itself was never changed away from `.transient`. Fixed via an explicit `NSApplication.didResignActiveNotification` observer that closes the popover on app deactivation, restoring the missing half of the contract through supported API rather than fighting SwiftUI's internal Menu/`NSMenu` tracking machinery.
- **Additional scope 4 (user-approved, bug fix requested during checkpoint review):** the recent-notes list was showing every note across every vault file, ignoring the file picker's current selection. Fixed via a single `refreshQuickNotesList()` helper (the only place `quickNotesController.notes` is now assigned) that filters `quickNotesStore.items` down to `note.fileName == selectedFileName`, reversed for most-recent-first, and is called from every existing list-refresh site plus `onSelectFile`/`onCreateFile` so switching files immediately re-filters the visible list. `quickNotesStore.items` itself is untouched — delete (id-based, uses the note's own `fileName`) and vault reconciliation (iterates every note across every file) both already operated on the full store, not the filtered display list, so neither needed logic changes beyond routing their final refresh through the shared helper.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add file-picker UI and new error-copy binding to QuickNotesPopoverView** - `36084bf` (feat)
2. **Task 2: Wire file listing, per-file submit targeting, and vault-delete with failure guard in AppDelegate** - `c0891d9` (feat)
3. **Task 3 (additional scope, user-approved): Reconcile local Quick Notes list against vault file on popover open** - `44c3ad3` (feat)
4. **Task 4 (additional scope, user-approved): Add "New File…" option to the Quick Notes file picker** - `c16add9` (feat)
5. **Task 5 (additional scope, user-approved bug fix): Restore outside-click/app-switch auto-dismiss on the popover** - `8a65d74` (fix)
6. **Task 6 (additional scope, user-approved bug fix): Filter the recent-notes list by the currently selected file** - `39848d4` (fix)

**Plan metadata:** pending — will be committed once the checkpoint below is approved (per explicit instruction, STATE.md/ROADMAP.md are not touched until on-device confirmation).

## Files Created/Modified

- `Islet/QuickNotes/QuickNotesPopoverView.swift` - `QuickNotesController` gains `availableFiles`/`selectedFileName`/`onSelectFile`/`onCreateFile`; a `Menu`-based file picker (with a "New File…" item + inline name TextField) rendered above the `TextEditor`; error banner now renders `controller.errorMessage` directly
- `Islet/AppDelegate.swift` - `openQuickNotesPopover()` reconciles the local list against the vault, lists real `.md` files, and self-heals the persisted selection; `applicationDidFinishLaunching` wires `onSelectFile`/`onCreateFile` and registers the outside-click-dismiss-fix observer; `handleQuickNoteSubmit` targets/stamps the selected file; `handleQuickNoteDelete` computes an occurrence rank and removes the matching vault line with a failure guard; new `reconcileQuickNotesWithVault(vaultFolderPath:)` prunes notes deleted directly in the vault; new `refreshQuickNotesList()` is the sole place `quickNotesController.notes` is assigned, filtering by `selectedFileName`
- `Islet/QuickNotes/QuickNotesStore.swift` - new `prune(keepingIDs:)` bulk-delete method, mirroring the existing `remove(id:)`'s shape

## Decisions Made

See `key-decisions` in frontmatter above — summarized:
- Vault-file reconciliation, deferred from Plan 64-06 per its own handoff note, is built here as an additional Task 3, explicitly approved for this execution rather than silently added.
- `QuickNotesStore.prune(keepingIDs:)` added instead of exposing `items` for direct external mutation, keeping the store's existing encapsulation.
- Reconciliation runs before file-listing/selection-restore in `openQuickNotesPopover()` so a pruned note can never leave a stale `fileName` reference in the computed `availableFiles`.
- "New File…" reuses the existing lazy-create-on-first-write behavior of `QuickNotesVaultWriter.append` instead of adding a new file-creation code path.
- The outside-click-dismiss fix uses `NSApplication.didResignActiveNotification` rather than a custom `NSEvent` mouse-down monitor, specifically to avoid risking a new regression in the just-built Menu's own item-selection tracking.
- The recent-notes list is a display-only filter (`quickNotesStore.items.filter { $0.fileName == selectedFileName }`) computed fresh by one shared helper; delete (id-based, reads `note.fileName`) and reconciliation (iterates all notes/files) both read from the full, unfiltered `quickNotesStore.items` and were unaffected beyond routing their final list-refresh through the same helper.

## Deviations from Plan

### Additional Scope (user-approved, not deviations from the locked plan itself)

**1. Vault-to-local reconciliation on popover open**
- **Requested by:** the coordinator, citing 64-06-SUMMARY.md's explicit handoff note ("64-08's planning should explicitly confirm whether this reconciliation is in its scope") and on-device UAT feedback during Plan 64-06.
- **What was built:** `AppDelegate.reconcileQuickNotesWithVault(vaultFolderPath:)`, called from `openQuickNotesPopover()` before the file-listing logic, plus `QuickNotesStore.prune(keepingIDs:)`.
- **Why not a "deviation":** this is net-new functionality explicitly scoped into this execution by the coordinator/user, not a bug fix or blocking-issue auto-fix under Rules 1-3, and not silently added without approval (Rule 4 would otherwise apply to an architectural addition like this).
- **Files modified:** `Islet/AppDelegate.swift`, `Islet/QuickNotes/QuickNotesStore.swift`
- **Verification so far:** build green, all 27 existing unit tests pass (no regressions). On-device verification of the actual delete-outside-the-app behavior is folded into the checkpoint below.
- **Committed in:** `44c3ad3`

**2. "New File…" option in the file picker**
- **Requested by:** the coordinator, during checkpoint review, before on-device verification of the plan's original tasks.
- **What was built:** a `Divider` + "New File…" `Button` inside the existing `Menu`; an inline `TextField`-based name prompt (Add/Cancel); `QuickNotesController.onCreateFile` wired in `AppDelegate` to add the typed (and `.md`-suffixed) name to `availableFiles` and select it.
- **Why not a "deviation":** explicitly requested new functionality, not a bug fix or blocking issue.
- **Files modified:** `Islet/QuickNotes/QuickNotesPopoverView.swift`, `Islet/AppDelegate.swift`
- **Verification so far:** build green. On-device verification (typing a new name, confirming it's selected, and confirming the file is actually created in the vault folder on the first submitted note) is folded into the checkpoint below.
- **Committed in:** `c16add9`

**3. Outside-click/app-switch auto-dismiss regression fix**
- **Requested by:** the coordinator, during checkpoint review — a real regression caused by this plan's own Task 1 (the file-picker `Menu`).
- **What was built:** `quickNotesPopoverDeactivationObserver`, an `NSApplication.didResignActiveNotification` observer registered in `applicationDidFinishLaunching` that explicitly closes `quickNotesPopover` when the app deactivates.
- **Why not a "deviation":** this is a genuine bug (Rule 1 — auto-fixed bugs) surfaced by the coordinator's own investigation of Task 1's side effects, not new plan scope; documented here for visibility since it required root-cause investigation rather than a one-line fix.
- **Files modified:** `Islet/AppDelegate.swift`
- **Verification so far:** build green, confirmed `.behavior` is still `.transient` (never accidentally changed). On-device verification that switching to another app now closes the popover again is folded into the checkpoint below as a new explicit check.
- **Committed in:** `8a65d74`

**4. Recent-notes list not filtered by the selected file**
- **Requested by:** the coordinator, during on-device checkpoint testing — a real functional bug found while verifying the file-picker (the list showed all files' notes mixed together instead of only the currently selected file's notes).
- **What was built:** `AppDelegate.refreshQuickNotesList()`, the sole call site now assigning `quickNotesController.notes`, filtering `quickNotesStore.items` by `fileName == selectedFileName` before reversing; called from the initial load, submit, delete, reconciliation, `onSelectFile`, and `onCreateFile`.
- **Why not a "deviation":** a genuine Rule-1 bug (display logic not matching the intended per-file browsing behavior the file-picker was built for), found via on-device testing, not new plan scope.
- **Files modified:** `Islet/AppDelegate.swift`
- **Verification so far:** build green, all 27 existing unit tests pass. On-device verification (switching between 2+ files with notes in each, confirming each shows only its own notes) is folded into the checkpoint below.
- **Committed in:** `39848d4`

---

**Total deviations:** 0 conventional Rule 1-3 auto-fixes during the plan's own two tasks; 2 genuine Rule-1 bug fixes (items 3-4 above, both found via the coordinator's own on-device checkpoint review) and 2 explicitly-approved additional-scope tasks (items 1-2 above), all requested by the coordinator before final on-device approval.
**Impact on plan:** No unrequested scope creep — every addition was directed by the coordinator with an explicit rationale and is fully documented here, not silently folded into the plan's own two tasks.

## Issues Encountered

None of the 6 tasks failed to build or broke an existing test. All existing Quick Notes unit tests (`QuickNotesStoreTests`, `QuickNotesFormatterTests`, `QuickNotesVaultWriterTests`, `QuickNotesFileStoreTests`) continue to pass unchanged after every task. The outside-click-dismiss root cause (SwiftUI `Menu` silently disabling `.transient`'s own detection) could only be reasoned about from documented AppKit/SwiftUI interop behavior, not confirmed by an automated test — like the rest of this popover's focus/dismiss behavior, it needs on-device confirmation (this project's own established discipline for this exact class of AppKit-window-behavior bug, per Plan 64-06's own multi-round on-device UAT history). The notes-list filtering bug was caught during the coordinator's own on-device checkpoint pass, not by the automated build/test suite — filtering logic has no unit-test coverage yet since `quickNotesController.notes` is a UI-facing projection, matching this codebase's existing convention of leaving SwiftUI-render-facing state to on-device/visual verification rather than unit tests (per 64-RESEARCH.md's NOTES-03 test-shape note).

## User Setup Required

None - no external service configuration required.

## Known Stubs

None found — scanned all three modified files for hardcoded empty values, placeholder text, and unwired data sources; none present. The file picker's `availableFiles`/`selectedFileName` are real, live-computed values, not stubs. "New File…" doesn't stub file creation — it correctly relies on the existing lazy-create-on-first-write behavior already present in `QuickNotesVaultWriter.append`.

## Checkpoint Status: PENDING ON-DEVICE VERIFICATION

The plan's `checkpoint:human-verify` task (gate="blocking") has NOT yet been run to full approval. Per this execution's explicit instructions, STATE.md and ROADMAP.md are intentionally NOT updated yet — this SUMMARY documents the 6 completed/committed automated tasks only (2 from the locked plan + 4 additional-scope). See the accompanying checkpoint message (returned alongside this summary) for the full on-device verification steps: the plan's original 6-step checklist, the vault-reconciliation check, "New File…" creation, outside-click/app-switch dismissal, PLUS a new check confirming the recent-notes list correctly filters per selected file.

## Next Phase Readiness

- Not yet ready to close — awaiting on-device checkpoint approval (the plan's original 6 verification steps, the reconciliation check, and the 3 newly added checks for New-File-creation, outside-click-dismiss, and per-file list filtering).
- Once approved: NOTES-01/NOTES-02 should be marked complete in REQUIREMENTS.md, STATE.md/ROADMAP.md updated, and a follow-up `docs(64-08)` metadata commit created — none of that has happened yet in this pass.

---
*Phase: 64-quick-notes-obsidian-export*
*Completed: 2026-07-25 (automated tasks only; checkpoint pending)*

## Self-Check: PENDING
