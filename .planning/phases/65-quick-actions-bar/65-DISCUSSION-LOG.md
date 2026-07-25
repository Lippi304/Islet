# Phase 65: Quick Actions Bar - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-26
**Phase:** 65-Quick Actions Bar
**Areas discussed:** Bar placement, Settings config UI, Tap feedback, Launch action shape, Switcher slot integration, Bar capacity

---

## Bar placement

| Option | Description | Selected |
|--------|-------------|----------|
| Always-visible strip | Persistent row shown whenever idle/collapsed-expanded, no tab switch needed | |
| New switcher tab | Dedicated tab alongside Home/Weather/Calendar/Tray | ✓ |
| Merged into Home tab | Actions appear as a row within the existing idle/Home view | |

**User's choice:** New switcher tab
**Notes:** Resolves the `IslandResolver.swift` reserved "relationship unclear, rank TBD" comment for Phase 65.

---

## Settings config UI

| Option | Description | Selected |
|--------|-------------|----------|
| Per-slot dropdowns | Same mechanism as Phase 52's switcher slots — N independent dropdowns, one per position | ✓ |
| Checklist + drag-reorder list | Toggle switches + free drag reorder — net-new UI component | |

**User's choice:** Per-slot dropdowns (recommended option)
**Notes:** No drag-reorder component exists anywhere in the codebase today; dropdown mechanism is already proven via Phase 52.

---

## Tap feedback

| Option | Description | Selected |
|--------|-------------|----------|
| Brief icon pulse/flash | Short scale/opacity animation confirms every tap | ✓ |
| State-dependent icon only | No universal feedback, only actions with visible state change their icon | |
| Claude decides per-action | Mixed rule, picked per action during UI-spec | |

**User's choice:** Brief icon pulse/flash
**Notes:** Uniform rule across all 8 actions, not per-action discretion.

---

## Launch action shape

| Option | Description | Selected |
|--------|-------------|----------|
| One configurable slot | Single fixed "launch" catalog entry, one app/URL | |
| Multiple independent slots | User can add several launch entries, each its own app/URL | ✓ |

**User's choice:** Multiple independent slots
**Notes:** Triggered a follow-up on total bar capacity (see below), since this could otherwise grow the bar past the roadmap's "~8" figure.

---

## Switcher slot integration (follow-up)

| Option | Description | Selected |
|--------|-------------|----------|
| 5th assignable option | Quick Actions joins the existing 4-dropdown catalog, no layout changes | ✓ |
| New dedicated 5th switcher slot | Switcher row grows from 4 to 5 fixed positions | |

**User's choice:** 5th assignable option (recommended)
**Notes:** Keeps Phase 52's 4-slot layout math (`switcherRowHeight`, spacing) untouched.

---

## Bar capacity (follow-up)

| Option | Description | Selected |
|--------|-------------|----------|
| Fixed at ~8 total slots | Roadmap's "~8-action row" stays literal; multiple launch slots share the pool | ✓ |
| Uncapped / scrollable | Every enabled action gets a slot regardless of count | |

**User's choice:** Fixed at ~8 total slots
**Notes:** Multiple launch slots (previous decision) draw from this same fixed pool rather than expanding it.

---

## Claude's Discretion

- Exact SF Symbols/icons for each catalog action.
- Exact pulse/flash animation timing and visual style.
- DND/Focus action's exact failure-state visual treatment (QACTION-03 requires visibility, mechanism undiscussed).
- Naming of the new `IslandPresentation`/switcher-slot case for Quick Actions.
- Technical mechanism for each non-mute action (display sleep, dark mode, screen lock, DND, caffeinate, empty Trash, launch app/URL).

## Deferred Ideas

None — discussion stayed within phase scope. One stale todo ("Quick Action disabled state has no controller gate") was reviewed and found to be a keyword-collision false match (it concerns Phase 34's unrelated drag-drop picker) — not folded into this phase.
