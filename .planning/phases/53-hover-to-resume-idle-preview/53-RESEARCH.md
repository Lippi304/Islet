# Phase 53: Hover-to-Resume Idle Preview - Research

**Researched:** 2026-07-21
**Domain:** Native macOS SwiftUI — MediaRemote transport constraints + collapsed-pill hover/click-through geometry
**Confidence:** HIGH (all claims below are grounded in this codebase's own source, read directly — including the vendored MediaRemote adapter's compiled Swift wrapper — plus this project's own accumulated STATE.md decisions. No external library research was needed; this phase adds zero new dependencies.)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

### Resume click scope
- **D-01:** Clicking the hover-preview resumes playback in place — calls `NowPlayingMonitor.togglePlayPause()` directly, the pill stays exactly as the wings-preview shape, no further expansion to the full Home transport view. Matches the Phase 42 secondary-bubble precedent exactly (tap toggles play/pause, nothing else).

### Preview visual motion
- **D-02:** The equalizer bars in the hover preview animate identically to the live-playing state (same view, no new "frozen" visual state) — simplest to implement, no new rendering branch.

### Resume-failure feedback
- **D-03:** ROADMAP Success Criterion #4 already locks that a failed resume must give clear feedback, not silently do nothing. The shape of that feedback is a brief inline text message (e.g., "Can't resume") shown in place of the equalizer/controls, then the preview collapses — mirrors the existing "Now Playing nicht verfügbar" health-state text pattern from Phase 4/NOW-03, not a new visual language.

### Dismiss timing
- **D-04:** The hover-preview collapses back to idle using the exact same ~0.4s pointer-away grace timer already used everywhere else in the app — no new timing constant.

### Claude's Discretion
- Exact SwiftUI mechanics for how the preview transitions from "invisible idle pill" to "wings visible on hover" (new `@State`/computed presentation branch vs. reusing `nowPlayingWings` conditionally) — implementation detail for planning.
- Whether resuming is technically achievable via the existing `NowPlayingMonitor`/MediaRemote adapter transport when no session is currently live is an **open technical question, not a user decision** (per PROJECT.md's v1.8 Key Context and ROADMAP Success Criterion #4) — must be verified early in phase research/planning, not assumed. If `togglePlayPause()` cannot resume a fully-stopped session for a given source, D-03's failure feedback is what the user sees.

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.

- Reviewed but not folded (unrelated, matched by generic keyword scoring): Calendar month-grid polish, Island briefly disappears during click-through, Quick Action disabled state has no controller gate.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| RESUME-01 | Hovering the collapsed island when nothing is playing expands it to preview the last track played this session (album art left, equalizer bars right) — same visual as the active Now Playing glance | Pattern 1 (synthetic `.playing` presentation construction, reusing Phase 30's precedent) + Pitfall 1 (click-through hot-zone widening required for the 290pt wings footprint to be reliably hoverable) |
| RESUME-02 | Clicking the hover-preview resumes playback of that last track, if still possible | Summary + Open Question 1 (transport has no track-addressable resume — verified via vendored `MediaController.swift` source read) + Pattern 2 (inferred-timeout failure detection, since `togglePlayPause()` has no completion signal) + Pitfall 2/3/4 |
</phase_requirements>

## Summary

This phase's only real risk is NOT the SwiftUI visual (the UI-SPEC already locks that down to a verbatim reuse of `mediaWingsRow`) — it is the transport layer. This research read the actual vendored `mediaremote-adapter` Swift source (`MediaController.swift`, not just this app's thin wrapper) and confirms: **there is no track-addressable resume API anywhere in this stack.** `NowPlayingService.togglePlayPause()` → `MediaController.togglePlayPause()` sends a bare `"toggle_play_pause"` string over a persistent perl-bridge stdin pipe, with **zero return value, zero completion handler, and zero success/failure signal** — mechanically identical to a hardware play/pause media key press. It does not target a bundle ID, PID, or track; it is delivered to whatever macOS's system-wide MediaRemote "Now Playing" pointer currently designates, if anything.

This has two concrete consequences for planning:
1. **Whether resume "works" is entirely outside this app's control** — it depends on whether the OS still considers the last-played app (Spotify or Apple Music — the only two allowlisted sources, D-01 in `NowPlayingPresentation.swift`) the current Now Playing app. This must be spiked on-device early (Task 1, blocking), not assumed.
2. **Resume-failure detection (D-03/SC#4) cannot be a direct API error** — since `togglePlayPause()` returns nothing, "did it work?" can only be inferred by starting a timeout after the tap and watching whether the existing `onTrackInfoReceived` stream emits a fresh `.playing` snapshot before it elapses. This mirrors the codebase's own existing `runHealthCheck()` timeout-inference pattern (D-12) — reuse that shape, don't invent a new one.

A second, independently significant finding: this app's click-through hot-zone (`NotchWindowController.hotZone`) is sized to the **physical notch cutout**, not to whichever `IslandPresentation` is currently rendered. The 290×32pt wings shape this phase's preview reuses verbatim is wider than that raw cutout. Phase 42 already hit this exact problem for the secondary bubble and fixed it with a bespoke widening function, `collapsedInteractiveZone()` — but that function widens ONLY for the secondary-bubble case today. It does nothing for the primary wings footprint the hover-preview will render at. Without extending it, clicks/hover near the album-art (left) or equalizer (right) edges of the preview will either premature-grace-collapse or pass through to the desktop.

**Primary recommendation:** Sequence the phase as (1) an early blocking on-device spike confirming/refuting resume-of-a-stopped-session for both Spotify and Apple Music, (2) build the preview render branch + the new dedicated tap handler (NOT the generic `onClick`/expand handler, NOT a literal reuse of `onSecondaryTap` either — a new third closure with the same toggle-play-pause body), (3) extend `collapsedInteractiveZone()`'s widening logic to also cover the idle-hover-preview's wings footprint, using the existing `NotchPillView.wingsSize` constant, mirroring the secondary-bubble widening technique exactly.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Hover-preview trigger detection | AppKit window/event tier (`NotchWindowController.handlePointer`/`collapsedInteractiveZone`) | SwiftUI (`NotchPillView` renders the branch) | Hover geometry and click-through hit-testing are AppKit's job in this codebase (global `.mouseMoved` monitor + `NSPanel.ignoresMouseEvents`); the view layer only renders what the resolver/controller tells it to. |
| Preview content (album art + equalizer) | SwiftUI (`NotchPillView.mediaWingsRow`) | — | Pure rendering, reuses existing verbatim component per UI-SPEC. |
| "Last played track" data | Model tier (`NowPlayingState.lastKnownTrack`) | — | Already built in Phase 30, session-only, zero new state needed. |
| Resume command dispatch | Transport/glue tier (`NowPlayingMonitor` / `NowPlayingService` protocol) | — | CLAUDE.md mandate: all MediaRemote-facing code stays behind this one protocol/file. Any resume-feasibility fallback logic belongs here, not in the view or controller. |
| Resume-failure detection (inferred, not returned) | Controller tier (`NotchWindowController`, timeout + stream-observation, mirroring `runHealthCheck`) | Transport tier (exposes nothing new — no API changes needed in `NowPlayingMonitor`) | The transport gives no completion signal; only the controller — which already owns the persistent `onTrackInfoReceived` stream — can observe "did a `.playing` snapshot arrive in time?". |
| Failure feedback text | SwiftUI (`NotchPillView`, replacing the `EqualizerBars` slot) | — | Per UI-SPEC, text-only, no new visual language. |

## Standard Stack

No new packages. This phase is 100% native SwiftUI/AppKit, reusing existing project code (`NowPlayingMonitor`, `NotchPillView`, `NotchWindowController`, `IslandResolver`). The vendored `mediaremote-adapter` (already a project dependency since Phase 4) is the only external dependency touched, and only its already-wired `togglePlayPause()` entry point — no API surface expansion, no version bump.

### Installation
Not applicable — no new packages.

## Package Legitimacy Audit

Not applicable — this phase installs zero new external packages. `mediaremote-adapter` is a pre-existing, already-audited (Phase 4) dependency; this phase makes no changes to `project.yml`/`Package.swift`.

## Architecture Patterns

### System Architecture Diagram

```
User hovers collapsed idle pill
        │
        ▼
NotchWindowController.handlePointer(at:)          ◄── global .mouseMoved monitor (AppKit)
        │  checks collapsedInteractiveZone()  (MUST be widened this phase — see Pitfall 1)
        ▼
handleHoverEnter() → interaction.phase = .hovering
        │
        ▼
renderPresentation() / resolve(...)  (IslandResolver.swift — PURE, Foundation-only)
        │  today: activeTransient=nil, ambient nowPlaying=.none → returns .idle
        │  THIS PHASE: .idle case needs a NEW hover-aware branch (not a new IslandPresentation
        │  case necessarily — could be a view-local @State/computed check on lastKnownTrack +
        │  a hover flag threaded down, per CONTEXT.md's "Claude's Discretion" note)
        ▼
NotchPillView.presentationSwitch → .idle → collapsedIsland
        │  NEW: if lastKnownTrack != nil && hovering → render mediaWingsRow(.playing(...), art:)
        │  ELSE → today's unchanged nothing-rendered idle pill
        ▼
User clicks the preview
        │
        ▼
NEW dedicated tap closure (NOT onClick/handleClick — that expands to Home;
NOT a literal onSecondaryTap passthrough either, semantically distinct call site)
        │
        ▼
NotchWindowController: nowPlayingMonitor?.togglePlayPause()   ◄── SAME call site pattern as
        │                                                          handleSecondaryTap() (line 1704)
        ▼
MediaController.togglePlayPause() → sendCommand(["toggle_play_pause"])
        │  fire-and-forget over a persistent perl-bridge stdin pipe — NO return value
        ▼
   ┌────────────────────────────┬─────────────────────────────────┐
   │ OS still tracks that app   │ OS has fully vacated Now Playing │
   │ as "Now Playing" (paused,  │ (app quit / stopped / idle-out)  │
   │ not stopped)               │                                  │
   ▼                            ▼
Playback resumes → a fresh   Nothing happens — no event, no error
.playing TrackInfo arrives   the persistent onTrackInfoReceived
via the SAME persistent      stream stays silent
loop child (no re-spawn)
   │                            │
   ▼                            ▼
Controller's existing        Controller's NEW inferred-timeout
resolve() picks up the       watcher (mirrors runHealthCheck's
new .playing snapshot,       "did a callback arrive in time?"
preview morphs into the      shape) times out → D-03 failure
REAL live nowPlayingWings    text replaces EqualizerBars slot,
state naturally               then collapses on the same 0.4s
                              grace timer
```

### Recommended Project Structure
No new files. All changes land in the 4 files CONTEXT.md's canonical_refs already names:
```
Islet/Notch/
├── NowPlayingState.swift        # unchanged — lastKnownTrack already exists (Phase 30)
├── NowPlayingMonitor.swift      # unchanged API surface — togglePlayPause() reused as-is
├── NotchPillView.swift          # NEW: hover-preview render branch off .idle + its own tap closure
└── NotchWindowController.swift  # NEW: hover-state wiring, resume-tap handler, inferred-failure
                                  #      timeout watcher, collapsedInteractiveZone() widening
```

### Pattern 1: Synthetic presentation construction (already established, Phase 30)
**What:** Build a `NowPlayingPresentation` value from `lastKnownTrack` purely for display, never feeding it back into `nowPlaying.presentation` itself.
**When to use:** Exactly this phase's preview-render need.
**Example — the exact precedent this phase's preview should copy:**
```swift
// Source: Islet/Notch/NotchPillView.swift:945-951 (Phase 30 / HOME-02, existing code)
case .homeLastPlayed:
    mediaContent(.paused(title: nowPlaying.lastKnownTrack?.title ?? "",
                          artist: nowPlaying.lastKnownTrack?.artist ?? ""),
                 art: nowPlaying.lastKnownTrack?.artwork)
```
Per UI-SPEC.md, this phase's collapsed analogue constructs `.playing(...)` (not `.paused`) specifically so `EqualizerBars(isPlaying:)` bounces (D-02) — `isPlayingFor(.paused(...))` returns `false` (`NotchPillView.swift:2952`) and would freeze the bars, which D-02 explicitly rejects.

### Pattern 2: Inferred success/failure via timeout (already established, Phase 4 D-12)
**What:** When a transport call has no completion signal, infer success by racing an expected async event against a deadline.
**When to use:** D-03's resume-failure detection — there is no other option, since `togglePlayPause()` is fire-and-forget.
**Example — the exact precedent to mirror (adapt the 3.0s window to something much shorter, ~1.5-2s, since this is a UI-latency-sensitive tap, not a launch probe):**
```swift
// Source: Islet/Notch/NowPlayingMonitor.swift:129-141 (existing code, D-12 pattern)
func runHealthCheck(then setHealthy: @escaping (Bool) -> Void) {
    var settled = false
    controller.getTrackInfo { info in
        if settled { return }
        settled = true
        setHealthy(true)
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
        if settled { return }
        settled = true
        setHealthy(false)
    }
}
```
This phase's version differs in one important way: it cannot spawn a NEW one-shot probe (`getTrackInfo`) — it must watch the EXISTING persistent stream (`onTrackInfoReceived`, already wired in `NowPlayingMonitor.start()`) for the next `.playing` transition after the tap, racing that against a deadline. This is new controller-side logic (a `settled`-style flag set by the very next qualifying `handleNowPlaying` invocation, or by a timeout), not a new transport method.

### Pattern 3: Click-through hot-zone widening for a wing-tier tap target (Phase 42 precedent — MUST be extended this phase)
**What:** `hotZone` is sized to the raw notch cutout; anything rendering wider (any 290pt wings shape) needs its own widening rule or clicks/hover near its edges silently fail.
**When to use:** Exactly this phase — the preview renders at the same `Self.wingsSize` (290×32) footprint the secondary bubble already had to solve for.
**Existing precedent to extend, not replace:**
```swift
// Source: Islet/Notch/NotchWindowController.swift:1408-1429 (existing code, Phase 42)
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
This function today widens ONLY for the secondary bubble. It has no branch at all for `.idle` + hover-preview showing. The plan must add a case (or a parallel check) that widens `hotZone` to `NotchPillView.wingsSize.width` (centered on the pill) whenever the hover-preview is the thing currently rendered — otherwise the pointer will read as "outside the zone" the instant it reaches the album-art (left, 22pt inset from a 290pt-wide shape) or equalizer (right, 24pt inset) content, triggering a premature grace-collapse or leaving the click unregistered (`panel.ignoresMouseEvents` stays `true`).

### Anti-Patterns to Avoid
- **Reusing `mediaWingsOrToast`'s `.onTapGesture { onClick() }` verbatim for the preview's tap target:** `onClick` is the generic tap-to-expand closure wired to `handleClick()` (5 call sites: `NotchPillView.swift:1100, 2085, 2297, 2395, 3012`) — using it here would EXPAND to the full Home view on click, directly contradicting D-01 ("the pill stays exactly as the wings-preview shape, no further expansion"). The preview needs its own tap closure with a `togglePlayPause()` body (mirroring `handleSecondaryTap()`'s body, not its call site).
- **Treating `togglePlayPause()`'s absence of a thrown error as "it worked":** it is fire-and-forget by construction (`MediaController.sendCommand` writes to a pipe and returns `Void`); silence is the DEFAULT outcome for every call, success or failure alike. Only the follow-up stream event distinguishes them.
- **Widening `hotZone` unconditionally to 290pt at all times:** would silently regress every other collapsed case (charging/device/focus/osd wings, which may use different widths) and would extend the click-through/keep-open zone even when nothing is being hovered. Widen conditionally, gated on the hover-preview actually being the active render, exactly like the secondary-bubble case already gates on `presentationState.secondary != nil`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Detecting "did resume succeed" | A new completion-callback API on `NowPlayingMonitor`/`MediaController` | The existing persistent `onTrackInfoReceived` stream + a timeout, mirroring `runHealthCheck` | The vendored adapter has no completion signal for any transport command (verified — `togglePlayPause()`/`play()`/`pause()` are all `Void`-returning fire-and-forget). Adding one would mean forking/patching the vendored perl bridge, a much bigger and riskier change than an inference-based approach the codebase already uses elsewhere. |
| Hover/click geometry for a 290pt-wide collapsed shape | A brand-new hover-zone abstraction | Extend `collapsedInteractiveZone()` | Exactly this problem was already solved once (Phase 42, secondary bubble); the widening math (base hotZone + a named offset constant) is the established shape. |
| "Last played track" storage | New `@Published` state, persistence, or a new data model | `NowPlayingState.lastKnownTrack` (Phase 30) | Already exists, already session-scoped exactly as this phase needs, never persisted. |

**Key insight:** every piece of new logic this phase needs is an EXTENSION of a pattern the codebase already proved out once (Phase 4's health-check timeout, Phase 30's synthetic presentation, Phase 42's hover-zone widening) — there is no genuinely novel mechanism required, only correctly recognizing which existing seam each new behavior belongs behind.

## Common Pitfalls

### Pitfall 1: Click-through hot-zone narrower than the rendered preview (HIGH confidence, code-verified)
**What goes wrong:** The preview renders at 290×32pt (`Self.wingsSize`), but `hotZone` is sized to the raw physical notch cutout (`notchSize(...)`, typically well under 290pt on real hardware) plus a 6pt pad. Hovering/clicking near the album-art or equalizer edges reads as "outside the zone."
**Why it happens:** `hotZone` is computed once in `positionAndShow()` from the measured notch geometry, NOT from whichever `IslandPresentation` is currently rendered (confirmed by reading `NotchWindowController.swift:993-1101` — `collapsedFrame` never varies by presentation case).
**How to avoid:** Extend `collapsedInteractiveZone()` (`NotchWindowController.swift:1420-1429`) with a branch for the hover-preview state, widening symmetrically to (at least) `NotchPillView.wingsSize.width`, exactly mirroring the existing secondary-bubble branch's shape.
**Warning signs:** On-device testing where hovering dead-center of the pill triggers the preview but moving toward the album art or equalizer immediately collapses it, or where clicking near either edge does nothing.

### Pitfall 2: Treating "no error thrown" as "resume succeeded" (HIGH confidence, code-verified)
**What goes wrong:** `togglePlayPause()` is `Void`-returning and fire-and-forget (writes to a pipe, no response awaited) — every call "succeeds" from Swift's point of view regardless of whether macOS actually resumed anything.
**Why it happens:** The vendored `MediaController.sendCommand(_:)` (`MediaController.swift:282-306`) has no acknowledgment protocol at all; it either writes to the persistent loop's stdin or (if that pipe is dead) falls through to `runPerlCommand`, and either way returns nothing to the caller.
**How to avoid:** Implement D-03's failure feedback via the inferred-timeout pattern (Pattern 2 above), never via a `do/catch` or a return-value check on `togglePlayPause()` itself — there is nothing to catch.
**Warning signs:** A plan task that reads "if togglePlayPause() throws/returns false, show the failure text" — this is not implementable against the real API and signals a misunderstanding of the transport.

### Pitfall 3: Assuming resume-of-a-stopped-session works because resume-of-a-paused-session does
**What goes wrong:** `NowPlayingPresentation.none` (the gate for showing this phase's preview at all) covers BOTH "the app is paused but macOS still tracks it as Now Playing" and "macOS has fully vacated its Now Playing pointer" (app quit, explicit Stop, or the well-known ~15-minute macOS Now-Playing-idle-out). These two sub-cases likely behave completely differently when `togglePlayPause()` is sent, and the codebase's `TrackSnapshot`/`NowPlayingPresentation` seam makes no distinction between them (a nil payload is nil either way, per `nowPlayingPresentation(from:)`, `NowPlayingPresentation.swift:52-60`).
**Why it happens:** The pure classification layer (by design, per that file's own header comment) treats "no media" as one case, not two — there is no signal anywhere in this app's model for "how long has it been idle" or "did the app quit vs. just stop".
**How to avoid:** The phase's blocking on-device spike (already flagged as required by CONTEXT.md/ROADMAP SC#4) must explicitly test BOTH sub-cases separately, for BOTH allowlisted sources (Spotify, Apple Music, per `allowedBundleIDs` in `NowPlayingPresentation.swift:49`): (a) pause via the app's own UI, wait, then resume-tap; (b) fully quit the app, then resume-tap. Do not assume a single spike result generalizes across both.
**Warning signs:** A plan that runs only one spike scenario (e.g., only "paused") and declares the technical question resolved for all cases.

### Pitfall 4: Reusing the wrong tap closure
**What goes wrong:** Wiring the preview's tap to `onClick`/`handleClick()` (the ambient generic expand-to-Home handler) instead of a dedicated toggle-play-pause closure.
**Why it happens:** `mediaWingsOrToast` (the live now-playing collapsed glance this preview visually borrows from) already has `.onTapGesture { onClick() }` wired for EXPAND semantics — it would be an easy, wrong copy-paste to reuse that exact gesture wrapper for the preview too.
**How to avoid:** The preview needs a new dedicated closure (e.g., a 3rd `NotchPillView` stored closure alongside the existing `onClick`/`onSecondaryTap`), wired to a new controller method whose body is `nowPlayingMonitor?.togglePlayPause()` — same body as `handleSecondaryTap()` (`NotchWindowController.swift:1703-1705`), different call site, since semantically this is a THIRD distinct tap affordance, not the secondary bubble's.
**Warning signs:** Clicking the preview during on-device testing expands to the full Home transport view instead of staying "exactly as the wings-preview shape" (violates D-01 directly).

## Code Examples

### The complete real transport surface (verified by reading the vendored source directly)
```swift
// Source: MediaController.swift (vendored mediaremote-adapter, ejbills/mediaremote-adapter),
// read from Xcode's local SourcePackages checkout at:
// ~/Library/Developer/Xcode/DerivedData/Islet-.../SourcePackages/checkouts/mediaremote-adapter/
//   Sources/MediaRemoteAdapter/MediaController.swift
public func play() { sendCommand(["play"]) }
public func pause() { sendCommand(["pause"]) }
public func togglePlayPause() { sendCommand(["toggle_play_pause"]) }
public func nextTrack() { sendCommand(["next_track"]) }
public func previousTrack() { sendCommand(["previous_track"]) }
// ...(stop/seek/shuffle/repeat/like/ban/wishlist, same shape)...
// EVERY ONE of these is Void-returning, fire-and-forget over sendCommand(_:), which either
// writes to the persistent loop child's stdin pipe or (if dead) falls back to spawning a
// one-shot perl process — NO caller ever learns whether the underlying app actually
// received or honored the command. There is NO play(track:)/resume(track:)/PID- or
// bundle-targeted variant anywhere in this file.
```

### This app's existing NowPlayingService surface (unchanged by this phase)
```swift
// Source: Islet/Notch/NowPlayingMonitor.swift:40-53 (existing code)
protocol NowPlayingService: AnyObject {
    func start()
    nonisolated func stop()
    func togglePlayPause()
    func nextTrack()
    func previousTrack()
    func runHealthCheck(then setHealthy: @escaping (Bool) -> Void)
    // ...
}
```
No new method is needed on this protocol for RESUME-01/02 — `togglePlayPause()` already exists and is the only lever available; the "resume" behavior this phase ships is entirely a UI/controller-side construction (Pattern 1 + Pattern 2 above) layered on top of this exact same call.

## State of the Art

Not applicable in the traditional sense (no external library version drift to track) — the one relevant "state of the art" fact is architectural: this app's Now Playing feature has been built, since Phase 4, on the explicit premise that MediaRemote is a private, breakable API surface, isolated behind one file. This phase's resume behavior must respect that isolation (CLAUDE.md: "Keep all now-playing behind one NowPlayingService protocol... isolation makes the fix a one-file swap"). Any resume-feasibility workaround belongs inside `NowPlayingMonitor.swift`, never leaked into `NotchPillView`/`NotchWindowController` as raw MediaRemote assumptions.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | macOS's system Now-Playing pointer sometimes survives a brief pause/stop and sometimes doesn't (idle-timeout, app-quit, or another app taking over), meaning `togglePlayPause()`'s success is state-dependent and non-deterministic from this app's point of view | Summary, Pitfall 3 | If this is wrong (e.g., resume genuinely never works past a certain point, or always works for a longer window than assumed), the phase's success-criteria framing ("whenever the underlying transport still supports it") and the failure-feedback timeout tuning both need revisiting — this is exactly why CONTEXT.md/ROADMAP flag it as an open technical question requiring an on-device spike, not something this research can resolve without real hardware/app testing. |
| A2 | A ~1.5-2s inferred-timeout window (vs. the existing 3.0s `runHealthCheck` window) is short enough to feel responsive but long enough to not false-positive on a legitimate but slightly slow resume (e.g., a cold-launched Spotify) | Pattern 2 | If too short, genuine successful resumes could be misreported as failed (D-03 text flashes then the real playback still starts a moment later — a confusing UX). If too long, a failed tap feels sluggish before the "Wiedergabe nicht möglich" text appears. Tune during the phase's own on-device UAT, not fixed a priori. |

## Open Questions

1. **Does `togglePlayPause()` resume a fully-stopped/quit session at all, for either allowlisted source?**
   - What we know: The command is a generic, non-targeted "toggle" sent to whatever macOS currently designates as the Now Playing app (verified via source read of `MediaController.swift`). No track/PID/bundle targeting exists anywhere in the stack.
   - What's unclear: Whether macOS's own Now-Playing-app designation itself survives long enough after a pause/stop/app-quit for this generic toggle to have any effect, and whether that differs between Spotify and Apple Music.
   - Recommendation: This is exactly ROADMAP SC#4's mandated early spike — Task 1 of the phase's first plan, blocking, must empirically test: (a) pause via app UI + wait + resume-tap, (b) fully quit app + resume-tap, for BOTH Spotify and Apple Music, and record the actual observed outcome for each of the 4 combinations before any further planning commits to a specific fallback design.

2. **Where exactly should the hover-preview live architecturally: a new `IslandPresentation` case, or a view-local branch off `.idle`?**
   - What we know: CONTEXT.md explicitly leaves this to Claude's discretion. `.idle` today renders literally nothing (`NotchPillView.swift:923-924`); `resolve(...)` (`IslandResolver.swift:117-176`) has no hover-state input at all today (hover is tracked separately in `NotchWindowController`/`InteractionPhase`, not fed into the pure resolver).
   - What's unclear: Threading a hover flag into the pure `resolve(...)` function would be architecturally cleaner (single arbiter, D-05 convention) but is a bigger diff than a purely view-local `@State`/computed check inside `collapsedIsland` reading `lastKnownTrack` + an existing hover signal already available to the view.
   - Recommendation: Given D-05's "single arbiter" convention is a strong, repeatedly-reinforced pattern in this codebase (see `IslandResolver.swift`'s own header comments), the planner should at least consider a new `IslandPresentation` case (e.g. `.idleHoverPreview`) resolved inside `resolve(...)` gated on `hasPlayedSinceLaunch && lastKnownTrack != nil && isHoveringIdlePill`, rather than a purely view-local branch — but a view-local check is the smaller, faster-to-ship alternative and CONTEXT.md explicitly permits either. Either way, the click-through widening (Pitfall 1) is required regardless of which architectural shape is chosen.

## Environment Availability

Skipped — this phase has no external tool/service/runtime dependencies beyond the existing project toolchain (Xcode, already-configured `mediaremote-adapter` SPM dependency). No new installs, no new permissions, no new entitlements.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (existing `IsletTests` target) |
| Config file | `Islet.xcodeproj` scheme "Islet" (no separate `.xctestplan`) |
| Quick run command | `xcodebuild build -project Islet.xcodeproj -scheme Islet -configuration Debug` (compile-gate only — see note below) |
| Full suite command | Manual Cmd-U in Xcode (see project-known limitation below) |

**Known project limitation (STATE.md/PROJECT.md, confirmed, applies here unchanged):** `xcodebuild test` hangs headless in this repo/worktree due to a `BluetoothMonitor`/`IOBluetoothCoreBluetoothCoordinator` TCC-authorization wait introduced in Phase 6. All prior phases route automated verification through `xcodebuild build` (compile-only) and a manual Cmd-U pass in Xcode for actually running the XCTest suite. This phase follows the same convention — do not add an `xcodebuild test` step to any plan's automated gate.

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| RESUME-01 | Hover preview shows correct visual gated on `hasPlayedSinceLaunch`/`lastKnownTrack` | unit (pure gating logic only — the SwiftUI render itself is not unit-testable in this codebase's existing convention) | `xcodebuild build ...` (compile gate) + manual Cmd-U for any new pure-function tests | Likely ❌ Wave 0 — no test file targets this gating logic yet; if the resolver-case approach (Open Question 2) is chosen, add cases to the existing `IslandResolverTests.swift` |
| RESUME-02 | Click resumes playback when transport supports it; clear feedback when it doesn't | manual-only (on-device UAT) — the actual resume behavior depends on live MediaRemote/OS state, which cannot be simulated in XCTest, mirroring this codebase's own established precedent for every prior MediaRemote-dependent phase (4, 47-49) | none automatable — on-device checkpoint required | N/A |

### Sampling Rate
- **Per task commit:** `xcodebuild build -project Islet.xcodeproj -scheme Islet -configuration Debug`
- **Per wave merge:** Debug + Release build, plus a manual Cmd-U pass for any new/changed pure-function unit tests (mirrors Phase 47/48/49 precedent)
- **Phase gate:** On-device UAT covering all 4 ROADMAP success criteria (this phase cannot be verified by automated tests alone — the core behavior is a live MediaRemote transport interaction)

### Wave 0 Gaps
- [ ] If a new `IslandPresentation` case is chosen (Open Question 2): extend `IslandResolverTests.swift` with cases for the new hover-preview branch's gating logic (`hasPlayedSinceLaunch`, `lastKnownTrack != nil`, hover flag)
- [ ] No new test file is needed for the transport call itself — `togglePlayPause()` is already exercised (indirectly) by existing manual/on-device precedent for Phase 42/47-49; the resume-inference timeout logic is controller-side glue, verified the same way `runHealthCheck`'s D-12 timeout was (on-device, not unit-tested, per that code's own header comment)

## Security Domain

Not applicable in the ASVS sense — this phase has no authentication, session, access-control, input-validation-from-untrusted-network-source, or cryptography surface. The only "input" is a UI-internal `lastKnownTrack` struct (title/artist/artwork), already sourced from the same allowlisted, sanitized MediaRemote payload path every other Now Playing feature in this app uses (D-01 bundle allowlist, empty-title rejection — `NowPlayingPresentation.swift:52-60`), and the failure-feedback string is a static, developer-authored literal, not untrusted user/network content.

## Sources

### Primary (HIGH confidence — direct codebase source reads this session)
- `Islet/Notch/NowPlayingMonitor.swift` (full file read) — `NowPlayingService` protocol, `togglePlayPause()`/`nextTrack()`/`previousTrack()`, D-12 health-check timeout pattern
- `Islet/Notch/NowPlayingState.swift` (full file read) — `lastKnownTrack: LastPlayedTrack?`, `hasPlayedSinceLaunch`
- `Islet/Notch/NowPlayingPresentation.swift` (full file read) — `NowPlayingPresentation` enum, `allowedBundleIDs`, `nowPlayingPresentation(from:)`, `nowPlayingLaunchGate`
- `Islet/Notch/IslandResolver.swift` (full file read) — `IslandPresentation` enum, `resolve(...)`, `resolveSecondary`, `showsSwitcherRow`
- `Islet/Notch/NotchPillView.swift` (targeted reads: lines 880-965, 2370-2470, 2820-2960, 3230-3250) — `presentationSwitch`, `mediaWingsOrToast`/`mediaWingsRow`, `secondaryBubble` hover/tap pattern, `onClick`/`onSecondaryTap` closures, `mediaUnavailableContent` styling precedent
- `Islet/Notch/NotchWindowController.swift` (targeted reads: lines 993-1160, 1360-1440, 1550-1720) — `positionAndShow`/`collapsedFrame`/`hotZone` computation, `collapsedInteractiveZone()`, `handlePointer`/`syncClickThrough`, `handleClick()`/`handleSecondaryTap()` call sites
- `Islet/Notch/NotchGeometry.swift` (targeted read: `notchSize`/`notchFrame`) — confirms `hotZone` derives from the raw physical notch cutout, independent of rendered presentation width
- `~/Library/Developer/Xcode/DerivedData/.../SourcePackages/checkouts/mediaremote-adapter/Sources/MediaRemoteAdapter/MediaController.swift` (full file read) — the actual vendored transport implementation: confirms every command (`play`/`pause`/`togglePlayPause`/etc.) is `Void`-returning, fire-and-forget, non-targeted (no PID/bundle/track parameter anywhere)
- `.planning/phases/53-hover-to-resume-idle-preview/53-CONTEXT.md`, `53-UI-SPEC.md`, `53-DISCUSSION-LOG.md` — user decisions, visual contract, alternatives log
- `.planning/REQUIREMENTS.md`, `.planning/STATE.md`, `.planning/PROJECT.md` — RESUME-01/02 wording, v1.8 milestone context, project-known `xcodebuild test` headless-hang limitation
- `CLAUDE.md` (project root) — "isolate all now-playing code behind one Swift protocol" mandate, MediaRemote-is-private-and-breakable framing

### Secondary (MEDIUM confidence)
None — no WebSearch/Context7 lookups were needed; this research was entirely a codebase-grounded investigation, which is the correct and higher-confidence approach for a question the phase itself frames as "verify against the actual adapter code in this codebase."

### Tertiary (LOW confidence)
None.

## Metadata

**Confidence breakdown:**
- Standard stack: N/A — no new stack, HIGH confidence nothing new is needed
- Architecture: HIGH — every pattern cited is read directly from this codebase's existing, shipped code
- Transport constraints (the phase's central open question): HIGH confidence on WHAT the API surface is (fully verified by reading the vendored source); LOW/UNVERIFIABLE-without-hardware confidence on WHETHER resume actually works for a stopped session — this is explicitly an on-device empirical question no static research can answer, correctly flagged as the phase's own required first spike
- Pitfalls: HIGH — both major pitfalls (hot-zone width, fire-and-forget transport) are demonstrated directly against this codebase's real code, not inferred from general SwiftUI/macOS knowledge

**Research date:** 2026-07-21
**Valid until:** Stable — the vendored adapter and this app's own architecture change infrequently; re-verify only if `mediaremote-adapter` is upgraded or if `NotchWindowController`'s hot-zone geometry is touched by an intervening phase before Phase 53 executes.
