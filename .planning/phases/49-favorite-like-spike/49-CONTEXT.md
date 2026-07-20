# Phase 49: Favorite/Like — Spike - Context

**Gathered:** 2026-07-20
**Status:** Ready for planning

<domain>
## Phase Boundary

Resolve this milestone's three genuine, undocumented/policy-gated unknowns before any Favorite/Like UI is planned in detail: Apple Music `current track`/`loved` reliability, Spotify OAuth/quota-mode reality, and the Automation (TCC) permission-prompt bug. No UI is built this phase — the output is a documented go/no-go scope decision that Phase 50 (implementation) reads to know exactly what to build (read/write, write-only, or Apple-Music-only). Shares no code path with the Audio Output Switcher work (Phases 47-48).

</domain>

<decisions>
## Implementation Decisions

### Spotify Developer account setup
- **D-01:** No Spotify Developer app/Client ID exists yet — registering one (developer.spotify.com, setting redirect URI for PKCE) is the spike's own first step, not a pre-existing asset. Budget spike time for this.
- **D-02:** A usable Spotify account (Premium or regular) is available for exercising the real OAuth PKCE round-trip and the real `PUT` Save-Track call — Success Criterion #3 is testable once D-01's app is registered.

### Spotify quota-wall fallback scope
- **D-03:** If the spike confirms the 5-user Development Mode cap with no realistic Extended Quota path, the accepted fallback for this milestone is: ship Spotify OAuth for a small, manually-approved allowlist — matching REQUIREMENTS.md's FAV-02 as already written. Do NOT descope to Apple-Music-only or switch to bring-your-own-Client-ID as the default plan.
- **D-04:** The 5-user cap is only acceptable if Phase 50's implementation doesn't paint itself into a corner — the design should leave room to later add Extended Quota approval or a bring-your-own-Client-ID option without a rewrite (e.g., don't hardcode a single shared Client ID so deep that swapping the auth source later requires touching every call site). This is a forward-compatibility note for Phase 50's planner, not a Phase 49 deliverable.

### Apple Music test-library coverage
- **D-05:** Both local-library tracks and streaming-only (not-yet-added) tracks are available on the dev machine — Success Criterion #2's library/streaming-only/play-pause matrix is fully testable on real hardware, no gaps to flag.

### Automation (TCC) bug reproduction depth
- **D-06:** Reproduce or rule out the Automation-permission prompt bug against Music.app only (the app that ships first via Apple Music write-back) — not a full Music.app + Spotify + idle/backgrounded matrix. Enough to inform Phase 50's FAV-03 error-handling design; Spotify's own unknowns (D-01..D-04) are the bigger risk already covered elsewhere in this spike.

### Claude's Discretion
- Exact spike execution order (Apple Music `loved` testing vs. Spotify OAuth registration vs. TCC repro) — not raised during discussion, sequence for fastest signal on the highest-risk unknown first (Spotify, per research/SUMMARY.md's own risk framing).
- Where the go/no-go decision gets documented (dedicated findings doc vs. Phase 50's CONTEXT.md decisions) — follow this project's existing spike/sketch wrap-up convention if applicable at planning time.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Roadmap & requirements
- `.planning/ROADMAP.md` (Phase 49 entry, lines 791-803) — goal, 4 success criteria, no hard dependency on Phases 47-48
- `.planning/REQUIREMENTS.md` (lines 61-63, 139-141) — FAV-01..03 full text; FAV-02 already assumes the small-allowlist fallback this discussion confirmed (D-03)

### Research (already covers this phase's risk analysis in detail)
- `.planning/research/SUMMARY.md` — "Phase 3: Favorite/Like — Spike" section (lines 82-97), overall risk framing (lines 6-14), Key Unknowns (lines 123-124)
- `.planning/research/STACK.md` — Spotify Web API endpoint shapes (`PUT /me/library`, post-Feb-2026 migration), `NSAppleScript` pattern for `loved`/Spotify track URI
- `.planning/research/PITFALLS.md` — Pitfall 1 (Spotify quota wall), Pitfall 2 (Apple Music `current track` failure), Pitfall 3 (Automation TCC bug) — all three require on-device verification, directly scoped by this spike
- `.planning/research/FEATURES.md` — favorite/like mechanics, MVP definition

### Existing code to reference (not modified this phase — spike only)
- `Islet/Notch/NowPlayingMonitor.swift` — the ONLY file that imports `MediaRemoteAdapter`; a future `toggleFavorite()`/`isFavorite` addition (Phase 50) extends this same protocol/bridge per research's recommendation, not a new isolated seam
- `Islet/Notch/NowPlayingState.swift`, `Islet/Notch/NowPlayingPresentation.swift` — existing Now Playing seam/state, unmodified this phase

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `NowPlayingMonitor.swift`'s existing MediaRemote isolation pattern (one file, protocol-typed, `start()`/`stop()` lifecycle) — Phase 50 extends this rather than building a new isolated bridge, per research/SUMMARY.md's own recommendation (favorite is "2-3 lines added to the existing seam", not a second protocol)

### Established Patterns
- This project's own spike-first precedent (Phase 22 drag-in, Phase 38/39 undocumented-API spikes) — resolve genuinely unverifiable-from-docs unknowns on real hardware before UI planning, exactly what this phase does

### Integration Points
- None this phase — spike produces no code changes to `NotchWindowController`/`NotchPillView`; Phase 50 does all UI wiring once this spike's go/no-go is recorded

</code_context>

<specifics>
## Specific Ideas

No specific UI/visual requirements — this is a spike phase, no UI surface exists yet. The concrete constraints are the six decisions above (D-01..D-06): Spotify app registration is a spike prerequisite, a small-allowlist Spotify launch is the accepted fallback scope (with forward-compatibility left open for later), both Apple Music library states are testable, and Automation-TCC reproduction stays scoped to Music.app only.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope (spike execution readiness and scope decisions for the already-scoped Favorite/Like unknowns).

### Reviewed Todos (not folded)
- **Calendar month-grid polish (arrows, day numbers, event hover/edit)** — UI todo, unrelated to this spike's scope.
- **Quick Action disabled state has no controller gate** — UI/state todo, unrelated to this phase's scope.
- **Island briefly disappears during click-through** — UI/click-through todo, unrelated to this phase's scope.

</deferred>

---

*Phase: 49-Favorite/Like — Spike*
*Context gathered: 2026-07-20*
