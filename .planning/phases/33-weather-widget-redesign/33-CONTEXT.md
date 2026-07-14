# Phase 33: Weather Widget Redesign - Context

**Gathered:** 2026-07-15
**Status:** Ready for planning

<domain>
## Phase Boundary

The Weather tab is redesigned as an iOS-widget-style card: a compact default (location, condition icon, current temperature, high/low) plus a Settings-gated extended variant that adds a multi-day forecast row. This is Phase 33 of the v1.5 milestone (WEATHER-01, WEATHER-02) — fully independent of the other v1.5 phases (Weather has its own resolver case and switcher tab, untouched by Phases 29-32).

</domain>

<decisions>
## Implementation Decisions

### Location display
- **D-01:** Show the real place name via reverse-geocoding (`CLGeocoder`), not a static "Local" label and not omitted entirely. Uses the existing `CLLocation` already obtained by `LocationProvider` — no new permission ask.
- **D-02:** While reverse-geocoding is pending, or on failure (no permission, no network, geocode error), show "Local" as the fallback label rather than a blank field or error text — matches `WeatherService`'s existing "silent omission on failure" convention (Phase 14 D-01). No layout shift while the real name loads in — the "Local" placeholder occupies the same slot the resolved name will use.

### Extended card height
- **D-03:** Weather gets its own height constant for the extended (forecast-showing) state, following Phase 32's `trayContentHeight` precedent exactly (a dedicated override that wins over the shared `switcherContentHeight` default). Home and Calendar stay untouched at 196pt regardless of Weather's toggle state — Weather is the only tab whose reserved height changes, and only when its own extended setting is on.
- **D-04:** Toggling the extended-forecast Settings switch animates live if the panel happens to be open at the time (spring/matchedGeometryEffect, consistent with every other size transition in the app — Home↔Tray, collapsed↔expanded). Not gated behind "settings usually change while collapsed" — build it animated by default since the mechanism already exists project-wide.

### Forecast row
- **D-05:** Show as many forecast days as fit cleanly at the existing 420pt panel width without horizontal scrolling — likely 4-5 days rather than the reference screenshot's 6. Research/planning determines the exact count from actual chip width (icon + weekday label + H/L text) plus the row's horizontal padding. No `ScrollView` for this row — a fixed-count row that always fits is preferred over Tray's scrolling pattern (scrolling in a small notch card was judged less discoverable than in Tray's dedicated file-shelf).
- **D-06:** Each day-chip shows: weekday label + condition icon + high/low temperatures (e.g. "Mon ☀️ 18°/12°") — matches Apple's own Medium-widget format. Not weekday+icon+high-only.

### Claude's Discretion
- Exact forecast day count (4 vs 5) — pick whichever count fits cleanly given the actual chip dimensions once built; don't force a specific number if the math doesn't land evenly.
- Whether the new WeatherKit forecast call is a fully separate `fetchDailyForecast` method or an extension of `fetchCurrent`'s signature — architecture research (see canonical refs) already recommends a separate method; follow that unless research turns up a reason not to.
- Exact reverse-geocode granularity (city only vs. city+region) — pick whichever `CLPlacemark` field reads most naturally in a narrow widget card; no strong user preference expressed.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### v1.5 milestone / requirements
- `.planning/PROJECT.md` §"Current Milestone: v1.5" — Weather redesign goal, reference layout description ("Local / 16° Cloudy H:24 L:15 / 6-day forecast row")
- `.planning/REQUIREMENTS.md` — WEATHER-01, WEATHER-02 full requirement text and anti-feature table (WidgetKit extension out of scope; hourly/alerts/radar out of scope)

