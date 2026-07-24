# Phase 63: Meeting-HUD - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-24
**Phase:** 63-Meeting-HUD
**Areas discussed:** Priority rank, Trigger sensitivity, Collapsed interaction, Visual design

---

## Priority rank

| Option | Description | Selected |
|--------|-------------|----------|
| Just below Timer (rank 9, lowest) | Everything else, even Caps Lock or Update, still wins over the call HUD. | |
| High priority, near Charging/Device | A live call preempts Focus/OSD/Download/CapsLock/Update/Timer; only Charging/Device outrank it. | ✓ |
| You decide | Claude picks a sensible rank during planning based on codebase precedent. | |

**User's choice:** High priority, near Charging/Device.
**Notes:** New rank slot lands directly after `.device`, before `.focus`, resolving the "rank TBD" comment already reserved in `IslandResolver.swift:88`.

---

## Trigger sensitivity

| Option | Description | Selected |
|--------|-------------|----------|
| Immediate | HUD appears the instant mic-active + app-running is detected. | ✓ |
| Short debounce (few seconds) | Mic must stay active for a few seconds before the HUD appears. | |
| You decide | Claude picks a sensible debounce during the spike. | |

**User's choice:** Immediate.
**Notes:** Accepted the false-positive risk research flagged (e.g. testing mic in Zoom's own settings) as a known tradeoff.

**Follow-up — hide/dismiss symmetry:**

| Option | Description | Selected |
|--------|-------------|----------|
| Disappear immediately | Symmetric with the immediate-show choice. | ✓ |
| Brief lingering dismiss (~1-2s) | Matches Caps Lock/Charging's auto-dismiss grace window. | |

**User's choice:** Disappear immediately.

---

## Collapsed interaction

| Option | Description | Selected |
|--------|-------------|----------|
| Inline tap on the collapsed pill | Mic icon directly tappable to mute/unmute, no expand needed. | ✓ |
| Tap expands, then tap mute inside | Tapping expands (Timer's Pattern 4), second tap mutes. | |

**User's choice:** Inline tap on the collapsed pill.
**Notes:** First collapsed HUD in the codebase with an actual tap target — requires new hot-zone-widening work in planning.

**Follow-up — tap-elsewhere behavior:**

| Option | Description | Selected |
|--------|-------------|----------|
| Collapsed-only, always | No expanded view exists at all. | ✓ |
| Tap-elsewhere also expands | Mirrors Timer's dual collapsed+expanded behavior. | |

**User's choice:** Collapsed-only, always.

---

## Visual design

**Call-active icon:**

| Option | Description | Selected |
|--------|-------------|----------|
| Video camera icon | SF Symbol video.fill. | |
| Phone/call icon | SF Symbol phone.fill. | |
| You decide | Claude picks during UI-spec. | ✓ |

**User's choice:** You decide.

**Mute-button visual state:**

| Option | Description | Selected |
|--------|-------------|----------|
| Icon swap only (mic / mic.slash) | Same accent color throughout. | |
| Icon swap + color signal (red when muted) | Extra at-a-glance signal, matches Zoom/Teams/FaceTime convention. | |
| You decide | Claude picks during UI-spec. | ✓ |

**User's choice:** You decide.

**Timer format for long calls:**

| Option | Description | Selected |
|--------|-------------|----------|
| mm:ss always, rolls past 59:59 | Consistent with Timer's existing format. | ✓ |
| Switch to h:mm:ss past 1 hour | More readable for long meetings, needs new formatting branch. | |

**User's choice:** mm:ss always, rolls past 59:59.

---

## Claude's Discretion

- Exact SF Symbol for the call-active icon.
- Exact mute-button visual treatment (icon-only vs. icon+color).
- Spike methodology and go/no-go criteria for the detection heuristic.
- Exact `.meeting` case wiring into the already-generalized `ActiveTransient.isPersistent`/`TransientQueue.preempt()`.

## Deferred Ideas

None — discussion stayed fully within phase scope.
