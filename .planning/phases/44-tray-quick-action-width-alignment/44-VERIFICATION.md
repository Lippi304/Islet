---
phase: 44-tray-quick-action-width-alignment
verified: 2026-07-19T16:10:00Z
status: passed
score: 7/7 must-haves verified
overrides_applied: 0
---

# Phase 44: Tray & Quick Action Width Alignment Verification Report

**Phase Goal:** The Tray view (and island) widens so every file icon fits without visual squeeze,
and the drag-preview Quick Action picker always renders at that same width — bundled into one
phase so the shared width constant is established once and both consumers stay in sync by
construction (ROADMAP wording). TRAY-06/DRAG-02.

**Verified:** 2026-07-19T16:10:00Z
**Status:** passed
**Re-verification:** No — initial verification

**Note on scope:** Plan 44-01's original `must_haves` (frontmatter) describe the initial D-03/D-05
decision that the picker must match Tray's **full** footprint (width AND height, including the
switcher-row addend, 650×189). During the 44-02 on-device checkpoint, the user explicitly
superseded this twice (D-09, then D-10, recorded in `44-CONTEXT.md`): the picker reverted to a
content-hugging height (117pt), and `trayContentHeight` was then tied directly to
`quickActionPickerContentHeight` so both share one 117pt content-height constant, rather than the
picker matching Tray's rendered switcher-inclusive height. This verification checks the codebase
against the **current, user-approved D-09/D-10 state**, not the plan's original literal wording,
per the explicit instruction accompanying this verification task. Width alignment (D-04,
`traySize.width` = 650 at all sites) is unaffected by D-09/D-10 and was verified as originally
specified.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | (ROADMAP SC1) At typical file counts, every Tray file icon fits without visual squeeze; icon/button sizes unchanged from today | VERIFIED | `traySize.width` = 650 unchanged (`NotchPillView.swift:663`); `shelfRow`'s horizontal ScrollView / icon sizes untouched by this phase. Height reduction (145→117, D-10) verified non-clipping: `cameraClearance(42) + trayShelfRowHeight(70) = 112` fits inside 117 (WR-02 code-review math correction, confirmed at `NotchPillView.swift:668-676`); 44-02 SUMMARY records round-6 on-device UAT approval of a populated shelf at this height. |
| 2 | (ROADMAP SC2) Quick Action picker renders at the exact same **width** as the real Tray view — no visible mismatch | VERIFIED | All 3 geometry sites use `NotchPillView.traySize.width` (650): `NotchWindowController.swift:1028` (panel reservation), `NotchWindowController.swift:1397` (contentSize branch), `NotchPillView.swift:1512` (blobShape call). Confirmed by direct read, not just grep. |
| 3 | (ROADMAP SC3) Click-through hit-testing remains correct at the new geometry — on-device trace closes off the CR-01/CR-02 dead-zone/click-swallowing failure class | VERIFIED (with tracked caveat) | 44-02's on-device checkpoint (6 rounds) explicitly ran the D-08a hover→expand→move-down trace. No CR-01/CR-02-class click-swallowing or dead-zone regression was reported. A **distinct** symptom ("island briefly disappears" during the same trace) was found, explicitly scoped **out of Phase 44** by the user on-device, and captured as a dedicated follow-up todo (`.planning/todos/pending/2026-07-19-island-briefly-disappears-during-click-through.md`) rather than silently dropped — status "pre-existing vs. newly surfaced" left unconfirmed pending a dedicated `/gsd-debug` session. This is a real open item but is not a CR-01/CR-02-class regression per the todo's own analysis, and was a deliberate, documented human scoping decision, not an unverified claim. |
| 4 | (Plan 44-01/44-02, superseded by D-09/D-10) Picker and Tray share one width AND one content-height constant | VERIFIED (per superseded D-09/D-10) | Width: both consume `traySize.width` (650). Height: `trayContentHeight` is now literally defined as `= quickActionPickerContentHeight` (`NotchPillView.swift:677`), i.e. both content-height values (117) come from one named constant — single source of truth, matching D-10's explicit request ("Die Höhe will ich genauso bei beiden"). Note: the picker's total on-screen box (117, `showSwitcher: false`) and Tray's total on-screen box (117 + switcherRowHeight 44 = 161, `showSwitcher: true`) still differ because Tray shows a switcher row the picker never renders (D-06, unchanged) — this is the accepted, by-design outcome of D-09/D-10, not a residual bug. |
| 5 | 3 Drop/AirDrop/Mail buttons stay a fixed, non-reflowing size, centered in the (now larger) card | VERIFIED | `quickActionButtonWidth` = 130 (fixed, `NotchPillView.swift:743`), applied via `.frame(maxWidth: Self.quickActionButtonWidth)` (`NotchPillView.swift:1559`) — capped rather than flex-filling per round-2 gap-closure fix, matching D-06's "no scaling up" intent (the plan's initial flex-fill implementation had unintentionally violated this at the wider 650pt card; the round-2 fix corrected it). |
| 6 | Button tap-zones (`computeQuickActionButtonFrames`) stay correctly anchored and in-bounds at the new card dimensions | VERIFIED | Function rewritten to fixed-width, centered, `cameraClearance`-anchored math (`DragDropSupport.swift:68-81`); lock-in unit test `testQuickActionButtonFramesFitWithinPickerCard` (`IsletTests/DragApproachGeometryTests.swift:99-109`) asserts all 3 frames stay within card bounds, built from live production constants (not hardcoded numbers); `xcodebuild build-for-testing` passes. `quickActionButtonFrames` (`NotchWindowController.swift:1032`) feeds both the hover-highlight tick (`:1076`) and the release hit-test (`:1176`) from the same aligned geometry. |
| 7 | Requirements TRAY-06 / DRAG-02 satisfied and traceable | VERIFIED | Both IDs declared in both plans' frontmatter (`44-01-PLAN.md`, `44-02-PLAN.md`); both marked `[x]` / "Complete" in `.planning/REQUIREMENTS.md:42,46,128-129`; no orphaned requirement IDs mapped to Phase 44 beyond these two. |

