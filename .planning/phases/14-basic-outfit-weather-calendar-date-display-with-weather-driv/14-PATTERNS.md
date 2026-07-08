# Phase 14: Basic Outfit — Weather + Calendar + Date Display - Pattern Map

**Mapped:** 2026-07-08
**Files analyzed:** 10 (6 new, 4 modified)
**Analogs found:** 10 / 10

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|--------------------|------|-----------|-----------------|----------------|
| `Islet/Weather/WeatherService.swift` | service (protocol-isolation seam) | request-response (async, permission-gated) | `Islet/Licensing/LicenseService.swift` + `Islet/Notch/NowPlayingMonitor.swift` | exact (protocol shape) |
| `Islet/Weather/WeatherCategory.swift` | utility (pure classification seam) | transform | `Islet/Notch/DeviceActivity.swift` | exact |
| `Islet/Calendar/CalendarService.swift` | service (protocol-isolation seam) | request-response (async, permission-gated) | `Islet/Notch/BluetoothMonitor.swift` + `Islet/Licensing/LicenseService.swift` | exact (shape) |
| `Islet/Calendar/CalendarGlance.swift` | utility (pure selection seam) | transform | `Islet/Notch/DeviceActivity.swift` | exact |
| `Islet/Location/LocationProvider.swift` | service (thin system-framework glue) | event-driven (delegate callback, one-shot) | `Islet/Notch/BluetoothMonitor.swift` (delegate-hop-to-main pattern) | role-match |
| `Islet/Notch/BasicOutfitState.swift` | store (`ObservableObject`) | CRUD (published state) | `NowPlayingState` / `IslandPresentationState` (in `NotchPillView.swift`/`IslandResolver.swift`) | exact |
| `Islet/Notch/NotchPillView.swift` (modified: `expandedIsland`) | component (SwiftUI view) | request-response (render only) | same file's `wings(for:)` / `deviceWings(for:)` | exact |
| `project.yml` (modified) | config | batch (build settings) | existing `INFOPLIST_KEY_NSBluetoothAlwaysUsageDescription` + `CODE_SIGN_ENTITLEMENTS` entries | exact |
| `Islet/Islet.entitlements` (modified) | config | batch (signing) | existing `com.apple.security.cs.disable-library-validation` entry | exact |
| Info.plist usage-description keys (modified via `project.yml`) | config | batch | `INFOPLIST_KEY_NSBluetoothAlwaysUsageDescription` (Phase 6/A1) | exact |

## Pattern Assignments

### `Islet/Weather/WeatherService.swift` (service, request-response)

**Analog:** `Islet/Licensing/LicenseService.swift` (protocol shape) + `Islet/Notch/NowPlayingMonitor.swift` (main-thread completion contract, `@MainActor` glue discipline)

**Protocol + single conformer pattern** (`Islet/Licensing/LicenseService.swift:35-61`):
```swift
protocol LicenseService: AnyObject {
    /// - Note: `completion` is ALWAYS delivered on the MAIN thread (contract — see file header).
    func activate(key: String, completion: @escaping (Result<Void, LicenseActivationError>) -> Void)
}

final class StubLicenseService: LicenseService {
    func activate(key: String, completion: @escaping (Result<Void, LicenseActivationError>) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // ... verdict computed ...
            completion(verdict)
        }
    }
}
```
Copy this exact shape: `protocol WeatherService: AnyObject { func fetchCurrent(latitude:longitude:completion:) }` with a `final class WeatherKitService: WeatherService` conformer. Callers (the controller) hold the **protocol type**, never the concrete class — this is the load-bearing convention (see file header comment in `LicenseService.swift:1-26` — "quarantined behind ONE `AnyObject` protocol... a one-file drop-in with ZERO protocol change").

