# Phase 17: Now Playing Launch Gating - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-09
**Phase:** 17-Now Playing Launch Gating
**Areas discussed:** Manual expand during gate, Gate reset scope, Gate trigger condition

---

## Manual expand during gate

| Option | Description | Selected |
|--------|-------------|----------|
| Idle view (date/weather) | Treat the paused track as invisible everywhere until real playback starts — expanding shows the same expandedIdle view as if nothing were loaded. | |
| Show the paused card | The ambient auto-glance stays hidden, but a deliberate user click to expand still reveals the paused Now Playing card with controls. | ✓ |

**User's choice:** Show the paused card.
**Notes:** Gate only suppresses the ambient auto-show (wings); a deliberate user click to expand reveals the real state. Captured as D-03 in CONTEXT.md.

---

## Gate reset scope

| Option | Description | Selected |
|--------|-------------|----------|
| Never re-arms | Once real playback has been observed once, the gate is permanently open for the rest of the Islet run. | ✓ |
| Re-arms on player quit/switch | If the active player app quits or now-playing drops to none, the gate re-arms. | |

**User's choice:** Never re-arms.
**Notes:** In-memory flag scoped to the Islet process lifetime; resets on next Islet launch. Captured as D-02 in CONTEXT.md.

---

## Gate trigger condition

| Option | Description | Selected |
|--------|-------------|----------|
| Any pre-first-play pause | Nothing playing at launch, then the user opens a player with a paused track before ever pressing Play — still gated. | ✓ |
| Literal first snapshot only | Only the very first snapshot Islet receives at launch is checked; later paused tracks show immediately. | |

**User's choice:** Any pre-first-play pause.
**Notes:** The rule is "no glance until playback has genuinely started once this session," not just "first snapshot at launch." Captured as D-01 in CONTEXT.md.

---

## Claude's Discretion

- Exact mechanism/location for the "has played since launch" flag (NotchWindowController vs. NowPlayingState, and whether it's threaded through `resolve(...)` as a parameter mirroring `nowPlayingHealthGate`) — left to research/planning.

## Deferred Ideas

None — discussion stayed within phase scope.
