# Phase 14: Basic Outfit — Weather + Calendar + Date Display - Research

**Researched:** 2026-07-08
**Domain:** Apple-native weather (WeatherKit), calendar (EventKit), location (CoreLocation), and SF Symbols animation, integrated into an existing SwiftUI notch-overlay app (Islet)
**Confidence:** MEDIUM-HIGH (native framework shapes are HIGH confidence/well-documented; some Tahoe/macOS-26-specific edge cases are MEDIUM — flagged inline)

## Summary

This phase adds three new external-data glances (weather, calendar, date — date is free, already `Date.now`) to the existing `expandedIdle` case in `NotchPillView.swift`. All three new externals are first-party Apple frameworks with **zero new third-party dependencies** — this is the cleanest phase in the project's history for the "don't hand-roll" and "no paid services" constraints simultaneously.

**Primary recommendation:** Use **Apple WeatherKit** (Swift framework, not the REST API) for weather — it is fully covered by the project's existing paid Apple Developer Program membership (500,000 calls/month included, no extra cost), returns strongly-typed `WeatherCondition`/`Measurement<UnitTemperature>` values with zero JSON parsing, and needs no API key. The free alternative considered (**Open-Meteo**) is explicitly **non-commercial-use-only** on its free/keyless tier — since Islet is a €7.99 paid product, using Open-Meteo's free tier would violate its terms of service; the paid Open-Meteo tier (from $XX/mo) would violate the project's "no paid services beyond the Developer account" constraint. This makes WeatherKit not just the better choice but the **only** choice that satisfies both constraints. **[VERIFIED: Apple Developer + Open-Meteo docs]**

**The one real setup gotcha:** WeatherKit requires the running binary to be signed with a provisioning identity carrying the `com.apple.developer.weatherkit` entitlement, tied to an App ID with the WeatherKit capability enabled in the Apple Developer portal. The project's current `project.yml` signs local Debug builds **ad-hoc** (`CODE_SIGN_IDENTITY: "-"`, "Sign to Run Locally") — this will NOT satisfy WeatherKit at runtime, even in local development. The Phase-13 Developer ID credentials (used only at release time via `scripts/release.sh`) must now also be wired into `project.yml` for day-to-day Debug builds, or WeatherKit calls will fail even on-device during development. This is a Wave-0-class setup task, not an implementation detail.

EventKit and CoreLocation need no such entitlement gymnastics — both are ordinary usage-description-gated frameworks, following the exact same shape as the project's existing `NSBluetoothAlwaysUsageDescription` precedent (Phase 6/A1).

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Weather fetch (WeatherKit) | API/Backend-equivalent (controller-owned service) | — | Fragile/permission-gated external; must be isolated behind one protocol per existing `NowPlayingService`/`LicenseService` convention — the view never calls WeatherKit directly |
| Location fetch (CoreLocation) | Controller-owned service | — | One-shot permission + `requestLocation()`; feeds the weather service, not rendered itself |
| Calendar fetch (EventKit) | Controller-owned service | — | Same isolation posture as weather; permission-gated, must degrade silently (D-03) |
| Weather condition → 4-category mapping | Pure Foundation-only seam | — | Mirrors `DeviceActivity.swift`/`NowPlayingPresentation.swift`: a total, unit-testable function with zero system-framework imports |
| "Next event" selection logic | Pure Foundation-only seam | — | Same pattern: given `[EKEvent]` + `Date`, a pure function picks today's-next-or-tomorrow's-first event — unit-testable without EventKit itself |
| Icon animation (SF Symbols `symbolEffect`) | SwiftUI View (Browser/Client-equivalent) | — | Purely presentational; no data flows through it |
| 3-column layout | SwiftUI View (`NotchPillView.swift`) | — | Extends the existing `expandedIsland` computed view; mirrors `wings(for:)`/`deviceWings(for:)` HStack pattern |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| **WeatherKit** (Apple framework) | Ships with Xcode 16 / macOS 14+ SDK | Current weather + condition + temperature | First-party, free under the existing Developer Program, strongly-typed Swift API, zero JSON parsing **[VERIFIED: Apple Developer docs — developer.apple.com/weatherkit]** |
| **EventKit** (Apple framework) | Ships with macOS SDK | Calendar event read access | First-party, only way to read system Calendar data on macOS **[CITED: developer.apple.com/documentation/eventkit]** |
| **CoreLocation** (Apple framework) | Ships with macOS SDK | One-time device location for weather query | First-party, standard `CLLocationManager.requestLocation()` one-shot pattern **[CITED: developer.apple.com/documentation/corelocation]** |
| **SF Symbols / SwiftUI `symbolEffect`** | Ships with macOS 14 (Sonoma)+ SDK | Weather icon animation (pulsing sun, drifting clouds, falling rain, snow) | Built into SwiftUI since macOS 14 — no custom `TimelineView` clock needed for the icon-only animation **[CITED: developer.apple.com WWDC23 "Animate symbols in your app"]** |

**No packages to install.** All four are Apple system frameworks already available in the existing Xcode 16+/macOS 14+ toolchain — `import WeatherKit`, `import EventKit`, `import CoreLocation` require no `project.yml` `packages:` entry (unlike `MediaRemoteAdapter`).

