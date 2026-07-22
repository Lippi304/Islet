---
phase: 42-dual-activity-display
plan: 04
subsystem: ui
tags: [swiftui, appkit, matchedGeometryEffect, click-through, now-playing, calendar-countdown]

# Dependency graph
requires:
  - phase: 42-02
    provides: on-device spike confirming today's hotZone "passes through" (doesn't cover wing-tier taps), forcing the widening branch
  - phase: 42-03
    provides: NotchPillView.secondaryBubble view + onSecondaryTap closure property + .offset(x: 220) bubble positioning
provides:
  - "currentPresentation()/renderPresentation() dual-field (presentation, secondary) wiring from one resolve()-derived call"
  - "D-11 staggered secondary reveal (~150ms) on fresh nil->non-nil transitions only"
  - "collapsedInteractiveZone() hot-zone widening so the secondary bubble is a real, reachable tap target"
  - "Secondary bubble hover-reveal play/pause control (supersedes original D-12/D-13 tap-to-expand design)"
  - "Vertically-centered bubble with a contrast rim, matching 42-UI-SPEC.md's midline-alignment contract"
affects: [dual-activity-display, now-playing, calendar-countdown-hud]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "DispatchWorkItem cancel-then-schedule discipline (mirrors scheduleActivityDismiss) reused for secondaryRevealWorkItem"
    - "collapsedInteractiveZone() extends visibleContentZone()'s per-case if/else-if branching convention for click-through geometry"

key-files:
  created: []
  modified:
    - Islet/Notch/NotchWindowController.swift
    - Islet/Notch/NotchPillView.swift

key-decisions:
  - "D-12 SUPERSEDED: tapping the secondary bubble now toggles play/pause directly via NowPlayingMonitor.togglePlayPause() instead of expanding to Now-Playing/Home — explicit live user decision during Task 3's on-device UAT"
  - "D-13 SUPERSEDED: hovering the bubble now darkens it and reveals a play/pause SF Symbol glyph reflecting current playback state — explicit live user decision during the same UAT round"
  - "42-02's spike outcome (\"passes through\") required the hot-zone widening branch; collapsedInteractiveZone() implements it bounded to the bubble's exact 220pt-offset position, not an open-ended region (closes T-42-07)"

patterns-established:
  - "collapsedInteractiveZone() as the presentation-aware click-through zone helper, extending visibleContentZone()'s branching convention to the collapsed tier"

requirements-completed: [DUAL-01]

# Metrics
duration: multi-session (Task 1-2 ~15min combined build/wire time; Task 3 on-device UAT across 3 feedback rounds)
completed: 2026-07-19
---

# Phase 42 Plan 04: Controller Wiring, Staggered Reveal, Bubble Interaction Summary

**Dual-field `renderPresentation()` wiring with D-11's staggered bubble reveal, a click-through hot-zone widening that makes the bubble a real tap target, and a live-redesigned hover-to-reveal play/pause control that supersedes the original tap-to-expand interaction (D-12/D-13) per explicit user direction during on-device UAT.**

## Performance

- **Tasks:** 3 (2 auto + 1 checkpoint:human-verify)
- **Files modified:** 2 (`NotchWindowController.swift`, `NotchPillView.swift`)
- **UAT rounds:** 3 (initial full-checklist pass + 2 live follow-up fixes/features, all on the same Task 3 checkpoint)

## Accomplishments

