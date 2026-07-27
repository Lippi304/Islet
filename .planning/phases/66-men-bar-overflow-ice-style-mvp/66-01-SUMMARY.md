---
phase: 66-men-bar-overflow-ice-style-mvp
plan: 01
subsystem: menu-bar
tags: [private-api, CGS, silgen_name, CGEvent, AXIsProcessTrusted, spike, XCTest]

# Dependency graph
requires: []
provides:
  - "MenuBarOverflowBridging.swift — permanent, reusable private-symbol shim (window enumeration, frame read, synthetic-drag move)"
  - "MenuBarOverflowManualSpike.swift — Cmd-U-only on-device spike exercising the mechanism"
  - "Ice source (Bridging.swift/Private.swift/MenuBarItemManager.swift/ControlItem.swift) read directly and transcribed, not paraphrased from memory"
affects: [66-02, 66-03, 66-04, 66-05, 66-06]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Private CGS*/@_silgen_name symbol shim, isolated to one file (mirrors NowPlayingMonitor/MicMuteController/MeetingMonitor 'one fragile surface, one file' discipline)"
    - "Manual on-device XCTestCase spike (Cmd-U only, always-green assertion, human-judged console output) — mirrors MeetingMonitorManualSpike.swift"

key-files:
  created:
    - Islet/Notch/MenuBarOverflowBridging.swift
    - IsletTests/MenuBarOverflowManualSpike.swift
  modified:
    - Islet.xcodeproj/project.pbxproj (xcodegen regeneration to register the 2 new files)

key-decisions:
  - "Did not re-declare CGSMainConnectionID()/CGSConnectionID — the codebase already has a global CGSMainConnectionID() -> Int32 in FullscreenSpaceProbe.swift (Phase 2) and a fileprivate CGSConnectionID typealias (UInt) in CGSSpace.swift (Phase 9); MenuBarOverflowBridging.swift reuses the existing CGSMainConnectionID() and types its own new symbols' connection-ID parameters as raw Int32 to avoid a second same-named module-level declaration"
  - "moveMenuBarItem() posts synthetic events via CGEvent.postToPid(pid) (a real, simpler public CGEvent API) rather than replicating Ice's full EventTap-based 'scrombleEvent' routing machinery — sufficient for this spike's validation purpose; a future production Controller (Plan 66-03) can revisit Ice's fuller routing if postToPid proves unreliable on-device"
  - "Owner-PID -> bundle-identifier resolution uses the public CGWindowListCopyWindowInfo (not a private symbol) combined with the private CGS windowID enumeration — CGS itself has no owner-pid accessor; this is a standard combined technique, not an invented one"

requirements-completed: []  # Spike-only plan — MENUBAR-01..04 are NOT complete; they require the production Controller/Store built in later 66-0x plans, gated on this plan's own checkpoint returning GO.

# Metrics
duration: ~35min (Task 1 only; Task 2 checkpoint still open)
completed: PENDING (Task 1 done 2026-07-27; Task 2 human on-device verification not yet run)
---

# Phase 66 Plan 01: MenuBarOverflowBridging Shim + On-Device Manual Spike Summary

**Private CGS*-symbol window-enumeration/frame-read shim + a synthetic-CGEvent-drag move function, transcribed directly from Ice's real source, plus a Cmd-U-only manual spike test — build verified clean; the mandatory on-device RECLAIMED-vs-OCCLUDED verdict (Task 2) is still PENDING human verification.**

## Status: BLOCKED on human checkpoint

Task 1 (the automated build task) is complete and committed. Task 2 is a `checkpoint:human-verify` gate — an on-device Xcode Cmd-U manual spike run that only a human with physical hardware access can perform. This plan is **not** finished; no later plan in Phase 66 (66-02 through 66-06) may begin until Task 2 returns a GO verdict per the plan's own explicit rule ("No later plan in this phase may begin until this plan's checkpoint returns a GO").

## Performance

- **Task 1 duration:** ~35 min
- **Started:** 2026-07-27T17:02:15Z
- **Task 1 completed:** 2026-07-27 (commit `adfbd70`)
- **Tasks:** 1 of 2 complete (Task 2 pending)
- **Files created:** 2 (+1 regenerated project file)

## Accomplishments (Task 1)

