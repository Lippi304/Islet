---
phase: 24-drag-in
plan: 03
subsystem: notch-shell
tags: [swift, appkit, cgeventtap, accessibility, drag-drop]

# Dependency graph
requires:
  - phase: 24-drag-in (24-02)
    provides: DragApproachDetector monitors + auto-expand + shelf landing (isDragApproaching edge-tracked flag, handleDragApproachEnd shelf-landing logic)
provides:
  - "Task 1 only: a throwaway #if DEBUG CGEventTap spike in NotchWindowController.swift that probes whether swallowing the terminating .leftMouseUp at .cgSessionEventTap/.defaultTap stops Finder's Desktop from relocating the original dragged file (Assumption A5), and whether the existing dragEndMonitor still fires for a tap-swallowed event (Assumption A7 / Pitfall A)"
affects: [24-drag-in remaining plan work, DropInterceptTap production implementation]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Throwaway #if DEBUG on-device spike pattern (mirrors Plan 24-01), fully excluded from Release builds"
    - "CGEventTap capture-less C-function-pointer callback threading self via Unmanaged/userInfo (first use of this idiom in the codebase)"

key-files:
  created: []
  modified:
    - Islet/Notch/NotchWindowController.swift

key-decisions:
  - "kAXTrustedCheckOptionPrompt (an Unmanaged<CFString>) must be unwrapped via .takeUnretainedValue() before use as a CFDictionary key — the RESEARCH.md interface sketch omitted this and the plain form does not compile"

patterns-established: []

requirements-completed: []  # SHELF-01/SHELF-02 NOT complete — plan paused at Task 2 checkpoint, Tasks 3-4 not yet executed

# Metrics
duration: ~15min (Task 1 only; plan paused at Task 2 checkpoint)
completed: 2026-07-11
---

# Phase 24 Plan 03: Drop-Interception CGEventTap Spike (Task 1 of 4) Summary

**Task 1 (throwaway DEBUG-only CGEventTap spike) is complete and committed; the plan is PAUSED at Task 2's blocking on-device human-verify checkpoint — Tasks 3-4 have NOT been executed.**

## Performance

- **Tasks completed:** 1 of 4 (Task 1)
- **Files modified:** 1
- **Status:** Paused at Task 2 checkpoint (blocking on-device hardware verification — cannot be automated or self-approved)

## Accomplishments

- Added a fully `#if DEBUG`-gated CGEventTap spike to `NotchWindowController.swift`:
  - `spikeInterceptTap`/`spikeInterceptRunLoopSource` properties
  - `armSpikeDropInterceptTap()`: logs `AXIsProcessTrusted()` (pre-request), then calls `AXIsProcessTrustedWithOptions(prompt:true)` and logs its result, then creates a `.cgSessionEventTap`/`.defaultTap` tap masked to `.leftMouseUp` only. The callback swallows (`return nil`) only when the controller's existing `isDragApproaching` flag is true, passing through every other event unmodified.
  - A temporary `NSLog` as the first statement in the existing (production) `handleDragApproachEnd()`, to observe on-device whether that method still fires for a tap-swallowed `.leftMouseUp`.
  - `deinit` teardown of the run-loop source and tap.
- Verified both `Debug` and `Release` configurations build clean, and confirmed via `strings` on the Release binary that none of the spike's `SPIKE-24-DIT` log tags or symbol names leak into the Release build (0 matches).

## Task Commits

1. **Task 1: Throwaway DEBUG-only CGEventTap spike instrumentation** - `10af783` (feat)

_Tasks 2-4 not yet executed — see "Plan Status" below._

## Files Created/Modified

- `Islet/Notch/NotchWindowController.swift` - Added the DEBUG-only spike properties, `armSpikeDropInterceptTap()`, a temporary diagnostic log line in `handleDragApproachEnd()`, and `deinit` teardown for the spike's tap/run-loop source.

## Decisions Made

