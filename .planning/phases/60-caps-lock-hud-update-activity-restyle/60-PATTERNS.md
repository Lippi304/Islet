# Phase 60: Caps Lock HUD + Update-Activity Restyle - Pattern Map

**Mapped:** 2026-07-23
**Files analyzed:** 9 (2 new, 7 modified)
**Analogs found:** 9 / 9

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|--------------------|------|-----------|-----------------|----------------|
| `Islet/Notch/CapsLockMonitor.swift` (NEW) | service (OS event monitor) | event-driven | `Islet/Notch/OSDInterceptor.swift` (Accessibility-gating half) + `Islet/Notch/PowerSourceMonitor.swift` (lifecycle skeleton) | role-match (composite of two analogs, no single exact match exists) |
| `Islet/Notch/NotchPillView.swift` — `wingsShape` (+`onTap` param) | component (shared view helper) | render/transform | itself, `NotchPillView.swift:2302-2348` | exact (additive edit to existing helper) |
| `Islet/Notch/NotchPillView.swift` — `capsLockWings(for:)` (NEW func) | component | render/transform | `focusWings(for:)` (`NotchPillView.swift:2588-2612`, closest shape: icon+label always visible) | exact |
| `Islet/Notch/NotchPillView.swift` — `updateWings(for:)` (NEW func) | component | render/transform | `wings(for:)` (`NotchPillView.swift:2355-2395`, closest shape: icon+label left, trailing pill right) | exact |
| `Islet/Notch/NotchPillView.swift` — `UpdateVersionPill` (NEW small view) | component | render/transform | `Islet/Notch/BatteryIndicator.swift` (visual language only, not content/fill-bar) | role-match |
| `Islet/Notch/IslandResolver.swift` | model / reducer | pure transform (CRUD-like state resolution) | itself — `.focus`/`.osd` cases (`:98-99`, `:117`, `:167-168`) are the literal template for `.capsLock`/`.updateAvailable` | exact |
| `Islet/Notch/NotchWindowController.swift` — `handleCapsLockChange`/`handleUpdateAvailable` (NEW funcs) + `activityEnabled(_:)` fix | controller | event-driven | `handleFocusChange` (`:2078-2093`), `handleOSDKeyPress` (`:2121-2196`) | exact |
| `Islet/ActivitySettings.swift` — `updateHudKey` (NEW constant) | config | CRUD (UserDefaults key) | `capsLockKey`/`downloadProgressKey` (`:35-36`) | exact |
| `Islet/SettingsView.swift` — `updateHudEnabled`, `ActivityCardData(id: "update"...)`, `capsLockPermissionExplanationView`, Caps Lock `onOptionsTap` wiring | component (settings UI) | CRUD + request-response (popover) | `osdPermissionExplanationView`/`focusPermissionExplanationView` (`:648-708`), `capsLock`/`downloadProgress` `ActivityCardData` entries (`:194-201`) | exact |
| `Islet/AppDelegate.swift` — `didFindValidUpdate` (extend) | controller (Sparkle delegate callback) | event-driven | itself, `:389-393` | exact (additive edit) |
| `IsletTests/IslandResolverTests.swift` (extend) | test | unit/pure-function | `testFocusWinsWhenCollapsed`/`testFocusFallsThroughWhenExpanded`/`testOSDPreemptsStandingFocusHead` (`:621-707`) | exact |
| `IsletTests/ActivitySettingsTests.swift` (extend) | test | unit | existing per-key default-value tests (pattern confirmed, not read line-by-line — same file, same convention as `IslandResolverTests`) | exact |

## Pattern Assignments

### `Islet/Notch/CapsLockMonitor.swift` (NEW — service, event-driven)

**Analog:** `Islet/Notch/PowerSourceMonitor.swift` (lifecycle skeleton) + `Islet/Notch/OSDInterceptor.swift` (Accessibility gate)

