---
phase: 16-notchwindowcontroller-device-coordinator-extraction-prove-th
plan: 02
subsystem: notch-window
tags: [swift, swiftui, bluetooth, iobluetooth, device-coordinator, refactor]

# Dependency graph
requires:
  - phase: 16-01
    provides: "DeviceCoordinator and ActivityCoordinator types with the public surface this plan wires against"
provides:
  - "NotchWindowController fully delegated to DeviceCoordinator for all device-splash bookkeeping"
  - "On-device D-03 Bluetooth verification (reconnect-flap debounce, launch-grace suppression, genuine disconnect, battery-poll promotion) recorded as passed"
affects: [notch-window, device-coordinator, bluetooth-monitor]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Reference-type coordinator fields that self-referencing closures capture and deinit must read are declared as `private var X: T!` (implicitly-unwrapped, constructed at the top of start()), not `private lazy var X: T`, because a lazy var's synthesized getter is main-actor-isolated and unreadable from a nonisolated deinit under this codebase's strict-concurrency settings."

key-files:
  created: []
  modified:
    - Islet/Notch/NotchWindowController.swift
    - .planning/phases/16-notchwindowcontroller-device-coordinator-extraction-prove-th/16-HUMAN-UAT.md

key-decisions:
  - "deviceCoordinator declared as private var DeviceCoordinator! (IUO, non-lazy) instead of the plan's private lazy var, to keep it readable from nonisolated deinit; deinit call site uses optional chaining (deviceCoordinator?.cancelPendingWork())."

patterns-established:
  - "Self-referencing-closure fields accessed from deinit follow the existing bluetoothMonitor/powerMonitor IUO-plus-construct-in-start() pattern, not lazy var."

requirements-completed: [D-01, D-03]

# Metrics
duration: (checkpoint-spanning; on-device verification performed by user between Task 2 and Task 3)
completed: 2026-07-08
---

# Phase 16 Plan 02: NotchWindowController → DeviceCoordinator Wiring Summary

**Deleted 9 fields and 3 methods from NotchWindowController, rewired all 6 device-splash call sites through a single `deviceCoordinator`, and proved zero regression across the phase's 4 mandatory on-device Bluetooth scenarios.**

## Performance

- **Tasks:** 3 completed (2 auto + 1 checkpoint:human-verify)
- **Files modified:** 2

## Accomplishments
- `NotchWindowController` no longer owns any device-splash state — `deviceLastShown`, `deviceSuppressedAtLaunch`, `deviceDebounce`, `connectedDeviceAddresses`, `bluetoothStartedAt`, `deviceLaunchGrace`, `deviceBatteryWork`, `pollingAddress`, `pendingDeviceBatteryPolls`, and the `handleDevice`/`triggerDeviceBatteryRefreshIfPromoted`/`scheduleDeviceBatteryRefresh` methods are gone; all behavior now lives in `DeviceCoordinator` (Plan 16-01).
- All 6 call sites (construction, `BluetoothMonitor.onReading`, `scheduleActivityDismiss`, `handleSettingsChanged`, `flushTransients(.device)`, `deinit`) rewired to `deviceCoordinator`, preserving exact statement ordering — including Pitfall 12's unconditional pending-poll clear before the `oldHead` guard, and `handleSettingsChanged`'s `deviceLastShown`-only reset asymmetry.
- `BluetoothMonitor`'s own lifecycle (construction/start/stop/deinit teardown) is byte-for-byte unchanged, satisfying D-01.
- D-03's on-device hard gate: all 4 scenarios (reconnect-flap debounce, launch-grace suppression, genuine disconnect, battery-poll promotion) verified pass on real hardware via Cmd-R, and the full `IsletTests` suite (existing ~20 files + new `DeviceCoordinatorTests`) verified green via Cmd-U.

## Task Commits

Each task was committed atomically:

1. **Task 1: Rewire NotchWindowController to DeviceCoordinator and delete the extracted fields/methods** - `647e638` (feat)
2. **Task 2: Create the D-03 on-device Bluetooth verification checklist** - `ff7394e` (docs)
3. **Task 3: Execute the D-03 on-device Bluetooth checklist and the full regression suite** - `11cc84e` (test) — checkpoint approved by user; no code change, results recorded

**Plan metadata:** (this commit)

## Files Created/Modified
- `Islet/Notch/NotchWindowController.swift` - device-splash bookkeeping deleted, all 6 call sites delegate to `deviceCoordinator`
- `.planning/phases/16-notchwindowcontroller-device-coordinator-extraction-prove-th/16-HUMAN-UAT.md` - D-03 checklist created (Task 2) then recorded all 4 scenarios `pass`, `status: complete` (Task 3)

## Decisions Made
- `deviceCoordinator` declared `private var DeviceCoordinator!` (implicitly-unwrapped, non-lazy, constructed at the top of `start()`) instead of the plan's `private lazy var`. See Deviations below.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `private lazy var deviceCoordinator` failed to compile under strict concurrency**
- **Found during:** Task 1 (Rewire NotchWindowController to DeviceCoordinator)
- **Issue:** The plan specified `deviceCoordinator` as a non-optional `private lazy var`. A `lazy var`'s synthesized getter is main-actor-isolated in this codebase's strict-concurrency setup and cannot be read from `NotchWindowController`'s `nonisolated deinit`, producing a compile error.
- **Fix:** Declared `private var deviceCoordinator: DeviceCoordinator!` (implicitly-unwrapped, non-lazy), constructed at the top of `start()`, mirroring the file's existing `bluetoothMonitor`/`powerMonitor` pattern for self-referencing-closure fields that `deinit` must access. `deinit` calls `deviceCoordinator?.cancelPendingWork()` (optional-chained) instead of the plan's literal non-optional call. No behavior change; call sites and method names unchanged.
- **Files modified:** Islet/Notch/NotchWindowController.swift
- **Verification:** `xcodebuild build -scheme Islet -configuration Debug` succeeds with zero errors/warnings.
- **Committed in:** 647e638 (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - bug/compile blocker)
**Impact on plan:** Necessary for correctness under the project's strict-concurrency settings. No scope creep — declaration style only, no behavior change.

## Issues Encountered
None beyond the compile-time deviation above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- The DeviceCoordinator extraction (D-01, D-03) is complete and proven on real hardware; `NotchWindowController` has no remaining device-splash bookkeeping to extract.
- `ActivityCoordinator`/`DeviceCoordinator` pattern established in this phase is available as a template for any future coordinator extractions from `NotchWindowController`.

---
*Phase: 16-notchwindowcontroller-device-coordinator-extraction-prove-th*
*Completed: 2026-07-08*
