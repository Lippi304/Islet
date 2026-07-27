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

---

# Revision: 2026-07-27 — Mechanism pivot after Plan 66-01 NO-GO

> **Audit trail only.** Decisions captured in the revised CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-27
**Trigger:** Plan 66-01's on-device spike returned NO-GO — Ice's private `CGSGetProcessMenuBarWindowList` mechanism does not enumerate real menu-bar windows on this hardware (macOS 27.0 beta), matching RESEARCH.md's own flagged Pitfall 3 risk. See `66-01-SUMMARY.md`.
**Areas discussed:** Technical direction after NO-GO, fate of MENUBAR-04 (Accessibility permission requirement)

---

## Technical direction after NO-GO

| Option | Description | Selected |
|--------|-------------|----------|
| Switch to spacer technique (Hidden Bar reference) | Reimplement using a giant-width invisible NSStatusItem that pushes icons off-screen. Public API only, no Accessibility permission, robust across macOS versions. Requires revising D-04/MENUBAR-04. | ✓ |
| Keep chasing Ice's private-API technique | Try to find/port whatever fix Ice's own team shipped for Tahoe compatibility. | |
| Descope Menübar-Overflow from v1.10 | Drop MENUBAR-01..04 entirely, move on to Phase 67. | |

**User's choice:** Switch to spacer technique (Recommended option)
**Notes:** Grounded in a direct read of Hidden Bar's `StatusBarController.swift` (github.com/dwarvesf/hidden, MIT) confirming the technique is public-API-only (`NSStatusBar.system.statusItem(withLength:)`, width toggled between ~20pt and ~2000pt bounded to screen width) and needs no private symbols or permissions. Also grounded in confirming this dev machine runs macOS 27.0 (beta, build 26A5388g) — newer than Tahoe (26), where Ice's own issues #679/#711 already documented the same class of breakage.

---

## Fate of MENUBAR-04 (Accessibility permission requirement)

| Option | Description | Selected |
|--------|-------------|----------|
| Drop it entirely | No permission needed → no gating, no "Permission required" Settings card, no deep-link button. | ✓ |
| Keep a minimal Settings entry anyway | Show a small Settings row confirming the feature is active, without permission-status logic. | |

**User's choice:** Drop it entirely
**Notes:** REQUIREMENTS.md still shows MENUBAR-04's original wording; the revised CONTEXT.md is the authority that supersedes it for this phase — downstream agents must not build any permission flow.

## Claude's Discretion (this revision)

- Whether to delete or repurpose the now-superseded `MenuBarOverflowBridging.swift`/`MenuBarOverflowManualSpike.swift` spike artifacts.
- Whether a full on-device spike-gate is still necessary before production code, given the new mechanism is public-API-only (research/planning call).
- D-03's open question: whether macOS's own status-item-ordering persistence suffices, or Islet needs active re-apply logic under the new technique.

## Deferred Ideas (this revision)

- Retrying Ice's private-API mechanism or porting Ice's own Tahoe-compatibility fix — explicitly considered and rejected in favor of the spacer technique.
