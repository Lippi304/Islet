# Phase 16: NotchWindowController Device Coordinator Extraction - Pattern Map

**Mapped:** 2026-07-08
**Files analyzed:** 5 (2 new source files, 1 modified source file, 1 new test file, 1 new planning artifact)
**Analogs found:** 5 / 5

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|--------------------|------|-----------|-----------------|---------------|
| `Islet/Notch/ActivityCoordinator.swift` (NEW) | protocol / DI seam | event-driven | `Islet/Licensing/LicenseState.swift:23-32` (`LicenseManaging`/`TrialStatusProviding` protocols) | role-match (narrow protocol seam, not a controller/service) |
| `Islet/Notch/DeviceCoordinator.swift` (NEW) | service (stateful orchestration/coordinator) | event-driven | `Islet/Notch/BluetoothMonitor.swift` (closure-injected `@MainActor` class, `nonisolated(unsafe)` teardown) | exact (same closure-init + nonisolated-teardown shape; body content comes verbatim from `NotchWindowController.swift:859-976`) |
| `Islet/Notch/NotchWindowController.swift` (MODIFIED — delete 9 fields/3 methods, rewire 6 call sites) | controller | event-driven | itself (in-place edit); call-site rewiring pattern mirrors the existing `powerMonitor`/`nowPlayingMonitor` toggle-off blocks in `handleSettingsChanged` (lines 1002-1031) | exact (surgical edit of an existing controller, not a fresh file) |
| `IsletTests/DeviceCoordinatorTests.swift` (NEW) | test | request-response (pure assertions against constructed state) | `IsletTests/LicenseStateTests.swift` (DI-seam fakes) + `IsletTests/IslandResolverTests.swift` (exercise a real, non-faked value type directly) | exact (two-analog composite — DI-seam pattern from one, direct-struct-exercise pattern from the other) |
| `.planning/phases/16-.../16-HUMAN-UAT.md` (NEW, optional per Open Question 2) | config/doc (manual verification checklist) | n/a | `.planning/phases/06-priority-resolver-settings-v1-ship/06-HUMAN-UAT.md` | exact (identical frontmatter + Tests/Summary/Gaps structure) |

## Pattern Assignments

### `Islet/Notch/ActivityCoordinator.swift` (protocol, event-driven)

**Analog:** `Islet/Licensing/LicenseState.swift:19-32`

**Narrow protocol + extension-conformance pattern** (lines 19-32):
```swift
// Phase 15 / P15-ITEM4 — DI seam mirroring TrialManager/LicenseManager's own
// protocol-typed collaborator pattern. These extensions keep LicenseManager.swift
// and TrialManager.swift untouched; the protocols exist solely so LicenseState's
// precedence logic is testable with fakes instead of only on-device.
protocol LicenseManaging: AnyObject {
    var isLicensed: Bool { get }
}

protocol TrialStatusProviding: AnyObject {
    func trialStartDate() -> Date?
}

extension LicenseManager: LicenseManaging {}
extension TrialManager: TrialStatusProviding {}
```

**Apply this shape but note the key difference:** `LicenseManaging`/`TrialStatusProviding` are protocols the *dependencies* conform to (injected collaborators). `ActivityCoordinator` is the reverse — `DeviceCoordinator` itself conforms to it (per RESEARCH.md's shape, `@MainActor protocol ActivityCoordinator { associatedtype Reading; func handle(_ reading: Reading); func activityPromoted() }`). Keep it to exactly these two methods (D-02) — do not add `reset()`/`cancelPendingWork()` to the protocol; those stay concrete-only methods on `DeviceCoordinator` (see RESEARCH.md's Open Question 1 recommendation).

---

### `Islet/Notch/DeviceCoordinator.swift` (service/coordinator, event-driven)

**Analog:** `Islet/Notch/BluetoothMonitor.swift` (full file, 158 lines) — the closest structural sibling: `@MainActor final class`, closure-injected at init, `nonisolated(unsafe)` state + `nonisolated func` teardown callable from the controller's `nonisolated deinit`.

