# Phase 14: Basic Outfit — Weather + Calendar + Date Display - Context

**Gathered:** 2026-07-08
**Status:** Ready for planning

<domain>
## Phase Boundary

Enrich the existing **`expandedIdle` presentation** in `NotchPillView.swift` (currently
just `Text(Date.now, format: .dateTime.hour().minute())` in the 360×144pt black blob,
D-11) with weather (icon + temperature), the date, and the next relevant calendar event
(today's next upcoming event, or tomorrow's first event if none today, or nothing if
neither) — arranged in the reference-image 3-column layout (weather left · time+date
center · calendar right). The weather icon itself animates per condition category
(sunny/cloudy/rain/snow); the black bubble background and app-wide black aesthetic are
**unchanged** — this phase touches ONLY the `expandedIdle` case, no other presentation
(wings, media, charging, device).

**Reversal note:** `PROJECT.md`'s "Out of Scope" section previously listed "calendar/weather
glance ... deferred until the core island is solid" — that condition is now met (v1.1 is
closing with Phase 13); this phase formally un-defers it. `PROJECT.md`'s Out of Scope /
Active sections should be updated to reflect this at the next evolution/transition pass
(not a Phase 14 build task).

Out of scope: any change to charging/media/device wings or the collapsed idle pill;
weather/calendar in any view besides `expandedIdle`; background color/gradient changes
(only the icon animates, per decision below); notification/messaging mirroring, FaceTime
integration (still explicitly out of scope per PROJECT.md).

</domain>

<decisions>
## Implementation Decisions

### Weather location (D-01)
- **D-01:** **Automatic device location.** One-time macOS location-permission prompt;
  thereafter weather loads for the current location automatically (mirrors the reference
  app). If the user denies the permission, the weather element is simply omitted — no
  begging dialog, no retry loop. Time/date/calendar continue working normally.

### Calendar source & scope (D-02)
- **D-02:** **All active macOS calendars.** EventKit access covers every calendar the
  system Calendar app shows (iCloud, Google, subscribed, etc.) — no per-calendar filter
  in Settings for this phase.

### Calendar permission denial (D-03)
- **D-03:** **Silent omission.** If Calendar access is denied, the calendar column is
  simply blank/hidden — no error banner, no link to System Settings, no crash. Same
  graceful-degradation posture as D-01's weather-denied case.

