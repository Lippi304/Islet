---
phase: 22-drag-in
plan: 01
subsystem: notch-window
tags: [appkit, nsdraggingdestination, nspanel, drag-and-drop, spike]

requires:
  - phase: 21-drag-out
    provides: NSItemProvider-based outbound drag from the shelf strip
provides:
  - Throwaway NSDraggingDestination spike scaffold on NotchPanel (registration + 4 NSLog stubs)
  - "Task 2 on-device verdict: PARTIAL -- A1's core technical question CONFIRMED YES, but a new hot-zone-geometry-vs-Mission-Control blocker discovered; 22-02/22-03 must NOT proceed until re-discussed"
affects: [22-02, 22-03]

tech-stack:
  added: []
  patterns:
    - "NSDraggingDestination is an @objc optional category protocol, not superclass members -- a Swift subclass must declare explicit `: NSDraggingDestination` conformance for `draggingEntered`/`draggingUpdated`/`draggingExited`/`performDragOperation` to compile; they are protocol requirement implementations (no `override` keyword), not overrides of an NSWindow/NSPanel superclass member."

key-files:
  created: []
  modified:
    - Islet/Notch/NotchPanel.swift

key-decisions:
  - "Corrected the plan's interfaces-section premise (no explicit conformance needed) with explicit NSDraggingDestination conformance on NotchPanel -- required for Swift to compile the override-style stubs at all (see Deviations)."

patterns-established: []

requirements-completed: []  # SHELF-01/02 NOT complete -- Task 2's verdict is PARTIAL, a new blocker was found; 22-02/22-03 do NOT proceed until re-discussed.

duration: ~15min (Task 1) + on-device human test (Task 2)
completed: 2026-07-10
---

# Phase 22 Plan 01: Drag-Destination Spike Scaffold Summary

**Task 1 (throwaway NSDraggingDestination spike scaffold) implemented, builds clean, committed. Task 2's on-device verdict is PARTIAL: Assumption A1's core technical question is CONFIRMED YES (AppKit drag delivery does reach the click-through NotchPanel -- `draggingEntered` fired), but a new, separate hot-zone-geometry blocker was discovered -- the drop never completes because the drag path crosses macOS's own top-edge Mission Control (F3) trigger before reaching the small hot zone. 22-02/22-03 must NOT proceed as currently scoped; return to `/gsd:discuss-phase 22`.**

## Performance

- **Duration:** ~15 min (Task 1) + one on-device human test session (Task 2)
- **Tasks:** 2 of 2 executed; Task 2's verdict is PARTIAL, not a clean PASS
- **Files modified:** 2 (`Islet/Notch/NotchPanel.swift`, `.planning/phases/22-drag-in/22-RESEARCH.md`)

## Accomplishments
- `NotchPanel.swift` now registers for `.fileURL` dragged types and has 4 throwaway, NSLog-marked `NSDraggingDestination` stub methods (`draggingEntered`, `draggingUpdated`, `draggingExited`, `performDragOperation`).
- `xcodebuild build -scheme Islet -configuration Debug` succeeds.
- Found and fixed a genuine compile-blocking bug in the plan's own premise about Swift/AppKit interop (see Deviations) -- without this fix Task 1's acceptance criteria (BUILD SUCCEEDED) could not have been met at all.
- On-device test (Task 2) confirmed Assumption A1's core technical claim (drag delivery survives `ignoresMouseEvents == true`) -- closing the phase's originally-identified largest risk.
- On-device test also surfaced a NEW, distinct blocker not covered by A1/Pitfall 1: hot-zone geometry vs. macOS's system-level Mission Control top-edge trigger. Documented in `22-RESEARCH.md` Open Question 4.

## Task 2 Verdict: PARTIAL

**On-device test performed by the user** (dragged a file from Finder toward the notch pill, starting outside the hot zone):

- "SPIKE draggingEntered fired" **DID** appear -- Assumption A1's core technical question (does AppKit `NSDraggingDestination` delivery reach a click-through, non-activating `NSPanel` with `ignoresMouseEvents == true`) is **CONFIRMED YES**. Pitfall 1 (event swallowing) does not occur; the Pattern-1 architecture (AppKit-direct registration on `NotchPanel`) is technically sound and receiving events.
- "SPIKE performDragOperation fired" **did NOT** appear -- the drag never completed. User's exact observation (translated from German): "The notch doesn't open to accept the drop. If I go too far up, macOS's Mission Control view (F3) appears, which prevents the whole thing -- meaning the notch itself needs to recognize a bit earlier that it may open when a file is being dragged near it."
- **Root cause:** NOT a recurrence of Pitfall 1. This is a hot-zone geometry / drag-hover auto-expand gap: the hot zone is sized/positioned for mouse hover/click (D-02), not for a drag session, and during a drag (unlike normal hover) the panel does not auto-expand early enough -- so the cursor crosses into macOS's own top-edge Mission Control trigger zone before it reaches the small hot zone, and Mission Control interrupts the drag before a drop can land.
- **Strict acceptance-criteria reading:** the plan required BOTH `draggingEntered` AND `performDragOperation` to fire for PASSED; only the former fired, so by the letter of the criteria this is **FAILED**. Recorded here as PARTIAL because the failure mode is a different, newly-discovered problem (hot-zone geometry) than what FAILED was designed to signal (Pitfall 1 / AppKit not delivering events at all) -- the core architecture question the spike was built to answer is resolved YES.

