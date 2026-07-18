---
phase: 39-volume-brightness-hud
plan: 08
subsystem: notch-osd-suppression-gap-closure
tags: [cgeventtap, cghideventtap, coreaudio, displayservices, self-drive, go-no-go, hud]
dependency-graph:
  requires: [39-01-suppression-unreliable-spike, 39-03-osd-interceptor, 39-07-osd-wing-layout]
  provides: [osd-suppression-confirmed-working, self-driven-volume-brightness-mute, snappier-osd-fill-animation]
  affects: [40-update-available-hud, future-cgeventtap-work]
tech-stack:
  added: []
  patterns: [dual-mode-cgeventtap-with-per-type-kill-switch, self-drive-before-onKeyPress]
key-files:
  created: []
  modified:
    - Islet/Notch/OSDInterceptor.swift
    - Islet/Notch/VolumeReader.swift
    - Islet/Notch/BrightnessReader.swift
    - Islet/Notch/NotchWindowController.swift
    - Islet/Notch/NotchPillView.swift
decisions:
  - "Go/no-go: SUCCESS — .cghidEventTap (HID-level, before Window Server session layer) suppresses the native macOS volume/brightness OSD on this machine/macOS Tahoe, reversing 39-01's suppression-unreliable finding for .cgSessionEventTap. Zero transport-key irregularities across all 8 on-device UAT steps. No rollback needed."
metrics:
  duration: "~5 min (Tasks 1-3, code+build) + on-device checkpoint"
  completed: 2026-07-18
---

# Phase 39 Plan 08: OSD Suppression Re-Attempt (.cghidEventTap) + Self-Drive + Animation Retune Summary

Re-attempted native OSD suppression using `.cghidEventTap` instead of the already-failed `.cgSessionEventTap` (D-14), self-drove the real system volume/brightness/mute value via CoreAudio/DisplayServices so a suppressed key press still has a real effect (D-15), and retuned `OSDLevelBar`'s fill spring for a snappier single-press feel (D-16). **Confirmed working on real hardware — the native OSD is now genuinely suppressed, with zero transport-key regressions.**

## Go/No-Go Result (Task 4 On-Device Checkpoint)

**Outcome: APPROVED — suppression confirmed working.**

All 8 verification steps passed clean on real hardware, user-reported "approved — all 8 verification steps clean, zero transport-key irregularities":

1. Settings toggle "Replace System Volume/Brightness OSD" turned on, Accessibility granted, status hint read "Active."
2. **BLOCKER CHECK passed**: all 4 media transport keys (Play/Pause, Next, Previous, Fast-Forward/Rewind) registered correctly on every press, mixed order, system-wide — zero missed presses, zero double-triggers, zero unresponsiveness.
3. Single non-held Volume Up/Down presses: native OSD did NOT appear; Islet's own HUD appeared reflecting the real level; fill visibly snapped faster than before.
4. Mute: real system audio muted/unmuted, icon swapped to muted glyph, bar fully drained.
5. Brightness Up/Down: native OSD did NOT appear, real screen brightness changed, HUD bar reflected it.
6. Held-key scrubbing: same HUD instance updated in place, no stacking/flicker, 1.5s auto-dismiss re-armed on every press.
7. Toggle OFF: native OSD returned (`.detectOnly` fallback confirmed). Toggle back ON: suppression resumed without relaunch (D-07 mid-session upgrade confirmed).

This **reverses** 39-01's `suppression-unreliable` finding: the difference is the tap TYPE (`.cghidEventTap`, HID-level, before the Window Server session layer) rather than `.cgSessionEventTap` (session-level) — `dannystewart/volumeHUD`'s proven technique. No rollback was needed; the blocker rollback procedure in the plan was never triggered.

## What Shipped

