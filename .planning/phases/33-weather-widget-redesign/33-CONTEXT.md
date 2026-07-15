# Phase 33: Weather Widget Redesign - Context

**Gathered:** 2026-07-15
**Status:** Ready for planning (revised — supersedes the 2026-07-15 morning version after on-device checkpoint feedback)

<domain>
## Phase Boundary

The Weather tab is redesigned as a 1:1 clone of Apple's own iOS Weather widget, always showing at least the "Medium" layout (location/icon/current temp/H-L header + an hourly forecast row) with a Settings-gated "Large" style adding a daily forecast list with min/max range bars. This is Phase 33 of the v1.5 milestone (WEATHER-01, WEATHER-02) — fully independent of the other v1.5 phases (Weather has its own resolver case and switcher tab, untouched by Phases 29-32).

**REVISION NOTE:** This supersedes the phase's original scope. Plan 33-01 (data layer: combined current+daily fetch, reverse-geocode, `weatherExtendedKey`) executed and merged as-is — still structurally valid (see Decisions below for what changes). Plan 33-02 (view layer) executed Tasks 1-2 (commits `f0e6bf0`, `580485d`) building a **daily 5-chip forecast row gated by a single boolean toggle** — this was based on a misreading of the original "6-day forecast row" description in PROJECT.md and does NOT match the real reference (Apple's actual iOS widget, screenshotted by the user at the Task-3 on-device checkpoint). That forecast-row implementation must be reworked, not extended. See `.planning/research/inspiration/32.png` and `notes.md`'s "Weather widget reference" section for the real reference.

</domain>

<decisions>
## Implementation Decisions

### Location display (unchanged — still correct as built)
- **D-01:** Show the real place name via reverse-geocoding (`CLGeocoder`), not a static "Local" label and not omitted entirely. Uses the existing `CLLocation` already obtained by `LocationProvider` — no new permission ask. Already implemented in Plan 33-01/33-02 as intended — no rework needed.
- **D-02:** While reverse-geocoding is pending, or on failure (no permission, no network, geocode error), show "Local" as the fallback label rather than a blank field or error text — matches `WeatherService`'s existing "silent omission on failure" convention (Phase 14 D-01). No layout shift while the real name loads in. Already implemented — no rework needed.

### Widget tiers — Medium is now the permanent baseline (REVISES original D-03)
- **D-03 (revised):** There is no more "Compact-only" state. The Weather tab always shows at minimum the **Medium** layout: the existing header (location, icon, current temp, H/L) PLUS an hourly forecast row beneath it, at all times — this is the new default, not something a toggle turns on. The original WEATHER-01 "compact card" framing is superseded by this always-shows-Medium behavior; the header fields themselves are unchanged, only their permanent pairing with the hourly row is new.
- **D-04 (new):** A Settings control offers exactly two style options — **Medium** (default) and **Large** — via a 2-way segmented control (not a boolean toggle, and not a 3-way control with a "Compact" option, since Compact no longer exists as a selectable state). Replaces the old `weatherExtendedKey` boolean semantics: the key can be repurposed to store the Medium/Large selection (e.g. a String/enum-backed `@AppStorage`) rather than a plain Bool — planner's call on the exact storage shape, but it must default to "Medium" for existing users (absent-key default).
- **D-05 (new):** Switching between Medium and Large animates live via the existing spring/blobShape-height mechanism (same precedent as the old D-04) — consistent with every other size transition in the app.

### Medium layout — hourly forecast row (REPLACES original D-05/D-06 daily-chip-row decisions)
- **D-06 (new):** Medium's forecast row is **hourly**, not daily — time label + condition icon + temperature per chip (e.g. "6:00 ☀️ 14°"), reusing the exact `weatherIcon(for:)` and temperature-formatting conventions already in place. This requires the WeatherKit `.hourly` dataset, which is NOT currently fetched (Plan 33-01 only fetches `.current` + `.daily`) — planner/researcher must add an hourly fetch, either folded into the existing combined call (`weather(for:including: .current, .hourly, .daily)`) or a separate call, following the same "one call, not N" discipline Plan 33-01's Pitfall 1 established.
- **D-07 (new):** Show as many hourly chips as fit cleanly at the existing 420pt panel width without horizontal scrolling or a `ScrollView` (same reasoning as the old D-05 — a fixed-count row that always fits, discoverability over scrolling). Apple's own reference shows 6; exact count is Claude's discretion based on real chip width once built.
- **Superseded:** the previously-built 5-day weekday-chip row (`forecastRow` in `NotchPillView.swift`, commit `f0e6bf0`) is replaced by this hourly row, not kept alongside it. The `.daily` fetch from Plan 33-01 is NOT wasted — it becomes the data source for Large's daily list (D-08 below), just no longer for a top-level chip row.

