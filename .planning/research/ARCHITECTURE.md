# Architecture Research

**Domain:** Native macOS notch / Dynamic-Island utility app (menu-bar agent, borderless overlay over the physical notch)
**Researched:** 2026-06-26
**Confidence:** HIGH (overlay window, geometry, lifecycle, power/Bluetooth services verified against Apple docs + multiple open-source apps); MEDIUM on Now Playing (MediaRemote is private and changes between macOS versions — the adapter workaround is verified but version-fragile)

> This architecture is reverse-engineered from the open-source apps the project already names as references — **TheBoringNotch** (TheBoredTeam/boring.notch), **DynamicNotch** (jackson-storm), and **DynamicNotchKit** (MrKai77) — plus Apple's AppKit/IOKit docs. All three real apps converge on the same shape, so the recommendation below is the *de facto standard* for this domain, not one option among many.

---

## The One Idea That Makes This Whole App Make Sense

A notch app is **not** a normal window-based app. It is:

> A **background agent** (no Dock icon) that owns **one always-on-top borderless panel** glued over the notch. That panel hosts **one SwiftUI view tree**. A single **state object** decides what that view shows. Several independent **services** watch the system (music, power, Bluetooth) and *push facts* into that state object. The view just renders whatever the state object currently says.

Everything below is an elaboration of that sentence. If you understand that one paragraph, you understand the architecture. The beginner-critical consequence: **the overlay window and the state object are the spine; features are leaves you bolt on one at a time.** You can ship a visible-but-empty island before any feature exists.

---

## Standard Architecture

### System Overview

```
┌──────────────────────────────────────────────────────────────────────┐
│                       APP LIFECYCLE LAYER                              │
│   NotchApp (@main, LSUIElement agent — no Dock icon)                   │
│   ├─ MenuBarExtra  → settings menu, quit, launch-at-login toggle       │
│   └─ AppDelegate   → creates the overlay panel, owns global lifecycle  │
├──────────────────────────────────────────────────────────────────────┤
│                       OVERLAY WINDOW LAYER                             │
│   NotchWindowController                                                │
│   ├─ NotchPanel : NSPanel  (borderless, .floating, joins all spaces,  │
│   │                          non-activating, sized & placed over notch)│
│   ├─ NSHostingView { NotchRootView }   ← SwiftUI lives inside here     │
│   └─ NotchGeometry  (reads NSScreen → notch frame, safe-area insets)   │
├──────────────────────────────────────────────────────────────────────┤
│                    STATE / COORDINATION LAYER  ★ the brain ★          │
│   IslandState : ObservableObject                                       │
│   ├─ presentation: .idle | .expanded | .activity(ActivityKind)        │
│   ├─ priority resolver (media vs charging vs device event)            │
│   └─ hover / interaction flags                                        │
├──────────────────────────────────────────────────────────────────────┤
│                       FEATURE / SERVICE LAYER                          │
│   ┌────────────────┐ ┌───────────────┐ ┌─────────────────┐            │
│   │ NowPlaying     │ │ Power /        │ │ Bluetooth       │            │
│   │ Service        │ │ Battery Service│ │ Service         │            │
│   │ (MediaRemote   │ │ (IOKit.ps)     │ │ (IOBluetooth)   │            │
│   │  via adapter)  │ │                │ │                 │            │
│   └───────┬────────┘ └───────┬───────┘ └────────┬────────┘            │
│           └──────────────────┴──── push facts ──┘                     │
│                          ▼                                            │
│                  (into IslandState)                                  │
├──────────────────────────────────────────────────────────────────────┤
│                       SYSTEM (read-only sources)                      │
│   mediaserverd  •  IOPowerSources  •  IOBluetooth  •  NSScreen        │
└──────────────────────────────────────────────────────────────────────┘
```

**Read this diagram as a one-way street going *up*:** the system emits events → services translate them into clean app facts → facts land in `IslandState` → SwiftUI re-renders. The view never reaches *down* into a service. This is the single most important rule for keeping a beginner project from turning into spaghetti.

