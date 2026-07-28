# Phase 66: Menübar-Overflow (Spacer-Technique MVP) - Pattern Map

**Mapped:** 2026-07-27
**Files analyzed:** 5 (2 new production files, 1 new test file, 2 existing files needing edits)
**Analogs found:** 5 / 5

**Mechanism note:** This is a from-scratch pattern map for the public-API spacer-`NSStatusItem` technique (Hidden Bar reference). It supersedes and does NOT reuse anything from the deleted Ice-mechanism 66-PATTERNS.md — `MenuBarOverflowBridging.swift`'s CGS shim and `CapsLockMonitor`'s Accessibility health-check pattern are explicitly not analogs for this version.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|-----------------|----------------|
| `Islet/Notch/MenuBarOverflowController.swift` (new) | controller/manager (owns 2 `NSStatusItem`s, click handling, screen-notification observer, UserDefaults persistence) | event-driven | `Islet/Notch/MeetingMonitor.swift` (class shape, observer lifecycle) + `Islet/AppDelegate.swift:107-134` (status item construction) | role-match (composite: no single existing file owns 2 status items + a click toggle + a screen observer, so this is assembled from 3 partial analogs) |
| `Islet/AppDelegate.swift` (modified — construction call site) | controller (integration point only) | request-response (one-time setup call) | `Islet/AppDelegate.swift:107-134` (`statusItem` construction) and `:489-519` (`debugStatusItem`, proof multiple simultaneous status items already coexist) | exact (same file, same established multi-status-item pattern) |
| `Islet/ActivitySettings.swift` (modified — remove/adjust `menuBarOverflowKey`) | config | CRUD (UserDefaults key registry) | `Islet/ActivitySettings.swift:37,65` (existing `menuBarOverflowKey` + its membership in `defaultsToFalseKeys`) | exact — this is the file itself, see "Stale Artifact" note below |
| `Islet/SettingsView.swift` (modified — remove toggle) | component (SwiftUI) | request-response | `Islet/SettingsView.swift:74,246` (`menuBarOverflowEnabled` `@AppStorage` + its settings-card row) | exact — this is the file itself, see "Stale Artifact" note below |
| `IsletTests/MenuBarOverflowClampTests.swift` (new, pure-function test — Wave 0 gap from RESEARCH.md) | test | transform | `IsletTests/DisplayResolverTests.swift` + `Islet/Notch/DisplayResolver.swift` (pure-function-extracted-for-testability shape) | role-match |

## Pattern Assignments

### `Islet/Notch/MenuBarOverflowController.swift` (new controller, event-driven)

No single existing file is a full analog — assemble from three precedents, all read directly from this codebase.

**Status-item construction pattern** — analog `Islet/AppDelegate.swift:107-134`:
```swift
// Islet/AppDelegate.swift:107-115
statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

if let button = statusItem.button {
    // A monochrome SF Symbol used as a TEMPLATE image: macOS auto-tints
    // it for light/dark menu bars (the `isTemplate = true` line is the key).
    let image = NSImage(systemSymbolName: "capsule.fill",
                        accessibilityDescription: "Islet")
    image?.isTemplate = true        // template image = the key line
    button.image = image
}
```
Apply this shape twice: once for the chevron (`NSImage(systemSymbolName: "chevron.left"/"chevron.right", accessibilityDescription: ...)`, per 66-UI-SPEC.md's two-state contract), once for the spacer (`NSStatusBar.system.statusItem(withLength: 1)`, no image/title per UI-SPEC's "invisible, non-interactive" contract). `AppDelegate.swift:489-519` (`debugStatusItem`) is direct proof this codebase already runs multiple simultaneous `NSStatusItem` instances without conflict — cite this as precedent, no new risk.

**Class shape / observer lifecycle pattern** — analog `Islet/Notch/MeetingMonitor.swift`:
```swift
// Islet/Notch/MeetingMonitor.swift:28-41
final class MeetingMonitor {
    private nonisolated(unsafe) var running = false
    private nonisolated(unsafe) var pollTimer: Timer?
    private nonisolated(unsafe) var workspaceObservers: [NSObjectProtocol] = []
    ...
    init(targetBundleIDs: Set<String> = [...], ...)
    func start() { ... }
    nonisolated func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
        let wc = NSWorkspace.shared.notificationCenter
        workspaceObservers.forEach { wc.removeObserver($0) }
        ...
    }
}
```
Mirror: a `final class MenuBarOverflowController` with `init()`/`start()` constructed from `AppDelegate`, an `[NSObjectProtocol]` observer array, and a `stop()`/`deinit` that removes every registered observer — same discipline this codebase already applies uniformly (MeetingMonitor, CapsLockMonitor, AudioOutputMonitor all follow this token-storage-and-teardown shape). Do NOT copy MeetingMonitor's CoreAudio/mic-specific body, its `pollTimer` 5s-poll fallback, or its NSWorkspace launch/terminate observers — RESEARCH.md's Don't Hand-Roll section explicitly says this mechanism needs none of that; only the class/observer-lifecycle skeleton is the reusable part.

