---
phase: 10-trial-lockout-gate
plan: 01
subsystem: licensing
tags: [keychain, security-framework, xctest, trial, tdd]

# Dependency graph
requires:
  - phase: 06-priority-resolver-settings-ship
    provides: "the single-arbiter shouldShow(...)/updateVisibility() pattern and #if DEBUG gating discipline this plan mirrors"
provides:
  - "Islet.Licensing.TrialLogic — pure trialStatus(startDate:now:trialLength:) classification"
  - "Islet.Licensing.TrialManager — Keychain-backed trial-start persistence with earliest-of-two reconciliation"
  - "Islet.Licensing.LicenseState — app-wide LicenseStatus/isEntitled/trialExpiryDate, DEBUG override stub"
affects: [10-02-notch-window-controller-lockout, 10-03-appdelegate-settings-wiring, 11-settings-ui, 12-polar-integration]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Pure/glue split for trial classification (TrialLogic.swift zero-I/O, TrialManager.swift Keychain glue) — mirrors PowerActivity/PowerSourceMonitor"
    - "Injectable KeychainStore protocol seam for unit-testing persistence logic without touching real Keychain I/O"
    - "Earliest-of-two-dates reconciliation between Keychain and UserDefaults mirror (never trust a later mirror value)"
    - "#if DEBUG gating on both the writer AND the reader of a stub-override UserDefaults key"

key-files:
  created:
    - Islet/Licensing/TrialLogic.swift
    - Islet/Licensing/TrialManager.swift
    - Islet/Licensing/LicenseState.swift
    - IsletTests/TrialLogicTests.swift
    - IsletTests/TrialManagerTests.swift
  modified: []

key-decisions:
  - "D-10: trial start date persists via Security-framework Keychain (kSecClassGenericPassword), not UserDefaults, so defaults delete/reinstall cannot reset the trial"
  - "Pitfall 5: when Keychain and the UserDefaults mirror disagree, the EARLIEST of the two dates always wins for enforcement"
  - "D-09: TrialManager.trialLength is a single 3*86400 constant in every build configuration; debugResetTrial() (reset-only) is the sole DEBUG testing seam, no shortened DEBUG trial length"
  - "LicenseStatus is the full 3-case enum (trial/trialExpired/licensed) from the start per RESEARCH Open Question 2, even though only the DEBUG override can produce .licensed until Phase 12's real Polar wiring"

patterns-established:
  - "Islet/Licensing/ group: pure classification file + thin system-glue file + stub state model, same split as Islet/Notch/"

requirements-completed: [TRIAL-01]

# Metrics
duration: ~20min
completed: 2026-07-05
---

# Phase 10 Plan 01: Trial Persistence Core Summary

**Keychain-backed 3-day trial persistence (earliest-of-two-dates tamper resistance) plus a stub `LicenseState` exposing `isEntitled`/`trialExpiryDate` for the visibility gate**

## Performance

- **Duration:** ~20 min
- **Completed:** 2026-07-05
- **Tasks:** 3 completed
- **Files modified:** 5 created (3 source, 2 test), 0 modified (plus regenerated `Islet.xcodeproj/project.pbxproj` via `xcodegen generate`)

## Accomplishments
- Pure, zero-I/O `trialStatus(startDate:now:trialLength:)` classification function with an exclusive 3-day boundary, unit-tested at zero-elapsed, near-boundary (2.99 days), exact boundary, and well-past-expiry
- Keychain-backed `TrialManager` with an injectable `KeychainStore` protocol seam, so first-launch write-once semantics and the earliest-of-two-dates reconciliation (Pitfall 5) are fully unit-tested without any real Security-framework calls in CI
- `LicenseState` stub exposing the exact interface contract Plan 02/03 will consume (`status`, `isEntitled`, `trialExpiryDate`), with the DEBUG override gated on both the write and read sides (Pitfall 4)
- Verified both Debug and Release configurations build cleanly with the new `#if DEBUG`-gated code present

## Task Commits

Each task was committed atomically (Tasks 1 and 2 followed RED/GREEN TDD):

