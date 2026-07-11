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
  - "Islet/Notch/DropInterceptTap.swift: a session CGEventTap that swallows the terminating .leftMouseUp for an armed drag-approach region, invoking handleDragApproachEnd() directly from the swallow branch before returning nil — stops Finder's Desktop from relocating the original dragged file"
  - "NotchWindowController wiring: dropInterceptTap lazily constructed+started on the first real drag-approach edge (D-11), stop() in deinit"
  - "On-device confirmation (Task 2 spike) of Assumption A5 (swallow prevents relocation), A7/Pitfall A (existing dragEndMonitor never fires for a tap-swallowed event — direct invocation was the right call), and A6 (Accessibility, not Input Monitoring, gates tap creation)"
affects: [24-drag-in Task 4 UAT, SHELF-01/SHELF-02 requirement closure]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "CGEventTap capture-less C-function-pointer callback threading self via Unmanaged/userInfo (first use of this idiom in the codebase)"
    - "DropInterceptTap mirrors BluetoothMonitor's owning-type lifecycle shape: idempotent start(), nonisolated stop(), periodic health-check timer for Pitfall C (silent Release re-sign inertness)"

key-files:
  created:
    - Islet/Notch/DropInterceptTap.swift
  modified:
    - Islet/Notch/NotchWindowController.swift
    - project.yml

key-decisions:
  - "kAXTrustedCheckOptionPrompt (an Unmanaged<CFString>) must be unwrapped via .takeUnretainedValue() before use as a CFDictionary key — the RESEARCH.md interface sketch omitted this and the plain form does not compile"
  - "On-device Task 2 finding: the existing dragEndMonitor (NSEvent global monitor) never fires for a .leftMouseUp the tap has swallowed — confirms Pitfall A's direct-invocation design (onIntercept() calling handleDragApproachEnd() from inside the tap's swallow branch) was necessary, not just defensive"

patterns-established:
  - "Pattern: DropInterceptTap-shaped small owning type for any future raw-HID-event interception need — BluetoothMonitor-lifecycle-shaped (init/start/stop/deinit), never touches ignoresMouseEvents/syncClickThrough() (orthogonal to click-through hit-testing)"

requirements-completed: []  # SHELF-01/SHELF-02 NOT YET marked complete — plan paused at Task 4 checkpoint (final on-device UAT still pending)

# Metrics
duration: ~45min so far (Tasks 1-3; plan paused at Task 4 checkpoint)
completed: 2026-07-11
---

# Phase 24 Plan 03: Drop-Interception CGEventTap (Tasks 1-3 of 4) Summary

**Production `DropInterceptTap` (session CGEventTap swallowing the terminating `.leftMouseUp`, invoking shelf-landing directly) is built and wired in; Tasks 1-3 complete and committed. The plan is PAUSED at Task 4's blocking on-device human-verify checkpoint (full UAT + a Release-configuration pass) — SHELF-01/SHELF-02 are not yet marked complete.**

## Performance

- **Tasks completed:** 3 of 4 (Tasks 1, 2, 3 — Task 2 was a human-verify checkpoint, approved by the user)
- **Files modified:** 3 (1 new: `DropInterceptTap.swift`)
- **Status:** Paused at Task 4 checkpoint (blocking on-device hardware UAT — cannot be automated or self-approved)

## Accomplishments

