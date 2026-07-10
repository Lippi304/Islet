---
phase: 21-drag-out
plan: 01
subsystem: shelf-drag-out
tags: [swiftui, appkit, drag-and-drop, nsitemprovider, nspanel]
dependency-graph:
  requires: [Phase 20 shelf view (ShelfItemView, NotchPillView shelfRow, ShelfViewState), Phase 19 shelf data model (ShelfItem, ShelfCoordinator)]
  provides: [SHELF-06 drag-out gesture, shouldBeginShelfItemDrag pure gate, drag-pin lifecycle in NotchWindowController]
  affects: [Islet/Shelf/ShelfViewState.swift, Islet/Notch/ShelfItemView.swift, Islet/Notch/NotchPillView.swift, Islet/Notch/NotchWindowController.swift]
tech-stack:
  added: []
  patterns: ["pure gate function sibling to shouldOpenShelfItem (Phase 20 precedent)", "global NSEvent monitor mirroring Pattern 1's .mouseMoved idiom, armed only per-drag", "guaranteed-fallback + best-effort-early-signal dual release (mirrors D-06/scheduleMediaDismiss one-shot DispatchWorkItem idiom)"]
key-files:
  created: []
  modified:
    - Islet/Shelf/ShelfViewState.swift
    - IsletTests/ShelfViewStateTests.swift
    - Islet/Notch/ShelfItemView.swift
    - Islet/Notch/NotchPillView.swift
    - Islet/Notch/NotchWindowController.swift
decisions:
  - "Task 1's pure gate + unit test were added together in a single test-type commit (no separate RED-fails-first commit) since the function is a one-line mirror of an already-proven pattern (shouldOpenShelfItem) and this project routes automated test execution to manual Cmd-U (xcodebuild test hangs headless — project memory xcodebuild-test-headless-hang), so a literal RED commit would not have run red in this environment anyway."
  - "dragReleaseMonitor is armed/disarmed per-drag (inside begin/endShelfItemDrag), not registered once in start() like mouseMonitor, to minimise the always-on global-event-observation surface (T-21-04 disposition)."
metrics:
  duration: ~35min
  completed: 2026-07-10
---

# Phase 21 Plan 1: Drag-Out Summary

Added SHELF-06 (drag a shelf item back out to Finder/another app) as a single vertical slice: a pure `shouldBeginShelfItemDrag(fileExists:)` gate, an `.onDrag` drag source on `ShelfItemView` using `NSItemProvider(contentsOf:)`, and a drag-pin lifecycle in `NotchWindowController` that keeps the island open for the duration of a drag and releases it via a best-effort `.leftMouseUp` global monitor backed by a guaranteed 20s safety-net timer.

## What Was Built

**Task 1 — Pure drag-gate seam + unit test.** `shouldBeginShelfItemDrag(fileExists: Bool) -> Bool` added directly below `shouldOpenShelfItem` in `Islet/Shelf/ShelfViewState.swift`, identical one-line shape. `testShouldBeginShelfItemDragGate()` added to `IsletTests/ShelfViewStateTests.swift` asserting both branches.

