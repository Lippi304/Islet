---
phase: 34-quick-action-destination-picker
plan: 02
subsystem: ui
tags: [swiftui, appkit, drag-and-drop, geometry, notch, uat-revision]

# Dependency graph
requires:
  - phase: 34-quick-action-destination-picker (34-01, merged)
    provides: computeQuickActionButtonFrames(card:), IslandPresentationState.hoveredQuickActionButtonIndex, buttons-only 117pt quickActionPickerView — this plan wires all three into the real drag loop
provides:
  - "pendingDrop populated at recheckDragAcceptRegion()'s dragEntered arm edge, not at release (D-10) — the picker shows DURING the drag"
  - "discardPendingDrop() wired into recheckDragAcceptRegion()'s exit branch (D-13b/Pitfall 6 fix) — drag-out-before-release no longer leaks a session-copied temp file or leaves the picker stuck open"
  - "handleDragApproachTick() live per-button hover hit-test, publish-only-on-change (D-11/Pitfall 8)"
  - "handleDragApproachEnd() release-on-target routing via quickActionButtonFrames hit-test (D-12/D-13)"
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Controller-side analytical hit-testing against a pre-computed CGRect array on every drag tick/release — no GeometryReader/PreferenceKey round-trip (34-RESEARCH.md Pattern 3)"

key-files:
  created: []
  modified:
    - Islet/Notch/NotchWindowController.swift
    - Islet/Notch/NotchPillView.swift
    - .planning/REQUIREMENTS.md

key-decisions:
  - "Fast-forwarded the stale worktree branch (git merge --ff-only) to bring in all Phase 34 planning docs before starting — same stale-worktree issue Plan 01's SUMMARY already documented, same fix"
  - "Did not reintroduce the old release-time item-building fallback branch in handleDragApproachEnd() (34-RESEARCH.md Open Question 2) — a release with pendingDrop == nil is correctly a no-op by construction once D-10 always populates pendingDrop at dragEntered"

patterns-established: []

requirements-completed: [TRAY-02, TRAY-03, TRAY-04]

# Metrics
duration: ~35min (2 code tasks + on-device UAT checkpoint)
completed: 2026-07-15
---

# Phase 34 Plan 02: Quick Action Picker — Drag-Target Wiring (UAT Revision) Summary

**Moved pendingDrop's lifetime from "populated at release" to "populated at dragEntered, discarded on drag-exit," and replaced the old Button(action:) tap wiring with a live per-button release hit-test — the drag-target interaction model the original click-based picker's on-device UAT rejected, now approved on real hardware.**

## Performance

- **Duration:** ~35 min (2 auto tasks + 1 on-device UAT checkpoint, approved on first pass)
- **Tasks:** 3 completed (2 auto, 1 checkpoint)
- **Files modified:** 3 (2 code, 1 requirements tracking)

## Accomplishments

