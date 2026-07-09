# Phase 18: Song-Change Toast - Research

**Researched:** 2026-07-09
**Domain:** Native macOS/SwiftUI transient-UI state modeling (in-codebase pattern extension, zero new dependencies)
**Confidence:** HIGH

## Summary

This phase adds no new technology — it is a pure extension of four already-established
patterns in the Islet codebase: the pure resolver seam (`IslandResolver.swift`), the
`@Published` state model (`NowPlayingState.swift`), the one-shot `DispatchWorkItem` dismiss
timer (`NotchWindowController.swift`), and the `@AppStorage` toggle (`SettingsView.swift`).
Every file the phase touches, and every precedent it should mirror, was read directly (not
inferred) as part of this research — see Code Examples below for exact current signatures.

The critical design decision the plan must get right is **where the toast state lives**. Per
CONTEXT.md D-02, the toast must NOT become a third `ActiveTransient` case (it must be silently
skippable, never queued, when a charging/device splash is active) and per D-04 it must not
fire when `isExpanded == true`. Both of these map cleanly onto the **ambient branch** of
`resolve(...)` — the same branch Phase 17's `nowPlayingLaunchGate` already lives in. The
natural, minimum-diff shape is: a new `@Published var songChangeToast: TrackSnapshot?` (or a
small pure value) on `NowPlayingState`, detected in `handleNowPlaying(_:_:)` via
`isSameTrack(previous, p)`, with its own one-shot `DispatchWorkItem` timer mirroring
`scheduleMediaDismiss`/`mediaDismissWorkItem` exactly (D-06/D-07 precedent), and a **new
`IslandPresentation` case or a toast-flag read alongside `.nowPlayingWings`** consumed by
`resolve(...)` only on the non-expanded path. `TransientQueue`/`ActiveTransient` are
untouched — this is the exact mechanism D-02 asks for ("no new queueing logic needed").

**Primary recommendation:** Model the toast as a fourth `@Published` field on
`NowPlayingState` (title/artist snapshot + nil-when-hidden), decided in `handleNowPlaying`
via `isSameTrack`, gated into `resolve(...)` as a new orthogonal parameter (mirroring how
`hasPlayedSinceLaunch` and `isExpanded` are already passed in as plain bools/flags rather than
folded into the transient queue), with its own `DispatchWorkItem` timer patterned byte-for-byte
on `scheduleMediaDismiss`. Add the Settings toggle as a fifth `ActivitySettings` key next to
`nowPlayingKey`, applied BEFORE the resolver (same discipline as the other three toggles).

## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01 (Toast content):** The toast shows both title and artist (not title-only), e.g.
  "Blinding Lights — The Weeknd". Exact layout (one line vs two, styling) is a UI-phase
  decision — this only locks that both fields are present.
- **D-02 (Priority vs Charging/Device transients):** If a genuine song change happens while a
  charging or device splash is currently showing (the two existing `ActiveTransient` kinds,
  ranked above Now Playing per D-02 in `IslandResolver.swift`), the toast for that change is
  skipped entirely — not queued, not shown afterward. Charging/device splashes already outrank
  the ambient Now Playing branch in `resolve(...)`, so this is the natural behavior if the
  toast is implemented as another ambient-gated state rather than a new
  `ActiveTransient`/`TransientQueue` participant — no new queueing logic needed.
- **D-03 (Rapid track skips):** If the user skips through several songs quickly, each new
  genuine change replaces the toast's content and restarts the ~3s timer — only the final
  settled track gets a full 3s display. No toast pile-up, no queue of pending toasts. This
  mirrors `TransientQueue`'s `updateHead()` in-place-refresh precedent (used today for
  charging-percent ticks) even though the toast itself isn't going through `TransientQueue`.
- **D-04 (Manual-expand interaction):** If the notch is already manually expanded (showing the
  full Now Playing card) when a genuine song change happens, the toast is suppressed — the
  expanded card already reflects the new title/artist live, so a toast on top would be
  redundant. This mirrors Phase 17's D-03 precedent: the toast, like the launch gate, only
  applies to the ambient/collapsed branch of `resolve(...)`; the `isExpanded` branch is
  untouched.

### Claude's Discretion

- Exact mechanism for detecting a "genuine" title+artist change: `isSameTrack(_:_:)` in
  `NowPlayingPresentation.swift` already exists for this purpose (true only when both sides
  have non-nil title/artist pairs AND those pairs are equal; a play↔pause transition on the
  same track is "same track", a title/artist change or a transition to/from `.none` is not).
  Whether the toast reuses this exact function or a close variant is left to research/planning.
- Whether the toast is modeled as a new `IslandPresentation` case, a sub-state carried
  alongside `.nowPlayingWings`, or a separate `@Published` flag read by the view layer is an
  implementation detail for planning/research to decide, informed by D-02 above (it must NOT
  participate in `ActiveTransient`/`TransientQueue`, since D-02 requires it to be silently
  skippable rather than queued).
