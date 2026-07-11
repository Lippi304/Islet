---
phase: 26-onboarding-flow
plan: 01
subsystem: onboarding
tags: [swift, foundation, pure-reducer, tdd, island-resolver]

# Dependency graph
requires:
  - phase: 06-priority-resolver-settings
    provides: IslandResolver.resolve(...) single-arbiter pattern this plan extends
provides:
  - "OnboardingStep/OnboardingEvent/OnboardingPermission enums, Foundation-only"
  - "nextOnboardingStep(_:_:) -- total step-sequencing reducer"
  - "shouldShowOnboarding(isFirstLaunch:onboardingCompletedStored:) -- launch gate"
  - "shouldSeedOnboardingCompletedForExistingUser(isFirstLaunch:onboardingCompletedStored:) -- grandfather-write gate"
  - "IslandPresentation.onboarding(OnboardingStep) case, highest priority in resolve(...)"
  - "ActivitySettings.onboardingCompletedKey UserDefaults key"
affects: [26-02, 26-03, 26-04]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Pure Foundation-only reducer seam (mirrors NotchInteractionState.nextState / IslandResolver.resolve)"
    - "Two-function launch-gate split (shouldShow vs shouldSeed) to make existing-user grandfathering independently testable"

key-files:
  created:
    - Islet/Notch/OnboardingFlow.swift
    - IsletTests/OnboardingFlowTests.swift
  modified:
    - Islet/Notch/IslandResolver.swift
    - Islet/ActivitySettings.swift
    - Islet/Notch/NotchPillView.swift

key-decisions:
  - "onboardingStep checked as the literal first statement of resolve(...), before switch activeTransient, so it structurally cannot be bypassed by any transient/expanded combination (T-26-02)"
  - "onboardingCompletedKey is plain UserDefaults, not Keychain -- a UX gate, not a security boundary (T-26-03)"

patterns-established:
  - "OnboardingStep is enum-typed (not raw Int index) so no out-of-range step is representable (T-26-05)"

requirements-completed: [ONBOARD-01, ONBOARD-03]

# Metrics
duration: 12min
completed: 2026-07-11
---

# Phase 26 Plan 01: Onboarding Pure Seams Summary

**Pure, Foundation-only onboarding step reducer and launch-gate functions, plus the single-arbiter `IslandResolver` precedence hook that makes a forced onboarding session structurally un-pre-emptable by any transient or expanded island state.**

## Performance

- **Duration:** ~12 min
- **Started:** 2026-07-11T19:20:00+02:00 (approx.)
- **Completed:** 2026-07-11T19:27:04+02:00
- **Tasks:** 2/2 completed
- **Files modified:** 5 (2 created, 3 modified)

## Accomplishments
- `OnboardingFlow.swift`: `nextOnboardingStep(_:_:)` (total reducer, Welcome → Trial/License/Buy → Permissions → Done, reversible, idempotent at both ends) plus `shouldShowOnboarding`/`shouldSeedOnboardingCompletedForExistingUser` (the two gate functions that correctly grandfather an existing pre-Phase-26 user per RESEARCH.md Pitfall 2).
- `IslandResolver.resolve(...)` extended with a defaulted `onboardingStep: OnboardingStep? = nil` parameter, checked as the literal first statement — a forced onboarding session outranks even a standing Charging transient over an expanded, healthy, playing island (the hardest D-09 precedence case), with zero changes to any existing call site.
- `ActivitySettings.onboardingCompletedKey` added to the shared key namespace.

## Task Commits

Each task was committed atomically (TDD RED → GREEN per task):