- `currentPresentation()` now returns `(presentation, secondary)` from one `resolve()`-derived call; `renderPresentation()` applies D-11's 3-way rule (immediate clear on nil, ~150ms staggered reveal on a fresh nil→non-nil transition via a new `secondaryRevealWorkItem`, immediate in-place update when already non-nil) — closing 42-RESEARCH.md's Pitfall 1 stale-bubble class of bug structurally.
- `handleSecondaryTap()` wired via `onSecondaryTap:` into `makeRootView`'s `NotchPillView(...)` call; 42-02's spike outcome ("passes through") required the hot-zone widening branch, so `collapsedInteractiveZone()` was added and used in place of the bare `hotZone` at `handlePointer(at:)`'s collapsed branch — the bubble is now a physically reachable tap target, not just logically wired.
- On-device UAT (Task 3) confirmed the full 8-step checklist works collectively, then drove two further rounds of live iteration: vertical centering + a contrast rim for the bubble (commit `d63d021`), and a hover-to-reveal play/pause control that changes the bubble's tap behavior from expand-to-Now-Playing to direct play/pause toggling (commit `af14514`) — both explicit user requests made live during the checkpoint, not silent scope drift.

## Task Commits

1. **Task 1: currentPresentation()/renderPresentation() tuple wiring + D-11 staggered reveal** - `3d87fe7` (feat)
2. **Task 2: Secondary bubble tap wiring + collapsed hot-zone widening** - `eab0ec2` (feat)
3. **Task 3: Phase 42 on-device UAT — hard merge gate** - approved across 3 rounds; follow-up commits `d63d021` (fix) and `af14514` (feat)

**Plan metadata:** (this commit)

## Files Created/Modified

- `Islet/Notch/NotchWindowController.swift` - `currentPresentation()` tuple return, `renderPresentation()`'s 3-way D-11 stagger rule, `secondaryRevealWorkItem`/`secondaryStaggerDelay`, `handleSecondaryTap()` (later repurposed to call `togglePlayPause()` instead of expanding), `collapsedInteractiveZone()` hot-zone widening
- `Islet/Notch/NotchPillView.swift` - bubble vertical-centering y-offset + contrast rim (`d63d021`), hover-darkening overlay + play/pause SF Symbol glyph + tap wiring to the repurposed handler (`af14514`)

## Decisions Made

- **D-12 superseded** (tapping the bubble expands to Now-Playing/Home) → tapping now toggles play/pause directly via the existing `NowPlayingMonitor.togglePlayPause()` call. This was an explicit, live product decision the user made during Task 3's on-device UAT (they asked for the feature; the executor asked a clarifying question — "Klick = Play/Pause direkt" — and the user confirmed), not a bug fix or silent drift.
- **D-13 superseded** (no hover-reveal anywhere on the bubble) → hovering now darkens the bubble and reveals a play/pause glyph matching current playback state. Same live UAT round, same explicit request.
- Both supersessions are recorded in `42-CONTEXT.md`'s D-12/D-13 entries with a superseded-by pointer to this summary, per this project's established decision-trail convention (original text preserved, not rewritten).
- The hot-zone widening branch (`collapsedInteractiveZone()`) was required, not optional, per 42-02's spike outcome ("passes through") — this was a locked input from a prior plan, not a new decision made here.

## Deviations from Plan

### In-scope Task-3-checkpoint follow-ups (not Rule 1-4 deviations — explicit live user decisions during the plan's own on-device UAT gate)

**1. Bubble vertical centering + contrast rim (commit `d63d021`)**
- **Found during:** Task 3, first UAT feedback round
- **Issue:** The bubble read as visually attached to the top edge rather than a clean floating circle, and didn't stand out enough against the pill.
- **Fix:** Added a y-offset centering the bubble on the countdown wing's 32pt vertical midline (matching 42-UI-SPEC.md's "centered on the primary pill's vertical midline" contract) and a light stroke rim (opacity 0.35) for contrast.
- **Files modified:** `Islet/Notch/NotchPillView.swift`
- **Verification:** User confirmed "Ja passt" (yes, fits) on-device.
- **Committed in:** `d63d021`