- **Task 1:** Built a throwaway `#if DEBUG` CGEventTap spike in `NotchWindowController.swift` to probe Assumption A5 (does swallowing `.leftMouseUp` at `.cgSessionEventTap`/`.defaultTap` stop Finder's Desktop from relocating the file) before writing any production code.
- **Task 2 (on-device checkpoint, approved):**
  - Assumption A5 **confirmed**: repeated drags showed `SWALLOWING this mouseUp` in Console, and the original file was never relocated to the Desktop.
  - Assumption A7 / Pitfall A **confirmed**: for every swallowed `.leftMouseUp`, the existing `dragEndMonitor` (NSEvent global monitor) never fired — validating that Task 3's design (invoking `handleDragApproachEnd()` directly from the tap's swallow branch) is load-bearing, not just defensive.
  - Assumption A6 **confirmed**: Accessibility (not Input Monitoring) is what gates tap creation — `AXIsProcessTrusted`/`AXIsProcessTrustedWithOptions` both returned `true` (already granted from an earlier session).
  - Ordinary clicking/dragging in other apps (Safari/TextEdit) unaffected; an Escape-cancelled drag left the island in a normal (not stuck) state.
  - One investigation round was needed first: the user's initial Console.app capture showed 0 of the spike's launch-time logs (only the existing `handleDragApproachEnd()` diagnostic line fired, 8/8 times, always `isDragApproaching=false`). Code review confirmed `armSpikeDropInterceptTap()` was correctly and unconditionally wired into `start()` with no early-return before its first `NSLog` — the missing logs were diagnosed as a Console.app capture-timing gap (opened *after* Cmd-R, per the original instructions, missing the one-shot launch-time lines), not a code bug. Re-running with Console opened and filtered *before* launch resolved it.
- **Task 3:** Removed Task 1's entire spike (properties, `armSpikeDropInterceptTap()`, its `start()`/`deinit` call sites, the temporary `handleDragApproachEnd()` diagnostic line). Created `Islet/Notch/DropInterceptTap.swift` — a `BluetoothMonitor`-shaped owning type wrapping the production tap, with a periodic 5s `CGEvent.tapIsEnabled` health check (Pitfall C — this project's own prior Release-only signing incident) that tears down and reinstalls a silently-inert tap. Wired `dropInterceptTap` into `NotchWindowController`: lazily constructed and started on the first real drag-approach edge (`recheckDragAcceptRegion()`, D-11), `stop()` added to `deinit` alongside `bluetoothMonitor?.stop()`. Added the defensive `INFOPLIST_KEY_NSInputMonitoringUsageDescription` key to `project.yml` (Accessibility is the real gate; Input Monitoring may also be granted "for free" per RESEARCH.md). Both `Debug` and `Release` builds succeed.

## Task Commits

1. **Task 1: Throwaway DEBUG-only CGEventTap spike instrumentation** - `10af783` (feat)
2. **Task 2: On-device spike validation checkpoint** - approved by user (no code commit; investigation/re-test only)
3. **Task 3: Production DropInterceptTap.swift + lazy wiring + spike removal** - `cd1a854` (feat)

**Plan metadata (this pause point):** committed alongside this SUMMARY update.

_Task 4 not yet executed — see "Plan Status" below._

## Files Created/Modified

- `Islet/Notch/DropInterceptTap.swift` - New: the production drop-interception `CGEventTap` wrapper (init/start/stop/handle, health-check timer).
- `Islet/Notch/NotchWindowController.swift` - `dropInterceptTap` property, lazy construct+start in `recheckDragAcceptRegion()`, `stop()` in `deinit`; Task 1's spike fully removed.
- `project.yml` - Added `INFOPLIST_KEY_NSInputMonitoringUsageDescription`; `xcodegen generate` re-run (regenerates `Islet.xcodeproj/project.pbxproj`, committed alongside).

## Decisions Made

- `kAXTrustedCheckOptionPrompt` is an `Unmanaged<CFString>`, not a `CFString` — fixed via `.takeUnretainedValue()` in both Task 1's spike and Task 3's production `DropInterceptTap.start()`.
- Task 2's on-device finding (existing `dragEndMonitor` never fires for a tap-swallowed event) confirmed Pitfall A's direct-invocation wiring in `DropInterceptTap.handle()` (`onIntercept()` called before `return nil`) is necessary — this was implemented exactly as designed, no change needed.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `kAXTrustedCheckOptionPrompt` unwrap required for compile (Task 1, recurred identically in Task 3)**
- **Found during:** Task 1, first Debug build attempt; same fix applied proactively in Task 3's `DropInterceptTap.start()`.
- **Issue:** `AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt: true] as CFDictionary)` fails to compile — `cannot convert value of type 'Unmanaged<CFString>' to expected dictionary key type 'AnyHashable'`.
- **Fix:** Used `kAXTrustedCheckOptionPrompt.takeUnretainedValue()` as the dictionary key.
- **Files modified:** `Islet/Notch/NotchWindowController.swift` (Task 1), `Islet/Notch/DropInterceptTap.swift` (Task 3).
- **Verification:** `xcodebuild -configuration Debug build` and `-configuration Release build` both succeed.
- **Committed in:** `10af783` (Task 1), `cd1a854` (Task 3).

