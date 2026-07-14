# Phase 33: Weather Widget Redesign - Pattern Map

**Mapped:** 2026-07-15
**Files analyzed:** 7 (6 modified, 1 new test file)
**Analogs found:** 7 / 7 — every file in this phase is a modification of an existing, already-shipped seam; there are no genuinely new files/directories.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|--------------------|------|-----------|-----------------|----------------|
| `Islet/Weather/WeatherService.swift` | service | request-response (async fetch, completion-on-main contract) | itself (extend in place) — `fetchCurrent` is the exact analog for the new `fetchCurrentAndForecast` | exact (self-analog) |
| `Islet/Notch/BasicOutfitState.swift` | store (`@Published` holder) | pub-sub (controller writes, view reads) | itself — `weather`/`calendar` fields are the exact analog for the new `forecast` field | exact (self-analog) |
| `Islet/Notch/NotchWindowController.swift` (`refreshWeather`, `positionAndShow`, `visibleContentZone`) | controller | event-driven (timer/settings-change triggered fetch + geometry sync) | Phase 32's `trayFrame`/`.trayExpanded` three-site pattern in the same file | exact |
| `Islet/Notch/NotchPillView.swift` (`weatherFullContent`, new `forecastRow`, `weatherExtendedContentHeight`) | component (SwiftUI view) | transform (render glance/forecast → view) | `trayFullView`/`trayContentHeight`/`shelfRow` (Phase 32) for the height-override + row pattern; `weatherFullView` itself for the content structure | exact |
| `Islet/ActivitySettings.swift` (+ `weatherExtendedKey`) | config | CRUD (key namespace) | `materialStyleKey` (Phase 27) | exact |
| `Islet/SettingsView.swift` (+ "Weather" Section) | component (SwiftUI settings form) | request-response (`@AppStorage` two-way binding) | `Section("Activities")`'s plain-Toggle block | exact |
| `IsletTests/WeatherServiceTests.swift` (new file) | test | request-response (fake conformer + completion capture) | `IsletTests/LocationServiceTests.swift`'s `FakeLocationService` | exact |

## Pattern Assignments

### `Islet/Weather/WeatherService.swift` (service, request-response)

**Analog:** itself — `WeatherKitService.fetchCurrent` (lines 29-46)

**Imports pattern** (lines 1-2):
```swift
import WeatherKit
import CoreLocation
```

**Protocol seam pattern** (lines 21-27) — new `fetchCurrentAndForecast` joins this protocol alongside (not replacing) `fetchCurrent`, same `AnyObject` protocol / main-thread-completion contract:
```swift
protocol WeatherService: AnyObject {
    func fetchCurrent(latitude: Double, longitude: Double, completion: @escaping (WeatherGlance?) -> Void)
}
```

**Core fetch + error handling pattern** (lines 32-45), the template for the new combined call:
```swift
func fetchCurrent(latitude: Double, longitude: Double, completion: @escaping (WeatherGlance?) -> Void) {
    Task {
        do {
            let location = CLLocation(latitude: latitude, longitude: longitude)
            let weather = try await service.weather(for: location)
            let glance = WeatherGlance(category: WeatherCategory.from(weather.currentWeather.condition),
                                       temperature: weather.currentWeather.temperature)
            await MainActor.run { completion(glance) }
        } catch {
            // D-01: no retry inside this call — silent omission on any thrown error.
            await MainActor.run { completion(nil) }
        }
    }
}
```
**Apply as:** `fetchCurrentAndForecast(latitude:longitude:completion:)` follows this exact shape but calls `service.weather(for: location, including: .current, .daily)` (RESEARCH.md Pattern 1, already gives the full Task/do-catch/`await MainActor.run` skeleton to reuse verbatim) and settles `(nil, nil)` on the same silent-omission contract.

