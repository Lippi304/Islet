# Phase 47: Audio Output Switcher — Pure Seam + Monitor - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-19
**Phase:** 47-Audio Output Switcher — Pure Seam + Monitor
**Areas discussed:** Device list scope, Non-default sort order, On-device verification scope

---

## Device list scope

| Option | Description | Selected |
|--------|-------------|----------|
| Physical only | Built-in speakers, Bluetooth, wired/USB. Filters out Multi-Output/aggregate/AirPlay. | |
| Match system Sound menu | Include everything macOS's own Sound output picker shows — AirPlay speakers, aggregate/Multi-Output devices too. | ✓ |
| You decide | Claude picks based on simplest-to-build-correctly + research's filter guidance. | |

**User's choice:** Match system Sound menu
**Notes:** None additional.

---

## Non-default sort order

| Option | Description | Selected |
|--------|-------------|----------|
| Alphabetical | Simple, predictable, easy to unit-test. Non-default devices sort A–Z below the pinned default. | ✓ |
| System/stable order | CoreAudio's own enumeration order — not guaranteed stable across reboots/reconnects. | |
| Type-grouped | Group by kind (Built-in, then Bluetooth, then Other/AirPlay), alphabetical within each group. | |

**User's choice:** Alphabetical
**Notes:** None additional.

---

## On-device verification scope

| Option | Description | Selected |
|--------|-------------|----------|
| Just the one Bluetooth headset | Minimum the success criterion requires — built-in + the one headset from research. | |
| Multiple device types | More than one non-built-in output available to test with. | ✓ |

**User's choice:** Multiple device types
**Follow-up:** Which additional types specifically?

| Option | Selected |
|--------|----------|
| Another Bluetooth device | ✓ |
| USB or wired output | ✓ |
| AirPlay speaker | |

**User's choice:** Another Bluetooth device + USB or wired output
**Notes:** Verification plan should cover built-in speakers, two distinct Bluetooth devices, and a USB/wired device — not just the one headset research assumed.

---

## Claude's Discretion

- Whether `AudioOutputMonitor` gets an optional `AudioOutputProviding` protocol for unit-test fakeability.
- Exact unit-test coverage/style for the pure sort/reorder logic (follow existing `NowPlayingPresentation`/`OSDActivity` convention).

## Deferred Ideas

None raised during this discussion. Three pending todos (calendar month-grid polish, quick-action disabled state, click-through disappear) were reviewed via cross-reference but confirmed unrelated to audio-output scope and left in the backlog.