### Architecture research (already covers most technical unknowns for this phase)
- `.planning/research/ARCHITECTURE.md` §"Feature 4 — Weather widget card + optional extended forecast" — concrete change shape: new `DailyForecast` model, `fetchForecast`/`fetchDailyForecast` protocol method, `BasicOutfitState.forecast` field, Settings `@AppStorage` toggle pattern (mirrors `ActivitySettings.MaterialStyle`), and the `switcherContentHeight` sizing conflict this CONTEXT.md's D-03 resolves
- `.planning/research/FEATURES.md` §"Area 4 — Weather as an iOS-widget-style card" — anti-feature table (no hourly, no continuous polling, no full weather-app feature set), open question flagged about location-name source (resolved by this CONTEXT.md's D-01/D-02)

### Existing code (current-conditions fetch, to be extended not replaced)
- `Islet/Weather/WeatherService.swift` — `WeatherService` protocol, `WeatherGlance` struct, `WeatherKitService.fetchCurrent` (always-main-thread completion, silent-nil-on-failure contract — new forecast fetch must follow the same contract)
- `Islet/Weather/WeatherCategory.swift` — pure `WeatherCondition` → `WeatherCategory` classification, reused as-is for forecast days
- `Islet/Notch/NotchPillView.swift` (~lines 737-775) — `weatherFullView`/`weatherFullContent`/`weatherCategoryLabel`, the current compact-only rendering this phase extends

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `weatherIcon(for:)` (NotchPillView.swift ~1486) — existing SF Symbol mapping per `WeatherCategory`, reuse verbatim for both the compact icon and each forecast-day chip's icon.
- Temperature formatting — `weather.temperature.formatted(.measurement(width: .narrow, numberFormatStyle: .number.precision(.fractionLength(0))))` is the existing locale-aware convention (no manual Celsius/Fahrenheit conversion); reuse for H/L and forecast-day temps.
- `LocationProvider`/`CLLocation` (NotchWindowController.swift ~121, ~580) — the existing coarse-refresh-gated location fetch; reverse-geocoding hangs off this same `CLLocation`, no new permission or fetch trigger needed.
- Phase 32's `trayContentHeight` override pattern (NotchPillView.swift, `blobShape`'s `height:` param winning over the `showSwitcher` default) — the direct precedent D-03 follows for Weather's own height constant.
- `ActivitySettings`/`@AppStorage` + `UserDefaults.didChangeNotification` observer already wired in `NotchWindowController.start()` — the extended-forecast toggle plugs into this exact existing live-reload mechanism, no new observer needed.

### Established Patterns
- "Isolate the fragile external behind one seam" (`WeatherService` protocol, `NowPlayingMonitor`, `LicenseService`) — the new forecast fetch must go through the `WeatherService` protocol, not a direct `WeatherKit` call from the view layer.
- "Silent omission on failure, no retry" (Phase 14 D-01) — forecast fetch failures degrade the same way current-conditions failures already do; do not invent a different failure UX for the new forecast path.
- Lazy/gated fetching — the forecast WeatherKit call only fires when the extended setting is enabled, avoiding a wasted API call for users on the compact-only default (mirrors the project's existing "no eager fetch" discipline).

### Integration Points
- `BasicOutfitState` gains a new `@Published var forecast: [DailyForecast]?` field alongside the existing `weather`/`calendar` fields (controller-only writer, same ownership contract as today).
- `NotchWindowController.refreshWeather()` becomes the dispatch point: always fetches current+H/L for the compact card; only fetches the daily forecast when the extended Settings toggle is on.

</code_context>

<specifics>
## Specific Ideas

- Reference layout: "Local / 16° Cloudy H:24 L:15 / 6-day forecast row" (compact-card fields plus what the extended row should look like) — screenshot referenced in `.planning/PROJECT.md`, not stored as a separate inspiration file in this repo (unlike the Droppy screenshots in `.planning/research/inspiration/`).
- Apple's own iOS Weather widgets (Small = location/icon/temp/H-L; Medium = same + horizontal multi-day row) are the explicit visual/structural reference — a well-understood, standard layout, not an exotic UI technique.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope. (The one weakly-matched pending todo, "Tray panel oversized vertically, shrink to fit content," is about Tray/Phase 32 and was not folded here — it appears already resolved by Phase 32's `trayContentHeight` shrink work; flagged for todo-list cleanup rather than carried into this phase.)

</deferred>

---

*Phase: 33-weather-widget-redesign*
*Context gathered: 2026-07-15*