**Class shape + closure-injected init pattern** (`BluetoothMonitor.swift:32-53`):
```swift
@MainActor
final class BluetoothMonitor: NSObject {
    private nonisolated(unsafe) var connectToken: IOBluetoothUserNotification?
    private nonisolated(unsafe) var disconnectTokens: [String: IOBluetoothUserNotification] = [:]
    private nonisolated(unsafe) var running = false
    private let onReading: (DeviceReading) -> Void

    init(onReading: @escaping (DeviceReading) -> Void) {
        self.onReading = onReading
        super.init()
    }
```
`DeviceCoordinator` is NOT an `NSObject` (no `@objc` selector targets needed) — drop `: NSObject` / `super.init()`, otherwise mirror the shape: `@MainActor final class DeviceCoordinator`, closures stored as `private let` for the reach-back dependencies (per RESEARCH.md's recommended closure-based DI: `presentTransientChange`, `renderPresentation`, queue read/write, `battery(forAddress:)`).

**`nonisolated(unsafe)` + `nonisolated func` teardown pattern** (`BluetoothMonitor.swift:150-156`, cross-checked identical in `PowerSourceMonitor.swift:62-97`):
```swift
private nonisolated(unsafe) var connectToken: IOBluetoothUserNotification?
// ...
nonisolated func stop() {
    connectToken?.unregister()
    connectToken = nil
    disconnectTokens.values.forEach { $0.unregister() }
    disconnectTokens.removeAll()
    running = false
}
```
Apply identically to `deviceBatteryWork`/`pollingAddress`: store both `nonisolated(unsafe)`, expose `nonisolated func cancelPendingWork()` (or similar name) so `NotchWindowController`'s `nonisolated deinit` can call it synchronously — RESEARCH.md explicitly rules out a `Task { @MainActor in ... }` wrapper here (could run after the object is gone).

**Core extraction target — move verbatim from `NotchWindowController.swift:859-976`** (already fully quoted in RESEARCH.md's "Exact Extraction Target" section; re-quoting the two shorter methods here for direct copy-paste):

`triggerDeviceBatteryRefreshIfPromoted()` (`NotchWindowController.swift:935-940`):
```swift
private func triggerDeviceBatteryRefreshIfPromoted() {
    let (match, remaining) = matchPendingBatteryPoll(pendingDeviceBatteryPolls, promoted: transientQueue.head)
    pendingDeviceBatteryPolls = remaining
    guard let match else { return }
    scheduleDeviceBatteryRefresh(address: match.address)
}
```
Reads `transientQueue.head` — the coordinator needs a `queueHead: () -> ActiveTransient?` closure (read-only reach-back), not a copy of the queue (it's a `struct`/value type per `IslandResolver.swift:98`).

The 9 fields (verbatim from `NotchWindowController.swift:107-154`, already quoted in full in RESEARCH.md's "Exact Extraction Target" section) move into `DeviceCoordinator` unchanged except `deviceBatteryWork`/`pollingAddress` gain `nonisolated(unsafe)` per the teardown pattern above.

**Don't hand-roll — call into these existing pure seams, do not reimplement:**
- `deviceActivity(from:)` / `shouldShowDeviceSplash(...)` — `Islet/Notch/DeviceActivity.swift:73-105` (already pure, already unit-tested in `DeviceActivityTests.swift`)
- `matchPendingBatteryPoll(_:promoted:)` — `Islet/Notch/IslandResolver.swift:79-90`
- `PendingBatteryPoll` struct — `Islet/Notch/IslandResolver.swift:66-69`

**The shared triplet `DeviceCoordinator` must call back into (not fork its own copy)** — `NotchWindowController.swift:502-508`:
```swift
private func presentTransientChange() {
    withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
        renderPresentation()
    }
    updateVisibility()
    scheduleActivityDismiss()
}
```
`handleDevice`'s enqueue-success path calls this ONE method; `scheduleDeviceBatteryRefresh`'s in-place battery-tick path calls `renderPresentation()` alone (NOT the triplet — would wrongly re-arm the dismiss timer, see Pitfall 11 in RESEARCH.md). Both must be separate injected closures.

---

### `Islet/Notch/NotchWindowController.swift` (controller, event-driven — surgical edit)

**Analog:** itself. The pattern to mirror for the 6 call-site rewires is the existing toggle-off block shape already used for `powerMonitor`/`nowPlayingMonitor` in the SAME method (`handleSettingsChanged`, lines 1002-1031) — `DeviceCoordinator` slots into the identical "if enabled → start; else if != nil → stop + reset + flush" shape used for the other two monitors:
```swift
// Charging
if activityEnabled(ActivitySettings.chargingKey) {
    startPowerMonitor()
} else if powerMonitor != nil {
    powerMonitor?.stop(); powerMonitor = nil
    lastActivity = nil; didSeedInitialPower = false
    flushTransients(.charging)
}

// Devices
if activityEnabled(ActivitySettings.deviceKey) {
    startBluetoothMonitor()
} else if bluetoothMonitor != nil {
    bluetoothMonitor?.stop(); bluetoothMonitor = nil
    deviceLastShown.removeAll()
    flushTransients(.device)
}
```
The `deviceLastShown.removeAll()` line becomes `deviceCoordinator.reset()` (concrete method, not protocol) — see RESEARCH.md's Call Sites table for the full 6-row rewire list (construction at line 419, `triggerDeviceBatteryRefreshIfPromoted()` calls at 830/1076, the toggle-off line 1016, `flushTransients(.device)`'s `pendingDeviceBatteryPolls.removeAll()` at 1071, and `deinit`'s `deviceBatteryWork?.cancel()` at 1220).

**`flushTransients(.device)` unconditional-clear ordering to preserve** (`NotchWindowController.swift:1059-1078`, Pitfall 12 in RESEARCH.md):
```swift
transientQueue.removeAll(where: matches)
switch category {
case .charging: chargingState.activity = nil
case .device:
    pendingDeviceBatteryPolls.removeAll()   // Finding 4 — drop any pending battery polls too
}
guard transientQueue.head != oldHead else { return }   // WR-2 — untouched head, no timer reset
```
The coordinator's pending-poll clear must fire UNCONDITIONALLY here (before the `oldHead` guard), not gated behind it — do not accidentally move it below the guard when rewiring.

**`deinit` split** (`NotchWindowController.swift:1216-1220`):
```swift
bluetoothMonitor?.stop()
deviceBatteryWork?.cancel()
```
Line 1 stays (D-01, `BluetoothMonitor` ownership unchanged). Line 2 becomes `deviceCoordinator.cancelPendingWork()` — callable from this same `nonisolated deinit` context (confirmed nonisolated per the file's convention: `powerMonitor.stop()` at line 1213 and `bluetoothMonitor?.stop()` at 1219 are both already nonisolated calls into this deinit).

---

### `IsletTests/DeviceCoordinatorTests.swift` (test, request-response)

**Analog 1 — DI-seam fakes pattern:** `IsletTests/LicenseStateTests.swift` (full file, 89 lines)

**Fakes as private nested classes + constructor injection** (lines 8-28):
```swift
final class LicenseStateTests: XCTestCase {

    private final class FakeLicenseManager: LicenseManaging {
        var isLicensed: Bool
        init(isLicensed: Bool) { self.isLicensed = isLicensed }
    }

    private final class FakeTrialManager: TrialStatusProviding {
        var trialStartDateValue: Date?
        init(trialStartDate: Date?) { self.trialStartDateValue = trialStartDate }
        func trialStartDate() -> Date? { trialStartDateValue }
    }

    func testPersistedLicenseWinsOverEverything() {
        let state = LicenseState(
            licenseManager: FakeLicenseManager(isLicensed: true),
            trialManager: FakeTrialManager(trialStartDate: nil)
        )
        XCTAssertEqual(state.status, .licensed)
    }
```
For `DeviceCoordinator`, fake the closures directly instead of a fake protocol-conforming class (the reach-back dependencies are closures per the discretion decision, not protocol-typed collaborators) — e.g. construct with recording closures: `var enqueuedActivities: [DeviceActivity] = []`, a settable `queueHead: ActiveTransient?` captured by a closure, and a counter for `presentTransientChange`/`renderPresentation` calls.

**Analog 2 — exercise a real value type directly, don't fake it:** `IsletTests/IslandResolverTests.swift:99-118` (real `TransientQueue` struct, constructed and mutated directly, never faked):
```swift
private let charging = ActiveTransient.charging(.charging(percent: 50))
private let device = ActiveTransient.device(.connected(name: "AirPods Pro", glyph: .airpodsPro, battery: nil))

func testEnqueueIntoEmptyShowsImmediately() {
    var q = TransientQueue()
    XCTAssertTrue(q.enqueue(charging))
    XCTAssertEqual(q.head, charging)
    XCTAssertEqual(q.pendingCount, 0)
}
```
Because `TransientQueue` is already a pure, already-tested `struct`, `DeviceCoordinatorTests.swift` can construct a real `TransientQueue` instance and pass its `.head`/`enqueue`/`updateHead` through the coordinator's injected closures rather than faking the queue itself — this is RESEARCH.md's explicit recommendation.

**Time-dependent debounce tests:** per RESEARCH.md's Assumption A2, `DeviceCoordinator.handle(_:)` needs an explicit `now:` parameter (default `Date().timeIntervalSinceReferenceDate` in production, explicit values in tests) — deviating minimally from `handleDevice`'s internal `Date()` read specifically so debounce/launch-grace math is testable without real sleeps. No existing analog reads `Date()` via injection in this codebase yet (`PowerActivityTests`/`DeviceActivityTests` sidestep this by testing pure functions directly with a passed-in `now:`) — this is the one place `DeviceCoordinator` slightly diverges from the closest existing precedent, flagged here so the planner treats it as an intentional, minimal signature addition, not a discovered analog.

---

### `.planning/phases/16-.../16-HUMAN-UAT.md` (optional planning artifact, per Open Question 2)

**Analog:** `.planning/phases/06-priority-resolver-settings-v1-ship/06-HUMAN-UAT.md` (full file, 40 lines)

**Frontmatter + structure to mirror:**
```markdown
---
status: complete
phase: 06-priority-resolver-settings-v1-ship
source: [06-VERIFICATION.md]
started: 2026-07-02T01:20:00Z
updated: 2026-07-02T04:40:00Z
---

## Current Test

[testing complete]

## Tests

### 1. <title>
expected: <behavior>
result: pass

## Summary

total: N
passed: N
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps
```
D-03's four required scenarios (reconnect-flap debounce, launch-grace suppression, genuine disconnect, battery-poll promotion) map to four numbered `### N.` entries in the `## Tests` section, `status: pending` until exercised, then flipped to `complete` per-item as verify-work runs the on-device checklist (mirrors this file's `result: pass` convention).

## Shared Patterns

### `@MainActor` class + closure-injected init + `nonisolated(unsafe)` teardown
**Source:** `Islet/Notch/BluetoothMonitor.swift` (full file), cross-checked identical in `Islet/Notch/PowerSourceMonitor.swift:58-97`
**Apply to:** `Islet/Notch/DeviceCoordinator.swift`
```swift
@MainActor
final class BluetoothMonitor: NSObject {
    private nonisolated(unsafe) var connectToken: IOBluetoothUserNotification?
    private let onReading: (DeviceReading) -> Void
    init(onReading: @escaping (DeviceReading) -> Void) { self.onReading = onReading; super.init() }
    nonisolated func stop() { connectToken?.unregister(); connectToken = nil }
}
```
Every monitor in this codebase (`BluetoothMonitor`, `PowerSourceMonitor`, `NowPlayingMonitor`) follows this exact shape — `DeviceCoordinator` should be a drop-in sibling of these types, not a new pattern.

### Narrow protocol DI seam (Phase 15 precedent)
**Source:** `Islet/Licensing/LicenseState.swift:23-32`
**Apply to:** `Islet/Notch/ActivityCoordinator.swift`
```swift
protocol LicenseManaging: AnyObject { var isLicensed: Bool { get } }
extension LicenseManager: LicenseManaging {}
final class LicenseState {
    private let licenseManager: LicenseManaging
    init(licenseManager: LicenseManaging = LicenseManager.shared) { self.licenseManager = licenseManager }
}
```
Define the protocol to fit exactly what the one real conformer needs — no speculative third method.

### Shared render/visibility/dismiss triplet — single call site per activity type
**Source:** `Islet/Notch/NotchWindowController.swift:502-508`
**Apply to:** `Islet/Notch/DeviceCoordinator.swift`'s enqueue-success path (via injected closure), NOT its in-place battery-tick path (which calls `renderPresentation()` alone)
```swift
private func presentTransientChange() {
    withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
        renderPresentation()
    }
    updateVisibility()
    scheduleActivityDismiss()
}
```

### DI-seam test fakes (constructor-injected, no shared fixture)
**Source:** `IsletTests/LicenseStateTests.swift:8-28`
**Apply to:** `IsletTests/DeviceCoordinatorTests.swift`
```swift
private final class FakeLicenseManager: LicenseManaging {
    var isLicensed: Bool
    init(isLicensed: Bool) { self.isLicensed = isLicensed }
}
```
Each test constructs a fresh instance; no `setUp()`/`tearDown()`, no mocking framework — matches "avoid unnecessary complexity" project constraint.

## No Analog Found

None — every file in this phase has a strong (exact or role-match) analog already in the codebase. This is expected: the phase is explicitly "copy an existing shape one level deeper" (RESEARCH.md's own framing), not new architecture.

## Metadata

**Analog search scope:** `Islet/Notch/`, `Islet/Licensing/`, `IsletTests/`, `.planning/phases/06-*`
**Files scanned:** `NotchWindowController.swift`, `BluetoothMonitor.swift`, `PowerSourceMonitor.swift`, `DeviceActivity.swift`, `IslandResolver.swift`, `LicenseState.swift`, `LicenseStateTests.swift`, `IslandResolverTests.swift`, `06-HUMAN-UAT.md`
**Pattern extraction date:** 2026-07-08
