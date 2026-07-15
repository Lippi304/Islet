# Phase 33: Weather Widget Redesign - Context

**Gathered:** 2026-07-15
**Status:** Ready for planning (revised twice — this version supersedes the 2026-07-15 "iOS widget clone" revision after a second checkpoint correction)

<domain>
## Phase Boundary

The Weather tab is redesigned as a 1:1 clone of Apple's own Weather-app widget (confirmed identical between iOS and macOS), always showing at least the "Medium" layout (two-column header: location+arrow+temp left, condition icon+label+H/T right, plus an hourly forecast row) with a Settings-gated "Large" style adding a daily forecast list with min/max range bars. This is Phase 33 of the v1.5 milestone (WEATHER-01, WEATHER-02) — fully independent of the other v1.5 phases (Weather has its own resolver case and switcher tab, untouched by Phases 29-32).

**REVISION NOTE (second round):** Plan 33-02 Tasks 1-3 (commits `326b0ca`, `e8d36cf`, `63fbac4`) executed the FIRST correction (hourly row + Large daily range-bar list) and got the hourly row and daily list right — confirmed structurally correct against real macOS Weather.app screenshots (`33.png`, `34.png`). But the header (`weatherFullContent`, previously marked "already correct, keep verbatim") is WRONG: it's a single centered column, but the real widget uses a two-column split header. See D-11 below — this is the only remaining rework, everything else from Tasks 1-3 stays.

**REVISION NOTE (first round, for history):** Plan 33-01 (data layer) executed and merged as-is — still structurally valid. Plan 33-02's original Tasks 1-2 built a daily 5-chip forecast row gated by a boolean toggle, based on a misreading of PROJECT.md's text description — corrected to the hourly-row + Large-daily-list structure now in `<decisions>` below.

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

### Header layout — two-column split (NEW, second-round correction — supersedes "keep verbatim" guidance)
- **D-11 (new):** `weatherFullContent` must be reworked from a single centered VStack into a two-column header, matching the real widget (`33.png`/`34.png`): **left column** — location name + a small directional arrow icon (mirrors the real widget's compass-style location indicator) stacked above the large current-temperature text; **right column** (top-aligned, trailing-aligned) — the condition icon, the condition label, and the "H: T: " line, stacked. The existing content (location/fallback text, icon mapping, temperature formatting, H/L formatting) is reused as-is — only the layout container changes from one centered `VStack` to an `HStack` of two `VStack`s. The hourly row and (Large) daily list remain unchanged below this header, full-width as already built.
- Exact SF Symbol for the location arrow icon is Claude's/planner's discretion (e.g. `location.fill` or a rotated arrow) — no exact system icon was identified from the reference, match the spirit (small, secondary-colored, directly after the location name).

### Background — stays Islet's existing chrome (NEW, explicit decision)
- **D-12 (new):** The Weather tab keeps Islet's existing black/frosted glass chrome (the same material every other tab — Home/Tray/Calendar — uses), NOT Apple's own per-widget navy/time-of-day gradient background seen in `33.png`/`34.png`. Explicit user decision: replicating Apple's dynamic gradient card would introduce a new per-tab visual special case; only the widget's *content layout* (header, hourly row, daily list) is being cloned, not its background treatment.

### Claude's Discretion
- Exact hourly chip count (D-07) and exact daily row count for Large (D-09) — pick whichever counts fit cleanly given real dimensions once built.
- Whether the hourly fetch is folded into the existing combined WeatherKit call or issued separately — follow the "one call" discipline already established in Plan 33-01 unless research finds a reason not to.
- Whether `weatherExtendedKey`'s storage is migrated to a String/enum or a new key is introduced alongside it — whichever keeps the Bool→enum migration cleanest for existing users defaulting to Medium. (Already resolved in Tasks 1-3: migrated to `ActivitySettings.WeatherStyle`/`weatherStyleKey`.)
- Exact gradient/color treatment of the range bar — match the spirit of Apple's bar (color scales with temperature, positioned within the list's min/max) without needing pixel-exact color stops. (Already resolved in Task 2: 5-stop blue→mint→yellow→orange→red via `NSColor.blended`.)
- Exact reverse-geocode granularity (city only vs. city+region) — no strong user preference expressed.
- The real widget's hourly row includes a non-hour-aligned sunrise-timestamp entry (e.g. "04:56") inserted between hourly points — explicitly OUT of scope to replicate; use plain on-the-hour `.hourly` dataset entries only, no separate sunrise-event fetch/interleave.
- The "Vorhersage" title+description text visible below the widget in `34.png` is macOS's widget-gallery caption chrome, not part of the widget itself — do not replicate.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Weather widget visual reference (THE authoritative reference — supersedes the PROJECT.md text description)
- `.planning/research/inspiration/33.png` — macOS Weather.app "Standard" (Medium) widget, screenshotted directly by the user from their own Mac (Neubrandenburg). Ground truth for D-06, D-07, and D-11 (header two-column layout).
- `.planning/research/inspiration/34.png` — macOS Weather.app "Extended" (Large) widget, same source. Ground truth for D-08 through D-11.
- `.planning/research/inspiration/32.png` — earlier-captured reference (originally mislabeled "iOS-only"), confirmed structurally identical to `33.png`/`34.png` — still valid as a secondary reference, not superseded in content, only in labeling.
- `.planning/research/inspiration/notes.md` §"Weather widget reference (images 32-34, revised...)" — written description of what each screenshot shows, including the second-round header-layout correction (D-11) and the background decision (D-12).

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

