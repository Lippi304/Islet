---
status: pending
phase: 16-notchwindowcontroller-device-coordinator-extraction-prove-th
source: [16-CONTEXT.md]
started: 2026-07-08T19:09:09Z
updated: 2026-07-08T19:09:09Z
---

## Current Test

[testing in progress]

## Tests

### 1. Reconnect-flap debounce
expected: Connect a real Bluetooth device, then trigger a second connection event for the SAME address within ~3s (e.g. toggle Bluetooth off/on quickly on the peripheral) — confirm only ONE splash fires, not two.
result: pending

### 2. Launch-grace suppression
expected: Have a device already connected BEFORE launching Islet — confirm no splash fires at launch, but a LATER genuine disconnect of that same device still fires a disconnect splash.
result: pending

### 3. Genuine disconnect edge
expected: Disconnect a connected real device — confirm a disconnect splash fires exactly once.
result: pending

### 4. Battery-poll promotion
expected: Connect device A, then connect device B while A's splash still stands (B enqueues behind A) — after A's splash dismisses/advances and B is promoted to head, confirm B's deferred battery percentage still appears (not blank, not A's stale value).
result: pending

## Summary

total: 4
passed: 0
issues: 0
pending: 4
skipped: 0
blocked: 0

## Gaps
