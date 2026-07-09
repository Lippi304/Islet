# Phase 18: Song-Change Toast - Pattern Map

**Mapped:** 2026-07-09
**Files analyzed:** 6 (modified only — no new files, per RESEARCH.md "Recommended Project Structure")
**Analogs found:** 6 / 6 (all in-file, self-analog — this phase extends existing files rather than creating new ones)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|--------------------|------|-----------|-----------------|---------------|
| `Islet/Notch/IslandResolver.swift` (new gate fn + `resolve(...)` param) | service (pure reducer) | transform | `nowPlayingLaunchGate(...)` in same file (lines 70-72) | exact — same file, same shape, direct precedent from Phase 17 |
| `Islet/Notch/NowPlayingState.swift` (new `@Published` field) | store | event-driven | `hasPlayedSinceLaunch` field in same file (lines 21-25) | exact — identical "orthogonal published flag" shape |
| `Islet/Notch/NotchWindowController.swift` — `handleNowPlaying(_:_:)` (detection + trigger) | controller | event-driven | same function, existing body (lines 945-1017) | exact — the toast trigger is inserted directly into this function |
| `Islet/Notch/NotchWindowController.swift` — new `scheduleToastDismiss()` | controller | event-driven / timer | `scheduleMediaDismiss(after:)` (lines 1023-1037) | exact — byte-for-byte structural mirror per RESEARCH.md Pattern 2 |
| `Islet/Notch/NotchPillView.swift` (toast render) | component (SwiftUI view) | request-response (render) | `mediaExpanded(_:art:)` title/artist `VStack` (lines 500-519) + `expandedIsland`/`blobShape` (lines 194-230) | exact — UI-SPEC.md locks reuse of `blobShape`, `expandedSize`, and the title/artist text styling verbatim |
| `Islet/ActivitySettings.swift` + `Islet/SettingsView.swift` (new toggle) | config | CRUD (persisted pref) | `nowPlayingKey` + `Toggle("Now Playing", ...)` (ActivitySettings.swift lines 15-17; SettingsView.swift lines 29, 133) | exact — direct sibling key/toggle addition |
| `IsletTests/IslandResolverTests.swift` (new test cases) | test | transform (unit) | `testNowPlayingLaunchGateForcesNoneWhenNotYetPlayed` + `testGatedPausedNotExpandedIsIdle` (lines 86-117) | exact — Phase 17's launch-gate test block is the direct structural template |

## Pattern Assignments

### `Islet/Notch/IslandResolver.swift` — toast suppression gate + `resolve(...)` param

**Analog:** `nowPlayingLaunchGate(...)` + `resolve(...)`, same file

**Imports pattern** (line 1):
```swift
import Foundation
```
Pure seam — Foundation only, no AppKit/SwiftUI/Timer. The toast gate function MUST follow this same import discipline (file header, lines 3-8, explicitly forbids Timer/clock/AppKit here).

**Core pattern — the existing ambient-gate shape to mirror** (lines 70-72):
```swift
func nowPlayingLaunchGate(hasPlayedSinceLaunch: Bool, nowPlaying: NowPlayingPresentation) -> NowPlayingPresentation {
    hasPlayedSinceLaunch ? nowPlaying : .none
}
```
A toast-suppression gate follows the identical total/pure/one-line shape — e.g. `songChangeToastGate(activeTransient:isExpanded:toastEnabled:toast:) -> TrackToast?` with a single `guard`/ternary (RESEARCH.md Pattern 1 sketch, lines 211-216 of RESEARCH.md).

