# Phase 38: Focus Mode HUD - Pattern Map

**Mapped:** 2026-07-17
**Files analyzed:** 9 (2 new, 5 modified, 2 test files extended)
**Analogs found:** 9 / 9

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|--------------------|------|-----------|-----------------|----------------|
| `Islet/Notch/FocusActivity.swift` (new) | model (pure seam) | transform | `Islet/Notch/PowerActivity.swift` | exact |
| `Islet/Notch/FocusModeMonitor.swift` (new) | service (system glue) | event-driven (degraded to poll — no push API exists) | `Islet/Notch/PowerSourceMonitor.swift` | role-match (polling vs. event-driven is the one structural difference, called out below) |
| `Islet/Notch/IslandResolver.swift` (edit) | service (pure reducer) | transform | itself (extend existing `ActiveTransient`/`resolve`/`TransientQueue`) | exact |
| `Islet/Notch/NotchWindowController.swift` (edit) | controller | event-driven | itself (extend existing `handlePower`/`scheduleActivityDismiss`/`handleSettingsChanged`) | exact |
| `Islet/Notch/NotchPillView.swift` (edit) | component (SwiftUI view) | request-response (render) | itself, `wings(for:)` (charging) / `deviceWings(for:)` (Bluetooth) | exact |
| `Islet/ActivitySettings.swift` (edit) | config | CRUD (UserDefaults) | itself (extend existing key/enum conventions) | exact |
| `Islet/SettingsView.swift` (edit) | component (SwiftUI view) | CRUD (toggle binding) + request-response (permission sheet) | itself, `generalSection`/`Activities` `Section`; `NotchPillView.swift`'s `.popover` (quick-add) for the explanation-surface presentation mechanism | exact (toggle) / role-match (explanation popover) |
| `IsletTests/IslandResolverTests.swift` (extend) | test | unit | itself (existing `testChargingOutranksDeviceAndMedia` etc.) | exact |
| `IsletTests/ActivitySettingsTests.swift` (extend) | test | unit | itself (existing `testMaterialStyleParsesGradient` etc.) | exact |

## Pattern Assignments

### `Islet/Notch/FocusActivity.swift` (model, transform) — NEW

**Analog:** `Islet/Notch/PowerActivity.swift` (also see `Islet/Notch/DeviceActivity.swift` for the "no system framework, pure Foundation only" discipline)

**File header / import pattern** (`PowerActivity.swift:1-21`):
```swift
import Foundation

// Phase N / REQ-ID — the PURE X→presentation seam (Pattern 1).
//
// Like NotchGeometry and NotchInteractionState, these are plain values + total
// functions importing ONLY Foundation — no system frameworks (no IOKit, AppKit, or
// SwiftUI here; that wiring lives in the Monitor file).
```
Follow verbatim for `FocusActivity.swift`: `import Foundation` only, no `Intents`/no `FileManager` — those live in `FocusModeMonitor.swift`.

