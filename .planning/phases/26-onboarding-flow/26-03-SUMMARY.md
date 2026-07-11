---
phase: 26-onboarding-flow
plan: 03
subsystem: ui
tags: [swiftui, appkit, onboarding, launch-gate, notch-window-controller]

# Dependency graph
requires:
  - phase: 26-01
    provides: "OnboardingStep/OnboardingEvent enums, shouldShowOnboarding/shouldSeedOnboardingCompletedForExistingUser pure gate functions, resolve(...)'s onboardingStep parameter, IslandPresentation.onboarding case"
provides:
  - "NotchWindowController.start(isFirstLaunch:) — the real launch-time onboarding gate wired against Plan 26-01's pure functions"
  - "onboardingStep/isOnboardingActive controller state, readable by Plan 26-04"
  - "startLocationOnce() split out of startOutfitRefresh(), independently callable by Plan 26-04's Permissions Grant handler"
  - "AppDelegate no longer auto-opens Settings on first launch — onboarding lives in the notch panel"
affects: [26-04]

# Tech tracking
tech-stack:
  added: []
  patterns: ["Launch-time pure-gate-first pattern: compute onboarding gate before any permission-triggering monitor starts, mirroring IslandResolver's forced-flow precedence check"]

key-files:
  created: []
  modified:
    - Islet/AppDelegate.swift
    - Islet/Notch/NotchWindowController.swift

key-decisions:
  - "Settings window is now unconditionally hidden on every launch (first or returning) — onboarding replaces the old first-launch auto-open-Settings behavior (D-08)"
  - "isOnboardingActive gates only Bluetooth + outfit refresh (Location/Calendar); Charging and Now Playing monitors remain unconditional per D-01's explicit scope"

patterns-established: []

requirements-completed: [ONBOARD-01, ONBOARD-03]

# Metrics
duration: ~20min
completed: 2026-07-11
---

# Phase 26 Plan 03: Launch-Time Onboarding Gate Wiring Summary

**AppDelegate now hands `isFirstLaunch` into `NotchWindowController.start(isFirstLaunch:)`, which uses Plan 26-01's pure gate functions to decide once at launch whether to show onboarding — and if so, defers Bluetooth/Location/Calendar instead of firing them eagerly.**

## Performance

- **Duration:** ~20 min
- **Completed:** 2026-07-11
- **Tasks:** 2/2 completed
- **Files modified:** 2

## Accomplishments
- `AppDelegate.applicationDidFinishLaunching` passes `isFirstLaunch` straight into `controller.start(isFirstLaunch:)` and unconditionally hides the Settings window on every launch (no more first-launch auto-open) — D-08.
- `NotchWindowController.start(isFirstLaunch:)` computes the onboarding gate as its literal first two statements, via unparaphrased calls to Plan 26-01's `shouldSeedOnboardingCompletedForExistingUser`/`shouldShowOnboarding`, correctly grandfathering every pre-Phase-26 install (RESEARCH.md Pitfall 2).
- Bluetooth monitor and outfit refresh (Location one-shot request + Calendar fetch) are skipped while `isOnboardingActive`; Charging and Now Playing monitors are untouched, exactly as scoped.
- `startLocationOnce()` split out of `startOutfitRefresh()` for Plan 26-04's Permissions-row Grant handler to call independently.
- A forced onboarding launch starts pre-expanded (`interaction.phase = .expanded`, no animation) and immediately click-through-synced (`syncClickThrough()`), so the panel is interactive without requiring a first hover tick.
- `currentPresentation()`'s `resolve(...)` call now threads `onboardingStep` through, so `IslandResolver`'s forced-flow precedence (from 26-01) actually takes effect.

## Task Commits

1. **Task 1: AppDelegate hands isFirstLaunch to the controller, stops auto-opening Settings** - `3ee4599` (feat)
2. **Task 2: NotchWindowController — gated start(), onboarding state, startLocationOnce() split** - `e17c2c2` (feat)

**Plan metadata:** (this commit)

## Files Created/Modified
- `Islet/AppDelegate.swift` - `controller.start()` → `controller.start(isFirstLaunch: isFirstLaunch)`; unconditional `hideSettingsWindowOnLaunch()` call replaces the old first-launch/returning-launch branch
- `Islet/Notch/NotchWindowController.swift` - `func start()` → `func start(isFirstLaunch: Bool)`; added `onboardingStep`/`isOnboardingActive` state; onboarding gate computed first; Bluetooth + outfit refresh gated behind `!isOnboardingActive`; `startLocationOnce()` extracted; `resolve(...)` call updated; pre-expanded + click-through-synced launch state for a forced onboarding session

## Decisions Made
- None beyond what the plan specified — both tasks were implemented literally as written, including the unparaphrased gate-function calls the threat model (T-26-01) requires.

## Deviations from Plan

None — plan executed exactly as written.

One note on the plan text itself (not a code deviation): Task 1's acceptance criteria for `didHideSettingsAtLaunch = true` reads "returns zero matches" but its own parenthetical says `hideSettingsWindowOnLaunch()`'s internal logic still sets it (self-contradictory wording in the PLAN.md). The action steps and `<done>` criteria are unambiguous — only the *early*-set branch (inside the old `if isFirstLaunch {...}` block) had to be removed, and `hideSettingsWindowOnLaunch(attempt:)` had to stay completely unmodified (action item 3). The implementation follows the explicit action steps: `hideSettingsWindowOnLaunch`'s own `didHideSettingsAtLaunch = true` (line 99) is untouched; the early-set copy that used to live inside the `if isFirstLaunch` branch is gone. `grep -c "didHideSettingsAtLaunch = true"` therefore correctly returns 1 (down from 2), not 0.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- `onboardingStep`/`isOnboardingActive` and `startLocationOnce()` are in place and ready for Plan 26-04 (same file, sequential wave) to add step-advance/grant/settings-hop/finish behavior.
- Build gate (`xcodegen generate && xcodebuild build -scheme Islet -destination 'platform=macOS' -configuration Debug`) passes with `BUILD SUCCEEDED`.
- No on-device UAT performed in this plan (deferred to Plan 26-04's checkpoint per the plan's own `<verification>` section) — a fresh install now enters `.welcome`/expanded state but nothing yet lets the user advance past it (that's 26-04's job).

---
*Phase: 26-onboarding-flow*
*Completed: 2026-07-11*
