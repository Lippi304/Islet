# Phase 66: Menübar-Overflow (Ice-Style MVP) - Pattern Map

**Mapped:** 2026-07-27
**Files analyzed:** 6 new/modified files (3 new manager-tier files, 1 new spike test, 2 modified integration points)
**Analogs found:** 6 / 6 (one file — `MenuBarOverflowBridging.swift` — has no in-codebase analog; external analog only, Ice's own `Bridging.swift`)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|--------------------|------|-----------|-----------------|----------------|
| `Islet/Notch/MenuBarOverflowBridging.swift` (new) | utility (private-API symbol shim) | none (pure C-symbol declarations, no data flow) | none in-codebase — external analog: `github.com/jordanbaird/Ice`'s `Ice/Bridging/Shims/Private.swift` | no in-codebase analog (genuinely novel per RESEARCH.md) |
| `Islet/Notch/MenuBarOverflowController.swift` (new) | controller (isolated manager, "one fragile surface, one file") | event-driven (health-check timer + `NSWorkspace` launch/terminate notifications + click handler) | `Islet/Notch/CapsLockMonitor.swift` (permission-gate + health-check shape) and `Islet/Notch/MeetingMonitor.swift` (`NSWorkspace.didLaunchApplicationNotification`/`didTerminateApplicationNotification` re-evaluation loop) | role-match (two analogs combined — no single file covers both the permission gate AND the relaunch-reapplication concern) |
| `Islet/Notch/MenuBarOverflowStore.swift` (new) | model (UserDefaults-backed keyed store) | CRUD (bundle-ID → hidden/visible read/write) | `Islet/ActivitySettings.swift` (`@AppStorage`/`UserDefaults` key-namespace convention) | role-match (namespace convention only — `ActivitySettings` uses fixed keys, this store needs arbitrary bundle-ID keys, so it is closer to a small standalone `UserDefaults` dictionary wrapper than a literal `ActivitySettings` extension) |
| `Islet/AppDelegate.swift` (modified — new chevron `NSStatusItem` + controller ownership) | component (status-item construction + menu-bar-only controller lifecycle owner) | request-response (button click → toggle reveal/hide) | itself — `statusItem` construction (lines 107-134) and `debugStatusItem` construction (lines 490-491); `quickNotesController` ownership shape (line 35) for the "menu-bar-only controller lives on AppDelegate, not NotchWindowController" precedent | exact (in-place extension, two combined precedents) |
| `Islet/SettingsView.swift` (modified — new permission-status card + resolve existing placeholder conflict) | component (Settings permission-status card) | request-response (render status + deep-link button tap) | itself — `osdPermissionExplanationView`/`capsLockPermissionExplanationView` (lines 744-798) for the card shape; `permissionRow`/`statusView(for:)` (lines 606-642) for the granted/denied glyph-and-color convention | exact (in-place extension) — **plus a required conflict resolution**, see below |
| `IsletTests/MenuBarOverflowManualSpike.swift` (new) | test (manual on-device spike, Wave 0) | none (human-observed console output, always-green assertion) | `IsletTests/MeetingMonitorManualSpike.swift` (48 lines, read in full) | exact (near-verbatim structural clone) |

## Pre-existing State This Phase Must Reconcile (found during mapping, not yet reflected in CONTEXT/RESEARCH)

**`ActivitySettings.menuBarOverflowKey` and a bound `@AppStorage` toggle already exist and are wired into the Activities grid as a disabled placeholder — this conflicts with D-02 ("no separate Settings on/off toggle").**

- `Islet/ActivitySettings.swift:37` — `static let menuBarOverflowKey = "activity.menuBarOverflow"` (declared Phase 59, `defaultsToFalseKeys` set, line 65).
- `Islet/SettingsView.swift:74` — `@AppStorage(ActivitySettings.menuBarOverflowKey) private var menuBarOverflowEnabled = false`.
- `Islet/SettingsView.swift:243-247` — the grid card itself:
```swift
ActivityCardData(id: "menuBarOverflow", title: "Menu Bar Overflow",
                  description: "Hides overflow menu-bar icons behind a chevron, Ice-style.",
                  icon: "menubar.rectangle", iconColor: .secondary,
                  isOn: $menuBarOverflowEnabled, isNew: false, onOptionsTap: nil,
                  isComingSoon: true),
```
This is Phase 59's generic "reserve a grid slot for every not-yet-built v1.10 activity" placeholder (`SETTINGS-05`, all 8 default OFF, all `isComingSoon: true`). D-02 explicitly makes Menübar-Overflow a mechanism with no on/off switch — same category as Quick Notes (D-13), which has **no** `ActivityCardData` entry in this grid at all (confirmed: no `"quickNotes"` `id` maps to a toggle-gated activity — Quick Notes' card, if present, would need the same non-toggle treatment). The plan must decide one of:
1. Remove the `"menuBarOverflow"` `ActivityCardData` entry entirely from `activityCards`/whichever grid array it lives in, and let the new permission-status card (D-04, its own `Section`) be the feature's only Settings surface — mirrors Quick Notes' precedent most closely.
2. Repurpose the existing card as a read-only status display (flip `isComingSoon: false`, remove `isOn`/binding since there is nothing to toggle) — requires checking whether `ActivityCardData`'s `isOn` parameter is optional; if not, this path needs a struct change affecting every other card, which is a larger blast radius than option 1.