### Supporting
None needed — no HTTP client, no JSON decoder, no third-party calendar/location library. This is the leanest phase in the project.

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| WeatherKit | Open-Meteo (free, keyless REST API) | **Rejected**: Open-Meteo's free/keyless tier is licensed **non-commercial use only** (10,000 calls/day, no uptime SLA); Islet is a €7.99 paid product, so shipping on the free tier would violate Open-Meteo's terms. Its commercial tier is a paid subscription, which violates the project's "no paid services beyond the Developer account" budget constraint. WeatherKit is the only option satisfying both the budget AND legal-use constraints. **[VERIFIED: open-meteo.com/en/terms, open-meteo.com/en/pricing]** |
| WeatherKit Swift framework | WeatherKit REST API | REST API is for non-Apple platforms (Android/web/server); on native macOS Swift the framework returns typed models directly with zero manual networking/parsing — strictly better here **[CITED: developer.apple.com/weatherkit]** |
| SF Symbols `symbolEffect` | Hand-built `TimelineView`-driven custom shapes (raindrops/snowflakes as bespoke `Canvas` drawing) | Only worth it if the 4 built-in animated symbol effects (`.variableColor`, `.bounce`, `.pulse`, `.wiggle`) can't produce a convincing enough "rain falling / clouds drifting" feel on review — start with symbols, escalate to hand-built only if visually insufficient |
| EventKit full access | `EventKitUI` calendar chooser UI | Not needed — this phase only READS events for display, never lets the user create/edit one, so no EventKitUI surface is required |

## Package Legitimacy Audit

**Not applicable to this phase.** No third-party packages are installed — WeatherKit, EventKit, CoreLocation, and SF Symbols/symbolEffect are all Apple first-party frameworks shipped with the OS/Xcode SDK, not fetched from any package registry. The Package Legitimacy Gate (slopcheck / npm / pip / cargo verification) has no target here.

## Architecture Patterns

### System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│ NotchWindowController (owns services, mirrors NowPlayingMonitor/     │
│ BluetoothMonitor/PowerSourceMonitor ownership pattern)               │
│                                                                       │
│  ┌──────────────────┐    ┌───────────────────┐   ┌────────────────┐│
│  │ WeatherService    │    │ CalendarService   │   │ CLLocationMgr  ││
│  │ (protocol)        │    │ (protocol)        │   │ (one-shot)     ││
│  │  ↳ WeatherKitSvc  │    │  ↳ EventKitSvc    │   │                ││
│  └────────┬──────────┘    └─────────┬─────────┘   └───────┬────────┘│
│           │ WeatherSnapshot?         │ [EKEvent]?          │location │
│           │ (nil on permission deny) │ (nil on deny)        │        │
│           ▼                          ▼                      │        │
│  ┌────────────────────┐   ┌─────────────────────┐           │        │
│  │ WeatherCategory     │   │ nextRelevantEvent(   │◄──────────┘        │
│  │  .from(condition)   │   │  events, now)        │                    │
│  │ (pure Foundation-   │   │ (pure Foundation-    │                    │
│  │  only mapping)      │   │  only selection)     │                    │
│  └────────┬────────────┘   └──────────┬───────────┘                   │
│           │                            │                               │
│           ▼                            ▼                               │
│  ┌──────────────────────────────────────────────────┐                 │
│  │ BasicOutfitState (ObservableObject, @Published)    │                 │
│  │  weather: WeatherGlance?  calendar: CalendarGlance? │                │
│  └──────────────────────┬─────────────────────────────┘                │
└─────────────────────────┼───────────────────────────────────────────┘
                          │ injected as @ObservedObject
                          ▼
              NotchPillView.expandedIsland (3-column HStack:
              weather+temp | time+date | calendar event)
```

### Recommended Project Structure
```
Islet/
├── Weather/
│   ├── WeatherService.swift        # protocol + WeatherKitService conformer (mirrors LicenseService.swift shape)
│   └── WeatherCategory.swift       # pure enum + WeatherCondition → 4-category mapping (mirrors DeviceActivity.swift)
├── Calendar/
│   ├── CalendarService.swift       # protocol + EventKitService conformer
│   └── CalendarGlance.swift        # pure nextRelevantEvent(events:now:) selection logic
├── Location/
│   └── LocationProvider.swift      # thin CLLocationManagerDelegate wrapper, one-shot requestLocation()
└── Notch/
    ├── BasicOutfitState.swift      # @Published ObservableObject the controller writes, view observes
    └── NotchPillView.swift         # expandedIsland extended with the 3-column layout (existing file)
```

### Pattern 1: Protocol Isolation for Fragile/Permission-Gated Externals
**What:** Every external system dependency (WeatherKit, EventKit) sits behind a small `protocol X: AnyObject` with exactly one concrete conformer, exactly like `NowPlayingService`/`LicenseService`.
**When to use:** Always, for this codebase's convention — a future WeatherKit/EventKit API change or an alternate implementation (e.g., swapping WeatherKit for a REST fallback) becomes a one-file change.
**Example:**
```swift
// Source: mirrors Islet/Licensing/LicenseService.swift:35-39 and
// Islet/Notch/NowPlayingMonitor.swift:40-47 (existing codebase pattern)
protocol WeatherService: AnyObject {
    /// Fetch current weather for a location. Completion delivered on MAIN thread
    /// (mirrors the LicenseService/NowPlayingService completion contract).
    func fetchCurrent(latitude: Double, longitude: Double,
                       completion: @escaping (WeatherGlance?) -> Void)
}

