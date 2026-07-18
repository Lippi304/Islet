# Architecture Research: Favorite + Audio-Output Integration (v1.7 candidate scope)

**Domain:** Native macOS notch overlay app (Islet) — integrating a "favorite song" write-back and an audio-output switcher into the existing Now Playing expanded view.
**Researched:** 2026-07-19
**Confidence:** MEDIUM overall — HIGH for the integration points (grounded in direct codebase reads); MEDIUM/LOW for the two external-API questions (whether the vendored MediaRemote adapter can send a like/favorite command, and whether it reports read-state), both flagged as spike-required rather than assumed.

## Standard Architecture (as it exists today — the seam this work extends)

### System Overview

```
┌───────────────────────────────────────────────────────────────────────┐
│  SYSTEM GLUE (one fragile surface = one file)                         │
│  NowPlayingMonitor (MediaRemoteAdapter)   VolumeReader (CoreAudio)    │
│  BluetoothMonitor (IOBluetooth)           OSDInterceptor (CGEventTap) │
├───────────────────────────────────────────────────────────────────────┤
│  PURE PRESENTATION SEAMS (Foundation-only, unit-tested)               │
│  NowPlayingPresentation.swift   OSDActivity.swift   DeviceCoordinator │
├───────────────────────────────────────────────────────────────────────┤
│  THE ONE ARBITER                                                       │
│  IslandResolver.swift → resolve() → IslandPresentation (enum)         │
│  TransientQueue (Charging > Device > Focus > OSD, ambient NowPlaying) │
├───────────────────────────────────────────────────────────────────────┤
│  CONTROLLER (AppKit)                                                   │
│  NotchWindowController — owns monitors, calls resolve(), writes       │
│  IslandPresentationState.presentation, sizes the NSPanel, click-through│
├───────────────────────────────────────────────────────────────────────┤
│  RENDER-ONLY VIEW (SwiftUI)                                            │
│  NotchPillView.presentationSwitch → mediaExpanded(...) etc.           │
└───────────────────────────────────────────────────────────────────────┘
```

The whole codebase enforces one rule everywhere: **the view never decides, the resolver never touches AppKit, and every fragile system framework gets exactly one glue file.** Both new features slot into this without adding a new architectural layer.

### Component Responsibilities (existing, relevant to this milestone)

| Component | Responsibility | File |
|-----------|-----------------|------|
| `NowPlayingMonitor` / `NowPlayingService` | ONLY file touching `MediaRemoteAdapter`; streams track snapshots, exposes `togglePlayPause()`/`nextTrack()`/`previousTrack()` | `Islet/Notch/NowPlayingMonitor.swift` |
| `VolumeReader` (free functions, no class) | Stateless CoreAudio reads/writes for the *default* device only — `readSystemVolume()`, `adjustSystemVolume()`, `toggleSystemMute()`, called on-demand by `OSDInterceptor`/key-press handling, never pushes updates itself | `Islet/Notch/VolumeReader.swift` |
| `IslandResolver.resolve()` | Pure reducer, the ONE arbiter of what the island shows | `Islet/Notch/IslandResolver.swift` |
| `IslandPresentationState` | `@Published` verdict + a couple of controller-computed **sibling** UI-state fields (`hoveredQuickActionButtonIndex`, `secondary`) that do NOT participate in the `IslandPresentation` enum itself | `Islet/Notch/IslandPresentationState.swift` |
| `NotchWindowController` | Owns every monitor's lifecycle, calls `resolve()`, sizes the `NSPanel` via a union of every presentation's max frame ("geometry three-site rule" — see below), computes click-through hit zones | `Islet/Notch/NotchWindowController.swift` |
| `NotchPillView.mediaExpanded(_:art:)` | Renders the Now Playing expanded card: art+title/artist+bars row, `ProgressBar`, then a fixed `HStack(spacing: 0)` control row with **two already-reserved 28×28 `Color.clear` slots** (left = "future Shuffle", right = "future Repeat") flanking the 3 real `TransportButton`s | `Islet/Notch/NotchPillView.swift:2731-2805` |

