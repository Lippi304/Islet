# Phase 48: Audio Output Switcher — UI Wiring - Context

**Gathered:** 2026-07-19
**Status:** Ready for planning

<domain>
## Phase Boundary

Wire the pure seam (`AudioOutputPresentation.swift`) and monitor (`AudioOutputMonitor.swift`) built in Phase 47 into the real UI: the reserved RIGHT 28×28 slot in `mediaContent`'s transport control row becomes a real speaker-icon button that reveals a panel with a live-updating device list (current device on top, tap-to-select) and a thick draggable volume slider controlling the current output's real system volume. This satisfies OUTPUT-01..04. The LEFT reserved slot (future Shuffle) and the Star/favorite feature are explicitly out of scope — Favorite/Like is Phase 49 (spike) / Phase 50 (implementation), sharing no code path with this phase.

</domain>

<decisions>
## Implementation Decisions

### System alert-sound routing
- **D-01 (LOCKED):** Switching output in the panel sets ONLY `kAudioHardwarePropertyDefaultOutputDevice` (the main/media output). It does NOT touch `kAudioHardwarePropertyDefaultSystemOutputDevice` (system alert sounds) — matches "switch what I'm listening to," the feature's actual intent, and never silently overrides a user's separately-configured alert-sound routing. This was an explicit "decision this needs" flag from `research/STACK.md` §2, now resolved.

### Tap-to-select (already locked upstream, restated here for planner clarity)
- **D-02 (LOCKED, not re-discussed):** Tapping a non-current device in the list makes it active and it animates to the top as the *visual result* of the tap (per OUTPUT-03 / `research/FEATURES.md`'s explicit Tap-vs-Drag Recommendation). Drag-to-reorder is NOT built this phase — it's an optional P3 future accelerator, never a replacement for tap. Note: `research/ARCHITECTURE.md`'s "Data Flow" section (lines ~192-221) describes a drag-based selection gesture that is stale relative to `FEATURES.md`'s later, explicit tap-to-select resolution and the locked OUTPUT-03 wording — planner should follow `FEATURES.md`/OUTPUT-03, not that section's drag framing.

### Volume slider visual style
- **D-03:** Reuse `OSDLevelBar`'s existing visual language (`NotchPillView.swift:3055` — Capsule track `white.opacity(0.15)` + accent-tinted Capsule fill) scaled up/thicker, rather than a new distinct slider design. Must become genuinely draggable (OSDLevelBar itself is currently display-only, no gesture) — this phase adds the drag gesture, reusing only the visual style.
- **D-04:** No live numeric/percentage readout while dragging — fill-only, matching OSDLevelBar's existing display-only precedent (no numeric label exists anywhere in the current volume HUD).

### Device row design & no-volume-control devices
- **D-05:** Current/default device is distinguished by an accent-tinted checkmark next to its name; other rows plain white text. Matches the app's existing single-accent-signal convention (e.g. `ProgressBar`'s accent fill) rather than a full row background highlight.
- **D-06:** When the current output device reports `hasVolumeControl(uid:) == false` (e.g. an external monitor — confirmed by Phase 47 on-device verification to actually occur), the volume slider stays visible but is greyed out / visually disabled (dimmed, non-interactive) rather than hidden — matches the app's existing "degrade silently on capability gaps" convention (WeatherKit, EventKit, Focus Mode).

