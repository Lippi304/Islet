---
status: partial
phase: 21-drag-out
source: [21-VERIFICATION.md]
started: 2026-07-10T03:58:00Z
updated: 2026-07-10T03:58:00Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. Cmd-U Test Pass Confirmation
expected: All ShelfViewStateTests (including the new testShouldBeginShelfItemDragGate) and the unchanged ShelfCoordinatorTests pass green in Xcode (Cmd-U).
result: [pending]

### 2. D-03 Early-Release Timing
expected: Slowly drag a shelf item toward the Desktop and drop it. Island stays open for the entire drag, then returns to normal hover/grace-collapse behavior promptly after the drop (not a 20s wait).
result: [pending]

### 3. Success Criterion #1 — File Lands on Desktop, Item Stays in Shelf
expected: Drop a dragged shelf item on the Desktop. The real file appears there, and the item is STILL present in the shelf strip afterward (D-01 copy semantics).
result: [pending]

### 4. Success Criterion #2 — Missing Backing File Degrades Gracefully
expected: Externally delete a shelf item's backing temp file (lives under $TMPDIR/IsletShelf/<uuid>/), then drag that item. No crash, nothing lands on Finder (a brief phantom drag-ghost that evaporates is acceptable).
result: [pending]

## Summary

total: 4
passed: 0
issues: 0
pending: 4
skipped: 0
blocked: 0

## Gaps
