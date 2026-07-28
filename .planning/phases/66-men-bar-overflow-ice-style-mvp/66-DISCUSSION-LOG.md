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

---

# Revision: 2026-07-28 — Second mechanism pivot after Plan 66-04 NO-GO

> **Audit trail only.** Decisions captured in the revised CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-28
**Trigger:** Plan 66-04's on-device UAT checkpoint returned NO-GO — the pivoted public-`NSStatusItem`-spacer technique (built in 66-02) does not reclaim/hide layout space and does not accept Cmd-drag. See `66-04-SUMMARY.md`.
**Areas discussed:** Grundrichtung (overall direction), Diagnose (third-party-app check), Mechanismus (third mechanism candidate), Ansatz (debug vs. new spike), Ice-Status (live reference availability)

---

## Grundrichtung (Overall Direction)

| Option | Description | Selected |
|--------|-------------|----------|
| Dritten Mechanismus spiken | Try a third mechanism, spike-first on real hardware before any plan | ✓ |
| Feature aus v1.10 descopen | Drop Menübar-Overflow from the milestone; it blocks nothing else | |
| Pausieren bis stabiles macOS | Pause on the theory this is a Tahoe-beta-specific OS regression | |

**User's choice:** Try a third approach, spike-first.
**Notes:** Refined by the next two questions below.

---

## Diagnose (Third-Party-App Check)

| Option | Description | Selected |
|--------|-------------|----------|
| Ja, erst Ice/Hidden Bar installieren | Install real reference apps first to test whether the "OS regression" theory holds | |
| Nein, direkt neue Variante spiken | Assume it's our own implementation, skip the diagnostic | |

**User's choice:** Neither pre-written option — user volunteered directly: "Ich kann sagen das Ice funktioniert auf dem Gerät weil ich das bisher immer benutzt habe." (Ice already works on this machine, confirmed from daily use.)
**Notes:** The pivotal fact of this whole discussion. It disproves the "macOS 27 Tahoe beta regression" hypothesis recorded in project memory `phase66_menubar_overflow_second_nogo` for the CGS-based mechanism specifically — real Ice uses that same private-CGS technique and works fine here.

---

## Mechanismus (Third Mechanism Candidate) — superseded before being decided

| Option | Description | Selected |
|--------|-------------|----------|
| Spacer-Variante mit anderen Flags | Retry the spacer technique with isVisible/autosaveName/behavior tweaks | |
| Private CGS mit anderen Symbolen | Retry private CGS with different/renamed symbols | |
| Ich habe noch keine Präferenz | Defer to research/spike | ✓ (answered, then overtaken by the diagnostic finding above) |

**User's choice:** No preference given — the question itself was overtaken by the Ice-works-here finding, which redirected the whole approach (see Ansatz below).
**Notes:** Kept for the record; not the direction actually taken.

---

## Ansatz (Debug vs. New Spike)

| Option | Description | Selected |
|--------|-------------|----------|
| 66-01 debuggen statt neu spiken | Debug the original CGS spike against real, working Ice as a live reference | ✓ |
| Trotzdem neue dritte Variante | Treat 66-01 as closed, try a different technique anyway | |

**User's choice:** Debug 66-01 against real Ice.
**Notes:** Given Ice's own private-CGS mechanism works on this exact hardware, the most direct, evidence-based path is finding where Islet's port of that mechanism (built in Plan 66-01) diverges from Ice's actual working behavior — rather than guessing at a fourth unrelated technique.

---

## Ice-Status (Live Reference Availability)

| Option | Description | Selected |
|--------|-------------|----------|
| Ja, läuft aktuell | Ice installed and running now | |
| Installiert, aber nicht aktiv | Ice installed but not currently running | ✓ |
| Nicht mehr installiert | Ice not installed, would need reinstall | |

**User's choice:** Installed but not currently running.
**Notes:** The debugging plan's first step must launch Ice before any comparison work can begin.

## Claude's Discretion (this revision)

- Exact persistence storage mechanism/format for D-03, informed by research under the CGS mechanism's real semantics.
- Chevron icon glyph/SF Symbol choice.
- Animation style for the reveal/hide transition (D-05).
- Whether to restore/repurpose the existing (partially superseded) `MenuBarOverflowBridging.swift`/`MenuBarOverflowManualSpike.swift` files, or start the CGS spike fresh.
- Whether Islet's own status item(s) are exempt from the hide mechanism (default: exempt).
- Exact debugging technique for comparing Islet's spike against live Ice (logging, `lsappinfo`-style inspection, line-by-line source re-read).

## Deferred Ideas (this revision)

- Descoping Menübar-Overflow from v1.10 entirely — considered and rejected; user chose to keep pursuing it given the new diagnostic evidence.
- "Wait for stable macOS release" theory — rejected for the CGS mechanism now that Ice is confirmed working on this exact build; the public-spacer failure's cause remains unexplained but is no longer being pursued.
- Hidden Bar's public-spacer technique as a fallback if CGS debugging dead-ends — not decided; if debugging genuinely dead-ends, return to `/gsd:discuss-phase 66` rather than silently falling back.