### Large layout — daily forecast list with range bars (NEW — no prior decision existed for this)
- **D-08 (new):** Large adds, below the Medium content (header + hourly row), a daily forecast list: one row per day showing day-of-week label, condition icon, low temperature (dimmed/secondary), a horizontal gradient bar representing that day's temperature range positioned within the visible list's overall min/max span, and high temperature (full-brightness). This is a new SwiftUI component with no existing precedent in the codebase — planner/researcher should treat the range-bar as the highest-risk/most-novel piece of this phase.
- **D-09 (new):** Day count for the Large list follows the same "fit cleanly, no scroll" principle as D-07 — Apple's reference shows 5 (Do-Mo); exact count is Claude's discretion based on real row height once built.
- **D-10 (new):** Large's reserved panel height is taller than Medium's (header + hourly row + full daily list) — this needs its own height constant (or a height function taking the day count), following the same `trayContentHeight`-precedent pattern as before, but now for TWO non-collapsed sizes (Medium, Large) instead of one (the old compact-vs-extended split). The three-site geometry rule (`blobShape` height override / `positionAndShow` union / `visibleContentZone()` branch) must account for both sizes, not just one — this is a materially bigger geometry surface than what Plan 33-02's Task 2 originally built, and needs its own explicit on-device checkpoint pass for both Medium→Large and Large→Medium transitions, plus the hover→expand→move-down click-through trace at the Large size specifically (CR-01/WR-02 regression class).

### Claude's Discretion
- Exact hourly chip count (D-07) and exact daily row count for Large (D-09) — pick whichever counts fit cleanly given real dimensions once built.
- Whether the hourly fetch is folded into the existing combined WeatherKit call or issued separately — follow the "one call" discipline already established in Plan 33-01 unless research finds a reason not to.
- Whether `weatherExtendedKey`'s storage is migrated to a String/enum or a new key is introduced alongside it — whichever keeps the Bool→enum migration cleanest for existing users defaulting to Medium.
- Exact gradient/color treatment of the range bar — match the spirit of Apple's bar (color scales with temperature, positioned within the list's min/max) without needing pixel-exact color stops.
- Exact reverse-geocode granularity (city only vs. city+region) — no strong user preference expressed.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Weather widget visual reference (THE authoritative reference — supersedes the PROJECT.md text description)
- `.planning/research/inspiration/32.png` — Apple's own iOS Weather widgets, Medium vs. Large side by side. This is the ground truth for D-06 through D-10.
- `.planning/research/inspiration/notes.md` §"Weather widget reference (image 32...)" — written description of what the screenshot shows and exactly how it corrects the original misread.

### v1.5 milestone / requirements
- `.planning/PROJECT.md` §"Current Milestone: v1.5" — Weather redesign goal; note its "6-day forecast row" text description is now known to have been an inaccurate paraphrase of the real reference (image 32) — trust image 32, not this text, for row content/structure
- `.planning/REQUIREMENTS.md` — WEATHER-01, WEATHER-02 full requirement text and anti-feature table (WidgetKit extension out of scope; radar/alerts out of scope — note "no hourly" in the old anti-feature table is now superseded by D-06, since the corrected reference explicitly requires hourly data)

### Architecture research (covers the original data/state shape; does NOT cover hourly fetch or the range-bar component — those are new since this revision)
- `.planning/research/ARCHITECTURE.md` §"Feature 4 — Weather widget card + optional extended forecast" — concrete change shape for the daily-fetch/state/toggle pattern (still structurally applicable, extend for hourly)
- `.planning/research/FEATURES.md` §"Area 4 — Weather as an iOS-widget-style card" — anti-feature table now partially outdated by D-06 (hourly is in scope); location-name source still correctly resolved by D-01/D-02

### Existing code — Plan 33-01 (data layer, merged, mostly still valid)
- `Islet/Weather/WeatherService.swift` — `DailyForecast` model, 4-field `WeatherGlance` (category/temperature/high/low), `fetchCurrentAndForecast`/`resolvePlaceName` on `WeatherService`/`WeatherKitService` — the combined-call pattern to extend with `.hourly` per D-06
- `Islet/Notch/BasicOutfitState.swift` — `forecast: [DailyForecast]?`, `locationName: String?` fields — will need an `hourlyForecast` (or similarly named) field added alongside
- `Islet/ActivitySettings.swift` — `weatherExtendedKey` — needs migration per D-04 (Bool → Medium/Large selector)

