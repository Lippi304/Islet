---
phase: 39-volume-brightness-hud
plan: 03
subsystem: system-glue
tags: [cgeventtap, nx-sysdefined, coreaudio, displayservices, osd, listen-only]

requires:
  - phase: 39-volume-brightness-hud
    provides: "39-01's on-device spike go/no-go decision (suppression-unreliable) and confirmed NX_KEYTYPE_* decode constants"
provides:
  - "OSDInterceptor.swift: production .listenOnly CGEventTap on NX_SYSDEFINED, permanent never-swallow detector"
  - "VolumeReader.swift: readSystemVolume() via CoreAudio (kAudioHardwareServiceDeviceProperty_VirtualMainVolume)"
  - "BrightnessReader.swift: BrightnessReader.readBrightness() -> Int? via dynamically-loaded DisplayServices.framework"
affects: [39-04-wing-view, 39-05-controller-wiring, 39-06-settings-toggle]

tech-stack:
  added: []
  patterns: [dedicated-CGEventTap-per-fragile-surface, one-fragile-system-surface-one-file, listen-only-permanent-detector]

key-files:
  created:
    - Islet/Notch/OSDInterceptor.swift
    - Islet/Notch/VolumeReader.swift
    - Islet/Notch/BrightnessReader.swift
  modified: []

key-decisions:
  - "Implemented the suppression-unreliable branch (39-01's spike finding): OSDInterceptor is a PERMANENT .listenOnly-only tap that never swallows any event regardless of suppressionArmed()'s value — the swallow-decision/dual-mode/single-mode code paths described elsewhere in the plan were never built"
  - "Plan 39-06's Settings toggle for 'suppress the native OSD' becomes a documented no-op as a direct consequence — must be explicitly gated/labeled in that plan's own implementation and SUMMARY.md"

patterns-established:
  - "Second CGEventTap in this codebase runs its run-loop source on a dedicated DispatchQueue (com.islet.osd-tap), not the main run loop, per Pitfall 1's double-HUD contention risk"
  - "Bounded key-code allowlist evaluated inside a tiny DispatchQueue.main.sync block (NSEvent construction only); every other code including all 4 transport keys returns before any decision is evaluated"

requirements-completed: [HUD-03, HUD-04]

duration: 12min
completed: 2026-07-17
---

# Phase 39 Plan 03: OSDInterceptor + VolumeReader + BrightnessReader Summary

