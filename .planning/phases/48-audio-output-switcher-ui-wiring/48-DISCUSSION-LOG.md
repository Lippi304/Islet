# Phase 48: Audio Output Switcher — UI Wiring - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-19
**Phase:** 48-Audio Output Switcher — UI Wiring
**Areas discussed:** System alert-sound routing, Volume slider visual style, Device row design & no-volume-control devices, Panel open/close & failed-switch behavior

---

## System alert-sound routing

| Option | Description | Selected |
|--------|-------------|----------|
| Only main output (Recommended) | Sets only kAudioHardwarePropertyDefaultOutputDevice — matches the feature's actual intent, never silently overrides a separately-configured alert-sound device. STACK.md's explicit recommendation. | ✓ |
| Mirror macOS Sound Output | Also flips kAudioHardwarePropertyDefaultSystemOutputDevice in lockstep, matching Control Center's real behavior. | |
| You decide | Claude picks the recommended approach. | |

**User's choice:** Only main output (Recommended)
**Notes:** This was an explicit "decision this needs" flag raised by `research/STACK.md` §2 — resolved here rather than left implicit.

---

## Volume slider visual style

| Option | Description | Selected |
|--------|-------------|----------|
| Reuse OSDLevelBar style, scaled up (Recommended) | Same Capsule-track + accent-fill visual language as the volume HUD popup, thicker and made draggable. | ✓ |
| New distinct design | A different look (e.g. a pill with a visible round knob/thumb). | |
| You decide | Claude designs it, following the app's existing visual language by default. | |

**User's choice:** Reuse OSDLevelBar style, scaled up (Recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| No number, fill only (Recommended) | Matches OSDLevelBar's existing display-only precedent — no numeric label anywhere in the current volume HUD. | ✓ |
| Show live percentage | A small % label appears while dragging, net-new UI element. | |

**User's choice:** No number, fill only (Recommended)

---

## Device row design & no-volume-control devices

| Option | Description | Selected |
|--------|-------------|----------|
| Accent-tinted checkmark + name (Recommended) | A checkmark in the app's accent color next to the current device's name — matches the app's existing single-accent-signal convention. | ✓ |
| Filled accent background on the row | The current device's entire row gets a tinted background. | |
| You decide | Claude picks a treatment consistent with existing convention. | |

**User's choice:** Accent-tinted checkmark + name (Recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| Grey out / disable the slider (Recommended) | Slider stays visible but visually disabled when the current device reports no volume control — matches "degrade silently on capability gaps" convention. | ✓ |
| Hide the slider entirely | Slider disappears from the panel entirely. | |
| You decide | Claude picks based on what looks cleanest once built. | |

**User's choice:** Grey out / disable the slider (Recommended)
**Notes:** Confirmed relevant, not hypothetical — Phase 47's on-device verification already found `hasVolumeControl` returns false for an external monitor.

---

## Panel open/close & failed-switch behavior

| Option | Description | Selected |
|--------|-------------|----------|
| Panel stays open (Recommended) | Selecting a device just re-sorts the list; panel stays open — matches macOS Control Center's Sound module. | ✓ |
| Panel closes after selection | Tapping a device switches output AND immediately collapses the panel. | |

**User's choice:** Panel stays open (Recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, tap toggles open/closed (Recommended) | Standard toggle-button behavior. | ✓ |
| No, only closes some other way | Re-tapping the speaker icon does nothing while open. | |

**User's choice:** Yes, tap toggles open/closed (Recommended)

| Option | Description | Selected |
|--------|-------------|----------|
| Snap list back to the real current device (Recommended) | If confirm-after-set fails, the list re-sorts back to whatever CoreAudio actually reports — no error toast. | ✓ |
| Show a visible error/shake on the row | The device row shows a brief error indicator when the switch fails to stick. | |
| You decide | Claude picks based on what's simplest to implement correctly. | |

**User's choice:** Snap list back to the real current device (Recommended)
**Notes:** Directly informed by Pitfall 8 (documented AirPods-handoff bug that can silently revert a switch) — `setDefaultOutput`'s completion callback already re-confirms via delayed re-read.

---

## Claude's Discretion