**`resolve(...)` — exact current signature to extend, NOT replace** (lines 34-54):
```swift
func resolve(activeTransient: ActiveTransient?,
             nowPlaying: NowPlayingPresentation,
             nowPlayingHealthy: Bool,
             hasPlayedSinceLaunch: Bool,
             isExpanded: Bool) -> IslandPresentation {
    switch activeTransient {                              // D-04: transient wins even over expanded
    case .charging(let a): return .charging(a)           // D-02 rank 1
    case .device(let d):   return .device(d)             // D-02 rank 2
    case nil: break
    }
    if isExpanded {
        if !nowPlayingHealthy { return .nowPlayingExpanded(nowPlaying, healthy: false) } // D-12
        if nowPlaying != .none { return .nowPlayingExpanded(nowPlaying, healthy: true) }
        return .expandedIdle
    }
    let ambient = nowPlayingLaunchGate(hasPlayedSinceLaunch: hasPlayedSinceLaunch, nowPlaying: nowPlaying)
    if ambient != .none { return .nowPlayingWings(ambient) }   // D-02 ambient yield (rank 3)
    return .idle
}
```
Add the toast parameter so it is consumed ONLY inside the `if ambient != .none { return .nowPlayingWings(ambient) }` line (per D-04, never inside `isExpanded`; per D-02, the `switch activeTransient` returns before the toast param is even read — this is what makes suppression "free"). Recommended shape (RESEARCH.md A1, Open Question 1): add a `toast: TrackToast?` associated value to `.nowPlayingWings`, i.e. `case nowPlayingWings(NowPlayingPresentation, toast: TrackToast?)` in the `IslandPresentation` enum (lines 17-24).

**`IslandPresentation` enum — the case to extend** (lines 17-24):
```swift
enum IslandPresentation: Equatable {
    case idle                                              // collapsed, nothing to show
    case charging(ChargingActivity)                        // D-02 rank 1 transient
    case device(DeviceActivity)                            // D-02 rank 2 transient
    case nowPlayingWings(NowPlayingPresentation)           // D-02 rank 3 ambient (collapsed glance)
    case nowPlayingExpanded(NowPlayingPresentation, healthy: Bool) // D-12 expanded media / "nicht verfügbar"
    case expandedIdle                                      // expanded, healthy, nothing playing (date/time)
}
```

**Anti-pattern to avoid (explicit in this file's own precedent):** Do NOT add the toast as a 3rd case inside `enum ActiveTransient` (lines 28-31) or route it through `TransientQueue` (lines 112-163) — D-02 requires silent skip, not queueing, which is exactly what `TransientQueue.enqueue`/`advance`/`updateHead` do NOT provide (those are FIFO/dedup semantics for a fundamentally different requirement).

---

### `Islet/Notch/NowPlayingState.swift` — new toast field

**Analog:** `hasPlayedSinceLaunch` field, same file

**Full existing file for context** (lines 1-30) — the pattern to extend:
```swift
import AppKit

final class NowPlayingState: ObservableObject {
    @Published var presentation: NowPlayingPresentation = .none
    @Published var artwork: NSImage?
    @Published var isHealthy: Bool = true
    // Phase 17 / NOW-04 — ORTHOGONAL to presentation (mirrors isHealthy's own
    // orthogonality). Default false (gated) — set to true ONCE in handleNowPlaying on the first
    // .playing snapshot and NEVER reset (D-02: no re-arm for the rest of the process lifetime).
    @Published var hasPlayedSinceLaunch: Bool = false
    @Published var position: PlaybackPosition?
}
```
Add a new `@Published var songChangeToast: TrackToast? = nil` (or equivalent title/artist pair struct) directly below `hasPlayedSinceLaunch`, following the exact same doc-comment convention (why it's orthogonal, when it's set/cleared). Per RESEARCH.md Open Question 2: store the toast's own snapshot value SEPARATELY from `presentation` — do NOT alias it to `presentation` (D-03's rapid-skip window requires the two to diverge: toast shows "last settled track" while `presentation` has already moved on).

---

### `Islet/Notch/NotchWindowController.swift` — detection in `handleNowPlaying` + new dismiss timer

**Analog:** existing `handleNowPlaying(_:_:)` body + `scheduleMediaDismiss(after:)`

