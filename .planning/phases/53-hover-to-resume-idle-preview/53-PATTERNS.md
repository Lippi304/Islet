# Phase 53: Hover-to-Resume Idle Preview - Pattern Map

**Mapped:** 2026-07-21
**Files analyzed:** 4 (2 locked modifications + 2 discretion-gated modifications)
**Analogs found:** 4 / 4 (all analogs are existing code in the SAME files being modified — this phase is a pure extension of already-proven patterns, no cross-module borrowing needed)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|--------------------|------|-----------|-----------------|----------------|
| `Islet/Notch/NotchPillView.swift` (new hover-preview render branch + 3rd tap closure) | component (SwiftUI view) | request-response (hover-state → render branch; tap → controller callback) | same file: `secondaryBubble(_:)` hover/tap (`~2883-2920`) + `.homeLastPlayed` synthetic-presentation branch (`~945-951`) + `mediaWingsRow`/`mediaUnavailableContent` (`~2402-2412`, `~3234-3247`) | exact — same file, established idiom |
| `Islet/Notch/NotchWindowController.swift` (hover wiring, dedicated resume-tap handler, inferred-failure timeout watcher, `collapsedInteractiveZone()` widening) | controller (AppKit window/event glue) | event-driven (pointer + click) with an inferred-timeout sub-flow | same file: `collapsedInteractiveZone()` (`1420-1429`) + `handleSecondaryTap()` (`1703-1705`); `Islet/Notch/NowPlayingMonitor.swift`'s `runHealthCheck` (`129-141`) for the timeout-inference shape | exact |
| `Islet/Notch/IslandResolver.swift` (OPTIONAL — only if the discretion call picks a new `IslandPresentation` case over a view-local branch) | model (pure resolver / reducer) | transform | same file: `resolve(...)`'s `.homeLastPlayed`/`.nowPlayingWings` branches (`155-174`) | exact |
| `IsletTests/IslandResolverTests.swift` (OPTIONAL — only if a new resolver case is added) | test | transform (pure-function unit test) | same file: `testNoTransientWhilePlayingReturnsToWings` (`76-85`), `testExpandedHealthyNoMediaHasPlayedShowsLastPlayed` (`194-204`) | exact |

