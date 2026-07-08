# Phase 15: Architecture Refactor — Mechanical Fixes & DI Seams - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-08
**Phase:** 15-architecture-refactor-notchwindowcontroller-notchpillview-de
**Areas discussed:** Phase sequencing, Bug-fix inclusion, Coordinator scope

---

## Phase sequencing

| Option | Description | Selected |
|--------|-------------|----------|
| Split into two phases | Phase 15 = low-risk mechanical fixes. Phase 16 = the NotchWindowController coordinator split alone, isolated for easier verification. | ✓ |
| One phase, sequenced waves | Everything in one phase, ordered mechanical-first/coordinator-last. | |

**User's choice:** Split into two phases.
**Notes:** Phase 15 was originally created (via `/gsd-phase add`) with a title spanning both the mechanical fixes and the NotchWindowController/NotchPillView decomposition; rescoped to mechanical-fixes-only after this decision, with Phase 16 added separately for the coordinator work.

---

## Bug-fix inclusion

| Option | Description | Selected |
|--------|-------------|----------|
| Include both, call them out explicitly | EqualizerBars re-render bug and the discarded Polar license payload are both included, flagged as explicit exceptions to the phase's zero-behavior-change default. | ✓ |
| Exclude both, pure refactor only | File both as separate `/gsd-quick` tasks instead. | |

**User's choice:** Include both, call them out explicitly.
**Notes:** Both already have a verified-shape fix from this session's audit work.

---

## Coordinator scope

| Option | Description | Selected |
|--------|-------------|----------|
| All four now | Extract Charging/Device/NowPlaying/Outfit coordinators together in one pass. | |
| Device first | Extract only DeviceCoordinator — highest documented risk, proves the pattern before repeating it. | ✓ |

**User's choice:** Device first.
**Notes:** This decision applies to Phase 16 (not yet planned), captured here so Phase 16's discuss-phase doesn't need to re-litigate it. Charging/NowPlaying/Outfit coordinators become a future phase pending Phase 16's on-device verification landing clean.

---

## Claude's Discretion

- Wave ordering of the 7 items within Phase 15's plan.
- Whether the two behavior-changing items (EqualizerBars, Polar payload) get their own dedicated wave or are folded into their nearest sibling's wave.

## Deferred Ideas

- NotchWindowController full coordinator extraction (Charging/NowPlaying/Outfit) — future phase after Phase 16.
- Full Clean Architecture (Domain/Data/Presentation) folder restructuring — explicitly rejected earlier this session as disproportionate for this app's size.
- Duplicated Keychain read-once-cache boilerplate (TrialManager/LicenseManager) — not bundled into this phase.
- Naming clarity across the three "License*" types — not bundled into this phase.
- Magic-number sprawl in NotchPillView.swift (no Constants/Layout enum) — not bundled into this phase.
