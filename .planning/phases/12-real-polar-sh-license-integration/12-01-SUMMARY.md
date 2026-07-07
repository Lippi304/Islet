---
phase: 12-real-polar-sh-license-integration
plan: 01
subsystem: auth
tags: [keychain, security-framework, codable, license-persistence, swift]

# Dependency graph
requires:
  - phase: 10-trial-lockout-gate
    provides: KeychainStore/KeychainTrialStore/TrialManager pattern (read-once cache, delete-then-add SecItem upsert) that this plan mirrors exactly
provides:
  - LicenseStore protocol seam (read/write/delete for a LicenseRecord)
  - LicenseRecord Codable proof-of-purchase record (key, licenseID, status, validatedAt)
  - KeychainLicenseStore real Security-framework implementation (service com.lippi304.islet.license, account validatedLicense)
  - LicenseManager singleton with read-once in-memory cache (isLicensed, recordValidation(key:), DEBUG debugResetLicense())
affects: [12-02, 12-03, 12-04, LicenseState.swift future integration]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Injectable persistence seam + read-once in-memory cache, mirroring TrialManager.swift exactly, to keep the hover/click hot path off the Keychain (prevents auth-prompt flood, memory 2401)"
    - "Entitlement persisted as a Codable record with a status string, never a bare Bool/UserDefaults value (T-11-02 / T-12-01)"

key-files:
  created:
    - Islet/Licensing/KeychainLicenseStore.swift
    - IsletTests/LicenseManagerTests.swift
  modified:
    - Islet.xcodeproj/project.pbxproj (XcodeGen auto-registration of the new test file)

key-decisions:
  - "LicenseManager mirrors TrialManager's shape 1:1 (protocol seam, real Keychain struct, singleton with cachedRecord/hasCachedRecord) rather than inventing a new pattern — keeps the codebase consistent and lets Task 2's tests directly mirror TrialManagerTests.swift"
  - "Verification used both `xcodebuild build` (the plan's literal gate) and `xcodebuild build-for-testing` (added check) — `build` alone does not compile the IsletTests target per project.yml's `IsletTests: [test]` scheme entry, so build-for-testing was needed to actually prove LicenseManagerTests.swift compiles"

patterns-established:
  - "Pattern: any future Keychain-backed single-item store follows LicenseStore/KeychainLicenseStore's exact shape (protocol seam -> real SecItem struct -> read-once-cached manager singleton)"

requirements-completed: [LIC-02]

# Metrics
duration: 12min
completed: 2026-07-07
---

# Phase 12 Plan 01: KeychainLicenseStore Persistence Layer Summary

**Keychain-backed LicenseStore/LicenseRecord/KeychainLicenseStore/LicenseManager persistence seam, mirroring the proven TrialManager pattern with a read-once in-memory cache and unit tests via a FakeLicenseStore.**

## Performance

- **Duration:** 12 min
- **Started:** 2026-07-07T19:56:00Z
- **Completed:** 2026-07-07T20:08:08Z
- **Tasks:** 2 completed
- **Files modified:** 3 (2 created, 1 XcodeGen-regenerated)

## Accomplishments
- `LicenseStore` protocol seam + `LicenseRecord` Codable proof-of-purchase record + `KeychainLicenseStore` (SecItem upsert on service `com.lippi304.islet.license`, account `validatedLicense`, `kSecAttrAccessibleAfterFirstUnlock`) created, mirroring `KeychainTrialStore` exactly.
- `LicenseManager` singleton with a read-once in-memory cache (`hasCachedRecord`/`cachedRecord`) — `isLicensed` never re-reads the Keychain after the first hit, `recordValidation(key:)` keeps the cache in sync without a re-read.
- `LicenseManagerTests.swift` with a `FakeLicenseStore` (readCount-tracked, no real Keychain/network I/O) covering: granted-record entitlement, empty-store/non-granted-status → false, read-once caching, and cache-sync-on-write.
- Both `xcodebuild build` (plan's literal gate) and `xcodebuild build-for-testing` (added check, since `build` alone skips the `[test]`-only IsletTests target) confirmed BUILD SUCCEEDED / TEST BUILD SUCCEEDED.

## Task Commits

Each task was committed atomically:

1. **Task 1: Create KeychainLicenseStore.swift** - `69c58d8` (feat)
2. **Task 2: Create LicenseManagerTests.swift and gate the build** - `3c45827` (test)

_Note: per the plan's own task split (source in Task 1, tests in Task 2), this was not a strict RED-first TDD cycle — the plan explicitly ordered implementation before tests and gated on `xcodebuild build`/`build-for-testing`, not `xcodebuild test` (which hangs in this project per prior findings)._

## Files Created/Modified
- `Islet/Licensing/KeychainLicenseStore.swift` - `LicenseStore` protocol, `LicenseRecord` Codable, `KeychainLicenseStore` (real Security-framework impl), `LicenseManager` (read-once-cached singleton)
- `IsletTests/LicenseManagerTests.swift` - `FakeLicenseStore` + 5 unit tests for entitlement rule, empty/non-granted cases, read-once cache, and recordValidation cache-sync
- `Islet.xcodeproj/project.pbxproj` - XcodeGen-regenerated to register the new test file (auto-glob, no manual project edits)

## Decisions Made
- Copied `TrialManager.swift`'s exact shape (protocol seam / real Keychain struct / cached singleton) rather than introducing a new pattern, per the plan's explicit interface-copy instruction.
- Added `xcodebuild build-for-testing` as a supplementary verification step beyond the plan's literal `xcodebuild build` gate, because the `Islet` scheme's `build` action does not compile `IsletTests` (it's registered `[test]`-only in `project.yml`) — `build` alone would not have caught a broken test file. This is Rule 1 territory (closing a gap in the given verification, not a deviation from the plan's intent) since the plan's own acceptance criteria requires the test suite to actually compile.

## Deviations from Plan

None - plan executed exactly as written. The `build-for-testing` addition above is a verification-strengthening step, not a change to any deliverable, task order, or file.

## Issues Encountered

- The plan's specified verify command (`xcodebuild build`) does not compile the `IsletTests` target under this project's `project.yml` scheme configuration (`IsletTests: [test]`, not `Islet: all`). Resolved by additionally running `xcodebuild build-for-testing`, which compiles both the app and test bundles without executing any tests (no risk of the known `xcodebuild test` Bluetooth-TCC hang). Both commands report success.

## User Setup Required

None - no external service configuration required. This plan adds zero external packages (Foundation + Security only, per the plan's threat model T-12-SC disposition).

## Next Phase Readiness
- `LicenseManager.shared` / `KeychainLicenseStore` are ready for 12-03 to call `recordValidation(key:)` on a successful Polar.sh validation response.
- `LicenseState.swift` integration (short-circuiting `.status` to `.licensed` from `LicenseManager.shared.isLicensed` with zero network I/O after first validation) is the next hook-in point, per `12-PATTERNS.md` lines 169-208 — not part of this plan's scope.
- Unit tests are authored but not yet run via Cmd-U (per the project's `xcodebuild test` hang constraint) — actual test execution is deferred to the manual verification checkpoint at 12-04, consistent with prior phases' precedent.

---
*Phase: 12-real-polar-sh-license-integration*
*Completed: 2026-07-07*

## Self-Check: PASSED

- FOUND: Islet/Licensing/KeychainLicenseStore.swift
- FOUND: IsletTests/LicenseManagerTests.swift
- FOUND: commit 69c58d8
- FOUND: commit 3c45827
