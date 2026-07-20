# Phase 48: Audio Output Switcher — UI Wiring - Context

**Gathered:** 2026-07-19
**Revised:** 2026-07-20 — row-as-volume-bar redesign, superseding original D-03/D-04/D-05/D-06 (see Revision Note below)
**Status:** Ready for replanning

<domain>
## Phase Boundary

Wire the pure seam (`AudioOutputPresentation.swift`) and monitor (`AudioOutputMonitor.swift`) built in Phase 47 into the real UI: the reserved RIGHT 28×28 slot in `mediaContent`'s transport control row becomes a real speaker-icon button that reveals a panel with a live-updating device list (current device on top, tap-to-select) where the **device rows themselves are the volume control** for the active device (see Revision Note). This satisfies OUTPUT-01..04. The LEFT reserved slot (future Shuffle) and the Star/favorite feature are explicitly out of scope — Favorite/Like is Phase 49 (spike) / Phase 50 (implementation), sharing no code path with this phase.

</domain>

<revision_note>
## Revision Note (2026-07-20)

Waves 1–2 and part of Wave 3 were built and committed against the ORIGINAL design (one shared `OSDLevelBar`-style slider above a plain device list, D-03/D-04/D-05/D-06 below, struck through). On-device UAT (Plan 48-03 Task 3 checkpoint) showed this technically matched what was locked in discuss-phase — but not the user's actual mental model, discovered only once they saw the running app.

**New design, replacing the struck-through decisions:** each device row IS the volume bar. There is no separate slider element above the list. Only the currently active device's row is live and draggable; inactive rows show plain text with no fill at all. Tapping an inactive row auto-selects it (existing D-02/D-07 tap-to-select-and-reorder-to-top behavior, unchanged), after which its row becomes the draggable one.

**Affected plans (need replanning, not just re-execution):**
- **48-02-PLAN.md** — built `outputPanel(devices:)` (`NotchPillView.swift:2953`) with a standalone `OutputVolumeSlider` (`NotchPillView.swift:3145`) above the device list. The standalone slider goes away; its exact Capsule-track/fill/drag/`enabled`-dimming logic gets absorbed into the active row itself (see Code Context — this is a near-direct reuse, not a rewrite).
- **48-03-PLAN.md** — Task 3 (on-device UAT checkpoint) is intentionally left unapproved against the old design; must be replanned/re-run against the new row-as-bar behavior.
- **48-01-PLAN.md** (data layer) — unaffected, no changes needed.

</revision_note>

<decisions>
## Implementation Decisions

### System alert-sound routing
- **D-01 (LOCKED, unaffected by revision):** Switching output in the panel sets ONLY `kAudioHardwarePropertyDefaultOutputDevice` (the main/media output). It does NOT touch `kAudioHardwarePropertyDefaultSystemOutputDevice` (system alert sounds) — matches "switch what I'm listening to," the feature's actual intent, and never silently overrides a user's separately-configured alert-sound routing.

### Tap-to-select (already locked upstream, unaffected by revision)
- **D-02 (LOCKED, not re-discussed):** Tapping a non-current device in the list makes it active; it animates to the top as the *visual result* of the tap (per OUTPUT-03). Drag-to-reorder is NOT built this phase. Tapping an inactive row both selects it AND transitions its row into the draggable/volume-bar state described in D-10 below.

### ~~Volume slider visual style~~ — superseded by D-10/D-11
- ~~**D-03:** Reuse `OSDLevelBar`'s existing visual language scaled up/thicker as a standalone slider element.~~
- ~~**D-04:** No live numeric/percentage readout while dragging — fill-only.~~ (The "no numeric readout" rule itself still holds — see D-11.)

### Row-as-volume-bar design (NEW — supersedes D-03)
- **D-10:** There is no separate slider element in the output panel. The device row itself is the volume control: the ACTIVE device's row renders a Capsule track+fill (same visual language as `OSDLevelBar`/the now-removed `OutputVolumeSlider`) as the row's own background, filled to the current volume fraction, and is drag-gesture-enabled across the row's full width. Reuse `OutputVolumeSlider`'s exact Capsule/GeometryReader/DragGesture/`enabled`-dimming implementation (`NotchPillView.swift:3145-3172`) — wrap the row's `Text`+checkmark content in it instead of rendering it as a separate element above the list.