**Model pattern** (lines 16-19) — `WeatherGlance` is the exact template for the new `DailyForecast` struct (both `Equatable`, both wrap `Measurement<UnitTemperature>`, no manual unit conversion):
```swift
struct WeatherGlance: Equatable {
    let category: WeatherCategory
    let temperature: Measurement<UnitTemperature>
}
```

---

### `Islet/Notch/BasicOutfitState.swift` (store, pub-sub)

**Analog:** itself (lines 1-11, whole file — 11 lines, single read, extract everything)

```swift
import Foundation

@MainActor
final class BasicOutfitState: ObservableObject {
    @Published var weather: WeatherGlance?
    @Published var calendar: CalendarGlance?
}
```
**Apply as:** add `@Published var forecast: [DailyForecast]?` as a third field, same ownership contract (controller-only writer, view-only reader) — no new class, no new file.

---

### `Islet/Notch/NotchWindowController.swift` (controller, event-driven)

**Analog:** the file's own Phase 32 Tray precedent for the three-site geometry rule, plus its own `refreshWeather`/`startOutfitRefresh` for the fetch-gating pattern.

**Fetch pattern to extend** (lines 604-609):
```swift
private func refreshWeather() {
    guard let loc = lastLocation else { return }
    weatherService.fetchCurrent(latitude: loc.coordinate.latitude, longitude: loc.coordinate.longitude) { [weak self] glance in
        self?.outfitState.weather = glance
    }
}
```
**Apply as:** replace the `fetchCurrent` call with `fetchCurrentAndForecast`, writing BOTH `outfit.weather` and `outfit.forecast` from the SAME completion callback (Pitfall 2 — atomic delivery, no partial-render pop-in). Per RESEARCH Open Question 2: always populate `forecast` regardless of toggle state, gating only what `NotchPillView` *renders*, not what the controller *fetches*.

