# Phase 40: Update-Available HUD & Sparkle Integration - Pattern Map

**Mapped:** 2026-07-18
**Files analyzed:** 7 (2 new... actually 1 new, 6 modified)
**Analogs found:** 7 / 7

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|-----------------|----------------|
| `project.yml` | config | batch (build-time package resolution) | `project.yml` itself — `MediaRemoteAdapter` package block (lines 24-27, 46-50) | exact |
| `Islet/AppDelegate.swift` | controller (app-lifecycle) | event-driven + request-response | itself — existing `statusItem`/`menu` construction (lines 37-58) | exact |
| `Islet/Notch/UpdateAvailableState.swift` (NEW) | model/store | event-driven | `Islet/Notch/NowPlayingState.swift` (whole file, 55 lines) | exact |
| `Islet/Notch/NotchWindowController.swift` | controller | event-driven | itself — `nowPlayingState` property declaration + ownership comment (lines 193-198) | exact |
| `Islet/Notch/NotchPillView.swift` | component (SwiftUI view) | event-driven (render-on-@Published-change) | itself — `body`/`presentationSwitch` outer container (lines 716-768) + Focus status dot (lines 2209-2210) | exact |
| `Islet/ActivitySettings.swift` | config/store | CRUD (key-value read/write) | itself — existing `@AppStorage` key + hint-helper conventions (lines 13-92) | exact |
| `Islet/SettingsView.swift` | component (SwiftUI view) | request-response (toggle → UserDefaults) | itself — Focus/OSD toggle rows in the "Activities" `Section` (lines 211-260) | exact |

All analogs are same-role, same-data-flow, and drawn from the same repo (no cross-project inference needed) — this phase is explicitly scoped by CONTEXT.md/RESEARCH.md to mirror existing precedents exactly (Phase-18 song-change toast shape for the badge, `MediaRemoteAdapter` embed shape for Sparkle, `ActivitySettings`/`SettingsView` toggle shape for D-11).

---

## Pattern Assignments

### `project.yml` (config, batch)

**Analog:** `project.yml` itself, `MediaRemoteAdapter` package entry

**Existing package block to mirror** (lines 21-27):
```yaml
# Phase-4 (Now Playing): the MediaRemote bridge. The repo has ZERO git tags, so
# `from:`/`majorVersion:` will NOT resolve (Pitfall 4) — pin a known-good commit by
# `revision:` for a reproducible, supply-chain-safe build (T-04-01).
packages:
  MediaRemoteAdapter:
    url: https://github.com/ejbills/mediaremote-adapter
    revision: cf30c4f1af29b5829d859f088f8dbdf12611a046   # no tags exist — pin a known-good commit
```
**Difference for Sparkle:** Sparkle DOES have real git tags (RESEARCH.md, "Alternatives Considered" table) — use `from: 2.9.4` instead of `revision:`.

**Existing dependency/embed block to mirror** (lines 46-50):
```yaml
    dependencies:
      - package: MediaRemoteAdapter
        product: MediaRemoteAdapter
        embed: true        # Embed & Sign — the framework is a RUNTIME resource (run.pl lives inside it), not just link-time. Pitfall 3: omitting → Bundle.module/run.pl resolve to nothing → silent no-op.
        codeSign: true     # codeSignOnCopy — required for hardened-runtime + later notarization
```
Add a second `- package: Sparkle / product: Sparkle` entry, same `embed: true`/`codeSign: true` shape. `CODE_SIGN_ENTITLEMENTS: Islet/Islet.entitlements` (line 93) is already project-wide and already carries `disable-library-validation` — no entitlement changes needed (Pitfall 3, confirmed in RESEARCH.md).

