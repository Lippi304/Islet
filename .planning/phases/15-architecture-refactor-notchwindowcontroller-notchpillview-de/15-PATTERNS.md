# Phase 15: Architecture Refactor — Mechanical Fixes & DI Seams - Pattern Map

**Mapped:** 2026-07-08
**Files analyzed:** 9 (7 modified production files + 2 new test files)
**Analogs found:** 9 / 9

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `Islet/Notch/NotchGeometry.swift` | utility | transform (pure function) | itself — `notchFrame`/`expandedNotchFrame` already show the DRY-wrapper shape | exact (self-referential) |
| `Islet/Notch/NotchPillView.swift` (`blobShape`) | component | request-response (SwiftUI render) | `wingsShape(content:)` at `NotchPillView.swift:221-233` | exact |
| `Islet/Notch/NotchPillView.swift` (`EqualizerBars`) | component | event-driven (animation state) | itself — fix is `@State` + static factory, no external analog needed | exact (self-contained fix) |
| `Islet/Location/LocationProvider.swift` | service | request-response (one-shot callback) | `WeatherService`/`WeatherKitService` (`Islet/Weather/WeatherService.swift:21-46`) and `CalendarService`/`EventKitService` (`Islet/Calendar/CalendarService.swift:15-55`) | exact |
| `Islet/Notch/BasicOutfitState.swift` | model | event-driven (`@Published` holder) | `NowPlayingState.swift` (cited in its own header as the shape to mirror); `@MainActor` precedent = `NotchWindowController` (implicit main-thread controller) | role-match |
| `Islet/Licensing/LicenseState.swift` | service/model | CRUD (status computation) | `LicenseManager` (`KeychainLicenseStore.swift:79-119`) + `TrialManager` (`TrialManager.swift:74-101`) — both already take injected protocol-typed collaborators with `.shared` defaults | exact |
| `Islet/Notch/NotchWindowController.swift` (arbiter gap) | controller | event-driven (timer + visibility gate) | itself — `updateVisibility()` (`NotchWindowController.swift:509-552`) already computes the exact boolean needed; `startPowerMonitor`/`startBluetoothMonitor`'s idempotent-guard convention (`NotchWindowController.swift:408-417`) is the analog for early-return shape | exact (self-referential) |
| `Islet/Licensing/LicenseService.swift` + `PolarLicenseService.swift` + `SettingsView.swift` (payload threading) | service + component | request-response | `LicenseService`/`PolarLicenseService`'s existing `Result<Void, LicenseActivationError>` contract is the base to widen; `LicenseRecord` (`KeychainLicenseStore.swift:19-24`) is the analog for the new `ValidatedLicense` result shape | exact |
| `IsletTests/LicenseStateTests.swift` (new) | test | — | `IsletTests/LicenseManagerTests.swift` (fake-store pattern) | exact |

## Pattern Assignments

### `Islet/Notch/NotchGeometry.swift` (utility, transform)

**Analog:** itself — `expandedNotchFrame` and `wingsFrame` (lines 64-79)

**Current duplicate bodies** (`NotchGeometry.swift:64-79`):
```swift
func expandedNotchFrame(collapsed: CGRect, expandedSize: CGSize) -> CGRect {
    let x = collapsed.midX - expandedSize.width / 2
    let y = collapsed.maxY - expandedSize.height
    return CGRect(x: x, y: y, width: expandedSize.width, height: expandedSize.height)
}

func wingsFrame(collapsed: CGRect, wingsSize: CGSize) -> CGRect {
    let x = collapsed.midX - wingsSize.width / 2
    let y = collapsed.maxY - wingsSize.height
    return CGRect(x: x, y: y, width: wingsSize.width, height: wingsSize.height)
}
```

