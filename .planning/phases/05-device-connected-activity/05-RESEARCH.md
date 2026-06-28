# Phase 5: Device-Connected Activity - Research

**Researched:** 2026-06-28
**Domain:** IOBluetooth connect/disconnect notifications (legacy macOS framework) + reuse of the in-repo transient-activity pattern
**Confidence:** HIGH (architecture reuse + IOBluetooth API), MEDIUM (TCC/permission reality on macOS 26)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** ALL Bluetooth devices trigger a splash, not just audio devices (AirPods, headphones, speakers, AND keyboards, mice, controllers). Deliberately broadens past the requirement's "Bluetooth audio device" wording. Wiring: app-wide `IOBluetoothDevice.register(forConnectNotifications:selector:)` + per-device `register(forDisconnectNotification:selector:)`. **No device-class allowlist gate.** Noise from non-audio devices is mitigated by the at-launch/reconnect guards (D-04), not by class-filtering.
- **D-02:** Device name + a device-specific glyph. Match by device name/class to pick the closest SF Symbol (AirPods / AirPods Pro / AirPods Max / headphones / Beats → specific glyphs; generic Bluetooth icon fallback for everything else — mice, keyboards, unknown). Exact name→symbol mapping + fallback symbol are Claude's discretion + on-device tuning. Device name source = IOBluetooth `device.name` (fallback to address / `nameOrAddress` if nil).
- **D-03:** Same wings splash for connect and disconnect, visually distinguished. Connect = colored/active icon; disconnect = dimmed/greyed icon and/or a small "Disconnected" label. One layout, two states — NOT two separate animated scenes (mirrors Phase 3 D-04). Exact dimming/label styling is discretion + on-device tuning.
- **D-04:** Suppress the at-launch / wake connect burst AND debounce rapid reconnect flapping. Devices already connected when the app starts (or that all re-fire "connect" on login/wake) must NOT splash — only genuine post-launch user-initiated edges splash. Reconnect flapping is debounced so it doesn't produce repeated splashes. Must stay event-driven, no polling (idle CPU ~0%) — burst suppression is a startup-grace / seen-set mechanism, NOT a timer loop.
- **D-05:** Device splash takes brief precedence, then yields to the ambient / now-playing state — mirroring Phase 3's charging D-11. Insert AirPods → connect splash shows briefly → then returns to the now-playing (or ambient) state. Minimal and device-specific — NOT a general resolver (that is Phase 6 / COORD-01). No speculative abstraction.
- **D-06:** ~3s auto-dismiss via a single scheduled `DispatchWorkItem` collapse (reuse the `graceWorkItem`/`dismissWorkItem` template), NOT a recurring timer. Hover pauses auto-dismiss; click is informational only (Phase 3 D-09/D-10). Splash visibility routes through the single `updateVisibility()` site so it inherits the fullscreen + clamshell hide for free (Phase 2 D-09).
- **D-07:** Same testable-seam discipline as `PowerActivity.swift` / `NowPlayingPresentation.swift`:
  - A **pure** `DeviceActivity` presentation seam (Foundation-only) mapping a device reading → presentation (connected/disconnected + name + glyph-kind), plus a **pure connect/disconnect edge + burst-suppression/debounce predicate**, all unit-tested in milliseconds (RED→GREEN).
  - A separate `@Published` device-activity **state model** (mirror `ChargingActivityState` / `NowPlayingState`) — NOT folded into the `InteractionPhase` gesture machine.
  - A thin **IOBluetooth monitor** wrapping the connect/disconnect notifications, hopping callbacks to the **main thread** before touching `@Published`/AppKit, with **deinit teardown** of registrations.

### Claude's Discretion

- The exact name→SF-Symbol mapping and the generic fallback glyph (D-02).
- The exact burst-suppression / debounce mechanism (startup grace window vs seen-set of already-connected devices; debounce interval) — keep it event-driven, no polling (D-04).
- The exact disconnect dimming/label styling (D-03) and wing geometry reuse.
- Whether the device-activity state is one model holding a connect/disconnect enum vs two — keep it device-specific, no general resolver (D-05).
- IOBluetooth specifics: selector signatures, the `IOBluetoothUserNotification` handle for disconnects, matching device identity, entitlement check (un-sandboxed → low-friction).
- Spring/duration tuning (start from Phase-2 vocabulary: response ≈ 0.35, damping ≈ 0.65).

### Deferred Ideas (OUT OF SCOPE)

- **Per-bud AirPods battery %** on connect (DEV-03) → later milestone; not in Phase 5.
- **General multi-activity priority resolver** (charging + media + device under one ranked policy) → Phase 6 (COORD-01). Phase 5 does only the minimal device-vs-now-playing brief-precedence (D-05).
- **Settings toggle** to enable/disable the device activity + accent/theme → Phase 6 (APP-03).
- **Device-class filtering** (audio-only vs all) — considered and rejected in favor of all-devices + noise guards (D-01); could revisit as a setting later.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DEV-01 | Connecting AirPods or a Bluetooth audio device shows a connect activity (device name + icon) in the island | App-wide `+registerForConnectNotifications:selector:` fires for ANY device connect (verified SDK macOS 26). Name from `device.name`; glyph from a pure name/class → SF-Symbol mapping seam. Renders through a new `device(...)` branch in `NotchPillView` wings (same flat-strip shape + `matchedGeometryEffect(id: "island")`). D-01 broadens to all devices. |
| DEV-02 | Disconnecting a device shows a brief disconnect activity | Per-device `-registerForDisconnectNotification:selector:` token, registered inside the connect callback and retained until it fires. Disconnect drives the SAME wings layout in a dimmed/"Disconnected" state (D-03). |