**Info.plist keys to add** — follow the existing `INFOPLIST_KEY_*` convention (lines 55-79, e.g. `INFOPLIST_KEY_LSUIElement`, `INFOPLIST_KEY_NSBluetoothAlwaysUsageDescription`):
```yaml
INFOPLIST_KEY_SUFeedURL: "https://<vercel-domain-placeholder>/appcast.xml"   # D-01, placeholder per D-03
INFOPLIST_KEY_SUPublicEDKey: "<base64 public key from generate_keys>"       # D-03
INFOPLIST_KEY_SUEnableAutomaticChecks: YES                                   # D-09/D-12, RESEARCH.md Pitfall 1 — MUST be explicit, do not rely on the runtime property alone
```
RESEARCH.md Open Question 1 flags this as unverified against `GENERATE_INFOPLIST_FILE: YES` (line 80) — try the `INFOPLIST_KEY_*` prefix first (consistent with every other key in this file); fall back to a literal `Info.plist` merge only if `xcodegen generate` doesn't pick it up.

---

### `Islet/AppDelegate.swift` (controller, event-driven + request-response)

**Analog:** itself

**Imports** (lines 1-2) — add `import Sparkle`:
```swift
import SwiftUI
import AppKit
```

**Menu construction pattern to extend** (lines 49-58):
```swift
menu = NSMenu()
menu.addItem(withTitle: "Settings…",
             action: #selector(openSettings), keyEquivalent: ",")
menu.addItem(.separator())
menu.addItem(withTitle: "Quit Islet",
             action: #selector(quit), keyEquivalent: "q")
// Menu items send their actions to this delegate.
for item in menu.items { item.target = self }
statusItem.menu = menu
```
Per `40-UI-SPEC.md`'s Menu Item Contract: insert `"Check for Updates…"` between `"Settings…"` and the separator, same `target = self` wiring — item wired to a new `checkForUpdates` selector before the `for item in menu.items { item.target = self }` loop runs (loop already picks up any item added before it).

**Property + construction pattern to mirror** (lines 14, 74-76 — `notchController` property and its construction in `applicationDidFinishLaunching`):
```swift
var notchController: NotchWindowController?
...
let controller = NotchWindowController()
controller.start(isFirstLaunch: isFirstLaunch)
self.notchController = controller
```
Sparkle's `SPUStandardUpdaterController` should be constructed the same way — a stored property built in `applicationDidFinishLaunching`, parallel to `statusItem`/`notchController` (RESEARCH.md Pattern 1):
```swift
private var updaterController: SPUStandardUpdaterController!
...
updaterController = SPUStandardUpdaterController(
    startingUpdater: true,
    updaterDelegate: self,
    userDriverDelegate: nil
)

@objc private func checkForUpdates() {
    updaterController.checkForUpdates(nil)
}
```

**Bridging pattern** — `AppDelegate` already reaches into `notchController` from outside (the class comment at lines 12-13: "not `private` so SettingsView can read the live nowPlayingState.isHealthy via the standard `NSApp.delegate as? AppDelegate` idiom"). Use the same reach-in to set the new badge state from the `SPUUpdaterDelegate` callback:
```swift
extension AppDelegate: SPUUpdaterDelegate {
    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        notchController?.updateAvailableState.updateAvailable = true
    }
}
```

**`@objc` selector pattern** (lines 130, 141) — `openSettings`/`quit` are the exact shape to copy for `checkForUpdates`:
```swift
@objc private func openSettings() {
    NSApp.activate(ignoringOtherApps: true)
    NotificationCenter.default.post(name: .openIsletSettings, object: nil)
    ...
}
```
Note: unlike `openSettings`, `checkForUpdates` does NOT need an explicit `NSApp.activate` call for the automatic/background-check path — only the user-initiated tap (menu item or badge) is allowed to activate the app (RESEARCH.md Pitfall 2, UI-SPEC.md Menu Item Contract: "explicit user-initiated click, so Sparkle's dialog activating/stealing focus here is acceptable").

---

### `Islet/Notch/UpdateAvailableState.swift` (NEW — model/store, event-driven)

**Analog:** `Islet/Notch/NowPlayingState.swift` (full file, 55 lines) — same "SEPARATE `@Published` model, mirrors [X]" shape used by every prior phase's orthogonal state carrier (`NowPlayingState`, and per RESEARCH.md, this mirrors the `songChangeToast` field's own "one-shot orthogonal `@Published` field" shape specifically).

