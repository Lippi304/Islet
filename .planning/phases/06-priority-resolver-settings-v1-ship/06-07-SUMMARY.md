---
phase: 06-priority-resolver-settings-v1-ship
plan: 07
subsystem: notch-controller
tags: [swift, swiftui, appkit, bluetooth, iokit, priority-resolver, gap-closure]

# Dependency graph
requires:
  - phase: 06-priority-resolver-settings-v1-ship (plans 01-06)
    provides: TransientQueue / IslandResolver arbiter, DeviceActivityState / BluetoothMonitor wiring, settings toggles
provides:
  - handleDevice honors shouldShowDeviceSplash's documented nil-address "can't dedup, but still show" contract instead of dropping addressless readings early
  - scheduleDeviceBatteryRefresh identity-tracks its poll chain (pollingAddress) so a stale in-flight closure cannot overwrite a different device's splash
  - flushTransients always re-arms a fresh ~3s dismiss window for a promoted survivor instead of inheriting the flushed transient's stale timer
  - a device promoted to head later (not immediately) still gets its post-connect battery refresh scheduled (pendingDeviceAddresses + triggerDeviceBatteryRefreshIfPromoted)
  - IslandResolver.nowPlayingHealthGate(enabled:isHealthy:) — currentPresentation() can no longer render "nicht verfügbar" for a disabled Now Playing
affects: [priority-resolver-settings-v1-ship phase closure, future device/notch-controller work]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Controller-owned, non-persisted side tables (pollingAddress, pendingDeviceAddresses) mirror the existing deviceLastShown convention for identity/promotion tracking outside the pure DeviceActivity/resolve(...) seams"

key-files:
  created: []
  modified:
    - Islet/Notch/NotchWindowController.swift
    - Islet/Notch/IslandResolver.swift
    - IsletTests/IslandResolverTests.swift

key-decisions:
  - "Identity tracking for the battery-poll race stays in a controller-owned side table (pollingAddress), NOT threaded into the pure DeviceActivity enum, per the pattern-mapper's explicit guidance"
  - "nowPlayingHealthGate is a total pure function (Foundation-only) living beside resolve(...) in IslandResolver.swift, keeping the health-gating logic unit-testable in milliseconds like the rest of the resolver seam"

requirements-completed: []  # COORD-01 already marked complete in 06-01..06-06; this plan is a gap-closure fix, checkpoint (Task 3) still pending human on-device verification

# Metrics
duration: ~25min (Tasks 1-2; Task 3 checkpoint pending)
completed: 2026-07-01
---

# Phase 06 Plan 07: Priority-Resolver Gap Closure (Tasks 1-2) Summary

**Five confirmed correctness bugs in the transient-queue/device-battery-refresh controller layer fixed: nil-address device drop, battery-poll identity race, dismiss-timer re-arm gap, missed promoted-device battery refresh, and a stale isHealthy flag that could show "nicht verfügbar" for a disabled Now Playing.**

## Performance

- **Duration:** ~25 min for Tasks 1-2 (automated); Task 3 is an on-device human-verify checkpoint, not yet run
- **Started:** 2026-07-01T21:09:00Z (approx, per orchestrator dispatch)
- **Completed:** Tasks 1-2 complete as of 2026-07-01T21:48:38Z; Task 3 PAUSED at checkpoint
- **Tasks:** 2 of 3 completed (Task 3 is a blocking human-verify checkpoint)
- **Files modified:** 3

## Accomplishments

- Finding 1 closed: `handleDevice` now scopes the address-keyed `connectedDeviceAddresses` edge-dedup to an `if let addr = reading.address` block; an addressless reading falls through unconditionally to `shouldShowDeviceSplash`/`deviceActivity(from:)` instead of being silently dropped by a blanket `guard let addr = reading.address else { return }`.
- Finding 2 closed: `scheduleDeviceBatteryRefresh` stamps a new `pollingAddress` side table on every call (including the retry recursion); the closure's `guard self.pollingAddress == address else { return }` aborts stale in-flight polls superseded by a newer connect before they can overwrite a different device's splash — closes the race even when `.cancel()` arrives too late to stop an already-running closure body.
- Finding 3 closed: `flushTransients` now unconditionally cancels `dismissWorkItem` first, then re-arms a fresh `scheduleActivityDismiss()` window whenever `TransientQueue.removeAll(where:)` promotes a survivor to head — the promoted transient gets a full ~3s window instead of inheriting the flushed transient's stale, partially-elapsed timer.
- Finding 4 closed: a new `pendingDeviceAddresses` FIFO (capped at `maxDepth`) remembers a connected device's address when its `enqueue` returns `false` (queued behind the current head); the new `triggerDeviceBatteryRefreshIfPromoted()` helper is called both from `scheduleActivityDismiss`'s promotion path and `flushTransients`'s promotion path, so a device promoted to head LATER still gets its post-connect battery poll scheduled.
- Finding 5 closed: new pure `IslandResolver.nowPlayingHealthGate(enabled:isHealthy:)` forces a neutral `true` health flag whenever Now Playing is disabled; `currentPresentation()` now gates `nowPlayingHealthy` through this helper instead of passing the raw (possibly stale) `nowPlayingState.isHealthy` straight to `resolve(...)`.
- New regression test `testNowPlayingHealthGateForcesNeutralWhenDisabled` added to `IslandResolverTests.swift` — 15/15 resolver tests pass (14 existing + 1 new); all 28 `DeviceActivityTests` still pass unchanged, confirming `handleDevice`'s fix honors the pure seam's own documented contract.

