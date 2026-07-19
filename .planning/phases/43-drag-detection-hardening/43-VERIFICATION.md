---
phase: 43-drag-detection-hardening
verified: 2026-07-19T01:45:00Z
status: passed
score: 8/8 must-haves verified
overrides_applied: 0
---

# Phase 43: Drag Detection Hardening Verification Report

**Phase Goal:** Fix DRAG-01 — the island's auto-expand / Quick Action picker force-triggers on any drag gesture near the notch (ordinary clicks, non-file drags), not just genuine file drags from Finder — without adding new capabilities or a heavy latency cost.
**Verified:** 2026-07-19T01:45:00Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Clicking the collapsed island (ordinary click, no external drag) never opens the Quick Action picker or force-expands the island (ROADMAP SC1 / 43-01 truth 1) | VERIFIED | `recheckDragAcceptRegion`'s arm branch (NotchWindowController.swift:1103-1105) now requires `isGenuineFileDrag(...)` in addition to geometry; an ordinary click's `.leftMouseDragged` wobble never changes `NSPasteboard(name: .drag)`'s changeCount vs. the per-gesture baseline, so the gate returns false. Confirmed on-device: 43-02-SUMMARY.md round 1, "D-04 scenarios 1 and 2 passed clean." |
| 2 | Hovering the collapsed or expanded island with no active external drag never opens the Quick Action picker (ROADMAP SC2 / 43-01 truth 2) | VERIFIED | Hover uses the separate `.mouseMoved`/`handlePointer(at:)` path, untouched by this phase's changes (confirmed by reading the diff — no `.mouseMoved` handler modified). On-device confirmed round 1. |
| 3 | A real Finder file drag still reliably auto-expands the island and shows the picker, no perceptible latency (ROADMAP SC3 / 43-01 truth 3, D-05) | VERIFIED | `isGenuineFileDrag(currentChangeCount:, gestureBaselineChangeCount:, urls:)` returns true exactly when changeCount changed this gesture AND urls non-empty — the genuine-drag case is unaffected; gate is a single pure boolean comparison on the existing per-tick poll (no new allocation/loop, per REVIEW.md T-43-02). On-device confirmed across all 4 UAT rounds; 43-02-SUMMARY.md: "all 3 D-04 scenarios confirmed on real hardware." |
| 4 | A non-file drag (Finder window move, text/URL/image drag) near the island never force-expands it (D-01) | VERIFIED | `isGenuineFileDrag` requires `!urls.isEmpty`; a non-file drag changes the pasteboard changeCount but carries no file URLs, so the gate returns false. Unit-tested: `testChangedCountWithNoURLsReturnsFalse`. |
| 5 | After a real file drag is dropped or discarded, the island returns to normal auto-collapse without requiring a manual click (D-03) | VERIFIED | Required 4 on-device UAT rounds (documented in 43-02-SUMMARY.md) to actually close: rounds 1-3 fixed a "stuck expanded forever" regression in the discard path (commits `ef2e2ca`, `6225f3f`, `745c78e`); round 4 added `InteractionEvent.dismissed` + `dismissExpandedImmediately()` (commit `bd6fac3`) to eliminate a content-flash regression. User confirmed "Perfekt klappt" after round 4. |
| 6 | `isGenuineFileDrag` pure gate function exists and is unit-tested (43-01 artifact) | VERIFIED | `DragDropSupport.swift:41-43`, exact one-line body `currentChangeCount != gestureBaselineChangeCount && !urls.isEmpty`, matching plan spec exactly. 4 unit tests in `DragApproachGeometryTests.swift` cover all 4 behavior cases. |
| 7 | `handleDragApproachEnd` refreshes the per-gesture pasteboard baseline unconditionally on every `.leftMouseUp`, before the `isDragApproaching` guard | VERIFIED | `NotchWindowController.swift:1159-1160` — `dragPasteboardChangeCount = NSPasteboard(name: .drag).changeCount` is the literal first statement, before `guard isDragApproaching else { return }`. |
| 8 | Code-review warning WR-01 (async AirDrop/Mail completion path leaves `pointerInZone` unresynced, risking silent click-swallowing) is fixed | VERIFIED | Commit `1ca597a` replaces the raw `pointerInZone = false; syncClickThrough()` tail of `dismissExpandedImmediately()` with `handlePointer(at: NSEvent.mouseLocation)`, which resyncs `pointerInZone` against the real cursor and calls `syncClickThrough()` itself — now uniform across all 4 call sites. |

