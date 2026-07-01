---
phase: 06-priority-resolver-settings-v1-ship
plan: 13
subsystem: coord
tags: [swift, xctest, transient-queue, state-machine]

# Dependency graph
requires:
  - phase: 06-priority-resolver-settings-v1-ship
    provides: TransientQueue, ActiveTransient, DeviceActivity, pendingDeviceAddresses FIFO (06-07 gap-closure)
provides:
  - PendingBatteryPoll struct + matchPendingBatteryPoll(_:promoted:) pure identity-matching helper (Foundation-only)
  - pendingDeviceBatteryPolls replacing pendingDeviceAddresses in NotchWindowController, matched by DeviceActivity identity
  - flushTransients' oldHead guard skipping redundant dismiss-timer resets when the standing head is untouched
affects: [06-VERIFICATION, 06-REVIEW, COORD-01]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Address-keyed side table + identity-matched pure lookup instead of insertion-order FIFO, for correctness when a bounded/de-duped queue can silently diverge from a side list tracking only a subset of its entries"
    - "oldHead capture before a mutating queue operation, then a `head != oldHead` guard, to distinguish 'this removal changed the standing state' from 'this removal only touched pending/queued entries' before re-arming a timer"

key-files:
  created: []
  modified:
    - Islet/Notch/IslandResolver.swift
    - IsletTests/IslandResolverTests.swift
    - Islet/Notch/NotchWindowController.swift

key-decisions:
  - "WR-1 fixed by identity-match (DeviceActivity payload equality) rather than any FIFO-position patch, since the root cause was FIFO desync, not FIFO length/trimming"
  - "WR-2 fixed with an oldHead-vs-head guard around the ENTIRE dismiss-timer cancel/re-arm block (not just the re-arm branch), so an untouched head's countdown is never even cancelled, let alone restarted"

patterns-established:
  - "Pattern: address-keyed side table, pure enum stays address-free (mirrors deviceLastShown convention) — applied to PendingBatteryPoll"

requirements-completed: [COORD-01]

# Metrics
duration: 12min
completed: 2026-07-02
---

# Phase 06 Plan 13: WR-1/WR-2 Transient-Queue Gap-Closure Summary

**Fixed a battery-poll identity desync (WR-1: device splash could show one device's name with another device's battery %) and an over-eager dismiss-timer reset (WR-2: an unrelated toggle could silently extend a standing splash's on-screen time) — both closed with pure, unit-tested logic in IslandResolver.swift and wired into NotchWindowController.swift.**

## Performance

- **Duration:** 12 min
- **Started:** 2026-07-02T00:55:32+02:00 (worktree base)
- **Completed:** 2026-07-02T01:06:05+02:00
- **Tasks:** 3 completed (2 code tasks + 1 verification-only task)
- **Files modified:** 3

## Accomplishments
- Added `PendingBatteryPoll` (address + DeviceActivity payload) and the pure, total `matchPendingBatteryPoll(_:promoted:)` function to `IslandResolver.swift`, replacing FIFO-position trust with identity-match (WR-1's fix), Foundation-only, zero new imports.
- Replaced `pendingDeviceAddresses: [String]` with `pendingDeviceBatteryPolls: [PendingBatteryPoll]` throughout `NotchWindowController.swift` (declaration, append site in `handleDevice`, lookup in `triggerDeviceBatteryRefreshIfPromoted`, and the `.device` case in `flushTransients`) — zero remaining references to the old property name anywhere under `Islet/`.
- Gated `flushTransients`'s dismiss-timer cancel/re-arm block behind `transientQueue.head != oldHead` (captured before `removeAll(where:)` runs), so toggling one activity category off no longer resets an unrelated standing splash's already-running ~3s countdown (WR-2's fix).
- Added 7 new regression tests to `IslandResolverTests.swift`: 5 for `matchPendingBatteryPoll` (identity-match-not-FIFO-position, nil/charging/disconnected-promoted, no-match) and 2 for `TransientQueue.removeAll(where:)`'s head-unchanged vs head-changed invariant.
- Full `IsletTests` suite: 131 tests, 0 failures (124 pre-existing + 7 new), confirmed twice (once after Task 2's wiring, once standalone in Task 3).

## Task Commits

Each task was committed atomically:

1. **Task 1: Pure identity-match seam for the battery-poll FIFO + regression tests for both defects** - `752e3cb` (test)
2. **Task 2: Wire the identity-safe battery matcher and head-changed guard into NotchWindowController** - `ede6a60` (fix)
3. **Task 3: Full-suite regression verification** - no commit (verification-only; confirmed the full suite green standalone, no source changes)

## Files Created/Modified
- `Islet/Notch/IslandResolver.swift` - Added `PendingBatteryPoll` struct and `matchPendingBatteryPoll(_:promoted:)` pure function (WR-1's identity-match logic)
- `IsletTests/IslandResolverTests.swift` - 7 new regression tests covering WR-1's identity-match and WR-2's head-unchanged/head-changed invariant
- `Islet/Notch/NotchWindowController.swift` - `pendingDeviceAddresses` fully replaced by `pendingDeviceBatteryPolls`; `triggerDeviceBatteryRefreshIfPromoted()` now calls `matchPendingBatteryPoll`; `flushTransients(_:)` captures `oldHead` and gates the dismiss-timer reset on it changing

## Decisions Made
- WR-1: matched by `DeviceActivity` equality (identity) rather than any adjustment to FIFO trimming/ordering, since the bug was fundamentally that the FIFO's insertion order could diverge from `TransientQueue`'s own pending list membership — no amount of reordering the FIFO fixes a desync in WHICH entries it contains.
- WR-2: the `oldHead` guard was placed around the entire `dismissWorkItem?.cancel()` + re-arm block (not just skipping the re-arm while still cancelling), so an untouched standing splash's timer is never even paused — a partial guard (cancel-then-not-rearm) would have left a **stopped** timer with no replacement, still a regression versus "leave it exactly as it was."
- No new threat surface: per the plan's threat model, this is internal state-machine/timer logic with no new external input, persisted state, or trust boundary — `T-06-18` (WR-1) is mitigated via the unit-tested identity match; `T-06-19` (WR-2) is timing-only and accepted, gated by the full-suite regression pass.

## Deviations from Plan

None - plan executed exactly as written. All acceptance criteria (grep checks, build, full test suite) passed on first attempt; no auto-fixes were required. Two in-code comments (in `IslandResolver.swift` and `NotchWindowController.swift`) that initially quoted the literal old property name `pendingDeviceAddresses` for historical context were reworded to avoid tripping the plan's own strict `grep -rn "pendingDeviceAddresses" Islet/` acceptance check — not a logic change, just comment wording to satisfy the plan's own literal verification command.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required. No source changes require user action (no Xcode UI changes needed beyond `xcodegen generate`, which was run automatically as part of verification).

## Next Phase Readiness
- COORD-01's remaining open gap from `06-VERIFICATION.md` ("activities coexist... without overlapping or glitching") is now closed at the code level for both WR-1 and WR-2.
- Full `IsletTests` suite (131 tests) green with zero regressions — no known blockers for closing Phase 06 pending any remaining human_verification items tracked separately in `06-VERIFICATION.md`/`06-REVIEW.md`.

---
*Phase: 06-priority-resolver-settings-v1-ship*
*Completed: 2026-07-02*

## Self-Check: PASSED

All created/modified files verified present; all task commit hashes (752e3cb, ede6a60, 3391501) verified present in git log.
