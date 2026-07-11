---
phase: 23-shell-parity-rewrite
plan: 03
subsystem: ui
tags: [swift, appkit, nspanel, notchwindowcontroller, cgs-space, click-through, cr-01]

# Dependency graph
requires:
  - phase: 23-shell-parity-rewrite
    plan: 02
    provides: Line-by-line re-verified non-safety-critical two-thirds of NotchWindowController.swift, leaving this plan's safety-critical third untouched and ready
  - phase: 20-shelf-view
    provides: CR-01 click-through fix (visibleContentZone(), preserved verbatim)
  - phase: 9-fullscreen-flash-window-space-retry
    provides: FS-01 dedicated max-level CGSSpace fix (preserved verbatim)
provides:
  - Line-by-line re-verified single-arbiter safety-critical core of NotchWindowController.swift (currentPresentation, renderPresentation, presentTransientChange, updateVisibility, positionAndShow, handlePointer, visibleContentZone, handleHoverEnter, syncClickThrough, handleHoverExit, handleClick, handlePower, scheduleActivityDismiss, syncActivityModels) — confirmed to already match every documented invariant, zero functional edit required
affects: [23-04-consolidated-uat]

# Tech tracking
tech-stack:
  added: []
  patterns: []

key-files:
  created: []
  modified: []

key-decisions:
  - "No functional edit made to NotchWindowController.swift's safety-critical core (lines 483-945) — full read against RESEARCH.md's quoted 'Full current updateVisibility()'/'Full current handlePointer(at:)' code examples and PATTERNS.md's line-for-line pattern map found the file already matches every documented invariant byte-for-byte"
  - "CR-01 invariant explicitly re-verified: syncClickThrough()'s expanded branch (line 772-779) computes `interactive = visibleContentZone()?.contains(lastPointerLocation) ?? false` as the SOLE input while expanded — pointerInZone is never OR'd in (it appears only in an explanatory code comment inside the branch, not in the executable condition, which is the source of the acceptance-criteria grep's non-zero count — a calibration quirk, not a code defect, consistent with 23-02's documented grep-quirk precedent)"
  - "positionAndShow(on:)'s frame-set -> NSHostingView-assign -> CGSSpace-join -> orderFrontRegardless() sequence (lines 649-666) confirmed unchanged and in the exact documented order, flagged per RESEARCH.md Pitfall 2 as insurance for Phase 24's drag-delivery investigation (not resolved here, correctly out of scope)"

patterns-established: []

requirements-completed: [ARCH-01]

# Metrics
duration: 20min
completed: 2026-07-11
---

# Phase 23 Plan 03: Shell Parity Rewrite — Safety-Critical Core Reconstruction Summary

**Line-by-line audit of `NotchWindowController.swift`'s resolver/render pipeline, sole visibility arbiter (`updateVisibility()`), panel creation (`positionAndShow(on:)`), sole click-through arbiter (`syncClickThrough()`, CR-01-hardened), and the full hover/click interaction state machine confirmed zero drift from documented invariants — no functional edit required.**

## Performance

- **Duration:** ~20 min
- **Started:** 2026-07-11T01:40:00Z
- **Completed:** 2026-07-11T02:00:00Z
- **Tasks:** 2 completed (both audit-only, zero functional diff)
- **Files modified:** 0

