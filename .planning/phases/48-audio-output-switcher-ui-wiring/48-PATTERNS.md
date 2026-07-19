# Phase 48: Audio Output Switcher — UI Wiring - Pattern Map

**Mapped:** 2026-07-20
**Files analyzed:** 5 (2 pre-existing seam/monitor files to leave alone but reuse; 3 modified files)
**Analogs found:** 5 / 5

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|--------------------|------|-----------|-----------------|----------------|
| `Islet/Notch/NotchPillView.swift` — new speaker-icon `TransportButton`-style button (right reserved slot, ~2872) | component (button) | request-response (tap → closure) | `TransportButton` struct, same file, lines 2904-2924 | exact |
| `Islet/Notch/NotchPillView.swift` — new draggable volume slider (reusing `OSDLevelBar` visual language) | component (slider) | event-driven (drag gesture → live value) | `OSDLevelBar` struct, same file, lines 3055-3068 (display-only; must ADD gesture — no local exact analog for the gesture half, see below) | role-match (visual), no analog for the drag half |
| `Islet/Notch/NotchPillView.swift` — new `outputPanel(devices:)` subview (device list, tap-to-select, checkmark, panel reveal) | component (list/panel) | CRUD-ish (tap → select → re-sort) | `ShelfItemView`/switcher-row list precedent + `TransportButton` closure-forwarding; no 1:1 existing "list with current-item checkmark" component — closest structural precedent is the calendar/switcher row's per-item tap dispatch | role-match |
| `Islet/Notch/NotchPillView.swift` — new closures `onToggleOutputPanel`, `onSelectOutputDevice`, `onVolumeChange` on the view's closure-forwarding block | interface (closure props) | request-response | Existing closure block, lines 169-223 (`onClick`, `onTogglePlayPause`/`onNext`/`onPrevious`, `onSwitcherSelect`) | exact |
| `Islet/Notch/NotchWindowController.swift` — `startAudioOutputMonitor()` / lifecycle wiring | controller (monitor lifecycle) | event-driven | `startBluetoothMonitor()`, lines 655-663, and its `deinit` teardown counterpart, lines 2456-2459 | exact |
| `Islet/Notch/NotchWindowController.swift` — `handleToggleOutputPanel()` / `handleSelectOutputDevice()` / `handleVolumeChange()` handlers + closure forwarding in `makeRootView` | controller (event handler) | request-response | `handleSwitcherSelect(_:)` forwarding pattern, `makeRootView`'s closure block lines 1984-2013 (esp. `onTogglePlayPause`/`onNext`/`onPrevious` at 1996-1998) | exact |
| `Islet/Notch/NotchWindowController.swift` — geometry three-site rule additions (`positionAndShow` union member, `visibleContentZone()` branch) | controller (geometry) | transform | `weatherExpandedFrame`/`.weatherExpanded` branch pair: `positionAndShow` lines 1016-1018 + `visibleContentZone()` lines 1378-1389 | exact (same "two-tier conditional height" shape as Weather Medium/Large) |
| `Islet/Notch/IslandPresentationState.swift` — new `@Published var outputPanelOpen: Bool` | model (sibling state) | event-driven | `hoveredQuickActionButtonIndex`, lines 18-24 | exact |
| `Islet/Notch/AudioOutputPresentation.swift` (existing, Phase 47 — read/reuse only, no changes expected) | model (pure seam) | transform | n/a — already built | n/a |
| `Islet/Notch/AudioOutputMonitor.swift` (existing, Phase 47 — read/reuse only, no changes expected) | service (event-driven monitor) | event-driven | n/a — already built | n/a |
| `Islet/Notch/VolumeReader.swift` (existing — reused UNCHANGED for slider read/write) | utility (stateless CoreAudio glue) | request-response (pull-based) | n/a — already built, do not modify | n/a |

## Pattern Assignments

### New speaker-icon button (right reserved slot in `mediaContent`, `NotchPillView.swift` ~2872)

**Analog:** `TransportButton` struct, `Islet/Notch/NotchPillView.swift:2904-2924`

**Core pattern — closure-forwarding + hover-background button** (lines 2904-2924):
```swift
private struct TransportButton: View {
    let systemName: String
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isHovering ? Color.white.opacity(0.40) : Color.clear)
                )
        }
        .frame(width: 32, height: 32)
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}
```