No genuinely new file is created. `NowPlayingState.swift` and `NowPlayingMonitor.swift` are read-only data sources for this phase (their existing `lastKnownTrack`/`togglePlayPause()` are consumed as-is, per RESEARCH.md's "Recommended Project Structure").

---

## Pattern Assignments

### `Islet/Notch/NotchPillView.swift` (component, request-response)

**Analog:** itself — `secondaryBubble(_:)` (hover+tap idiom), `.homeLastPlayed` (synthetic-presentation idiom), `mediaWingsRow`/`mediaUnavailableContent` (the exact visuals to reuse)

**Closure-declaration pattern to mirror for the 3rd tap closure** (`NotchPillView.swift:205-228`):
```swift
// D-02 — the CLICK-to-expand callback. The view stays AppKit-free: it only reports
// "the pill was tapped" via this plain closure. NotchWindowController owns the
// closure ...
var onClick: () -> Void = {}

// Phase 42 / DUAL-01 ... the secondary bubble's tap callback, mirroring `onClick`'s
// exact declaration style. ... repurposed to toggle play/pause directly (see
// `secondaryBubble(_:)` and `NotchWindowController.handleSecondaryTap()`).
// Defaults to a no-op so the DEBUG #Previews build without a controller.
var onSecondaryTap: () -> Void = {}
```
Add a 3rd closure (e.g. `onResumeTap: () -> Void = {}`) with the same doc-comment shape and no-op default — NOT a reuse of `onClick` (which expands to Home, contradicting D-01) and NOT a literal passthrough of `onSecondaryTap` (semantically a distinct call site per RESEARCH.md Pitfall 4/Anti-Pattern).

**Hover-state + tap-to-toggle pattern to mirror** (`NotchPillView.swift:2883-2920`, Phase 42 precedent):
```swift
@State private var isSecondaryBubbleHovering = false

private func secondaryBubble(_ activity: SecondaryActivity) -> some View {
    switch activity {
    case .nowPlaying(let p):
        let isPlaying = isPlayingFor(p)
        return Circle()
            .fill(islandFill)
            .matchedGeometryEffect(id: "secondaryBubble", in: ns)
            .frame(width: Self.secondaryBubbleDiameter, height: Self.secondaryBubbleDiameter)
            .overlay(secondaryBubbleGlassOverlay)
            .overlay(artThumbnailCircular(nowPlaying.artwork, diameter: Self.secondaryBubbleDiameter))
            .overlay(Circle().strokeBorder(Color.white.opacity(0.35), lineWidth: 1))
            .overlay(Circle().fill(Color.black.opacity(isSecondaryBubbleHovering ? 0.45 : 0)))
            .overlay(
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .opacity(isSecondaryBubbleHovering ? 1 : 0)
            )
            .onHover { isSecondaryBubbleHovering = $0 }
            // Tap now toggles playback directly (see onSecondaryTap's own decl comment).
            .onTapGesture { onSecondaryTap() }
    }
}
```
For the idle-hover preview, the new render branch needs its own `@State`-or-computed hover flag (mirroring `isSecondaryBubbleHovering`) and an `.onHover { ... }` + `.onTapGesture { onResumeTap() }` pair wired the same way — NOT `.onTapGesture { onClick() }` (that is `mediaWingsOrToast`'s EXPAND semantics, see below).

**Synthetic-presentation construction to mirror** (`NotchPillView.swift:945-951`, Phase 30 precedent):
```swift
case .homeLastPlayed:
    // Phase 30 / HOME-02 (D-04): synthesize a .paused presentation from the
    // sticky last-played snapshot and feed the SAME mediaContent(_:art:) the
    // live state uses -- no second parallel view.
    mediaContent(.paused(title: nowPlaying.lastKnownTrack?.title ?? "",
                          artist: nowPlaying.lastKnownTrack?.artist ?? ""),
                 art: nowPlaying.lastKnownTrack?.artwork)
```
This phase's collapsed-idle-preview must build `.playing(...)` (NOT `.paused`, per RESEARCH.md Pattern 1) from `nowPlaying.lastKnownTrack` so `EqualizerBars(isPlaying:)` bounces per D-02:
```swift
// isPlayingFor(_:) — NotchPillView.swift:2952-2955
private func isPlayingFor(_ presentation: NowPlayingPresentation) -> Bool {
    if case .playing = presentation { return true }
    return false
}
```

**The exact visual to reuse verbatim** (`NotchPillView.swift:2402-2412`, the wings row: art left / equalizer right):
```swift
private func mediaWingsRow(_ presentation: NowPlayingPresentation, art: NSImage?) -> some View {
    let isPlaying = isPlayingFor(presentation)
    return HStack(spacing: 0) {
        artThumbnail(art, side: Self.wingsSize.height - 8, corner: 6)  // LEFT wing
            .padding(.leading, 22)   // inset from the outer notch edge (user request)
        Spacer()                                            // clears the physical camera bridge
        EqualizerBars(isPlaying: isPlaying)  // RIGHT wing — EQ-01 bars, fixed white (no accent)
            .padding(.trailing, 24)  // inset from the outer notch edge (user request)
    }
    .frame(width: Self.wingsSize.width, height: Self.wingsSize.height)
}
```
Call this directly (or the `mediaWingsOrToast` wrapper it feeds, `NotchPillView.swift:2368-2396`) for the preview's content — do not build a second parallel wings view.

**Idle-case render branch this phase touches** (`NotchPillView.swift:923-924`):
```swift
case .idle:
    collapsedIsland                                                  // idle pill
```
Currently renders unconditionally regardless of hover (per CONTEXT.md/RESEARCH.md Open Question 2, this is exactly where the new hover-gated branch is added — either inline here as a view-local check on `nowPlaying.lastKnownTrack`/`hasPlayedSinceLaunch` + a hover flag, or via a new `IslandPresentation` case dispatched from a new `presentationSwitch` arm).

**D-03 failure-feedback text pattern to mirror** (`NotchPillView.swift:3234-3247`, Phase 4/NOW-03 precedent):
```swift
// D-12 — the "Now Playing nicht verfügbar" health state (adapter blocked/dead). Same
// expanded blob shape so the island still morphs; a single centered message.
private var mediaUnavailableContent: some View {
    Text("Now Playing nicht verfügbar")
        .font(.system(size: 14, weight: .medium, design: .rounded))
        .foregroundStyle(.white)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 16)
        .padding(.top, Self.cameraClearance)
}
```
D-03's "Can't resume" text replaces the `EqualizerBars` slot in the SAME wings-sized shape (not a new visual language, not the expanded blob) — a small `Text(...)` with matching styling swapped in for the equalizer, in place, before the preview collapses on the D-04 grace timer.

**Anti-pattern — do NOT reuse this tap wiring for the preview** (`NotchPillView.swift:2393-2395`):
```swift
// Finding 15 (06-10) precedent: the shared tap-to-toggle, same as wingsShape's
// callers — no buttons live in this content, so one ancestor gesture is safe.
.onTapGesture { onClick() }
```
This is `mediaWingsOrToast`'s EXPAND-to-full-view gesture (5 call sites app-wide: `NotchPillView.swift:1100, 2085, 2297, 2395, 3012`). The hover-preview's tap target must be the new dedicated `onResumeTap` closure instead (D-01 requires staying exactly in the wings-preview shape, no expansion).

---

### `Islet/Notch/NotchWindowController.swift` (controller, event-driven + inferred-timeout)

**Analog:** itself — `collapsedInteractiveZone()` (click-through widening idiom), `handleSecondaryTap()` (dedicated-tap-handler idiom); `NowPlayingMonitor.swift`'s `runHealthCheck` (timeout-inference idiom)

**Click-through hot-zone widening to EXTEND (not replace)** (`NotchWindowController.swift:1420-1429`, Phase 42 precedent):
```swift
private func collapsedInteractiveZone() -> CGRect? {
    guard let hotZone else { return nil }
    guard presentationState.secondary != nil else { return hotZone }
    let collapsedFrame = hotZone.insetBy(dx: hotZonePadding, dy: hotZonePadding)
    let bubbleFarEdge = collapsedFrame.midX + NotchPillView.secondaryBubbleCenterOffset
        + NotchPillView.secondaryBubbleDiameter / 2 + hotZonePadding
    guard bubbleFarEdge > hotZone.maxX else { return hotZone }
    return CGRect(x: hotZone.minX, y: hotZone.minY,
                  width: bubbleFarEdge - hotZone.minX, height: hotZone.height)
}
```
Add a parallel branch (or an additional guard) that widens `hotZone` symmetrically to at least `NotchPillView.wingsSize.width` (290pt) whenever the hover-preview is the thing currently rendered — mirroring this function's existing "compute a real geometric bound from a named `NotchPillView` constant, never widen unconditionally" shape (RESEARCH.md Pattern 3 / Pitfall 1 / Anti-Pattern 3). `hotZone` itself is set once per `positionAndShow()` at `NotchWindowController.swift:1101`:
```swift
// The hot-zone is the COLLAPSED pill (padded), in the same global bottom-left coords.
hotZone = collapsedFrame.insetBy(dx: -hotZonePadding, dy: -hotZonePadding)
```

**Dedicated tap-handler idiom to mirror for the resume tap** (`NotchWindowController.swift:1697-1705`):
```swift
// Phase 42 / DUAL-01 (D-12, SUPERSEDED ...) — this used to expand to the Now-Playing/Home media
// view (D-12). No caller besides `makeRootView`'s `onSecondaryTap` wiring exists, so it's
// repurposed here rather than adding a second closure: tapping the bubble now toggles
// play/pause directly via the SAME `nowPlayingMonitor.togglePlayPause()` the transport row's
// play/pause button already calls (see `onTogglePlayPause` in `makeRootView`) — no expand,
// no view-switch.
private func handleSecondaryTap() {
    nowPlayingMonitor?.togglePlayPause()
}
```
The new resume-tap handler's body is the SAME call (`nowPlayingMonitor?.togglePlayPause()`) but must ALSO arm the D-03 inferred-failure timeout watcher (see below) — a new method, e.g. `handleResumeTap()`, not a literal call to `handleSecondaryTap()`.

**Wiring call site to extend** (`NotchWindowController.swift:2138-2153`, `makeRootView`):
```swift
NotchPillView(interaction: interaction,
              nowPlaying: nowPlayingState,
              presentationState: presentationState,
              outfit: outfitState,
              shelfViewState: shelfViewState,
              onboardingState: onboardingState,
              viewSwitcherState: viewSwitcherState,
              calendarViewState: calendarViewState,
              onClick: { [weak self] in self?.handleClick() },
              onSecondaryTap: { [weak self] in self?.handleSecondaryTap() },
              // NOW-02: transport rides the EXISTING persistent child's stdin via the
              // monitor — no re-spawn, no focus steal.
              onTogglePlayPause: { [weak self] in self?.nowPlayingMonitor?.togglePlayPause() },
              onNext: { [weak self] in self?.nowPlayingMonitor?.nextTrack() },
              onPrevious: { [weak self] in self?.nowPlayingMonitor?.previousTrack() },
```
Add `onResumeTap: { [weak self] in self?.handleResumeTap() },` in the same `[weak self]` closure style, alongside the existing 3 transport closures.

**Inferred-timeout pattern to mirror for D-03 resume-failure detection** (`Islet/Notch/NowPlayingMonitor.swift:127-141`, D-12 precedent — the exact shape, NOT a literal reuse since this phase watches the persistent stream instead of spawning a new one-shot probe):
```swift
// D-12 launch-time health check (Pattern 3 option a — see file header for the why).
// "A callback arrived at all" → healthy; "no callback within the timeout" → unavailable.
func runHealthCheck(then setHealthy: @escaping (Bool) -> Void) {
    var settled = false
    controller.getTrackInfo { info in
        if settled { return }
        settled = true
        setHealthy(true)   // heard back → the bridge is alive
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
        if settled { return }
        settled = true
        setHealthy(false)   // never heard back → D-12 "nicht verfügbar"
    }
}
```
Per RESEARCH.md Pattern 2: this phase's version cannot spawn a new probe — it must watch the EXISTING persistent `onTrackInfoReceived` stream (already wired via `NowPlayingMonitor.start()`, delivered to the controller's existing `handleNowPlaying`) for the next `.playing` transition after the tap, racing that against a shorter deadline (~1.5-2s per RESEARCH.md A2, vs. the 3.0s health-check window). Implement as a `settled`-style flag inside `NotchWindowController` (not inside `NowPlayingMonitor` — no protocol/API change, per RESEARCH.md's Architectural Responsibility Map), set either by the very next qualifying `handleNowPlaying` invocation observing a fresh `.playing` snapshot, or by the timeout.

**Pointer/hover event-dispatch pattern this phase's hover-preview plugs into** (`NotchWindowController.swift:1363-1406`):
```swift
private func handlePointer(at point: CGPoint) {
    lastPointerLocation = point
    let activeZone = interaction.isExpanded ? (visibleContentZone() ?? hotZone) : collapsedInteractiveZone()
    guard let zone = activeZone else { return }
    let inside = zone.contains(point)
    if inside && !pointerInZone {
        pointerInZone = true
        handleHoverEnter()          // cancels the pending grace collapse inside
    } else if !inside && pointerInZone {
        pointerInZone = false
        handleHoverExit()
    }
    ...
}
```
D-04's dismiss timing reuses whichever grace-collapse timer `handleHoverExit()` already arms (~0.4s pointer-away) — no new timing constant, per CONTEXT.md D-04.

---

### `Islet/Notch/IslandResolver.swift` (OPTIONAL — model, transform)

**Only relevant if the "Claude's Discretion" architectural call (RESEARCH.md Open Question 2) picks a new `IslandPresentation` case over a view-local branch.**

**Analog:** itself — the `.homeLastPlayed`/`.nowPlayingWings` branches inside `resolve(...)` (`IslandResolver.swift:155-174`):
```swift
if !nowPlayingHealthy { return .nowPlayingExpanded(nowPlaying, healthy: false) } // D-12
if nowPlaying != .none { return .nowPlayingExpanded(nowPlaying, healthy: true) }
if hasPlayedSinceLaunch { return .homeLastPlayed }
return .homeEmpty
...
let ambient = nowPlayingLaunchGate(hasPlayedSinceLaunch: hasPlayedSinceLaunch, nowPlaying: nowPlaying)
if ambient != .none { return .nowPlayingWings(ambient) }   // D-02 ambient yield (rank 3)
return .idle
```
A new case (e.g. `.idleHoverPreview`) would slot into this SAME single-arbiter function (D-05 "single ranking authority"), gated on `hasPlayedSinceLaunch && lastKnownTrack != nil && isHoveringIdlePill` per RESEARCH.md's own recommendation — `resolve(...)` would need a new hover-flag parameter (it currently has none; hover lives in `NotchWindowController`/`InteractionPhase`, not fed into this pure function today). The `IslandPresentation` enum itself (`IslandResolver.swift:61-77`) gets one new case alongside `.idle`/`.nowPlayingWings`/`.homeLastPlayed`.

---

### `IsletTests/IslandResolverTests.swift` (OPTIONAL — test, transform)

**Only relevant if `IslandResolver.swift` gains a new case (see above).**

**Analog:** itself — existing gating-logic test idiom (`IslandResolverTests.swift:76-95`, `194-204`):
```swift
func testNoTransientWhilePlayingReturnsToWings() {
    // D-02 ambient yield (rank 3): with no transient and media playing, the resolver
    // yields to the now-playing wings — NOT idle.
    let r = resolve(activeTransient: nil,
                    nowPlaying: .playing(title: "Song", artist: "Artist"),
                    nowPlayingHealthy: true,
                    hasPlayedSinceLaunch: true,
                    isExpanded: false)
    XCTAssertEqual(r, .nowPlayingWings(.playing(title: "Song", artist: "Artist")))
}

func testNoTransientNoMediaIsIdle() {
    // No transient, nothing playing, collapsed → the static idle pill.
    let r = resolve(activeTransient: nil,
                    nowPlaying: .none,
                    nowPlayingHealthy: true,
                    hasPlayedSinceLaunch: true,
                    isExpanded: false)
    XCTAssertEqual(r, .idle)
}
```
New cases would mirror this exact call-`resolve(...)`-then-`XCTAssertEqual` shape, covering: hover + `lastKnownTrack` present + not yet played this session → still `.idle` (no preview, per CONTEXT.md's explicit "before anything has played this session, hovering stays unchanged"); hover + `hasPlayedSinceLaunch` + `lastKnownTrack` present → the new case; no hover → `.idle` unchanged. `XCTest`/`@testable import Islet` header (`IslandResolverTests.swift:1-14`) is the file-level convention to match if this file is touched at all.

---

## Shared Patterns

### Synthetic presentation construction (never fed back into real state)
**Source:** `NotchPillView.swift:945-951` (`.homeLastPlayed` case) + `isPlayingFor(_:)` (`NotchPillView.swift:2952-2955`)
**Apply to:** the hover-preview's render branch in `NotchPillView.swift`
```swift
case .homeLastPlayed:
    mediaContent(.paused(title: nowPlaying.lastKnownTrack?.title ?? "",
                          artist: nowPlaying.lastKnownTrack?.artist ?? ""),
                 art: nowPlaying.lastKnownTrack?.artwork)
```
This phase's version constructs `.playing(...)` (not `.paused`) so the equalizer bounces (D-02) — the ONE deliberate deviation from this precedent's literal shape.

### Hover-state + dedicated-tap-closure wiring
**Source:** `NotchPillView.swift:2883-2920` (`secondaryBubble(_:)`, `isSecondaryBubbleHovering`)
**Apply to:** the hover-preview's `.onHover`/`.onTapGesture` in `NotchPillView.swift`, and the new `onResumeTap` closure declaration (mirroring `onClick`/`onSecondaryTap` at `NotchPillView.swift:205-228`)

### Click-through hot-zone widening, gated on the active render
**Source:** `NotchWindowController.swift:1420-1429` (`collapsedInteractiveZone()`)
**Apply to:** the SAME function, extended with a hover-preview branch widening to `NotchPillView.wingsSize.width` — never an unconditional widen (Anti-Pattern, RESEARCH.md)

### Inferred success/failure via timeout (no completion signal exists)
**Source:** `Islet/Notch/NowPlayingMonitor.swift:129-141` (`runHealthCheck`, D-12)
**Apply to:** `NotchWindowController.swift`'s new resume-tap handler — race the existing persistent `onTrackInfoReceived`/`handleNowPlaying` stream for a fresh `.playing` snapshot against a ~1.5-2s deadline; `togglePlayPause()` itself never throws/returns anything to check (Pitfall 2)

### Inline-text health-state feedback (D-03)
**Source:** `NotchPillView.swift:3234-3247` (`mediaUnavailableContent`, Phase 4/NOW-03)
**Apply to:** the "Can't resume" text shown in place of `EqualizerBars` inside the preview's wings-sized shape, then the D-04 grace-collapse

### ~0.4s pointer-away grace-collapse timer (D-04)
**Source:** `NotchWindowController.swift:1363-1406` (`handlePointer`/`handleHoverEnter`/`handleHoverExit`)
**Apply to:** the hover-preview's dismiss timing — reuse the existing timer verbatim, no new constant

---

## No Analog Found

| File/Behavior | Role | Data Flow | Reason |
|----------------|------|-----------|--------|
| On-device resume-feasibility spike (RESEARCH.md Open Question 1: does `togglePlayPause()` resume a fully-stopped session for Spotify/Apple Music) | n/a — empirical verification, not code | n/a | Not a coding pattern to copy from anywhere in this codebase or any other; RESEARCH.md flags this as a required blocking on-device spike (Task 1) that must run BEFORE the D-03 failure-feedback timeout is tuned. Planner should sequence a spike task ahead of any implementation task, per RESEARCH.md's "Primary recommendation."|

## Metadata

**Analog search scope:** `Islet/Notch/NotchPillView.swift`, `Islet/Notch/NotchWindowController.swift`, `Islet/Notch/NowPlayingMonitor.swift`, `Islet/Notch/NowPlayingState.swift`, `Islet/Notch/NowPlayingPresentation.swift`, `Islet/Notch/IslandResolver.swift`, `IsletTests/IslandResolverTests.swift`
**Files scanned:** 7 (all read directly this session; 4 small files read in full, 3 large files read via targeted non-overlapping `Read` calls at line ranges identified by `grep -n`)
**Pattern extraction date:** 2026-07-21