## Task Commits

Each task was committed atomically:

1. **Task 1: Fix nil-address device-splash regression and the battery-poll identity race** - `8300bdc` (fix)
2. **Task 2: Fix dismiss-timer re-arm on promotion and the missed battery-refresh, and gate the stale isHealthy flag** - `2dbf2d9` (fix)

Task 3 (checkpoint:human-verify, gate="blocking") has NOT run — no files change in that task; it is an on-device verification step. This SUMMARY documents Tasks 1-2 only, per the checkpoint pause.

## Files Created/Modified

- `Islet/Notch/NotchWindowController.swift` — `handleDevice` restructured (Finding 1); `pollingAddress` + `scheduleDeviceBatteryRefresh` identity guard (Finding 2); `pendingDeviceAddresses` + `triggerDeviceBatteryRefreshIfPromoted()` (Finding 4); `scheduleActivityDismiss` calls the new helper on promotion; `flushTransients` always cancels + conditionally re-arms (Finding 3) and clears `pendingDeviceAddresses` on a device-category flush; `currentPresentation()` gates `nowPlayingHealthy` through `nowPlayingHealthGate` (Finding 5)
- `Islet/Notch/IslandResolver.swift` — new pure `nowPlayingHealthGate(enabled:isHealthy:)` function directly below `resolve(...)`
- `IsletTests/IslandResolverTests.swift` — new `testNowPlayingHealthGateForcesNeutralWhenDisabled` test

## Decisions Made

- Kept all five fixes as controller-owned side tables / control-flow changes only — no changes to the pure `DeviceActivity.swift` seam (`shouldShowDeviceSplash`, `deviceActivity(from:)`) or to `resolve(...)`'s signature/existing 14 tests, per the plan's explicit constraint and the pattern-mapper's guidance.
- `nowPlayingHealthGate` lives in `IslandResolver.swift` (same "TOTAL pure reducer" style, Foundation-only) rather than inline in the controller, keeping it unit-testable in milliseconds like the rest of the resolver.

## Deviations from Plan

None — plan executed exactly as written for Tasks 1-2. One minor self-correction during execution: an early draft of the Finding-1 code comment in `handleDevice` accidentally quoted the exact old guard-statement text verbatim, which would have caused the acceptance-criteria grep (`grep -n "guard let addr = reading.address else { return }"` expecting NO match) to false-positive on the comment. Reworded the comment before committing so the grep correctly reports no match; the actual code change was correct from the start. Not tracked as a Rule 1-4 deviation since no shipped behavior was affected — caught and fixed before the Task 1 commit.

## Known Stubs

None — no stub/placeholder patterns introduced.

## Threat Flags

None — this plan's `<threat_model>` (T-06-15, disposition `accept`) already covers all five fixes as pure control-flow/timing-identity changes to existing internal, non-persisted, controller-owned state. No new external input surface, no new persisted state, no new trust boundary was introduced by the Task 1-2 changes.

## Checkpoint Status

**PAUSED at Task 3** (`type="checkpoint:human-verify"`, `gate="blocking"`). This is a standard (non-auto-mode) checkpoint per `.planning/config.json`'s `workflow.auto_advance: false` — execution stops here per the checkpoint protocol; a fresh agent (or the orchestrator) must resume after the human performs the on-device verification described in the plan's Task 3 `<how-to-verify>` block:

1. Toggle Now Playing off after a prior "nicht verfügbar" state, expand the island — confirm plain idle date/time view (Finding 5).
2. Connect a Bluetooth device, then quickly plug in the charger before the device splash elapses — confirm the device splash gets a FRESH ~3s window after the charging splash yields (Finding 3).
3. Connect two Bluetooth devices in quick succession — confirm the second device's splash, once promoted, eventually shows its correct battery % (Finding 4).
4. If no Bluetooth hardware is available, log as "not independently verifiable this session, code-complete" per the project's standing DEV-01/DEV-02 carry-over — does not block the checkpoint.

## Next Steps

- Resume this plan by running Task 3's on-device verification and typing "approved" (or describing any issue found) at the checkpoint's resume-signal.
- No STATE.md / ROADMAP.md updates were made by this worktree agent — the orchestrator owns those writes centrally after the wave (and after this checkpoint resolves).