- Fetched and read Ice's real, current source directly (github.com/jordanbaird/Ice, MIT) — `Bridging.swift`, `Shims/Private.swift`, `MenuBarItemManager.swift`, `ControlItem.swift` — fulfilling the ROADMAP's explicit "reading Ice's actual open-source mechanism directly" mandate rather than reconstructing it from RESEARCH.md's summary.
- Created `Islet/Notch/MenuBarOverflowBridging.swift`: declares only the `CGS*` symbols this spike actually calls (`CGSGetWindowCount`, `CGSGetProcessMenuBarWindowList`, `CGSGetScreenRectForWindow`, transcribed verbatim from Ice's `Private.swift`), reuses the codebase's pre-existing `CGSMainConnectionID()` rather than re-declaring it, resolves owner PIDs via the public `CGWindowListCopyWindowInfo`, and excludes Islet's own bundle identifier from every read. Adds `moveMenuBarItem(windowID:toX:maxAttempts:)`, a 5-attempt retry loop synthesizing a Cmd-flagged mouse-down -> mouse-dragged -> mouse-up `CGEvent` sequence routed via `postToPid`, mirroring Ice's `MenuBarItemManager.move()`/`wakeUpItem()` shape (read directly from `MenuBarItemManager.swift` lines 936-1135). Every CGS return value is guarded; no force-unwraps of any CGS/window-server result (T-66-04); a failed/exhausted move returns `false` without looping indefinitely (T-66-01).
- Created `IsletTests/MenuBarOverflowManualSpike.swift`: a single `@MainActor func testManualMechanism()` cloning `MeetingMonitorManualSpike.swift`'s exact shape — prints `AXIsProcessTrusted()`, enumerates and prints other processes' menu-bar-item windows, moves one real third-party icon and prints before/after frames, explicitly asks the human to judge RECLAIMED vs OCCLUDED (Pitfall 2's central question), runs inside a 180s `RunLoop.current.run(until:)` window covering the permission-revoke/sleep-wake/app-relaunch checklist, and re-reads the window list at the end to confirm graceful degradation. Assertion is the always-green `XCTAssertTrue(true, ...)` discipline — pass/fail is human-judged from console output.
- Ran `xcodegen generate` (new files not auto-discovered by the explicit file-reference list, per the documented Phase 59-02/61-01 precedent) and `xcodebuild build -scheme Islet -configuration Release -destination 'platform=macOS'` — build succeeded with zero errors and zero new warnings attributable to either new file.

## Task Commits

1. **Task 1: MenuBarOverflowBridging.swift shim + MenuBarOverflowManualSpike.swift spike test** - `adfbd70` (feat)

Task 2 has no commit — it is a human-verification checkpoint with no code changes of its own.

## Files Created/Modified

- `Islet/Notch/MenuBarOverflowBridging.swift` - private CGS* window-enumeration/frame-read shim + synthetic-drag `moveMenuBarItem()`
- `IsletTests/MenuBarOverflowManualSpike.swift` - Cmd-U-only manual on-device spike test
- `Islet.xcodeproj/project.pbxproj` - regenerated via `xcodegen generate` to register both new files

## Decisions Made

- **CGS symbol collision avoided, not force-merged.** `Islet/Notch/FullscreenSpaceProbe.swift` (Phase 2) already declares a global `CGSMainConnectionID() -> Int32`, and `Islet/Notch/CGSSpace.swift` (Phase 9) already declares a `fileprivate typealias CGSConnectionID = UInt` with its own `_CGSDefaultConnection()`-based symbol set. The first build attempt failed with "invalid redeclaration" / "ambiguous for type lookup" errors from a naive verbatim port of RESEARCH.md's Code Example (which declares its own `CGSConnectionID`/`CGSMainConnectionID`). Fixed (Rule 3 - blocking) by removing the duplicate declarations and typing `MenuBarOverflowBridging.swift`'s own new symbols' connection-ID parameters as raw `Int32`, reusing the existing global `CGSMainConnectionID()` as-is. Documented inline in the file for the next plan/reader.
- **`postToPid` over Ice's full EventTap routing.** Ice's own `move()`/`wakeUpItem()` route synthetic events through an internal `scrombleEvent`/`EventTap.Location` abstraction (`.pid`/`.sessionEventTap`). This spike uses `CGEvent.postToPid(_:)` directly — a real, documented, simpler public CGEvent API that achieves the same "route this event at one specific process" effect — sufficient to validate the mechanism's core question (does the move visually happen, does it reclaim or occlude) without porting Ice's more elaborate tap infrastructure into a spike-only file.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] CGS symbol redeclaration collision with existing codebase files**
- **Found during:** Task 1 (first `xcodebuild build` attempt after creating both files)
- **Issue:** `MenuBarOverflowBridging.swift`'s initial `typealias CGSConnectionID = Int32` + `@_silgen_name("CGSMainConnectionID") func CGSMainConnectionID() -> CGSConnectionID` (transcribed verbatim from RESEARCH.md's Code Example) collided with two pre-existing declarations: `FullscreenSpaceProbe.swift`'s global `CGSMainConnectionID() -> Int32` (invalid redeclaration) and `CGSSpace.swift`'s `fileprivate typealias CGSConnectionID = UInt` (ambiguous type lookup). Build failed with 12 errors across `CGSSpace.swift` and `FullscreenSpaceProbe.swift`.
- **Fix:** Removed the duplicate `typealias`/`CGSMainConnectionID()` declaration from `MenuBarOverflowBridging.swift`; retyped its own 3 new symbol declarations' connection-ID parameters as raw `Int32`; reused the codebase's existing global `CGSMainConnectionID()` call sites unchanged.
- **Files modified:** `Islet/Notch/MenuBarOverflowBridging.swift` (part of the same Task 1 commit, not a separate commit)
- **Verification:** `xcodebuild build -scheme Islet -configuration Release -destination 'platform=macOS'` — BUILD SUCCEEDED, zero errors.
- **Committed in:** `adfbd70` (Task 1 commit — fixed before commit, not a follow-up)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Necessary correctness fix to reach a green build; no scope creep — the shim's public surface (`menuBarItemWindows()`, `currentFrame(windowID:)`, `moveMenuBarItem(windowID:toX:maxAttempts:)`) is unchanged from the plan's specification.