**Full analog structure to copy** (`NowPlayingState.swift` lines 1-45):
```swift
import AppKit

// Phase 4 / NOW-01/02/03 — the SEPARATE @Published media model, mirroring
// ChargingActivityState. Deliberately NOT folded into NotchInteractionState or
// ChargingActivityState, so the Phase-2 gesture machine + Phase-3 charging splash stay
// untouched and D-14 precedence is a one-line `if` in the view.
final class NowPlayingState: ObservableObject {
    @Published var presentation: NowPlayingPresentation = .none
    @Published var artwork: NSImage?
    @Published var isHealthy: Bool = true
    @Published var hasPlayedSinceLaunch: Bool = false
    @Published var songChangeToast: TrackToast? = nil
    @Published var position: PlaybackPosition?
    @Published var lastKnownTrack: LastPlayedTrack? = nil
}
```

**New file shape (one field, no timers — D-13 explicitly has NO auto-dismiss unlike `songChangeToast`):**
```swift
import Foundation

// Phase 40 / HUD-06 — the SEPARATE @Published badge model, mirroring NowPlayingState's
// shape. Deliberately NOT routed through IslandResolver/TransientQueue/ActiveTransient
// (ARCHITECTURE.md Integration Point 5, 40-CONTEXT.md domain note) — this flag never
// expires on its own and never competes for a collapsed-pill slot; it overlays.
final class UpdateAvailableState: ObservableObject {
    // D-13: pure reflection of Sparkle's live SPUUpdaterDelegate signal — set true by
    // AppDelegate's updater(_:didFindValidUpdate:), reset to false only by an actual
    // app relaunch after install (no explicit clear code needed, per RESEARCH.md Pattern 2).
    @Published var updateAvailable: Bool = false
}
```

**Difference from the `songChangeToast` field on `NowPlayingState`:** `songChangeToast` (line 33 of `NowPlayingState.swift`) is cleared by a dismiss timer and by interrupting-transient/manual-expand logic (`NotchWindowController.swift` lines 799-801, 1416-1418, 1913-1916). `updateAvailable` has NO such clearing logic anywhere — D-13/D-14 explicitly forbid any app-level dismiss path beyond Sparkle's own dialog.

---

### `Islet/Notch/NotchWindowController.swift` (controller, event-driven — small modification)

**Analog:** itself — `nowPlayingState` property declaration (lines 193-198)

**Pattern to copy:**
```swift
// Phase 4 / NOW-01/02 — the SEPARATE @Published media model the media wings + expanded
// controls observe (Plan 02). Created here so the view has a live instance to bind to;
// Plan 04 wires the NowPlayingMonitor to drive its presentation/artwork/isHealthy
// (start() + runHealthCheck + onSnapshot/onTerminated) and applies the spring on mutation.
// Until then it stays .none/healthy → the view shows the existing collapsed/date-time states.
let nowPlayingState = NowPlayingState()
```
Add a parallel `let updateAvailableState = UpdateAvailableState()` stored property, same `let` (not `private`) visibility — `AppDelegate` needs to reach in and flip `.updateAvailable` from its `SPUUpdaterDelegate` callback (same reach-in precedent as `nowPlayingState.isHealthy`, quick-task 260708-u47 comment at `AppDelegate.swift` lines 12-13). No `start()`/monitor wiring needed — unlike `nowPlayingState`, this model is driven entirely from outside (`AppDelegate`), not from an internal monitor this controller owns.

---

### `Islet/Notch/NotchPillView.swift` (component, event-driven render)

**Analog:** itself — `body`/`presentationSwitch` outer container (lines 757-768) + Focus status dot (lines 2209-2210) for size-class precedent

**Outer container to attach the overlay to** (lines 757-768):
```swift
var body: some View {
    ZStack(alignment: .top) {
        presentationSwitch
    }
    .frame(...)   // existing frame modifiers, unchanged
}
```
Per `40-UI-SPEC.md` Verification Notes: attach `.overlay(alignment: .topTrailing)` on this SAME outer `ZStack` (NOT inside any `presentationSwitch` case body) so the badge renders regardless of which `IslandPresentation` case is active, and gate on `!interaction.isExpanded` (D-06).