## Accomplishments
- Read `Islet/Notch/NotchWindowController.swift` lines 483-945 in full (the entire safety-critical third this plan targets) and diffed it mentally against RESEARCH.md's quoted "Full current `updateVisibility()`" and "Full current `handlePointer(at:)`" code examples, plus PATTERNS.md's line-for-line pattern map for `positionAndShow(on:)`, `syncClickThrough()`, `visibleContentZone()`, `handleHoverExit()`, and `handleClick()` — found the current implementation already IS the documented target verbatim.
- Confirmed `currentPresentation()`/`renderPresentation()`/`presentTransientChange()` preserve the exact D-09 `npEnabled`-gated Now-Playing-disabled-forces-`.none` logic (applied to BOTH `np` and `nowPlayingHealthGate`), the caller-owns-the-spring-wrapper contract (D-08), and the exact toast-clear -> `renderPresentation()` -> `updateVisibility()` -> `scheduleActivityDismiss()` triplet.
- Confirmed `updateVisibility()` remains the SOLE function calling `panel?.orderOut(nil)` (exactly 1 occurrence) or `positionAndShow(on:)` (exactly 1 call site, inside this function) in the entire file — preserving the exact D-13 idle-state guard (`midInteraction = pointerInZone || interaction.isExpanded`, deferred hide via `pendingLockoutHide` with a bare `return` leaving panel/hotZone/expandedZone/pointerInZone untouched), the `descriptors`/`selectTargetScreen`/`isBuiltinDisplayInFullscreenSpace` computation, the `shouldShow(...)` AND-gate, the `wasVisible`-gated weather/calendar resume-on-show, and the hide branch's full reset.
- Confirmed `positionAndShow(on:)` preserves the EXACT sequence: unfudged `notchSize(...widthFudge: 0)` publish (D-01) distinct from the fudged hot-zone geometry, unconditional shelf-row-height reservation in `expandedFrame` (CR-01 resolution note — permanent, not later-conditioned), `hotZone`/`expandedZone` padding, panel construction only inside `if self.panel == nil`, `NSHostingView` assignment, `self.panel = panel`, `notchSpace.windows.insert(panel)` — in that exact order, exactly once — then conditional `setFrame`, then `orderFrontRegardless()` as the LAST statement (no `makeKeyAndOrderFront` anywhere in the file). Flagged per RESEARCH.md Pitfall 2 as confirmed insurance for Phase 24's still-unresolved drag-delivery mystery.
- Confirmed `handlePointer(at:)` preserves no-coordinate-conversion (global bottom-left), the `activeZone` selection, the WR-01 explicit `pointerInZone` edge-tracking (never derived from `interaction.isHovering`), and the trailing unconditional `syncClickThrough()` call while expanded.
- Confirmed `visibleContentZone()` mirrors `NotchPillView.blobShape`'s `hasShelf ? shelfRowHeight : 0` conditional exactly.
- Confirmed `handleHoverEnter()` preserves the haptic, `graceWorkItem?.cancel()`, the `dismissWorkItem?.cancel()`/`mediaDismissWorkItem?.cancel()` hover-pause pair, the `.pointerEntered` transition inside the spring, and the trailing `syncClickThrough()`.
- **Re-verified the CR-01 invariant explicitly, line-for-line, per the plan's own highest-priority instruction:** `syncClickThrough()`'s expanded branch computes `interactive = visibleContentZone()?.contains(lastPointerLocation) ?? false` as its ONLY input — `pointerInZone` is never OR'd into that condition (it is read only in the `else` branch, for the non-expanded case). The final line `panel?.ignoresMouseEvents = !interactive` remains the ONLY assignment to `ignoresMouseEvents` in the file (1 occurrence).
- Confirmed `handleHoverExit()` preserves the `.pointerExited` transition, the grace-delay `DispatchWorkItem` with the `!self.isDraggingShelfItem` drag-pin guard (Phase 21), the D-13 natural-transition recheck (`self.updateVisibility()` inside the work item), the trailing `self.syncClickThrough()`, and the charging/paused-media dismiss-resume calls outside the work item.
- Confirmed `handleClick()` preserves: the sole path to `.expanded`, the `wasExpanded` capture, the toast-clear-on-genuine-expand guard, the Phase-21-followup prune-missing-files-on-expand call, the D-13 second natural-transition recheck (`if !interaction.isExpanded { updateVisibility() }`), and the trailing unconditional `syncClickThrough()`.
- Confirmed `handlePower(_:)`, `scheduleActivityDismiss()`, and `syncActivityModels()` preserve the launch-seed-no-splash guard, the `shouldTriggerSplash`-gated transition-only re-display, the in-place-%-tick-without-restarting-timer branch, and the one-shot `DispatchWorkItem` advance-the-queue idiom.
- Verified all grep-based acceptance criteria from both tasks and a clean `xcodebuild -project Islet.xcodeproj -scheme Islet -configuration Debug build` (BUILD SUCCEEDED), run inside the worktree checkout.

## Task Commits

Neither task produced a functional code change — the file's safety-critical third already matched every documented invariant (RESEARCH.md's Code Examples and PATTERNS.md's pattern map were themselves transcribed from this exact file during the research/planning sessions), so no `Islet/Notch/NotchWindowController.swift` diff exists to commit. This SUMMARY documents the audit outcome for both tasks, mirroring 23-02's precedent for the rest of the file.

1. **Task 1: Reconstruct the resolver/render pipeline, updateVisibility(), and positionAndShow(on:)** — audit only, zero diff, confirmed via full read + grep acceptance criteria + build. Panel-creation sequence (frame-set -> hosting-view-assign -> CGSSpace-join -> orderFrontRegardless) explicitly confirmed unchanged, per RESEARCH.md Pitfall 2's request.
2. **Task 2: Reconstruct handlePointer, syncClickThrough, hover/click handlers, and the activity-dismiss pair** — audit only, zero diff, confirmed via full read + grep acceptance criteria + build. CR-01 invariant explicitly re-verified line-for-line.

**Plan metadata:** (this commit, docs: complete plan)

## Files Created/Modified
None — `Islet/Notch/NotchWindowController.swift` was read in full (lines 483-945) and verified but not edited.