**Screen-parameter-driven re-clamp pattern** — analog `Islet/Notch/NotchWindowController.swift:601-611`:
```swift
// Islet/Notch/NotchWindowController.swift:601-611
observer = NotificationCenter.default.addObserver(
    forName: NSApplication.didChangeScreenParametersNotification,
    object: nil, queue: .main
) { [weak self] _ in
    // Pitfall 6: this can fire several times / mid-transition. Hop to the next
    // main-loop turn so NSScreen.screens has fully settled; the routine is
    // idempotent so extra calls are harmless.
    DispatchQueue.main.async { self?.updateVisibility() }
}
```
Apply verbatim shape, substituting `updateVisibility()` with a `recomputeSpacerExpandedLength()` call (RESEARCH.md Pattern 3/Pitfall 4 — recompute the expanded-length screen-width clamp on every screen-parameter change, never capture once at launch).

**`autosaveName` persistence pattern** — no in-codebase analog (new public-API surface for this project); use RESEARCH.md Pattern 2 / 66-UI-SPEC.md's exact hardcoded strings directly:
```swift
chevronItem.autosaveName = "IsletMenuBarOverflowChevron"
spacerItem.autosaveName = "IsletMenuBarOverflowSpacer"
```

**UserDefaults small-bool-state persistence pattern** — analog `Islet/ActivitySettings.swift` key-registry convention:
```swift
// Islet/ActivitySettings.swift:37 (existing, to be repurposed/removed — see Stale Artifact note)
static let menuBarOverflowKey = "activity.menuBarOverflow"
```
Do NOT reuse `menuBarOverflowKey` as-is for D-05's "is the hidden section expanded/collapsed" bool — that key is currently wired as an Activities on/off `@AppStorage` toggle in `SettingsView.swift:74/246`, and D-02 explicitly forbids any Settings on/off toggle for this feature. Add a new, distinctly-named key (e.g. `menuBarOverflowRevealedKey`) following the exact same `static let ... = "..."` declaration shape at the same file/location, but do NOT add it to `defaultsToFalseKeys` (that set drives the Activities-toggle default-OFF convention `SettingsView.swift` reads from — not applicable, since this key isn't a toggle).

**Click-handling pattern** — analog `Islet/AppDelegate.swift:299-308` (`applyMenuBarClickRouting`):
```swift
// Islet/AppDelegate.swift:299-308
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
Shows this codebase's convention for `button.target`/`button.action` wiring (no `NSMenu` attached) — apply the same `target`/`action` assignment for the chevron's click (`#selector(toggleReveal)`), with `statusItem.menu = nil` always (66-UI-SPEC.md: "No `NSMenu` attached... clicking the chevron never opens a dropdown/popover").

---

### `Islet/AppDelegate.swift` (modified, integration point)