**Existing environment accent read to reuse** (line 132):
```swift
@Environment(\.nowPlayingAccent) private var nowPlayingAccent
```
D-07/UI-SPEC.md: the badge reuses this exact same accent — no new EnvironmentKey.

**Existing small status-dot precedent for size-class comparison** (Focus dot, lines 2209-2210):
```swift
Circle().fill(Color.green)                 // fixed, universal active signal — never theme-tinted
    .frame(width: 8, height: 8)
```
UI-SPEC.md explicitly deviates from this: the badge is a 12pt semibold SF Symbol glyph (`arrow.up.circle.fill`), not an 8pt plain `Circle()`, and uses the theme accent (`nowPlayingAccent`) rather than a fixed color — this Focus-dot excerpt is cited only as the closest prior "small fixed status indicator" precedent, not as code to copy verbatim.

**Existing tap + accessibility pattern to mirror** (shelf trash icon precedent, line 1901):
```swift
.accessibilityLabel("Clear shelf")
```
Use the same `.accessibilityLabel(...)` + `.onTapGesture { ... }` shape for the badge, per UI-SPEC.md's locked copy `"Update available"`.

**New overlay code (per `40-UI-SPEC.md`, approved):**
```swift
.overlay(alignment: .topTrailing) {
    if updateAvailableState.updateAvailable && !interaction.isExpanded {
        Image(systemName: "arrow.up.circle.fill")
            .font(.system(size: 12, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(nowPlayingAccent)
            .offset(x: -4, y: 4)
            .accessibilityLabel("Update available")
            .onTapGesture { onUpdateBadgeTap() }
    }
}
```
`NotchPillView` needs a new `@ObservedObject var updateAvailableState: UpdateAvailableState` (or equivalent binding, mirroring how `nowPlaying: NowPlayingState` is already threaded into this view) plus a tap-handler closure parameter (mirrors the existing closures like `openOnboardingSettings()` threaded from `NotchWindowController`).

---

### `Islet/ActivitySettings.swift` (config/store, CRUD)

**Analog:** itself — existing `@AppStorage` key convention (lines 13-38)

