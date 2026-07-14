# Phase 33: Weather Widget Redesign - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-15
**Phase:** 33-weather-widget-redesign
**Areas discussed:** Location display, Extended card height, Forecast row

---

## Location display

| Option | Description | Selected |
|--------|-------------|----------|
| Echter Ortsname via Reverse-Geocoding | CLGeocoder wandelt die vorhandene CLLocation in einen Stadtnamen um | ✓ |
| Statisches Label "Local" | Kein echter Ortsname, immer "Local" wie im Referenz-Screenshot | |
| Ganz weglassen | Nur Icon + Temp + H/L, kein Standort-Text | |

**User's choice:** Echter Ortsname via Reverse-Geocoding (Empfehlung)

| Option | Description | Selected |
|--------|-------------|----------|
| "Local" als Fallback | Solange kein echter Ortsname vorliegt, zeigt das Widget "Local" | ✓ |
| Feld komplett ausblenden bis Name da ist | Kein Platzhalter-Text, Layout verspringt leicht wenn Name nachlädt | |

**User's choice:** "Local" als Fallback (Empfehlung)
**Notes:** Matches WeatherService's existing silent-omission-on-failure convention (Phase 14 D-01).

---

## Extended card height

| Option | Description | Selected |
|--------|-------------|----------|
| Weather bekommt eigene Höhen-Konstante | Gleiches Muster wie Tray in Phase 32 (trayContentHeight) — Home/Calendar bleiben bei 196pt | ✓ |
| Geteilte 196pt-Box global vergrößern | switcherContentHeight wächst für alle vier Tabs | |

**User's choice:** Weather bekommt eigene Höhen-Konstante (Empfehlung)
**Notes:** Direct precedent from Phase 32's `trayContentHeight` override pattern — avoids Phase 32's own painful 11-round vertical-clearance debugging spreading to Home/Calendar.

| Option | Description | Selected |
|--------|-------------|----------|
| Ja, animiert | Passt zum bestehenden Spring/matchedGeometryEffect-Stil | ✓ |
| Instant, kein Übergang nötig | Toggle meist bei geschlossenem Panel geändert | |

**User's choice:** Ja, animiert (Empfehlung)

---

## Forecast row

| Option | Description | Selected |
|--------|-------------|----------|
| So viele wie bei 420pt sauber passen, ohne Scrollen | Vermutlich 4-5 Tage statt Referenz-6, feste Anzahl | ✓ |
| Alle 6 Tage wie im Referenz-Screenshot, mit horizontalem Scrollen falls nötig | Hält sich exakt an die Referenz, übernimmt Tray-Scroll-Muster | |

**User's choice:** So viele wie bei 420pt sauber passen, ohne Scrollen (Empfehlung)

| Option | Description | Selected |
|--------|-------------|----------|
| Wochentag + Icon + High/Low | z.B. "Mo ☀️ 18°/12°" — entspricht Apple's Medium-Widget-Format | ✓ |
| Wochentag + Icon + nur High | Knapper, spart horizontalen Platz | |

**User's choice:** Wochentag + Icon + High/Low (Empfehlung)

---

## Claude's Discretion

- Exact forecast day count (4 vs 5) — determined by actual chip dimensions during planning/research, not fixed here.
- Separate `fetchDailyForecast` method vs. extending `fetchCurrent` — architecture research already recommends separate method; follow unless a reason emerges not to.
- Reverse-geocode granularity (city only vs. city+region) — pick whichever `CLPlacemark` field reads best in a narrow card.

## Deferred Ideas

- "Tray panel oversized vertically, shrink to fit content" pending todo matched this phase weakly (score 0.5, keyword-only) but is about Tray/Phase 32, not Weather — not folded in; appears already resolved by Phase 32's `trayContentHeight` shrink, flagged for todo-list cleanup instead.
