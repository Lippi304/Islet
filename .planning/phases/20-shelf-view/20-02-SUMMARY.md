---
phase: 20-shelf-view
plan: 02
subsystem: controller
tags: [swiftui, appkit, notch-window-controller, shelf]

# Dependency graph
requires:
  - phase: 20-shelf-view
    plan: 01
    provides: ShelfViewState, shouldOpenShelfItem(fileExists:), NotchPillView.shelfRowHeight, shelf-aware blobShape
provides:
  - Real ShelfCoordinator ownership wired into NotchWindowController (replaces Plan 20-01's empty placeholder)
  - handleShelfItemTap/handleShelfItemDelete/handleShelfClearAll — live shelf interaction handlers
  - Panel-height reservation for the shelf band (unconditional, never a live NSPanel resize)
  - DEBUG hand-seed of 3 real on-disk sample shelf items for on-device UAT
  - ShelfViewStateTests.swift — resync contract + D-04 gate coverage
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Controller-owned coordinator + resync: every ShelfCoordinator mutation (append/remove/clear) is immediately followed by shelfViewState.items = shelfCoordinator.logic.items — the one place the published mirror is ever written, mirroring nowPlayingState/outfitState's ownership contract"
    - "D-04 guard-before-side-effect: shouldOpenShelfItem(fileExists:) is checked and returns early BEFORE NSWorkspace.shared.open is ever called"
    - "Unconditional panel-height reservation: the NSPanel's expandedFrame always adds NotchPillView.shelfRowHeight, independent of whether the shelf currently has items — the panel never resizes live; only the visible blobShape height is conditional"

key-files:
  created:
    - IsletTests/ShelfViewStateTests.swift
  modified:
    - Islet/Notch/NotchWindowController.swift

key-decisions:
  - "Task 1/Task 2 edits were interleaved during drafting but split into 2 separate commits before landing (temporarily removed the DEBUG seed block, committed the coordinator wiring, then re-added and committed the seed) — keeps atomic per-task history despite editing the same file twice in sequence"
  - "seedDebugShelfItems() uses try? for both file-write and makeSessionCopy, skipping any seed file that fails rather than crashing DEBUG launch — matches the plan's 'via try?, skipping on failure' instruction"

patterns-established: []

requirements-completed: [SHELF-04, SHELF-05, SHELF-07]

# Metrics
duration: ~12min
completed: 2026-07-10
---

# Phase 20 Plan 02: NotchWindowController Shelf Wiring Summary

**`NotchWindowController` now owns a real `ShelfCoordinator`, routes tap/delete/clear-all through it with the D-04 missing-file guard, reserves the panel's window height for the shelf band unconditionally, and hand-seeds 3 real on-disk sample files in DEBUG builds.**

## Performance

- **Duration:** ~12 min (wall time between first and last task commit)
- **Completed:** 2026-07-10
- **Tasks:** 3/3 completed
- **Files modified:** 2 (1 created, 1 modified)

## Accomplishments

- Replaced Plan 20-01's empty `shelfViewState` placeholder scope with a real `private let shelfCoordinator = ShelfCoordinator()`, wired `onShelfItemTap`/`onShelfItemDelete`/`onShelfClearAll` into `makeRootView`'s `NotchPillView(...)` call
- `handleShelfItemTap` guards with `shouldOpenShelfItem(fileExists:)` before any `NSWorkspace.shared.open` call (D-04 silent no-op on a vanished local copy)
- `handleShelfItemDelete`/`handleShelfClearAll` call the locked Phase-19 `ShelfCoordinator.remove`/`clear` (real disk-IO cleanup) then resync `shelfViewState.items`
- `positionAndShow`'s `expandedFrame` now adds `NotchPillView.shelfRowHeight` to `expandedSize.height` unconditionally — the panel window reserves the shelf band up front so a live NSPanel resize is never needed, while the visible `blobShape` still only grows conditionally
- `seedDebugShelfItems()` (`#if DEBUG`-gated, called from `start()`) writes 3 real files (`Report.pdf`, `Photo.jpg`, `Notes.txt`) to `NSTemporaryDirectory()/IsletShelfSeed/`, copies each through `ShelfFileStore.makeSessionCopy`, and appends real `ShelfItem`s to the coordinator — confirmed absent from a Release build via the `#if DEBUG` guard (Release build succeeded with zero seed code compiled in)
- `ShelfViewStateTests.swift` added: 3 real-disk-IO resync tests (append/remove/clear) + 1 pure `shouldOpenShelfItemGate` test
- `xcodebuild build` (Debug), `xcodebuild build` (Release), and `xcodebuild build-for-testing` (Debug) all succeeded after their respective tasks

## Task Commits

1. **Task 1: Own ShelfCoordinator, wire handlers into makeRootView, reserve panel height** - `9936f28` (feat)
2. **Task 2: DEBUG hand-seed real on-disk sample files** - `5d023d6` (feat)
3. **Task 3: ShelfViewStateTests — resync contract + D-04 gate** - `01c8911` (test)

## Files Created/Modified

- `Islet/Notch/NotchWindowController.swift` - `shelfCoordinator` property; 3 shelf handlers; `makeRootView` wiring; `positionAndShow` panel-height reservation; `seedDebugShelfItems()` DEBUG hand-seed + its `start()` call site
- `IsletTests/ShelfViewStateTests.swift` - `ShelfViewStateTests: XCTestCase` — resync contract (append/remove/clear) + `shouldOpenShelfItemGate`

## Decisions Made

- Task 1 and Task 2 both touch `NotchWindowController.swift`; to keep per-task commits atomic, the DEBUG seed block was drafted, then temporarily removed via Edit, Task 1 built + committed alone, then the seed block was re-added, built, and committed as Task 2 — no functional difference from writing them sequentially, just commit hygiene.
- Verified the D-04 guard textually precedes `NSWorkspace.shared.open` (acceptance criterion) — `guard shouldOpenShelfItem(...) else { return }` is the very first line of `handleShelfItemTap`.

## Deviations from Plan

None - plan executed exactly as written. The Plan 20-01 upstream note (empty `shelfViewState` placeholder in `NotchWindowController`) was the expected starting state and was replaced/extended exactly as scoped.

## Known Stubs

None. The shelf strip is now fully live: `shelfViewState.items` is driven by the real `ShelfCoordinator`, seeded with real on-disk sample files in DEBUG builds, and the 3 handlers perform real disk-IO through the already-shipped, locked Phase-19 `ShelfCoordinator`/`ShelfFileStore`.

## Issues Encountered

None.

## Next Phase Readiness

- The shelf strip is now interactive end-to-end (tap-to-open with D-04 guard, per-item delete, delete-all) and visually verifiable on-device via the DEBUG hand-seed.
- Phase 21 (Drag-Out) can build on `shelfCoordinator`/`shelfViewState` as the live data source; Phase 22 (Drag-In) replaces the DEBUG hand-seed's manual `ShelfCoordinator.append` calls with real `NSItemProvider` drag delivery.
- Manual on-device UAT still needed (per plan's `<verification>` wave gate): Cmd-U confirms `ShelfViewStateTests` pass; on-device confirms the shelf strip renders 3 real items, per-item trash removes one, the far-right trash clears all, clicking an item opens it, and the panel never clips.

## Self-Check: PASSED

Both modified/created files confirmed present on disk; all 3 task commit hashes (9936f28, 5d023d6, 01c8911) confirmed in git log.
