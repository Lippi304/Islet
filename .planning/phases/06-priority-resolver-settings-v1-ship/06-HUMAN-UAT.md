---
status: partial
phase: 06-priority-resolver-settings-v1-ship
source: [06-VERIFICATION.md]
started: 2026-07-02T01:20:00Z
updated: 2026-07-02T01:20:00Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. 06-07 gap-closure on-device checks (nil-address splash, dismiss-timer re-arm, second-device battery)
expected: Toggling Now Playing off after "nicht verfügbar" shows plain idle date/time; connecting a device then quickly plugging in the charger gives the device splash a fresh ~3s window after charging yields; connecting two BT devices in succession shows each its OWN correct battery %.
result: [pending]

### 2. 06-08 gap-closure on-device checks (health-gate stability, paused-media hover-pause)
expected: Playing music continuously 30+s while expanding/collapsing never shows "nicht verfügbar". Pausing playback, expanding, and hovering the transport controls past 15s keeps the paused glance visible under the pointer.
result: [pending]

### 3. 06-10 gap-closure on-device checks (transport-button tap isolation)
expected: Rapidly tapping play/pause/next/previous in the expanded media view only triggers its own action, never also collapses/toggles the island; the collapsed pill, wing glances, expanded idle view, and "unavailable" message still all toggle as before.
result: [pending]

### 4. Settings window live visual behavior (toggle-driven monitor lifecycle + accent re-tint)
expected: Flipping each of the three activity toggles off/on actually starts/stops the corresponding monitor (e.g. toggling Charging off makes a plug-in event produce no splash); picking a different accent swatch re-tints the battery indicator, equalizer bars, and device glyph immediately without an app restart. Note: watch specifically for a visible flash/reset of the island (and equalizer bar reshuffle) at the moment the accent swatch is changed, not just whether the new color eventually appears (06-REVIEW.md WR-02).

## Summary

total: 4
passed: 0
issues: 0
pending: 4
skipped: 0
blocked: 0

## Gaps