**Coexistence note:** the device splash is the THIRD activity to share `NotchWindowController` (after charging + now-playing). D-05 mandates only minimal device-vs-now-playing brief-precedence — the full ranked resolver is COORD-01 / Phase 6. Implement precedence as one more line in `NotchPillView`'s if-ordering, NOT a new abstraction.
</phase_requirements>

## Summary

Phase 5 is a **third clone of an already-proven, twice-implemented in-repo pattern**, fed by a new (to this project) but old (to macOS) event source: IOBluetooth connect/disconnect notifications. The architecture is not in question — `PowerActivity.swift` (pure seam) + `ChargingActivityState.swift` (`@Published` model) + `PowerSourceMonitor.swift` (thin `@MainActor` glue with start/stop + main-hop + nonisolated teardown) is the exact template, mirrored a second time by the now-playing trio. The device feature is `DeviceActivity.swift` + `DeviceActivityState.swift` + `BluetoothMonitor.swift`, wired into `NotchWindowController` exactly like `powerMonitor`/`nowPlayingMonitor`, rendered via a new branch in `NotchPillView`'s wings, dismissed by a `DispatchWorkItem` clone of `scheduleActivityDismiss`.

The genuinely new knowledge is IOBluetooth. The two registration calls are **verified against the macOS 26 SDK on this build machine**: `+ registerForConnectNotifications:selector:` is a **class** method (fires for ANY device's connect, returns a self-retaining `IOBluetoothUserNotification`), and `- registerForDisconnectNotification:selector:` is a **per-device instance** method (returns a token you must keep alive until it fires). Both selectors take `(IOBluetoothUserNotification, IOBluetoothDevice)`. The notification machinery is run-loop driven (event-driven, no polling — satisfies the idle-CPU criterion for free) and delivers callbacks on the main thread when registered from main.

The one MEDIUM-confidence area — and the single highest-risk item for **Success Criterion 3 ("no intrusive permission prompts")** — is the macOS 26 **TCC/Bluetooth-permission reality**. Sources agree that *daemons* are blocked and that *active* Bluetooth use (`pairedDevices()`, opening connections, scanning) is gated behind a TCC prompt requiring `NSBluetoothAlwaysUsageDescription` + (when sandboxed) the `com.apple.security.device.bluetooth` entitlement. What sources do NOT definitively confirm is whether **passively observing connect/disconnect notifications** from an un-sandboxed GUI/agent app triggers that prompt. This MUST be verified on-device early (Wave 0 spike) before the visual work, because it directly decides Success Criterion 3 and may require adding an `INFOPLIST_KEY_NSBluetoothAlwaysUsageDescription` to `project.yml`.

**Primary recommendation:** Clone the charging trio (pure `DeviceActivity` seam + `@Published` `DeviceActivityState` + thin `@MainActor` `BluetoothMonitor`), wire it into `NotchWindowController` exactly as `powerMonitor` is wired, and add a `device(...)` branch to `NotchPillView`'s wings. **Spike the IOBluetooth permission question on-device FIRST** (does observing connect/disconnect prompt?) — it is the only unknown that can move scope.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| IOBluetooth.framework | macOS 26 SDK (present on build machine) | Connect/disconnect notifications for system paired devices | `[VERIFIED: /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/.../IOBluetooth.framework]` — the framework is on the build machine; CLAUDE.md mandates it (NOT Core Bluetooth) for paired-device connect/disconnect; legacy but the correct and working abstraction for "did a paired device connect to the system?" |
| Foundation | system | Pure `DeviceActivity` presentation + edge/debounce seam (Foundation-only, unit-tested) | `[VERIFIED: codebase]` — `PowerActivity.swift` / `NowPlayingPresentation.swift` import ONLY Foundation; the device seam follows |
| AppKit + SwiftUI | macOS 14 SDK floor | `@Published`/`ObservableObject` model → `NSHostingView` → `NotchPillView` wings | `[VERIFIED: codebase]` — the established UI stack |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| SF Symbols (system) | macOS 14+ | Device glyphs: `airpods`, `airpodspro`, `airpodsmax`, `headphones`, `beats.*`, generic Bluetooth fallback | D-02 — name→symbol mapping; verify each symbol name renders on macOS 14 floor (some AirPods/Beats glyphs were added in later SF Symbols releases — confirm on-device, see Pitfalls) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| IOBluetooth | Core Bluetooth (`CBCentralManager`) | **WRONG abstraction** — Core Bluetooth is for acting as a BLE *central* to a custom peripheral, NOT for observing system paired-device connect/disconnect. CLAUDE.md "What NOT to Use" rejects it. `[CITED: CLAUDE.md]` |
| IOBluetooth connect-notification | Polling `IOBluetoothDevice.pairedDevices()` + diffing `isConnected()` | Violates the no-polling / idle-CPU criterion (D-04) AND `pairedDevices()` is the call most likely to trip the TCC prompt (sources flag it specifically). Avoid. `[CITED: gist comment, jamesmartin]` |
| Connect-notification name | `remoteNameRequest(_:withPageTimeout:)` | Only needed as a FALLBACK if `device.name` is nil at connect time (Pitfall) — issues an active name request. Prefer the cached `name`/`nameOrAddress` first. `[CITED: developer.apple.com/.../remotenamerequest]` |

**Installation:** No package to add. IOBluetooth is a system framework — `import IOBluetooth` in the new `BluetoothMonitor.swift`. XcodeGen auto-links system frameworks referenced by `import`, so no `project.yml` dependency edit is needed for the framework itself. (A `project.yml` change MAY be needed for the Bluetooth usage-description Info.plist key — see Security/Environment.)

**Version verification:** N/A — no third-party packages. The IOBluetooth API surface was verified directly against the installed macOS 26 SDK headers (see Code Examples + Sources).

## Architecture Patterns

### Recommended Project Structure (new files mirror the charging trio exactly)
```
Islet/Notch/
├── DeviceActivity.swift          # PURE seam (Foundation-only): DeviceReading → DeviceActivity?
│                                 #   + shouldShowDeviceSplash(...) edge/burst/debounce predicate
│                                 #   + name/class → DeviceGlyph mapping (pure)        [clone of PowerActivity.swift]
├── DeviceActivityState.swift     # @Published holder: var activity: DeviceActivity?    [clone of ChargingActivityState.swift]
├── BluetoothMonitor.swift        # @MainActor thin IOBluetooth glue: start()/stop(),    [clone of PowerSourceMonitor.swift]
│                                 #   connect class-notification + per-device disconnect
│                                 #   tokens, main-hop, nonisolated teardown
└── (edits) NotchPillView.swift   # add a device(...) wings branch + precedence if-line
   (edits) NotchWindowController.swift  # add deviceState + bluetoothMonitor + handleDevice + scheduleDeviceDismiss
IsletTests/
└── DeviceActivityTests.swift     # clone of PowerActivityTests.swift — the pure matrix in ms
```
`[VERIFIED: codebase]` — `project.yml` auto-discovers any `.swift` under `Islet/`; run `xcodegen generate` after adding files (no manual `.xcodeproj` edits).

### Pattern 1: The three-part activity pattern (the template to clone)
**What:** (a) a pure Foundation-only seam that maps a raw reading → a presentation enum + fires an edge predicate; (b) a tiny `@Published` model with no logic; (c) a thin `@MainActor` monitor that owns the system event source, hops to main, and tears down in `stop()`.
**When to use:** Every activity in this app. Charging and now-playing both do exactly this. Device is the third.
**Example (the charging shape this phase mirrors):**
```swift
// Source: codebase Islet/Notch/PowerActivity.swift (pure seam) + ChargingActivityState.swift
struct PowerReading: Equatable { /* plain values, tests build by hand */ }
enum ChargingActivity: Equatable { case charging(percent: Int); case full(percent: Int); case onBattery(percent: Int) }
func powerActivity(from r: PowerReading) -> ChargingActivity? { /* total pure mapping; nil == no splash */ }
func shouldTriggerSplash(previous: ChargingActivity?, next: ChargingActivity?) -> Bool { /* pure edge predicate */ }

final class ChargingActivityState: ObservableObject { @Published var activity: ChargingActivity? }
```
The device analogue: `DeviceReading` (e.g. `name: String?`, `classMajor: UInt32`, `addressString: String?`, `event: .connected/.disconnected`) → `deviceActivity(from:)` → `DeviceActivity` (`.connected(name:glyph:)` / `.disconnected(name:glyph:)`); plus `shouldShowDeviceSplash(...)` carrying the burst-suppression/debounce logic (D-04).

### Pattern 2: The thin monitor (main-hop + nonisolated teardown)
**What:** `@MainActor final class` owning the system source via `nonisolated(unsafe)` stored handles so the controller's `nonisolated deinit` can call `stop()`. The callback hops to main before touching `@Published`.
**When to use:** Any file that touches a system event framework (IOKit, MediaRemote, IOBluetooth).
**Example (the IOKit shape; IOBluetooth mirrors the lifecycle):**
```swift
// Source: codebase Islet/Notch/PowerSourceMonitor.swift
@MainActor final class PowerSourceMonitor {
    private nonisolated(unsafe) var runLoopSource: CFRunLoopSource?
    private let onChange: (PowerReading) -> Void
    init(onChange: @escaping (PowerReading) -> Void) { self.onChange = onChange }
    func start() { /* create source, CFRunLoopAddSource(main), emit initial reading */ }
    nonisolated func stop() { /* CFRunLoopRemoveSource — safe from nonisolated deinit */ }
}
```
For IOBluetooth the analogue holds the connect `IOBluetoothUserNotification` and a dictionary of per-device disconnect tokens; `stop()` calls `.unregister()` on each. (Note: IOBluetooth selectors require an `@objc` target — see Pitfall 5.)

### Pattern 3: Wiring into NotchWindowController (the integration hub)
**What:** The controller owns each activity's `@Published` state + monitor, constructs+starts the monitor in `start()`, routes the event handler through the SINGLE `updateVisibility()` show/hide site, and schedules a one-shot `DispatchWorkItem` dismiss.
**Example (charging — copy this for device):**
```swift
// Source: codebase Islet/Notch/NotchWindowController.swift (handlePower + scheduleActivityDismiss)
private func handlePower(_ reading: PowerReading) {
    let next = powerActivity(from: reading)
    guard didSeedInitialPower else { didSeedInitialPower = true; lastActivity = next; return } // launch suppression
    let fire = shouldTriggerSplash(previous: lastActivity, next: next)
    lastActivity = next
    if fire, let activity = next {
        withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) { chargingState.activity = activity }
        updateVisibility()           // SOLE show/hide site — inherits fullscreen/clamshell hide
        scheduleActivityDismiss()    // ~3s one-shot DispatchWorkItem
    } /* else: in-place % update without re-firing */
}
```
The `didSeedInitialPower` gate is **the exact template for D-04's at-launch burst suppression** — seed a "seen" set on the first callback(s) without splashing.

### Pattern 4: The wings render branch (NotchPillView)
**What:** The device splash is one more flat-strip branch in `NotchPillView.body`'s if-ordering, sharing the `matchedGeometryEffect(id: "island")` morph and `wingsSize` so the single black island morphs between charging/media/device/expanded/collapsed.
**Where:** Add the device branch to the precedence chain. Current order is `charging > expanded > media-wings > collapsed`. D-05 wants the device splash to take brief precedence then yield to now-playing — so place the device branch ABOVE the media-wings branch (and decide its rank vs `charging`/`expanded`; simplest consistent with D-05: device alongside charging as a transient that briefly wins, then clears after ~3s and the body falls through to media/idle automatically).
```swift
// Source: codebase Islet/Notch/NotchPillView.swift (existing wings + precedence)
if let activity = charging.activity { wings(for: activity) }
else if let dev = device.activity { deviceWings(for: dev) }   // NEW — D-05 brief precedence
else if interaction.isExpanded { /* media controls / date-time / unavailable */ }
else if nowPlaying.presentation != .none { mediaWings(...) }
else { collapsedIsland }
```

### Anti-Patterns to Avoid
- **A general activity resolver / priority engine.** D-05 explicitly forbids it — that is COORD-01 / Phase 6. One more if-line only. `[CITED: CONTEXT.md D-05]`
- **A device-class allowlist gate.** D-01 says ALL devices splash; noise is handled by D-04 guards, not by filtering. `[CITED: CONTEXT.md D-01]`
- **A polling loop / repeating Timer** to detect connects or to debounce. Event-driven only; the burst guard is a seen-set/grace flag, the dismiss is a one-shot `DispatchWorkItem`. `[CITED: CONTEXT.md D-04, D-06]`
- **Folding device state into `NotchInteractionState`.** Keep a separate `@Published` model so the Phase-2 gesture tests stay intact. `[CITED: CONTEXT.md D-07]`
- **A second show/hide site.** Route device visibility through the one `updateVisibility()` (inherits fullscreen/clamshell hide). `[CITED: codebase Pattern 7]`

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| "Did a paired device connect?" | A Core Bluetooth central + manual pairing-state diffing | `+IOBluetoothDevice.register(forConnectNotifications:selector:)` | Core Bluetooth is the wrong abstraction; IOBluetooth gives the exact system event. `[CITED: CLAUDE.md]` |
| Detecting disconnects | Polling `isConnected()` on a timer | Per-device `-register(forDisconnectNotification:selector:)` token | Event-driven, no polling (idle-CPU criterion). `[VERIFIED: SDK header]` |
| The transient splash / dismiss / hide-in-fullscreen | New window/dismiss/visibility logic | Clone `ChargingActivityState` + `scheduleActivityDismiss` + the single `updateVisibility()` | Already built, tested, and on-device-verified twice. `[VERIFIED: codebase]` |
| The wings layout + morph | A new SwiftUI scene | A `device(...)` branch reusing `NotchShape` + `wingsSize` + the shared `matchedGeometryEffect` namespace | The morph identity must be shared or the island cross-fades instead of morphing. `[VERIFIED: codebase NotchPillView]` |

**Key insight:** The only thing genuinely new in this phase is ~30 lines of IOBluetooth registration glue. Everything else is a copy of a pattern that has shipped and been UAT-verified twice. The risk is concentrated in (1) the TCC permission question and (2) IOBluetooth's selector/retention/name-caching quirks — not in the app architecture.

## Common Pitfalls

### Pitfall 1: The at-launch / wake "connect burst" (D-04 — locked)
**What goes wrong:** Waking a Mac with 4 paired devices fires `connect` for all 4; launching the app while AirPods are already connected may fire `connect` immediately. Without suppression that's 4 splashes on wake / a spurious splash on launch.
**Why it happens:** The class connect-notification fires for "any device connection," including the burst the system replays on login/wake; an already-connected device may also be delivered at registration time.
**How to avoid:** Mirror `didSeedInitialPower` — a startup-grace window (e.g. ignore connects in the first ~1.5–2s after `start()`) and/or a "seen-set" seeded from the devices already connected at launch (read once via `IOBluetoothDevice.pairedDevices()` filtered by `isConnected()` — but note this read is the TCC-sensitive call; see Pitfall 6). Only genuine post-launch edges splash. The mechanism choice is Claude's discretion (D-04).
**Warning signs:** Multiple splashes immediately after unlock; a splash on every app launch.

### Pitfall 2: Reconnect flapping (D-04 — locked)
**What goes wrong:** AirPods that drop and re-pair within a second produce repeated connect/disconnect splashes.
**How to avoid:** Debounce per device identity (`addressString`) — suppress a repeat connect/disconnect for the same device within a short window (e.g. 2–3s). Implement as a pure predicate in the `DeviceActivity` seam keyed on `(addressString, event, lastSeenTime)` so it is unit-testable in ms. Keep it event-driven — the "last seen" timestamps are stored, not polled.
**Warning signs:** A burst of identical splashes when a device's link is unstable.

### Pitfall 3: `device.name` is nil / stale at connect time
**What goes wrong:** The splash shows an address or "Unknown" instead of "AirPods Pro". `[CITED: SDK header — "name only returns a value if a remote name request has been performed on the target device"]`
**Why it happens:** `name` (and `deviceClassMajor`) are only meaningful once the device has been seen during inquiry / a remote-name request has completed. For an already-paired device reconnecting, the name is *usually* cached, but not guaranteed.
**How to avoid:** Read `device.name`; fall back to `device.nameOrAddress`, then `addressString`. The mapping seam must tolerate nil → generic glyph + address label. Only if name quality proves bad on-device, consider an async `remoteNameRequest(_:withPageTimeout:)` fallback (adds latency — design the UI to fill the name in asynchronously, exactly as now-playing fills artwork async). `[CITED: developer.apple.com/.../remotenamerequest]`
**Warning signs:** Addresses instead of product names in the splash, especially right after pairing a brand-new device.

### Pitfall 4: The disconnect token must outlive the registration; connect token must NOT be over-managed
**What goes wrong:** Disconnect never fires (token deallocated), or a crash from touching an unregistered notification.
**Why it happens:** Two different lifetimes:
- **Connect (class) notification:** the SDK header states *"It is not necessary to retain the result... valid for as long as the notification is registered."* `[VERIFIED: SDK header]` So one `IOBluetoothUserNotification` for the lifetime of the monitor, `.unregister()`-ed in `stop()`.
- **Disconnect (per-device) notification:** the header gives NO such "no need to retain" guarantee and the token is per-connection. Store it in a `[String: IOBluetoothUserNotification]` keyed by `addressString` (or whatever the connect callback gives you), keep it alive until the disconnect selector fires (or the device reconnects), then drop/replace it. `[VERIFIED: SDK header — registerForDisconnectNotification returns a token, "valid for the current connection," unregister via -unregister]`
**How to avoid:** In the connect callback, register the per-device disconnect notification and store its token; in the disconnect callback, remove the stored token. In `stop()`, `.unregister()` the connect token and every stored disconnect token.
**Warning signs:** Connect splashes work, disconnect splashes never appear; or a crash on app quit / device churn.

### Pitfall 5: The selector target must be `@objc` and the callback must hop to main
**What goes wrong:** `register(forConnectNotifications:selector:)` returns a non-nil token but the selector is never invoked (Objective-C can't find it), or `@Published`/AppKit is touched off-main.
**Why it happens:** IOBluetooth uses Objective-C target/selector dispatch — the observer's method must be `@objc`. The callback delivers on the run loop the registration ran on.
**How to avoid:** Make `BluetoothMonitor` an `NSObject` subclass (or expose `@objc` methods) with `@objc func deviceConnected(_ note: IOBluetoothUserNotification, device: IOBluetoothDevice)` and `@objc func deviceDisconnected(_ note: IOBluetoothUserNotification, device: IOBluetoothDevice)`, using `#selector(...)`. Register from the **main** run loop in `start()` so callbacks arrive on main; still defensively `DispatchQueue.main.async` before mutating `@Published`, mirroring `PowerSourceMonitor`. The two selector args are `(IOBluetoothUserNotification, IOBluetoothDevice)` for BOTH connect and disconnect. `[VERIFIED: SDK header]`
**Warning signs:** Token is non-nil but no callbacks; "unrecognized selector" crash; UI updates that race or assert off-main.

### Pitfall 6: TCC / Bluetooth permission prompt (Success Criterion 3 — the one to verify FIRST)
**What goes wrong:** On macOS 26 the app shows a "wants to use Bluetooth" prompt (or silently gets no events), violating Success Criterion 3 ("no intrusive permission prompts").
**Why it happens:** Since macOS Sonoma, IOBluetooth access is gated by TCC (`kTCCServiceBluetoothAlways`). Daemons cannot get this grant at all; sandboxed apps need `com.apple.security.device.bluetooth`; the prompt requires `NSBluetoothAlwaysUsageDescription` to be present. `pairedDevices()` / active scanning are specifically flagged as prompt-triggering. `[CITED: developer.apple.com/forums/thread/738748, thread/758094; gist comment]`
**What is uncertain:** Whether *passively observing* connect/disconnect notifications (no `pairedDevices()`, no scanning) from an **un-sandboxed LSUIElement GUI agent** triggers the prompt at all. Sources confirm GUI/agent apps run in the user TCC context (unlike daemons) but do NOT definitively state whether the passive-observe path prompts. **This is [ASSUMED] and must be settled on-device.**
**How to avoid / decide:**
1. **Wave 0 spike (before any UI work):** in the real signed `.app`, register only the connect/disconnect notifications (no `pairedDevices()` read), with NO usage-description key, and observe on macOS 26 whether (a) a prompt appears and (b) callbacks fire. This single test decides Success Criterion 3.
2. If a prompt appears or events don't fire without it, add `INFOPLIST_KEY_NSBluetoothAlwaysUsageDescription` to `project.yml` (the project uses `GENERATE_INFOPLIST_FILE: YES`, so this is a one-line build-setting addition — there is no physical Info.plist). A usage-description string makes the prompt non-"intrusive" (one-time, expected), which likely satisfies Criterion 3; a *recurring* or *event-blocking* prompt would not.
3. Avoid `pairedDevices()` entirely if it proves prompt-triggering — derive the at-launch "already connected" seen-set another way (e.g. treat the first ~2s of connects as the burst, per D-04) so the no-prompt path is preserved.
**Warning signs:** A Bluetooth permission dialog on first launch; connect events never arriving; events arriving on Ventura/Sonoma in testing but not on the macOS 26 build machine.

### Pitfall 7: SF Symbol availability on the macOS 14 floor
**What goes wrong:** A device glyph (`airpodspro`, `airpodsmax`, specific Beats symbols) renders as a missing-symbol box on macOS 14, because the symbol was added in a later SF Symbols release.
**How to avoid:** The mapping seam must have a **generic Bluetooth fallback** (D-02 already requires this). Verify each specific glyph name exists at the macOS 14 deployment floor (and on the macOS 26 build machine) before relying on it; when in doubt, fall back to `headphones` or a generic `wave.3.right`/Bluetooth-style glyph. Treat the exact symbol set as on-device tuning (D-02 discretion).
**Warning signs:** Empty/placeholder glyph squares in the splash for some device types.

## Code Examples

### Verified IOBluetooth method signatures (from the macOS 26 SDK on this build machine)
```objc
// Source: VERIFIED — /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/System/Library/
//         Frameworks/IOBluetooth.framework/Headers/objc/IOBluetoothDevice.h (lines 136, 151)

// CLASS method — fires for ANY device connect. Self-retaining while registered.
+ (IOBluetoothUserNotification *)registerForConnectNotifications:(id)observer selector:(SEL)inSelector;

// INSTANCE method — per-device. Returns a token you keep until it fires.
- (IOBluetoothUserNotification *)registerForDisconnectNotification:(id)observer selector:(SEL)inSelector;

// Header @discussion (verbatim): the selector "should accept two arguments. The first is the
// user notification object. The second is the device that was connected." (same shape for disconnect)
// Connect result: "It is not necessary to retain the result. ... valid for as long as the
//   notification is registered. ... Once -unregister is called on it, it will no longer be valid."
// Disconnect result: "To unregister the notification, call -unregister of the returned
//   IOBluetoothUserNotification object."
```

### Verified device-class constants (macOS 26 SDK)
```c
// Source: VERIFIED — MacOSX.sdk/.../IOBluetooth.framework/Headers/BluetoothAssignedNumbers.h
kBluetoothDeviceClassMajorMiscellaneous = 0x00,  // Miscellaneous
kBluetoothDeviceClassMajorAudio         = 0x04,  // Headset, Speaker, Stereo, etc... (AirPods, headphones)
kBluetoothDeviceClassMajorPeripheral    = 0x05,  // Mouse, Joystick, Keyboards, etc...
// device.deviceClassMajor is UInt32; compare against these. NOTE D-01: do NOT gate the splash
// on class — use the class only to pick the glyph (audio → headphone/AirPods glyph; else generic).
```

### The Swift monitor shape (synthesized from the verified API + the in-repo PowerSourceMonitor template — NOT yet compiled in this session; validate in Wave 0)
```swift
// Source: SYNTHESIZED from VERIFIED SDK signatures + codebase PowerSourceMonitor.swift pattern.
//         [ASSUMED] exact compile under Swift 5 mode — verify on build.
import IOBluetooth
import AppKit

@MainActor
final class BluetoothMonitor: NSObject {                 // NSObject so @objc selectors resolve (Pitfall 5)
    private nonisolated(unsafe) var connectToken: IOBluetoothUserNotification?
    private nonisolated(unsafe) var disconnectTokens: [String: IOBluetoothUserNotification] = [:]
    private let onEvent: (_ name: String?, _ classMajor: UInt32, _ address: String?, _ connected: Bool) -> Void

    init(onEvent: @escaping (String?, UInt32, String?, Bool) -> Void) { self.onEvent = onEvent; super.init() }

    func start() {                                       // register on MAIN so callbacks arrive on main
        connectToken = IOBluetoothDevice.register(forConnectNotifications: self,
                                                  selector: #selector(deviceConnected(_:device:)))
    }

    @objc private func deviceConnected(_ note: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        let addr = device.addressString
        // register the per-device disconnect token and keep it alive (Pitfall 4)
        if let addr, disconnectTokens[addr] == nil {
            disconnectTokens[addr] = device.register(forDisconnectNotification: self,
                                                     selector: #selector(deviceDisconnected(_:device:)))
        }
        DispatchQueue.main.async {                       // defensive main-hop before @Published (Pitfall 5)
            self.onEvent(device.name, device.deviceClassMajor, addr, true)
        }
    }

    @objc private func deviceDisconnected(_ note: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        let addr = device.addressString
        if let addr { disconnectTokens[addr]?.unregister(); disconnectTokens[addr] = nil }
        DispatchQueue.main.async {
            self.onEvent(device.name, device.deviceClassMajor, addr, false)
        }
    }

    nonisolated func stop() {                            // callable from the controller's nonisolated deinit
        connectToken?.unregister(); connectToken = nil
        disconnectTokens.values.forEach { $0.unregister() }
        disconnectTokens.removeAll()
    }
}
```
This is a design sketch to guide the planner — the exact Swift-5-mode concurrency annotations (`nonisolated(unsafe)`, `@MainActor`, `@objc`) must be validated at build, mirroring how `PowerSourceMonitor`/`NowPlayingMonitor` were verified on-device.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Free IOBluetooth access | TCC-gated (`kTCCServiceBluetoothAlways`), daemons blocked | macOS Sonoma (14) | Must verify the passive-observe path doesn't prompt on macOS 26; may need `NSBluetoothAlwaysUsageDescription`. `[CITED: forums/738748]` |
| `IOBluetooth` for everything | Apple steers NEW BLE work to Core Bluetooth | ongoing | IOBluetooth is legacy but remains the ONLY correct API for paired-device connect/disconnect; watch for future deprecation. `[CITED: CLAUDE.md]` |

**Deprecated/outdated:**
- Running Bluetooth observation from a **daemon** — blocked by TCC; not relevant here (this app is an LSUIElement GUI agent, the correct context). `[CITED: forums/758094]`

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Passively observing connect/disconnect notifications from an un-sandboxed LSUIElement GUI agent on macOS 26 does NOT trigger an intrusive TCC prompt (or, if it does, a one-time prompt with a usage string satisfies Success Criterion 3). | Pitfall 6 / Security | **HIGH** — directly decides Success Criterion 3 and whether a `project.yml` Info.plist key is needed. **Verify in Wave 0 spike before UI work.** |
| A2 | The class connect-notification reliably delivers an already-connected device's connect event (or the burst on wake), so the at-launch seen-set/grace approach is sufficient for D-04 without polling `pairedDevices()`. | Pitfall 1 | MEDIUM — if already-connected devices don't re-fire, the seen-set may need a `pairedDevices()` read (which is TCC-sensitive). |
| A3 | `device.name` is reliably populated (cached) for an already-paired device at reconnect time, so the address-fallback is rarely hit. | Pitfall 3 | LOW — fallback chain (name → nameOrAddress → address) keeps it functional regardless; only affects label quality. |
| A4 | The synthesized `BluetoothMonitor` compiles cleanly under Swift 5 language mode with the shown `@MainActor` / `nonisolated(unsafe)` / `@objc` annotations. | Code Examples | MEDIUM — exact concurrency annotations may need adjustment at build, as happened for `PowerSourceMonitor`/`NowPlayingMonitor`. |
| A5 | Specific AirPods/Beats SF Symbols exist at the macOS 14 deployment floor. | Pitfall 7 | LOW — generic-Bluetooth fallback (D-02) makes a missing glyph cosmetic, not breaking. |

## Open Questions

1. **Does observing IOBluetooth connect/disconnect prompt for permission on macOS 26?**
   - What we know: daemons are blocked; `pairedDevices()`/scanning prompt; GUI agents run in the user TCC context.
   - What's unclear: whether the passive-observe path specifically prompts.
   - Recommendation: **Wave 0 on-device spike in the signed `.app`** — register notifications with no usage string, observe prompt + event delivery. Decide Criterion 3 from the result; add `NSBluetoothAlwaysUsageDescription` only if needed.

2. **Device-vs-now-playing precedence rank (D-05).**
   - What we know: device splash takes brief precedence then yields; minimal, no resolver.
   - What's unclear: exact if-ordering vs `charging`/`expanded`.
   - Recommendation: place the device branch as a transient alongside charging (briefly wins, ~3s `DispatchWorkItem` clears it, body falls through to media/idle automatically) — matches how charging coexists today. Tune on-device.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| IOBluetooth.framework | DEV-01/02 connect/disconnect notifications | ✓ | macOS 26 SDK (build machine) | — |
| `kBluetoothDeviceClassMajorAudio` etc. constants | Glyph selection (D-02) | ✓ | BluetoothAssignedNumbers.h (verified) | — |
| Xcode / XcodeGen toolchain | Build, auto-discover new `.swift` | ✓ | Xcode 26.6 / Swift 6.3.3 (Swift 5 mode) | — |
| `NSBluetoothAlwaysUsageDescription` (Info.plist key) | Possibly required for no-prompt observation | ⚠ TBD | add via `INFOPLIST_KEY_*` in `project.yml` if Wave 0 spike shows it's needed | Spike decides |
| A physical Bluetooth device (AirPods + a mouse/keyboard) | On-device UAT of connect/disconnect + glyph + burst guard | (user-side) | — | — |

**Missing dependencies with no fallback:** None — IOBluetooth and the constants are present on the build machine.

**Missing dependencies with fallback:** The Bluetooth usage-description key is conditional on the Wave 0 spike outcome (one-line `project.yml` addition).

## Validation Architecture

> `.planning/config.json` is absent → nyquist_validation treated as ENABLED.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (`IsletTests` bundle, hosted in the app for `@testable import Islet`) |
| Config file | `project.yml` (XcodeGen) — `IsletTests` target |
| Quick run command | `xcodebuild test -scheme Islet -only-testing:IsletTests/DeviceActivityTests` |
| Full suite command | `xcodebuild test -scheme Islet` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DEV-01 | name/class → DeviceActivity + glyph mapping (connected) | unit (pure) | `xcodebuild test -scheme Islet -only-testing:IsletTests/DeviceActivityTests` | ❌ Wave 0 |
| DEV-01 | already-connected / at-launch burst is suppressed | unit (pure predicate) | same | ❌ Wave 0 |
| DEV-01 | reconnect flap within window is debounced | unit (pure predicate) | same | ❌ Wave 0 |
| DEV-01/02 | nil name → address fallback in mapping | unit (pure) | same | ❌ Wave 0 |
| DEV-02 | disconnect maps to the dimmed/"Disconnected" presentation | unit (pure) | same | ❌ Wave 0 |
| DEV-01/02 | IOBluetooth callbacks fire, hop to main, drive `@Published`; deinit unregisters; NO permission prompt | **manual / on-device UAT** | run signed `.app`, connect/disconnect AirPods + a mouse | — (cannot unit-test real BT hardware; mirrors PowerSourceMonitor/NowPlayingMonitor) |
| DEV-01/02 | wings render + morph + ~3s dismiss + hover-pause + fullscreen-hide | manual / on-device UAT | run `.app` | — |

### Sampling Rate
- **Per task commit:** `xcodebuild test -scheme Islet -only-testing:IsletTests/DeviceActivityTests`
- **Per wave merge:** `xcodebuild test -scheme Islet`
- **Phase gate:** Full suite green + on-device UAT (connect/disconnect both fire, no prompt, splash+dismiss correct) before `/gsd-verify-work`.

### Wave 0 Gaps
- [ ] `IsletTests/DeviceActivityTests.swift` — the pure mapping + burst-suppression + debounce matrix (clone `PowerActivityTests.swift`) — covers DEV-01/DEV-02 pure logic
- [ ] **IOBluetooth permission spike** — register connect/disconnect in the signed `.app` on macOS 26, observe prompt + event delivery (decides Success Criterion 3 + whether `project.yml` needs the usage-description key). This is the gating spike — run it before the visual work.
- [ ] No new framework install needed (IOBluetooth is a system framework, auto-linked by `import`).

## Security Domain

> `security_enforcement` config absent → treated as enabled.

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | n/a — no auth surface |
| V3 Session Management | no | n/a |
| V4 Access Control | yes | macOS TCC governs Bluetooth access (`kTCCServiceBluetoothAlways`); app stays un-sandboxed + hardened-runtime; request the minimum (passive observe, avoid `pairedDevices()`/scanning if it can be) |
| V5 Input Validation | yes | Treat `device.name` as **untrusted external input** — it's an attacker-controllable string from a remote device. Bound it in the view exactly as now-playing bounds track metadata: `.lineLimit(1)` + `.truncationMode(.tail)`; SwiftUI `Text` is inert to format strings. Never use the name in a format string or shell. |
| V6 Cryptography | no | n/a — no crypto |

### Known Threat Patterns for IOBluetooth device-activity (this stack)
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Malicious/over-long/format-string device name in the splash | Tampering / DoS (layout break) | `.lineLimit(1)` + truncation in the SwiftUI wing; inert `Text`; no string interpolation into format/shell (mirrors T-04-09) |
| Notification token used after free (registration outlives owner) | Tampering / crash | `.unregister()` connect + all disconnect tokens in `stop()`; controller's `nonisolated deinit` calls `bluetoothMonitor?.stop()` (mirrors `powerMonitor?.stop()` T-03-06) |
| Off-main `@Published`/AppKit mutation from a BT callback | Tampering / UI corruption | `DispatchQueue.main.async` hop before any `@Published`/AppKit touch (mirrors PowerSourceMonitor Pitfall 2) |
| Over-broad permission request (intrusive prompt) | (privacy) | Observe only; avoid `pairedDevices()`/scanning where possible; add a clear `NSBluetoothAlwaysUsageDescription` only if the spike proves it's required — directly serves Success Criterion 3 |

## Project Constraints (from CLAUDE.md)

- **IOBluetooth (legacy), NOT Core Bluetooth**, for system paired-device connect/disconnect; match AirPods by name/class; un-sandboxed → entitlement low-friction. `[CITED: CLAUDE.md]`
- **Swift 5 language mode** (Xcode 26.6 / Swift 6.3.3 toolchain) — avoid Swift 6 strict concurrency. `[VERIFIED: project.yml SWIFT_VERSION 5.0]`
- **Un-sandboxed** (`ENABLE_APP_SANDBOX: NO`), **hardened runtime ON**. `[VERIFIED: project.yml]`
- **macOS 14.0 deployment floor**; build machine is macOS 26 (Tahoe). `[VERIFIED: project.yml + sw_vers]`
- **Small AppKit surface + SwiftUI via `NSHostingView`**; plain `@Published`/`ObservableObject` (Combine only where it clearly helps). `[CITED: CLAUDE.md]`
- **Isolate the fragile system integration behind one service** (as MediaRemote is) — the BT monitor is the one-file isolation point. `[CITED: CLAUDE.md]`
- **XcodeGen**: add `.swift` under `Islet/`, run `xcodegen generate`; no manual `.xcodeproj` edits; `GENERATE_INFOPLIST_FILE: YES` (no physical Info.plist — Info.plist keys via `INFOPLIST_KEY_*`). `[VERIFIED: project.yml]`
- **No paid services / no Apple Developer account assumed for dev** — notarization is Phase 6; local ad-hoc signing (`CODE_SIGN_IDENTITY: "-"`). `[VERIFIED: project.yml]`
- **Idle CPU ~0% / no polling**; event-driven only; one-shot `DispatchWorkItem` for dismiss. `[CITED: CLAUDE.md + Phase 2/3 decisions]`

## Sources

### Primary (HIGH confidence)
- **macOS 26 SDK headers on the build machine** — `IOBluetoothDevice.h` (lines 136/151: `+registerForConnectNotifications:selector:`, `-registerForDisconnectNotification:selector:`, verbatim @discussion on selector args + retention) and `BluetoothAssignedNumbers.h` (device-class-major constants). Verified via `xcrun --show-sdk-path` + grep/sed.
- **Codebase (this repo)** — `PowerActivity.swift`, `ChargingActivityState.swift`, `PowerSourceMonitor.swift`, `NowPlayingMonitor.swift`/`NowPlayingState.swift`/`NowPlayingPresentation.swift`, `NotchWindowController.swift`, `NotchPillView.swift`, `AppDelegate.swift`, `PowerActivityTests.swift`, `project.yml`. The authoritative template for the three-part pattern + wiring + tests.
- `CLAUDE.md` — IOBluetooth (not Core Bluetooth) mandate, stack constraints, isolation principle.
- `.planning/phases/05-device-connected-activity/05-CONTEXT.md` — locked decisions D-01…D-07.

### Secondary (MEDIUM confidence)
- Apple Developer Forums thread 738748 — selector signature `deviceIsConnected:fromDevice:`, run-loop requirement, Sonoma TCC gating, daemon-vs-launch-agent behavior. `https://developer.apple.com/forums/thread/738748`
- Apple Developer Forums thread 758094 — daemons blocked from Bluetooth TCC; GUI/agent runs in user context. `https://developer.apple.com/forums/thread/758094`
- Apple archive — IOBluetooth Changes for Swift; `register(forConnectNotifications:selector:)` doc. `https://developer.apple.com/documentation/iobluetooth/iobluetoothdevice/1433370-registerforconnectnotifications`
- `remoteNameRequest(_:withPageTimeout:)` doc (name-fallback). `https://developer.apple.com/documentation/iobluetooth/iobluetoothdevice/remotenamerequest(_:withpagetimeout:)`
- `NSBluetoothAlwaysUsageDescription` doc. `https://developer.apple.com/documentation/bundleresources/information-property-list/nsbluetoothalwaysusagedescription`

### Tertiary (LOW confidence — flagged for on-device validation)
- jamesmartin gist + comment — `pairedDevices()` needs `com.apple.security.device.bluetooth` (sandboxed context); informs Pitfall 6. `https://gist.github.com/jamesmartin/9847466aba513de9a77507b56e712296`
- lapfelix/BluetoothConnector — real IOBluetooth Swift usage (`name`, `addressString`, `isConnected()`), though it uses direct connect calls, not notifications. `https://github.com/lapfelix/BluetoothConnector`
- TheBoringNotch — Bluetooth live-activity is on their ROADMAP, NOT implemented; no canonical reference code exists there for this feature.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — IOBluetooth + constants verified against the installed macOS 26 SDK; architecture verified against shipped in-repo code.
- Architecture: HIGH — a third clone of a twice-shipped, UAT-verified pattern; every reuse point read in source.
- IOBluetooth API specifics: HIGH — signatures, selector args, retention semantics, class constants all from the SDK header verbatim.
- Pitfalls: MEDIUM-HIGH — burst/flap/name-caching/retention/threading are well-grounded; the TCC permission outcome is the one MEDIUM item.
- Permission/Success-Criterion-3: MEDIUM — sources establish the TCC landscape but not the passive-observe outcome; A1 must be settled by the Wave 0 spike.

**Research date:** 2026-06-28
**Valid until:** ~2026-07-28 for the architecture/SDK facts (stable); re-verify the TCC/permission behavior after any macOS 26.x update (treat each macOS update as a potential Bluetooth-permission regression event).
