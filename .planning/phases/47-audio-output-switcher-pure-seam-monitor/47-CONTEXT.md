# Phase 47: Audio Output Switcher — Pure Seam + Monitor - Context

**Gathered:** 2026-07-19
**Status:** Ready for planning

<domain>
## Phase Boundary

Build the pure device-list/sort logic (`AudioOutputPresentation.swift`) and the event-driven CoreAudio device monitor (`AudioOutputMonitor.swift`) for the audio-output switcher — infrastructure only, no UI. This mirrors the already-shipped `VolumeReader`/`BrightnessReader` (public API) and `BluetoothMonitor` (event-driven shape) risk tier and pattern. No UI wiring happens in this phase — that's Phase 48, which depends on this phase's seam being proven correct first (research's explicit build-order recommendation, same risk-isolation precedent as Phase 22→24 and Phase 38→39).

</domain>

<decisions>
## Implementation Decisions

### Device list scope
- **D-01:** The device list matches the system Sound output menu's scope — includes AirPlay speakers and aggregate/Multi-Output devices, not just physical hardware (built-in/Bluetooth/wired/USB). The pure filter logic (output-capable via channel count under `kAudioObjectPropertyScopeOutput`, per STACK.md) must classify these device kinds correctly, not just exclude them.

### Non-default sort order
- **D-02:** The current/default device is always pinned on top (locked by OUTPUT-02, Phase 48 scope — informs this phase's sort function contract now). The remaining (non-default) devices sort alphabetically by name below it. No type-grouping, no system/stable-order dependency — alphabetical is simple, deterministic, and directly unit-testable per Success Criterion #1.

### On-device verification scope
- **D-03:** Success Criterion #4 (per-device volume-property support verified against real hardware) has more than the one Bluetooth headset mentioned in research available on the dev machine. Verify against: built-in speakers, **two** distinct Bluetooth devices (to catch codec/implementation differences between them, not just Bluetooth-vs-built-in), and a USB/wired output device. This widens the on-device verification step beyond the research doc's minimum — plan/execute should budget for testing all of these, not just one Bluetooth device.

### Claude's Discretion
- Whether `AudioOutputMonitor` gets an optional `AudioOutputProviding` protocol for unit-test fakeability (per ARCHITECTURE.md Pattern 2) — not a hard requirement since CoreAudio is public API (no MediaRemote-style isolation risk); Claude decides based on what the unit tests for Success Criterion #1 actually need.
- Exact unit-test coverage/style for the pure sort/reorder logic — follow the existing `NowPlayingPresentation`/`OSDActivity` pure-seam testing convention already in the codebase.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Roadmap & requirements
- `.planning/ROADMAP.md` (Phase 47 entry) — goal, success criteria, "no formal REQ-ID, infra phase preceding Phase 48" framing
- `.planning/REQUIREMENTS.md` (OUTPUT-01..04) — the Phase 48 user-facing requirements this phase's pure logic must be shaped to support (esp. OUTPUT-02's "current output pinned on top" and OUTPUT-04's UID-not-AudioDeviceID keying)

### Research (this phase = research's "Phase 1", confirmed standard-pattern — no dedicated research-phase needed)
- `.planning/research/STACK.md` §2 "Audio-output-device switcher + per-device volume" — CoreAudio API surface (`kAudioHardwarePropertyDevices`, `kAudioHardwarePropertyDefaultOutputDevice`, `AudioHardwareServiceGetPropertyData`/`SetPropertyData` with `kAudioHardwareServiceDeviceProperty_VirtualMainVolume`, `AudioObjectAddPropertyListenerBlock`), explicitly recommends extending the existing CoreAudio surface, NOT `SimplyCoreAudio` (archived)
- `.planning/research/PITFALLS.md` Pitfalls 4, 5, 6, 7, 8 — UID-not-AudioDeviceID keying (mandatory), off-main callback hop (mandatory), BluetoothMonitor/CoreAudio independence (do not derive one from the other), non-uniform volume-property support (guard `AudioObjectHasProperty` before every volume call), output-switch confirm-after-set discipline
- `.planning/research/ARCHITECTURE.md` Pattern 2 ("Audio-output switching needs a new dedicated Monitor — cannot extend VolumeReader"), Anti-Pattern 3, Build Order steps 1–2 (pure seams first, then the safe public-API monitor) — this is exactly this phase's scope
- `.planning/research/SUMMARY.md` "Phase 1: Audio Output Switcher — Pure Seam + Monitor" section — confirms this phase needs no dedicated research-phase; two working examples already exist to copy from

### Existing code to mirror
- `Islet/Notch/BluetoothMonitor.swift` — the event-driven register/callback shape `AudioOutputMonitor` must mirror (idempotent `start()`, full teardown `stop()`, explicit `DispatchQueue.main.async` hop in every callback, keyed by stable identity not ephemeral ID)
- `Islet/Notch/VolumeReader.swift` — the existing CoreAudio surface; reused UNCHANGED for volume reads (not extended with device-list logic — that's the whole point of Pattern 2/Anti-Pattern 3)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `VolumeReader.swift`'s `defaultOutputDeviceID()` pattern (guarded `AudioObjectGetPropertyData` against `AudioObjectPropertyAddress`, safe-default-never-force-unwrap discipline) — the exact defensive-cast style `AudioOutputMonitor`'s device enumeration should follow.
- `BluetoothMonitor.swift`'s full shape (idempotent start, per-item token retention keyed by stable string identity, explicit main-thread hop, full teardown in stop()) — copy this structure directly for `AudioOutputMonitor`, substituting IOBluetooth notification registration for `AudioObjectAddPropertyListenerBlock`.

### Established Patterns
- "One fragile system surface, one file" — `AudioOutputMonitor.swift` is a NEW file, never bolted onto `VolumeReader.swift`, even though both touch CoreAudio (their shapes are incompatible: stateless/pull-based vs. stateful/event-driven).
- Pure seam / system glue split — `AudioOutputPresentation.swift` (Foundation-only, unit-tested) must have zero AppKit/SwiftUI/CoreAudio import, exactly like `NowPlayingPresentation.swift`/`OSDActivity.swift`.

### Integration Points
- This phase produces no wiring into `NotchWindowController`/`NotchPillView` — that's Phase 48. The two new files should be buildable and testable in isolation.

</code_context>

<specifics>
## Specific Ideas

No specific UI/visual requirements — this phase is infrastructure-only, no UI surface exists yet. The three decisions above (D-01 device scope, D-02 sort order, D-03 verification hardware) are the concrete shape constraints for the pure logic and its on-device verification step.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope. (Persisted "recently used outputs" ordering and drag-to-reorder are already deferred in PROJECT.md/REQUIREMENTS.md to a later milestone, not re-raised here.)

### Reviewed Todos (not folded)
- **Calendar month-grid polish (arrows, day numbers, event hover/edit)** — UI todo, unrelated to audio-output infrastructure; belongs with future Calendar work.
- **Quick Action disabled state has no controller gate** — UI/state todo, unrelated to this phase's scope.
- **Island briefly disappears during click-through** — UI/click-through todo, unrelated to this phase's scope.

</deferred>

---

*Phase: 47-Audio Output Switcher — Pure Seam + Monitor*
*Context gathered: 2026-07-19*