**Async task + main-hop completion pattern** (`NowPlayingMonitor.swift:49-67`, `100-112`):
```swift
@MainActor
final class NowPlayingMonitor: NowPlayingService {
    private let onSnapshot: (TrackSnapshot?, NSImage?) -> Void
    init(onSnapshot: @escaping (TrackSnapshot?, NSImage?) -> Void, ...) { ... }
    func runHealthCheck(then setHealthy: @escaping (Bool) -> Void) {
        var settled = false
        controller.getTrackInfo { info in
            if settled { return }
            settled = true
            setHealthy(true)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if settled { return }
            settled = true
            setHealthy(false)
        }
    }
}
```
For `WeatherKitService.fetchCurrent`, use Swift concurrency (`Task { ... await MainActor.run { completion(...) } }`) exactly as sketched in RESEARCH.md Pattern 1 — this is a natural extension of the completion-closure contract already established by `LicenseService`/`NowPlayingService`, just using `async/await` instead of `DispatchQueue.main.asyncAfter` for the real WeatherKit call.

**Silent-failure / D-01 pattern** (mirrors `LicenseService.swift`'s `#if DEBUG` fail-safe default and `NowPlayingMonitor`'s `onSnapshot(nil, nil)` "no media" convention): any WeatherKit `catch` or location-denial path calls `completion(nil)` — never throws up to the view, never retries. See RESEARCH.md Pattern 1's `catch { await MainActor.run { completion(nil) } }`.

---

### `Islet/Weather/WeatherCategory.swift` (utility, transform)

**Analog:** `Islet/Notch/DeviceActivity.swift` (pure Foundation-only classification seam)

**Imports pattern** (`DeviceActivity.swift:1`):
```swift
import Foundation
```
No system-framework import in the pure seam — same discipline required here (do NOT `import WeatherKit` inside the classification switch's *logic*; the WeatherCondition type itself must be passed in from the service layer, or the enum kept in the same file with only Foundation-visible logic per RESEARCH.md's explicit call-out: "Foundation-only, no WeatherKit import needed if the enum is re-declared as a test fixture").

**Total pure mapping function pattern** (`DeviceActivity.swift:61-69`, `73-82`):
```swift
func deviceGlyph(name: String?, classMajor: UInt32) -> DeviceGlyph {
    let n = (name ?? "").lowercased()
    if n.contains("airpods pro") { return .airpodsPro }
    if n.contains("airpods max") { return .airpodsMax }
    if n.contains("airpods")     { return .airpods }
    if n.contains("beats")       { return .beats }
    if classMajor == 0x04        { return .headphones }
    return .generic     // exhaustive fallback — never crashes on garbage input
}

func deviceActivity(from r: DeviceReading) -> DeviceActivity? {
    let label = deviceLabel(name: r.name, address: r.address)
    let glyph = deviceGlyph(name: r.name, classMajor: r.classMajor)
    return r.connected
        ? .connected(name: label, glyph: glyph, battery: battery)
        : .disconnected(name: label, glyph: glyph)
}
```
Copy this exact shape for `WeatherCategory.from(_ condition: WeatherKit.WeatherCondition) -> WeatherCategory`: a `switch` with an exhaustive `default: return .cloudy` fallback bucket (never a missing-case compile error, never a crash — same "fail-safe by construction" posture as `.generic` above). RESEARCH.md Code Examples section already has the concrete switch to copy verbatim (condition case list flagged `[ASSUMED]` — verify via Xcode Quick Help before finalizing).

**Testing pattern:** `DeviceActivity.swift`'s pure functions are unit-tested by hand-constructing `DeviceReading` values with no IOBluetooth import (see file header comment lines 1-12: "Tests build DeviceReading by hand... unit-tested in milliseconds"). Mirror this for `WeatherCategoryTests.swift` — construct `WeatherCondition` cases directly (WeatherKit import is fine in the test target since it's a system framework, no network call needed for the pure mapping test) or a local fixture enum, per RESEARCH.md's Wave 0 Gaps note.

---

### `Islet/Calendar/CalendarService.swift` (service, request-response)

**Analog:** `Islet/Notch/BluetoothMonitor.swift` (system-framework glue, permission/authorization-gated) + `Islet/Licensing/LicenseService.swift` (protocol isolation)