**How to apply:** Reuse `TransportButton` directly (it's parameterized by `systemName`/`action` already — a speaker glyph like `"speaker.wave.2.fill"` and an `onToggleOutputPanel` closure slot straight in). D-08 (re-tap closes the panel) is satisfied for free since the closure the button calls can just flip `outputPanelOpen`. Replace the `Color.clear.frame(width: 28, height: 28)` reserved slot at line 2872 (`mediaExpanded`'s control-row `HStack`) with `TransportButton(systemName: "speaker.wave.2.fill", action: onToggleOutputPanel)`. Left reserved slot (2864) stays untouched (out of scope — future Shuffle).

**Call site to mirror** (`mediaContent`'s control row, lines 2862-2873):
```swift
HStack(spacing: 0) {
    Color.clear.frame(width: 28, height: 28)   // reserved Shuffle slot (D-09, not built)
    Spacer()
    TransportButton(systemName: "backward.fill", action: onPrevious)        // ⏪
    Spacer()
    TransportButton(systemName: "playpause.fill", action: onTogglePlayPause) // ⏯
    Spacer()
    TransportButton(systemName: "forward.fill", action: onNext)             // ⏩
    Spacer()
    Color.clear.frame(width: 28, height: 28)   // reserved Repeat slot (D-09, not built)
}
```

---

### New draggable volume slider (visual language from `OSDLevelBar`)

**Analog:** `OSDLevelBar`, `Islet/Notch/NotchPillView.swift:3055-3068`

**Visual pattern to copy verbatim (D-03)** (lines 3055-3068):
```swift
private struct OSDLevelBar: View {
    let fraction: CGFloat
    let tint: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.15))                       // empty track
                Capsule().fill(tint).frame(width: geo.size.width * fraction)    // filled (D-02 fixed tint)
                    .animation(.spring(response: 0.15, dampingFraction: 0.86), value: fraction)   // D-16 retuned value
            }
        }
    }
}
```

**Call site for `fraction`/`tint` plumbing (existing OSD wing usage)**, `Islet/Notch/NotchPillView.swift:2593`:
```swift
OSDLevelBar(fraction: fraction, tint: tint)
    .frame(width: barWidth, height: 5)
```

**How to apply:** `OSDLevelBar` itself is `private` to this file and display-only (no gesture) — D-03 explicitly says "must become genuinely draggable (OSDLevelBar itself is currently display-only, no gesture) — this phase adds the drag gesture, reusing only the visual style." Two implementation options, both consistent with the ladder: (a) add a `DragGesture` directly onto a NEW thicker sibling struct that copies `OSDLevelBar`'s two-Capsule `ZStack`/`GeometryReader` body (do not make the existing OSD wing's bar draggable — different call site, different sizing), or (b) widen `OSDLevelBar`'s own type to accept an optional `onDrag: ((CGFloat) -> Void)?` closure and reuse it directly in both places. Given YAGNI and "no analog for the gesture half," (a) — a new small `OutputVolumeSlider` view copying `OSDLevelBar`'s body verbatim (D-03's own wording: "rather than a new distinct slider design... reusing only the visual style") plus a `.gesture(DragGesture(minimumDistance: 0) { ... })` computing `fraction` from `value.location.x / geo.size.width` clamped to `0...1` — is the lower-risk, smaller-diff option since `OSDLevelBar`'s existing 2 call sites (OSD wing, this new slider) have very different sizing/thickness needs (D-03: "scaled up/thicker"). No numeric readout (D-04) — fill-only, matches this component's existing display-only precedent exactly.

**Disabled/no-volume-control state (D-06):** dim via `.opacity(0.35)` (or similar) and skip attaching the gesture entirely when `AudioOutputMonitor.hasVolumeControl(deviceUID:)` is false for the current device — no existing "disabled slider" analog in this codebase; follow the same "check before rendering interactive, degrade to inert" discipline `VolumeReader`/`AudioOutputMonitor.hasVolumeControl` already apply on the read side (Pitfall 7).

---

### New output device list / panel (`outputPanel(devices:)` subview)

**Analog (closure-forwarding convention):** `NotchPillView.swift:169-223` (existing closure-prop block) + `NotchWindowController.swift:2008` (`onSwitcherSelect` handler forwarding)

**Closure declaration pattern to extend** (`NotchPillView.swift:184-186`, immediately after the transport closures):
```swift
var onTogglePlayPause: () -> Void = {}
var onNext: () -> Void = {}
var onPrevious: () -> Void = {}
```
Add, mirroring this exact style:
```swift
var onToggleOutputPanel: () -> Void = {}
var onSelectOutputDevice: (AudioOutputDevice) -> Void = { _ in }
var onVolumeChange: (Float) -> Void = { _ in }
```
(Mirrors `onSwitcherSelect: (SelectedView) -> Void = { _ in }` at line 214 for the single-payload-closure shape.)

**Row structure — no exact existing "list with a checkmark on the current item" component in this codebase.** Closest structural precedent for "tap a row → closure fires with the row's identity → controller acts": `onShelfItemTap: (ShelfItem) -> Void` (line 192) forwarded from `ShelfItemView`, and `onSwitcherSelect: (SelectedView) -> Void` (line 214). Build each device row as a plain `HStack` (accent-tinted `Image(systemName: "checkmark")` when `device.isDefault`, else nothing, per D-05 — "single-accent-signal convention... rather than a full row background highlight") with `.onTapGesture { onSelectOutputDevice(device) }`, `ForEach(devices) { device in ... }` over the already-sorted `[AudioOutputDevice]` array (list order IS the default signal — `AudioOutputPresentation.sortedAudioOutputDevices`, no separate `isDefault` re-sort needed client-side). D-07: no `.onTapGesture`-triggered dismiss — the panel stays open, only the list re-sorts (this falls out for free from `AudioOutputMonitor.onDevicesChanged` re-delivering a re-sorted list after `setDefaultOutput` succeeds).

**Panel open/close boolean — analog:** `hoveredQuickActionButtonIndex`, `Islet/Notch/IslandPresentationState.swift:18-24`:
```swift
@Published var hoveredQuickActionButtonIndex: Int? = nil
```
Add a sibling, per ARCHITECTURE.md Pattern 3 (explicitly recommended shape):
```swift
@Published var outputPanelOpen: Bool = false
```
Written only by the controller (`NotchWindowController.handleToggleOutputPanel()`), read only by the view (`mediaContent`'s body) — never plain SwiftUI `@State`, because `visibleContentZone()` (AppKit-side click-through geometry) must also read it (CR-01 invariant — see Shared Patterns below).

---

### `NotchWindowController` — `AudioOutputMonitor` lifecycle wiring

**Analog:** `startBluetoothMonitor()` (start) + `deinit`'s `bluetoothMonitor?.stop()` (teardown)

**Start pattern** (`NotchWindowController.swift:655-663`):
```swift
private func startBluetoothMonitor() {
    guard bluetoothMonitor == nil else { return }
    // Reset the edge-tracking state and stamp the start so the at-launch connect burst of
    // already-connected devices is recorded-but-not-splashed (DeviceCoordinator's launch-grace window).
    deviceCoordinator.started(at: Date())
    let bt = BluetoothMonitor { [weak self] reading in self?.deviceCoordinator.handle(reading) }
    bluetoothMonitor = bt
    bt.start()
}
```
Apply as:
```swift
private func startAudioOutputMonitor() {
    guard audioOutputMonitor == nil else { return }
    let monitor = AudioOutputMonitor { [weak self] devices in self?.handleAudioOutputDevicesChanged(devices) }
    audioOutputMonitor = monitor
    monitor.start()
}
```
(`AudioOutputMonitor.start()` already delivers an initial synchronous snapshot per its own header comment — no separate "prime the list" call needed, matching `startFocusModeMonitor()`'s equally-idempotent shape at line 666-671.)

**Teardown pattern** (`NotchWindowController.swift:2456-2459`):
```swift
// Phase 6 / DEV-01 (security T-06-12): tear the IOBluetooth monitor down — unregister the
// class connect token + every per-device disconnect token so no OS-held token outlives
// the owner. Mirrors powerMonitor.stop()'s owner-driven teardown.
bluetoothMonitor?.stop()
deviceCoordinator?.cancelPendingWork()
```
Apply as (single line, `AudioOutputMonitor.stop()` is `nonisolated`, no coordinator to cancel):
```swift
audioOutputMonitor?.stop()
```
placed in the same `deinit` block, mirroring `focusModeMonitor?.stop()`/`calendarCountdownMonitor?.stop()`'s single-line siblings (lines 2464, 2468).

**Where to call `startAudioOutputMonitor()`:** unlike `startBluetoothMonitor()` (gated behind `activityEnabled(ActivitySettings.deviceKey)`), the output panel has no user-facing on/off Setting in this phase's scope — call unconditionally from `start(isFirstLaunch:)`, mirroring `startOSDInterceptor()`'s own "called UNCONDITIONALLY... no activityEnabled gate" precedent (line 693-696) since the speaker button/panel is always available, not a toggleable HUD activity.

---

### `NotchWindowController` — closure forwarding + handler (`handleToggleOutputPanel`/`handleSelectOutputDevice`/`handleVolumeChange`)

**Analog:** `onTogglePlayPause`/`onNext`/`onPrevious` forwarding, `NotchWindowController.swift:1994-1998`:
```swift
// NOW-02: transport rides the EXISTING persistent child's stdin via the
// monitor — no re-spawn, no focus steal.
onTogglePlayPause: { [weak self] in self?.nowPlayingMonitor?.togglePlayPause() },
onNext: { [weak self] in self?.nowPlayingMonitor?.nextTrack() },
onPrevious: { [weak self] in self?.nowPlayingMonitor?.previousTrack() },
```
And `onSwitcherSelect: { [weak self] view in self?.handleSwitcherSelect(view) }` (line 2008) for the "closure calls a named `handle*` method rather than inlining logic" convention used for anything with actual branching.

**Apply as**, added to the same `makeRootView(theme:)` closure block (after line 1998, before `onShelfItemTap`):
```swift
onToggleOutputPanel: { [weak self] in self?.handleToggleOutputPanel() },
onSelectOutputDevice: { [weak self] device in self?.handleSelectOutputDevice(device) },
onVolumeChange: { [weak self] value in self?.handleVolumeChange(value) },
```

**`handleToggleOutputPanel()` — mirrors `handleSwitcherSelect`'s "flip state inside the spring wrapper, re-run panel-resize" shape** (per ARCHITECTURE.md Pattern 3's own recommended shape: "flips the flag and re-runs the same panel-resize path `handleSwitcherSelect` already triggers"). No direct code excerpt exists yet for `handleSwitcherSelect` itself in the files read — grep it before writing the plan's exact snippet, but the shape is: mutate `presentationState.outputPanelOpen` inside the existing spring `withAnimation` wrapper used elsewhere in this controller, then call `positionAndShow(on:)` again so the geometry three-site rule's union stays consistent.

**`handleSelectOutputDevice(_:)`** — calls `audioOutputMonitor?.setDefaultOutput(device) { success in ... }`. Per D-09, the completion's `success == false` case does NOT surface an error — no-op; `onDevicesChanged`'s own re-delivery (already wired via `startAudioOutputMonitor()`) is the sole source of truth the UI snaps back to.

**`handleVolumeChange(_:)`** — calls `adjustSystemVolume`-shaped logic, but the UI drag needs an absolute set, not the existing relative increase/decrease `adjustSystemVolume(increase:)` shape. `VolumeReader.swift` has no absolute-set function today (only relative `adjustSystemVolume(increase:)` and `readSystemVolume()`). Per CONTEXT.md ("reused UNCHANGED"), do not add a new public function to `VolumeReader.swift` without checking whether the drag can be expressed as repeated relative steps first — if an absolute set is genuinely required, the closest existing pattern to copy is `adjustSystemVolume`'s own guarded Get/Set sequence (`VolumeReader.swift:57-108`, esp. the `AudioObjectSetPropertyData` call at line 92) targeting a directly-computed `target` (the drag fraction) instead of `currentVolume ± volumeStep`. Flag this as a planning-time decision, not resolved by this pattern map (CONTEXT.md's `code_context` says "reused UNCHANGED" but the existing API surface is relative-only).

---

### `NotchWindowController` — geometry three-site rule (output panel reveal)

**Analog:** Weather's two-tier Medium/Large conditional height, the most structurally similar precedent (a single presentation case whose *content height varies by a runtime condition*, exactly like `outputPanelOpen` varying `mediaExpanded`'s height).

