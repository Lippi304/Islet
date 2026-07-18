---
phase: 36-cosmetic-restyles-signature-animation
plan: 1
subsystem: notch-pill-view
tags: [swiftui, hud, charging, bluetooth, droppy-restyle]
requires: []
provides:
  - "Charging wing (HUD-02): left 'Charging' label + bolt icon, shown only while actively charging"
  - "Bluetooth wing (HUD-01): left 'Connected' label + device glyph, shown only while connected"
  - "Bluetooth right-wing green status ring for connected-with-no-battery-known state"
  - "Independent left/right wing-flank sizing (wingsShape leftWidth/rightWidth) so a wide label never stretches the opposite flank"
affects:
  - Islet/Notch/NotchPillView.swift
  - Islet/Notch/NotchWindowController.swift
  - Islet/Notch/PowerActivity.swift
tech-stack:
  added: []
  patterns:
    - "wingsShape(leftWidth:rightWidth:) with an alignmentGuide(.center) override to size each wing flank independently while keeping the notch-center pin point fixed"
    - "Charging classification keys off isOnAC + !isCharged (not the literal IOKit isCharging flag) to account for macOS 'Optimized Battery Charging' throttling"
key-files:
  created: []
  modified:
    - Islet/Notch/NotchPillView.swift
    - Islet/Notch/NotchWindowController.swift
    - Islet/Notch/PowerActivity.swift
    - Islet/Notch/PowerSourceMonitor.swift
    - IsletTests/PowerActivityTests.swift
decisions:
  - "Charging label triggers on AC-connected + not-fully-charged, not the raw IOKit isCharging bit — the literal flag rarely fires true under Optimized Battery Charging."
  - "Only the label-bearing LEFT wing flank widens (145pt -> 200pt half-width) to fit 'Charging'/'Connected' text; the RIGHT flank (battery/ring/xmark) stays fixed at the original half-width regardless of state."
metrics:
  duration: "multi-session, 5 on-device UAT rounds"
  completed: "2026-07-16"
---

# Phase 36 Plan 1: Charging/Bluetooth Droppy-Pill Restyle Summary

Restyled the collapsed Charging (HUD-02) and Bluetooth (HUD-01) wing HUDs to the Droppy visual language — left-wing icon+label shown only in the positive state, and a new fixed-green status ring replacing the checkmark for a connected Bluetooth device with no reported battery level.

## What Shipped

- **Charging wing:** left flank now shows a bolt icon + "Charging" text (`.font(.system(size: 12, weight: .semibold, design: .rounded))`, white) whenever the device is on AC power and not fully charged; the right flank's `BatteryIndicator` is byte-identical to before.
- **Bluetooth wing:** left flank shows the device glyph + "Connected" text under the same styling, only while connected. The right flank is now a 3-way branch: `BatteryIndicator` when a battery level is known, a fixed `Color.green` `Circle().strokeBorder(lineWidth: 1.5)` ring when connected with no battery reported, and the unchanged dimmed xmark when disconnected.
- **Independent flank sizing:** `wingsShape` now takes `leftWidth`/`rightWidth` instead of one shared width, with an `alignmentGuide(.center)` override pinning the notch-center point at `leftWidth` from the leading edge. The label-bearing left flank grows to `wingsLabelWidth / 2` (200pt) only while its label is shown; the right flank stays at the original `wingsSize.width / 2` (145pt) always.

## Commits (chronological)

| Commit | Type | Description |
|--------|------|-------------|
| `7d56c42` | feat | Charging wing restyle — left icon+label HStack, `Text("Charging")` gated on `isCharging` (Task 1) |
| `ea661dc` | feat | Bluetooth wing restyle — left icon+label HStack, `Text("Connected")` gated on `isConnected`; 3-way `deviceTrailing` branch incl. green ring (Task 2) |
| `32ce3d7` | fix | First fix attempt for "Charging" text never appearing — assumed an IOKit connect-edge timing race, added a 0.6s settle re-poll. Did not fix the underlying issue. |
| `8fcf7fd` | debug | Added temporary `[36-01-DEBUG]` diagnostic logging across the power-source read → classification → view-body pipeline after two guess-based fixes failed, to get ground-truth on-device data instead of guessing a third time. |
| `3871ba4` | debug | Removed the diagnostic logging once the root cause was identified from the trace. |
| `bf99ad0` | fix | Real root-cause fix — `powerActivity(from:)` now classifies `.charging` vs `.full` off `isOnAC && !isCharged` instead of the raw `kIOPSIsChargingKey`, which stays `false` for an entire AC session under macOS's Optimized Battery Charging. Removed the now-unneeded 0.6s settle re-poll from `32ce3d7`. Updated `PowerActivityTests`. |
| `77ecd18` | fix | Layout bug found after the label started appearing — text clipped to "Char.." because the wings pill is centered over the physical notch cutout (~179pt visible vs. 290pt total strip). Widened the whole pill to a new `wingsLabelWidth` (400pt) while a label is shown. |
| `49133c2` | fix | Design refinement per user request — only the LEFT flank should grow for its label; the RIGHT flank (battery/ring/xmark) should stay compact. Reworked `wingsShape` to take independent `leftWidth`/`rightWidth` via an `alignmentGuide` override. |

