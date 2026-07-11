---
phase: 24-drag-in
plan: 01
subsystem: notch-window
tags: [appkit, nsevent, global-monitor, nspasteboard, drag-and-drop, spike]

requires:
  - phase: 23-shell-parity-rewrite
    provides: Reconstructed NotchPanel/NotchWindowController shell with zero behavioral regression (drag-in prerequisite)
provides:
  - Throwaway DEBUG-only .leftMouseDragged/.leftMouseUp global-monitor spike in NotchWindowController
  - "Task 2 on-device verdict: PASSED -- Assumption A1 CONFIRMED across single-file, multi-file, folder, and Escape-cancelled trials"
affects: [24-02]

tech-stack:
  added: []
  patterns:
    - "Inbound-drag detection via NSPasteboard(name: .drag).changeCount polling inside a global .leftMouseDragged monitor -- no NSDraggingDestination registration needed, confirmed reliable on this project's exact click-through NSPanel/run-loop configuration"

key-files:
  created: []
  modified:
    - Islet/Notch/NotchWindowController.swift

key-decisions:
  - "Spike code kept 100% isolated to NotchWindowController.swift, wrapped in #if DEBUG, mirroring the existing mouseMonitor/didLogFirstHover conventions exactly -- zero risk of leaking into Release or touching DragDropSupport.swift/NotchPanel.swift/Shelf files."

patterns-established:
  - "Inbound drag detection: a global .leftMouseDragged monitor + NSPasteboard(name: .drag) changeCount delta (not NSDraggingDestination) is the confirmed-working mechanism for this project's click-through NSPanel; Plan 24-02's real DragApproachDetector should read dragged URLs at .leftMouseUp, not from the tick handler (see Deviations/Findings)."

requirements-completed: []  # SHELF-01 NOT complete -- this plan is an isolated spike only (D-05); real accept/shelf-landing logic ships in Plan 24-02.

duration: ~10min (Task 1) + on-device human test session (Task 2)
completed: 2026-07-11
---

# Phase 24 Plan 01: Drag-Approach Spike Instrumentation Summary

**Task 1 (throwaway DEBUG-only `.leftMouseDragged`/`.leftMouseUp` global-monitor spike) implemented, builds clean in both Debug and Release, committed. Task 2's on-device verdict is PASSED: Assumption A1 is CONFIRMED -- global monitors reliably detect a real Finder-initiated inbound drag via `NSPasteboard(name: .drag)` changeCount deltas, across single-file, multi-file, folder, and Escape-cancelled trials. Plan 24-02 (full accept/shelf-landing implementation) is now unblocked.**

## Performance

- **Duration:** ~10 min (Task 1) + one on-device human test session (Task 2)
- **Tasks:** 2 of 2 executed
- **Files modified:** 1 (`Islet/Notch/NotchWindowController.swift`)

## Accomplishments
- `NotchWindowController.swift` now has three throwaway `#if DEBUG`-only spike properties (`spikeDragApproachMonitor`, `spikeDragEndMonitor`, `spikeDragPasteboardChangeCount`), armed in `start()` right after the existing `mouseMonitor`, and torn down in `deinit` right after `mouseMonitor`'s own removal -- mirroring that property's exact arm/disarm shape.
- Two new DEBUG-only handler methods (`handleSpikeDragApproachTick`, `handleSpikeDragApproachEnd`) log `[SPIKE-24]`-tagged `NSLog` output: changeCount delta, `fileURLs(from:)` (the existing pure seam, reused unchanged), and pointer location.
- `xcodebuild -configuration Debug build` and `xcodebuild -configuration Release build` both succeed; the Release build confirms the spike is excluded (guarded by `#if DEBUG`, never top-level).
- On-device test (Task 2) confirmed Assumption A1 across all required trial types -- closing this phase's single largest unknown.

## Task 2 Verdict: PASSED

**On-device test performed by the user** (real notch MacBook, Cmd-R via Xcode, Console.app filtered on `"[SPIKE-24]"`):

