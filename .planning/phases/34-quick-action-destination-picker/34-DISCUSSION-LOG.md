# Phase 34: Quick Action Destination Picker - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-15
**Phase:** 34-quick-action-destination-picker
**Areas discussed:** Picker UI & trigger, Interrupt precedence, No-choice / cancel behavior, AirDrop/Mail fallback plan

---

## Picker UI & trigger

| Option | Description | Selected |
|--------|-------------|----------|
| Full-takeover view | Own resolver case, replacing whatever tab was showing, like the Charging/Device wings splash | ✓ |
| Overlay on top of current tab | Floating panel/sheet on top of the current tab without changing `selectedView` | |

**User's choice:** Full-takeover view (Recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| Show a small preview | File icon + filename (or file count for multiple) alongside the 3 buttons | ✓ |
| Buttons only, no preview | Just the 3 destination buttons, no confirmation of what was dropped | |

**User's choice:** Show a small preview (Recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| One decision for the whole batch | A single picker decision applies to all dropped files at once | ✓ |
| One picker per file, in sequence | Each dropped file gets its own picker | |

**User's choice:** One decision for the whole batch (Recommended)

---

## Interrupt precedence

| Option | Description | Selected |
|--------|-------------|----------|
| Charging/Device interrupts | Matches the existing D-04 rule in `IslandResolver.resolve()` — transients already win over any expanded view | ✓ |
| Picker blocks Charging/Device | Inverts the existing precedent — picker would outrank transients, a first exception to the rule | |

**User's choice:** Charging/Device interrupts (Recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| Survives — picker auto-resumes | The pending drop is held; the picker reappears with the same file(s) once the transient clears | ✓ |
| Discarded on interrupt | The pending drop is cancelled entirely if a transient interrupts | |

**User's choice:** Survives — picker auto-resumes (Recommended)

---

## No-choice / cancel behavior

| Option | Description | Selected |
|--------|-------------|----------|
| Dismissible via pointer-away | Reuses the existing hover-away grace-collapse mechanism | ✓ |
| Must choose — no dismiss | The picker stays pinned open until a button is explicitly clicked | |

**User's choice:** Dismissible via pointer-away (Recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| Discarded — nothing staged | No destination chosen means nothing happens to the file(s) | ✓ |
| Auto-default to Drop | Dismissing silently stages the file into the Tray anyway | |

**User's choice:** Discarded — nothing staged (Recommended)

---

## AirDrop/Mail fallback plan

| Option | Description | Selected |
|--------|-------------|----------|
| Allow it, scoped narrowly | Momentary key-window acceptable only for the instant of invoking AirDrop/Mail, reverts immediately after | ✓ |
| Never break non-key, find another way | Keep the panel permanently non-key no matter what; use a different mechanism if needed | |

**User's choice:** Allow it, scoped narrowly (Recommended)
**Notes:** This is a narrow, user-initiated exception to ISL-03 ("never steals focus") — not a general focus-behavior change. Only applies to the instant the user clicks AirDrop or Mail.

| Option | Description | Selected |
|--------|-------------|----------|
| Ship Drop-only, disable the rest | Drop ships on schedule; AirDrop/Mail appear disabled if the spike can't make them work | ✓ |
| Pause the whole phase | Don't ship anything until all 3 destinations work as specified | |

**User's choice:** Ship Drop-only, disable the rest (Recommended)

---

## Claude's Discretion

- Exact visual treatment of the drop preview and the disabled-button state for AirDrop/Mail
- Exact SF Symbols for the Drop/AirDrop/Mail buttons
- Where the pending-drop state lives in code (new struct vs. fields on `NotchWindowController`)
- Naming of the new `IslandPresentation`/resolver case
- Whether "Drop" routes through `ShelfCoordinator.append` directly or via a new intermediate step
- Whether the switcher row shows during the picker (no direct precedent — Charging/Device wings don't show it; left to planning)

## Deferred Ideas

None new. Already-known (from REQUIREMENTS.md v2 candidates, not re-litigated): "Open Tray After Drop" convenience setting for the picker's Drop outcome.

A stale pending todo ("Tray panel oversized vertically, shrink to fit content") matched Phase 34 by keyword but was already resolved by Phase 32 — deleted as housekeeping during this discussion, not folded into Phase 34.

---

## UAT Revision Round (2026-07-15) — after on-device rejection of the click-based picker

**Trigger:** Plan 34-01/34-02 built and shipped the click-based picker above (build-green), but on-device UAT found (1) a bug — drag-hover shows Now Playing instead of a drop affordance — and (2) the user wanted a different interaction model entirely. See `34-02-SUMMARY.md` §"Outcome: CHANGES REQUESTED" for full findings and screenshots.

### Drag-Ziel Trigger & Feedback

| Option | Description | Selected |
|--------|-------------|----------|
| Sofort bei Grenzübertritt | Picker appears at the same `.dragEntered` edge that already auto-expands the island today | ✓ |
| Erst nach kurzem Verweilen | Island expands immediately, picker appears after ~0.3s hover | |

**User's choice:** Sofort bei Grenzübertritt (Recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| Ja, Hervorhebung | The button under the pointer highlights (brighter fill/scale) during the drag, before release | ✓ |
| Nein, keine Hervorhebung | All 3 buttons always look the same; only release decides | |

**User's choice:** Ja, Hervorhebung (Recommended)

### Loslassen außerhalb der Buttons

| Option | Description | Selected |
|--------|-------------|----------|
| Verwerfen wie D-07 | Releasing outside any of the 3 buttons discards the pending file(s), same as the existing no-choice-dismissal rule | ✓ |
| Picker bleibt offen | Nothing happens; the picker stays open and the pending drop persists until landed on a button | |

**User's choice:** Verwerfen wie D-07 (Recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| Ja, Picker verschwindet dann | Dragging the pointer back out of the island's geometry during the drag collapses the picker (existing exit condition, unchanged) | ✓ |
| Nein, Picker bleibt bis Loslassen sichtbar | Once opened, the picker stays open regardless of pointer position until release | |

**User's choice:** Ja, Picker verschwindet dann (Recommended)

### Layout ohne Vorschau

| Option | Description | Selected |
|--------|-------------|----------|
| Karte wird kürzer | The file preview is removed; the card's height shrinks to fit only the button row (new, smaller `quickActionPickerContentHeight`) | ✓ |
| Gleiche Höhe, Buttons zentriert | Card keeps 188pt; buttons center in the leftover vertical space | |

**User's choice:** Karte wird kürzer (Recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| Nur 3 Buttons, keine Zahl | No file-count indicator anywhere, even for multi-file drops — consistent across 1 vs. N files | ✓ |
| Kleine Zahl irgendwo einblenden | A small badge/count shows the number of pending files without the full preview | |

**User's choice:** Nur 3 Buttons, keine Zahl (Recommended)

### Visual polish (flagged directly, not discussed as options)
- "Drop" button height mismatch vs. "AirDrop"/"Mail" (SF Symbol intrinsic-size difference) — needs a layout fix.
- AirDrop icon (`personalhotspot`) may need a closer visual match — Claude's discretion.

**Next steps:** Route to `/gsd-plan-phase 34` for a gap-closure plan (34-03) covering D-10–D-15 + the two polish items, reusing the Plan 34-01/34-02 infrastructure verbatim.

---

*Phase: 34-quick-action-destination-picker*
*Discussion logged: 2026-07-15 (original) + 2026-07-15 (UAT revision)*