## Issues Encountered

None beyond the CGS redeclaration fix documented above.

## User Setup Required

None - no external service configuration required. Task 2, however, requires the user's physical presence at the Mac (see below).

## Next Phase Readiness — BLOCKED

**Task 2 (`checkpoint:human-verify`, gate: blocking) has NOT been run.** No later plan in Phase 66 (66-02 through 66-06) may begin until this returns GO, per the plan's own explicit rule and ROADMAP Success Criteria #1.

### What was built (for the human to verify)

A manual on-device spike (`MenuBarOverflowManualSpike.testManualMechanism`) that reads/moves a real third-party menu-bar icon using the same private CGS*-symbol + synthetic-CGEvent-drag technique Ice itself uses, and reports whether Accessibility-denied degrades gracefully.

### How to verify (run these steps exactly, in Xcode, on real hardware)

1. In Xcode, open `IsletTests/MenuBarOverflowManualSpike.swift` and run ONLY `testManualMechanism` via Cmd-U (never `xcodebuild test` — this project's test host hangs headless on TCC waits).
2. Read the console output. Confirm `AXIsProcessTrusted()` prints `true` (grant Accessibility to the Xcode-launched test host in System Settings -> Privacy & Security -> Accessibility if it prints `false`, then re-run).
3. Confirm the console lists at least one other process's menu-bar-item window with a bundle ID and CGRect that is NOT Islet's own bundle ID.
4. Watch the target icon during the 180s run — confirm it visually moves when `moveMenuBarItem` fires.
5. THE CENTRAL QUESTION (Pitfall 2): after the move, does an adjacent visible icon shift left to fill the vacated position (RECLAIMED — real space returned), or does the position just sit empty/covered by the frontmost app's own menu titles when you switch apps (OCCLUDED)? Report which one you observed.
6. During the same 180s run, revoke Accessibility for the Xcode test host in System Settings, re-run the test once, and confirm the window-list read returns empty/no crash (not a partial/garbage result).
7. Put the Mac to sleep and wake it once during a run; confirm a subsequent window-list read still succeeds without needing an app relaunch.
8. Quit and relaunch the target third-party app during a run; confirm a fresh window-list read finds its NEW window ID at its new default position (not a stale/dead reference).

### Resume signal

Report **GO** (mechanism works, state whether RECLAIMED or OCCLUDED) or **NO-GO** (describe what failed). A NO-GO or an OCCLUDED-only finding requires stopping here and returning to `/gsd:discuss-phase 66` to revisit SC#4's wording before any of Plans 66-02..66-06 proceed.

---
*Phase: 66-men-bar-overflow-ice-style-mvp*
*Task 1 completed: 2026-07-27 — Task 2 checkpoint PENDING*

## Self-Check: PASSED

- FOUND: Islet/Notch/MenuBarOverflowBridging.swift
- FOUND: IsletTests/MenuBarOverflowManualSpike.swift
- FOUND: .planning/phases/66-men-bar-overflow-ice-style-mvp/66-01-SUMMARY.md
- FOUND commit: adfbd70