- `.leftMouseDragged` ticks fired mid-drag (not just at release) with correct changeCount delta and correct file URL(s), e.g. `changeCount delta=1 urls=("file:///Users/lippi304/Documents/keyne_spain_austria-1.gif") location={861.4, 677.4}` -- confirmed repeatedly for single-file, multi-file, and folder drags.
- **Multi-file drag** (3 files selected together): all 3 URLs logged together in order, consistently across many repeated trials.
- **Folder drag**: exactly ONE URL logged (the folder's own path, not enumerated contents) -- confirmed on both the `.leftMouseDragged` tick and the final `.leftMouseUp` line.
- **`.leftMouseUp`** logged the correct final pointer location and a still-readable URL across dozens of trials (single file, multi-file, folder, including a `.heic` file from Desktop).
- **Escape-cancelled drag**: explicitly tested by the user -- app continued running normally afterward, no crash, no exception traces, no bogus/stale drop lines around that trial.

All 4 acceptance-criteria items are satisfied. **Assumption A1 is CONFIRMED**: `.leftMouseDragged`/`.leftMouseUp` global monitors reliably fire during a real Finder-initiated inbound drag on this project's exact panel/run-loop configuration.

**Minor timing observation (not a blocker):** in the raw console dump, the `.leftMouseDragged` tick log did not always appear for every single-file trial (some trials showed only the final `.leftMouseUp` line). Every trial's `.leftMouseUp` line, however, had the correct URL. Worth carrying into Plan 24-02: the real accept logic should read dragged URLs at `.leftMouseUp` (the drag-end handler), not rely on the tick handler having fired at least once.

## Task Commits

1. **Task 1: Add throwaway DEBUG-only drag-approach spike instrumentation** - `b1d0a91` (feat)
2. **Task 2: On-device spike validation** - no code changes (plan specifies no file edits in this task); verdict recorded in this SUMMARY

_Note: no plan-metadata commit against STATE.md/ROADMAP.md -- those are intentionally NOT touched by this worktree agent (orchestrator owns those after the wave completes)._

## Files Created/Modified
- `Islet/Notch/NotchWindowController.swift` - Added throwaway `#if DEBUG` spike properties, arm/disarm blocks in `start()`/`deinit`, and two diagnostic handler methods. Zero production logic added; entire change is scoped to be superseded/removed by Plan 24-02.

## Decisions Made
- Spike instrumentation kept 100% isolated to `NotchWindowController.swift`, never touching `DragDropSupport.swift`, `NotchPanel.swift`, `NotchInteractionState.swift`, or any Shelf file -- per plan's explicit isolation requirement (D-05).
- `.leftMouseUp` chosen as the reliable read point for dragged URLs in the real Plan 24-02 implementation, based on the on-device timing observation above.

## Deviations from Plan

None - plan executed exactly as written. Both tasks matched the plan's action/verification/acceptance-criteria specification with no auto-fixes needed.

## Known Stubs

The entire Task 1 change is an intentional, plan-specified throwaway spike:
- `spikeDragApproachMonitor`, `spikeDragEndMonitor`, `handleSpikeDragApproachTick`, `handleSpikeDragApproachEnd` in `Islet/Notch/NotchWindowController.swift` do no real accept/shelf-landing logic (observational NSLog only, no gating). Per the plan, Plan 24-02 supersedes/removes this entire block once the real `DragApproachDetector` is built. Not a defect -- explicitly scoped as throwaway by this plan (D-05).

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness

Plan 24-02 (full accept/shelf-landing implementation) is unblocked -- Assumption A1 is confirmed on this project's exact shell (post Phase-23 rewrite). Plan 24-02 should read dragged URLs at the drag-end (`.leftMouseUp`-equivalent) point, per the minor timing observation above, and can proceed to build the real `DragApproachDetector` global-monitor mechanism plus shelf-landing logic.

## Self-Check: PASSED

- FOUND: Islet/Notch/NotchWindowController.swift (spike instrumentation present, confirmed via grep)
- FOUND: commit b1d0a91 (Task 1)
- FOUND: .planning/phases/24-drag-in/24-01-SUMMARY.md (this file)

---
*Phase: 24-drag-in*
*Completed: 2026-07-11*
