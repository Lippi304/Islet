---
phase: 12-real-polar-sh-license-integration
plan: 03
subsystem: auth
tags: [swiftui, license-state, polar.sh, keychain]

# Dependency graph
requires:
  - phase: 12-real-polar-sh-license-integration (12-01)
    provides: LicenseManager.shared (isLicensed, recordValidation(key:)) — read-once cached Keychain persistence
  - phase: 12-real-polar-sh-license-integration (12-02)
    provides: PolarLicenseService — LicenseService conformer that POSTs to the real Polar.sh validate endpoint
provides:
  - LicenseState.status persisted-license branch — LIC-02 observably true end-to-end (offline relaunch entitlement)
  - SettingsView wired to the real PolarLicenseService (StubLicenseService removed from the call site)
  - D-04 error split — .unreachable (retryable, non-red) distinct from .invalidKey (.failure, red)
affects: [12-04 (wave-merge verification, on-device checkpoint)]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Persisted-entitlement branch reads LicenseManager.shared.isLicensed (in-memory cached) on the LicenseState.status hot path, never hitting the Keychain directly from updateVisibility()"

key-files:
  created: []
  modified:
    - Islet/Licensing/LicenseState.swift
    - Islet/SettingsView.swift

key-decisions:
  - "Persisted branch placed AFTER the DEBUG override and BEFORE sessionActivated, per plan's exact interface spec — DEBUG override still wins in dev, trial fallback unchanged, isEntitled needed no change since it already maps .licensed -> true"
  - "recordValidation(key:) call placed AFTER the existing sessionActivated=true + UserDefaults nudge write (not before/instead), preserving the proven updateVisibility() live-unlock path from Phase 10/11 unchanged"

patterns-established: []

requirements-completed: [LIC-02]

# Metrics
duration: 14min
completed: 2026-07-07
---

# Phase 12 Plan 03: Wire LicenseManager + PolarLicenseService into LicenseState/SettingsView Summary

**LicenseState.status now short-circuits to `.licensed` from a persisted Keychain record (offline, zero network call), and SettingsView activates against the real PolarLicenseService with a D-04-compliant `.unreachable`/`.invalidKey` split plus a manual Retry button.**

## Performance

- **Duration:** 14 min
- **Started:** 2026-07-07T20:04:27Z
- **Completed:** 2026-07-07T20:18:00Z
- **Tasks:** 2 completed
- **Files modified:** 2

## Accomplishments
- `LicenseState.status` gained one new branch — `if LicenseManager.shared.isLicensed { return .licensed }` — placed after the DEBUG override and before `sessionActivated`, so a validated key survives relaunch offline (LIC-02 success criterion 3) with the in-memory cache keeping the Keychain off the `updateVisibility()` hot path.
- `SettingsView`'s `licenseService` seam now instantiates `PolarLicenseService()` instead of `StubLicenseService()` — a one-line swap, protocol type unchanged.
- `ActivationPhase` gained `.unreachable`; `statusLine` renders it as a distinct non-red "Server not reachable." message with a `Retry` button that re-calls `activate()` (D-04 — no silent auto-retry).
- `activate()` now splits `.failure(.invalidKey)` → `.failure` phase and `.failure(.unreachable)` → `.unreachable` phase, and on `.success` persists the granted record via `LicenseManager.shared.recordValidation(key:)` — placed after the existing `sessionActivated = true` + `UserDefaults` nudge write, so the proven `updateVisibility()` live-unlock path is untouched.
- `xcodegen generate` + `xcodebuild build -scheme Islet -destination 'platform=macOS' -configuration Debug` → `BUILD SUCCEEDED`.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add the persisted-license branch to LicenseState.status** - `52f75a2` (feat)
2. **Task 2: Swap to PolarLicenseService, persist on success, and split .unreachable from .invalidKey (D-04 + Retry)** - `9b431c7` (feat)

## Files Created/Modified
- `Islet/Licensing/LicenseState.swift` - added the `LicenseManager.shared.isLicensed` persisted branch to `status`, between the DEBUG override and `sessionActivated`
- `Islet/SettingsView.swift` - swapped to `PolarLicenseService()`, added `.unreachable` to `ActivationPhase` with a distinct `statusLine` message + Retry button, split `activate()`'s failure handling, and added `recordValidation(key:)` persistence on success

## Decisions Made
- Followed the plan's exact interface ordering (persisted branch between DEBUG override and `sessionActivated`); no reordering needed since `isEntitled` already treats `.licensed` uniformly.
- Kept the existing `UserDefaults` activation-nudge write exactly where it was and added `recordValidation` immediately after it, rather than restructuring the success branch, to avoid any risk to the already-proven `updateVisibility()` re-entitlement trigger.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required. This plan only edits two existing Swift files; no new dependencies or secrets.

## Next Phase Readiness
- LIC-02 is now observably true end-to-end in source: a granted Keychain record short-circuits `status` offline, and a live Polar.sh activation persists that record on success.
- The `.unreachable`/`.invalidKey` split and Retry button are implemented in source but not yet exercised on real hardware against the live Polar.sh API (server-down vs. bad-key vs. good-key scenarios) or across an actual app relaunch — this end-to-end behavioral verification is explicitly deferred to 12-04's on-device checkpoint, per this plan's own `<verification>` section.
- No blockers for 12-04 (wave-merge verification). This plan touched only `Islet/Licensing/LicenseState.swift` and `Islet/SettingsView.swift`; `Islet.xcodeproj/project.pbxproj` was regenerated by `xcodegen generate` but produced no diff (no new files added by this plan).

---
*Phase: 12-real-polar-sh-license-integration*
*Completed: 2026-07-07*

## Self-Check: PASSED

- FOUND: Islet/Licensing/LicenseState.swift
- FOUND: Islet/SettingsView.swift
- FOUND: commit 52f75a2
- FOUND: commit 9b431c7