`menuBarOverflowKey`/`menuBarOverflowEnabled` becoming dead code (never read by production logic, only by `IsletTests/ActivitySettingsTests.swift:124,167`'s key-string assertions) is the likely outcome of option 1 — flag this for the plan rather than silently leaving an unused toggle wired into the UI.

## Pattern Assignments

### `Islet/Notch/MenuBarOverflowBridging.swift` (new — private CGS* symbol declarations)

**Analog:** none in-codebase. External analog only: `github.com/jordanbaird/Ice`, `Ice/Bridging/Shims/Private.swift` (per 66-RESEARCH.md Code Examples, direct source read).

**Declaration shape to follow** (RESEARCH.md, verbatim from Ice's source):
```swift
import CoreGraphics

typealias CGSConnectionID = Int32

@_silgen_name("CGSMainConnectionID")
func CGSMainConnectionID() -> CGSConnectionID

@_silgen_name("CGSGetScreenRectForWindow")
func CGSGetScreenRectForWindow(
    _ cid: CGSConnectionID,
    _ wid: CGWindowID,
    _ rect: inout CGRect
) -> CGError
```
Declare only the handful of symbols the spike (Wave 0) actually validates as necessary — do not port Ice's full `Private.swift` surface speculatively. This file has zero data flow of its own; it is a pure declaration shim consumed by `MenuBarOverflowController`.

---

### `Islet/Notch/MenuBarOverflowController.swift` (new — isolated manager: detect/move/persist)

**Analog 1 (permission gate + health-check idempotent start):** `Islet/Notch/CapsLockMonitor.swift` (105 lines, read in full)

**Permission-gated idempotent `start()` with 5s health-check retry, no force-prompt** (lines 34-56):
```swift
static var isAccessibilityTrusted: Bool { AXIsProcessTrusted() }

func start() {
    guard monitorToken == nil else { return }
    guard Self.isAccessibilityTrusted else {
        armHealthCheck()
        return
    }
    install()
}

private func armHealthCheck() {
    guard healthCheckTimer == nil else { return }
    healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
        DispatchQueue.main.async { [weak self] in
            guard let self, self.monitorToken == nil, Self.isAccessibilityTrusted else { return }
            self.install()
        }
    }
}
```
Directly satisfies D-02 ("activates automatically once Accessibility permission is granted — no relaunch"). Copy this shape verbatim for `MenuBarOverflowController.start()`: untrusted → arm a 5s retry that calls the real `install()` (which in this phase's case creates the chevron `NSStatusItem` — but note the chevron itself is owned by `AppDelegate`, so this controller's `install()` should be the moment `AppDelegate` is signaled to create the chevron, e.g. via a callback closure, not the controller creating the `NSStatusItem` directly — see `AppDelegate` section below for D-04's "chevron never appears while denied" requirement, which needs the chevron's *construction*, not just its behavior, gated on this same check).

**`nonisolated func stop()` + empty `deinit` ownership discipline** (lines 90-103): copy verbatim — the owning `AppDelegate`'s own deinit/teardown path calls `stop()`, this class's `deinit` stays empty by design.

**Analog 2 (relaunch re-application — directly resolves RESEARCH.md Pitfall 1):** `Islet/Notch/MeetingMonitor.swift` lines 118-125 (`NSWorkspace.didLaunchApplicationNotification`/`didTerminateApplicationNotification` observer pair)

```swift
let wc = NSWorkspace.shared.notificationCenter
for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
    let token = wc.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
        DispatchQueue.main.async { [weak self] in self?.evaluate() }
    }
    workspaceObservers.append(token)
}
```
D-03/Pitfall 1 requires the controller to **actively re-invoke the hide mechanism** whenever a bundle ID with a stored "hidden" assignment reappears — Ice's own source does not solve this. Subscribe the same way: on `didLaunchApplicationNotification`, diff the newly-launched app's bundle ID against `MenuBarOverflowStore`'s hidden set, and re-run the move-to-hidden sequence if it matches. Also mirror `MeetingMonitor`'s coarse 5s `pollTimer` fallback (lines 130-137) as a belt-and-suspenders convergence mechanism, since the private CGS window-list read (Pitfall 3, cross-version fragility) may silently miss a notification-driven re-check.

**Bundle-ID membership check pattern** (`isTargetAppRunning`, line 215):
```swift
NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier.map(targetBundleIDs.contains) ?? false }
```
Reuse this exact `Set<String>.contains` + `.map`-over-optional shape for checking whether a freshly-launched app's bundle ID is in the stored hidden set.

**Do NOT reuse `OSDInterceptor`'s `CGEventTap`/`.cghidEventTap` pattern for the drag mechanism itself** — Cmd-drag repositioning is native, zero-app-code OS behavior (RESEARCH.md Don't Hand-Roll); `OSDInterceptor.swift`/`DropInterceptTap.swift`'s tap-based interception is the wrong analog for MENUBAR-02. The only place a `CGEventTap`-adjacent technique applies is the synthetic-`CGEvent`-drag *move* mechanism itself (spike-validated, Wave 0), which is a one-shot synthesized sequence, not a passive tap/interceptor — do not model `MenuBarOverflowController` as a tap-holding class the way `OSDInterceptor`/`DropInterceptTap` are.

---

### `Islet/Notch/MenuBarOverflowStore.swift` (new — UserDefaults-backed bundle-ID → hidden/visible store)

**Analog:** `Islet/ActivitySettings.swift` (namespace-key convention, lines 13-50) — role-match only, not a literal extension.

**Key-namespace-as-enum-of-static-lets convention** (lines 13-21):
```swift
enum ActivitySettings {
    static let chargingKey   = "activity.charging"
    static let nowPlayingKey = "activity.nowPlaying"
    ...
}
```
`ActivitySettings` uses one fixed `String` constant per feature — it has no shape for an arbitrary, growing set of bundle-ID keys. `MenuBarOverflowStore` needs a genuinely different data shape: a single `UserDefaults` key (e.g. `"menuBarOverflow.hiddenBundleIDs"`) holding a `Set<String>`/`[String]` array of hidden bundle identifiers, read/written as one encoded value — not one `UserDefaults` key per bundle ID (which would require enumerating all keys to reconstruct the set, an anti-pattern `UserDefaults` does not support cleanly). This is the phase's own "Claude's Discretion" item (D-03 storage format) — the closest working precedent for "one UserDefaults key holding a small `Codable`/array value" in this codebase is `ActivitySettings.quickNotesVaultFolderPathKey`'s plain-`String`-value shape (line 44), generalized from a single `String` to a `Set<String>`/`[String]`, both trivially `UserDefaults`-representable without a custom `Codable` wrapper.

**Guard against malformed keys (RESEARCH.md Security Domain V5):** validate bundle-ID strings are non-empty before using them as members of the stored set — bundle IDs originate from `NSWorkspace.runningApplications`/window info (OS-supplied), not user text, but a defensive empty-string guard costs one line and mirrors this codebase's "guard failure returns a safe default, never a partial write" discipline (`MicMuteController.swift`'s `readSystemInputMuted`/`toggleSystemInputMute` guard-chain shape, Phase 65 PATTERNS.md precedent).

