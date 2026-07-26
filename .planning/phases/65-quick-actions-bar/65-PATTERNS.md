# Phase 65: Quick Actions Bar - Pattern Map

**Mapped:** 2026-07-26
**Files analyzed:** 12 (8 action helpers + catalog + resolver/state/view wiring + Settings + tests)
**Analogs found:** 12 / 12

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|-----------------|----------------|
| `Islet/Notch/QuickActionsBar/DisplaySleepAction.swift` | utility (system action helper) | fire-and-forget process spawn | `Islet/Notch/MicMuteController.swift` | role-match (fragile-surface-per-file convention) |
| `Islet/Notch/QuickActionsBar/DarkModeToggleAction.swift` | utility (system action helper) | request-response (AppleScript + errorDict) | `Islet/Notch/NowPlayingMonitor.swift` (`spikeTriggerAutomationPrompt`, lines 112-124) | exact (AppleScript + errorDict pattern) |
| `Islet/Notch/QuickActionsBar/ScreenLockAction.swift` | utility (private-API system action) | fire-and-forget | `Islet/Notch/MicMuteController.swift` | role-match (private/fragile surface, guard-never-crash discipline) |
| `Islet/Notch/QuickActionsBar/FocusToggleAction.swift` | utility (best-effort action + read-back verification) | request-response with async callback | `Islet/Notch/FocusModeMonitor.swift` | exact (same `INFocusStatusCenter` surface, same isolation discipline) |
| `Islet/Notch/QuickActionsBar/CaffeinateToggleAction.swift` | utility (stateful IOKit toggle) | event-driven (assertion held/released) | `Islet/Notch/MicMuteController.swift` (toggle shape) | role-match |
| `Islet/Notch/QuickActionsBar/EmptyTrashAction.swift` | utility (system action helper) | request-response (AppleScript + errorDict) | `Islet/Notch/NowPlayingMonitor.swift` (lines 112-124) | exact |
| `Islet/Notch/QuickActionsBar/LaunchAction.swift` | utility (AppKit passthrough) | fire-and-forget | `Islet/SettingsView.swift` (`quickNotesVaultPickerView`, lines 770-798 — `NSOpenPanel` validated-URL discipline) | role-match |
| `Islet/Notch/QuickActionsBar/QuickActionCatalog.swift` | model/config (fixed enum catalog + AppStorage keys) | CRUD (config read/write) | `Islet/Notch/ViewSwitcherState.swift` (`SelectedView` enum + `orderedSlotIcons`) | exact |
| `Islet/Notch/IslandResolver.swift` (modified) | controller (pure reducer) | transform | itself — extend existing `resolve()`/`IslandPresentation` pattern (`.trayExpanded`/`.timerSetup` branches, lines 97-119, 222-229) | exact (in-place extension) |
| `Islet/Notch/ViewSwitcherState.swift` (modified) | model | CRUD | itself — extend `SelectedView` enum (lines 20-26) | exact (in-place extension) |
| `Islet/Notch/NotchPillView.swift` (modified — new `quickActionsBarContent` view + tap-pulse) | component | request-response (render + tap dispatch) | itself — `homeEmptyContent` (lines 1256-1290), `navCircleButton`/`chipButton` (lines 2330-2389), `switcherRow`/`icon(for:)` (lines 2514-2554) | exact (in-place extension) |
| `Islet/SettingsView.swift` (modified — flip `isComingSoon`, add popover + 8-slot pickers) | component (Settings config UI) | CRUD | itself — `slotOptions`/4-slot `Picker` (lines 482-507), `quickNotesVaultPickerView` (lines 770-798) | exact (in-place extension) |
| `IsletTests/IslandResolverTests.swift` (modified — new resolver cases) | test | transform (pure function assertions) | itself — `testTraySelectedExpandedReturnsTrayExpanded` (lines 320-331) | exact |
| `IsletTests/FocusToggleActionTests.swift` (new) | test | transform (before/after comparison) | `IsletTests/MicMuteControllerTests.swift` | role-match (pure-function testing shape for a system-adjacent helper) |

## Pattern Assignments

### `Islet/Notch/QuickActionsBar/ScreenLockAction.swift` / `DisplaySleepAction.swift` / `CaffeinateToggleAction.swift` (utility, system action)

**Analog:** `Islet/Notch/MicMuteController.swift` (81 lines, read in full)

