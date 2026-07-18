---
phase: 39-volume-brightness-hud
plan: 01
subsystem: notch-osd-suppression-spike
tags: [cgeventtap, nx-sysdefined, spike, go-no-go]
dependency-graph:
  requires: []
  provides: [osd-suppression-go-no-go-decision, nx-keytype-decode-constants]
  affects: [39-03-osd-interceptor]
tech-stack:
  added: []
  patterns: [dedicated-CGEventTap-per-fragile-surface, DEBUG-only-throwaway-spike]
key-files:
  created:
    - Islet/Notch/OSDInterceptionSpike.swift
  modified:
    - Islet/AppDelegate.swift
    - Islet.xcodeproj/project.pbxproj
decisions:
  - "Go/no-go: suppression-unreliable — native OSD suppression does not work on this dev machine/macOS Tahoe despite a correct SWALLOWING decode+nil-return; 39-03 must NOT attempt suppression"
metrics:
  duration: "~35 min (incl. on-device checkpoint)"
  completed: 2026-07-17
---

# Phase 39 Plan 01: Dual-Mode CGEventTap Go/No-Go Spike Summary

Confirmed on real hardware that `.cgSessionEventTap` decodes NX_SYSDEFINED volume/brightness keys correctly and never touches the 4 media transport keys in either tap mode, but that `.defaultTap` + returning `nil` from the callback does NOT actually suppress the native macOS volume/brightness OSD on this machine (macOS 26/Tahoe) — final call: **`suppression-unreliable`**.

## What Shipped

