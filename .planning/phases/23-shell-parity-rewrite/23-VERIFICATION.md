---
phase: 23-shell-parity-rewrite
verified: 2026-07-11T01:51:39Z
status: passed
score: 5/5 must-haves verified
overrides_applied: 0
---

# Phase 23: Shell Parity Rewrite Verification Report

**Phase Goal:** The notch window shell (`NotchPanel`/`NotchWindowController`) is rebuilt with behavior identical to today, clearing the one architectural prerequisite standing between the project and a working drag-in feature.
**Verified:** 2026-07-11T01:51:39Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Island positions on notch, morphs collapsed<->expanded on hover/click, grace-collapses after ~0.4s — identical to today, on-device | ✓ VERIFIED | Human on-device UAT (Plan 23-04 Task 2, steps 4-7) explicitly approved by user ("alles approved") in this session. Code-level: `positionAndShow(on:)` (NotchWindowController.swift:601-666) frame-set→hosting-view-assign→CGSSpace-join→`orderFrontRegardless()` sequence independently re-read and confirmed intact (`orderFrontRegardless()` at line 666 is the sole and final call; `notchSpace.windows.insert(panel)` at line 661, exactly once, inside `if self.panel == nil`). |
| 2 | Island hides in true fullscreen (3 triggers) and click-through works with no dead-zone regressions | ✓ VERIFIED | Human on-device UAT (steps 8-14, including the CR-01 empty-shelf hover→expand→move-down trace) explicitly approved. Code-level: `syncClickThrough()` (line 770-784) independently re-read — expanded branch computes `interactive = visibleContentZone()?.contains(lastPointerLocation) ?? false` as its SOLE input; `pointerInZone` appears only in an explanatory comment, never in the executable condition (CR-01 regression class correctly avoided). `panel?.ignoresMouseEvents = !interactive` (line 783) is the only writer of that property in the file. |
| 3 | Island stays visible above all windows across all Spaces, repositions through external-display/clamshell changes | ✓ VERIFIED | Human on-device UAT (steps 15-19) explicitly approved. Code-level: `deinit` teardown independently re-read and matches the documented owner-driven-teardown discipline exactly (observer removals from correct centers, monitor `.stop()` calls, `notchSpace.windows.remove(panel)` for FS-01 teardown) — no resource leak that would cause stuck/flicker states across Space/display changes. |
| 4 | No `NSDraggingDestination` conformance or drag-stub overrides remain in `NotchPanel.swift` | ✓ VERIFIED | Read `Islet/Notch/NotchPanel.swift` in full (37 lines) — class declared `final class NotchPanel: NSPanel {` with no protocol conformance. `grep -c "NSDraggingDestination\|registerForDraggedTypes\|draggingEntered\|draggingUpdated\|draggingExited\|performDragOperation" Islet/Notch/NotchPanel.swift` returns 0. `IsletTests/NotchPanelTests.swift` carries `testPanelHasNoDraggingDestinationResidue()` as a regression guard (7 test methods total, confirmed present). |
| 5 | `IslandResolver.swift`, `DeviceCoordinator.swift`, `Islet/Shelf/` show zero diff — rewrite touched only window-shell code | ✓ VERIFIED | `git diff --stat 81eaeec^ HEAD -- Islet/Notch/IslandResolver.swift Islet/Notch/DeviceCoordinator.swift Islet/Shelf/` (81eaeec^ = commit immediately before Phase 23's first commit) returns empty output. Additionally confirmed the ENTIRE phase touched only 2 files in the whole repo: `git diff --stat 81eaeec^ HEAD -- Islet/ IsletTests/` shows only `Islet/Notch/NotchPanel.swift` (-26/+1) and `IsletTests/NotchPanelTests.swift` (+6) changed — `NotchWindowController.swift` itself also shows zero diff (confirmed via Plans 23-02/23-03's audit-only outcome, independently reproduced by this verifier's own git diff). |

**Score:** 5/5 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `Islet/Notch/NotchPanel.swift` | Borderless overlay panel, zero drag residue | ✓ VERIFIED | 37 lines, `final class NotchPanel: NSPanel {`, all construction properties (styleMask, isOpaque, backgroundColor, hasShadow, isMovable, isReleasedWhenClosed, ignoresMouseEvents, level, collectionBehavior, canBecomeKey/canBecomeMain) present and unchanged from documented pre-Phase-22-spike baseline |
| `IsletTests/NotchPanelTests.swift` | Unit-level proof drag scaffold is gone | ✓ VERIFIED | 7 `func test` methods present (confirmed via full file read), including `testPanelHasNoDraggingDestinationResidue()` asserting `!(panel is NSDraggingDestination)` |
| `Islet/Notch/NotchWindowController.swift` | Full shell reconstruction, safety-critical core intact | ✓ VERIFIED | 1378 lines; `xcodebuild -project Islet.xcodeproj -scheme Islet -configuration Debug build` run independently by this verifier — BUILD SUCCEEDED; `updateVisibility()`/`positionAndShow()`/`syncClickThrough()`/`deinit` all independently re-read and match every documented invariant |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `IsletTests/NotchPanelTests.swift` | `Islet/Notch/NotchPanel.swift` | `XCTAssertFalse(panel is NSDraggingDestination)` | ✓ WIRED | Assertion present at end of test file, references the live `NotchPanel` type via `@testable import Islet` |
| `NotchWindowController.updateVisibility()` | `panel?.orderOut(nil)` / `positionAndShow(on:)` | sole hide/show call sites | ✓ WIRED | `grep -c "panel?.orderOut(nil)"` = 1; `positionAndShow(on:` has exactly 1 definition (line 601) and 1 call site (line 578, inside `updateVisibility()`) |
| `NotchWindowController.syncClickThrough()` | `panel?.ignoresMouseEvents` | sole writer | ✓ WIRED | `grep -c "panel?.ignoresMouseEvents"` = 1 (line 783), CR-01 fix confirmed intact by direct code read |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Full Debug build compiles with all 4 plans' combined edits | `xcodebuild -project Islet.xcodeproj -scheme Islet -configuration Debug build` | `** BUILD SUCCEEDED **` | ✓ PASS (independently re-run by verifier, not just trusted from SUMMARY) |
| Zero-diff on locked files since pre-phase baseline | `git diff --stat 81eaeec^ HEAD -- Islet/Notch/IslandResolver.swift Islet/Notch/DeviceCoordinator.swift Islet/Shelf/` | empty output | ✓ PASS |
| Zero drag residue in NotchPanel.swift | `grep -c "NSDraggingDestination" Islet/Notch/NotchPanel.swift` | `0` | ✓ PASS |
| On-device UAT — not independently re-run by this verifier (requires physical notch hardware); per task instructions, treated as satisfied by the user's explicit "alles approved" response recorded in Plan 23-04's SUMMARY and this session's conversation history | N/A (human-only) | Approved | ✓ PASS (accepted per task instructions — see note below) |

**Note on Criteria 1-3:** Per explicit instruction accompanying this verification task, the on-device human UAT checkpoint (Plan 23-04, Task 2) — a documented 20-item test pass covering hover/click/morph, all 3 fullscreen triggers, the CR-01 click-through empty-shelf trace, multi-Space/display/clamshell repositioning, and lock/sleep-wake stability — was explicitly approved by the user with "alles approved" in this session. This verifier did not re-request on-device testing per that instruction, and independently corroborated the code-level invariants underlying those criteria (panel-show sequence, click-through arbiter, deinit teardown) via direct source reads rather than relying solely on SUMMARY narrative.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|--------------|--------|----------|
| ARCH-01 | 23-01, 23-02, 23-03, 23-04 | Notch window shell rebuilt with behavior identical to today, drag scaffold removed | ✓ SATISFIED | All 5 roadmap Success Criteria independently verified above. **Note:** `.planning/REQUIREMENTS.md` line 12/75 still shows ARCH-01 as `- [ ]` unchecked / "Pending" — this is a documentation bookkeeping gap (checkbox/status-table update), not a code gap. Flagged as info, not a blocker. |

No orphaned requirements — Phase 23 only claims ARCH-01, and REQUIREMENTS.md maps only ARCH-01 to Phase 23.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| — | — | None found | — | `grep -n -E "TBD\|FIXME\|XXX\|TODO\|HACK\|PLACEHOLDER"` on both modified files returns zero matches. No dead code, no orphaned drag-related references anywhere in the repo (`grep -rn "DragApproachDetector" Islet/Notch/` returns empty, confirming D-01's "no named seam left behind" instruction was honored). |

**Info-only item:** `.planning/REQUIREMENTS.md` ARCH-01 checkbox/status not yet flipped to complete — administrative bookkeeping, does not affect phase goal achievement, expected to be closed out alongside ROADMAP.md's Progress table by the orchestrator (consistent with prior project pattern of phase-completion bookkeeping being a separate step from code verification).

### Human Verification Required

None. Criteria 1-3 requiring on-device testing were already covered by the explicitly-approved UAT documented in Plan 23-04 ("alles approved," recorded in 23-04-SUMMARY.md and this session's conversation). No further human verification items were identified during this pass.

### Gaps Summary

No gaps. All 5 ROADMAP Success Criteria are independently verified: on-device parity for hover/click/morph/grace-collapse, fullscreen hiding across all 3 triggers with click-through (CR-01 trace) intact, multi-Space/display/clamshell repositioning, zero `NSDraggingDestination` residue, and zero diff on `IslandResolver.swift`/`DeviceCoordinator.swift`/`Islet/Shelf/`. The rewrite touched exactly 2 files in the whole repository (`NotchPanel.swift`, `NotchPanelTests.swift`); `NotchWindowController.swift` was audited line-by-line across Plans 23-02/23-03 and confirmed already matching every documented invariant, independently reproduced here via a fresh `git diff` against the pre-phase baseline. A clean Debug build was independently re-run by this verifier (not merely trusted from SUMMARY claims). The only outstanding item is a documentation-bookkeeping checkbox in REQUIREMENTS.md, which does not block phase goal achievement.

---

*Verified: 2026-07-11T01:51:39Z*
*Verifier: Claude (gsd-verifier)*