**Header-comment convention** (lines 1-18):
```swift
import CoreAudio
import AudioToolbox

// Phase 63 Plan 01 / MEET-02 — the shared system-wide INPUT-mute primitive (D-02/D-04).
// Deliberately a near-literal sibling of VolumeReader.swift with the scope swapped from
// Output to Input, following this codebase's "one fragile system surface, one file"
// convention: ...
```
Every new action helper must open with an equivalent phase/decision-ID comment explaining WHY it is isolated to its own file (mirrors RESEARCH.md Pattern 1).

**Safe-default-on-guard-failure pattern** (lines 39-56, `readSystemInputMuted`):
```swift
func readSystemInputMuted() -> Bool {
    guard let deviceID = defaultInputDeviceID() else { return false }
    var muteAddr = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyMute,
        mScope: kAudioDevicePropertyScopeInput,
        mElement: kAudioObjectPropertyElementMain)
    guard AudioObjectHasProperty(deviceID, &muteAddr) else { return false }
    var muted: UInt32 = 0
    var mutedSize = UInt32(MemoryLayout<UInt32>.size)
    guard AudioObjectGetPropertyData(deviceID, &muteAddr, 0, nil, &mutedSize, &muted) == noErr
    else { return false }
    return muted == 1
}
```
Every guard failure returns a safe default — never crashes, never partially applies a write. `toggleSystemInputMute()` (lines 62-81) shows the "Set is the LAST step, reached only after every other guard passes" discipline — copy this exact shape for `ScreenLockAction.lockNow()`'s `dlopen`/`dlsym` guards and `CaffeinateToggleAction`'s `IOPMAssertionCreateWithName` result check.

