---
phase: 64-quick-notes-obsidian-export
plan: 01
subsystem: quick-notes
tags: [swift, xctest, foundation, json-persistence, pure-value-types]

# Dependency graph
requires: []
provides:
  - QuickNote pure value type (id, text, timestamp)
  - QuickNotesStore pure reducer (plain append + D-17 remove(id:), D-14 cap=30 FIFO eviction)
  - QuickNotesFormatter (D-05 exact "## YYYY-MM-DD" / "- HH:mm text" / 2-space-indented-continuation string builders)
  - QuickNotesFileStore (D-18 plaintext JSON local persistence under its own IsletQuickNotes storage root)
affects: [64-02, 64-03, 64-04, 64-05]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Pure-reducer + side-effect-isolated file-store split (QuickNotesStore/QuickNotesFileStore), mirroring ClipboardStore/ClipboardFileStore"
    - "D-05 fixed Markdown entry format via plain String split/join, no NSRegularExpression"

key-files:
  created:
    - Islet/QuickNotes/QuickNote.swift
    - Islet/QuickNotes/QuickNotesStore.swift
    - Islet/QuickNotes/QuickNotesFormatter.swift
    - Islet/QuickNotes/QuickNotesFileStore.swift
    - IsletTests/QuickNotesStoreTests.swift
    - IsletTests/QuickNotesFormatterTests.swift
    - IsletTests/QuickNotesFileStoreTests.swift
  modified:
    - Islet.xcodeproj/project.pbxproj (xcodegen regenerate to pick up new QuickNotes/ sources)

key-decisions:
  - "QuickNotesStore.append is a plain append with no dedupe branch (discretion note in 64-CONTEXT.md: append is the simpler default for notes)"
  - "QuickNotesStore has no clear()/delete-all method -- D-17 explicitly has no Delete All, only per-row remove(id:)"
  - "QuickNotesFileStore uses its own IsletQuickNotes storage root, sibling to IsletClipboard, never shared"

patterns-established:
  - "Pattern: near-verbatim copy of an existing pure-reducer/file-store pair (Clipboard) with the crypto/dedupe branches removed for a lower-risk feature variant"

requirements-completed: [NOTES-02, NOTES-03]

# Metrics
duration: ~10min
completed: 2026-07-25
---

# Phase 64 Plan 1: Quick Notes Data Model + Formatter + Local Persistence Summary

**QuickNote model, QuickNotesStore reducer (cap=30 FIFO + per-row delete), QuickNotesFormatter (exact D-05 Markdown entry string), and QuickNotesFileStore (plaintext JSON local persistence) -- all near-verbatim analogs of the existing Clipboard History building blocks with crypto/dedupe removed.**

## Performance

- **Duration:** ~10 min
- **Completed:** 2026-07-25T12:57:05Z
- **Tasks:** 3
- **Files modified:** 8 (7 new + 1 regenerated project file)

## Accomplishments
- `QuickNote` pure value type (id, text, timestamp) -- no `Kind` enum, always plain text
- `QuickNotesStore` pure reducer: plain `append` (no dedupe), `cap = 30` FIFO eviction (D-14), and a new `remove(id:)` for per-row delete (D-17, no analog in `ClipboardStore`)
- `QuickNotesFormatter.isoDate(_:)` / `formatEntry(text:at:)` producing the exact locked D-05 string shape, verified with `XCTAssertEqual` against the literal target strings (not substring checks)
- `QuickNotesFileStore` plaintext JSON persistence under its own `IsletQuickNotes` Application Support directory, load-never-throws discipline (missing/corrupted `index.json` returns `[]`)
- Zero regressions in the existing `ClipboardStoreTests`/`ClipboardFileStoreTests` suites (10/10 still pass)

## Task Commits

Each task was executed as a RED -> GREEN TDD cycle, each half committed atomically:

1. **Task 1: QuickNote model + QuickNotesStore reducer**
   - `aaf809e` feat(64-01): add QuickNote pure value type
   - `0a693b0` test(64-01): add failing test for QuickNotesStore append/evict/remove (RED)
   - `0eb9e77` feat(64-01): implement QuickNotesStore append/evict-at-cap/remove(id:) (GREEN)
2. **Task 2: QuickNotesFormatter (D-05 exact string format)**
   - `fcf3c84` test(64-01): add failing test for QuickNotesFormatter D-05 string shape (RED)
   - `60a0784` feat(64-01): implement QuickNotesFormatter D-05 exact string builders (GREEN)
3. **Task 3: QuickNotesFileStore (plaintext local persistence, D-18)**
   - `638864c` test(64-01): add failing test for QuickNotesFileStore round-trip/D-18 (RED)
   - `aac3f2c` feat(64-01): implement QuickNotesFileStore plaintext local persistence (GREEN)

_Each RED commit was verified to actually fail the build (stubbed implementation, real test) before the corresponding GREEN commit restored the real implementation and re-ran green._

## Files Created/Modified
- `Islet/QuickNotes/QuickNote.swift` - pure value type (id, text, timestamp)
- `Islet/QuickNotes/QuickNotesStore.swift` - pure reducer: append (no dedupe), cap=30 FIFO, remove(id:)
- `Islet/QuickNotes/QuickNotesFormatter.swift` - isoDate(_:) and formatEntry(text:at:) D-05 string builders
- `Islet/QuickNotes/QuickNotesFileStore.swift` - plaintext JSON load/save under IsletQuickNotes root
- `IsletTests/QuickNotesStoreTests.swift` - 4 tests (cap eviction, no-dedupe, remove(id:), safe no-op remove)
- `IsletTests/QuickNotesFormatterTests.swift` - 4 tests (isoDate, single-line, 2-line, 3-line indent)
- `IsletTests/QuickNotesFileStoreTests.swift` - 3 tests (round-trip, missing index, corrupted index)
- `Islet.xcodeproj/project.pbxproj` - regenerated via `xcodegen generate` to include the new `Islet/QuickNotes/` sources

## Decisions Made
- Plan executed exactly as written -- all 4 `must_haves.truths` and all 4 `must_haves.artifacts` implemented verbatim against the plan's locked interfaces (ClipboardItem/ClipboardStore/ClipboardFileStore analogs).
- One phrasing tweak (not a behavior deviation): the `QuickNotesFileStore.swift` header comment originally said "minus CryptoKit/Keychain", which caused the plan's own acceptance-criteria grep (`grep -c CryptoKit ... returns 0`) to falsely match on the comment text. Reworded to "minus the encryption/Keychain layer" so the literal grep check passes without changing any code behavior.

## Deviations from Plan

None - plan executed exactly as written (aside from the one comment-wording fix above, which is not a behavior change).

## Issues Encountered
None.

## User Setup Required

None - no external service configuration required. These are pure Foundation-only types with no new dependencies.

## Next Phase Readiness

`QuickNote`, `QuickNotesStore`, `QuickNotesFormatter`, and `QuickNotesFileStore` all exist, compile, and pass their dedicated XCTest suites with zero regressions in the existing Clipboard suites. Plan 2 (the vault writer, `QuickNotesVaultWriter`) and later plans (popover view, AppDelegate wiring, Settings card) can now build directly against these stable, tested types -- no other plan should redefine `QuickNote` or reimplement the D-05 string format.

---
*Phase: 64-quick-notes-obsidian-export*
*Completed: 2026-07-25*

## Self-Check: PASSED