**Load-bearing existing fact:** `mediaExpanded`'s control row is `HStack(spacing: 0) { Color.clear(28×28) · ⏪ · ⏯ · ⏩ · Color.clear(28×28) }`. The left slot was explicitly reserved for a future "Shuffle" and the right for "Repeat"; the comment at the top of `mediaExpanded` (D-09) says outright: *"The Star/favorite is DROPPED entirely (no slot — D-09)."* That decision predates this milestone and should be explicitly reversed, not silently worked around — the left reserved slot is exactly where the star belongs by the milestone's own spec ("left of transport controls"), and the right reserved slot is exactly where the speaker icon belongs ("right of transport controls"). This is a near-zero-geometry win: **no new horizontal space, no new `blobShape` width math** — just two `Color.clear` frames becoming two real buttons of the identical 28×28 footprint `TransportButton`'s style already uses.

## Recommended Integration

### New/Modified Files

```
Islet/Notch/
├── NowPlayingMonitor.swift          # MODIFY: extend NowPlayingService protocol
├── NowPlayingPresentation.swift     # MODIFY: add isFavorite to TrackSnapshot/NowPlayingPresentation (pure seam)
├── AudioOutputMonitor.swift         # NEW: event-driven CoreAudio device-list glue (mirrors BluetoothMonitor's shape)
├── AudioOutputPresentation.swift    # NEW: pure seam — AudioOutputDevice value type + sort/reorder logic (mirrors NowPlayingPresentation.swift's Pattern 1 discipline)
├── NotchWindowController.swift      # MODIFY: start/stop AudioOutputMonitor, wire favorite toggle + output-panel state, extend geometry union + visibleContentZone()
├── NotchPillView.swift              # MODIFY: mediaExpanded's two reserved slots become real buttons; new outputPanel(...) subview; new content-height constant
IsletTests/
├── AudioOutputPresentationTests.swift  # NEW: pure seam unit tests (device sort/reorder, default-device mapping)
```

Nothing here needs a new top-level folder — both features are extensions of the existing `Islet/Notch/` module, matching every prior HUD phase (39, 41, 42) that added exactly one new Monitor + one new pure seam file inside the same directory.

### Structure Rationale

- **`Islet/Notch/`** stays the single home for anything driving the island's own state — the project has never split "Now Playing" and "system HUD" concerns into separate modules even though they're conceptually different (Phase 39 added `OSDActivity`/`VolumeReader`/`OSDInterceptor` right alongside `NowPlayingMonitor` without a new folder). No reason to deviate here.
- **`AudioOutputMonitor.swift` is a NEW file, not an extension of `VolumeReader.swift`** — see Pattern 2 below for why.
- **Favorite status is NOT a new file** — it is 2-3 lines added to the *existing* `NowPlayingMonitor`/`NowPlayingService` seam, because it is the same fragile bridge, same lifecycle, same "one file, one system surface" boundary. Splitting it into `FavoriteService.swift` would duplicate the MediaRemote plumbing for no isolation benefit (see Pattern 1).

## Architectural Patterns

### Pattern 1: Favorite does NOT need its own isolated service — it extends `NowPlayingService`

**What:** Add `func toggleFavorite()` (and a `isFavorite: Bool?` reported through the existing snapshot) to the *same* `NowPlayingService` protocol and `NowPlayingMonitor` class that already owns transport control.

**Why not a new isolated service (the question's premise doesn't hold up against the code):** The project's isolation rule ("isolate all now-playing code behind one Swift protocol/service") exists because MediaRemote is ONE fragile private bridge that can break as a unit — the isolation boundary is *the bridge*, not *the feature*. `togglePlayPause()`/`nextTrack()`/`previousTrack()` already live together in `NowPlayingMonitor` precisely because they all ride the same persistent adapter child's stdin (see `NowPlayingMonitor.swift:93-96`). A `MRMediaRemoteCommandLikeTrack`/`MRMediaRemoteCommandDislikeTrack` favorite toggle (confirmed to exist at the private-API level — see Sources) is just a 4th command on the exact same channel. Creating a second protocol/class for it would duplicate the child-process lifecycle, the health-check, and the `@MainActor` discipline `NowPlayingMonitor` already solved — a second isolation seam around the *same* risk is redundant isolation, not defense in depth.

