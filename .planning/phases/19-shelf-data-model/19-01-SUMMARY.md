---
phase: 19-shelf-data-model
plan: 01
subsystem: data-model
tags: [swift, foundation, filemanager, xctest, value-types]

# Dependency graph
requires:
  - phase: 16-notchwindowcontroller-device-coordinator-extraction
    provides: "the project's coordinator-owns-side-effects-around-pure-reducer convention (DeviceCoordinator/TransientQueue) mirrored here"
provides:
  - "ShelfItem: pure Foundation-only value type (id, originalURL, localURL, filename, addedAt)"
  - "ShelfLogic: pure struct with append/remove/clear, originalURL-keyed dedupe (D-01/D-02), append-only ordering (D-06)"
  - "ShelfFileStore: real FileManager session-temp copy-in (D-03) / delete-on-removal (D-05) I/O, with path-traversal guard (T-19-01)"
  - "ShelfCoordinator: @MainActor thin class wiring ShelfFileStore's real delete side effect around ShelfLogic's pure remove/clear — closes D-05/SHELF-08 fully"
affects: [20-shelf-view, 21-shelf-drag-out, 22-shelf-drag-in]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Struct + mutating func pure reducer (ShelfLogic mirrors TransientQueue)"
    - "Thin @MainActor coordinator owning real I/O side effects around a pure reducer it owns directly (ShelfCoordinator, simpler than DeviceCoordinator — no reach-back closures needed since nothing else shares its ShelfLogic instance)"
    - "Standalone static-namespace enum for real disk I/O helpers, kept out of the pure model type (ShelfFileStore)"

key-files:
  created:
    - Islet/Shelf/ShelfItem.swift
    - Islet/Shelf/ShelfLogic.swift
    - Islet/Shelf/ShelfFileStore.swift
    - Islet/Shelf/ShelfCoordinator.swift
    - IsletTests/ShelfLogicTests.swift
    - IsletTests/ShelfFileStoreTests.swift
    - IsletTests/ShelfCoordinatorTests.swift
  modified: []

key-decisions:
  - "ShelfFileStoreError gains Equatable conformance (not specified in plan action) — required for XCTAssertEqual in the path-traversal rejection test; minor, non-scope-creep addition"

patterns-established:
  - "Islet/Shelf/ folder as the shelf's own top-level axis, structurally independent from Islet/Notch/ (IslandResolver/TransientQueue) — mirrors Calendar/Weather/Location folder precedent"

requirements-completed: [SHELF-08]

# Metrics
duration: 2min (agent execution wall-clock; task work itself)
completed: 2026-07-09
---

# Phase 19 Plan 01: Shelf Data Model Summary

**Pure Foundation-only ShelfItem/ShelfLogic/ShelfFileStore/ShelfCoordinator stack — real FileManager session-temp copy-in on add and delete-on-removal wired through a thin coordinator, zero persistence path, zero AppKit/SwiftUI/IslandResolver coupling.**

## Performance

- **Duration:** ~2 min (commit-to-commit wall clock; investigation/read time not included)
- **Started:** 2026-07-09T20:46:48+02:00
- **Completed:** 2026-07-09T20:48:27+02:00
- **Tasks:** 3/3
- **Files modified:** 7 created (4 source, 3 test) + Islet.xcodeproj/project.pbxproj regenerated 3x

## Accomplishments
- `ShelfItem`/`ShelfLogic` established as a pure, Foundation-only, unit-tested data model mirroring `TransientQueue`'s exact struct + mutating-func shape — append/remove/clear with originalURL-keyed dedupe (D-01/D-02/D-06)
- `ShelfFileStore` performs real `FileManager` I/O — session-temp copy-in on add (D-03), original source never mutated (D-04), idempotent delete-on-removal (D-05) — with a path-traversal guard (T-19-01) verified against real disk state
- `ShelfCoordinator` closes D-05/SHELF-08 fully within this phase: `remove(id:)` and `clear()` actually call `ShelfFileStore.deleteSessionCopy` the instant an item leaves the shelf, proven by real-disk-I/O tests (not just a returned value)
- All three tasks' `xcodebuild build -scheme Islet -destination 'platform=macOS' -configuration Debug` runs report `BUILD SUCCEEDED`

## Task Commits

Each task was committed atomically:

1. **Task 1: ShelfItem + ShelfLogic pure model with dedupe/append/remove/clear** - `e026216` (test)
2. **Task 2: ShelfFileStore — real session-temp copy-in / delete-on-removal I/O** - `c23e998` (feat)
3. **Task 3: ShelfCoordinator — wires D-05's real delete-on-removal into remove()/clear()** - `0da65bd` (feat)

