---
phase: 39-volume-brightness-hud
plan: 05
subsystem: ui
tags: [swiftui, appkit, notch, osd, volume, brightness, transient-queue]

# Dependency graph
requires:
  - phase: 39-volume-brightness-hud (Plan 39-02)
    provides: IslandResolver.swift's OSDActivity-carrying ActiveTransient/IslandPresentation .osd cases, TransientQueue.updateHead's (.osd, .osd) arm, isPersistent exclusion for .osd
  - phase: 39-volume-brightness-hud (Plan 39-03)
    provides: OSDInterceptor (CGEventTap `.listenOnly` detector, suppression-unreliable per 39-01 spike), readSystemVolume()
  - phase: 39-volume-brightness-hud (Plan 39-04)
    provides: BrightnessReader (DisplayServices.framework glue), osdVolumeActivity/osdBrightnessActivity pure constructors
provides:
  - NotchWindowController.osdInterceptor property + unconditional startOSDInterceptor() lifecycle
  - handleOSDKeyPress(_:) implementing D-09 (re-arm on scrub)/D-12 (cross-category instant replace)/D-13 (Focus preemption)
  - scheduleActivityDismiss() generalized to a per-category duration (D-10's separate 1.5s OSD window)
  - ActivitySettings.osdSuppressionKey + osdPermissionStatusHint(toggleOn:granted:)
affects: [39-06 (Settings UI toggle + permission hint), 39-07 (on-device UAT of D-09/D-10/D-12/D-13 timing)]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "New transient category wiring (TransientCategory case + flushTransients matches/model-clear arm) added defensively even though nothing calls flushTransients(.osd) yet — mirrors Focus's own precedent of an exhaustive switch that must compile"
    - "scheduleActivityDismiss's duration computation reads the SAME `head` local the persistence guard already snapshotted, not a fresh transientQueue.head read, per the plan's own threat-model row T-39-05-01 (no new race window)"

key-files:
  created: []
  modified:
    - Islet/Notch/NotchWindowController.swift
    - Islet/ActivitySettings.swift

key-decisions:
  - "handleOSDKeyPress's same-category branch (D-09/D-12) explicitly re-arms scheduleActivityDismiss() itself, since updateHead's in-place refresh does NOT go through presentTransientChange() (which already arms it) — this is the one deliberate divergence from Charging's %-tick branch, called out inline"
  - "osdActivityDuration (1.5s) kept as a fully separate stored constant from activityDuration (3.0s), never derived from or consolidated with it, per D-10"

requirements-completed: [HUD-03, HUD-04]

# Metrics
duration: 55min
completed: 2026-07-17
---

# Phase 39 Plan 05: OSD Controller Wiring Summary

**Wired the already-existing OSDInterceptor/VolumeReader/BrightnessReader/IslandResolver `.osd` plumbing (Plans 39-02/39-03/39-04) into `NotchWindowController` — the controller now starts OSD detection unconditionally at launch and turns every volume/brightness key press into the exact D-09/D-10/D-12/D-13 TransientQueue sequence.**

## Performance

- **Duration:** ~55 min
- **Completed:** 2026-07-17
- **Tasks:** 2/2 completed
- **Files modified:** 2

## Accomplishments
- `startOSDInterceptor()` starts the CGEventTap-based detector unconditionally in `start()`, alongside `startOutfitRefresh()`'s existing unconditional-start precedent — no `activityEnabled(...)` gate, matching D-06 (only native-OSD suppression is opt-in, never the HUD itself).
- `handleOSDKeyPress(_:)` builds an `OSDActivity` from a fresh `readSystemVolume()`/`brightnessReader.readBrightness()` call and branches on the current `transientQueue.head`: a standing `.osd` head gets an in-place `updateHead` + explicit re-arm (D-09 scrub-refresh, D-12 cross-category instant replace), while no standing `.osd` head reuses the exact D-13 Focus-preemption shape already established for Charging/Device.
- `scheduleActivityDismiss()` generalized to compute its wake-up duration from the current head's category (`osdActivityDuration` = 1.5s for `.osd`, `activityDuration` = 3.0s for everything else) — every other line of the function (the persistence guard, the `DispatchWorkItem` body, the re-arm-on-advance branch) is untouched.
- `ActivitySettings` gained `osdSuppressionKey` + `osdPermissionStatusHint(toggleOn:granted:)`, the shared namespace Plan 39-06's Settings toggle reads next.

## Task Commits

Each task was committed atomically:

1. **Task 1: OSDInterceptor lifecycle + handleOSDKeyPress(_:) — D-09/D-12/D-13** - `e8b330c` (feat)
2. **Task 2: ActivitySettings.swift — osdSuppressionKey + status hint** - `e2e9379` (feat)

_Note: no TDD tasks in this plan — both are `type="auto"`._

## Files Created/Modified
- `Islet/Notch/NotchWindowController.swift` - `osdInterceptor` property + `startOSDInterceptor()` (unconditional-start lifecycle, mirrors `startFocusModeMonitor()`'s idempotent shape), `brightnessReader` stored instance, `osdActivityDuration` constant, `handleOSDKeyPress(_:)`, generalized `scheduleActivityDismiss()` duration, `TransientCategory.osd` + `flushTransients(_:)` arm, `osdInterceptor?.stop()` in `deinit`
- `Islet/ActivitySettings.swift` - `osdSuppressionKey` + `osdPermissionStatusHint(toggleOn:granted:)`

## Decisions Made
- Duration computation inside `scheduleActivityDismiss()` reads the `head` local variable already bound by the function's own persistence guard, not a second fresh read of `transientQueue.head` — closes the threat register's T-39-05-01 row (both checks now observe one consistent snapshot) without needing any additional locking/synchronization.
- `handleOSDKeyPress`'s same-category branch calls `scheduleActivityDismiss()` explicitly after `updateHead`, since `updateHead` (unlike `presentTransientChange()`) does not itself arm the dismiss timer — documented inline as the one deliberate divergence from Charging's %-tick branch (which intentionally does NOT re-arm).

## Deviations from Plan

None — plan executed exactly as written. All resolver/queue-side `.osd` plumbing (`IslandPresentation.osd`, `ActiveTransient.osd`, `TransientQueue.updateHead`'s `(.osd, .osd)` arm, `isPersistent` exclusion, `syncActivityModels()`'s `.osd` arm) was already present from Plans 39-02/39-03/39-04 — this plan's job was purely the controller-side wiring described in the objective.

## Issues Encountered

None blocking. Build succeeded on the first attempt after all edits.

## Verification

- `xcodebuild build -project Islet.xcodeproj -scheme Islet -configuration Debug` — **BUILD SUCCEEDED**
- All 5 acceptance-criteria greps from the plan confirmed:
  - `startOSDInterceptor()` called unconditionally inside `start()` (no `activityEnabled(...)` wrap)
  - `handleOSDKeyPress` — exactly 1 match, body contains both `updateHead(.osd(` and `preempt(.osd(` / `enqueue(.osd(` paths
  - `osdActivityDuration` — declared and used inside the generalized duration computation
  - `case .osd = transientQueue.head` — confirmed inside `handleOSDKeyPress`'s same-category branch, re-arming via an explicit `scheduleActivityDismiss()` call
  - `osdInterceptor?.stop()` — exactly 1 match, inside `deinit`
- On-device timing/priority verification (does the 1.5s dismiss feel right, does Volume<->Brightness swap instantly, does a Volume press interrupt a standing Focus pill) is deferred to Plan 39-07's consolidated on-device UAT checkpoint, per this plan's own `<verification>` section.

## Next Steps
- Plan 39-06: SettingsView toggle for OSD suppression, reading `ActivitySettings.osdSuppressionKey` + `osdPermissionStatusHint`.
- Plan 39-07: consolidated on-device UAT of D-09/D-10/D-12/D-13 timing/priority behavior.

## Self-Check: PASSED