---

### `Islet/AppDelegate.swift` (modified — new chevron `NSStatusItem` + controller ownership)

**Analog 1 (status-item construction, D-01 placement):** `Islet/AppDelegate.swift` lines 107-134 (`statusItem`) and lines 490-491 (`debugStatusItem`)

```swift
statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

if let button = statusItem.button {
    let image = NSImage(systemSymbolName: "capsule.fill",
                        accessibilityDescription: "Islet")
    image?.isTemplate = true        // template image = the key line
    button.image = image
    ...
}
```
The chevron follows this exact `NSStatusBar.system.statusItem(withLength:)` + template-image construction shape, using `chevron.left`/`chevron.right` per the UI-SPEC's Menu Bar Chevron Contract instead of `capsule.fill`. **D-01 ordering constraint:** construct the chevron item and add it to `NSStatusBar.system` *before* `statusItem`/`debugStatusItem` are constructed (UI-SPEC: "added to `NSStatusBar.system` before those two so it lands to their left") — this means the chevron's construction call must be sequenced earlier in `applicationDidFinishLaunching`/`setupMenuBar`-equivalent than line 107, not appended after it. **D-04 gate:** the chevron's construction itself (not just its click behavior) must be wrapped in `MenuBarOverflowController.isAccessibilityTrusted` (or an equivalent controller-owned check) — if untrusted, skip creating the `NSStatusItem` entirely; the controller's health-check-driven `install()` callback (see Controller section above) is what later triggers the chevron's construction on a mid-session grant, mirroring `CapsLockMonitor`'s pattern but for UI construction rather than an event monitor.

