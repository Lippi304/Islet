---
phase: 34-quick-action-destination-picker
plan: 01
subsystem: ui
tags: [swiftui, appkit, drag-and-drop, geometry, notch]

# Dependency graph
requires:
  - phase: 34-quick-action-destination-picker (34-02, original spike, merged)
    provides: PendingDrop struct, .quickActionPicker(PendingDrop) resolver case, QuickActionSharingService, handleQuickActionDrop/AirDrop/Mail controller handlers — all reused verbatim
provides:
  - "computeQuickActionButtonFrames(card:) — pure, unit-tested analytical geometry for the 3 destination buttons' live global frames"
  - "IslandPresentationState.hoveredQuickActionButtonIndex — controller-write/view-read carrier for D-11's drag-hover highlight"
  - "NotchPillView's buttons-only Quick Action picker at 117pt (quickActionPickerView/quickActionButtonRow/quickActionButton, all argument-free re: PendingDrop)"
affects: [34-02 (Wave 2 controller wiring: pendingDrop trigger timing, drag-out leak fix, live hit-testing into the real drag loop)]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Analytical per-button live global frame computation (mirrors expandedNotchFrame/topPinnedFrame), deliberately not a GeometryReader/PreferenceKey round-trip"
    - "Controller computes, view renders — hoveredQuickActionButtonIndex published only on change (Pitfall 8), view is a pure consumer"

key-files:
  created: []
  modified:
    - Islet/Notch/DragDropSupport.swift
    - IsletTests/DragApproachGeometryTests.swift
    - Islet/Notch/IslandPresentationState.swift
    - Islet/Notch/NotchPillView.swift

key-decisions:
  - "Followed 34-RESEARCH.md Pattern 3 exactly: pure arithmetic geometry function, zero AppKit/SwiftUI dependency, no PreferenceKey pipeline"
  - "Kept case .quickActionPicker: on its own line (two-line style) to match this switch's own established convention (every other case does this) rather than force a single-line grep match"

patterns-established: []

requirements-completed: [TRAY-02]

# Metrics
duration: 25min
completed: 2026-07-15
---

# Phase 34 Plan 01: Quick Action Picker Geometry & Buttons-Only View Summary

**`computeQuickActionButtonFrames(card:)` pure per-button hit-test geometry, `IslandPresentationState.hoveredQuickActionButtonIndex` carrier, and a buttons-only 117pt Quick Action picker view — the UAT-revised interaction contract Plan 02 wires into the live drag loop.**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-07-15T19:00:00Z (approx, worktree fast-forward + context load)
- **Completed:** 2026-07-15T19:18:52Z
- **Tasks:** 2 completed
- **Files modified:** 4

## Accomplishments
- `computeQuickActionButtonFrames(card:)` added to `DragDropSupport.swift` as a pure top-level function, unit-tested with 6 new tests (column count, equal width, left/right inset, bottom-row placement, origin-independence) — zero AppKit/SwiftUI runtime dependency, mirrors `isWithinDragAcceptRegion`'s existing style.
- `IslandPresentationState.hoveredQuickActionButtonIndex: Int?` added as the controller-write/view-read carrier for D-11's live drag-hover highlight.
- `NotchPillView`'s Quick Action picker rewritten: preview block deleted entirely (D-14), height shrunk 188pt → 117pt (D-15), `quickActionButton` no longer wraps `Button(action:)` (D-12), gains a fixed 22×22pt icon frame (Pitfall 9 fix) and D-11's hover fill/scale styling driven purely from `presentationState.hoveredQuickActionButtonIndex`.
- 2 new `#Preview`s ("Idle" / "AirDrop Hovered") replace the old single-file/multi-file previews, demonstrating D-11's hover states.

## Task Commits

Each task was committed atomically:

1. **Task 1: computeQuickActionButtonFrames(card:) — the analytical per-button geometry seam** - `8af36b6` (feat)
2. **Task 2: NotchPillView.swift — buttons-only picker at 117pt with controller-driven hover** - `2b0cf50` (feat)

**Plan metadata:** (this commit)

## Files Created/Modified
- `Islet/Notch/DragDropSupport.swift` - Added `computeQuickActionButtonFrames(card:)`, pure geometry, after `isWithinDragAcceptRegion`
- `IsletTests/DragApproachGeometryTests.swift` - Added 6 unit tests for `computeQuickActionButtonFrames(card:)`
- `Islet/Notch/IslandPresentationState.swift` - Added `hoveredQuickActionButtonIndex: Int? = nil`
- `Islet/Notch/NotchPillView.swift` - `quickActionPickerContentHeight` 188→117; deleted `quickActionPreview`; `quickActionPickerView`/`quickActionButtonRow` now argument-free; `quickActionButton` rewritten (no `Button(action:)`, fixed icon frame, hover fill/scale); body switch case updated; 2 `#Preview`s replaced

