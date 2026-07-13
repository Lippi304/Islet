# Phase 29: NotchShape Flare - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-13
**Phase:** 29-notchshape-flare
**Areas discussed:** Flare look, Media wings coverage, Flare width

---

## Flare look

| Option | Description | Selected |
|--------|-------------|----------|
| Subtle widen | Top edge widens only a little before curving into the bezel — closer to today's existing 6pt quad-curve, just a touch more pronounced. | ✓ |
| Pronounced flare | A clearly visible trumpet/bell-shaped flare — wider, more dramatic. | |
| I have a reference | User has a specific image/app/mockup in mind. | |
| You decide | Claude designs a moderate default and tunes on-device. | |

**User's choice:** Subtle widen
**Notes:** No reference image or app was provided; exact pt values left to on-device tuning (project convention).

---

## Media wings coverage

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, include it | mediaWingsOrToast is the same "wings" shape family as Charging/Device — leaving it flush would look inconsistent. | |
| No, leave it flush | It's more of a passing glance than a deliberate "expanded" state — keep it flush like the collapsed pill. | ✓ |
| You decide | Claude picks based on what looks visually consistent once implemented. | |

**User's choice:** No, leave it flush
**Notes:** Confirmed structurally clean — `mediaWingsOrToast` already makes its own inline `NotchShape(...)` call rather than routing through the shared `wingsShape()` helper, so this requires no special-casing.

---

## Flare width

| Option | Description | Selected |
|--------|-------------|----------|
| Same absolute flare | Same fixed widen amount everywhere regardless of shape width. | ✓ |
| Scale with width | Flare scales proportionally to each shape's own width. | |
| You decide | Claude picks whichever reads better on-device once both are visible side by side. | |

**User's choice:** Same absolute flare
**Notes:** User chose consistency across all covered presentations over per-width proportional scaling.

---

## Claude's Discretion

- Exact pt value(s) for the flare widen amount — tuned on-device after initial implementation, matching this project's established pattern (wings sizing, bottom-corner radius, spring curves were all tuned this way).
- Exact geometry/technical mechanism for the new flare parameter in `NotchShape.swift` (new animatable property vs. extending the existing quad-curve technique).

## Deferred Ideas

None — discussion stayed fully within phase scope. User-configurable flare depth/amount was already explicitly out-of-scope per `REQUIREMENTS.md` before this discussion started.
