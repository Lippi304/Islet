# Phase 70: File Tray Convert Button - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-29
**Phase:** 70-file-tray-convert-button
**Areas discussed:** Convert-Ablauf & Formatwahl, Ziel der konvertierten Datei, Verhalten bei gemischten Drops, Welche Formate zählen

---

## Convert-Ablauf & Formatwahl (Conversion flow & format selection)

| Option | Description | Selected |
|--------|-------------|----------|
| 2-Schritt: Formatauswahl | Releasing on Convert opens a 2nd step with format tiles (JPG/PNG/etc.), like Finder's own submenu | ✓ |
| Sofort festes Zielformat | Convert immediately converts to one fixed format (e.g. always PNG) | |
| Smart: automatisch das jeweils andere Format | JPG→PNG, PNG→JPG toggle, no menu | |

**User's choice:** 2-Schritt: Formatauswahl (Empfehlung)

**Follow-up — visual shape of the 2nd step:**

| Option | Description | Selected |
|--------|-------------|----------|
| Gleiche Kachel-Reihe, ersetzt die 4 Buttons | Format options appear in the same row/card, same button style | ✓ |
| Eigene kleine Liste darunter/dahinter | Separate panel/list, needs new geometry | |
| Du entscheidest | Claude picks pragmatic approach | |

**User's choice:** Gleiche Kachel-Reihe, ersetzt die 4 Buttons (Empfehlung)

---

## Ziel der konvertierten Datei (Destination for converted file)

| Option | Description | Selected |
|--------|-------------|----------|
| In die Tray/Shelf (wie 'Drop') | Reuses ShelfCoordinator.append, same mechanism as Drop | ✓ |
| Original ersetzen/danebenlegen | Saved next to original file, no Tray entry | |
| Speicherort-Dialog | System save dialog, extra focus-window risk | |

**User's choice:** In die Tray/Shelf (wie 'Drop')

---

## Verhalten bei gemischten Drops (Mixed-batch enablement)

| Option | Description | Selected |
|--------|-------------|----------|
| Ausgegraut sobald NICHT-Bild dabei ist | Matches existing D-09 dim-never-hide pattern | ✓ |
| Aktiv solange mind. 1 Bild dabei ist | Partial-batch conversion, ignores non-images | |
| Komplett ausgeblendet bei Nicht-Bild | Breaks existing D-09 convention, button row width shifts | |

**User's choice:** Ausgegraut sobald NICHT-Bild dabei ist (Empfehlung)

**Folded todo during this area:** `2026-07-19-quick-action-disabled-state-has-no-controller-gate.md` — existing enabled-dimming has no controller-side release-hit-test gate (currently dormant, both existing flags hardcoded true). User confirmed folding the fix into this phase (Convert would be the first real trigger for the bug).

---

## Welche Formate zählen (Which formats matter)

| Option | Description | Selected |
|--------|-------------|----------|
| JPG + PNG | Minimal scope, the two explicitly mentioned formats | |
| JPG, PNG, HEIC, TIFF | Full Finder "Convert Image" scope | ✓ |
| Du entscheidest | Claude researches Finder's exact scope | |

**User's choice:** JPG, PNG, HEIC, TIFF (Finder-Umfang)

---

## Claude's Discretion

- Exact SF Symbol for the Convert icon and each format tile
- Underlying image-conversion mechanism (CGImageDestination/ImageIO vs. NSBitmapImageRep vs. `sips`)
- Image-type detection method (extension vs. UTType)
- Back/cancel affordance from the format-tile step
- Naming of the new image-conversion seam/service

## Deferred Ideas

None — discussion stayed within phase scope. Partial-batch conversion (converting only the images in a mixed batch) was considered as an alternative during the "Verhalten bei gemischten Drops" discussion but not chosen — this is a rejected option, not a deferred idea for a future phase.
