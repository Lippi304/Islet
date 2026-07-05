# Phase 10: Trial & Lockout Gate - Pattern Map

**Mapped:** 2026-07-05
**Files analyzed:** 8 (3 new Licensing files + 2 new test files, 4 modified files, 1 modified test file)
**Analogs found:** 8 / 8

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|-----------------|---------------|
| `Islet/Licensing/TrialLogic.swift` (new) | model/utility (pure classification) | transform | `Islet/Notch/PowerActivity.swift` | exact |
| `Islet/Licensing/TrialManager.swift` (new) | service (Keychain glue) | CRUD (read/write one record) | `Islet/Notch/PowerSourceMonitor.swift` | role-match (system-glue shape); Keychain itself has no analog in repo (new subsystem) |
| `Islet/Licensing/LicenseState.swift` (new) | model/provider (`@Published` stub) | event-driven (state read by arbiter + DEBUG writer) | `Islet/ActivitySettings.swift` (key-constant + enum-holder shape) | role-match |
| `Islet/Notch/FullscreenDetector.swift` (modified) | utility (pure predicate) | transform | itself (existing file, extend in place) | exact |
| `Islet/Notch/NotchWindowController.swift` (modified) | controller/glue | event-driven | itself (existing file, extend in place) | exact |
| `Islet/AppDelegate.swift` (modified) | controller (AppKit glue) | request-response (menu/click routing) | itself (existing file, extend in place) | exact |
| `Islet/SettingsView.swift` (modified) | component (SwiftUI view) | request-response | itself (existing file, extend in place) | exact |
| `IsletTests/TrialLogicTests.swift` (new) | test | transform | `IsletTests/PowerActivityTests.swift` | exact |
| `IsletTests/TrialManagerTests.swift` (new) | test | CRUD (fake-store injection) | `IsletTests/PowerActivityTests.swift` (style only; no direct DI analog exists yet) | partial |
| `IsletTests/VisibilityDecisionTests.swift` (modified) | test | transform | itself (existing file, extend in place) | exact |

## Pattern Assignments

### `Islet/Licensing/TrialLogic.swift` (new — pure model)

**Analog:** `Islet/Notch/PowerActivity.swift` (the pure power→presentation seam, Pattern 1 in this codebase's own vocabulary)

**Imports pattern** (line 1):
```swift
import Foundation
```
Pure seams in this codebase import ONLY `Foundation` (no IOKit/AppKit/SwiftUI) — see `PowerActivity.swift:1`, `FullscreenDetector.swift` (only `CoreGraphics`, no AppKit).

**Core pattern — total pure function + doc-comment discipline** (`PowerActivity.swift` lines 1-39):
```swift
import Foundation

// Phase 3 / CHG-01 + CHG-02 — the PURE power→presentation seam (Pattern 1).
//
// Like NotchGeometry and NotchInteractionState, these are plain values + total
// functions importing ONLY Foundation — no system frameworks (no IOKit, AppKit, or
// SwiftUI here; that wiring lives in Plan 03). Tests build
// PowerReading by hand, so the riskiest classification logic ... is unit-tested in
// milliseconds. Plan 03 owns the real IOPS read ... and lifts a
// PowerReading out of the IOPS dictionary to feed in here.

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

// TOTAL pure mapping. nil == "no splash" (no readable battery → graceful no-op).
func powerActivity(from r: PowerReading) -> ChargingActivity? {
    guard r.isPresent else { return nil }
    let p = min(max(r.percent, 0), 100)
    if r.isOnAC {
        if r.isCharging { return .charging(percent: p) }
        return .full(percent: p)
    }
    return .onBattery(percent: p)
}
```

**Apply to `TrialLogic.swift`:** RESEARCH.md's own `trialStatus(startDate:now:trialLength:)` example (Architecture Patterns, Pattern 1) already follows this exact shape — `now` is always a passed-in parameter (never an internal `Date()` call), mirroring `powerActivity(from:)` taking a fully-formed `PowerReading` rather than reading IOKit itself. Use a 3-case enum per RESEARCH Open Question 2 (`.trial(daysRemaining:)` / `.trialExpired` / `.licensed` — though the `.licensed` case is really `LicenseState`'s concern, not `TrialLogic`'s; keep `TrialLogic` scoped to `.active(daysRemaining:)` / `.expired` as RESEARCH's own example shows, and let `LicenseState` layer `.licensed` on top).

