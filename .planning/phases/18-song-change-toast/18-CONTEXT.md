# Phase 18: Song-Change Toast - Context

**Gathered:** 2026-07-09
**Status:** Ready for planning

<domain>
## Phase Boundary

When Now Playing's title+artist genuinely changes (not the first track detected after Islet
launch, not a pause/resume/scrub of the same track), the island briefly expands downward to
show the new track as a toast, then collapses back to the compact ambient glance after ~3s.
Users can turn this toast off in Settings' Activities tab without affecting the underlying Now
Playing glance, controls, or classification — this phase only adds a transient visual cue on top
of the existing ambient Now Playing state.

</domain>

<decisions>
## Implementation Decisions

### Toast content
- **D-01:** The toast shows both title and artist (not title-only), e.g. "Blinding Lights —
  The Weeknd". Exact layout (one line vs two, styling) is a UI-phase decision — this only locks
  that both fields are present.

### Priority vs Charging/Device transients
- **D-02:** If a genuine song change happens while a charging or device splash is currently
  showing (the two existing `ActiveTransient` kinds, ranked above Now Playing per D-02 in
  `IslandResolver.swift`), the toast for that change is skipped entirely — not queued, not
  shown afterward. Charging/device splashes already outrank the ambient Now Playing branch in
  `resolve(...)`, so this is the natural behavior if the toast is implemented as another
  ambient-gated state rather than a new `ActiveTransient`/`TransientQueue` participant — no new
  queueing logic needed.

### Rapid track skips
- **D-03:** If the user skips through several songs quickly, each new genuine change replaces
  the toast's content and restarts the ~3s timer — only the final settled track gets a full 3s
  display. No toast pile-up, no queue of pending toasts. This mirrors `TransientQueue`'s
  `updateHead()` in-place-refresh precedent (used today for charging-percent ticks) even though
  the toast itself isn't going through `TransientQueue`.

### Manual-expand interaction
- **D-04:** If the notch is already manually expanded (showing the full Now Playing card) when
  a genuine song change happens, the toast is suppressed — the expanded card already reflects
  the new title/artist live, so a toast on top would be redundant. This mirrors Phase 17's D-03
  precedent: the toast, like the launch gate, only applies to the ambient/collapsed branch of
  `resolve(...)`; the `isExpanded` branch is untouched.

### Claude's Discretion
- Exact mechanism for detecting a "genuine" title+artist change: `isSameTrack(_:_:)` in
  `NowPlayingPresentation.swift` already exists for this purpose (true only when both sides have
  non-nil title/artist pairs AND those pairs are equal; a play↔pause transition on the same
  track is "same track", a title/artist change or a transition to/from `.none` is not). Whether
  the toast reuses this exact function or a close variant is left to research/planning.
- Whether the toast is modeled as a new `IslandPresentation` case, a sub-state carried alongside
  `.nowPlayingWings`, or a separate `@Published` flag read by the view layer is an implementation
  detail for planning/research to decide, informed by D-02 above (it must NOT participate in
  `ActiveTransient`/`TransientQueue`, since D-02 requires it to be silently skippable rather than
  queued).
- Exact toast dismiss/timer mechanism (Timer vs scheduled dispatch) — should follow the existing
  precedent of `NotchWindowController`'s `scheduleMediaDismiss`/`pausedTimeout` (D-06/D-07) or the
  charging/device transient's own ~3s auto-advance, whichever fits better once the state model is
  chosen.
- Settings toggle default value (on/off) and exact wording — not discussed; default to "on"
  (matching the existing `nowPlayingKey` default of `true`) unless research/planning finds a
  reason otherwise.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements & Roadmap