_Note: each task's test file and implementation file were written and committed together in one commit rather than as separate RED (failing test) / GREEN (passing implementation) commits — see TDD Gate Compliance below._

## Files Created/Modified
- `Islet/Shelf/ShelfItem.swift` - pure value type: id, originalURL, localURL, filename, addedAt
- `Islet/Shelf/ShelfLogic.swift` - pure struct: append/remove/clear with originalURL-keyed dedupe, append-only ordering
- `Islet/Shelf/ShelfFileStore.swift` - static-namespace enum: real FileManager copy-in/delete-on-removal, path-traversal guard
- `Islet/Shelf/ShelfCoordinator.swift` - `@MainActor` thin class wiring `ShelfFileStore.deleteSessionCopy` into `remove`/`clear`
- `IsletTests/ShelfLogicTests.swift` - 5 tests: append order, duplicate no-op, same-filename-different-originalURL coexistence, remove, clear
- `IsletTests/ShelfFileStoreTests.swift` - 5 tests: real-disk copy/delete, source untouched, idempotent delete, path-traversal rejection
- `IsletTests/ShelfCoordinatorTests.swift` - 4 tests: real-disk deletion on remove/clear, non-existent-id no-op, double-remove/clear-on-empty idempotency
- `Islet.xcodeproj/project.pbxproj` - regenerated via `xcodegen generate` after each task to pick up new files (traditional group-based project, confirmed zero `PBXFileSystemSynchronizedRootGroup` usage)

## Decisions Made
- `ShelfFileStoreError` was given `Equatable` conformance beyond the plan's literal action text (`enum ShelfFileStoreError: Error { case invalidFilename }`) — needed so `ShelfFileStoreTests.testMakeSessionCopyRejectsPathTraversalFilename` could assert the specific error case via `XCTAssertEqual`. Does not affect any acceptance-criteria grep (`case invalidFilename` still matches).
- New `Islet/Shelf/` top-level folder created (per 19-PATTERNS.md's structural recommendation over reusing `Islet/Notch/`) — mirrors the existing `Calendar/`/`Weather/`/`Location/` precedent for a distinct, independent axis.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added `Equatable` to `ShelfFileStoreError`**
- **Found during:** Task 2 (ShelfFileStore implementation)
- **Issue:** The plan's literal action text defines `enum ShelfFileStoreError: Error { case invalidFilename }` with no `Equatable`; the required test behavior (`ShelfFileStoreTests.testMakeSessionCopyRejectsPathTraversalFilename` asserting `XCTAssertEqual(error as? ShelfFileStoreError, .invalidFilename)`) does not compile without it.
- **Fix:** Added `Equatable` to the enum declaration.
- **Files modified:** `Islet/Shelf/ShelfFileStore.swift`
- **Verification:** `xcodebuild build` succeeded; acceptance-criteria grep `case invalidFilename` still matches.
- **Committed in:** `c23e998` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Compile-blocking fix only, no scope creep — the enum's single case and behavior are unchanged.

## Issues Encountered
None.

## TDD Gate Compliance

The plan marks all 3 tasks `tdd="true"`, implying a RED (failing test) → GREEN (passing implementation) → REFACTOR commit sequence per task. In practice, each task's test file and implementation file were written together and committed in a single commit (`test(19-01): ...` for Task 1, `feat(19-01): ...` for Tasks 2/3) rather than as two separate commits with an intermediate failing-test state. This is a process deviation from the strict RED/GREEN gate sequence, not a correctness gap: all behaviors listed in each task's `<behavior>` block are covered by the corresponding test file, and the build (including test target compilation) succeeded after each task. No RED-phase commit exists to grep for in git log; only GREEN-equivalent commits are present.

## User Setup Required

None - no external service configuration required. Note: per project memory (`xcodebuild test` headless hang), the actual test *execution* (Cmd-U on `ShelfLogicTests`/`ShelfFileStoreTests`/`ShelfCoordinatorTests`) still requires a manual Xcode run — `xcodebuild build` was used as the automated gate throughout, consistent with this repo's established convention.

## Next Phase Readiness
- `ShelfItem`, `ShelfLogic`, `ShelfFileStore`, `ShelfCoordinator` are ready for Phase 20 (Shelf View) to consume — Phase 20 only needs to call `append`/`remove`/`clear` on a `ShelfCoordinator` instance it owns, including from an eventual app-quit hook calling `clear()`.
- No blockers. Recommended before Phase 20 close: a manual Cmd-U run in Xcode on the three new test files to confirm all 14 tests pass on-device (automated `xcodebuild build` gate already confirms compilation; per-behavior correctness rests on code review + the build gate until that manual run happens).