- **`Islet/Notch/OSDInterceptor.swift`** — rebuilt as a dual-mode interceptor: private `TapMode { detectOnly, detectAndSuppress }` and `RawOSDKey` enum (replacing the old two `Set<Int>` constants, same 39-01-confirmed decode values). `desiredMode()` returns `.detectAndSuppress` only when both the Settings toggle and Accessibility are true, else `.detectOnly` — mirrors the prior safe default. `installTap(mode:)` creates the tap with `tap: .cghidEventTap` (never `.cgSessionEventTap` again) and `.defaultTap`/`.listenOnly` per mode. `reconcileMode()` (replacing the old `checkHealthAndReinstallIfNeeded()`) now also installs a never-yet-installed tap and live-upgrades/downgrades mode mid-session (D-07, both directions). Per-type kill switches `volumeSelfDriveWorking`/`brightnessSelfDriveWorking` (reset `true` on every `start()`) gate whether a press is actually swallowed; `applySelfDrive(_:)` writes the real system value before `onKeyPress(kind)` runs, flipping the corresponding flag off on any write failure (self-drive falls back to passthrough for that key type for the rest of the session, never leaving keys silently dead).
- **`Islet/Notch/VolumeReader.swift`** — added `adjustSystemVolume(increase:) -> (percent: Int, muted: Bool)?` and `toggleSystemMute() -> (percent: Int, muted: Bool)?`, both via `AudioObjectSetPropertyData` on the same `kAudioHardwareServiceDeviceProperty_VirtualMainVolume`/`kAudioDevicePropertyMute` selectors the existing read path uses. Clamped to `0...1`, quantized to the 1/16 grid, auto-unmute-before-raising / auto-mute-at-zero to mirror native OSD behavior. Any failed Get/Set aborts the whole adjustment (returns `nil`), never partially applies.
- **`Islet/Notch/BrightnessReader.swift`** — added `adjustBrightness(increase:) -> Int?`, resolving `DisplayServicesSetBrightness`/`DisplayServicesCanChangeBrightness` from the SAME already-loaded `DisplayServices.framework` bundle handle (no second dlopen). Gated on `DisplayServicesCanChangeBrightness` before any write attempt (never drives a display that reports it can't be changed this way).
- **`Islet/Notch/NotchWindowController.swift`** — `startOSDInterceptor()` now passes its own existing `brightnessReader` instance into `OSDInterceptor(...)`.
- **`Islet/Notch/NotchPillView.swift`** — `OSDLevelBar`'s fill spring retuned `response: 0.35 → 0.15`, `dampingFraction: 0.75 → 0.86` (D-16), addressing the user-reported perceived delay on a single non-held key press. Header comment updated to record both the original D-04 decision and this retune.

## Task Commits

1. **Task 1** (VolumeReader/BrightnessReader write paths): `15d5fc1`
2. **Task 2** (OSDInterceptor dual-mode rewrite + controller wiring): `6aca10b`
3. **Task 3** (OSDLevelBar animation retune): `5c6dd6a`
4. **Task 4** (on-device checkpoint): no code changes — approved as-is

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Acceptance-criteria greps required literal-string-clean comments**
- **Found during:** Task 2 and Task 3 acceptance-criteria verification
- **Issue:** The plan's own grep acceptance criteria (`grep -n "cgSessionEventTap" ... reports zero matches`, `grep -n "response: 0.35" ... reports zero matches`) initially failed because explanatory comments referenced the old values/API by name (standard practice for "what changed and why" documentation).
- **Fix:** Reworded the comments to describe the change without using the literal old-value strings (e.g. "39-01's original session-level tap" instead of naming `.cgSessionEventTap`; dropped the literal `response: 0.35` from prose). No functional code changed.
- **Files modified:** `Islet/Notch/OSDInterceptor.swift`, `Islet/Notch/NotchPillView.swift`
- **Commits:** folded into `6aca10b` and `5c6dd6a` respectively (fixed before each task's commit, not a separate commit)

None of the deviations altered architecture or the go/no-go outcome.

## Known Stubs

None.

## Self-Check: PASSED

- FOUND: Islet/Notch/OSDInterceptor.swift
- FOUND: Islet/Notch/VolumeReader.swift
- FOUND: Islet/Notch/BrightnessReader.swift
- FOUND: Islet/Notch/NotchWindowController.swift
- FOUND: Islet/Notch/NotchPillView.swift
- FOUND: commit 15d5fc1 (git log --oneline --all)
- FOUND: commit 6aca10b (git log --oneline --all)
- FOUND: commit 5c6dd6a (git log --oneline --all)

## Next Phase Readiness

Phase 39 (HUD-03, HUD-04) is now fully shipped with native OSD suppression genuinely working (not just showing alongside the native OSD, per the originally-accepted fallback) — the last open item from the 39-CONTEXT.md gap-closure addendum (D-14/D-15/D-16) is closed. Ready for `/gsd-discuss-phase 40` (Update-Available HUD & Sparkle Integration).
