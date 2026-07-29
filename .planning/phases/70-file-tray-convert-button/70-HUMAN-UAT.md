---
status: partial
phase: 70-file-tray-convert-button
source: [70-VERIFICATION.md]
started: 2026-07-30T02:00:00Z
updated: 2026-07-30T02:00:00Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. Format-tile stage self-heals if abandoned (CR-01 fix)
expected: Drag an image onto Convert (format tiles appear), then move the mouse away and do nothing — do NOT click anywhere in the picker card. Within a few seconds (~3-4s after the pointer last leaves the card), the island should auto-collapse on its own, exactly like it does for every other picker/expanded state you walk away from. It should not stay stuck open indefinitely.
result: [pending]

## Summary

total: 1
passed: 0
issues: 0
pending: 1
skipped: 0
blocked: 0

## Gaps