**Score:** 7/7 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `Islet/Notch/NotchWindowController.swift` | 3 geometry sites (reservation, contentSize) aligned to `traySize.width` / current content-height constant | VERIFIED | Lines 1027-1029 and 1390-1398 both use `NotchPillView.traySize.width` + `NotchPillView.quickActionPickerContentHeight` consistently. |
| `Islet/Notch/NotchPillView.swift` | `quickActionPickerView()`'s `blobShape` call aligned; orphaned constant removed/replaced consistently; `trayContentHeight` tied to `quickActionPickerContentHeight` | VERIFIED | Line 1512 passes `width: Self.traySize.width, height: Self.quickActionPickerContentHeight`; `trayContentHeight` at line 677 `= quickActionPickerContentHeight`; no dangling reference to the original plan's `trayContentHeight + switcherRowHeight` picker height remains (correctly superseded). |
| `Islet/Notch/DragDropSupport.swift` | `computeQuickActionButtonFrames` re-anchored, no defensive regression | VERIFIED | Fixed-width, centered, `cameraClearance`-anchored (lines 68-81); confirmed consistent with AppKit's bottom-left-origin coordinate convention by hand-tracing the math. |
| `IsletTests/DragApproachGeometryTests.swift` | Lock-in test present, uses production constants | VERIFIED | `testQuickActionButtonFramesFitWithinPickerCard` (renamed from the plan's originally-specified name, functionally equivalent) present at line 99, builds `productionCard` from `NotchPillView.traySize.width`/`quickActionPickerContentHeight` (lines 48-50), all 6 pre-existing tests rebuilt against the same production constants (no stale 420×117 literals found). |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `NotchWindowController.positionAndShow()` `quickActionPickerFrame` | `NotchPillView.traySize`/`quickActionPickerContentHeight` | direct static constant reference | WIRED | Confirmed at `NotchWindowController.swift:1027-1029`. |
| `NotchPillView.quickActionPickerView()` | `blobShape(width:height:...)` | explicit override args | WIRED | Confirmed at `NotchPillView.swift:1511-1513`. |
| `NotchWindowController.quickActionButtonFrames` | `DragDropSupport.computeQuickActionButtonFrames(card:)` | computed once per `positionAndShow()`, consumed by hover tick + release hit-test | WIRED | Confirmed at `NotchWindowController.swift:1032` (compute), `:1076` (hover), `:1176` (release). |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Debug build compiles clean with the new geometry | `xcodebuild build -scheme Islet -configuration Debug` | `** BUILD SUCCEEDED **` | PASS |
| Test target compiles clean with the new lock-in test | `xcodebuild build-for-testing -scheme Islet -configuration Debug` | `** TEST BUILD SUCCEEDED **` | PASS |
| No dangling debt markers in phase-modified files | `grep -E "TBD|FIXME|XXX"` across 4 modified source/test files | no matches | PASS |
| Actual on-device UI behavior (spring feel, visual size match, click-through) | N/A — requires running app | Already covered by 44-02's own 6-round on-device checkpoint (documented, not re-run here) | SKIP (covered by prior checkpoint) |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| TRAY-06 | 44-01, 44-02 | Tray widened so every file icon fits without visual squeeze; icon/button sizes unchanged | SATISFIED | Phase 32's 650pt/scroll implementation unchanged; height reduction verified non-clipping and on-device approved. |
| DRAG-02 | 44-01, 44-02 | Quick Action picker renders at the exact same width as the real Tray view | SATISFIED | `traySize.width` (650) used consistently at all 3 geometry sites for both picker and Tray. |

No orphaned requirements found (REQUIREMENTS.md maps only TRAY-06/DRAG-02 to Phase 44, both declared in plan frontmatter).

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `Islet/Notch/NotchPillView.swift` / `NotchWindowController.swift` | 201-202, 1534-1537 / 1174-1194 | Quick Action `enabled:` (AirDrop/Mail dim) is cosmetic-only, no controller-side gate (44-REVIEW.md WR-01) | INFO | Pre-existing since Phase 34, not introduced or worsened by this phase; both flags hardcoded `true` today so currently dead code. Captured as a todo (`2026-07-19-quick-action-disabled-state-has-no-controller-gate.md`), not a Phase 44 blocker. |
| `Islet/Notch/NotchWindowController.swift` (click-through hot-zone path) | n/a | "Island briefly disappears" during hover→expand→move-down trace | INFO (tracked) | Found during 44-02's required D-08a trace, explicitly scoped out of Phase 44 by the user on-device, captured as a dedicated debug todo. Not a CR-01/CR-02-class click-swallowing/dead-zone regression per the todo's own analysis — the specific ROADMAP SC3 failure class was not reproduced. |

Code review (`44-REVIEW.md`) WR-02 (stale/miscounted `trayContentHeight` risk comment) was fixed in commit `3f248f2`, confirmed present and corrected in the current file.

### Human Verification Required

None. The phase's own `44-02-PLAN.md` `checkpoint:human-verify` task already executed all 4 required on-device checks (picker-vs-Tray size match, click-through trace, button tap-zone re-check, TRAY-06 re-verification) across 6 iterative rounds, with fixes applied and re-confirmed on-device for each round, per `44-02-SUMMARY.md` and the corresponding commit history (`39ec98c` … `1910ddd` … `6f5c68e`). Per this project's own established convention (skip re-requesting on-device verification when a phase's own human-verify checkpoint already covered its ROADMAP success criteria), no further human action is requested by this verification pass.

The one open item (disappearing island during click-through) has already been triaged by the user on-device and routed to a dedicated follow-up todo — it does not require a fresh human decision here.

### Gaps Summary

No blocking gaps. All ROADMAP success criteria and both requirement IDs (TRAY-06, DRAG-02) are
satisfied against the current, user-approved D-09/D-10 geometry state. One pre-existing, explicitly
out-of-scope UI anomaly (island briefly disappearing during click-through) was found during this
phase's own on-device checkpoint and correctly deferred to a tracked todo rather than silently
dropped — flagged here for visibility but not blocking, consistent with the user's own on-device
scoping decision.

---

*Verified: 2026-07-19T16:10:00Z*
*Verifier: Claude (gsd-verifier)*