1. **Task 1: Pure trial classification — TrialLogic.swift**
   - `692f730` (test) — failing `TrialLogicTests.swift` (RED: `trialStatus` didn't exist)
   - `69b1028` (feat) — `TrialLogic.swift` implementation (GREEN: 5/5 passed)
2. **Task 2: Keychain-backed trial persistence — TrialManager.swift**
   - `d11b4fa` (test) — failing `TrialManagerTests.swift` (RED: `TrialManager`/`KeychainStore` didn't exist)
   - `f88e17c` (feat) — `TrialManager.swift` implementation (GREEN: 6/6 passed)
3. **Task 3: License/trial status stub — LicenseState.swift**
   - `01205e6` (feat) — `LicenseState.swift`, verified via `xcodebuild build -scheme Islet` (Debug) and `-configuration Release`, both succeeded

## Files Created/Modified
- `Islet/Licensing/TrialLogic.swift` — pure `TrialStatus` enum + `trialStatus(startDate:now:trialLength:)` total function
- `Islet/Licensing/TrialManager.swift` — `KeychainStore` protocol, `KeychainTrialStore` (real Security-framework impl), `TrialManager` (Keychain + UserDefaults-mirror glue, `recordFirstLaunchIfNeeded`, DEBUG-only `debugResetTrial`)
- `Islet/Licensing/LicenseState.swift` — `LicenseStatus` enum, `LicenseState.shared` (`status`/`isEntitled`/`trialExpiryDate`), DEBUG override stub
- `IsletTests/TrialLogicTests.swift` — 5 tests covering the classification boundary matrix
- `IsletTests/TrialManagerTests.swift` — 6 tests using a fake in-memory `KeychainStore`, covering first-launch write-once, earliest-of-two reconciliation, single-store fallback, nil-when-empty, and DEBUG reset
- `Islet.xcodeproj/project.pbxproj` — regenerated via `xcodegen generate` after each new source file addition (auto-discovered from the `Islet`/`IsletTests` source paths in `project.yml`; no `project.yml` changes needed)

## Decisions Made
- Followed the plan's exact interface contract verbatim (`TrialStatus`, `KeychainStore`, `TrialManager`, `LicenseStatus`, `LicenseState`) — no naming or shape deviations from what Plan 02/03 expect to consume.
- Reworded one doc-comment in `TrialLogic.swift` to avoid the literal substring `Date()` inside a comment (originally read "never an internal Date() read"), because the plan's own acceptance-criteria grep (`grep -n "Date()" ...` expecting zero matches) would otherwise have matched the comment text itself despite no actual clock read existing in the file. Reworded to "never an internal system-clock read" — same meaning, satisfies the literal automated check.

## Deviations from Plan

None - plan executed exactly as written (the doc-comment wording note above is a same-commit textual adjustment to satisfy the plan's own literal acceptance-criteria grep, not a behavioral or scope deviation).

## Issues Encountered
- The plan-level `<verification>` full-suite command (`xcodebuild test -scheme Islet`) is known to hang indefinitely in this worktree-agent sandbox due to a pre-existing `BluetoothMonitor`/IOBluetooth TCC-authorization wait (already documented in `.planning/phases/09-fullscreen-flash-window-space-retry/deferred-items.md` for Phase 9, unrelated to any Phase 10 change). Logged as a new entry in `.planning/phases/10-trial-lockout-gate/deferred-items.md` rather than re-running the same known-hanging command. All per-task automated verifications specified in each task's own `<verify>` block (the actual gating checks) ran successfully: `TrialLogicTests` (5/5), `TrialManagerTests` (6/6), Debug build, Release build.

## Known Stubs

`LicenseState.status` defaults to `.trial(daysRemaining: 3)` when `TrialManager.shared.trialStartDate()` returns `nil` (should not happen after `recordFirstLaunchIfNeeded()` has run — this is a documented, intentional defensive fallback per the plan's own `<action>` spec, not an unwired data path). No other stubs — `.licensed` is genuinely reachable today via the DEBUG override for testing purposes; the real Polar.sh-backed path to `.licensed` is explicitly deferred to Phase 12 per the plan and RESEARCH.md's Open Question 2 resolution.

## User Setup Required

None - no external service configuration required. No new dependencies were added (only first-party `Foundation`/`Security` system frameworks).

## Next Phase Readiness

- `LicenseState.shared.isEntitled`/`status`/`trialExpiryDate` are ready for Plan 02 (`NotchWindowController`'s `shouldShow(...)` AND-term extension) and Plan 03 (`AppDelegate`/`SettingsView` first-launch notice + DEBUG menu wiring) to consume exactly as specified in this plan's `<interfaces>` contract.
- No blockers. The pre-existing `xcodebuild test -scheme Islet` full-suite hang (BluetoothMonitor TCC wait) remains a known, out-of-scope environment limitation carried from Phase 9 — does not block Plan 02/03 execution, which can use `-only-testing:` scoped runs the same way this plan did.

---
*Phase: 10-trial-lockout-gate*
*Completed: 2026-07-05*