### Which event is shown (D-04)
- **D-04:** **Next upcoming (or in-progress) event.** Not a fixed "first event of the
  day" — the shown event advances live through the day as events pass. If no event
  remains today, show tomorrow's first event instead; if neither exists, show nothing
  (blank calendar column, per the phase's original ask).

### Weather-driven animation scope (D-05)
- **D-05:** **Icon-only animation.** The black bubble background stays exactly as it is
  everywhere else in the app (D-01/D-08 idle-invisible, pure-black aesthetic) — only the
  weather icon itself animates per condition (e.g., falling raindrops, pulsing sun rays,
  drifting clouds). No background tint/gradient shift. Keeps this phase visually
  consistent with the rest of the app rather than introducing a second visual language.

### Weather category count (D-06)
- **D-06:** **4 categories:** Sunny, Cloudy, Rain, Snow. Each condition from the weather
  API maps down to one of these four for icon + animation selection — finer distinctions
  (thunderstorm, fog, etc.) are not built in this phase.

### Layout (D-07)
- **D-07:** **3-column layout matching the reference image**, adapted to the narrower
  360pt bubble width: weather icon + temperature on the LEFT, time (large) + date
  (smaller, below) CENTERED, calendar event (with a "Today"/"Tomorrow" label) on the
  RIGHT. Mirrors the existing wings' left-content/right-content framing pattern already
  used elsewhere in `NotchPillView.swift` (e.g., `wings(for:)`, `deviceWings(for:)`).

### Claude's Discretion
- Weather API/SDK choice (e.g., Apple WeatherKit — covered under the existing paid
  Developer Program's free tier — vs. a free keyless API like Open-Meteo). Research
  should confirm which fits the "no paid services beyond the Developer account" budget
  constraint (CLAUDE.md) and the "isolate fragile externals behind one protocol" pattern
  already established for `NowPlayingService`/`LicenseService`.
- Exact icon animation implementation (SF Symbols variable-color/animated symbols vs.
  hand-built `TimelineView` animations, mirroring `EqualizerBars`' idle-CPU-gated clock
  discipline — D-04/Pitfall 5 precedent: no animation may run when off-screen/idle).
- Exact EventKit query shape (event store setup, calendar authorization request timing —
  likely mirrors the Bluetooth/location permission-request patterns already in the app).
- Precise spacing/sizing within the fixed 360×144 `expandedSize` — the 3 columns must fit
  without crowding the physical camera/notch clearance band (existing 32pt top-clearance
  constraint from `mediaExpanded`/`expandedIsland`).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### The view this phase extends
- `Islet/Notch/NotchPillView.swift` — the `expandedIdle` case (line ~137) and its backing
  `expandedIsland` computed view (line ~182) are what this phase replaces/extends. Study
  the existing `wingsShape`/`wings(for:)`/`deviceWings(for:)` helpers as the established
  left-content/right-content layout pattern to mirror for the new 3-column layout.
- `Islet/Notch/NotchPillView.swift`'s `EqualizerBars` struct (line ~500) — the idle-CPU-safe
  `TimelineView(.animation(paused:))` animation-gating pattern (D-04/Pitfall 5) that any new
  weather-icon animation MUST follow — no animation clock may run when not needed.

### Protocol-isolation precedent (pattern to mirror for weather/calendar)
- `Islet/Licensing/LicenseService.swift` and the `NowPlayingService`/`NowPlayingMonitor`
  pair — the established "isolate fragile externals behind one protocol" pattern
  (mentioned repeatedly across Phase 4/11/12 CONTEXT.md files). A new `WeatherService`
  and `CalendarService`-style seam should follow the same shape.

### Requirements & roadmap
- `.planning/ROADMAP.md` §Phase 14 — phase stub (goal/requirements to be filled by
  `/gsd-plan-phase 14`, informed by this CONTEXT.md).
- `.planning/PROJECT.md` §Out of Scope — the "calendar/weather glance ... deferred" line
  this phase formally un-defers (see Reversal note in `<domain>` above); §Constraints
  (Budget: hobby/personal, no paid services beyond the Developer account) constrains the
  weather-API choice.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `NotchPillView.wingsShape(content:)` helper — the shared NotchShape/fill/
  matchedGeometryEffect/frame skeleton; while `expandedIdle` uses the taller
  `expandedIsland` blob shape (not `wingsShape`), the LEFT/`Spacer()`/RIGHT `HStack`
  content-composition pattern from `wings(for:)`/`deviceWings(for:)` is directly
  reusable for the new 3-column content.
- `BatteryIndicator`, `EqualizerBars` — existing small presentational components in the
  same file, useful precedent for how a small animated glyph component is structured.

### Established Patterns
- Single `@ObservedObject` published state models feed the view (`NowPlayingState`,
  `IslandPresentationState`) — a new `WeatherState`/`CalendarState` (or a combined
  `BasicOutfitState`) should follow the same `ObservableObject` + controller-owns-instance
  shape already used throughout.
- The controller (`NotchWindowController`) owns monitors/services and injects state into
  the view — never the view fetching data directly. Weather/Calendar fetching should live
  in a controller-owned service, not inside `NotchPillView`.
- Idle-CPU discipline (D-04/Pitfall 5): any animation must gate its clock off entirely
  when not visible/needed — verified via `sample`/Energy on-device, per `EqualizerBars`'
  and `ProgressBar`'s established precedent.

### Integration Points
- `expandedIdle` case in the `switch presentation` (line ~137) is the sole render
  entry point this phase changes.
- A new weather/calendar fetch service would be owned by `NotchWindowController` (mirrors
  `NowPlayingMonitor`/`BluetoothMonitor`/`LicenseManager` ownership) and would need new
  Info.plist usage-description keys (location, calendar) analogous to the existing
  `NSBluetoothAlwaysUsageDescription` requirement discovered in Phase 6 (project memory:
  A1 Bluetooth usage key).

</code_context>

<specifics>
## Specific Ideas

- Reference image (user-provided screenshot): a lock-screen-style widget with a
  rain-cloud icon + temperature on the left, a large time + date in the center, and a
  "Today" event card with a colored dot + title + time range on the right. This phase
  reproduces that column arrangement inside Islet's existing black expanded bubble,
  narrower (360pt vs. the reference's much wider card) — exact spacing is Claude's
  discretion (see above).
- The animated background language ("sonnig aussehen lassen oder regnend wolkig") was
  clarified to mean the ICON animates (rain falling, sun pulsing, clouds drifting), not
  the black bubble's background color/gradient — see D-05.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within the weather/calendar/date scope of this phase. (Messaging
mirroring, FaceTime, and other DynamicLake-style extras remain out of scope per
PROJECT.md.)

</deferred>

---

*Phase: 14-basic-outfit-weather-calendar-date-display-with-weather-driv*
*Context gathered: 2026-07-08*
