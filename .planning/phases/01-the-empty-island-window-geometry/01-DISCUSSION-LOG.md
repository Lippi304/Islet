# Phase 1: The Empty Island (Window + Geometry) - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-26
**Phase:** 1-the-empty-island-window-geometry
**Areas discussed:** Idle appearance & notch fit, Multi-display & clamshell, Window technique, Phase-1 scope

---

## Idle Appearance & Notch Fit (ISL-01 / ISL-07)

| Option | Description | Selected |
|--------|-------------|----------|
| Exact-hug, invisible when idle | Same width + corner radius as the physical notch; merges with hardware notch; dev-tinted to verify | ✓ |
| Slim visible pill | A few px larger than the notch so a subtle black pill is always visible when idle | |

**User's choice:** Exact-hug — invisible when idle, temporarily tinted during development.
**Notes:** Matches Alcove reference and ISL-07.

---

## Multi-display & Clamshell (ISL-06)

| Option | Description | Selected |
|--------|-------------|----------|
| Built-in only; hide in clamshell | Island stays on built-in notch screen; lid closed → hide entirely | ✓ (with caveat) |
| Show on external in clamshell | Relocate to active external display at a simulated position (flagged out-of-scope) | |

**User's choice (free text):** "standard im eingebauten notch display sonst kann man aber auch
einstellen ob im vollbild oder auch auf externen monitoren etc." → Phase 1 ships the **default**
(built-in only, clamshell hides); the **configurability** (external monitors + fullscreen behavior)
is parked as a later idea.
**Notes:** Confirmed in follow-up — Phase 1 = standard behavior only; keep the display-selection
code future-open so a later "also external" option isn't blocked. External-pill out-of-scope v1,
fullscreen=Phase 2, settings toggle=Phase 6.

---

## Window Technique

| Option | Description | Selected |
|--------|-------------|----------|
| Custom NSPanel | Borderless, non-activating, status-bar level, all-Spaces; NSHostingView | ✓ |
| DynamicNotchKit | Library; oriented at transient toasts, not a persistent pill | |

**User's choice:** Custom NSPanel.
**Notes:** Per CLAUDE.md — full control, no third-party dependency for the persistent pill.

---

## Phase-1 Scope / Interactivity

| Option | Description | Selected |
|--------|-------------|----------|
| Static only, foundation window | Static pill; window built non-activating + click-through; hover/expand → Phase 2 | ✓ |
| Include simple hover/expand now | Pull Phase 2 behavior forward | |

**User's choice:** Static only; window non-activating + click-through as foundation.
**Notes:** Hover/expand/animation correctly deferred to Phase 2.

---

## Claude's Discretion

- Notch-geometry API + corner-radius approximation method.
- NSPanel style mask, window level, collectionBehavior flags.
- Dev-time tint toggle mechanism.
- Location/ownership of the overlay window controller in code.
- Screen-reconfiguration observer wiring + debounce.

## Deferred Ideas

- Configurable display behavior (show on external monitors; fullscreen visibility toggle) — later
  phases (external-pill out-of-scope v1, fullscreen Phase 2, settings Phase 6); keep Phase 1 code
  future-open.
- Hover, spring-morph expand/collapse, click-through gating, fullscreen-yield → Phase 2.
