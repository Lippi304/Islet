---
status: partial
phase: 36-cosmetic-restyles-signature-animation
source: [36-VERIFICATION.md]
started: 2026-07-16T21:13:55Z
updated: 2026-07-16T21:13:55Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. Tap registration on the widened "Charging"/"Connected" wing labels
expected: Code review (36-REVIEW.md, WR-02) found that `NotchWindowController`'s click-through `hotZone` was never widened to match Plan 36-01's new `wingsLabelWidth` (label text now extends to ~200pt half-width vs. the hot-zone's existing ~99pt). Tap directly on the "Charging" or "Connected" label text (not just the icon) while the wing is showing that label, and confirm the tap correctly expands the island rather than passing through to whatever app/window sits behind the notch at that screen position.
result: [pending]

## Summary

total: 1
passed: 0
issues: 0
pending: 1
skipped: 0
blocked: 0

## Gaps