**Concrete verified fact:** the private `MRMediaRemoteCommand` enum (theos/headers, `MediaRemote.h`) DOES include `MRMediaRemoteCommandLikeTrack`, `MRMediaRemoteCommandDislikeTrack`, `MRMediaRemoteCommandRateTrack`, and `MRMediaRemoteCommandBookmarkTrack` — so a "like" affordance is a real, existing private command, not something Islet would have to invent. **Unverified (spike-required):** whether the *vendored* Swift wrapper (`ejbills/mediaremote-adapter`'s `MediaController`) exposes sending this command at all — the project only confirmed `togglePlayPause`/`nextTrack`/`previousTrack`/`getTrackInfo` are wrapped; `like`/`favorite` was not found documented anywhere in the wrapper's public surface during this research pass. This is the same kind of unknown Phase 38 (Focus Mode Path A vs B) and Phase 39 (OSD suppression tap type) hit, and this project's own convention is to resolve it with a cheap on-device spike before committing to a plan, not to guess.

**Fallback if the wrapper doesn't expose it:** `MediaController` is a thin Swift wrapper around a stdin/stdout JSON protocol talking to the perl-hosted MediaRemote bridge (see `mediaremote-adapter`'s own README) — worst case, the fix is adding one more command string to the wrapper's own command-dispatch table (a contained change, still inside the one `NowPlayingMonitor.swift` isolation boundary, never spreading into `NotchPillView`/`IslandResolver`).

**Also worth flagging:** liked-status needs to be *read*, not just written — the star's fill state must reflect whether the current track is already favorited. Confirm during the spike whether `getTrackInfo`/the streamed payload carries an `isFavorite`/`isLiked`/`isRated` field at all (this is the "does the platform even tell us" question, independent of whether we can toggle it). If MediaRemote exposes no read-side signal, the star can only be a write-only fire-and-forget action (tap → send the command → optimistically flip local UI state for the session) — a materially smaller, still-valuable feature. This distinction changes the plan's scope and must be resolved before implementation, not discovered mid-execution.

**Example (grounded in the real file):**
```swift
// NowPlayingMonitor.swift — protocol grows by one method + one snapshot field,
// the isolation boundary (this ONE file) does not move.
protocol NowPlayingService: AnyObject {
    func start()
    nonisolated func stop()
    func togglePlayPause()
    func nextTrack()
    func previousTrack()
    func toggleFavorite()                      // NEW — same child, same stdin channel
    func runHealthCheck(then setHealthy: @escaping (Bool) -> Void)
}

// TrackSnapshot (NowPlayingPresentation.swift, the PURE seam) grows one Optional field —
// nil means "platform didn't report a rating state", matching every other Optional-field
// precedent in this struct (durationMicros, elapsedTimeMicros, etc.):
struct TrackSnapshot: Equatable {
    // ...existing fields...
    var isFavorite: Bool? = nil   // nil = unknown/unsupported, not "not favorited"
}
```

### Pattern 2: Audio-output switching DOES need a new dedicated Monitor — it cannot extend `VolumeReader`

**What:** A new `AudioOutputMonitor` (event-driven class, `@MainActor`, `start()`/`stop()` lifecycle) rather than adding functions to `VolumeReader.swift`.

**Why `VolumeReader` is the wrong host:** `VolumeReader.swift`'s own header comment is explicit about its shape — "thin CoreAudio glue... **no equivalent stored state** — it is called directly inline" (confirmed live in `NotchWindowController.swift:241`). It is a bag of *stateless, pull-based* free functions: something else (a key-press) triggers a read, there is no persistent object, no listener registration, no `@Published`. Device switching needs the opposite shape:
1. **A live, continuously-current device list** (built-in speakers, AirPods, USB DAC, etc.) that can change at any time — plugging in headphones, an AirPods disconnect — none of which is a "volume key was pressed" event `VolumeReader` is built around.
2. **CoreAudio property *listeners*** (`AudioObjectAddPropertyListener` on `kAudioHardwarePropertyDevices` for add/remove, and `kAudioHardwarePropertyDefaultOutputDevice` for external changes, e.g. the user switches via the menu bar) — a genuinely event-driven registration/callback lifecycle, structurally identical to `BluetoothMonitor`'s `register(forConnectNotifications:)`/`register(forDisconnectNotification:)` pattern, not to `VolumeReader`'s "read on demand" pattern.
3. **A live current-volume readout while the panel is open** (the milestone spec: "revealing a volume slider") — this DOES reuse `readSystemVolume()`/`adjustSystemVolume()` as-is (they already operate on whatever is the current default device, which is exactly right — no change needed there), but the device-list and default-device-changed concerns are new state `VolumeReader` was deliberately never given.

