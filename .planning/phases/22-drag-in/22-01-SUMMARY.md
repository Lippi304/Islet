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
  - Task 2 (on-device drag test) is a BLOCKING checkpoint -- not yet executed, requires human verification
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

requirements-completed: []  # SHELF-01/02 NOT complete -- this plan is a diagnostic spike; Task 2 (on-device verdict) is unresolved, blocking 22-02/22-03.

duration: ~15min (Task 1 only; Task 2 blocked)
completed: 2026-07-10
---

# Phase 22 Plan 01: Drag-Destination Spike Scaffold Summary

**Task 1 (throwaway NSDraggingDestination spike scaffold) is implemented, builds clean, and committed. Task 2 (the on-device interactive drag test that produces the PASS/FAIL verdict for Assumption A1) is a blocking human-verification checkpoint that has NOT been executed -- this plan is incomplete until a human runs the on-device test.**

## Performance

- **Duration:** ~15 min (Task 1 only)
- **Tasks:** 1 of 2 completed (Task 2 is a blocking checkpoint requiring human on-device action)
- **Files modified:** 1

## Accomplishments
- `NotchPanel.swift` now registers for `.fileURL` dragged types and has 4 throwaway, NSLog-marked `NSDraggingDestination` stub methods (`draggingEntered`, `draggingUpdated`, `draggingExited`, `performDragOperation`).
- `xcodebuild build -scheme Islet -configuration Debug` succeeds.
- Found and fixed a genuine compile-blocking bug in the plan's own premise about Swift/AppKit interop (see Deviations) -- without this fix Task 1's acceptance criteria (BUILD SUCCEEDED) could not have been met at all.

## Task Commits

1. **Task 1: Scaffold the throwaway drag-destination spike on NotchPanel** - `7571001` (feat)

Task 2 (checkpoint:human-verify, gate="blocking") not yet executed -- no commit.

_Note: no plan-metadata commit yet -- this SUMMARY.md commit itself is the only remaining commit for this worktree agent; STATE.md/ROADMAP.md are intentionally NOT touched (orchestrator owns those after the wave completes)._

## Files Created/Modified
- `Islet/Notch/NotchPanel.swift` - Added `registerForDraggedTypes([.fileURL])` to `init`, declared `NSDraggingDestination` conformance on the class, and added 4 throwaway stub methods that NSLog when AppKit's drag-destination callbacks fire.

## Decisions Made
- Declared explicit `NSDraggingDestination` conformance on `NotchPanel` rather than relying on bare `override` (see Deviations -- this was a compile-blocking correction, not a design choice, but it does establish the pattern 22-03's real implementation must also follow).

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

## Self-Check: PENDING

See below -- self-check performed after this section.

## CHECKPOINT: Task 2 Blocked -- On-Device Human Verification Required

Task 2 of this plan is `type="checkpoint:human-verify" gate="blocking"` and requires a human to physically Build+Run the app in Xcode and perform an interactive on-device drag test. This cannot be performed by an automated agent. See the CHECKPOINT REACHED report returned to the orchestrator for full details (what to verify, exact steps, and the PASSED/FAILED resume-signal contract).

**This plan is NOT complete.** Do not mark SHELF-01/SHELF-02 as validated, and do not proceed to 22-02/22-03, until Task 2's on-device verdict is recorded.