**Error handling:** N/A — pure total function, no throwing, no I/O (mirrors `powerActivity(from:)` having zero error paths).

---

### `Islet/Licensing/TrialManager.swift` (new — Keychain glue)

**Analog:** `Islet/Notch/PowerSourceMonitor.swift` (the thin system-framework glue, "the ONLY file that touches a system power framework")

**Imports pattern** (lines 1-2):
```swift
import IOKit.ps
import CoreFoundation
```
For `TrialManager.swift`, mirror with:
```swift
import Foundation
import Security
```
Doc-comment convention to copy (`PowerSourceMonitor.swift` lines 1-21):
```swift
// Phase 3 / CHG-01 + CHG-02 — the THIN IOKit power glue (Plan 03).
//
// This is the ONLY file in the phase that touches a system power framework. Like
// NSScreen+Notch.swift and FullscreenSpaceProbe.swift, it is a thin system-call
// wrapper — NOT a pure fixture-tested seam. The riskiest CLASSIFICATION logic
// ... lives in the PURE PowerActivity.swift seam (Plan 01) and is unit-tested in ms;
// this glue is verified ON-DEVICE (real hardware power events can't be unit-tested).
```
Replace "IOKit power framework" with "Security framework Keychain calls" — `TrialManager.swift` should carry the equivalent note: "the ONLY file that touches `Security`/`kSecClass*` for this phase."

**Core pattern — defensive optional-cast reads, never force-unwrap** (`PowerSourceMonitor.swift` lines 26-55):
```swift
func readCurrentPower() -> PowerReading {
    guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
          let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef]
    else {
        return PowerReading(isPresent: false, isOnAC: false, isCharging: false, isCharged: false, percent: 0)
    }
    for ps in sources {
        guard let d = IOPSGetPowerSourceDescription(blob, ps)?.takeUnretainedValue() as? [String: Any]
        else { continue }
        guard (d[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType else { continue }
        // DEFENSIVE (security T-03-05): every dictionary value is read with an optional
        // cast + a default — a missing / malformed key never force-unwraps or crashes.
        let state    = d[kIOPSPowerSourceStateKey] as? String
        ...
        return PowerReading(isPresent: true, ...)
    }
    return PowerReading(isPresent: false, isOnAC: false, isCharging: false, isCharged: false, percent: 0)
}
```
Apply the same "every optional cast has a graceful nil-fallback, never crashes on malformed system data" discipline to Keychain reads — RESEARCH.md's own `KeychainTrialStore.read()`/`write()` example (Architecture Patterns Pattern 2, lines 210-254 of `10-RESEARCH.md`) already follows this: `guard status == errSecSuccess, let data = ..., let timestamp = ... else { return nil }`.

**Error handling:** Keychain calls return `OSStatus`; check `== errSecSuccess` explicitly (never assume success), matching `PowerSourceMonitor`'s `guard let ... else { return <safe-default> }` idiom rather than throwing.

**Lifecycle note:** `PowerSourceMonitor` is a class with `start()`/`stop()` + a `deinit` comment explaining WHY teardown does NOT happen in `deinit` itself (Swift 5 mode can't make deinit `@MainActor`) — `TrialManager` is simpler (no run-loop source, no C callback) so this full ceremony likely does not apply, but the "one file owns the fragile/system-specific surface" discipline (also called out in RESEARCH.md's Pattern 2 comment: "mirrors the NowPlayingMonitor precedent: one file owns the fragile/system-specific surface") is the key transferable pattern.

---

### `Islet/Licensing/LicenseState.swift` (new — stub model + DEBUG override)

**Analog:** `Islet/ActivitySettings.swift` (UserDefaults-key-constant-holder enum) + the `#if DEBUG` discipline in `NotchWindowController.swift`

