---
phase: 10-trial-lockout-gate
plan: 02
subsystem: licensing
tags: [swiftui, appkit, notch-window-controller, tdd, dispatch-work-item]

# Dependency graph
requires:
  - phase: 10-trial-lockout-gate (10-01)
    provides: "Islet.Licensing.LicenseState.shared exposing isEntitled/trialExpiryDate"
provides:
  - "shouldShow(hasTarget:hideInFullscreen:isFullscreen:isLicensed:) — the single visibility arbiter, now with isLicensed as a dominant AND-term (D-11)"
  - "NotchWindowController.updateVisibility() reading licenseState.isEntitled fresh on every call"
  - "pendingLockoutHide idle-state guard deferring license-driven hides until the next natural hover-exit-collapse or toggle-shut click (D-13)"
  - "trialExpiryWorkItem — single best-effort one-shot expiry re-check timer (D-12)"
affects: [10-03-appdelegate-settings-wiring, 10-04-human-uat, 11-settings-ui, 12-polar-integration]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Idle-state guard pattern: a state-driven hide check computes midInteraction (pointerInZone || interaction.isExpanded) and defers via a pending flag, applied at the next natural UI transition rather than synchronously"
    - "5th instance of the file's existing property + cancel-then-reschedule + deinit-cancel one-shot DispatchWorkItem idiom (trialExpiryWorkItem mirrors dismissWorkItem/graceWorkItem/mediaDismissWorkItem/deviceBatteryWork)"

key-files:
  created: []
  modified:
    - Islet/Notch/FullscreenDetector.swift
    - IsletTests/VisibilityDecisionTests.swift
    - Islet/Notch/NotchWindowController.swift

key-decisions:
  - "D-11: isLicensed is a leading/dominant AND-term in shouldShow(...) — an unlicensed state always hides regardless of every other input"
  - "D-12: exactly one best-effort one-shot DispatchWorkItem (trialExpiryWorkItem) proactively nudges updateVisibility() at the computed trial-expiry instant; the wall-clock licenseState.isEntitled read inside updateVisibility() remains the sole authoritative check (accepted Mach-time-across-sleep drift, T-10-06)"
  - "D-13: a license-driven hide while the pointer is in the hot-zone or the island is expanded is deferred via pendingLockoutHide and applied only at the next natural transition (handleHoverExit's grace-elapsed collapse, or a handleClick toggle-shut) — never an abrupt mid-interaction yank"
  - "D-04 reuse: the locked-state hide reuses the existing panel?.orderOut(nil) branch verbatim — no new visual state introduced"

patterns-established: []

requirements-completed: [LIC-03]

# Metrics
duration: ~25min
completed: 2026-07-05
---

# Phase 10 Plan 02: NotchWindowController Lockout Wiring Summary

**`shouldShow(...)` gains a dominant `isLicensed` AND-term consumed by `NotchWindowController.updateVisibility()`, with a `pendingLockoutHide` idle-state guard so a license-driven hide never abruptly interrupts an active hover/expansion, plus a single best-effort one-shot trial-expiry timer**

## Performance

- **Duration:** ~25 min
- **Completed:** 2026-07-05
- **Tasks:** 2 completed (Task 1 followed RED/GREEN TDD)
- **Files modified:** 3 (`FullscreenDetector.swift`, `VisibilityDecisionTests.swift`, `NotchWindowController.swift`)

## Accomplishments
- `shouldShow(...)` extended to a 4-parameter pure predicate with `isLicensed` as a new leading, dominant AND-term (D-11) — an unlicensed state hides regardless of target/fullscreen inputs
- 9/9 `VisibilityDecisionTests` pass (6 pre-existing tests updated with `isLicensed: true`, 3 new tests proving the D-11 dominance, e.g. `testUnlicensedHidesEvenWhenTargetPresentAndNotFullscreen`)
- `NotchWindowController` reads `LicenseState.shared.isEntitled` fresh on every `updateVisibility()` call, wired as the sole production call site's new `isLicensed:` argument
- `pendingLockoutHide` idle-state guard (D-13): `updateVisibility()` checks `pointerInZone || interaction.isExpanded` first; if a license-driven hide would otherwise fire mid-interaction, it defers instead of touching `panel`/`hotZone`/`expandedZone`/`pointerInZone` — the deferred hide is re-applied via new `updateVisibility()` calls wired into `handleHoverExit`'s grace-elapsed collapse work item and `handleClick`'s toggle-shut branch
- `trialExpiryWorkItem`: a 5th one-shot `DispatchWorkItem` instance mirroring the file's existing `dismissWorkItem`/`graceWorkItem`/`mediaDismissWorkItem`/`deviceBatteryWork` idiom exactly (property, cancel-then-reschedule via `scheduleTrialExpiryCheck()`, call site in `start()`, cancel in `deinit`) — no polling loop (D-12)
- Full test suite green at wave-merge: 155/155 tests pass, `xcodebuild build -scheme Islet` succeeds