final class WeatherKitService: WeatherService {
    private let service = WeatherKit.WeatherService.shared
    func fetchCurrent(latitude: Double, longitude: Double,
                       completion: @escaping (WeatherGlance?) -> Void) {
        Task {
            let location = CLLocation(latitude: latitude, longitude: longitude)
            do {
                let weather = try await service.weather(for: location)
                let glance = WeatherGlance(
                    category: WeatherCategory.from(weather.currentWeather.condition),
                    temperatureF: weather.currentWeather.temperature.value)
                await MainActor.run { completion(glance) }
            } catch {
                await MainActor.run { completion(nil) }   // D-01: silent omission on any failure
            }
        }
    }
}
```

### Pattern 2: Pure Classification Seam (mirrors `DeviceActivity.swift`)
**What:** The WeatherKit `WeatherCondition` enum (dozens of cases: `.clear`, `.mostlyClear`, `.partlyCloudy`, `.rain`, `.heavyRain`, `.snow`, `.blizzard`, `.thunderstorms`, etc. — full list is NOT enumerated in Apple's public docs pages surfaced by search; verify the complete case list via Xcode's Quick Help / autocomplete during implementation) collapses to the phase's 4 categories (D-06) via one pure, Foundation-only, unit-tested function — no WeatherKit import needed in the test target.
**Example:**
```swift
// Source: pattern mirrors Islet/Notch/DeviceActivity.swift's DeviceGlyph mapping
enum WeatherCategory: Equatable {
    case sunny, cloudy, rain, snow

