# Phase 16: NotchWindowController Device Coordinator Extraction - Research

**Researched:** 2026-07-08
**Domain:** Swift/AppKit internal refactor — stateful orchestration extraction behind a narrow protocol seam
**Confidence:** HIGH (this is a pure internal-codebase extraction; every claim below is read directly from the actual source files, not external docs)

## Summary

This phase moves 9 fields and 3 methods off `NotchWindowController` into a new `DeviceCoordinator`
class, behind a new `ActivityCoordinator` protocol, without changing any runtime behavior. All
the facts a planner needs — exact field types, exact method bodies, exact call sites, the shared
triplet the extracted code must keep calling into, and the DI-seam test precedent to mirror — are
directly quoted below from the real source, not summarized from memory.

The critical constraint is **not** "extract cleanly" — it's "extract without breaking any of the
11 documented races". `handleDevice`, `scheduleDeviceBatteryRefresh`, and
`triggerDeviceBatteryRefreshIfPromoted` read like a bug-fix changelog: every branch exists because
a specific race was found in production and patched. This research inventories every one of those
comments verbatim with line numbers so the plan can include "preserve this specific behavior" as
an explicit checklist, and so verify-work can check the checklist item-by-item instead of eyeballing
a diff.

**Primary recommendation:** Move the 9 fields + 3 methods verbatim into `DeviceCoordinator`,
give it a closure-based reach-back into the controller (not a delegate protocol) for the
`presentTransientChange()`/`transientQueue`/`bluetoothMonitor.battery(forAddress:)` dependencies,
define `ActivityCoordinator` with exactly the two methods `DeviceCoordinator` needs
(`handle(reading:) -> Bool`-shaped or similar, and a teardown method), and write
`DeviceCoordinatorTests.swift` mirroring `LicenseStateTests.swift`'s constructor-injected-fakes
pattern. No new abstraction beyond what one coordinator needs (per D-02).

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| IOBluetooth connect/disconnect notification registration | AppKit/System glue (`BluetoothMonitor`) | — | Already isolated; D-01 keeps it on the controller, untouched by this phase |
| Device-splash debounce/launch-grace/edge-tracking bookkeeping | New `DeviceCoordinator` (System glue/orchestration tier) | — | Stateful, has a clock (`Date()`), calls back into shared queue/render — not pure, but should own its own state instead of living inline on the window controller |
| Device reading → presentable activity mapping | `DeviceActivity.swift` (pure seam) | — | Already extracted, untouched by this phase (explicitly out of scope) |
| Transient queue / dismiss timing / render / visibility | `NotchWindowController` (owns `TransientQueue`, `presentTransientChange()`, `updateVisibility()`) | `DeviceCoordinator` calls into it | Shared across Charging + Device; D-02 forbids Device from forking its own copy or owning the queue |
| Battery re-poll scheduling + cancellation | New `DeviceCoordinator` | `BluetoothMonitor.battery(forAddress:)` (data source) | The `DispatchWorkItem` and its identity-race guard (`pollingAddress`) belong with the rest of the device bookkeeping being extracted |

## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** `NotchWindowController` keeps owning `BluetoothMonitor` (start/stop/lifecycle) — matches the ROADMAP's literal field/method list (no `BluetoothMonitor` mentioned) and the established "controller owns monitors, injects readings into logic" pattern already used for `PowerSourceMonitor`/`NowPlayingMonitor`. `DeviceCoordinator` receives `DeviceReading` values handed to it by the controller — it does not touch `BluetoothMonitor` directly. Smallest safe diff for a first coordinator slice.
- **D-02:** Design `ActivityCoordinator` narrowly, fitted to what `DeviceCoordinator` actually needs — do NOT pre-sketch Charging/NowPlaying/Outfit shapes in this phase. Guessing at the other three coordinators' shapes before they're extracted risks a wrong abstraction that gets reworked anyway once their real needs are known.
- **D-03:** Full on-device Bluetooth checklist is REQUIRED before this phase is considered done, not just unit tests + spot-check. Given this is the single most race-prone code path in the app by the audit's own account (11+ after-the-fact fixes), a pure structural move can still silently break timing-sensitive edge cases unit tests can't exercise (real IOBluetooth callbacks arrive off-main and get hopped to main). Checklist must cover, at minimum: reconnect-flap debounce (same device connects twice within the ~3s window), launch-grace suppression (device already connected when the monitor starts), a genuine disconnect edge, and battery-poll promotion (a device enqueued behind the current head later gets promoted and still receives its deferred battery refresh).

