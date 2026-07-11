# Phase 23: Shell Parity Rewrite - Context

**Gathered:** 2026-07-11
**Status:** Ready for planning

<domain>
## Phase Boundary

Rebuild the notch window shell (`NotchPanel.swift`, `NotchWindowController.swift` — 1,378 lines combined) with behavior identical to today: positioning on the built-in notch, the hover/click/grace-collapse interaction state machine, true-fullscreen hiding (CGS managed-display-spaces), click-through hit-testing, and multi-Space visibility. The residual Phase-22 `NSDraggingDestination` scaffold (`registerForDraggedTypes` + 4 stub methods in `NotchPanel.swift`) is removed entirely. This is the hard prerequisite for Phase 24 (Drag-In) only — `IslandResolver.swift`, `DeviceCoordinator.swift`, and `Islet/Shelf/` are explicitly locked to show zero diff (Success Criteria #5).

Out of scope for this phase: any new drag-detection mechanism (Phase 24's `DragApproachDetector`), any visual/material change (Phase 25), any onboarding/Settings/calendar work (Phases 26-28), and any behavioral change whatsoever — this is a parity rewrite, not a feature phase.

</domain>

<decisions>
## Implementation Decisions

All four gray areas discussed were left to Claude's discretion, with one exception (drag scaffold removal, locked below).

### Drag scaffold removal
- **D-01 (LOCKED):** Go fully clean — delete `registerForDraggedTypes` and all 4 `NSDraggingDestination` stub methods from `NotchPanel.swift` entirely, matching Success Criteria #4 literally. Do NOT leave a named extension seam/hook for Phase 24's `DragApproachDetector`. Phase 24 builds its detection mechanism from scratch against the reproven shell — no scaffolding to maintain or reconcile in the meantime.

### Claude's Discretion
- **Rewrite strategy** — in-place refactor (edit `NotchWindowController.swift`/`NotchPanel.swift` directly, commit incrementally, rely on git + on-device UAT as the safety net — matches how every prior phase in this project has worked) vs. parallel-build-then-swap (new files alongside old, verify on-device, then delete old in one final swap). Planner/researcher picks based on the actual diff shape once the rewrite plan is scoped. Given this project's established convention (every phase to date has refactored in place — Phase 15/16 included), in-place is the natural default unless research surfaces a specific reason the swap approach is safer for this particular rewrite.
- **Refactor scope boundary** — whether the still-inline license/trial-gating logic (`pendingLockoutHide`, D-11/D-12/D-13 in `updateVisibility()`/`handleClick()`) gets extracted into its own coordinator while the surrounding methods are being rewritten anyway (mirroring the Phase 16 `DeviceCoordinator` precedent), or moves verbatim into the new file untouched. Judge based on how cleanly it separates from the hover/click state machine during the actual rewrite — do not force an extraction that adds risk to a zero-regression phase, but take the opportunity if it falls out naturally.
- **Verification rigor** — one consolidated on-device UAT pass merging the existing scattered checklists (Phase 2's 8 fullscreen/hover scenarios from `02-HUMAN-UAT.md`, Phase 9's 3-trigger fullscreen checklist, the CR-01 hover→expand→move-down trace) vs. a lighter spot-check of headline behaviors only. Given this phase's explicit "zero behavioral regression" framing and that it touches the most safety-critical code in the app (focus-safety, click-through, fullscreen), lean toward the more thorough consolidated pass unless the actual diff turns out to be small and mechanical.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements source
- `.planning/REQUIREMENTS.md` §Architecture — ARCH-01 ("The notch window shell is rebuilt with behavior identical to today ... with the residual NSDraggingDestination scaffold from Phase 22 removed. Prerequisite for SHELF-01/02.")
- `.planning/ROADMAP.md` §"Phase 23: Shell Parity Rewrite" — Goal, Depends on (Phase 21 — Phase 22 superseded, not resumed), 5 Success Criteria

### Prior phase decisions this phase must preserve behavior of
- `.planning/phases/22-drag-in/22-CONTEXT.md` — full record of why Phase 22 was abandoned (`draggingEntered` never fired on-device twice, root cause unidentified) and the architecture-risk note: any new state must route through the single `syncClickThrough()` arbiter, never a parallel flag. This phase removes the scaffold that note was about.
- `.planning/phases/21-drag-out/21-CONTEXT.md` — the CR-01 gotcha (project memory `cr01-clickthrough-or-defeat-gotcha`): `syncClickThrough()`'s expanded branch must stay a pure `visibleContentZone()` check, never OR'd with the broader `pointerInZone` — this exact regression class must not be reintroduced by the rewrite.
- `.planning/STATE.md` "Blockers/Concerns" — the full Phase 22 abandonment record and the explicit warning that re-attempting drag-in before the shell is reproven repeats Phase 22's failure mode.
- Project memory `cr01-clickthrough-or-defeat-gotcha` — grep/build gates miss this regression class; needs an explicit hover→expand→move-down on-device trace to catch.

No other external specs — requirements fully captured in decisions above.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets (behavior to preserve verbatim)
- `Islet/Notch/NotchPanel.swift` (62 lines) — the borderless, non-activating `NSPanel`. Style mask (`.borderless`, `.nonactivatingPanel`), `canBecomeKey`/`canBecomeMain` overridden false, `ignoresMouseEvents` starts true, `.statusBar` level, `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]` — all must carry over unchanged. Lines 33, 39-61 are the Phase-22 drag scaffold to delete (D-01).
- `Islet/Notch/NotchWindowController.swift` (1,378 lines) — the single AppKit glue class. Key methods/state to preserve exactly: `start()` (observer wiring), `updateVisibility()` (the SOLE show/hide site — Pattern 7), `positionAndShow(on:)` (frame computation, panel creation, `notchSpace.windows.insert`), `handlePointer(at:)` (global `.mouseMoved` hit-testing against `hotZone`/`expandedZone`), `handleHoverEnter()`/`handleHoverExit()` (haptic, spring, grace-delay collapse), `handleClick()` (the only path to `.expanded`), `syncClickThrough()` (the ONE place `ignoresMouseEvents` is decided — WR-02/CR-01), `visibleContentZone()` (CR-01's narrower hit-test rect).
- `Islet/Notch/NotchGeometry.swift` (83 lines) — pure frame-math seams (`notchFrame`, `expandedNotchFrame`, `wingsFrame`, `topPinnedFrame`) already extracted and tested; likely untouched by this rewrite (no behavior change needed here), but confirm no accidental coupling.
- `notchSpace = CGSSpace(level: 2147483647)` (Phase 9, FS-01 Candidate C) — the dedicated max-level CGS Space joined once at panel creation, additive alongside `.canJoinAllSpaces`. Must survive the rewrite exactly as-is; this was a hard-won root-cause fix (Phase 8 → Phase 9 escalation chain), not something to "improve" here.
- `licenseState`/`pendingLockoutHide` (Phase 10, D-11/D-12/D-13) — the idle-state guard that defers a license-driven hide when the pointer is mid-hover or the island is mid-expansion, applying it only at the next natural transition. Behavior must be preserved regardless of whether it's extracted into its own coordinator (Claude's Discretion above).

### Established Patterns
- **Single arbiter, no parallel state machine** (`syncClickThrough()`) — the single most important invariant to preserve. Any restructuring must keep exactly one code path deciding `ignoresMouseEvents`, checked from every phase/pointer mutation site.
- **Coordinator-extraction precedent** (Phase 16, `DeviceCoordinator`) — proof this codebase can cleanly pull bookkeeping out of `NotchWindowController` behind a narrow protocol (`ActivityCoordinator`) with `[weak self]`-capturing reach-back closures, wired in `start()`. The template to reuse IF the license-gating extraction (Claude's Discretion above) is taken.
- **One-shot `DispatchWorkItem`, never a recurring timer** — `graceWorkItem`, `dismissWorkItem`, `mediaDismissWorkItem`, `trialExpiryWorkItem` all follow the same cancel-then-reschedule idiom for idle-CPU-friendly deferred work. Preserve this idiom in whatever the rewritten file's equivalent fields look like.

### Integration Points
- `NotchWindowController` currently also owns Now-Playing/Charging/Bluetooth/Outfit/Shelf wiring (all `start()`-time constructed monitors/coordinators) — these are explicitly OUT of scope (Success Criteria #5 locks `DeviceCoordinator`/`IslandResolver`/`Islet/Shelf/` as zero-diff), but the rewritten shell file still needs to hold references to them and call into them at the same points (`renderPresentation()`, `presentTransientChange()`) since they're not being extracted this phase.

</code_context>

<specifics>
## Specific Ideas

No specific visual or behavioral references given for this phase — it is a pure parity rewrite with success criteria fully captured in ROADMAP.md. The user deferred all four discussed gray areas (rewrite strategy, refactor scope, verification rigor) to Claude's discretion except the drag-scaffold removal, which was locked to "fully clean, zero drag code."

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 23-Shell Parity Rewrite*
*Context gathered: 2026-07-11*
