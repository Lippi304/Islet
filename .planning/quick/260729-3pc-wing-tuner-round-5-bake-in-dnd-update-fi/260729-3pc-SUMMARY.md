---
phase: quick-260729-3pc
plan: 01
subsystem: notch-wings-ui
tags: [swiftui, wing-tuner, charging-wing, device-wing, focus-wing, update-wing]
requires: []
provides:
  - Round-5 tuned DND/Focus + Update wing base constants (nudge=0 now reproduces the tuning session)
  - Charging wing redesigned to plain-white plug icon + white BatteryIndicator (no green, no text)
  - Device wing redesigned to fixed plain-white Bluetooth-style icon + white BatteryIndicator
affects:
  - Islet/Notch/NotchPillView.swift
tech-stack:
  added: []
  patterns:
    - "Baking in on-device-tuned Wing Tuner deltas into base literals (same pattern as rounds 2-4)"
    - "Collapsing per-variant conditional styling (icon color/width) to a single fixed value when a redesign removes the need for the distinction"
key-files:
  created: []
  modified:
    - Islet/Notch/NotchPillView.swift
decisions:
  - "Charging and Device wings both go fully white/gray (no green anywhere) per the user's explicit repeated 'in white' request and the reference image — chargingAccent/deviceAccent environment properties are left declared but now unused by these two wings (flagged, not removed — cross-file Settings mechanism out of scope)"
  - "Device wing's per-device-type icon (AirPods/AirPods Pro/AirPods Max/Beats/generic) collapsed to one fixed dot.radiowaves.left.and.right glyph — closest available 'Bluetooth icon' since Apple has no literal Bluetooth-logo SF Symbol for third-party apps; deviceSymbol(for:) deleted as now-dead code"
metrics:
  duration: ~20min
  completed: 2026-07-29
---

# Quick Task 260729-3pc: Wing Tuner Round 5 Summary

Baked in the user's final tuned deltas for the DND/Focus and Update wings, then redesigned the
Charging and Device wings to a minimal white-on-black look (plain white icon left, plain white
`BatteryIndicator` right, no colored icons or text) per the user's first on-device look at the
Charging wing and an explicit reference image.

## What Was Built

**Task 1 — Baked in round-5 tuned deltas (`01336d3`):**
- `focusWings(for:)`: `margin` 0 → 20, `leadingPad` 14 → 18, `trailingPad` 20 → 16 (gap unchanged, delta 0)
- `updateWings(for:)`: `leadingPad` base 8 → 12, `trailingPad` base 8 → 12 (margin/labelWidth unchanged, delta 0)
- Debug build: BUILD SUCCEEDED

**Task 2 — Charging wing redesign (`d45383e`):**
- Removed the green `bolt.fill` icon and conditional "Charging" text entirely
- Left flank: single fixed `powerplug.fill` icon, plain white, unconditional width (no more isCharging-based leftWidth ternary)
- Right flank: `BatteryIndicator` accent switched from `chargingAccent` (theme color) to `.white`
- Debug build: BUILD SUCCEEDED

**Task 3 — Device wing redesign + dead-code removal (`bfa1635`):**
- `deviceWings(for:)`: dropped the unused `glyph`/`let g` bindings; icon is now a single fixed `dot.radiowaves.left.and.right` glyph in plain white (`iconOpacity` disconnected-dimming unchanged) instead of the per-device-type `deviceSymbol(for: glyph)` lookup in `deviceAccent`
- `deviceTrailing(isConnected:battery:)`: `BatteryIndicator(level: battery)` (implicit default green) → `BatteryIndicator(level: battery, accent: .white)`; the connected-without-battery green ring and disconnected xmark branches are untouched
- Deleted `deviceSymbol(for:)` entirely — repo-wide grep reconfirmed its only call site was the one removed above; `DeviceGlyph` and its classification tests are untouched
- Debug build: BUILD SUCCEEDED
- Release build: BUILD SUCCEEDED (this round touches production UI code, verified per the plan's extra requirement)

## Deviations from Plan

None — plan executed exactly as written. All three tasks' target code was copied verbatim from
the plan's `<interfaces>` section; verified-live line numbers matched the actual file before each edit.

## Flagged Interpretation Choices (carried into the pending checkpoint)

1. **No green anywhere on either wing.** Both the Charging plug icon and Device Bluetooth-style
   icon, plus both `BatteryIndicator`s, are now plain white — matching the reference image (zero
   colored icons) and the majority of the user's request ("in weiß" x3). The Settings "Charging"
   and "Device" accent swatches (`ActivitySettings.chargingAccent`/`deviceAccent`) no longer have
   any visible effect on these two wings. If the user actually wanted a green tint somewhere
   (e.g. a small badge), that's a cheap follow-up round — not built speculatively here.
2. **Device wing's per-device-type icon distinction is gone.** AirPods / AirPods Pro / AirPods Max
   / Beats / generic-headphones now all render the identical `dot.radiowaves.left.and.right`
   glyph, chosen because Apple exposes no literal Bluetooth-logo SF Symbol to third-party apps.
   Flagged as an easy follow-up if per-device icons should return.

## Checkpoint Pending (not executed by this agent)

The plan's final task (`checkpoint:human-verify`, gate=blocking) requires the user to run the app
on real hardware via Xcode (Cmd-R), open the Wing Tuner debug menu, and preview all 4 affected
wings (Focus, Update, Charging, Device) plus confirm the "no green anywhere" interpretation choice.
This was intentionally **not** executed — it requires the actual user on real hardware and cannot
be automated. See `260729-3pc-PLAN.md`'s final task for the full 7-step verification checklist and
resume signal.

## Self-Check: PASSED

- `Islet/Notch/NotchPillView.swift` exists and contains all expected changes (verified via grep during execution: `CGFloat = 20 + wingMarginNudge`, `CGFloat = 18 + wingLeadingNudge`, `CGFloat = 16 + wingTrailingNudge`, `12 * wScale + wingLeadingNudge`, `powerplug.fill`, `BatteryIndicator(level: percent, accent: .white)`, `dot.radiowaves.left.and.right`, `BatteryIndicator(level: battery, accent: .white)`; zero occurrences of `bolt.fill`, `Text("Charging")`, `func deviceSymbol`)
- Commits `01336d3`, `d45383e`, `bfa1635` all found in `git log --oneline`
- Debug build succeeded after each task; Release build succeeded after Task 3
