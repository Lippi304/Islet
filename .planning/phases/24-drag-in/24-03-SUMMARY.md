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
  - "Islet/Notch/DropInterceptTap.swift: a session CGEventTap that intercepts the terminating .leftMouseUp for an armed drag-approach region, invoking handleDragApproachEnd() directly (Pitfall A) then relocating the event off-screen and passing it through (NOT returning nil) — stops Finder's Desktop from relocating the original dragged file WITHOUT stranding the drag ghost image on the cursor"
  - "NotchWindowController wiring: dropInterceptTap lazily constructed+started on the first real drag-approach edge (D-11), stop() in deinit"
  - "On-device confirmation (Task 2 spike + Task 4 round-1 UAT) of Assumption A5 (relocation prevented), A7/Pitfall A (existing dragEndMonitor never fires for a fully-swallowed event — direct invocation was the right call), A6 (Accessibility, not Input Monitoring, gates tap creation), and a NEW finding: fully swallowing (nil) the event also starves the WindowServer's own drag-session-end bookkeeping, stranding the drag visual on the cursor — fixed by relocating+passing-through instead of swallowing"
affects: [SHELF-01, SHELF-02, future raw-HID-event interception work]

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
    - .planning/REQUIREMENTS.md

key-decisions:
  - "kAXTrustedCheckOptionPrompt (an Unmanaged<CFString>) must be unwrapped via .takeUnretainedValue() before use as a CFDictionary key — the RESEARCH.md interface sketch omitted this and the plain form does not compile"
  - "On-device Task 2 finding: the existing dragEndMonitor (NSEvent global monitor) never fires for a .leftMouseUp the tap has swallowed — confirms Pitfall A's direct-invocation design (onIntercept() calling handleDragApproachEnd() from inside the tap's swallow branch) was necessary, not just defensive"
  - "On-device Task 4 round-1 finding: returning nil (full swallow) for the terminating .leftMouseUp also starves the WindowServer's own drag-session-completion bookkeeping (not just Finder's Desktop and not just Islet's own dragEndMonitor), stranding the drag ghost image on the cursor. Fix: relocate the event's location off every screen and pass it through (Unmanaged.passUnretained) instead of nil — window server ends the drag session normally against a location with no valid drop target, so no relocation AND no stuck cursor"

patterns-established:
  - "Pattern: DropInterceptTap-shaped small owning type for any future raw-HID-event interception need — BluetoothMonitor-lifecycle-shaped (init/start/stop/deinit), never touches ignoresMouseEvents/syncClickThrough() (orthogonal to click-through hit-testing)"
  - "Pattern: when a CGEventTap needs to deny a drop target without breaking the OS-level drag-session lifecycle, relocate-and-pass-through beats swallow-with-nil — nil fully removes the event from the WindowServer's own internal bookkeeping, not just from downstream app observers"

requirements-completed: [SHELF-01, SHELF-02]

# Metrics
duration: ~1h15m
completed: 2026-07-11
---

# Phase 24 Plan 03: Drop-Interception CGEventTap Summary

**Production `DropInterceptTap` (session CGEventTap) closes the drag-in data-loss gap: files land in the shelf, the original is never relocated, and (after a round-1 on-device fix) the drag cursor releases cleanly instead of staying stuck. Task 4's round-2 on-device UAT is APPROVED — all 4 tasks complete, SHELF-01/SHELF-02 done, and Plan 24-02's originally-paused Task 3 checkpoint is resolved/superseded by this plan.**

## Performance

- **Tasks completed:** 4 of 4 (Task 2 and Task 4 were on-device human-verify checkpoints, both approved — Task 4 required one fix-and-retry round per D-13)
- **Files modified:** 5 (1 new: `DropInterceptTap.swift`; plus `NotchWindowController.swift`, `project.yml`, `Islet.xcodeproj/project.pbxproj`, `.planning/REQUIREMENTS.md`)
- **Status:** COMPLETE — SHELF-01/SHELF-02 done, Plan 24-02 Task 3 resolved/superseded

## Accomplishments

- **Task 1:** Built a throwaway `#if DEBUG` CGEventTap spike in `NotchWindowController.swift` to probe Assumption A5 (does swallowing `.leftMouseUp` at `.cgSessionEventTap`/`.defaultTap` stop Finder's Desktop from relocating the file) before writing any production code.
- **Task 2 (on-device checkpoint, approved):**
  - Assumption A5 **confirmed**: repeated drags showed `SWALLOWING this mouseUp` in Console, and the original file was never relocated to the Desktop.
  - Assumption A7 / Pitfall A **confirmed**: for every swallowed `.leftMouseUp`, the existing `dragEndMonitor` (NSEvent global monitor) never fired — validating that Task 3's design (invoking `handleDragApproachEnd()` directly from the tap's swallow branch) is load-bearing, not just defensive.
  - Assumption A6 **confirmed**: Accessibility (not Input Monitoring) is what gates tap creation — `AXIsProcessTrusted`/`AXIsProcessTrustedWithOptions` both returned `true` (already granted from an earlier session).
  - Ordinary clicking/dragging in other apps (Safari/TextEdit) unaffected; an Escape-cancelled drag left the island in a normal (not stuck) state.
  - One investigation round was needed first: the user's initial Console.app capture showed 0 of the spike's launch-time logs (only the existing `handleDragApproachEnd()` diagnostic line fired, 8/8 times, always `isDragApproaching=false`). Code review confirmed `armSpikeDropInterceptTap()` was correctly and unconditionally wired into `start()` with no early-return before its first `NSLog` — the missing logs were diagnosed as a Console.app capture-timing gap (opened *after* Cmd-R, per the original instructions, missing the one-shot launch-time lines), not a code bug. Re-running with Console opened and filtered *before* launch resolved it.
