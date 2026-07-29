---
phase: quick-260729-2td
plan: 01
subsystem: notch-wing-geometry
tags: [wing-tuner, focus-wing, device-wing, charging-preview, update-wing, timer-preview]
dependency-graph:
  requires: [quick-260729-0zh, quick-260729-0b5, quick-260728-wg7]
  provides: [wing-tuner-round-4-baseline, focus-device-margin-mechanism]
  affects: [NotchPillView.swift wing geometry, NotchWindowController.swift debug preview tooling, AppDelegate.swift debug preview actions]
tech-stack:
  added: []
  patterns: [notch-cutout-derived margin+cameraBlockWidth formula applied uniformly to focusWings/deviceWings]
key-files:
  created: []
  modified:
    - Islet/Notch/NotchPillView.swift
    - Islet/Notch/NotchWindowController.swift
    - Islet/AppDelegate.swift
decisions:
  - "Baked 5 wings' on-device tuned deltas directly into base literals (nudge=0 now reproduces the tuned result)."
  - "Focus/Device wings migrated from fixed-footprint leftWidth/rightWidth to the same margin+cameraBlockWidth derivation every other wing uses, so Margin nudge finally resizes the visible island on both."
  - "Caps Lock trailingPad floored to 2 (naive delta would be -6) — flagged as a known live-recheck item, not a faithful reproduction of the tuning session."
  - "Charging preview forces a genuine AC-edge transition (fake .onBattery reading before the real charging reading) instead of touching production shouldTriggerSplash logic."
  - "Timer preview bypass added as a new #if DEBUG-only function; real handleStartCountdown(seconds:) keeps its Settings guard completely unchanged."
metrics:
  duration: ~25min
  completed: 2026-07-29
---

# Quick Task 260729-2td: Wing Tuner Round 4 — Bake In Final Tuned Constants Summary

Baked 5 wings' on-device-tuned deltas into their base constants, converted Focus/Device wings onto the shared margin+cameraBlockWidth formula so Margin nudging finally resizes their visible island, and fixed 3 reported debug-preview bugs (Charging never showing, Update label truncated, Timer preview no-op'ing when Settings-disabled).

## Tasks Completed

### Task 1: Bake in round-4 tuned deltas for 5 wings
Commit: `3a8b167`

Applied all 12 base-literal edits from the plan's computed-deltas table to `Islet/Notch/NotchPillView.swift`:
- Now Playing (`mediaWingContentWidth()`): margin 55 -> 5
- OSD (`osdWings(for:)`): margin 55 -> 40, iconLeadingPad 14 -> 24, trailingPad 20 -> 24
- Meeting (`meetingWings(for:)`): leadingPad 16 -> 24, trailingPad 12 -> 20
- Caps Lock (`capsLockWings(for:)`): margin 65 -> 40, iconLeadingPad 12 -> 20, trailingPad 12 -> 2 (naive delta -6 floored to 2, flagged for live recheck)
- Download (`downloadWings(for:)`): margin 20 -> 10, leadingPad 16 -> 20, trailingPad 16 -> 22

Every `+ wing*Nudge` addend, `* wScale`/`* resolvedWingWidthScale` multiplier, downstream formula, and `assert(...)` line left untouched — only the numeric base literal changed, each tagged with a "Quick task 260729-2td Round 4" inline comment.

Verification: Debug build BUILD SUCCEEDED; all 4 automated grep checks passed.

### Task 2: Convert DND (Focus) and Device wings to margin-driven island resize
Commit: `ccc48cc`

Replaced the entire bodies of `focusWings(for activity: FocusActivity)` and `deviceWings(for activity: DeviceActivity)` with the plan's verbatim target implementations — both now derive `leftWidth`/`rightWidth` from a `margin`+`cameraBlockWidth` formula (matching `osdWings`/`capsLockWings`/`mediaWingContentWidth`) instead of holding fixed footprint constants. Both starting margins (Focus: 0, Device: 30) are documented estimates, not live-measured — flagged in-code for on-device re-tuning. No other wing function touched.

Verification: Debug and Release builds both BUILD SUCCEEDED; both grep checks (`"Focus camera block width"`, `"Device camera block width"`) passed.

### Task 3: Fix Charging preview, Update label truncation, Timer preview no-op
Commit: `cf062e1`

- `AppDelegate.swift` `debugPreviewCharging()`: added a first `handlePower(...)` call with an `.onBattery`-mapping reading (`isOnAC: false`) before the existing charging call, forcing a genuine AC-edge transition so `shouldTriggerSplash` reliably detects the fake reconnect regardless of the dev machine's actual current power state. Production logic (`handlePower(_:)`, `powerActivity(from:)`, `shouldTriggerSplash(previous:next:)`) untouched.
- `NotchPillView.swift` `updateWings(for:)`: `labelWidth` widened 38 -> 54; downstream `leftWidth`/`totalWidth`/`rightWidth` pick it up automatically by reference.
- `NotchWindowController.swift`: new `#if DEBUG`-gated `debugPreviewStartCountdown(seconds:)` added inside the existing debug-preview block (alongside `debugCancelPendingDismiss()`/`debugClearAllPreviews()`), mirroring `handleStartCountdown(seconds:)`'s body minus the `activityEnabled(ActivitySettings.timerKey)` Settings guard. `handleStartCountdown(seconds:)` itself is unchanged — real Timer starts still respect the Settings toggle. `AppDelegate.swift` `debugPreviewTimer()` now calls the new bypass function.

Verification: Debug and Release builds both BUILD SUCCEEDED; all 4 automated grep checks passed. Release success also confirms `debugPreviewStartCountdown` compiles out of Release along with the rest of the `#if DEBUG` block.

## Deviations from Plan

None — plan executed exactly as written for all 3 auto tasks. All code snippets, target function bodies, and line references matched the plan's `<interfaces>` section verbatim.

## Checkpoint Status

**Task 4 (`checkpoint:human-verify`, gate=blocking) was NOT executed** — it requires the actual user verifying on real hardware (Preview Wing menu clicks, visual confirmation of each of the 5 baked-in wings, Margin nudge testing on Focus/Device, and confirming the 3 bug fixes work). Per this task's constraints, execution stops here and the checkpoint is reported as pending.

**How to resume:** Open `Islet.xcodeproj`, run the app (Cmd-R, Debug), open the debug menu -> "Wing Tuner" + "Preview Wing", and follow the plan's 11-step verification sequence (`260729-2td-PLAN.md` final task). Resume signal: "approved" or a description of any mismatch.

## Known Flags for the On-Device Checkpoint

- Caps Lock's `trailingPad` (2, floored from a naive -6) is a known, documented deviation from the user's actual tuned value — flagged in-code and in the checkpoint's how-to-verify step 4 for a live recheck/re-bake if it looks wrong.
- Focus wing's `margin` (0) and Device wing's `margin` (30) are both explicit estimates, not live-measured — the checkpoint's steps 6-7 are the first real-hardware test of the new mechanism itself, separate from getting the exact numbers right.

## Self-Check: PASSED

- `Islet/Notch/NotchPillView.swift`: FOUND (modified, all edits present)
- `Islet/Notch/NotchWindowController.swift`: FOUND (modified, `debugPreviewStartCountdown` present)
- `Islet/AppDelegate.swift`: FOUND (modified, both fixes present)
- Commit `3a8b167`: FOUND
- Commit `ccc48cc`: FOUND
- Commit `cf062e1`: FOUND
