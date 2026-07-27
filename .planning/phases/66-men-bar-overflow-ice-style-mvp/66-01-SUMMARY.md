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

requirements-completed: []  # Spike-only plan — MENUBAR-01..04 are NOT complete. Verdict is NO-GO: the private CGS mechanism does not work reliably on this hardware/macOS version, so 66-02..66-06 do not proceed as scoped.

# Metrics
duration: ~35min Task 1 + ~1h diagnostic/checkpoint round-trip
completed: 2026-07-27 — Task 2 checkpoint returned NO-GO
---

# Phase 66 Plan 01: MenuBarOverflowBridging Shim + On-Device Manual Spike Summary

**Private CGS*-symbol window-enumeration/frame-read shim + a synthetic-CGEvent-drag move function, transcribed directly from Ice's real source, plus a Cmd-U-only manual spike test — build verified clean. On-device verdict: NO-GO. The private CGS enumeration mechanism does not reliably find real menu-bar-item windows on this hardware/macOS version, including the developer's own confirmed-running Islet status item.**

## Status: NO-GO — checkpoint closed, phase execution halted

Task 1 (the automated build task) completed and committed. Task 2 (`checkpoint:human-verify`, gate=blocking) ran on real hardware across three on-device rounds (see "On-device verdict" below) and returned **NO-GO**. Per this plan's own explicit rule ("A NO-GO ... requires stopping here and returning to `/gsd:discuss-phase 66` to revisit SC#4's wording before any of Plans 66-02..66-06 proceed"), Phase 66 execution halts here. Plans 66-02 through 66-06 do not proceed under their current scope.

## On-device verdict: NO-GO

Three Cmd-U rounds were run on real hardware (2026-07-27), each adding diagnostics to isolate the cause before concluding:

1. **Round 1** — `CGSGetProcessMenuBarWindowList` returned 0 other-process windows despite the user confirming several visible non-system menu-bar icons were present.
2. **Round 2** — Ruled out Screen Recording permission: `CGRequestScreenCaptureAccess()` was added and actively invoked; no system prompt appeared and the result was unchanged (permission was later confirmed already-granted in Round 3, with no change in outcome).
3. **Round 3 (conclusive)** — With Screen Recording confirmed `true` and `Bundle.main.bundleIdentifier` confirmed correctly resolving to `"com.lippi304.islet"` (ruling out the hosted-XCTest-bundle-identity gotcha), the private CGS call `CGSGetProcessMenuBarWindowList(CGSMainConnectionID(), 0, ...)` — called with the exact same arguments Ice's own `getMenuBarWindowList()` uses — returned exactly one window: `windowID=6771, pid=630`, whose bundle identifier could not even be resolved via `NSRunningApplication(processIdentifier:)` (`rawBundleID=nil`). An independent cross-check via the **public** `CGWindowListCopyWindowInfo` API, filtered to `kCGWindowLayer == CGWindowLevelForKey(.statusWindow)`, found the developer's own real, currently-running Islet status item at a **different** pid (`pid=55045, ownerName="Islet"`) — a window the private CGS enumeration did not surface at all.

**Conclusion:** The private CGS mechanism, transcribed faithfully from Ice's real, current source (not guessed or invented — RESEARCH.md's own mandate was honored), fails to enumerate even a guaranteed-real, independently-confirmed menu-bar-item window on this developer's hardware/macOS version. This is not a permission gap, not a Bundle.main resolution bug, and not an absence-of-target-icon issue — it is the core private-API mechanism itself not returning correct results. This matches the exact risk RESEARCH.md Pitfall 3 flagged going in ("undocumented, version-fragile SkyLight/CoreGraphics symbols with no API stability guarantee... multiple recent Ice GitHub issues report cross-macOS-version breakage").

**Diagnostic instrumentation added during this checkpoint** (commits `5f231f3`, `6136d7f`, `68bb5a2`) remains in both files for whoever picks this back up — it should be stripped once a fix direction (different private API, a different macOS-version-specific symbol, or abandoning the private-CGS approach entirely) is decided in `/gsd:discuss-phase 66`.

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

## Next Phase Readiness — NO-GO, halted

Per the plan's own resume-signal rule, Phase 66 execution stops here. **Next step: `/gsd:discuss-phase 66`** to decide how to proceed — options to weigh there include: trying a different/updated private CGS symbol set for this macOS version, researching whether a newer fork of Ice (or a different reference implementation) has already adapted to this breakage, or descoping/abandoning the Ice-style overflow mechanism (SC#4) for this milestone.

---
*Phase: 66-men-bar-overflow-ice-style-mvp*
*Task 1 completed: 2026-07-27 — Task 2 checkpoint PENDING*

## Self-Check: PASSED

- FOUND: Islet/Notch/MenuBarOverflowBridging.swift
- FOUND: IsletTests/MenuBarOverflowManualSpike.swift
- FOUND: .planning/phases/66-men-bar-overflow-ice-style-mvp/66-01-SUMMARY.md
- FOUND commit: adfbd70
