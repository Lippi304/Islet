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
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Occurrence-by-append-order duplicate disambiguation: quickNotesStore.items is stored in the same order notes were appended to the vault file, so counting earlier same-fileName/same-formatted-entry items before a given note yields the correct physical line to target — reused identically for both single-note delete (handleQuickNoteDelete) and bulk vault reconciliation (reconcileQuickNotesWithVault)"
    - "AppDelegate as single source of truth for QuickNotesPopoverView's error copy: the view renders controller.errorMessage directly instead of a hardcoded string, since two distinct failure messages (save vs. delete) now exist"

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

requirements-completed: []  # NOTES-01/NOTES-02 pending checkpoint approval below — not marked complete until on-device UAT confirms

# Metrics
duration: 20min (plus pending on-device checkpoint)
completed: 2026-07-25
---

# Phase 64 Plan 08: Quick Notes Vault File-Picker, Vault-Delete & Reconciliation Summary

**Popover file-picker targeting any .md file in the vault folder, per-note vault-delete with occurrence-ranked duplicate disambiguation and a genuine failure guard, plus (additional scope) two-way vault/local-list reconciliation so notes deleted directly in the vault file also disappear from Islet's own list.**

## Performance

- **Duration:** ~20 min automated work; a checkpoint (blocking, on-device) is now pending
- **Completed:** 2026-07-25 (automated tasks); checkpoint awaiting on-device confirmation
- **Tasks:** 3 automated tasks (2 from the locked plan + 1 additional-scope task) — checkpoint not yet run
- **Files modified:** 3 (`QuickNotesPopoverView.swift`, `AppDelegate.swift`, `QuickNotesStore.swift`)

## Accomplishments

