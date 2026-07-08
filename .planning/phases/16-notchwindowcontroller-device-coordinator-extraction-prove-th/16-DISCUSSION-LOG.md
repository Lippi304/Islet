# Phase 16: NotchWindowController Device Coordinator Extraction - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-08
**Phase:** 16-notchwindowcontroller-device-coordinator-extraction-prove-th
**Areas discussed:** Extraction boundary, Protocol foresight, Verification rigor

---

## Extraction boundary

| Option | Description | Selected |
|--------|-------------|----------|
| Controller keeps monitor | Matches ROADMAP's literal field/method list (no BluetoothMonitor mentioned); controller keeps owning all monitors and injects readings into logic, per established pattern. | ✓ |
| Coordinator owns the monitor too | Fuller extraction — coordinator wraps BluetoothMonitor's start()/stop() entirely. | |
| You decide | Let Claude pick based on smallest diff. | |

**User's choice:** Controller keeps monitor (recommended)
**Notes:** None.

---

## Protocol foresight

| Option | Description | Selected |
|--------|-------------|----------|
| Narrow, Device-only | Roadmap explicitly calls this a deliberate first slice; designing for hypothetical future coordinators risks guessing wrong. | ✓ |
| Generic now | Sketch the protocol to fit all 4 future coordinators upfront. | |
| You decide | Let Claude decide during planning. | |

**User's choice:** Narrow, Device-only (recommended)
**Notes:** None.

---

## Verification rigor

| Option | Description | Selected |
|--------|-------------|----------|
| Full on-device checklist | Reconnect flap, launch-grace window, disconnect edge, battery-poll promotion — highest-risk, most-race-prone activity type in the app. | ✓ |
| Unit tests + spot-check | Faster; relies on existing 18-file test suite plus one manual connect/disconnect. | |

**User's choice:** Full on-device checklist (recommended)
**Notes:** None.

---

## Claude's Discretion

- Exact `ActivityCoordinator` protocol method signatures and how the coordinator reports queue changes back to the controller.
- Whether `DeviceCoordinator` receives `TransientQueue`/render/visibility access via closures, delegate, or a narrow protocol.
- Structure of `DeviceCoordinatorTests.swift`.

## Deferred Ideas

- Charging/NowPlaying/Outfit coordinators — future phase, gated on this phase landing clean.
- Moving `BluetoothMonitor` ownership into the coordinator — explicitly rejected for this phase.
