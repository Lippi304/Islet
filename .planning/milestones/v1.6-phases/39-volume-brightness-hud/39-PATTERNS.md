# Phase 39: Volume & Brightness HUD - Pattern Map

**Mapped:** 2026-07-17
**Files analyzed:** 8 new, 5 modified
**Analogs found:** 13 / 13

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|--------------------|------|-----------|-----------------|----------------|
| `Islet/Notch/OSDActivity.swift` (NEW) | model (pure value + mapping) | transform | `Islet/Notch/FocusActivity.swift` | exact |
| `Islet/Notch/OSDInterceptor.swift` (NEW) | service (system glue, CGEventTap) | event-driven | `Islet/Notch/DropInterceptTap.swift` | exact |
| `Islet/Notch/VolumeReader.swift` (NEW) | service (thin system-call glue) | request-response | `Islet/Notch/PowerSourceMonitor.swift`'s `readCurrentPower()` | role-match |
| `Islet/Notch/BrightnessReader.swift` (NEW) | service (private-framework dynamic load) | request-response | `Islet/Notch/PowerSourceMonitor.swift`'s `readCurrentPower()` (dynamic-load technique itself has no in-repo analog — see below) | partial |
| `Islet/Notch/IslandResolver.swift` (EXTEND) | model (pure reducer + queue) | transform | itself — Focus's `.focus` case/branch/`isPersistent`/`preempt()` additions (Phase 38) | exact (self-extend) |
| `Islet/Notch/NotchPillView.swift` (EXTEND: `osdWings(for:)`) | component (SwiftUI wing view) | transform | `focusWings(for:)` (structure) + `ProgressBar` struct (fill-bar technique) | exact |
| `Islet/Notch/NotchWindowController.swift` (EXTEND) | controller | event-driven | Focus wiring: `startFocusModeMonitor()`, `handleFocusChange(_:)`, preempt call sites, `scheduleActivityDismiss()`, `flushTransients(_:)` | exact |
| `Islet/ActivitySettings.swift` (EXTEND) | config | CRUD (UserDefaults keys) | `focusKey` + `focusPermissionStatusHint(toggleOn:granted:)` | exact |
| `Islet/SettingsView.swift` (EXTEND) | component (SwiftUI settings toggle) | request-response | Focus Mode HUD toggle + `focusPermissionExplanationView` (lines 211-227, 257-288) | exact |
| `IsletTests/OSDActivityTests.swift` (NEW) | test | transform | `IsletTests/FocusActivityTests.swift` | exact |
| `IsletTests/IslandResolverTests.swift` (EXTEND) | test | transform | Focus test block, lines 619-665 | exact |

## Pattern Assignments

### `Islet/Notch/OSDActivity.swift` (NEW — model, transform)

**Analog:** `Islet/Notch/FocusActivity.swift` (read in full, 21 lines)

**Whole-file shape to mirror:**
```swift
import Foundation

// Pure value + a total mapping function, importing ONLY Foundation.
enum FocusActivity: Equatable {
    case on
}

func focusActivity(from isFocused: Bool) -> FocusActivity? {
    isFocused ? .on : nil
}
```

