# Phase 52: Top-Edge Switcher Layout & Placement Config - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-21
**Phase:** 52-top-edge-switcher-layout-placement-config
**Areas discussed:** Placement reassignment UI, Top-edge icon visual style, Mode switch behavior, No-notch fallback

---

## Placement reassignment UI

| Option | Description | Selected |
|--------|-------------|----------|
| Fixed-pair swap | Home+Tray / Calendar+Weather stay as pairs; user only picks which pair goes left vs right | (initial pick, superseded) |
| Fully independent per-slot | Any of the 4 icons can go in any of the 4 slots individually | ✓ (confirmed via clarification) |

**User's choice:** Fully independent per-icon assignment.
**Notes:** The user initially picked "Fixed-pair swap" for granularity but then picked "Per-slot dropdown pickers" for the control UI — a contradiction (fixed-pair implies 2 arrangements, dropdowns imply 4 independent choices). A clarifying question resolved it: the user wants 4 dropdowns, one per icon, each assignable to any slot — i.e. fully independent, not fixed-pair. CONTEXT.md's D-01 records this as the final answer and notes the fixed-pair answer was superseded.

| Option | Description | Selected |
|--------|-------------|----------|
| Simple swap toggle | One control that swaps which pair is on which side | |
| Per-slot dropdown pickers | 4 dropdown menus, each picks from the 4 icons | ✓ |
| Drag-to-reorder list | A reorderable list where position maps to slot | |

**User's choice:** Per-slot dropdown pickers (4 dropdowns).

| Option | Description | Selected |
|--------|-------------|----------|
| Top-edge only | Pill-below keeps its current fixed order always | |
| Applies to both layouts | Reassigning also reorders the pill's icon order | ✓ |

**User's choice:** Applies to both layouts — reassignment reorders the pill too, not just the top-edge layout.
**Notes:** Flagged in CONTEXT.md as touching the already-shipped, Phase-45-morph-fixed `switcherRow` — a scope note for research/planning, not a re-litigation.

| Option | Description | Selected |
|--------|-------------|----------|
| Claude decides | Inner/outer order within a side is an implementation detail | ✓ |
| User-configurable too | User wants control over inner/outer order too | |

**User's choice:** Claude decides — moot in practice once D-01 became fully independent 4-slot assignment (inner/outer position is just one of the 4 explicit slots).

---

## Top-edge icon visual style

| Option | Description | Selected |
|--------|-------------|----------|
| Same navCircleButton style | Reuses the existing circular filled/unfilled button exactly | ✓ |
| Smaller/flatter icons | A new, more compact icon treatment sized for the top-edge strip | |

**User's choice:** Same `navCircleButton` style — reuse verbatim, verify on-device it physically fits.

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, same filled indicator | Active tab shows filled, matching navCircleButton's existing `filled:` param | ✓ |
| No visual selection indicator | Icons look the same regardless of active tab | |

**User's choice:** Yes, same filled/highlighted indicator as the pill today.

---

## Mode switch behavior

| Option | Description | Selected |
|--------|-------------|----------|
| Pill row fully removed | showSwitcher-driven pill row disappears entirely; island shrinks by that height | ✓ |
| Content grows to fill the gap | Content area expands to reclaim the freed vertical space | |

**User's choice:** Pill row fully removed — island shrinks, content area unchanged.

| Option | Description | Selected |
|--------|-------------|----------|
| New "Switcher" section | A dedicated new SidebarSection holds the toggle + 4 dropdowns | ✓ |
| Fold into an existing section | Add into an existing section (e.g. Appearance) | |

**User's choice:** New dedicated "Switcher" section in Settings, following Phase 51's per-feature-section pattern.

---

## No-notch fallback

| Option | Description | Selected |
|--------|-------------|----------|
| Hide the option entirely | Top-edge layout only makes sense flanking a real cutout — hide when hasNotch is false | ✓ |
| Show it, render centered without a gap | Keep the option everywhere; render as one centered row on non-notch displays | |

**User's choice:** Hide the option entirely on non-notch displays, reusing the app's existing `hasNotch` signal.

---

## Claude's Discretion

- SF Symbol / icon for the new "Switcher" Settings section.
- Whether `hasNotch` gating hides just the toggle/dropdowns or the entire Switcher section (observable requirement only: unreachable on non-notch displays).
- Internal data model for "which icon is in which of the 4 slots" (ordered array vs. 4 discrete `@AppStorage` values).
- Whether the pill's reordering requires restructuring `switcherRow` into an iteration-driven layout, or can stay a hardcoded switch keyed on slot assignment — must not regress Phase 45's continuous-view-identity morph fix.

## Deferred Ideas

None — discussion stayed within phase scope. No pending todos matched this phase's domain.