- Exact spring/animation parameters for the "device slides to top" reorder animation and panel reveal/collapse — follow existing `matchedGeometryEffect`/spring language, tune on-device.
- Device-kind icon (if any) per row vs. text-only rows — not raised during discussion.
- Exact panel height/geometry-union math (whether `switcherContentHeight` already accommodates the panel) — implementation detail per `ARCHITECTURE.md`'s own note.
- Whether `AudioOutputMonitor` gets an optional `AudioOutputProviding` protocol for unit-test fakeability — carried over unresolved from Phase 47's context.

## Deferred Ideas

None — discussion stayed within phase scope. Drag-to-promote (P3 accelerator) and persisted "recently used outputs" ordering remain deferred to v2+/backlog per prior research (`FEATURES.md`), not re-raised here.

Reviewed but not folded (todo cross-reference): Calendar month-grid polish, Quick Action disabled-state controller gate, Island disappears during click-through — all unrelated to this phase's scope.

---

# Revision (2026-07-20) — row-as-volume-bar redesign

> On-device UAT of Waves 1-2 (built exactly to the original design above) revealed the built
> behavior didn't match the user's actual mental model — surfaced only once they saw the
> running app. This is a design revision, not a bug fix. See `48-CONTEXT.md`'s Revision Note.

**Areas discussed:** Inactive-row fill meaning, Active-device visual signal, No-volume-control row appearance

## Inactive-row fill meaning

| Option | Description | Selected |
|--------|-------------|----------|
| Static/neutral fill (Recommended) | Inactive rows show a fixed look, no new per-device volume reads needed. | |
| Real per-device volume | Each inactive row's fill reflects that device's actual volume — requires a new per-device volume READ in AudioOutputMonitor. | |
| No fill until active | Inactive rows show plain text only; bar-fill only appears once a device becomes active. | (closest match) |

**User's choice (free text, German):** "Na die aktuell ausgewählte zeigt ja die aktuelle Lautstärke an, die anderen werden ohne Lautstärke angezeigt. Wenn man eine andere Quelle andrückt wählt man diese automatisch aus und dann kann man die Lautstärke verschieben."
**Notes:** Only the active row shows real, live volume as its fill. Inactive rows show no fill/volume indication at all. Tapping an inactive row auto-selects it, after which its row becomes the draggable one. No per-device volume reads added — confirms the "No fill until active" option, phrased in the user's own words. → CONTEXT.md D-10/D-11.

---

## Active-device visual signal

| Option | Description | Selected |
|--------|-------------|----------|
| Fill alone is enough (Recommended) | No checkmark needed — the filled bar + top position are signal enough. | (closest match) |
| Checkmark stays in addition | Checkmark remains next to the name as an additional signal. | |

**User's choice (free text, German):** "Na die ausgewählte/aktuelle Quelle ist im normalem hellen weiß und die nicht ausgewählten sind nur so leichter hell weiß dadurch werden die ja auch eher als sekundäre quellen gesehen."
**Notes:** No checkmark. Active row's text is full-opacity white; inactive rows' text is dimmed/lighter white, reading as secondary. Replaces D-05 entirely. → CONTEXT.md D-12.

---

## No-volume-control row appearance

| Option | Description | Selected |
|--------|-------------|----------|
| Bar greyed out, not draggable (Recommended) | Row stays full white (still active), but its bar/fill is dimmed and non-interactive — matches old D-06's "visible but disabled" convention. | ✓ |
| No fill, text only | Active row looks like an inactive row when it lacks volume control. | |

**User's choice:** Bar greyed out, not draggable (Recommended)
**Notes:** Reuses `OutputVolumeSlider`'s existing `enabled: Bool` → `opacity(0.35)` + gesture-no-op behavior directly, just scoped to the row instead of a standalone element. → CONTEXT.md D-13.

---

## Revision — Claude's Discretion (additions)

- Row height/padding adjustment when a row gains the Capsule-bar background vs. staying a plain inactive row — not raised during discussion.
- Exact spring/fade timing for a row transitioning into/out of its active-with-fill state — follow existing `.spring(response: 0.15, dampingFraction: 0.86)` convention, tune on-device.

## Revision — Deferred Ideas

None raised during the revision discussion.
