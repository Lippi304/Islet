---
phase: 44-tray-quick-action-width-alignment
plan: 02
subsystem: ui
tags: [swiftui, appkit, geometry, click-through, notch]

requires:
  - phase: 44-tray-quick-action-width-alignment
    provides: Plan 44-01's width-only geometry alignment (traySize.width at all 3 sites) that this on-device check verified and then iterated on
provides:
  - Quick Action picker at a content-hugging height (117pt) instead of Tray's full footprint, with matching width (650pt)
  - quickActionButtonWidth (130pt, fixed) replacing flex-fill buttons that were stretching past the card's curved edges
  - computeQuickActionButtonFrames hit-test re-anchored from the card's top (cameraClearance) instead of its bottom, fixing a hover/visual misalignment that only surfaced once the card grew taller than its old content-hugging height
  - trayContentHeight tied directly to quickActionPickerContentHeight (single source of truth) per explicit user request that both views share one height
  - trayEmptyState's top padding trimmed so its text fits inside the now-shorter Tray box
affects: [tray, quick-action-picker, drag-drop, click-through]

tech-stack:
  added: []
  patterns:
    - "Geometry N-site rule extended to button-level constants (quickActionButtonWidth, quickActionButtonRowHeight) shared between the SwiftUI view and the pure hit-test function, not just the 3 card-level sites"

key-files:
  created: []
  modified:
    - Islet/Notch/NotchPillView.swift
    - Islet/Notch/NotchWindowController.swift
    - Islet/Notch/DragDropSupport.swift
    - IsletTests/DragApproachGeometryTests.swift
    - .planning/phases/44-tray-quick-action-width-alignment/44-CONTEXT.md

key-decisions:
  - "D-09 (supersedes D-05): picker height no longer matches Tray's full footprint — reverted to a content-hugging 117pt after round 3 UAT found the extra margin looked wrong; width (D-04) still matches Tray."
  - "D-10: trayContentHeight tied directly to quickActionPickerContentHeight per explicit user request ('Die Höhe will ich genauso bei beiden') — accepted, documented risk that 117pt is tighter than the shelf row's prior tuned minimum."

patterns-established:
  - "Shared height/width constants for picker and hit-test math must live in ONE place (NotchPillView) and be referenced, never duplicated as local `let`s — the bottom-anchored vs. top-anchored hover bug in round 2 was caused by exactly this kind of drift."

requirements-completed: [TRAY-06, DRAG-02]

duration: ~55min
completed: 2026-07-19
---

# Phase 44: Tray & Quick Action Width Alignment Summary

**On-device UAT (6 rounds) found and fixed 5 real bugs beyond Plan 44-01's build-verified geometry: button overflow past the card's curved edges, a hover hit-test anchored to the wrong edge of the card, excess picker height, a Tray-height mismatch, and clipped empty-state text — ending with picker and Tray sharing one exact height/width footprint by explicit user design.**

## Performance

- **Duration:** ~55 min (6 checkpoint rounds)
- **Started:** 2026-07-19T13:14:00Z
- **Completed:** 2026-07-19T13:52:00Z
- **Tasks:** 1 (checkpoint:human-verify) + 5 rounds of gap-closure fixes driven by on-device feedback
- **Files modified:** 5

## Accomplishments
- Confirmed and fixed a real button-overflow bug: `quickActionButtonRow()` had zero horizontal padding, so `.frame(maxWidth: .infinity)` chips filled the picker card edge-to-edge and visibly poked past the curved corners.
- Found and fixed the actual root cause of a hover misalignment: `computeQuickActionButtonFrames`'s hit-test row was anchored from the card's bottom edge, which only coincidentally matched the top-anchored SwiftUI render at the old 117pt card height. The new 189pt height (from Plan 44-01) broke that coincidence, leaving a ~72pt gap. Re-anchored both from the same `cameraClearance` constant so they can't drift apart again.
- Capped button width at 130pt (matching the pre-Phase-44 flush-edge size) instead of flex-filling, per an explicit user request to make the buttons visually tighter.
- Reverted picker height from Tray's full 189pt footprint to a content-hugging 117pt (D-09, supersedes D-05) after user feedback that the extra margin looked wrong.
- Tied `trayContentHeight` directly to `quickActionPickerContentHeight` (D-10) per explicit user request that both views share the exact same height — an intentional, risk-flagged deviation from the phase's original locked decisions.
- Fixed Tray's empty-state text clipping against the now-shorter box by trimming its top padding.

## Task Commits

