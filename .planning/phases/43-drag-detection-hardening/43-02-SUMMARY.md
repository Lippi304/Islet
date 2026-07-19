---
phase: 43-drag-detection-hardening
plan: 02
subsystem: ui
tags: [swiftui, appkit, nsevent, state-machine, drag-and-drop]

# Dependency graph
requires:
  - phase: 43-drag-detection-hardening
    provides: isGenuineFileDrag pasteboard-change gate (plan 43-01)
provides:
  - On-device confirmation of DRAG-01's false-trigger fix against all 3 D-04 scenarios
  - A dedicated `.dismissed` InteractionEvent (expanded -> collapsed, immediate, no grace defer)
  - dismissExpandedImmediately() — shared immediate-collapse helper for all 4 Quick Action
    picker resolution paths (Drop, AirDrop, Mail, discard)
affects: [any future phase touching NotchWindowController's drag/picker/collapse logic]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Picker/gesture resolution transitions call dismissExpandedImmediately() (a dedicated
       .dismissed state-machine event), never the hover-exit grace-timer path — a resolved
       gesture is a definitive completion, not a lingering hover."

key-files:
  created: []
  modified:
    - Islet/Notch/NotchWindowController.swift
    - Islet/Notch/NotchInteractionState.swift
    - IsletTests/InteractionStateTests.swift

key-decisions:
  - "Quick Action picker resolution (Drop/AirDrop/Mail/discard) always force-collapses via a new
     .dismissed state-machine event instead of deferring through the existing hover-exit grace
     timer — confirmed with the user during round 4's on-device UAT after 3 prior rounds each
     surfaced a different way the deferred/edge-detected approach left the island stuck expanded
     or briefly flashed the underlying content."
  - "The Drop action's collapse must happen before renderPresentation() runs so IslandResolver's
     isExpanded check is already false — otherwise .trayExpanded renders for one frame even
     though viewSwitcherState.selectedView = .tray is set correctly and permanently for the next
     manual open."

patterns-established:
  - "dismissExpandedImmediately(): a shared 'force close now' helper for any gesture-completion
     event, distinct from the pointer-driven hover-exit/grace-timer path. Reach for this whenever
     a NEW terminal user action needs to close the island without waiting on hover state."

requirements-completed: [DRAG-01]

# Metrics
duration: ~2h (across 4 on-device UAT rounds)
completed: 2026-07-19
---

# Phase 43 Plan 02: On-Device Drag Detection UAT Summary

**Confirmed DRAG-01's false-trigger fix on-device across 4 UAT rounds, closing 3 additional real regressions found only by physically testing the gesture (stuck-expanded island, and a picker-resolution content flash) that no build/unit-test gate could have caught.**

## Performance

- **Duration:** ~2h across 4 on-device verification rounds
- **Started:** 2026-07-19T02:52Z
- **Completed:** 2026-07-19T03:26Z
- **Tasks:** 1 (checkpoint:human-verify), re-executed 4 times as each round's fix surfaced the next issue
- **Files modified:** 3 (`NotchWindowController.swift`, `NotchInteractionState.swift`, `InteractionStateTests.swift`)

## Accomplishments
- Confirmed Plan 43-01's `isGenuineFileDrag` pasteboard-gate fix on-device: ordinary clicks and
  hover-with-no-drag never open the Quick Action picker (D-04 scenarios 1 and 2 passed clean on
  the first round).
- Found and fixed a real regression the plan's own build/test gates could not detect: dragging a
  file toward the island then discarding it (dragging back out, or releasing without hitting a
  button) left the island permanently stuck in its expanded state, because the auto-collapse
  grace-timer machinery was never actually wired to fire for a drag-driven expand (only a real
  `.mouseMoved`-driven hover-exit could trigger it, and drag sessions never produce `.mouseMoved`
  events).
- Found and fixed a second-order regression: even after the stuck-forever bug was fixed, resolving
  the picker (via Drop, AirDrop/Mail, or discard) still visibly flashed the underlying "normal"
  expanded content (Now-Playing/Home, or briefly the File Tray for the Drop case) for the ~0.4s
  grace-timer window before collapsing.
- Added a dedicated, unit-tested `.dismissed` state-machine transition and a shared
  `dismissExpandedImmediately()` helper so all 4 picker-resolution paths close the island
  immediately and cleanly, with no dependency on hover/pointer edge-detection.

## Task Commits

