# Phase 33: Weather Widget Redesign - Research

**Researched:** 2026-07-15
**Domain:** WeatherKit combined-fetch API, CoreLocation reverse-geocoding, SwiftUI settings-gated layout switching, panel-frame/click-through geometry (native macOS Swift/SwiftUI/AppKit)
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

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
- Whether the new WeatherKit forecast call is a fully separate `fetchDailyForecast` method or an extension of `fetchCurrent`'s signature — architecture research (see canonical refs) already recommends a separate method; follow that unless research turns up a reason not to. **Research finding: use the combined `weather(for:including: .current, .daily)` single call (see Pattern 1) — the phase description itself mandates this, and it also resolves Pitfall 1/5 (doubled quota).**
- Exact reverse-geocode granularity (city only vs. city+region) — pick whichever `CLPlacemark` field reads most naturally in a narrow widget card; no strong user preference expressed. **Research recommendation: `CLPlacemark.locality` (see Assumption A2).**

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope. (The one weakly-matched pending todo, "Tray panel oversized vertically, shrink to fit content," is about Tray/Phase 32 and was not folded here — it appears already resolved by Phase 32's `trayContentHeight` shrink work; flagged for todo-list cleanup rather than carried into this phase.)
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| WEATHER-01 | Weather tab shows a compact iOS-widget-style card by default — location, condition icon, current temperature, high/low | Pattern 1 (combined WeatherKit call supplies H/L for the compact card at no extra quota cost); Code Examples (`WeatherGlance` extended with `high`/`low`); Pitfall 3 + Code Examples (reverse-geocode with "Local" fallback, D-01/D-02) |
| WEATHER-02 | A Settings toggle switches Weather to an extended widget adding a multi-day forecast row (day, icon, temp) | Code Examples (Settings toggle wiring, mirrors `ActivitySettings.materialStyleKey`); Pattern 2/3 (dedicated height constant + panel-frame/click-through updates, D-03); Pitfall 4 (CR-01-class geometry-divergence risk); Pitfall 2 (atomic current+forecast delivery avoids partial-render pop-in) |
</phase_requirements>

## Summary

This phase extends an already-shipped, working feature (`WeatherService`/`WeatherKitService`/`weatherFullView`, Phase 14/28) rather than building anything from scratch. The exact WeatherKit combined-call API needed (`weather(for:including:_:)` returning `(CurrentWeather, Forecast<DayWeather>)`) was confirmed directly against the installed macOS SDK's Swift interface (not training data, not WebSearch) — HIGH confidence. `DayWeather` already carries every field the forecast-chip design needs (`date`, `condition`, `symbolName`, `highTemperature`, `lowTemperature`) with no additional model design required beyond a thin `DailyForecast` wrapper.

The two genuinely new risks are architectural, not API-shaped: (1) CONTEXT.md's D-03 decision — a dedicated Weather height constant taller than the shared `switcherContentHeight` (196pt) box — requires touching the exact same three call sites Phase 32's `trayContentHeight` touched (`NotchPillView.blobShape`'s `height:` override, `NotchWindowController.positionAndShow`'s panel-frame union, and `visibleContentZone()`'s click-through math), and this project has twice shipped bugs (CR-01, WR-02) from exactly this render-geometry/hit-test-geometry divergence — the plan must update all three in one commit. (2) The combined single-call fetch must replace `fetchCurrent`'s network call, not run alongside it, or the phase silently doubles WeatherKit quota usage per refresh cycle (flagged as Pitfall 5 in prior v1.5 research, and independently confirmed by direct source read of `refreshWeather()`'s 15-minute timer).

**Primary recommendation:** Extend `WeatherService` with one new method — `fetchCurrentAndForecast(latitude:longitude:completion:)` — backed by a single `weather(for:location, including: .current, .daily)` call, gated by the extended-forecast `@AppStorage` toggle exactly like `ActivitySettings.materialStyleKey`. Give Weather its own `weatherExtendedContentHeight` constant following `trayContentHeight`'s precedent verbatim, and update `blobShape`'s `height:` override, `positionAndShow`'s panel union, and `visibleContentZone()`'s `.weatherExpanded` branch together, in the same task.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Combined current+daily WeatherKit fetch | API/Backend-equivalent (`WeatherKitService`, the app's own "backend" seam) | — | Isolated behind the existing `WeatherService` protocol per project convention ("fragile external behind one seam") |
| Reverse-geocode location name | API/Backend-equivalent (`LocationProvider`/new geocode step) | — | Runs off the existing `CLLocation`, no UI-tier concern |
| Compact/extended layout switch | Client (SwiftUI `NotchPillView`) | — | Pure rendering-value branch on an `@AppStorage` bool, no business logic |
| Settings toggle persistence | Client (`@AppStorage`/`UserDefaults`) | — | App-owned preference, not a system-owned setting (mirrors `ActivitySettings` doc comment) |
| Panel-frame / click-through sizing | Client (AppKit `NSPanel`, `NotchWindowController`) | — | Must move in lockstep with the SwiftUI content height per Anti-Pattern 1 (CR-01/WR-02 precedent) |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| WeatherKit | Ships with macOS 15 SDK (installed: macOS 26.x SDK, deployment target 15.0) | Combined current+daily weather fetch | Already the project's chosen weather source (Phase 14); `weather(for:including:_:)` is Apple's own documented multi-dataset-in-one-request API |
| CoreLocation (`CLGeocoder`) | Ships with SDK | Reverse-geocode `CLLocation` → place name | Already linked (Phase 14 `LocationProvider`); no new dependency |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| SwiftUI `@AppStorage` | Ships with SDK | Persist + live-observe the extended-forecast toggle | Exact precedent: `ActivitySettings.materialStyleKey` |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `CLGeocoder.reverseGeocodeLocation` | `MKReverseGeocodingRequest` (MapKit) | `MKReverseGeocodingRequest` is `CLGeocoder`'s Apple-designated replacement, but per the installed SDK header it only became available at the same macOS version that deprecated `CLGeocoder` (macOS 26.0) — see Pitfall 3 below. Islet's deployment target is 15.0, so adopting it now would require an `if #available(macOS 26.0, *)` branch purely to silence a deprecation warning. Not worth the complexity for a first-time-programmer codebase; use `CLGeocoder` and accept the warning. |
| Two separate WeatherKit calls (`fetchCurrent` + a new `fetchForecast`) | One combined `weather(for:including: .current, .daily)` call | The phase description itself already mandates the combined call; two calls would double quota use per refresh cycle for zero benefit (Pitfall 1 below) |

**Installation:** No new packages. Both frameworks (`WeatherKit`, `CoreLocation`) are already imported in `Islet/Weather/WeatherService.swift` and `Islet/Location/LocationProvider.swift`.

**Version verification:** Confirmed directly against the installed SDK (`/Applications/Xcode.app/.../MacOSX.sdk/.../WeatherKit.swiftmodule/arm64e-apple-macos.swiftinterface`) — see Code Examples for the exact extracted signatures. This is the ground-truth source for this project's actual build environment, stronger than Context7/WebSearch for this claim.

## Package Legitimacy Audit

Not applicable — this phase adds zero third-party/external packages. Both APIs used (`WeatherKit.WeatherService`, `CoreLocation.CLGeocoder`) are first-party Apple frameworks already linked in the project.

## Architecture Patterns

### System Architecture Diagram

```
Settings toggle (weatherExtendedKey, @AppStorage)
        |
        v
UserDefaults.didChangeNotification -> NotchWindowController.handleSettingsChanged()
        |
        v
NotchWindowController.refreshWeather()
        |
        +-- always --> WeatherKitService.fetchCurrentAndForecast(lat, lon) { current, forecast in
        |                    (ONE combined weather(for:including: .current, .daily) call)
        |                    -> BasicOutfitState.weather   (current + H/L, always populated)
        |                    -> BasicOutfitState.forecast  (only meaningfully read when extended toggle is on)
        |              }
        |
        v
NotchPillView.weatherFullView
        |
        +-- reads @AppStorage(weatherExtendedKey) --> branch:
        |         false -> weatherFullContent(weather)                 [compact card]
        |         true  -> weatherFullContent(weather) + forecastRow(forecast)  [extended card]
        |
        v
blobShape(height: extended ? weatherExtendedContentHeight : nil)
        |
        v
NotchWindowController.positionAndShow  (panel-frame union MUST include weatherExtendedContentHeight)
NotchWindowController.visibleContentZone()  (.weatherExpanded branch MUST match, or clicks miss — CR-01 class bug)
```

### Recommended Project Structure

No new files needed — every change lands in existing files:
```
Islet/Weather/WeatherService.swift   # + DailyForecast model, + fetchCurrentAndForecast method
Islet/Notch/BasicOutfitState.swift   # + forecast field
Islet/Notch/NotchWindowController.swift  # refreshWeather() rewired, positionAndShow union, visibleContentZone() branch
Islet/Notch/NotchPillView.swift      # weatherFullContent extended, forecastRow view, weatherExtendedContentHeight constant
Islet/ActivitySettings.swift         # + weatherExtendedKey
Islet/SettingsView.swift             # + Toggle in generalSection's Activities-style pattern (new "Weather" Section)
```

### Pattern 1: Combined WeatherKit fetch, one call, tuple return

**What:** `weather(for:including:_:)` with two `WeatherQuery` values returns a typed tuple `(T1, T2)` in a single network request.
**When to use:** Any time two or more WeatherKit datasets are needed together — this is Apple's own supported multi-fetch API, not a workaround.
**Example (verified against installed SDK, `WeatherKit.swiftinterface` lines 1006-1014):**
```swift
// Extracted signature (HIGH confidence — read directly from the installed macOS SDK's
// WeatherKit.swiftmodule/arm64e-apple-macos.swiftinterface, not training data):
//   @preconcurrency final public func weather<T1, T2>(
//       for location: CLLocation,
//       including dataSet1: WeatherQuery<T1>,
//       _ dataSet2: WeatherQuery<T2>
//   ) async throws -> (T1, T2) where T1: Sendable, T2: Sendable
//
//   public static var current: WeatherQuery<CurrentWeather> { get }
//   public static var daily: WeatherQuery<Forecast<DayWeather>> { get }

func fetchCurrentAndForecast(latitude: Double, longitude: Double,
                              completion: @escaping (WeatherGlance?, [DailyForecast]?) -> Void) {
    Task {
        do {
            let location = CLLocation(latitude: latitude, longitude: longitude)
            let (current, daily) = try await service.weather(for: location, including: .current, .daily)
            let today = daily.first   // Forecast<DayWeather> is a RandomAccessCollection; .first is "today"
            let glance = WeatherGlance(category: WeatherCategory.from(current.condition),
                                        temperature: current.temperature,
                                        high: today?.highTemperature,
                                        low: today?.lowTemperature)
            let forecast = daily.map { day in
                DailyForecast(date: day.date,
                              category: WeatherCategory.from(day.condition),
                              high: day.highTemperature,
                              low: day.lowTemperature)
            }
            await MainActor.run { completion(glance, forecast) }
        } catch {
            await MainActor.run { completion(nil, nil) }   // D-01: silent omission, no retry
        }
    }
}
```

### Pattern 2: Dedicated height constant winning over the shared switcher box (Phase 32 precedent, applies verbatim to Weather)

**What:** `blobShape`'s `height:` parameter, when explicitly passed, wins over the `showSwitcher` default (`Self.switcherContentHeight`) — this reordering already shipped in Phase 32 specifically so a caller-supplied override works.
**When to use:** Any presentation whose content is genuinely taller (or shorter) than the shared 196pt box — Weather-extended is taller, exactly like Tray was shorter.
**Example (existing code, `NotchPillView.swift` ~1188, already generalized — no change needed to `blobShape` itself):**
```swift
let baseHeight = height ?? (showSwitcher ? Self.switcherContentHeight : Self.expandedSize.height)
```
Weather's call site then becomes, mirroring `trayFullView`'s `height: Self.trayContentHeight`:
```swift
blobShape(topCornerRadius: 24, bottomCornerRadius: 32, alignment: .top,
          height: weatherExtended ? Self.weatherExtendedContentHeight : nil,
          shelfItems: shelfViewState.items, shelfVisible: shelfStripVisible, showSwitcher: true) {
    weatherFullContent(weather, forecast: weatherExtended ? outfit.forecast : nil)
}
```

### Pattern 3: Panel-frame union + click-through zone MUST be updated together (Anti-Pattern 1 from ARCHITECTURE.md, this project's own two-time-repeated bug class)

**What:** Every `blobShape` height/width override needs a matching `expandedNotchFrame(...)` union member in `positionAndShow` AND a matching branch in `visibleContentZone()`. Tray's `trayFrame`/`.trayExpanded` branch (added Phase 32) is the exact template to copy for Weather.
**When to use:** Any time Weather's extended state is taller than `switcherContentHeight`.
**Example (existing code, `NotchWindowController.swift` 807-815, to be mirrored for Weather):**
```swift
// positionAndShow — add a 4th union member alongside expandedFrame/wings/onboardingFrame/trayFrame:
let weatherExtendedFrame = expandedNotchFrame(collapsed: collapsedFrame,
                                              expandedSize: CGSize(width: expandedSize.width,
                                                                    height: NotchPillView.weatherExtendedContentHeight
                                                                          + NotchPillView.switcherRowHeight))
let panelFrame = expandedFrame.union(wings).union(onboardingFrame).union(trayFrame).union(weatherExtendedFrame)
```
```swift
// visibleContentZone() — add a branch keyed off the toggle AND the .weatherExpanded case
// (IslandResolver.swift already has this case — see Integration Points below):
} else if case .weatherExpanded = presentationState.presentation, weatherExtendedEnabled {
    contentSize = CGSize(width: expandedSize.width,
                         height: NotchPillView.weatherExtendedContentHeight + switcherHeight)
}
```

### Anti-Patterns to Avoid
- **Two independent WeatherKit calls (`fetchCurrent` unchanged + a new parallel `fetchForecast`):** doubles quota per refresh cycle and duplicates the D-01 silent-failure contract across two independently-erroring async paths. Use the single combined call (Pattern 1).
- **Updating `blobShape`'s height override without updating `positionAndShow`/`visibleContentZone()` in the same commit:** this is the exact CR-01 (Phase 20)/WR-02 (Phase 28) failure class — a drawn/hit-tested geometry mismatch either swallows clicks or makes content unclickable. All three sites move together (Pattern 3).
- **Re-deciding "is Weather extended" inside `NotchPillView` via a fresh precedence check instead of a single `@AppStorage` read shared with `NotchWindowController`:** keep exactly one source of truth for the toggle value (the `@AppStorage`/`UserDefaults` key), read identically in both the view (for rendering) and the controller (for panel-frame math and fetch-gating) — do not let the two drift.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Multi-day forecast data fetch | A custom REST client against some weather API | `WeatherKit.WeatherService.weather(for:including: .daily)` | Already the project's chosen provider; `Forecast<DayWeather>` gives every field needed (date, condition, symbolName, high/low) with zero parsing code |
| Live settings-toggle observation | A new NotificationCenter post/observe pair for the weather toggle specifically | The existing `UserDefaults.didChangeNotification` → `handleSettingsChanged()` pipeline already wired in `NotchWindowController.start()` | One shared observer already re-applies every `@AppStorage`-backed setting live; a new key needs zero new wiring, only a new branch inside `handleSettingsChanged()` if immediate action (an on-flip forecast fetch) is desired |
| Reverse geocoding | A custom lat/lon → city-name lookup table or 3rd-party geocoding API | `CLGeocoder.reverseGeocodeLocation(_:completionHandler:)` | First-party, already-linked framework; the `CLLocation` is already in hand from `LocationProvider` — no new permission, no new network dependency |

**Key insight:** Every piece of this phase is an *extension* of an existing, working seam (`WeatherService`, `ActivitySettings`, `blobShape`, `LocationProvider`) — the discipline is additive-parameter-with-safe-default at each seam, exactly as Phase 25 (flare-precedent narrative) and Phase 32 (`trayContentHeight`) already proved out in this codebase. No new architectural pattern needs inventing.

## Common Pitfalls

### Pitfall 1: Two independent WeatherKit calls instead of one combined call
**What goes wrong:** Adding a new `fetchForecast(...)` method that makes its own `weather(for:)` call alongside the untouched `fetchCurrent(...)` doubles WeatherKit quota usage on every 15-minute refresh cycle.
**Why it happens:** Extending `fetchCurrent`'s signature looks like a breaking change; a parallel method looks like a smaller, safer diff. It's the opposite: `weather(for:including:_:)` supports multiple datasets in one request natively.
**How to avoid:** Build `fetchCurrentAndForecast(...)` using `weather(for: location, including: .current, .daily)` (Pattern 1). If `fetchCurrent`'s existing single-value signature is still called elsewhere, have it delegate internally rather than issuing a second network request.
**Warning signs:** Code review finding two separate `service.weather(for:)` call sites inside the refresh path.
**Source:** `.planning/research/PITFALLS.md` Pitfall 5 (v1.5 research), confirmed against this project's actual `refreshWeather()`/`startOutfitRefresh()` 15-minute-timer code.

### Pitfall 2: Forecast strip pops in a beat after the rest of the card (partial-render window)
**What goes wrong:** If current-conditions and forecast data arrive on different timelines (e.g. a stale cached `outfitState.weather` renders immediately while a freshly-triggered forecast fetch is still in flight), the extended widget's forecast row visibly pops in after the rest of the card — janky for a small, information-dense widget.
**Why it happens:** `WeatherGlance`/`outfitState.weather` has no loading/partial state today — it's `nil` or fully populated. Bolting `forecast` onto the same all-or-nothing model without a loading placeholder is the easy path.
**How to avoid:** The combined call (Pattern 1) delivers `current` and `daily` atomically in one completion, so this mostly resolves itself IF `refreshWeather()` writes both `outfit.weather` and `outfit.forecast` from the same completion callback, not two separate ones. Do not fetch forecast from a separate trigger (e.g. tab-select) independent of the main refresh cycle.
**Warning signs:** On-device UAT: toggle the extended setting on right after launch (before the timer's first tick) and watch for the forecast row appearing a beat after the rest of the card.
**Source:** `.planning/research/PITFALLS.md` Pitfall 6.

### Pitfall 3: `CLGeocoder.reverseGeocodeLocation` is deprecated as of macOS 26.0 — but its replacement isn't usable at this project's deployment target
**What goes wrong:** The installed SDK marks both `reverseGeocodeLocation` overloads `API_DEPRECATED(..., macos(10.8, 26.0))` / `macos(10.13, 26.0)`, in favor of `MKReverseGeocodingRequest` (MapKit). A plan that reflexively "uses the modern API" would reach for `MKReverseGeocodingRequest`.
**Why it happens:** Deprecation warnings read as "stop using this," and the build machine itself runs macOS 26 (Tahoe) — see project memory `build-machine-macos26-toolchain` — so the warning will actually surface during local builds.
**How to avoid:** `MKReverseGeocodingRequest` requires macOS 26.0+ per the same SDK (it was introduced at the version that deprecated `CLGeocoder`'s method); Islet's deployment target is 15.0 (Phase 26 decision). Adopting it now means either bumping the deployment target again (out of scope, no user request) or `if #available` branching purely to silence one warning. Use `CLGeocoder.reverseGeocodeLocation(_:completionHandler:)` as-is; the deprecation warning is cosmetic and safe to ignore at this deployment target. Revisit only if/when the deployment floor is raised to 26.0.
**Warning signs:** A build-warning triage that treats every deprecation as blocking, or a plan task that silently swaps in `MKReverseGeocodingRequest` without checking its availability floor.
**Source:** VERIFIED directly against installed SDK headers — `CoreLocation.framework/Headers/CLGeocoder.h` line 33-34, `MapKit.framework/Headers/MKReverseGeocodingRequest.h`.

### Pitfall 4: A new `blobShape` height override shipped without the matching `positionAndShow`/`visibleContentZone()` updates
**What goes wrong:** The visible black shape grows to the new height but the transparent panel window (and/or the click-through hit-test rect) doesn't — either the extended forecast row clips off the bottom edge (panel too small), or clicks on the new taller area fall through to whatever's underneath (hit-test rect too small).
**Why it happens:** `blobShape`'s content height, the panel's own frame, and `visibleContentZone()`'s click-acceptance rect are three independently-maintained values that must agree — this project has hit this exact bug class twice already (CR-01 Phase 20, WR-02 Phase 28 review) and a third time narrowly avoided (Phase 32 Pitfall 2/3 in its own research).
**How to avoid:** Pattern 3 above — update `blobShape`'s call site, `positionAndShow`'s union, and `visibleContentZone()`'s branch in the same task/commit, and re-run the on-device hover→expand→click trace this project already uses for CR-01-class verification.
**Warning signs:** Extended forecast row visibly clipped at the bottom edge on-device (panel too small); or clicking within the forecast row area (but below the compact card) does nothing / collapses the island (hit-test too small).
**Source:** Direct read of `NotchWindowController.swift` `positionAndShow`/`visibleContentZone()`, cross-referenced with `.planning/research/ARCHITECTURE.md` Anti-Pattern 1 and this project's own `cr01-clickthrough-or-defeat-gotcha` memory entry.

## Code Examples

### `DailyForecast` model (new, additive)
```swift
// Mirrors WeatherGlance's existing Equatable, Measurement<UnitTemperature>-based convention —
// no manual unit conversion, locale-aware formatting happens at the render layer.
struct DailyForecast: Equatable, Identifiable {
    var id: Date { date }
    let date: Date
    let category: WeatherCategory
    let high: Measurement<UnitTemperature>
    let low: Measurement<UnitTemperature>
}
```

### `WeatherGlance` extended with H/L (needed even for the compact card per CONTEXT.md's reference layout)
```swift
struct WeatherGlance: Equatable {
    let category: WeatherCategory
    let temperature: Measurement<UnitTemperature>
    let high: Measurement<UnitTemperature>?   // nil only if `daily.first` was somehow empty
    let low: Measurement<UnitTemperature>?
}
```

### Reverse-geocode with the "Local" placeholder fallback (D-01/D-02)
```swift
// Source: CoreLocation.framework/Headers/CLGeocoder.h (installed SDK, deprecated-but-functional
// per Pitfall 3 above). Runs off the SAME CLLocation LocationProvider already obtained —
// no new permission ask, no new fetch trigger.
private let geocoder = CLGeocoder()

func resolvePlaceName(for location: CLLocation, completion: @escaping (String?) -> Void) {
    geocoder.reverseGeocodeLocation(location) { placemarks, error in
        // D-01/D-02 convention: any error, or an empty/nil locality, settles "Local" —
        // never a blank field, never an error string, never a retry.
        let name = placemarks?.first?.locality
        DispatchQueue.main.async { completion(name) }   // completion contract: always main thread
    }
}
```

### Settings toggle wiring (mirrors `ActivitySettings.materialStyleKey` exactly)
```swift
// ActivitySettings.swift
static let weatherExtendedKey = "weather.extended"

// SettingsView.swift, inside generalSection's Form, a new Section alongside "Activities":
@AppStorage(ActivitySettings.weatherExtendedKey) private var weatherExtended = false
...
Section("Weather") {
    Toggle("Extended forecast", isOn: $weatherExtended)
}

// NotchPillView.swift — read the SAME key for rendering:
@AppStorage(ActivitySettings.weatherExtendedKey) private var weatherExtended = false
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|---------------|--------|
| `fetchCurrent` — single-dataset `weather(for:)` call, category+temperature only | `fetchCurrentAndForecast` — combined `weather(for:including: .current, .daily)`, one network request, richer `WeatherGlance` (+H/L) and new `[DailyForecast]` | This phase | Compact card gains H/L "for free" from the same call the extended toggle needs; no quota increase for compact-only users versus today (still one call per refresh) |
| `CLGeocoder.reverseGeocodeLocation` | Still current for this project's deployment target; Apple's replacement (`MKReverseGeocodingRequest`) requires macOS 26.0+ | Deprecation surfaced macOS 26.0 (2026), replacement not adoptable at Islet's 15.0 floor | Expect a (harmless) deprecation warning in the build log; do not "fix" it by bumping deployment target or availability-branching without a separate user decision |

**Deprecated/outdated:**
- `CLGeocoder.reverseGeocodeLocation` is Apple-deprecated as of macOS 26.0 but remains fully functional and is the correct choice at this project's 15.0 deployment target (see Pitfall 3).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Exact forecast day count (4 vs 5) that fits the 420pt panel width cleanly — left to Claude's discretion per CONTEXT.md, no chip-width measurement done in this research pass (would require on-device font-metric measurement, not something a documentation-lookup research pass can determine) | Common Pitfalls / D-05 (CONTEXT.md) | Low — CONTEXT.md already frames this as "pick whichever count fits cleanly," explicitly not a hard-locked number; the planner/executor resolves it with an on-device check, same as Tray's own width iterations (Phase 32, 3 on-device rounds) |
| A2 | `CLPlacemark.locality` (city name) is the right granularity for D-01/reverse-geocode, vs. `.name` or `.subLocality` — CONTEXT.md leaves this to discretion; this research picked `.locality` because it reads most naturally in a narrow widget card ("Cupertino" not "Apple Inc." or a neighborhood name), but this is a judgment call, not a verified requirement | Code Examples | Low — cosmetic; easy to swap to a different `CLPlacemark` field post-hoc, no architectural dependency on the exact field chosen |

## Open Questions (RESOLVED)

1. **Exact `weatherExtendedContentHeight` value**
   - What we know: it must exceed `switcherContentHeight` (196pt) by however much the forecast row + its own top padding needs; `trayContentHeight`'s doc comment shows the box-math style to follow (sum of camera clearance + header + content + bottom inset).
   - What's unclear: the forecast row's actual height in points depends on the day-chip font sizes/padding chosen during implementation — not knowable without building the chip first.
   - Recommendation: follow `trayContentHeight`'s worked-math-in-a-comment convention once the chip design is drafted; treat the first value as a starting point for on-device tuning, exactly as `switcherRowHeight`'s own doc comment already states ("a starting point for on-device tuning").
   - **Resolved:** `33-UI-SPEC.md`'s Layout Contract now specifies the worked-math values directly — `weatherMediumContentHeight = 290` and `weatherLargeContentHeight = 470` — carried into `33-02-PLAN.md` Task 2's `blobShape` height constants (flagged there as needing on-device tuning at the Task 4 checkpoint).

2. **Does `handleSettingsChanged()` need a new branch for immediate live-refresh on flip-to-extended, or does the existing render pass suffice?**
   - What we know: `handleSettingsChanged()` already re-runs `renderPresentation()` under `withAnimation(...)` for every settings change (materialStyle, accents, activity toggles) — this alone should make the compact→extended layout swap animate live per D-04, since `outfitState.forecast` will already be populated from the last refresh cycle (data was fetched all along, just not rendered until the toggle flips — see Pitfall 2's "fetch always, render conditionally" resolution).
   - What's unclear: whether `outfitState.forecast` should be populated even while the toggle is OFF (making the flip-to-on transition always have data ready) or only fetched once the toggle is first turned on (saving one field of memory, at the cost of a possible empty-forecast flash on first enable).
   - Recommendation: always populate `outfitState.forecast` from the same combined call regardless of toggle state (simpler, avoids Pitfall 2's partial-render window entirely, and the "quota" argument in Pitfall 1 is about call *count* not response *size* — reading an unused field costs nothing extra since it's the same one call either way).
   - **Resolved:** confirmed as-recommended — no new `handleSettingsChanged()` branch needed. `33-02-PLAN.md`'s `refreshWeather()` (Task 3) writes `outfitState.weather`/`.forecast`/`.hourlyForecast` unconditionally on every refresh regardless of `weatherStyle`, so the existing `renderPresentation()` re-run under `withAnimation(...)` is sufficient for live Medium/Large switching.

## Environment Availability

Skipped — this phase has no new external dependencies. `WeatherKit` and `CoreLocation` are both already linked and functioning in the project (confirmed via direct source read of `WeatherService.swift`/`LocationProvider.swift`, and via `.planning/PROJECT.md`'s note that Phase 14 already fixed the WeatherKit Portal App Services entitlement gap).

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (Xcode 16+) |
| Config file | `project.yml` (XcodeGen) → generates `Islet.xcodeproj`; shared scheme at `Islet.xcodeproj/xcshareddata/xcschemes/Islet.xcscheme` |
| Quick run command | `xcodebuild build -scheme Islet -destination 'platform=macOS'` (build-only gate — see below) |
| Full suite command | Manual Cmd-U in Xcode (NOT `xcodebuild test`) |

**Critical project-specific pitfall (from project memory, confirmed by `.planning/PROJECT.md` line 212):** `xcodebuild test` hangs in this project — tests are hosted inside the full `Islet.app`, which boots `NSPanel`/`MediaRemote`/`IOBluetooth` at test-runner launch, and `BluetoothMonitor`'s TCC-authorization wait never resolves in a non-interactive/headless environment. **Use `xcodebuild build` as the automated gate for every task in this phase's plan; route the actual test *execution* to a manual Cmd-U instruction for the human operator**, exactly as this project's existing plans already do (see project memory `xcodebuild-test-headless-hang`).

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| WEATHER-01 | Compact card shows location, icon, current temp, H/L | unit (pure data mapping) + manual on-device (rendering) | `xcodebuild build -scheme Islet` (build gate); no automated render assertion — SwiftUI view output isn't unit-testable in this codebase's existing pattern (no snapshot-testing library present) | New: `IsletTests/DailyForecastTests.swift` or extend `WeatherCategoryTests.swift`-style pure-mapping tests — ❌ Wave 0 |
| WEATHER-01 | Reverse-geocode "Local" fallback on failure/pending (D-02) | unit (pure fallback logic, if extracted as a pure function) | `xcodebuild build -scheme Islet` | ❌ Wave 0 — depends on how the plan structures the fallback (pure function vs. inline closure) |
| WEATHER-02 | Settings toggle switches compact ↔ extended, live, no relaunch (D-04) | manual on-device (this is a `@AppStorage`-driven SwiftUI render branch + AppKit panel-frame change — no existing precedent in this codebase for unit-testing this class of behavior; `ActivitySettingsTests.swift` tests the key/persistence layer only, not live-render behavior) | none automatable | N/A — manual UAT checkpoint required |
| WEATHER-02 | Extended card fetches forecast via ONE combined WeatherKit call, not two (Pitfall 1) | unit (mock `WeatherService` conformer, assert call count) | `xcodebuild build -scheme Islet` then manual Cmd-U | ❌ Wave 0 — needs a test double; `LocationServiceTests.swift` shows this codebase's existing protocol-mock pattern to follow |

### Sampling Rate
- **Per task commit:** `xcodebuild build -scheme Islet -destination 'platform=macOS'`
- **Per wave merge:** Manual Cmd-U in Xcode (full XCTest suite) — cannot be scripted per the pitfall above
- **Phase gate:** Full suite green (Cmd-U) before `/gsd:verify-work`, plus the on-device UAT checkpoints for WEATHER-02's live-toggle behavior (D-04) and the forecast-row fit (D-05)

### Wave 0 Gaps
- [ ] `IsletTests/DailyForecastTests.swift` (or equivalent) — pure `WeatherCondition`→`WeatherCategory` mapping reuse for forecast days already covered by existing `WeatherCategoryTests.swift`; new tests only needed for any new pure logic (e.g. a `DailyForecast` initializer/mapping function, or a "Local" fallback helper if extracted)
- [ ] A mock `WeatherService` conformer that records call count, to assert the combined-call-not-two-calls contract (Pitfall 1) — check whether `IsletTests/` already has a `WeatherService` test double before adding one (grep found none as of this research pass)
- [ ] Framework install: none — XCTest ships with Xcode

*(No gap in existing infrastructure beyond the above — `IsletTests/` already has 29 test files covering this codebase's established seam-testing conventions; this phase's new pure logic slots into that same pattern.)*

## Sources

### Primary (HIGH confidence)
- Installed macOS SDK, `WeatherKit.framework/Versions/A/Modules/WeatherKit.swiftmodule/arm64e-apple-macos.swiftinterface` — exact `weather(for:including:_:)` overload set, `DayWeather`/`CurrentWeather` field lists, `WeatherQuery.current`/`.daily` statics (read directly, not training data)
- Installed macOS SDK, `CoreLocation.framework/Headers/CLGeocoder.h` and `CLPlacemark.h` — exact `reverseGeocodeLocation` signatures and deprecation annotations, `CLPlacemark` field list
- Installed macOS SDK, `MapKit.framework/Headers/MKReverseGeocodingRequest.h` — confirms the replacement API's existence (used only to establish Pitfall 3, not recommended for use)
- Direct source read: `Islet/Weather/WeatherService.swift`, `Islet/Weather/WeatherCategory.swift`, `Islet/Location/LocationProvider.swift`, `Islet/Notch/BasicOutfitState.swift`, `Islet/ActivitySettings.swift`, `Islet/SettingsView.swift`, `Islet/Notch/NotchPillView.swift` (constants block, `weatherFullView`/`weatherFullContent`, `blobShape`, `trayFullView` as the height-override precedent), `Islet/Notch/NotchWindowController.swift` (`refreshWeather`, `startOutfitRefresh`, `handleSettingsChanged`, `positionAndShow`, `visibleContentZone`), `Islet/Notch/IslandResolver.swift` (confirms `.weatherExpanded` case already exists)

### Secondary (MEDIUM confidence)
- `.planning/research/ARCHITECTURE.md` §"Feature 4" and Anti-Pattern 1 — v1.5-milestone-level architecture research, itself HIGH confidence per its own header ("every claim grounded in a direct read of current source") but MEDIUM here since it predates this phase's own direct SDK verification
- `.planning/research/PITFALLS.md` Pitfalls 5/6 — same v1.5-milestone research, WWDC22-session-corroborated for the combined-call API (independently re-confirmed HIGH by this phase's own SDK read)
- `.planning/research/FEATURES.md` §"Area 4" — anti-feature table (no hourly/alerts/radar), confirms scope boundary

### Tertiary (LOW confidence)
- None used — the WebSearch result for the combined-call API was superseded by the direct SDK read before being relied upon.

## Metadata

**Confidence breakdown:**
- Standard stack (WeatherKit combined call, CLGeocoder): HIGH — verified against the actual installed SDK's Swift interface and Objective-C headers, not documentation lookup or training data
- Architecture (panel-frame/click-through geometry pattern): HIGH — every claim traced to a direct read of this project's own `NotchWindowController.swift`/`NotchPillView.swift`, cross-referenced against 3 prior phases (20, 28, 32) that hit the identical bug class
- Pitfalls: HIGH for the WeatherKit-quota and CLGeocoder-deprecation pitfalls (SDK-verified); MEDIUM for the exact `weatherExtendedContentHeight` value (Open Question 1 — genuinely undeterminable without building the chip)

**Research date:** 2026-07-15
**Valid until:** 30 days (stable, first-party Apple APIs; re-verify if Xcode/SDK is upgraded before planning starts, since `CLGeocoder`'s deprecation floor and `MKReverseGeocodingRequest`'s availability were both read from the currently-installed SDK snapshot)
