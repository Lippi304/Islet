# Phase 26: Onboarding Flow - Pattern Map

**Mapped:** 2026-07-11
**Files analyzed:** 7 (5 modified, 2 new; 1 new test file + 1 extended test file counted separately below)
**Analogs found:** 7 / 7

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|-----------------|---------------|
| `Islet/Notch/IslandResolver.swift` (MODIFIED — new `.onboarding` case + resolve() first-check) | service (pure reducer) | transform | itself — existing `resolve()`/`IslandPresentation` cases (same file) | exact |
| `Islet/Notch/OnboardingFlow.swift` (NEW, optional pure seam) | model (pure state machine) | transform | `Islet/Notch/NotchInteractionState.swift` (`InteractionPhase`/`InteractionEvent`/`nextState`) | exact |
| `Islet/Notch/NotchWindowController.swift` (MODIFIED — gate 3 permission call sites, own `currentOnboardingStep`, split `startOutfitRefresh`) | controller (AppKit glue) | event-driven | itself — existing `activityEnabled()`-gated `start()` block + `startOutfitRefresh()` | exact |
| `Islet/Notch/NotchPillView.swift` (MODIFIED — new `.onboarding` switch case + `onboardingCarousel(step)`) | component (SwiftUI view) | request-response (render) | itself — `expandedIsland` via `blobShape()` | exact |
| `Islet/AppDelegate.swift` (MODIFIED — `isFirstLaunch` branch no longer auto-opens Settings) | controller (app entry) | event-driven | itself — existing `isFirstLaunch` branch (lines 77-89) | exact |
| `Islet/ActivitySettings.swift` (MODIFIED — add `onboardingCompletedKey`) or new `OnboardingSettings.swift` | config (key namespace) | CRUD (persisted flag) | `Islet/ActivitySettings.swift` (existing key-namespace enum) | exact |
| `IsletTests/OnboardingFlowTests.swift` (NEW) | test | transform | `IsletTests/IslandResolverTests.swift` (pure-reducer test shape) | exact |
| `IsletTests/IslandResolverTests.swift` (EXTENDED — `testOnboardingOutranksEverything`) | test | transform | itself — existing test methods | exact |

## Pattern Assignments

### `Islet/Notch/IslandResolver.swift` (service, transform)

**Analog:** itself — `resolve()` and `IslandPresentation` (same file, lines 17-54)

**IslandPresentation enum — add a case here, do not build a parallel enum** (lines 17-24):
```swift
enum IslandPresentation: Equatable {
    case idle                                              // collapsed, nothing to show
    case charging(ChargingActivity)                        // D-02 rank 1 transient
    case device(DeviceActivity)                            // D-02 rank 2 transient
    case nowPlayingWings(NowPlayingPresentation)           // D-02 rank 3 ambient (collapsed glance)
    case nowPlayingExpanded(NowPlayingPresentation, healthy: Bool) // D-12 expanded media / "nicht verfügbar"
    case expandedIdle                                      // expanded, healthy, nothing playing (date/time)
    // ADD: case onboarding(OnboardingStep)
}
```