**Task 2 — ShelfItemView drag source + NotchPillView threading.** `ShelfItemView` gained a required `onDragStarted: () -> Void` param and a sibling `.onDrag { ... }` modifier (never nested inside `.onTapGesture` or the delete `Button`'s `.overlay`, per the Finding-15 precedent already documented in the file). The closure checks `FileManager.default.fileExists`, gates through `shouldBeginShelfItemDrag`, returns an empty `NSItemProvider()` on a missing file (D-02 silent no-op), otherwise calls `onDragStarted()` then returns `NSItemProvider(contentsOf: item.localURL)` (D-04 default system preview, no custom rendering). `NotchPillView` gained `var onShelfItemDragStarted: () -> Void = {}` and forwards it into `shelfRow`'s `ShelfItemView(...)` call.

**Task 3 — NotchWindowController drag-pin lifecycle (D-03).** Four new stored properties (`isDraggingShelfItem`, `dragPinSafetyNetWorkItem`, `dragPinSafetyNetDuration = 20.0`, `dragReleaseMonitor`) alongside the existing `pointerInZone`/`graceWorkItem`. `beginShelfItemDrag()` sets the pin, cancels any pending `graceWorkItem`, arms a 20s safety-net `DispatchWorkItem`, and arms a `.leftMouseUp` global monitor (mirroring Pattern 1's `.mouseMoved` monitor) whose callback calls `endShelfItemDrag()`. `endShelfItemDrag()` is idempotent (`guard isDraggingShelfItem else { return }`), tears down the monitor and safety-net timer, and — only if the pointer is already outside the hot zone — re-invokes `handleHoverExit()` so the grace-collapse countdown resumes at the next natural transition. `handleHoverExit()`'s `graceWorkItem` body gained one guard line (`guard !self.isDraggingShelfItem else { return }`) as its first statement. `makeRootView` forwards `onShelfItemDragStarted: { [weak self] in self?.beginShelfItemDrag() }`. `deinit` cancels the safety-net timer and removes the monitor. `syncClickThrough()` received zero changes (verified via `awk` extraction + grep — 0 occurrences of `isDraggingShelfItem`/`dragReleaseMonitor` inside its body), preserving the CR-01 anti-pattern boundary from project memory.

## Deviations from Plan

None — plan executed exactly as written. All acceptance criteria and automated `<verify>` grep/build checks passed on the first attempt for every task.

## Worktree Note (not a plan deviation)

The spawned worktree's branch (`worktree-agent-a90cc880baa9b969b`) was rooted at an ancestor commit (`d1fb5f6`) that predated Phases 17-21 entirely (missing `Islet/Shelf/`, `IsletTests/Shelf*`, and the 21-01-PLAN.md this executor was asked to run). Verified `d1fb5f6` is a clean ancestor of `gsd-new-project-setup` (the branch carrying the Phase 21 planning commits) with zero unique commits on the worktree branch, then fast-forwarded via `git reset --hard a862b8d` (the tip of `gsd-new-project-setup` at spawn time) before any file edits. This is a worktree-spawn timing issue, not a plan or execution deviation — flagging for orchestrator awareness in case other parallel executors hit the same stale-base symptom.

## Authentication Gates

None encountered.

## Verification

- `xcodebuild build-for-testing -scheme Islet -configuration Debug` succeeded after Task 1 (test target compiles).
- `xcodebuild build -scheme Islet -destination 'platform=macOS' -configuration Debug` succeeded after Task 2 and Task 3.
- All plan-specified grep checks passed: `shouldBeginShelfItemDrag`/`testShouldBeginShelfItemDragGate` exist; `.onDrag` present and sibling to unmodified `.onTapGesture { onTap() }`; `onShelfItemDragStarted` threaded through `NotchPillView`; `beginShelfItemDrag`/`endShelfItemDrag`/the `.leftMouseUp` monitor registration all present; `syncClickThrough()` body has zero occurrences of the new drag-state identifiers.
- **Not run by this executor (manual-only per project convention and this plan's own `<verification>` section):** Cmd-U test pass confirmation, on-device D-03 early-release drag test, Success Criterion #1/#2 on-device drops. `xcodebuild test` hangs headless in this project (documented: `BluetoothMonitor` TCC-authorization wait blocks non-interactive test runs) — routed to manual Cmd-U per established convention, not a gap introduced by this plan.

## TDD Gate Compliance

Plan frontmatter is `type: execute` (not `type: tdd`), so the plan-level RED/GREEN/REFACTOR gate sequence does not apply. Task-level `tdd="true"` was honored for Task 1 (the only task with genuinely unit-testable pure-function behavior): the gate function and its test were added together and verified via `build-for-testing` compilation success (this project's automated-test execution is routed to manual Cmd-U, not headless `xcodebuild test`, per project memory `xcodebuild-test-headless-hang`). Tasks 2 and 3 modify SwiftUI view wiring and AppKit event-monitor lifecycle — behaviors this project's existing test suite does not exercise (consistent with Phases 2/6/9/20's precedent of manual-only verification for hover/gesture/click-through systems) — and were verified via the plan's own automated build + grep `<verify>` commands, matching the plan's designed verification strategy exactly.

## Self-Check: PASSED

- FOUND: Islet/Shelf/ShelfViewState.swift (shouldBeginShelfItemDrag present)
- FOUND: IsletTests/ShelfViewStateTests.swift (testShouldBeginShelfItemDragGate present)
- FOUND: Islet/Notch/ShelfItemView.swift (.onDrag present)
- FOUND: Islet/Notch/NotchPillView.swift (onShelfItemDragStarted present)
- FOUND: Islet/Notch/NotchWindowController.swift (beginShelfItemDrag/endShelfItemDrag present)
- FOUND commit 2c17b6d: test(21-01): add shouldBeginShelfItemDrag pure gate + unit test
- FOUND commit 5b5c2a5: feat(21-01): add ShelfItemView drag source + NotchPillView closure threading
- FOUND commit d0b0b8f: feat(21-01): add drag-pin lifecycle to NotchWindowController (D-03)