### Component Responsibilities

| Component | Responsibility (what it OWNS) | Typical Implementation |
|-----------|-------------------------------|------------------------|
| `NotchApp` (@main) | App entry, declares it's an agent, holds the menu bar item | SwiftUI `App` + `MenuBarExtra`, `LSUIElement=true` in Info.plist |
| `AppDelegate` | Creates the overlay panel at launch, owns workspace/screen observers, launch-at-login | `NSApplicationDelegateAdaptor` |
| `NotchWindowController` | Builds & positions the panel, swaps it across screen changes | `NSWindowController` subclass |
| `NotchPanel` | The actual borderless window over the notch; all window-level config | `NSPanel` subclass |
| `NotchGeometry` | "Where is the notch, how big, is there even one?" | Reads `NSScreen.safeAreaInsets` / `auxiliaryTopLeftArea` |
| `NotchRootView` | The single SwiftUI root; switches between idle/expanded/activity subviews | SwiftUI `View` + `@EnvironmentObject IslandState` |
| **`IslandState`** | **The brain: which activity wins, idle vs expanded, current content** | `ObservableObject` with `@Published` props |
| `NowPlayingService` | Current track, art, play state; play/pause/skip commands | MediaRemote via `mediaremote-adapter` (see Integration) |
| `PowerService` | Charging? Plugged in? Battery %? | `IOKit.ps` + run-loop notification source |
| `BluetoothService` | Device connected / disconnected events | `IOBluetooth` connect/disconnect notifications |
| `SettingsStore` | User preferences, persisted | `@AppStorage` / `UserDefaults` |

---

## Recommended Project Structure

```
Notch/
├── App/
│   ├── NotchApp.swift              # @main, MenuBarExtra, agent declaration
│   ├── AppDelegate.swift           # creates overlay, screen/workspace observers
│   └── Info.plist                  # LSUIElement = true
├── Window/
│   ├── NotchWindowController.swift # builds + positions the panel
│   ├── NotchPanel.swift            # NSPanel subclass (all window config)
│   └── NotchGeometry.swift         # NSScreen → notch frame, safe-area insets
├── State/
│   ├── IslandState.swift           # ★ the central ObservableObject (the brain)
│   └── ActivityKind.swift          # enum: nowPlaying / charging / deviceEvent ...
├── Views/
│   ├── NotchRootView.swift         # root; switches idle/expanded/activity
│   ├── IdleNotchView.swift         # the closed black pill
│   ├── ExpandedNotchView.swift     # expanded shell + transitions
│   └── Activities/
│       ├── NowPlayingView.swift
│       ├── ChargingView.swift
│       └── DeviceConnectedView.swift
├── Services/
│   ├── NowPlaying/
│   │   ├── NowPlayingService.swift
│   │   └── MediaRemoteAdapter/     # bundled perl script + framework (see notes)
│   ├── PowerService.swift
│   └── BluetoothService.swift
├── Settings/
│   ├── SettingsStore.swift
│   └── SettingsView.swift          # shown from MenuBarExtra
└── Resources/
    └── Assets.xcassets
```

### Structure Rationale

- **`Window/` is isolated from everything else.** It knows *nothing* about music or batteries. This is what lets the beginner build and test "a black pill sits on my notch" in total isolation before any feature exists — the hardest, most macOS-specific part, done first and never touched again.
- **`State/` sits between `Window`/`Views` and `Services` and is the only place that makes decisions.** One file (`IslandState`) holds *all* arbitration logic. When the beginner asks "why did the island show charging instead of music?", there is exactly one file to look at.
- **Each service is one self-contained file/folder.** Adding the file shelf or timer later = add a service + a view + one enum case. Nothing existing needs rewiring. This is the "layer features in" property the project requires.
- **Views are dumb.** They read `IslandState` and render. They contain no IOKit, no MediaRemote, no timers. This keeps the SwiftUI a beginner can read separate from the gnarly system APIs.

