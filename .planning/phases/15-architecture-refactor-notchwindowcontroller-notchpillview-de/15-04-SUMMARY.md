---
phase: 15-architecture-refactor-notchwindowcontroller-notchpillview-de
plan: 04
subsystem: auth
tags: [swift, licensing, polar-sh, keychain]

# Dependency graph
requires:
  - phase: 12-real-polar-license-integration
    provides: PolarLicenseService, KeychainLicenseStore, LicenseRecord
provides:
  - "ValidatedLicense{id,status,expiresAt} result type threaded through LicenseService -> PolarLicenseService/StubLicenseService -> SettingsView.activate() -> LicenseManager.recordValidation(key:validated:)"
  - "Real Polar.sh server payload (id/status/expiresAt) persisted in the Keychain LicenseRecord instead of a fabricated placeholder"
affects: [16-notchwindowcontroller-devicecoordinator-extraction]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Widened Result success type (Void -> ValidatedLicense) threaded through an existing protocol seam without changing failure-path behavior"

key-files:
  created: []
  modified:
    - Islet/Licensing/LicenseService.swift
    - Islet/Licensing/PolarLicenseService.swift
    - Islet/Licensing/KeychainLicenseStore.swift
    - Islet/SettingsView.swift
    - IsletTests/LicenseServiceTests.swift
    - IsletTests/PolarLicenseServiceTests.swift
    - IsletTests/LicenseManagerTests.swift

key-decisions:
  - "D-03: item 7 is an explicit behavior-change exception to Phase 15's zero-behavior-change policy — only what's PERSISTED changes, not activation UX/unlock behavior"
  - "No revocation/expiry enforcement added; only the data needed for future enforcement is now captured (CONTEXT.md scope)"

patterns-established: []

requirements-completed: [P15-ITEM7]

# Metrics
duration: 25min
completed: 2026-07-08
---

# Phase 15 Plan 04: Persist Real Polar.sh Validation Payload Summary

**Widened `LicenseService.activate` to return `ValidatedLicense{id,status,expiresAt}` instead of discarding the real Polar.sh 200-response payload, and persisted it in the Keychain `LicenseRecord` in place of a fabricated `licenseID:""`/`status:"granted"` placeholder.**

## Performance

- **Duration:** 25 min
- **Tasks:** 3 (2 auto + 1 human-verify checkpoint)
- **Files modified:** 7

## Accomplishments
- `LicenseService` protocol now returns `Result<ValidatedLicense, LicenseActivationError>`; both `StubLicenseService` and `PolarLicenseService` populate the real payload on success
- `LicenseManager.recordValidation(key:validated:)` persists the actual server-supplied `id`/`status` instead of hardcoded placeholders
- `SettingsView.activate()` threads the validated payload through unchanged UX (success message, unlock behavior identical for today's users — D-06)
- On-device verified: real Polar.sh activation, DEBUG magic-key path, and Keychain payload all confirmed correct by the user

## Task Commits

Each task was committed atomically:

1. **Task 1: Widen the LicenseService contract and both conformers' payload** - `5896694` (feat)
2. **Task 2: Thread the payload through persistence, SettingsView, and update existing tests** - `067f28b` (feat)
3. **Task 3: On-device Polar activation check** - verification-only checkpoint, no code changes; confirmed by user ("approved" — activation UX unchanged, app stays unlocked, Keychain confirmed to hold real server-supplied id/status/expiresAt)

**Plan metadata:** (this commit)

## Files Created/Modified
- `Islet/Licensing/LicenseService.swift` - Added `ValidatedLicense` type; widened protocol + `StubLicenseService` success payload
- `Islet/Licensing/PolarLicenseService.swift` - 200-branch now returns the decoded `id`/`status`/`expiresAt` instead of discarding them
- `Islet/Licensing/KeychainLicenseStore.swift` - `recordValidation(key:validated:)` persists the real payload
- `Islet/SettingsView.swift` - `activate()` passes the validated payload to `recordValidation`
- `IsletTests/LicenseServiceTests.swift` - asserts `v.status == "granted"` from the returned `ValidatedLicense`
- `IsletTests/PolarLicenseServiceTests.swift` - asserts `v.id == "lic_1"` from the granted-fixture response
- `IsletTests/LicenseManagerTests.swift` - two `recordValidation` call sites updated to pass a `validated:` argument

## Decisions Made
None beyond what's already recorded in the plan's `must_haves.truths` (D-01, D-03, D-06) — followed plan as specified.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Phase 15's item 7 (the only behavior-changing plan in this phase) is complete and on-device verified. `LicenseManager.isLicensed` still only reads the cached local Keychain record and never re-queries Polar — the data needed for future revocation/expiry enforcement is now captured, but the enforcement itself remains explicitly out of scope (T-15-06, deferred to a future phase). No blockers for Phase 16.

---
*Phase: 15-architecture-refactor-notchwindowcontroller-notchpillview-de*
*Completed: 2026-07-08*