Bolting listener registration and `@Published` device-list state onto `VolumeReader` would turn a "one fragile surface, one file, stateless" file into two different things wearing one name — the same shape mismatch the project already avoided once (`OSDActivity.swift`'s header explicitly separates the *pure mapping* from the *system glue*, and `BluetoothMonitor` vs `DeviceCoordinator` shows the same split for a live-list system: the raw event source is its own file, its own class, with its own lifecycle).

**Public API, not private — no protocol-isolation needed, only file-isolation:** unlike MediaRemote, everything `AudioOutputMonitor` needs (`kAudioHardwarePropertyDevices`, `kAudioHardwarePropertyDefaultOutputDevice`, `AudioObjectSetPropertyData` to switch it, `AudioObjectAddPropertyListener`) is public, documented CoreAudio — the same public framework `VolumeReader` already uses for reads/writes. This means `AudioOutputMonitor` does NOT need a `NowPlayingService`-style protocol seam (no "Apple will break this" risk in the same class as the private MediaRemote bridge) — it only needs its own file per the project's general "one system surface, one file" convention (which `VolumeReader`, `BrightnessReader`, `BluetoothMonitor`, `FocusModeMonitor` all already follow regardless of public/private API status). A protocol IS still worth adding if/when unit tests need to fake device lists (mirrors `NowPlayingService`'s testability motivation more than its risk-isolation motivation) — an `AudioOutputProviding` protocol is a cheap, optional addition, not a hard requirement like it is for MediaRemote.

**Example (mirrors `BluetoothMonitor`'s real shape):**
```swift
// AudioOutputMonitor.swift — NEW, event-driven, mirrors BluetoothMonitor.swift's shape
// (register → callback → hand off pure values, no @Published/SwiftUI in this file).
@MainActor
final class AudioOutputMonitor: NSObject {
    private let onDevicesChanged: ([AudioOutputDevice]) -> Void
    // AudioObjectID-typed listener blocks/tokens stored here, mirroring
    // BluetoothMonitor's connectToken/disconnectTokens dictionary.

    func start() {
        // AudioObjectAddPropertyListenerBlock on kAudioHardwarePropertyDevices
        // AND kAudioHardwarePropertyDefaultOutputDevice, both scoped to
        // kAudioObjectPropertyScopeGlobal — fires onDevicesChanged(currentDevices())
        // on either event.
    }
    nonisolated func stop() { /* remove listeners */ }

    func setDefaultOutput(_ device: AudioOutputDevice) {
        // AudioObjectSetPropertyData(systemObject, kAudioHardwarePropertyDefaultOutputDevice, ...)
        // — reuses defaultOutputDeviceID()'s exact property-address pattern from VolumeReader.swift,
        // just targeting a different selector/write instead of a read.
    }
}

// AudioOutputPresentation.swift — NEW pure seam, Foundation-only, mirrors
// NowPlayingPresentation.swift's discipline exactly:
struct AudioOutputDevice: Equatable, Identifiable {
    let id: AudioDeviceID
    let name: String
    let isDefault: Bool
}
```

### Pattern 3: The output panel is local, controller-visible view state — NOT a new `IslandPresentation` resolver case

**What:** A boolean "is the output panel open" flag that toggles an inline reveal below the transport row, inside the *existing* `.nowPlayingExpanded` presentation.

**Why NOT a resolver case:** `IslandResolver.resolve()` exists to arbitrate **competing top-level activities** (Charging vs Device vs Focus vs OSD vs Now Playing vs Calendar). The output panel is not a competing activity — it's a disclosure state *within* the Now Playing card, exactly the same category as `hoveredQuickActionButtonIndex` (Phase 34) or the secondary-bubble hover/darken state (Phase 42), both of which are explicitly kept OFF the `IslandPresentation` enum and instead live as sibling fields. Making it a resolver case would force `resolve()` to know about it, would make Charging/Device transients incorrectly interrupt it (transients always win per `resolve()`'s `switch activeTransient` block — correct for that, wrong for "user has the output picker open," which should probably survive a brief charging blip the same way the switcher tab selection does), and would multiply `IslandPresentation`'s already-19-case switch for a piece of state that only matters inside one case.