### Existing code — Plan 33-02 (view layer, Tasks 1-2 committed but built the wrong forecast content; header parts are correct)
- `Islet/Notch/NotchPillView.swift` (commit `f0e6bf0`) — `weatherExtendedContentHeight` constant, `weatherFullContent` (location/H-L — CORRECT, keep), `forecastRow` (5-day weekday chips — WRONG, replace with hourly row per D-06, then add the Large daily-bar-list component per D-08)
- `Islet/Notch/NotchWindowController.swift` (commit `580485d`) — `refreshWeather()` combined-fetch wiring (extend for hourly), `positionAndShow`'s `weatherExtendedFrame` union member and `visibleContentZone()`'s `.weatherExpanded` branch (both need a second size tier per D-10)
- `Islet/SettingsView.swift` (commit `580485d`) — "Extended forecast" boolean Toggle — replace with the Medium/Large segmented control per D-04
- `Islet/Weather/WeatherCategory.swift` — pure `WeatherCondition` → `WeatherCategory` classification, reused as-is for both hourly and daily entries

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `weatherIcon(for:)` (NotchPillView.swift ~1486) — existing SF Symbol mapping per `WeatherCategory`, reuse verbatim for the header icon, each hourly chip's icon, and each daily-list row's icon.
- Temperature formatting — `weather.temperature.formatted(.measurement(width: .narrow, numberFormatStyle: .number.precision(.fractionLength(0))))` is the existing locale-aware convention; reuse for H/L, hourly-chip temps, and daily-list low/high temps.
- `LocationProvider`/`CLLocation` (NotchWindowController.swift ~121, ~580) — the existing coarse-refresh-gated location fetch; reverse-geocoding hangs off this same `CLLocation`, no new permission or fetch trigger needed. Already wired.
- Phase 32's `trayContentHeight` override pattern (NotchPillView.swift, `blobShape`'s `height:` param winning over the `showSwitcher` default) — the direct precedent for both Medium's and Large's height constants (D-10 now needs two, not one).
- `ActivitySettings`/`@AppStorage` + `UserDefaults.didChangeNotification` observer already wired in `NotchWindowController.start()` — the Medium/Large selector plugs into this exact existing live-reload mechanism, no new observer needed.
- Plan 33-02's already-correct header work (`weatherFullContent`'s location/H-L rendering, commit `f0e6bf0`) — keep as-is, do not rebuild.

### Established Patterns
- "Isolate the fragile external behind one seam" (`WeatherService` protocol, `NowPlayingMonitor`, `LicenseService`) — the new hourly fetch must go through the `WeatherService` protocol, not a direct `WeatherKit` call from the view layer.
- "Silent omission on failure, no retry" (Phase 14 D-01) — hourly/daily fetch failures degrade the same way current-conditions failures already do; do not invent a different failure UX.
- "One call, not two" (Plan 33-01's Pitfall 1, re-affirmed by D-06) — the hourly dataset should fold into the existing combined WeatherKit call rather than triggering a second network round-trip, unless research finds a concrete reason WeatherKit can't return `.current`+`.hourly`+`.daily` together.

### Integration Points
- `BasicOutfitState` already has `forecast: [DailyForecast]?` and `locationName: String?` (Plan 33-01) — needs an hourly-forecast field added alongside for D-06.
- `NotchWindowController.refreshWeather()` is the dispatch point — per D-03, it now always needs current+hourly (no more toggle-gating on the fetch itself, since Medium's hourly row is the permanent default); `.daily` continues to be fetched unconditionally too (cheap, already the case) since Large needs it live-available the moment the user switches styles, not fetched on-demand.

</code_context>

<specifics>
## Specific Ideas

- **`.planning/research/inspiration/32.png`** — Apple's own iOS Weather widgets (Medium + Large side by side), the exact and only visual reference for D-06 through D-10. This is a genuine screenshot, not a text paraphrase — trust its exact structure (header → hourly row → [Large only] daily list with range bars) over any earlier text description in PROJECT.md.
- User's framing at the checkpoint: "Droppy hat diese 1:1 Wetter app widget. Genau sowas wollte ich nachbauen" — the intent is a faithful 1:1 clone of Apple's own widget shapes (via a Droppy comparison, but the actual reference image supplied is Apple's widget, not a Droppy screenshot), not a loose reinterpretation.
- Confirmed explicitly: no "Compact-only" state should remain selectable — "Ja ganz weg von Compact, einfach nur diese beiden Medium und Large Widgets... wovon Medium standard ist."

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope; this revision is a correction of the original scope's forecast-row misunderstanding, not new scope.

</deferred>

---

*Phase: 33-weather-widget-redesign*
*Context gathered: 2026-07-15 (revised same day after Plan 33-02 checkpoint feedback)*