**2. Hover-to-reveal play/pause control (commit `af14514`)**
- **Found during:** Task 3, second UAT feedback round
- **Issue:** Not an issue — a new feature the user requested live during the same checkpoint: a way to control playback directly from the bubble without expanding the island.
- **Fix:** Hover now darkens the bubble and shows a play/pause SF Symbol matching current playback state; tap toggles play/pause directly via `NowPlayingMonitor.togglePlayPause()` instead of expanding — an explicit interaction decision confirmed by the user before implementation ("Klick = Play/Pause direkt").
- **Files modified:** `Islet/Notch/NotchPillView.swift`, `Islet/Notch/NotchWindowController.swift`
- **Verification:** User confirmed "Klappt!" (works!) on-device — final approval.
- **Committed in:** `af14514`

---

**Total deviations:** 0 Rule 1-4 auto-fixes. 2 explicit live user-directed feature/design changes during the plan's own checkpoint, both documented above and reflected as D-12/D-13 supersessions in `42-CONTEXT.md`.
**Impact on plan:** No scope creep in the Rule 1-4 sense — these were user-driven product decisions made during the exact on-device UAT round the plan scheduled for this purpose, following this project's established precedent (e.g. Phase 36's ONBOARD-04 pivot, Phase 38's live Focus-wing redesign) of treating first-real-visibility feedback as authoritative over a pre-UAT spec.

## Issues Encountered

None beyond the two UAT-driven design iterations above, which are the plan's own checkpoint doing its job (the whole reason this hard-merge gate exists).

## Task 3: On-Device UAT — 8-Step Checklist Outcome

Per the checkpoint resolution: the user confirmed the full 8-step checklist collectively ("alles klappt wie beschrieben" — everything works as described) rather than itemizing each step pass/fail individually. Recorded honestly here rather than backfilling a per-step table that was never actually produced:

1. Dual-activity collapsed display (primary pill + secondary bubble with real artwork, visible gap) — confirmed working; the only gap raised was visual (bubble needed to stand out more / read as floating, not attached) — resolved by `d63d021`.
2. Spring-in morph feel, no dropped frames / geometry collisions — confirmed working, no follow-up.
3. Tap-to-expand (D-12, the highest-risk step per 42-RESEARCH.md Pitfall 2) — confirmed the tap registers (hot-zone widening from Task 2 works); the tap's *behavior* was then changed by explicit user request in round 3 from expand-to-Now-Playing to direct play/pause toggle (`af14514`) — the tap-registration risk itself is closed, the interaction contract evolved.
4. Single-activity byte-identical fallback (D-04) — confirmed working.
5. Transient suppresses both slots together, no stale bubble (D-10, Pitfall 1) — confirmed working.
6. Staggered reveal (primary first, bubble ~150ms later, D-11) — confirmed working.
7. No hover-reveal (D-13) — reported as-built in round 1, then explicitly superseded by user request in round 3 (hover now reveals a play/pause glyph) — same commit `af14514`.
8. CR-01 hover→expand→move-down click-through regression trace (relevant since the widening branch was taken) — no phantom click-swallowing reported across any of the 3 UAT rounds.

All 8 steps pass as of the final approval ("Klappt!"). No gaps require further gap-closure follow-up.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- DUAL-01 is fully shipped and on-device UAT-approved. Phase 42 is the last phase of v1.6 (Liquid Glass & System HUD Suite) — v1.6 is now code-complete pending formal milestone close.
- `42-CONTEXT.md`'s D-12/D-13 entries carry superseded-by notes pointing to this summary; any future phase reading Phase 42's decision trail should treat "tap = play/pause direct" and "hover reveals a play/pause glyph" as the bubble's actual shipped behavior, not the original tap-to-expand/no-hover design.
- `handleSecondaryTap()` was repurposed in place (its only caller) rather than adding a second closure — future readers of `NotchWindowController.swift` should expect this name to mean "toggle playback," not "expand to Now-Playing."

---
*Phase: 42-dual-activity-display*
*Completed: 2026-07-19*

## Self-Check: PASSED

- FOUND: `.planning/phases/42-dual-activity-display/42-04-SUMMARY.md`
- FOUND: commit `3d87fe7`
- FOUND: commit `eab0ec2`
- FOUND: commit `d63d021`
- FOUND: commit `af14514`
