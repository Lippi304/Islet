# Phase 60: Caps Lock HUD + Update-Activity Restyle - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-23
**Phase:** 60-Caps Lock HUD + Update-Activity Restyle
**Areas discussed:** Update HUD scope reality-check, Caps Lock HUD content, Update HUD version pill, priority ranking, collapsed-only visibility, pending-todo review

---

## Update HUD Scope (reality-check against ROADMAP.md wording)

| Option | Description | Selected |
|--------|-------------|----------|
| New island HUD replaces the dot | Build the transient, remove the menu-bar dot entirely | |
| New island HUD, keep the dot too | Build as a new transient, leave the dot as fallback | ✓ |
| You decide | Claude picks based on researcher findings on the click-through bug | |

**User's choice:** New island HUD, keep the dot too.
**Notes:** ROADMAP.md Phase 60 describes UPDATE-01 as "reskinning the existing update-available HUD," but the codebase shows Phase 40 deleted that HUD (`UpdateAvailableState.swift`) and redesigned it to a menu-bar red dot after an unfixable click-through/hot-zone bug (commit `30d9f82`). Surfaced this gap before asking the scope question. User chose to keep the dot as a fallback rather than re-risk the exact bug Phase 40 fled from.

---

## Caps Lock HUD Content

| Option | Description | Selected |
|--------|-------------|----------|
| Label + icon for both ON and OFF | Both states show icon + explicit text label | ✓ |
| Icon-only, color/fill changes | Same icon both times, distinguished by color/fill | |
| You decide | Claude picks based on Droppy reference and fixed-width constraints | |

**User's choice:** Label + icon for both ON and OFF (Recommended).
**Notes:** Unlike Charging's wings (label only in the positive state), SC1 requires a legible HUD for both the on-toggle and off-toggle transitions.

---

## Update HUD Version Pill

| Option | Description | Selected |
|--------|-------------|----------|
| Version number only | e.g. "v1.11" from `displayVersionString`, mirrors BatteryIndicator's role | ✓ |
| "Update" + version as separate static text | Simpler view hierarchy, less visually distinct | |
| You decide | Claude picks exact pill styling during planning | |

**User's choice:** Version number only (Recommended).

---

## Priority / Rank Placement

| Option | Description | Selected |
|--------|-------------|----------|
| Lowest priority, below OSD | Rank 5/6, below all existing transients | ✓ |
| Caps Lock ranks with OSD (both input-driven) | Caps Lock next to OSD, Update stays lowest | |
| You decide | Claude/researcher picks exact rank slotting | |

**User's choice:** Lowest priority, below OSD (Recommended).
**Notes:** Exact relative order between Caps Lock and Update (which is rank 5 vs. 6) left to Claude's discretion — low-stakes, unlikely to collide with each other.

---

## Collapsed-Only Visibility

| Option | Description | Selected |
|--------|-------------|----------|
| Collapsed-only for both | Matches Focus/OSD precedent and CAPS-01's literal wording | ✓ |
| Interrupt expanded view too, like Charging | More attention-grabbing, risks yanking user out of Calendar/Tray | |
| You decide | Claude follows whatever's most consistent with rank 5/6 placement | |

**User's choice:** Collapsed-only for both (Recommended).

---

## Pending-Todo Review

| Option | Description | Selected |
|--------|-------------|----------|
| Note click-through todo as a risk | Flag in CONTEXT.md, don't fix in Phase 60 | ✓ |
| Fold click-through fix into Phase 60 | Actually resolve the disappearing-island bug this phase | |
| Ignore all 3 — not relevant | No mention in CONTEXT.md | |

**User's choice:** Note click-through todo as a risk (Recommended).
**Notes:** 3 todos keyword-matched (score 0.9 each): "Island briefly disappears during click-through" (genuinely related — same `NotchWindowController` hot-zone code path the new Update HUD tap target depends on), "Calendar month-grid polish" and "Quick Action disabled state has no controller gate" (false-positive keyword matches, not relevant). Only the click-through one was folded into the Deferred/Reviewed section as a risk note.

---

## Claude's Discretion

- Exact SF Symbol choice and color treatment for the Caps Lock icon (on vs. off states).
- Relative rank order between Caps Lock (rank 5) and Update (rank 6) — or the reverse.
- Whether the Update HUD's tap-to-install reuses `wings(for:)`'s existing tap wiring or needs its own — left for planning/research.

## Deferred Ideas

None — discussion stayed within phase scope. "Island briefly disappears during click-through" is noted as a risk (see CONTEXT.md `<deferred>`), not deferred as a scope item, since it was reviewed and explicitly not folded in.