**Site 1 — `blobShape`'s height argument.** Not read directly in this pass (not in the 5 offsets read), but the site-2/site-3 excerpts below make the required shape unambiguous: wherever `mediaExpanded`/`.nowPlayingExpanded`'s height is currently a fixed `NotchPillView.homeContentHeight`, it must become a ternary reading the same `outputPanelOpen` flag, mirroring the weather style ternary referenced at `visibleContentZone()` line 1389: `(style == .large ? NotchPillView.weatherLargeContentHeight : NotchPillView.weatherMediumContentHeight)`.

**Site 2 — `positionAndShow`'s union member** (`NotchWindowController.swift:1016-1018`, the Weather analog to copy the *shape* of, not literally reuse):
```swift
let weatherExpandedFrame = expandedNotchFrame(collapsed: collapsedFrame,
                                               expandedSize: CGSize(width: expandedSize.width,
                                                                     height: NotchPillView.weatherLargeContentHeight + NotchPillView.switcherRowHeight))
```
**Per CONTEXT.md's Claude's-Discretion item — check FIRST whether this union member is even needed**, following the ARCHITECTURE.md "geometry three-site rule" section's own explicit caveat: `switcherContentHeight` (196pt, `NotchPillView.swift:642`) may already exceed `homeContentHeight` (170pt, line 656) plus the panel's real added content. If the output panel's device list + slider fits under 196pt total, `expandedFrame`'s existing union member (line 985-987, which already reserves `switcherContentHeight`) may need NO new union member at all — do not add one speculatively (YAGNI/ladder rung 1).