## Task Commits

Each task was committed atomically (Task 1 followed RED/GREEN TDD):

1. **Task 1: Extend the single arbiter — shouldShow(isLicensed:)**
   - `67e282d` (test) — failing `VisibilityDecisionTests.swift` (RED: "Extra argument 'isLicensed' in call" compile failure across all 9 test call sites)
   - `3d8a92b` (feat) — `FullscreenDetector.swift` 4-parameter `shouldShow(...)` (GREEN: 9/9 passed)
2. **Task 2: Wire licenseState + trial-expiry timer + idle-state lockout guard into NotchWindowController**
   - `8dfaccb` (feat) — `NotchWindowController.swift`: `licenseState`/`pendingLockoutHide`/`trialExpiryWorkItem` properties, idle-state guard + `isLicensed:` argument in `updateVisibility()`, natural-transition rechecks in `handleHoverExit`/`handleClick`, `scheduleTrialExpiryCheck()`, and `deinit` cancel — verified via `xcodebuild build -scheme Islet`

## Files Created/Modified
- `Islet/Notch/FullscreenDetector.swift` — `shouldShow(hasTarget:hideInFullscreen:isFullscreen:isLicensed:)`, `isLicensed` as a dominant leading AND-term; doc-comment updated to reference D-11/LIC-03
- `IsletTests/VisibilityDecisionTests.swift` — 6 existing tests updated with `isLicensed: true`; 3 new tests (`testUnlicensedHidesEvenWhenTargetPresentAndNotFullscreen`, `testUnlicensedHidesEvenWithHideFlagOff`, `testUnlicensedHidesRegardlessOfNoTargetOrFullscreen`) proving D-11 dominance
- `Islet/Notch/NotchWindowController.swift` — `licenseState`/`pendingLockoutHide`/`trialExpiryWorkItem` properties; `updateVisibility()` idle-state guard + `isLicensed:` argument; `scheduleTrialExpiryCheck()` method + `start()` call site; `handleHoverExit`/`handleClick` natural-transition recheck calls; `deinit` timer cancel

## Decisions Made
Followed the plan's exact structure and naming verbatim — `licenseState`, `pendingLockoutHide`, `trialExpiryWorkItem`, `scheduleTrialExpiryCheck()` all match the plan's `<action>` spec exactly, including the precise insertion points (idle-state guard at the very top of `updateVisibility()`; recheck calls immediately after each `withAnimation` block closes, before `syncClickThrough()`/the existing `if` branch).

## Deviations from Plan

None - plan executed exactly as written. Task 1's `<verify>` (a scoped `-only-testing:` run) requires the whole `Islet`/`IsletTests` targets to compile, which meant the production call site in `NotchWindowController.swift` needed its `isLicensed:` argument added before Task 1's automated check could pass standalone — since Task 2 fully wires that same call site anyway (with the live `licenseState.isEntitled` read, not a placeholder), both tasks' code changes were implemented together in this session before either was verified, then committed as two separate atomic commits per their respective `<files>` scopes. No scope or behavior deviation — this is a sequencing note, not a plan deviation.

## Issues Encountered
None. Unlike Plan 01's documented `xcodebuild test -scheme Islet` hang risk (BluetoothMonitor TCC-authorization wait, logged in `10-trial-lockout-gate/deferred-items.md` for Plan 01), the full suite ran to completion in this session without hanging: 155/155 tests passed in ~2 seconds.

## Known Stubs

None introduced by this plan. The `isLicensed` gate is fully wired end-to-end against the real `LicenseState.shared` (built in Plan 01); no placeholder/mock value was left in the production call site.

## User Setup Required

None - no external service configuration required. No new dependencies added.

## Next Phase Readiness

- The `isLicensed` AND-term (D-11), idle-state guard (D-13), and one-shot expiry timer (D-12) are all live against the real `LicenseState.shared` stub from Plan 01 — Plan 03 (AppDelegate/Settings wiring) and Plan 04 (on-device UAT) can exercise the full lockout path, including flipping the DEBUG override to force `.trialExpired`/`.licensed` and observing the island hide/show accordingly.
- On-device confirmation of the D-13 mid-interaction deferral (per the threat register's T-10-07 disposition) remains for Plan 10-04's manual checkpoint, as planned.
- No blockers.

---
*Phase: 10-trial-lockout-gate*
*Completed: 2026-07-05*

## Self-Check: PASSED
All 3 modified files verified present on disk; all 4 commits (67e282d, 3d8a92b, 8dfaccb, 0a99640) verified present in git log. Working tree clean.