**Apply to `OSDActivity.swift`:** same "plain value + total function" shape, but the CONTEXT.md/RESEARCH.md primary recommendation is ONE shared type with an inner enum (`OSDActivity` = `.volume(percent: Int, muted: Bool)` / `.brightness(percent: Int)`), not two files. Mirror `FocusActivity`'s Foundation-only import discipline. Per RESEARCH Open Question 3: implement the muted check as a pure total function, e.g. `isMuted = hardwareMuted || percent == 0` (D-03), inside this file's own mapping function — do not duplicate that OR anywhere else. Clamp percent to `0...100` here (V5 input validation from RESEARCH's Security Domain) — mirrors `PowerSourceMonitor.readCurrentPower()`'s defensive-optional-cast convention (`d[kIOPSCurrentCapacityKey] as? Int ?? 0`), just applied at the pure-mapping seam instead of the glue seam.

---

### `Islet/Notch/OSDInterceptor.swift` (NEW — service, event-driven)

**Analog:** `Islet/Notch/DropInterceptTap.swift` (read in full, 116 lines) — the ONLY existing CGEventTap in this codebase.

**Imports + class shape** (lines 1, 15-19):
```swift
import AppKit

final class DropInterceptTap {
    private var machPort: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var healthCheckTimer: Timer?
```

**Permission + tap-creation pattern** (lines 33-67):
```swift
func start() {
    guard machPort == nil else { return }
    _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary)
    guard let tap = CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: CGEventMask(1 << CGEventType.leftMouseUp.rawValue),
        callback: { _, type, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }
            let tap = Unmanaged<DropInterceptTap>.fromOpaque(userInfo).takeUnretainedValue()
            return tap.handle(type: type, event: event)
        },
        userInfo: Unmanaged.passUnretained(self).toOpaque()
    ) else { return }   // silent no-op on missing Accessibility
    let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
    CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    CGEvent.tapEnable(tap: tap, enable: true)
    machPort = tap
    runLoopSource = source
    healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
        self?.checkHealthAndReinstallIfNeeded()
    }
}

private func checkHealthAndReinstallIfNeeded() {
    guard let machPort else { return }
    if !CGEvent.tapIsEnabled(tap: machPort) { stop(); start() }
}
```

**Lifecycle teardown** (lines 108-116):
```swift
nonisolated func stop() {
    if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
    if let machPort { CGEvent.tapEnable(tap: machPort, enable: false) }
    machPort = nil
    runLoopSource = nil
    healthCheckTimer?.invalidate()
    healthCheckTimer = nil
}
```

**REQUIRED DEVIATIONS from this analog** (per RESEARCH.md Pattern 1, Pitfall 2, Pitfall 3 — do not copy verbatim):
1. **Dedicated `DispatchQueue`, not `CFRunLoopGetMain()`** — Droppy's own fix for a main-thread-contention "double HUD" bug during rapid key-repeat scrubbing. `DropInterceptTap` uses the main run loop because its one `.leftMouseUp` event is rare; volume/brightness keys fire rapidly and must not share that queue.
2. **`checkHealthAndReinstallIfNeeded()` must also handle `machPort == nil`** (Pitfall 2) — `DropInterceptTap`'s version (`guard let machPort else { return }`) only reinstalls an existing-but-disabled tap; it can never recover from "Accessibility wasn't granted at `start()` time." D-07 requires `OSDInterceptor`'s health check to ALSO call `start()` when `machPort == nil` and `AXIsProcessTrusted()` (no-prompt query) now returns `true`.
3. **`eventsOfInterest` is `NX_SYSDEFINED`** (`CGEventType.systemDefined`, raw value 14), not `.leftMouseUp`.
4. **`NSEvent(cgEvent:)` construction and the key-code decode must happen on main**, never inside the C callback on the tap queue (Pitfall 3 — Caps Lock/TSM crash precedent from Droppy's own history). Decode the swallow/pass decision fast and synchronously on the tap queue; hop `DispatchQueue.main.async` (not `.sync`) for the level-read + resolver enqueue.
5. **Handler signature** differs entirely — see the RESEARCH.md Pattern 2 bit-decode block for the concrete `handle(type:event:)` body (NX_KEYTYPE_* allowlist of SOUND_UP/DOWN/MUTE/BRIGHTNESS_UP/DOWN, unconditional passthrough for every other code including all 4 transport keys).

---

### `Islet/Notch/VolumeReader.swift` (NEW — service, request-response)

**Analog:** `Islet/Notch/PowerSourceMonitor.swift`'s `readCurrentPower()` (lines 26-55, read in full) — the "thin system-call wrapper, isolated in its own file" convention.

**Pattern to mirror — defensive optional-cast, never force-unwrap:**
```swift
// PowerSourceMonitor.swift lines 42-50
let state    = d[kIOPSPowerSourceStateKey] as? String
let isOnAC   = (state == kIOPSACPowerValue)
let charging = d[kIOPSIsChargingKey] as? Bool ?? false
let charged  = d[kIOPSIsChargedKey] as? Bool ?? false
let cur      = d[kIOPSCurrentCapacityKey] as? Int ?? 0
let mx       = d[kIOPSMaxCapacityKey] as? Int ?? 100
let pct      = mx > 0 ? Int((Double(cur) / Double(mx) * 100).rounded()) : cur
```

**Apply to `VolumeReader.swift`:** same defensive-cast, always-return-a-safe-default discipline, using `AudioObjectGetPropertyData` (CoreAudio, public API) as shown in RESEARCH.md Pattern 3's `readSystemVolume()` example — **use `kAudioHardwareServiceDeviceProperty_VirtualMainVolume`, NOT `VirtualMasterVolume`** (renamed at Xcode 13; the old symbol will not resolve on this project's SDK — RESEARCH Pitfall 4). Return a plain synchronous struct/tuple like `readCurrentPower()` does — no monitor/class needed for volume (the event trigger is the key press via `OSDInterceptor`, not a live-updating notification source like `PowerSourceMonitor`'s `IOPSNotificationCreateRunLoopSource`).

---

### `Islet/Notch/BrightnessReader.swift` (NEW — service, request-response)

**Analog:** `Islet/Notch/PowerSourceMonitor.swift` for the "isolate one fragile system surface per file, silent-degrade on failure" discipline (same file as above) — there is no dynamic-`CFBundle`-load precedent elsewhere in this codebase to copy verbatim (RESEARCH.md confirms: "this project has no existing CoreAudio/DisplayServices code to reuse"). Listed in RESEARCH.md's "No Analog Found" category below for the dynamic-load mechanics specifically.

**Silent-degrade convention to mirror** (from `PowerSourceMonitor.readCurrentPower()`'s no-battery-found fallback, line 53-54):
```swift
// No internal battery found in the list → no-op reading (no splash, no crash).
return PowerReading(isPresent: false, isOnAC: false, isCharging: false, isCharged: false, percent: 0)
```
`BrightnessReader.readBrightness()` must apply the same never-crash principle but return `Int?` (not a defaulted `0`) per RESEARCH's Security Domain table: "a failed read must suppress the Brightness HUD entirely, never render a false '0%'" — this is a deliberate divergence from `PowerReading`'s all-fields-defaulted shape, not a copy of it.

**Dynamic-load skeleton** (RESEARCH.md Pattern 3, cited from Droppy's shipping source — no in-repo precedent, use as-is):
```swift
final class BrightnessReader {
    private typealias GetBrightnessFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private var getBrightness: GetBrightnessFn?

    init() {
        let path = "/System/Library/PrivateFrameworks/DisplayServices.framework"
        guard let url = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, path as CFString, .cfurlposixPathStyle, true),
              let bundle = CFBundleCreate(kCFAllocatorDefault, url),
              CFBundleLoadExecutable(bundle),
              let ptr = CFBundleGetFunctionPointerForName(bundle, "DisplayServicesGetBrightness" as CFString)
        else { return }
        getBrightness = unsafeBitCast(ptr, to: GetBrightnessFn.self)
    }

    func readBrightness() -> Int? {
        guard let getBrightness else { return nil }
        var value: Float = 0
        guard getBrightness(CGMainDisplayID(), &value) == 0 else { return nil }
        return Int((value * 100).rounded())
    }
}
```

---

### `Islet/Notch/IslandResolver.swift` (EXTEND — model, transform)

**Analog:** itself — Phase 38's Focus additions are the exact precedent for every mechanism D-09/D-12/D-13 need. File read in full (298 lines).

**1. `ActiveTransient` case + `IslandPresentation` case** (lines 54-76):
```swift
enum IslandPresentation: Equatable {
    ...
    case focus(FocusActivity)                        // Phase 38 / HUD-05: rank 3 transient, collapsed-only (D-07)
    ...
}
enum ActiveTransient: Equatable {
    case charging(ChargingActivity)
    case device(DeviceActivity)
    case focus(FocusActivity)
}
```
Add `case osd(OSDActivity)` to both enums (per CONTEXT.md's discretion note — one shared case with an inner enum, not two separate cases, so `updateHead`'s same-category-replace gives D-12 "for free").

**2. `isPersistent`** (lines 83-88) — Volume/Brightness must NOT be added here (they self-elapse via D-10's 1.5s timer, unlike Focus):
```swift
extension ActiveTransient {
    var isPersistent: Bool {
        if case .focus = self { return true }
        return false
    }
}
```
`.osd` falls through the `return false` default — no change needed to this function at all, only a comment noting why.

**3. `resolve(...)`'s transient switch — new rank-4 collapsed-only tier** (lines 117-123):
```swift
switch activeTransient {                              // D-04: transient wins even over expanded
case .charging(let a): return .charging(a)           // D-02 rank 1
case .device(let d):   return .device(d)             // D-02 rank 2
case .focus(let f) where !isExpanded: return .focus(f) // Phase 38 / HUD-05 rank 3, collapsed-only (D-07)
case .focus: break                                    // expanded -- falls through to the isExpanded branch below, unmodified
case nil: break
}
```
Add a 4th tier below Focus, same `where !isExpanded` / `break`-when-expanded shape: `case .osd(let o) where !isExpanded: return .osd(o)` then `case .osd: break`.

**4. `TransientQueue.preempt()`** (lines 249-263) — D-13 requires Volume/Brightness to preempt a standing Focus head, exactly reusing this existing mechanism (built in Phase 38 for exactly this problem):
```swift
mutating func preempt(_ t: ActiveTransient) -> Bool {
    guard case .focus = head else { return enqueue(t) }
    let displaced = head!
    head = t
    pending.insert(displaced, at: 0)
    return true
}
```
No change needed to `preempt()` itself — the controller calls it with `.osd(...)` exactly like it already does with `.charging(...)`/`.device(...)`.

**5. `TransientQueue.updateHead()`** (lines 273-285) — D-09 needs a NEW variant (current one explicitly does NOT re-arm the timer, by design, for Charging's % ticks):
```swift
mutating func updateHead(_ t: ActiveTransient) {
    guard let h = head else { return }
    switch (h, t) {
    case (.charging, .charging): head = t
    case (.device, .device):     head = t
    default: break   // different category — ignore (use enqueue)
    }
}
```
Add `case (.osd, .osd): head = t` to the existing switch (same-category match covers BOTH D-09's Volume-scrub-refresh case AND D-12's Volume↔Brightness instant-replace case, since both are `.osd` regardless of inner enum value) — this is the "2-line addition" RESEARCH.md's Primary Recommendation calls out. The RE-ARM behavior itself (D-09) is a controller-side concern (the caller decides whether to also call `scheduleActivityDismiss()` after `updateHead`), not a change to this pure function's contract — do not add a Timer/re-arm parameter to this Foundation-only file.

**Pure-reducer discipline to preserve:** this file imports ONLY `Foundation` (header comment, line 4-8) — no AppKit, no SwiftUI, no CoreAudio, no CGEventTap types. `OSDActivity`'s inner enum values (Int percent, Bool muted) are plain, so this constraint is easy to keep.

---

### `Islet/Notch/NotchPillView.swift` (EXTEND — component, transform)

**Analog 1 (wing-wrapper structure):** `focusWings(for:)` (lines 2151-2179, read in full).
```swift
private func focusWings(for activity: FocusActivity) -> some View {
    wingsShape(
        leftWidth: 118,
        rightWidth: 160
    ) {
        HStack(spacing: 0) {
            Image(systemName: "moon.fill")
                .font(.system(size: 13, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white)
                .padding(.leading, 14)
            Spacer()                                      // clears the physical camera bridge
            HStack(spacing: 4) {
                Circle().fill(Color.green)                 // fixed, universal active signal — never theme-tinted
                    .frame(width: 8, height: 8)
                Text("On")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .padding(.trailing, 20)
        }
    }
}
```
Apply the SAME `wingsShape(leftWidth:rightWidth:content:)` wrapper for `osdWings(for:)` — icon LEFT (per D-01), fill bar RIGHT (replacing Focus's icon+label pairing). D-02's fixed-color rule (`.foregroundStyle(.white)`, never `.deviceAccent`/`.chargingAccent`) carries over unchanged — same discipline focusWings already applies (comment: "D-11 ... a universal system-level state should read consistently regardless of the user's chosen accent theme").

**Analog 2 (fill-bar technique):** `ProgressBar` struct's `GeometryReader`/`Capsule` fill pattern (lines 2542-2548, read in full).
```swift
GeometryReader { geo in
    ZStack(alignment: .leading) {
        Capsule().fill(Color.white.opacity(0.25))          // unfilled track (D-03)
        Capsule().fill(tint).frame(width: geo.size.width * fraction)  // filled (D-03/D-04)
    }
}
.frame(height: 3)   // D-04: thin 3pt line
```
Reuse this exact `GeometryReader { ZStack(alignment: .leading) { unfilled Capsule; filled Capsule.frame(width: geo.size.width * fraction) } }` shape for the D-01 bar — this is the only existing "filled progress bar" primitive in the codebase. Apply D-02's fixed colors as `tint`: green for Volume, orange/yellow for Brightness (not `.white` like ProgressBar's default). Wrap the bar's `fraction` value in `withAnimation(.spring(...))` at the CONTROLLER layer for D-04's spring-not-snap requirement — mirrors this file's own "the view drives no animation of its own" convention (see `wings(for:)`'s and `focusWings(for:)`'s header comments: "the controller wraps the activity mutation in its spring wrapper").

**Dispatch switch site** (line 735, inside the presentation `switch`):
```swift
case .focus(let activity): focusWings(for: activity)                 // D-02 rank 3 transient (38-04)
```
Add `case .osd(let activity): osdWings(for: activity)` alongside it, in the same switch.

**D-03 icon swap:** mirror `wings(for:)`'s (Charging) conditional-icon pattern (lines 1983-1991) — `isCharging ? bolt.fill (green) : bolt.fill (dim white)` — for Volume's `speaker.wave.fill` → `speaker.slash.fill` swap when `isMuted` (computed in the pure `OSDActivity` mapping, per D-03/Open-Question-3 above), with the bar's `fraction` forced to 0 in that state.

---

### `Islet/Notch/NotchWindowController.swift` (EXTEND — controller, event-driven)

**Analog:** the complete Focus wiring chain (Phase 38), read across four sections.

**Monitor property declaration** (line 209):
```swift
private var focusModeMonitor: FocusModeMonitor?
```
Add `private var osdInterceptor: OSDInterceptor?` alongside it (plus, if the dual-tap architecture from RESEARCH Open Questions is adopted, a second property for the listen-only variant — confirm against the locked plan before implementing, this is RESEARCH's own flagged open item).

**Idempotent start** (lines 613-619):
```swift
private func startFocusModeMonitor() {
    guard focusModeMonitor == nil else { return }
    let monitor = FocusModeMonitor { [weak self] isFocused in self?.handleFocusChange(isFocused) }
    focusModeMonitor = monitor
    monitor.start()
}
```
Mirror exactly for `startOSDInterceptor()`.

**Preempt-against-Focus call site** (lines 393-397, inside `DeviceCoordinator`'s `enqueue` closure — same pattern also appears at lines 1565-1573 for Charging):
```swift
enqueue: { [weak self] t in
    guard let self else { return false }
    if case .focus = self.transientQueue.head { return self.transientQueue.preempt(t) }
    return self.transientQueue.enqueue(t)
},
```
D-13 requires the SAME `if case .focus = head { preempt } else { enqueue }` shape at the OSD key-press handler call site.

**Handler + dismiss-arm pattern** (`handleFocusChange`, lines 1593-1608):
```swift
private func handleFocusChange(_ isFocused: Bool) {
    if isFocused {
        guard let activity = focusActivity(from: true) else { return }
        let changed = transientQueue.enqueue(.focus(activity))
        if changed {
            presentTransientChange()
        }
    } else {
        flushTransients(.focus)
        withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
            renderPresentation()
        }
        updateVisibility()
    }
}
```
The OSD handler differs materially here per D-09: EVERY key press (not just the on/off edge Focus has) must either `enqueue`/`preempt` (new value, no standing `.osd` head) OR call the NEW `updateHead` + explicitly re-arm `scheduleActivityDismiss()` (same category already standing) — Focus's handler has no re-arm-on-every-tick concept to copy verbatim; instead mirror the Charging % -tick branch shape (lines 1577-1584) for the "already standing, same category, refresh + re-arm" half:
```swift
} else if next != nil, case .charging = transientQueue.head {
    chargingState.activity = next
    if let activity = next { transientQueue.updateHead(.charging(activity)) }
    renderPresentation()
}
```
Note Charging's version deliberately does NOT re-arm the timer (Pitfall 4 comment) — the OSD handler must explicitly ADD a `scheduleActivityDismiss()` call in its own same-category branch that Charging's does not have, per D-09's locked requirement.

**`isPersistent`-gated dismiss timer** (lines 1618-1624) — needs zero changes; `.osd` is not persistent so it already gets a timer armed. D-10's 1.5s duration is a NEW separate constant, not `activityDuration` — locate that constant's declaration and add `osdActivityDuration = 1.5` alongside it, threading it through wherever `scheduleActivityDismiss()`'s duration is currently hardcoded/shared for the `.osd` case specifically (D-10 explicitly forbids consolidating into the shared constant).

**`flushTransients` category enum + switch** (lines 1788-1803):
```swift
private enum TransientCategory { case charging, device, focus }
private func flushTransients(_ category: TransientCategory) {
    let oldHead = transientQueue.head
    let matches: (ActiveTransient) -> Bool = { t in
        switch (t, category) {
        case (.charging, .charging), (.device, .device), (.focus, .focus): return true
        default: return false
        }
    }
    transientQueue.removeAll(where: matches)
    switch category {
    case .charging: chargingState.activity = nil
    case .device: deviceCoordinator.clearPendingBatteryPolls()
    case .focus: break
    }
    guard transientQueue.head != oldHead else { return }
    ...
}
```
Add `case osd` to `TransientCategory`, a matching `(.osd, .osd): return true` arm, and (most likely) `case .osd: break` in the model-clear switch, mirroring Focus's "no separate `@Published` model to clear" comment — Volume/Brightness state most likely also lives entirely in the resolver's `IslandPresentation`, not a separate `@Published` field, unless the planner decides otherwise.

**Settings-toggle start/stop gate** (lines 1734-1738, `handleSettingsChanged()`):
```swift
if activityEnabled(ActivitySettings.focusKey) && FocusModeMonitor.isAuthorized {
    startFocusModeMonitor()
} else if focusModeMonitor != nil {
    focusModeMonitor?.stop(); focusModeMonitor = nil
    flushTransients(.focus)
}
```
Mirror for the OSD toggle, BUT per D-06 the HUD itself must show regardless of Accessibility — so this gate structure likely needs adapting: RESEARCH's Open Question 1 flags this as a genuine unresolved product question the planner must confirm before wiring this exact branch (does `activityEnabled(osdKey)` gate detection+HUD+suppression together, or only suppression while an always-on listen tap handles HUD-only detection). Do not copy this gate verbatim without resolving that question first.

**`default(for:)`-style default-false key** (lines 566-567, referenced in NotchWindowController's `activityEnabled` default lookup):
```swift
let defaultValue = (key == ActivitySettings.focusKey) ? false : true
```
Add `ActivitySettings.osdKey` (or whatever key name is chosen) to this same OFF-by-default carve-out per D-05 ("mirrors Focus Mode's D-01 exactly... stays opt-in").

**Deinit teardown** (line 2134 area): `focusModeMonitor?.stop()` — add `osdInterceptor?.stop()` alongside it.

---

### `Islet/ActivitySettings.swift` (EXTEND — config, CRUD)

**Analog:** `focusKey` + `focusPermissionStatusHint(toggleOn:granted:)` (lines 19-22, 73-80, read in full).
```swift
static let focusKey = "activity.focus"
...
static func focusPermissionStatusHint(toggleOn: Bool, granted: Bool) -> String? {
    guard toggleOn else { return nil }
    return granted ? "Active" : "Permission needed — tap to grant"
}
```
Add `static let osdSuppressionKey = "activity.osdSuppression"` (or similar, per CONTEXT.md's Claude's Discretion on naming) and an analogous `osdPermissionStatusHint(toggleOn:granted:)` pure function, same shape. This is the shared key namespace both `SettingsView` and `NotchWindowController` read — never redefine the string elsewhere (file's own header discipline, lines 8-12).

---

### `Islet/SettingsView.swift` (EXTEND — component, request-response)

**Analog:** the Focus Mode HUD toggle + explanation popover (lines 211-227, 257-288, read in full).
```swift
Toggle("Focus Mode HUD", isOn: $focusEnabled)
    .onChange(of: focusEnabled) { _, on in
        if on && !FocusModeMonitor.isAuthorized {
            showFocusPermissionExplanation = true
        }
    }
    .popover(isPresented: $showFocusPermissionExplanation) {
        focusPermissionExplanationView
    }
if let hint = ActivitySettings.focusPermissionStatusHint(
    toggleOn: focusEnabled, granted: FocusModeMonitor.isAuthorized
) {
    Text(hint)
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .onTapGesture { showFocusPermissionExplanation = true }
}
```
```swift
private var focusPermissionExplanationView: some View {
    VStack(alignment: .leading, spacing: 8) {
        Text("Allow Focus Status Access")...
        Text("Islet needs permission to detect when Focus or Do Not Disturb is on.")...
        HStack {
            Button("Not Now") { showFocusPermissionExplanation = false }
            Spacer()
            Button("Continue") {
                FocusModeMonitor.requestAuthorization { granted in
                    DispatchQueue.main.async {
                        if granted { (NSApp.delegate as? AppDelegate)?.notchController?.focusPermissionGranted() }
                        showFocusPermissionExplanation = false
                    }
                }
            }
            .keyboardShortcut(.defaultAction)
        }
    }
    .padding(16)
    .frame(width: 280)
}
```

**CRITICAL DEVIATION (per RESEARCH.md's own explicit flag, not a copy-paste target):** D-08 says the OSD toggle's explanation should deep-link via `x-apple.systempreferences:` to System Settings → Accessibility. Focus's `"Continue"` button above does NOT do this — it calls `FocusModeMonitor.requestAuthorization(completion:)`, a completion-based re-request API that Accessibility has no equivalent of. The OSD toggle's `"Continue"` button must instead call:
```swift
NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
```
This is genuinely new code in this codebase — there is no existing deep-link precedent to copy (RESEARCH.md's Assumptions Log note, verbatim: "There is no existing deep-link code in this codebase to reuse"). Mirror the popover/toggle SHELL structure above, but write the deep-link body fresh.

---

### `IsletTests/OSDActivityTests.swift` (NEW — test, transform)

**Analog:** `IsletTests/FocusActivityTests.swift` (read in full, 21 lines).
```swift
import XCTest
@testable import Islet

final class FocusActivityTests: XCTestCase {
    func testFocusedMapsToOn() {
        XCTAssertEqual(focusActivity(from: true), .on)
    }
    func testNotFocusedMapsToNil() {
        XCTAssertNil(focusActivity(from: false))
    }
}
```
Mirror this total-function test-every-branch style for `OSDActivity`'s pure mapping, explicitly covering RESEARCH Open Question 3's two muted-trigger paths (`hardwareMuted == true` AND `percent == 0` each independently produce the muted state) and percent clamping (0...100).

---

### `IsletTests/IslandResolverTests.swift` (EXTEND — test, transform)

**Analog:** the Focus test block, lines 619-665 (read in full):
```swift
func testFocusWinsWhenCollapsed() {
    let r = resolve(activeTransient: .focus(.on), nowPlaying: .none, nowPlayingHealthy: true,
                    hasPlayedSinceLaunch: true, isExpanded: false)
    XCTAssertEqual(r, .focus(.on))
}
func testFocusFallsThroughWhenExpanded() {
    let r = resolve(activeTransient: .focus(.on), nowPlaying: .none, nowPlayingHealthy: true,
                    hasPlayedSinceLaunch: false, isExpanded: true, selectedView: .home)
    XCTAssertEqual(r, .homeEmpty)
}
func testActiveTransientIsPersistentFlags() {
    XCTAssertFalse(ActiveTransient.charging(.charging(percent: 50)).isPersistent)
    XCTAssertFalse(ActiveTransient.device(.connected(name: "AirPods Pro", glyph: .airpodsPro, battery: nil)).isPersistent)
    XCTAssertTrue(ActiveTransient.focus(.on).isPersistent)
}
func testPreemptPushesFocusToFrontOfPending() {
    var q = TransientQueue()
    _ = q.enqueue(.focus(.on))
    XCTAssertTrue(q.preempt(.charging(.charging(percent: 50))))
    XCTAssertEqual(q.head, .charging(.charging(percent: 50)))
    XCTAssertTrue(q.advance())
    XCTAssertEqual(q.head, .focus(.on))
}
```
Add the mirrored set for `.osd`: collapsed-only win / expanded fallthrough (same shape as `testFocusWinsWhenCollapsed`/`testFocusFallsThroughWhenExpanded`), `.osd(...).isPersistent == false` (extend `testActiveTransientIsPersistentFlags`), `.osd` preempting a standing Focus head (mirrors `testPreemptPushesFocusToFrontOfPending` with `.osd(.volume(...))` swapped in for `.charging(...)`), and — the D-12-specific new case with no direct Focus precedent — `updateHead` replacing `.osd(.volume(...))` with `.osd(.brightness(...))` instantly, asserted against the new `(.osd, .osd)` switch arm.

## Shared Patterns

### CGEventTap lifecycle (permission → tapCreate → health-check → teardown)
**Source:** `Islet/Notch/DropInterceptTap.swift` (whole file)
**Apply to:** `OSDInterceptor.swift`, with the 3 required deviations listed above (dedicated queue, `machPort == nil` health-check recovery, main-thread NSEvent decode).

### Monitor idempotent start()/nonisolated stop() + owner-driven deinit
**Source:** `Islet/Notch/PowerSourceMonitor.swift` and `Islet/Notch/FocusModeMonitor.swift` (both read in full) — identical shape in both:
```swift
func start() {
    guard !running /* or guard machPort == nil */ else { return }
    ...
}
nonisolated func stop() { ... }
deinit {
    // deinit can't be @MainActor in Swift 5 mode; owner's deinit calls monitor.stop().
}
```
**Apply to:** any new monitor-shaped type this phase introduces (if `VolumeReader`/`BrightnessReader` end up needing live-update lifecycles rather than pure synchronous reads — current recommendation is synchronous read-on-demand, no monitor needed for either).

### `wingsShape(leftWidth:rightWidth:content:)` wing wrapper
**Source:** `Islet/Notch/NotchPillView.swift` lines 1929-1952 (read in full)
**Apply to:** `osdWings(for:)` — every collapsed-pill wing in this codebase (Charging, Device, Focus) routes through this one shared shape/morph/tap-gesture wrapper; do not build a new wrapper shape for OSD.

### Fixed (never accent-tinted) color for universal system states
**Source:** `focusWings(for:)`'s D-11 comment (`Islet/Notch/NotchPillView.swift` lines 2148-2150) — "icon + label render in a FIXED white, never deviceAccent/chargingAccent/any theme accent — a universal system-level state should read consistently regardless of the user's chosen accent theme."
**Apply to:** D-02's fixed green/orange bar colors and fixed white icon — same rationale, same precedent, extended from Phase 36's D-03/D-11.

### Transient priority: preempt vs enqueue against a persistent Focus head
**Source:** `Islet/Notch/IslandResolver.swift` `TransientQueue.preempt()` (lines 249-263) + its two call sites in `NotchWindowController.swift` (Device coordinator's `enqueue` closure, lines 393-397; Charging's branch, lines 1565-1573)
**Apply to:** the OSD key-press handler's enqueue call — same `if case .focus = transientQueue.head { preempt } else { enqueue }` shape, third call site of an already-2x-repeated pattern.

### Settings toggle + off-by-default + permission popover + status hint
**Source:** `Islet/SettingsView.swift` lines 211-227 (toggle+popover) and 257-288 (explanation view), `Islet/ActivitySettings.swift` lines 19-22, 73-80 (key + hint function), `Islet/Notch/NotchWindowController.swift` lines 566-567 (default-false carve-out) and 1734-1738 (start/stop gate)
**Apply to:** the OSD suppression toggle — full chain already proven end-to-end by Focus Mode HUD (Phase 38), with the one confirmed deviation being the deep-link mechanism (D-08, see SettingsView section above) instead of `requestAuthorization(completion:)`.

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `Islet/Notch/BrightnessReader.swift`'s `CFBundle` dynamic-load mechanics specifically (the `init()` body loading `/System/Library/PrivateFrameworks/DisplayServices.framework`) | service | request-response | No private-framework dynamic-load code exists anywhere in this codebase yet — `MediaRemoteAdapter` (the closest conceptual cousin) is a linked SPM package with `Embed & Sign`, not a runtime `CFBundleCreate`/`CFBundleGetFunctionPointerForName` load. Use RESEARCH.md Pattern 3's cited Droppy-sourced skeleton directly (reproduced above) — it is already verified against this project's SDK constraints in RESEARCH.md's Assumptions Log (A3). |
| The Volume/Brightness NX_SYSDEFINED bit-decode constants and `handle(type:event:)` body | logic (pure decode) | transform | `DropInterceptTap.handle(type:event:)` decodes `.leftMouseUp`, an entirely different event type with no bit-shifting; there is no NX_SYSDEFINED-decoding precedent in this codebase. Use RESEARCH.md Pattern 2's cited skeleton directly (multiple independent community sources agree on the constants; RESEARCH's own spike — Success Criterion 1 — is designed to verify them on-device before any suppression logic depends on them, per Assumptions Log A1). |
| Dual-tap `.listenOnly`-vs-`.defaultTap` architecture (if adopted per RESEARCH Open Questions 1/2) | service | event-driven | `DropInterceptTap` only ever uses `.defaultTap`; there is zero in-repo evidence for how `.listenOnly` behaves on `.cgSessionEventTap` + `NX_SYSDEFINED` specifically. This is an unresolved architectural question RESEARCH.md flags explicitly — confirm before planning locks the toggle's wiring, do not assume a pattern from this codebase covers it. |

## Metadata

**Analog search scope:** `Islet/Notch/` (all monitor/resolver/wing/interceptor files), `Islet/` (SettingsView.swift, ActivitySettings.swift), `IsletTests/` (FocusActivityTests.swift, IslandResolverTests.swift)
**Files scanned:** IslandResolver.swift, FocusActivity.swift, FocusModeMonitor.swift, DropInterceptTap.swift, PowerSourceMonitor.swift, NotchPillView.swift (targeted sections: wingsShape, wings(for:), focusWings(for:), ProgressBar, dispatch switch), NotchWindowController.swift (targeted sections: monitor properties, preempt call sites, handleFocusChange, scheduleActivityDismiss, flushTransients, settings-change gate), ActivitySettings.swift, SettingsView.swift (targeted: Focus toggle + popover), IsletTests/FocusActivityTests.swift, IsletTests/IslandResolverTests.swift (targeted: Focus test block)
**Pattern extraction date:** 2026-07-17