Final on-device approval ("Passt") confirmed via screenshot: left wing shows a green bolt icon + fully legible "Charging" text; right wing shows the battery percentage sitting tight against the notch, not stretched out.

## Deviations from Plan

This plan required 5 rounds of on-device checkpoint rejection/remediation before approval — documented here for reviewer context, not as scope creep. All changes stayed within Task 3's own on-device human-verify checkpoint (no plan re-scoping, no new requirements).

**1. [Round 1 — wrong root-cause guess] "Charging" text never appeared at all**
- **Found during:** first on-device test of Tasks 1-2's code.
- **Issue:** the label looked identical to the pre-plan icon-only state; assumed an IOKit connect-edge timing race.
- **Fix attempted:** added a 0.6s settle re-poll (`32ce3d7`). Did not fix it — user re-tested at a lower battery % and confirmed it still failed.
- **Files:** `Islet/Notch/NotchWindowController.swift`.

**2. [Round 2 — diagnostic-first, not another guess] Instrumented instead of guessing again**
- **Found during:** second rejection.
- **Action:** added temporary `[36-01-DEBUG]` print tracing across `PowerSourceMonitor.readCurrentPower()`, `NotchWindowController.handlePower()`, and `NotchPillView.wings(for:)` (`8fcf7fd`), then removed it once the root cause was confirmed (`3871ba4`).

**3. [Rule 1 — real bug, root cause] `kIOPSIsChargingKey` stays false under Optimized Battery Charging**
- **Found during:** the user's own on-device debug trace at 96% battery, AC-connected — `kIOPSIsChargingKey=false` persisted for the entire session.
- **Root cause:** macOS's "Optimized Battery Charging" throttles literal charging cycles, so the raw IOKit flag rarely reports `true` even while genuinely plugged in and below 100%.
- **Decision presented to user (Rule 4 — architectural-adjacent classification logic change):** trigger "Charging" on the literal IOKit flag (status quo, broken) vs. on "AC-connected + not fully charged" (new). User chose the latter.
- **Fix:** `bf99ad0` — `powerActivity(from:)` reclassified; `PowerActivityTests` updated to match; the now-unnecessary 0.6s settle re-poll removed.
- **Files:** `Islet/Notch/PowerActivity.swift`, `Islet/Notch/NotchWindowController.swift`, `IsletTests/PowerActivityTests.swift`.

**4. [Rule 1 — real bug, hardware-specific] Label text clipped to "Char.." against the physical notch cutout**
- **Found during:** round after the label started appearing correctly.
- **Root cause:** the 290pt wings strip is centered over the physical camera-notch cutout (~179pt); only ~55pt per flank is actually visible pixels outside the housing. "Charging"/"Connected" needed ~82-100pt of left-flank space, well past that budget.
- **Fix:** `77ecd18` — added `wingsLabelWidth` (400pt) and widened the whole pill to it only while a label is actually shown; the negative/dimmed state keeps the original 290pt.

**5. [Design refinement, user request] Only the label flank should grow, not both**
- **Found during:** final on-device round, after `77ecd18` fixed clipping by widening the WHOLE pill symmetrically.
- **User feedback:** the right flank (battery%/ring/xmark) looked stretched/loose; it should stay tight to the notch regardless of the left flank's label state.
- **Fix:** `49133c2` — reworked `wingsShape` to accept independent `leftWidth`/`rightWidth`, with an `alignmentGuide(.center)` override pinning the notch-center reference point at `leftWidth` so each flank extends outward independently while the pill stays visually centered on the physical notch.

## Auth Gates

None.

## Threat Flags

None — this plan's threat register (T-36-01, T-36-02) already covered the shipped surface (static label strings, boolean-only green ring); no new surface was introduced by the remediation rounds. The `bf99ad0` classification change reads only already-validated `IOPSCopyPowerSourcesInfo()` fields (`isOnAC`, `isCharged`), no new trust boundary.

## Known Stubs

None.

## Self-Check: PASSED

- `Islet/Notch/NotchPillView.swift` — FOUND (read directly, confirmed `Text("Charging")`/`Text("Connected")` gated correctly, `Circle().strokeBorder(Color.green, lineWidth: 1.5)` present, `wingsShape(leftWidth:rightWidth:)` present with `alignmentGuide` override).
- Commit `7d56c42` — FOUND (`git cat-file -e`)
- Commit `ea661dc` — FOUND
- Commit `32ce3d7` — FOUND
- Commit `8fcf7fd` — FOUND
- Commit `3871ba4` — FOUND
- Commit `bf99ad0` — FOUND
- Commit `77ecd18` — FOUND
- Commit `49133c2` — FOUND
- `xcodebuild build -scheme Islet -destination 'platform=macOS'` — BUILD SUCCEEDED (final re-run)