- The Quick Notes popover now shows a `Menu`-based file picker above the `TextEditor`, listing every real `.md` file in the chosen vault folder (plus the fixed default filename even if it doesn't exist yet) — disabled when the vault isn't configured, matching the existing TextEditor/Save-button guard.
- The error banner renders `controller.errorMessage` directly instead of a hardcoded save-specific string, since a second distinct failure message (delete) now exists — `AppDelegate` is the single source of truth for both exact copy strings.
- `openQuickNotesPopover()` lists real vault files on every open (never cached) and self-heals the persisted file selection back to the default if the previously selected file was renamed/deleted.
- New notes are targeted at and stamped with whichever file is currently selected (`quickNotesController.selectedFileName`), reversing the original fixed-filename design (D-08 reversal, as scoped).
- Per-row delete now removes the matching line from the note's OWN stored vault file (`note.fileName`, not necessarily the currently selected file), with an occurrence rank computed from `quickNotesStore.items`' append order so a byte-identical duplicate entry is never deleted at the wrong physical line. A genuine I/O failure during vault removal surfaces a new error banner ("Couldn't delete from vault — check your vault folder in Settings.") and leaves the note in the local list untouched — mirroring D-12's existing save-failure data-loss guard.
- **Additional scope (user-approved, not in the original locked plan):** on every popover open, `reconcileQuickNotesWithVault` re-reads each distinct vault file referenced by the local notes and prunes any note whose formatted entry is no longer present in its own file's content — so a note deleted directly in the vault (Obsidian, a text editor, Finder trash, etc.) also disappears from Islet's recent-notes list. Reuses the exact same occurrence-by-append-order disambiguation logic as the single-note delete path, computed across all notes in one forward pass. A vault file that can't be read at all (missing, permissions error) is treated as "unknown," never "deleted" — nothing is pruned for that file, avoiding a false-positive data-loss scenario.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add file-picker UI and new error-copy binding to QuickNotesPopoverView** - `36084bf` (feat)
2. **Task 2: Wire file listing, per-file submit targeting, and vault-delete with failure guard in AppDelegate** - `c0891d9` (feat)
3. **Task 3 (additional scope, user-approved): Reconcile local Quick Notes list against vault file on popover open** - `44c3ad3` (feat)

**Plan metadata:** pending — will be committed once the checkpoint below is approved (per explicit instruction, STATE.md/ROADMAP.md are not touched until on-device confirmation).

## Files Created/Modified

- `Islet/QuickNotes/QuickNotesPopoverView.swift` - `QuickNotesController` gains `availableFiles`/`selectedFileName`/`onSelectFile`; a `Menu`-based file picker rendered above the `TextEditor`; error banner now renders `controller.errorMessage` directly
- `Islet/AppDelegate.swift` - `openQuickNotesPopover()` reconciles the local list against the vault, lists real `.md` files, and self-heals the persisted selection; `applicationDidFinishLaunching` wires `onSelectFile`; `handleQuickNoteSubmit` targets/stamps the selected file; `handleQuickNoteDelete` computes an occurrence rank and removes the matching vault line with a failure guard; new `reconcileQuickNotesWithVault(vaultFolderPath:)` prunes notes deleted directly in the vault
- `Islet/QuickNotes/QuickNotesStore.swift` - new `prune(keepingIDs:)` bulk-delete method, mirroring the existing `remove(id:)`'s shape

## Decisions Made

See `key-decisions` in frontmatter above — summarized:
- Vault-file reconciliation, deferred from Plan 64-06 per its own handoff note, is built here as an additional Task 3, explicitly approved for this execution rather than silently added.
- `QuickNotesStore.prune(keepingIDs:)` added instead of exposing `items` for direct external mutation, keeping the store's existing encapsulation.
- Reconciliation runs before file-listing/selection-restore in `openQuickNotesPopover()` so a pruned note can never leave a stale `fileName` reference in the computed `availableFiles`.

## Deviations from Plan

### Additional Scope (user-approved, not a deviation from the locked plan itself)

**1. Vault-to-local reconciliation on popover open**
- **Requested by:** the coordinator, citing 64-06-SUMMARY.md's explicit handoff note ("64-08's planning should explicitly confirm whether this reconciliation is in its scope") and on-device UAT feedback during Plan 64-06.
- **What was built:** `AppDelegate.reconcileQuickNotesWithVault(vaultFolderPath:)`, called from `openQuickNotesPopover()` before the file-listing logic, plus `QuickNotesStore.prune(keepingIDs:)`.
- **Why not a "deviation":** this is net-new functionality explicitly scoped into this execution by the coordinator/user, not a bug fix or blocking-issue auto-fix under Rules 1-3, and not silently added without approval (Rule 4 would otherwise apply to an architectural addition like this).
- **Files modified:** `Islet/AppDelegate.swift`, `Islet/QuickNotes/QuickNotesStore.swift`
- **Verification so far:** build green, all 27 existing unit tests pass (no regressions). On-device verification of the actual delete-outside-the-app behavior is folded into the checkpoint below (added a 7th verification step to the plan's original 6).
- **Committed in:** `44c3ad3`

---

**Total deviations:** 0 conventional deviations (no Rule 1/2/3 auto-fixes needed); 1 explicitly-approved additional-scope task.
**Impact on plan:** No scope creep — the addition was directed by the coordinator with an explicit rationale (Plan 64-06's own deferred handoff note) and is fully documented here, not silently folded into the plan's own two tasks.

## Issues Encountered

None — both of the plan's own tasks and the additional reconciliation task built and compiled successfully on the first attempt; all existing Quick Notes unit tests (`QuickNotesStoreTests`, `QuickNotesFormatterTests`, `QuickNotesVaultWriterTests`, `QuickNotesFileStoreTests`) continue to pass unchanged.

## User Setup Required

None - no external service configuration required.

## Known Stubs

None found — scanned all three modified files for hardcoded empty values, placeholder text, and unwired data sources; none present. The file picker's `availableFiles`/`selectedFileName` are real, live-computed values, not stubs.

## Checkpoint Status: PENDING ON-DEVICE VERIFICATION

The plan's `checkpoint:human-verify` task (gate="blocking") has NOT yet been run. Per this execution's explicit instructions, STATE.md and ROADMAP.md are intentionally NOT updated yet — this SUMMARY documents the 3 completed/committed automated tasks only. See the accompanying checkpoint message (returned alongside this summary) for the full on-device verification steps, extended to also cover the additional vault-reconciliation scope (deleting a note's line directly in the vault file with Islet closed, then confirming it disappears from the recent-notes list on next popover open).

## Next Phase Readiness

- Not yet ready to close — awaiting on-device checkpoint approval (both the plan's original 6 verification steps and the added reconciliation-specific check).
- Once approved: NOTES-01/NOTES-02 should be marked complete in REQUIREMENTS.md, STATE.md/ROADMAP.md updated, and a follow-up `docs(64-08)` metadata commit created — none of that has happened yet in this pass.

---
*Phase: 64-quick-notes-obsidian-export*
*Completed: 2026-07-25 (automated tasks only; checkpoint pending)*