**Fix shape** (extract private helper, keep both public signatures as thin wrappers — every call site compiles unchanged):
```swift
private func topPinnedFrame(collapsed: CGRect, size: CGSize) -> CGRect {
    let x = collapsed.midX - size.width / 2
    let y = collapsed.maxY - size.height
    return CGRect(x: x, y: y, width: size.width, height: size.height)
}

func expandedNotchFrame(collapsed: CGRect, expandedSize: CGSize) -> CGRect {
    topPinnedFrame(collapsed: collapsed, size: expandedSize)
}

func wingsFrame(collapsed: CGRect, wingsSize: CGSize) -> CGRect {
    topPinnedFrame(collapsed: collapsed, size: wingsSize)
}
```

**Testing pattern:** `IsletTests/NotchGeometryTests.swift` already exists and tests both functions by their public signatures — no test changes needed since behavior is byte-identical; existing tests are the regression gate.

---

### `Islet/Notch/NotchPillView.swift` — `blobShape()` helper (component, request-response)

**Analog:** `wingsShape(content:)` (`NotchPillView.swift:221-233`) — the prior "Finding 12" extraction that already solved this exact problem for the three wing variants.

**Analog pattern to mirror exactly:**
```swift
private func wingsShape<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    NotchShape(topCornerRadius: 6, bottomCornerRadius: 6)   // flatter than the downward blob
        .fill(Color.black)
        .matchedGeometryEffect(id: "island", in: ns)
        .frame(width: Self.wingsSize.width, height: Self.wingsSize.height)
        .overlay(
            content()
                .frame(width: Self.wingsSize.width, height: Self.wingsSize.height)
        )
        .onTapGesture { onClick() }
}
```

**The three duplicate blob chains to collapse** (`expandedIsland` lines 194-214, `mediaExpanded` lines 476-534, `mediaUnavailable` lines 551-564) all repeat:
```swift
NotchShape(topCornerRadius: 6, bottomCornerRadius: 20)
    .fill(Color.black)
    .matchedGeometryEffect(id: "island", in: ns)
    .frame(width: Self.expandedSize.width, height: Self.expandedSize.height)
    .overlay( /* distinct per-case content */ )
    .onTapGesture { onClick() }   // mediaExpanded scopes this to its top HStack only, not the whole blob
```

**New helper shape (mirrors `wingsShape` exactly, but with `expandedSize`, radius 6/20, and an
`alignment` parameter — required because `mediaExpanded` deliberately overlays at `.top`, not
`.center`, see nuance below):**
```swift
private func blobShape<Content: View>(topCornerRadius: CGFloat, bottomCornerRadius: CGFloat,
                                       alignment: Alignment = .center,
                                       @ViewBuilder content: () -> Content) -> some View {
    NotchShape(topCornerRadius: topCornerRadius, bottomCornerRadius: bottomCornerRadius)
        .fill(Color.black)
        .matchedGeometryEffect(id: "island", in: ns)
        .frame(width: Self.expandedSize.width, height: Self.expandedSize.height)
        .overlay(alignment: alignment) { content() }
        .onTapGesture { onClick() }
}
```

