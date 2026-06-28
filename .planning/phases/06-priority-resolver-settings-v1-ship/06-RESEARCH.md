# Phase 6: Priority Resolver, Settings & v1 Ship - Research

**Researched:** 2026-06-28
**Domain:** SwiftUI/AppKit activity coordination (pure ranked resolver + bounded splash queue), `@AppStorage` settings + accent threading, IOBluetooth device wiring, macOS-26 notarize/health-check ship gate
**Confidence:** HIGH (the "how" is largely settled in CONTEXT.md + the existing two activity quartets; this research grounds the resolver shape, accent threading, toggle wiring, and the Tahoe ship gate in the real code)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Priority resolver — ranking & coexistence (COORD-01)**
- **D-01:** Finish the device activity wiring in Phase 6 — build `DeviceActivityState` (@Published model), the thin `BluetoothMonitor` (IOBluetooth connect/disconnect, main-hop, deinit teardown), and the device wings view branch, completing Phase-5 Waves 2-3 so the resolver has **three real inputs**. Reuse Phase-5 D-01…D-07 verbatim (all-devices, glyph-by-name, dimmed disconnect, burst-suppression/debounce, ~3s dismiss). **Defer only** the on-device Bluetooth verification (no test device). Wire behind the single `updateVisibility()` gate.
- **D-02:** One ranked resolver replaces the ad-hoc per-pair ordering. Rank: **Charging > Device > Now Playing.** Now Playing is the **ambient baseline**; charging/device are **transient ~3s splashes** that briefly win, then the island returns to the highest-priority ambient state (now-playing wings if playing, else idle pill). Generalizes Phase-3 D-11 / Phase-4 D-14 / Phase-5 D-05.
- **D-03:** Collision = short sequential queue. A second transient arriving while one shows is **enqueued** (show A ~3s, then B ~3s). Not drop-the-loser, not interrupt-with-latest. Queue stays **bounded and de-duped** (no stacking duplicate copies; small depth) so it cannot back up. Exact depth/dedup rule is Claude's discretion but must stay simple (no over-engineering).
- **D-04:** Transient wins briefly over a user-expanded island (generalize Phase-3 D-11): splash shows its brief feedback, then returns to open/ambient. User interaction is **not** a protected higher rank.
- **D-05:** Resolver is the **single arbiter of which presentation renders** — replace the scattered precedence `if`-chain in `NotchPillView` + the per-handler logic in `NotchWindowController` with one clear, ideally **pure/testable** ranking+queue seam. Exact shape (enum-of-active-activity vs a resolver function over the three @Published states) is Claude's discretion — keep it the ONE place priority lives, routed through the single `updateVisibility()`.

