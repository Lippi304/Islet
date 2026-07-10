# Phase 22: Drag-In - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-10
**Phase:** 22-Drag-In
**Areas discussed:** Expand-Timing, Drop-Zone, Hot-Feedback, Drop-Scope

---

## Expand-Timing

| Option | Description | Selected |
|--------|-------------|----------|
| Sofort beim Drag-Enter | Insel expandiert, sobald die Maus mit der gezogenen Datei die Pille berührt — Nutzer sieht den offenen Shelf und lässt dann darüber los. Fühlt sich wie macOS-Dock-Spring-Loading an. | ✓ |
| Erst nach dem Drop | Datei wird auf die kleine kollabierte Pille fallengelassen; erst danach expandiert die Insel und zeigt das neue Item. | |

**User's choice:** Sofort beim Drag-Enter (recommended)
**Notes:** Locked as D-01.

---

## Drop-Zone

| Option | Description | Selected |
|--------|-------------|----------|
| Gleiche Zone wie Hover | Nutzt die bestehende pointerInZone-Hot-Zone der Notch — konsistent mit Klick/Hover-Verhalten, kein neuer Zonentyp. | ✓ |
| Großzügiger gepolstert | Größere, vergrößerte Zone speziell fürs Draggen, da die Pille sehr klein ist. | |

**User's choice:** Gleiche Zone wie Hover (recommended)
**Notes:** Locked as D-02.

---

## Hot-Feedback

| Option | Description | Selected |
|--------|-------------|----------|
| Leichtes Scale-up / Bounce | Pille vergrößert sich leicht mit Spring-Animation — nutzt die schon vorhandene Hover-Bounce-Mechanik (D-01/Phase 2) wieder. | ✓ |
| Rand-Glow/Highlight | Ein heller Rand oder Glow um die Pille erscheint. | |
| Farb-/Akzentwechsel | Die Pille nimmt kurz die Akzentfarbe an. | |

**User's choice:** Leichtes Scale-up / Bounce (recommended)
**Notes:** Locked as D-03.

---

## Drop-Scope

| Option | Description | Selected |
|--------|-------------|----------|
| Nur kollabiert, wie im Roadmap-Text | Genau das, was SHELF-01/Erfolgskriterien beschreiben — Drop auf bereits erweiterte Ansichten ist außerhalb dieser Phase. | ✓ |
| Auch im erweiterten Zustand | Drop funktioniert überall auf der Insel, egal ob kollabiert oder schon offen. | |

**User's choice:** Nur kollabiert, wie im Roadmap-Text (recommended)
**Notes:** Locked as D-04. Explicitly excludes drop-while-expanded from this phase's scope.

---

## Claude's Discretion

- Exact `NSDraggingDestination` registration point (view vs. panel, `registerForDraggedTypes`)
- Drag-enter/exit detection mechanism (`draggingEntered`/`draggingExited` vs. SwiftUI `.onDrop`/`isTargeted`)
- Non-file drag content handling (reject/no-op)
- Drag-in attempted during Charging/Device splash suppression (defaults to existing silent-no-op precedent)
- Multi-file/folder drop ordering into shelf (follows Phase 19 D-06 append order)

## Deferred Ideas

None — discussion stayed within phase scope. Drop-while-expanded was considered and explicitly locked out of scope (D-04), not deferred as a future idea.

---

## Revision — 2026-07-10 (Hot-Zone/Mission-Control Fallback)

**Trigger:** 22-01 on-device spike confirmed A1 (drag delivery survives click-through) but found a NEW blocker: the drop never completes because the drag path crosses macOS's top-edge Mission Control trigger before reaching the tiny D-02 hot-zone. Routed back here per `22-01-SUMMARY.md` / `22-RESEARCH.md` Open Question 4.

**Areas discussed:** Drag-accept zone size, Auto-expand trigger, Click zone unchanged?

### Drag-accept zone size

| Option | Description | Selected |
|--------|-------------|----------|
| Reuse existing footprint | The already-reserved `expandedZone`-equivalent (expanded+wings union) becomes the drag-accept region — no new geometry to build. | ✓ |
| New dedicated drag-only zone | A separate zone sized/tuned specifically for dragging. | |
| You decide | Claude's discretion. | |

**User's choice:** Reuse existing footprint (recommended)
**Notes:** Locked as D-02b.

| Option | Description | Selected |
|--------|-------------|----------|
| Require landing below the edge | Drop-accept requires the release point to sit some margin below the literal top screen edge, avoiding the Mission-Control dwell trigger. | ✓ |
| Flush to the top edge is fine | Same positioning as today's pill. | |
| You decide | Claude's discretion. | |

**User's choice:** Require landing below the edge (recommended)
**Notes:** Locked as D-02c. Exact margin value is Claude's Discretion.

### Auto-expand trigger

| Option | Description | Selected |
|--------|-------------|----------|
| Trigger on wider footprint entry | Auto-expand fires as soon as `draggingEntered` reports entry into the wider reserved footprint. | ✓ |
| Keep the tighter/original trigger | Auto-expand still waits for a closer approach to the notch itself. | |
| You decide | Claude's discretion. | |

**User's choice:** Trigger on wider footprint entry (recommended)
**Notes:** Locked as D-05.

| Option | Description | Selected |
|--------|-------------|----------|
| Fire with the wider trigger | D-03's drag-hot bounce feedback fires at the same moment as the wider auto-expand trigger — one signal drives both. | ✓ |
| Keep feedback on tighter geometry | Bounce stays tied to the old, tighter hover geometry. | |
| You decide | Claude's discretion. | |

**User's choice:** Fire with the wider trigger (recommended)
**Notes:** Locked as D-06.

### Click zone unchanged?

| Option | Description | Selected |
|--------|-------------|----------|
| Yes — drag-only widening | Normal (non-drag) hover/click hot-zone stays exactly as small as today; widening applies only during an active drag session. | ✓ |
| Widen for both | Also loosen the normal hover/click zone to the same wider footprint. | |
| You decide | Claude's discretion. | |

**User's choice:** Yes — drag-only widening (recommended)
**Notes:** Locked as D-07.

### Claude's Discretion (added this revision)

- Exact margin value for D-02c's landing-below-the-edge requirement
- How "an active drag session" is detected to gate the widened zone (draggingEntered/draggingExited vs. a global drag-session monitor) — must route through the existing `syncClickThrough()` single arbiter, not a parallel flag (CR-01 regression class)

### Deferred Ideas (this revision)

None.