Task 1 (checkpoint:human-verify) required 4 on-device rounds, each producing its own fix commit
(plan 43-01's prior commits are `00f340a`/`d8eeeb6`, not part of this plan):

1. **Round 1 fix** — `ef2e2ca` (fix): seeded `pointerInZone = true` on drag-approach arm and
   re-synced via `handlePointer(at:)` on exit. Insufficient — see round 2.
2. **Round 2 fix** — `6225f3f` (fix): replaced the round-1 approach with a direct
   `handleHoverExit()` call on drag-exit, since `isWithinDragAcceptRegion`'s extra Y-margin term
   let a drag exit past round 1's zone-geometry check undetected.
3. **Round 3 fix** — `745c78e` (fix): applied the same direct-collapse fix to the D-13
   discard-without-a-button-hit release path in `handleDragApproachEnd`, ordered carefully so the
   function's own trailing `handlePointer(at:)` resync couldn't immediately cancel it.
4. **Round 4 fix** — `bd6fac3` (fix): superseded rounds 2-3's `handleHoverExit()`-based approach
   with a proper `.dismissed` state-machine event + `dismissExpandedImmediately()` helper, adding
   unit test coverage, to eliminate the remaining picker-resolution content flash across all 4
   resolution paths (Drop, AirDrop, Mail, discard).

**Plan metadata:** (this commit) — docs: complete plan

## Files Created/Modified
- `Islet/Notch/NotchWindowController.swift` — drag-approach exit handling, D-13 discard path, and
  all 3 Quick Action resolution handlers (`handleQuickActionDrop`, `finishQuickActionSharing`)
  now route through the new `dismissExpandedImmediately()` helper.
- `Islet/Notch/NotchInteractionState.swift` — added `InteractionEvent.dismissed` and its
  `(.expanded, .dismissed) -> .collapsed` transition to the pure `nextState` reducer.
- `IsletTests/InteractionStateTests.swift` — 3 new tests covering the `.dismissed` transition
  (expanded collapses immediately; collapsed/hovering are no-ops).

## Decisions Made
- Quick Action picker resolution (any of Drop/AirDrop/Mail/discard) must force-collapse
  immediately via a dedicated state-machine event, never defer through the hover-exit grace
  timer — confirmed explicitly with the user via `AskUserQuestion` during round 4 after 3 prior
  rounds of iterative on-device fixes each addressed a narrower symptom.
- Kept the fix inside the existing pure `nextState` reducer + its unit test suite (rather than
  ad-hoc AppKit-side state mutation) to preserve the project's established "all interaction
  transitions go through one testable pure function" discipline (ISL-03 pattern).

## Deviations from Plan

This plan's single task was `checkpoint:human-verify` with `files_modified: []` — verification
only, no code changes expected. On-device testing found 3 real regressions not visible to any
automated gate, requiring 4 rounds of targeted fixes before the on-device behavior matched the
plan's stated success criteria.

### Auto-fixed Issues

**1. [Regression found during human-verify] Island stuck permanently expanded after discarding a drag**
- **Found during:** Task 1, round 1 (real Finder drag, discard variant)
- **Issue:** The auto-collapse grace-timer was never wired to fire for a drag-driven expand;
  `pointerInZone` edge-detection (the only path to `handleHoverExit()`) depends on `.mouseMoved`
  events, which never occur during an active `.leftMouseDragged` session.
- **Fix:** 3 iterations (rounds 1-3) converging on directly invoking the collapse path instead of
  relying on pointer-edge detection, applied to both the drag-exit-before-release path and the
  D-13 release-without-button-hit path.
- **Files modified:** `Islet/Notch/NotchWindowController.swift`
- **Verification:** On-device re-test, confirmed by user after round 3.
- **Committed in:** `ef2e2ca`, `6225f3f`, `745c78e`

**2. [Regression found during human-verify] Brief flash of underlying content on picker resolution**
- **Found during:** Task 1, round 4 (both the Drop button and discard variants)
- **Issue:** Resolving the picker cleared `pendingDrop` while `interaction.phase` was still
  `.expanded`, so `IslandResolver` briefly rendered the underlying Home/Now-Playing content (or
  `.trayExpanded` for the Drop case) before the grace-timer collapse caught up.
- **Fix:** Added a dedicated `.dismissed` state-machine event and `dismissExpandedImmediately()`
  helper; all 4 resolution paths now force collapse before the next render.
- **Files modified:** `Islet/Notch/NotchWindowController.swift`, `Islet/Notch/NotchInteractionState.swift`,
  `IsletTests/InteractionStateTests.swift`
- **Verification:** On-device re-test, user confirmed "Perfekt klappt" (works perfectly).
- **Committed in:** `bd6fac3`

---

**Total deviations:** 2 auto-fixed regressions (4 fix commits total), both found exclusively via
on-device human verification.
**Impact on plan:** Both fixes were necessary to meet the plan's own stated success criteria (D-03
auto-collapse, no stuck states). No unrelated scope creep — every change traces directly to a
concrete on-device repro the user reported.

## Issues Encountered
- Each of rounds 1-3 fixed a real but narrower slice of the bug; the user's precise, repeated
  on-device repro reports were what surfaced the next layer each time. Round 4 required an
  explicit `AskUserQuestion` clarification (immediate-collapse vs. keep-grace-delay-but-fix-flash)
  since the requirement had shifted from "the island must eventually collapse" to "no visible
  flash of any other content," which is a stricter, previously-unstated bar.

## User Setup Required
None — no external service configuration required.

## Next Phase Readiness
- DRAG-01 is now genuinely closed: all 3 D-04 scenarios confirmed on real hardware, including the
  discard variants that were the actual point of this hardening phase.
- `dismissExpandedImmediately()` and the `.dismissed` event are reusable for any future
  gesture-completion-driven collapse (e.g. a future picker/action type) — reach for these instead
  of re-deriving pointer-edge-detection tricks.

---
*Phase: 43-drag-detection-hardening*
*Completed: 2026-07-19*