### Existing code — Plan 33-02 Tasks 1-3 (view+controller layer, committed `326b0ca`/`e8d36cf`/`63fbac4` — hourly row + Large daily list CORRECT, header WRONG)
- `Islet/Notch/NotchPillView.swift` — `weatherMediumContentHeight`/`weatherLargeContentHeight` constants (correct, keep), `hourlyForecastRow(_:)` (correct, keep), `dailyForecastList(_:)`/`dailyForecastRow(_:overallLow:span:)`/`temperatureColor(fraction:)` (correct, keep) — `weatherFullContent(_:)` (WRONG per D-11, rework from centered VStack to two-column HStack; the field-level content — location/fallback text, icon, temp, condition label, H/L string — is reused as-is, only the container layout changes)
- `Islet/Notch/NotchWindowController.swift` — `refreshWeather()`'s 3-value completion, `positionAndShow`'s `weatherExpandedFrame` reservation, `visibleContentZone()`'s unconditional `.weatherExpanded` branch — all correct, no rework needed (D-11's header change is view-only, doesn't affect panel geometry sizing)
- `Islet/SettingsView.swift` — Medium/Large segmented Picker — correct, keep
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
- Plan 33-02's already-correct hourly row and Large daily-list work (Tasks 2, commits `e8d36cf`) — keep as-is, do not rebuild. Only `weatherFullContent`'s layout container needs rework per D-11; its field-level rendering logic (location text, icon, temp string, condition label, H/L string) is reused as-is inside the new two-column layout.

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

- **`.planning/research/inspiration/33.png`/`34.png`** — real macOS Weather.app widget screenshots (Standard/Extended), the exact and authoritative visual reference for D-06 through D-11. Genuine screenshots, not text paraphrases — trust their exact structure over any earlier text description.
- User's framing this round: "ich will 1:1 das widget von der Kalender app dort drin haben und es nicht selbst gebaut haben, das wurde bisher falsch verstanden" — clarified via follow-up questions to mean: (1) a pixel-faithful recreation is fine (literally embedding a live system widget isn't possible via public macOS API), and (2) the reference app is Weather.app specifically, not Calendar.app (the user's informal naming). Intent: match the real widget exactly, not a loose reinterpretation — same underlying goal as the first round's framing, this round caught a header-layout detail the first round's reference (`32.png`) also showed but wasn't fully translated into the built code.
- User's framing at the first-round checkpoint: "Droppy hat diese 1:1 Wetter app widget. Genau sowas wollte ich nachbauen" — the intent is a faithful 1:1 clone of Apple's own widget shapes.
- Confirmed explicitly (first round): no "Compact-only" state should remain selectable — "Ja ganz weg von Compact, einfach nur diese beiden Medium und Large Widgets... wovon Medium standard ist."
- Confirmed explicitly (this round): keep Islet's own black/frosted glass chrome for the Weather tab rather than adopting Apple's per-widget gradient background (D-12).

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope; this revision is a correction of the original scope's forecast-row misunderstanding, not new scope.

</deferred>

---

*Phase: 33-weather-widget-redesign*
*Context gathered: 2026-07-15 (revised same day after Plan 33-02 checkpoint feedback)*