**Where it should actually live — NOT purely `@State` in the view, contra the question's own framing:** the question's example ("purely local view state, like the drag-hover highlight in the Quick Action picker") is a slight mis-description of the actual precedent — `hoveredQuickActionButtonIndex` is NOT plain SwiftUI `@State`; it is a controller-computed `@Published` field on `IslandPresentationState` (`IslandPresentationState.swift:24`), written by `NotchWindowController` and only ever *read* by the view. The real reason it must be controller-visible: **`visibleContentZone()` (the click-through hit-test geometry, AppKit-side) must also know whether the panel is open**, because opening it grows the visible blob height and the click-through region must grow with it (exactly the same reasoning that made `shelfStripVisible`/`showsSwitcherRow` controller-visible instead of view-local). Plain `@State` inside `NotchPillView` would be invisible to `NotchWindowController`, silently reproducing the CR-01 click-through bug class the project has already hit twice (Phase 20, Phase 40).

**Recommended shape:** a new small `@Published var outputPanelOpen: Bool = false` on `IslandPresentationState` (or a tiny sibling `ObservableObject`, mirroring `ViewSwitcherState`'s "one flag, one file" precedent if it's cleaner to keep Now-Playing-specific state out of the shared presentation object) — written by a closure the view calls on tap (`onToggleOutputPanel: () -> Void`, exactly mirroring the existing `onSwitcherSelect`/`onShelfItemTap` closure-forwarding convention already used throughout `NotchPillView`'s init), handled by a new `NotchWindowController.handleToggleOutputPanel()` which flips the flag and re-runs the same panel-resize path `handleSwitcherSelect` already triggers.

**The output device *list drag-reorder* interaction (dragging a device to the top = switch active output), by contrast, IS purely local, ephemeral view state** — the drag-in-progress hover position doesn't need to survive outside the gesture and doesn't affect click-through geometry (the panel's already-open bounding box doesn't change size while reordering within it) — a plain `@State` `draggedDeviceID`/`dropTargetIndex` in the output-panel subview is correct and directly mirrors `TransportButton`'s own local `@State private var isHovering`.

**Trade-off:** this is one more controller round-trip than a pure-SwiftUI `@State` toggle would need, but it is the only shape that keeps `NotchWindowController` (the authority on click-through hit-testing) and the view in agreement — the exact invariant CR-01 was a regression of.

## Data Flow

### Favorite toggle flow

```
User taps ★ (left reserved slot, mediaExpanded)
    ↓
NotchPillView calls onToggleFavorite() closure
    ↓
NotchWindowController.handleToggleFavorite() → nowPlayingMonitor?.toggleFavorite()
    ↓
NowPlayingMonitor sends MRMediaRemoteCommandLikeTrack over the SAME persistent
adapter child's stdin togglePlayPause() already uses (no re-spawn)
    ↓
(if the platform reports rating state) next onTrackInfoReceived snapshot carries
isFavorite — flows through TrackSnapshot → NowPlayingPresentation (pure seam,
unit-testable) → re-rendered star fill state
    ↓
(if the platform does NOT report rating state) star flips optimistically in
local/controller state only, for this session — a write-only affordance
```

### Audio output switch flow

```
AudioOutputMonitor (event-driven, CoreAudio listeners)
    ↓ onDevicesChanged([AudioOutputDevice])
NotchWindowController stores the live list (mirrors deviceCoordinator's role,
or a plain @Published on a new tiny AudioOutputViewState mirroring ViewSwitcherState)
    ↓
User taps speaker icon (right reserved slot) → onToggleOutputPanel()
    ↓
NotchWindowController flips IslandPresentationState.outputPanelOpen = true,
re-runs positionAndShow()'s frame math (panel already reserves the max height
up front — "geometry three-site rule", see below — so this is instant, no live resize)
    ↓
NotchPillView renders outputPanel(devices:) below the transport row: an
OSDLevelBar-style volume slider (reuses readSystemVolume()/adjustSystemVolume()
verbatim — same default device, no AudioOutputMonitor involvement) + a
reorderable list of AudioOutputDevice
    ↓
User drags a device to the top (local view @State drag gesture, mirrors
ShelfItemView's onDragStarted precedent)
    ↓
On drop-at-top: onSelectOutputDevice(device) closure → NotchWindowController
→ audioOutputMonitor.setDefaultOutput(device) → CoreAudio kAudioHardwarePropertyDefaultOutputDevice set
    ↓
AudioOutputMonitor's own listener fires (its OWN write triggers the system
notification loopback) → onDevicesChanged re-delivers the list with the new
isDefault flag → list re-sorts to match (list order IS the "is default" signal,
not a separate boolean the UI could drift out of sync with)
```

### The "geometry three-site rule" (this project's own established convention — name it, don't rediscover it)

Every prior taller-content addition (Tray/Phase 32, Weather/Phase 33, Quick Action Picker/Phase 34) required touching the SAME three places, and `NotchWindowController.swift`'s own comments literally call this pattern out at each site ("mirroring trayFrame/weatherExpandedFrame's precedent exactly"). The output panel reveal must touch all three or it WILL repeat a shipped-and-fixed bug class (Weather's round-3 UAT clip, CR-01's click-through gap):

1. **`NotchPillView.blobShape`'s `height:` argument** — `mediaExpanded` needs a new content-height constant when the panel is open (e.g. `homeContentHeightWithOutputPanel`), passed conditionally based on the new `outputPanelOpen` flag — mirrors `weatherMediumContentHeight`/`weatherLargeContentHeight`'s two-tier precedent exactly (same file, same technique, just a 2nd tier of `homeContentHeight` instead of a 2nd tier of the weather height).
2. **`NotchWindowController`'s panel-frame union** (`positionAndShow`, ~line 984) — reserve the taller height **unconditionally up front**, same as every existing union member (`trayFrame`, `weatherExpandedFrame`, `quickActionPickerFrame`) — the panel is sized once to the max of everything so no live NSPanel resize ever races the SwiftUI spring morph. Check first whether `switcherContentHeight` (196pt) already exceeds `homeContentHeight` (170pt) plus the panel's real added content — if the panel is short enough to fit inside 196, this union member may need NO change at all (a real possibility worth checking before adding a new one, since `switcherContentHeight` already reserves generously for the tallest switcher-row case).
3. **`visibleContentZone()`** — the click-through hit-test branch for `.nowPlayingExpanded` must grow its returned rect when `outputPanelOpen` is true, using the SAME boolean the view's `blobShape` call reads, or the panel will render but be unclickable/click-through-broken past its old bounds (exactly CR-01's original failure mode).