- Exact toast dismiss/timer mechanism (Timer vs scheduled dispatch) — should follow the
  existing precedent of `NotchWindowController`'s `scheduleMediaDismiss`/`pausedTimeout`
  (D-06/D-07) or the charging/device transient's own ~3s auto-advance, whichever fits better
  once the state model is chosen.
- Settings toggle default value (on/off) and exact wording — not discussed; default to "on"
  (matching the existing `nowPlayingKey` default of `true`) unless research/planning finds a
  reason otherwise.

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| NOW-05 | User sees a brief (~3s) toast with the new track's title when playback switches to a genuinely different song (not on the very first track detected after launch), then the island returns to the compact glance | `isSameTrack(_:_:)` (exact signature captured below) is the ready-made genuine-change detector; `handleNowPlaying(_:_:)` is the single integration point; `scheduleMediaDismiss`/`mediaDismissWorkItem` is the exact ~3s one-shot-timer precedent to mirror |
| NOW-06 | User can toggle the song-change toast on/off in Settings (Activities tab, next to the existing Now Playing toggle) | `ActivitySettings` enum + `@AppStorage` pattern (exact keys/defaults captured below) is a direct 2-line extension; toggle applied BEFORE the resolver per existing `npEnabled` discipline in `currentPresentation()` |

## Project Constraints (from CLAUDE.md)

- Tech stack is native Swift + SwiftUI/AppKit only — no Electron/web, no new third-party
  packages for this phase (confirmed: nothing in the phase touches MediaRemote, IOKit, or
  IOBluetooth directly; it consumes the already-classified `NowPlayingPresentation` output).
- Swift 5 language mode / macOS 14.0 deployment target — this phase's code (plain
  `@Published`, `DispatchWorkItem`, `enum`/`struct` values) has no concurrency-mode
  implications; no `async`/`await` or actor isolation is introduced.
- Animation approach: `withAnimation(.spring(response:dampingFraction:))` +
  `matchedGeometryEffect` is the established "morph" mechanism — the toast's "expand downward"
  visual (UI-phase concern per ROADMAP) should reuse the same spring constants
  (`springResponse = 0.35`, `springDamping = 0.65`) already defined on
  `NotchWindowController`, not introduce new tuning constants.
- Pure-seam discipline (explicit repo convention, see below): classification/detection logic
  belongs in Foundation-only files and is unit-tested; timer/controller wiring belongs in the
  `@MainActor` `NotchWindowController` layer and is verified on-device / via Cmd-U.
- No sandboxing, no new entitlements — this phase adds no IOKit/Bluetooth/network surface, so
  the existing `disable-library-validation` / Bluetooth-usage-key entitlements already in
  `project.yml` are unaffected.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Genuine-change detection (title/artist diff) | Pure Foundation seam (`NowPlayingPresentation.swift` / `IslandResolver.swift`) | — | Must be a total, deterministic, unit-testable function — mirrors `isSameTrack`, `nowPlayingLaunchGate` |
| Toast priority/suppression (D-02, D-04) | Pure Foundation seam (`IslandResolver.swift` `resolve(...)`) | — | The single arbiter (D-05) — all ranking/gating logic lives here, never scattered in the controller |
| ~3s toast timer + restart-on-skip (D-03) | `@MainActor` controller (`NotchWindowController.swift`) | — | Timer/clock is explicitly excluded from the pure seams (file headers state "no Timer/clock here"); mirrors `scheduleMediaDismiss` |
| Toast content state (title/artist while showing) | `@Published` model (`NowPlayingState.swift`) | — | Mirrors `presentation`/`artwork`/`hasPlayedSinceLaunch` — plain published holder, no logic |
| Toast on/off persistence | `@AppStorage` (`ActivitySettings.swift` + `SettingsView.swift`) | Controller (`activityEnabled(...)` gate before resolver) | Mirrors `nowPlayingKey`/`chargingKey`/`deviceKey` exactly — app-owned prefs, applied before the resolver per D-09 |
| Toast visual (expand-downward, text render) | SwiftUI view (`NotchPillView.swift`) | — | UI-phase concern (ROADMAP marks "UI hint: yes") — layout/styling deferred, only that it renders title+artist (D-01) is locked here |

## Standard Stack

