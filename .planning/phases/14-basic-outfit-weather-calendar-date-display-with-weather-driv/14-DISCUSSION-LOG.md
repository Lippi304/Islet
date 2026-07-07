# Phase 14: Basic Outfit — Weather + Calendar + Date Display - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-08
**Phase:** 14-basic-outfit-weather-calendar-date-display-with-weather-driv
**Areas discussed:** Wetter-Quelle & Standort, Kalender-Quelle & Termin-Auswahl, Wetter-animierter Hintergrund, Layout

---

## Wetter-Quelle & Standort

| Option | Description | Selected |
|--------|-------------|----------|
| Automatisch (Geräte-Standort) | One-time location permission prompt, then automatic current-location weather; denied → weather omitted | ✓ |
| Manuelle Stadt in Settings | User types a city once in Settings, no location permission prompt | |

**User's choice:** Automatisch (Geräte-Standort)
**Notes:** Matches the reference screenshot's behavior; graceful degradation (no weather shown) if denied.

---

## Kalender-Quelle & Termin-Auswahl

| Option | Description | Selected |
|--------|-------------|----------|
| Alle in macOS aktiven Kalender | EventKit across every calendar the system Calendar app shows | ✓ |
| Nur ein bestimmter Kalender | User picks one calendar in Settings, others ignored | |

**User's choice:** Alle in macOS aktiven Kalender

### Permission denial

| Option | Description | Selected |
|--------|-------------|----------|
| Basic Outfit ohne Kalender-Zeile | Silent omission, no error, no re-prompt | ✓ |
| Hinweis + Link zu Systemeinstellungen | Visible notice with a link to System Settings privacy pane | |

**User's choice:** Basic Outfit ohne Kalender-Zeile

### Which event when multiple exist today

| Option | Description | Selected |
|--------|-------------|----------|
| Nächster anstehender Termin | The next upcoming/in-progress event, advances through the day | ✓ |
| Erster Termin des Tages | Always the day's first event regardless of whether it already passed | |

**User's choice:** Nächster anstehender Termin

---

## Wetter-animierter Hintergrund — wie stark?

| Option | Description | Selected |
|--------|-------------|----------|
| Nur Icon animiert | Black bubble stays as-is; only the weather icon animates (rain, sun, clouds) | ✓ |
| Icon + dezenter Hintergrund-Farbverlauf | Icon animates AND the black bubble tints toward the weather mood | |

**User's choice:** Nur Icon animiert
**Notes:** Keeps consistency with the rest of the app's pure-black aesthetic.

### Weather category count

| Option | Description | Selected |
|--------|-------------|----------|
| 4 Kategorien (empfohlen) | Sunny, Cloudy, Rain, Snow | ✓ |
| Mehr Kategorien | + Thunderstorm, Fog, etc. — more icon/animation variants to build | |

**User's choice:** 4 Kategorien

---

## Layout innerhalb der festen Blasengröße

| Option | Description | Selected |
|--------|-------------|----------|
| 3-Spalten wie Referenzbild | Weather left · time+date center · calendar right, adapted to 360pt width | ✓ |
| 2 Zeilen — Zeit oben, Rest unten | Large centered time on top, weather/date/event in a narrower row below | |

**User's choice:** 3-Spalten wie Referenzbild

---

## Claude's Discretion

- Weather API/SDK choice (WeatherKit vs. free keyless API) — research to confirm budget fit.
- Exact icon animation implementation (SF Symbols animated variants vs. hand-rolled TimelineView).
- Exact EventKit query/authorization request shape.
- Precise spacing/sizing of the 3 columns within the fixed 360×144 bubble.

## Deferred Ideas

None — discussion stayed within the weather/calendar/date scope of this phase.