1. **Task 1: On-device verification checkpoint** — ran inline (no code), 6 rounds of user feedback → fix → re-verify:
   - `39ec98c` fix(44-02): apply 24pt wall-inset to Quick Action button row
   - `39cceb9` docs: capture todo - island briefly disappears during click-through (deferred, out of phase scope)
   - `b5f719c` fix(44-02): fix Quick Action button size and hover hit-test alignment
   - `43ce0e7` fix(44-02): revert picker height to content-hugging size (D-05 override)
   - `1910ddd` fix(44-02): tie trayContentHeight to quickActionPickerContentHeight (D-10)
   - `6f5c68e` fix(44-02): raise Tray empty-state text to fit shorter box (round 5)

_Note: this plan has no `auto` tasks — its single `checkpoint:human-verify` task was executed inline by the orchestrator, not a subagent, since there was no autonomous work to delegate ahead of the checkpoint._

## Files Created/Modified
- `Islet/Notch/NotchPillView.swift` — `quickActionButtonWidth`/`quickActionButtonRowHeight`/`quickActionPickerContentHeight` constants added; `quickActionButton()` capped at fixed width; `quickActionPickerView()`'s `blobShape` call and `trayContentHeight` updated to the new height; `trayEmptyState`'s top padding trimmed.
- `Islet/Notch/NotchWindowController.swift` — `quickActionPickerFrame` reservation and `.quickActionPicker` `contentSize` branch updated to the new content-hugging height.
- `Islet/Notch/DragDropSupport.swift` — `computeQuickActionButtonFrames` rewritten: fixed-width centered columns (was flex-fill) and top-anchored via `cameraClearance` (was bottom-anchored via a stale `bottomInset`).
- `IsletTests/DragApproachGeometryTests.swift` — 6 pre-existing tests (hardcoded against the now-dead 420×117 box) rebuilt against real production constants; 1 renamed for accuracy.
- `.planning/phases/44-tray-quick-action-width-alignment/44-CONTEXT.md` — D-09 and D-10 recorded as explicit supersessions of D-05, with the accepted risk documented for D-10.

## Decisions Made
- **D-09 (supersedes D-05):** Picker height decoupled from Tray's full footprint — content-hugging 117pt instead of 189pt. Width (D-04, `traySize.width`) is unaffected.
- **D-10 (extends D-09):** `trayContentHeight` tied to `quickActionPickerContentHeight` per explicit user request that both views share one height, with a clearly documented, user-accepted risk (117pt is tighter than the shelf row's prior tuned minimum of ~145pt).

## Deviations from Plan

This plan's single task was a `checkpoint:human-verify`. Real bugs were found on-device that Plan 44-01's build-only verification could not catch (SwiftUI layout and AppKit hit-test coordinate mismatches are invisible to `xcodebuild`). Each was root-caused and fixed inline per this project's "fix directly" GSD workflow override, rather than deferred to a separate gap-closure planning round — explicitly requested by the user mid-checkpoint.

**Total deviations:** 5 rounds of on-device-driven fixes (not plan deviations in the traditional sense — this plan's entire purpose was to surface exactly this class of issue).
**Impact on plan:** All 5 fixes are squarely within DRAG-02/TRAY-06 scope (picker/Tray geometry) except round 4/D-10's `trayContentHeight` change, which reaches into the shared Tray feature beyond the picker alone — flagged explicitly to the user with the regression risk before applying, and accepted.

## Issues Encountered
- **Deferred, not fixed:** "Island briefly disappears" during the click-through hover→expand→move-down trace (D-08a). User confirmed this is out of Phase 44's scope; captured as a todo (`.planning/todos/pending/2026-07-19-island-briefly-disappears-during-click-through.md`) for a dedicated `/gsd-debug` session, since project memory `cr01-clickthrough-or-defeat-gotcha` warns this class of bug needs an explicit isolated trace, not a guess made inline here.
- **Unverified residual risk:** D-10's `trayContentHeight` = 117pt is below the ~145pt this constant was tuned up to across several earlier gap-closure rounds specifically to prevent file icon/text clipping in the POPULATED (non-empty) shelf state. The empty-state clipping (round 5) was found and fixed; the populated-shelf case was approved by the user in round 6 but with fewer files staged than a stress-test worth — worth a follow-up glance with a large file count if issues surface later.

## User Setup Required
None — no external service configuration required.

## Next Phase Readiness
- Phase 44 (TRAY-06, DRAG-02) is functionally and visually verified on-device across 6 UAT rounds.
- No blockers for the next phase in the v1.7 milestone.

---
*Phase: 44-tray-quick-action-width-alignment*
*Completed: 2026-07-19*
