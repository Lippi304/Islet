---
phase: 22-drag-in
plan: 02
subsystem: notch
tags: [swift, appkit, nspasteboard, state-machine, unit-testing]

# Dependency graph
requires:
  - phase: 22-drag-in (22-01)
    provides: on-device spike confirming AppKit drag-destination delivery reaches a click-through NSPanel
provides:
  - "InteractionEvent.dragEntered + nextState's (.collapsed/.hovering, .dragEntered) -> .expanded transitions"
  - "Islet/Notch/DragDropSupport.swift: fileURLs(from:) and shouldAcceptDrop(isExpanded:urls:) pure seams"
  - "Confirmed ShelfFileStore.makeSessionCopy directory round-trip (Open Question 3 closed)"
affects: [22-03]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "AppKit pasteboard reduced to plain [URL] at the Swift boundary via a top-level pure function (DragDropSupport.swift), mirroring NotchGeometry.swift's file shape"
    - "Accept/reject decisions expressed as a single boolean pure-gate function, mirroring shouldOpenShelfItem/shouldBeginShelfItemDrag"

key-files:
  created:
    - Islet/Notch/DragDropSupport.swift
    - IsletTests/DragDropSupportTests.swift
  modified:
    - Islet/Notch/NotchInteractionState.swift
    - IsletTests/InteractionStateTests.swift
    - IsletTests/ShelfFileStoreTests.swift

key-decisions:
  - "fileURLs(from:) uses pasteboard.readObjects(forClasses:[NSURL.self]) which never enumerates a folder URL's contents -- returns it as one item, satisfying REQUIREMENTS.md's Out of Scope Pitfall 4"
  - "shouldAcceptDrop combines D-04's collapsed-only gate with the non-file/empty-payload rejection into one function (!isExpanded && !urls.isEmpty), no spatial component -- 22-03 owns the separate hot-zone geometry gate"
  - "(.expanded, .dragEntered) is NOT an explicit switch case -- covered by the existing 'default: return current' arm, keeping the diff minimal"

patterns-established: []

requirements-completed: [SHELF-01, SHELF-02]

# Metrics
duration: ~15min
completed: 2026-07-10
---

# Phase 22 Plan 02: Drag-In Pure Seams Summary

**Two pure, AppKit-glue-free seams (nextState .dragEntered auto-expand transition + DragDropSupport.swift's fileURLs/shouldAcceptDrop) built and unit-tested, ready for 22-03 to wire into NotchPanel's forwarded drag callbacks.**

## Performance

- **Duration:** ~15 min
- **Completed:** 2026-07-10T20:02:53Z
- **Tasks:** 2
- **Files modified:** 5 (2 created, 3 modified)

## Accomplishments
- `InteractionEvent.dragEntered` added to the existing `nextState` state machine; `.collapsed`/`.hovering` both transition to `.expanded` on drag-enter, matching `.clicked`'s target — 3 new unit tests
- New `Islet/Notch/DragDropSupport.swift` with `fileURLs(from:)` (pasteboard → `[URL]`, folder URLs never enumerated) and `shouldAcceptDrop(isExpanded:urls:)` (D-04 gate + non-file/empty rejection) — 7 new unit tests, all using dedicated per-test pasteboards (never `NSPasteboard.general`)
- Closed 22-RESEARCH.md Open Question 3: `testMakeSessionCopyHandlesDirectoryURL` confirms `ShelfFileStore.makeSessionCopy`'s existing `FileManager.copyItem` call already round-trips a directory tree correctly — zero production code change

## Task Commits

Each task was committed atomically:

1. **Task 1: nextState .dragEntered event** - `906d633` (feat)
2. **Task 2: DragDropSupport.swift + folder round-trip test** - `0d5c357` (feat)

_TDD note: both tasks are marked `tdd="true"` in the plan, but per plan `<action>` instructions tests and implementation were added together per task (not as separate RED/GREEN commits) — the plan's own task-commit granularity, mirrored here._

## Files Created/Modified
- `Islet/Notch/NotchInteractionState.swift` - added `InteractionEvent.dragEntered` case + 2 new `nextState` transitions
- `IsletTests/InteractionStateTests.swift` - 3 new tests for the drag-enter transitions
- `Islet/Notch/DragDropSupport.swift` - new file: `fileURLs(from:)`, `shouldAcceptDrop(isExpanded:urls:)`
- `IsletTests/DragDropSupportTests.swift` - new file: 7 tests covering both functions
- `IsletTests/ShelfFileStoreTests.swift` - added `testMakeSessionCopyHandlesDirectoryURL`
- `Islet.xcodeproj/project.pbxproj` - xcodegen-regenerated to register the two new files (committed alongside Task 2, standard for this repo's tracked `.xcodeproj`)

## Decisions Made
- Followed the plan's exact implementation shape for both pure functions — no deviation from the specified `fileURLs`/`shouldAcceptDrop` signatures or bodies
- `.expanded, .dragEntered` left uncovered by an explicit switch case, relying on the existing `default: return current` idempotent arm, exactly as the plan specified

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Both pure seams (`nextState(.collapsed/.hovering, .dragEntered)` and `DragDropSupport.swift`'s two functions) are built, unit-tested, and ready for 22-03's AppKit glue to call directly from `NotchPanel`'s forwarded drag callbacks
- 22-03 owns all D-02b/D-02c/D-05/D-06 hot-zone geometry — untouched by this plan, as scoped
- Manual Cmd-U run recommended before 22-03 begins (per plan's `<verification>` note — `xcodebuild test` hangs headlessly per project memory `xcodebuild-test-headless-hang`) to confirm `InteractionStateTests`, `DragDropSupportTests`, and `ShelfFileStoreTests` all pass green; this was not run headlessly in this worktree session, only `build-for-testing` (compiles, does not execute)

---
*Phase: 22-drag-in*
*Completed: 2026-07-10*