**Protocol isolation + permission-gated fetch pattern** — combine `BluetoothMonitor`'s `@MainActor` system-glue discipline with `LicenseService`'s protocol/completion contract. RESEARCH.md's own sketch (already vetted against this codebase's conventions) is the concrete pattern to copy:
```swift
protocol CalendarService: AnyObject {
    func fetchUpcoming(completion: @escaping ([EKEvent]?) -> Void)
}

final class EventKitService: CalendarService {
    private let store = EKEventStore()
    func fetchUpcoming(completion: @escaping ([EKEvent]?) -> Void) {
        Task {
            let granted = (try? await store.requestFullAccessToEvents()) ?? false
            guard granted else { await MainActor.run { completion(nil) }; return }  // D-03
            let calendars = store.calendars(for: .event)   // D-02: ALL active calendars
            let predicate = store.predicateForEvents(
                withStart: Date(), end: Date().addingTimeInterval(2 * 24 * 3600), calendars: calendars)
            let events = store.events(matching: predicate)
            await MainActor.run { completion(events) }
        }
    }
}
```
**Untrusted-input handling** — mirror `BluetoothMonitor.swift:96-105`'s comment/discipline for `device.name` ("UNTRUSTED... passed as a plain String only, never format/shell") applied to `EKEvent.title`: pass titles through as plain `String`, bound only at render time (`.lineLimit(1)` + `.truncationMode(.tail)` in the view, per UI-SPEC.md).

---

### `Islet/Calendar/CalendarGlance.swift` (utility, transform)