- `Islet/Notch/OSDInterceptionSpike.swift` — DEBUG-only throwaway spike (single top-level `#if DEBUG`/`#endif`, verified `grep -c "^#if DEBUG"` = 1), `final class OSDInterceptionSpike` with `SpikeMode { detectOnly, detectAndSuppress }`, mirroring `DropInterceptTap.swift`'s `AXIsProcessTrustedWithOptions` → `CGEvent.tapCreate` → `CFMachPortCreateRunLoopSource` → 5s health-check-timer lifecycle. `.detectOnly` skips the Accessibility request entirely and uses `.listenOnly`; `.detectAndSuppress` requests Accessibility and uses `.defaultTap`.
- `Islet/AppDelegate.swift` — two new DEBUG-only debug-menu items ("OSD Spike: Start Detect-Only" / "OSD Spike: Start Detect+Suppress"), each lazily constructing and starting its own spike instance, menu-triggered only (never auto-started).
- Release build verified to contain zero spike code (Release `BUILD SUCCEEDED`, which requires the `AppDelegate`'s own `#if DEBUG`-gated references to `OSDInterceptionSpike` to also compile out cleanly — confirms the whole feature is genuinely DEBUG-only).

## On-Device Checkpoint Results (Task 2)

### Detect-Only (`.listenOnly`, no Accessibility request)

- `tapCreate` succeeded (non-nil). No permission dialog was observed.
- **Open/inconclusive:** this dev machine already has Accessibility granted to Islet from the pre-existing `DropInterceptTap`/drag-and-drop feature — "no dialog appeared" is therefore NOT solid evidence that `.listenOnly` on `.cgSessionEventTap` for `NX_SYSDEFINED` works *without* Accessibility (RESEARCH.md Open Question 2 / Assumption A2 stays **unresolved** by this spike, not confirmed either way — a genuinely Accessibility-denied machine would be needed to settle it).
- All decoded key codes (`0, 1, 2, 3, 16`) printed `PASSTHROUGH` — never swallowed anything, confirming detect-only is safe by construction.

### Detect+Suppress (`.defaultTap`, Accessibility requested)

- `tapCreate` succeeded. User confirmed this mode was explicitly active.
- Console correctly showed `SWALLOWING` on `keyDown=true` for codes `0, 1, 2, 3, 7` — matching Assumption A1's `SOUND_UP=0 / SOUND_DOWN=1 / BRIGHTNESS_UP=2 / BRIGHTNESS_DOWN=3 / MUTE=7`, and always `PASSTHROUGH` on `keyDown=false` for the same codes. **Corroborated, not individually confirmed:** the user did not label which physical key produced each code one-by-one, but the observed code set and swallow/pass behavior line up exactly with A1's predicted values.
- **Suppression itself failed:** despite `SWALLOWING` being logged and the callback returning `nil`, the native macOS volume/brightness OSD still appeared on screen every time.
- All 4 media transport keys (play/pause, next, previous — fast-forward/rewind not separately exercised but the 3 tested keys covered the transport-key safety question) worked normally throughout, in both modes — the transport-key passthrough guarantee held.

### Final call: `suppression-unreliable`

Per the plan's own defined outcome for this bucket: transport keys did not break, but suppression itself failed to hide the native OSD — this lands in `suppression-unreliable` (the plan's criteria is "suppression failed OR a transport key broke"; here it's the former). Per ROADMAP's own fallback language, the HUD ships **showing ALONGSIDE the native OSD**, never suppressing it, regardless of permission state.

## For Plan 39-03 (`OSDInterceptor.swift`)

- **Do not build a suppress-capable tap for volume/brightness.** The `.defaultTap` + `return nil` suppression path is confirmed unreliable on this dev machine/macOS Tahoe — returning `nil` from the callback does not stop the native OSDUIHelper from showing its own HUD. Building `OSDInterceptor`'s architecture around `IslandResolver`/`TransientQueue`'s existing volume/brightness case is still valid; only the swallow branch of Pattern 2 (39-RESEARCH.md) should be dropped.
- The production interceptor only needs to **detect** key presses (to trigger the HUD's level-read + resolver enqueue) — it can use `.listenOnly` throughout (never `.defaultTap`), which removes the swallow-decision code path entirely and, per the detect-only spike results above, never risks a transport-key regression since `.listenOnly` cannot suppress anything by construction.
- The Accessibility-vs-Input-Monitoring permission question for `.listenOnly` (A2) is still open per the inconclusive result above — 39-03 should default to requesting Accessibility (same as the existing `DropInterceptTap` pattern, already proven working and already granted on this dev machine) rather than assuming a lighter Input-Monitoring-only gate, and treat this as an explicit product-scope note rather than a resolved fact if D-06 ("HUD shows without Accessibility") depends on it.
- Confirmed decode constants for 39-03's allowlist: `SOUND_UP=0, SOUND_DOWN=1, BRIGHTNESS_UP=2, BRIGHTNESS_DOWN=3, MUTE=7` (Assumption A1 corroborated, not individually key-labeled). Other observed codes during the checkpoint (`16` in detect-only) are outside the volage/brightness allowlist and were correctly passed through untouched in both modes — safe precedent for the transport-key/Caps-Lock default-passthrough branch.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `CGEventType.systemDefined` does not exist on this project's SDK**
- **Found during:** Task 1, initial Debug build
- **Issue:** The plan's `<action>` and RESEARCH.md Pattern 1/2 both reference `CGEventType.systemDefined.rawValue`, but this project's macOS 26.5 SDK's public `CGEventType` enum (`CoreGraphics/CGEventTypes.h`) does not define a `systemDefined` case — build failed with "type 'CGEventType' has no member 'systemDefined'".
- **Fix:** Built the `eventsOfInterest` mask directly from the raw NX_SYSDEFINED value: `CGEventMask(1 << 14)`, with an inline comment explaining the omission. `type.rawValue == 14` (already specified by the plan) is unaffected.
- **Files modified:** `Islet/Notch/OSDInterceptionSpike.swift`
- **Commit:** `5e3de61`

**2. [Documentation note, not a code fix] Plan's literal Release-build grep acceptance criterion**
- **Found during:** Task 1 acceptance-criteria verification
- **Issue:** `xcodebuild build ... -configuration Release 2>&1 | grep -i "OSDInterceptionSpike"` necessarily matches xcodebuild's own routine `SwiftCompile`/`SwiftDriverJobDiscovery` batch-compile-group lines, which list every source filename in the target regardless of `#if DEBUG` content — this is unavoidable build-log tooling output, not compiled code.
- **Resolution:** Verified the acceptance criterion's actual intent (zero spike code reaches Release) via: (a) `grep -i "OSDInterceptionSpike" release-log | grep -v "^SwiftCompile\|^SwiftDriverJobDiscovery"` returns zero matches — no errors, no other references; (b) Release `BUILD SUCCEEDED` with zero errors, which requires `AppDelegate.swift`'s own `#if DEBUG`-gated `OSDInterceptionSpike(mode:...)` references to also compile out cleanly (a leak would be a hard compile error, "cannot find type in scope"); (c) the spike file's single top-level `#if DEBUG`/`#endif` wrap verified via `grep -c "^#if DEBUG"` = 1.
- **Files modified:** none (verification methodology only)

None of the deviations altered the architecture or the go/no-go outcome.

## Self-Check: PASSED

- FOUND: Islet/Notch/OSDInterceptionSpike.swift
- FOUND: commit 5e3de61 (git log --oneline --all)
