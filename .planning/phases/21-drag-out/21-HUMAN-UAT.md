---
status: resolved
phase: 21-drag-out
source: [21-VERIFICATION.md]
started: 2026-07-10T03:58:00Z
updated: 2026-07-10T15:55:00Z
---

## Current Test

[complete]

## Tests

### 1. Cmd-U Test Pass Confirmation
expected: All ShelfViewStateTests (including the new testShouldBeginShelfItemDragGate) and the unchanged ShelfCoordinatorTests pass green in Xcode (Cmd-U).
result: passed — confirmed green in Xcode.

### 2. D-03 Early-Release Timing
expected: Slowly drag a shelf item toward the Desktop and drop it. Island stays open for the entire drag, then returns to normal hover/grace-collapse behavior promptly after the drop (not a 20s wait).
result: passed — collapsed promptly after drop.

### 3. Success Criterion #1 — File Lands on Desktop, Item Stays in Shelf
expected: Drop a dragged shelf item on the Desktop. The real file appears there, and the item is STILL present in the shelf strip afterward (D-01 copy semantics).
result: passed — file landed, item remained in shelf.

### 4. Success Criterion #2 — Missing Backing File Degrades Gracefully
expected: Externally delete a shelf item's backing temp file (lives under $TMPDIR/IsletShelf/<uuid>/), then drag that item. No crash, nothing lands on Finder (a brief phantom drag-ghost that evaporates is acceptable).
result: passed — no crash, nothing landed on Finder.

## Summary

total: 4
passed: 4
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps

None outstanding. Two additional issues surfaced during this UAT round, both diagnosed and fixed before sign-off:

1. **Shelf row invisible despite correct AppKit panel sizing** — root cause: `NotchPillView.body`'s outer `ZStack` container was still hardcoded to `Self.expandedSize.height` (pre-Phase-20 constant), clipping `blobShape`'s own `+shelfRowHeight` growth before it reached the screen, even though the NSPanel itself was sized correctly. Fixed in commit `3b38f33` (outer `.frame(height:)` now grows with `shelfViewState.items`).
2. **UAT feedback (out of original D-02 scope, explicitly authorized by user to add now)** — a shelf item whose backing file was deleted externally stayed inert until manually trashed, cluttering the shelf. Added `ShelfCoordinator.pruneMissingFiles()`, called on hover-click expand, in commit `dfbde2d`. Covered by new tests `testPruneMissingFilesRemovesOnlyItemsWithDeletedBackingFile` / `testPruneMissingFilesOnFullyIntactShelfIsANoOp`.