**Lifecycle skeleton to clone** (`PowerSourceMonitor.swift:60-112`, verbatim):
```swift
@MainActor
final class PowerSourceMonitor {
    private nonisolated(unsafe) var runLoopSource: CFRunLoopSource?
    private let onChange: (PowerReading) -> Void

    init(onChange: @escaping (PowerReading) -> Void) { self.onChange = onChange }

    func start() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        let callback: IOPowerSourceCallbackType = { ctx in
            guard let ctx = ctx else { return }
            let monitor = Unmanaged<PowerSourceMonitor>.fromOpaque(ctx).takeUnretainedValue()
            DispatchQueue.main.async {
                monitor.onChange(readCurrentPower())
            }
        }
        guard let src = IOPSNotificationCreateRunLoopSource(callback, context)?.takeRetainedValue() else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        runLoopSource = src
        onChange(readCurrentPower())
    }

    nonisolated func stop() {
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
            runLoopSource = nil
        }
    }

    deinit {
        // deinit can't be @MainActor in Swift 5 mode, so it does NOT call stop() here.
        // The controller (@MainActor) owns the monitor for the app lifetime and calls
        // stop() from its own deinit.
    }
}
```
`CapsLockMonitor` should follow this exact `init(onChange:)` / idempotent `start()` (guard against double-install) / `nonisolated func stop()` / empty `deinit` shape, swapping `NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged)` for the IOKit run-loop source. Store the monitor token (`NSObjectProtocol` returned by `addGlobalMonitorForEvents`) instead of `CFRunLoopSource`, remove it via `NSEvent.removeMonitor(_:)` in `stop()`.