**Important nuance (verified this session, lines 476-534 read in full):** `mediaExpanded` uses
`.overlay(alignment: .top) { VStack {...} }`, not default-center — its adjacent comment explains
default `.overlay` centering would leave only ~22pt top clearance against the 32pt camera band,
not enough; top-pinning makes the clearance exact. `blobShape` must take an `alignment` parameter
(default `.center`, matching `expandedIsland`/`mediaUnavailable`'s existing default centering) so
`mediaExpanded`'s call site can pass `alignment: .top` explicitly and preserve that clearance.
Separately, `mediaExpanded`'s `.onTapGesture` is scoped to the inner top `VStack`/`HStack` (line
513), NOT the whole blob shape — unlike `expandedIsland`/`mediaUnavailable` where the tap is on
the outer shape. Since `blobShape` always attaches its own `.onTapGesture` at the shape level too,
`mediaExpanded`'s call site keeps its own inner tap gesture as well — both call the identical
`onClick()` closure, so no behavior conflict, and the transport buttons stay outside both
tap-scoped regions (Finding 15's invariant).

**Explicitly excluded (per audit + CONTEXT.md D-02 nuance):** `collapsedIsland` (lines 170-184) — DEBUG-only tint fill (not `.black`), hover `.scaleEffect`, dev `.offset`. Leave as its own case.

---

### `Islet/Notch/NotchPillView.swift` — `EqualizerBars` bug fix (component, event-driven)

**Analog:** none needed — self-contained `@State`-initial-value fix; this is Swift/SwiftUI semantics, not a codebase pattern to copy.

**Current buggy shape** (`NotchPillView.swift:596-622`):
```swift
struct EqualizerBars: View {
    let isPlaying: Bool
    var tint: Color = .white
    private static let barCount = 5
    private let profiles: [(low: CGFloat, high: CGFloat, period: Double, phase: Double)]
    private let boxHeight: CGFloat = 16

    init(isPlaying: Bool, tint: Color = .white) {
        self.isPlaying = isPlaying
        self.tint = tint
        self.profiles = (0..<Self.barCount).map { _ in
            (low: CGFloat.random(in: 3...6), high: CGFloat.random(in: 10...16),
             period: Double.random(in: 0.55...1.05), phase: Double.random(in: 0...1))
        }
    }
```

**Worked fix (from CONTEXT.md, verified shape):**
```swift
@State private var profiles: [(low: CGFloat, high: CGFloat, period: Double, phase: Double)]
    = EqualizerBars.makeProfiles()

private static func makeProfiles() -> [(low: CGFloat, high: CGFloat, period: Double, phase: Double)] {
    (0..<barCount).map { _ in
        (low: CGFloat.random(in: 3...6), high: CGFloat.random(in: 10...16),
         period: Double.random(in: 0.55...1.05), phase: Double.random(in: 0...1))
    }
}
// init(isPlaying:tint:) removed — isPlaying/tint keep their memberwise/default assignment.
```

**On-device verify (D-06):** Now Playing active, watch bars ~30s — profile shape stays visually stable across parent re-renders (e.g. `nowPlaying.position` ticking).

---

### `Islet/Location/LocationProvider.swift` (service, request-response)

**Analogs:** `WeatherService`/`WeatherKitService` (`Islet/Weather/WeatherService.swift:1-46`) and `CalendarService`/`EventKitService` (`Islet/Calendar/CalendarService.swift:1-55`) — both Phase-14 siblings already establish the exact protocol-isolation + main-thread-contract convention this file is missing.

**Imports pattern** (`WeatherService.swift:1-2`):
```swift
import WeatherKit
import CoreLocation
```

**Protocol-isolation + contract-header pattern** (`WeatherService.swift:4-27`):
```swift
// Phase 14 / WEATHER-01 — the WeatherKit fetch SEAM (D-01/D-06), mirroring
// LicenseService.swift's protocol-isolation convention: a fragile/replaceable external
// is quarantined behind ONE `AnyObject` protocol with a single `final class` conformer.
//
// CONTRACT — `completion` is ALWAYS delivered on the MAIN thread (mirrors
// LicenseService.swift's file-header contract).

protocol WeatherService: AnyObject {
    func fetchCurrent(latitude: Double, longitude: Double, completion: @escaping (WeatherGlance?) -> Void)
}

final class WeatherKitService: WeatherService {
    private let service = WeatherKit.WeatherService.shared

    func fetchCurrent(latitude: Double, longitude: Double, completion: @escaping (WeatherGlance?) -> Void) {
        Task {
            do {
                // ... fetch ...
                await MainActor.run { completion(glance) }
            } catch {
                await MainActor.run { completion(nil) }
            }
        }
    }
}
```

**Current `LocationProvider`** (whole file, `LocationProvider.swift:1-55`) — concrete class, no protocol, no main-thread hop/comment on its `CLLocationManagerDelegate` callbacks (lines 33-54):
```swift
final class LocationProvider: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var completion: ((CLLocation?) -> Void)?

    func requestOnce(completion: @escaping (CLLocation?) -> Void) {
        self.completion = completion
        manager.delegate = self
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorized:
            manager.requestLocation()
        default:
            completion(nil)
        }
    }
    // locationManagerDidChangeAuthorization / didUpdateLocations / didFailWithError — no main-thread comment
}
```

**Fix shape** (add protocol per CONTEXT.md item 3, conform `LocationProvider`, add the same CONTRACT header comment as `WeatherService.swift:9-10`/`CalendarService.swift:8-9`):
```swift
// CONTRACT — `completion` is ALWAYS delivered on the MAIN thread (mirrors
// WeatherService.swift / CalendarService.swift's file-header contract). CLLocationManager
// delegate callbacks land on the main queue by default (Apple's documented behavior for a
// manager with no explicit delegateQueue) — this comment makes the implicit contract explicit,
// matching the sibling services' documented pattern.
protocol LocationService: AnyObject {
    func requestOnce(completion: @escaping (CLLocation?) -> Void)
}

final class LocationProvider: NSObject, CLLocationManagerDelegate, LocationService {
    // ... body unchanged ...
}
```

**Call site to update** (`NotchWindowController.swift:93`):
```swift
private let locationProvider = LocationProvider()
```
→ becomes (protocol-typed, mirrors `weatherService: WeatherService`/`calendarService: CalendarService` at lines 91-92):
```swift
private let locationProvider: LocationService = LocationProvider()
```

---

### `Islet/Notch/BasicOutfitState.swift` — `@MainActor` (model, event-driven)

**Analog:** `NowPlayingState.swift`'s minimal `@Published`-holder shape, cited in `BasicOutfitState.swift`'s own header as the pattern it mirrors.

**Current** (`BasicOutfitState.swift`, whole file):
```swift
final class BasicOutfitState: ObservableObject {
    @Published var weather: WeatherGlance?
    @Published var calendar: CalendarGlance?
}
```

**Fix:**
```swift
@MainActor
final class BasicOutfitState: ObservableObject {
    @Published var weather: WeatherGlance?
    @Published var calendar: CalendarGlance?
}
```

**Note:** all current writers (`NotchWindowController.refreshWeather`/`refreshCalendar`, `NotchWindowController.swift:439-450`) already run inside `WeatherService`/`CalendarService`'s `await MainActor.run { completion(...) }` blocks, so this is a zero-behavior-change annotation that makes the existing implicit guarantee compiler-checked.

---

### `Islet/Licensing/LicenseState.swift` (service/model, CRUD)

**Analogs:** `LicenseManager` (`KeychainLicenseStore.swift:79-119`) and `TrialManager` (`TrialManager.swift:74-101`) — both already take an injected protocol-typed collaborator with a `.shared`-backed default, exactly the seam `LicenseState` is missing.

**`LicenseManager`'s injection pattern** (`KeychainLicenseStore.swift:79-93`):
```swift
final class LicenseManager {
    static let shared = LicenseManager(store: KeychainLicenseStore())
    private let store: LicenseStore
    private var cachedRecord: LicenseRecord?
    private var hasCachedRecord = false

    init(store: LicenseStore) {
        self.store = store
    }
```

**`TrialManager`'s matching pattern** (`TrialManager.swift:74-101`):
```swift
final class TrialManager {
    static let shared = TrialManager(keychain: KeychainTrialStore())
    static let trialLength: TimeInterval = 3 * 86400
    private let keychain: KeychainStore
    private let defaults: UserDefaults
    private var cachedStartDate: Date?
    private var hasCachedStartDate = false

    init(keychain: KeychainStore, defaults: UserDefaults = .standard) {
        self.keychain = keychain
        self.defaults = defaults
    }
```

**Current `LicenseState`** (`LicenseState.swift:19-87`) hard-references `.shared` directly inside `status` (lines 56, 63) — see full excerpt already captured in CONTEXT.md's `<code_context>` item 4.

**Fix (worked shape from CONTEXT.md, verified against real `LicenseManager`/`TrialManager` signatures read this session):**
```swift
protocol LicenseManaging: AnyObject { var isLicensed: Bool { get } }
protocol TrialStatusProviding: AnyObject { func trialStartDate() -> Date? }
extension LicenseManager: LicenseManaging {}
extension TrialManager: TrialStatusProviding {}

final class LicenseState {
    static let shared = LicenseState()
    private let licenseManager: LicenseManaging
    private let trialManager: TrialStatusProviding

    init(licenseManager: LicenseManaging = LicenseManager.shared,
         trialManager: TrialStatusProviding = TrialManager.shared) {
        self.licenseManager = licenseManager
        self.trialManager = trialManager
    }
    // status/isEntitled/trialExpiryDate: replace `LicenseManager.shared.isLicensed` with
    // `licenseManager.isLicensed`, `TrialManager.shared.trialStartDate()` with
    // `trialManager.trialStartDate()`. No other logic changes — same #if DEBUG override,
    // same precedence order, same private init() removed only insofar as default args replace it.
}
```

**Call sites unaffected** (default args preserve `.shared` behavior): `NotchWindowController.swift:57,517,538`, `AppDelegate.swift`, `SettingsView.swift:12,115,120,175,188`.

**Testing pattern — analog is `IsletTests/LicenseManagerTests.swift` in full** (fake-collaborator + XCTest shape to copy for the new `LicenseStateTests.swift`):
```swift
import XCTest
@testable import Islet

final class LicenseManagerTests: XCTestCase {
    private final class FakeLicenseStore: LicenseStore {
        var storedRecord: LicenseRecord?
        private(set) var readCount = 0
        func read() -> LicenseRecord? { readCount += 1; return storedRecord }
        @discardableResult func write(_ record: LicenseRecord) -> Bool { storedRecord = record; return true }
        func delete() { storedRecord = nil }
    }

    func testIsLicensedFalseOnEmptyStore() {
        let fake = FakeLicenseStore()
        let manager = LicenseManager(store: fake)
        XCTAssertFalse(manager.isLicensed)
    }
    // ... etc — construct with the fake, assert on the public surface only.
}
```
For `LicenseStateTests.swift`, mirror this shape with `FakeLicenseManager: LicenseManaging` and `FakeTrialManager: TrialStatusProviding`, then pin the 4-way precedence order per D-05: DEBUG override → persisted license (`licenseManager.isLicensed`) → session activation (`sessionActivated`) → trial computation (`trialManager.trialStartDate()`).

---

### `Islet/Notch/NotchWindowController.swift` — arbiter gap fix (controller, event-driven)

**Analog:** itself — the idempotent-guard convention already used by `startPowerMonitor`/`startBluetoothMonitor` (`NotchWindowController.swift:408-417`), and `updateVisibility()` itself (lines 509-552) which already computes the exact "is currently visible" boolean via `shouldShow(...)` (line 535).

**Current unconditional timer** (`NotchWindowController.swift:424-435`):
```swift
private func startOutfitRefresh() {
    guard outfitRefreshTimer == nil else { return }
    locationProvider.requestOnce { [weak self] location in
        self?.lastLocation = location
        self?.refreshWeather()
    }
    refreshCalendar()
    outfitRefreshTimer = Timer.scheduledTimer(withTimeInterval: 900, repeats: true) { [weak self] _ in
        self?.refreshWeather()
        self?.refreshCalendar()
    }
}
```

**The visibility computation already exists inline in `updateVisibility()`** (`NotchWindowController.swift:525-539`):
```swift
let descriptors = NSScreen.screens.map { $0.descriptor }
let target = selectTargetScreen(from: descriptors)
let fullscreen = isBuiltinDisplayInFullscreenSpace(builtinUUID: currentBuiltin()?.uuid)

if shouldShow(hasTarget: target != nil,
              hideInFullscreen: hideInFullscreen,
              isFullscreen: fullscreen,
              isLicensed: licenseState.isEntitled),
   let target {
    positionAndShow(on: target)
} else {
    panel?.orderOut(nil)
    // ...
}
```

**Fix shape (per CONTEXT.md item 5):** expose the boolean `shouldShow(...)` already computes — e.g. a stored `private var isCurrentlyVisible = false` set at the top of both branches of `updateVisibility()`'s `if`/`else` (or a computed property recomputing the same `shouldShow(...)` call) — then early-return from the timer tick and from `startOutfitRefresh`'s immediate calls when not visible:
```swift
outfitRefreshTimer = Timer.scheduledTimer(withTimeInterval: 900, repeats: true) { [weak self] _ in
    guard let self, self.isCurrentlyVisible else { return }
    self.refreshWeather()
    self.refreshCalendar()
}
```
Resume path: `positionAndShow(on:)` (line 556) is the natural place to kick a refresh back on when transitioning from hidden→visible, per CONTEXT.md ("resuming on the next `positionAndShow`").

**On-device verify (D-06):** toggle fullscreen / simulate expired trial, confirm WeatherKit/EventKit calls stop firing while hidden (no change to rendering while visible).

---

### `Islet/Licensing/LicenseService.swift` + `PolarLicenseService.swift` + `SettingsView.swift` — Polar payload threading (service + component, request-response)

**Analog:** `LicenseRecord` (`KeychainLicenseStore.swift:19-24`) is the model shape to mirror for the new result type; `PolarLicenseService`'s own already-decoded-but-discarded `ValidatedLicenseKey` (`PolarLicenseService.swift:52-61`) is the source of the real data.

**Current protocol** (`LicenseService.swift:35-39`):
```swift
protocol LicenseService: AnyObject {
    func activate(key: String, completion: @escaping (Result<Void, LicenseActivationError>) -> Void)
}
```

**`PolarLicenseService`'s already-decoded, currently-discarded payload** (`PolarLicenseService.swift:52-61,104-111`):
```swift
private struct ValidatedLicenseKey: Decodable {
    let id: String
    let key: String
    let status: String        // "granted" | "revoked" | "disabled"
    let expiresAt: String?
    enum CodingKeys: String, CodingKey {
        case id, key, status
        case expiresAt = "expires_at"
    }
}
// ...
case 200:
    guard let data = data,
          let validated = try? JSONDecoder().decode(ValidatedLicenseKey.self, from: data),
          validated.status == "granted"
    else {
        return finish(.failure(.invalidKey))
    }
    return finish(.success(()))   // <-- validated.id/status/expiresAt DISCARDED here
```

**`LicenseRecord`'s Codable shape to mirror for the new public result type** (`KeychainLicenseStore.swift:19-24`):
```swift
struct LicenseRecord: Codable {
    let key: String
    let licenseID: String
    let status: String
    let validatedAt: Date
}
```

**Fix shape (per CONTEXT.md item 7):**
1. Widen `LicenseService.activate`'s `Result` success type from `Void` to a new small public type, e.g.:
```swift
struct ValidatedLicense: Equatable {
    let id: String
    let status: String
    let expiresAt: String?
}

protocol LicenseService: AnyObject {
    func activate(key: String, completion: @escaping (Result<ValidatedLicense, LicenseActivationError>) -> Void)
}
```
2. `PolarLicenseService.activate`'s 200-branch (`PolarLicenseService.swift:104-111`) returns `.success(ValidatedLicense(id: validated.id, status: validated.status, expiresAt: validated.expiresAt))` instead of `.success(())`.
3. `StubLicenseService.activate` (`LicenseService.swift:45-60`) returns a dummy success payload, e.g. `.success(ValidatedLicense(id: "", status: "granted", expiresAt: nil))`.
4. `SettingsView.activate()` (`SettingsView.swift:170-196`) — currently fabricates via `LicenseManager.shared.recordValidation(key:)` (`KeychainLicenseStore.swift:103-110`, which itself fabricates `LicenseRecord(key:, licenseID: "", status: "granted", validatedAt: Date())`). Update `recordValidation` to accept the real payload (or add a new method) so `SettingsView`'s `case .success(let validated):` threads `validated.id`/`validated.status`/`validated.expiresAt` into the persisted `LicenseRecord` instead of hardcoded `licenseID: ""`/`status: "granted"`.

**Runtime effect (per CONTEXT.md):** identical for today's users (still ends in `.licensed`) — only changes what's persisted, no new enforcement.

**Testing pattern:** `IsletTests/LicenseServiceTests.swift` and `IsletTests/PolarLicenseServiceTests.swift` already exist and exercise `activate(key:completion:)` — both need their `Result<Void, ...>` assertions updated to `Result<ValidatedLicense, ...>`, same fake-`HTTPSession` structure otherwise (see `PolarLicenseService.swift:28-30`'s `HTTPSession` protocol seam, already injectable for tests).

## Shared Patterns

### Protocol-isolation for fragile externals
**Source:** `Islet/Licensing/LicenseService.swift:35-39` (file header, the originally-cited convention), mirrored by `Islet/Weather/WeatherService.swift:21-27`, `Islet/Calendar/CalendarService.swift:15-20`
**Apply to:** `LocationProvider` (item 3) — same `protocol X: AnyObject { func y(completion: @escaping (Z?) -> Void) }` shape, `final class` conformer, controller holds the protocol type.
```swift
protocol LocationService: AnyObject {
    func requestOnce(completion: @escaping (CLLocation?) -> Void)
}
final class LocationProvider: NSObject, CLLocationManagerDelegate, LocationService { /* ... */ }
```

### Main-thread delivery contract (header comment convention)
**Source:** `Islet/Weather/WeatherService.swift:9-10`, `Islet/Calendar/CalendarService.swift:8-9`
**Apply to:** `LocationProvider.swift` (item 3) — add the identical "CONTRACT — delivered on MAIN thread" header comment above the protocol declaration.

### Injected-collaborator-with-`.shared`-default DI seam
**Source:** `Islet/Licensing/TrialManager.swift:74,98-101` and `Islet/Licensing/KeychainLicenseStore.swift:79,91-93`
**Apply to:** `LicenseState.swift` (item 4) — `static let shared = X(dep: RealDep())` + `init(dep: Protocol = RealDep.shared)`, preserving every existing call site's `.shared` usage unmodified.

### Fake-collaborator XCTest shape
**Source:** `IsletTests/LicenseManagerTests.swift` (full file, 81 lines) — private nested `Fake*` class conforming to the protocol, constructed inline per test, asserted only through the public surface.
**Apply to:** new `IsletTests/LicenseStateTests.swift` (item 4's D-05 requirement).

### Idempotent `guard ... == nil else { return }` monitor-start convention
**Source:** `Islet/Notch/NotchWindowController.swift:408-417` (`startBluetoothMonitor`), `:424-425` (`startOutfitRefresh`'s own existing guard)
**Apply to:** the visibility-gated timer-tick early-return in item 5 — same terse `guard`-based early-exit style, no new abstraction.

## No Analog Found

None — all 7 CONTEXT.md items and the 2 new test files have exact or role-match analogs already present in the codebase (this phase is explicitly a mechanical/DI-seam phase drawing on Phase 10-14 precedents).

## Metadata

**Analog search scope:** `Islet/Notch/`, `Islet/Licensing/`, `Islet/Weather/`, `Islet/Calendar/`, `Islet/Location/`, `IsletTests/`
**Files scanned (read in full or targeted ranges this session):** `NotchGeometry.swift`, `LocationProvider.swift`, `WeatherService.swift`, `CalendarService.swift`, `BasicOutfitState.swift`, `LicenseState.swift`, `LicenseService.swift`, `PolarLicenseService.swift`, `TrialManager.swift`, `KeychainLicenseStore.swift`, `NotchPillView.swift` (lines 1-40, 160-400, 460-560, 596-630), `NotchWindowController.swift` (lines 60-100, 400-565), `SettingsView.swift` (lines 1-40, 160-200), `IsletTests/LicenseManagerTests.swift`
**Pattern extraction date:** 2026-07-08