    static func from(_ condition: WeatherKit.WeatherCondition) -> WeatherCategory {
        switch condition {
        case .clear, .mostlyClear, .hot:
            return .sunny
        case .snow, .heavySnow, .blizzard, .flurries, .sleet, .wintryMix, .blowingSnow, .freezingRain, .freezingDrizzle:
            return .snow
        case .rain, .heavyRain, .drizzle, .isolatedThunderstorms, .scatteredThunderstorms, .thunderstorms, .strongStorms, .hurricane, .tropicalStorm:
            return .rain
        default:   // partlyCloudy, mostlyCloudy, cloudy, foggy, haze, windy, etc.
            return .cloudy
        }
    }
}
```
**Note [ASSUMED]:** the exact `WeatherCondition` case list above is reconstructed from partial search results, not a verified exhaustive enumeration. The planner should have the executor confirm the full case list via Xcode autocomplete/Quick Help on `WeatherKit.WeatherCondition` before finalizing the `switch`, and add an exhaustive `default:` bucket to `.cloudy` regardless (fail-safe, never a compile error from a missing case, never a runtime crash).

### Pattern 3: Silent-Degradation Permission Flow (mirrors existing Bluetooth precedent's shape, NOT its content)
**What:** Both weather and calendar must degrade to "simply omit the column" on permission denial (D-01, D-03) — no retry loop, no error banner. This differs from the Bluetooth precedent (which crashes hard without its usage key) — for weather/calendar the correct behavior is graceful `nil`, not a crash.
**When to use:** Location authorization check before ever calling WeatherKit; EventKit authorization check before ever calling `requestFullAccessToEvents`.
**Example:**
```swift
// Location: request once, feed weather only on success (D-01)
final class LocationProvider: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var completion: ((CLLocation?) -> Void)?

    func requestOnce(completion: @escaping (CLLocation?) -> Void) {
        self.completion = completion
        manager.delegate = self
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()   // completion arrives via delegate callback
        case .authorizedAlways, .authorized:
            manager.requestLocation()
        default:
            completion(nil)   // denied/restricted → D-01 silent omission
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorized {
            manager.requestLocation()
        } else if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted {
            completion?(nil); completion = nil
        }
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        completion?(locations.last); completion = nil
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        completion?(nil); completion = nil   // D-01: any failure → silent omission
    }
}
```

```swift
// Calendar: request once, feed nil on denial (D-03)
final class EventKitService: CalendarService {
    private let store = EKEventStore()
    func fetchUpcoming(completion: @escaping ([EKEvent]?) -> Void) {
        Task {
            let granted = (try? await store.requestFullAccessToEvents()) ?? false
            guard granted else { await MainActor.run { completion(nil) }; return }  // D-03
            let calendars = store.calendars(for: .event)   // D-02: ALL active calendars, no filter
            let predicate = store.predicateForEvents(
                withStart: Date(), end: Date().addingTimeInterval(2 * 24 * 3600), calendars: calendars)
            let events = store.events(matching: predicate)
            await MainActor.run { completion(events) }
        }
    }
}
```

### Pattern 4: 3-Column `expandedIsland` Layout (extends existing `wings(for:)` idiom)
**What:** Mirror the LEFT/`Spacer()`/RIGHT `HStack` shape from `wings(for:)`/`deviceWings(for:)`, but with a THIRD center column (time+date), inside the taller `expandedIsland` blob (not `wingsShape`, which is the flatter strip).
**Example:**
```swift
// Source: mirrors Islet/Notch/NotchPillView.swift's wings(for:) HStack shape,
// adapted to expandedIsland's .padding(.top, 32) camera-clearance convention
// (see mediaExpanded, NotchPillView.swift:434)
private var expandedIsland: some View {
    NotchShape(topCornerRadius: 6, bottomCornerRadius: 20)
        .fill(Color.black)
        .matchedGeometryEffect(id: "island", in: ns)
        .frame(width: Self.expandedSize.width, height: Self.expandedSize.height)
        .overlay(alignment: .top) {
            HStack(spacing: 0) {
                if let weather = outfit.weather {
                    weatherColumn(weather)          // LEFT: icon + temp (D-07)
                }
                Spacer()
                VStack(spacing: 2) {                 // CENTER: time (large) + date (small)
                    Text(Date.now, format: .dateTime.hour().minute())
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text(Date.now, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let calendarGlance = outfit.calendar {
                    calendarColumn(calendarGlance)  // RIGHT: Today/Tomorrow + event (D-07)
                }
            }
            .padding(.top, 32)      // camera-clearance band (existing convention)
            .padding(.horizontal, 16)
        }
        .onTapGesture { onClick() }
}
```
**Sizing note:** the reference image's 3 columns must fit inside 360pt width minus ~32pt horizontal padding = ~328pt usable, split roughly 30/40/30% (weather ~100pt / time-date ~130pt / calendar ~100pt) — exact spacing is Claude's Discretion per CONTEXT.md; the executor should tune on-device against the same 179×32pt measured notch documented in project memory.

### Anti-Patterns to Avoid
- **Fetching weather/calendar from inside `NotchPillView` itself:** violates the established "controller owns monitors/services, view only renders" rule (see `code_context` in CONTEXT.md) — always inject a `BasicOutfitState` from `NotchWindowController`, mirroring `NowPlayingState`/`IslandPresentationState`.
- **Polling weather/calendar on a timer:** neither WeatherKit nor EventKit needs polling for this phase's scope — weather can refresh on a coarse interval (e.g., every 30-60 min, well under the 500k/month quota) driven by a simple `Timer` owned by the controller, not a continuous clock; calendar can re-query on a similar coarse interval or on notch-expand. Do NOT re-query either on every render.
- **Treating `nil` weather/calendar different from "no event today":** `nil` (permission denied or fetch failed) means "hide the column" (D-01/D-03); a successfully-fetched-but-empty event list also means "hide the column" (D-04's "nothing" case) — these are the same UI outcome from different causes; keep the state model distinguishing them only if useful for logging, never for the view's rendering branch.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Weather data fetch/parsing | A `URLSession` HTTP client + custom JSON `Codable` weather-code table | `WeatherKit.WeatherService.shared.weather(for:)` | Apple's framework returns strongly-typed `CurrentWeather` with `.condition: WeatherCondition` and `.temperature: Measurement<UnitTemperature>` — zero parsing, zero HTTP error handling to hand-write |
| Weather icon animation | Hand-drawn `Canvas`/`CAShapeLayer` raindrop/snowflake particle systems | SF Symbols `.symbolEffect(.variableColor)` / `.symbolEffect(.bounce)` / `.symbolEffect(.pulse)` on the built-in `sun.max.fill`/`cloud.fill`/`cloud.rain.fill`/`cloud.snow.fill` symbols | Apple ships multi-layer symbols specifically designed for these animations since macOS 14 — building a custom particle system is significant unnecessary complexity for an icon-only animation (D-05) |
| "Next relevant event" query | Manually iterating all events and hand-writing date-range comparison logic against raw Calendar-app SQLite or AppleScript | `EKEventStore.predicateForEvents(withStart:end:calendars:)` + a pure `nextRelevantEvent(events:now:)` filter | EventKit's predicate already efficiently queries across all calendars (D-02); only the "which ONE event to show" (D-04's live-advancing pick) needs a small hand-written pure function — not the querying itself |
| One-time location fix | A persistent location-tracking service / significant-location-change monitoring | `CLLocationManager.requestLocation()` (single-shot, auto-stops) | The phase needs ONE coordinate for a weather query, not continuous tracking — `requestLocation()` is designed exactly for this and avoids any privacy-invasive persistent tracking UI |

**Key insight:** Every piece of "hand-rolling" temptation in this phase (HTTP parsing, particle animation, calendar SQL) is already solved by a first-party Apple framework shipped in the exact SDK version this project targets. The only code actually worth hand-writing is the two small, pure, Foundation-only classification functions (`WeatherCategory.from(_:)` and `nextRelevantEvent(events:now:)`) — everything else is framework glue.

## Common Pitfalls

### Pitfall 1: WeatherKit Fails Silently Under Ad-Hoc Local Signing
**What goes wrong:** `WeatherService.shared.weather(for:)` throws/returns an error at runtime on a Debug build signed "Sign to Run Locally" (ad-hoc, `CODE_SIGN_IDENTITY: "-"`) — the current `project.yml` default for the `Islet` target.
**Why it happens:** WeatherKit authenticates via the code-signing identity + entitlement, not an API key; ad-hoc signing carries no App-ID-linked WeatherKit entitlement.
**How to avoid:** Before implementation, update `project.yml` to sign the `Islet` target with the REAL Development Team (the same Apple Developer Program account used for Phase-13 Developer ID/notarization) for Debug configuration too — not just at release time via `scripts/release.sh`. Add the WeatherKit capability to the App ID in the Apple Developer portal (Certificates, Identifiers & Profiles → Identifiers → the app's App ID → App Services tab → WeatherKit checkbox), then add "WeatherKit" in Xcode's Signing & Capabilities tab (or the equivalent `CODE_SIGN_ENTITLEMENTS` / `SystemCapabilities` in `project.yml`) so `com.apple.developer.weatherkit` is baked into `Islet.entitlements`.
**Warning signs:** WeatherKit calls throwing an unclear "not entitled"/network error on-device despite correct code; works in one build config but not another.

### Pitfall 2: `.symbolEffect` Repeating vs. One-Shot Confusion
**What goes wrong:** Assuming `.symbolEffect(.variableColor)` animates continuously by default, when in fact most symbol effects are **value-triggered, one-shot** unless `options: .repeating` is explicitly passed.
**Why it happens:** WWDC marketing material emphasizes continuous-looking demos, but the default behavior for many effects fires once per `value:` change or while `isActive:` is true — continuous looping requires `options: .repeating` explicitly. **[MEDIUM confidence — WebSearch-verified against multiple tutorial sources, not Apple's primary API reference page directly.]**
**How to avoid:** Since `expandedIsland` (and therefore the weather icon) only renders while the user has the island expanded — never while collapsed/idle — the D-04/Pitfall-5 "no clock runs when off-screen" precedent is satisfied by construction (the view simply doesn't exist in the switch when collapsed). Use `options: .repeating` deliberately for the weather icon since continuous animation IS the desired look while expanded and visible; this is NOT the same idle-CPU risk as `EqualizerBars` (which can render during collapsed "wings" glances that persist for seconds). Confirm on-device that no `symbolEffect` clock survives after the island collapses back (i.e., after `presentation` leaves `.expandedIdle`, verify no dangling animation task — SwiftUI should tear this down automatically when the view leaves the hierarchy, but confirm empirically per project precedent).
**Warning signs:** Icon animates once then freezes (missing `.repeating`); or (less likely, but worth an on-device check) energy/CPU sampling shows a lingering symbol-effect driver after collapse.

### Pitfall 3: EventKit Info.plist Key Drift Across macOS Versions
**What goes wrong:** Adding only the legacy `NSCalendarsUsageDescription` key (pre-Sonoma convention) and having the permission prompt fail to appear or the request silently deny on macOS 14+/26, which expects the newer granular `NSCalendarsFullAccessUsageDescription` key alongside it.
**Why it happens:** Apple introduced granular calendar/reminders access scopes (full vs. write-only) starting macOS Sonoma (14), each with its own usage-description key, while still nominally supporting the legacy key for backward compatibility. **[MEDIUM confidence — corroborated by two independent sources, not Apple's primary Info.plist key reference page directly fetched.]**
**How to avoid:** Add BOTH `INFOPLIST_KEY_NSCalendarsUsageDescription` and `INFOPLIST_KEY_NSCalendarsFullAccessUsageDescription` to `project.yml` (mirroring the existing `INFOPLIST_KEY_NSBluetoothAlwaysUsageDescription` defensive-key precedent from Phase 6/A1) since the deployment target floor is 14.0 and this app's actual build machine is Tahoe (macOS 26).
**Warning signs:** `requestFullAccessToEvents()` throws or the system prompt never appears; app crashes with a "privacy-sensitive data without usage description" error (exact same crash class as the documented Bluetooth A1 finding).

### Pitfall 4: Confusing "No Location Permission" with "No Weather Data"
**What goes wrong:** Treating a WeatherKit fetch failure (network, quota, transient) identically to a location-permission denial, potentially retrying indefinitely on a genuine denial (violating D-01's "no retry loop" decision).
**Why it happens:** Both paths converge to `nil` in the naive implementation.
**How to avoid:** Check `CLLocationManager.authorizationStatus` explicitly BEFORE ever attempting a WeatherKit call; only call WeatherKit when authorized. A denial short-circuits before any network attempt — no retry, no periodic re-check of authorization status (D-01: no begging dialog, no retry loop). A genuine WeatherKit network failure (after authorization succeeded) can retry on the same coarse timer as its next natural refresh (e.g., 30-60 min) — never a tight retry loop.
**Warning signs:** Battery/network activity in Instruments correlating with WeatherKit calls firing repeatedly against a permanently-denied location authorization.

### Pitfall 5: Idle-CPU Regression from the Icon Animation (D-04/Pitfall 5 precedent)
**What goes wrong:** A naive implementation adds the weather icon's `symbolEffect` (or a hand-built fallback `TimelineView`) unconditionally, and it turns out to keep animating even when the notch is collapsed (contradicting the project's hard-won zero-idle-CPU guarantee, verified via `sample`/Energy for `EqualizerBars` and `ProgressBar`).
**Why it happens:** Copy-pasting a symbol-effect example without checking whether the containing view is actually torn down (not just visually hidden) when the island collapses.
**How to avoid:** Because `expandedIsland` (and hence the weather icon) is one case of `switch presentation` — literally not constructed when `presentation != .expandedIdle` — SwiftUI deallocates the view (and any attached `symbolEffect`/`TimelineView` driver) on transition away, matching the codebase's existing "isPlaying-gated" idle-CPU discipline pattern by construction rather than by an explicit gate. Verify this empirically on-device (the same `sample`/Energy check used for `EqualizerBars` in Phase 4 UAT) rather than assuming SwiftUI's teardown is sufficient — this is the one on-device validation this phase inherits from the project's established precedent.
**Warning signs:** Energy/CPU sampling still shows animation-related CPU after collapsing the island back to the idle pill.

## Code Examples

### WeatherKit Fetch (Swift concurrency)
```swift
// Source: pattern per developer.apple.com/weatherkit + Apple's WeatherKit sample code shape
import WeatherKit
import CoreLocation

let service = WeatherService.shared
let location = CLLocation(latitude: lat, longitude: lon)
let weather = try await service.weather(for: location)
let condition = weather.currentWeather.condition       // WeatherCondition enum
let tempF = weather.currentWeather.temperature.converted(to: .fahrenheit).value
let symbolName = weather.currentWeather.symbolName      // Apple's OWN SF Symbol name, if not building custom mapping
```

### EventKit Next-Event Query
```swift
// Source: developer.apple.com/documentation/eventkit/ekeventstore/requestfullaccesstoevents(completion:)
let store = EKEventStore()
let granted = (try? await store.requestFullAccessToEvents()) ?? false
guard granted else { return nil }   // D-03: silent omission
let calendars = store.calendars(for: .event)   // D-02: all active calendars, no filter
let predicate = store.predicateForEvents(
    withStart: Calendar.current.startOfDay(for: .now),
    end: Calendar.current.date(byAdding: .day, value: 2, to: .now)!,
    calendars: calendars)
let events = store.events(matching: predicate).sorted { $0.startDate < $1.startDate }
```

### Pure "Next Relevant Event" Selection (D-04)
```swift
// Foundation-only, unit-testable without EventKit — mirrors DeviceActivity.swift's pure-seam pattern
struct CalendarGlance: Equatable {
    let title: String
    let startDate: Date
    let isToday: Bool   // drives the "Today"/"Tomorrow" label (D-07)
}

func nextRelevantEvent(events: [(title: String, start: Date, end: Date)], now: Date) -> CalendarGlance? {
    let calendar = Calendar.current
    // In-progress or upcoming TODAY:
    if let todayEvent = events
        .filter({ calendar.isDate($0.start, inSameDayAs: now) })
        .filter({ $0.end > now })                    // still relevant (in-progress or future)
        .sorted(by: { $0.start < $1.start })
        .first {
        return CalendarGlance(title: todayEvent.title, startDate: todayEvent.start, isToday: true)
    }
    // Else tomorrow's FIRST event:
    guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) else { return nil }
    if let tomorrowEvent = events
        .filter({ calendar.isDate($0.start, inSameDayAs: tomorrow) })
        .sorted(by: { $0.start < $1.start })
        .first {
        return CalendarGlance(title: tomorrowEvent.title, startDate: tomorrowEvent.start, isToday: false)
    }
    return nil   // D-04: neither exists → blank calendar column
}
```

### Animated Weather Icon (SF Symbols)
```swift
// Source: pattern per WWDC23 "Animate symbols in your app" + createwithswift.com symbolEffect guide
Image(systemName: symbolName(for: category))
    .symbolRenderingMode(.multicolor)
    .symbolEffect(.variableColor.iterative, options: .repeating, isActive: true)
    // ^ .repeating is REQUIRED for continuous animation — the default is often one-shot per value change

func symbolName(for category: WeatherCategory) -> String {
    switch category {
    case .sunny:  return "sun.max.fill"
    case .cloudy: return "cloud.fill"
    case .rain:   return "cloud.rain.fill"
    case .snow:   return "cloud.snow.fill"
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|---------------|--------|
| `EKEventStore.requestAccess(to:completion:)` (blanket access) | `EKEventStore.requestFullAccessToEvents()` / `requestWriteOnlyAccessToEvents()` (granular scopes) | iOS 17 / macOS Sonoma (14) | The old blanket API is deprecated but still functions; the granular API is the forward-compatible choice given this project's 14.0 floor and Tahoe (26) build machine |
| Static SF Symbols (no animation) | `symbolEffect` view modifier with `.variableColor`/`.bounce`/`.pulse`/`.wiggle` | macOS 14 (Sonoma) / WWDC23 | Enables the D-05 icon-only animation requirement without any custom animation clock |
| `NSCalendarsUsageDescription`-only Info.plist convention | Additional granular `NSCalendarsFullAccessUsageDescription` key required alongside it on 14+ | macOS Sonoma (14) | Both keys should be added defensively — mirrors this project's own Bluetooth A1 precedent of a hard-required usage key discovered only via a crash |

**Deprecated/outdated:**
- `EKEventStore.requestAccess(to: .event, completion:)`: superseded by `requestFullAccessToEvents()`. Still callable but not the forward path given the project's macOS 14.0 floor.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The full `WeatherKit.WeatherCondition` case list used in the `WeatherCategory.from(_:)` mapping example | Pattern 2 (Code Examples) | A missing case silently falls into the `.cloudy` `default:` bucket — cosmetically wrong category for that condition, not a crash (fail-safe by construction) |
| A2 | `.symbolEffect` defaults to one-shot, requiring explicit `options: .repeating` for continuous animation | Pitfall 2 | If wrong (default IS continuous), the explicit `.repeating` is harmless/redundant — low risk either way |
| A3 | Both `NSCalendarsUsageDescription` AND `NSCalendarsFullAccessUsageDescription` are needed on macOS 14+/26 for the prompt to reliably appear | Pitfall 3 | If only one is actually required, adding both is harmless over-inclusion (same defensive posture as the existing Bluetooth key) |
| A4 | WeatherKit calls fail under the project's current ad-hoc ("Sign to Run Locally") local Debug signing | Summary / Pitfall 1 | If WeatherKit tolerates ad-hoc signing in some Xcode/OS combination, the recommended `project.yml` signing-team change becomes unnecessary extra setup work — but the safer assumption is to require it, since the cost of being wrong the other way (silent WeatherKit failures with no clear error) is much higher and harder to debug |
| A5 | The reconstructed `WeatherService`/`CalendarService` protocol shapes (method signatures) are illustrative, not verified against a real WeatherKit/EventKit compile | Architecture Patterns | Executor must confirm exact async/completion signatures against the real macOS 26 SDK during implementation — Swift's `async throws` idioms may differ slightly from the illustrated completion-closure wrapper shown here (chosen to match the existing `LicenseService`/`NowPlayingService` completion-closure convention in this codebase) |

## Open Questions

1. **Exact `WeatherKit.WeatherCondition` full case enumeration**
   - What we know: dozens of cases exist (clear, cloudy, rain, snow, thunderstorm variants, fog/haze, wind); WeatherKit exposes both `.condition` (enum) and `.symbolName` (Apple's own SF Symbol string) on `CurrentWeather`.
   - What's unclear: the complete authoritative case list wasn't available through the search tools used in this session.
   - Recommendation: planner should have the executor enumerate the real case list via Xcode Quick Help/autocomplete on `WeatherKit.WeatherCondition` at implementation time, write the `switch` with an exhaustive `default: .cloudy` fallback (already reflected in the Pattern 2 example), and unit-test the mapping function against the confirmed case list.

2. **Whether `weather.currentWeather.symbolName` (Apple's own suggested SF Symbol) should be used directly instead of hand-mapping to 4 custom category symbols**
   - What we know: WeatherKit exposes a ready-made `symbolName` per exact condition (dozens of possible symbol names, day/night variants).
   - What's unclear: D-06 explicitly wants only 4 coarse categories (not Apple's finer-grained symbol set) for the animation mapping — so `symbolName` is likely NOT usable directly; the phase needs its OWN 4-symbol mapping (as shown in Pattern 2/Code Examples) regardless.
   - Recommendation: use the custom 4-category mapping (`WeatherCategory.from(condition)` → one of 4 fixed SF Symbol names), not `weather.currentWeather.symbolName`, to honor D-06.

3. **Refresh cadence for weather/calendar data**
   - What we know: WeatherKit's 500k/month quota gives enormous headroom (a refresh every 15 min = ~2,880/month for one user); EventKit has no meaningful rate limit for local queries.
   - What's unclear: CONTEXT.md doesn't specify a refresh interval — this is Claude's Discretion territory not explicitly flagged in the phase's Discretion list, but material to plan.
   - Recommendation: planner should pick a simple coarse timer (e.g., 15-30 min for weather, re-query calendar on notch-expand or a similar coarse interval) — no need for anything more sophisticated at this phase's scope.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| WeatherKit capability on App ID (Apple Developer portal) | Weather fetch | ✗ (not yet enabled — must be added) | — | None; weather feature blocked without it |
| Real Developer Team signing for local Debug builds | Weather fetch (entitlement requires non-ad-hoc signing) | ✗ (project.yml currently ad-hoc "-") | — | None for WeatherKit specifically; EventKit/CoreLocation work fine ad-hoc |
| Xcode 16+ / macOS 14+ SDK (WeatherKit, EventKit granular APIs, symbolEffect) | All three externals | ✓ | Xcode 26 / Tahoe (per project memory) | — |
| macOS Location Services system toggle (System Settings) | CoreLocation | Assumed ✓ but user-controllable at the OS level, separate from the per-app prompt | — | D-01 already covers this: any non-authorized state → silent omission |

**Missing dependencies with no fallback:**
- WeatherKit App ID capability + real-team local signing — this is a one-time Apple Developer portal + `project.yml` setup step that must happen before any weather code can be tested on-device, not an implementation risk to defer.

**Missing dependencies with fallback:**
- None — EventKit and CoreLocation need only the standard usage-description Info.plist keys (no portal-side capability registration), which the project already has a working precedent for (Bluetooth, Phase 6).

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest, hosted inside the `Islet.app` target (per `IsletTests` in `project.yml`) |
| Config file | `project.yml` (XcodeGen-generated `.xcodeproj`) |
| Quick run command | `xcodebuild build -scheme Islet` (build-only gate — see note below) |
| Full suite command | Manual `Cmd-U` in Xcode (per project memory: `xcodebuild test` hangs because tests boot the full `Islet.app`, which starts `NSPanel`/`MediaRemote`/`IOBluetooth`) |

**Project memory note carried into this phase:** `xcodebuild test` is known to hang headlessly in this project because the test bundle hosts inside the full app, which boots live system-framework glue at launch. This phase adds WeatherKit/EventKit/CoreLocation glue that will make headless `xcodebuild test` even less viable (permission prompts block headlessly) — continue routing the full test run to manual Cmd-U in Xcode, and gate CI/automated commits on `xcodebuild build` succeeding, exactly as established.

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| (TBD by planner — no REQUIREMENTS.md IDs assigned yet) | `WeatherCategory.from(_:)` maps every condition case to one of 4 categories, exhaustively | unit (pure, Foundation-only) | `xcodebuild build -scheme Islet` (build gate) + manual Cmd-U for the actual assertions | ❌ Wave 0 — new `WeatherCategoryTests.swift` |
| (TBD) | `nextRelevantEvent(events:now:)` picks today's next/in-progress event, falls to tomorrow's first, else nil (D-04) | unit (pure, Foundation-only) | same as above | ❌ Wave 0 — new `CalendarGlanceTests.swift` |
| (TBD) | Weather/calendar column hidden (not error-shown) on permission denial (D-01/D-03) | manual on-device (permission prompts can't be automated headlessly) | manual Cmd-U + manual System Settings toggle | N/A — on-device UAT, mirrors existing Bluetooth/location precedent |
| (TBD) | Idle-CPU: no animation clock survives island collapse (D-04/Pitfall 5 precedent) | manual on-device (`sample`/Energy, mirrors `EqualizerBars`/`ProgressBar` precedent) | manual on-device sampling | N/A — on-device UAT only, never automated in this codebase |

### Sampling Rate
- **Per task commit:** `xcodebuild build -scheme Islet` (build gate — mirrors project memory precedent)
- **Per wave merge:** manual Cmd-U for the two new pure-seam unit test files (`WeatherCategoryTests.swift`, `CalendarGlanceTests.swift`)
- **Phase gate:** on-device UAT for permission-denial silent-omission (D-01/D-03) and idle-CPU verification (D-04/Pitfall-5 precedent) before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `IsletTests/WeatherCategoryTests.swift` — covers the pure `WeatherCategory.from(_:)` mapping (Foundation-only, no WeatherKit import needed if the enum is re-declared as a test fixture, OR import WeatherKit directly in the test target since it's a system framework with no async network call in the pure mapping function)
- [ ] `IsletTests/CalendarGlanceTests.swift` — covers the pure `nextRelevantEvent(events:now:)` selection logic using hand-built `(title:start:end:)` tuples, no `EKEvent`/EventKit import needed
- [ ] No new test-framework install needed — `IsletTests` XCTest bundle already exists and is wired into the `Islet` scheme

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | No auth surface in this phase |
| V3 Session Management | No | N/A |
| V4 Access Control | Yes | OS-level permission prompts (Location, Calendar) are the access-control boundary — app must honor denial (D-01/D-03), never bypass or nag |
| V5 Input Validation | Yes | Calendar event titles are UNTRUSTED external input (same class as the existing Bluetooth device-name precedent, T-05-01) — must be bounded with `.lineLimit(1)` + `.truncationMode(.tail)` in the SwiftUI `Text`, never interpolated into logging/shell/format strings unbounded |
| V6 Cryptography | No | No crypto surface added by this phase |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Untrusted calendar event title (arbitrary length/content, attacker could theoretically control via a shared/subscribed calendar) rendered unbounded | Denial of Service (layout break) / Information Disclosure (none here, purely cosmetic) | Same mitigation as the existing Bluetooth device-name precedent: `.lineLimit(1)` + `.truncationMode(.tail)` on the SwiftUI `Text`; SwiftUI's `Text` is already inert to format-string injection |
| Location coordinates transmitted to WeatherKit | Information Disclosure | WeatherKit is Apple's own first-party service under the existing Developer Program agreement — no additional third-party data-sharing surface introduced; standard Apple privacy posture applies (same trust boundary as any other Apple framework already in use, e.g. IOBluetooth/MediaRemote) |

## Sources

### Primary (HIGH confidence)
- Apple Developer — developer.apple.com/weatherkit — WeatherKit overview, 500,000 calls/month quota, framework vs. REST API guidance
- Apple Developer — developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.weatherkit — WeatherKit entitlement
- Apple Developer — developer.apple.com/documentation/eventkit/ekeventstore/requestfullaccesstoevents(completion:) — EventKit full-access API shape
- Open-Meteo — open-meteo.com/en/terms, open-meteo.com/en/pricing — non-commercial-only free tier confirmation (directly disqualifies it for this paid product)
- Existing codebase: `Islet/Licensing/LicenseService.swift`, `Islet/Notch/NowPlayingMonitor.swift`, `Islet/Notch/DeviceActivity.swift`, `Islet/Notch/BluetoothMonitor.swift`, `Islet/Notch/NotchPillView.swift`, `project.yml`, `Islet/Islet.entitlements`, `scripts/release.sh` — direct file reads establishing the protocol-isolation, pure-seam, controller-ownership, and idle-CPU-gating conventions this phase must follow

### Secondary (MEDIUM confidence)
- WebSearch, multiple tutorial sources (createwithswift.com, appcoda.com, nilcoalescing.com) — `.symbolEffect` default one-shot vs. `.repeating` behavior
- WebSearch, multiple sources — `NSCalendarsFullAccessUsageDescription` requirement alongside legacy `NSCalendarsUsageDescription` on macOS Sonoma+
- WebSearch — `CLLocationManager.requestLocation()` one-shot pattern for SwiftUI

### Tertiary (LOW confidence)
- Full `WeatherKit.WeatherCondition` enum case enumeration (Pattern 2 mapping) — reconstructed from partial search snippets, not a fetched authoritative list; flagged in Assumptions Log (A1) and Open Questions (#1) for executor verification via Xcode at implementation time

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — WeatherKit/EventKit/CoreLocation/SF Symbols are all well-documented first-party frameworks with clear version floors matching this project's existing 14.0 target
- Architecture: HIGH — directly mirrors three existing, working patterns already in this exact codebase (`LicenseService`, `NowPlayingService`/`NowPlayingMonitor`, `DeviceActivity.swift`)
- Pitfalls: MEDIUM — the WeatherKit signing gotcha (Pitfall 1) is HIGH confidence given the project's own current `project.yml` state; the `.symbolEffect` default-behavior and Info.plist granular-key pitfalls (2, 3) are MEDIUM confidence, corroborated by multiple secondary sources but not a directly-fetched Apple primary reference page

**Research date:** 2026-07-08
**Valid until:** ~30 days (Apple framework APIs are stable; the WeatherKit signing/entitlement setup process is the most likely thing to shift with an Xcode update)