**Accessibility-trust gate to clone** (`OSDInterceptor.swift:43-46, 102-106`, verbatim):
```swift
static var isAccessibilityTrusted: Bool { AXIsProcessTrusted() }

private func desiredMode() -> TapMode {
    (suppressionArmed() && Self.isAccessibilityTrusted) ? .detectAndSuppress : .detectOnly
}
```
`CapsLockMonitor` needs the same `static var isAccessibilityTrusted: Bool { AXIsProcessTrusted() }` and should gate `start()`/event delivery on it exactly like `desiredMode()` does — never call `AXIsProcessTrustedWithOptions(prompt: true)` (anti-pattern, see OSDInterceptor's own comment at `:43-45`).

**Health-check reconcile timer precedent** (`OSDInterceptor.swift:83-100`, for Pitfall 3's live-reconcile spike):
```swift
func start() {
    guard machPort == nil else { return }
    ...
    installTap(mode: desiredMode())
    healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
        self?.reconcileMode()
    }
}
```
If the on-device spike (RESEARCH.md Pitfall 3) shows `NSEvent.addGlobalMonitorForEvents` does NOT live-reconcile after an Accessibility grant, add the same shape: a 5s `Timer` that tears down and reinstalls the monitor once `AXIsProcessTrusted()` flips true.

**Controller ownership pattern** (mirrors `NotchWindowController`'s existing `powerMonitor`/OSD-interceptor ownership — same file, not re-read this session since the shape is already fully documented in RESEARCH.md Pattern 3): a `private var capsLockMonitor: CapsLockMonitor?`, guarded `guard capsLockMonitor == nil else { return }` on start, `.stop()` called from `NotchWindowController.deinit`.

---

### `Islet/Notch/NotchPillView.swift` — `wingsShape` gains `onTap` (controller/component, render)

**Analog:** itself, current implementation (`NotchPillView.swift:2302-2348`, verbatim — the exact block to edit):
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
        .overlay(
            content()
                .frame(width: size.width, height: size.height, alignment: .leading)
        )
        .alignmentGuide(HorizontalAlignment.center) { _ in leftWidth }
        .onTapGesture { onClick() }   // <-- line 2347, the ONE line this phase must parameterize
}
```
**Required edit (UI-SPEC/RESEARCH Pattern 2, locked shape):** add `onTap: (() -> Void)? = nil` as a new parameter (after `rightWidth`, before `content`) and change the last line to `.onTapGesture { (onTap ?? onClick)() }`. This is purely additive — every existing call site (`wings(for:)`, `deviceWings(for:)`, `focusWings(for:)`, `osdWings(for:)`) must compile unchanged since the new parameter defaults to `nil`.

---

### `Islet/Notch/NotchPillView.swift` — `capsLockWings(for:)` (NEW, component, render)

**Analog:** `focusWings(for:)` (`NotchPillView.swift:2588-2612` per RESEARCH.md's verbatim excerpt, confirmed at that line range):
```swift
private func focusWings(for activity: FocusActivity) -> some View {
    wingsShape(leftWidth: 118, rightWidth: 160) {
        HStack(spacing: 0) {
            Image(systemName: "moon.fill")
                .font(.system(size: 13, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white)
                .padding(.leading, 14)
            Spacer()
            HStack(spacing: 4) {
                Circle().fill(Color.green).frame(width: 8, height: 8)
                Text("On").font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(.white)
            }
            .padding(.trailing, 20)
        }
    }
}
```
**Deviation required (D-03, locked):** unlike Focus (icon-only left, label-only right), `capsLockWings(for:)` needs icon-ONLY left (`capslock.fill`, `wingsSize.width/2` = 145pt) and label-ONLY right (`"Caps Lock On"`/`"Caps Lock Off"`, `wingsLabelWidth/2` = 200pt) — see UI-SPEC's exact per-side widths/padding table (60-UI-SPEC.md "Caps Lock Wing Contract"). Use the `wings(for:)` left/right split shape (icon HStack left with `.padding(.leading, 12)`, `Spacer()`, label HStack right with `.padding(.trailing, 14)`) rather than `focusWings`' width split (118/160), since Caps Lock's widths are 145/200 per the UI-SPEC.

---

### `Islet/Notch/NotchPillView.swift` — `updateWings(for:)` (NEW, component, render)

**Analog:** `wings(for:)` (`NotchPillView.swift:2355-2395`, verbatim):
```swift
private func wings(for activity: ChargingActivity) -> some View {
    let isCharging: Bool
    let percent: Int
    switch activity {
    case .charging(let p): isCharging = true;  percent = p
    case .full(let p):     isCharging = false; percent = p
    case .onBattery(let p):isCharging = false; percent = p
    }
    return wingsShape(
        leftWidth: isCharging ? Self.wingsLabelWidth / 2 : Self.wingsSize.width / 2,
        rightWidth: Self.wingsSize.width / 2
    ) {
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
`updateWings(for:)` mirrors this exact HStack/Spacer/trailing-element shape: left = `Self.wingsLabelWidth/2` (200pt) icon+`"Update"` label (always shown, no conditional — Update has no negative state), right = `Self.wingsSize.width/2` (145pt) `UpdateVersionPill` instead of `BatteryIndicator`. **Tap override:** pass `onTap: { triggerSparkleInstall() }` to `wingsShape(...)` (the one and only wing call site using the new non-nil override — see the `wingsShape` edit above).

---

### `Islet/Notch/NotchPillView.swift` — `UpdateVersionPill` (NEW small view)

**Analog (visual weight/language only, NOT content):** `Islet/Notch/BatteryIndicator.swift` (full file, 62 lines, read verbatim):
```swift
struct BatteryIndicator: View {
    let level: Int
    var accent: Color = .green
    private var clamped: Int { min(100, max(0, level)) }
    private var fillColor: Color {
        if clamped <= 10 { return .red }
        if clamped <= 20 { return .orange }
        return accent
    }
    var body: some View {
        let w: CGFloat = 27, h: CGFloat = 13, corner: CGFloat = 3.5, inset: CGFloat = 1.2
        return HStack(spacing: 1.2) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: corner).fill(Color.white.opacity(0.12)).frame(width: w, height: h)
                RoundedRectangle(cornerRadius: corner - inset).fill(fillColor)
                    .frame(width: max(4, (w - inset * 2) * CGFloat(clamped) / 100.0), height: h - inset * 2)
                    .padding(.leading, inset)
                RoundedRectangle(cornerRadius: corner).stroke(Color.white.opacity(0.5), lineWidth: 1).frame(width: w, height: h)
                Text("\(clamped)%").font(.system(size: 7.5, weight: .bold, design: .rounded)).monospacedDigit()
                    .foregroundStyle(.white).shadow(color: .black.opacity(0.4), radius: 0.5).frame(width: w, height: h)
            }
            RoundedRectangle(cornerRadius: 1).fill(Color.white.opacity(0.5)).frame(width: 1.8, height: h * 0.4)
        }
    }
}
```
**Do NOT reuse `BatteryIndicator` itself** (per UI-SPEC's explicit instruction — no "level"/fill concept for a version string). `UpdateVersionPill` borrows only the "compact rounded, legible small text" weight: per 60-UI-SPEC.md's exact spec — `RoundedRectangle(cornerRadius: 4)` fill `Color.white.opacity(0.15)`, stroke `Color.white.opacity(0.3)` width 1, fixed height 16pt, horizontal padding 8pt (auto-sizing width), text `.system(size: 11, weight: .semibold, design: .rounded)`, `.monospacedDigit()`, `Color.white`, content `"v\(item.displayVersionString)"`.

---

### `Islet/Notch/IslandResolver.swift` (model/reducer — CRUD-like case additions)

**Analog:** itself — the `.focus`/`.osd` cases are the literal template (verbatim, `IslandResolver.swift:93-132`):
```swift
enum IslandPresentation: Equatable {
    ...
    case focus(FocusActivity)      // Phase 38 / HUD-05: rank 3 transient, collapsed-only (D-07)
    case osd(OSDActivity)          // Phase 39 / HUD-03/HUD-04: rank 4 transient, collapsed-only (D-11), NOT persistent
    ...
}

enum ActiveTransient: Equatable {
    case charging(ChargingActivity)
    case device(DeviceActivity)
    case focus(FocusActivity)
    case osd(OSDActivity)
}

extension ActiveTransient {
    var isPersistent: Bool {
        if case .focus = self { return true }
        return false
    }
}
```
Add `case capsLock(CapsLockActivity)` (rank 5) and `case updateAvailable(UpdateActivity)` (rank 6) to BOTH enums, following the exact named-rank-comment convention (never renumbering 1-4). Both stay OUT of `isPersistent`'s true-case (self-elapsing, like `.osd`).

**`resolve()`'s collapsed-only branch pattern** (verbatim, `IslandResolver.swift:162-170`):
```swift
switch activeTransient {                              // D-04: transient wins even over expanded
case .charging(let a): return .charging(a)           // D-02 rank 1
case .device(let d):   return .device(d)             // D-02 rank 2
case .focus(let f) where !isExpanded: return .focus(f) // Phase 38 / HUD-05 rank 3, collapsed-only (D-07)
case .focus: break                                    // expanded -- falls through unmodified
case .osd(let o) where !isExpanded: return .osd(o)    // Phase 39 rank 4, collapsed-only (D-11)
case .osd: break                                      // expanded -- falls through unmodified
case nil: break
}
```
Add, in the same shape and same position (after `.osd`, before the `case nil: break` terminal — order matters for switch exhaustiveness, not priority, since Swift matches top-to-bottom but each case is mutually exclusive by pattern):
```swift
case .capsLock(let c) where !isExpanded: return .capsLock(c)
case .capsLock: break
case .updateAvailable(let u) where !isExpanded: return .updateAvailable(u)
case .updateAvailable: break
```

**`TransientQueue`'s `enqueue`/`preempt`/`advance`/`updateHead`** (verbatim, `IslandResolver.swift:319-387`) — no changes needed to this struct itself, only new call-site usage in `NotchWindowController`:
```swift
struct TransientQueue {
    private(set) var head: ActiveTransient?
    private var pending: [ActiveTransient] = []
    let maxDepth = 2

    mutating func enqueue(_ t: ActiveTransient) -> Bool {
        if head == nil { head = t; return true }
        if head == t || pending.contains(t) { return false }
        pending.append(t)
        if pending.count > maxDepth { pending.removeFirst() }
        return false
    }

    mutating func preempt(_ t: ActiveTransient) -> Bool {
        guard case .focus = head else { return enqueue(t) }
        let displaced = head!
        head = t
        pending.insert(displaced, at: 0)
        return true
    }

    mutating func advance() -> Bool {
        guard !pending.isEmpty else { head = nil; return true }
        head = pending.removeFirst()
        return true
    }

    mutating func updateHead(_ t: ActiveTransient) {
        guard let h = head else { return }
        switch (h, t) {
        case (.charging, .charging): head = t
        case (.device, .device):     head = t
        case (.osd, .osd): head = t
        default: break
        }
    }
}
```
Note `preempt` only special-cases `.focus` as the displaced head — Caps Lock/Update handlers must call `preempt` only when `transientQueue.head` is `.focus`, otherwise `enqueue`, exactly mirroring OSD's own call-site branch below.

---

### `Islet/Notch/NotchWindowController.swift` — new handlers + `activityEnabled(_:)` fix

**Analog:** `handleOSDKeyPress(_:)` (`NotchWindowController.swift:2121-2196`) — specifically its enqueue/preempt tail (verbatim):
```swift
if case .osd = transientQueue.head {
    transientQueue.updateHead(.osd(activity))
    withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
        renderPresentation()
    }
    scheduleActivityDismiss()   // D-09 — re-arm on every press while an .osd head stands
} else {
    let changed: Bool
    if case .focus = transientQueue.head {
        changed = transientQueue.preempt(.osd(activity))
    } else {
        changed = transientQueue.enqueue(.osd(activity))
    }
    if changed {
        presentTransientChange()
    }
}
```
And the simpler `handleFocusChange(_:)` (`:2078-2093`, verbatim) for the "no same-category in-place update needed" shape (Update HUD has no scrub-refresh case, so this simpler shape fits it better than OSD's):
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
`handleCapsLockChange(_:)`/`handleUpdateAvailable(version:)` should follow `handleFocusChange`'s simpler enqueue-only shape (no scrub/updateHead case applies to either), with the OSD-style `if case .focus = transientQueue.head { preempt } else { enqueue }` branch substituted in for the initial fire.

**Bug to fix as part of this phase** — `activityEnabled(_:)` (`NotchWindowController.swift:673-676`, verbatim, current/broken state):
```swift
private func activityEnabled(_ key: String) -> Bool {
    let defaultValue = (key == ActivitySettings.focusKey) ? false : true
    return UserDefaults.standard.object(forKey: key) as? Bool ?? defaultValue
}
```
Per RESEARCH.md Pitfall 1 (highest-value finding): this hardcodes only `focusKey` as defaulting `false`; `capsLockKey` and the new `updateHudKey` will silently default to `true` (visible/armed) before the user ever opens Settings, breaking the "both default OFF" requirement. Fix by inverting to an explicit `defaultsToFalseKeys: Set<String>` membership check covering `focusKey`, `osdSuppressionKey`, and all 8 Phase 59 keys (`capsLockKey`, `downloadProgressKey`, `menuBarOverflowKey`, `timerKey`, `meetingHUDKey`, `quickNotesKey`, `quickActionsKey`, `codingProgressKey`) plus this phase's new `updateHudKey` — 10 keys total in the false-default set.

---

### `Islet/ActivitySettings.swift` — `updateHudKey` (NEW constant)

**Analog:** existing key declarations (verbatim, `ActivitySettings.swift:35-42`):
```swift
static let capsLockKey = "activity.capsLock"
static let downloadProgressKey = "activity.downloadProgress"
static let menuBarOverflowKey = "activity.menuBarOverflow"
static let timerKey = "activity.timer"
static let meetingHUDKey = "activity.meetingHUD"
static let quickNotesKey = "activity.quickNotes"
static let quickActionsKey = "activity.quickActions"
static let codingProgressKey = "activity.codingProgress"
```
Add `static let updateHudKey = "activity.updateHud"` in the same block (the "9th" new key per RESEARCH.md's framing). `autoUpdateCheckKey` (`:46`) is a DIFFERENT, pre-existing key (gates Sparkle's background check, not this HUD) — do not conflate or reuse it.

---

### `Islet/SettingsView.swift` — `updateHudEnabled`, new `ActivityCardData`, Caps Lock `onOptionsTap`, `capsLockPermissionExplanationView`

**AppStorage + card analog** (verbatim, `SettingsView.swift:61`, `:194-201`):
```swift
@AppStorage(ActivitySettings.capsLockKey) private var capsLockEnabled = false
...
ActivityCardData(id: "capsLock", title: "Caps Lock",
                  description: "Flashes an on/off indicator whenever Caps Lock is toggled.",
                  icon: "capslock.fill", iconColor: .secondary,
                  isOn: $capsLockEnabled, isNew: true, onOptionsTap: nil),
ActivityCardData(id: "downloadProgress", title: "Download Progress",
                  description: "Shows a live indicator while a file downloads to your Mac.",
                  icon: "arrow.down.circle.fill", iconColor: .secondary,
                  isOn: $downloadProgressEnabled, isNew: true, onOptionsTap: nil),
```
Add `@AppStorage(ActivitySettings.updateHudKey) private var updateHudEnabled = false` (near `capsLockEnabled`, `:61`) and a new `ActivityCardData(id: "update", title: "Update Available", description: "Shows a brief HUD in the notch when a new Islet version is available.", icon: "arrow.triangle.2.circlepath", iconColor: .secondary, isOn: $updateHudEnabled, isNew: true, onOptionsTap: nil)` inside `systemHUDCards` (`:170-206`), alongside the `capsLock`/`downloadProgress` entries. Also change Caps Lock's own entry's `onOptionsTap: nil` (`:197`) to `onOptionsTap: { showCapsLockPermissionExplanation = true }`, mirroring Focus's wiring exactly (`:184`, `onOptionsTap: { showFocusPermissionExplanation = true }`).

**`@State` toggle + popover-attachment analog** (verbatim, `:43,52` and `:398-403`):
```swift
@State private var showFocusPermissionExplanation = false
@State private var showOSDPermissionExplanation = false
...
categorySection(title: "System-HUDs", cards: systemHUDCards)
    .popover(isPresented: $showFocusPermissionExplanation) {
        focusPermissionExplanationView
    }
    .popover(isPresented: $showOSDPermissionExplanation) {
        osdPermissionExplanationView
    }
```
Add `@State private var showCapsLockPermissionExplanation = false` and a third `.popover(isPresented: $showCapsLockPermissionExplanation) { capsLockPermissionExplanationView }` chained onto the same `categorySection(title: "System-HUDs"...)` call. No popover is needed for the Update HUD card (no permission gate, per UI-SPEC "Options chevron: nil").

**`osdPermissionExplanationView` — the exact popover template to clone** (verbatim, `SettingsView.swift:684-708`):
```swift
private var osdPermissionExplanationView: some View {
    VStack(alignment: .leading, spacing: 8) {
        Text("Replace System OSD")
            .font(.system(size: 15, weight: .semibold))
        Text("Islet needs Accessibility access to hide the native volume/brightness indicator. Islet only intercepts volume and brightness key presses — it never reads, modifies, or sends anything else on your Mac.")
            .font(.system(size: 12))
            .lineSpacing(12 * 0.4)
        HStack {
            Button("Not Now") {
                showOSDPermissionExplanation = false
            }
            Spacer()
            Button("Open System Settings") {
                NSWorkspace.shared.open(URL(string:
                    "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                showOSDPermissionExplanation = false
            }
            .keyboardShortcut(.defaultAction)
        }
    }
    .padding(16)
    .frame(width: 280)
}
```
`capsLockPermissionExplanationView` clones this exactly (same `.padding(16)`, `.frame(width: 280)`, same deep-link URL string — same Accessibility permission bucket, per UI-SPEC's explicit "do not build a generic shared popover" instruction), swapping in Caps Lock's own copy (heading `"Caps Lock HUD"`, body per 60-UI-SPEC.md's Copywriting Contract, buttons `"Not Now"`/`"Open System Settings"` — identical action wiring, `showCapsLockPermissionExplanation = false` instead of the OSD flag).

**`handlePermissionTap`'s deep-link pattern** (verbatim, `:589-596`, for reference — NOT directly reused since Caps Lock's popover has its own inline `Open System Settings` button like OSD's, not routed through the generic `PermissionKind` switch):
```swift
case .denied:
    NSWorkspace.shared.open(URL(string:
        "x-apple.systempreferences:com.apple.preference.security?\(kind.deepLinkAnchor)")!)
```

---

### `Islet/AppDelegate.swift` — `didFindValidUpdate` (extend, controller/event-driven)

**Analog:** itself, current implementation (verbatim, `AppDelegate.swift:389-393`):
```swift
extension AppDelegate: SPUUpdaterDelegate {
    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        updateDotView?.isHidden = false
    }
}
```
Add a second signal call alongside the existing dot-unhide, per D-02/RESEARCH.md's Code Examples section:
```swift
func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
    updateDotView?.isHidden = false
    notchController?.handleUpdateAvailable(version: item.displayVersionString)
}
```
Do not touch `updateDotView` (`:13,106`) — it stays exactly as-is, unremoved (D-02).

---

### `IsletTests/IslandResolverTests.swift` (extend — test, unit)

**Analog:** `testFocusWinsWhenCollapsed`/`testFocusFallsThroughWhenExpanded` (`IslandResolverTests.swift:621-644`, verbatim) and `testOSDPreemptsStandingFocusHead` (`:697-707`, verbatim):
```swift
func testFocusWinsWhenCollapsed() {
    let r = resolve(activeTransient: .focus(.on),
                    nowPlaying: .none,
                    nowPlayingHealthy: true,
                    hasPlayedSinceLaunch: true,
                    isExpanded: false)
    XCTAssertEqual(r, .focus(.on))
}

func testFocusFallsThroughWhenExpanded() {
    let r = resolve(activeTransient: .focus(.on),
                    nowPlaying: .none,
                    nowPlayingHealthy: true,
                    hasPlayedSinceLaunch: false,
                    isExpanded: true,
                    selectedView: .home)
    XCTAssertEqual(r, .homeEmpty)
}

func testOSDPreemptsStandingFocusHead() {
    var q = TransientQueue()
    _ = q.enqueue(.focus(.on))
    XCTAssertTrue(q.preempt(.osd(.volume(percent: 50, hardwareMuted: false))))
    XCTAssertEqual(q.head, .osd(.volume(percent: 50, hardwareMuted: false)))
    XCTAssertTrue(q.advance())
    XCTAssertEqual(q.head, .focus(.on))
}
```
Add `testCapsLockCollapsedOnly`/`testCapsLockFallsThroughWhenExpanded`/`testUpdateAvailableCollapsedOnly`/`testUpdateAvailableFallsThroughWhenExpanded` following this exact shape (swap `.focus(.on)` for `.capsLock(...)`/`.updateAvailable(...)`), plus a `testCapsLock`/`testUpdateAvailablePreemptsStandingFocusHead` pair mirroring `testOSDPreemptsStandingFocusHead` verbatim with the new cases substituted in.

---

### `IsletTests/ActivitySettingsTests.swift` (extend — test, unit)

**Analog:** existing per-key default-value tests in the same file (same convention as `IslandResolverTests`'s naming pattern — file exists and already covers `capsLockKey`'s default per Phase 59; add equivalent coverage for `updateHudKey`'s default-false behavior, and — if `activityEnabled(_:)`'s Pitfall 1 fix is implemented as a `NotchWindowController`-level `defaultsToFalseKeys` set rather than purely in `ActivitySettings.swift` — a corresponding unit test asserting `updateHudKey`/`capsLockKey` both resolve to `false` when `UserDefaults.standard.object(forKey:)` returns `nil` (fresh install simulation).

---

## Shared Patterns

### Wing rendering (`wingsShape`)
**Source:** `Islet/Notch/NotchPillView.swift:2302-2348`
**Apply to:** `capsLockWings(for:)`, `updateWings(for:)` — both call through this one shared helper, never a new shape/`NotchShape` variant.
```swift
private func wingsShape<Content: View>(
    leftWidth: CGFloat = Self.wingsSize.width / 2,
    rightWidth: CGFloat = Self.wingsSize.width / 2,
    onTap: (() -> Void)? = nil,             // NEW this phase
    @ViewBuilder content: () -> Content
) -> some View {
    // ...unchanged body...
    .onTapGesture { (onTap ?? onClick)() }  // NEW this phase
}
```

### Transient priority/queueing (`TransientQueue`/`resolve()`/`IslandPresentation`/`ActiveTransient`)
**Source:** `Islet/Notch/IslandResolver.swift:93-132, 149-208, 319-387`
**Apply to:** both new activities — additive enum cases + resolver branches, zero new tier, zero renumbering of existing named ranks 1-4.

### Accessibility permission gate (`AXIsProcessTrusted`)
**Source:** `Islet/Notch/OSDInterceptor.swift:43-46, 102-106`
**Apply to:** `CapsLockMonitor` (gates event delivery) + `capsLockPermissionExplanationView`/Settings status-hint text (gates the UI affordance) — one permission bucket (Accessibility), reused verbatim, never a second differently-worded popover for the same TCC pane.

### Settings-popover pattern (permission explanation)
**Source:** `Islet/SettingsView.swift:684-708` (`osdPermissionExplanationView`)
**Apply to:** `capsLockPermissionExplanationView` (new, this phase) — same `.padding(16)`/`.frame(width: 280)` container, same "Not Now" / primary-action button pair, same deep-link URL pattern (`x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`).

### Controller-side enqueue/preempt branch
**Source:** `Islet/Notch/NotchWindowController.swift:2170-2195` (`handleOSDKeyPress`'s tail)
**Apply to:** `handleCapsLockChange`/`handleUpdateAvailable` — `if case .focus = transientQueue.head { preempt } else { enqueue }`, never preempting Charging/Device/OSD (they outrank both new activities and simply aren't touched).

### Default-OFF activity toggle bug fix
**Source:** `Islet/Notch/NotchWindowController.swift:673-676` (`activityEnabled(_:)`, currently broken for any key but `focusKey`)
**Apply to:** both `capsLockKey` and the new `updateHudKey` — must be fixed as part of this phase's task list (not deferred), since both need to default OFF per SETTINGS-05/CONTEXT.md's Phase Boundary.

## No Analog Found

None — every file this phase touches has at least a role-match analog already in the codebase (see RESEARCH.md's own "Don't Hand-Roll" table for confirmation that zero new architecture/dependencies are needed).

## Metadata

**Analog search scope:** `Islet/Notch/` (NotchPillView.swift, IslandResolver.swift, NotchWindowController.swift, OSDInterceptor.swift, PowerSourceMonitor.swift, BatteryIndicator.swift), `Islet/` (ActivitySettings.swift, SettingsView.swift, AppDelegate.swift), `IsletTests/` (IslandResolverTests.swift, ActivitySettingsTests.swift)
**Files scanned:** 11 source files + 2 test files (all read directly via grep + targeted offset/limit reads, no full-file loads over ~400 lines except where the file itself was ≤120 lines, e.g. `PowerSourceMonitor.swift`/`BatteryIndicator.swift`)
**Pattern extraction date:** 2026-07-23