**Click handler wiring precedent** (line 306):
```swift
statusItem.button?.target = self
statusItem.button?.action = #selector(openSettings)
```
The chevron's button click (D-05 reveal/hide toggle) follows the same `button?.target`/`button?.action` `#selector` wiring — a plain `NSStatusItem.button` click handler, no `NSMenu` attached (UI-SPEC: "no menu attached to the chevron item itself, distinct from the main `statusItem`'s `NSMenu`" — matches `debugStatusItem`'s menu-attached shape being the WRONG analog here; `statusItem`'s pre-D-05-lock `button.action` shape, before `applyMenuBarClickRouting` introduced the menu/action mutual-exclusivity, is closer, but simplest is: never call `statusItem.menu = ...` on the chevron item at all).

**Analog 2 (menu-bar-only controller ownership on AppDelegate, not NotchWindowController):** `Islet/AppDelegate.swift` line 35
```swift
private let quickNotesController = QuickNotesController()
```
`MenuBarOverflowController` must be a stored property on `AppDelegate`, constructed and `.start()`-ed alongside `quickNotesController`, `statusItem`, `debugStatusItem` — **not** added to `NotchWindowController`'s `startXMonitor()`/`activityEnabled(ActivitySettings.xKey)` gated-lifecycle pattern (`NotchWindowController.swift` lines 685-887, e.g. `startCapsLockMonitor()`) — that pattern is exclusively for `IslandResolver`/notch-participating activities gated by an `ActivitySettings` toggle key, which per D-02 this feature explicitly has neither of (RESEARCH.md Architectural Responsibility Map; CONTEXT.md D-02 citing the Quick Notes/D-13 precedent directly).

---

### `Islet/SettingsView.swift` (modified — new permission-status card, `System` sidebar section)

**Analog:** `osdPermissionExplanationView`/`capsLockPermissionExplanationView` (lines 744-798) for copy/button shape; `permissionRow`/`statusView(for:)` (lines 606-642) for the granted/denied glyph-and-color convention; `permissionsSection`/`diagnosticsSection`'s `ScrollView(.vertical) { Form { Section(...) { ... } } }.padding(20)` container shape (lines 566-594).