**2. [Rule 1 - Bug] `NSAccessibilityUsageDescription` acceptance-criteria false positive from a project.yml comment**
- **Found during:** Task 3 acceptance-criteria check (`grep -c "NSAccessibilityUsageDescription" project.yml` returned 1, expected 0).
- **Issue:** My own explanatory comment in `project.yml` mentioned the literal string "NSAccessibilityUsageDescription" (to explain why it's deliberately NOT added), which the grep-based acceptance check matched — no actual key was added, but the check couldn't distinguish comment from key.
- **Fix:** Reworded the comment to avoid the literal substring while preserving the same explanation.
- **Files modified:** `project.yml`
- **Verification:** `grep -c "NSAccessibilityUsageDescription" project.yml` now returns 0; `xcodegen generate` + Debug/Release builds re-verified after the change.
- **Committed in:** `cd1a854` (Task 3)

**3. [Note, not a deviation requiring action] Task 1's `#if DEBUG` count acceptance criterion (carried over from prior report, now moot — spike fully removed in Task 3)**

---

**Total deviations:** 2 auto-fixed (both Rule 1 - compile/check-blocking bugs), 1 documentation note (no code change, now moot).
**Impact on plan:** All necessary for the plan to build and pass its own acceptance criteria. No scope creep.

## Issues Encountered

- Task 2's first on-device round showed 0 launch-time spike logs in Console.app, initially looking like a possible wiring bug. Root-caused as a Console.app capture-timing gap (filter applied after app launch, missing one-shot logs), not a code defect — confirmed by full code trace (call site, method body, no early return before the first log) before concluding no fix was needed. Re-test with Console opened first resolved it; this did not count against D-13's round cap since no code changed.

## Plan Status: PAUSED at Task 4 (blocking human-verify checkpoint)

Per this plan's `<plan_context>`, Task 4 requires genuine on-device hardware verification (repeated real drags, a Release-configuration re-sign/re-launch cycle, cross-app click/drag regression checks) that cannot be automated or self-approved by this agent. Task 4's approval both completes SHELF-01/SHELF-02 and formally supersedes Plan 24-02's originally-paused Task 3 checkpoint.

**Task 4 has NOT been executed.** SHELF-01/SHELF-02 are NOT YET marked complete. `REQUIREMENTS.md` has not been touched — that update is part of Task 4's own completion, per this plan's `<success_criteria>`.

See the accompanying checkpoint message (returned to the orchestrator) for the exact Xcode/Finder GUI steps needed to perform Task 4's on-device UAT.

## User Setup Required

None - no external service configuration required. Task 4 itself requires the user to build/run on-device (Debug) and separately build/run a `-configuration Release` build via Xcode's GUI — this is the checkpoint's own content, not separate setup.

## Next Phase Readiness

- Blocked pending Task 4's on-device checkpoint reply ("approved" / narrow-bug retry / "failed").
- If "approved": SHELF-01/SHELF-02 complete; `REQUIREMENTS.md` should be updated and Plan 24-02's Task 3 marked resolved/superseded (per this plan's `<success_criteria>`) as part of finishing this plan.
- If "failed" (D-13's cap reached with the core premise itself failing, not a narrow bug): this plan stops here; route to `/gsd:discuss-phase 24` to scope D-14's move-back mitigation as its own follow-up plan.

---
*Phase: 24-drag-in*
*Completed: N/A — paused mid-plan at Task 4 checkpoint (2026-07-11)*
