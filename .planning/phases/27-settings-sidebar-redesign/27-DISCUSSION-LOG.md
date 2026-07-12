# Phase 27: Settings Sidebar Redesign - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-12
**Phase:** 27-Settings-Sidebar-Redesign
**Areas discussed:** Section-Mapping, Material-Style, Per-Element Accent, App-Icon-Varianten, Preset-Liste, Icon-Descope-Ziel, Workspace-Section

---

## Section-Mapping

| Option | Description | Selected |
|--------|-------------|----------|
| General = Activities + Login | General bekommt die 4 Activity-Toggles + Launch-at-Login + Fullscreen-Toggle + Diagnostics. About/License bekommt nur License+Version. Workspace(Shelf) bleibt vorerst leer/Platzhalter. | ✓ |
| Ich sag dir die genaue Zuordnung | User beschreibt selbst pro Section, was rein soll. | |

**User's choice:** General = Activities + Login
**Notes:** Locked as D-01/D-02 in CONTEXT.md.

---

## Material-Style

| Option | Description | Selected |
|--------|-------------|----------|
| Intensitäts-Regler | Slider, der den bestehenden Gradient anpasst — kein neues Material. | |
| Mehrere Material-Presets | Mehrere fertige Stile zur Auswahl (z.B. Gradient / Solid Black / Glossy). | ✓ |
| Nur Platzhalter für später | UI-Element existiert, aber keine echte Funktionalität. | |

**User's choice:** Mehrere Material-Presets
**Notes:** Follow-up narrowed this to exactly 2 presets (Gradient + Solid Black) — see Preset-Liste below.

---

## Per-Element Accent

| Option | Description | Selected |
|--------|-------------|----------|
| Ja, 3 unabhängige Picker | Now Playing, Charging, Device bekommen je einen eigenen Picker aus der gleichen 6er-Palette. | ✓ |
| Global bleibt, nur Label ändert sich | Ein Picker bleibt bestehen, "per-element" wird nicht wörtlich umgesetzt. | |

**User's choice:** Ja, 3 unabhängige Picker
**Notes:** Locked as D-07/D-08. Requires new @AppStorage keys + migration handling to avoid regressing existing users' accent choice.

---

## App-Icon-Varianten

| Option | Description | Selected |
|--------|-------------|----------|
| Ich liefere die Icon-Dateien | User stellt 2-3 fertige alternative App-Icon-Sets bereit. | |
| Einfache programmatische Varianten | Claude generiert simple Farbvarianten des bestehenden Icons als Platzhalter. | |
| Aus Phase 27 rausnehmen | App-Icon-Auswahl wird gestrichen/verschoben, bleibt offen für eine spätere Phase. | ✓ |

**User's choice:** Aus Phase 27 rausnehmen
**Notes:** No alternate icon assets exist anywhere in the repo. Follow-up question resolved where it goes (Icon-Descope-Ziel below).

---

## Preset-Liste

| Option | Description | Selected |
|--------|-------------|----------|
| Gradient + Solid Black (2 Presets) | Nur zwei Optionen: Phase-25-Gradient (Standard) + flacher Solid-Black-Fallback. | ✓ |
| Gradient + Solid Black + Glossy (3 Presets) | Wie oben plus ein drittes "glossy/frosted" Material. | |
| Ich beschreibe die Presets selbst | User legt fest wie viele und wie sie aussehen sollen. | |

**User's choice:** Gradient + Solid Black (2 Presets)
**Notes:** Locked as D-05.

---

## Icon-Descope-Ziel

| Option | Description | Selected |
|--------|-------------|----------|
| Backlog / spätere Phase | App-Icon-Auswahl wird als offener Punkt für eine zukünftige Phase vermerkt. | ✓ |
| Ganz streichen | App-Icon-Auswahl wird komplett aus dem Projekt-Scope entfernt. | |

**User's choice:** Backlog / spätere Phase
**Notes:** Requires a REQUIREMENTS.md/ROADMAP.md follow-up edit (same pattern as Phase 25's D-04 VISUAL-03 descope) — not applied by this CONTEXT.md itself. See D-10.

---

## Workspace-Section

| Option | Description | Selected |
|--------|-------------|----------|
| Ja, mit Platzhalter-Inhalt | Sidebar-Eintrag existiert, zeigt Hinweistext ("No shelf settings yet"). | ✓ |
| Section weglassen, 3 statt 4 | Nur General / System(Theming) / About-License werden gebaut. | |

**User's choice:** Ja, mit Platzhalter-Inhalt
**Notes:** Satisfies ROADMAP Success Criterion #1 literally, even though no shelf-specific settings exist yet.

---

## Claude's Discretion

- Exact SwiftUI mechanism for material-style preset picker and per-element accent pickers (segmented control vs. list vs. swatch grid).
- Settings window sizing for the new NavigationSplitView layout (today's fixed 360×280 frame will likely need to grow).
- Fixed vs. collapsible NavigationSplitView sidebar.
- Exact placeholder copy for the empty Workspace (Shelf) section.
- Exact migration/seeding approach for the 3 new per-element accent keys (must not visually regress existing users).
- Whether the Solid Black preset needs any shape/corner-radius special-casing beyond Phase 25's existing values.

## Deferred Ideas

- **Alternate app icon variants** — no icon assets exist yet; deferred to backlog/a future phase (needs either user-supplied icon files or a real icon-design pass).