## Anti-Patterns to Avoid

### Anti-Pattern 1: Giving Favorite its own protocol/service class "because it's private-API-adjacent too"

**What people would do:** Create `FavoriteService.swift` with its own protocol, mirroring `NowPlayingService` 1:1, out of an instinct that "private API risk = new isolation boundary."
**Why it's wrong:** It's the SAME bridge, same process, same risk surface as transport control, which already lives in `NowPlayingMonitor`. A second seam around the identical risk adds a second thing to keep in sync with zero added safety — if MediaRemote breaks, it breaks `NowPlayingMonitor` and `FavoriteService` on the exact same day, and now there are two files' health-check/lifecycle code to fix instead of one.
**Do this instead:** One method + one field on the existing `NowPlayingService`/`NowPlayingMonitor`/`TrackSnapshot`, per Pattern 1.

### Anti-Pattern 2: Making the output-device list part of `IslandPresentation`

**What people would do:** Add a `case audioOutputExpanded([AudioOutputDevice])` to `IslandPresentation`, treating it like Tray/Calendar/Weather's own dedicated resolver cases.
**Why it's wrong:** Tray/Calendar/Weather are *whole-tab* destinations reached via the switcher row — genuinely competing top-level content. The output panel is a *disclosure within* Now Playing, never reachable except from there, and must NOT out-rank or get pre-empted by Charging/Device the way real resolver cases correctly do. Folding it into the resolver would also force `resolve()`'s already-large switch to know about audio hardware state, breaking the "resolver only arbitrates competing activities" invariant.
**Do this instead:** Sibling `@Published` boolean on `IslandPresentationState` (or a tiny dedicated state object), per Pattern 3 — read by `mediaExpanded`'s own body, invisible to `resolve()`.