**Spring/timing constants already defined — reuse, do not add new ones** (lines 158-165, 233-234):
```swift
private var mediaDismissWorkItem: DispatchWorkItem?
private let pausedTimeout: TimeInterval = 15.0   // D-06 single tuning seed
...
private let activityDuration: TimeInterval = 3.0   // D-09 single tuning seed
...
private let springResponse: Double = 0.35
private let springDamping: Double = 0.65
```
The toast's own `toastDismissWorkItem: DispatchWorkItem?` property and its ~3.0s constant should reuse `activityDuration` (matches CONTEXT.md's "~3s"), NOT `pausedTimeout`.

**`handleNowPlaying(_:_:)` — exact current body, the integration point** (lines 945-1017):
```swift
private func handleNowPlaying(_ snapshot: TrackSnapshot?, _ art: NSImage?) {
    let p = nowPlayingPresentation(from: snapshot)
    let previous = nowPlayingState.presentation
    let previousPosition = nowPlayingState.position
    nowPlayingState.isHealthy = true
    if case .playing = p { nowPlayingState.hasPlayedSinceLaunch = true }

    withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
        nowPlayingState.presentation = p
        nowPlayingState.position = resolvePublishedPosition(previous: previous, previousPosition: previousPosition,
                                                              incoming: p, incomingPosition: playbackPosition(from: snapshot),
                                                              now: Date().timeIntervalSince1970)
        if let art {
            nowPlayingState.artwork = art
        } else if p == .none || !isSameTrack(previous, p) {
            nowPlayingState.artwork = nil
        }
        renderPresentation()
    }
    updateVisibility()

    switch p {
    case .playing: mediaDismissWorkItem?.cancel()
    case .paused:  if previous != p { scheduleMediaDismiss(after: pausedTimeout) }
    case .none:    mediaDismissWorkItem?.cancel()
    }
}
```
The toast-trigger check inserts alongside this, reading `previous` (already captured before overwrite — reuse the SAME capture, don't re-read) and the PRE-callback `hasPlayedSinceLaunch` value (must be captured BEFORE line `if case .playing = p { nowPlayingState.hasPlayedSinceLaunch = true }` mutates it — RESEARCH.md Pitfall 2). Guard order per RESEARCH.md Pitfall 1: `p != .none` (real track) → `!isSameTrack(previous, p)` (genuine change) → the D-02/D-04 suppression gate computed FIRST (RESEARCH.md Pitfall 3) → only then call the schedule function.

**`scheduleMediaDismiss(after:)` — exact template for the new `scheduleToastDismiss()`** (lines 1023-1037):
```swift
private func scheduleMediaDismiss(after seconds: TimeInterval) {
    mediaDismissWorkItem?.cancel()
    let work = DispatchWorkItem { [weak self] in
        guard let self else { return }
        withAnimation(.spring(response: self.springResponse, dampingFraction: self.springDamping)) {
            self.nowPlayingState.presentation = .none   // collapse the media glance
            self.nowPlayingState.artwork = nil
            self.nowPlayingState.position = nil
            self.renderPresentation()                   // Phase 6: re-resolve to ambient/idle
        }
        self.updateVisibility()   // re-evaluate the single show/hide site
    }
    mediaDismissWorkItem = work
    DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
}
```
Copy this shape exactly for `scheduleToastDismiss()`: own `toastDismissWorkItem` property, cancel-then-reschedule (this cancel-then-reschedule call IS D-03's "restart on rapid skip" — no extra logic needed, per RESEARCH.md Pattern 2), clears `nowPlayingState.songChangeToast = nil` inside the spring block instead of `presentation`/`artwork`/`position`.

**Toggle-off live-clear pattern — exact precedent for NOW-06's Pitfall 4** (lines 869-880):
```swift
// Now Playing — stop the perl child on disable (RESEARCH Open Q3: prefer a clean restart);
if activityEnabled(ActivitySettings.nowPlayingKey) {
    startNowPlayingMonitor()
} else if nowPlayingMonitor != nil {
    nowPlayingMonitor?.stop(); nowPlayingMonitor = nil
    mediaDismissWorkItem?.cancel()
    nowPlayingState.presentation = .none
    nowPlayingState.artwork = nil
    nowPlayingState.position = nil
}
```
This is inside the settings-apply function (`applyActivitySettings`, containing this block). The new toast toggle needs an analogous branch: when flipped off while a toast is showing, `toastDismissWorkItem?.cancel()` + `nowPlayingState.songChangeToast = nil` — mirrored exactly, not just gating future triggers (RESEARCH.md Pitfall 4).

**`currentPresentation()` — where the pre-resolver toggle read happens** (lines 452-465):
```swift
private func currentPresentation() -> IslandPresentation {
    let npEnabled = activityEnabled(ActivitySettings.nowPlayingKey)
    let np = npEnabled ? nowPlayingState.presentation : .none   // D-09 disabled NP → forced .none
    let healthy = nowPlayingHealthGate(enabled: npEnabled, isHealthy: nowPlayingState.isHealthy)
    return resolve(activeTransient: transientQueue.head,
                   nowPlaying: np,
                   nowPlayingHealthy: healthy,
                   hasPlayedSinceLaunch: nowPlayingState.hasPlayedSinceLaunch,
                   isExpanded: interaction.isExpanded)
}
```
The toast's own `@AppStorage`-backed enabled flag reads the same way (`activityEnabled(ActivitySettings.songChangeToastKey)`) and is passed into `resolve(...)` as the new toast parameter — applied BEFORE the resolver, never inside it (D-09 discipline).

---

### `Islet/Notch/NotchPillView.swift` — toast visual (expand-downward)

**Analog:** `mediaExpanded(_:art:)` title/artist block + `expandedIsland`/`blobShape` skeleton

**`blobShape` helper — reuse exactly, do not add a new shape helper** (lines 220-230):
```swift
private func blobShape<Content: View>(topCornerRadius: CGFloat,
                                       bottomCornerRadius: CGFloat,
                                       alignment: Alignment = .center,
                                       @ViewBuilder content: () -> Content) -> some View {
    NotchShape(topCornerRadius: topCornerRadius, bottomCornerRadius: bottomCornerRadius)
        .fill(Color.black)
        .matchedGeometryEffect(id: "island", in: ns)
        .frame(width: Self.expandedSize.width, height: Self.expandedSize.height)
        .overlay(alignment: alignment) { content() }
        .onTapGesture { onClick() }
}
```
Per UI-SPEC.md's Motion & Interaction Contract: the toast reuses `blobShape(topCornerRadius: 6, bottomCornerRadius: 20)` with the SAME `Self.expandedSize` (360×144) and default `.center` alignment (like `expandedIsland`, NOT `.top` like `mediaExpanded` — the toast's ~35-40pt text block doesn't need camera-clearance pinning).

**Title/artist text styling — exact tokens to reuse verbatim** (lines 504-515, inside `mediaExpanded`):
```swift
VStack(alignment: .leading, spacing: 1) {
    Text(meta.title)
        .font(.system(size: 15, weight: .bold, design: .rounded))
        .foregroundStyle(.white)
        .lineLimit(1)
        .truncationMode(.tail)
    Text(meta.artist)
        .font(.system(size: 12, design: .rounded))
        .foregroundStyle(.secondary)   // grey (D-10)
        .lineLimit(1)
        .truncationMode(.tail)
}
```
UI-SPEC.md locks: same 15pt bold white title / 12pt secondary artist tokens, but the toast's own `VStack(spacing: 2)` (not `spacing: 1`) and **center-aligned** (not `.leading`) since there's no leading art thumbnail crowding it. Both lines keep `.lineLimit(1)` + `.truncationMode(.tail)`.

**Switch statement — the case to extend** (lines 133-148):
```swift
switch presentation {
case .charging(let a):
    wings(for: a)
case .device(let d):
    deviceWings(for: d)
case .nowPlayingWings(let p):
    mediaWings(p, art: nowPlaying.artwork)
case .nowPlayingExpanded(let p, true):
    mediaExpanded(p, art: nowPlaying.artwork)
case .nowPlayingExpanded(_, false):
    mediaUnavailable
case .expandedIdle:
    expandedIsland
case .idle:
    collapsedIsland
}
```
If `.nowPlayingWings` gains a `toast:` associated value (per the resolver's recommended shape), this arm becomes `case .nowPlayingWings(let p, let toast):` and branches internally: `toast != nil` renders the new toast blob view, `toast == nil` renders the existing `mediaWings(p, art:)` collapsed glance unchanged.

---

### `Islet/ActivitySettings.swift` + `Islet/SettingsView.swift` — new toggle

**Analog:** `nowPlayingKey` + `Toggle("Now Playing", ...)`, same two files

**`ActivitySettings.swift` — key namespace to extend** (lines 13-22):
```swift
enum ActivitySettings {
    static let chargingKey   = "activity.charging"
    static let nowPlayingKey = "activity.nowPlaying"
    static let deviceKey     = "activity.device"
    static let accentIndexKey = "accentIndex"
    static let hideInFullscreenKey = "notch.hideInFullscreen"
    ...
}
```
Add `static let songChangeToastKey = "activity.songChangeToast"` next to `nowPlayingKey`, following the `activity.*` namespace convention (RESEARCH.md A3).

**`SettingsView.swift` — `@AppStorage` declaration + Toggle placement** (lines 29, 132-135):
```swift
@AppStorage(ActivitySettings.nowPlayingKey) private var nowPlayingEnabled = true
...
Section("Activities") {
    Toggle("Charging", isOn: $chargingEnabled)
    Toggle("Now Playing", isOn: $nowPlayingEnabled)
    Toggle("Devices", isOn: $deviceEnabled)
}
```
Add `@AppStorage(ActivitySettings.songChangeToastKey) private var songChangeToastEnabled = true` (default `true`, matching `nowPlayingEnabled`'s default per CONTEXT.md discretion note) and insert `Toggle("Song-Change Toast", isOn: $songChangeToastEnabled)` directly after the `Toggle("Now Playing", ...)` line — exact label per UI-SPEC.md's Copywriting Contract.

---

### `IsletTests/IslandResolverTests.swift` — new gate/resolver test cases

**Analog:** Phase 17's launch-gate test block, same file (lines 84-131)

```swift
// MARK: nowPlayingLaunchGate(...) / hasPlayedSinceLaunch — Phase 17 NOW-04 regression coverage

func testNowPlayingLaunchGateForcesNoneWhenNotYetPlayed() {
    XCTAssertEqual(nowPlayingLaunchGate(hasPlayedSinceLaunch: false,
                                        nowPlaying: .paused(title: "Song", artist: "Artist")),
                   .none)
    XCTAssertEqual(nowPlayingLaunchGate(hasPlayedSinceLaunch: true,
                                        nowPlaying: .paused(title: "Song", artist: "Artist")),
                   .paused(title: "Song", artist: "Artist"))
}

func testGatedPausedNotExpandedIsIdle() {
    let r = resolve(activeTransient: nil,
                    nowPlaying: .paused(title: "Song", artist: "Artist"),
                    nowPlayingHealthy: true,
                    hasPlayedSinceLaunch: false,
                    isExpanded: false)
    XCTAssertEqual(r, .idle)
}

func testGatedPausedExpandedStillShowsRealState() {
    let r = resolve(activeTransient: nil,
                    nowPlaying: .paused(title: "Song", artist: "Artist"),
                    nowPlayingHealthy: true,
                    hasPlayedSinceLaunch: false,
                    isExpanded: true)
    XCTAssertEqual(r, .nowPlayingExpanded(.paused(title: "Song", artist: "Artist"), healthy: true))
}
```
Add a new `// MARK: songChangeToastGate(...) — Phase 18 NOW-05 coverage` block in the same file, in this exact style (direct `XCTAssertEqual` calls, one Given/When/Then comment per test, hand-built `NowPlayingPresentation`/`ActiveTransient` values, no mocks/fixtures). Cover per Wave 0 Gaps in RESEARCH.md: genuine-change → toast shown; same-track play↔pause → not re-triggered; D-02 (active transient present) → suppressed; D-04 (`isExpanded: true`) → suppressed; first-track-after-launch (`hasPlayedSinceLaunch` pre-value false) → suppressed. No new test file — extend this one (313 lines today).

## Shared Patterns

### Pure-seam / controller split (repo-wide convention)
**Source:** File headers of `IslandResolver.swift` (lines 3-8) and `NowPlayingPresentation.swift` (lines 3-10)
**Apply to:** All 3 layers this phase touches — detection/gating logic goes in `IslandResolver.swift` (Foundation-only, unit-tested), timer/controller wiring goes in `NotchWindowController.swift` (`@MainActor`, verified on-device), rendering goes in `NotchPillView.swift` (SwiftUI, UI-phase concern already locked by 18-UI-SPEC.md).
```swift
// Islet/Notch/IslandResolver.swift lines 3-8
// Phase 6 / COORD-01 — the PURE priority resolver: the SINGLE arbiter (D-05) ...
// Like PowerActivity, DeviceActivity, and NowPlayingPresentation, this imports ONLY
// Foundation — no AppKit, no SwiftUI, no IOBluetooth, no Timer/clock ...
```

### One-shot `DispatchWorkItem` dismiss timer (cancel-then-reschedule)
**Source:** `NotchWindowController.swift` lines 1023-1037 (`scheduleMediaDismiss`), also `scheduleActivityDismiss` (line 797)
**Apply to:** The toast's new `scheduleToastDismiss()` — every existing ~3s/15s dismiss in this codebase uses this exact idiom, never a recurring `Timer`.

### `@AppStorage` toggle applied BEFORE the resolver (D-09 discipline)
**Source:** `NotchWindowController.swift` `currentPresentation()` lines 452-465; `SettingsView.swift` lines 28-31
**Apply to:** The new `songChangeToastKey` toggle — read via `activityEnabled(ActivitySettings.songChangeToastKey)` and passed as a plain `Bool` into `resolve(...)`, never checked inside `resolve(...)` itself.

### Toggle-off live-clear branch
**Source:** `NotchWindowController.swift` lines 869-880 (the `nowPlayingKey` disable branch inside the settings-apply function)
**Apply to:** The new toast toggle's disable path — cancel `toastDismissWorkItem`, clear `nowPlayingState.songChangeToast`, not just gate future triggers (Pitfall 4).

## No Analog Found

None — every file this phase touches already has a direct, exact-match in-file precedent from Phase 4/6/17 to mirror. No new files are created (confirmed by RESEARCH.md's "Recommended Project Structure": "No new files. Extend in place.").

## Metadata

**Analog search scope:** `Islet/`, `Islet/Notch/`, `IsletTests/` (all files named in CONTEXT.md canonical_refs and RESEARCH.md Sources)
**Files scanned:** `IslandResolver.swift` (163 lines, full read), `NowPlayingPresentation.swift` (135 lines, full read), `NowPlayingState.swift` (30 lines, full read), `ActivitySettings.swift` (48 lines, full read), `SettingsView.swift` (258 lines, full read), `NotchWindowController.swift` (1099 lines, targeted reads: 440-489, 855-894, 945-1044), `NotchPillView.swift` (857 lines, targeted reads: 100-249, 492-571), `IslandResolverTests.swift` (313 lines, targeted reads: 1-53, 84-123)
**Pattern extraction date:** 2026-07-09