---

## Architectural Patterns

### Pattern 1: One Window, One Root View, State-Driven Content

**What:** There is exactly **one** overlay panel and **one** SwiftUI root view for its entire life. The island never creates/destroys windows to switch content — it changes a `@Published` property on `IslandState` and SwiftUI swaps the subview.

**When to use:** Always, for this app. All three reference apps do this (DynamicNotch's `NotchViewModel`, TheBoringNotch's `BoringViewModel`, DynamicNotchKit's `DynamicNotch`).

**Trade-offs:** Pro — animations are trivial (it's all one view tree, so SwiftUI's `withAnimation` + `.matchedGeometryEffect`/`.transition` "just work"); state is centralized; cheap on CPU (TheBoringNotch reports <2% CPU). Con — you must keep `IslandState` disciplined or it becomes a god object; mitigated by keeping *decision* logic in it but *data* in the services.

**Example:**
```swift
final class IslandState: ObservableObject {
    enum Presentation: Equatable {
        case idle                       // collapsed black pill
        case expanded                   // user hovered/clicked
        case activity(ActivityKind)     // a live activity is showing
    }
    @Published private(set) var presentation: Presentation = .idle
    @Published var isHovered = false

    // services push facts in through methods like these:
    func mediaChanged(_ info: NowPlayingInfo?) { resolve() }
    func powerChanged(_ power: PowerState)     { resolve() }
    func deviceEvent(_ event: DeviceEvent)     { resolve() }

    private func resolve() { /* priority logic — see Pattern 2 */ }
}
```
```swift
struct NotchRootView: View {
    @EnvironmentObject var state: IslandState
    var body: some View {
        switch state.presentation {
        case .idle:                 IdleNotchView()
        case .expanded:             ExpandedNotchView()
        case .activity(let kind):   ActivityView(kind: kind)
        }
    }
}
```

### Pattern 2: Priority Resolver (the activity arbiter)

**What:** Multiple things can want the island at once (music is playing *and* you plug in the charger *and* AirPods connect). One function decides who wins and for how long. Temporary events (charge plugged in, device connected) are **transient** — they show briefly, then yield back to the ambient state (music or idle).

**When to use:** The moment you have a second feature. This is the heart of feeling "native" — the iPhone Dynamic Island's polish *is* this arbitration.

**Trade-offs:** Pro — predictable, debuggable in one place. Con — getting the priorities/durations to *feel* right is design work, not just code (flag this phase for extra iteration).

**Example (priority model, not final tuning):**
```swift
// Highest wins. Transient events auto-expire back to the ambient layer.
enum ActivityKind: Comparable {
    case nowPlaying      // ambient / sticky while music plays
    case charging        // transient: ~3s splash, then collapse
    case deviceConnected // transient: ~3s splash, then collapse
}
// resolve(): if a transient event is active and unexpired → show it;
//            else if media is playing → show nowPlaying (collapsed strip);
//            else → idle.
```
A small **transient queue** (DynamicNotch literally calls its core a "queue-driven presentation state machine") holds short-lived events so two near-simultaneous events don't fight — they play in sequence.

### Pattern 3: Services Push, Never Pull

**What:** Services own a connection to a system source, convert raw system data into a clean app-domain struct (`NowPlayingInfo`, `PowerState`, `DeviceEvent`), and call a method on `IslandState`. Views *never* call services. Services *never* touch views.

**When to use:** Every service.

**Trade-offs:** Pro — each service is independently testable/buildable and replaceable (huge for the fragile MediaRemote piece — if Apple breaks it again you swap one file); clean one-directional data flow a beginner can trace. Con — a tiny bit more boilerplate than letting a view read IOKit directly (worth it).

**Example:**
```swift
final class PowerService {
    private let onChange: (PowerState) -> Void
    private var runLoopSource: CFRunLoopSource?

    init(onChange: @escaping (PowerState) -> Void) {
        self.onChange = onChange
        // IOPSNotificationCreateRunLoopSource → fires when power state changes
        // inside callback: read IOPSCopyPowerSourcesInfo, build PowerState, call onChange
    }
}
// Wiring (in AppDelegate / a composition root):
let power = PowerService { [weak islandState] in islandState?.powerChanged($0) }
```

---

## Data Flow

### Event Flow (system → screen)

```
[charger plugged in]
      ↓
IOPowerSources fires run-loop notification
      ↓
PowerService reads IOPSCopyPowerSourcesInfo → builds PowerState(isCharging, percent)
      ↓
PowerService calls islandState.powerChanged(power)
      ↓
IslandState.resolve() decides: transient "charging" activity wins for ~3s
      ↓
@Published presentation = .activity(.charging)  →  SwiftUI re-renders
      ↓
NotchRootView shows ChargingView with animation
      ↓
(timer expires) → resolve() → back to .nowPlaying or .idle
```

### Command Flow (the ONLY downward path: user → system)

The single exception to "data flows up." When the user taps play/pause in the island, the view sends a command *down* into a service:
```
[user taps pause in NowPlayingView]
      ↓ (intent, via IslandState or a passed closure)
NowPlayingService.togglePlayPause()
      ↓
MediaRemote send command → mediaserverd
      ↓
mediaserverd changes state → fires Now-Playing-changed notification
      ↓  (loops back into the normal upward flow)
NowPlayingService.onChange → islandState.mediaChanged(...) → view updates
```
Note the command does **not** optimistically update the UI; it lets the resulting system notification flow back up. This keeps the UI always reflecting real system state — the native-feeling behavior.

### State Management

```
        services push facts
   NowPlaying ─┐
   Power ──────┼──▶  IslandState (@Published)  ──subscribe──▶  SwiftUI views
   Bluetooth ──┘         ▲                                         │
                         └──────────── commands ───────────────────┘
                              (views → services, the one way down)
```

### Key Data Flows

1. **Ambient media:** music plays → `NowPlayingService` keeps `IslandState` updated → collapsed island shows a tiny now-playing strip; hover → expands to full controls + art.
2. **Transient power/device splash:** plug in / AirPods connect → service fires one event → island briefly expands with an animation → auto-collapses back to the ambient state.
3. **Hover/interaction:** mouse-enter inside the notch region → `isHovered = true` → `resolve()` may promote `.idle`/ambient to `.expanded`.

---

## Overlay Window: the macOS-specific recipe (verified)

This is the part with no SwiftUI equivalent — it must be done in AppKit. Verified against Apple docs + the floating-panel references.

| Concern | Setting | Why |
|---------|---------|-----|
| Window class | `NSPanel` subclass | Panels can be non-activating (clicking doesn't steal focus from your real app) |
| Style mask | `[.borderless, .nonactivatingPanel, .fullSizeContentView]` | No title bar/chrome; clicking won't activate the app |
| Level | `.statusBar` (above menu bar) or `.floating` | Notch sits at the very top; must float above normal windows |
| Collection behavior | `.canJoinAllSpaces` + `.fullScreenAuxiliary` | Island follows you across every Space; survives full-screen apps. **Avoid `.stationary`** |
| Activation | `becomesKeyOnlyIfNeeded = true`, `isFloatingPanel = true` | Stays out of the app-switcher / focus stealing |
| Background | `backgroundColor = .clear`, `isOpaque = false`, `hasShadow = false` | The "island" is a rounded black SwiftUI shape, not the window itself |
| Content | `contentView = NSHostingView(rootView: NotchRootView().environmentObject(islandState))` | Bridges SwiftUI into the AppKit panel |
| Click-through | Default panel intercepts mouse; for fully-transparent regions set `ignoresMouseEvents` or shape the interactive area | So you can click the desktop *around* the island but still hit the pill |

**Geometry** (where to put it) — verified against Apple docs:
- `NSScreen.safeAreaInsets.top > 0` → this screen has a notch (macOS 12+).
- `NSScreen.auxiliaryTopLeftArea` / `auxiliaryTopRightArea` → the exact unobscured rectangles flanking the notch; the gap between them *is* the notch width. This is how you size and center the panel precisely.
- Recompute on `NSApplication.didChangeScreenParametersNotification` (resolution change, external display, clamshell) — owned by `AppDelegate`/`NotchGeometry`.

---

## Animation / Transition System

- **One view tree → SwiftUI does the heavy lifting.** Because content swaps inside a single root, expand→collapse and activity-switching are just state changes wrapped in `withAnimation(.spring(...))`.
- **`matchedGeometryEffect`** for the signature Dynamic-Island morph (pill grows into a panel; album art slides from the strip into the expanded view).
- **`.transition(.asymmetric(...))`** for activity content appearing/disappearing.
- **The panel's *frame* animates too**, not just its content — the window itself resizes/repositions to follow the expanded shape. Drive the panel frame from `IslandState` so window size and view size stay in lockstep. (DynamicNotch exposes "interactive resize" through its `NotchViewModel` for exactly this.)
- Spring parameters are *the* place polish lives (the Alcove bar). Flag for design iteration, not a one-shot.

---

## Suggested Build Order (dependency-ordered, beginner-first)

Each step produces something **visible and runnable** before the next. This is the spine-first strategy: ship an empty island, then layer features as independent leaves.

```
0. Agent shell        → MenuBarExtra app, LSUIElement, "Quit" works.  (no overlay yet)
1. The empty island   → NotchPanel over the notch: a static black rounded pill.  ★ visible win
2. Geometry           → NotchGeometry centers/sizes the pill exactly on the notch,
                        survives screen changes / external display / clamshell.
3. Hover + expand     → IslandState(.idle/.expanded) + hover detection; pill grows
                        on hover with a spring. (still no real data — placeholder content)
4. NowPlayingService  → first real feature: music shows in the strip; hover = full
                        controls + art; play/pause/skip work.  ★ the core value
5. PowerService       → charging splash: plug in → transient charging animation → collapse.
6. BluetoothService   → device-connected/disconnected splash (reuses the transient pattern).
7. Priority resolver  → tune arbitration + transient durations so 4/5/6 coexist nicely.
8. Settings + launch-at-login → MenuBarExtra settings, SMAppService toggle, persistence.
   ──────── v1 ships here ────────
9+. Later leaves      → File shelf, HUDs, Timer — each = new Service + View + ActivityKind
                        case. Spine untouched.
```

**Why this order (the dependencies):**
- **Steps 0–3 are pure scaffolding with zero private APIs.** The beginner gets a real, on-screen island and learns the window/state/view loop *before* touching the fragile MediaRemote piece. Confidence + a debuggable foundation first.
- **Now Playing (4) is intentionally the first feature** because it's the core value *and* it exercises the full up-and-down data path (services push facts up, commands go down). Everything after reuses that proven path.
- **Power (5) and Bluetooth (6) are the easy transient pattern** — once Now Playing's wiring exists, these are small, near-identical additions. Doing them after Now Playing means the transient/priority machinery has a real ambient state (music) to arbitrate against.
- **Priority resolver (7) comes after all three sources exist** because you can't tune arbitration with nothing to arbitrate.
- **Later features (9+) require zero changes to steps 0–8** — that's the whole point of the service/leaf structure.

---

## Anti-Patterns

### Anti-Pattern 1: Letting views talk to system APIs directly
**What people do:** Put `IOPSCopyPowerSourcesInfo` or MediaRemote calls inside a SwiftUI `View`.
**Why it's wrong:** The view re-runs constantly; you leak IOKit objects, can't test, and when Apple breaks MediaRemote (they did in 15.4) the damage is smeared across the UI instead of contained in one file.
**Do this instead:** All system access lives in a `Service`; views read `IslandState` only.

### Anti-Pattern 2: Creating/destroying windows to switch activities
**What people do:** Make a new panel for "now playing", another for "charging".
**Why it's wrong:** Flicker, lost animations, focus/space bugs, expensive. Kills the morphing animation that defines a Dynamic Island.
**Do this instead:** One panel, one root view, state-driven content (Pattern 1).

### Anti-Pattern 3: Putting arbitration logic in the services
**What people do:** `PowerService` checks "is music playing?" before deciding to show.
**Why it's wrong:** Services now know about each other; priority logic is scattered; impossible to reason about. Services should be ignorant of one another.
**Do this instead:** Services only report *their own* facts. Only `IslandState.resolve()` decides who wins.

### Anti-Pattern 4: `.stationary` collection behavior / wrong window level
**What people do:** Copy a generic floating-window snippet using `.stationary` or `.normal` level.
**Why it's wrong:** The island vanishes when you switch Spaces or enter full-screen, and can hide under the menu bar.
**Do this instead:** `.canJoinAllSpaces + .fullScreenAuxiliary`, level `.statusBar`/`.floating`, non-activating panel.

### Anti-Pattern 5: Assuming Now Playing "just works"
**What people do:** Link MediaRemote, call `MRMediaRemoteGetNowPlayingInfo`, ship.
**Why it's wrong:** On macOS 15.4+ Apple added entitlement checks; un-entitled apps get `nil`. This *will* bite mid-project.
**Do this instead:** Plan from day one for the `mediaremote-adapter` (bundled perl) workaround; isolate it behind `NowPlayingService` so a future fix swaps one file. (See Integration Points.)

---

## Integration Points

### External / System Services

| Source | Integration Pattern | Notes / Gotchas |
|--------|---------------------|-----------------|
| **MediaRemote** (Now Playing) | Private framework, accessed via **`mediaremote-adapter`** (ungive) — a bundled `/usr/bin/perl` script + helper framework that streams now-playing JSON to stdout | macOS **15.4+ blocks** direct un-entitled access (returns nil). The perl-adapter is the proven, SIP-free workaround used by current apps (TheBoringNotch ships a `mediaremote-adapter`). **Blocks Mac App Store** (already a project decision). Version-fragile → isolate behind `NowPlayingService`. **MEDIUM confidence** — verify against current macOS at build time. |
| **IOKit power** (charging/battery) | `IOPSCopyPowerSourcesInfo` + `IOPSCopyPowerSourcesList` + `IOPSGetPowerSourceDescription`; live updates via `IOPSNotificationCreateRunLoopSource` | Public, stable API. Distinguish "AC connected" (`IOPSCopyExternalPowerAdapterDetails`) from "actively charging" (`kIOPSIsChargingKey`). Handle Macs with no battery. Use `takeUnretainedValue()` per Apple docs. **HIGH confidence.** |
| **IOBluetooth** (device connect/disconnect) | `IOBluetoothDevice.register(forConnectNotifications:selector:)` and `register(forDisconnectNotification:selector:)` → return `IOBluetoothUserNotification` (call `unregister` to stop) | Selector gets `(notification, device)`. Register for *connect* globally, then register *disconnect* on each connected device. Needs `com.apple.security.device.bluetooth` entitlement. **HIGH confidence.** |
| **NSScreen** (notch geometry) | `safeAreaInsets`, `auxiliaryTopLeftArea/RightArea`; observe `didChangeScreenParametersNotification` | Public, stable (macOS 12+). Recompute on every screen-config change. **HIGH confidence.** |
| **Launch at login** | `SMAppService.mainApp.register()` (modern) or write a LaunchAgent plist | SMAppService is the current API; default OFF with an explicit user toggle (App Review guideline). **HIGH confidence.** |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| Service → `IslandState` | Service calls a method / fires a closure with a clean domain struct | One-way *up*. Service never references views. |
| `IslandState` → Views | SwiftUI `@Published` / `@EnvironmentObject` subscription | One-way *up*. Views only read. |
| View → Service | Command call (play/pause), the **only** downward path | Routed via `IslandState` or an injected closure, not a global. |
| `AppDelegate` ↔ `NotchWindowController` | Direct ownership; delegate creates controller at launch | Composition root: where services + state + window get wired together. |
| `NotchGeometry` → `NotchPanel` | Geometry computes frame; controller applies it | Re-runs on screen-param change. |

---

## Scaling Considerations

This is a single-user desktop utility — "scaling" means *features and macOS versions*, not users.

| Axis | Adjustment |
|------|------------|
| More activities (shelf/HUD/timer) | Already handled: add a Service + View + `ActivityKind` case. The spine doesn't change. This is the architecture's main design goal. |
| macOS version drift | The fragile surface is **only** MediaRemote. Keeping it behind `NowPlayingService` means a future Apple change is a one-file fix. Power/Bluetooth/NSScreen are public and stable. |
| Non-notch Macs (out of scope for v1) | DynamicNotchKit/TheBoringNotch handle this by falling back to a `.floating` simulated pill. The same `NotchGeometry` boundary is where you'd add it later — no other layer cares. |
| CPU/battery | One window + push-based services (no polling) keeps it cheap; TheBoringNotch reports <2% CPU. Avoid timers that poll system state; use the notification/run-loop sources above. |

---

## Sources

- TheBoringNotch — TheBoredTeam/boring.notch (open-source reference; module layout: `boringNotch`, `mediaremote-adapter`, XPC helper): https://github.com/TheBoredTeam/boring.notch — **HIGH** (named project reference)
- DynamicNotch — jackson-storm (NotchEngine / NotchViewModel / NotchEventCoordinator + `Features/` folder pattern): https://github.com/jackson-storm/DynamicNotch — **HIGH**
- DynamicNotchKit — MrKai77 (one `DynamicNotch` container, SwiftUI-hosted, async expand/collapse): https://github.com/MrKai77/DynamicNotchKit — **HIGH**
- Apple — `NSScreen.safeAreaInsets`: https://developer.apple.com/documentation/appkit/nsscreen/safeareainsets — **HIGH**
- Apple — `NSScreen.auxiliaryTopLeftArea`: https://developer.apple.com/documentation/AppKit/NSScreen/auxiliaryTopLeftArea-uglc — **HIGH**
- Apple — `IOBluetoothUserNotification` / `register(forConnectNotifications:selector:)`: https://developer.apple.com/documentation/iobluetooth/iobluetoothusernotification — **HIGH**
- Apple — `MenuBarExtra`: https://developer.apple.com/documentation/SwiftUI/MenuBarExtra — **HIGH**
- Apple Dev Forums — Mac charging detection via IOKit.ps (`IOPSGetPowerSourceDescription`, `kIOPSIsChargingKey`): https://developer.apple.com/forums/thread/128048 — **HIGH**
- ungive/mediaremote-adapter — perl-based MediaRemote workaround for macOS 15.4+: https://github.com/ungive/mediaremote-adapter — **MEDIUM** (private-API workaround, version-fragile)
- TheAppleWiki — MediaRemote.framework (Now Playing notifications): https://theapplewiki.com/wiki/Dev:MediaRemote.framework — **MEDIUM**
- SwiftUI Floating Panel / NSPanel patterns (borderless, non-activating, collectionBehavior, NSHostingView): https://fazm.ai/blog/swiftui-floating-panel — **MEDIUM** (verified against Apple AppKit docs)
- nilcoalescing — macOS menu-bar utility + launch-at-login (SMAppService): https://nilcoalescing.com/blog/LaunchAtLoginSetting/ — **MEDIUM**

---
*Architecture research for: native macOS notch / Dynamic-Island utility app*
*Researched: 2026-06-26*