### Panel open/close & failed-switch behavior
- **D-07:** Tapping a device to select it does NOT auto-close the panel — the list just re-sorts (selected device animates to top) and the panel stays open, matching macOS Control Center's Sound module (never auto-closes on selection).
- **D-08:** Re-tapping the speaker icon while the panel is open closes it (standard toggle-button behavior, symmetric with opening it).
- **D-09:** If `AudioOutputMonitor.setDefaultOutput`'s confirm-after-set reports failure (Pitfall 8 — a documented AirPods-handoff bug can silently revert a switch with no error return), the UI shows NO error toast/shake. The device list simply snaps back to whatever CoreAudio's own listener reports as the real current default (the monitor's `onDevicesChanged` callback already re-delivers the true state) — a transient handoff blip resolving itself on its own shouldn't alarm the user.

### Claude's Discretion
- Exact spring/animation parameters for the "device slides to top" reorder animation and the panel reveal/collapse — follow the app's existing `matchedGeometryEffect`/spring language (e.g. `OSDLevelBar`'s `.spring(response: 0.15, dampingFraction: 0.86)`) as a starting point, tune on-device per this project's established convention.
- Device-kind icon (if any) shown per row (speaker/headphone/AirPods/monitor glyph) vs. text-only rows — not raised during discussion; Claude decides based on what fits the row's existing 28×28/list-item sizing conventions.
- Exact panel height/geometry-union math (whether `switcherContentHeight` (196pt) already accommodates the panel without a new union member) — `research/ARCHITECTURE.md`'s "geometry three-site rule" section already flags this as worth checking before adding new geometry constants; implementation detail, not a user decision.
- Whether `AudioOutputMonitor` gets an optional `AudioOutputProviding` protocol for unit-test fakeability — carried over as still-open discretion from Phase 47's own context (not resolved differently by this phase's UI-only scope).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Roadmap & requirements
- `.planning/ROADMAP.md` (Phase 48 entry, lines 713-724) — goal, hard dependency on Phase 47, OUTPUT-01..04, 4 success criteria
- `.planning/REQUIREMENTS.md` (lines 67-70, 135-138) — OUTPUT-01..04 full text and status table

### Research (already covers this phase in detail — no dedicated research-phase needed per `research/SUMMARY.md`)
- `.planning/research/ARCHITECTURE.md` — Pattern 2 (why `AudioOutputMonitor` is a new file), Pattern 3 (output panel as sibling `@Published` state on `IslandPresentationState`, NOT a resolver case — with full rationale on click-through/`visibleContentZone()` correctness), Anti-Patterns 1-3, "geometry three-site rule" section, Suggested Build Order steps 3-4 (this phase = steps 3 and 4). **Caveat:** its "Data Flow" section's drag-gesture description is superseded by D-02 above — follow `FEATURES.md` and OUTPUT-03 instead.
- `.planning/research/FEATURES.md` — "Tap-vs-Drag Recommendation" section (explicit answer + rationale), MVP Definition (P1 output-switcher scope), Anti-Features table (why drag-as-sole-selection is rejected)
- `.planning/research/PITFALLS.md` — Pitfall 4 (UID-not-AudioDeviceID keying, already solved in `AudioOutputPresentation.swift`/`AudioOutputMonitor.swift`), Pitfall 5 (off-main callback hop, already solved), Pitfall 7 (per-device volume-property guard, already solved via `hasVolumeControl`), Pitfall 8 (confirm-after-set / AirPods-handoff revert — directly informs D-09 above)
- `.planning/research/STACK.md` §2 (lines 26-36) — CoreAudio `AudioHardwareService*` volume API, `AudioObjectAddPropertyListenerBlock`, and the alert-sound-routing decision flag resolved by D-01 above
- `.planning/research/SUMMARY.md` — "Phase 2: Audio Output Switcher — UI Wiring" section (lines 76-80), confirms this phase needs no dedicated research-phase

### Prior phase context
- `.planning/phases/47-audio-output-switcher-pure-seam-monitor/47-CONTEXT.md` — D-01 (device scope incl. AirPlay/aggregate), D-02 (default-pinned-top + alphabetical sort, already implemented), D-03 (on-device verification scope); this phase's Claude's-Discretion item on `AudioOutputProviding` protocol carries forward unresolved