1. **Task 1: OnboardingFlow.swift — step reducer + launch gate functions**
   - `b581c60` (test) — RED: `OnboardingFlowTests.swift`, does not compile (types don't exist yet)
   - `63aa628` (feat) — GREEN: `OnboardingFlow.swift` implementation, `xcodebuild build` succeeds
2. **Task 2: IslandResolver onboarding precedence + ActivitySettings key**
   - `d78acd9` (test) — RED: `testOnboardingOutranksEverything()` added to `IslandResolverTests.swift`; confirmed via `xcodebuild build-for-testing` → `TEST BUILD FAILED` (only this file)
   - `01e41c2` (feat) — GREEN: `IslandPresentation.onboarding` case, `resolve(...)` precedence check, `ActivitySettings.onboardingCompletedKey`, plus the Rule 3 `NotchPillView.swift` exhaustive-switch fix

**Plan metadata:** (this commit, docs) — SUMMARY.md

## Files Created/Modified
- `Islet/Notch/OnboardingFlow.swift` — the pure onboarding seam (enums + reducer + two launch gates)
- `IsletTests/OnboardingFlowTests.swift` — 13 test methods covering every Behavior line
- `Islet/Notch/IslandResolver.swift` — `.onboarding(OnboardingStep)` case (highest priority) + `resolve(..., onboardingStep:)` precedence check
- `Islet/ActivitySettings.swift` — `onboardingCompletedKey` constant
- `Islet/Notch/NotchPillView.swift` — added `.onboarding: EmptyView()` case to keep the presentation switch exhaustive (Rule 3 fix, not planned)

## Decisions Made
- Followed the plan's exact interface contract verbatim (type names, function signatures, doc-comment convention referencing decision IDs) — no deviation from the specified shape.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking compile error] NotchPillView.swift's presentation switch was no longer exhaustive**
- **Found during:** Task 2, GREEN step (`xcodebuild build` after adding `IslandPresentation.onboarding`)
- **Issue:** `NotchPillView.body`'s `switch presentation { ... }` enumerates every `IslandPresentation` case explicitly (no `default:`); adding `.onboarding(OnboardingStep)` as a new case broke compilation project-wide (`switch must be exhaustive`).
- **Fix:** Added a `case .onboarding: EmptyView()` placeholder branch with a comment noting the actual onboarding UI is out of this plan's scope and will be built by Plans 26-02/26-03/26-04. No caller passes a non-nil `onboardingStep` yet, so this branch is unreachable in production today.
- **Files modified:** `Islet/Notch/NotchPillView.swift`
- **Verification:** `xcodebuild build` → `BUILD SUCCEEDED`; `xcodebuild build-for-testing` → `TEST BUILD SUCCEEDED`
- **Committed in:** `01e41c2` (part of Task 2's GREEN commit)

---

**Total deviations:** 1 auto-fixed (Rule 3)
**Impact on plan:** Necessary to keep the codebase compiling after adding the new enum case; zero behavior change (the branch is unreachable until a later plan wires a real onboarding UI in). No scope creep beyond making the build green.

## Issues Encountered

`xcodebuild build -scheme Islet` (the plan's specified verification command) only builds the `Islet.app` target (`buildForRunning = YES`); the `IsletTests` target has `buildForRunning = NO` in the shared scheme, so this command alone never actually compiles test files — matching this project's documented `xcodebuild test` headless-hang constraint (tests are gated to manual Cmd-U). To get genuine RED/GREEN confidence without triggering the hang, `xcodebuild build-for-testing` (which compiles but does not run tests) was used as an additional, unofficial verification step alongside the plan's official `build` gate: it confirmed RED (`TEST BUILD FAILED`, only the new/modified test files) before each GREEN commit, and `TEST BUILD SUCCEEDED` after. Actual test *execution* (all 13 new `OnboardingFlowTests` + `testOnboardingOutranksEverything` + the full pre-existing `IslandResolverTests` suite passing) still requires a manual Cmd-U run in Xcode, per this phase's `<done>` criteria.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

Plans 26-02, 26-03, and 26-04 can now import and use `OnboardingStep`/`OnboardingEvent`/`OnboardingPermission`/`nextOnboardingStep`/`shouldShowOnboarding`/`shouldSeedOnboardingCompletedForExistingUser`/`IslandPresentation.onboarding`/`ActivitySettings.onboardingCompletedKey` without any further contract changes, per this plan's success criteria.

**Recommended manual follow-up (not blocking):** run Cmd-U in Xcode to execute the full `IsletTests` suite and visually confirm all 13 new `OnboardingFlowTests` methods and `testOnboardingOutranksEverything` pass, and that the full pre-existing `IslandResolverTests` suite still passes unmodified — per this project's documented `xcodebuild test` headless-hang constraint, this cannot be done from this automated session.

---
*Phase: 26-onboarding-flow*
*Completed: 2026-07-11*

## Self-Check: PASSED

All 5 created/modified source files and the SUMMARY.md itself found on disk; all 4 task commit hashes (`b581c60`, `63aa628`, `d78acd9`, `01e41c2`) found in git log.