**Pattern to copy** (lines 13-26, showing the key-declaration shape):
```swift
enum ActivitySettings {
    static let chargingKey   = "activity.charging"
    static let nowPlayingKey = "activity.nowPlaying"
    static let songChangeToastKey = "activity.songChangeToast"
    static let deviceKey     = "activity.device"
    static let focusKey = "activity.focus"
    static let osdSuppressionKey = "activity.osdSuppression"
    ...
```
Add a new key following the exact same naming convention: `static let autoUpdateCheckKey = "activity.autoUpdateCheck"` (RESEARCH.md's own Code Examples section confirms this exact key string). No permission-hint helper needed (unlike `focusPermissionStatusHint`/`osdPermissionStatusHint`, lines 81-92) — UI-SPEC.md's Settings Toggle Contract explicitly states "no permission-explanation popover for this phase."

---

### `Islet/SettingsView.swift` (component, request-response)

**Analog:** itself — Focus/OSD toggle rows inside the "Activities" `Section` (lines 211-260)

**`@AppStorage` declaration pattern to copy** (lines 37, 46):
```swift
@AppStorage(ActivitySettings.focusKey) private var focusEnabled = false
...
@AppStorage(ActivitySettings.osdSuppressionKey) private var osdSuppressionEnabled = false
```
New declaration, default `true` per D-12 (deliberately opposite of Focus/OSD's `false` default — RESEARCH.md's own Code Examples section confirms this exact line):
```swift
@AppStorage(ActivitySettings.autoUpdateCheckKey) private var autoUpdateCheckEnabled = true  // D-12: default true
```

**Simple toggle-row pattern to copy** (lines 212-215, the plain toggles with no permission popover):
```swift
Toggle("Charging", isOn: $chargingEnabled)
Toggle("Now Playing", isOn: $nowPlayingEnabled)
Toggle("Song-Change Toast", isOn: $songChangeToastEnabled)
Toggle("Devices", isOn: $deviceEnabled)
```
Per UI-SPEC.md: the new toggle follows this PLAIN shape (no `.onChange`/`.popover`/status-hint — unlike Focus/OSD's permission-gated toggles at lines 220-259), added to the same `Section("Activities") { ... }` block:
```swift
Toggle("Automatically Check for Updates", isOn: $autoUpdateCheckEnabled)
```
Wire the read side (not shown in this file — belongs in `AppDelegate`/updater construction): `updater.automaticallyChecksForUpdates = autoUpdateCheckEnabled` read once at relevant points, per RESEARCH.md's Architectural Responsibility Map ("Settings UI writes `@AppStorage`, a lifecycle/controller object reads it").

---

## Shared Patterns

### Orthogonal `@Published` state, NOT routed through `IslandResolver`
**Source:** `Islet/Notch/NowPlayingState.swift` (whole file) + `Islet/Notch/IslandResolver.swift:195` (`songChangeToastGate`, for contrast — the badge needs NO equivalent gate function since it has no queue/expiry semantics)
**Apply to:** `UpdateAvailableState.swift`, `NotchPillView.swift`'s overlay
```swift
final class NowPlayingState: ObservableObject {
    @Published var songChangeToast: TrackToast? = nil   // one-shot, timer-cleared — NOT this phase's model
}
```
The badge's `updateAvailable: Bool` differs from every existing `@Published` field in this codebase in one respect: it has no clearing logic at all inside `NotchWindowController`/`IslandResolver` — do not add a gate function or a `TransientQueue` case for it (RESEARCH.md Anti-Patterns section, explicit).

### `project.yml` third-party-framework embed (Hardened Runtime)
**Source:** `project.yml` lines 24-27, 46-50, 93 (`MediaRemoteAdapter` package + `embed: true`/`codeSign: true` + `CODE_SIGN_ENTITLEMENTS: Islet/Islet.entitlements`)
**Apply to:** the new Sparkle package block
```yaml
packages:
  Sparkle:
    url: https://github.com/sparkle-project/Sparkle
    from: 2.9.4
...
    dependencies:
      - package: Sparkle
        product: Sparkle
        embed: true
        codeSign: true
```
No entitlement change needed — `disable-library-validation` is already project-wide (confirmed in `Islet/Islet.entitlements`, RESEARCH.md Pitfall 3).

### `@AppStorage` toggle, app-owned preference (not system permission)
**Source:** `Islet/ActivitySettings.swift` lines 13-22 (key declarations) + `Islet/SettingsView.swift` lines 28-33 (declarations) and 212-215 (plain toggle rows, no popover)
**Apply to:** `autoUpdateCheckKey`/`autoUpdateCheckEnabled` toggle
```swift
static let autoUpdateCheckKey = "activity.autoUpdateCheck"
...
@AppStorage(ActivitySettings.autoUpdateCheckKey) private var autoUpdateCheckEnabled = true
...
Toggle("Automatically Check for Updates", isOn: $autoUpdateCheckEnabled)
```

### `AppDelegate` app-lifecycle object construction + `NSMenu` wiring
**Source:** `Islet/AppDelegate.swift` lines 49-58 (menu construction), 74-76 (controller construction + property assignment), 130-139/141-143 (`@objc` action pattern)
**Apply to:** `updaterController` construction, `"Check for Updates…"` menu item, `checkForUpdates` selector

---

## No Analog Found

None. Every file in this phase's scope has a direct, exact-match analog already in the codebase — this phase is explicitly designed (per CONTEXT.md/RESEARCH.md) to mirror the Phase-18 song-change-toast shape and the Phase-4 `MediaRemoteAdapter` embed shape rather than invent new patterns.

## Metadata

**Analog search scope:** `Islet/`, `Islet/Notch/`, `project.yml` — targeted reads guided directly by RESEARCH.md's own line-number citations (all independently re-verified against the live files this session)
**Files scanned:** `AppDelegate.swift`, `ActivitySettings.swift`, `project.yml`, `NotchPillView.swift`, `NotchWindowController.swift`, `NowPlayingState.swift`, `SettingsView.swift` — 7 files, all read directly (no re-reads of the same range)
**Pattern extraction date:** 2026-07-18
</content>