## Decisions Made
- Implemented Pattern 3 (analytical geometry) exactly as researched — no `GeometryReader`/`PreferenceKey` pipeline, per 34-RESEARCH.md's explicit recommendation and Pitfall 7's coordinate-space warning.
- Preserved the switch statement's existing two-line `case:` / content style rather than forcing a single-line match for the plan's literal acceptance-criteria grep string (see Deviations).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Worktree branch was stale relative to phase 34 planning docs**
- **Found during:** Start of execution (files_to_read step)
- **Issue:** The worktree's branch (`worktree-agent-a61bc38563b2d214e`) was created from a commit (`d1fb5f6`) that predates all of Phase 34's planning artifacts (CONTEXT.md, RESEARCH.md, UI-SPEC.md, PLAN.md) — none of `.planning/phases/34-quick-action-destination-picker/*` existed on disk, blocking every read in `<files_to_read>`.
- **Fix:** Verified `git merge-base --is-ancestor HEAD gsd-new-project-setup` (HEAD was a strict ancestor, zero divergent commits on the worktree branch) and ran `git merge --ff-only gsd-new-project-setup` — a pure fast-forward, no rewrite, no conflict, brings the worktree branch current with all already-committed planning docs.
- **Files modified:** None (git history only — brought in already-committed commits)
- **Verification:** `ls .planning/phases/34-quick-action-destination-picker/` confirmed all plan files present after the fast-forward; build succeeded normally afterward.
- **Committed in:** N/A (fast-forward merge, no new commit created — HEAD simply advanced)

**2. [Rule 1 - Bug] Test file `Int`/`CGFloat` type mismatch**
- **Found during:** Task 1 (`build-for-testing` step)
- **Issue:** `let expectedWidth = (420 - 2 * 16 - 2 * 16) / 3` inferred as `Int`, but `XCTAssertEqual(frame.width, expectedWidth, accuracy:)` requires `CGFloat` — compile error in the new test file.
- **Fix:** Added explicit `: CGFloat` type annotation to the `expectedWidth` literal.
- **Files modified:** `IsletTests/DragApproachGeometryTests.swift`
- **Verification:** `xcodebuild build-for-testing` succeeded after the fix.
- **Committed in:** `8af36b6` (part of Task 1 commit)

**3. [Rule 2 - Missing Critical, minor] Case-statement grep-literal vs. house style**
- **Found during:** Task 2 acceptance-criteria check
- **Issue:** The plan's acceptance criterion greps for the literal single-line string `case \.quickActionPicker: quickActionPickerView()`, but every other case in this `switch` (14 cases) uses a two-line `case X:` / content-on-next-line style. Writing a single-line case here would be inconsistent with the file's own established convention.
- **Fix:** Kept the two-line style (`case .quickActionPicker:` / `quickActionPickerView()` on the next line) consistent with all 13 sibling cases. Functionally identical — verified via `grep -n "case \.quickActionPicker"` and by reading the switch body directly.
- **Files modified:** `Islet/Notch/NotchPillView.swift`
- **Verification:** Manual read of the switch body confirms the case renders `quickActionPickerView()` with no arguments, matching the plan's interface contract; build succeeds.
- **Committed in:** `2b0cf50` (part of Task 2 commit)

---

**Total deviations:** 3 auto-fixed (1 blocking worktree-sync, 1 test-compile bug, 1 style-consistency note)
**Impact on plan:** All necessary for the plan to be executable/correct at all (worktree sync) or for the build to succeed (type fix). The case-style deviation is cosmetic and does not affect functional correctness — the acceptance criterion's underlying intent (buttons-only case, argument-free) is fully met.

## Issues Encountered
None beyond the deviations documented above.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Plan 02 (Wave 2) can now wire against a fully-defined, already-tested contract:
- `computeQuickActionButtonFrames(card:)` — ready for the controller to call once per `positionAndShow()`, store as an ivar, and hit-test against on every drag tick / release.
- `IslandPresentationState.hoveredQuickActionButtonIndex` — ready for the controller's `handleDragApproachTick()` to assign, only on change.
- `quickActionPickerView()`/`quickActionButtonRow()`/`quickActionButton(...)` — render-only, no remaining PendingDrop dependency, no `Button(action:)` to remove.

No blockers. `onQuickActionDrop`/`onQuickActionAirDrop`/`onQuickActionMail` closures on `NotchPillView` are deliberately left in place (still wired in `NotchWindowController.makeRootView`) per this plan's `<interfaces>` note — Plan 02 removes both the properties and their call site together, in the same commit, alongside the D-10 trigger-timing move and the D-13b/Pitfall 6 leak fix.

---
*Phase: 34-quick-action-destination-picker*
*Completed: 2026-07-15*

## Self-Check: PASSED

All 4 modified files found on disk; both task commits (`8af36b6`, `2b0cf50`) found in git history.