**Reading struct + activity enum pattern** (`PowerActivity.swift:13-28`):
```swift
struct PowerReading: Equatable {
    let isPresent: Bool
    let isOnAC: Bool
    let isCharging: Bool
    let isCharged: Bool
    let percent: Int
}

enum ChargingActivity: Equatable {
    case charging(percent: Int)
    case full(percent: Int)
    case onBattery(percent: Int)
}
```
For Focus: a `FocusReading` (or reuse a bare `Bool`, per RESEARCH §3's `onChange: (Bool) -> Void`) and a `FocusActivity` enum with exactly the two states this phase needs (`.on` / `.off` — no named-mode payload, per REQUIREMENTS.md Out of Scope). Keep it this minimal — do not add a payload "for later."

**Total pure mapping function pattern** (`PowerActivity.swift:41-49`):
```swift
func powerActivity(from r: PowerReading) -> ChargingActivity? {
    guard r.isPresent else { return nil }
    let p = min(max(r.percent, 0), 100)
    if r.isOnAC {
        if r.isCharged { return .full(percent: p) }
        return .charging(percent: p)
    }
    return .onBattery(percent: p)
}
```
Mirror this shape for `focusActivity(from:)` — a TOTAL function, `nil`/`.off` is a legitimate "nothing to show" result, never crashes on malformed input (ties directly into RESEARCH.md's defensive-parsing requirement for `Assertions.json`: a parse failure must map to "no state change," which the CALLER in `FocusModeMonitor` should handle by not calling `onChange` at all, not by this function returning a fabricated `.off`).

---

### `Islet/Notch/FocusModeMonitor.swift` (service, event-driven/degraded-poll) — NEW

**Analog:** `Islet/Notch/PowerSourceMonitor.swift` (lifecycle shape) — note the ONE structural deviation called out in RESEARCH.md §3: PowerSourceMonitor is push/event-driven via `IOPSNotificationCreateRunLoopSource`; Focus has no push API on either detection path, so `FocusModeMonitor` degrades to `DispatchSourceTimer` polling (2-3s interval, per CONTEXT.md's Claude's Discretion note) while keeping every other convention identical.

**`@MainActor final class` + closure-init + start/stop shape** (`PowerSourceMonitor.swift:60-70`):
```swift
@MainActor
final class PowerSourceMonitor {
    private nonisolated(unsafe) var runLoopSource: CFRunLoopSource?
    private let onChange: (PowerReading) -> Void

    init(onChange: @escaping (PowerReading) -> Void) { self.onChange = onChange }

    func start() { ... }
    nonisolated func stop() { ... }
    deinit { /* does NOT call stop() — owner's deinit does, see below */ }
}
```
Copy this exact shape for `FocusModeMonitor`: `@MainActor final class`, one `onChange` closure taken in `init`, `start()`/`stop()`, `nonisolated func stop()` so `NotchWindowController`'s nonisolated deinit can call it (mirrors `PowerSourceMonitor.stop()`/`BluetoothMonitor.stop()` verbatim — see NotchWindowController.swift:2035-2045 teardown block).

**Idempotent start guard convention** (`NotchWindowController.swift:548-556`, the CALLER side, not the monitor itself):
```swift
private func startPowerMonitor() {
    guard powerMonitor == nil else { return }
    didSeedInitialPower = false
    let monitor = PowerSourceMonitor { [weak self] reading in self?.handlePower(reading) }
    powerMonitor = monitor
    monitor.start()
}
```
`startFocusModeMonitor()` in `NotchWindowController.swift` should follow this exact `guard ... == nil else { return }` idempotency pattern (Pitfall 5 in the Bluetooth analog: never double-register/double-start on a fast toggle flip).

**Defensive parsing note (NEW discipline this file introduces — no direct analog in this codebase, closest precedent is `CalendarService.swift`'s untrusted-external-data handling):** `Assertions.json`'s `storeAssertionRecords` key can be transiently absent mid-transition. Every dictionary/array access must be optional-chained; a decode failure must be treated as "no change, keep prior state" (do NOT call `onChange` at all), mirroring `readCurrentPower()`'s own defensive optional-cast discipline (`PowerSourceMonitor.swift:42-50`, "every dictionary value is read with an optional cast + a default — a missing/malformed key never force-unwraps or crashes").

**Full Disk Access "read as ground truth" pattern:** Do NOT poll `FileManager.isReadableFile(atPath:)` as a proxy for "granted" — attempt the actual `FileManager.default.contents(atPath:)` read and treat `nil` as "not granted," exactly as RESEARCH.md's Don't Hand-Roll table specifies. No existing codebase analog for this specific check (FDA is new to this phase) — this is the one place `FocusModeMonitor.swift` cannot mirror an existing pattern and must follow RESEARCH.md's Code Examples directly.

---

### `Islet/Notch/IslandResolver.swift` (pure reducer) — EDIT

**Analog:** itself — this file already contains the exact shape to extend, no external analog needed.

**`ActiveTransient` enum extension point** (`IslandResolver.swift:71-74`):
```swift
enum ActiveTransient: Equatable {
    case charging(ChargingActivity)
    case device(DeviceActivity)
}
```
Add `case focus(FocusActivity)`.

**`IslandPresentation` enum extension point** (`IslandResolver.swift:54-67`):
```swift
enum IslandPresentation: Equatable {
    ...
    case charging(ChargingActivity)                        // D-02 rank 1 transient
    case device(DeviceActivity)                             // D-02 rank 2 transient
    ...
}
```
Add `case focus(FocusActivity)` alongside `.charging`/`.device`.

**`resolve(...)`'s transient switch — THE load-bearing edit** (`IslandResolver.swift:103-107`):
```swift
switch activeTransient {                              // D-04: transient wins even over expanded
case .charging(let a): return .charging(a)           // D-02 rank 1
case .device(let d):   return .device(d)             // D-02 rank 2
case nil: break
}
```
Per RESEARCH.md §2, extend to (exact recommended form):
```swift
switch activeTransient {
case .charging(let a): return .charging(a)            // unchanged — wins collapsed AND expanded
case .device(let d):   return .device(d)              // unchanged — wins collapsed AND expanded
case .focus(let f) where !isExpanded: return .focus(f) // D-07: Focus wins ONLY when collapsed
case .focus: break                                     // D-07: expanded — falls through to the
                                                        //   isExpanded branch below unmodified
case nil: break
}
```
This is a `where`-guarded case addition to the existing exhaustive switch — no new parameter threaded through `resolve(...)`'s signature, no duplicated switch structure (matches CONTEXT.md's Claude's Discretion note exactly).

**`showsSwitcherRow(for:)` — check for exhaustiveness, likely NO change needed** (`IslandResolver.swift:83-88`): Focus never reaches the `isExpanded` cases this function checks (it only wins the collapsed pill), so this function should not need a `.focus` case — but Pitfall D in RESEARCH.md flags this as something to CONFIRM explicitly during implementation, not assume.

**`TransientQueue.removeAll(where:)` reuse for D-09 (Focus Off = silent disappearance)** (`IslandResolver.swift:260-265`, already-existing method — NO new method needed for this specific piece):
```swift
mutating func removeAll(where predicate: (ActiveTransient) -> Bool) {
    pending.removeAll(where: predicate)
    if let h = head, predicate(h) {
        head = pending.isEmpty ? nil : pending.removeFirst()
    }
}
```
Call site pattern already exists in `NotchWindowController.flushTransients(_:)` (see below) — Focus-off wiring should call `transientQueue.removeAll { if case .focus = $0 { true } else { false } }` directly (RESEARCH.md Code Examples section gives this exact snippet).

**NEW: `TransientQueue.preempt(_:)` — genuinely new method, no direct analog in this file.** The closest structural sibling is `enqueue(_:)` itself (`IslandResolver.swift:225-231`):
```swift
mutating func enqueue(_ t: ActiveTransient) -> Bool {
    if head == nil { head = t; return true }
    if head == t || pending.contains(t) { return false }
    pending.append(t)
    if pending.count > maxDepth { pending.removeFirst() }
    return false
}
```
Per RESEARCH.md §5, add an ADDITIVE new method (do not rewrite `enqueue`):
```swift
// D-08 — Charging/Device preempt an already-standing Focus head immediately (Focus has no
// dismiss timer of its own to naturally elapse and yield). Displaced Focus goes to the FRONT
// of pending so it resumes the instant the preempting transient's own dismiss fires.
mutating func preempt(_ t: ActiveTransient) -> Bool {
    guard case .focus = head else { return enqueue(t) }
    let displaced = head!
    head = t
    pending.insert(displaced, at: 0)
    return true
}
```
Used only by the controller's Charging/Device enqueue call sites (`handlePower`/device-connect handler), guarded by `if case .focus = transientQueue.head`.

---

### `Islet/Notch/NotchWindowController.swift` (controller, event-driven) — EDIT

**Analog:** itself — `handlePower`, `scheduleActivityDismiss`, `handleSettingsChanged`, `flushTransients`, `syncActivityModels` are all direct structural analogs for the equivalent Focus wiring.

**Monitor start/stop gated on Settings toggle** (`NotchWindowController.swift:445, 550-556`):
```swift
if activityEnabled(ActivitySettings.chargingKey) { startPowerMonitor() }
...
private func startPowerMonitor() {
    guard powerMonitor == nil else { return }
    didSeedInitialPower = false
    let monitor = PowerSourceMonitor { [weak self] reading in self?.handlePower(reading) }
    powerMonitor = monitor
    monitor.start()
}
```
`startFocusModeMonitor()` should follow this exactly, additionally gated on the permission-granted check (D-02: only starts if BOTH the toggle is on AND the winning detection path reports authorized/granted — RESEARCH.md §3's `start()` doc comment states this guard belongs in the CALLER, mirroring how `chargingKey`/`deviceKey` gate their monitors here).

**THE critical new piece — non-self-dismissing wiring.** Existing uniform-timer code that must NOT be reused unmodified for Focus (`NotchWindowController.swift:1546-1563`):
```swift
private func scheduleActivityDismiss() {
    dismissWorkItem?.cancel()
    let work = DispatchWorkItem { [weak self] in
        guard let self else { return }
        _ = self.transientQueue.advance()
        withAnimation(...) { self.syncActivityModels(); self.renderPresentation() }
        self.updateVisibility()
        if self.transientQueue.head != nil { self.scheduleActivityDismiss() }
    }
    dismissWorkItem = work
    DispatchQueue.main.asyncAfter(deadline: .now() + activityDuration, execute: work)
}
```
Per RESEARCH.md §4 (option 1, recommended — reuses existing machinery): when Focus becomes head via `transientQueue.enqueue(.focus(...))`, do NOT call `scheduleActivityDismiss()` for that promotion. Focus is removed from the queue only when the monitor itself reports `.off`, via the SAME `removeAll(where:)` call `flushTransients` already uses (see below) — not via the 3s timer.

**`handlePower(_:)` as the direct template for `handleFocusChange(_:)`** (`NotchWindowController.swift:1494-1536`): copy the enqueue/presentTransientChange shape, but branch the ENQUEUE call between `enqueue` (Focus arriving while nothing/lower-priority stands) and skip-the-dismiss-arm (per above) vs. `preempt` (used by `handlePower`/device-connect when Focus is currently head — D-08).

**`flushTransients(_:)` as the direct template for Focus-off handling** (`NotchWindowController.swift:1701-1717`):
```swift
private enum TransientCategory { case charging, device }
private func flushTransients(_ category: TransientCategory) {
    let oldHead = transientQueue.head
    let matches: (ActiveTransient) -> Bool = { t in
        switch (t, category) {
        case (.charging, .charging), (.device, .device): return true
        default: return false
        }
    }
    transientQueue.removeAll(where: matches)
    switch category {
    case .charging: chargingState.activity = nil
    case .device: deviceCoordinator.clearPendingBatteryPolls()
    }
    guard transientQueue.head != oldHead else { return }
    dismissWorkItem?.cancel()
    ...
}
```
Add `.focus` to `TransientCategory` and this switch — this is the EXACT mechanism D-09 ("Focus Off = silent disappearance, no separate HUD moment") should route through: the monitor's `onChange(false)` callback calls something like `flushTransients(.focus)`, which removes Focus from head/pending and re-renders — no toast, no timer, matches Charging/Device's disable-in-Settings precedent exactly.

**`handleSettingsChanged()` toggle-driven start/stop pattern** (`NotchWindowController.swift:1635-1652`):
```swift
if activityEnabled(ActivitySettings.chargingKey) {
    startPowerMonitor()
} else if powerMonitor != nil {
    powerMonitor?.stop(); powerMonitor = nil
    lastActivity = nil; didSeedInitialPower = false
    flushTransients(.charging)
}
```
Add an identical `if activityEnabled(ActivitySettings.focusKey) { startFocusModeMonitor() } else if focusModeMonitor != nil { ... flushTransients(.focus) }` block.

**`syncActivityModels()` exhaustiveness (Pitfall D)** (`NotchWindowController.swift:1568-1574`):
```swift
private func syncActivityModels() {
    switch transientQueue.head {
    case .charging: break
    case .device:   chargingState.activity = nil
    case nil:       chargingState.activity = nil
    }
}
```
Adding `.focus` to `ActiveTransient` makes this non-exhaustive — the compiler will force a `.focus` arm here (and at every other exhaustive `switch activeTransient`/`ActiveTransient` site — grep `case .charging` and `case .device` across `Islet/` before starting, per RESEARCH.md Pitfall D).

**Teardown convention** (`NotchWindowController.swift:2035-2045`): add `focusModeMonitor?.stop()` alongside the existing `powerMonitor.stop()`/`bluetoothMonitor?.stop()` calls in the controller's deinit, same nonisolated-teardown discipline.

---

### `Islet/Notch/NotchPillView.swift` (SwiftUI view, render) — EDIT

**Analog:** `wings(for:)` (Charging, `NotchPillView.swift:1958-1998`) and `deviceWings(for:)` (Bluetooth, `NotchPillView.swift:2096-...`) — both already fully cited in `38-UI-SPEC.md`'s Verification Notes, reuse verbatim per that spec.

**`wingsShape(...)` shared helper** (`NotchPillView.swift:1928-1951`):
```swift
private func wingsShape<Content: View>(
    leftWidth: CGFloat = Self.wingsSize.width / 2,
    rightWidth: CGFloat = Self.wingsSize.width / 2,
    @ViewBuilder content: () -> Content
) -> some View {
    let shape = NotchShape(topCornerRadius: 12, bottomCornerRadius: 6)
    let size = CGSize(width: leftWidth + rightWidth, height: Self.wingsSize.height)
    return shape
        .fill(islandFill)
        .matchedGeometryEffect(id: "island", in: ns)
        .frame(width: size.width, height: size.height)
        .overlay(liquidGlassEffectLayer(shape: shape, size: size, parameters: .expanded))
        .overlay(content().frame(width: size.width, height: size.height))
        .alignmentGuide(HorizontalAlignment.center) { _ in leftWidth }
        .onTapGesture { onClick() }
}
```
`focusWings(for:)` MUST call this exact helper (do not build a new shape) — matches D-10's "no new visual language" constraint.

**Charging wing content as the direct template** (`NotchPillView.swift:1958-1998`):
```swift
private func wings(for activity: ChargingActivity) -> some View {
    ...
    return wingsShape(leftWidth: ..., rightWidth: Self.wingsSize.width / 2) {
        HStack(spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isCharging ? Color.green : Color.white.opacity(0.6))
                if isCharging {
                    Text("Charging")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
            .padding(.leading, 12)
            Spacer()
            BatteryIndicator(level: percent, accent: chargingAccent)
                .padding(.trailing, 14)
        }
    }
}
```
`focusWings(for:)` (38-UI-SPEC.md's own worked example, consistent with this analog):
```swift
private func focusWings(for activity: FocusActivity) -> some View {
    wingsShape(leftWidth: Self.wingsLabelWidth / 2, rightWidth: Self.wingsSize.width / 2) {
        HStack(spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: "moon.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white)                 // D-11: FIXED, never accent-tinted
                Text("Focus")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .padding(.leading, 12)
            Spacer()
            Circle().fill(Color.green).frame(width: 8, height: 8)   // D-10: simple on/off dot, not BatteryIndicator
                .padding(.trailing, 14)
        }
    }
}
```
Constants to reuse verbatim (do not invent new sizing): `Self.wingsSize` (`NotchPillView.swift:240`), `Self.wingsLabelWidth` (`NotchPillView.swift:263`). Because the wing only ever renders in the "on" state (D-09), there is no dimmed/negative branch to build — unlike `wings(for:)`'s `isCharging ? ... : ...` ternary, `focusWings(for:)` needs no conditional at all on its own state (the resolver already guarantees `.focus` is only ever the "on" case).

**Render dispatch site** — wherever `NotchPillView.swift`'s body switches on `IslandPresentation` to pick `wings(for:)`/`deviceWings(for:)`/etc., add a `.focus(let activity): focusWings(for: activity)` arm (exact line not captured in this pass — grep `case .charging(let` in `NotchPillView.swift`'s body switch during implementation).

---

### `Islet/ActivitySettings.swift` (config) — EDIT

**Analog:** itself — the existing `chargingKey`/`deviceKey`/`WeatherStyle` enum conventions are the direct templates.

**Simple Bool toggle key convention** (`ActivitySettings.swift:14-18`):
```swift
static let chargingKey   = "activity.charging"
static let nowPlayingKey = "activity.nowPlaying"
static let deviceKey     = "activity.device"
```
Add `static let focusKey = "activity.focus"`.

**String-backed enum with corruption-safe default convention** (`ActivitySettings.swift:34-37`, `WeatherStyle`):
```swift
enum WeatherStyle: String, CaseIterable {
    case medium, large
}
static let weatherStyleKey = "weather.style"
```
For D-05's permission-status tracking (if the FDA path needs to persist "did the user already see the explanation" or similar), follow this exact enum-with-corruption-safe-default shape. NOTE: the actual live permission STATE (granted/not-granted) should be read fresh from the system (`FileManager` read attempt or `INFocusStatusCenter.authorizationStatus`) each time, mirroring `LaunchAtLogin.isEnabled`'s "the system, not the app, is the source of truth" discipline (`Islet/LaunchAtLogin.swift:9-15`) — do NOT cache "granted" in UserDefaults as the source of truth, only cache UX state like "explanation already shown once."

---

### `Islet/SettingsView.swift` (SwiftUI view) — EDIT

**Analog:** itself — `@AppStorage` toggle declaration + `Activities` `Section` (`SettingsView.swift:28-33, 197-202`).

**Toggle declaration convention** (`SettingsView.swift:28-33`):
```swift
@AppStorage(ActivitySettings.chargingKey)   private var chargingEnabled = true
@AppStorage(ActivitySettings.deviceKey)     private var deviceEnabled = true
```
Add `@AppStorage(ActivitySettings.focusKey) private var focusEnabled = false` — NOTE the default is `false` here, deliberately diverging from every existing activity toggle's `= true` default, because D-01 requires Focus to be OFF by default (opt-in only) — the ONE place this phase's Settings code must NOT copy the sibling pattern verbatim.

**`Activities` Section row convention** (`SettingsView.swift:197-202`):
```swift
Section("Activities") {
    Toggle("Charging", isOn: $chargingEnabled)
    Toggle("Now Playing", isOn: $nowPlayingEnabled)
    Toggle("Song-Change Toast", isOn: $songChangeToastEnabled)
    Toggle("Devices", isOn: $deviceEnabled)
}
```
Add `Toggle("Focus Mode HUD", isOn: $focusEnabled)` here (per `38-UI-SPEC.md`, same section — "Claude's Discretion" on exact placement already resolved by the UI-SPEC toward this section). Below the toggle, add the D-05 status-hint `Text` (small, secondary style — no direct existing analog for a live permission-status hint text in this codebase; closest precedent is the License section's status line pattern, `SettingsView.swift:9-13` area — read that section during implementation if a closer visual match is wanted).

**`.onChange` + system-settings-deep-link pattern** (`SettingsView.swift:174-193`, Launch-at-login toggle):
```swift
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
This is the closest existing analog for "toggle flip triggers a permission/system-settings flow" — mirror its `.onChange(of:)` shape for `focusEnabled`: flipping ON triggers the D-02 authorization request (only at this moment, never earlier) and presents the explanation surface.

**System-settings deep-link call convention** (`Islet/LaunchAtLogin.swift:32-36`):
```swift
static func openLoginItemsSettings() {
    SMAppService.openSystemSettingsLoginItems()
}
```
No existing `x-apple.systempreferences:` URL-scheme call exists in this codebase (LaunchAtLogin uses the typed `SMAppService` API instead) — D-03's FDA deep link is genuinely new machinery. Follow RESEARCH.md's Code Examples verbatim:
```swift
func openFullDiskAccessSettings() {
    guard let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles") else { return }
    NSWorkspace.shared.open(url)
}
```
Verify the anchor on-device before locking it in (RESEARCH.md Open Question 2).

**Explanation-surface presentation mechanism** — `.popover(isPresented:)` (`NotchPillView.swift:2560`, the quick-add "+ Add" popover) is the ONE existing `.popover`/`.sheet` precedent in this codebase:
```swift
.popover(isPresented: $isShowing) {
    quickAddContent
}
```
Reuse this exact modifier shape for the FDA/`INFocusStatusCenter` explanation surface attached to the Focus toggle row (per `38-UI-SPEC.md`'s "reuses whatever sheet/popover presentation pattern SettingsView.swift already uses elsewhere" — note this specific popover actually lives in `NotchPillView.swift`, not `SettingsView.swift`; it is still the correct SwiftUI-idiom analog to copy the modifier usage from).

---

### `IsletTests/IslandResolverTests.swift` (test) — EXTEND

**Analog:** itself, existing test method shape (`IsletTests/IslandResolverTests.swift:18-27`):
```swift
func testChargingOutranksDeviceAndMedia() {
    let r = resolve(activeTransient: .charging(.charging(percent: 47)),
                    nowPlaying: .playing(title: "Song", artist: "Artist"),
                    nowPlayingHealthy: true,
                    hasPlayedSinceLaunch: true,
                    isExpanded: true)
    XCTAssertEqual(r, .charging(.charging(percent: 47)))
}
```
New test methods to add, matching this exact call/assert shape (per RESEARCH.md's Phase Requirements → Test Map, all Wave 0 gaps):
1. `.focus` wins when `isExpanded: false`.
2. `.focus` does NOT win when `isExpanded: true` — falls through to Tray/Calendar/Weather/Home exactly as if no transient were active.
3. Focus transient survives past `activityDuration` (3s) with no Charging/Device event — this is a `TransientQueue`-level test (construct a queue, `enqueue(.focus(...))`, assert `head` is unchanged after simulating no `advance()` call — i.e. assert the CONTROLLER never calls `scheduleActivityDismiss()` for a `.focus` promotion; if the non-self-dismissal logic lives in the controller rather than pure `TransientQueue`, this may need a `NotchWindowController`-adjacent test instead, per RESEARCH.md's Test Map note).
4. Charging/Device preempts an already-standing Focus head immediately (`TransientQueue.preempt`) — assert Charging becomes head immediately and Focus is at `pending[0]`.
5. Focus-off removal — exercise `removeAll(where:)` with a `.focus` predicate, mirroring the existing Charging/Device disable-in-Settings test if one exists in this file (check the file for a `flushTransients`/removeAll precedent test before adding a new one).

---

### `IsletTests/ActivitySettingsTests.swift` (test) — EXTEND (only if a pure permission-status mapping function is introduced)

**Analog:** itself, existing test shape (`IsletTests/ActivitySettingsTests.swift:12-14, 30-34`):
```swift
func testMaterialStyleParsesGradient() {
    XCTAssertEqual(ActivitySettings.MaterialStyle(rawValue: "gradient"), .gradient)
}

func testNewKeyNames() {
    XCTAssertEqual(ActivitySettings.materialStyleKey, "theming.materialStyle")
    ...
}
```
If D-05's status-hint mapping (`Bool`/enum permission state → `"Permission needed — tap to grant"` vs. `"Active"`) is factored into a pure function (recommended per RESEARCH.md, mirrors `nowPlayingHealthGate`'s shape in `IslandResolver.swift:146-148`), add a test asserting the mapping in the same plain-XCTest style — no fakes needed, matches this file's existing "pure-logic coverage" convention.

## Shared Patterns

### Silent permission-degrade (D-04)
**Source:** `Islet/Calendar/CalendarService.swift:121-134` (`createReminder`'s Reminders-access denial) and `Islet/Location/LocationProvider.swift:25-39, 41-51` (`requestOnce`'s `.denied`/`.restricted` handling)
**Apply to:** `FocusModeMonitor.swift`'s permission-check path and the Settings toggle's `.onChange` handler.
```swift
// LocationProvider.swift:35-38 — the exact "denied/restricted → settle immediately, no retry, no nag" shape:
default:
    // D-01: denied/restricted — settle immediately, no retry, no begging dialog.
    completion(nil)
```
Focus's D-04 ("no re-ask, no nag, no periodic re-check popup... toggle stays on but the feature is inert") is this exact same convention applied to a live/polled state instead of a one-shot completion — `FocusModeMonitor` simply never starts its poll timer (or the poll silently no-ops) if permission isn't granted, and the Settings status hint (not a popup) is the only feedback surface.

### Monitor lifecycle (`@MainActor final class` + closure + start/stop + owner-driven teardown)
**Source:** `Islet/Notch/PowerSourceMonitor.swift` (whole file) and `Islet/Notch/BluetoothMonitor.swift` (whole file)
**Apply to:** `FocusModeMonitor.swift`
Both existing monitors share: `@MainActor final class`, one injected `onChange`/`onReading` closure, `nonisolated(unsafe)` internal state written only on main, `nonisolated func stop()` for the owner's nonisolated deinit, an idempotent `start()` (guarded at the CALLER in `NotchWindowController`, per `startPowerMonitor`/`startBluetoothMonitor`), and zero classification logic inside the monitor itself (that lives in the pure sibling `*Activity.swift` file). `FocusModeMonitor` must follow every one of these except the "event-driven, not polling" property, which RESEARCH.md explicitly confirms has no available alternative for Focus/DND on this OS.

### Transient queue lifecycle (enqueue → dismiss timer → advance)
**Source:** `Islet/Notch/IslandResolver.swift` `TransientQueue` struct (whole struct, lines 215-266) + `Islet/Notch/NotchWindowController.swift` `scheduleActivityDismiss`/`handlePower`/`flushTransients` (lines 1494-1563, 1701-1717)
**Apply to:** all Focus enqueue/preempt/dismiss wiring in `NotchWindowController.swift` and the new `preempt` method in `IslandResolver.swift`.
This is the single most load-bearing shared pattern in the phase — see the dedicated `IslandResolver.swift` and `NotchWindowController.swift` sections above for the full excerpts; every new piece of Focus timing logic must route through this existing machinery (extended, not bypassed), per PITFALLS.md Pitfall 6 ("every new HUD type enqueues through `IslandResolver`, no exceptions").

### Droppy-pill wing visual language (icon+label left, status right, fixed vs. accent-tinted color)
**Source:** `Islet/Notch/NotchPillView.swift` `wings(for:)` (charging, ~L1958-1998) and `deviceWings(for:)` (Bluetooth, ~L2096+), `wingsShape(...)` helper (~L1928-1951)
**Apply to:** `focusWings(for:)`
Already fully specified in `38-UI-SPEC.md`; the concrete code excerpts are in the `NotchPillView.swift` section above. Key shared constants: `Self.wingsSize` (`NotchPillView.swift:240`), `Self.wingsLabelWidth` (`NotchPillView.swift:263`).

## No Analog Found

| File/Feature | Role | Data Flow | Reason |
|---------------|------|-----------|--------|
| `x-apple.systempreferences:` deep-link call (D-03) | utility | request-response | No existing codebase call uses this URL scheme — `LaunchAtLogin.openLoginItemsSettings()` uses the typed `SMAppService.openSystemSettingsLoginItems()` API instead, a different (safer) mechanism unavailable for Full Disk Access. Use RESEARCH.md's Code Examples section directly: `NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles")!)`. |
| Permission-status hint text (D-05, "Permission needed — tap to grant" / "Active") | component (SwiftUI Text) | request-response | No existing Settings row shows a LIVE permission-state subtitle (License section's status line is the closest visual precedent but tracks trial/license state, not an OS permission) — build per `38-UI-SPEC.md`'s Typography section (11px regular, matches "existing Settings secondary-text convention"). |
| `INFocusStatusCenter` authorization path (if the spike selects it over FDA) | service | request-response | No existing codebase code calls `Intents`/`INFocusStatusCenter` at all — this would be entirely new framework usage with no internal analog; follow RESEARCH.md Architecture Patterns §1's Code Examples verbatim if the spike selects this path (low-probability per RESEARCH.md's own assessment). |

## Metadata

**Analog search scope:** `Islet/Notch/` (IslandResolver.swift, NotchWindowController.swift, NotchPillView.swift, PowerSourceMonitor.swift, BluetoothMonitor.swift, PowerActivity.swift, DeviceActivity.swift), `Islet/ActivitySettings.swift`, `Islet/SettingsView.swift`, `Islet/LaunchAtLogin.swift`, `Islet/Calendar/CalendarService.swift`, `Islet/Location/LocationProvider.swift`, `IsletTests/IslandResolverTests.swift`, `IsletTests/ActivitySettingsTests.swift`
**Files scanned:** 13 read/grepped directly, all cited above with line numbers
**Pattern extraction date:** 2026-07-17
