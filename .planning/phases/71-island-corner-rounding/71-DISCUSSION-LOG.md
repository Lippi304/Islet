# Phase 71: Island Corner Rounding - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-30
**Phase:** 71-Island Corner Rounding
**Areas discussed:** Target roundness, Tuner axis structure, Nudge granularity

---

## Target Roundness

| Option | Description | Selected |
|--------|-------------|----------|
| Full pill (~16/~16) | Push both top and bottom radius toward 16pt — half the 32pt wing height, the mathematically "full pill" look. Uniform, most rounded, biggest change from today's 12/6. | |
| Rounder but still asymmetric | Scale both up while keeping some top/bottom difference (e.g. top ~14, bottom ~12) — noticeably rounder than today without going fully uniform. | ✓ |
| No fixed target — tune live on hardware | Start from a modest bump (e.g. +4/+4 over today's 12/6) and let the new DEBUG tuner find the final numbers on real hardware. | |

**User's choice:** Rounder but still asymmetric
**Notes:** Exact starting numbers left to planner/executor proposal, refined live via the new DEBUG tuner (SHAPE-03) — keep top > bottom asymmetry mirroring today's 12/6 shape direction, both noticeably larger than today.

---

## Tuner Axis Structure

| Option | Description | Selected |
|--------|-------------|----------|
| One combined nudge | A single "Corner Radius" axis that moves both top and bottom together by the same delta. Simplest, matches the seed's "a new nudge axis" (singular) wording. | ✓ |
| Two separate nudges | Independent "Top Radius" / "Bottom Radius" axes, like the existing Leading/Trailing pair — full flexibility to fine-tune the asymmetry itself on hardware. | |

**User's choice:** One combined nudge
**Notes:** Preserves whatever fixed top/bottom asymmetry ratio the planner bakes in while scaling.

---

## Nudge Granularity

| Option | Description | Selected |
|--------|-------------|----------|
| ±1 only | One fine-grained step size, mirroring Leading/Trailing's simple ±2. | |
| ±1 and ±5 | A fine step plus a coarse jump, mirroring Margin's multi-tier buttons (±5/±10/±20) — more menu items, faster large adjustments. | ✓ |
| You decide | Claude picks based on what fits the existing Wing Tuner menu's visual convention during planning. | |

**User's choice:** ±1 and ±5
**Notes:** Given the corner radius's small usable range (~6-16pt total), stopped at two tiers rather than Margin's three (±5/±10/±20) — a ±10/±20 tier would overshoot immediately.

---

## Claude's Discretion

- Exact final `topCornerRadius`/`bottomCornerRadius` starting values.
- Exact menu item ordering/labels for the new tuner buttons.

## Deferred Ideas

None — discussion stayed within phase scope.