- **Task 3:** Removed Task 1's entire spike (properties, `armSpikeDropInterceptTap()`, its `start()`/`deinit` call sites, the temporary `handleDragApproachEnd()` diagnostic line). Created `Islet/Notch/DropInterceptTap.swift` — a `BluetoothMonitor`-shaped owning type wrapping the production tap, with a periodic 5s `CGEvent.tapIsEnabled` health check (Pitfall C — this project's own prior Release-only signing incident) that tears down and reinstalls a silently-inert tap. Wired `dropInterceptTap` into `NotchWindowController`: lazily constructed and started on the first real drag-approach edge (`recheckDragAcceptRegion()`, D-11), `stop()` added to `deinit` alongside `bluetoothMonitor?.stop()`. Added the defensive `INFOPLIST_KEY_NSInputMonitoringUsageDescription` key to `project.yml` (Accessibility is the real gate; Input Monitoring may also be granted "for free" per RESEARCH.md). Both `Debug` and `Release` builds succeed.
- **Task 4, round 1 (on-device UAT):** Core relocation-prevention premise held (single-file and multi-file+folder drags, Debug AND a Release re-sign/re-launch) — original files were never relocated. BUT: the dragged item's ghost image stayed visually attached to the cursor after release; the user had to press Escape or start a second drag/drop to release it. Root-caused (not guessed): `.cgSessionEventTap` sits at "the point where session events ... are entering the window server" (Apple docs) — returning `nil` fully suppresses the event before the WindowServer's OWN drag-session-completion bookkeeping ever sees it, not just Finder's Desktop and not just Islet's own `dragEndMonitor` (the same mechanism already proven by Pitfall A). Fix: `DropInterceptTap.handle()` now relocates the event's `location` to a point far outside every screen (`CGPoint(x: -100_000, y: -100_000)`, CG's own top-left-origin global-display coordinate space) and passes the REAL, now-relocated event through (`Unmanaged.passUnretained`) instead of returning `nil`. The window server receives a genuine release (drag session ends normally, cursor lets go) but hit-tests against a location with no window at all, so no `NSDraggingDestination` ever receives the drop — same net effect (no relocation) via a mechanism that also lets the drag-session-end signal through. `shelf-landing` (`onIntercept()`) still runs first, unchanged.
- **Task 4, round 2 (on-device UAT, APPROVED):** User re-ran the full checklist against the round-1 fix. Every check passed: single-file and multi-file+folder drags land in the shelf with originals untouched, cursor now releases cleanly (no more stuck ghost image), hot-feedback still shows, 5+ repeated drags with no crash/stuck state, Escape-cancel leaves the island normal, other apps (Safari/TextEdit) unaffected, AND the fix survives a `-configuration Release` re-sign/re-launch cycle. SHELF-01/SHELF-02 complete; Plan 24-02's originally-paused Task 3 is resolved/superseded (its full checklist is re-covered by this task's own).

## Task Commits

1. **Task 1: Throwaway DEBUG-only CGEventTap spike instrumentation** - `10af783` (feat)
2. **Task 2: On-device spike validation checkpoint** - approved by user (no code commit; investigation/re-test only)
3. **Task 3: Production DropInterceptTap.swift + lazy wiring + spike removal** - `cd1a854` (feat)
4. **Task 4 round-1 fix: stop swallowed leftMouseUp from stranding the drag cursor** - `1db9b0b` (fix)
5. **Task 4 round-2: on-device UAT re-verification** - approved by user (no code commit)

**Plan metadata (this completion):** `.planning/REQUIREMENTS.md` (SHELF-01/SHELF-02 marked complete) committed alongside this final SUMMARY update.

## Files Created/Modified