**Settings — activity toggles (APP-03)**
- **D-06:** Three independent on/off toggles: Charging, Now Playing, Device — one switch each.
- **D-07:** All default ON.
- **D-08:** Pure on/off only for v1. No master "pause all", no per-activity duration. Toggles live in the existing `SettingsView` Form (alongside Launch-at-Login + Version).
- **D-09:** Persist across restarts via `@AppStorage`/`UserDefaults` (Claude's discretion). Toggling **applies live** — turning off immediately suppresses the splash without a restart. Whether "off" also stops the underlying monitor (vs just suppressing display) is Claude's discretion; **prefer not registering the source when off** to keep idle CPU ~0%.

**Settings — accent / theme (APP-03)**
- **D-10:** Accent color only — no theme system. The island **stays black** (no light/dark, no tinted island variant).
- **D-11:** The accent tints the **lively active elements**: the charging bolt/battery glyph, the Now-Playing equalizer bars, the device icon. It does **not** restyle the expanded-view chrome (transport buttons / title) in v1.
- **D-12:** Curated palette (~5-6 colors), default = neutral / system color. Apple-style preset swatches, NOT a free ColorPicker. Persisted like the toggles. Exact palette + default swatch are Claude's discretion + on-device taste.

**v1 ship (release + health re-check)**
- **D-13:** Product name stays `Islet` for v1 (current bundle name).
- **D-14:** Version `0.1` / `0.x` (private first release; `1.0` reserved for the public/sellable launch).
- **D-15:** No Apple Developer account yet → release runs as a **DRY-RUN**. The Phase-0 `scripts/release.sh` runs **unchanged**: Developer-ID/notary stay placeholder-gated, ad-hoc fallback exits 0 with the loud SKIP banner. The **real** Developer-ID sign→notarize→staple + clean-second-Mac open is a **carry-over**. Keep the DMG via **`hdiutil` (UDZO)** — no `create-dmg`.
- **D-16:** Re-verify the Now Playing launch-time health check as part of the ship gate — confirm the `NowPlayingMonitor` health check + "nicht verfügbar" fallback still pass on the current installed macOS.

### Claude's Discretion
- The resolver's exact shape (pure ranking/queue function over the three @Published states vs an active-activity enum) and the queue depth/dedup rule — keep it the ONE priority site, simple, testable, routed through `updateVisibility()`.
- The persistence keys/structure (`@AppStorage` vs a small settings model) and whether a disabled activity stops its monitor or just suppresses display (prefer stop).
- The exact 5-6 accent swatches + the default, and how the accent color threads into the existing views.
- Device-activity specifics inherited from 05-CONTEXT (name→SF-Symbol map, burst/debounce, disconnect dimming).
- Spring/duration tuning (start from Phase-2 seeds: response ≈ 0.35, damping ≈ 0.65).
- The pure-logic TDD seam for the resolver (rank + queue) and the device edge predicate — unit-tested in ms; IOBluetooth + AppKit/SwiftUI wiring verified on-device (BT UAT deferred).

### Deferred Ideas (OUT OF SCOPE)
- On-device Bluetooth UAT (DEV-01/DEV-02 verification + the A1 permission-key verdict) → run when a Bluetooth test device is available; code ships code-complete in Phase 6.
- Real Developer-ID notarize/staple + clean-second-Mac open (success criterion 3 / APP-04) → carry-over once the $99/yr account exists.
- Public product name + 1.0 version → deferred to the later sellable launch.
- Master "pause all" switch, per-activity duration settings, free ColorPicker, light/dark or tinted island, accent on expanded-view chrome → considered and cut for v1.
- Sneak-peek toggle + source-allowlist widening (Phase-4 v2) → still v2.
- create-dmg prettier installer → optional polish, not v1.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| **COORD-01** | When several activities occur close together, the island shows them by a sensible priority without overlapping or glitching | §Architecture Pattern 1 (pure ranked resolver), Pattern 2 (bounded de-duped splash queue off the one-shot DispatchWorkItem), Pattern 6 (route through `updateVisibility()`); §Don't Hand-Roll (timing source); §Validation Architecture (resolver rank + queue unit tests) |
| **APP-03** | A minimal settings window lets the user choose which activities are shown and set an accent/theme | §Architecture Pattern 3 (`@AppStorage` toggles + live monitor start/stop), Pattern 4 (accent threading via `@AppStorage` → existing tint params), Pattern 5 (curated swatch palette in a `Form`); §Code Examples |
| DEV-01 (carried) | Connecting AirPods/BT audio shows a connect activity (name + icon) | §Architecture Pattern 7 (DeviceActivityState + BluetoothMonitor clone of the power triple); §Runtime State Inventory; the pure `DeviceActivity.swift` seam already exists + is tested |
| DEV-02 (carried) | Disconnecting a device shows a brief disconnect activity | Same — `deviceActivity(from:)` already emits `.disconnected`; per-device disconnect token wiring in BluetoothMonitor |
| APP-04 (carried, dry-run) | Developer-ID signed + notarized + stapled download opening on a clean Mac | §v1 Ship — `scripts/release.sh` runs unchanged as the placeholder-gated dry-run; real run is the deferred carry-over |
</phase_requirements>

## Summary

Phase 6 has three jobs and **almost no new "how" to discover** — the heavy lifting was done by CONTEXT.md and by the two complete activity "quartets" already in the codebase (Power and NowPlaying). The single highest-value research output is the **shape of the priority resolver**: how to collapse the existing scattered precedence — a `ZStack` `if`-chain in `NotchPillView.body` (lines 110–124) plus per-handler scheduling in `NotchWindowController` (`handlePower`/`handleNowPlaying`, the `dismissWorkItem`/`mediaDismissWorkItem` pair) — into one pure, testable, ranked policy with a short bounded de-duped queue, while keeping the **single `updateVisibility()`** as the sole show/hide site.

The codebase makes the resolver shape clear. There are exactly **three `@Published` inputs**: `ChargingActivityState.activity: ChargingActivity?`, the to-build `DeviceActivityState.activity: DeviceActivity?` (mirror of charging), and `NowPlayingState.presentation: NowPlayingPresentation` (+ `.isHealthy`). The recommended shape is a **pure reducer-style function** `resolve(charging:device:nowPlaying:expanded:settings:) -> IslandPresentation` returning a single enum that the view renders with one `switch` — **plus** a tiny stateful **transient-splash queue** that owns *which* transient (if any) is currently winning. The pure ranking and the queue's ordering/dedup logic go in a framework-free seam (unit-tested in ms, mirroring `PowerActivity`/`DeviceActivity`); the controller keeps the AppKit timing (the one-shot `DispatchWorkItem` that already exists) and feeds queue transitions through `updateVisibility()`.

Settings is greenfield (`grep` confirms **zero** `@AppStorage`/`UserDefaults` usage today) and low-risk: three `@AppStorage` `Bool`s default `true` in the existing `SettingsView` `Form`, an `@AppStorage` accent-swatch index, and the accent threaded into the views via params that **already exist** (`EqualizerBars(isPlaying:tint:)` takes a `tint: Color`). The Tahoe ship gate is well understood: the build machine is macOS 26 / Xcode 26.6 / Swift 6.3.3, all release CLIs are present, `create-dmg` is absent, and `scripts/release.sh` already exits 0 with a SKIP banner when the Developer-ID placeholders are unfilled — so the dry-run is a *run-and-confirm*, not a build task. The Now-Playing health-check re-verify (D-16) is on-device only (the adapter spawns a perl child); reading works on macOS 26, with a community note that media *commands* were flaky on 26.1 and fixed by 26.2 — worth confirming live against the installed build.

**Primary recommendation:** Build the resolver as a **pure ranked-reducer seam + a small bounded de-duped transient queue**, both framework-free and unit-tested; delete the precedence `if`-chain from `NotchPillView` (the view renders one `IslandPresentation` enum) and the per-pair scheduling from the controller (one `scheduleTransientDismiss()` drives the queue off the existing one-shot `DispatchWorkItem`); finish the device quartet by cloning the Power triple; do Settings with plain `@AppStorage`; and run the ship pipeline unchanged as the D-15 dry-run plus a live D-16 health re-check.

## Standard Stack

No new third-party libraries. Everything is Apple-framework + the already-pinned MediaRemoteAdapter. Verified against the live build machine.

### Core
| Library / API | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI `@AppStorage` | macOS 14+ SDK | Persist the three activity toggles + accent swatch; auto-reinvokes view `body` on change (live-apply) | [VERIFIED: HackingWithSwift, fatbobman 2026] The first-party UserDefaults-backed property wrapper; ideal for a *small fixed set* of keys (exactly our case). |
| `UserDefaults.standard` | macOS 14+ | The controller (non-View) side reads the same keys the views persist, to decide whether to register a monitor (D-09 "prefer stop") | [VERIFIED: codebase] `@AppStorage` writes to `UserDefaults.standard`; the controller reads/observes the same suite. |
| IOBluetooth | macOS SDK (legacy, functional) | `BluetoothMonitor` connect/disconnect notifications (D-01) | [CITED: developer.apple.com/documentation/iobluetooth] Correct tool for "did a paired device connect" (Core Bluetooth is the wrong abstraction — CLAUDE.md). Still present on macOS 26. |
| MediaRemoteAdapter (`ejbills/mediaremote-adapter`) | pinned `cf30c4f` (already in `project.yml`); upstream `ungive` v0.7.6 (2026-05-11) | Now Playing health re-check (D-16) only — no change in Phase 6 | [VERIFIED: github.com/ungive/mediaremote-adapter] "Fully functional MediaRemote access for all versions of macOS"; reading works on macOS 26. |
| `hdiutil` (UDZO) | system | DMG creation in `release.sh` (D-15) | [VERIFIED: live machine] Present; `create-dmg` deliberately avoided (not installed). |
| `xcrun notarytool` + `xcrun stapler` + `spctl` | Xcode 26.6 | Notarize/staple/verify steps (gated off in the dry-run; the real carry-over) | [VERIFIED: live machine] All present at the expected paths. |

### Supporting
| API | Purpose | When to Use |
|---------|---------|-------------|
| `DispatchWorkItem` + `DispatchQueue.main.asyncAfter` | The ~3s one-shot transient dismiss AND the queue's timing source (D-03) | [VERIFIED: codebase] Already the established no-polling timing primitive (`graceWorkItem`, `dismissWorkItem`, `mediaDismissWorkItem`). The queue reuses this, never a repeating timer. |
| `withAnimation(.spring(response:dampingFraction:))` | Attach the spring AT each presentation mutation (D-08: the view drives no animation) | [VERIFIED: codebase] Used at every mutation site in the controller; the resolver's transitions must stay wrapped the same way. |
| `EqualizerBars(isPlaying:tint:)` | Accent on the now-playing bars (D-11) | [VERIFIED: codebase] The `tint: Color = .white` parameter **already exists** (NotchPillView.swift:401) — accent threading for the bars is a one-arg change. |
| `Image(systemName:variableValue:).foregroundStyle(_)` | Accent on the charging glyph + device icon (D-11) | [VERIFIED: codebase] The charging wings already use `.foregroundStyle(tint)` (NotchPillView.swift:197); thread the accent into `tint`. |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Plain `@AppStorage` Bools | `fatbobman/ObservableDefaults` macro library | [CITED: github.com/fatbobman/ObservableDefaults] Solves multi-key/iCloud/precise-update scaling — but adds a dependency for **3 toggles + 1 enum**. Over-engineering for v1 (D-08 "no over-engineering"). Stay with `@AppStorage`. |
| A pure resolver function returning an enum | A full `enum`-state-machine `ActiveActivity` driven by a reducer | [VERIFIED: web — splinter.com.au, betterprogramming.pub] Both are idiomatic. The pure-function-over-three-`@Published`-states is closer to the existing pure seams (`powerActivity(from:)`, `deviceActivity(from:)`) and the established TDD discipline; pick it unless the queue state makes an explicit enum clearer. The **queue** is the one genuinely stateful piece — model *it* as a small typed value, not the whole app. |
| Suppress display when a toggle is off | Stop/never-register the monitor when off (D-09 preferred) | Stopping the monitor keeps idle CPU ~0% (no IOPS source / no perl child / no IOBluetooth registration), matching the project's no-polling ethos — but requires a clean start/stop path keyed off the toggle. Both monitors already expose `start()`/`stop()`; the device monitor must too. Prefer stop; fall back to display-suppression only if a live start/stop proves racy. |

**Installation:** None — no `npm`/SPM additions. After adding the new `.swift` files (`DeviceActivityState.swift`, `BluetoothMonitor.swift`, the resolver seam, and any settings model), run `xcodegen generate` (XcodeGen auto-discovers sources under `Islet/`).

**Version verification (done this session):**
- Build machine: `sw_vers` → ProductVersion **27.0** / Build **26A5368g** (= macOS 26 "Tahoe" family), `xcodebuild -version` → **Xcode 26.6**, `swift --version` → **Apple Swift 6.3.3**. [VERIFIED: live machine 2026-06-28]
- mediaremote-adapter upstream latest = **v0.7.6 (2026-05-11)**; project pins commit `cf30c4f` — unchanged in Phase 6. [VERIFIED: github.com/ungive/mediaremote-adapter]

## Architecture Patterns

### Recommended Project Structure (additions only)
```
Islet/Notch/
├── DeviceActivity.swift          # EXISTS — pure seam + tests (Phase-5 Tasks 1-2)
├── DeviceActivityState.swift     # NEW — @Published model (clone ChargingActivityState)
├── BluetoothMonitor.swift        # NEW — thin IOBluetooth glue (clone PowerSourceMonitor shape)
├── IslandResolver.swift          # NEW — the PURE ranked reducer + the bounded de-duped queue value
├── ChargingActivityState.swift   # EXISTS
├── NowPlayingState.swift         # EXISTS
├── NotchPillView.swift           # EDIT — replace the if-chain with a single switch over IslandPresentation; thread accent
└── NotchWindowController.swift   # EDIT — add handleDevice; route all three through the resolver/queue + updateVisibility()
Islet/
├── SettingsView.swift            # EDIT — add 3 toggles + accent swatch row
└── (optional) ActivitySettings.swift  # NEW (discretion) — typed accent palette + AppStorage keys
IsletTests/
├── IslandResolverTests.swift     # NEW — rank + queue ordering/dedup (pure, ms)
└── (DeviceActivityTests.swift already covers the device edge predicate)
```

### Pattern 1: The pure ranked resolver (COORD-01, D-02/D-05)
**What:** A framework-free function over the three current activity states + interaction phase + settings, returning ONE `IslandPresentation` enum the view renders with a single `switch`. This is the "single arbiter" D-05 asks for.
**When to use:** Every show/render decision. It replaces the `if`-chain in `NotchPillView.body` (lines 110–124) — the view stops deciding precedence and just renders what it's told.
**Why a reducer-shape:** It mirrors the existing pure seams (`powerActivity(from:)`, `deviceActivity(from:)`, `nowPlayingPresentation(from:)`) and the locked TDD discipline (pure logic unit-tested in ms; AppKit/IOBluetooth verified on-device).

```swift
// Source: pattern grounded in the existing pure seams (PowerActivity.swift / DeviceActivity.swift)
// IslandResolver.swift — imports ONLY Foundation. No AppKit, no SwiftUI, no IOBluetooth.

// The ONE thing the view renders. The view's body becomes a single switch over this.
enum IslandPresentation: Equatable {
    case idle                                   // collapsed pill (D-08 idle-static)
    case charging(ChargingActivity)             // transient splash (rank 1)
    case device(DeviceActivity)                 // transient splash (rank 2)
    case nowPlayingWings(NowPlayingPresentation) // ambient glance (rank 3)
    case nowPlayingExpanded(NowPlayingPresentation, healthy: Bool) // user-expanded media/date/unavailable
    case expandedIdle                           // user-expanded, healthy, no media (date/time)
}

// The transient currently "winning" (owned by the queue, passed in). nil = no transient.
enum ActiveTransient: Equatable { case charging(ChargingActivity), device(DeviceActivity) }

// Pure. `activeTransient` is decided by the QUEUE (Pattern 2); the rest is direct ranking.
func resolve(activeTransient: ActiveTransient?,
             nowPlaying: NowPlayingPresentation,
             nowPlayingHealthy: Bool,
             isExpanded: Bool) -> IslandPresentation {
    // D-04: a transient briefly wins even over a user-expanded island.
    switch activeTransient {
    case .charging(let a): return .charging(a)   // rank 1
    case .device(let d):   return .device(d)     // rank 2
    case nil: break
    }
    // No transient → ambient. The user-expanded branch picks media/date/unavailable.
    if isExpanded {
        if !nowPlayingHealthy { return .nowPlayingExpanded(nowPlaying, healthy: false) } // D-12
        if nowPlaying != .none { return .nowPlayingExpanded(nowPlaying, healthy: true) } // media controls
        return .expandedIdle                                                              // date/time
    }
    if nowPlaying != .none { return .nowPlayingWings(nowPlaying) }   // ambient glance (rank 3)
    return .idle
}
```
**Note:** the *settings toggles* are applied BEFORE the resolver, not inside it — a disabled activity simply never produces a transient (its monitor is stopped, D-09) and a disabled Now-Playing means `nowPlaying` is forced `.none`. Keeping the resolver about *ranking only* keeps it tiny and total.

### Pattern 2: The bounded, de-duped transient queue (COORD-01, D-03)
**What:** A small value that holds the *pending* transients while one is showing, with the ordering/dedup rules. The controller advances it off the **existing one-shot `DispatchWorkItem`** (NOT a repeating timer — D-03 / the locked no-polling rule). The "currently winning" head is what feeds `activeTransient` into `resolve(...)`.
**When to use:** Whenever a transient (charging or device splash) is triggered. If nothing is showing, it becomes the head immediately and arms the ~3s dismiss; if one is already showing, it enqueues (deduped).
**De-dup + bound rule (discretion, kept simple per D-03):** identity = the transient's *category+key* (charging: the category; device: the address+connected-edge). Don't enqueue a duplicate of the head or of an already-pending entry; cap depth at a small N (e.g. 2–3) and **drop the oldest pending on overflow** (never drop the head). This makes "charger plugged while AirPods connect, then a track change" show charging→device sequentially and can never back up.

```swift
// Source: pattern grounded in the controller's existing one-shot dismiss (scheduleActivityDismiss)
// IslandResolver.swift — still Foundation-only. The QUEUE is the one stateful value; keep it tiny.
struct TransientQueue {
    private(set) var head: ActiveTransient?      // the one currently winning (feeds resolve)
    private var pending: [ActiveTransient] = []  // bounded, de-duped
    let maxDepth = 2                             // discretion: small, can't back up

    // Returns true if `head` changed (caller should re-render + (re)arm the ~3s dismiss).
    mutating func enqueue(_ t: ActiveTransient) -> Bool {
        if head == nil { head = t; return true }            // show immediately
        if head == t || pending.contains(t) { return false } // de-dup (D-03)
        pending.append(t)
        if pending.count > maxDepth { pending.removeFirst() } // bound (drop oldest pending)
        return false
    }

    // The ~3s elapsed for the head → advance. Returns true if head changed.
    mutating func advance() -> Bool {
        guard !pending.isEmpty else { head = nil; return true } // back to ambient
        head = pending.removeFirst()
        return true
    }
}
```
The controller keeps **one** dismiss work-item: on a head change it (re)arms `asyncAfter(+activityDuration)`; when it fires it calls `advance()` and, if the head changed, re-renders + re-arms (or stops if `head == nil`). This is exactly the existing `scheduleActivityDismiss` shape, generalized from one splash to a queue.

### Pattern 3: Live activity toggles that stop the monitor (APP-03, D-06/D-07/D-09)
**What:** Three `@AppStorage` `Bool`s (`charging`/`nowPlaying`/`device`), default `true`. The **view** persists + live-applies; the **controller** reads the same `UserDefaults` keys to decide whether to `start()`/`stop()` each monitor (D-09 "prefer stop").
**When to use:** At launch (register only enabled monitors) and whenever a toggle flips (start/stop the affected monitor + flush any of its standing/queued transients).
**Wiring given the existing pattern:** each monitor already has `start()`/`stop()` (the device monitor must too). The cleanest seam is for the controller to observe the defaults (`NotificationCenter` `UserDefaults.didChangeNotification`, or a small settings model the controller also holds) and call the matching `start()`/`stop()`. Turning Now-Playing off should also force `nowPlaying = .none` into the resolver so the ambient glance disappears live.
**Anti-pattern to avoid:** wiring the toggle ONLY into the view's render (display-suppression) while the monitor keeps running — that leaves the perl child / IOPS source / IOBluetooth registration alive and violates the idle-CPU intent (D-09 prefers stop).

### Pattern 4: Accent threading from `@AppStorage` into the lively elements (APP-03, D-10/D-11/D-12)
**What:** One persisted accent choice (a swatch index or a small enum), read where the three lively elements render, NEVER applied to the island shape (D-10 stays black) or expanded chrome (D-11).
**When to use:** Charging bolt/battery glyph, equalizer bars, device icon.
**How to thread (discretion — pick ONE, recommend the Environment value):**
- **Recommended — a custom `EnvironmentKey`** (`\.activityAccent`): set once on the hosting `NotchPillView` from the persisted value; the three subviews read `@Environment(\.activityAccent)`. Clean, no prop-drilling, live-updates when the key changes. The view tree is tiny so the blast radius is contained.
- **Simplest — direct `@AppStorage` read** in each subview: 3 reads, auto-live-updates, but couples the leaf views to a defaults key.
- The `EqualizerBars` already takes `tint: Color` and the charging wings already use `.foregroundStyle(tint)` — so the **last mile is trivial** whichever source you pick.
**Default = neutral/system (D-12):** map the default swatch to `Color.white` for the bolt/bars/icon (preserves today's look) OR `Color.accentColor`; "neutral" here means "no surprising tint until the user picks one."

### Pattern 5: Curated swatch palette in the existing Form (APP-03, D-12)
**What:** A non-ColorPicker preset row in `SettingsView`'s `Form`: ~5-6 fixed swatches + a selected ring, persisted to `@AppStorage`.
**When to use:** Below the activity toggles, above/below Version.
```swift
// Source: SwiftUI Form idiom; grounded in the existing SettingsView Form
private let palette: [Color] = [.white, .blue, .green, .orange, .pink, .purple] // discretion (D-12)
@AppStorage("accentIndex") private var accentIndex = 0   // 0 = neutral default (D-12)

// In the Form:
HStack(spacing: 10) {
    ForEach(palette.indices, id: \.self) { i in
        Circle().fill(palette[i]).frame(width: 22, height: 22)
            .overlay(Circle().strokeBorder(.primary, lineWidth: accentIndex == i ? 2 : 0))
            .onTapGesture { accentIndex = i }   // persists + live-applies
    }
}
```

### Pattern 6: Everything still routes through the single `updateVisibility()`
**What:** The resolver decides *what* renders; `updateVisibility()` stays the SOLE *show/hide* site (it owns the fullscreen + clamshell gate). Every resolver/queue transition that changes the head must end with `updateVisibility()` (or a render + `updateVisibility()`), exactly as `handlePower`/`handleNowPlaying` do today.
**Why:** Preserves ISL-05 fullscreen-hide and ISL-06 clamshell-correctness for free. A second show/hide site would race the screen/fullscreen observers (Pitfall 5 in the existing controller).

### Pattern 7: Finish the device quartet by cloning the power triple (D-01, DEV-01/02)
**What:** `DeviceActivityState` is a 1:1 clone of `ChargingActivityState` (`@Published var activity: DeviceActivity?`). `BluetoothMonitor` mirrors `PowerSourceMonitor`'s discipline: `@MainActor`, injected `onChange`/edge closure, `start()`/`stop()`, callbacks hop to main, `nonisolated stop()` callable from the controller's `deinit`. The connect path uses `IOBluetoothDevice.register(forConnectNotifications:selector:)`; each connected device registers a per-device `register(forDisconnectNotification:selector:)` whose token must be **retained** (the `BluetoothSpike` already demonstrates the exact retention pattern — `disconnectTokens[addr]`). Lift a `DeviceReading` out of the callbacks and feed the existing pure `deviceActivity(from:)` + `shouldShowDeviceSplash(...)`.
**Critical:** remove `BluetoothSpike.swift` + the `#if DEBUG_BT_SPIKE` block in `AppDelegate.swift` once the real monitor lands.

### Anti-Patterns to Avoid
- **A repeating `Timer` for the queue.** The whole codebase is one-shot `DispatchWorkItem` only (idle CPU ~0%). The queue advances on the head's existing ~3s one-shot, never a clock.
- **Putting ranking logic back in the view.** The view must become "render this `IslandPresentation`" — no `if charging … else if expanded …`. That centralization IS the deliverable (D-05).
- **Re-entrant queue mutation.** All queue mutation happens on main inside the controller (the monitors already hop to main). Don't mutate the queue from a background callback.
- **Accent on the black island or expanded chrome.** D-10/D-11 — tint ONLY the bolt/bars/device-icon.
- **A second `start()` of a monitor on toggle without an idempotent guard.** Toggling fast must not double-register an IOBluetooth/IOPS source. Make `start()` idempotent or gate on a "running" flag.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Timed transient dismiss + queue advance | A custom `Timer`/`DisplayLink`/run-loop poll | The existing one-shot `DispatchWorkItem` + `asyncAfter` pattern | [VERIFIED: codebase] Already the locked no-polling primitive; idle CPU ~0% is a success criterion. |
| Settings persistence | A hand-rolled plist read/write or a JSON file | `@AppStorage` (+ `UserDefaults.standard` on the controller side) | [VERIFIED: HackingWithSwift] First-party, auto-live-updates the view, zero boilerplate for a small key set. |
| Multi-key/iCloud reactive defaults | A bespoke `ObservableObject` wrapping many keys | (For v1) just `@AppStorage`; ObservableDefaults only if it ever scales | [CITED: github.com/fatbobman/ObservableDefaults] Real but overkill for 3 toggles + 1 enum (D-08). |
| BT connect/disconnect events | Core Bluetooth central scanning | IOBluetooth `register(forConnect/DisconnectNotifications:)` | [CITED: CLAUDE.md + Apple docs] CB is for being a BLE central; IOBluetooth is the correct paired-device-connect API. |
| Now-Playing access | Direct `dlopen` of MediaRemote | The already-pinned MediaRemoteAdapter (unchanged) | [VERIFIED: ungive README] Direct access is blocked on 15.4+/26; the adapter is the only working path. |
| DMG creation | `create-dmg` (not installed) | `hdiutil … -format UDZO` (already in `release.sh`) | [VERIFIED: live machine] `create-dmg` absent; D-15 locks hdiutil. |

**Key insight:** Phase 6 is overwhelmingly *composition of existing, proven seams*. The only genuinely new logic is the **pure ranking + the bounded queue** — and that's exactly the part the locked TDD discipline says to unit-test in milliseconds.

## Runtime State Inventory

> Phase 6 is mostly greenfield logic + UI, but it (a) adds persisted settings and (b) removes a debug spike, so a small inventory applies.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | `UserDefaults.standard` will gain **new keys** (`charging`/`nowPlaying`/`device` toggles + `accentIndex`). No keys exist today (`grep` confirms zero `@AppStorage`/`UserDefaults`). | Code only — pick stable key names; defaults `true`/`0`. No migration (greenfield). |
| Live service config | None — no external service stores Islet state. The MediaRemoteAdapter perl child is spawned at runtime, not persisted. | None — verified by code (only `MediaController().startListening()` at launch). |
| OS-registered state | `SMAppService.mainApp` (Launch-at-Login) is registered on toggle — **unchanged** by Phase 6. macOS TCC may hold a Bluetooth-usage consent once the real `BluetoothMonitor` runs on a machine with a BT device (the A1 verdict, deferred). | None for the dry-run on a machine with no BT test device; the A1 TCC verdict is the deferred carry-over. |
| Secrets/env vars | `release.sh` reads the notary keychain profile NAME only (placeholder-gated in the dry-run); no secret in the repo. | None — dry-run never touches real credentials. |
| Build artifacts | Adding `.swift` files requires `xcodegen generate` (XcodeGen auto-discovers `Islet/`). Removing `BluetoothSpike.swift` + the `#if DEBUG_BT_SPIKE` block also requires a regenerate. `dist/` + `build/` from a prior `release.sh` run are stale once rebuilt (the script `rm -rf build dist` first). | Run `xcodegen generate` after adding/removing sources; `release.sh` self-cleans `build`/`dist`. |

**The canonical question — after every file is updated, what runtime state still carries the old shape?** Only two things: (1) the throwaway `DEBUG_BT_SPIKE` compile path must be deleted so a future `-DDEBUG_BT_SPIKE` build can't double-register IOBluetooth alongside the real monitor; (2) `NSBluetoothAlwaysUsageDescription` must be added to `project.yml` **only if** the deferred A1 verdict says it's required (don't add it speculatively — it would surface a TCC prompt where none is needed).

## Common Pitfalls

### Pitfall 1: The queue silently backs up or shows duplicates
**What goes wrong:** Without dedup, a flapping device (connect/disconnect/reconnect) or repeated charging ticks enqueue many copies; the island plays a long stuttering chain.
**Why it happens:** Naively appending every trigger to the queue.
**How to avoid:** Dedup by category+key against the head AND pending; bound depth (small N) and drop oldest-pending on overflow. The device side already has `shouldShowDeviceSplash(...)` (debounce + at-launch burst suppression) as a *first* gate before the queue — keep both.
**Warning signs:** A unit test that enqueues the same transient twice should leave the queue depth unchanged.

### Pitfall 2: A transient that yields back to the WRONG ambient state
**What goes wrong:** After the splash, the island goes to idle even though music is playing (should return to the now-playing wings — D-02/D-14 "return to wings, not empty").
**Why it happens:** Clearing the transient without re-running the resolver over the current `nowPlaying` state.
**How to avoid:** On `advance()` to `head == nil`, re-render via the resolver (which falls through to `.nowPlayingWings` if playing). The existing code already gets this right for charging→media; the resolver makes it uniform.
**Warning signs:** Manual: play music, plug charger, wait ~3s → island must show the media glance, not the bare pill.

### Pitfall 3: Toggling an activity off leaves a standing/queued splash on screen
**What goes wrong:** User disables "Charging" while a charging splash is up (or queued) — it keeps showing.
**Why it happens:** The toggle stops the monitor but doesn't flush the resolver/queue.
**How to avoid:** On a toggle-off, stop the monitor AND drop any matching head/pending transient (and force `nowPlaying = .none` for the Now-Playing toggle), then `updateVisibility()`.
**Warning signs:** Manual: trigger a splash, immediately disable that activity → it must clear at once.

### Pitfall 4: Accent leaks onto the island shape or expanded chrome
**What goes wrong:** The black island picks up a tint, breaking the seamless-notch illusion (D-10), or transport buttons get colored (D-11 says no).
**Why it happens:** Applying the accent at too high a level (the `NotchShape().fill` or a blanket `.tint`).
**How to avoid:** Thread the accent ONLY into the three named leaf elements; the island `fill` stays `Color.black`; transport buttons stay `.white`.
**Warning signs:** Visual UAT — the pill must look identical (black) regardless of accent.

### Pitfall 5: IOBluetooth monitor double-registration on fast toggling
**What goes wrong:** Flipping the device toggle on/off/on registers two connect observers → duplicate splashes / leaked tokens.
**Why it happens:** `start()` not idempotent; `stop()` not unregistering every per-device disconnect token.
**How to avoid:** Guard `start()` with a running flag; `stop()` unregisters the connect token + every `disconnectTokens` value (the spike already shows the cleanup loop). Mirror `PowerSourceMonitor`'s nonisolated teardown so `deinit` can clean up.
**Warning signs:** A second connect after a toggle cycle fires the callback twice.

### Pitfall 6: Assuming the Now-Playing health re-check (D-16) can be unit-tested
**What goes wrong:** Trying to assert the health check in `IsletTests`.
**Why it happens:** The health probe spawns a real perl child via MediaRemoteAdapter — it's IPC, not pure logic.
**How to avoid:** D-16 is an **on-device manual gate**: launch, confirm `isHealthy` flips true (a callback arrived), and confirm the "nicht verfügbar" fallback path is intact. The pure `nowPlayingPresentation(from:)` is already unit-tested; the *bridge* is on-device only. Note the macOS-26.1 command-flakiness community report — verify play/pause live on the installed build.
**Warning signs:** A flaky/hanging test that shells out.

## Code Examples

### `DeviceActivityState` — clone of the existing charging model
```swift
// Source: 1:1 mirror of Islet/Notch/ChargingActivityState.swift (VERIFIED in codebase)
import Foundation
final class DeviceActivityState: ObservableObject {
    @Published var activity: DeviceActivity?
}
```

### `BluetoothMonitor` skeleton — mirrors PowerSourceMonitor's lifecycle
```swift
// Source: discipline mirrored from PowerSourceMonitor.swift + retention pattern from BluetoothSpike.swift (VERIFIED)
import IOBluetooth
import AppKit

@MainActor
final class BluetoothMonitor: NSObject {
    private var connectToken: IOBluetoothUserNotification?
    private var disconnectTokens: [String: IOBluetoothUserNotification] = [:]
    private var running = false                              // Pitfall 5: idempotent start()
    private let onReading: (DeviceReading) -> Void           // controller hops are already on main here

    init(onReading: @escaping (DeviceReading) -> Void) { self.onReading = onReading; super.init() }

    func start() {
        guard !running else { return }                       // Pitfall 5
        running = true
        connectToken = IOBluetoothDevice.register(forConnectNotifications: self,
                                                  selector: #selector(connected(_:device:)))
    }

    @objc private func connected(_ n: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        if let addr = device.addressString, disconnectTokens[addr] == nil {
            disconnectTokens[addr] = device.register(forDisconnectNotification: self,
                                                     selector: #selector(disconnected(_:device:)))  // retain (Pitfall 5)
        }
        emit(device, connected: true)
    }
    @objc private func disconnected(_ n: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        if let addr = device.addressString { disconnectTokens[addr]?.unregister(); disconnectTokens[addr] = nil }
        emit(device, connected: false)
    }
    private func emit(_ d: IOBluetoothDevice, connected: Bool) {
        // device.name is UNTRUSTED (T-05-01) — passed as a plain String into the pure seam only.
        onReading(DeviceReading(name: d.name, classMajor: d.deviceClassMajor,
                                address: d.addressString, connected: connected))
    }

    func stop() {                                            // nonisolated variant if deinit needs it (see PowerSourceMonitor)
        connectToken?.unregister(); connectToken = nil
        disconnectTokens.values.forEach { $0.unregister() }; disconnectTokens.removeAll()
        running = false
    }
}
```

### Three toggles in the existing Form (live-apply via `@AppStorage`)
```swift
// Source: SwiftUI @AppStorage idiom; slots into the existing SettingsView Form (VERIFIED structure)
@AppStorage("activity.charging")   private var chargingEnabled = true
@AppStorage("activity.nowPlaying") private var nowPlayingEnabled = true
@AppStorage("activity.device")     private var deviceEnabled = true

// Inside the Form (default ON — D-07):
Toggle("Charging", isOn: $chargingEnabled)
Toggle("Now Playing", isOn: $nowPlayingEnabled)
Toggle("Devices", isOn: $deviceEnabled)
```

### Pure resolver test shape (matches existing PowerActivityTests style)
```swift
// Source: mirrors IsletTests/DeviceActivityTests.swift / PowerActivityTests.swift (VERIFIED)
func testChargingOutranksDeviceAndMedia() {
    let p = resolve(activeTransient: .charging(.charging(percent: 47)),
                    nowPlaying: .playing(title: "x", artist: "y"),
                    nowPlayingHealthy: true, isExpanded: true)
    XCTAssertEqual(p, .charging(.charging(percent: 47)))   // D-02 rank 1 + D-04 over-expanded
}
func testNoTransientWhilePlayingReturnsToWings() {
    let p = resolve(activeTransient: nil, nowPlaying: .playing(title: "x", artist: "y"),
                    nowPlayingHealthy: true, isExpanded: false)
    XCTAssertEqual(p, .nowPlayingWings(.playing(title: "x", artist: "y")))  // D-02 yield-to-ambient
}
func testQueueDedupsDuplicateHead() {
    var q = TransientQueue()
    _ = q.enqueue(.charging(.charging(percent: 50)))
    let changed = q.enqueue(.charging(.charging(percent: 50)))
    XCTAssertFalse(changed)   // D-03 dedup
}
```

## State of the Art

| Old Approach (current code) | Phase-6 Approach | Why | Impact |
|--------------|------------------|--------------|--------|
| Precedence as a `ZStack` `if`-chain in `NotchPillView.body` (charging > expanded > media-wings > collapsed) | One `switch` over an `IslandPresentation` decided by the pure resolver | D-05 single arbiter; testable | View becomes render-only; precedence is unit-tested |
| Per-handler scheduling (`handlePower` + `dismissWorkItem`, `handleNowPlaying` + `mediaDismissWorkItem`) with no cross-activity ordering | One transient queue advanced off a single one-shot dismiss | D-03 sequential coexistence; no glitch/overlap | Adding the device transient is "enqueue", not new special-casing |
| Two activity quartets (Power, NowPlaying); device only has its pure seam | Three quartets; device monitor + state + wing finished | D-01 three real inputs | Resolver finally has all three to rank |
| No settings persistence | `@AppStorage` toggles + accent | APP-03 | Greenfield; no migration |

**Deprecated/outdated to avoid:** `create-dmg` (not installed), direct MediaRemote `dlopen` (blocked), Core Bluetooth for connect events, the `DEBUG_BT_SPIKE` path (delete), repeating `Timer`s (no-polling rule).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | IOBluetooth `register(forConnectNotifications:)` still fires on macOS 26 without an intrusive TCC prompt from this un-sandboxed LSUIElement agent | Pattern 7 / Runtime State | If a prompt IS required, `NSBluetoothAlwaysUsageDescription` must be added to `project.yml` and Success-Criterion-3's "no intrusive prompts" needs revisiting. **This is the deferred A1 verdict — already flagged as on-device-only.** Don't add the key speculatively. |
| A2 | The MediaRemote health check + "nicht verfügbar" fallback still pass on the installed macOS 26 build (D-16) | Pitfall 6 / v1 Ship | If reading is blocked on this exact build, Now-Playing degrades to "nicht verfügbar" (graceful by design) but the core feature is down — D-16 exists precisely to catch this live. Community note: 26.1 had *command* flakiness, fixed by 26.2. |
| A3 | `device.deviceClassMajor` returns `0x04` for audio devices at connect time (used only to pick the glyph, never to gate) | Pattern 7 | Cosmetic only — a wrong class falls through to `.generic`/`.headphones`; never blocks a splash (D-01). Already covered by the pure seam's fallback chain. |
| A4 | Stopping a monitor on toggle-off is clean (no race) and idle CPU returns to ~0 | Pattern 3 / D-09 | If start/stop proves racy on fast toggling, fall back to display-suppression (the resolver already supports forcing an activity out). Discretion explicitly allows either. |

**If this table looks empty of blockers:** A1 and A2 are the only two that gate *success criteria*, and both are already the **deferred on-device carry-overs** named in CONTEXT.md (BT UAT + the D-16 live re-check) — Phase 6 ships code-complete around them.

## Open Questions

1. **Resolver function vs. explicit `enum` state machine for the queue head.**
   - What we know: both are idiomatic; the pure-function-over-`@Published`-states matches the existing seams best.
   - What's unclear: nothing blocking — it's the locked Claude's-discretion call.
   - Recommendation: pure `resolve(...)` for ranking + a tiny `TransientQueue` value for the one stateful piece (Patterns 1+2). Don't model the whole app as a state machine.

2. **Accent threading: Environment value vs. direct `@AppStorage` reads in leaves.**
   - What we know: both live-update; `EqualizerBars` already takes a `tint`.
   - What's unclear: taste/coupling preference.
   - Recommendation: a custom `\.activityAccent` `EnvironmentKey` set once on the hosting view (cleanest, no prop-drilling).

3. **Does a disabled-Now-Playing toggle stop the perl child, or just force `.none`?**
   - What we know: `NowPlayingMonitor.stop()` terminates the child (best for idle CPU, D-09 preferred); but Now-Playing is the *ambient baseline*, so re-enabling must `start()` + re-read cleanly.
   - Recommendation: stop the child on disable, `start()` + `runHealthCheck` on re-enable (mirrors launch). Verify the restart re-reads current media on-device.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode / xcodebuild | Build, archive, test | ✓ | 26.6 (17F113) | — |
| Swift toolchain | Compile (Swift-5 language mode) | ✓ | 6.3.3 | — |
| xcodegen | Regenerate project after adding sources | ✓ | /opt/homebrew/bin/xcodegen | — |
| codesign | Ad-hoc sign (dry-run) / Developer-ID (deferred) | ✓ | /usr/bin/codesign | — |
| notarytool | Notarize (gated off in dry-run) | ✓ | Xcode bundled | — (dry-run skips) |
| stapler | Staple (gated off) | ✓ | /usr/bin/stapler | — (dry-run skips) |
| spctl | Gatekeeper verdict | ✓ | /usr/sbin/spctl | — |
| hdiutil | DMG (UDZO) creation | ✓ | /usr/bin/hdiutil | — (this IS the chosen path) |
| ditto / xattr | Bundle copy / quarantine in release.sh | ✓ | /usr/bin | — |
| Apple Developer ID + notary creds | REAL notarize/staple + clean-second-Mac open | ✗ | — | **Run as DRY-RUN (D-15)** — `release.sh` exits 0 with SKIP banner; real run deferred |
| Bluetooth test device | DEV-01/DEV-02 on-device UAT + A1 TCC verdict | ✗ | — | **Code-complete now, UAT deferred** (D-01) |

**Missing dependencies with no fallback:** None that block Phase-6 *code completion*. The two ✗ rows are the **explicitly-deferred carry-overs** (real notarization needs the $99/yr account; BT UAT needs a device) — both are accepted as deferred in CONTEXT.md.

**Missing dependencies with fallback:** The Developer-ID/notary credentials → the release pipeline runs unchanged as the placeholder-gated dry-run (the fallback IS the deliverable for D-15).

## Validation Architecture

> `.planning/config.json` not asserted to disable Nyquist — treating validation as enabled. The locked TDD discipline (pure logic unit-tested in ms; IOBluetooth/AppKit/release verified on-device) governs this phase.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (`@testable import Islet`), hosted in the `Islet` app target |
| Config file | `project.yml` → `IsletTests` `bundle.unit-test` (TEST_HOST = Islet.app); 10 existing test files, 956 LOC |
| Quick run command | `xcodebuild test -scheme Islet -destination 'platform=macOS' -only-testing:IsletTests/IslandResolverTests` |
| Full suite command | `xcodebuild test -scheme Islet -destination 'platform=macOS'` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| COORD-01 | Rank Charging > Device > Now Playing; transient over expanded (D-02/D-04) | unit | `…-only-testing:IsletTests/IslandResolverTests` | ❌ Wave 0 |
| COORD-01 | No transient → yield to now-playing wings / idle (D-02 ambient) | unit | same | ❌ Wave 0 |
| COORD-01 | Queue ordering: A then B sequentially (D-03) | unit | same | ❌ Wave 0 |
| COORD-01 | Queue dedup: duplicate head/pending not stacked; bounded depth (D-03) | unit | same | ❌ Wave 0 |
| COORD-01 | Resolver routed through the single `updateVisibility()` (fullscreen/clamshell gate intact) | manual/on-device | (UAT: trigger splash in fullscreen → hidden) | — |
| DEV-01/02 | Device edge predicate (connect/disconnect, glyph, label, burst/debounce) | unit | `…-only-testing:IsletTests/DeviceActivityTests` | ✅ (exists, 182 LOC) |
| DEV-01/02 | IOBluetooth real connect/disconnect splash | manual/on-device | (UAT: connect/disconnect AirPods — **deferred**, no device) | — |
| APP-03 | Toggles persist + live-apply; accent persists | manual/on-device | (UAT: flip toggles, restart, observe) | — |
| APP-03 | Accent tints bolt/bars/device-icon only; island stays black | manual/visual | (UAT: pick a swatch, inspect) | — |
| D-16 | Now-Playing health check + "nicht verfügbar" still pass | manual/on-device | (UAT: launch, confirm isHealthy; test play/pause live) | — |
| APP-04 (dry-run) | `release.sh` produces `dist/Islet.dmg`, exits 0 with SKIP banner | manual/script | `./scripts/release.sh` (expect SKIP banner, ad-hoc DMG) | — |

### Sampling Rate
- **Per task commit:** the quick `IslandResolverTests` run (and `DeviceActivityTests` for device-edge changes).
- **Per wave merge:** full `xcodebuild test -scheme Islet` (must stay green; 102+ tests, no regressions — the Phase-5 baseline).
- **Phase gate:** full suite green + the on-device UAT checklist (resolver coexistence in fullscreen, toggles, accent, D-16 health, dry-run DMG) before `/gsd-verify-work`. BT-device UAT and real notarization remain deferred carry-overs.

### Wave 0 Gaps
- [ ] `IsletTests/IslandResolverTests.swift` — covers COORD-01 rank + queue ordering/dedup/bound (the new pure seam).
- [ ] (No new conftest/fixtures needed — XCTest, no shared fixtures; construct values by hand as the existing tests do.)
- [ ] (Framework already installed — `IsletTests` exists; no install step.)

*Device edge predicate is already covered by the existing `DeviceActivityTests.swift` (Phase-5 Tasks 1-2) — no new pure-test file needed for the device classification itself.*

## Security Domain

> `security_enforcement` not explicitly disabled → included. Phase 6 adds settings + a BT monitor; the surface is small and mostly inherited.

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | No accounts/auth in v1 |
| V3 Session Management | no | No sessions |
| V4 Access Control | partial | macOS TCC (Bluetooth consent — the deferred A1 verdict) + SMAppService login-item approval; no app-level access control |
| V5 Input Validation | **yes** | `device.name` is UNTRUSTED external input (T-05-01) — the pure `deviceLabel(...)` returns it as a plain String only; SwiftUI `Text` is inert to format strings; `.lineLimit(1)+.truncationMode(.tail)` bounds it. Already implemented in `DeviceActivity.swift`. |
| V6 Cryptography | no | Notarization signing uses Apple's toolchain (codesign/notarytool); no hand-rolled crypto. Notary creds live in the keychain (profile NAME only in `release.sh`). |

### Known Threat Patterns for this stack
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Untrusted Bluetooth `device.name` injected into UI/logs (T-05-01) | Tampering / Info-disclosure | Plain String only; never format/shell; `Text` bounded — already done in the pure seam |
| Orphaned perl/MediaRemoteAdapter child after controller death (T-04-12) | DoS (resource leak) | `deinit` calls `nowPlayingMonitor.stop()` — preserved; the device monitor adds analogous IOBluetooth token teardown |
| Use-after-free of the IOPS/IOBluetooth context pointer (T-03-06) | Tampering | `nonisolated stop()` removes the source/tokens in `deinit` before the owner frees — mirror for `BluetoothMonitor` |
| Notary credentials leaking into the repo | Info-disclosure | `release.sh` uses a keychain profile NAME only; placeholders in the dry-run; no secret in git |
| Speculative `NSBluetoothAlwaysUsageDescription` surfacing an unneeded TCC prompt | (UX/consent) | Add the key ONLY if the deferred A1 verdict requires it |

## Sources

### Primary (HIGH confidence)
- Codebase (read this session): `NotchWindowController.swift`, `NotchPillView.swift`, `DeviceActivity.swift`, `ChargingActivityState.swift`, `NowPlayingState.swift`, `PowerSourceMonitor.swift`, `NowPlayingMonitor.swift`, `SettingsView.swift`, `LaunchAtLogin.swift`, `AppDelegate.swift`, `IsletApp.swift`, `BluetoothSpike.swift`, `scripts/release.sh`, `project.yml`, `IsletTests/*` — the real seams the planner extends.
- Live build machine probes: `sw_vers` (macOS 27.0 / 26A5368g = Tahoe family), `xcodebuild -version` (26.6), `swift --version` (6.3.3), CLI availability (all release tools present, `create-dmg` absent).
- Memory: `build-machine-macos26-toolchain.md` (Swift-5 mode explicit, Window(id:) over Settings, hdiutil over create-dmg) — corroborated live.
- CLAUDE.md (project stack mandates: IOBluetooth not Core Bluetooth, MediaRemote adapter, un-sandboxed, small AppKit surface).
- github.com/ungive/mediaremote-adapter — v0.7.6 (2026-05-11), "all versions of macOS".
- developer.apple.com/documentation/iobluetooth — `register(forConnectNotifications:selector:)`.

### Secondary (MEDIUM confidence)
- hackingwithswift.com / fatbobman.com — `@AppStorage` live-update + Observation/UserDefaults patterns (2026).
- WebSearch (corroborated): mediaremote-adapter reads on macOS 26; command flakiness on 26.1 fixed by 26.2 (community report — verify live for D-16).
- splinter.com.au / betterprogramming.pub — enum state-machine vs pure-reducer idioms in Swift.

### Tertiary (LOW confidence — flagged for live verification)
- IOBluetooth TCC-prompt behavior on macOS 26 from a background LSUIElement agent — no authoritative deprecation/prompt doc found; **this is the deferred A1 on-device verdict** (matches the Phase-5 spike's purpose).

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new libs; everything verified against the live machine + existing pinned deps.
- Architecture (resolver + queue): HIGH — grounded in the three real `@Published` inputs and the existing one-shot dismiss; the shape is a direct generalization of code that already works.
- Settings/accent: HIGH — greenfield but trivial; the `tint`/`foregroundStyle` hooks already exist.
- Device wiring: HIGH on shape (clone of the power triple + the spike's retention pattern), MEDIUM on the A1 TCC-prompt behavior (deferred on-device verdict).
- Ship gate: HIGH on the dry-run mechanics (CLIs present, script self-gates), MEDIUM on the D-16 live health result (must be re-checked on the installed build).
- Pitfalls: HIGH — derived from the code's own documented pitfalls + the queue's new failure modes.

**Research date:** 2026-06-28
**Valid until:** ~2026-07-28 for the SwiftUI/AppKit/IOBluetooth patterns (stable); re-verify the macOS-26 Now-Playing health + any IOBluetooth/TCC behavior at execution time and after every macOS point update (per the standing Phase-4 blocker).