### Inactive-row fill (NEW — supersedes D-04's "fill-only" framing for non-active rows)
- **D-11:** Inactive (non-active) device rows show NO fill/bar at all — plain name text only, same layout as the current build's plain rows. No live per-device volume reads are added to `AudioOutputMonitor` for this phase (only the active device's volume is ever read/displayed, via the existing `VolumeReader` surface) — avoids extending Phase 47's CoreAudio scope. Still no numeric/percentage readout on the active row's fill either (D-04's original rule holds, just scoped to the one row that has a fill at all).

### Active-device visual signal (NEW — supersedes D-05's checkmark)
- **D-12 (supersedes D-05):** No checkmark. The active device's row renders its name text at full white opacity; every inactive row renders its name text at a dimmed/lighter white opacity, reading as visually secondary. Combined with D-10's fill (present only on the active row) and D-02's "active row sits on top," this is sufficient signal for which device is currently selected — no additional icon/badge needed.

### No-volume-control devices, per row (NEW — supersedes D-06)
- **D-13 (supersedes D-06):** Because inactive rows never show a fill (D-11), this scenario only matters when the ACTIVE device lacks volume control (`hasVolumeControl(uid:) == false`, e.g. an external monitor — confirmed by Phase 47 to actually occur). In that case: the row's text STAYS full white (it is still the active device — D-12's signal is unaffected), but its Capsule fill/bar is dimmed (`opacity(0.35)`, matching `OutputVolumeSlider`'s existing `enabled`-false styling) and the drag gesture is a no-op — matches the app's "degrade silently on capability gaps" convention and directly reuses the `enabled: Bool` parameter already built into `OutputVolumeSlider`.

### Panel open/close & failed-switch behavior (unaffected by revision)
- **D-07 (LOCKED):** Tapping a device to select it does NOT auto-close the panel — the list just re-sorts and the panel stays open.
- **D-08 (LOCKED):** Re-tapping the speaker icon while the panel is open closes it.
- **D-09 (LOCKED):** If `AudioOutputMonitor.setDefaultOutput`'s confirm-after-set reports failure (Pitfall 8 — AirPods-handoff bug), the UI shows NO error toast/shake — the device list just snaps back to whatever CoreAudio's own listener reports as the real current default.

### Claude's Discretion
- Exact spring/animation parameters for the row transitioning into/out of its "active, has-fill" state (fill fading in, row possibly growing to accommodate the thicker bar) — follow the app's existing `.spring(response: 0.15, dampingFraction: 0.86)` convention as a starting point, tune on-device.
- Row height/padding adjustment when a row gains the Capsule-bar background vs. a plain inactive row — implementation detail, not raised during discussion.
- Device-kind icon (if any) shown per row — not raised during discussion; Claude decides based on existing row sizing conventions.
- Exact panel height/geometry-union math — `research/ARCHITECTURE.md`'s "geometry three-site rule" section already flags this as worth checking before adding new geometry constants; implementation detail, not a user decision.
- Whether `AudioOutputMonitor` gets an optional `AudioOutputProviding` protocol for unit-test fakeability — carried over as still-open discretion from Phase 47's own context.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Roadmap & requirements
- `.planning/ROADMAP.md` (Phase 48 entry, lines 713-724) — goal, hard dependency on Phase 47, OUTPUT-01..04, 4 success criteria
- `.planning/REQUIREMENTS.md` (lines 67-70, 135-138) — OUTPUT-01..04 full text and status table

### Research (already covers this phase in detail — no dedicated research-phase needed per `research/SUMMARY.md`)
- `.planning/research/ARCHITECTURE.md` — Pattern 2, Pattern 3, Anti-Patterns 1-3, "geometry three-site rule" section, Suggested Build Order steps 3-4. **Caveat:** its "Data Flow" section's drag-gesture description is superseded by D-02; its slider-related framing predates this revision — follow this CONTEXT.md's D-10..D-13 for the row-as-bar design.
- `.planning/research/FEATURES.md` — "Tap-vs-Drag Recommendation" section, MVP Definition, Anti-Features table
- `.planning/research/PITFALLS.md` — Pitfall 4, 5, 7 (per-device volume-property guard — directly informs D-13's per-row `hasVolumeControl` gating), Pitfall 8 (confirm-after-set — informs D-09)
- `.planning/research/STACK.md` §2 (lines 26-36) — CoreAudio volume API, resolved by D-01
- `.planning/research/SUMMARY.md` — "Phase 2: Audio Output Switcher — UI Wiring" section

### Prior phase context
- `.planning/phases/47-audio-output-switcher-pure-seam-monitor/47-CONTEXT.md` — D-01 (device scope), D-02 (default-pinned-top + alphabetical sort), D-03 (on-device verification scope)

### Prior implementation artifacts (this phase, pre-revision — read to know what's being replaced)
- `.planning/phases/48-audio-output-switcher-ui-wiring/48-01-SUMMARY.md` — Wave 1 data-layer, unaffected by this revision
- `.planning/phases/48-audio-output-switcher-ui-wiring/48-02-SUMMARY.md` — Wave 2 UI wiring, built the standalone-slider version this revision replaces
- Project memory: user's clarified design description and the UAT-checkpoint-mismatch process note (session 2026-07-20) — captured in this revision's decisions above, no separate doc to read

### Existing code to reuse/modify
- `Islet/Notch/AudioOutputPresentation.swift` — pure seam, unchanged
- `Islet/Notch/AudioOutputMonitor.swift` — event-driven monitor, unchanged; `hasVolumeControl(deviceUID:)` now gates the ACTIVE row's fill/drag per D-13 (previously gated the standalone slider)
- `Islet/Notch/NotchPillView.swift:2953` (`outputPanel(devices:)`) — needs restructuring: remove the standalone `OutputVolumeSlider` call, move its visual/gesture logic into each row's rendering, gated on `device.isDefault`
- `Islet/Notch/NotchPillView.swift:3145-3172` (`OutputVolumeSlider`) — the exact Capsule/DragGesture/`enabled`-opacity implementation to reuse as the active row's background (D-10/D-13); likely gets moved/renamed rather than staying a standalone element, or the row becomes a new small view that composes it
- `Islet/Notch/NotchPillView.swift:3119` (`OSDLevelBar`) — untouched, still used only by the OSD wing (unrelated to this panel)
- `Islet/Notch/VolumeReader.swift` — `readSystemVolume()`/`adjustSystemVolume()`, reused UNCHANGED, still only reads/writes the current default device's volume (D-11 — no per-device reads added)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `OutputVolumeSlider` (`NotchPillView.swift:3145-3172`) — its Capsule track/fill/DragGesture/`enabled`-dimming logic is a near-direct fit for the active row's new bar-background; this is a move/adapt, not a from-scratch build
- `TransportButton` (`NotchPillView.swift:2904`) — closure-forwarding + hover-background pattern for the speaker-icon button, unaffected by this revision
- `VolumeReader.swift`'s `readSystemVolume()`/`adjustSystemVolume()` — direct reuse, unchanged

### Established Patterns
- "Geometry three-site rule" (`ARCHITECTURE.md`) — unaffected by this revision; the panel's overall height contract doesn't change, only its internal row rendering
- Sibling `@Published` boolean on `IslandPresentationState` for disclosure state — unaffected
- Closure-forwarding convention (`onSelectOutputDevice`/`onVolumeChange`) — unaffected; `onVolumeChange` now fires from within the active row's gesture instead of a standalone slider's gesture

### Integration Points
- `NotchWindowController` — no changes expected beyond what was already wired in Wave 3 Tasks 1-2 (handlers + CR-01 geometry); the row-as-bar change is presentation-only within `NotchPillView.swift`
- `outputPanel(devices:)`'s per-row `ForEach` needs to branch its rendering on `device.isDefault` — active row wraps content in the `OutputVolumeSlider`-style Capsule+gesture, inactive rows keep the current plain `HStack` (minus the checkmark, per D-12)

</code_context>

<specifics>
## Specific Ideas

User's own description of the intended design (2026-07-20, translated from German): "The currently selected device shows its actual current volume [as the row's fill]. The others are shown without any volume/fill. If you tap another source, it gets automatically selected, and then you can drag its volume." Active row text is normal bright white; inactive rows are a slightly lighter/dimmer white, reading as secondary sources.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope (implementation details of the already-scoped output-switcher panel). Drag-to-promote as an optional accelerator on top of tap-to-select, and persisted "recently used outputs" ordering, remain deferred to v2+/backlog per prior research.

### Reviewed Todos (not folded)
- **Calendar month-grid polish (arrows, day numbers, event hover/edit)** — UI todo, unrelated to audio-output UI wiring.
- **Quick Action disabled state has no controller gate** — UI/state todo, unrelated to this phase's scope.
- **Island briefly disappears during click-through** — UI/click-through todo, unrelated to this phase's scope.

</deferred>

---

*Phase: 48-Audio Output Switcher — UI Wiring*
*Context gathered: 2026-07-19, revised 2026-07-20*