**Imports pattern** (`ActivitySettings.swift` line 1):
```swift
import SwiftUI
```
(Only needed if `LicenseState` uses `@Published`/`ObservableObject` from Combine/SwiftUI; if it's a plain struct/enum + static keys like `ActivitySettings`, `import Foundation` suffices.)

**Core pattern — shared key constants + doc comment on WHY they're centralized** (`ActivitySettings.swift` lines 13-19):
```swift
enum ActivitySettings {
    // @AppStorage / UserDefaults keys — used by BOTH SettingsView and the controller (Plan 04).
    static let chargingKey   = "activity.charging"
    static let nowPlayingKey = "activity.nowPlaying"
    static let deviceKey     = "activity.device"
    static let accentIndexKey = "accentIndex"
    ...
}
```
Apply the identical shape to `LicenseState`'s DEBUG override key(s) — one enum/namespace owning the UserDefaults key string(s) so `AppDelegate`'s DEBUG menu writer and `LicenseState`'s reader never hand-type the string twice (mirrors "never redefine these strings elsewhere" comment at `ActivitySettings.swift:12`).

**DEBUG-gating pattern to mirror** (`NotchWindowController.swift` lines 231-239):
```swift
#if DEBUG
// A1 probe seam (Pitfall 1): ...
// DEBUG-only: the pointer location is NEVER logged in release (privacy / threat T-02-07).
private var didLogFirstHover = false
#endif
```
Per RESEARCH.md Pitfall 4, gate BOTH the writer (`AppDelegate`'s debug menu action) and the reader (`LicenseState`'s override lookup) behind `#if DEBUG` — not just the menu item. This is the direct analog to only compiling the entire `didLogFirstHover` probe out of Release, not just its trigger site.

**Defaulting pattern** (`ActivitySettings.swift`'s `accent(for:)` — clamp-on-read, never crash on tampered data, lines 25-30):
```swift
static func accent(for index: Int) -> Color {
    palette.indices.contains(index) ? palette[index] : palette[defaultAccentIndex]
}
```
Same defensive-default discipline applies to `LicenseState` reading a possibly-absent/malformed Keychain or UserDefaults value — always fall back to a safe default (e.g. `.trial` computed from a fresh start, never a force-unwrap).

---

### `Islet/Notch/FullscreenDetector.swift` (modified — extend `shouldShow`)

**Analog:** itself (exact current state, verified this session)

**Current state — full file** (lines 25-31):
```swift
// ISL-05 / Pattern 7 — the ONE visibility decision. Every "should the pill be
// visible right now?" input (clamshell/target from Phase 1, fullscreen from
// Phase 2) converges here. hideInFullscreen is the single gating flag (D-10):
// default true ships the hide; a future Phase-6 settings toggle flips it.
func shouldShow(hasTarget: Bool, hideInFullscreen: Bool, isFullscreen: Bool) -> Bool {
    hasTarget && !(hideInFullscreen && isFullscreen)
}
```

**Required change (per RESEARCH.md Pattern 3 / D-11):**
```swift
func shouldShow(hasTarget: Bool, hideInFullscreen: Bool, isFullscreen: Bool, isLicensed: Bool) -> Bool {
    isLicensed && hasTarget && !(hideInFullscreen && isFullscreen)
}
```
Keep the same doc-comment convention: update the "ONE visibility decision" comment to note the new `isLicensed` AND-term and cross-reference D-11/Pattern 7. This is a **breaking signature change** — every call site (production + all 6 existing tests) must be updated in the same commit.

---

### `Islet/Notch/NotchWindowController.swift` (modified — 3 integration points)

**Analog:** itself (exact current state, verified this session)

**1. `updateVisibility()` call-site extension** (lines 421-448, current state):
```swift
private func updateVisibility() {
    let descriptors = NSScreen.screens.map { $0.descriptor }
    let target = selectTargetScreen(from: descriptors)
    let fullscreen = isBuiltinDisplayInFullscreenSpace(builtinUUID: currentBuiltin()?.uuid)

    if shouldShow(hasTarget: target != nil,
                  hideInFullscreen: hideInFullscreen,
                  isFullscreen: fullscreen),
       let target {
        positionAndShow(on: target)
    } else {
        // The ONLY hide call in the file (single path).
        panel?.orderOut(nil)
        hotZone = nil
        expandedZone = nil
        pointerInZone = false
    }
}
```
Add the `isLicensed: licenseState.isEntitled` argument (see RESEARCH.md Code Examples section for the exact before/after diff, already verified against this file this session). The `else` branch (the hide path) needs ZERO changes — this is what makes D-04 ("reuse the exact same hide path") fall out for free.

**2. One-shot `DispatchWorkItem` idiom to mirror for the trial-expiry timer** (property declaration + `start()` registration + `deinit` teardown, three-part pattern already used 4x in this file):

Property declaration style (e.g. line 173, `dismissWorkItem`):
```swift
// D-09 / Pattern 5 — the ~3s one-shot auto-dismiss. A single DispatchWorkItem mirroring
// graceWorkItem (NOT a recurring timer): one wake-up then idle, so CPU stays ~0% while a
private var dismissWorkItem: DispatchWorkItem?
```

Scheduling style (lines 674-688, the closest existing "schedule + store + no recurrence" example):
```swift
dismissWorkItem?.cancel()
let work = DispatchWorkItem { [weak self] in
    ...
}
dismissWorkItem = work
DispatchQueue.main.asyncAfter(deadline: .now() + <interval>, execute: work)
```

`deinit` teardown style (lines 1067, mirrored 4x for each work item in `deinit`):
```swift
dismissWorkItem?.cancel()
```

Apply this exact 3-part idiom (property + cancel-then-reschedule + deinit cancel) for the new `trialExpiryWorkItem` — RESEARCH.md's Code Examples section already has the concrete adaptation (`scheduleTrialExpiryCheck()`), verified consistent with this file's real idiom.

**3. `#if DEBUG` gating precedent** (lines 231-239, `didLogFirstHover`) — see LicenseState section above; the same file already establishes this exact discipline for a different probe, so the DEBUG stub read/write gating in this file (if any DEBUG menu wiring touches `NotchWindowController` directly) should match.

**4. `UserDefaults.didChangeNotification` live-update observer** (lines 302-305, registration; `handleSettingsChanged()` lines 854-894, handler body) — the existing live-update mechanism the DEBUG stub toggle can piggyback on (per RESEARCH.md Architecture diagram and Assumption A3):
```swift
defaultsObserver = NotificationCenter.default.addObserver(
    forName: UserDefaults.didChangeNotification,
    object: nil, queue: .main
) { [weak self] _ in self?.handleSettingsChanged() }
```
`handleSettingsChanged()`'s body pattern (start/stop monitors based on toggle state, then re-render, then call the single `updateVisibility()`) is the template for how a license-state change should also end by calling `updateVisibility()` — never a second show/hide site.

**Error handling:** No try/catch anywhere in this file's Dispatch/AppKit code — the discipline is defensive optionals + guard-let-else with safe fallbacks (e.g. `guard let collapsedFrame = ... else { return }` at line 453), not exceptions.

---

### `Islet/AppDelegate.swift` (modified — D-05 click routing + first-launch Settings + DEBUG menu)

**Analog:** itself (exact current state, verified this session, 93 lines total)

**Current state — full menu construction + click handling** (lines 12-51):
```swift
func applicationDidFinishLaunching(_ notification: Notification) {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    if let button = statusItem.button {
        let image = NSImage(systemSymbolName: "capsule.fill", accessibilityDescription: "Islet")
        image?.isTemplate = true
        button.image = image
    }

    let menu = NSMenu()
    menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
    menu.addItem(.separator())
    menu.addItem(withTitle: "Quit Islet", action: #selector(quit), keyEquivalent: "q")
    for item in menu.items { item.target = self }
    statusItem.menu = menu

    let controller = NotchWindowController()
    controller.start()
    self.notchController = controller

    // A menu-bar agent must NOT show its Settings window on launch ...
    DispatchQueue.main.async { [weak self] in
        self?.hideSettingsWindowOnLaunch()
    }
}
```

**D-05 pattern — `NSStatusItem.menu` vs `button.action` mutual exclusivity** (RESEARCH.md Pattern 4, already a concrete adaptation of this exact file's structure):
```swift
private func applyMenuBarClickRouting(isLicensed: Bool) {
    if isLicensed {
        statusItem.menu = menu
        statusItem.button?.action = nil
    } else {
        statusItem.menu = nil
        statusItem.button?.target = self
        statusItem.button?.action = #selector(openSettings)
    }
}
```
Note `menu` is currently a local `let` inside `applicationDidFinishLaunching` (line 26) — it must be promoted to a stored property (alongside `statusItem`) so `applyMenuBarClickRouting` can reference it later.

**Pitfall 2 pattern — the `hideSettingsWindowOnLaunch()` race** (lines 43-69, current retry-loop):
```swift
private func hideSettingsWindowOnLaunch(attempt: Int = 0) {
    guard !didHideSettingsAtLaunch else { return }
    if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "settings" }) {
        window.isRestorable = false
        window.isReleasedWhenClosed = false
        window.orderOut(nil)
        didHideSettingsAtLaunch = true
    } else if attempt < 50 {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { [weak self] in
            self?.hideSettingsWindowOnLaunch(attempt: attempt + 1)
        }
    }
}
```
Per RESEARCH.md Pitfall 2 / Open Question 1, the recommended fix is a one-line guard: check `TrialManager.recordFirstLaunchIfNeeded()`'s `isFirstLaunch` return value BEFORE scheduling this hide, and skip the hide entirely on first launch (going straight to an explicit show via the existing `openSettings()` path below) rather than letting hide-then-reshow race.

**`openSettings()` reuse for both D-02 (first-launch notice) and D-05 (locked-click)** (lines 71-80):
```swift
@objc private func openSettings() {
    NSApp.activate(ignoringOtherApps: true)
    NotificationCenter.default.post(name: .openIsletSettings, object: nil)
    NSApp.windows.first { $0.identifier?.rawValue == "settings" }?
        .makeKeyAndOrderFront(nil)
}
```
Both new behaviors (first-launch auto-open, locked-click jump) should call this exact existing method — no new window-showing code needed.

**Error handling:** No throwing APIs in this file; `hideSettingsWindowOnLaunch`'s guard-based retry-until-success-or-give-up-after-N-attempts is the template for any similarly-timed "wait for the window to exist" logic.

---

### `Islet/SettingsView.swift` (modified — add trial-notice line)

**Analog:** itself (exact current state, verified this session, 88 lines total)

**Section/Form pattern to mirror** (lines 42-64, the `Section("Activities")` block):
```swift
Section("Activities") {
    Toggle("Charging", isOn: $chargingEnabled)
    Toggle("Now Playing", isOn: $nowPlayingEnabled)
    Toggle("Devices", isOn: $deviceEnabled)
    ...
}
```
And the simple `LabeledContent` row pattern (lines 66-68):
```swift
LabeledContent("Version") {
    Text(Self.versionString)
}
```
For the D-02 trial-notice line ("Your 3-day trial started — ends [date]"), the simplest fit is a `Text` row inside the existing `Form` (not necessarily inside a `Section`), following the plain `LabeledContent`/`Text` style already used for the Version row — no new Section needed for a single line, per D-02's "short line" framing. Read `licenseState` (or a computed property deriving text from it) the same way `versionString` is a computed static property.

**`@AppStorage`/`@State` reactivity pattern** (lines 4, 12-15, `.onAppear`/`.onChange` at lines 75-78):
```swift
@AppStorage(ActivitySettings.chargingKey) private var chargingEnabled = true
...
.onAppear { launchAtLogin = LaunchAtLogin.isEnabled }
.onChange(of: appearsActive) { _, active in
    if active { launchAtLogin = LaunchAtLogin.isEnabled }
}
```
If the trial-notice text needs to re-derive from `LicenseState` on each appearance (e.g. days-remaining freshness), mirror this `.onAppear`/`.onChange(of: appearsActive)` re-sync pattern rather than inventing a new refresh mechanism.

**Error handling:** N/A — SwiftUI declarative view, no try/catch; error-shaped logic (e.g. `LaunchAtLogin.set` failure at lines 34-37) uses do/catch only where a genuine throwing API is called; the trial-notice text itself is pure display of already-computed state so no error path expected here.

---

### `IsletTests/TrialLogicTests.swift` (new — pure classification tests)

**Analog:** `IsletTests/PowerActivityTests.swift`

**Imports + class declaration pattern** (lines 1-10):
```swift
import XCTest
@testable import Islet

// Phase 3 / CHG-01 + CHG-02: the PURE power→presentation seam. Like NotchGeometry
// and NotchInteractionState, powerActivity(from:) and shouldTriggerSplash(previous:next:)
// are total, framework-free functions — no IOKit, no AppKit — so the riskiest
// classification logic ... is verified deterministically by an automated agent in
// milliseconds. Plan 03 owns the real IOPS read + run-loop source and feeds
// PowerReading values in here.
final class PowerActivityTests: XCTestCase {
```

**Boundary-testing style** (lines 14-57, one test per classification branch + explicit clamp-boundary tests):
```swift
func testChargingMapsToCharging() {
    let r = PowerReading(isPresent: true, isOnAC: true, isCharging: true, isCharged: false, percent: 47)
    XCTAssertEqual(powerActivity(from: r), .charging(percent: 47))
}
...
func testPercentClampedLow() {
    let r = PowerReading(isPresent: true, isOnAC: true, isCharging: true, isCharged: false, percent: -5)
    XCTAssertEqual(powerActivity(from: r), .charging(percent: 0))
}
```
For `TrialLogicTests.swift`, mirror this exactly: one test per `TrialStatus` branch (active well within window, active at 2.99 days, expired at exactly the boundary, expired well past), each constructing `startDate`/`now` by hand (per RESEARCH.md's own Wave-0-gap note: "active at 2.99 days, expired at exactly 3.0 days").

---

### `IsletTests/TrialManagerTests.swift` (new — needs an injection seam)

**Analog:** `IsletTests/PowerActivityTests.swift` (style only) — **no direct dependency-injection analog exists in this codebase yet** (flagged below in No Analog Found). `PowerSourceMonitor` itself is NOT unit-tested (it's system-glue, verified on-device only, per its own doc comment) — this is the precedent that "thin system glue is not unit-tested directly," which argues for RESEARCH.md's own suggested seam (a `KeychainReading`/`KeychainWriting` protocol `TrialManager` takes, or testing `TrialLogic` + a fake-clock wrapper) rather than trying to unit-test real Keychain I/O.

---

### `IsletTests/VisibilityDecisionTests.swift` (modified — breaking signature update)

**Analog:** itself (exact current state, verified this session, 40 lines, 6 tests)

**Current state — full file:**
```swift
import XCTest
@testable import Islet

final class VisibilityDecisionTests: XCTestCase {

    func testTargetPresentNotFullscreenShows() {
        XCTAssertTrue(shouldShow(hasTarget: true, hideInFullscreen: true, isFullscreen: false))
    }

    func testTargetPresentFullscreenWithHideFlagHides() {
        XCTAssertFalse(shouldShow(hasTarget: true, hideInFullscreen: true, isFullscreen: true))
    }

    func testTargetPresentFullscreenWithHideFlagOffShows() {
        XCTAssertTrue(shouldShow(hasTarget: true, hideInFullscreen: false, isFullscreen: true))
    }

    func testNoTargetHidesEvenWhenNotFullscreen() {
        XCTAssertFalse(shouldShow(hasTarget: false, hideInFullscreen: true, isFullscreen: false))
    }

    func testNoTargetHidesEvenInFullscreen() {
        XCTAssertFalse(shouldShow(hasTarget: false, hideInFullscreen: true, isFullscreen: true))
    }

    func testNoTargetHidesWithHideFlagOff() {
        XCTAssertFalse(shouldShow(hasTarget: false, hideInFullscreen: false, isFullscreen: false))
    }
}
```
Every existing call must gain `isLicensed: true` (to preserve current pass/fail meaning — these tests all assume "licensed" as the implicit baseline), plus new tests where `isLicensed: false` must dominate every other combination (mirrors this file's own existing "no-target dominates" test pairs, e.g. `testNoTargetHidesEvenInFullscreen`/`testNoTargetHidesWithHideFlagOff` — same "one condition always wins" test-naming/structure convention to extend for `isLicensed`).

## Shared Patterns

### One-shot `DispatchWorkItem` idiom (applies to: `NotchWindowController.swift`'s new trial-expiry timer)
**Source:** `Islet/Notch/NotchWindowController.swift` (4 existing instances: `dismissWorkItem` ~line 173/674-688, `graceWorkItem` ~line 193, `mediaDismissWorkItem` ~line 167/1016-1031, `deviceBatteryWork` ~line 108/801-809)
**Apply to:** the new `trialExpiryWorkItem`
```swift
private var trialExpiryWorkItem: DispatchWorkItem?
// scheduling (cancel-then-reschedule):
trialExpiryWorkItem?.cancel()
let work = DispatchWorkItem { [weak self] in self?.updateVisibility() }
trialExpiryWorkItem = work
DispatchQueue.main.asyncAfter(deadline: .now() + interval, execute: work)
// deinit teardown:
trialExpiryWorkItem?.cancel()
```
Never a recurring `Timer`/polling loop — matches the codebase's stated idle-CPU-~0% discipline (RESEARCH.md Anti-Pattern, `ARCHITECTURE.md` Anti-Pattern 3).

### Single-arbiter `shouldShow(...)` AND-chain (Pattern 7 / ISL-05)
**Source:** `Islet/Notch/FullscreenDetector.swift` + `Islet/Notch/NotchWindowController.swift:updateVisibility()` (lines 421-448)
**Apply to:** the new `isLicensed` AND-term — added ONLY inside `shouldShow(...)`'s boolean algebra and the ONE call site in `updateVisibility()`. No second show/hide call site anywhere else (this exact anti-pattern was already fixed once in Phases 2/6/8/9 per RESEARCH.md).

### `#if DEBUG`-gated probes, compiled entirely out of Release (both write AND read sides)
**Source:** `Islet/Notch/NotchWindowController.swift` lines 231-239 (`didLogFirstHover`)
**Apply to:** `AppDelegate`'s DEBUG menu item (writer) AND `LicenseState`'s override-key reader — gate BOTH sides, per RESEARCH.md Pitfall 4.

### UserDefaults-key-constant-holder enum, shared verbatim between reader and writer
**Source:** `Islet/ActivitySettings.swift` lines 13-19 ("never redefine these strings elsewhere")
**Apply to:** `LicenseState`'s DEBUG override key(s) and any UserDefaults mirror key for the Keychain trial-start date.

### Defensive optional-cast reads with safe fallback, never force-unwrap
**Source:** `Islet/Notch/PowerSourceMonitor.swift` lines 42-49 (security T-03-05 comment)
**Apply to:** `TrialManager.swift`'s Keychain reads (`SecItemCopyMatching` result parsing) and `LicenseState`'s UserDefaults override reads.

### `UserDefaults.didChangeNotification` as the live-update signal
**Source:** `Islet/Notch/NotchWindowController.swift` lines 302-305 (registration) + `handleSettingsChanged()` lines 854-894 (handler body ending in `updateVisibility()`)
**Apply to:** the DEBUG stub license-state toggle (per RESEARCH.md's Architecture diagram) — reuses this exact existing observer rather than adding a second notification mechanism.

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| Keychain read/write calls specifically (`SecItemAdd`/`SecItemCopyMatching`/`SecItemDelete`) inside `TrialManager.swift` | service | CRUD | Confirmed via `grep -rln "kSecClass"` returning zero hits repo-wide (per RESEARCH.md Standard Stack) — genuinely new subsystem in this codebase, no prior Keychain code to copy from. Use RESEARCH.md's own Pattern 2 code example (`10-RESEARCH.md` lines 206-257) as the primary source instead — it is already written against this project's exact conventions (doc-comment style, `@discardableResult`, delete-then-add upsert). |
| `IsletTests/TrialManagerTests.swift`'s injection seam (fake Keychain store) | test | CRUD | No existing protocol-based DI seam for a system-framework glue file exists in this codebase — `PowerSourceMonitor`/`NowPlayingMonitor`/`BluetoothMonitor` are all verified on-device only, never unit-tested directly. RESEARCH.md's own Wave-0-gap note flags this as needing a new small seam (`KeychainReading`/`KeychainWriting` protocol or fake-clock wrapper) — this is genuinely novel within the codebase, not a copy-from-existing-file situation. |

## Metadata

**Analog search scope:** `Islet/` (all subdirectories), `IsletTests/`
**Files scanned:** `Islet/Notch/FullscreenDetector.swift`, `Islet/Notch/NotchWindowController.swift` (targeted sections: lines 1-30, 225-325, 421-450, 498-600, 674-690, 801-895, 1050-1085), `Islet/AppDelegate.swift` (full), `Islet/SettingsView.swift` (full), `Islet/ActivitySettings.swift` (full), `Islet/Notch/PowerActivity.swift` (full), `Islet/Notch/PowerSourceMonitor.swift` (full), `IsletTests/VisibilityDecisionTests.swift` (full), `IsletTests/PowerActivityTests.swift` (full)
**Pattern extraction date:** 2026-07-05