**Score:** 8/8 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `Islet/Notch/DragDropSupport.swift` | `isGenuineFileDrag(currentChangeCount:gestureBaselineChangeCount:urls:)` pure gate function | VERIFIED | Present at line 41, exact signature and one-line body per plan spec, doc comment cites Phase 43/DRAG-01. |
| `IsletTests/DragApproachGeometryTests.swift` | 4 new unit tests covering `isGenuineFileDrag`'s behavior matrix | VERIFIED | `testUnchangedCountWithURLsReturnsFalse`, `testChangedCountWithNoURLsReturnsFalse`, `testChangedCountWithURLsReturnsTrue`, `testUnchangedCountWithNoURLsReturnsFalse` all present, each calling the function once. |
| `Islet/Notch/NotchWindowController.swift` | `recheckDragAcceptRegion`'s arm branch gated on `isGenuineFileDrag`; `handleDragApproachEnd` refreshes baseline unconditionally | VERIFIED | Confirmed by direct read (lines 1097-1194); gate wired into the arm condition, baseline refresh is the first statement of `handleDragApproachEnd`. |
| `Islet/Notch/NotchInteractionState.swift` | `.dismissed` InteractionEvent + `(.expanded, .dismissed) -> .collapsed` transition (43-02 addition beyond original plan scope) | VERIFIED | Line 9 (`case dismissed` added to enum), line 32 (`case (.expanded, .dismissed): return .collapsed`). 3 unit tests confirm behavior (`testExpandedDismissedCollapsesImmediately`, `testCollapsedDismissedIsNoOp`, `testHoveringDismissedIsNoOp`). |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `NotchWindowController.recheckDragAcceptRegion(currentChangeCount:)` | `DragDropSupport.isGenuineFileDrag(...)` | direct function call gating the arm branch | WIRED | Line 1104-1105: `&& isGenuineFileDrag(currentChangeCount: currentChangeCount, gestureBaselineChangeCount: dragPasteboardChangeCount, urls: urls)` inside the `if geometryInside && !isDragApproaching && !interaction.isExpanded` condition. |
| `NotchWindowController.handleDragApproachEnd()` | `dragPasteboardChangeCount` | unconditional baseline refresh before the guard | WIRED | Line 1159, confirmed positioned before line 1160's `guard isDragApproaching`. |
| `NotchWindowController.handleDragApproachTick()` | `recheckDragAcceptRegion(currentChangeCount:)` | passes freshly-read pasteboard count | WIRED | Line 1065-1066: `let count = NSPasteboard(name: .drag).changeCount; recheckDragAcceptRegion(currentChangeCount: count)`. Old self-referential `if count != dragPasteboardChangeCount` block confirmed removed (`grep -c` returns 0). |
| All 4 Quick Action resolution paths (`handleQuickActionDrop`, `finishQuickActionSharing` ← AirDrop/Mail, D-13 discard) | `dismissExpandedImmediately()` → `nextState(.expanded, .dismissed)` → `handlePointer(at:)` | shared helper call | WIRED | Confirmed by direct read: lines 1187 (discard), 1239 (Drop), 1251 (finishQuickActionSharing, covers both AirDrop and Mail via their shared completion closure). |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Test target compiles with all new/modified test files | `xcodebuild build-for-testing -scheme Islet -configuration Debug` | `** TEST BUILD SUCCEEDED **` | PASS |
| Old self-referential baseline check fully removed | `grep -c "if count != dragPasteboardChangeCount" NotchWindowController.swift` | `0` | PASS |
| No debt markers (TBD/FIXME/XXX/TODO/HACK/PLACEHOLDER) introduced in phase-modified files | `grep` across the 5 phase-modified files | no matches | PASS |

Full `xcodebuild test` (Cmd-U equivalent) was not run headless per this project's own documented constraint (memory: `xcodebuild-test-headless-hang` — the full app boots NSPanel/MediaRemote/IOBluetooth and hangs in a headless CI context). `build-for-testing` is the correct automated gate per the plan's own acceptance criteria, and it passed.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|--------------|------------|--------------|--------|----------|
| DRAG-01 | 43-01, 43-02 | Auto-expand/Quick Action picker only triggers on a genuine external file drag; plain click/hover never triggers it | SATISFIED | All observable truths above verified in code and confirmed on-device (43-02-SUMMARY.md, all 4 rounds). REQUIREMENTS.md traceability table (line 127) correctly maps DRAG-01 → Phase 43. Note: the requirement's own `[ ]` checkbox (line 41) and traceability table's "Pending" status have not yet been flipped to complete/`[x]` — this is a documentation-sync lag (known project pattern, memory `gsd-phase-complete-roadmap-gaps`), not a functional gap; ROADMAP.md's own Phase 43 top-line checkbox and Progress table already show `[x]`/complete. |

No orphaned requirements: DRAG-01 is the only requirement ID phase 43 covers and it's the only one mapped to Phase 43 in REQUIREMENTS.md's traceability table.

### Anti-Patterns Found

None. No TBD/FIXME/XXX/TODO/HACK/PLACEHOLDER markers, no empty implementations, no hardcoded-empty stub patterns found in any of the 5 files modified this phase (`DragDropSupport.swift`, `NotchWindowController.swift`, `NotchInteractionState.swift`, `DragApproachGeometryTests.swift`, `InteractionStateTests.swift`).

### Human Verification Required

None. The phase's own `checkpoint:human-verify` task (43-02) already covered all 3 ROADMAP success criteria on real hardware across 4 iterative rounds, with explicit user confirmation ("Perfekt klappt") on the final round. Per this project's own established pattern, re-running verify-work's human-check step for the same already-confirmed scenarios is not warranted.

One residual note (not a blocking gap): the WR-01 fix (commit `1ca597a`, applied after the 43-02 on-device UAT rounds concluded) changes `dismissExpandedImmediately()`'s resync behavior specifically for the AirDrop/Mail async-completion path — a code path the 4 UAT rounds never exercised (only Drop-button and discard were tested on-device). The fix reuses `handlePointer(at:)`, an existing, already-exercised helper, in a new call site, and the code reviewer traced the fix logic directly rather than asserting it. This is outside DRAG-01's core scope (it concerns click-responsiveness after AirDrop/Mail use, not auto-expand false-triggering) and does not block this phase's goal — flagging only as an optional follow-up: on a future occasion, dragging a file and choosing AirDrop or Mail, then immediately clicking the collapsed island without moving the mouse first, would confirm WR-01's fix on real hardware.

### Gaps Summary

None. All observable truths for DRAG-01 are verified in code, unit-tested where testable, and confirmed on-device where hardware-dependent. The debug build and test-target build are both green. The code-review warning (WR-01) found during this phase's own review was fixed in a follow-up commit, itself verified present in the codebase.

---

_Verified: 2026-07-19T01:45:00Z_
_Verifier: Claude (gsd-verifier)_