**Enum-namespace static-func shape** (RESEARCH.md Code Examples, cross-referenced against this file's own top-level-function style): use `enum ScreenLockAction { static func lockNow() { ... } }` for one-shot actions (screen lock, display sleep, empty trash), a `final class`/small stateful `struct` only for CaffeinateToggleAction (needs to hold `assertionID`/`isActive` across calls, per RESEARCH.md Code Examples).

---

### `Islet/Notch/QuickActionsBar/DarkModeToggleAction.swift` / `EmptyTrashAction.swift` (utility, AppleScript request-response)

**Analog:** `Islet/Notch/NowPlayingMonitor.swift` lines 112-124 (`spikeTriggerAutomationPrompt`, the ONLY existing AppleScript+errorDict call site in this codebase)

**AppleScript + errorDict pattern** (lines 112-124):
```swift
func spikeTriggerAutomationPrompt() {
    let script = NSAppleScript(source: "tell application \"Music\" to get name of current track")
    var errorDict: NSDictionary?
    let result = script?.executeAndReturnError(&errorDict)
    if let errorDict {
        let number = errorDict[NSAppleScript.errorNumber] as? Int
        NSLog("SPIKE AppleScript error number=\(number ?? -1) dict=\(errorDict)")
        // -1743 (errAEEventNotPermitted) = TCC denial/never-prompted (Pitfall 3)
    } else {
        NSLog("SPIKE AppleScript succeeded: \(result?.stringValue ?? "nil")")
    }
}
```
Both new helpers MUST check `errorDict` explicitly (never assume success from the absence of a thrown Swift error — RESEARCH.md Pitfall 2). Concrete target shape (from RESEARCH.md Code Examples, cross-verified):
```swift
func toggleDarkMode(completion: @escaping (Bool) -> Void) {
    let script = NSAppleScript(source:
        "tell application \"System Events\" to tell appearance preferences to set dark mode to not dark mode")
    var errorDict: NSDictionary?
    script?.executeAndReturnError(&errorDict)
    completion(errorDict == nil)
}
```
Read-state helper for the icon swap: `NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua])` — pure AppKit read, no new pattern needed.

---

### `Islet/Notch/QuickActionsBar/FocusToggleAction.swift` (utility, best-effort + read-back verification — QACTION-03)

**Analog:** `Islet/Notch/FocusModeMonitor.swift` (97 lines, read in full)

**Authorization entry points to reuse verbatim** (lines 69-81):
```swift
static var isAuthorized: Bool {
    INFocusStatusCenter.default.authorizationStatus == .authorized
}

static func requestAuthorization(completion: @escaping (Bool) -> Void) {
    INFocusStatusCenter.default.requestAuthorization { status in
        completion(status == .authorized)
    }
}
```
`FocusToggleAction` MUST call `FocusModeMonitor.isAuthorized` — never duplicate authorization-request logic (Research Pitfall 4; UI-SPEC Verification Notes). Do NOT gate on `ActivitySettings.focusKey` — that is Phase 38's unrelated HUD toggle; Quick Actions must gate on `ActivitySettings.quickActionsKey` only.

**Silent-degrade / no-onChange-on-untrusted-read convention** (lines 56-63):
```swift
private func poll() {
    guard INFocusStatusCenter.default.authorizationStatus == .authorized else { return }
    guard let isFocused = INFocusStatusCenter.default.focusStatus.isFocused else { return }
    onChange(isFocused)
}
```
Mirror this "untrusted read = no-op, never assume a state" discipline in the read-back comparison.

**Read-back verification target shape** (RESEARCH.md Pattern 2, builds directly on the above):
```swift
enum FocusToggleAction {
    static func toggle(shortcutName: String, onResult: @escaping (Bool) -> Void) {
        guard FocusModeMonitor.isAuthorized else { onResult(false); return }
        let before = INFocusStatusCenter.default.focusStatus.isFocused ?? false
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        task.arguments = ["run", shortcutName]
        do { try task.run() } catch { onResult(false); return }
        task.terminationHandler = { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let after = INFocusStatusCenter.default.focusStatus.isFocused ?? before
                onResult(after != before)
            }
        }
    }
}
```

---

### `Islet/Notch/QuickActionsBar/LaunchAction.swift` (utility, AppKit passthrough + config validation)

**Analog:** `Islet/SettingsView.swift` lines 766-798 (`quickNotesVaultPickerView`)

**Validated-URL-only discipline** (lines 769, 778-788):
```swift
// ... the stored path only
// ever comes from NSOpenPanel's own return value (T-64-07) — never user-typed text.
private var quickNotesVaultPickerView: some View {
    ...
    Button("Choose Folder…") {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        panel.message = "Choose your Obsidian vault folder"
        if panel.runModal() == .OK, let url = panel.url {
            quickNotesVaultFolderPath = url.path
        }
    }
    ...
}
```
Apply the same discipline to each independent launch slot's config UI (`NSOpenPanel(allowedContentTypes: [.application])` for app targets; a validated `URL(string:)` for URL targets) — never pass raw typed text into `NSWorkspace.shared.open` or any shell/AppleScript string (UI-SPEC Verification Notes; RESEARCH.md Security Domain V5).

---

### `Islet/Notch/QuickActionsBar/QuickActionCatalog.swift` (model, fixed catalog + per-slot config)

**Analog:** `Islet/Notch/ViewSwitcherState.swift` (41 lines, read in full)

**Fixed enum + CaseIterable/AppStorage-compatible shape** (lines 20-26):
```swift
enum SelectedView: String, Equatable, Hashable, CaseIterable {
    case home
    case tray
    case calendar
    case weather
    case timer
}
```

**One-shared-ordering-projection pattern** (lines 32-37):
```swift
func orderedSlotIcons(leftOuter: SelectedView,
                      leftInner: SelectedView,
                      rightInner: SelectedView,
                      rightOuter: SelectedView) -> [SelectedView] {
    [leftOuter, leftInner, rightInner, rightOuter]
}
```
`QuickActionCatalog` needs the SAME shape but for 8 slots: a `String`/`CaseIterable` catalog enum (mic, displaySleep, darkMode, screenLock, dnd, caffeinate, emptyTrash, launch — with launch slots needing an associated config value, unlike `SelectedView`'s bare cases) plus 8 independent `@AppStorage` keys (never a single encoded array — mirrors `ActivitySettings`'s `switcherSlot*Key` convention, one key per position, see `ActivitySettings.swift` lines 100-106) and an `orderedQuickActionSlots(...)` projection function mirroring `orderedSlotIcons` exactly.

**Naming constraint (critical):** every new type must be prefixed `QuickActionsBar*`, never bare `QuickAction*` — `IslandResolver.swift` already has an UNRELATED `case quickActionPicker(PendingDrop)` (Phase 34 drag-drop) at line 119, and `Islet/Notch/QuickActionSharingService.swift` exists. Confirmed via `IslandResolver.swift`'s own line 119 during this pattern-mapping pass.

---

### `Islet/Notch/IslandResolver.swift` (modified — new presentation case + resolve() branch)

**Analog:** itself — the `.trayExpanded`/`.timerSetup` precedent (same file, same tier)

**Presentation case declaration convention** (lines 97-119, e.g. line 117):
```swift
case trayExpanded                                      // 28-04 round 5: dedicated files-only Tray view
```
Add `case quickActionsBarExpanded` with an equivalent trailing rank-comment, placed per the Resolver-Priority Reference Table (lines 58-92) — this is exactly the reserved "Quick Actions bar (Phase 65) — relationship unclear... rank TBD" line at line 90, which D-01 resolves as: same tier as Calendar/Weather/Tray (isExpanded branch, `selectedView`-driven), NOT ActiveTransient, NOT a fixed always-shown case.

**resolve() branch pattern** (lines 222-229):
```swift
if selectedView == .calendar { return .calendarExpanded }
if selectedView == .weather { return .weatherExpanded }
if selectedView == .tray { return .trayExpanded }
if selectedView == .timer { return .timerSetup }
```
Add `if selectedView == .quickActions { return .quickActionsBarExpanded }` in this same ordered `if`-chain (before the Home fallback, after pendingDrop). **Do NOT** add a new `ActiveTransient` case and **do NOT** special-case it above the `switch activeTransient` block — Research Pitfall 5 explicitly warns against copying Timer's fixed-5th-tab precedent instead of Tray's per-slot-catalog precedent.

**showsSwitcherRow(for:) update** (lines 169-174):
```swift
func showsSwitcherRow(for presentation: IslandPresentation) -> Bool {
    switch presentation {
    case .homeLastPlayed, .homeEmpty, .calendarExpanded, .weatherExpanded, .trayExpanded, .nowPlayingExpanded, .timerSetup: return true
    default: return false
    }
}
```
Add `.quickActionsBarExpanded` to this case list — the bar is one of the switcher-tab presentations (D-01), so it must show the switcher row like every sibling.

---

### `Islet/Notch/ViewSwitcherState.swift` (modified — new `SelectedView` case)

**Analog:** itself, lines 20-26 (see catalog section above) — add `case quickActions` to the enum. Per Research Pitfall 5, this case joins `slotOptions`' explicit 4-line list in `SettingsView.swift` (becoming 5 lines) — it must NOT be added to `orderedSlotIcons`'s fixed-4-param signature (that stays untouched; Timer's `.timer` case is the wrong precedent to copy here, it is NOT in `orderedSlotIcons` either, for the same reason).

---

### `Islet/Notch/NotchPillView.swift` (modified — new `quickActionsBarContent` view + tap-pulse + tabHeight/tabWidth branch)

**Analog:** itself — `homeEmptyContent` (lines 1256-1290) for the empty-state layout shape, `navCircleButton`/`chipButton` (lines 2330-2389) for the tile button primitive, `icon(for:)`/`switcherRow` (lines 2514-2554) for the ForEach-over-slots + tap-dispatch wiring.

**Empty-state pattern** (lines 1256-1290):
```swift
private var homeEmptyContent: some View {
    VStack(spacing: 4) {
        Image(systemName: "music.note")
            .font(.system(size: 28))
            .foregroundStyle(.white.opacity(0.4))
        Text("Nothing Playing")
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
        Text("Start something in Spotify or Music.")
            .font(.system(size: 11, weight: .regular, design: .rounded))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
    }
    .padding(.top, Self.cameraClearance)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
}
```
UI-SPEC's "No Actions Configured" empty state (icon `bolt.horizontal.fill`, 28px, `.white.opacity(0.4)`) copies this exact icon/heading/body/`cameraClearance` structure.

**Tile button primitive** (lines 2330-2343):
```swift
private static let navCircleDiameter: CGFloat = 36

private func navCircleButton(systemName: String, filled: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Image(systemName: systemName)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(filled ? Color.black : Color.white)
            .frame(width: Self.navCircleDiameter, height: Self.navCircleDiameter)
            .background(Circle().fill(filled ? Color.white : Color.clear))
            .overlay(Circle().strokeBorder(Color.white.opacity(filled ? 0 : 0.4), lineWidth: 1.5))
            .contentShape(Circle())
    }
    .buttonStyle(.plain)
}
```
UI-SPEC locks the 8 action tiles as `navCircleButton`-style 36pt circles — reuse `navCircleButton` directly rather than a new primitive; add the D-04 tap-pulse (`scaleEffect` 1.0→1.15→1.0, spring response 0.15/damping 0.86, matching Phase 39-08's OSD level-bar retune) as a `.scaleEffect`/opacity-overlay modifier layered onto the existing button, not a new button type.

**ForEach-over-slots + shared icon-mapping pattern** (lines 2514-2554):
```swift
private func icon(for view: SelectedView) -> (systemName: String, action: () -> Void) {
    switch view {
    case .home:     return ("house.fill",     { onSwitcherSelect(.home) })
    ...
    }
}

private var switcherRow: some View {
    HStack(spacing: 8) {
        ForEach(orderedSlotViews, id: \.self) { view in
            let mapping = icon(for: view)
            navCircleButton(systemName: mapping.systemName,
                             filled: viewSwitcherState.selectedView == view,
                             action: mapping.action)
        }
    }
    .frame(height: Self.switcherRowHeight)
}
```
`quickActionsBarContent` needs an equivalent `icon(for:)`-shaped mapping (`QuickActionCatalog.Action -> (systemName, action)`) and a `ForEach` over the up-to-8 configured slots — but as a 2-row × 4-column grid (per UI-SPEC), not a single HStack, and with `Spacer()`-distributed columns (not a fixed gap) so 1-8 configured tiles stay centered — UI-SPEC explicitly forbids empty placeholder tiles.

**tabHeight/tabWidth branch to extend** (lines 94-120):
```swift
var tabWidth: CGFloat {
    switch presentation {
    case .calendarExpanded: return Self.calendarWidth
    case .trayExpanded: return Self.traySize.width
    default: return Self.expandedSize.width
    }
}
var tabHeight: CGFloat {
    switch presentation {
    case .calendarExpanded: return Self.calendarContentHeight
    case .trayExpanded: return Self.trayContentHeight
    case .weatherExpanded: return weatherStyle == .large ? Self.weatherLargeContentHeight : Self.weatherMediumContentHeight
    case .timerSetup: return timerSetupMode == .countdown ? Self.calendarContentHeight : Self.timerSetupContentHeight
    default: return Self.homeContentHeight + ...
    }
}
```
Add `case .quickActionsBarExpanded: return Self.quickActionsContentHeight` to `tabHeight` (new constant, starting value 150pt per UI-SPEC) — `tabWidth` falls through to `default: return Self.expandedSize.width` unchanged (no structural resize, per D-01/UI-SPEC).

**tabContentView switch to extend** (lines 1068-1094): add `case .quickActionsBarExpanded: quickActionsBarContent` alongside the existing `.homeEmpty`/`.calendarExpanded`/`.weatherExpanded`/`.trayExpanded`/`.timerSetup` arms.

---

### `Islet/SettingsView.swift` (modified — flip `isComingSoon`, wire popover + 8 pickers)

**Analog:** itself — `productivityCards` entry (lines 254-258) + `slotOptions`/4-slot-Picker pattern (lines 482-507) + `quickNotesVaultPickerView` popover shape (lines 766-798)

**Existing card entry to flip** (lines 254-258):
```swift
ActivityCardData(id: "quickActions", title: "Quick Actions",
                  description: "A row of one-tap system actions — mute mic, lock screen, and more.",
                  icon: "bolt.horizontal.fill", iconColor: .secondary,
                  isOn: $quickActionsEnabled, isNew: false, onOptionsTap: nil,
                  isComingSoon: true),
```
Change `isComingSoon: true` → `false` and `onOptionsTap: nil` → `{ showQuickActionsPopover = true }`, mirroring the `quickNotes` entry's `onOptionsTap` (line 253) exactly — no other field changes.

**4-slot dropdown pattern to extend to 8** (lines 482-507):
```swift
Section("Icon Placement") {
    Picker("Left Outer", selection: $slotLeftOuter) { slotOptions }
        .pickerStyle(.menu)
    ...
}
...
@ViewBuilder private var slotOptions: some View {
    Label("Home", systemImage: "house.fill").tag(SelectedView.home)
    Label("Tray", systemImage: "tray.fill").tag(SelectedView.tray)
    Label("Calendar", systemImage: "calendar").tag(SelectedView.calendar)
    Label("Weather", systemImage: "cloud.sun.fill").tag(SelectedView.weather)
}
```
Two distinct dropdown catalogs needed: (1) add ONE `Label("Quick Actions", systemImage: "bolt.horizontal.fill").tag(SelectedView.quickActions)` line to `slotOptions` (5th line, per D-01), and (2) build a NEW `quickActionSlotOptions`-shaped `@ViewBuilder` (8-entry catalog: mic/displaySleep/darkMode/screenLock/dnd/caffeinate/emptyTrash/launch + "None") for the bar's OWN 8 internal `Picker`s inside the new popover (per D-02) — same `Picker(..., selection:) { ... }.pickerStyle(.menu)` mechanism, not a new component.

**Popover shape to clone** (lines 766-798, `quickNotesVaultPickerView`): title (15pt semibold) → content rows → `HStack { action-button; Spacer(); Button("Done") }`, `.padding(16).frame(width: 280)`. The new "Configure Quick Actions" popover needs a taller frame (8 pickers) but the same title/body/Done-button skeleton — widen `.frame(width:)` as needed, keep the 16pt padding.

---

## Shared Patterns

### AppleScript + errorDict error checking
**Source:** `Islet/Notch/NowPlayingMonitor.swift` lines 112-124
**Apply to:** `DarkModeToggleAction.swift`, `EmptyTrashAction.swift`
```swift
var errorDict: NSDictionary?
script?.executeAndReturnError(&errorDict)
completion(errorDict == nil)   // never assume success from "didn't throw"
```

### One-fragile-surface-per-file isolation
**Source:** `Islet/Notch/MicMuteController.swift` (whole-file convention), `Islet/Notch/FocusModeMonitor.swift` (whole-file convention)
**Apply to:** every file under `Islet/Notch/QuickActionsBar/` — each of the 8 action mechanisms gets its own file, never a shared "SystemActions" god-file (RESEARCH.md Pattern 1, Anti-Patterns).

### Safe-default-on-guard-failure, never partially apply
**Source:** `Islet/Notch/MicMuteController.swift` lines 39-81 (`readSystemInputMuted`/`toggleSystemInputMute`)
**Apply to:** `ScreenLockAction`, `CaffeinateToggleAction` — every guard failure returns a safe default (`nil`/`false`) without ever issuing the write; the Set/write call is always the LAST step, only reached once every other guard has already passed.

### Fixed-catalog + per-slot AppStorage dropdown (never drag-reorder)
**Source:** `Islet/Notch/ViewSwitcherState.swift` (`SelectedView`, `orderedSlotIcons`) + `Islet/SettingsView.swift` lines 482-507 (`slotOptions`)
**Apply to:** `QuickActionCatalog.swift`, `SettingsView.swift`'s new 8-slot popover — one independent `@AppStorage` key per position, a `Label(...).tag(...)` catalog list feeding a `Picker(..., selection:).pickerStyle(.menu)`, and a single `orderedX(...)` projection function turning N independent slot values into one ordered array.

### Validated-URL-only config input (never raw typed text into a shell/AppleScript string)
**Source:** `Islet/SettingsView.swift` lines 766-798 (`quickNotesVaultPickerView`, T-64-07 discipline)
**Apply to:** `LaunchAction.swift`'s config UI — `NSOpenPanel`'s own return value or a validated `URL(string:)`, never string-interpolated user text (RESEARCH.md Security Domain, UI-SPEC Verification Notes).

### Pure-reducer resolver extension (one ordered if-chain, no scattered precedence)
**Source:** `Islet/Notch/IslandResolver.swift` lines 209-240 (`resolve()`'s `isExpanded` branch)
**Apply to:** the new `.quickActions` branch — inserted into the SAME ordered if-chain as Calendar/Weather/Tray/Timer, never a second precedence mechanism.

## No Analog Found

None — every file this phase touches has a strong existing analog in this codebase (RESEARCH.md's own finding: "almost nothing in this phase is a genuinely new UI mechanism").

## Metadata

**Analog search scope:** `Islet/Notch/` (MicMuteController.swift, FocusModeMonitor.swift, NowPlayingMonitor.swift, IslandResolver.swift, ViewSwitcherState.swift, NotchPillView.swift), `Islet/` (SettingsView.swift, ActivitySettings.swift, ActivityCard.swift), `IsletTests/` (MicMuteControllerTests.swift, IslandResolverTests.swift)
**Files scanned:** 9 source files read in full or via targeted non-overlapping ranges, 2 test files
**Pattern extraction date:** 2026-07-26
