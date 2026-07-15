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

---

## REVISION 2 — 2026-07-15, after Plan 33-02 Tasks 1-3 recovered from an interrupted session

Session closed mid-execution after the first revision's Tasks 1-3 were built (hourly row + Large daily list); work was recovered from an orphaned git worktree and merged. On resuming, the user said: "Ja ne ich will 1:1 das widget von der Kalender app dort drin haben und es nicht selbst gebaut haben, das wurde bisher falsch verstanden" — raising doubt about whether the whole approach (a hand-built recreation vs. embedding a real system widget) and the reference app (Weather vs. Calendar) were correct.

**Areas discussed:**

| Option | Description | Selected |
|--------|-------------|----------|
| Pixelgenaue Nachbildung | Recreate the widget's look in Islet's own SwiftUI code | ✓ |
| Echtes System-Widget live einbetten | Host the real live WidgetKit widget inside Islet | |

**User's choice:** Pixelgenaue Nachbildung (Empfehlung) — live-embedding a system widget isn't possible via public macOS API for a third-party host app.

| Option | Description | Selected |
|--------|-------------|----------|
| Wetter-App Widget (Weather.app) | Apple's standalone macOS Weather app's own widget | ✓ |
| Notification-Center-Panel bei Klick auf die Menüleisten-Uhr | The panel shown when clicking the menu-bar clock (Calendar events + Weather together) | |
| Etwas anderes | User describes/provides a screenshot | |

**User's choice:** Wetter-App Widget (Weather.app) — "Kalender App" in the original message was the user's informal name for something else; the actual target is the Weather.app widget.

User then supplied two direct screenshots of the real macOS Weather.app widget (Standard/Medium and Extended/Large, Neubrandenburg), saved as `.planning/research/inspiration/33.png`/`34.png`. Comparison against the already-built Tasks 1-3 code found:
- Hourly row and Large daily range-bar list: **already correct**, no rework.
- Header (`weatherFullContent`): **wrong** — single centered column built, but the real widget uses a two-column split (location+arrow+temp left, condition+H/T right). New decision D-11.

| Option | Description | Selected |
|--------|-------------|----------|
| Islets bestehendes Glass-Chrome behalten | Weather tab stays visually consistent with Home/Tray/Calendar's existing black/frosted glass | ✓ |
| Apples Wetter-Verlaufshintergrund übernehmen | Adopt Apple's own navy/time-of-day gradient card background | |

**User's choice:** Islets bestehendes Glass-Chrome behalten (Empfehlung) — new decision D-12.

**Decisions captured:** D-11 (header two-column rework), D-12 (background stays Islet's existing chrome), both added to the revised CONTEXT.md. D-01 through D-10 carried forward unchanged — confirmed still correct against the new, higher-fidelity screenshots.

**Not re-litigated:** Hourly row content/count (D-06/D-07), Large daily range-bar list (D-08/D-09), two-tier panel geometry (D-10), WeatherStyle Settings control (D-04/D-05) — all confirmed correct as already built in Tasks 1-3.