**Deep-link button pattern to reuse verbatim** (lines 758-763, `osdPermissionExplanationView`):
```swift
Button("Open System Settings") {
    NSWorkspace.shared.open(URL(string:
        "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    showOSDPermissionExplanation = false
}
.keyboardShortcut(.defaultAction)
```
The new card's "Open System Settings" button (D-04) uses the identical URL string — copy-paste, not re-derive.

**Status glyph/color convention to reuse** (lines 630-641, `statusView(for:)`):
```swift
case .granted:
    Label("Granted", systemImage: "checkmark.circle.fill")
        .foregroundStyle(.green)
case .denied:
    Label("Denied", systemImage: "xmark.circle.fill")
        .foregroundStyle(.red)
```
UI-SPEC's card content (granted → green `checkmark.circle.fill` "Active"; denied → red `xmark.circle.fill` "Permission required") maps directly onto this existing 2-case convention (the 3rd `.notYetAsked` case in `PermissionStatus` is not needed here per UI-SPEC — Accessibility's `AXIsProcessTrusted()` is a bare `Bool`, not a 3-state framework enum, so this card's local state is a simple `Bool`, not `PermissionStatus`; **do not** force this into the existing `PermissionKind`/`PermissionStatus` 5-item rollup — UI-SPEC explicitly locks this as "deliberately not added as a 6th row," confirmed correct: `PermissionStatus.swift`'s `PermissionKind` enum has exactly 5 fixed cases with no Accessibility case, and its rollup copy ("X of 5 granted") is hardcoded to that count).

