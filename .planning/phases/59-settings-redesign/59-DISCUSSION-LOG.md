# Phase 59: Settings-Redesign - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-23
**Phase:** 59-Settings-Redesign
**Areas discussed:** Grid-Layout — Gruppierung & Reihenfolge, Was gehört ins Grid?, Karten mit Zusatzoptionen (Popover), Mini-Live-Preview — Echt oder Mock?

---

## Grid-Layout — Gruppierung & Reihenfolge

| Option | Description | Selected |
|--------|-------------|----------|
| Kategorisiert (System-HUDs / Medien / Produktivität) | Braucht neue Kategorie-Header, macht 8+ neue Aktivitäten übersichtlich | ✓ |
| Eine flache Liste, feste Reihenfolge | Einfacher zu bauen, kein Kategorie-Konzept nötig | |
| Alphabetisch | Vorhersehbar, ordnet aber thematisch zusammenhängende Aktivitäten weit auseinander | |

| Option | Description | Selected |
|--------|-------------|----------|
| 2 Spalten | Karten breiter, mehr Platz für Beschreibungstext | ✓ |
| 3 Spalten | Näher an Droppy-Referenz, kompakter | |
| Responsive (automatisch) | Mehr Aufwand, wenig Nutzen bei fixer Fensterbreite | |

| Option | Description | Selected |
|--------|-------------|----------|
| Bestehende vor neuen | Nutzer sieht Vertrautes zuerst | ✓ |
| Neue vor bestehenden | Hebt neue Aktivitäten hervor | |
| Manuell kuratierte Reihenfolge | Volle Freiheit beim Bauen | |

| Option | Description | Selected |
|--------|-------------|----------|
| Ja, "Neu"-Badge | Hilft, die 8 neuen (default-OFF) Aktivitäten zu entdecken | ✓ |
| Nein, keine Markierung | Einfacher, aber neue Aktivitäten könnten untergehen | |

**User's choice:** Kategorisiert, 2 Spalten, bestehende vor neuen, mit "Neu"-Badge.
**Notes:** Keine.

---

## Was gehört ins Grid?

| Option | Description | Selected |
|--------|-------------|----------|
| Ja, raus aus dem Grid | "Launch at login"/"Auto-Update" bleiben als schlichte Toggles außerhalb | ✓ |
| Trotzdem als Karten ins Grid | Konsistenz, aber ohne echte Pill-Vorschau | |

| Option | Description | Selected |
|--------|-------------|----------|
| Eigene Karte | Konsistent mit "eine Karte pro Toggle" | ✓ |
| Unteroption von "Now Playing" | Spiegelt tatsächliche Abhängigkeit wider | |

| Option | Description | Selected |
|--------|-------------|----------|
| Produktivität | Passt thematisch zu "Zeit/Termine organisieren" | |
| System-HUDs | Kategorie bedeutet eher "alles was vor v1.10 existierte + Systemzustand" | ✓ |

**User's choice:** Launch-at-login/Auto-Update raus aus dem Grid; Song-Change-Toast als eigene Karte; Calendar Countdown → System-HUDs.
**Notes:** Keine.

---

## Karten mit Zusatzoptionen (Popover)

| Option | Description | Selected |
|--------|-------------|----------|
| Ja, Popover bleibt an der Karte | Minimale Änderung, Konsistenz mit heutigem Toggle | ✓ |
| Zusatzoptionen wandern in ein "Verwalten…"-Sheet | Mehr Platz für zukünftige komplexere Einstellungen | |

| Option | Description | Selected |
|--------|-------------|----------|
| Generischer Options-Slot jetzt schon | Kleiner Mehraufwand jetzt, spart Rework später | ✓ |
| Erst bei Bedarf (YAGNI) | Spätere Phasen erweitern die Card-Komponente selbst | |

| Option | Description | Selected |
|--------|-------------|----------|
| Ersetzt es — ein einheitliches Options-Icon | Optisch konsistent über alle Karten | ✓ |
| Zwei getrennte Icons | Vermeidet Migrationsrisiko am bestehenden UI-Verhalten | |

**User's choice:** Popover bleibt an der Karte; generischer Options-Slot wird jetzt gebaut und ersetzt das bisherige Icon.
**Notes:** Bewusste Foundation-Entscheidung für spätere Phasen (Timer-Dauer, Meeting-HUD-Kalenderauswahl etc.), kein Scope-Creep — die neuen Aktivitäten selbst werden nicht in Phase 59 gebaut.

---

## Mini-Live-Preview — Echt oder Mock?

| Option | Description | Selected |
|--------|-------------|----------|
| Echte Live-Daten | Eindrucksvoller, aber deutlich mehr Aufwand pro Aktivität; bei default-OFF neuen Aktivitäten gäbe es ohnehin nichts Echtes zu zeigen | |
| Statisches Illustrations-Icon | Weniger Aufwand, funktioniert auch für ausgeschaltete/neue Aktivitäten, entspricht dem tatsächlichen Droppy-Referenz-Grid | ✓ |

| Option | Description | Selected |
|--------|-------------|----------|
| Ich (Claude) entwerfe beides | Icons + Beschreibungstexte, Review beim UAT | ✓ |
| Erst als Mockup/Sketch ansehen | Kurzer /gsd:sketch vor der eigentlichen Umsetzung | |

**User's choice:** Statische Illustrations-Icons; Claude entwerft Icons und Beschreibungstexte direkt.
**Notes:** Keine.

---

## Claude's Discretion

- Exakte Form/Ablageort der Resolver-Priority-Tabelle (SC5) — keine Nutzerpräferenz geäußert.
- Konkreter Migrationsmechanismus für default-OFF neue Aktivitäten — Wiederverwendung des bestehenden `migrateLegacyAccentIfNeeded()`-Musters.

## Deferred Ideas

None — discussion stayed within phase scope.
