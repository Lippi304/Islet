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
