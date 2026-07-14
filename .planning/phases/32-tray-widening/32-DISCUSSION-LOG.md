# Phase 32: Tray Widening - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-14
**Phase:** 32-tray-widening
**Areas discussed:** Todo fold, Growth scope (Wachstum), Layout, Target size (Zielgröße), Height/shrink-to-fit (Höhe)

---

## Todo fold

| Option | Description | Selected |
|--------|-------------|----------|
| Ja, in Phase 32 einbauen | Vertical shrink-to-fit becomes part of Phase 32 alongside width/tile size | ✓ |
| Nein, separater Quick-Task danach | Phase 32 stays strictly width/tile-size, height handled after as its own task | |

**User's choice:** Ja, in Phase 32 einbauen
**Notes:** Matched the screenshot the user showed at session start (files peeking over the island's top edge, large gap below the file row).

---

## Growth scope (Wachstum)

| Option | Description | Selected |
|--------|-------------|----------|
| Ja, nur Tray wird breiter | Uses `blobShape`'s existing `width:` override; Home/Calendar/Weather stay at 420pt | ✓ |
| Ganze Insel wird breiter | `expandedSize.width` grows globally for all tabs | |

**User's choice:** Ja, nur Tray wird breiter (empfohlen)

| Option | Description | Selected |
|--------|-------------|----------|
| Immer breit auf Tray-Tab | Width override tied to the Tray tab being active, not to item count | ✓ |
| Nur breit wenn Dateien vorhanden | Width only grows once the first file is dropped (extra morph moment) | |

**User's choice:** Immer breit auf Tray-Tab (empfohlen)

---

## Layout

| Option | Description | Selected |
|--------|-------------|----------|
| Einzeilig, weiter scrollbar | `shelfRow(_:)`'s existing ScrollView(.horizontal)+HStack structure unchanged | ✓ |
| Mehrzeiliges Grid | Replace with LazyVGrid-style multi-row layout | |

**User's choice:** Einzeilig, weiter scrollbar (empfohlen)

---

## Target size (Zielgröße)

| Option | Description | Selected |
|--------|-------------|----------|
| Claude schlägt vor | ~30-40% wider (560-600pt) + icons 28→36pt | |
| Ich gebe eine Zahl vor | User specifies exact width/ratio | ✓ (free text) |

**User's choice (free text):** "mach mal so doppelt so breit erstmal. Höhe müssen wir dort aber auch noch besprechen falls das hier nicht mit drin ist" → target width ≈ 840pt (double 420pt); flagged wanting height covered too (already folded above).

| Option | Description | Selected |
|--------|-------------|----------|
| Proportional verdoppeln (56×56pt) | Icons scale at the same ratio as panel width | |
| Moderat größer (z.B. 40×40pt) | Icons grow less than the panel width | ✓ |

**User's choice:** Moderat größer (~40×40pt)

---

## Height/shrink-to-fit (Höhe)

| Option | Description | Selected |
|--------|-------------|----------|
| Icons dürfen leicht wandern | Tray's switcher-row Y position shifts vs. other tabs since panel shrinks to content | ✓ |
| Icons müssen exakt fix bleiben | Requires decoupling switcher-row position from content height (bigger structural change) | |

**User's choice:** Icons dürfen leicht wandern (empfohlen)
**Notes:** Background given — Phase 28-04 round 5 deliberately made all tabs share `switcherContentHeight` (196pt) to prevent a misclick regression from switcher-row Y position shifting between tabs. User explicitly accepted a controlled reintroduction of that variance for Tray only, rather than requiring the larger overlay-based decoupling fix.

---

## Claude's Discretion

- Exact new Tray height constant(s) for empty vs. non-empty state.
- Exact pixel values for width (~840pt target) and icon size (~40×40pt target).
- Exact filename caption width/font adjustments to match larger icons.
- Animation curve choice for the width-morph/height-shrink transitions.

## Deferred Ideas

None — discussion stayed within Phase 32's scope (width, icon size, layout shape, folded height todo).
