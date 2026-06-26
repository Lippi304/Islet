# Phase 2: Hover, Expand & Fullscreen Hardening - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-27
**Phase:** 02-hover-expand-fullscreen-hardening
**Areas discussed:** Expand trigger & intent, Expanded empty state, Morph feel, Fullscreen yield

---

## Gray-area selection

User selected all four offered areas: Expand trigger & intent, Expanded empty state, Morph feel, Fullscreen yield.

---

## Expand trigger & intent

| Option | Description | Selected |
|--------|-------------|----------|
| Hover only | Expands while pointer over it, collapses on leave (iPhone-DI-like) | |
| Hover to peek + click to open/pin | Hover peeks, click fully opens | |
| Click only | Hover does nothing, click toggles | partial |

**User's choice (free text):** Alcove model — moving onto the island gives **trackpad haptic feedback + a slight bounce** as a "you're in" signal, but it **does NOT open on hover**; it **opens on click**. → captured as D-01 (hover haptic+bounce affordance) + D-02 (click-to-open).
**Notes:** Intentionally diverges from the literal ISL-03 "hover expands" wording.

### Expand eagerness
**User's choice:** "fällt ja weg durch klick" — moot, since expand is click-driven, not hover-timed.

---

## Expanded empty state

| Option | Description | Selected |
|--------|-------------|----------|
| Empty larger rounded panel | Pure morph placeholder | |
| Minimal subtle label | App name so it isn't empty | |
| Small date/time readout | Temporary filler | ✓ |

**User's choice:** Small date/time readout as temporary Phase-2 filler. → D-05.

### Expanded size
| Option | Description | Selected |
|--------|-------------|----------|
| Medium DI-style panel (~2–3× notch) | Clearly a panel | |
| Compact (modestly larger than notch) | | ✓ |
| You decide a default | | |

**User's choice:** Compact — only modestly larger than the notch. → D-06.

---

## Morph feel

| Option | Description | Selected |
|--------|-------------|----------|
| Snappy & playful with slight bounce | iPhone-DI / Alcove | ✓ |
| Sanft & weich (gentle settle) | No overshoot | |
| You decide an Alcove-near default | | |

**User's choice:** Snappy & playful with a slight bounce. → D-07 (matchedGeometry morph, no cross-fade per ISL-04).

### Collapse trigger
| Option | Description | Selected |
|--------|-------------|----------|
| Pointer leaves the island | Rollout closes it (Alcove-near) | ✓ |
| Re-click to close | Click opens, click closes | |
| Both (click-outside OR pointer leaves) | | |

**User's choice:** Pointer leaves the island. → D-03.

### Collapse grace delay
| Option | Description | Selected |
|--------|-------------|----------|
| Yes, ~0.3–0.5s grace | Brief rollout doesn't snap shut | ✓ |
| No, close immediately | | |

**User's choice:** Yes, short grace delay. → D-03.

---

## Fullscreen yield

| Option | Description | Selected |
|--------|-------------|----------|
| Fully hidden until fullscreen exits | No ghost bar (ISL-05) | ✓ (default) |
| Hidden but reveal-on-hover at notch | Like auto-hidden menu bar | |

**User's choice (free text):** Should be **configurable** whether the island shows in fullscreen, but **default OFF (fully hidden)** — i.e. like option 1 by default. → D-09 (default hidden) + D-10 (flag-gated; settings UI deferred to Phase 6 / APP-03).
**Notes:** Maximized/zoomed windows do NOT count — only true fullscreen.

---

## Claude's Discretion

- Hover hot-zone bounds; the focus-safe hover/click mechanism (global NSEvent monitor vs tracking
  area + conditional `ignoresMouseEvents`); exact spring values + bounce magnitude + grace value;
  fullscreen detection mechanism; haptic pattern type; where `isExpanded` state + date/time view live.

## Deferred Ideas

- "Show island in fullscreen" toggle → Phase 6 (APP-03), default off, flag-gated now.
- Activity content inside the expanded island → Phase 3+.
- ISL-03 ROADMAP/REQUIREMENTS wording still says "hover expands" — agreed model is click-to-open;
  user chose to proceed without editing those docs (offer to reconcile stands).