- `Islet/Notch/DropInterceptTap.swift` - New: the production drop-interception `CGEventTap` wrapper (init/start/stop/handle, health-check timer). `handle()` relocates-and-passes-through the terminating `.leftMouseUp` rather than swallowing it (Task 4 round-1 fix).
- `Islet/Notch/NotchWindowController.swift` - `dropInterceptTap` property, lazy construct+start in `recheckDragAcceptRegion()`, `stop()` in `deinit`; Task 1's spike fully removed.
- `project.yml` - Added `INFOPLIST_KEY_NSInputMonitoringUsageDescription`; `xcodegen generate` re-run (regenerates `Islet.xcodeproj/project.pbxproj`, committed alongside).
- `.planning/REQUIREMENTS.md` - SHELF-01/SHELF-02 marked complete (checkboxes + traceability table), via `gsd-sdk query requirements.mark-complete`.

## Decisions Made

- `kAXTrustedCheckOptionPrompt` is an `Unmanaged<CFString>`, not a `CFString` — fixed via `.takeUnretainedValue()` in both Task 1's spike and Task 3's production `DropInterceptTap.start()`.
- Task 2's on-device finding (existing `dragEndMonitor` never fires for a tap-swallowed event) confirmed Pitfall A's direct-invocation wiring in `DropInterceptTap.handle()` (`onIntercept()` called before the terminal action) is necessary — implemented exactly as designed, unaffected by the round-1 fix.
- Task 4 round-1: chose relocate-and-pass-through over swallow-with-nil specifically because the project's OWN prior on-device evidence (Task 2/4 both showed manipulating this exact terminating event controls the relocation outcome) supports that redirecting its target, not just consuming it outright, should be equally effective at denying Finder a valid drop target while additionally letting the drag session end cleanly.

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

**3. [Rule 1 - Bug] Drag ghost image stranded on cursor after a swallowed drop (Task 4 round-1 on-device finding)**
- **Found during:** Task 4, first on-device UAT round (user-reported, not in the plan's original checklist).
- **Issue:** The core relocation-prevention premise held, but returning `nil` for the terminating `.leftMouseUp` also prevented the WindowServer's own drag-session-completion bookkeeping from ever seeing the release — the dragged item's ghost image stayed visually attached to the cursor until the user pressed Escape or performed a second drag/drop.
- **Fix:** `DropInterceptTap.handle()` now relocates the event to `CGPoint(x: -100_000, y: -100_000)` (CG's top-left-origin global-display space) and passes the real, relocated event through instead of returning `nil` — the drag session ends normally (cursor releases) while still landing on a location with no valid drop target (no relocation).
- **Files modified:** `Islet/Notch/DropInterceptTap.swift`
- **Verification:** Debug and Release builds succeed; confirmed on-device in round 2 (cursor releases cleanly, relocation-prevention still intact, Release pass included).
- **Committed in:** `1db9b0b`

**4. [Note, not a deviation requiring action] Task 1's `#if DEBUG` count acceptance criterion (carried over from prior report, now moot — spike fully removed in Task 3)**

---

**Total deviations:** 3 auto-fixed (2 Rule 1 compile/check-blocking bugs + 1 Rule 1 on-device-found bug), 1 documentation note (no code change, now moot).
**Impact on plan:** All necessary for the plan to build, pass its own acceptance criteria, and (pending round-2 confirmation) deliver a UX-correct fix. No scope creep — the round-1 fix is a narrow, targeted change to the same `handle()` method, no architectural change.

## Issues Encountered

- Task 2's first on-device round showed 0 launch-time spike logs in Console.app, initially looking like a possible wiring bug. Root-caused as a Console.app capture-timing gap (filter applied after app launch, missing one-shot logs), not a code defect — confirmed by full code trace (call site, method body, no early return before the first log) before concluding no fix was needed. Re-test with Console opened first resolved it; this did not count against D-13's round cap since no code changed.
- Task 4's first on-device round surfaced the stuck-drag-cursor bug documented above (Deviation 3). Investigated via CGEventTap/`.cgSessionEventTap` documentation semantics plus the project's own prior on-device evidence before writing any fix — not a blind guess. This was D-13's one allowed retry round for Task 4; round 2 confirmed the fix and was approved.

## Plan Status: COMPLETE

All 4 tasks done, Task 4's round-2 on-device UAT (including the Release-configuration pass) approved by the user. SHELF-01/SHELF-02 are complete — `REQUIREMENTS.md` updated (checkboxes + traceability table) via `gsd-sdk query requirements.mark-complete SHELF-01 SHELF-02`. Per this plan's own `<success_criteria>`, Plan 24-02's originally-paused Task 3 checkpoint is **resolved/superseded** by this plan's Task 4 (its full on-device checklist is re-covered, plus the new interception-specific checks) — 24-02's Task 3 does not need to be separately re-run.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- SHELF-01/SHELF-02 shipped and on-device verified (Debug + Release). Phase 24 (Drag-In) is complete.
- The `DropInterceptTap`-shaped owning-type pattern (init/start/stop/deinit, health-check timer, relocate-and-pass-through over swallow-with-nil) is available as a precedent for any future raw-HID-event interception need.
- No known blockers carried forward from this plan.

---
*Phase: 24-drag-in*
*Completed: 2026-07-11*