### Claude's Discretion
- Exact protocol method signatures for `ActivityCoordinator` (e.g., `handle(reading:)` vs. `process(_:)`, how it reports "did the queue change" back to the controller — return value vs. callback) — pick whichever keeps `NotchWindowController`'s call sites (`handleDevice`, `triggerDeviceBatteryRefreshIfPromoted`, the `deinit` cancellation of `deviceBatteryWork`) simplest to swap in.
- Whether `DeviceCoordinator` needs a reference to the shared `TransientQueue`/`presentTransientChange()`/`renderPresentation()` passed in as closures, a delegate, or a narrow protocol — `handleDevice` currently calls all three directly; the extraction must preserve identical enqueue/render/dismiss timing (D-03's zero-behavior-change contract), the connecting mechanism is an implementation detail.
- Structure of `DeviceCoordinatorTests.swift` (isolated unit tests against fakes for `TransientQueue`/`BluetoothMonitor`/clock, mirroring `LicenseStateTests.swift`'s DI-seam test pattern from Phase 15) — Claude's call at planning time.

### Deferred Ideas (OUT OF SCOPE)
- **Charging/NowPlaying/Outfit coordinators** — explicitly out of scope (D-02, Phase 15 D-04). A future phase, gated on this phase's on-device verification landing clean, and informed by whatever `ActivityCoordinator` shape actually falls out of this Device-only extraction (not pre-guessed here).
- **`BluetoothMonitor` ownership move into the coordinator** — considered and explicitly rejected for this phase (D-01); revisit only if a future coordinator generalization pass finds the current split awkward.

## Project Constraints (from CLAUDE.md)

- **Swift 5 language mode** is mandatory (`SWIFT_VERSION: "5.0"` in `project.yml`, confirmed at 3 locations) — do not introduce Swift 6 strict-concurrency patterns (actors, `Sendable` conformance requirements) in `DeviceCoordinator`. Follow the existing `nonisolated(unsafe)` + explicit `DispatchQueue.main.async` hop convention used throughout the codebase (`BluetoothMonitor`, `PowerSourceMonitor`).
- **`@MainActor` class, not actor.** Every monitor/controller in this codebase is a plain `@MainActor final class`, never a Swift `actor`. `DeviceCoordinator` should follow the identical pattern for consistency and Swift-5-mode compatibility.
- **Protocol-based DI seams, not concrete singletons** — Phase 15 (`LicenseState`, `LocationProvider`) established the pattern: define a narrow protocol, provide a default-argument initializer pointing at the real singleton, and the class is now fake-injectable in tests without touching any call site.
- **First-time-programmer builder** — avoid unnecessary complexity. Do not over-abstract `ActivityCoordinator` beyond exactly what `DeviceCoordinator` needs (this is also D-02, doubly reinforced).
- **`xcodebuild test` hangs** (project memory) — the full `Islet.app` boots `NSPanel`/`MediaRemote`/`IOBluetooth` when tests are hosted in it, causing a headless hang. Use `xcodebuild build` (or `build-for-testing`) as the automated gate; route the actual test run to a manual Cmd-U in Xcode. This must be reflected in the Validation Architecture section below.
- **Release-config gate:** any change touching entitlements or embedded frameworks needs a `-configuration Release` build check (not relevant to this phase — no entitlement/framework changes — but noted per project memory in case scope creeps).

## Phase Requirements

No formal REQ-IDs exist for this phase (confirmed: `.planning/REQUIREMENTS.md` does not exist in this repo's `.planning/` directory at time of research — the project has not yet run `/gsd-new-milestone` to create one for the post-v1.1 scope). This phase is scoped entirely by CONTEXT.md's D-01/D-02/D-03 and the ROADMAP goal text.

| ID | Description | Research Support |
|----|-------------|------------------|
| (none) | Extract 9 fields + 3 methods into `DeviceCoordinator` behind `ActivityCoordinator`, zero behavior change | See "Exact Extraction Target" and "Common Pitfalls" sections below |

## Exact Extraction Target

### The 9 fields (`NotchWindowController.swift:107-154`)

```swift
// Phase 6 / 05 D-04 — the device-splash debounce/burst-suppression state threaded into the
// PURE shouldShowDeviceSplash(...) predicate (no clock inside it; the controller passes `now`
// + these dictionaries).
private var deviceLastShown: [String: TimeInterval] = [:]
private var deviceSuppressedAtLaunch: Set<String> = []
private let deviceDebounce: TimeInterval = 3.0   // mirror activityDuration (discretion seed)

// Phase 6 fix (post-checkpoint) — addresses currently believed CONNECTED (edge-detection Set).
private var connectedDeviceAddresses: Set<String> = []

// The instant the BluetoothMonitor started — launch-grace window origin.
private var bluetoothStartedAt: Date?
private let deviceLaunchGrace: TimeInterval = 4.0

// The one-shot post-connect battery re-read work item.
private var deviceBatteryWork: DispatchWorkItem?

// Gap-closure fix (Finding 2) — the address the CURRENT poll chain is running for.
private var pollingAddress: String?

// Gap-closure fix (WR-1) — address-keyed side data mirroring TransientQueue's pending order
// for `.device` entries ONLY, capped at 2 (mirrors TransientQueue.maxDepth).
private var pendingDeviceBatteryPolls: [PendingBatteryPoll] = []
```

`PendingBatteryPoll` is defined in `IslandResolver.swift:66-69` (`struct PendingBatteryPoll: Equatable { let address: String; let activity: DeviceActivity }`) — it is a shared pure type, NOT part of the 9 fields, and stays in `IslandResolver.swift` untouched.

### The 3 methods — verbatim, with every inline race-comment preserved

**`handleDevice(_:)` — `NotchWindowController.swift:859-925`** (full body already captured in this
research session; reproduce verbatim in the new location, changing only `self.` references that
now point at coordinator-owned state vs. controller-owned dependencies).

**`triggerDeviceBatteryRefreshIfPromoted()` — `NotchWindowController.swift:935-940`**
```swift
private func triggerDeviceBatteryRefreshIfPromoted() {
    let (match, remaining) = matchPendingBatteryPoll(pendingDeviceBatteryPolls, promoted: transientQueue.head)
    pendingDeviceBatteryPolls = remaining
    guard let match else { return }
    scheduleDeviceBatteryRefresh(address: match.address)
}
```
Reads `transientQueue.head` (controller-owned, shared) — the coordinator needs read access to the
queue's head, not just write/enqueue access.

**`scheduleDeviceBatteryRefresh(address:attempt:)` — `NotchWindowController.swift:948-976`**
Reads `self.transientQueue.head` (to check the device is still standing), calls
`self.transientQueue.updateHead(_:)` (mutates shared queue in-place — no dismiss re-arm, "like a
charging % tick"), calls `self.bluetoothMonitor?.battery(forAddress:)` (D-01: still the
controller's monitor — coordinator needs a closure/reference to reach it, NOT ownership), calls
`withAnimation(...) { self.renderPresentation() }` (shared render primitive), and recurses into
itself for the retry chain (bounded at 6 attempts / ~3.6s total, spaced ~0.6s via
`DispatchQueue.main.asyncAfter`).

### `deinit` teardown (`NotchWindowController.swift:1219-1220`)

```swift
bluetoothMonitor?.stop()
deviceBatteryWork?.cancel()
```

These two lines are adjacent but serve different owners after extraction: `bluetoothMonitor?.stop()`
stays on the controller (D-01); `deviceBatteryWork?.cancel()` must become a call into the
coordinator's own teardown method (e.g. `deviceCoordinator.stop()` or `.cancelPendingWork()`).
**The coordinator itself has no other `deinit`-relevant state** — none of the other 8 fields need
explicit teardown (no OS tokens, no observers), only the one `DispatchWorkItem`.

### Call sites that must be rewired (all in `NotchWindowController.swift`)

| Line(s) | Current code | After extraction |
|---------|--------------|-------------------|
| 335, 1012-1013 | `if activityEnabled(ActivitySettings.deviceKey) { startBluetoothMonitor() }` | Unchanged — `BluetoothMonitor` lifecycle stays on controller (D-01) |
| 419 | `let bt = BluetoothMonitor { [weak self] reading in self?.handleDevice(reading) }` | Becomes `self?.deviceCoordinator.handle(reading)` (or equivalent) — the controller's `onReading` closure now forwards to the coordinator instead of calling its own private method |
| 830, 1076 | `self.triggerDeviceBatteryRefreshIfPromoted()` | Becomes `self.deviceCoordinator.triggerBatteryRefreshIfPromoted()` (or the chosen method name) |
| 1016 | `deviceLastShown.removeAll()` (inside `handleSettingsChanged`, devices-toggle-off branch) | Becomes a coordinator method call, e.g. `deviceCoordinator.reset()` — this line runs alongside `bluetoothMonitor?.stop(); bluetoothMonitor = nil` and `flushTransients(.device)`; all three must still fire in the same order |
| 1071 | `pendingDeviceBatteryPolls.removeAll()` (inside `flushTransients(.device)`) | Becomes a coordinator call too — `flushTransients` is controller-owned (touches `transientQueue`/`chargingState` for both categories) but the `.device`-specific pending-poll clear must reach into the coordinator |
| 1219-1220 | `bluetoothMonitor?.stop()` / `deviceBatteryWork?.cancel()` | Split: first line stays, second becomes `deviceCoordinator.cancelPendingWork()` (or coordinator's own deinit if the coordinator itself has a deinit — see Pitfall 5 below re: `nonisolated` deinit ordering) |

**`handleSettingsChanged`'s devices-off branch (line 1012-1018) and `flushTransients(.device)`
(line 1059-1078) both need partial coordinator delegation while staying otherwise controller-owned** —
this is the trickiest wiring point because these two methods ALSO handle Charging in the same
function body. The plan must NOT extract the whole method, only the device-specific lines inside it.

## The Shared Triplet — exact call shape `DeviceCoordinator` must reach back into

```swift
// NotchWindowController.swift:502-508 — Finding 11, shared by handlePower AND handleDevice
private func presentTransientChange() {
    withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
        renderPresentation()
    }
    updateVisibility()
    scheduleActivityDismiss()
}
```

`handleDevice` calls this ONE method (not the three sub-steps separately) after a successful
`transientQueue.enqueue(.device(activity))` that returns `changed == true`. `scheduleDeviceBatteryRefresh`
calls `renderPresentation()` directly (not the full triplet) because an in-place battery-%
update on an already-standing splash must NOT re-arm the dismiss timer (would extend how long the
splash is visible — a distinct, intentional deviation from the enqueue path).

**Concrete tradeoff for the Claude's-Discretion reach-back mechanism:**

| Approach | Shape | Pros | Cons |
|----------|-------|------|------|
| **Closures (recommended)** | `DeviceCoordinator(presentTransientChange: @escaping () -> Void, renderPresentation: @escaping () -> Void, queue: ...)` passed at construction | Matches existing codebase idiom exactly (`BluetoothMonitor`'s own `onReading` closure, `PowerSourceMonitor`'s `onReading`, `NowPlayingMonitor`'s `onSnapshot`/`onTerminated`) — zero new vocabulary for a first-time programmer; trivially fakeable in tests (pass a closure that increments a counter) | A handful of closures (4-5) in the initializer — mildly verbose but consistent with every other type in this file |
| Delegate protocol | `protocol DeviceCoordinatorDelegate: AnyObject { func presentTransientChange(); func renderPresentation() }` | Slightly more "OOP-idiomatic" | Introduces a NEW pattern not used anywhere else in this codebase (no delegate protocol exists today) — inconsistent, adds a concept the builder hasn't seen elsewhere |
| Narrow protocol matching `ActivityCoordinator`'s own shape | Have `NotchWindowController` itself conform to a `TransientPresenting` protocol, coordinator holds `weak var host: TransientPresenting?` | Testable, avoids retain cycle risk of a hard closure capturing `self` | Over-engineered for one coordinator per D-02's own spirit — adds a protocol AND a weak-ref discipline question for zero benefit over closures here |

**Recommendation: closures**, matching the codebase's own established idiom (every monitor already
takes closures at init — `BluetoothMonitor(onReading:)`, `PowerSourceMonitor(onReading:)`,
`NowPlayingMonitor(onSnapshot:onTerminated:)`). This keeps `DeviceCoordinator` a drop-in sibling of
those monitor types rather than introducing the first delegate pattern in the app. `DeviceCoordinator`
does NOT need direct access to `transientQueue` as shared mutable state passed BY REFERENCE — Swift
structs are value types, so either (a) the coordinator holds closures for `enqueue`/`updateHead`/
`readHead` that the controller implements against its own `transientQueue` property, or (b) the
controller still owns `transientQueue` and hands the coordinator a read/write closure pair. Given
`TransientQueue` is a `struct` (value type, confirmed at `IslandResolver.swift:98`), the coordinator
CANNOT hold a mutable reference to it directly — closures are actually structurally necessary here,
not just stylistically preferred.

## `ActivityCoordinator` Protocol Shape (D-02: narrow, Device-only, no pre-guessing)

Based on how `NotchWindowController` actually calls into device logic today, the two operations
needed are: (1) handle an incoming reading, (2) react to a queue-head promotion. A minimal shape
that fits exactly `DeviceCoordinator`'s two real call sites (`handleDevice` and
`triggerDeviceBatteryRefreshIfPromoted`) and nothing hypothetical for Charging/NowPlaying/Outfit:

```swift
@MainActor
protocol ActivityCoordinator {
    associatedtype Reading
    /// Feed a new reading in. Coordinator internally debounces/gates and enqueues into the
    /// shared TransientQueue via its injected closures. No return value needed — the coordinator
    /// itself decides whether to fire the shared presentTransientChange() triplet.
    func handle(_ reading: Reading)
    /// Called after the shared TransientQueue's head changes for a reason OUTSIDE this
    /// coordinator's own handle(_:) call (dismiss-timer advance, flushTransients promotion) —
    /// lets the coordinator react if ITS OWN activity type became the new head.
    func activityPromoted()
}
```

`DeviceCoordinator: ActivityCoordinator { typealias Reading = DeviceReading }`. This avoids
guessing at Charging's shape (Charging currently has no "promoted battery refresh" concept at all —
`handlePower`'s equivalent is far simpler, no polling chain) — per D-02, do not add a third method
speculatively for Charging's sake.

**Why an `associatedtype` and not a plain closure-typed struct:** a protocol is what the phase
description explicitly asks for ("`DeviceCoordinator`... behind an `ActivityCoordinator` protocol").
A plain struct-of-closures would technically satisfy "narrow" but wouldn't be a protocol at all.
Keep the protocol to these two methods only — do not add `reset()`/`cancelPendingWork()` to the
protocol itself unless a second coordinator in a future phase actually needs the same shape; for
THIS phase, `DeviceCoordinator` can expose `reset()`/`cancelPendingWork()` as its own concrete
methods (not protocol requirements) since only the controller calls them directly today, not through
a protocol-typed reference.

## `BluetoothMonitor`'s `onReading` Closure & `deinit` Cancellation (must be preserved)

```swift
// BluetoothMonitor.swift:48-53
private let onReading: (DeviceReading) -> Void
init(onReading: @escaping (DeviceReading) -> Void) {
    self.onReading = onReading
    super.init()
}
```

Constructed today at `NotchWindowController.swift:419`:
```swift
let bt = BluetoothMonitor { [weak self] reading in self?.handleDevice(reading) }
```
After extraction this becomes:
```swift
let bt = BluetoothMonitor { [weak self] reading in self?.deviceCoordinator.handle(reading) }
```
(or whatever the chosen property name is). **`deviceCoordinator` should NOT be optional** given
it has no toggle-driven lifecycle of its own (unlike `bluetoothMonitor` which is nil'd on toggle-off) —
its bookkeeping (debounce dictionaries, `pendingDeviceBatteryPolls`) simply sits idle when the
Devices toggle is off, mirroring how `deviceLastShown`/`pendingDeviceBatteryPolls` already just sit
unused today when `bluetoothMonitor == nil`.

`deinit` cancellation (`NotchWindowController.swift:1219-1220`):
```swift
bluetoothMonitor?.stop()
deviceBatteryWork?.cancel()
```
`NotchWindowController`'s deinit is `nonisolated` (confirmed by the file's convention — every other
monitor's `stop()` is called `nonisolated` from this same deinit, e.g. `powerMonitor.stop()`,
`nowPlayingMonitor?.stop()`). **`DeviceCoordinator.cancelPendingWork()` must therefore also be
callable from a nonisolated context** — either mark it `nonisolated func cancelPendingWork()` with
`deviceBatteryWork` stored `nonisolated(unsafe)` (mirroring `BluetoothMonitor.connectToken`'s own
`nonisolated(unsafe)` pattern, justified there because "these are only ever written on main... the
deinit teardown at app-quit is the sole nonisolated reader, so there is no concurrent access" — the
identical justification applies to `deviceBatteryWork`), OR keep `DeviceCoordinator` fully
`@MainActor` and have the controller's deinit call `Task { @MainActor in deviceCoordinator.cancelPendingWork() }`
— **the second option is WRONG**: a `deinit`-scheduled `Task` may run after the object (and its
captured closures) are already gone, defeating the purpose of synchronous teardown. **Use the first
option** — mirror `BluetoothMonitor`'s exact `nonisolated(unsafe)` + `nonisolated func stop()`
pattern for `deviceBatteryWork`/`pollingAddress` inside `DeviceCoordinator`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Device→presentation classification | A new mapping function inside the coordinator | `deviceActivity(from:)` / `shouldShowDeviceSplash(...)` in `DeviceActivity.swift` | Already pure, already unit-tested (`DeviceActivityTests.swift`) — the coordinator calls these, never reimplements them |
| Identity-matching a promoted device to its pending battery poll | A new FIFO or dictionary lookup | `matchPendingBatteryPoll(_:promoted:)` in `IslandResolver.swift:79-90` | Already the fix for the exact bug (WR-1) this extraction must not reintroduce |
| Nonisolated teardown of a `DispatchWorkItem` from a nonisolated deinit | A `Task`/async wrapper | `nonisolated(unsafe)` + `nonisolated func` mirroring `BluetoothMonitor`'s existing pattern | The codebase has already solved this exact problem three times (`PowerSourceMonitor`, `BluetoothMonitor`, `NowPlayingMonitor`) — copy the pattern, don't invent a fourth approach |

**Key insight:** every "new" problem this extraction seems to raise (nonisolated teardown,
closure-based reach-back, protocol-typed dependency injection) already has an established, working
answer somewhere else in this exact file or its sibling monitors. This phase is copying an existing
shape one level deeper, not inventing new architecture.

## Common Pitfalls — the 11+ verbatim gap-closure/Finding comments that must NOT regress

Extracted directly from `handleDevice`, `triggerDeviceBatteryRefreshIfPromoted`,
`scheduleDeviceBatteryRefresh` (`NotchWindowController.swift:848-976`). Each is a real bug found
after the fact — treat this as the verification checklist for the extraction diff.

1. **Line 862-864 (comment above `handleDevice`)** — "IOBluetooth re-fires connection events for an already-connected device (the CoreBluetooth bridge fires connectionEventDidOccur repeatedly), which previously made a stable headphone splash perpetually. Splash ONLY on a genuine connect/disconnect EDGE, keyed by address." → `connectedDeviceAddresses` Set-based dedup, lines 873-884.

2. **Gap-closure fix (Finding 1), lines 868-872** — "an ADDRESSLESS reading must NOT be dropped here — it just can't be deduped by this Set. It falls through to the shared splash-gate/deviceActivity call below unconditionally... the previous blanket early-return on a nil address silently dropped every addressless reading." → the `if let addr = reading.address { ... } else if reading.connected, let started = bluetoothStartedAt ... { return }` branch structure (lines 873-890) must be preserved exactly, including the `else if` symmetry check on line 885-889 ("Symmetry with the addressed path above: an addressless connect during the at-launch burst window is still suppressed, even though it can't be tracked in the Set").

3. **Line 877-880 (05 D-04 at-launch suppression)** — "a device already connected when the monitor started is recorded as connected above but does NOT splash." → the `bluetoothStartedAt`/`deviceLaunchGrace` check runs AFTER `connectedDeviceAddresses.insert(addr)`, not before — order matters (a suppressed-at-launch device is still recorded as connected so a LATER genuine disconnect can fire).

4. **Line 892-901 (Secondary flap debounce)** — "drop a repeat edge for the same address within ~3s. Passes reading.address DIRECTLY (may be nil) — shouldShowDeviceSplash's own contract falls through to true when it has no address to dedup against." → this is a SECOND, independent debounce layer on top of the edge-detection Set — do not conflate or merge them.

5. **Line 902** — `deviceLastShown[addr] = now` is stamped "only when there IS a key" — an addressless reading that passes the gate does NOT get a debounce timestamp (can't dedupe next time either — accepted, matches `shouldShowDeviceSplash`'s own documented contract). Unit-tested: a second addressless reading fed shortly after the first must ALSO enqueue (no debounce timestamp exists for it to be checked against).

6. **Gap-closure fix (Finding 4), lines 913-923** — "this connect was enqueued BEHIND the current head (or deduped), so it did NOT get a battery-refresh scheduled above. Remember it... capped at maxDepth) so `triggerDeviceBatteryRefreshIfPromoted()` can identity-match it (WR-1) once it is eventually promoted to head." → the `else if reading.connected` branch (not just `else`) — a disconnect that fails to become head is NOT queued for a pending battery poll (only connects need one).

7. **Line 921-922 cap** — `if pendingDeviceBatteryPolls.count > 2 { pendingDeviceBatteryPolls.removeFirst() }` — the cap mirrors `TransientQueue.maxDepth` (2); must stay in sync if `maxDepth` ever changes (currently a coincidental magic-number duplication, not derived from the real constant — flag but do not silently "fix" during this phase, it is out of scope).

8. **Gap-closure fix (WR-1), lines 931-934, 936** — `matchPendingBatteryPoll` identity-match "not by FIFO position — the old address-only FIFO's `.first` pop could poll a stale/mismatched device once it desynced from TransientQueue's own pending list." → must call the exact same pure function, not a hand-rolled address lookup.

9. **Finding 2 (lines 949-951, 957-960), `scheduleDeviceBatteryRefresh`** — "stamp the address BEFORE cancel/schedule, on every call including the internal retry recursion... `deviceBatteryWork?.cancel()` cannot stop a closure that has ALREADY started executing... this side table lets that stale closure detect it has been superseded." → `pollingAddress = address` MUST be the first line of the method, before `deviceBatteryWork?.cancel()`, and the inner closure's `guard self.pollingAddress == address else { return }` guard must run before any other logic in the `DispatchWorkItem` body.

10. **Line 961-962 (dismissal check)** — "Stop once the device is no longer the standing splash (advanced / dismissed)." → `guard case .device(.connected(...))? = self.transientQueue.head else { return }` — the coordinator needs read access to `transientQueue.head` for this guard on every retry tick, not just at schedule time.

11. **Line 963-971 (in-place update, no dismiss re-arm)** — "update the head in place (no dismiss re-arm — like a charging % tick)" — calls `transientQueue.updateHead(_:)` + `renderPresentation()` directly, explicitly NOT `presentTransientChange()` (which would re-arm the dismiss timer and extend the splash's visible duration — an actual behavior change if conflated).

12. **Finding 3/WR-2 cross-reference (`flushTransients`, line 1055-1057, 1073)** — "an untouched standing splash's already-running ~3s countdown is left exactly as it was" — `flushTransients(.device)` only cancels/re-arms the dismiss timer if `transientQueue.head != oldHead`; the coordinator's `pendingDeviceBatteryPolls.removeAll()` call (line 1071) happens UNCONDITIONALLY inside `flushTransients(.device)` regardless of that head-changed check — do not accidentally gate it behind the same condition when rewiring this call site.

**Additional non-comment-tagged behavior to preserve:** the `deviceLastShown.removeAll()` call on
toggle-off (`handleSettingsChanged`, line 1016) resets the debounce dictionary but NOT
`connectedDeviceAddresses` or `deviceSuppressedAtLaunch` — this asymmetry is existing behavior
(not flagged as a bug anywhere in comments) and must be preserved as-is unless the planner
explicitly decides otherwise (out of scope for a zero-behavior-change phase).

## `DeviceCoordinatorTests.swift` — Template from `LicenseStateTests.swift`

`IsletTests/LicenseStateTests.swift` (Phase 15's DI-seam precedent, full file read this session)
establishes the pattern to mirror:

1. **Fakes are private nested classes conforming to the protocol**, constructed with the exact
   state the test needs:
   ```swift
   private final class FakeLicenseManager: LicenseManaging {
       var isLicensed: Bool
       init(isLicensed: Bool) { self.isLicensed = isLicensed }
   }
   ```
2. **The class under test is constructed with fakes injected via its default-argument initializer**
   (no `.shared` singleton touched, no real Keychain/UserDefaults I/O).
3. **Each test method constructs a fresh instance** — no shared mutable fixture, no `setUp()`/
   `tearDown()` — keeping every test trivially independent and readable top-to-bottom.
4. **Assertions are direct `XCTAssertEqual`/`XCTAssertTrue` on the class's public read-only
   properties** — no mocking framework, no verification-of-calls libraries (matches the "avoid
   unnecessary complexity" project constraint).

**Applying this to `DeviceCoordinator`:** the coordinator's dependencies to fake are (a) the clock
(`Date()` calls inside `handleDevice`/debounce logic — currently NOT injected anywhere in the
codebase; `PowerActivityTests`/`DeviceActivityTests` sidestep this by testing the PURE functions
directly with a passed-in `now: TimeInterval`, never `Date()` itself) and (b) the closures for
`presentTransientChange`/`renderPresentation`/queue read-write and `BluetoothMonitor.battery(forAddress:)`.

Recommended approach — **do not try to fake `Date()` inside the coordinator.** Instead, structure
`DeviceCoordinator`'s tests the same way `DeviceActivityTests.swift` already tests
`shouldShowDeviceSplash` and `handleDevice`'s OWN logic largely reduces to sequencing calls to that
pure function — the coordinator's value-add under test is the STATEFUL bookkeeping around it
(does `connectedDeviceAddresses` correctly dedupe an edge, does `pendingDeviceBatteryPolls` cap at
2, does `matchPendingBatteryPoll` get invoked with the right queue head). Test these by:
- Injecting fake closures that record what was called (e.g. `var enqueuedActivities: [DeviceActivity] = []`, `queueHead: ActiveTransient? = nil` settable by the test) instead of a fake `TransientQueue` — because `TransientQueue` is a real, already-pure, already-tested `struct` (not a system dependency needing a fake), tests CAN construct and mutate a real `TransientQueue` instance directly rather than faking it, following `IslandResolverTests.swift`'s own precedent (check that file's pattern before writing the coordinator's tests — it already tests `TransientQueue` behavior directly).
- For time-dependent debounce tests, inject `now` as an explicit parameter to `handle(_:)` (or an injectable `clock: () -> TimeInterval` closure) rather than reading `Date()` internally — this is a SMALL deviation from today's `handleDevice(_ reading:)` signature (which reads `Date()` internally at line 860) but is necessary for the coordinator to be unit-testable at all without real wall-clock sleeps. Flag this as an explicit, minimal, behavior-preserving signature change: production call sites still pass no `now` (default `Date().timeIntervalSinceReferenceDate` via a default argument), only tests pass an explicit value.

## Code Examples

### Pattern: nonisolated teardown mirrored from `BluetoothMonitor`
```swift
// Source: Islet/Notch/BluetoothMonitor.swift:40-45, 150-156
private nonisolated(unsafe) var connectToken: IOBluetoothUserNotification?
// ...
nonisolated func stop() {
    connectToken?.unregister()
    connectToken = nil
    // ...
}
```
Apply the identical shape to `DeviceCoordinator.deviceBatteryWork` / `pollingAddress` if the
coordinator's teardown must be callable from `NotchWindowController`'s `nonisolated deinit`.

### Pattern: closure-injected monitor construction (the idiom to mirror for `DeviceCoordinator`'s init)
```swift
// Source: Islet/Notch/NotchWindowController.swift:386, 393-395, 419
let monitor = PowerSourceMonitor { [weak self] reading in self?.handlePower(reading) }
let np = NowPlayingMonitor(
    onSnapshot: { [weak self] snap, art in self?.handleNowPlaying(snap, art) },
    onTerminated: { [weak self] in self?.handleAdapterTerminated() })
let bt = BluetoothMonitor { [weak self] reading in self?.handleDevice(reading) }
```

### Pattern: Phase 15 DI-seam protocol + default-argument initializer (the idiom to mirror for `ActivityCoordinator`/`DeviceCoordinator`'s protocol dependencies, if any beyond closures are needed)
```swift
// Source: .planning/phases/15-.../15-CONTEXT.md, worked/verified-compiling shape for LicenseState
protocol LicenseManaging: AnyObject { var isLicensed: Bool { get } }
extension LicenseManager: LicenseManaging {}

final class LicenseState {
    private let licenseManager: LicenseManaging
    init(licenseManager: LicenseManaging = LicenseManager.shared) {
        self.licenseManager = licenseManager
    }
}
```

## State of the Art

Not applicable — this is a same-codebase structural move, not an external-library adoption. No
external "old approach → new approach" axis exists; the only "before/after" is this file's own
pre- and post-extraction shape.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Closures (not a delegate protocol) are the right reach-back mechanism for `DeviceCoordinator` into the controller | The Shared Triplet section | Low — this is flagged as Claude's Discretion in CONTEXT.md itself; the closure recommendation is grounded in an actual codebase-wide pattern match (every existing monitor uses closures), not a guess, so confidence is HIGH despite being "discretion" |
| A2 | `DeviceCoordinator.handle(_:)` needs an explicit `now:`/clock parameter to be unit-testable, deviating slightly from `handleDevice`'s internal `Date()` read | `DeviceCoordinatorTests.swift` template section | Medium — if the planner instead accepts calling `Date()` internally and tests only via longer real-time sleeps or skips debounce-timing tests entirely, this changes the achievable test coverage (D-03 already requires full on-device verification regardless, so unit test coverage of the debounce math is a nice-to-have, not the sole safety net) |
| A3 | `ActivityCoordinator`'s two methods (`handle(_:)`, `activityPromoted()`) are the complete and correct minimal set — no third method needed | `ActivityCoordinator` Protocol Shape section | Low-Medium — if `handleSettingsChanged`'s devices-off branch and `flushTransients(.device)`'s partial delegation (see Call Sites table) turn out to need their own protocol methods (`reset()`/`cancelPendingWork()`) rather than being called as concrete (non-protocol) methods on the concrete `DeviceCoordinator` type, the protocol would need a third/fourth requirement — this research recommends keeping those as concrete methods specifically to avoid this, but the planner should confirm this holds once actually writing the extraction |

## Open Questions (RESOLVED)

1. **Should `handleSettingsChanged`'s device-toggle-off branch and `flushTransients(.device)`'s pending-poll clear be full protocol methods or concrete `DeviceCoordinator` methods called directly (not through `ActivityCoordinator`)?**
   - What we know: the controller already holds a concrete `deviceCoordinator: DeviceCoordinator` property (not just an `any ActivityCoordinator` existential), because it needs both the protocol-driven `handle`/`activityPromoted` calls (which could go through the protocol) AND the toggle-off/flush concrete calls documented in the Call Sites table.
   - What's unclear: whether holding both a concrete type AND intending it to conform to a protocol is worth the protocol at all, given only ONE coordinator exists this phase (D-02) — but the phase description explicitly mandates the protocol exists, so this isn't really open for the planner to skip, just to size correctly.
   - Recommendation: hold `private let deviceCoordinator = DeviceCoordinator(...)` as a concrete type (not `any ActivityCoordinator`), and have `DeviceCoordinator: ActivityCoordinator` be a conformance used only where the protocol type is actually useful (arguably nowhere yet, since there's only one — but D-02/the phase title mandate the protocol's existence as scaffolding for the future, not for present-day polymorphism). This is a case where the protocol is intentionally "unused" polymorphically in this phase and that is fine per the phase's own stated goal ("prove the coordinator shape").
   - **RESOLVED (Plan 16-02, Task 1):** `NotchWindowController` holds `private lazy var deviceCoordinator: DeviceCoordinator` as the concrete type, with `reset()`/`clearPendingBatteryPolls()`/`cancelPendingWork()`/`started(at:)` called directly (not through the protocol), exactly per the recommendation above.

2. **Does the on-device Bluetooth checklist (D-03) need a NEW verification document, or does it fold into the existing verify-work flow?**
   - What we know: D-03 lists four minimum scenarios (reconnect-flap debounce, launch-grace suppression, genuine disconnect, battery-poll promotion).
   - What's unclear: whether the plan should produce a dedicated `16-HUMAN-UAT.md`-style checklist file (mirroring Phase 2's `02-HUMAN-UAT.md` precedent found in STATE.md) or fold these four scenarios into `/gsd:verify-work`'s standard on-device pass.
   - Recommendation: planner should create an explicit checklist artifact (mirroring `02-HUMAN-UAT.md`) given the project's own history shows unstructured on-device checks get deferred/forgotten (STATE.md's "Phase 2's 8 on-device UAT scenarios... remain unexercised since v1.0 close").
   - **RESOLVED (Plan 16-02, Task 2):** `16-HUMAN-UAT.md` is created as a dedicated deliverable with all four D-03 scenarios enumerated, then executed and recorded in Plan 16-02's Task 3 checkpoint, exactly per the recommendation above.

## Environment Availability

Skipped — this phase has no new external dependencies (no new packages, no new frameworks). It
touches only existing first-party Swift files and the existing `IsletTests` target. `xcodebuild`/
Xcode 16+ availability is an existing, already-verified project prerequisite (not phase-specific).

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (`IsletTests` target, confirmed via `project.yml` and 20 existing test files) |
| Config file | `project.yml` (XcodeGen) — scheme `Islet` is shared/checked-in (`Islet.xcodeproj/xcshareddata/xcschemes/Islet.xcscheme`) |
| Quick run command | `xcodebuild build -scheme Islet -configuration Debug` (build-only gate — see pitfall below) |
| Full suite command | Manual: open Xcode, Cmd-U on the `Islet` scheme |

**Known project-memory pitfall (do not run `xcodebuild test` headlessly):** the `IsletTests`
target is hosted inside the full `Islet.app`, which boots the real `NSPanel`/`MediaRemote`/
`IOBluetooth` stack on test-runner launch — this hangs in a headless/CI context. Automated gates
in this project use `xcodebuild build` (compiles the test target too, catching type errors) as the
sampling proxy; the actual test EXECUTION is manual (`Cmd-U` in Xcode GUI) per existing project
convention. The plan's task-level "run tests" instructions must say "build to verify compilation,
then ask the user to Cmd-U in Xcode" — not "run `xcodebuild test`".

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| (D-01) | `BluetoothMonitor` ownership unchanged | build-only (no logic change) | `xcodebuild build -scheme Islet` | n/a |
| (D-02/extraction) | `DeviceCoordinator` reproduces `handleDevice`'s dedup/debounce/launch-grace logic | unit | new `DeviceCoordinatorTests.swift` — `xcodebuild build-for-testing -scheme Islet` then manual Cmd-U | ❌ Wave 0 (new file) |
| (D-02/extraction) | `matchPendingBatteryPoll` identity-match + cap-at-2 preserved | unit | same file | ❌ Wave 0 (new file) |
| (D-03) | Reconnect-flap debounce (real device, ~3s window) | manual on-device | n/a — physical Bluetooth device required | ❌ needs new UAT checklist (see Open Question 2) |
| (D-03) | Launch-grace suppression (device connected before app launch) | manual on-device | n/a | ❌ needs new UAT checklist |
| (D-03) | Genuine disconnect edge | manual on-device | n/a | ❌ needs new UAT checklist |
| (D-03) | Battery-poll promotion (device enqueued behind head, later promoted) | manual on-device | n/a | ❌ needs new UAT checklist |
| (regression) | Existing 20-file / IsletTests suite stays green | full suite | manual Cmd-U | ✅ exists |

### Sampling Rate
- **Per task commit:** `xcodebuild build -scheme Islet -configuration Debug` (catches compile errors in the extraction diff immediately — this is the ONLY thing safely automatable given the headless-test-hang constraint).
- **Per wave merge:** Manual Cmd-U in Xcode for the full `IsletTests` suite (20+ files, must stay green — mirrors Phase 15's D-05 "existing suite must stay green" bar).
- **Phase gate:** Full on-device Bluetooth checklist (D-03's four scenarios) MUST pass before `/gsd:verify-work` closes this phase — this is a HARD requirement per CONTEXT.md, not a nice-to-have.

### Wave 0 Gaps
- [ ] `IsletTests/DeviceCoordinatorTests.swift` — new file, covers the extracted stateful bookkeeping (dedup, debounce, launch-grace, pending-poll cap/identity-match). Mirror `LicenseStateTests.swift`'s constructor-fakes pattern; mirror `IslandResolverTests.swift`'s pattern for exercising the real (non-faked) `TransientQueue` struct directly.
- [ ] A dedicated on-device UAT checklist document for D-03's four scenarios (recommend `16-HUMAN-UAT.md`, mirroring the Phase 2 precedent `02-HUMAN-UAT.md` referenced in STATE.md) — framework install: none needed, this is a manual document the plan should produce as a deliverable, not a code file.

## Security Domain

`security_enforcement` is not present in `.planning/config.json` — treated as enabled per the
protocol's default, but this phase has essentially no new attack surface:

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | Not touched by this phase |
| V3 Session Management | No | Not touched by this phase |
| V4 Access Control | No | Not touched by this phase |
| V5 Input Validation | Marginal — `DeviceReading.name` is UNTRUSTED (T-05-01, pre-existing) | Already handled by `deviceLabel(name:address:)` in `DeviceActivity.swift` — plain-String-only, never interpolated into format strings/shell. This extraction moves the STATEFUL orchestration around this call, not the validation logic itself — no new validation surface introduced. |
| V6 Cryptography | No | Not touched by this phase |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Untrusted Bluetooth device name used unsafely (T-05-01, pre-existing, already mitigated) | Tampering | `deviceLabel`'s plain-String-only contract — unchanged by this extraction, verify the coordinator doesn't accidentally introduce a new formatting/logging call that interpolates `reading.name` unsafely |
| Flapping/malicious device flooding the transient queue (T-06-09, pre-existing, already mitigated) | Denial of Service | `shouldShowDeviceSplash`'s debounce gate + `TransientQueue.maxDepth` bound — unchanged by this extraction, this research's Pitfall list (items 1-12) exists specifically to ensure this mitigation isn't accidentally weakened during the move |
| OS-token leak on teardown (T-06-12, pre-existing, already mitigated) | — (resource exhaustion) | `bluetoothMonitor?.stop()` in `deinit` — untouched (D-01 keeps this on the controller); this extraction only adds one more thing (`deviceBatteryWork?.cancel()`) that must ALSO reliably fire on teardown, per the `nonisolated` discussion above |

No new threat surface is introduced by this phase — it is a pure code-shape move of
already-hardened logic. The only genuine risk is REGRESSING an existing mitigation during the
move (covered exhaustively in Common Pitfalls above), not introducing a new one.

## Sources

### Primary (HIGH confidence — direct source reads this session)
- `Islet/Notch/NotchWindowController.swift` (lines 1-170, 320-425, 460-560, 815-995, 1055-1080, 1200-1240) — the extraction target, shared triplet, call sites, and deinit teardown
- `Islet/Notch/BluetoothMonitor.swift` (full file) — `onReading` closure signature, off-main→main hop discipline, `nonisolated(unsafe)`/`nonisolated func stop()` teardown pattern
- `Islet/Notch/DeviceActivity.swift` (full file) — the pure seam `handleDevice` calls into, confirmed untouched by this phase
- `Islet/Notch/IslandResolver.swift` (lines 66-99) — `PendingBatteryPoll`, `matchPendingBatteryPoll`, `ActiveTransient`, `TransientQueue` (confirmed a `struct`/value type — informs the closure-vs-reference DI decision)
- `Islet/Notch/PowerSourceMonitor.swift` (partial, `nonisolated`/`@MainActor` pattern grep) — cross-check that the `nonisolated(unsafe)` teardown pattern is used consistently across all three monitors, not just `BluetoothMonitor`
- `IsletTests/LicenseStateTests.swift` (full file) — the DI-seam test template to mirror
- `.planning/phases/16-.../16-CONTEXT.md` (full file) — locked decisions D-01/D-02/D-03, discretion areas
- `.planning/phases/15-.../15-CONTEXT.md` (full file) — the `LicenseState` DI-seam worked example (Phase 15 item 4), Phase 16 scope confirmation (D-04)
- `.planning/STATE.md` (full file) — project history, Phase 2 UAT precedent, current phase position
- `project.yml` (grep) — Swift 5 language mode confirmation (3 locations), deployment target 14.0, test target/scheme names
- `.planning/config.json` (full file) — `nyquist_validation: true` confirms Validation Architecture section is required; no `security_enforcement` key present (defaults enabled)

### Secondary (MEDIUM confidence)
None — this research required no external library docs or WebSearch; it is a 100% internal-codebase extraction.

### Tertiary (LOW confidence)
None.

## Metadata

**Confidence breakdown:**
- Standard stack: N/A — no external stack, pure Swift-5-mode internal refactor
- Architecture: HIGH — every claim is a direct quote from the real source with line numbers, not inference
- Pitfalls: HIGH — all 12 pitfalls are the codebase's OWN documented "Finding N"/"gap-closure" comments, verbatim, not researcher-invented risks

**Research date:** 2026-07-08
**Valid until:** Effectively indefinite for the source-code facts (this is a snapshot of the current file — re-verify line numbers if other phases/quick-tasks touch `NotchWindowController.swift` before Phase 16 executes). Recommend re-grepping line numbers immediately before planning if any other work has landed on `main` since this research.