**Consequence:** D-02 ("reuse the existing hot-zone as-is" for drag-accept) is a locked `CONTEXT.md` decision that this on-device finding contradicts in practice. Per this plan's own resume-signal contract, any outcome short of a clean PASSED means **do not execute 22-02/22-03 as planned**. Return to `/gsd:discuss-phase 22` to decide the fallback (22-RESEARCH.md Open Question 2 and new Open Question 4): a wider always-interactive drop zone during an active drag session, and/or a drag-hover-triggered early auto-expand more forgiving than the click hot zone, positioned to stay clear of the Mission Control trigger geometry.

## Task Commits

1. **Task 1: Scaffold the throwaway drag-destination spike on NotchPanel** - `7571001` (feat)
2. **Task 2: On-device spike verdict (PARTIAL) + RESEARCH.md amendment** - see commits below (docs)

Task 2 required no code changes (the plan specifies "no file edits in this task" beyond the human test itself); the RESEARCH.md amendment recording the verdict is a separate `docs` commit.

_Note: no plan-metadata commit against STATE.md/ROADMAP.md -- those are intentionally NOT touched by this worktree agent (orchestrator owns those after the wave completes, and in any case this plan is not cleanly complete)._

## Files Created/Modified
- `Islet/Notch/NotchPanel.swift` - Added `registerForDraggedTypes([.fileURL])` to `init`, declared `NSDraggingDestination` conformance on the class, and added 4 throwaway stub methods that NSLog when AppKit's drag-destination callbacks fire.
- `.planning/phases/22-drag-in/22-RESEARCH.md` - Amended Assumption A1 / Open Question 1 with the RESOLVED verdict, and added new Open Question 4 documenting the hot-zone-geometry-vs-Mission-Control blocker discovered on-device.

## Decisions Made
- Declared explicit `NSDraggingDestination` conformance on `NotchPanel` rather than relying on bare `override` (see Deviations -- this was a compile-blocking correction, not a design choice, but it does establish the pattern 22-03's real implementation must also follow).
- Task 2's verdict is recorded as PARTIAL, not silently rounded to PASSED or FAILED -- the two sub-questions (does drag delivery survive click-through; does the drop practically complete) have different, independently-actionable answers, and collapsing them into a single verdict would have hidden the newly-discovered hot-zone blocker from the phase-blocking gate.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Plan's "no explicit NSDraggingDestination conformance needed" premise was incorrect for Swift; build failed with "method does not override any method from its superclass"**
- **Found during:** Task 1, first build verification attempt
- **Issue:** The plan's `<interfaces>` section asserted (based on a same-session read of the AppKit.framework `NSDragging.h` header) that because `NSDraggingDestination` is an `@objc optional` Objective-C protocol, `NSWindow`/`NSPanel` "does NOT need an explicit conformance declaration" and a direct subclass `override` of any of its methods is sufficient. This is true for Objective-C's dynamic message dispatch, but **not** for Swift: `NSDraggingDestination` is delivered to `NSWindow` via an `NSObject` category, not as actual superclass members, so the Swift compiler has no superclass method for `override` to bind to. All 4 `override func` stubs failed with `error: method does not override any method from its superclass`.
- **Fix:** Added explicit `NSDraggingDestination` conformance to the class declaration (`final class NotchPanel: NSPanel, NSDraggingDestination`) and removed the `override` keyword from all 4 stub methods -- they now satisfy protocol requirements rather than overriding a superclass implementation. Functionally identical behavior (same method signatures, same NSLog/return-value bodies as specified in the plan); only the Swift-level declaration mechanism changed.
- **Files modified:** `Islet/Notch/NotchPanel.swift`
- **Verification:** `xcodebuild build -scheme Islet -destination 'platform=macOS' -configuration Debug` now succeeds (`BUILD SUCCEEDED`); `grep -q "registerForDraggedTypes"` and a count of 4 for the 4 stub method signatures both pass (grep pattern adjusted to drop the literal `override` substring, since the plan's original grep for `override func draggingEntered|...` would now fail even though the functional intent -- 4 present stub methods -- is met).
- **Committed in:** `7571001` (part of Task 1 commit)

## Known Stubs

The entire Task 1 change is an intentional, plan-specified throwaway spike:
- `draggingEntered`, `draggingUpdated`, `draggingExited`, `performDragOperation` in `Islet/Notch/NotchPanel.swift` do no real drag handling (only `NSLog` + fixed return values). Per the plan, 22-03 Task 1 removes this entire block and replaces it with the real closure-forwarding architecture. Not a defect -- explicitly scoped as throwaway by this plan.

## Self-Check: PASSED

- FOUND: Islet/Notch/NotchPanel.swift
- FOUND: .planning/phases/22-drag-in/22-01-SUMMARY.md
- FOUND: commit 7571001 (Task 1)
- FOUND: commit 1abfa59 (this SUMMARY)
- FOUND: registerForDraggedTypes present in NotchPanel.swift

## Phase Routing: Return to /gsd:discuss-phase 22

Task 2's on-device human verification is complete, but the verdict is PARTIAL (see above), not a clean PASSED. Per this plan's own resume-signal contract and Open Question 2's escalation path (now joined by new Open Question 4), **do not execute 22-02/22-03 as currently scoped**. The project should return to `/gsd:discuss-phase 22` to decide the fallback hot-zone/drag-hover-expand design before any further Phase 22 implementation work proceeds.

**This plan is NOT cleanly complete.** SHELF-01/SHELF-02 remain unvalidated. A1 itself (drag delivery through the click-through panel) is closed and does not need re-testing; the open item is the newly-discovered hot-zone geometry problem.