**Production `.listenOnly`-only NX_SYSDEFINED key detector (never suppresses, per 39-01's spike) plus CoreAudio volume and DisplayServices brightness readers.**

## Performance

- **Duration:** ~12 min
- **Completed:** 2026-07-17
- **Tasks:** 2
- **Files modified:** 3 (all new)

## Accomplishments
- `OSDInterceptor.swift` — a permanent `.listenOnly` `CGEvent.tapCreate` on `.cgSessionEventTap` for `NX_SYSDEFINED`, running its run-loop source on a dedicated `DispatchQueue`, with a bounded volume/brightness key-code allowlist (`{0,1,7}` = volume, `{2,3}` = brightness, matching 39-01's on-device-confirmed decode constants) and unconditional passthrough for every other code including all 4 media transport keys
- `VolumeReader.swift` — `readSystemVolume()` reads live output volume + mute via CoreAudio, using the correct non-renamed `kAudioHardwareServiceDeviceProperty_VirtualMainVolume` symbol, with a defensive `guard ... == noErr else { return (0, false) }` at every step
- `BrightnessReader.swift` — dynamically loads `DisplayServicesGetBrightness` from `/System/Library/PrivateFrameworks/DisplayServices.framework`, returns `Int?` (never a fabricated `0%` on load/read failure)

## Task Commits

1. **Task 1: OSDInterceptor.swift — production listen-only CGEventTap** - `fc10756` (feat)
2. **Task 2: VolumeReader.swift + BrightnessReader.swift** - `e5ab0af` (feat)

## Files Created/Modified
- `Islet/Notch/OSDInterceptor.swift` - permanent `.listenOnly` NX_SYSDEFINED detector, dedicated tap queue, bounded key-code allowlist, 5s health-check reinstall, `static isAccessibilityTrusted` exposed for later plans
- `Islet/Notch/VolumeReader.swift` - `readSystemVolume() -> (percent: Int, muted: Bool)` via CoreAudio
- `Islet/Notch/BrightnessReader.swift` - `BrightnessReader.readBrightness() -> Int?` via dynamically-loaded DisplayServices.framework

## Decisions Made

**Architecture implemented: `suppression-unreliable`.** 39-01-SUMMARY.md's on-device spike confirmed the NX_SYSDEFINED decode/key-classification logic works correctly (SWALLOWING was logged for the correct key codes), but `.defaultTap` + returning `nil` from the callback did NOT actually hide the native macOS volume/brightness OSD on this dev machine/macOS Tahoe. Per the spike's own explicit recommendation for Plan 39-03, this plan built `OSDInterceptor` as a **permanent `.listenOnly`-only detector**:
- The tap options are always `.listenOnly`, never `.defaultTap`.
- The swallow-decision branch is never built — `handle(type:event:)` always returns `Unmanaged.passUnretained(event)`, regardless of `suppressionArmed()`'s value (which is still read fresh on every event, purely to preserve the call contract for a possible future re-enable).
- No `TapMode` enum, no `reconcileMode()`, no Accessibility-driven tap teardown/reinstall exists in this file — none of that machinery is needed since suppression is never attempted.
- `AXIsProcessTrustedWithOptions` is never called anywhere in this file (not even the no-prompt query is needed to gate `.listenOnly`, since Accessibility isn't required for it). `static var isAccessibilityTrusted: Bool { AXIsProcessTrusted() }` is still exposed per the plan's universal requirement, for Plan 39-05/39-06 to read (e.g. to show an accurate "suppression unavailable" hint).

**Consequence for Plan 39-06 (flagged explicitly, per this plan's own instructions):** the Settings toggle for "suppress the native OSD" has nothing to actually arm — `OSDInterceptor` structurally cannot suppress in this build. Plan 39-06 must treat its own toggle as a documented no-op (or gate/relabel it accordingly) rather than wiring it to real suppression behavior.

## Deviations from Plan

None beyond the branch selection itself (which the plan's own conditional structure anticipated and directed — see `39-03-PLAN.md` Task 1's "IF 39-01-SUMMARY.md recorded `suppression-unreliable`" clause). One presentational fix during acceptance-criteria verification:

**1. [Rule 1 - Bug] Header comment's literal text tripped its own acceptance-criteria grep**
- **Found during:** Task 1 acceptance-criteria verification
- **Issue:** The file's own architecture-rationale comment originally spelled out `CFRunLoopGetMain()` in prose (explaining what was deliberately NOT used), which caused `grep -n "CFRunLoopGetMain" Islet/Notch/OSDInterceptor.swift` (the acceptance criterion verifying Pitfall 1's dedicated-queue requirement) to falsely match a comment rather than actual code.
- **Fix:** Reworded the comment to say "the main run loop" instead of the literal API name, preserving the same explanation without the false-positive match.
- **Files modified:** `Islet/Notch/OSDInterceptor.swift`
- **Commit:** `fc10756` (part of Task 1 commit)

A similar fix was applied to `VolumeReader.swift`'s comment (which named the old renamed symbol in prose) before its own commit, for the same reason — see `grep -n "VirtualMasterVolume"` acceptance criterion.

---

**Total deviations:** 1 auto-fixed (Rule 1, cosmetic — comment wording only, no logic change)
**Impact on plan:** No scope creep; both fixes are comment-wording only, verified via re-run greps and a clean rebuild after each.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness

`OSDKeyKind`, `readSystemVolume()`, and `BrightnessReader` are now a locked system-glue contract for Plan 39-04 (wing view) and Plan 39-05 (controller wiring). Plan 39-06 (Settings toggle) must account for the `suppression-unreliable` finding: its OSD-suppression toggle cannot arm real suppression in this codebase and should be implemented/labeled as a no-op, not wired to `OSDInterceptor` internals that don't exist. On-device behavioral verification (does the HUD actually appear on key press, does the level read reflect reality) is deferred to Plan 39-07's consolidated UAT checkpoint per this plan's own `<verification>` note — not performed here.

---
*Phase: 39-volume-brightness-hud*
*Completed: 2026-07-17*
