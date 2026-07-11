---
phase: 24-drag-in
plan: 02
subsystem: notch-window
tags: [appkit, nsevent, global-monitor, nspasteboard, drag-and-drop, shelf]

requires:
  - phase: 24-drag-in
    provides: "Plan 24-01's confirmed-reliable .leftMouseDragged/.leftMouseUp global-monitor mechanism (Assumption A1 PASSED)"
provides:
  - "isWithinDragAcceptRegion(_:zone:maxY:) pure geometry gate in DragDropSupport.swift, unit-tested"
  - "Production DragApproachDetector: dragApproachMonitor/dragEndMonitor global monitors, isDragApproaching edge-tracked flag, dragLandingMaxY geometry, auto-expand + shelf-landing wiring in NotchWindowController"
  - "Task 3 on-device UAT confirmed the detection/auto-expand/shelf-landing mechanism itself works reliably, but surfaced an architectural gap: because NotchPanel is deliberately click-through/non-NSDraggingDestination, the real OS drag session falls through to Finder's Desktop underneath, which performs its own default same-volume MOVE -- relocating the user's original file"
affects: [24-03]

tech-stack:
  added: []
  patterns:
    - "Drag-landing accept-region as a pure top-level function (isWithinDragAcceptRegion), mirroring shouldAcceptDrop's testable-without-a-real-drag-session convention"
    - "Edge-tracked isDragApproaching flag mirrors pointerInZone's arm/disarm shape exactly"

key-files:
  created:
    - IsletTests/DragApproachGeometryTests.swift
  modified:
    - Islet/Notch/DragDropSupport.swift
    - Islet/Notch/NotchWindowController.swift

key-decisions:
  - "Task 3's on-device checkpoint was left intentionally OPEN (not approved, not skipped) once UAT revealed the drop-interception gap -- user explicitly routed this to /gsd:discuss-phase 24 rather than patching further in the execution loop."
  - "Resolution: Plan 24-03 (CGEventTap-based DropInterceptTap) was planned to close the gap. Per 24-03's own objective section, its Task 4 on-device checkpoint re-covers every item in this plan's Task 3 checklist plus the new interception checks, so Task 3 is RESOLVED/SUPERSEDED by 24-03 Task 4 rather than being separately re-run."

patterns-established:
  - "dragLandingMaxY: a screen-top landing-margin boundary computed alongside expandedZone/hotZone in positionAndShow(), cleared alongside them in updateVisibility()'s hide branch."

requirements-completed: []  # SHELF-01/SHELF-02 NOT yet complete -- Task 3's on-device acceptance is pending resolution via Plan 24-03 Task 4 (drop-interception fix). Do not mark complete until 24-03 lands.

duration: ~15min (Tasks 1-2) + on-device UAT session (Task 3, surfaced architecture gap) + 2 on-device fixes
completed: 2026-07-11
---

# Phase 24 Plan 02: DragApproachDetector Accept/Shelf-Landing Summary

**Tasks 1-2 (pure geometry seam + production DragApproachDetector monitors + auto-expand + shelf-landing) implemented, committed, and on-device confirmed reliable across repeated trials (with two on-device fixes: `dragLandingMargin` 40→4pt, and a `recheckDragAcceptRegion` self-disarm bug). Task 3's on-device UAT surfaced an architectural gap beyond this plan's scope: the click-through panel never intercepts the real drag session, so Finder's Desktop underneath performs its own default file MOVE. Task 3 is left open by design and resolved by Plan 24-03's CGEventTap-based fix.**

## Performance

- **Duration:** ~15 min (Tasks 1-2) + on-device UAT session (Task 3) + 2 on-device fixes
- **Tasks:** 2 of 3 executed to completion; Task 3 (checkpoint) paused open, superseded by 24-03
- **Files modified:** 3 (`Islet/Notch/DragDropSupport.swift`, `Islet/Notch/NotchWindowController.swift`, `IsletTests/DragApproachGeometryTests.swift`)

## Accomplishments
- `isWithinDragAcceptRegion(_:zone:maxY:)` added as a pure, unit-tested top-level function in `DragDropSupport.swift`, covered by 5 new tests in `IsletTests/DragApproachGeometryTests.swift`.
- Production (non-DEBUG-gated) `dragApproachMonitor`/`dragEndMonitor` global monitors, `isDragApproaching` edge-tracked flag, `dragLandingMaxY` geometry, `handleDragApproachTick`/`recheckDragAcceptRegion`/`handleDragApproachEnd` wired into `NotchWindowController`, replacing Plan 24-01's throwaway spike entirely.
- On-device UAT confirmed: auto-expand on drag-approach, hot/targeted feedback, files/folders landing in the shelf in drop order, no crash across repeated trials, Escape-cancel leaves the island in a normal state, ordinary hover/click/click-through unaffected.
- Two on-device fixes applied and merged during the Task 3 checkpoint loop: `dragLandingMargin` corrected 40→4pt (drops on the pill itself were being rejected), and a `recheckDragAcceptRegion` self-disarm logic bug fixed (`!interaction.isExpanded` was incorrectly gating the sustain/exit condition, not just the rising edge).
- **Gap found:** because `NotchPanel` is deliberately click-through and never a registered `NSDraggingDestination` (this phase's D-05 pivot away from Phase 22's twice-unexplained `draggingEntered` failure), the real OS-level drag session is never intercepted -- it falls through to Finder's Desktop, which performs its own default same-volume MOVE. Confirmed on-device: the original file is relocated to the Desktop even though the shelf also correctly receives its own session copy.

