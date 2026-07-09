# Phase 17: Now Playing Launch Gating - Context

**Gathered:** 2026-07-09
**Status:** Ready for planning

<domain>
## Phase Boundary

Islet must not auto-show the collapsed Now Playing "wings" glance for a track that is only
paused/loaded — the glance should appear only once the user has actually started playback
(observed `isPlaying == true`) at least once during the current Islet run. A track that is
already actively playing when Islet launches is unaffected (shows immediately, no regression).
This is purely a gating condition on when the ambient glance is allowed to show; it does not
change the Now Playing classification logic, transport controls, or the existing paused-timeout
auto-dismiss behavior for later mid-session pauses.

</domain>

<decisions>
## Implementation Decisions

### Gate scope — what counts as "hasn't played yet"
- **D-01:** The gate is keyed on "has any `.playing` presentation been observed since Islet
  launched" — not literally "the first snapshot received." If Islet launches with no track at
  all (`.none`), and the user later opens Spotify/Music with a paused track *before* ever
  pressing Play, that paused track is still gated (no glance) until a real Play happens.
- **D-02:** Once `.playing` has been observed once, the gate is lifted permanently for the rest
  of the Islet session. It never re-arms — quitting the player app, switching between Spotify
  and Apple Music, or the presentation dropping back to `.none` and later returning to `.paused`
  does not re-trigger the gate. This is an in-memory flag scoped to the Islet process lifetime
  (not persisted across Islet relaunches — each Islet launch starts gated again).

### Gate surface — ambient glance only, not manual expand
- **D-03:** The gate only suppresses the ambient auto-show (the collapsed "wings" glance driven
  by `resolve()`'s non-expanded branch in `IslandResolver.swift`). If the user manually clicks
  to expand the notch while still gated, the expanded Now Playing card (with title/artist/
  controls) shows normally — a deliberate user action to look should reveal the real state, gating
  is only about what auto-appears without being asked.

### Claude's Discretion
- Exact mechanism/location for tracking "has played since launch" (e.g., a new flag on
  `NotchWindowController` or `NowPlayingState`, checked in `handleNowPlaying`/`resolve`) is an
  implementation detail for planning/research, not decided here.
- Whether the flag lives on the controller vs. is threaded through `IslandResolver.resolve(...)`
  as an extra parameter (mirroring the existing `nowPlayingHealthGate` pattern) is left to
  research/planning to pick the analog that fits best.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements & Roadmap
- `.planning/REQUIREMENTS.md` — NOW-04 (this phase's sole requirement)
- `.planning/ROADMAP.md` — Phase 17 entry (goal, success criteria, depends on Phase 16)

### Core files this phase touches
- `Islet/Notch/IslandResolver.swift` — the pure `resolve(...)` reducer; the `if nowPlaying !=
  .none { return .nowPlayingWings(nowPlaying) }` branch (non-expanded case) is where the gate
  must apply. `nowPlayingHealthGate(enabled:isHealthy:)` in the same file is the existing analog
  for "gate a presentation input before it reaches the resolver."
- `Islet/Notch/NowPlayingPresentation.swift` — pure classification (`nowPlayingPresentation`,
  `TrackSnapshot`, `NowPlayingPresentation` enum: `.playing`/`.paused`/`.none`). No changes to
  the classification itself expected — the gate is a separate, additional condition.
- `Islet/Notch/NowPlayingState.swift` — the `@Published` model (`presentation`, `isHealthy`,
  `position`) that could host a new "has played since launch" flag.
- `Islet/Notch/NotchWindowController.swift` — `handleNowPlaying(_:_:)` (~line 944) is where every
  live snapshot lands and `renderPresentation()`/`resolve(...)` get called; also owns the
  existing D-06/D-07 paused-timeout auto-dismiss (`scheduleMediaDismiss`, `pausedTimeout`) which
  is unaffected by this phase.

No external ADR/SPEC docs exist for this phase — NOW-04 in REQUIREMENTS.md and the ROADMAP.md
Phase 17 entry are the full requirement source.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `nowPlayingHealthGate(enabled: Bool, isHealthy: Bool) -> Bool` in `IslandResolver.swift` is the
  direct precedent for this phase's gate: a pure, total function that neutralizes one input to
  `resolve(...)` based on a boolean condition, keeping `resolve(...)` itself simple. The launch
  gate should likely follow the same shape (a pure helper feeding a boolean/derived presentation
  into `resolve`), tested the same way (`IslandResolverTests`-style, per Phase 6/16 precedent of
  unit-testing pure seams in milliseconds).

### Established Patterns
- Pure-seam discipline: classification/resolution logic (`NowPlayingPresentation.swift`,
  `IslandResolver.swift`) is Foundation-only and unit-tested; MediaRemote glue
  (`NowPlayingMonitor.swift`) and controller wiring (`NotchWindowController.swift`) are the
  `@MainActor` layers verified on-device. A new "has played since launch" flag should follow
  this split — the gating *decision* as a pure function, the flag *storage* on the `@MainActor`
  state.
- D-11/D-12 orthogonality precedent (`NowPlayingPresentation.swift` header): keep new axes
  (like "has played this session") separate from the existing `.playing`/`.paused`/`.none`
  classification enum, mirroring how `isHealthy` is already kept orthogonal to `presentation`.

### Integration Points
- `handleNowPlaying(_:_:)` in `NotchWindowController.swift` is the single site every live
  snapshot passes through — the natural place to flip a "has played" flag to `true` the first
  time `p` is `.playing`.
- `resolve(...)` in `IslandResolver.swift` is the single arbiter (D-05) all presentation state
  flows through before rendering — the natural place to apply the gate to the non-expanded
  branch only (per D-03 above), leaving the `isExpanded` branch untouched.

</code_context>

<specifics>
## Specific Ideas

No specific UI/visual requests — this phase is pure behavioral gating, no new UI surface.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope. (Phase 18's song-change toast is already tracked
separately in ROADMAP.md and depends on this phase.)

</deferred>

---

*Phase: 17-Now Playing Launch Gating*
*Context gathered: 2026-07-09*
