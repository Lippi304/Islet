---
phase: 20-shelf-view
plan: 03
subsystem: ui
tags: [swift, appkit, nspanel, click-through, hit-testing]

# Dependency graph
requires:
  - phase: 20-shelf-view (20-01, 20-02)
    provides: shelfCoordinator, shelfViewState, NotchPillView.blobShape's shelf-conditional height
provides:
  - visibleContentZone() hit-test scoping for the click-through invariant
  - resyncShelfViewState(animated:) single-source shelf mutation resync
affects: [21-drag-out, 22-drag-in]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Static panel reservation + scoped hit-test (strategy b): never live-resize an NSPanel mid-spring; instead narrow the click-through decision to the actual visible content rect"
    - "Single resync helper for a published view-state mirror, called from every mutation path, that also re-triggers the dependent hit-test recompute"

key-files:
  created: []
  modified:
    - Islet/Notch/NotchWindowController.swift

key-decisions:
  - "Kept panel geometry (positionAndShow/expandedFrame) byte-for-byte unchanged; fixed CR-01 purely in the click-through hit-test (visibleContentZone), per 20-REVIEW.md strategy (b) — avoids re-introducing the live-panel-resize-vs-spring race the original plan revision was flagged for"
  - "resyncShelfViewState(animated:) reads shelfCoordinator.logic.items into a local `newItems` once (per the plan's own action text) rather than repeating the exact `shelfViewState.items = shelfCoordinator.logic.items` literal three times — functionally identical dedupe, but see Deviations for a note on the plan's self-contradictory acceptance grep"

patterns-established:
  - "visibleContentZone(): narrower, independently-scoped rect (mirrors NotchPillView.blobShape's hasShelf conditional) used only by syncClickThrough(), distinct from hotZone/expandedZone (which remain the keep-open/grace-collapse zones, untouched)"

requirements-completed: [SHELF-03, SHELF-04, SHELF-05]

# Metrics
duration: ~30min
completed: 2026-07-10
---

# Phase 20 Plan 03: CR-01 Click-Through Gap Closure Summary

**Scoped `syncClickThrough()`'s hit-test to the actual visible blob rect (`visibleContentZone()`) instead of the full static panel, closing the invisible 56pt click-swallowing band under an empty shelf, and extracted a single `resyncShelfViewState(animated:)` helper so shelf delete/clear-all animate with the standard spring instead of snapping instantly.**

## Performance

- **Duration:** ~30 min
- **Started:** 2026-07-09T23:20:28Z
- **Completed:** 2026-07-09T23:20:20Z (commit d5346e5)
- **Tasks:** 2 completed
- **Files modified:** 1

## Accomplishments
- Fixed CR-01: the expanded panel's reserved-but-invisible 56pt shelf band (present whenever the shelf is empty, i.e. every default Release install) no longer swallows clicks meant for the app underneath the notch
- No live panel resize introduced anywhere — `positionAndShow`'s static max-reservation sizing is untouched, so the shrink-to-empty transition never races the SwiftUI spring
- Shelf item delete / clear-all now animate with the controller's standard spring (WR-01) instead of snapping instantly
- `shelfViewState.items` resync logic consolidated into one helper used by all three mutation paths — delete, clear-all, and the DEBUG seed (WR-02)

## Task Commits

Each task was committed atomically:

1. **Task 1: Scope syncClickThrough's hit-test to the visible blob height, not the full panel (CR-01, strategy b)** - `09dc463` (fix)
2. **Task 2: Extract resyncShelfViewState(animated:) — wire animation (WR-01), dedupe (WR-02), and refresh the click-through hit-test** - `d5346e5` (fix)

**Plan metadata:** (this commit)

## Files Created/Modified
- `Islet/Notch/NotchWindowController.swift` - Added `lastPointerLocation`, `visibleContentZone()`, rewrote `syncClickThrough()` to hit-test against the visible content zone while expanded; added `resyncShelfViewState(animated:)` and routed `handleShelfItemDelete`/`handleShelfClearAll`/`seedDebugShelfItems` through it