**Site 3 — `visibleContentZone()` branch** (`NotchWindowController.swift:1378-1389`, the Weather two-tier branch to mirror exactly):
```swift
} else if case .weatherExpanded = presentationState.presentation {
    let style = ActivitySettings.WeatherStyle(rawValue: UserDefaults.standard.string(forKey: ActivitySettings.weatherStyleKey) ?? "") ?? .medium
    contentSize = CGSize(width: expandedSize.width,
                         height: (style == .large ? NotchPillView.weatherLargeContentHeight : NotchPillView.weatherMediumContentHeight) + switcherHeight)
}
```
Since the output panel is NOT a resolver case (Pattern 3 — stays inside the existing default/`.nowPlayingExpanded` `else` branch at line 1405-1408), the new branch must be added as a condition INSIDE that final `else` clause (or as its own `else if presentationState.outputPanelOpen`-gated branch placed before the final `else`, following the same ordering discipline as the onboarding/tray/weather/quickAction/calendar branches above it), reading `presentationState.outputPanelOpen` and adding the panel's extra height on top of `expandedSize.height`/`homeContentHeight` — must use the EXACT SAME boolean read at `blobShape`'s call site (Site 1) or reproduce the CR-01 click-through regression this section explicitly warns against.

---

## Shared Patterns

