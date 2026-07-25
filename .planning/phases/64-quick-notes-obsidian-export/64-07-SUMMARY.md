---
phase: 64-quick-notes-obsidian-export
plan: 07
subsystem: quick-notes
tags: [swift, foundation, filemanager, codable, obsidian, vault-write]

# Dependency graph
requires:
  - phase: 64-quick-notes-obsidian-export (Plans 01-02)
    provides: QuickNote model, QuickNotesVaultWriter append-only writer, QuickNotesFormatter
provides:
  - "QuickNote.fileName field, defaulted and backward-compatibly decoded"
  - "QuickNotesVaultWriter.removeEntry — atomic, occurrence-ranked vault-line delete"
  - "QuickNotesVaultWriter.listMarkdownFiles — vault .md file enumeration"
  - "ActivitySettings.quickNotesDefaultFileName / quickNotesSelectedFileNameKey constants"
affects: [64-08 (popover/AppDelegate wiring for delete + multi-file selection)]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Deliberate, scoped exception to an append-only-writer convention (D-07): full-file read + temp-file-in-same-directory + FileManager.replaceItemAt atomic rename, confined to a single explicit delete function, hot append path left untouched"
    - "occurrence-rank disambiguation for exact-string-match line deletion when the same formatted content can legitimately repeat"

key-files:
  created: []
  modified:
    - Islet/QuickNotes/QuickNote.swift
    - Islet/QuickNotes/QuickNotesVaultWriter.swift
    - Islet/ActivitySettings.swift
    - IsletTests/QuickNotesVaultWriterTests.swift
    - IsletTests/QuickNotesFileStoreTests.swift

key-decisions:
  - "removeEntry is the ONE deliberate, scoped exception to this file's D-07 append-only rule — documented directly above the function, runs only on an explicit rare user delete, never on the append path"
  - "occurrence parameter (0-based) disambiguates byte-identical duplicate entries; Plan 64-08 is responsible for computing the correct rank from its own ordered note list"

patterns-established:
  - "Atomic vault rewrite: read whole file -> String, mutate in memory, write to a hidden temp file in the same directory, FileManager.replaceItemAt to swap in — never a truncating in-place write"

requirements-completed: [NOTES-02, NOTES-03]

# Metrics
duration: 12min
completed: 2026-07-25
---

# Phase 64 Plan 07: QuickNote fileName + Vault Delete/Enumerate Contracts Summary

**Backward-compatible QuickNote.fileName field plus an atomic, occurrence-ranked QuickNotesVaultWriter.removeEntry and a listMarkdownFiles enumerator, built contracts-only for Plan 64-08 to wire up.**

## Performance

- **Duration:** 12 min
- **Started:** 2026-07-25T15:16:00Z
- **Completed:** 2026-07-25T15:19:25Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments
- `QuickNote` now carries which vault `.md` file it belongs to, with a custom `Decodable` init so pre-existing `index.json` entries (written before this field existed) decode to the default filename instead of being silently dropped by `QuickNotesFileStore.load`'s discard-on-decode-failure discipline.
- `QuickNotesVaultWriter.removeEntry` safely deletes exactly one note's formatted entry (bullet + any continuation lines) from a vault file via a temp-file + atomic-rename rewrite, disambiguating byte-identical duplicate entries by an explicit `occurrence` rank, and returning `.notFound` (no throw, no side effects) whenever the target line or file isn't there.
- `QuickNotesVaultWriter.listMarkdownFiles` enumerates the `.md` files in a folder, sorted alphabetically, empty-safe for a missing/empty folder.
- `ActivitySettings` gains `quickNotesDefaultFileName` ("Islet Notes.md") and `quickNotesSelectedFileNameKey`, giving the filename a single named source of truth instead of the value hardcoded in `AppDelegate.swift`'s `handleQuickNoteSubmit` (that call site itself is untouched — out of this contracts-only plan's scope, per the plan's explicit files_modified list).

## Task Commits

Each task was committed atomically:

1. **Task 1: Add QuickNote.fileName with backward-compatible decoding** - `b6bf7bd` (feat)
2. **Task 2: Add QuickNotesVaultWriter.removeEntry and listMarkdownFiles** - `6d9938d` (feat)

**Plan metadata:** (this commit)

## Files Created/Modified
- `Islet/QuickNotes/QuickNote.swift` - fourth `fileName` stored property, explicit `CodingKeys`, memberwise init (fileName defaulted, existing call sites unaffected), custom `init(from:)` decoding `fileName` via `decodeIfPresent(...) ?? default`
- `Islet/ActivitySettings.swift` - `quickNotesDefaultFileName` and `quickNotesSelectedFileNameKey` constants near the existing `quickNotesVaultFolderPathKey`
- `Islet/QuickNotes/QuickNotesVaultWriter.swift` - added `VaultDeleteResult` enum, `removeEntry(matching:occurrence:from:)`, `DecodeError`, `listMarkdownFiles(inFolder:)`; `append`/`readTail` unchanged (diff confirms no removed lines in either)
- `IsletTests/QuickNotesFileStoreTests.swift` - `testLoadDecodesOldJSONMissingFileNameAsDefault` (hand-built pre-`fileName` JSON decodes to the default), extended `testSaveThenLoadRoundTripsNotes` with an explicit non-default `fileName` round-trip assertion
- `IsletTests/QuickNotesVaultWriterTests.swift` - 7 new tests: `testRemoveEntryDeletesOnlyMatchingBulletLeavesOthersByteIdentical`, `testRemoveEntryRemovesMultiLineContinuationLines`, `testRemoveEntryReturnsNotFoundWhenLineAlreadyGone`, `testRemoveEntryReturnsNotFoundForNonexistentFileWithoutCreatingIt`, `testRemoveEntryTargetsRequestedOccurrenceAmongDuplicates`, `testListMarkdownFilesReturnsOnlyMdFilesSorted`, `testListMarkdownFilesReturnsEmptyForMissingFolder`

## Decisions Made
None beyond what the plan itself specified - plan executed exactly as written, including the explicit D-07 exception rationale documented as a comment above `removeEntry`.

## Deviations from Plan

None - plan executed exactly as written.

One informational note: the plan's acceptance criterion `grep -c "replaceItemAt" ... returns 1` actually returns 2, because the required doc comment above `removeEntry` (which the plan itself mandates, explaining the D-07 exception) also names `FileManager.replaceItemAt` in prose. The code still calls `replaceItemAt` exactly once. Not a functional deviation — just a byproduct of satisfying two acceptance criteria (the grep count and the mandated comment) simultaneously.

## Issues Encountered
None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Plan 64-08 can now wire `QuickNotesVaultWriter.removeEntry`/`listMarkdownFiles` and `QuickNote.fileName` into the popover and `AppDelegate` for the vault-delete and multi-file-selection features. `AppDelegate.swift`'s `handleQuickNoteSubmit` still hardcodes `"Islet Notes.md"` inline rather than referencing the new `ActivitySettings.quickNotesDefaultFileName` constant — deliberately left as-is since it's outside this plan's `files_modified` scope; Plan 64-08 should switch that call site to the named constant while wiring the new UI, or a fast-follow can adjust it.

Both new unit-test methods and the 7 vault-writer tests were verified via `xcodebuild build-for-testing` (compiles clean) and a manual read-through against the specified behaviors; per this project's documented headless-`xcodebuild test`-hang limitation, actual `Cmd-U` execution is left for on-device/manual confirmation as the plan itself specifies.

---
*Phase: 64-quick-notes-obsidian-export*
*Completed: 2026-07-25*