**Live-updating status via the controller's own health-check, not a new poll:** the card's Bool state should read `MenuBarOverflowController.isAccessibilityTrusted` (or observe a published property the controller updates from its own 5s health-check timer, mirroring `CapsLockMonitor`'s cadence) — do not spin up a second, independent polling timer in `SettingsView` for the same fact.

**Sidebar section placement — UI-SPEC's "System" section does not exist in this codebase.** `SettingsView.swift` lines 148-152 define the actual `SidebarSection` enum:
```swift
case activities, appearance, switcher, fullscreen, weather, permissions, diagnostics, workspace, about
```
There is no `.system` case (UI-SPEC's reference to "Phase 27's `NavigationSplitView` categories: General/Workspace/System/About" does not match the live enum — that categorization is stale/aspirational, not the actual code). UI-SPEC itself flags this as non-locked ("not explicitly locked by CONTEXT.md, treat as a default the planner may relocate"). Closest fits among the real cases: `.permissions` (thematically closest — an always-visible permission-status surface, same spirit as the existing 5-row `permissionsSection`, though D-04's card is deliberately NOT a 6th row in that same section per UI-SPEC) or `.diagnostics`. The plan should pick one of the 9 real cases, not `.system`.

---

### `IsletTests/MenuBarOverflowManualSpike.swift` (new — Wave 0 mandated spike, SC#1)

**Analog:** `IsletTests/MeetingMonitorManualSpike.swift` (48 lines, read in full) — clone the shape 1:1.

**Full structural shape to clone:**
```swift
import XCTest
@testable import Islet

// MANUAL SPIKE — DO NOT RUN VIA `xcodebuild test` (the full Islet.app test host hangs
// headless — this project's established xcodebuild-test-headless-hang precedent). Run via
// Xcode Cmd-U for THIS single test method only, then read the Xcode console and follow the
// N-step on-device verification checklist in <plan-file>.md Task N.
final class MeetingMonitorManualSpike: XCTestCase {

    @MainActor
    func testManualDetectionHeuristic() {
        print("[MeetingSpike] about to read+toggle system input mute — NO TCC prompt expected")
        ...
        RunLoop.current.run(until: Date().addingTimeInterval(180))
        ...
        // Always green — the real pass/fail criteria is the human-read console output plus
        // the plan's on-device checkpoint, never this trivial assertion.
        XCTAssertTrue(true, "manual spike — see console output and <plan>.md Task N for the real pass/fail criteria")
    }
}
```
`MenuBarOverflowManualSpike.swift` must:
1. Rename the header comment's precedent citation to reference this phase's own plan file.
2. Substitute the CGS-symbol window-list read + synthetic-drag move for the mic-mute read/toggle (RESEARCH.md Standard Stack).
3. Cover permission-denied, sleep/wake, and Dock-relaunch as separate console-logged checklist steps within the same `RunLoop.current.run(until:)` window (RESEARCH.md Pattern 1: "covering permission-denied / sleep-wake / Dock-relaunch as separate checklist steps within the same run").
4. Keep the assertion `XCTAssertTrue(true, ...)` — pass/fail is human-judged from console output against the plan's checklist, never from the test framework itself.
5. Explicitly print whether the vacated position appears to reclaim space or only occlude (RESEARCH.md Pitfall 2 — this IS the spike's primary acceptance criterion, per RESEARCH.md Open Question 1's recommendation).

## Shared Patterns

### Accessibility-gated idempotent `start()` with 5s health-check retry, never force-prompting
**Source:** `Islet/Notch/CapsLockMonitor.swift` lines 34-56 (`isAccessibilityTrusted`, `start()`, `armHealthCheck()`)
**Apply to:** `MenuBarOverflowController.start()` — untrusted state arms a retry timer instead of giving up; never calls `AXIsProcessTrustedWithOptions(prompt: true)` from a passive check (RESEARCH.md Anti-Patterns — only a genuine user-initiated action, if any, would call the prompt variant, mirroring `DropInterceptTap.swift`'s one-time call at explicit `start()`).

### `NSWorkspace` launch/terminate notification + coarse poll fallback for re-applying state
**Source:** `Islet/Notch/MeetingMonitor.swift` lines 118-137
**Apply to:** `MenuBarOverflowController` — resolves RESEARCH.md Pitfall 1 (hidden-icon assignment must be actively re-applied on relaunch, Ice's own source does not solve this generically).

### Deep-link to System Settings' Accessibility pane
**Source:** `Islet/SettingsView.swift` lines 758-763 (also `:788-791`), verbatim URL string `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`
**Apply to:** the new permission-status card's "Open System Settings" button (D-04) — copy-paste, this exact string is already proven working in this app on this deployment target.

### `nonisolated func stop()` + empty `deinit`, owner-driven teardown
**Source:** `Islet/Notch/CapsLockMonitor.swift` lines 90-103, `Islet/Notch/MeetingMonitor.swift` lines 144-182
**Apply to:** `MenuBarOverflowController.stop()` — `AppDelegate` (the owner) is responsible for calling `stop()`; the controller's own `deinit` stays empty by convention.

### Manual on-device `XCTestCase` spike, always-green assertion, human-judged pass/fail
**Source:** `IsletTests/MeetingMonitorManualSpike.swift` (whole-file convention)
**Apply to:** `MenuBarOverflowManualSpike.swift` — mandated by ROADMAP SC#1; never gate this or any future automated suite on it, per the documented `xcodebuild-test-headless-hang` precedent.

## No Analog Found

**`Islet/Notch/MenuBarOverflowBridging.swift`** — the private `CGS*` `@_silgen_name` symbol-linkage technique has zero precedent anywhere in this codebase (confirmed via `grep -rn "_silgen_name" Islet/` returning no matches). The only external analog is Ice's own `Ice/Bridging/Shims/Private.swift` (RESEARCH.md Code Examples, direct source read) — this file's shape must be built from that reference, not from an in-codebase pattern, and is exactly the "highest-novelty, zero-reuse" code RESEARCH.md's Don't Hand-Roll section flags as the phase's real work.

## Metadata

**Analog search scope:** `Islet/Notch/` (CapsLockMonitor.swift, OSDInterceptor.swift, DropInterceptTap.swift, MeetingMonitor.swift, MicMuteController.swift read in full or via targeted ranges), `Islet/` (AppDelegate.swift, SettingsView.swift, ActivitySettings.swift, PermissionStatus.swift), `IsletTests/` (MeetingMonitorManualSpike.swift read in full, ActivitySettingsTests.swift grepped)
**Files scanned:** 9 source files (5 read in full, 4 via targeted non-overlapping ranges), 1 test file read in full
**Pattern extraction date:** 2026-07-27
