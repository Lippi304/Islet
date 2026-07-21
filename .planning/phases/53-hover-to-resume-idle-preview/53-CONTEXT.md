# Phase 53: Hover-to-Resume Idle Preview - Context

**Gathered:** 2026-07-21
**Status:** Ready for planning

<domain>
## Phase Boundary

When the collapsed island is idle (nothing currently playing) but at least one track has played since Islet launched, hovering it previews that last-played track — album art left, equalizer bars right, the same visual as the live Now Playing collapsed glance — and clicking resumes it. Before anything has played this session, hovering the idle island stays unchanged (no preview). Extends the existing collapsed hover/Now-Playing wings visual (`NowPlayingMonitor`, `NotchPillView` wings) and reuses the Phase 42 secondary-bubble hover-reveals/tap-toggles interaction pattern — no new tabs, no new persistence, no new data model.

</domain>

<decisions>
## Implementation Decisions

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

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Roadmap & requirements
- `.planning/ROADMAP.md` §"Phase 53: Hover-to-Resume Idle Preview" (~line 892) — goal, 4 success criteria (SC#4 locks the failure-feedback requirement), "Depends on: Nothing" framing
- `.planning/REQUIREMENTS.md` (RESUME-01, RESUME-02, lines 88-89, 165) — the two locked requirements this phase satisfies
- `.planning/PROJECT.md` (lines 94-107, "Current Milestone: v1.8") — milestone goal; explicitly flags "resuming a past track depends on what MediaRemote/the adapter actually supports outside an active session — worth a quick technical check during phase planning rather than assumed"

### Prior phase precedent this phase builds on
- `.planning/phases/42-dual-activity-display/42-CONTEXT.md` (if present) or `PROJECT.md`'s Phase 42 entry — the secondary-bubble hover-reveals/tap-toggles-playback pattern (`.onHover` darkens + reveals glyph, tap calls `togglePlayPause()` directly) this phase's D-01/D-02 reuse verbatim
- Phase 30 (HOME-02) — established `NowPlayingState.lastKnownTrack` as the session-only "sticky last-played" data contract this phase reuses directly, no new state needed
- Phase 4 (NOW-03) — established the "Now Playing nicht verfügbar" inline-text health-state pattern D-03's failure feedback mirrors

### Existing code (unmodified architecture this phase extends)
- `Islet/Notch/NowPlayingState.swift` — `lastKnownTrack: LastPlayedTrack?` (title/artist/artwork, session-only, overwritten on every new `.playing` track, never persisted) — the exact data source for the preview
- `Islet/Notch/NowPlayingMonitor.swift` — `NowPlayingService` protocol: `togglePlayPause()`, `nextTrack()`, `previousTrack()` — the only transport surface available; no `play(track:)`/resume-specific method exists today, which is the open technical question above
- `Islet/Notch/NowPlayingPresentation.swift` — `NowPlayingPresentation` enum (`.playing`/`.paused`/`.none`) and `nowPlayingPresentation(from:)` — pure classification seam, likely untouched (the preview branches off `lastKnownTrack` + hover state, not a new presentation case)
- `Islet/Notch/IslandResolver.swift` — `IslandPresentation` enum (~line 61): `.idle`, `.nowPlayingWings(NowPlayingPresentation)`, `.homeLastPlayed` already exist; this phase's hover-preview is a NEW collapsed-state behavior distinct from all of these (currently `.idle` renders nothing regardless of hover — only the general D-02 Alcove bounce-affordance fires)
- `Islet/Notch/NotchPillView.swift` — `secondaryBubble(_:)` (~line 2885) and `isSecondaryBubbleHovering` (~line 2883) — the exact `.onHover`/tap-to-toggle pattern to mirror; wings-rendering code for the active Now Playing glance (album art left / equalizer right) is the visual to reuse for the preview
- `Islet/Notch/NotchWindowController.swift` — existing ~0.4s pointer-away grace-collapse timer (D-04 reuses verbatim); `nowPlayingMonitor?.togglePlayPause()` already wired at line ~1704 as the exact call this phase's click handler reuses

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `NowPlayingState.lastKnownTrack` — ready-made data source, zero new state/persistence needed (Phase 30 already built exactly what this phase needs).
- `NowPlayingMonitor.togglePlayPause()` — the resume action; already the same call the transport row and Phase 42 bubble both use.
- `secondaryBubble(_:)`'s `.onHover`/tap pattern (`NotchPillView.swift` ~2883-2916) — direct precedent for hover-state + tap-to-toggle wiring.
- The active `nowPlayingWings` visual (album art left, equalizer right) — same rendering to reuse for the preview, not a new layout.

### Established Patterns
- Phase 4/NOW-03's inline-text health-state pattern ("Now Playing nicht verfügbar") — D-03's failure feedback follows this exact precedent rather than inventing a new visual language.
- This project's "spike/verify the technical unknown early" convention (Phase 22/24 drag-in, Phase 38/39 undocumented-API spikes, Phase 49 Favorite/Like) — the resume-feasibility question should be checked early in planning/research, not assumed.

### Integration Points
- `Islet/Notch/NotchPillView.swift` — new hover-preview rendering branch for the collapsed idle state, gated on `lastKnownTrack != nil` and hover state.
- `Islet/Notch/NotchWindowController.swift` — click handler wiring (reuse the existing `togglePlayPause()` call site), grace-timer reuse (D-04).

</code_context>

<specifics>
## Specific Ideas

No specific visual references given — the preview reuses the existing active Now Playing wings visual verbatim (album art left, equalizer right), per ROADMAP SC#1's explicit "same visual as the active Now Playing view" framing.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

### Reviewed Todos (not folded)
- **Calendar month-grid polish** (`.planning/todos/pending/2026-07-19-calendar-month-grid-polish.md`) — matched by generic keyword scoring (hover/phase), not actually related to hover-to-resume; skipped.
- **Island briefly disappears during click-through** (`.planning/todos/pending/2026-07-19-island-briefly-disappears-during-click-through.md`) — matched by generic keyword scoring (island/click/phase), unrelated; skipped.
- **Quick Action disabled state has no controller gate** (`.planning/todos/pending/2026-07-19-quick-action-disabled-state-has-no-controller-gate.md`) — matched by generic keyword scoring, unrelated; skipped.

</deferred>

---

*Phase: 53-hover-to-resume-idle-preview*
*Context gathered: 2026-07-21*