**Timer/one-shot trigger pattern** (lines 579-600) — unchanged, `refreshWeather()` stays the dispatch point on both the one-shot `startLocationOnce()` path and the 900s repeating timer; no new trigger needed (Don't-Hand-Roll table).

**Panel-frame union — 3-site pattern, site 1** (lines 807-815, Phase 32's `trayFrame`, the exact template for `weatherExtendedFrame`):
```swift
let trayFrame = expandedNotchFrame(collapsed: collapsedFrame,
                                   expandedSize: CGSize(width: NotchPillView.traySize.width,
                                                         height: NotchPillView.trayContentHeight + NotchPillView.switcherRowHeight))
let panelFrame = expandedFrame.union(wings).union(onboardingFrame).union(trayFrame)
```
**Apply as:** add a 4th union member `weatherExtendedFrame` built the same way from `NotchPillView.weatherExtendedContentHeight + NotchPillView.switcherRowHeight`, and fold it into `panelFrame`'s `.union(...)` chain — gate the frame's inclusion (or just always include it in the union, cheapest/laziest option since it's a static upper bound like `trayFrame` already is).

**Click-through zone — 3-site pattern, site 2** (lines 990-999, Phase 32's `.trayExpanded` branch, the exact template for `.weatherExpanded`):
```swift
if isOnboardingActive {
    contentSize = NotchPillView.onboardingSize
} else if case .trayExpanded = presentationState.presentation {
    contentSize = CGSize(width: NotchPillView.traySize.width,
                         height: NotchPillView.trayContentHeight + switcherHeight)
} else {
    contentSize = CGSize(width: expandedSize.width,
                         height: (switcherRowShowing ? NotchPillView.switcherContentHeight : expandedSize.height) + switcherHeight)
}
```
**Apply as:** insert a new `else if case .weatherExpanded = presentationState.presentation, weatherExtendedEnabled` branch ahead of the default `else`, sizing to `weatherExtendedContentHeight + switcherHeight` — mirrors RESEARCH.md Pattern 3's worked example almost verbatim. **CRITICAL (Pitfall 4 / Anti-Pattern 1, this project's twice-repeated bug class):** this branch, the `weatherExtendedFrame` union member, and `blobShape`'s call-site `height:` override in `NotchPillView.swift` must land in the SAME commit — see project memory `cr01-clickthrough-or-defeat-gotcha`.

**Live settings-reload pattern** (lines 1433 onward, `handleSettingsChanged()`) — no new observer needed (Don't-Hand-Roll table); the existing `UserDefaults.didChangeNotification` pipeline already re-runs `renderPresentation()` under `withAnimation(...)` for every `@AppStorage` change, which is what makes D-04's live animated toggle work "for free."

---

### `Islet/Notch/NotchPillView.swift` (component, transform)

**Analog:** `trayFullView`/`trayContentHeight` (Phase 32) for the height-override mechanics; `weatherFullView`/`weatherFullContent` (lines 737-768) for the content structure to extend in place.

**Height constant pattern** (lines 338-348, `trayContentHeight`'s box-math-in-a-comment convention — copy this comment STYLE exactly for `weatherExtendedContentHeight`):
```swift
static let traySize = CGSize(width: 650, height: 144)
static let trayContentHeight: CGFloat = 128
```
**Apply as:** `static let weatherExtendedContentHeight: CGFloat = 240` per UI-SPEC's worked math (cameraClearance 42 + icon 44 + spacing 8 + temp 32 + spacing 8 + location/H-L label lines ~16 + section gap 16 + forecast chip stack ~56 + bottom inset 16 ≈ 238, rounded to 240) — flagged in the UI-SPEC as a starting point for on-device tuning, exactly like `trayContentHeight`'s own history.

**`blobShape` override-wins-over-default pattern** (line 1188, already generalized, no change needed to `blobShape` itself):
```swift
let baseHeight = height ?? (showSwitcher ? Self.switcherContentHeight : Self.expandedSize.height)
```
**Weather's call site** (mirrors `trayFullView`'s lines 803-806 exactly):
```swift
private var trayFullView: some View {
    blobShape(topCornerRadius: 24, bottomCornerRadius: 32, alignment: .top,
              width: Self.traySize.width, height: Self.trayContentHeight, shelfItems: [],
              shelfVisible: false, showSwitcher: true) { ... }
}
```
**Apply as:** `weatherFullView`'s existing `blobShape(...)` call (currently line 738, no `height:` argument) gets a `height: weatherExtended ? Self.weatherExtendedContentHeight : nil` argument added — RESEARCH.md's Pattern 2 code example shows this exact call site already drafted.

**Content structure to extend** (lines 755-768, `weatherFullContent`, current shape — icon → temp → category label):
```swift
private func weatherFullContent(_ weather: WeatherGlance) -> some View {
    VStack(spacing: 8) {
        weatherIcon(for: weather.category)
            .font(.system(size: 44))
        Text(weather.temperature.formatted(.measurement(width: .narrow, numberFormatStyle: .number.precision(.fractionLength(0)))))
            .font(.system(size: 32, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.white)
        Text(weatherCategoryLabel(weather.category))
            .font(.system(size: 13, weight: .regular, design: .rounded))
            .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
}
```
**Apply as:** per UI-SPEC Layout Contract — add the location-name label (13pt, `.secondary`, D-01/D-02 "Local" fallback) ABOVE the icon, and an H/L readout line under the category label; do not restructure the icon/temperature pairing. Append the new `forecastRow(_:)` view (an `HStack(spacing: 8)` of day-chips, `VStack(spacing: 4)` internals per chip: weekday 11pt Caption → icon 20pt (`weatherIcon(for:)`, reused verbatim, lines 1486-1501) → H/L 12pt semibold `.monospacedDigit()`) BELOW `weatherFullContent`, gated by `@AppStorage(ActivitySettings.weatherExtendedKey)`, only when extended.

**Icon reuse** (lines 1486-1501, `weatherIcon(for:)`) — reuse verbatim for both the compact icon (44pt) and each forecast chip icon (20pt, smaller `.font(.system(size: 20))` only):
```swift
@ViewBuilder
private func weatherIcon(for category: WeatherCategory) -> some View {
    switch category {
    case .sunny: Image(systemName: "sun.max.fill").symbolRenderingMode(.multicolor)
    case .cloudy: Image(systemName: "cloud.fill").symbolRenderingMode(.multicolor)
    case .rain: Image(systemName: "cloud.rain.fill").symbolRenderingMode(.multicolor)
    case .snow: Image(systemName: "cloud.snow.fill").symbolRenderingMode(.multicolor)
    }
}
```

**Switcher-row source of truth** (lines 1224-1240, `switcherRow`) — unchanged; Weather is already the 4th icon (`.weatherExpanded`) in this row, no edit needed here.

---

### `Islet/ActivitySettings.swift` (config, CRUD)

**Analog:** `materialStyleKey` (line 39)

```swift
static let materialStyleKey = "theming.materialStyle"
```
**Apply as:** `static let weatherExtendedKey = "weather.extended"` — a single plain `@AppStorage`-backed `Bool` key (no enum needed, unlike `MaterialStyle`), added to the same top-level key block near `hideInFullscreenKey`/`onboardingCompletedKey` (lines 26-30).

---

### `Islet/SettingsView.swift` (component, request-response)

**Analog:** `Section("Activities")` (lines 162-167)

```swift
@AppStorage(ActivitySettings.chargingKey)   private var chargingEnabled = true
...
Section("Activities") {
    Toggle("Charging", isOn: $chargingEnabled)
    Toggle("Now Playing", isOn: $nowPlayingEnabled)
    Toggle("Song-Change Toast", isOn: $songChangeToastEnabled)
    Toggle("Devices", isOn: $deviceEnabled)
}
```
**Apply as:** add `@AppStorage(ActivitySettings.weatherExtendedKey) private var weatherExtended = false` near the other `@AppStorage` declarations (line 28-33), and a new `Section("Weather") { Toggle("Extended forecast", isOn: $weatherExtended) }` inside `generalSection`'s `Form`, alongside `Section("Activities")`/`Section("Fullscreen")` (UI-SPEC Copywriting Contract confirms the exact label "Extended forecast" and Section title "Weather"). No `.onChange` handler needed — unlike `launchAtLogin` (line 140), this is a plain app-owned `@AppStorage` value with no system-state round-trip, same as every `Activities` toggle.

---

### `IsletTests/WeatherServiceTests.swift` (new file, test, request-response)

**Analog:** `IsletTests/LocationServiceTests.swift` (whole file, 42 lines — read in full above)

```swift
import XCTest
import CoreLocation
@testable import Islet

final class LocationServiceTests: XCTestCase {
    private final class FakeLocationService: LocationService {
        private(set) var requestOnceCallCount = 0
        private(set) var lastCompletion: ((CLLocation?) -> Void)?

        func requestOnce(completion: @escaping (CLLocation?) -> Void) {
            requestOnceCallCount += 1
            lastCompletion = completion
        }
    }

    func testFakeLocationServiceCapturesCompletionAndRoundTripsSyntheticLocation() {
        let fake = FakeLocationService()
        var receivedLocation: CLLocation?
        fake.requestOnce { location in receivedLocation = location }
        let synthetic = CLLocation(latitude: 52.5, longitude: 13.4)
        fake.lastCompletion?(synthetic)
        XCTAssertEqual(receivedLocation?.coordinate.latitude, synthetic.coordinate.latitude)
        XCTAssertEqual(fake.requestOnceCallCount, 1)
    }
}
```
**Apply as:** `FakeWeatherService: WeatherService` with a `fetchCurrentAndForecastCallCount` counter (asserts Pitfall 1's "one combined call, not two" contract) plus a captured completion for synthetic-glance/forecast round-tripping — same in-memory-fake-no-real-I/O shape as `FakeLocationService`. Also extend `WeatherCategoryTests.swift`-style pure-mapping tests (already reused as-is for forecast days per CONTEXT.md line 50, no new test needed there) if a `DailyForecast` init/mapping helper is extracted as pure logic.

---

## Shared Patterns

### Silent-omission-on-failure (D-01, project-wide weather/location convention)
**Source:** `Islet/Weather/WeatherService.swift` lines 40-43 (`catch { completion(nil) }`)
**Apply to:** `fetchCurrentAndForecast`'s catch block (settle `(nil, nil)`), and the new `resolvePlaceName` reverse-geocode helper (settle `nil` → view-layer "Local" fallback). No retry, no error string, ever.

### Main-thread completion contract
**Source:** `Islet/Weather/WeatherService.swift` file header comment (lines 9-10) and every `await MainActor.run { completion(...) }` call site
**Apply to:** every new completion closure this phase adds (`fetchCurrentAndForecast`, `resolvePlaceName`) — this is a file-header-documented CONTRACT other callers rely on, not incidental.

### Geometry three-site rule (Pitfall 4 / Anti-Pattern 1 — CR-01/WR-02 precedent)
**Source:** `Islet/Notch/NotchPillView.swift` `blobShape` height-override (line 1188) + `Islet/Notch/NotchWindowController.swift` `positionAndShow`'s `trayFrame` union (lines 812-815) + `visibleContentZone()`'s `.trayExpanded` branch (lines 993-995)
**Apply to:** all three Weather-extended equivalents (`weatherFullView`'s `blobShape` call, a new `weatherExtendedFrame` union member, a new `.weatherExpanded` branch) — MUST land together in one commit/task per this project's own twice-repeated bug class; verify via the on-device hover→expand→click trace already used for CR-01-class regressions.

### `@AppStorage` settings-key + live-reload pattern
**Source:** `Islet/ActivitySettings.swift` (`materialStyleKey`) + `Islet/SettingsView.swift` (`Section("Activities")`) + `Islet/Notch/NotchWindowController.swift` `handleSettingsChanged()` (line 1433)
**Apply to:** `weatherExtendedKey` — declare once in `ActivitySettings`, bind identically in both `SettingsView` (for the Toggle) and `NotchPillView`/`NotchWindowController` (for rendering/geometry) — never let the two drift (Anti-Pattern 3 in RESEARCH.md).

## No Analog Found

None — every file in this phase's scope is an extension of an existing, already-shipped seam (`WeatherService`, `BasicOutfitState`, `NotchWindowController`, `NotchPillView`, `ActivitySettings`, `SettingsView`, and the `LocationServiceTests`-style fake-conformer test pattern). No new architectural pattern needs inventing (RESEARCH.md's own "Key insight").

## Metadata

**Analog search scope:** `Islet/Weather/`, `Islet/Notch/`, `Islet/ActivitySettings.swift`, `Islet/SettingsView.swift`, `IsletTests/`
**Files scanned:** `Islet/Weather/WeatherService.swift`, `Islet/Weather/WeatherCategory.swift`, `Islet/Notch/BasicOutfitState.swift`, `Islet/Notch/NotchPillView.swift` (2127 lines, targeted reads: 200-360, 725-840, 1139-1260, 1480-1520), `Islet/Notch/NotchWindowController.swift` (1857 lines, targeted reads: 575-620, 795-825, 960-1030, 1420-1470), `Islet/Notch/IslandResolver.swift` (confirmed `.weatherExpanded` case pre-exists), `Islet/ActivitySettings.swift`, `Islet/SettingsView.swift` (137-186), `IsletTests/WeatherCategoryTests.swift`, `IsletTests/LocationServiceTests.swift`
**Pattern extraction date:** 2026-07-15
