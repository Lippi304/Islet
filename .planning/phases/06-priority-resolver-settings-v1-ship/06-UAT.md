---
status: complete
phase: 06-priority-resolver-settings-v1-ship
source: [06-01-SUMMARY.md, 06-02-SUMMARY.md, 06-03-SUMMARY.md, 06-04-SUMMARY.md, 06-05-SUMMARY.md]
started: 2026-07-01T00:41:22Z
updated: 2026-07-01T00:55:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Priority Resolver — Charging Beats Ambient, Then Yields Back
expected: Play music (Now Playing wings showing). Plug in the charger. A charging splash briefly wins (~3s), then the island returns to the media wings — not the bare black pill.
result: issue
reported: "Die Beiden breiten passen nicht also es ist nicht so schön das quasi beide Musik Symbole verschwinden und das dann halt die notch breiter wird und dann tauchen da die Symbole auf also kein smoother übergang."
severity: minor

### 2. Device Connect/Disconnect Splash + Battery
expected: Connect a Bluetooth audio device (e.g. headphones). A transient splash shows the device connecting, including its battery percentage if reported. Disconnecting shows a corresponding disconnect splash.
result: pass

### 3. Settings — Live Toggle + Persistence
expected: Open Settings, turn OFF "Charging". Plug/unplug the charger — no splash appears. Turn it back ON — splash returns. Quit and relaunch the app — your toggle choices are remembered.
result: pass

### 4. Accent Color — Tints Only Lively Elements
expected: In Settings, pick a different accent swatch. The charging battery glyph and the Now-Playing equalizer bars pick up the new color. The black island shape itself and the expanded transport buttons stay untinted.
result: issue
reported: "equalizer bars pass aber beim Akku nix geändert an Farbe."
severity: major

### 5. Fullscreen Gate Still Holds
expected: Enter true fullscreen (e.g. a fullscreen video) while an activity would normally splash. The island stays hidden — it does not pop over the fullscreen app.
result: issue
reported: "immernoch der kleien mini flash wenn man mit der Slide animaiton zum Fullscreen kommt das dann der kurze nochmal flash kommt."
severity: cosmetic
note: Matches the previously known Phase-2 (02-04) root cause — a ~1-frame island flash at the END of the fullscreen-ENTER transition, caused by the window server compositing the all-Spaces panel onto the activating fullscreen Space. Product-deferred at the time; a show-debounce fix was tried and reverted (nothing to debounce). Still present, not a new Phase-6 regression.

### 6. v1 Ship — Now Playing Health Check (D-16)
expected: On the current macOS build, Now Playing shows title/artist/art and the transport controls (play/pause/skip) work — confirming the launch-time health check passed, not the "nicht verfügbar" fallback.
result: pass
note: Confirmed earlier in this session — healthy on macOS 27.0 (26A5368g), Now Playing info displayed and transport controls worked.

## Summary

total: 6
passed: 3
issues: 3
pending: 0
skipped: 0
blocked: 0

## Gaps

- truth: "After a charging splash yields back to the Now-Playing wings, the transition should be a smooth width morph (matchedGeometryEffect), not an abrupt resize with the media symbols popping in afterward"
  status: failed
  reason: "User reported: Die Beiden breiten passen nicht also es ist nicht so schön das quasi beide Musik Symbole verschwinden und das dann halt die notch breiter wird und dann tauchen da die Symbole auf also kein smoother übergang."
  severity: minor
  test: 1
  artifacts: []
  missing: []

- truth: "Picking a different accent swatch in Settings should tint the charging battery indicator's color, same as it tints the Now-Playing equalizer bars"
  status: failed
  reason: "User reported: equalizer bars pass aber beim Akku nix geändert an Farbe."
  severity: major
  test: 4
  artifacts: []
  missing: []

- truth: "Entering true fullscreen while an activity would splash should hide the island with no visible flash"
  status: failed
  reason: "User reported: immernoch der kleien mini flash wenn man mit der Slide animaiton zum Fullscreen kommt das dann der kurze nochmal flash kommt."
  severity: cosmetic
  test: 5
  artifacts: []
  missing: []
  root_cause: "Likely the known Phase-2 (02-04) window-server compositing flash at the end of the fullscreen-ENTER transition — previously product-deferred, a show-debounce fix was tried and reverted since there was nothing to debounce. Re-diagnose to confirm before assuming it's identical."
