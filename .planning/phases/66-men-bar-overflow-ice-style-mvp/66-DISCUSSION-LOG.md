# Phase 66: Menübar-Overflow (Ice-Style MVP) - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-27
**Phase:** 66-Menübar-Overflow (Ice-Style MVP)
**Areas discussed:** Chevron-Platzierung & Ein/Aus, Persistenz der versteckten Icons, Verhalten bei verweigerter Berechtigung, Reveal-Interaktion beim Klick

---

## Chevron-Platzierung & Ein/Aus

| Option | Description | Selected |
|--------|-------------|----------|
| Ganz links, immer aktiv nach Berechtigung | Ice-Konvention: Chevron trennt sichtbaren vom versteckten Bereich, erscheint automatisch sobald Accessibility gewährt ist — kein extra Settings-Schalter nötig. | ✓ |
| Ganz links, Opt-in über Settings | Gleiche Position, aber folgt dem Standard-Pattern aller neuen v1.10-Activities: Toggle in Settings, standardmäßig AUS. | |
| You decide | Überlass mir die Platzierungs-/Default-Entscheidung basierend auf Ice's Vorbild und dem Projekt-Pattern. | |

**User's choice:** Ganz links, immer aktiv nach Berechtigung
**Notes:** Diverges deliberately from the v1.10 "new activities default OFF" convention (Pitfall 5) — reasoning captured in CONTEXT.md D-02 (this is a menu-bar mechanism, not an `IslandResolver` activity).

---

## Persistenz der versteckten Icons

| Option | Description | Selected |
|--------|-------------|----------|
| Ja, persistent | Wie Ice: Zuordnung (welches App-Icon versteckt ist) wird gespeichert und beim nächsten Start wiederhergestellt — mehr Aufwand, aber kein ständiges Neu-Einsortieren. | ✓ |
| Nein, pro Session | Einfachste MVP-Variante — nach jedem Neustart sind alle Icons wieder sichtbar, User zieht bei Bedarf neu. | |
| You decide | Überlass mir die Entscheidung — ich wäge Aufwand vs. Nutzen beim Planen ab. | |

**User's choice:** Ja, persistent
**Notes:** Storage mechanism (UserDefaults vs. plist, keyed by bundle ID) left to Claude's discretion.

---

## Verhalten bei verweigerter Berechtigung

| Option | Description | Selected |
|--------|-------------|----------|
| Chevron fehlt, Settings zeigt Hinweis | Kein Chevron in der Menüleiste; in Settings steht klar "Berechtigung fehlt" mit Button direkt zu den Systemeinstellungen. | ✓ |
| Chevron ausgegraut mit Tooltip | Chevron ist sichtbar aber inaktiv/ausgegraut, Hover zeigt Erklärung warum es nicht funktioniert. | |
| You decide | Überlass mir die visuelle Umsetzung, solange es sichtbar (nicht still) degradiert. | |

**User's choice:** Chevron fehlt, Settings zeigt Hinweis
**Notes:** Satisfies MENUBAR-04's "visible, not silent" degradation requirement via the Settings-side explanation rather than a disabled menu-bar icon.

---

## Reveal-Interaktion beim Klick

| Option | Description | Selected |
|--------|-------------|----------|
| Inline in der Leiste (Ice-Stil) | Versteckte Icons gleiten direkt sichtbar in die Menüleiste ein, neben den bereits sichtbaren Icons. | ✓ |
| Dropdown/Popover | Ein separates Popover unterhalb des Chevrons listet die versteckten Icons auf — nicht direkt in der Leiste. | |
| You decide | Überlass mir die Wahl — ich orientiere mich am tatsächlichen Ice-Mechanismus, den die Phase sowieso als Spike liest. | |

**User's choice:** Inline in der Leiste (Ice-Stil)
**Notes:** Matches MENUBAR-03's requirement that hidden icons are genuinely absent (not just repositioned) — inline reveal is the literal Ice mechanic the phase's spike will read directly.

---

## Claude's Discretion

- Exact persistence storage mechanism/format (UserDefaults keyed by bundle ID vs. plist).
- Chevron icon glyph/SF Symbol choice.
- Animation style for the reveal/hide transition.
- Exact one-time permission-explanation copy/wording.
- Whether Islet's own status item(s) (main + debug) can also be hidden behind the chevron, or are exempt — default assumption is exempt, not discussed explicitly.
- All technical mechanism details assigned to the phase's own mandatory on-device spike (Success Criteria #1) — not a discussion decision.

## Deferred Ideas

None beyond what the milestone scope already excludes (always-hidden/hotkey tier, menu-bar theming, hotkeys — reaffirmed, not re-opened).

### Reviewed Todos (not folded)
- `2026-07-19-calendar-month-grid-polish.md` — unrelated (calendar UI).
- `2026-07-19-island-briefly-disappears-during-click-through.md` — unrelated (notch click-through).
- `2026-07-19-quick-action-disabled-state-has-no-controller-gate.md` — belongs to Phase 65, not 66.
