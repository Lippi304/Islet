# Phase 5: Device-Connected Activity - Context

**Gathered:** 2026-06-28
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 5 completes the "reacts to my life" feel: **connecting or disconnecting a Bluetooth
device** produces a **brief transient splash** (device name + icon) in the island, reusing the
**proven transient activity pattern** from Phase 3 (charging) and Phase 4 (now playing). Covers
**DEV-01** (connect activity: device name + icon) and **DEV-02** (brief disconnect activity).

**In scope:** the connect/disconnect splash visual (wings layout: icon left, name/status right),
its appear/collapse animation, the IOBluetooth event source that drives it, noise control
(at-launch/wake burst suppression + reconnect-flap debounce), and minimal device-vs-now-playing
coexistence so the common AirPods+music overlap doesn't glitch.

**Explicitly NOT in this phase:**
- **Per-bud AirPods battery %** on connect (**DEV-03**) → deferred to a later milestone (not in
  Phase 5's requirement set).
- The **general multi-activity priority resolver** (charging + media + device coexistence under
  one ranked policy) → **Phase 6 (COORD-01)**. Phase 5 only handles the device-vs-now-playing
  brief-precedence case (D-05), mirroring Phase 3's charging-vs-user D-11.
- Settings to toggle the device activity on/off + accent/theme → **Phase 6 (APP-03)**.
- Any BLE central / peripheral interaction (Core Bluetooth) — wrong abstraction for
  system-paired connect/disconnect events; IOBluetooth is the correct choice (CLAUDE.md).
</domain>

<decisions>
## Implementation Decisions

### Device scope (DEV-01, DEV-02)
- **D-01:** **ALL Bluetooth devices trigger a splash**, not just audio devices. Anything that
  connects/disconnects (AirPods, headphones, speakers — but also keyboards, mice, controllers)
  produces the splash. This **deliberately broadens beyond the requirement's "Bluetooth audio
  device" wording** — the user's product call for the simplest, most "it reacts to everything"
  behavior. Noise from non-audio devices is mitigated by the at-launch/reconnect guards (D-04),
  not by class-filtering.
  - Wiring: app-wide `IOBluetoothDevice.register(forConnectNotifications:selector:)` +
    per-device `register(forDisconnectNotification:selector:)` (CLAUDE.md). No device-class
    allowlist gate.

### Splash content & icon (DEV-01)
- **D-02:** **Device name + a device-specific glyph.** Match by device name/class to pick the
  closest SF Symbol: AirPods / AirPods Pro / AirPods Max / headphones / Beats → their specific
  glyphs; **generic Bluetooth icon as the fallback** for everything else (mice, keyboards,
  unknown devices). This is the "most Apple" feel. Exact name→symbol mapping table and fallback
  symbol are Claude's discretion + on-device tuning.
- Device name source = IOBluetooth `device.name` (fallback to address/`nameOrAddress` if nil).

### Disconnect treatment (DEV-02)
- **D-03:** **Same wings splash for connect and disconnect, visually distinguished.** Connect =
  colored/active icon (e.g. "Connected"); disconnect = **dimmed/greyed icon and/or a small
  "Disconnected" label**. One layout, two states — NOT two separate animated scenes (mirrors
  Phase 3 D-04's single-glyph-encodes-state philosophy). Exact dimming/label styling is
  discretion + on-device tuning.

### Noise control (locked by DEV-03 success criterion "no intrusive prompts" + idle-CPU)
- **D-04:** **Suppress the at-launch / wake connect burst AND debounce rapid reconnect flapping.**
  - Devices **already connected when the app starts** (or that all re-fire "connect" on
    login/wake) must **not** splash — only genuine post-launch user-initiated edges splash.
  - **Reconnect flapping** (AirPods dropping and reconnecting within a short window) is
    **debounced** so it doesn't produce repeated splashes.
  - Implementation must stay **event-driven, no polling** (idle CPU ~0%) — the burst suppression
    is a startup-grace / seen-set mechanism, not a timer loop.

### Coexistence with Now Playing (interim, pre-Phase-6)
- **D-05:** **Device splash takes brief precedence, then yields to the ambient / now-playing
  state** — mirroring Phase 3's charging D-11. Scenario: insert AirPods → connect splash shows
  briefly → then returns to the now-playing (or ambient) state. **Minimal and device-specific —
  NOT a general resolver** (that is Phase 6 / COORD-01). No speculative abstraction.

### Timing & interaction (carried from Phase 3/4)
- **D-06:** **~3s auto-dismiss via a single scheduled `DispatchWorkItem` collapse** (reuse the
  `graceWorkItem` template), NOT a recurring timer. **Hover pauses auto-dismiss; click is
  informational only** (Phase 3 D-09/D-10).
- Splash visibility routes through the **single `updateVisibility()`** site so it inherits the
  fullscreen + clamshell hide for free (Phase 2 D-09).

### Architecture / TDD (carried from Phase 3/4)
- **D-07:** **Same testable-seam discipline** as `PowerActivity.swift` / `NowPlayingPresentation.swift`:
  - A **pure** `DeviceActivity` presentation seam (Foundation-only) mapping a device reading →
    presentation (connected/disconnected + name + glyph-kind), plus a **pure connect/disconnect
    edge + burst-suppression/debounce predicate**, all unit-tested in milliseconds (RED→GREEN).
  - A separate `@Published` device-activity **state model** (mirror `ChargingActivityState` /
    `NowPlayingState`) — NOT folded into the `InteractionPhase` gesture machine.
  - A thin **IOBluetooth monitor** wrapping the connect/disconnect notifications, hopping
    callbacks to the **main thread** before touching `@Published`/AppKit, with **deinit
    teardown** of registrations.

### Claude's Discretion
- The exact **name→SF-Symbol mapping** and the generic fallback glyph (D-02).
- The exact **burst-suppression / debounce mechanism** (startup grace window vs seen-set of
  already-connected devices; debounce interval) — keep it event-driven, no polling (D-04).
- The exact **disconnect dimming/label styling** (D-03) and wing geometry reuse.
- Whether the device-activity state is one model holding a connect/disconnect enum vs two —
  keep it device-specific, no general resolver (D-05).
- IOBluetooth specifics: selector signatures, the `IOBluetoothUserNotification` handle for
  disconnects, matching device identity, entitlement check (un-sandboxed → low-friction).
- Spring/duration tuning (start from the Phase-2 vocabulary: response ≈ 0.35, damping ≈ 0.65).

### Folded Todos
(None — no pending todos matched this phase.)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Bluetooth / device events (primary for Phase 5)
- `CLAUDE.md` → **"Bluetooth / AirPods connect events"** — the API map:
  `IOBluetoothDevice.register(forConnectNotifications:selector:)` (app-wide connects) +
  per-device `register(forDisconnectNotification:selector:)`; match AirPods by name/class;
  **IOBluetooth (legacy but correct) — NOT Core Bluetooth** for system paired-device events;
  un-sandboxed → entitlement low-friction.
- `CLAUDE.md` → **Apple frameworks table** — IOBluetooth (MEDIUM-HIGH), legacy-deprecation watch.
- `CLAUDE.md` → **"What NOT to Use"** — Core Bluetooth is the wrong abstraction here.

### The transient-activity pattern to REUSE (the template Phase 5 mirrors)
- `Islet/Notch/PowerActivity.swift` — the **pure power→presentation seam** + the
  `shouldTriggerSplash(previous:next:)` **edge predicate**. This is the exact shape for a pure
  `DeviceActivity` seam + connect/disconnect/burst-suppression predicate.
- `Islet/Notch/ChargingActivityState.swift` — the **separate `@Published` activity model**
  pattern (NOT folded into `InteractionPhase`). Template for the device-activity state.
- `Islet/Notch/PowerSourceMonitor.swift` — the **event-source monitor** template (run-loop
  source, main-thread hop, deinit teardown). Device monitor mirrors this with IOBluetooth.
- `Islet/Notch/NowPlayingPresentation.swift` / `NowPlayingState.swift` / `NowPlayingMonitor.swift`
  — the **second instance** of the same pattern (pure seam / @Published model / thin monitor) —
  confirms the convention to follow.
- `Islet/Notch/NotchPillView.swift` — the **wings/sideways layout** (icon left, name/info right)
  shared by charging + now-playing; add the device-activity wing branch here.
- `Islet/Notch/NotchWindowController.swift` — owns the panel, the **single `updateVisibility()`**
  show/hide site, the **`graceWorkItem` one-shot `DispatchWorkItem` collapse** (~3s dismiss
  template), fullscreen/clamshell hide, deinit teardown. The IOBluetooth observer + device
  activity state wire in here.
- `Islet/Notch/NotchGeometry.swift` — pure unit-tested geometry seam (wings-frame math to reuse).

### Phase carry-forward decisions Phase 5 inherits
- `.planning/phases/03-charging-activity/03-CONTEXT.md` — **D-09** (~3s single `DispatchWorkItem`
  dismiss, no timer), **D-10** (hover pauses, click informational), **D-11** (brief-precedence
  then return — the model D-05 mirrors), idle-CPU/no-polling + fullscreen-hide criteria.
- `.planning/phases/04-now-playing/04-CONTEXT.md` — the now-playing state Phase 5 coexists with
  (D-05) and the second copy of the activity pattern.
- `.planning/phases/02-hover-expand-fullscreen-hardening/02-CONTEXT.md` — **D-09** fullscreen hide
  via `updateVisibility()`; **D-08** idle-static.

### Project planning
- `.planning/ROADMAP.md` → **§ "Phase 5: Device-Connected Activity"** (goal + 3 success criteria).
- `.planning/REQUIREMENTS.md` — **DEV-01** (connect: name + icon), **DEV-02** (disconnect cue);
  **DEV-03** (per-bud battery — deferred); **COORD-01** (Phase-6 resolver anchor).
- `.planning/PROJECT.md` — vision (as polished as Alcove), Key Decisions, out-of-scope.

_No external ADRs/specs — requirements fully captured in CLAUDE.md + the planning docs above._

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`PowerActivity.swift` + `ChargingActivityState.swift`** — the canonical pure-seam +
  `@Published` model pair to clone for `DeviceActivity` + `DeviceActivityState`. `PowerActivity`'s
  `shouldTriggerSplash` edge predicate is the direct analogue for the connect/disconnect +
  burst-suppression edge logic.
- **`PowerSourceMonitor.swift`** — the event-source monitor template (callback → main-thread hop
  → set `@Published`, deinit teardown). The IOBluetooth monitor mirrors its lifecycle.
- **`NotchWindowController.swift`** — single `updateVisibility()` show/hide; `graceWorkItem`
  one-shot collapse (the ~3s dismiss template); fullscreen/clamshell hide; natural home for the
  IOBluetooth observer + device state. **Two activities already coexist here (charging + media)**
  — the device splash is a third; keep coexistence minimal (D-05), no general resolver.
- **`NotchPillView.swift`** — the wings layout shared by charging + now-playing; the device wing
  (icon left, name/status right) is a new branch alongside them.

### Established Patterns
- Small AppKit surface + SwiftUI via `NSHostingView`; `@Published`/`ObservableObject` into
  SwiftUI; **Swift-5 language mode**; un-sandboxed; **macOS-14 floor**.
- `project.yml` (XcodeGen) auto-discovers new `.swift` files under `Islet/` — run
  `xcodegen generate` after adding sources; no manual `.xcodeproj` edits.
- **TDD seam**: pure logic (presentation mapping + edge/debounce predicate) unit-tested;
  IOBluetooth + AppKit/SwiftUI wiring verified on-device.
- **One-shot `DispatchWorkItem` collapse** for auto-dismiss — never a repeating timer (no-polling).
- **Single `updateVisibility()`** is the sole show/hide site — route device visibility through it.

### Integration Points
- `AppDelegate.applicationDidFinishLaunching` creates/retains the controller — no ownership
  change; the IOBluetooth registration is added inside the controller's `start()`.
- The connect/disconnect callbacks must **hop to the main thread** before touching
  `@Published`/AppKit; **deinit must unregister** the IOBluetooth notifications.
- The fullscreen-hide and the splash coexist via `updateVisibility()`.
- Device splash vs the existing charging + now-playing activities: minimal brief-precedence
  (D-05), full resolver deferred to Phase 6.

</code_context>

<specifics>
## Specific Ideas

- **Alcove-style moment:** the point is the instant "you just connected your AirPods, here's
  feedback" beat — wings flank the notch (device glyph one side, name/status the other), then
  collapse after ~3s. Disconnect is the same beat, dimmed / labelled "Disconnected".
- **All-devices, glyph-specific:** every Bluetooth connect/disconnect splashes (D-01), but the
  icon is as specific as the device allows (AirPods Pro vs Max vs generic BT) (D-02) — so a mouse
  shows a generic BT icon + its name, AirPods show the AirPods glyph.
- **Burst-suppressed:** waking the Mac with 4 paired devices must NOT fire 4 splashes (D-04).

</specifics>

<deferred>
## Deferred Ideas

- **Per-bud AirPods battery %** on connect (**DEV-03**) → later milestone; not in Phase 5.
- **General multi-activity priority resolver** (charging + media + device under one ranked
  policy) → **Phase 6 (COORD-01)**. Phase 5 does only the minimal device-vs-now-playing
  brief-precedence (D-05).
- **Settings toggle** to enable/disable the device activity + accent/theme → **Phase 6 (APP-03)**.
- **Device-class filtering** (audio-only vs all) — considered and rejected in favor of all-devices
  + noise guards (D-01); could revisit as a setting later.

### Reviewed Todos (not folded)
(None — no pending todos existed to review.)

</deferred>

---

*Phase: 05-device-connected-activity*
*Context gathered: 2026-06-28*