### Closure-forwarding convention (applies to every new interaction: button tap, device tap, drag)
**Source:** `Islet/Notch/NotchPillView.swift:169-223` (declaration) + `Islet/Notch/NotchWindowController.swift:1984-2013` (construction/forwarding)
**Apply to:** the new speaker button, every device row, the volume slider's drag callback
```swift
// Declaration side (NotchPillView.swift)
var onTogglePlayPause: () -> Void = {}
// Construction side (NotchWindowController.swift)
onTogglePlayPause: { [weak self] in self?.nowPlayingMonitor?.togglePlayPause() },
```
Every closure defaults to a no-op so `#Preview` blocks keep compiling without a live controller — replicate the `= {}` / `= { _ in }` default on every new closure.

### Off-main dispatch discipline (Pitfall 5 — already solved inside `AudioOutputMonitor`, but the CONTROLLER'S handler side must also respect it)
**Source:** `Islet/Notch/AudioOutputMonitor.swift:37-42` (already wraps every callback in `DispatchQueue.main.async`)
```swift
let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
    DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        self.onDevicesChanged(self.currentDevices())
    }
}
```
**Apply to:** `NotchWindowController.handleAudioOutputDevicesChanged(_:)` can assume it is already on main (the monitor guarantees this) — do not add a redundant hop, but do not remove/bypass the monitor's own hop either.

