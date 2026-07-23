---
phase: 60-caps-lock-hud-update-activity-restyle
plan: 02
subsystem: system-glue
tags: [swift, nsevent, accessibility, sparkle, monitor]

# Dependency graph
requires:
  - phase: 60-caps-lock-hud-update-activity-restyle
    plan: "60-01"
    provides: "CapsLockActivity/UpdateActivity, IslandResolver .capsLock/.updateAvailable cases, ActivitySettings.capsLockKey/updateHudKey"
  - phase: 60-caps-lock-hud-update-activity-restyle
    plan: "60-04"
    provides: "NotchPillView.onUpdateTap closure property, wingsShape's onTap override"
provides:
  - "CapsLockMonitor — the codebase's first Accessibility-gated NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) monitor"
  - "NotchWindowController.handleCapsLockChange/handleUpdateAvailable(version:)/triggerUpdateInstall() — the real OS-signal entry points into the Plan 60-01 arbiter"
  - "AppDelegate.onUpdateInstallRequested wiring + a second didFindValidUpdate signal (D-02, additive to the existing menu-bar dot)"
affects: [60-05]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Accessibility-gated NSEvent global monitor (CapsLockMonitor) — clones PowerSourceMonitor's start()/stop()/deinit lifecycle skeleton + OSDInterceptor.isAccessibilityTrusted's gate, net-new combination for this codebase"

key-files:
  created:
    - Islet/Notch/CapsLockMonitor.swift
  modified:
    - Islet/Notch/NotchWindowController.swift
    - Islet/AppDelegate.swift
    - Islet.xcodeproj/project.pbxproj

key-decisions:
  - "capsLockActivityDuration (1.5s) is its own named constant, not a reused alias of osdActivityDuration, even though the value coincidentally matches — CAPS-01's own '~1-2s' tuning knob"
  - "handleUpdateAvailable(version:) is internal (not private) since AppDelegate calls it cross-file, mirroring spikeLikeCurrentTrack()'s existing internal access level"
  - "CapsLockMonitor.start() never calls AXIsProcessTrustedWithOptions(prompt: true) — Accessibility has no re-request API in this codebase's established discipline; untrusted is a silent no-op, never a crash"

patterns-established: []

requirements-completed: [CAPS-01, UPDATE-01]

# Metrics
duration: 25min
completed: 2026-07-23
---

# Phase 60 Plan 02: Caps Lock Monitor / Update Signal Wiring Summary

**A net-new Accessibility-gated `NSEvent.flagsChanged` global monitor (`CapsLockMonitor`) plus a second signal off Sparkle's existing `didFindValidUpdate` callback, both routed through the Plan 60-01 arbiter exactly like every other system monitor in this codebase.**

## Performance

- **Duration:** 25 min
- **Started:** 2026-07-23T20:07:00+02:00
- **Completed:** 2026-07-23T20:32:00+02:00
- **Tasks:** 3
- **Files modified:** 3 (1 created, 2 modified, plus the regenerated Xcode project)

## Accomplishments
- `CapsLockMonitor` clones `PowerSourceMonitor`'s exact `init(onChange:)`/idempotent `start()`/`nonisolated stop()`/empty-`deinit` lifecycle, gated on `Self.isAccessibilityTrusted` (cloned from `OSDInterceptor.isAccessibilityTrusted`) — never force-prompts, silently no-ops when untrusted
- `NotchWindowController` owns/starts/stops `capsLockMonitor` exactly like `focusModeMonitor` (toggle-gated at launch and in `handleSettingsChanged()`); `handleCapsLockChange`/`handleUpdateAvailable(version:)` both use the preempt-if-`.focus`-else-enqueue shape, never `updateHead` (no in-place scrub case for either)
- `TransientCategory`/`flushTransients`'s exhaustive switch and its `matches` closure gained `.capsLock`/`.updateAvailable`; `scheduleActivityDismiss()` gained its own `capsLockActivityDuration` (1.5s); `syncActivityModels()` already had both cases from Plan 60-01
- `AppDelegate`'s `didFindValidUpdate` now fires both the existing menu-bar dot unhide AND `notchController?.handleUpdateAvailable(version:)` (D-02, dot unremoved); `onUpdateInstallRequested` wired right after `notchController` assignment, forwarding the Update wing's tap to the real `checkForUpdates()`; a DEBUG-only `debugSpikeSimulateUpdateAvailable()` spike hook, confirmed absent from the Release binary (0 matches via `strings`/`nm`/build-log grep)