### Anti-Pattern 3: Extending `VolumeReader.swift` with device-list functions "since it's already CoreAudio"

**What people would do:** Add `listOutputDevices()`/`setDefaultOutputDevice()` as more free functions in `VolumeReader.swift`, since it already imports CoreAudio and has `defaultOutputDeviceID()`.
**Why it's wrong:** `VolumeReader` is deliberately stateless and pull-based (no listeners, no lifecycle, called synchronously from `OSDInterceptor`'s key-press handler). Device enumeration + live add/remove/default-changed tracking is a fundamentally different, event-driven shape — cramming it in produces a file that's neither a clean "stateless reader" nor a clean "event-driven monitor," and it would be the first file in the project to mix those two shapes.
**Do this instead:** New `AudioOutputMonitor.swift`, event-driven class, mirrors `BluetoothMonitor`'s shape — per Pattern 2. `VolumeReader`'s existing functions are reused UNCHANGED for the volume-slider part of the panel (they already operate correctly on "whatever the current default device is").

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| MediaRemote `MRMediaRemoteCommandLikeTrack`/`DislikeTrack` (private, via `mediaremote-adapter`) | Extend existing `NowPlayingMonitor`'s `MediaController` calls | Command's existence confirmed at the framework level (theos headers); whether the vendored Swift wrapper exposes sending it is UNVERIFIED — spike first (see Pattern 1) |
| CoreAudio `kAudioHardwarePropertyDevices` / `kAudioHardwarePropertyDefaultOutputDevice` (public) | New `AudioObjectAddPropertyListener` registration in `AudioOutputMonitor` | Public, documented, same framework `VolumeReader` already links — low risk relative to MediaRemote, still gets its own file per the "one system surface, one file" convention |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| `NowPlayingMonitor` ↔ `NotchWindowController` | Injected closures (`onSnapshot`, `onTerminated`), extend with the existing pattern — no new channel needed for favorite | Matches `togglePlayPause()`'s existing call shape exactly |
| `AudioOutputMonitor` ↔ `NotchWindowController` | Injected closure (`onDevicesChanged`), mirrors `BluetoothMonitor`'s `{ [weak self] reading in ... }` init pattern | New monitor, started/stopped in `NotchWindowController.start()`/lifecycle alongside the others |
| `NotchPillView.mediaExpanded` ↔ `NotchWindowController` | New closures: `onToggleFavorite`, `onToggleOutputPanel`, `onSelectOutputDevice`, `onVolumeChange` — forwarded exactly like `onPrevious`/`onTogglePlayPause`/`onNext` already are | No new communication mechanism, just 4 more entries in the same closure-forwarding convention |
| `visibleContentZone()` ↔ `blobShape`'s `height:` | Both must read the SAME `outputPanelOpen` boolean | The exact invariant CR-01 broke once already — do not let the two branches be computed independently |

## Suggested Build Order (mirrors this project's own risk-isolation precedent)

This project's established pattern (Phase 19→22 shelf: model → view → drag-out → risky drag-in isolated last; Phase 38→39: new resolver case proven with a safe activity type BEFORE the high-risk suppression mechanism) is: **prove the pure/safe seams first, isolate the one genuinely uncertain external-API question into its own small, spike-able step, and don't let it block the rest.**