- `.planning/REQUIREMENTS.md` — NOW-05, NOW-06 (this phase's two requirements)
- `.planning/ROADMAP.md` — Phase 18 entry (goal, success criteria, depends on Phase 17)

### Core files this phase touches
- `Islet/Notch/IslandResolver.swift` — the pure `resolve(...)` reducer; `IslandPresentation`
  enum; `ActiveTransient`/`TransientQueue` (the existing charging/device transient mechanism,
  which D-02 above says the toast must NOT join); `nowPlayingLaunchGate(...)` (Phase 17's
  ambient-only gate, the direct precedent for D-04's "ambient only, not expanded" rule).
- `Islet/Notch/NowPlayingPresentation.swift` — `NowPlayingPresentation` enum, `TrackSnapshot`,
  and `isSameTrack(_:_:)` — the existing pure same-track comparison (title+artist equality,
  playing/paused-agnostic) that is the direct precedent/candidate primitive for detecting a
  "genuine" song change.
- `Islet/Notch/NowPlayingState.swift` — the `@Published` model that could host new toast state
  (e.g. "currently showing toast for X").
- `Islet/Notch/NotchWindowController.swift` — `handleNowPlaying(_:_:)` (~line 944), where every
  live snapshot lands; also owns `scheduleMediaDismiss`/`pausedTimeout` (D-06/D-07), the existing
  timer-based dismiss precedent this phase's ~3s toast timer should likely follow.
- `Islet/Notch/NotchPillView.swift` — rendering layer; charging/device wings rendering (`wings(for
  activity:)` etc.) is the closest existing visual precedent for a transient "expands, shows
  content, collapses" UI, though the toast is a new visual per ROADMAP ("expands downward").
- `Islet/SettingsView.swift` — `ActivitySettings.nowPlayingKey` / `@AppStorage nowPlayingEnabled`
  and the `Toggle("Now Playing", isOn: $nowPlayingEnabled)` at line 133 — the exact placement and
  pattern NOW-06's new toggle must sit next to.

No external ADR/SPEC docs exist for this phase — NOW-05/NOW-06 in REQUIREMENTS.md and the
ROADMAP.md Phase 18 entry are the full requirement source.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `isSameTrack(_:_:)` in `NowPlayingPresentation.swift` — pure, already-tested function that
  distinguishes a genuine track change from a play/pause transition on the same track. Directly
  answers "what counts as a genuine song change" without new classification logic.
- `nowPlayingLaunchGate(hasPlayedSinceLaunch:nowPlaying:)` in `IslandResolver.swift` (Phase 17) —
  the ambient-only gating precedent this phase's toast-suppression-while-expanded rule (D-04)
  should mirror in shape.
- `ActivitySettings` struct in `SettingsView.swift` — the existing `@AppStorage` key pattern
  (`chargingKey`, `nowPlayingKey`, `deviceKey`) that NOW-06's new toggle key should follow.

### Established Patterns
- Pure-seam discipline (Phase 4/6/16/17 precedent): classification/resolution logic lives in
  Foundation-only files (`NowPlayingPresentation.swift`, `IslandResolver.swift`) and is
  unit-tested; MediaRemote glue and controller/timer wiring live in the `@MainActor` layer
  (`NotchWindowController.swift`) and are verified on-device. The toast's "is this a genuine
  change" decision should be a pure function; its timer/dismiss mechanism belongs on the
  controller.
- D-02 priority ranking (`IslandResolver.swift` header): Charging > Device > Now Playing ambient.
  The toast, per this phase's D-02 decision, sits OUTSIDE this ranking entirely rather than as a
  4th tier — it only ever competes with the ambient Now Playing branch, never with
  charging/device transients directly.

### Integration Points
- `handleNowPlaying(_:_:)` in `NotchWindowController.swift` — the single site every live snapshot
  passes through; the natural place to compare incoming vs previous presentation via
  `isSameTrack(_:_:)` and decide whether to trigger a toast.
- `resolve(...)` in `IslandResolver.swift` — would need a new input/branch if the toast is
  modeled as part of the pure resolver output, gated the same way as the Phase 17 launch gate
  (ambient branch only, per D-04).
- `SettingsView.swift` line ~133 — insertion point for the new toggle next to `Toggle("Now
  Playing", isOn: $nowPlayingEnabled)`.

</code_context>

<specifics>
## Specific Ideas

No specific visual/copy requests beyond title+artist content (D-01) — exact toast layout,
animation curve, and styling are left to the UI phase (ROADMAP marks this phase "UI hint: yes").

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 18-Song-Change Toast*
*Context gathered: 2026-07-09*