- `quickActionButtonFrames: [CGRect]` ivar added, computed once per `positionAndShow()` via `computeQuickActionButtonFrames(card:)`, mirroring `expandedZone`/`dragLandingMaxY`'s own "recomputed every show, read every tick" lifecycle.
- `recheckDragAcceptRegion()`'s rising arm edge now populates `pendingDrop` (D-10) — the item-building block (session-copy + `ShelfItem` construction) moved verbatim from `handleDragApproachEnd()` to inside the existing `withAnimation` block that already fires the auto-expand transition, so the picker's first-ever render already reflects the populated drop.
- `recheckDragAcceptRegion()`'s exit branch now calls `discardPendingDrop()` + `renderPresentation()` (D-13b/Pitfall 6) — closes the confirmed leak where dragging out before release left `pendingDrop` set, the picker stuck open, and a session-copied temp file orphaned on re-entry.
- `handleDragApproachEnd()` reduced, then extended with D-12/D-13 release-on-target routing: hit-tests the release point against `quickActionButtonFrames`, invokes the unchanged `handleQuickActionDrop/AirDrop/Mail()` on a hit, discards on a miss.
- `handleDragApproachTick()` publishes `presentationState.hoveredQuickActionButtonIndex` from a per-tick hit-test against `quickActionButtonFrames`, gated to fire only on actual change (D-11/Pitfall 8 — avoids re-rendering the picker dozens of times/second).
- The now-dead `onQuickActionDrop`/`onQuickActionAirDrop`/`onQuickActionMail` closure properties removed from `NotchPillView` and their call site in `makeRootView()` — selection no longer flows through a view-level tap.
- **On-device UAT (Task 3, checkpoint):** all 7 verification steps passed on real hardware on the first pass — drag-target trigger + AirDrop/Mail spike (RESEARCH.md's previously-unanswered Open Question 1 now confirmed working), Drop destination, release-off-target discard, drag-out-before-release (D-13b/Pitfall 6 fix confirmed working — picker actually disappears, no orphaned temp file), CR-01 click-through at the new 117pt height, Charging/Device transient-interrupt-and-resume (D-04/D-05), and ordinary hover/click regression. No D-09 fallback needed — AirDrop and Mail both invoked successfully from the non-key `NotchPanel` with zero focus/activation side effects.

## Task Commits

Each task was committed atomically:

1. **Task 1: D-10 trigger timing, D-13b/Pitfall 6 leak fix, Pattern 3 geometry storage** - `1840d30` (feat)
2. **Task 2: D-11 live hover publish, D-12/D-13 release-on-target routing, closure removal** - `87de0d9` (feat)
3. **Task 3: On-device UAT checkpoint** - approved by user, no code changes (D-09 fallback not triggered)

**Plan metadata:** (this commit)

## Files Created/Modified

- `Islet/Notch/NotchWindowController.swift` - `quickActionButtonFrames` ivar + its `positionAndShow()` computation; `recheckDragAcceptRegion()`'s arm block now populates `pendingDrop`, exit block now discards it; `handleDragApproachEnd()` reduced then extended with release-hit-test routing; `handleDragApproachTick()` publishes live hover index; `makeRootView()`'s 3 trailing `onQuickAction*` arguments removed
- `Islet/Notch/NotchPillView.swift` - `onQuickActionDrop`/`onQuickActionAirDrop`/`onQuickActionMail` closure properties + doc comment removed; `airDropAvailable`/`mailAvailable` untouched
- `.planning/REQUIREMENTS.md` - TRAY-02/03/04 marked complete (checkboxes + traceability table), all 3 requirements shipped per this plan's on-device-verified outcome

## Decisions Made

- Followed 34-RESEARCH.md Pattern 3/4/5 exactly as researched — analytical geometry hit-testing, no `GeometryReader`/`PreferenceKey` pipeline, item-building logic moved (not duplicated) to the `dragEntered` edge.
- Per 34-RESEARCH.md Open Question 2, did not reintroduce the old release-time item-building fallback branch in `handleDragApproachEnd()` — once D-10 always populates `pendingDrop` at `dragEntered`, a release with `pendingDrop == nil` is correctly a no-op by construction.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Worktree branch was stale relative to phase 34 planning docs**
- **Found during:** Start of execution (files_to_read step) — identical to Plan 01's own documented finding
- **Issue:** The worktree's branch (`worktree-agent-aba3cd9be9497e014`) was created from commit `d1fb5f6`, predating all of Phase 34's planning artifacts and even Plan 01's own merged work — `.planning/phases/34-quick-action-destination-picker/` didn't exist on disk, and `Islet/Notch/DragDropSupport.swift`/`IslandPresentationState.swift`/`NotchPillView.swift` didn't yet have Plan 01's contracts.
- **Fix:** Verified `git merge-base --is-ancestor HEAD gsd-new-project-setup` (HEAD was a strict ancestor, zero divergent commits) and ran `git merge --ff-only gsd-new-project-setup` — a pure fast-forward to `5d5ed44`, no rewrite, no conflict.
- **Files modified:** None (git history only)
- **Verification:** `ls .planning/phases/34-quick-action-destination-picker/` and file line-counts confirmed Plan 01's contracts present after the fast-forward; build succeeded normally afterward.
- **Committed in:** N/A (fast-forward merge, no new commit created)

**Total deviations:** 1 auto-fixed (blocking worktree-sync, same class as Plan 01's own).
**Impact on plan:** Necessary for the plan to be executable at all — no functional impact on the shipped feature.

## Issues Encountered

None beyond the worktree-sync deviation above. The on-device UAT checkpoint (Task 3) passed all 7 steps on the first attempt — no D-09 fallback, no further code iteration needed.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

TRAY-02/03/04 are now shipped and on-device verified. Phase 34 (Quick Action Destination Picker) is code-complete: both waves (34-01 geometry/view, 34-02 controller wiring) landed, the UAT-revised drag-target interaction model (D-10 through D-15) is fully implemented and approved on real hardware. No blockers for closing out v1.5 or continuing v1.6 work.

---
*Phase: 34-quick-action-destination-picker*
*Completed: 2026-07-15*

## Self-Check: PASSED

All 2 modified source files found on disk; both task commits (`1840d30`, `87de0d9`) found in git history.