No new libraries, packages, or frameworks. This phase is a closed-world extension of
first-party Swift/SwiftUI/Foundation code already present in the repo. Package Legitimacy
Audit is not applicable — no `npm install` / SPM package additions occur in this phase.

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| New `@Published` toast field on `NowPlayingState` + new `resolve(...)` parameter | A 4th `IslandPresentation` case entirely separate from `.nowPlayingWings` (e.g. `.songChangeToast(...)`) | Viable, but loses the "ambient branch only" framing that made Phase 17's launch gate trivial to reason about; also forces every `resolve(...)` call site (tests, controller) to add a new top-level switch arm even though the toast is really a decoration ON TOP of the ambient wings state, not a rank-4 peer. Recommend AGAINST unless the toast's expand-downward visual genuinely cannot be expressed as a modifier on `.nowPlayingWings`. |
| `DispatchWorkItem` one-shot timer (mirrors `scheduleMediaDismiss`) | `Timer.scheduledTimer` (used elsewhere only for the 900s outfit-refresh recurring timer) | `DispatchWorkItem` is the established idiom for every OTHER one-shot ~3s/15s dismiss in this file (`scheduleActivityDismiss`, `scheduleMediaDismiss`) — recurring `Timer` is reserved for the one genuinely periodic case. Use `DispatchWorkItem` for consistency and because it composes with `.cancel()` the same way the restart-on-skip (D-03) requirement needs. |
| Reusing `isSameTrack(_:_:)` verbatim for genuine-change detection | Writing a new toast-specific comparison | `isSameTrack` already encodes exactly the semantics NOW-05 needs ("play↔pause on the same track is same, title/artist change or transition to/from `.none` is not") — a new function would duplicate this with high risk of subtle divergence. Reuse verbatim: `!isSameTrack(previous, p)` in `handleNowPlaying` gives "genuine change" directly, with `p != .none` as an additional required guard (see Pitfall 1 below — a stop is NOT the same as a title change). |

## Architecture Patterns

### System Architecture Diagram

```
MediaRemote adapter callback (existing, Phase 4)
        │
        ▼
handleNowPlaying(snapshot, art)          [NotchWindowController.swift, @MainActor]
        │
        ├─ p = nowPlayingPresentation(from: snapshot)     [pure seam, unchanged]
        ├─ previous = nowPlayingState.presentation         (captured BEFORE overwrite, existing)
        │
        ├─ NEW: genuine-change check
        │     guard hasPlayedSinceLaunch (or: skip on the very first .playing, mirrors D-01/17)
        │     guard case .playing/.paused = p  (not .none — a stop must not toast)
        │     guard !isSameTrack(previous, p)  (genuine title/artist change)
        │     guard resolve(...) with isExpanded:false and no ActiveTransient would show wings
        │       (D-02: skip silently if charging/device transient is currently head;
        │        D-04: skip if interaction.isExpanded)
        │  → nowPlayingState.songChangeToast = TrackSnapshot-ish (title, artist)
        │  → (re)schedule the toast's own DispatchWorkItem, cancelling any prior one (D-03 restart)
        │
        ▼
renderPresentation() → resolve(activeTransient:, nowPlaying:, ..., songChangeToast:, isExpanded:)
        │                                          [IslandResolver.swift, pure]
        ▼
presentationState.presentation  (IslandPresentation, @Published)
        │
        ▼
NotchPillView.body switch            [SwiftUI render, UI-phase decides exact visual]
   - .nowPlayingWings(p) today
   - NEW: toast decorates/expands this branch when songChangeToast != nil
```

### Recommended Project Structure

No new files. Extend in place:

```
Islet/
├── ActivitySettings.swift        # + songChangeToastKey (or similar name — NOW-06)
├── SettingsView.swift             # + Toggle next to "Now Playing" (line ~133)
├── Notch/
│   ├── NowPlayingPresentation.swift   # (likely unchanged — isSameTrack reused as-is)
│   ├── NowPlayingState.swift          # + @Published var songChangeToast state
│   ├── IslandResolver.swift           # + toast param/gate in resolve(...), + pure helper
│   │                                    mirroring nowPlayingLaunchGate's shape
│   ├── NotchWindowController.swift    # + detection in handleNowPlaying, + own DispatchWorkItem
│   │                                    timer mirroring scheduleMediaDismiss
│   └── NotchPillView.swift            # UI-phase: render toast content (title+artist, D-01)
IsletTests/
├── IslandResolverTests.swift          # + tests for the new gate/param (D-02, D-04 as pure cases)
└── NowPlayingPresentationTests.swift  # only if a new pure helper is added here instead
```

### Pattern 1: Pure ambient-gate helper (Phase 17 precedent to mirror)

**What:** A `nowPlayingLaunchGate`-shaped total function that the toast's suppression logic
(D-02/D-04) should copy in form — small, pure, one `guard`/ternary, Foundation-only.
**When to use:** Any "hide the ambient presentation under condition X" rule.
**Example (existing code, verbatim — the template to mirror):**
```swift
// Source: Islet/Notch/IslandResolver.swift (current repo state, lines 70-72)
func nowPlayingLaunchGate(hasPlayedSinceLaunch: Bool, nowPlaying: NowPlayingPresentation) -> NowPlayingPresentation {
    hasPlayedSinceLaunch ? nowPlaying : .none
}
```
A toast-suppression helper of the same shape (sketch, not prescriptive on exact signature —
planning decides):
```swift
// Sketch — mirrors nowPlayingLaunchGate's shape exactly; planning finalizes signature/name.
func songChangeToastGate(activeTransient: ActiveTransient?, isExpanded: Bool,
                          toastEnabled: Bool, toast: TrackToast?) -> TrackToast? {
    guard toastEnabled, activeTransient == nil, !isExpanded else { return nil }  // D-02 + D-04
    return toast
}
```

