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

---

## REVISION — 2026-07-15, after Plan 33-02 Task 3 on-device checkpoint

Plan 33-01 executed and merged. Plan 33-02 executed Tasks 1-2 (commits `f0e6bf0`, `580485d`) and reached the Task 3 human-verify checkpoint. User rejected the checkpoint: the built forecast row (5 daily weekday chips behind a single boolean toggle) did not match what they actually wanted, and supplied a real screenshot of Apple's own iOS Weather widgets (Medium vs. Large) — saved as `.planning/research/inspiration/32.png`. The original "6-day forecast row" text description in PROJECT.md turned out to be an inaccurate paraphrase of this reference.

**Areas re-discussed:**

| Option | Description | Selected |
|--------|-------------|----------|
| Medium only (hourly row) | Header + hourly forecast row, replaces the built daily-chip row 1:1 | |
| Large only (hourly + daily bar list) | Everything Medium has, plus a daily list with min/max range bars | |
| Both, user picks in Settings | Medium is the default; a Settings control lets the user switch to Large | ✓ |

**User's choice:** Both, selectable in Settings — clarified over several follow-up turns:

1. First answer: "Standard ist die Medium Anzeige und man kann erweitern auf die Large Variante" — established the two-tier Medium-default/Large-optional shape.
2. Follow-up on control shape (3-way segmented Compact/Medium/Large vs. two nested toggles) — user asked what "Compact" meant; clarified it as the pre-existing header-only state.
3. Final answer: "Es soll nur die beiden Möglichkeiten da sein die ich jetzt screenshotted habe nicht das was wir eben gebaut haben" — explicitly rejects keeping the built daily-chip row as a third option.
4. Final confirmation: "Ja ganz weg von Compact einfach nur diese beiden Medium und Large Widgets... wovon Medium standard ist" — Compact is fully removed as a selectable state; the widget always shows at least Medium; Settings offers a 2-way Medium/Large control, defaulting to Medium.

**Decisions captured:** D-03 through D-10 in the revised CONTEXT.md (widget-tier structure, hourly-row content, Large's new range-bar component, two-tier panel geometry). D-01/D-02 (location display) carried forward unchanged — already correctly built.

**Not re-litigated:** Location display and the underlying `.daily`/reverse-geocode data-layer work from Plan 33-01 — both still correct as built.