## Task Commits

Each task was committed atomically:

1. **Task 1: CapsLockMonitor** - `a515c08` (feat)
2. **Task 2: NotchWindowController wiring** - `32aab85` (feat)
3. **Task 3: AppDelegate wiring** - `b0fcec5` (feat)

## Files Created/Modified
- `Islet/Notch/CapsLockMonitor.swift` - net-new Accessibility-gated `NSEvent.flagsChanged` global monitor class
- `Islet/Notch/NotchWindowController.swift` - `capsLockMonitor` property + `onUpdateInstallRequested` closure; `startCapsLockMonitor()`; `handleCapsLockChange(_:)`/`handleUpdateAvailable(version:)`/`triggerUpdateInstall()`; launch-time gate + `handleSettingsChanged()` toggle-on/off block; `TransientCategory`/`flushTransients`/`scheduleActivityDismiss` coverage; `makeRootView`'s `onUpdateTap` wiring; `deinit` teardown
- `Islet/AppDelegate.swift` - second `didFindValidUpdate` signal; `onUpdateInstallRequested` closure assignment; `debugSpikeSimulateUpdateAvailable()` DEBUG spike hook + menu item
- `Islet.xcodeproj/project.pbxproj` - regenerated via `xcodegen generate` to pick up `CapsLockMonitor.swift`

## Decisions Made
- No deviations from the plan's own literal instructions beyond one self-correction (see below) — every task's acceptance-criteria greps match exactly as specified.

## Deviations from Plan

None functionally — plan executed as written. One cosmetic self-correction during Task 1: the first draft of `CapsLockMonitor.swift`'s doc comment literally contained the string `AXIsProcessTrustedWithOptions(prompt: true)` while explaining the anti-pattern is never used, which made the acceptance criterion's grep-for-absence check falsely match a comment (not real code). Reworded the comment to describe the anti-pattern without spelling out the literal API call, so the grep now correctly confirms the API is never invoked in this file. No behavior change, same commit (`a515c08`).

## Issues Encountered

None. Debug build green after each task; Release build succeeded with the DEBUG spike symbol confirmed absent (`strings`/`nm` on the built binary and a build-log grep all returned 0 matches for `debugSpikeSimulateUpdateAvailable`).

## User Setup Required

None for this plan's own code — CapsLockMonitor is inert (no HUD) until the user grants Islet Accessibility trust in System Settings, which is expected graceful-degrade behavior (Plan 60-03 already ships the permission-explanation popover).

## Next Phase Readiness
- Both `CAPS-01` and `UPDATE-01`'s system-glue layer is now code-complete: the monitor, the handlers, the queue-category coverage, and the AppDelegate signal are all wired end-to-end into the Plan 60-01 arbiter and Plan 60-04's wing rendering.
- RESEARCH.md Pitfall 3 (does `NSEvent.addGlobalMonitorForEvents` live-reconcile a mid-session Accessibility grant, or does it need a relaunch, unlike `OSDInterceptor`'s proven `reconcileMode()`) is explicitly UNRESOLVED — flagged in `CapsLockMonitor.swift`'s own comment for Plan 60-05's on-device checkpoint to verify empirically, not assumed either way here.
- RESEARCH.md Pitfall 4 (does the Update wing's genuinely new tap-to-install affordance reliably hit its tap target with zero click-through, unlike the universal expand-to-Home taps every other wing uses) is also unverified by this plan — the `debugSpikeSimulateUpdateAvailable()` hook exists specifically so Plan 60-05 can trigger the Update HUD on-device without a real newer Sparkle appcast and test repeated taps.
- `xcodebuild test` is documented in this repo (STATE.md, Phase 56) to hang headlessly; only `build-for-testing` (compile-level, confirms zero regressions to the `IsletTests` target) was run here. A full on-device/Xcode Cmd+U pass is recommended as part of Plan 60-05's on-device checkpoint, alongside the Pitfall 3/4 verifications above.

---
*Phase: 60-caps-lock-hud-update-activity-restyle*
*Completed: 2026-07-23*

## Self-Check: PASSED

All 3 created/modified source files and this SUMMARY.md confirmed present on disk; all 3 task commit hashes (a515c08, 32aab85, b0fcec5) confirmed in git log.