- `kAXTrustedCheckOptionPrompt` is an `Unmanaged<CFString>`, not a `CFString` — RESEARCH.md's interface sketch used it directly as a dictionary key, which does not compile. Fixed by calling `.takeUnretainedValue()` before use. This is the same key in both the Task 1 spike and will apply identically to Task 3's production `DropInterceptTap.start()`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `kAXTrustedCheckOptionPrompt` unwrap required for compile**
- **Found during:** Task 1, first Debug build attempt
- **Issue:** `AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt: true] as CFDictionary)` fails to compile — `cannot convert value of type 'Unmanaged<CFString>' to expected dictionary key type 'AnyHashable'`. This exact form appears in the plan's `<action>` text (Task 1) and will recur verbatim in Task 3.
- **Fix:** Used `kAXTrustedCheckOptionPrompt.takeUnretainedValue()` as the dictionary key.
- **Files modified:** `Islet/Notch/NotchWindowController.swift`
- **Verification:** `xcodebuild -configuration Debug build` succeeds.
- **Committed in:** `10af783` (Task 1 commit)

**2. [Note, not a deviation requiring action] `#if DEBUG` count acceptance criterion**
- The plan's acceptance criteria offered two ways to confirm Release exclusion: (a) a `strings`-based check on the built Release binary for `SPIKE-24-DIT`/`spikeInterceptTap`, and (b) a "simpler equivalent" heuristic that `grep -c "#if DEBUG"` increases by exactly 2. This implementation used 5 separate `#if DEBUG` blocks (properties, call site, method definition, the `handleDragApproachEnd` diagnostic line, and `deinit` teardown) rather than consolidating into 2, so the count increased from 5 to 11 (not +2). The primary, authoritative check — (a), the Release-binary `strings` scan — returned 0 matches, positively confirming the spike is excluded from Release. The heuristic in (b) does not hold numerically but the actual intent it was checking (DEBUG-only exclusion) is directly verified. No action taken; documented for transparency.

---

**Total deviations:** 1 auto-fixed (Rule 1 - compile-blocking bug), 1 documentation note (no code change).
**Impact on plan:** Both necessary for Task 1 to build; no scope creep.

## Issues Encountered

None beyond the compile-fix above.

## Plan Status: PAUSED at Task 2 (blocking human-verify checkpoint)

Per this plan's `<plan_context>`, Task 2 requires genuine on-device hardware verification (dragging real files from Finder, observing macOS permission prompts, confirming file relocation behavior) that cannot be automated or self-approved by this agent, regardless of auto-mode configuration. Task 2's outcome gates whether Task 3 (production `DropInterceptTap.swift`) and Task 4 (final on-device UAT) execute at all — per D-13, this is capped at 2 on-device validation rounds.

**Tasks 3-4 have NOT been executed.** SHELF-01/SHELF-02 are NOT complete. `REQUIREMENTS.md` has not been touched.

See the accompanying checkpoint message (returned to the orchestrator) for the exact Xcode/Finder GUI steps needed to perform Task 2's on-device validation.

## User Setup Required

None - no external service configuration required. Task 2 itself requires the user (or an agent with Xcode GUI access) to build/run on-device and grant an Accessibility permission prompt if one appears — this is the checkpoint's own content, not separate setup.

## Next Phase Readiness

- Blocked pending Task 2's on-device checkpoint reply ("approved" / narrow-bug retry / "failed").
- If "approved": resume with Task 3 (production `DropInterceptTap.swift`), then Task 4 (final UAT, incl. a Release-configuration pass).
- If "failed" (D-13's 2-round cap exhausted): this plan stops here; Tasks 3-4 are not built; route to `/gsd:discuss-phase 24` to scope D-14's move-back mitigation as its own follow-up plan.

---
*Phase: 24-drag-in*
*Completed: N/A — paused mid-plan at Task 2 checkpoint (2026-07-11)*