## Task Commits

1. **Task 1: Pure geometry seam + storage wiring + unit test** - `22e4703` (feat)
2. **Task 2: DragApproachDetector monitors + auto-expand + shelf landing** - `f1fdbee` (feat)
3. **On-device fix: dragLandingMargin correction** - `e589150` (fix)
4. **On-device fix: recheckDragAcceptRegion self-disarm bug** - `2bebf84` (fix)

**Plan metadata:** `a7f58ca` (docs: pause Task 3 checkpoint, route to discuss-phase)

_Task 3 (checkpoint:human-verify) produced no code commit of its own — its two on-device findings were addressed via the fix commits above, then the checkpoint was explicitly left open rather than approved._

## Files Created/Modified
- `Islet/Notch/DragDropSupport.swift` - Added `isWithinDragAcceptRegion(_:zone:maxY:)` pure geometry gate
- `Islet/Notch/NotchWindowController.swift` - Removed Plan 24-01's DEBUG spike; added production `DragApproachDetector` monitors, `dragLandingMaxY`/`dragLandingMargin`, auto-expand + shelf-landing logic
- `IsletTests/DragApproachGeometryTests.swift` - 5 unit tests for the new geometry gate

## Decisions Made
- Task 3's checkpoint intentionally left OPEN (not approved, not skipped) once the drop-interception gap was found — user explicitly agreed to route through `/gsd:discuss-phase 24` rather than patch further in the execution loop.
- Root cause identified as architectural, not a small implementation bug: droppy-style apps intercept/consume the drag at a lower level (CGEventTap), which the click-through `NotchPanel` design does not currently do.

## Deviations from Plan

### Auto-fixed Issues (during Task 3's on-device checkpoint loop, within Task 2's existing scope)

**1. [On-device finding] `dragLandingMargin` too large, rejecting valid drops**
- **Found during:** Task 3 on-device UAT
- **Issue:** `dragLandingMargin: CGFloat = 40` rejected drops landing on the pill itself
- **Fix:** Reduced to 4pt
- **Committed in:** `e589150`

**2. [On-device finding] `recheckDragAcceptRegion` self-disarm bug**
- **Found during:** Task 3 on-device UAT
- **Issue:** `!interaction.isExpanded` incorrectly gated the sustain/exit condition, not just the rising edge, causing `isDragApproaching` to disarm itself on the tick right after auto-expand
- **Fix:** Corrected the edge-tracking condition
- **Committed in:** `2bebf84`

---

**Total deviations:** 2 auto-fixed on-device (both narrow, within Task 2's existing scope). **Not fixed / left open:** the drop-interception architecture gap itself — out of this plan's scope by design, routed to discuss-phase and resolved by Plan 24-03.

## Issues Encountered
The click-through panel design (D-05) means the real drag session is never intercepted by Islet — it falls through to Finder's Desktop, which performs its own default same-volume file MOVE. This is a data-loss risk (the user's original file gets relocated) beyond a UI bug. Resolved via `/gsd:discuss-phase 24` → Plan 24-03 (`DropInterceptTap`, a `CGEventTap`-based fix).

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness

**Task 3's checkpoint is RESOLVED/SUPERSEDED, not separately re-run:** Plan 24-03's Task 4 on-device checkpoint re-covers every item in this plan's Task 3 checklist (single-file, multi-file+folder, hot feedback, repeated trials, Escape-cancel, ordinary-interaction non-regression) plus the new interception-specific checks. Once 24-03 Task 4 returns "approved", SHELF-01/SHELF-02 are fully complete and `REQUIREMENTS.md` should be updated to reflect both this plan's and 24-03's acceptance together.

## Self-Check: PASSED

- FOUND: Islet/Notch/DragDropSupport.swift (isWithinDragAcceptRegion present)
- FOUND: Islet/Notch/NotchWindowController.swift (DragApproachDetector present)
- FOUND: commits 22e4703, f1fdbee, e589150, 2bebf84
- FOUND: .planning/phases/24-drag-in/24-02-SUMMARY.md (this file)

---
*Phase: 24-drag-in*
*Completed: 2026-07-11*
