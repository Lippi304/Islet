# Phase 23: Shell Parity Rewrite - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-11
**Phase:** 23-Shell Parity Rewrite
**Areas discussed:** Rewrite strategy, Refactor scope, Verification rigor, Drag scaffold removal

---

## Rewrite Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| In-place refactor | Edit NotchWindowController.swift/NotchPanel.swift directly, commit incrementally, rely on git + on-device UAT as the safety net. Matches how every prior phase in this project has worked. | |
| Parallel build then swap | Build the new shell as new files alongside the old ones, verify on-device, then delete the old file in one final swap. Safer rollback but doubles the code temporarily. | |
| You decide | Claude picks based on what the planner/researcher find once they look at the exact diff shape needed. | ✓ |

**User's choice:** You decide.
**Notes:** Deferred to Claude's discretion — noted in CONTEXT.md that in-place is the natural default given project convention (Phases 15/16 both refactored in place) unless research surfaces a specific reason the swap approach is safer.

---

## Refactor Scope

| Option | Description | Selected |
|--------|-------------|----------|
| Extract it too | Pull license/trial-gating bookkeeping (pendingLockoutHide, D-11/D-12/D-13) into its own coordinator while rewriting the surrounding methods anyway — mirrors the Phase 16 DeviceCoordinator precedent. | |
| Leave it inline, untouched | Rewrite only the literal window/hover/click/fullscreen mechanics; license-gating code moves verbatim into the new file without restructuring. | |
| You decide | Claude/planner judges based on how cleanly the license logic separates from the hover/click state machine during the actual rewrite. | ✓ |

**User's choice:** You decide.
**Notes:** Deferred to Claude's discretion — CONTEXT.md notes not to force an extraction that adds risk to a zero-regression phase, but to take the opportunity if it falls out naturally.

---

## Verification Rigor

| Option | Description | Selected |
|--------|-------------|----------|
| One consolidated UAT pass | Merge the scattered existing checklists (Phase 2's 8 scenarios, Phase 9's 3-trigger fullscreen checklist, the CR-01 hover→expand→move-down trace) into one comprehensive on-device pass. | |
| Lighter spot-check | Verify the headline behaviors (hover/click/expand, fullscreen hide via one trigger, click-through) on-device, trusting the rewrite's mechanical fidelity for the rest. | |
| You decide | Claude/planner sizes the UAT checklist once the actual diff and risk areas are known. | ✓ |

**User's choice:** You decide.
**Notes:** Deferred to Claude's discretion — CONTEXT.md leans toward the more thorough consolidated pass given the "zero behavioral regression" framing and that this touches the most safety-critical code in the app, unless the actual diff turns out small and mechanical.

---

## Drag Scaffold Removal

| Option | Description | Selected |
|--------|-------------|----------|
| Fully clean, zero drag code | Delete registerForDraggedTypes + all 4 stub methods, literally matching success criteria #4. Phase 24 adds its own DragApproachDetector from scratch. | ✓ |
| Leave a named extension point | Remove the actual conformance/stubs, but leave one clearly-commented hook documenting where Phase 24's detector will plug in. | |
| You decide | Claude/planner follows whatever reads cleaner once the rewrite's actual shape is known. | |

**User's choice:** Fully clean, zero drag code.
**Notes:** Locked decision (D-01 in CONTEXT.md) — no speculative scaffolding left for Phase 24 to reconcile against.

---

## Claude's Discretion

- Rewrite strategy (in-place vs. parallel-build-then-swap)
- Whether license/trial-gating logic gets extracted into its own coordinator during this rewrite
- Verification checklist scope (consolidated pass vs. lighter spot-check)

## Deferred Ideas

None — discussion stayed within phase scope.