### Existing code to reuse/modify
- `Islet/Notch/AudioOutputPresentation.swift` — pure seam, already implements `AudioOutputDevice`, `isOutputCapableDevice`, `sortedAudioOutputDevices` (list order IS the is-default signal)
- `Islet/Notch/AudioOutputMonitor.swift` — event-driven monitor, already implements `start()`/`stop()`, `setDefaultOutput(_:completion:)` (confirm-after-set per Pitfall 8), `hasVolumeControl(deviceUID:)` (per Pitfall 7)
- `Islet/Notch/NotchPillView.swift:2826-2896` (`mediaContent`) — the two reserved `Color.clear.frame(width: 28, height: 28)` slots at lines 2864 (left, Shuffle, untouched this phase) and 2872 (right, becomes the speaker-icon button); `TransportButton` struct (line 2904) as the closure-forwarding/hover-background convention to mirror for the new button
- `Islet/Notch/NotchPillView.swift:3055` (`OSDLevelBar`) — the display-only Capsule track+fill visual language D-03 reuses (must add a drag gesture; component itself has none today)
- `Islet/Notch/VolumeReader.swift` — `readSystemVolume()`/`adjustSystemVolume()`, reused UNCHANGED for the slider's live volume read/write (already operates on whatever is the current default device)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `OSDLevelBar` (`NotchPillView.swift:3055`) — Capsule track/fill visual language for the new draggable slider (D-03)
- `TransportButton` (`NotchPillView.swift:2904`) — the exact closure-forwarding + hover-background pattern the new speaker-icon button should mirror
- `VolumeReader.swift`'s `readSystemVolume()`/`adjustSystemVolume()` — direct reuse for the slider's live control, no changes needed
- `AudioOutputPresentation.swift`/`AudioOutputMonitor.swift` (Phase 47) — the full pure seam + monitor this phase wires up; no changes expected here beyond what UI wiring needs

### Established Patterns
- "Geometry three-site rule" (`ARCHITECTURE.md`) — any taller-content reveal touches `blobShape`'s height, `NotchWindowController`'s panel-frame union, AND `visibleContentZone()` together, never independently (CR-01 precedent)
- Sibling `@Published` boolean on `IslandPresentationState` for disclosure state within an existing presentation case, not a new `IslandPresentation` resolver case (Pattern 3) — mirrors `hoveredQuickActionButtonIndex`/`shelfStripVisible` precedent
- Closure-forwarding convention (`onPrevious`/`onTogglePlayPause`/`onNext`) extends naturally to `onToggleOutputPanel`/`onSelectOutputDevice`/`onVolumeChange`

### Integration Points
- `NotchWindowController` starts/stops `AudioOutputMonitor` alongside its other monitors, stores the live device list, and handles the new closures
- `visibleContentZone()` and `blobShape`'s `height:` argument both must read the same new `outputPanelOpen` boolean (the CR-01 invariant)

</code_context>

<specifics>
## Specific Ideas

No specific new visual reference beyond what's captured in the decisions above (reuse `OSDLevelBar`'s existing look, accent checkmark for current device, grey-out for no-volume-control devices, panel stays open on selection). The 4 discussed areas cover every genuinely open UI/UX choice surfaced by research — everything else (tap-to-select, panel-as-sibling-state, UID keying, off-main hop, alert-sound-only routing) was already locked by Phase 47's context or this phase's research docs.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope. Drag-to-promote as an optional accelerator on top of tap-to-select (`research/FEATURES.md` P3) and persisted "recently used outputs" ordering remain deferred to v2+/backlog per prior research, not re-raised here.

### Reviewed Todos (not folded)
- **Calendar month-grid polish (arrows, day numbers, event hover/edit)** — UI todo, unrelated to audio-output UI wiring; belongs with future Calendar work.
- **Quick Action disabled state has no controller gate** — UI/state todo, unrelated to this phase's scope.
- **Island briefly disappears during click-through** — UI/click-through todo, unrelated to this phase's scope.

</deferred>

---

*Phase: 48-Audio Output Switcher — UI Wiring*
*Context gathered: 2026-07-19*
