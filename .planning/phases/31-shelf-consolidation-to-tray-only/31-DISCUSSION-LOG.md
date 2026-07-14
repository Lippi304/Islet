# Phase 31: Shelf Consolidation to Tray-Only - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-14
**Phase:** 31-shelf-consolidation-to-tray-only
**Areas discussed:** Phase scope (given prior quick-task shipment)

---

## Phase scope

Quick task `260714-3k6` was discovered during codebase scouting to have already shipped a `shelfStripVisible` gate (always `false`) that hides the shelf strip on Home/Calendar/Weather, plus a matching `visibleContentZone()` simplification — i.e. TRAY-01's requirement text was already true in the code before this discussion started.

| Option | Description | Selected |
|--------|-------------|----------|
| Verify & close only | Re-run the mandatory on-device click-through trace, add a regression test, formally mark TRAY-01 delivered. No new feature work. | ✓ |
| Verify & bundle small polish | Same, plus fold in an additional small related cleanup. | |
| Something's missing | User believes the quick task didn't fully cover TRAY-01. | |

**User's choice:** Verify & close only
**Notes:** None — user confirmed directly without additional clarification.

---

## Done check

| Option | Description | Selected |
|--------|-------------|----------|
| Ready for context | Nothing else to discuss. | ✓ |
| One more thing | Something else to raise first. | |

**User's choice:** Ready for context

---

## Claude's Discretion

- Exact shape/location of the regression test locking `shelfStripVisible == false`.
- Whether to touch `shelfStripVisible`'s implementation (hardcoded computed property vs. inline vs. removal) — deferred to researcher/planner judgment, only if verification surfaces an actual bug.

## Deferred Ideas

- Drop feedback on non-Tray tabs (haptic/toast/auto-switch-to-Tray when a file lands in the shelf while viewing Home/Calendar/Weather) — this is explicitly Phase 34's scope (TRAY-02/03/04, Quick Action destination picker), not re-litigated here.