**Analog:** `Islet/Notch/DeviceActivity.swift` (pure selection/classification seam, same file as WeatherCategory's analog)

**Pure selection function pattern** — mirrors `shouldShowDeviceSplash(...)` (`DeviceActivity.swift:94-105`), which is a **total function of its arguments** with an explicit `now: TimeInterval` parameter rather than an internal `Date()` read:
```swift
// DeviceActivity.swift:84-86 — the load-bearing discipline comment to replicate verbatim in intent:
// "Pure D-04 burst/debounce predicate — a total function of its arguments. NO Date()/Timer/
// clock read inside (callers pass `now`)... preserves the deterministic ms tests and the
// no-polling guarantee."
func shouldShowDeviceSplash(address: String?, connected: Bool, now: TimeInterval,
                            lastShown: [String: TimeInterval], debounce: TimeInterval,
                            suppressedAtLaunch: Set<String>) -> Bool { ... }
```
Apply the same "caller passes `now`, function never reads the clock" discipline to `nextRelevantEvent(events:now:)` (RESEARCH.md Code Examples has the concrete implementation already fitted to this codebase's conventions — copy it directly, keeping `now: Date` as an explicit parameter for the same testability reason).

---

### `Islet/Location/LocationProvider.swift` (service, event-driven)

**Analog:** `Islet/Notch/BluetoothMonitor.swift` (thin system-framework delegate wrapper, off-main-callback discipline)

**Delegate-callback + explicit main-hop pattern** (`BluetoothMonitor.swift:32-53`, `64-81`):
```swift
@MainActor
final class BluetoothMonitor: NSObject {
    private let onReading: (DeviceReading) -> Void
    init(onReading: @escaping (DeviceReading) -> Void) {
        self.onReading = onReading
        super.init()
    }
    func start() {
        guard !running else { return }   // idempotent start
        running = true
        connectToken = IOBluetoothDevice.register(forConnectNotifications: self,
                                                  selector: #selector(connected(_:device:)))
    }
    @objc private func connected(_ n: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        // CRITICAL: delivered on a non-main queue — hop explicitly before touching state.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.emit(device, connected: true)
        }
    }
}
```
`LocationProvider` should follow the same shape but as a `CLLocationManagerDelegate` (`NSObject` conformer, injected completion closure, one-shot `requestLocation()` rather than a persistent registration). RESEARCH.md's Pattern 3 code block already adapts this exact analog correctly — copy it directly:
```swift
final class LocationProvider: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var completion: ((CLLocation?) -> Void)?
    func requestOnce(completion: @escaping (CLLocation?) -> Void) {
        self.completion = completion
        manager.delegate = self
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorized: manager.requestLocation()
        default: completion(nil)   // D-01 silent omission
        }
    }
    // ... delegate callbacks call completion(...) then nil it out (one-shot) ...
}
```
Note: `CLLocationManagerDelegate` callbacks ARE delivered on the thread the manager was configured on by default (main, if created on main) — unlike IOBluetooth's off-main delegate queue — but keep the defensive main-hop discipline if any doubt surfaces on-device (same posture as `BluetoothMonitor`'s comment: "IOBluetooth delivers... on its OWN dispatch queue... NOT the main thread... explicitly hop to main").

---

### `Islet/Notch/BasicOutfitState.swift` (store, CRUD)

**Analog:** `NowPlayingState` (declared alongside `NowPlayingMonitor.swift`/`NotchPillView.swift`) and `IslandPresentationState` (`IslandResolver.swift`) — both small `@Published`-only `ObservableObject`s the controller owns and mutates, the view only observes.

**Pattern to copy** — from `NotchPillView.swift:35-42`'s usage contract:
```swift
// @ObservedObject var nowPlaying: NowPlayingState   — controller owns the instance,
// injects it into NotchPillView's init; the monitor's callback → controller mutates
// the @Published property → SwiftUI re-renders.
```
`BasicOutfitState` should be a minimal `final class BasicOutfitState: ObservableObject` with `@Published var weather: WeatherGlance?` and `@Published var calendar: CalendarGlance?` — no logic inside, purely a published data holder, exactly mirroring the `NowPlayingState`/`IslandPresentationState` convention (controller-owns-instance, injects via `@ObservedObject`, view never mutates it).

---

### `Islet/Notch/NotchPillView.swift` — `expandedIsland` (modified) (component, request-response)

**Analog:** same file's `wings(for:)` (`NotchPillView.swift:221-240`) and `deviceWings(for:)` (`272-295`) — the LEFT/`Spacer()`/RIGHT `HStack` content-composition idiom.

**Current code to replace** (`NotchPillView.swift:182-195`):
```swift
private var expandedIsland: some View {
    NotchShape(topCornerRadius: 6, bottomCornerRadius: 20)
        .fill(Color.black)
        .matchedGeometryEffect(id: "island", in: ns)
        .frame(width: Self.expandedSize.width, height: Self.expandedSize.height)
        .overlay(
            // D-05: Phase-2 placeholder only — real activity content arrives Phase 3+.
            Text(Date.now, format: .dateTime.hour().minute())
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
        )
        .onTapGesture { onClick() }
}
```
**Three-column HStack pattern to copy the shape of** (`wings(for:)`, lines 221-240):
```swift
private func wings(for activity: ChargingActivity) -> some View {
    ...
    return wingsShape {
        HStack(spacing: 0) {
            Image(systemName: "bolt.fill")
                .foregroundStyle(isCharging ? Color.green : Color.white.opacity(0.6))
                .padding(.leading, 12)
            Spacer()
            BatteryIndicator(level: percent, accent: accent)
                .padding(.trailing, 14)
        }
    }
}
```
Per UI-SPEC.md (Spacing Scale, `overlay alignment: default (centered)` not `.top`), the new `expandedIsland` overlay is `HStack(spacing: 0) { weatherColumn... ; Spacer(); centerColumn... ; Spacer(); calendarColumn... }` — RESEARCH.md's Pattern 4 code block already has the exact target shape fitted to this file's conventions (note: UI-SPEC.md corrects RESEARCH's `.padding(.top, 32)` to **no top-pin, default/centered overlay alignment** — follow UI-SPEC.md's spacing values, RESEARCH.md's structural HStack shape).

**Optional-column omission pattern** (mirrors `deviceTrailing`'s `@ViewBuilder` optional branching, `NotchPillView.swift:301-310`, and UI-SPEC.md's explicit instruction "mirroring the `if let calendarGlance` pattern already used for the media artwork's optional branches"):
```swift
@ViewBuilder
private func deviceTrailing(isConnected: Bool, battery: Int?) -> some View {
    if isConnected, let battery {
        BatteryIndicator(level: battery)
    } else {
        Image(systemName: isConnected ? "checkmark" : "xmark")
            ...
    }
}
```
Use `if let weather = outfit.weather { weatherColumn(weather) }` / `if let calendarGlance = outfit.calendar { calendarColumn(calendarGlance) }` directly inside the HStack — D-01/D-03 silent omission renders as "column simply absent," not a placeholder.

**Animated icon pattern** — new territory (no existing `symbolEffect` usage in the codebase), but the idle-CPU discipline it must satisfy is set by `EqualizerBars` (`NotchPillView.swift:500-556`):
```swift
// TIME-DRIVEN (not @State-driven) so the loop is IMMUNE to ambient withAnimation(.spring)
// transactions... TimelineView(.animation, paused: !isPlaying) ticks each frame while
// playing and STOPS entirely when paused (no clock → idle CPU ~0, D-04 / Pitfall 5).
var body: some View {
    TimelineView(.animation(paused: !isPlaying)) { context in ... }
}
```
The weather icon does NOT need this `TimelineView` machinery — per RESEARCH.md Pitfall 5, `expandedIsland` (and therefore the icon) is one case of `switch presentation` and is deallocated by SwiftUI when `presentation != .expandedIdle`, satisfying the "no clock runs when off-screen" guarantee **by construction**, same as `EqualizerBars`' `isPlaying`-gate achieves it **by explicit boolean**. Use plain `.symbolEffect(.pulse/.variableColor.iterative, options: .repeating, isActive: true)` per UI-SPEC.md's Interaction Contract table — no custom `TimelineView` needed, but the on-device `sample`/Energy verification step that validated `EqualizerBars`' gating must be repeated for this icon (inherited on-device UAT, not automatable).

---

## Shared Patterns

### Protocol Isolation for Fragile/Permission-Gated Externals
**Source:** `Islet/Licensing/LicenseService.swift:1-26` (file header) + `Islet/Notch/NowPlayingMonitor.swift:35-47`
**Apply to:** `WeatherService.swift`, `CalendarService.swift`
```swift
// "isolate all now-playing code behind one Swift protocol/service so swapping the
// implementation is a one-file change" (CLAUDE.md mandate, honored by both existing seams)
protocol X: AnyObject { func fetch(..., completion: @escaping (Result?) -> Void) }
final class RealX: X { ... }
// Controller stores `let x: X`, never `RealX` directly.
```

### Controller-Owns-Monitor Lifecycle (idempotent start / nonisolated stop)
**Source:** `Islet/Notch/NotchWindowController.swift:357-398` (`startPowerMonitor`, `startNowPlayingMonitor`, `startBluetoothMonitor`) and `:1124-1152` (`deinit`)
**Apply to:** wherever `NotchWindowController` constructs `WeatherKitService`/`EventKitService`/`LocationProvider`
```swift
private func startXMonitor() {
    guard xMonitor == nil else { return }     // idempotent — never double-register
    let m = XMonitor { [weak self] reading in self?.handleX(reading) }
    xMonitor = m
    m.start()
}
// deinit { xMonitor?.stop() }   — nonisolated stop() mirrors PowerSourceMonitor/BluetoothMonitor/NowPlayingMonitor
```
The view (`NotchPillView`) never fetches weather/calendar itself — only `NotchWindowController` does, injecting the resulting `BasicOutfitState` (per RESEARCH.md's explicit Anti-Pattern warning and CONTEXT.md's `code_context` section).

### Off-Main Callback → Explicit Main-Hop
**Source:** `Islet/Notch/BluetoothMonitor.swift:64-81` (`connected(_:device:)`, `disconnected(_:device:)`)
**Apply to:** `LocationProvider` (if `CLLocationManagerDelegate` callbacks are observed off-main on-device — verify empirically) and any WeatherKit/EventKit completion that isn't already `await MainActor.run`-wrapped.
```swift
DispatchQueue.main.async { [weak self] in
    guard let self else { return }
    self.emit(...)
}
```

### Silent Degradation on Permission Denial / Fetch Failure (D-01/D-03)
**Source:** `Islet/Licensing/LicenseService.swift:54-58` (`#if DEBUG`/`#else` fail-closed) and `Islet/Notch/NowPlayingMonitor.swift:72-73` (`guard let p = info?.payload else { self.onSnapshot(nil, nil); return }`)
**Apply to:** `WeatherKitService`, `EventKitService`, `LocationProvider` — every failure/denial path calls `completion(nil)`, never throws to the view, never retries in a tight loop (RESEARCH.md Pitfall 4).

### Pure, Foundation-Only Classification/Selection Seam
**Source:** `Islet/Notch/DeviceActivity.swift` (entire file — `deviceGlyph`, `deviceActivity(from:)`, `shouldShowDeviceSplash`)
**Apply to:** `WeatherCategory.swift`, `CalendarGlance.swift`
- No system-framework imports, only `Foundation`.
- Total functions (exhaustive `switch`/fallback, never crash on unexpected input).
- Callers pass `now`/timestamps explicitly — no internal `Date()`/clock reads — so tests are deterministic and millisecond-fast.

### Untrusted External String Rendering (V5)
**Source:** `Islet/Notch/DeviceActivity.swift:14-17` (file header) + `Islet/Notch/BluetoothMonitor.swift:96-98` (`emit` comment)
**Apply to:** `CalendarGlance`'s `title: String` (from `EKEvent.title`, a subscribed/shared calendar could contain adversarial content) — pass as plain `String` only, bound at render time with `.lineLimit(1)` + `.truncationMode(.tail)` inside the `NotchPillView.swift` `calendarColumn` (per UI-SPEC.md Interaction Contract), same posture as the existing Bluetooth device-name precedent (T-05-01).

### Info.plist Usage-Description Key Precedent
**Source:** `project.yml:50-55` (`INFOPLIST_KEY_NSBluetoothAlwaysUsageDescription`, Phase 6/A1)
**Apply to:** new `INFOPLIST_KEY_NSLocationWhenInUseUsageDescription`, `INFOPLIST_KEY_NSCalendarsUsageDescription`, `INFOPLIST_KEY_NSCalendarsFullAccessUsageDescription` entries in `project.yml`'s `Islet` target settings block:
```yaml
INFOPLIST_KEY_NSBluetoothAlwaysUsageDescription: "Islet zeigt eine kurze Mitteilung in der Notch, wenn ein Bluetooth-Gerät wie deine AirPods verbunden oder getrennt wird."
```
Same German-locale string convention, same defensive-key posture (add both legacy + granular calendar keys per RESEARCH.md Pitfall 3 — mirrors this exact Bluetooth precedent of "a hard-required usage key discovered only via a crash").

### Entitlements File Growth Pattern
**Source:** `Islet/Islet.entitlements:1-8` (currently only `com.apple.security.cs.disable-library-validation`)
**Apply to:** add `com.apple.developer.weatherkit` as a sibling `<key>`/`<true/>` pair, following the exact same flat-dict XML shape. No new file — extend the existing one.

### Ad-hoc-signing-breaks-WeatherKit Setup Gotcha (project.yml)
**Source:** `project.yml:23-30` (`CODE_SIGN_IDENTITY: "-"` base setting, comment "ad-hoc 'Sign to Run Locally' (no Team yet — D-03)") and `project.yml:64-69`'s `CODE_SIGN_ENTITLEMENTS` comment block precedent (documents a prior BLOCKER fix with a dated comment tag)
**Apply to:** this phase's Wave-0 setup task — `project.yml`'s base `CODE_SIGN_IDENTITY`/`DEVELOPMENT_TEAM` must move off ad-hoc to the real Developer Team (the credentials already wired for Phase-13 `scripts/release.sh`) for Debug builds too, or WeatherKit silently fails at runtime (RESEARCH.md Pitfall 1, HIGH confidence). Follow the existing inline-comment convention (`# BLOCKER fix (dated-id): ...`) when documenting this change.

## No Analog Found

None — all 10 files/config changes have a close, directly-applicable analog already in this codebase.

## Metadata

**Analog search scope:** `Islet/Licensing/`, `Islet/Notch/` (all monitor + view + state files), `project.yml`, `Islet/Islet.entitlements`
**Files scanned:** `LicenseService.swift`, `NowPlayingMonitor.swift`, `DeviceActivity.swift`, `BluetoothMonitor.swift`, `NotchPillView.swift`, `NotchWindowController.swift`, `IslandResolver.swift` (grep only), `project.yml`, `Islet.entitlements`
**Pattern extraction date:** 2026-07-08