**resolve() — the single arbiter, add onboarding as the VERY FIRST branch** (lines 34-54):
```swift
func resolve(activeTransient: ActiveTransient?,
             nowPlaying: NowPlayingPresentation,
             nowPlayingHealthy: Bool,
             hasPlayedSinceLaunch: Bool,
             isExpanded: Bool) -> IslandPresentation {
    switch activeTransient {                              // D-04: transient wins even over expanded
    case .charging(let a): return .charging(a)           // D-02 rank 1
    case .device(let d):   return .device(d)             // D-02 rank 2
    case nil: break
    }
    if isExpanded {
        if !nowPlayingHealthy { return .nowPlayingExpanded(nowPlaying, healthy: false) } // D-12
        if nowPlaying != .none { return .nowPlayingExpanded(nowPlaying, healthy: true) }
        return .expandedIdle
    }
    let ambient = nowPlayingLaunchGate(hasPlayedSinceLaunch: hasPlayedSinceLaunch, nowPlaying: nowPlaying)
    if ambient != .none { return .nowPlayingWings(ambient) }   // D-02 ambient yield (rank 3)
    return .idle
}
```
Add a new `onboardingStep: OnboardingStep?` parameter and check it as the **very first line of the function body**, before the `switch activeTransient` block, so a forced-flow onboarding session structurally can never be pre-empted by charging/device (D-09's "once started, always reaches Done"). This is a total pure function — no AppKit/SwiftUI import, matching the file header's own discipline ("imports ONLY Foundation").

**Error handling / degrade pattern:** N/A — this is a total pure reducer, no error states, mirrors `songChangeToastGate`'s single-purpose gate style (lines 87-89).

---

### `Islet/Notch/OnboardingFlow.swift` (NEW, model — pure state machine)

**Analog:** `Islet/Notch/NotchInteractionState.swift` (full file read — 45 lines)

**Imports pattern** (lines 1-2):
```swift
import Foundation
import CoreGraphics
```
For the onboarding seam, `import Foundation` only is correct (no CoreGraphics needed unless step carries geometry).

**Core pure-reducer pattern** (lines 8-29, verbatim structure to mirror):
```swift
enum InteractionPhase: Equatable { case collapsed, hovering, expanded }
enum InteractionEvent: Equatable { case pointerEntered, pointerExited, clicked, graceElapsed, dragEntered }

func nextState(_ current: InteractionPhase, _ event: InteractionEvent) -> InteractionPhase {
    switch (current, event) {
    case (.collapsed, .pointerEntered): return .hovering
    case (.hovering,  .pointerExited):  return .hovering
    case (.hovering,  .graceElapsed):   return .collapsed
    case (.hovering,  .clicked):        return .expanded
    case (.collapsed, .clicked):        return .expanded
    default:                            return current     // idempotent no-ops
    }
}
```
**Recommended shape for `OnboardingFlow.swift`:**
```swift
enum OnboardingStep: Equatable { case welcome, trialLicenseBuy, permissions, done }
enum OnboardingEvent: Equatable { case next, back }

func nextOnboardingStep(_ current: OnboardingStep, _ event: OnboardingEvent) -> OnboardingStep {
    switch (current, event) {
    case (.welcome, .next):         return .trialLicenseBuy
    case (.trialLicenseBuy, .next): return .permissions
    case (.trialLicenseBuy, .back): return .welcome
    case (.permissions, .next):     return .done
    case (.permissions, .back):     return .trialLicenseBuy
    default:                        return current   // .done has no .next; .welcome has no .back
    }
}
```
Per the Security Domain's Pitfall 3 note (malformed step index): since this is an `enum`, not an `Int` index, there is no out-of-range case to clamp — this sidesteps the defensive-clamp concern `ActivitySettings.accent(for:)` (lines 33-35) needed for its `Int`-keyed palette. Prefer the enum shape over a raw `Int` step counter for exactly this reason.

**ObservableObject holder pattern** (lines 33-45, mirror if the controller needs a `@Published` step — NOT required if `NotchWindowController` already owns a plain `@Published var currentOnboardingStep` itself, see NotchWindowController section below):
```swift
final class NotchInteractionState: ObservableObject {
    @Published var phase: InteractionPhase = .collapsed
    @Published var collapsedNotchSize: CGSize?
    var isExpanded: Bool { phase == .expanded }
    var isHovering: Bool { phase == .hovering || phase == .expanded }
}
```

**Testing pattern:** see `OnboardingFlowTests.swift` section below.

---

### `Islet/Notch/NotchWindowController.swift` (controller, event-driven)

**Analog:** itself — the existing `activityEnabled()`-gated block inside `start()` (lines 380-397) and `startOutfitRefresh()` (lines 492-506)

**Imports pattern:** unchanged — file already imports `AppKit`, `SwiftUI`, `Combine` as needed; no new imports required for the onboarding gate itself.

**Existing gate pattern to mirror for D-01** (lines 380-397, exact current code):
```swift
if activityEnabled(ActivitySettings.chargingKey) { startPowerMonitor() }
if activityEnabled(ActivitySettings.nowPlayingKey) { startNowPlayingMonitor() }
if activityEnabled(ActivitySettings.deviceKey) { startBluetoothMonitor() }   // ← gate this too (Bluetooth)
startOutfitRefresh()                                                         // ← gate this too (Location + Calendar)
```
```swift
// activityEnabled() itself (lines 441-443) — the exact "read a UserDefaults bool,
// default true when absent" idiom the new onboarding-completed gate should mirror
// (but default FALSE for onboarding, not true — see Shared Patterns below):
private func activityEnabled(_ key: String) -> Bool {
    UserDefaults.standard.object(forKey: key) as? Bool ?? true
}
```

**startOutfitRefresh() — MUST be split for D-02's independent per-row Grant buttons** (lines 492-506, exact current code, read verbatim):
```swift
private func startOutfitRefresh() {
    guard outfitRefreshTimer == nil else { return }
    locationProvider.requestOnce { [weak self] location in            // ← Location permission trigger
        self?.lastLocation = location
        self?.refreshWeather()
    }
    refreshCalendar()                                                  // ← Calendar permission trigger
    outfitRefreshTimer = Timer.scheduledTimer(withTimeInterval: 900, repeats: true) { [weak self] _ in
        guard let self, self.isCurrentlyVisible else { return }
        self.refreshWeather()
        self.refreshCalendar()
    }
}
```
Split this into a `startLocationOnce()` (wraps just the `locationProvider.requestOnce` call) and keep `refreshCalendar()` (already its own function at lines 517-521) independently callable — the Permissions screen's Bluetooth row already has `startBluetoothMonitor()` (lines 477-485) as its own independently-callable function; Location and Calendar need the same treatment. The 900s timer arm can stay inside `startOutfitRefresh()`, called once onboarding reaches `.done` (or immediately on later launches, unchanged).

**startBluetoothMonitor() — the exact idempotent-start pattern already correct for the Permissions Bluetooth row, reuse as-is** (lines 477-485):
```swift
private func startBluetoothMonitor() {
    guard bluetoothMonitor == nil else { return }
    deviceCoordinator.started(at: Date())
    let bt = BluetoothMonitor { [weak self] reading in self?.deviceCoordinator.handle(reading) }
    bluetoothMonitor = bt
    bt.start()
}
```

**Click-through pattern — DO NOT touch `syncClickThrough()`'s interactive VALUE** (lines 903-917, read verbatim, CR-01 regression risk):
```swift
private func syncClickThrough() {
    let interactive: Bool
    if interaction.isExpanded {
        interactive = visibleContentZone()?.contains(lastPointerLocation) ?? false
    } else {
        interactive = pointerInZone
    }
    panel?.ignoresMouseEvents = !interactive
}
```
Force `interaction.phase = .expanded` for the whole onboarding session instead — this existing branch then handles onboarding clickability with **zero diff to this function**. See Shared Patterns / Anti-Pattern below.

**Grace-timer pin pattern — mirror `isDraggingShelfItem`'s guard** (lines 921-930, read verbatim):
```swift
private func handleHoverExit() {
    withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
        interaction.phase = nextState(interaction.phase, .pointerExited)
    }
    let work = DispatchWorkItem { [weak self] in
        guard let self else { return }
        guard !self.isDraggingShelfItem else { return }   // ADD a parallel: guard !self.isOnboardingActive else { return }
        // ...
    }
    graceWorkItem = work
    DispatchQueue.main.asyncAfter(deadline: .now() + graceDelay, execute: work)
}
```

**positionAndShow() panel-sizing union — extend only if the onboarding content doesn't fit 360×144** (lines 681-690, read verbatim):
```swift
let expandedFrame = expandedNotchFrame(collapsed: collapsedFrame,
                                       expandedSize: CGSize(width: expandedSize.width,
                                                             height: expandedSize.height + NotchPillView.shelfRowHeight))
let wings = wingsFrame(collapsed: collapsedFrame, wingsSize: wingsSize)
let panelFrame = expandedFrame.union(wings)   // ← add .union(onboardingFrame) here IF a 3rd size constant is needed
```

**Error/silent-degrade pattern (D-03) — mirror `LocationProvider.requestOnce`'s completion contract:** each permission row's Grant button calls the existing function; on denial the existing completion closures already settle `nil`/silently (see Shared Patterns below) — no new error handling needed in the controller, just read the resulting state into the row's UI.

---

### `Islet/Notch/NotchPillView.swift` (component, request-response/render)

**Analog:** itself — `expandedIsland` via `blobShape()` (lines 251-311)

**Imports pattern:** unchanged (`SwiftUI` only, already imported at file top).

**Body switch — add the new case in the existing single-arbiter switch** (lines 184-199, read verbatim):
```swift
switch presentation {
case .charging(let a):
    wings(for: a)
case .device(let d):
    deviceWings(for: d)
case .nowPlayingWings(let p):
    mediaWingsOrToast(p)
case .nowPlayingExpanded(let p, true):
    mediaExpanded(p, art: nowPlaying.artwork)
case .nowPlayingExpanded(_, false):
    mediaUnavailable
case .expandedIdle:
    expandedIsland
case .idle:
    collapsedIsland
// ADD: case .onboarding(let step): onboardingCarousel(step)
}
```

**Core composition pattern — `expandedIsland` via `blobShape()`, the exact template for `onboardingCarousel(step)`** (lines 251-266, read verbatim):
```swift
private var expandedIsland: some View {
    blobShape(topCornerRadius: 6, bottomCornerRadius: 32, shelfItems: shelfViewState.items) {
        HStack(spacing: 0) {
            if let weather = outfit.weather {
                weatherColumn(weather)
            }
            Spacer()
            centerColumn
            Spacer()
            if let calendarGlance = outfit.calendar {
                calendarColumn(calendarGlance)
            }
        }
        .padding(.horizontal, 16)
    }
}
```
`onboardingCarousel(step)` should follow this exact shape: call `blobShape(topCornerRadius: 6, bottomCornerRadius: 32, shelfItems: [])` (always empty shelf per D-06) with a `@ViewBuilder` closure that switches on `step` internally to render welcome/trial-license-buy/permissions/done content plus Next/Back buttons at the bottom corners (per the Droppy reference).

**blobShape() — the shared shape/material/morph helper itself, read verbatim, DO NOT reinvent** (lines 286-311):
```swift
private func blobShape<Content: View>(topCornerRadius: CGFloat,
                                       bottomCornerRadius: CGFloat,
                                       alignment: Alignment = .center,
                                       shelfItems: [ShelfItem],
                                       @ViewBuilder content: () -> Content) -> some View {
    let hasShelf = !shelfItems.isEmpty
    let height = Self.expandedSize.height + (hasShelf ? Self.shelfRowHeight : 0)
    return NotchShape(topCornerRadius: topCornerRadius, bottomCornerRadius: bottomCornerRadius)
        .fill(Self.islandMaterial)
        .matchedGeometryEffect(id: "island", in: ns)
        .frame(width: Self.expandedSize.width, height: height)
        .overlay(alignment: .top) {
            VStack(spacing: 0) {
                content()
                    .frame(width: Self.expandedSize.width, height: Self.expandedSize.height, alignment: alignment)
                if hasShelf {
                    shelfRow(shelfItems)
                        .transition(.opacity)
                }
            }
        }
        .onTapGesture { onClick() }
}
```
**Important:** `blobShape`'s trailing `.onTapGesture { onClick() }` toggles collapse/expand on ANY tap in empty space — for the onboarding carousel this is almost certainly wrong (a stray tap on the card background must not collapse the forced flow). The Next/Back/Grant buttons inside the content closure will correctly intercept their own taps (SwiftUI `Button` beats an ancestor `.onTapGesture`, same precedent noted in `expandedIsland`'s own header comment about `mediaExpanded`'s button row, lines 210-220), but plan for whether `onboardingCarousel` needs its own non-`blobShape` variant that omits the ancestor tap-to-collapse, OR relies on D-09's "no early exit" meaning an accidental collapse-tap during onboarding is actually harmless (the resolver's onboarding-first check re-shows onboarding on the next render regardless of `isExpanded`). Flag this as a planner decision — Wave 0 open question, not decided here.

**expandedSize constant** (line 122):
```swift
static let expandedSize = CGSize(width: 360, height: 144)
```

---

### `Islet/AppDelegate.swift` (controller, event-driven)

**Analog:** itself — the existing `isFirstLaunch` branch (lines 77-89, read verbatim)

**Current code to replace:**
```swift
if isFirstLaunch {
    didHideSettingsAtLaunch = true
    DispatchQueue.main.async { [weak self] in
        self?.openSettings()
    }
} else {
    DispatchQueue.main.async { [weak self] in
        self?.hideSettingsWindowOnLaunch()
    }
}
```
Per RESEARCH.md's architecture diagram, this branch must stop auto-opening Settings on first launch — instead let `NotchWindowController.start()`'s resolver render `.onboarding(.welcome)` (D-08: no auto-open of Settings). The `else` branch (`hideSettingsWindowOnLaunch()`) is very likely now the ONLY branch needed for both first-launch and returning-launch cases, since onboarding lives in the notch, not Settings. `didHideSettingsAtLaunch`'s existing retry-until-window-exists logic (lines 100-112) stays unchanged.

**`openSettings()` — reused as-is for the D-05/D-07 forward hop to license entry / permission re-grant** (lines 131-140, read verbatim):
```swift
@objc private func openSettings() {
    NSApp.activate(ignoringOtherApps: true)
    NotificationCenter.default.post(name: .openIsletSettings, object: nil)
    NSApp.windows.first { $0.identifier?.rawValue == "settings" }?
        .makeKeyAndOrderFront(nil)
}
```
The onboarding carousel's "Enter License Key" button calls this exact same private method (or a small public wrapper) — no new bridge needed.

**`isFirstLaunch` source (line 29):**
```swift
let isFirstLaunch = TrialManager.shared.recordFirstLaunchIfNeeded()
```
This stays untouched (D-04) — it is the initial trigger only; the resolver's `.onboarding` branch is driven by the separate persisted `"onboarding.completed"` flag (see Shared Patterns), not by `isFirstLaunch` directly, so a mid-flow quit/relaunch does not re-trigger from a now-`false` `isFirstLaunch`.

---

### `Islet/ActivitySettings.swift` (config, CRUD)

**Analog:** itself — the existing key-namespace enum (lines 13-23, read verbatim)

```swift
enum ActivitySettings {
    static let chargingKey   = "activity.charging"
    static let nowPlayingKey = "activity.nowPlaying"
    static let songChangeToastKey = "activity.songChangeToast"
    static let deviceKey     = "activity.device"
    static let accentIndexKey = "accentIndex"
    static let hideInFullscreenKey = "notch.hideInFullscreen"
    // ADD: static let onboardingCompletedKey = "onboarding.completed"
    // ...
}
```
Add `onboardingCompletedKey` directly to this existing enum (matching the file's own stated purpose: "the shared key namespace between SettingsView and the controller") rather than creating a separate `OnboardingSettings.swift` — there is only one new key, not enough surface to justify a new file (YAGNI; a second file only pays off if onboarding grows several more persisted keys).

**Read pattern — mirror `activityEnabled(_:)`'s shape but with a FALSE default** (`NotchWindowController.swift` lines 441-443):
```swift
private func activityEnabled(_ key: String) -> Bool {
    UserDefaults.standard.object(forKey: key) as? Bool ?? true   // default TRUE (existing keys)
}
// New onboarding gate must default FALSE when absent (not this same helper) —
// UserDefaults.standard.object(forKey: ActivitySettings.onboardingCompletedKey) as? Bool ?? false
```

**Write pattern — mirror `SettingsView.activate()`'s nudge-write** (`SettingsView.swift` lines 217-218):
```swift
UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "license.activationNudge")
```
On reaching `.done` → Finish: `UserDefaults.standard.set(true, forKey: ActivitySettings.onboardingCompletedKey)`.

---

### `IsletTests/OnboardingFlowTests.swift` (NEW, test)

**Analog:** `IsletTests/IslandResolverTests.swift` (lines 1-27, read verbatim)

```swift
import XCTest
@testable import Islet

final class IslandResolverTests: XCTestCase {
    func testChargingOutranksDeviceAndMedia() {
        let r = resolve(activeTransient: .charging(.charging(percent: 47)),
                        nowPlaying: .playing(title: "Song", artist: "Artist"),
                        nowPlayingHealthy: true,
                        hasPlayedSinceLaunch: true,
                        isExpanded: true)
        XCTAssertEqual(r, .charging(.charging(percent: 47)))
    }
    // ...
}
```
`OnboardingFlowTests.swift` should follow this exact shape: `import XCTest` + `@testable import Islet`, one `XCTestCase` per pure function, asserting `nextOnboardingStep(current, event)` transitions and `resolve(..., onboardingStep: .welcome, ...)` outranking every other branch (mirroring `testChargingOutranksDeviceAndMedia`'s "outranks" naming convention). No mocks/fixtures needed — pure value in, pure value out.

---

## Shared Patterns

### Permission silent-degrade (D-03)
**Source:** `Islet/Location/LocationProvider.swift` lines 25-39, `Islet/Calendar/CalendarService.swift` lines 25-54, `Islet/Notch/BluetoothMonitor.swift` lines 55-62
**Apply to:** the Permissions screen's 3 Grant-button handlers
```swift
// LocationProvider.requestOnce — D-01 silent degrade, the pattern D-03 explicitly mirrors:
func requestOnce(completion: @escaping (CLLocation?) -> Void) {
    self.completion = completion
    manager.delegate = self
    switch manager.authorizationStatus {
    case .notDetermined:
        manager.requestWhenInUseAuthorization()
    case .authorizedAlways, .authorized:
        manager.requestLocation()
    default:
        completion(nil)   // denied/restricted — settle immediately, no retry, no nag dialog
    }
}
```
```swift
// EventKitService.fetchUpcoming — same silent-degrade shape, async/await version:
func fetchUpcoming(completion: @escaping (CalendarGlance?) -> Void) {
    Task {
        let granted = (try? await store.requestFullAccessToEvents()) ?? false
        guard granted else {
            await MainActor.run { completion(nil) }   // denied — settle nil, no retry
            return
        }
        // ...
    }
}
```
Each Permissions-row Grant button calls the SAME existing function (`locationProvider.requestOnce`, `calendarService.fetchUpcoming` via `refreshCalendar()`, `bluetoothMonitor.start()` via `startBluetoothMonitor()`) — never a second/duplicate permission-request call. The row's "not granted" quiet state is read from the completion closure settling nil/false, no new error dialog.

### Single-arbiter presentation extension
**Source:** `Islet/Notch/IslandResolver.swift` (whole file)
**Apply to:** `IslandResolver.swift`, `NotchPillView.swift`
Every existing island presentation was added as a new `IslandPresentation` case handled inside `resolve()` — never a parallel state machine or a second `if`-chain in the view. Onboarding follows the identical extension shape.

### CR-01 click-through discipline
**Source:** `Islet/Notch/NotchWindowController.swift` lines 903-917
**Apply to:** `NotchWindowController.swift`
The interactive VALUE inside `if interaction.isExpanded` must stay pure `visibleContentZone()`-derived — never OR a new `isOnboardingActive` flag into that boolean. Force `interaction.phase = .expanded` for the onboarding session instead so the existing branch handles it with zero diff (see NotchWindowController Pattern Assignment above).

### App-owned persisted flag (not Keychain)
**Source:** `Islet/ActivitySettings.swift` (key namespace) + `NotchWindowController.swift` `activityEnabled(_:)` (lines 441-443)
**Apply to:** the new `"onboarding.completed"` flag
Plain `UserDefaults`/`@AppStorage` boolean, NOT `TrialManager`'s Keychain-backed pattern (onboarding is a UX gate, not a security/anti-tampering gate — see Security Domain in RESEARCH.md).

### Settings reuse, zero new validation logic (D-05, D-10)
**Source:** `Islet/SettingsView.swift` lines 173-180 (license entry), lines 67-86 (Launch-at-Login toggle), `Islet/LaunchAtLogin.swift` (whole file)
**Apply to:** the onboarding "Enter License Key" hop (via `.openIsletSettings`) and the Done screen's inline Launch-at-Login toggle
```swift
// SettingsView.swift lines 173-180 — reused via Settings hop, NOT duplicated inline:
@ViewBuilder private var licenseEntry: some View {
    TextField("Enter your license key", text: $enteredKey)
        .frame(maxWidth: .infinity)
    Button("Activate") { activate() }
        .disabled(activationPhase == .validating
                  || enteredKey.trimmingCharacters(in: .whitespaces).isEmpty)
    statusLine
}
```
```swift
// SettingsView.swift lines 67-86 — near-verbatim copy for the Done screen's own @State toggle:
Toggle("Launch Islet at login", isOn: $launchAtLogin)
    .onChange(of: launchAtLogin) { _, on in
        do {
            let result = try LaunchAtLogin.set(on)
            if on && LaunchAtLogin.requiresApproval {
                launchAtLogin = true
                LaunchAtLogin.openLoginItemsSettings()
            } else {
                launchAtLogin = result
            }
        } catch {
            launchAtLogin = LaunchAtLogin.isEnabled
        }
    }
```

### NotchPanel focus-safety hard lock (D-07 constraint, read-only — do not modify)
**Source:** `Islet/Notch/NotchPanel.swift` lines 35-36
```swift
override var canBecomeKey: Bool { false }
override var canBecomeMain: Bool { false }
```
This is why license-key text entry cannot live in the notch-hosted carousel — confirmed unchanged, load-bearing since Phase 1/2/23.

## No Analog Found

None — every file in scope has a strong same-file or same-role existing analog; this phase is 100% extension of established patterns, per RESEARCH.md's own framing ("a pure application of the codebase's own existing patterns to a new presentation case").

## Metadata

**Analog search scope:** `Islet/`, `Islet/Notch/`, `Islet/Location/`, `Islet/Calendar/`, `Islet/Licensing/`, `IsletTests/`
**Files scanned (read this session):** `AppDelegate.swift`, `IslandResolver.swift`, `SettingsView.swift`, `LaunchAtLogin.swift`, `ActivitySettings.swift`, `NotchPanel.swift`, `IsletApp.swift`, `NotchWindowController.swift` (targeted ranges: start/positionAndShow/syncClickThrough), `NotchPillView.swift` (targeted range: body/expandedIsland/blobShape), `LocationProvider.swift`, `BluetoothMonitor.swift` (partial), `CalendarService.swift`, `NotchInteractionState.swift`, `IslandResolverTests.swift` (partial), `TrialManager.swift` (grep only)
**Pattern extraction date:** 2026-07-11
