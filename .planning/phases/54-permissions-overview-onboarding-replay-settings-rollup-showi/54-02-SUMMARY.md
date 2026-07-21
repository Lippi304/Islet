---
phase: 54-permissions-overview-onboarding-replay-settings-rollup-showi
plan: 02
subsystem: ui
tags: [swiftui, onboarding, appkit-window-controller, notch]

# Dependency graph
requires:
  - phase: 26 (onboarding carousel + OnboardingViewState)
    provides: the existing carousel (welcome/trial-license-buy/permissions/done), finishOnboarding(), NotchPillView's onboarding closure set this plan extends
provides:
  - replayOnboarding()/finishOnboardingReplay() — mid-session onboarding replay that never
    touches ActivitySettings.onboardingCompletedKey and restores the exact prior interaction phase
  - requestBluetoothPermission() cross-window trigger for the Settings Permissions section
  - replay-only close button (onOnboardingCancel + replayCloseButton) shown only when
    onboardingState.isReplay is true
affects: [54-03 (Permissions overview + Settings Replay button wiring, consumes all three new entry points)]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Replay-vs-real branching via a single optional (replayPriorPhase != nil) rather than a
       second enum/flag — mirrors the existing isOnboardingActive boolean style"

key-files:
  created: []
  modified:
    - Islet/Notch/OnboardingViewState.swift
    - Islet/Notch/NotchWindowController.swift
    - Islet/Notch/NotchPillView.swift

key-decisions:
  - "finishOnboardingReplay() restores interaction.phase to the captured replayPriorPhase
     directly rather than routing through nextState(_:_:.clicked) — the real finishOnboarding()
     keeps its .clicked transition unchanged, but replay's whole purpose is not clobbering
     whatever the island was showing before it started (D-07/D-08)"
  - "Task 1's own automated verify step (xcodebuild build) could not literally pass until Task
     2's NotchPillView onOnboardingCancel parameter existed (the call site in Task 1 already
     references it), so both tasks' code was written before the first build run; commits still
     split per-task exactly as planned (Task 1 files committed first, Task 2 file second)"

patterns-established: []

requirements-completed: [ARCH-P2]

# Metrics
duration: 15min
completed: 2026-07-21
---

# Phase 54 Plan 02: Onboarding Replay Mechanism Summary

**Mid-session onboarding replay (`replayOnboarding()`/`finishOnboardingReplay()`) that reuses the Phase 26 carousel verbatim without ever writing the onboarding-completed flag, plus a replay-only close button and the Bluetooth cross-window permission trigger Plan 03 needs.**

## Performance

- **Duration:** ~15 min
- **Completed:** 2026-07-21
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- `OnboardingViewState.isReplay` published flag — the single reactive signal the view reads to show the replay-only close button.
- `NotchWindowController.replayOnboarding()`/`finishOnboardingReplay()` — idempotent replay entry/exit that never writes `ActivitySettings.onboardingCompletedKey` and restores the captured prior `interaction.phase` instead of forcing `.clicked`.
- `requestBluetoothPermission()` cross-window trigger, mirroring the existing `focusPermissionGranted()` precedent, for Plan 03's Bluetooth "not yet asked" Settings tap.
- `onOnboardingFinish` now branches on `replayPriorPhase != nil` to call the right exit path; `finishOnboarding()` (the real first-launch path) is provably untouched.
- Replay-only `xmark.circle.fill` close button, top-trailing of the onboarding carousel card, rendered at every step (not just `.done`) only when `onboardingState.isReplay` is true.

## Task Commits

Each task was committed atomically:

1. **Task 1: replayOnboarding()/finishOnboardingReplay()/requestBluetoothPermission() + isReplay flag** - `2ec857a` (feat)
2. **Task 2: Replay-only close button in onboardingCarousel** - `3e4773a` (feat)

**Plan metadata:** (pending — final docs commit below)

## Files Created/Modified
- `Islet/Notch/OnboardingViewState.swift` - added `@Published var isReplay: Bool = false`
- `Islet/Notch/NotchWindowController.swift` - added `replayPriorPhase`, `replayOnboarding()`, `finishOnboardingReplay()`, `requestBluetoothPermission()`; branched `onOnboardingFinish`; added `onOnboardingCancel` closure at the construction site
- `Islet/Notch/NotchPillView.swift` - added `onOnboardingCancel` closure property, `replayCloseButton` view, and the `.overlay(alignment: .topTrailing)` wiring it onto `onboardingCarousel(_:)`

## Decisions Made
- `finishOnboardingReplay()` restores the exact captured `interaction.phase` (not `nextState(_, .clicked)`) — see Pitfall 2 in the plan; this is the entire point of a "safe mid-session" replay.
- Deliberately did not call `startBluetoothMonitor()`/`startOutfitRefresh()` from `finishOnboardingReplay()` — both are already running by the time a replay could fire, per the plan's explicit instruction.
- Both tasks' source edits were written before the first build run, since Task 1's call site already references `onOnboardingCancel` (a Task 2 deliverable) — the plan's own interfaces make the two tasks build-time-coupled even though they're logically and commit-wise separable. Commits are still split exactly along the plan's task boundaries.

## Deviations from Plan

None - plan executed exactly as written. (The build-ordering note above is a sequencing detail, not a code deviation — every line of code matches the plan's `<action>` blocks.)

## Issues Encountered
None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Plan 03 can now wire the Settings "Replay Onboarding" button to `replayOnboarding()` and the Bluetooth "not yet asked" Permissions tap to `requestBluetoothPermission()`.
- No automated test covers the live replay interaction itself (manual-only per RESEARCH.md's Test Map) — full behavioral verification happens in Plan 03's Task 3 on-device checkpoint, once the Settings Replay button actually triggers `replayOnboarding()` end-to-end.

---
*Phase: 54-permissions-overview-onboarding-replay-settings-rollup-showi*
*Completed: 2026-07-21*

## Self-Check: PASSED
- FOUND: Islet/Notch/OnboardingViewState.swift
- FOUND: Islet/Notch/NotchWindowController.swift
- FOUND: Islet/Notch/NotchPillView.swift
- FOUND: .planning/phases/54-permissions-overview-onboarding-replay-settings-rollup-showi/54-02-SUMMARY.md
- FOUND commit: 2ec857a
- FOUND commit: 3e4773a