## Decisions Made
- Followed 20-REVIEW.md's strategy (b): fix the hit-test, not the panel geometry — see key-decisions above.
- Used a local `newItems` variable in `resyncShelfViewState` (per the plan's own action text), not three literal copies of the assignment.

## Deviations from Plan

### Non-blocking plan-authoring inconsistency (documented, not auto-fixed)

**1. Task 2's acceptance_criteria grep conflicts with Task 2's own action text**
- **Found during:** Task 2
- **Issue:** The action text explicitly instructs: "read `let newItems = shelfCoordinator.logic.items` once" then assign `shelfViewState.items = newItems` in both the animated and non-animated branches. But the acceptance_criteria for the same task greps for the literal string `shelfViewState.items = shelfCoordinator.logic.items` and expects it to return exactly 1 — following the action text as written makes that literal string appear 0 times (it's been split across a local variable), not 1.
- **Resolution:** Followed the more detailed, more specific action text (matches the plan author's likely actual intent: single resync call site instead of the old 3x duplication) rather than the stale/inconsistent literal grep. The functional goal (WR-02: one resync line, not three duplicates) is fully achieved and verified by the other three acceptance criteria for this task, which all pass:
  - Exactly one `private func resyncShelfViewState(animated: Bool = true)` declaration
  - `handleShelfItemDelete`/`handleShelfClearAll` call `resyncShelfViewState()` with the `true` default
  - `seedDebugShelfItems` calls `resyncShelfViewState(animated: false)`
  - The animated branch uses the exact same spring constants (`springResponse`/`springDamping`) as the rest of the file
- **Files modified:** Islet/Notch/NotchWindowController.swift
- **Verification:** `xcodebuild build -scheme Islet -configuration Debug` succeeds; manual grep checks above confirm dedupe.
- **Committed in:** d5346e5 (Task 2 commit)

---

**Total deviations:** 1 (plan-authoring inconsistency in acceptance criteria vs. action text, non-blocking)
**Impact on plan:** None on functionality — the WR-02 dedupe goal is met exactly as the action text prescribed. No scope creep, no architectural change.

## Issues Encountered
- The spawned worktree's branch (`worktree-agent-a21bb389c811ed5fe`) had been created from a stale base commit 106 commits behind the branch actually containing Phase 20 (`gsd-new-project-setup`) — the plan file, `.planning/phases/20-shelf-view/`, and the target source files did not exist in the worktree at session start. Confirmed via `git merge-base` that the worktree's HEAD was an exact ancestor of `gsd-new-project-setup` with zero divergent local commits, so a lossless `git merge --ff-only gsd-new-project-setup` was used to bring the worktree up to date before any plan work began. No commits were lost or rewritten; this was a pure fast-forward.
- The plan's hardcoded `<verify>` command path (`cd /Users/lippi304/conductor/workspaces/notch/algiers && ...`) points at a different checkout than this worktree. Ran `xcodegen generate` + `xcodebuild build` against the worktree's own root instead (`/Users/lippi304/conductor/repos/notch/.claude/worktrees/agent-a21bb389c811ed5fe`) so the build actually exercises this plan's edited files. Both builds succeeded (`BUILD SUCCEEDED`).

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- CR-01 (blocking finding from `20-VERIFICATION.md`/`20-REVIEW.md`) is closed at the code level; the on-device manual checks specified in the plan's `<verification>` section (empty-shelf click-through, non-empty-shelf shelf interactivity, animated delete/clear-all) still need to be run before re-running `/gsd:verify-work 20`.
- Phases 21 (Drag-Out) and 22 (Drag-In) inherit this same panel-reservation + click-through-scoping foundation; no further changes needed here for those phases to build on top of.

---
*Phase: 20-shelf-view*
*Completed: 2026-07-10*

## Self-Check: PASSED

- FOUND: `.planning/phases/20-shelf-view/20-03-SUMMARY.md`
- FOUND: `09dc463` (Task 1 commit)
- FOUND: `d5346e5` (Task 2 commit)
- FOUND: `e260b81` (SUMMARY commit)