**Construction call-site pattern** (lines 107, 490 — where to add the new controller's instantiation):
```swift
// Islet/AppDelegate.swift:107 and :490 — both follow "create right after
// trial/settings migration, before controller.start()" ordering
statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
...
debugStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
```
Per D-02 ("activates automatically on app launch, no toggle/permission gate to wait on"), construct and `start()` the new `MenuBarOverflowController` unconditionally in `applicationDidFinishLaunching`, alongside (not gated behind) the existing `statusItem` setup — no `if enabled` branch, unlike the Phase-59-era `ActivitySettings` toggle convention other v1.10 activities use.

---

### `Islet/ActivitySettings.swift` (modified — stale artifact cleanup)

**Existing stale wiring found** (pre-dates this session's mechanism pivot, likely a Phase-59 SETTINGS-05 placeholder for the original permission-gated design):
```swift
// Islet/ActivitySettings.swift:37
static let menuBarOverflowKey = "activity.menuBarOverflow"
// Islet/ActivitySettings.swift:65 (membership in the default-OFF toggle set)
focusKey, osdSuppressionKey, capsLockKey, downloadProgressKey, menuBarOverflowKey, ...
```
This key currently drives a real Settings-card toggle (`SettingsView.swift:74,246`, `isOn: $menuBarOverflowEnabled`). D-02 requires this feature to have **no** Settings on/off toggle at all — flag this as a required cleanup for the planner: either delete `menuBarOverflowKey` and its `SettingsView.swift` card entirely, or (Claude's Discretion territory) repurpose the constant name for the new D-05 UI-state key if the planner prefers one fewer new key — but the existing **on/off toggle semantics and its settings-card row must not survive** into this phase's plans as-is.

---

### `Islet/SettingsView.swift` (modified — stale artifact cleanup)

```swift
// Islet/SettingsView.swift:74
@AppStorage(ActivitySettings.menuBarOverflowKey) private var menuBarOverflowEnabled = false
// Islet/SettingsView.swift:246
isOn: $menuBarOverflowEnabled, isNew: false, onOptionsTap: nil,
```
Same stale-artifact note as above — this settings-card row and its binding must be removed as part of this phase's plans (D-02/D-04 supersede whatever phase originally scaffolded this row).

---

### `IsletTests/MenuBarOverflowClampTests.swift` (new, pure-function test)

**Analog:** `IsletTests/DisplayResolverTests.swift` + `Islet/Notch/DisplayResolver.swift` — this codebase's established "extract the pure decision function, test it with hand-built inputs, no live AppKit objects" pattern:
```swift
// Islet/Notch/DisplayResolver.swift:33-40 — pure function, no NSScreen dependency
func selectTargetScreen(from screens: [ScreenDescriptor]) -> ScreenDescriptor? {
    screens.first { $0.isBuiltin && $0.hasNotch }
}
```
Apply the same shape to RESEARCH.md's Wave-0-gap ask: extract the spacer's expanded-length clamp math as a standalone pure function (e.g. `func clampedExpandedLength(candidate: CGFloat, screenWidth: CGFloat) -> CGFloat`, `min`/`max`-shaped per RESEARCH.md's "Wave 0 Gaps" line), then test it with hand-built `CGFloat` inputs — no live `NSScreen`/`NSStatusItem` needed, mirroring `DisplayResolverTests.swift`'s test-with-a-struct-you-construct-by-hand convention rather than `MicMuteControllerTests.swift`'s real-hardware-required style (not applicable here — there's no hardware dependency for pure geometry math).

---

## Shared Patterns

### Multi-status-item coexistence
**Source:** `Islet/AppDelegate.swift:107` (`statusItem`) and `:490` (`debugStatusItem`)
**Apply to:** `MenuBarOverflowController.swift`'s chevron + spacer construction
No structural conflict exists in this codebase for running 2+ simultaneous `NSStatusItem`s — already proven with 2 (3 once this phase's 2 more are added, all coexisting).

### Observer-token lifecycle (register in `start()`, remove in `stop()`/`deinit`)
**Source:** `Islet/Notch/MeetingMonitor.swift:40-41` (`pollTimer`, `workspaceObservers` stored, both torn down in `nonisolated func stop()`)
**Apply to:** `MenuBarOverflowController`'s `NSApplication.didChangeScreenParametersNotification` observer
Store the observer token, remove it in a `nonisolated func stop()`/`deinit` pair — this project's uniform convention across `MeetingMonitor`, `CapsLockMonitor`, `NotchWindowController` (`observer`, `spaceObserver`, `appActivateObserver` at `NotchWindowController.swift:603-627`).

### `UserDefaults` key registry
**Source:** `Islet/ActivitySettings.swift` (all `static let ...Key = "..."` declarations, e.g. lines 15-117)
**Apply to:** The new D-05 reveal/collapse UI-state bool
Add the new key as a `static let` in `ActivitySettings.swift` next to the existing (soon-to-be-removed) `menuBarOverflowKey`, following the exact naming convention (`"activity.<name>"`-style dotted string) already used throughout the file.

### Template-image SF Symbol icon rendering
**Source:** `Islet/AppDelegate.swift:112-114`
**Apply to:** The chevron's two-state icon (`chevron.left`/`chevron.right`, per 66-UI-SPEC.md)
```swift
let image = NSImage(systemSymbolName: "capsule.fill", accessibilityDescription: "Islet")
image?.isTemplate = true
```
No `NSImage.SymbolConfiguration` override — 66-UI-SPEC.md mandates matching this exact precedent (no custom point size/weight).

## No Analog Found

None — every file in scope has at least a role-match analog assembled above. The composite nature of `MenuBarOverflowController.swift` (no single existing file owns "2 status items + click toggle + screen observer + autosaveName") is noted above under its own entry rather than listed here, since 3 strong partial analogs together cover it fully.

## Superseded Files (do not use as analogs, D-06 discretion — delete or repurpose)

| File | Status | Note |
|------|--------|------|
| `Islet/Notch/MenuBarOverflowBridging.swift` | Superseded (old Ice private-CGS shim) | Not read for pattern extraction per orchestrator instruction — do not port any part of it |
| `IsletTests/MenuBarOverflowManualSpike.swift` | Superseded (old Ice-mechanism spike test) | Not read for pattern extraction per orchestrator instruction — do not extend it; write a fresh test file instead |

Planner/executor: D-06 leaves deletion-vs-repurposing of these two files to Claude's discretion — this pattern map takes no position on which, only that neither should be used as a code source for the new mechanism.

## Metadata

**Analog search scope:** `Islet/AppDelegate.swift`, `Islet/Notch/*.swift`, `Islet/ActivitySettings.swift`, `Islet/SettingsView.swift`, `IsletTests/*.swift`
**Files scanned:** ~120 (directory listing) + 7 read in full/targeted (`AppDelegate.swift` partial, `MeetingMonitor.swift` partial, `MicMuteController.swift` full, `MicMuteControllerTests.swift` full, `NotchWindowController.swift` partial, `ActivitySettings.swift` grep + partial, `SettingsView.swift` grep + partial, `DisplayResolver.swift` full)
**Pattern extraction date:** 2026-07-27