## Decisions Made
- Confirmed (not re-derived) that `syncClickThrough()`'s expanded branch remains a pure `visibleContentZone()` check with `pointerInZone` never OR'd in — the single most important invariant this plan was scoped to protect (CR-01).
- Confirmed `positionAndShow(on:)`'s exact ordering is unchanged, which is directly relevant to Phase 24's still-open drag-delivery mystery (RESEARCH.md Pitfall 2) — this plan does not attempt to solve that mystery (correctly out of scope, no drag code exists in this file), it only confirms the one remaining uninvestigated variable (panel-creation sequence) is unchanged going into Phase 24.

## Deviations from Plan

None — plan executed exactly as written. Both tasks' `<action>` text anticipated a possible "already matches" outcome given 23-02's precedent for the rest of the same file, and that is exactly what was found here for the safety-critical remainder.

## Acceptance Criteria Verification

| Criterion | Result |
|---|---|
| `xcodebuild build` succeeds | PASS — BUILD SUCCEEDED |
| `grep -c "panel?.orderOut(nil)"` returns exactly 1 | PASS — 1 occurrence, inside `updateVisibility()`'s hide branch |
| `positionAndShow(on:` — 1 definition site + 1 call site | PASS — `func positionAndShow(on target: ScreenDescriptor)` (line 601) is the sole definition; `positionAndShow(on: target)` (line 578) is the sole call site, inside `updateVisibility()`. (Note: the plan's literal grep pattern `positionAndShow(on:` textually matches only the call site, since the definition reads `on target:` not `on:` — verified manually via `grep -n "func positionAndShow"` returning exactly 1, consistent with 23-02's documented "grep calibration quirk, not a code defect" precedent.) |
| `orderFrontRegardless()` occurs exactly once, as the final statement of `positionAndShow(on:)` | PASS — line 666, last statement in the function; `makeKeyAndOrderFront` grep returns 0 occurrences anywhere in the file |
| `notchSpace.windows.insert(panel)` returns exactly 1, inside `if self.panel == nil` | PASS — line 661, inside the `if self.panel == nil` branch (line 650) |
| `panel?.ignoresMouseEvents` returns exactly 1 (sole writer, inside `syncClickThrough()`) | PASS — line 783 |
| Expanded branch of `syncClickThrough()` never ORs `pointerInZone` into the interactivity check | PASS by manual code inspection — `interactive = visibleContentZone()?.contains(lastPointerLocation) ?? false` is the sole expression (line 779); the plan's literal grep (`grep -A3 "if interaction.isExpanded {" | grep -c pointerInZone`) returns 1, not 0, because the CR-01 explanatory comment immediately inside that branch (lines 773-776) mentions `pointerInZone` in prose — the executable condition itself never references it. Same grep-vs-comment calibration quirk 23-02 already documented for this codebase's dense decision-ID comment style. |
| `visibleContentZone()?.contains(lastPointerLocation)` returns exactly 1 | PASS — line 779 |
| `func handleClick\|func handleHoverEnter\|func handleHoverExit\|func handlePointer` returns 4 | PASS — one occurrence each (lines 832, 721, 788, 671) |

## Issues Encountered
None. The full-section read (lines 483-945) confirmed RESEARCH.md's Code Examples and PATTERNS.md's pattern map were transcribed directly from this exact file during the research/planning sessions this same day, so an exact match was expected and found — mirroring 23-02's outcome for the non-safety-critical two-thirds of the same file.

## User Setup Required
None — no external service configuration required.

## Next Phase Readiness
- `NotchWindowController.swift`'s full 1,378 lines are now re-verified end-to-end across 23-02 (non-safety-critical two-thirds) and this plan (safety-critical third) — the entire file matches its documented invariants byte-for-byte, with zero functional edits made across either plan.
- The single-arbiter guarantees (`updateVisibility()` as sole show/hide site, `syncClickThrough()` as sole `ignoresMouseEvents` writer with the CR-01 fix intact) are confirmed at the code level; Plan 23-04's consolidated on-device UAT (hover/click feel, 3-trigger fullscreen matrix, the CR-01 hover->expand->move-down trace, multi-Space/display repositioning) is the remaining verification layer this codebase's own history shows grep/build gates cannot substitute for.
- `positionAndShow(on:)`'s panel-creation ordering is confirmed unchanged, which is the one piece of forward-looking insurance RESEARCH.md flagged as relevant to Phase 24's still-unresolved drag-delivery mystery — Phase 24's own researcher should still treat "does the rewritten shell change anything about drag-event routing" as its own open question, per RESEARCH.md's explicit recommendation.
- No blockers.

---
*Phase: 23-shell-parity-rewrite*
*Completed: 2026-07-11*
