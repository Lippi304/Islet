---
phase: 15-architecture-refactor-notchwindowcontroller-notchpillview-de
plan: 03
subsystem: auth
tags: [swift, xctest, dependency-injection, licensing]

# Dependency graph
requires:
  - phase: 12-real-polarsh-license-integration
    provides: LicenseManager (Keychain-backed) and TrialManager, whose existing DI pattern this plan mirrors
provides:
  - LicenseManaging/TrialStatusProviding protocol seam on LicenseState
  - LicenseStateTests.swift pinning the 4-way status precedence order with fakes
affects: [16-notchwindowcontroller-devicecoordinator-extraction]

# Tech tracking
tech-stack:
  added: []
  patterns: ["Protocol-typed collaborator with .shared-backed default-argument init (mirrors TrialManager/LicenseManager)"]

key-files:
  created: [IsletTests/LicenseStateTests.swift]
  modified: [Islet/Licensing/LicenseState.swift, Islet.xcodeproj/project.pbxproj]

key-decisions:
  - "LicenseManaging/TrialStatusProviding protocol conformances added via one-line extensions inside LicenseState.swift, keeping LicenseManager.swift/TrialManager.swift untouched"
  - "TrialManager.trialLength stays a direct static access (a constant, not a collaborator) — not injected"

patterns-established:
  - "LicenseState now follows the same protocol-typed-collaborator-with-.shared-default pattern as its siblings LicenseManager/TrialManager"

requirements-completed: [P15-ITEM4]

# Metrics
duration: 35min
completed: 2026-07-08
---

# Phase 15 Plan 03: LicenseState DI Seam Summary

**LicenseState's 4-way entitlement precedence (DEBUG override → persisted license → session activation → trial) is now pinned by 6 automated XCTest cases using fakes, closing a pre-existing test-coverage gap with zero behavior change.**

## Performance

- **Duration:** 35 min
- **Started:** 2026-07-08T17:31:00Z
- **Completed:** 2026-07-08T19:35:00Z
- **Tasks:** 2 (1 auto/TDD, 1 checkpoint:human-verify)
- **Files modified:** 3

## Accomplishments
- `LicenseState` takes injected `LicenseManaging`/`TrialStatusProviding` collaborators with `.shared`-backed default arguments — every existing call site (`NotchWindowController.swift`, `AppDelegate.swift`, `SettingsView.swift`) keeps compiling and behaving identically.
- `LicenseManager`/`TrialManager` conform to the new protocols via one-line extensions inside `LicenseState.swift`, so those two files stay untouched.
- New `IsletTests/LicenseStateTests.swift` pins the precedence order with `FakeLicenseManager`/`FakeTrialManager` — never touches the real Keychain.
- Full `IsletTests` suite (including the new file) confirmed green via Xcode Cmd-U by the user — no regressions.

## Task Commits

Each task was committed atomically (TDD RED → GREEN):

1. **Task 1: LicenseState DI seam + precedence-order tests** - `285e8be` (test, RED — build-for-testing fails, `LicenseManaging`/`TrialStatusProviding`/injectable init don't exist yet) → `e8a837c` (feat, GREEN — `xcodebuild build-for-testing` succeeds)
2. **Task 2: Confirm full suite green via Cmd-U** - verification-only, no commit (human-verify checkpoint; confirmed "approved" by user via Cmd-U)

**Plan metadata:** (this commit) `docs(15-03): complete LicenseState DI seam plan`

_Note: Task 1 used the project's established RED/GREEN commit split (see `git log --oneline | grep test\(` precedent from Phases 10-14)._

## Files Created/Modified
- `Islet/Licensing/LicenseState.swift` - Added `LicenseManaging`/`TrialStatusProviding` protocols, `LicenseManager`/`TrialManager` conformance extensions, and an injectable init; `status`/`trialExpiryDate` now read through the injected collaborators instead of `.shared` literals.
- `IsletTests/LicenseStateTests.swift` - New: `FakeLicenseManager`, `FakeTrialManager`, and 6 tests covering persisted-license precedence, session-activation precedence, active/expired/fresh trial computation, and `isEntitled` mapping.
- `Islet.xcodeproj/project.pbxproj` - Regenerated via `xcodegen generate` to include the new test file in the `IsletTests` target.

## Decisions Made
- Protocol conformance extensions for `LicenseManager`/`TrialManager` live inside `LicenseState.swift` (not their own files) — keeps the two existing files untouched, per the plan's interface spec.
- `TrialManager.trialLength` stays a direct static access, not injected — it is a constant, not a collaborator being faked.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None. This project's headless `xcodebuild test` hangs (documented project memory `xcodebuild-test-headless-hang`), so the full-suite regression gate was executed manually via Xcode Cmd-U per the plan's Task 2 checkpoint; the user confirmed all tests pass, including the 6 new `LicenseStateTests.swift` cases, with no regressions.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

`LicenseState`'s precedence logic is now unit-testable, closing the audit finding that motivated this plan (D-05 truth). Phase 16 (NotchWindowController DeviceCoordinator Extraction) is unaffected by this change — `LicenseState.shared` call sites in `NotchWindowController.swift` continue to work unchanged.

---
*Phase: 15-architecture-refactor-notchwindowcontroller-notchpillview-de*
*Completed: 2026-07-08*