### Geometry three-site rule (CR-01 invariant)
**Source:** `.planning/research/ARCHITECTURE.md` "geometry three-site rule" section + `NotchWindowController.swift:1352-1411` (`visibleContentZone()`), `:970-1033` (`positionAndShow`)
**Apply to:** any change to `mediaExpanded`'s rendered height when `outputPanelOpen` toggles — `blobShape`'s `height:` argument, `positionAndShow`'s union (only if needed, see Site 2 above), and `visibleContentZone()`'s `.nowPlayingExpanded`/default branch must all read the identical `presentationState.outputPanelOpen` boolean, or the panel renders but becomes unclickable past its old bounds (the exact bug class Weather/CR-01 already hit and fixed).

### UID-not-AudioDeviceID keying (Pitfall 4 — already solved, do not reintroduce in the UI layer)
**Source:** `Islet/Notch/AudioOutputPresentation.swift:12-21` (`AudioOutputDevice.uid`/`id`) + `Islet/Notch/AudioOutputMonitor.swift:83-102` (`resolveDeviceID(uid:)`)
**Apply to:** the device list's `ForEach` — use `AudioOutputDevice.id` (== `uid`) as the SwiftUI identity, never derive or cache an `AudioDeviceID` in the view/controller layer; every CoreAudio call already re-resolves from UID inside `AudioOutputMonitor`, so the UI only ever needs to pass the `AudioOutputDevice` value itself to `onSelectOutputDevice`.

### Confirm-after-set / silent-revert handling (D-09, Pitfall 8)
**Source:** `Islet/Notch/AudioOutputMonitor.swift:104-129` (`setDefaultOutput(_:completion:)`, already does the delayed re-read/confirm)
```swift
func setDefaultOutput(_ device: AudioOutputDevice, completion: @escaping (Bool) -> Void) {
    guard let targetDeviceID = resolveDeviceID(uid: device.uid) else { completion(false); return }
    // ... AudioObjectSetPropertyData ...
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
        guard let self else { completion(false); return }
        completion(self.defaultOutputDeviceID() == targetDeviceID)
    }
}
```
**Apply to:** `NotchWindowController.handleSelectOutputDevice(_:)` — call this, and per D-09 do NOTHING distinct on `completion(false)` (no toast/shake); the monitor's own `onDevicesChanged` re-delivery (already wired) is what the UI trusts.

## No Analog Found

| File/Component | Role | Data Flow | Reason |
|-----------------|------|-----------|--------|
| Draggable-slider gesture logic (the `DragGesture` itself, as opposed to `OSDLevelBar`'s static visual) | component | event-driven | No existing draggable-value control in `NotchPillView.swift` — every existing slider-shaped element (`OSDLevelBar`, `ProgressBar`) is strictly display-only. Nearest gesture precedent for a live-value drag is `ShelfItemView`'s `onDragStarted` (file-drag, not a value-drag) — different enough (drag-out-of-app vs. in-place value scrub) that it is not a usable template beyond confirming this codebase's general comfort with `DragGesture`. |
| "Device row with accent checkmark for current item" list component | component | CRUD-ish | No existing list row in this codebase marks a "current/default" item via a leading accent checkmark — closest precedent (`ProgressBar`'s accent fill, D-05's own cited comparison) is a fill treatment, not a row-marker; build net-new, small, following D-05's explicit single-accent-signal wording. |
| Absolute (non-relative) system-volume SET function | utility | request-response | `VolumeReader.swift` only exposes `adjustSystemVolume(increase: Bool)` (relative ±1/16 step) and `readSystemVolume()` — no absolute-set entry point exists for a drag gesture's continuous target value. Flagged above as a planning-time decision (extend `VolumeReader.swift` with a guarded absolute-set function following `adjustSystemVolume`'s exact Get/Set/guard shape, vs. expressing the drag as many relative steps) — CONTEXT.md's "reused UNCHANGED" framing does not by itself resolve which shape the executor should build. |

## Metadata

**Analog search scope:** `Islet/Notch/` (`NotchPillView.swift`, `NotchWindowController.swift`, `IslandPresentationState.swift`, `AudioOutputPresentation.swift`, `AudioOutputMonitor.swift`, `VolumeReader.swift`, `BluetoothMonitor.swift` referenced via grep)
**Files scanned:** 7 read directly (targeted offsets, no full-file reads on the two >2000-line files) + grep sweeps across `NotchPillView.swift`/`NotchWindowController.swift` for closure/constant/lifecycle declarations
**Pattern extraction date:** 2026-07-20