### Pattern 2: One-shot DispatchWorkItem dismiss timer (D-06/D-07 precedent to mirror exactly)

**What:** The established idiom for every ~3s/15s "show then auto-collapse" behavior in this
codebase — cancel-then-reschedule, no recurring `Timer`.
**When to use:** The toast's ~3s auto-dismiss, and its D-03 "restart on rapid skip" behavior
(re-calling the same schedule function IS the restart — cancel-then-reschedule is already
built into the existing pattern, so D-03 requires zero new logic beyond calling the existing
schedule function again on each genuine change).
**Example (existing code, verbatim — the exact template):**
```swift
// Source: Islet/Notch/NotchWindowController.swift (current repo state, lines 1023-1037)
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
A toast dismiss timer follows this exact shape with its own `toastDismissWorkItem` property
and a ~3.0s constant (matching `activityDuration: TimeInterval = 3.0`, NOT `pausedTimeout =
15.0` which is the unrelated paused-glance linger).

### Pattern 3: `@AppStorage` toggle (NOW-06 precedent to mirror exactly)

**What:** App-owned boolean preference, default `true`, shared key constant between
`SettingsView` and the controller.
**Example (existing code, verbatim):**
```swift
// Source: Islet/ActivitySettings.swift (current repo state, lines 13-22)
enum ActivitySettings {
    static let chargingKey   = "activity.charging"
    static let nowPlayingKey = "activity.nowPlaying"
    static let deviceKey     = "activity.device"
    // NEW: static let songChangeToastKey = "activity.songChangeToast"
    ...
}
```
```swift
// Source: Islet/SettingsView.swift (current repo state, lines 28-30, 132-134)
@AppStorage(ActivitySettings.nowPlayingKey) private var nowPlayingEnabled = true
// NEW: @AppStorage(ActivitySettings.songChangeToastKey) private var songChangeToastEnabled = true

