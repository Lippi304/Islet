# Phase 7: Now Playing Progress Bar - Research

**Researched:** 2026-07-04
**Domain:** SwiftUI continuous-animation UI on top of an existing MediaRemote data feed (no new external dependency, no new IPC)
**Confidence:** HIGH

## Summary

This phase is almost entirely **plumbing + SwiftUI layout**, not new integration risk. The
hard problem (bridging MediaRemote on macOS 15.4+) is already solved and isolated in
`NowPlayingMonitor.swift`; this phase only needs to (1) stop dropping four fields
(`durationMicros`, `elapsedTimeMicros`, `timestampEpochMicros`, `playbackRate`) that the
vendored adapter already delivers, (2) thread them through the existing pure-seam →
`@Published` model → view layering the codebase already uses for every other feature, and
(3) render a thin accent-filled bar driven by a local, expanded-gated `TimelineView` that
extrapolates position between snapshot pushes using a formula the vendored package already
implements (`TrackInfo.Payload.currentElapsedTime`).

I confirmed on-device (via the checked-out Swift package in DerivedData, `git rev-parse
HEAD` matched against `project.yml`'s pinned revision `cf30c4f1af29b5829d859f088f8dbdf
12611a046`) that `TrackInfo.Payload` exposes exactly the four numeric fields CONTEXT.md
expected, all `Double?`, plus a computed `currentElapsedTime: TimeInterval?` with the
exact drift-corrected formula CONTEXT.md described, including the paused-freeze branch. No
guessing required here — this is source-verified, not assumed.

The app's `EqualizerBars` component is the direct, load-bearing precedent for the local
continuous-timer requirement (D-07): it already uses `TimelineView(.animation(paused:
!isPlaying))` gated on a boolean, explicitly to avoid leaving a `.repeatForever` clock
running and breaking the idle-CPU discipline documented throughout this codebase. The
progress bar's timer should follow the identical pattern, additionally gated on
`isExpanded` (per CONTEXT.md's Claude's-discretion note) since the bar only ever renders
in `mediaExpanded`.

**Primary recommendation:** Extend `TrackSnapshot`/`NowPlayingPresentation` and
`NowPlayingState` to carry the four raw fields (or the precomputed `currentElapsedTime` +
`duration` pair), lift them in `NowPlayingMonitor.onTrackInfoReceived`, and render a new
`ProgressBar` subview inside `mediaExpanded`'s `VStack` (replacing the 4pt D-09 spacer)
driven by a `TimelineView(.animation(paused: !isPlaying))` that recomputes elapsed time
from `(elapsedSeconds, timestampSeconds, rate)` each tick — mirroring `EqualizerBars`
exactly, not inventing a new animation mechanism.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Raw playback position/duration data | Native process bridge (MediaRemoteAdapter via `NowPlayingMonitor`) | — | Already the sole owner of all MediaRemote IPC (CLAUDE.md isolation mandate); this phase only stops discarding fields it already receives |
| Pure classification/shape of position data | Pure seam (`NowPlayingPresentation.swift`) | — | Existing `TrackSnapshot`/`nowPlayingPresentation(from:)` convention — plain values, framework-free, unit-testable |
| Live position state for the view | `@Published` model (`NowPlayingState.swift`) | — | Mirrors how `presentation`/`artwork`/`isHealthy` already flow; new fields join this model, not a new one |
| Continuous interpolation between snapshots | SwiftUI view layer (`NotchPillView.swift`, `TimelineView`) | — | `EqualizerBars` precedent: extrapolation-over-time belongs in the view's render loop, not in the `@Published` model (no `Timer`/clock object in app state) |
| Visual rendering (bar, labels, color) | SwiftUI view layer | — | Pure declarative rendering, accent color read from existing `\.activityAccent` environment value |

## User Constraints (from CONTEXT.md)

<user_constraints>

### Locked Decisions

- **D-01:** Right-side label shows total track duration (not countdown) — format `elapsed
  / total`, e.g. "1:23 / 3:45". The REQUIREMENTS.md "remaining" wording is superseded by
  its own example.
- **D-02:** Labels flank the bar ends on one row — elapsed left of bar, total right (Apple
  Music mini-player style), not stacked below.
- **D-03:** Bar's filled portion uses the app's existing `@AppStorage` accent color (same
  one tinting equalizer bars / charging bolt); unfilled track stays dim grey/white.
- **D-04:** Thin minimalist line (~2-3pt tall, rounded caps) — not a thick Alcove-style
  capsule.
- **D-05:** Time label text matches existing title/artist typography — secondary grey
  (`.foregroundStyle(.secondary)`), not accent-tinted.
- **D-06:** Expanded island grows taller (~16-20pt) to fit bar + labels; the 4pt D-09
  placeholder spacer is replaced, not reused as-is. No compression of the art/title/artist
  row or the control row to compensate. Placement: between the top row (art/title/artist/
  bars) and the bottom control row.
- **D-07:** Bar animates continuously while playing (visibly gliding fill), not a
  once-per-second step. Technical basis: `mediaremote-adapter`'s stream only pushes a new
  snapshot on play/pause/track-change, not continuously — a locally-driven UI timer is
  required to interpolate between snapshots, reusing the vendored `currentElapsedTime`
  formula (`elapsedSeconds + (now - timestampSeconds) * rate`) rather than reinventing it.
  None of these fields currently flow through `TrackSnapshot`/`NowPlayingPresentation`/
  `NowPlayingState` — extending that seam is required plumbing, not a new architectural
  decision. This does NOT add polling of MediaRemote itself — only a local SwiftUI-side
  animation/timer recomputing from already-received data.

### Claude's Discretion

- Exact bar height (~2-3pt), exact accent-vs-track color values, corner radius of rounded
  caps, and the exact SwiftUI mechanism for the continuous local timer (`TimelineView`, a
  `Timer.publish`, or the existing display-link-style approach `EqualizerBars` already
  uses) — pick whichever fits existing animation patterns.
- Whether the local UI timer runs only while the island is expanded (progress bar only
  ever renders there) to keep idle CPU ~0% when collapsed — consistent with established
  idle-CPU discipline.
- Exact new expanded-island height value and how it composes with
  `NotchPillView.expandedSize` / `NotchGeometry`'s existing frame math — as long as it
  grows (D-06) and doesn't compress existing rows.
- How the bar/labels render (or don't) during the D-12 "Now Playing nicht verfügbar" state
  and the D-11 no-media date/time state — different view branches (`mediaUnavailable`,
  `expandedIsland`) this phase doesn't touch; the bar only appears in `mediaExpanded`
  (playing/paused).
- Whether pausing freezes the bar's fill position exactly at the last known elapsed value
  vs. any other paused-state micro-behavior not explicitly discussed.

### Deferred Ideas (OUT OF SCOPE)

- Tap/drag-to-seek — excluded by REQUIREMENTS.md Out of Scope; the bar is inert to
  clicks/drags.
- Accent-tinted time label numbers — rejected in favor of matching existing title/artist
  grey typography (D-05).
- Thick Alcove-style capsule bar — rejected in favor of the thin line (D-04).
- Once-per-second stepped update — rejected in favor of continuous smooth animation
  (D-07).
- Shuffle/Repeat controls, sneak-peek, color-adaptive tint, waveform on artwork — v2
  deferrals from Phase 4, untouched here.
- Fullscreen-flash fix — Phase 8 (FS-01), unrelated.
- Widening the Spotify/Apple-Music source allowlist — Phase 4 D-01, unchanged.

</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PBAR-01 | Horizontal progress bar in expanded Now Playing view with elapsed/total time labels; smooth update while playing, holds still while paused; no tap-to-seek | Vendored `currentElapsedTime` formula source-verified (Code Examples); exact integration points identified in `NowPlayingPresentation.swift`/`NowPlayingState.swift`/`NowPlayingMonitor.swift`/`NotchPillView.swift` (Architecture Patterns); `EqualizerBars` gives a working, idle-CPU-safe continuous-animation precedent to copy (Code Examples); layout insertion point and height-growth mechanics confirmed line-by-line (Code Examples) |
</phase_requirements>

## Standard Stack

### Core

No new libraries. This phase extends the existing vendored dependency's usage; it adds
zero new packages.

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI `TimelineView` | Ships with macOS 14+ SDK (already targeted, `MACOSX_DEPLOYMENT_TARGET: 14.0` in project.yml) | Drives the continuous fill-position interpolation | Already the app's chosen mechanism for `EqualizerBars`' continuous animation — same tool, same idle-CPU-safe pattern (`.animation(paused:)`), zero new API surface to learn |
| MediaRemoteAdapter (existing, unchanged) | Pinned commit `cf30c4f1af29b5829d859f088f8dbdf12611a046` `[VERIFIED: on-device `git rev-parse HEAD` in the DerivedData checkout matches project.yml's pinned revision]` | Source of `durationMicros`/`elapsedTimeMicros`/`timestampEpochMicros`/`playbackRate` | Already integrated in Phase 4; this phase reads four fields it was already receiving and discarding |

### Supporting

None — no new supporting libraries needed. Time formatting (`m:ss`) can be done with a
small pure helper function (`String(format:)` or `DateComponentsFormatter`); no library
required for something this small, consistent with the "no unnecessary complexity" project
constraint.

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `TimelineView(.animation(paused:))` for the interpolation clock | `Timer.publish(...).autoconnect()` + `@State` | `Timer.publish` is a viable alternative but is a NEW pattern in this codebase (the project currently has zero `Timer`/`Combine` publisher usage for continuous UI updates); `TimelineView` is already proven working, already idle-CPU-verified on-device (per `EqualizerBars`' code comments), and avoids introducing Combine only for this. Recommend `TimelineView` unless a concrete limitation is hit. |
| `TrackInfo.Payload.currentElapsedTime` (vendored formula, computed in the package) | Re-deriving `elapsed + (now - timestamp) * rate` inside app code | CONTEXT.md D-07 already directs reuse of the vendored formula. Since `TrackSnapshot` is a plain value type owned by this app (not the vendored `Payload` struct), the app cannot call the vendored computed property directly after lifting fields into `TrackSnapshot` — the SAME formula must be re-implemented as a plain function in the pure seam (mirroring the vendored logic exactly, not reinventing the approach). This is not a meaningful behavioral alternative, just a code-location detail — see Code Examples. |
| `String(format: "%d:%02d", ...)` for `m:ss` formatting | `DateComponentsFormatter` (`.abbreviated`/`.positional` style) | `DateComponentsFormatter` is more "Apple-native" but has locale/edge-case quirks (e.g., can render "0:00" vs "00:00" inconsistently, and needs `allowedUnits`/`zeroFormattingBehavior` tuning to avoid unwanted hour components at longer durations). A tiny hand-rolled `m:ss` formatter is simpler, has zero ambiguity for track lengths (always well under an hour), and matches the project's stated preference to avoid unnecessary abstraction for a first-time programmer. Recommend the hand-rolled formatter; `DateComponentsFormatter` is a reasonable alternative if the planner prefers idiomatic Foundation API. |

**Installation:**
No installation step — no new packages. `project.yml` is unchanged.

**Version verification:** N/A — no new package versions to verify. The existing
MediaRemoteAdapter pin was independently re-confirmed on-device this session (see Sources).

## Package Legitimacy Audit

Not applicable — this phase introduces zero new external packages. The only external
dependency touched (`MediaRemoteAdapter`) is the existing Phase-4 pin, unchanged, and was
independently re-verified this session by checking `git rev-parse HEAD` in the resolved
Swift Package Manager checkout against `project.yml`'s `revision:` value — both equal
`cf30c4f1af29b5829d859f088f8dbdf12611a046`. No `slopcheck`/registry audit is required for
a zero-new-package phase.

## Architecture Patterns

### System Architecture Diagram

```
mediaremote-adapter (perl-bridged MediaRemote IPC, unchanged Phase-4 plumbing)
        │  TrackInfo.Payload { title, artist, isPlaying,
        │                      durationMicros, elapsedTimeMicros,
        │                      timestampEpochMicros, playbackRate, ... }
        ▼
NowPlayingMonitor.swift  (controller.onTrackInfoReceived closure, ~line 70-79)
        │  lifts 4 NEW fields (currently dropped) into an EXTENDED TrackSnapshot
        ▼
NowPlayingPresentation.swift  (pure seam)
        │  TrackSnapshot → nowPlayingPresentation(from:) → NowPlayingPresentation
        │  EXTENDED to carry duration/elapsed/timestamp/rate alongside title/artist
        ▼
NowPlayingState.swift  (@Published model)
        │  new @Published fields (or a bundled struct) hold live position data
        ▼
NotchWindowController.swift  (resolver glue, unchanged pattern)
        │  IslandResolver.resolve(...) already threads NowPlayingPresentation through
        │  .nowPlayingExpanded(_, healthy:) — carries position data for free once the
        │  enum case's payload is extended
        ▼
NotchPillView.swift → mediaExpanded(_:art:)
        │  reads position data from the presentation/state it's already handed
        ▼
NEW: ProgressBar subview, inside VStack(spacing: 6), replacing the 4pt D-09 spacer
        │  TimelineView(.animation(paused: !isExpanded || !isPlaying)) { context in
        │      recompute elapsed = elapsedSeconds + (context.date - timestampSeconds) * rate
        │      render Capsule (accent, filled width) + Capsule (grey, track) + 2 Text labels
        │  }
```

### Recommended Project Structure

No new files strictly required — this fits the existing "extend the Phase-4 quartet"
shape. If the planner prefers isolating the new visual component (consistent with
`EqualizerBars` being a standalone `struct: View` inside `NotchPillView.swift`), add:

```
Islet/Notch/
├── NowPlayingPresentation.swift   # EXTEND: TrackSnapshot + NowPlayingPresentation payload
├── NowPlayingState.swift          # EXTEND: new @Published position fields
├── NowPlayingMonitor.swift        # EXTEND: lift 4 new Payload fields in onTrackInfoReceived
├── NotchPillView.swift            # EXTEND: mediaExpanded(...) layout + new ProgressBar struct
```

### Pattern 1: Continuous, idle-CPU-gated interpolation (EqualizerBars precedent)

**What:** A `TimelineView(.animation(paused: <gate>))` recomputes a time-derived value on
every frame while un-paused, and stops entirely (zero clock, zero CPU) when paused.

**When to use:** Any UI element that must animate smoothly between discrete data pushes
without a `Timer`/Combine publisher living in app state.

**Example (existing code, `NotchPillView.swift` lines 519-537):**
```swift
// Source: Islet/Notch/NotchPillView.swift (existing EqualizerBars — this phase's
// TimelineView pattern should mirror this exactly, gated additionally on isExpanded).
var body: some View {
    TimelineView(.animation(paused: !isPlaying)) { context in
        let t = context.date.timeIntervalSinceReferenceDate
        // ... derive a value from `t`, render it ...
    }
}
```

**For the progress bar**, the gate should be `paused: !(isPlaying && isExpanded)` (the
Claude's-discretion idle-CPU note) — but since the bar view only ever gets constructed
inside `mediaExpanded(...)`, which itself only renders when `isExpanded` is already true
(per `IslandResolver.resolve`'s branching), the `isExpanded` half of the gate is likely
already structurally guaranteed by WHERE the view lives in the switch — the timer simply
doesn't exist in the view tree when collapsed. Confirm this during planning: if
`mediaExpanded` were ever pre-constructed off-screen (it isn't currently — SwiftUI's
`switch` in `NotchPillView.body` only instantiates the active case), the extra
`isExpanded` gate would become necessary; today it appears redundant but cheap insurance.

### Pattern 2: Pure formula reuse (drift-corrected elapsed time)

**What:** Recompute the true elapsed position from a `(elapsedSeconds, timestampSeconds,
rate, isPlaying)` tuple captured at the last snapshot, rather than trusting a stale
`elapsedSeconds` value directly.

**When to use:** Any time a snapshot-pushed timestamp needs to be extrapolated forward to
"now" for smooth display.

**Example (source-verified from the vendored package, exact formula to mirror as a plain
function in the pure seam):**
```swift
// Source: SourcePackages/checkouts/mediaremote-adapter/Sources/MediaRemoteAdapter/
// TrackInfo.swift (pinned commit cf30c4f1af29b5829d859f088f8dbdf12611a046, verified
// on-device this session — this is the ACTUAL vendored source, not training-data recall)
public var currentElapsedTime: TimeInterval? {
    guard let elapsedMicros = elapsedTimeMicros,
          let timestampMicros = timestampEpochMicros else {
        return nil
    }
    let elapsedSeconds = elapsedMicros / 1_000_000
    if isPlaying != true {
        return elapsedSeconds   // paused/unknown → freeze exactly here (D-07's "holds still")
    }
    let timestampSeconds = timestampMicros / 1_000_000
    let rate = playbackRate ?? 0.0
    let now = Date().timeIntervalSince1970
    let timeSinceUpdate = now - timestampSeconds
    return elapsedSeconds + (timeSinceUpdate * rate)
}
```

This exact struct/property lives on `TrackInfo.Payload`, a vendored type. Because the
app's own `TrackSnapshot` is a separate, pure, hand-constructible value type (deliberately
decoupled from the vendored type per the pure-seam discipline), this formula must be
**re-implemented as a small pure function** in `NowPlayingPresentation.swift` operating on
`TrackSnapshot`'s own fields — copy the logic, not the type. This keeps `TrackSnapshot`
constructible by hand in tests (no `MediaRemoteAdapter` import in the pure seam) while
reusing the exact, already-correct math.

**Important subtlety confirmed from source:** when `isPlaying != true`, the formula
returns `elapsedSeconds` directly — it does NOT use `context.date` at all in the paused
case. This means the paused-freeze behavior (success criterion 3, "holds perfectly still")
is already correct BY CONSTRUCTION if the reimplemented function is a straight port: a
`TimelineView` tick while paused would recompute the same frozen value every frame (safe,
though redundant) — but since the timer should also be paused via `.animation(paused:
!isPlaying)`, no ticks fire at all while paused, so this is a non-issue either way. Do not
let the paused state derive its displayed value from `context.date`.

### Pattern 3: `matchedGeometryEffect` absorbs frame-size changes automatically

**What:** Both `mediaExpanded` and every other case-branch view share ONE
`matchedGeometryEffect(id: "island", in: ns)` on the SAME `@Namespace`. Changing
`Self.expandedSize.height` (D-06) changes the `.frame(width:height:)` this modifier is
attached to; SwiftUI's morph animation interpolates the height change automatically,
exactly like it already does for the collapsed↔expanded transition.

**When to use:** Confirmed applicable here — no separate resize/animation logic is needed
for D-06's height growth. This is a straightforward `Self.expandedSize` constant edit plus
padding-math bookkeeping (see below), not new animation code.

**Confirmed source (`NotchPillView.swift` lines 78-93):**
```swift
// Source: Islet/Notch/NotchPillView.swift (existing height-math comment — the SAME
// arithmetic discipline this phase's height bump must follow)
// Height fits the tallest expanded content WITH a top notch-clearance band...
//   32 (top notch clearance)
// + 84 (mediaExpanded content: HStack art 40 + spacing 6 + seek spacer 4 + spacing 6
//        + transport row 28)
// + 12 (bottom inset)
// = 128.
static let expandedSize = CGSize(width: 360, height: 128)
```
The "seek spacer 4" line in this exact comment is the D-09 placeholder CONTEXT.md
identifies as the insertion point. Growing it from 4pt to a real bar+labels row (D-06 says
~16-20pt growth) means: (a) replace `Spacer(minLength: 0).frame(height: 4)` at line 411
with the new row, (b) update the arithmetic comment and `expandedSize.height` from 128 to
128 + (new_row_height − 4) ≈ 140-148, and (c) since `Self.expandedSize` is ALSO fed into
the panel's window frame sizing elsewhere (confirmed by the comment: "The panel window
(expandedNotchFrame) and the SwiftUI content frame both derive from THIS one value"), a
single constant change propagates correctly — but the planner should grep for every other
consumer of `NotchPillView.expandedSize` (e.g. `NotchWindowController`'s
`expandedNotchFrame`/`NotchGeometry`) to confirm no second hard-coded height value needs
updating in parallel.

### Anti-Patterns to Avoid

- **A repeating `Timer`/Combine publisher stored as app state:** would be a genuinely new
  pattern in a codebase that has deliberately avoided this everywhere else (see D-08 in
  `NotchPillView.swift`'s own header comment: "This is the VIEW LAYER only. It drives NO
  animation itself"). `TimelineView` keeps the clock scoped to the view's render pass,
  with no risk of an orphaned timer outliving its view or double-firing across re-renders.
- **Deriving the paused-state displayed value from `context.date`:** would silently
  reintroduce drift/jitter into what must be a perfectly still paused bar (success
  criterion 3). The vendored formula's own branch structure (`if isPlaying != true {
  return elapsedSeconds }`) is the guardrail — mirror it exactly, don't "simplify" it into
  a single unconditional expression.
- **Polling MediaRemote again for position (e.g. a second `getTrackInfo` call on a
  timer):** violates the explicit "no re-spawning, no polling MediaRemote itself" mandate
  CONTEXT.md restates from CLAUDE.md. All position data must come from the ALREADY-
  STREAMING `onTrackInfoReceived` snapshots; the local timer only interpolates, it never
  re-fetches.
- **Computing "now minus timestamp" math inside the SwiftUI view body directly on raw
  micros:** breaks the pure-seam/`@Published`-model/thin-glue layering this codebase
  enforces everywhere else (see `NowPlayingPresentation.swift`'s explicit "do not compute
  elapsed-time-now math inside the view" note already present in CONTEXT.md's Established
  Patterns section). Put the pure formula in `NowPlayingPresentation.swift`, not in
  `NotchPillView.swift`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Drift-corrected elapsed-time extrapolation | A custom "now minus lastUpdate" clock formula derived from scratch | Port the vendored `currentElapsedTime` formula verbatim into the pure seam | Already correct, already handles the paused-freeze edge case, already accounts for `playbackRate` (covers non-1.0x playback rates some apps report) — re-deriving it independently risks subtly diverging (e.g. forgetting the `isPlaying != true` early-return) |
| A continuous animation clock | `Timer`, `CADisplayLink`-style manual loop, or a Combine `Timer.publish` | `TimelineView(.animation(paused:))` | Zero new concepts vs. the existing `EqualizerBars`; already proven idle-CPU-safe on-device per that component's own code comments |
| `m:ss` time formatting | Manual string interpolation with off-by-one/negative-time edge cases | A small pure helper (either hand-rolled `String(format:)` or Foundation's `DateComponentsFormatter`) | Small enough that either is fine; just don't scatter formatting logic across multiple call sites — one function, one place |

**Key insight:** Every piece of this phase has a same-codebase or same-package precedent
already implemented and working. There is no genuinely novel technical risk here — the
work is disciplined plumbing through an established layering, not new integration
surface.

## Common Pitfalls

### Pitfall 1: Forgetting the `isPlaying != true` early-return when porting the formula

**What goes wrong:** A naive port might always compute `elapsedSeconds + (now -
timestampSeconds) * rate`, even while paused. If `rate` happens to be non-zero while
paused (some apps may not zero it), or if `timestampSeconds` is stale, this would make the
bar silently creep while paused — directly violating success criterion 3.
**Why it happens:** The formula looks like one continuous expression at first glance;
easy to miss that the vendored source special-cases the paused branch.
**How to avoid:** Copy the vendored `if isPlaying != true { return elapsedSeconds }` guard
verbatim (see Code Examples Pattern 2) — do not "simplify" by assuming `rate == 0` while
paused is a safe substitute.
**Warning signs:** On-device UAT: pause a track, wait 10+ seconds, confirm the bar/labels
have not moved at all.

### Pitfall 2: `expandedSize` height change breaking the "no cramping" constraint (D-06)

**What goes wrong:** If the new row is inserted without growing `expandedSize.height` by a
matching amount, SwiftUI's fixed-frame `.overlay` content will either clip or force
existing rows to compress to fit — directly violating D-06's "existing spacing elsewhere
is NOT compressed."
**Why it happens:** The content `VStack` sits inside a `.frame(width:height:)` sized to
`Self.expandedSize` — that frame does not auto-grow to fit its content; the constant must
be bumped explicitly and in sync with padding-math.
**How to avoid:** Update `expandedSize.height`'s arithmetic comment (128 → new total)
BEFORE writing the new row's height into the `VStack`, matching the existing
"32 (clearance) + 84 (content) + 12 (bottom inset)" bookkeeping style so future contributors
can audit it the same way. Re-verify on-device that no visual clipping/compression occurs
at the new size.
**Warning signs:** Title/artist text truncating differently than before, transport buttons
shifting vertically, or the bottom rounded-corner curve looking cramped against the
control row.

### Pitfall 3: A second hard-coded height constant drifting out of sync

**What goes wrong:** `NotchPillView.expandedSize`'s own comment states the panel window
frame ALSO derives from this value ("The panel window (expandedNotchFrame) and the
SwiftUI content frame both derive from THIS one value") — but this needs to be verified,
not assumed, since a second, independently-hardcoded height in `NotchWindowController`/
`NotchGeometry` would silently desync the window's clickable/visible bounds from the
content.
**Why it happens:** Multiple `NotchGeometry`/window-sizing call sites existed historically
in this project (see Phase 2 commit history), so a stale duplicate constant is plausible
even if the current code claims single-sourcing.
**How to avoid:** `grep -rn "expandedSize" Islet/` during planning/implementation to
enumerate every consumer before changing the constant, confirming there is genuinely one
source of truth today.
**Warning signs:** The black island's visible frame does not match its actual hit-testable
window bounds after the height change (clicks land outside the visible shape, or vice
versa).

### Pitfall 4: Reintroducing polling or a second MediaRemote hop

**What goes wrong:** A "just fetch the latest position on a timer tick" instinct is
natural for continuous UI, but calling `controller.getTrackInfo` (the ONE-SHOT variant)
repeatedly would re-spawn the perl bridge child process per call — the exact anti-pattern
`NowPlayingMonitor.swift`'s own header comment (A1) explicitly forbids ("`getTrackInfo` is
the ONE-SHOT ... used ONLY for the launch health probe, NEVER for live updates").
**Why it happens:** Conflating "I need continuous position data" with "I need to keep
asking MediaRemote for it" — the correct model is "I already have it, I just need to
extrapolate locally between pushes."
**How to avoid:** The local `TimelineView` must ONLY read already-published `NowPlayingState`
fields (last snapshot's elapsed/timestamp/rate) — it must never call into
`NowPlayingMonitor`/`MediaController` at all.
**Warning signs:** Any new code path that calls `nowPlayingMonitor?.getTrackInfo` or
similar from the view/timer layer is a red flag during code review.

### Pitfall 5: Missing/nil duration or elapsed data (defensive display)

**What goes wrong:** `durationMicros`/`elapsedTimeMicros`/`timestampEpochMicros` are all
`Double?` in the vendored `Payload` (confirmed from source) — some players/edge cases
(track just changed, adapter mid-update) may report nil for one or more. A crash-free but
UNGUARDED display (e.g. force-unwrapping, or dividing by a nil/zero duration) would break
the bar or produce garbage ("NaN%" width, division-by-zero).
**Why it happens:** The existing `TrackSnapshot` fields are already optional-safe (title/
artist/isPlaying are handled with nil-coalescing/guards) — the new fields need the SAME
discipline, but it's easy to assume "if we're already `.playing`, duration must be
present."
**How to avoid:** Design the extended `TrackSnapshot`/presentation payload so a nil
duration or elapsed value renders the row in some defined, tested fallback state (e.g. bar
hidden, or a 0-width bar with "--:-- / --:--" labels) — decide this explicitly during
planning rather than leaving it to runtime discovery. Unit-test this branch in the pure
seam the same way `testNoTitleMapsToNone` covers the analogous title case today.
**Warning signs:** A crash or a visibly broken bar (100% width, or NaN-derived layout) the
first time a player reports incomplete metadata (this WILL happen in practice — album art
is already documented as sometimes arriving a beat late; duration/timestamp could
plausibly do the same).

## Code Examples

### Existing continuous-animation gate to mirror (EqualizerBars, full context)

```swift
// Source: Islet/Notch/NotchPillView.swift, lines 519-537 (existing, unmodified)
// TIME-DRIVEN (not @State-driven) so the loop is IMMUNE to ambient withAnimation(.spring)
// transactions... TimelineView(.animation, paused: !isPlaying) ticks each frame while
// playing and STOPS entirely when paused (no clock → idle CPU ~0, D-04 / Pitfall 5).
var body: some View {
    TimelineView(.animation(paused: !isPlaying)) { context in
        let t = context.date.timeIntervalSinceReferenceDate
        // ... render using `t` ...
    }
}
```

### Vendored drift-correction formula (source-verified, to be ported into the pure seam)

See Architecture Patterns → Pattern 2 above for the full verbatim source and the exact
paused-state guard that must be preserved.

### Existing accent-consumption pattern to copy for the bar's fill color

```swift
// Source: Islet/Notch/NotchPillView.swift, line 51 and line 401 (existing, unmodified)
@Environment(\.activityAccent) private var accent
// ...
EqualizerBars(isPlaying: isPlaying, tint: accent)   // D-11 accent on the bars
```
The new progress bar's filled `Capsule` should read this SAME `accent` environment value
(D-03) — no new plumbing needed, it is already available inside `mediaExpanded`.

### D-09 insertion point (exact current code to replace)

```swift
// Source: Islet/Notch/NotchPillView.swift, line 411 (existing, TO BE REPLACED per D-06)
// D-09: reserved vertical room for the future seek bar (NOT built — NOW-04 v2).
Spacer(minLength: 0).frame(height: 4)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|---------------|--------|
| Direct `dlopen`/`MRMediaRemoteGetNowPlayingInfo` for Now Playing data | `mediaremote-adapter` perl-bridge (already adopted, Phase 4) | Broke macOS 15.3/15.4; already migrated | N/A — this phase inherits the already-correct approach, no further migration needed |
| 4pt placeholder spacer for a "future seek bar" (D-09, Phase 4) | Real bar+labels row (this phase) | This phase (7) | Direct scope of this phase — closes out the D-09 placeholder |

**Deprecated/outdated:** None specific to this phase's scope — the vendored dependency's
API surface used here (`durationMicros`/`elapsedTimeMicros`/`timestampEpochMicros`/
`playbackRate`/`currentElapsedTime`) is current as of the pinned commit and was directly
read from source this session, not from possibly-stale training data.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The paused-freeze behavior is fully satisfied by porting the vendored formula's `isPlaying != true` branch + gating the `TimelineView` on `isPlaying` — no additional explicit "freeze" state is needed | Code Examples / Pitfall 1 | Low — if wrong, on-device UAT (pause + wait) would immediately reveal drift; cheap to catch and fix |
| A2 | `Self.expandedSize` is genuinely the single source of truth for the panel window frame (per its own code comment) with no second hard-coded height elsewhere | Architecture Patterns Pattern 3 / Pitfall 3 | Medium — if a second constant exists and isn't updated in sync, the visible island and its hit-testable window bounds could desync after the height change; mitigated by the explicit grep instruction in Pitfall 3 |
| A3 | A hand-rolled `m:ss` formatter (vs. `DateComponentsFormatter`) is the right call for this codebase's stated "avoid unnecessary complexity for a first-time programmer" constraint | Standard Stack / Alternatives Considered | Low — purely a style choice; either works correctly, no functional risk |

**A1-A3 are all low-to-medium risk implementation-detail assumptions, not requirements or
compliance judgment calls** — none of the CONTEXT.md-locked decisions (D-01 through D-07)
are themselves assumed; they were all copied verbatim from user decisions and separately
corroborated against source code (e.g. D-07's technical basis was independently confirmed
by reading the actual vendored `TrackInfo.swift`, not just trusted from CONTEXT.md's
prose).

## Open Questions

1. **Exact new `expandedSize.height` value**
   - What we know: current is 128 (32 clearance + 84 content + 12 bottom inset); D-06
     wants "~16-20pt" growth; the D-09 spacer being replaced is only 4pt, so the NEW row's
     total height (bar + labels + its own vertical spacing) minus the 4pt already
     accounted for determines the exact delta.
   - What's unclear: the exact pixel height of the bar (2-3pt per D-04) + its label row
     (font-driven, likely ~14-16pt) + any spacing above/below it — this determines whether
     the final growth is closer to 16pt or 20pt.
   - Recommendation: the planner/executor should pick a concrete bar height (e.g. 3pt) and
     label font size (matching the existing 12pt artist-text size per D-05), sum the exact
     row height, and compute `expandedSize.height` precisely rather than eyeballing it —
     then verify on-device that no clipping/cramping occurs (Pitfall 2).

2. **Nil-duration/nil-elapsed fallback rendering**
   - What we know: the fields are optional in the vendored payload (Pitfall 5); the
     existing codebase has a consistent "fail safe to a defined fallback" discipline for
     other optional fields (e.g. nil artist → "").
   - What's unclear: CONTEXT.md doesn't explicitly specify what the bar should show when
     duration/elapsed are unavailable but title/artist ARE present (e.g. a player that
     doesn't report timing) — this is a genuine gap, not covered by any locked decision or
     Claude's-discretion note.
   - Recommendation: flag this for the planner to make an explicit (even if small) design
     call — e.g. "hide the bar entirely, keep just title/artist/controls" vs. "show
     '--:-- / --:--' with a 0-width bar" — and write a corresponding unit test in the pure
     seam, following the existing `testNoTitleMapsToNone`-style convention.

## Environment Availability

Skipped — this phase has no new external tool/service/runtime dependencies. The only
dependency (MediaRemoteAdapter, Xcode 16+, macOS 14+ SDK) is already installed and proven
working from Phase 4; nothing new to probe.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | XCTest (existing — `IsletTests` target) |
| Config file | Xcode project (`project.yml` → xcodegen-generated `.xcodeproj`), no separate test config file |
| Quick run command | `xcodebuild test -scheme Islet -destination 'platform=macOS' -only-testing:IsletTests/NowPlayingPresentationTests` |
| Full suite command | `xcodebuild test -scheme Islet -destination 'platform=macOS'` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PBAR-01 | Extended `TrackSnapshot`/presentation carries duration/elapsed/timestamp/rate correctly; pure elapsed-time formula matches vendored math, including the paused-freeze branch | unit | `xcodebuild test -scheme Islet -only-testing:IsletTests/NowPlayingPresentationTests` | ✅ (extend existing file) |
| PBAR-01 | Nil-duration/nil-elapsed fallback behaves per the Open Question 2 decision | unit | same command, new test case | ✅ (extend existing file) |
| PBAR-01 | Bar visually renders correctly, updates smoothly while playing, freezes while paused, does not respond to clicks/drags, expanded island doesn't clip/cramp | manual-only | on-device UAT — SwiftUI `TimelineView` continuous-render behavior and real MediaRemote timing data are not practically unit-testable | — (manual UAT, no automation gap to close) |

Manual-only justification: the continuous animation's real-world smoothness, the
paused-freeze visual confirmation, and the layout's on-device fit against the actual
physical notch geometry (per the codebase's own established precedent — Phase 2's
fullscreen detection, Phase 4's artwork latency, Phase 6's on-device tuning) all require a
running app on real hardware with a real Spotify/Apple Music session. This mirrors every
prior phase's validation split in this project: pure logic is unit-tested, MediaRemote/
UI-timing/on-device-geometry behavior is verified via UAT.

### Sampling Rate

- **Per task commit:** `xcodebuild test -scheme Islet -only-testing:IsletTests/NowPlayingPresentationTests`
- **Per wave merge:** `xcodebuild test -scheme Islet -destination 'platform=macOS'` (full suite)
- **Phase gate:** Full suite green + on-device UAT (bar smoothness, paused-freeze, no
  cramping, no click/drag response) before `/gsd:verify-work`

### Wave 0 Gaps

None — `IsletTests/NowPlayingPresentationTests.swift` already exists and is the correct
extension point; no new test file or fixture infrastructure is needed. New test methods
should be added to this existing file following its established naming/structure
convention (see Code Examples in this file's own read-through above).

## Project Constraints (from CLAUDE.md)

- **Isolation mandate:** "isolate all now-playing code behind one Swift protocol/service
  so swapping the implementation is a one-file change" — `NowPlayingMonitor.swift` remains
  the ONLY file importing `MediaRemoteAdapter`; the new fields must be lifted there and
  nowhere else touches the vendored types directly.
- **No polling MediaRemote** — confirmed compatible; this phase adds zero new IPC calls,
  only reads already-streamed data more fully.
- **Swift 5 language mode** (not strict Swift 6 concurrency) — no new actor-isolation
  concerns introduced by this phase; `TimelineView` and the pure-seam extension are
  ordinary value-type/SwiftUI code, no concurrency surface added.
- **Avoid unnecessary complexity / no speculative abstraction** — informs the "hand-rolled
  `m:ss` formatter over `DateComponentsFormatter`" recommendation and "no new Timer/Combine
  pattern" recommendation above.
- **GSD workflow enforcement** — this research feeds `/gsd:plan-phase`; no direct
  implementation happens in this research pass.

## Sources

### Primary (HIGH confidence)

- On-device source read: `Islet/Notch/NowPlayingPresentation.swift`,
  `Islet/Notch/NowPlayingState.swift`, `Islet/Notch/NowPlayingMonitor.swift`,
  `Islet/Notch/NotchPillView.swift`, `Islet/Notch/IslandResolver.swift`,
  `IsletTests/NowPlayingPresentationTests.swift`, `Islet/Notch/NotchInteractionState.swift`
  — all read directly this session, current repo state.
- On-device source read: `/Users/lippi304/Library/Developer/Xcode/DerivedData/
  Islet-dnqqxjhrqzcdrvcmdlvlqorickdh/SourcePackages/checkouts/mediaremote-adapter/
  Sources/MediaRemoteAdapter/TrackInfo.swift` — the vendored dependency's actual source,
  confirmed via `git rev-parse HEAD` == `cf30c4f1af29b5829d859f088f8dbdf12611a046`
  (matches `project.yml`'s pinned `revision:` exactly).
- `project.yml` (repo root) — confirmed the exact pinned commit and `embed: true` /
  `codeSign: true` package settings, unchanged by this phase.
- `.planning/phases/07-now-playing-progress-bar/07-CONTEXT.md`,
  `.planning/REQUIREMENTS.md`, `.planning/STATE.md`, `.planning/ROADMAP.md` — project
  planning artifacts, read directly this session.

### Secondary (MEDIUM confidence)

None needed — every claim in this research was either read directly from source (HIGH) or
copied verbatim from CONTEXT.md's locked user decisions (also HIGH, by definition of
"locked").

### Tertiary (LOW confidence)

None.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new dependencies; existing `TimelineView` pattern
  source-verified in the codebase itself.
- Architecture: HIGH — every integration point (pure seam, `@Published` model, monitor
  glue, view layout, `matchedGeometryEffect` sizing) was read directly from current source,
  not inferred or recalled from training data.
- Pitfalls: HIGH — all five pitfalls are either directly sourced from reading the vendored
  formula's exact branching logic, or derived from the codebase's own documented prior
  incidents (idle-CPU discipline, artwork-latency precedent, isolation mandate).

**Research date:** 2026-07-04
**Valid until:** 30 days (stable — no new external dependency, all logic already
source-verified against the pinned vendored commit; the only volatility risk is if the
vendored `mediaremote-adapter` pin itself changes before planning starts, which is
independently tracked as a standing project blocker, not specific to this phase)
</content>