1. **Pure seams first, no system framework touched:** `AudioOutputPresentation.swift` (device value type + sort/reorder pure functions) and the `TrackSnapshot.isFavorite`/`NowPlayingPresentation` field addition — both unit-testable in milliseconds, zero on-device risk, matches every phase's Plan-01 precedent in this codebase.
2. **The safe, public-API monitor:** `AudioOutputMonitor` (CoreAudio device enumeration + listeners + `setDefaultOutput`) — public framework, same risk tier as `VolumeReader`/`BrightnessReader`, no spike needed, just careful `AudioObjectPropertyAddress` plumbing (this project already has 2 working examples to copy from, `VolumeReader.swift` and `BrightnessReader.swift`).
3. **UI wiring for the output panel + volume slider + reorder list**, using the two Anti-Pattern-avoiding integration points above (sibling `@Published` panel-open flag, local `@State` drag-reorder) — this is now pure SwiftUI/AppKit work with zero unresolved external-API risk, safe to build and fully on-device-UAT before step 4.
4. **The reserved-slot buttons (star + speaker icons)** in `mediaExpanded` — trivial once step 3's closures exist; wire the speaker icon to toggle the already-proven output panel.
5. **The one genuinely risky step, isolated last, exactly like Phase 22/38/39:** a small, throwaway on-device spike that (a) confirms whether `ejbills/mediaremote-adapter`'s `MediaController` can send `MRMediaRemoteCommandLikeTrack` at all (worst case: patch the wrapper's own command table, still contained to `NowPlayingMonitor.swift`), and (b) confirms whether the streamed payload ever reports a rating/favorite read-state. Only after this spike answers both questions should the star's real `NowPlayingMonitor.toggleFavorite()` + `TrackSnapshot.isFavorite` wiring be planned in detail — if the spike says "write-only, no read-state," scope the star down to an optimistic session-local toggle rather than a real bidirectional rating control, and say so explicitly rather than discovering it mid-plan.

This ordering means a spike failure on step 5 (favorite) never blocks or contaminates the output-switcher work, which is the higher-confidence, more visually complex half of this milestone slice — the same isolation discipline that let Phase 22's failure stay contained instead of stalling Phases 19-21.

## Sources

- Direct codebase reads (HIGH confidence): `Islet/Notch/NowPlayingMonitor.swift`, `NowPlayingPresentation.swift`, `IslandResolver.swift`, `IslandPresentationState.swift`, `VolumeReader.swift`, `OSDActivity.swift`, `NotchPillView.swift` (`mediaExpanded`, `blobShape`, constants block), `NotchWindowController.swift` (`positionAndShow`, `visibleContentZone`, `startNowPlayingMonitor`, `startBluetoothMonitor`), `BluetoothMonitor.swift`, `ViewSwitcherState.swift`, `.planning/PROJECT.md` (Key Decisions, Validated requirements through Phase 42).
- [theos/headers MediaRemote.h](https://github.com/theos/headers/blob/master/MediaRemote/MediaRemote.h) — MEDIUM confidence, reverse-engineered/community-maintained header, not an Apple source, but the only available reference for the private `MRMediaRemoteCommand` enum; confirms `MRMediaRemoteCommandLikeTrack`/`DislikeTrack`/`RateTrack`/`BookmarkTrack` exist as command constants.
- [ungive/mediaremote-adapter](https://github.com/ungive/mediaremote-adapter) and [ejbills/mediaremote-adapter](https://github.com/ejbills/mediaremote-adapter) — HIGH confidence on architecture (already the project's own dependency, per CLAUDE.md/STACK research); LOW confidence on whether the Swift wrapper's `MediaController` exposes sending a like/favorite command — not found documented in this research pass, flagged as the step-5 spike question.
- Apple CoreAudio public documentation (`kAudioHardwarePropertyDevices`, `kAudioHardwarePropertyDefaultOutputDevice`, `AudioObjectAddPropertyListener`) — HIGH confidence, standard documented public API, same framework already in production use via `VolumeReader.swift`.

---
*Architecture research for: Islet v1.7 candidate scope — Favorite write-back + Audio-output switcher integration*
*Researched: 2026-07-19*