Section("Activities") {
    Toggle("Charging", isOn: $chargingEnabled)
    Toggle("Now Playing", isOn: $nowPlayingEnabled)
    // NEW: Toggle("Song-Change Toast", isOn: $songChangeToastEnabled)   <- next to Now Playing per SC-03
    Toggle("Devices", isOn: $deviceEnabled)
}
```
The controller reads it the same way `npEnabled` is read in `currentPresentation()` (line
453), applied BEFORE the resolver — never inside `resolve(...)` itself (D-09 discipline,
confirmed by the `nowPlayingHealthGate`/`nowPlayingLaunchGate` comments).

### Anti-Patterns to Avoid

- **Adding the toast as a 3rd `ActiveTransient` case:** Explicitly forbidden by D-02 — it
  would make the toast queueable/orderable against charging/device splashes, which the user
  decided against ("skipped entirely — not queued, not shown afterward").
- **Detecting "genuine change" by comparing raw `TrackSnapshot` fields instead of the
  classified `NowPlayingPresentation`:** `isSameTrack` operates on the classified enum
  (post-allowlist, post-empty-title-rejection) precisely so a non-allowlisted source or an
  empty title never trips a false "genuine change". Comparing raw snapshots would reintroduce
  bugs `isSameTrack` was written to prevent.
- **A recurring `Timer` for the toast:** Every other one-shot dismiss in this codebase uses
  `DispatchWorkItem` + `asyncAfter`; a recurring `Timer` would need manual invalidation logic
  the codebase deliberately avoids (file-header comment: "NOT a polling loop").
- **Putting the toast-suppression check (D-02/D-04) only in the controller, not in
  `resolve(...)`:** `IslandResolver.swift`'s header states it is "the SINGLE arbiter (D-05)"
  — splitting ranking logic between the controller and the resolver was explicitly what Phase
  6 refactored away from ("replaces the scattered per-pair if-ordering").

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Detecting a genuine title/artist change | A new string-diff or hashing comparison | `isSameTrack(_:_:)` (already exists, already unit-tested, already handles the play↔pause-is-same-track and `.none` edge cases) | Duplicating this logic risks silent divergence from the play/pause-agnostic semantics NOW-05 needs |
| ~3s show-then-collapse timing | A custom debounce/animation-completion callback | `DispatchWorkItem` + `DispatchQueue.main.asyncAfter`, mirroring `scheduleMediaDismiss` | Same idiom used 3x already in this file (`scheduleActivityDismiss`, `scheduleMediaDismiss`); a 4th bespoke mechanism adds inconsistency with zero benefit |
| Toggle persistence | Any custom UserDefaults wrapper or Combine publisher | `@AppStorage` (SwiftUI-native, already the pattern for 5 other toggles) | `@AppStorage` IS the source of truth per this codebase's explicit convention (ActivitySettings.swift header) |

**Key insight:** This phase has zero genuinely novel engineering — every piece it needs
(genuine-change detection, one-shot timer, toggle) already exists as a working, tested
pattern elsewhere in the same three files. The planning risk is entirely in wiring order and
gating placement (ambient-branch-only, pre-resolver toggle check), not in inventing new
mechanisms.

## Common Pitfalls

### Pitfall 1: Treating a stop (`.playing/.paused` → `.none`) as a "genuine change"
**What goes wrong:** `isSameTrack(previous, .none)` returns `false` (per its own doc comment:
"a title change or a transition to/from `.none` is not [same track]"), so a naive
`!isSameTrack(previous, p)` check alone would fire a toast when playback simply STOPS —
showing a toast for an empty title/artist, or crashing on a force-unwrap of `p`'s
title/artist.
**Why it happens:** `isSameTrack` is deliberately silent about `.none` transitions — it only
answers "same track y/n", not "is this presentation showing a track".
**How to avoid:** Guard `case .playing/.paused = p` (i.e. `p != .none`) BEFORE checking
`!isSameTrack(previous, p)`. Only trigger the toast when the NEW presentation is itself a
real track.
**Warning signs:** A toast appearing (with blank or garbage text) exactly when the user
pauses-then-stops or when playback ends.

### Pitfall 2: Firing the toast on the very first track after launch
**What goes wrong:** NOW-05 explicitly excludes "the very first track detected after
launch" — this is nearly identical wording to Phase 17's NOW-04 launch-gate requirement
("not on the very first track detected after launch" vs Phase 17's "only once the user
actually presses Play"). A naive implementation comparing `previous` (initial `.none`) to the
first real `.playing` presentation would see `!isSameTrack(.none, playing)` = `true` and
incorrectly fire a toast.
**Why it happens:** The very first transition from `.none` → `.playing` looks identical, at
the `isSameTrack` level, to a genuine mid-session track change — both are "not same track".
**How to avoid:** Gate on `hasPlayedSinceLaunch` (the exact flag Phase 17 introduced for this
purpose) — e.g. only evaluate the toast trigger when `hasPlayedSinceLaunch` was ALREADY `true`
before this callback set it. Since `handleNowPlaying` sets `hasPlayedSinceLaunch = true`
unconditionally on `.playing` (line 966, "no `if !hasPlayedSinceLaunch` guard needed... do NOT
move into the post-render switch"), the toast-trigger check must read the PRE-callback value
of `hasPlayedSinceLaunch` (captured at the top, same pattern as `previous`/`previousPosition`
are already captured before being overwritten).
**Warning signs:** A toast appearing immediately at app launch or immediately after the user
presses Play for the very first time in a session.

### Pitfall 3: Re-arming the toast timer even when the toast was suppressed (D-02/D-04)
**What goes wrong:** If the toast-suppression check (charging/device active, or expanded) is
applied AFTER already scheduling the dismiss timer, a suppressed toast could still leave a
stale `DispatchWorkItem` that fires later and clears/re-renders state for a toast that was
never shown, potentially clobbering a charging/device splash's own render.
**Why it happens:** Mirrors a documented gap-closure fix already in this file (Finding 3 /
WR-2, "dismiss-timer not re-armed on promotion" / "over-eager dismiss-timer reset") — this
codebase has twice already hit and fixed exactly this class of bug for the existing transient
queue.
**How to avoid:** Compute the D-02/D-04 suppression check FIRST; only call the schedule
function if the toast will actually be shown. Do not schedule-then-suppress.
**Warning signs:** A charging/device splash flickering or reverting to ambient state a few
seconds after it starts, coinciding with a song change that happened while it was showing.

### Pitfall 4: Toggle-off not clearing an already-showing toast
**What goes wrong:** The existing `nowPlayingKey`/`chargingKey`/`deviceKey` toggles all have
an explicit "if disabled while currently showing, clear it live" branch in
`applyActivitySettings` (lines ~852-880: `mediaDismissWorkItem?.cancel()`,
`nowPlayingState.presentation = .none`, etc.). A naive NOW-06 toggle that only gates NEW
toasts (checked at trigger time) but doesn't clear an in-flight one would leave a toast
visible after the user turns it off mid-toast.
**Why it happens:** The toggle is easy to wire as a simple `if enabled` guard at the trigger
site while missing the "already showing, now disabled" live-update case that the other three
toggles handle explicitly.
**How to avoid:** Mirror the existing `nowPlayingKey` disable branch (lines 872-880) — when
the toast toggle flips off, cancel its `DispatchWorkItem` and clear its `@Published` state
inside `applyActivitySettings`, not just gate future triggers.
**Warning signs:** Turning the toggle off in Settings while a toast is on-screen and watching
it NOT disappear until its natural ~3s timer would have elapsed anyway.

## Code Examples

### `isSameTrack` — exact current signature (the detection primitive)
```swift
// Source: Islet/Notch/NowPlayingPresentation.swift, lines 69-78 (current repo state)
func isSameTrack(_ a: NowPlayingPresentation, _ b: NowPlayingPresentation) -> Bool {
    func titleArtist(_ p: NowPlayingPresentation) -> (title: String, artist: String)? {
        switch p {
        case .playing(let t, let a), .paused(let t, let a): return (t, a)
        case .none: return nil
        }
    }
    guard let ta = titleArtist(a), let tb = titleArtist(b) else { return false }
    return ta == tb
}
```

### `resolve(...)` — exact current signature (must be extended, not replaced)
```swift
// Source: Islet/Notch/IslandResolver.swift, lines 34-54 (current repo state)
func resolve(activeTransient: ActiveTransient?,
             nowPlaying: NowPlayingPresentation,
             nowPlayingHealthy: Bool,
             hasPlayedSinceLaunch: Bool,
             isExpanded: Bool) -> IslandPresentation {
    switch activeTransient {
    case .charging(let a): return .charging(a)
    case .device(let d):   return .device(d)
    case nil: break
    }
    if isExpanded {
        if !nowPlayingHealthy { return .nowPlayingExpanded(nowPlaying, healthy: false) }
        if nowPlaying != .none { return .nowPlayingExpanded(nowPlaying, healthy: true) }
        return .expandedIdle
    }
    let ambient = nowPlayingLaunchGate(hasPlayedSinceLaunch: hasPlayedSinceLaunch, nowPlaying: nowPlaying)
    if ambient != .none { return .nowPlayingWings(ambient) }
    return .idle
}
```
A toast parameter would be added here as an additional argument, consumed ONLY inside the
`if ambient != .none { return .nowPlayingWings(ambient) }` branch (never inside `isExpanded`,
per D-04) and never inside the `switch activeTransient` branch (per D-02 — if a transient is
active, `resolve` returns before the toast param is even inspected, which IS the "skip
silently" behavior D-02 asks for, for free).

### `handleNowPlaying` — exact current integration point
```swift
// Source: Islet/Notch/NotchWindowController.swift, lines 945-1017 (current repo state, abridged)
private func handleNowPlaying(_ snapshot: TrackSnapshot?, _ art: NSImage?) {
    let p = nowPlayingPresentation(from: snapshot)
    let previous = nowPlayingState.presentation   // <- capture point; toast trigger reads this too
    let previousPosition = nowPlayingState.position
    nowPlayingState.isHealthy = true
    if case .playing = p { nowPlayingState.hasPlayedSinceLaunch = true }  // <- Pitfall 2: capture
                                                                            //    the PRE-value first
    withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
        nowPlayingState.presentation = p
        // ... position/artwork logic unchanged ...
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
The toast-trigger check belongs alongside this function, reading `previous` and the
pre-callback `hasPlayedSinceLaunch` value (captured before the `if case .playing` line
mutates it), then calling a new `scheduleToastDismiss()` mirroring `scheduleMediaDismiss`
exactly if D-02/D-04/Pitfall-1/Pitfall-2 all pass.

## State of the Art

Not applicable — no external library/framework version drift to track. All primitives used
(`DispatchWorkItem`, `@AppStorage`, `@Published`, `withAnimation(.spring)`) are stable
first-party APIs already in active use throughout this codebase; no deprecations or
API changes affect this phase.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The toast should be modeled as a 4th `@Published` field on `NowPlayingState` + a new `resolve(...)` parameter, rather than a new `IslandPresentation` case | Summary, Standard Stack (Alternatives) | Low — this is a planning-time structural choice CONTEXT.md explicitly left to research/planning discretion; the plan can choose the alternative (new `IslandPresentation` case) without violating any locked decision, as long as D-02/D-04 gating still lands in `resolve(...)` |
| A2 | The toast's own dismiss constant should be ~3.0s (matching `activityDuration`), distinct from `pausedTimeout` (15.0s) | Pattern 2 | Low — ROADMAP/CONTEXT.md both say "~3s" explicitly (Success Criterion 1), so this is directly sourced, not assumed; flagged only because the exact constant name/placement is left to planning |
| A3 | The new Settings toggle key should be named something like `activity.songChangeToast` following the `activity.*` namespace convention | Pattern 3 | Low — cosmetic; any key name works as long as it's a new distinct `@AppStorage` key; exact string is planning's choice |

**If this table is empty:** N/A — see above; all three entries are low-risk naming/structural
choices explicitly deferred to planning by CONTEXT.md, not uncertain facts about the domain.

## Open Questions

1. **Should the toast be a new `IslandPresentation` case or a decoration on `.nowPlayingWings`?**
   - What we know: D-02 requires it to sit outside `ActiveTransient`/`TransientQueue`; D-04
     requires it to apply to the ambient branch only. Both constraints are satisfiable either
     way.
   - What's unclear: Whether the UI-phase's "expand downward" visual is easier to express as
     a new case (`.nowPlayingWings(_, toast: TrackToast?)` associated value, or a sibling
     `.songChangeToast(NowPlayingPresentation)` case) vs a view-layer-only flag read alongside
     `.nowPlayingWings`.
   - Recommendation: Planning should default to adding an associated value to
     `.nowPlayingWings` (e.g. `case nowPlayingWings(NowPlayingPresentation, toast: TrackSnapshot?)`)
     since this keeps the toast strictly subordinate to the ambient case rather than a peer,
     matching D-02's "not a new tier" framing most literally. Confirm with the UI phase once
     the exact expand-downward geometry is designed.

2. **Does the toast need its own `Equatable` value type, or can it reuse a lightweight
   `(title: String, artist: String)?` tuple / the existing `TrackSnapshot`?**
   - What we know: `TrackSnapshot` already exists and carries title/artist (plus playback
     fields the toast doesn't need). `NowPlayingPresentation`'s `.playing`/`.paused` cases
     also already carry title/artist.
   - What's unclear: Whether reusing `NowPlayingPresentation` itself for the toast's stored
     value (rather than a new struct) creates confusion between "what's ambiently playing" and
     "what the toast is currently showing" during the ~3s window where they could differ (D-03
     rapid-skip case: toast still showing song A's text while `nowPlaying` has already moved
     to song C).
   - Recommendation: Store the toast's own snapshot value (title+artist pair) SEPARATELY from
     `nowPlayingState.presentation`, since D-03 explicitly describes a window where the two
     diverge (toast content = "last settled call", ambient state = "current live state").
     Reusing `NowPlayingPresentation`'s `.playing`/`.paused` cases for this stored value is
     fine; aliasing the toast's storage directly to `presentation` is not.

## Environment Availability

Skipped — this phase has no external tool/service/runtime dependency beyond the existing
Xcode 16 / macOS 14.0 toolchain already verified working for prior phases (confirmed via
project memory: build machine is Tahoe/Xcode 26.6/Swift 6.3.3, Swift 5 language mode).

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (native, via `xcodebuild`) |
| Config file | `project.yml` (XcodeGen) → generates `Islet.xcodeproj`; scheme `Islet`, test target `IsletTests` |
| Quick run command | `xcodebuild build -project Islet.xcodeproj -scheme Islet -configuration Debug` (build-as-gate; see below) |
| Full suite command | Manual Cmd-U in Xcode GUI (documented project pitfall — `xcodebuild test` hangs) |

**Known project pitfall (from prior-session memory, confirmed applicable here):**
`xcodebuild test` hangs because tests are hosted inside the full `Islet.app`, which boots the
`NSPanel`/MediaRemote/IOBluetooth stack at test-runner launch. The established workaround for
this codebase is: use `xcodebuild build` as the automated commit-time gate (compiles + type-
checks the new pure-seam code and its tests), and route the actual test EXECUTION to a manual
Cmd-U in Xcode, exactly as done for Phase 17. Any plan for this phase must follow the same
split — do not have tasks assume `xcodebuild test` will complete headlessly.

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| NOW-05 | Genuine track change triggers toast; same-track (play/pause) does not; first track after launch does not; D-02 suppression while charging/device active; D-04 suppression while expanded; D-03 restart-on-rapid-skip | unit (pure `resolve(...)`/new gate helper) | `xcodebuild build ...` (compile gate) + manual Cmd-U for `IslandResolverTests` | ❌ Wave 0 — new test cases needed in existing `IslandResolverTests.swift` |
| NOW-05 (timer wiring) | ~3s auto-dismiss, restart on rapid skip (D-03), suppressed toast doesn't leave a stale timer (Pitfall 3) | manual-only (controller/timer, `@MainActor`, `DispatchWorkItem`) | — | N/A — controller-layer timer wiring is verified on-device per this codebase's established discipline (pure seam gets unit tests, controller wiring gets on-device verification) |
| NOW-06 | Toggle on/off in Settings; toggling off mid-toast clears it live (Pitfall 4) | manual-only (SwiftUI view + `@AppStorage` + live controller state) | — | N/A — `SettingsView`/`@AppStorage` toggle wiring has no existing automated-test precedent in this codebase (the 3 existing toggles are also unverified by XCTest, only by manual Settings-tab checks per STATE.md quick-task history) |

### Sampling Rate
- **Per task commit:** `xcodebuild build -project Islet.xcodeproj -scheme Islet -configuration Debug` (compile gate for every pure-seam change)
- **Per wave merge:** Manual Cmd-U run of `IslandResolverTests` (+ `NowPlayingPresentationTests` if a new pure helper lands there) in Xcode GUI
- **Phase gate:** Full manual Cmd-U pass + on-device verification of the toast timing/suppression/toggle behavior before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] New test cases in `IsletTests/IslandResolverTests.swift` covering: genuine-change → toast
      shown; same-track (play↔pause) → toast NOT re-triggered; D-02 (active transient present)
      → toast suppressed; D-04 (`isExpanded: true`) → toast suppressed; first-track-after-launch
      (`hasPlayedSinceLaunch` pre-value false) → toast suppressed
- [ ] No new test file needed — extend the existing `IslandResolverTests.swift` (313 lines,
      already covers D-02/D-04-shaped resolver cases) rather than creating a new file
- [ ] Framework install: none — XCTest already configured and working for this target

## Security Domain

`security_enforcement` is absent from `.planning/config.json` (workflow block has no such
key) → treated as enabled per the default rule. However, this phase introduces no new
external input, no new network/IPC surface, no new persisted user data beyond a boolean
toggle, and no new entitlements.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | N/A — no auth surface touched |
| V3 Session Management | No | N/A |
| V4 Access Control | No | N/A — single-user local app, no access boundaries |
| V5 Input Validation | Marginal | The toast's title/artist strings originate from `TrackSnapshot`, already validated by the existing `nowPlayingPresentation(from:)` allowlist/empty-check (D-01) — no NEW untrusted input path is introduced; the toast merely displays a value already rendered elsewhere in the ambient glance |
| V6 Cryptography | No | N/A |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Untrusted track-title text rendered as SwiftUI `Text` | Tampering (low severity — a malicious media player could set an adversarial title string) | SwiftUI `Text` does not interpret its string content as markup/HTML by default (unlike a WKWebView render path), so no injection risk; this is the same trust boundary the existing Now Playing glance already accepts (no new exposure from this phase) |

No new threats are introduced by this phase; it is a display-only extension of an
already-accepted data path.

## Sources

### Primary (HIGH confidence — direct repo reads, this session)
- `Islet/Notch/IslandResolver.swift` — full file read, `resolve(...)`, `IslandPresentation`,
  `ActiveTransient`, `TransientQueue`, `nowPlayingLaunchGate` current signatures
- `Islet/Notch/NowPlayingPresentation.swift` — full file read, `isSameTrack(_:_:)`,
  `TrackSnapshot`, `NowPlayingPresentation` current signatures
- `Islet/Notch/NowPlayingState.swift` — full file read, `@Published` field list
- `Islet/Notch/NotchWindowController.swift` — targeted reads (lines 440-480, 790-1050):
  `currentPresentation()`, `handleNowPlaying(_:_:)`, `scheduleMediaDismiss`,
  `scheduleActivityDismiss`, `flushTransients`, spring constants
- `Islet/Notch/NotchPillView.swift` — grep + targeted read: presentation-switch rendering,
  `wingsShape`/`wings(for:)` precedent
- `Islet/ActivitySettings.swift` — full file read, `@AppStorage` key namespace
- `Islet/SettingsView.swift` — targeted reads: `@AppStorage` declarations, Activities tab
  Toggle list (line 131-135)
- `IsletTests/IslandResolverTests.swift`, `IsletTests/NowPlayingPresentationTests.swift` —
  targeted reads confirming existing test structure/conventions
- `.planning/phases/18-song-change-toast/18-CONTEXT.md` — locked decisions D-01–D-04,
  discretion areas
- `.planning/REQUIREMENTS.md`, `.planning/STATE.md` — NOW-05/NOW-06 wording, phase sequencing
- `.planning/config.json` — `nyquist_validation: true`, no `security_enforcement` key
- `project.yml` — confirmed scheme name `Islet`, macOS 14.0 deployment target
- Project memory (`xcodebuild-test-headless-hang.md`) — confirmed `xcodebuild test` hang
  pitfall applies to this phase's test strategy

### Secondary / Tertiary
None used — this phase required zero external documentation lookups (no new library,
framework, or API); all research was direct codebase investigation.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — zero new dependencies, 100% reuse of verified in-repo patterns
- Architecture: HIGH — every referenced file/function was read directly this session, not
  inferred from CONTEXT.md's description alone
- Pitfalls: HIGH — all four pitfalls are either directly derivable from reading the exact
  current code (Pitfall 1, 2) or documented gap-closure fixes already present in this same
  file for the analogous transient-queue mechanism (Pitfall 3, 4)

**Research date:** 2026-07-09
**Valid until:** Effectively unbounded for this phase (no external API/version drift risk);
re-verify only if Phase 17's `IslandResolver.swift`/`NowPlayingState.swift` code changes
before Phase 18 planning begins.
