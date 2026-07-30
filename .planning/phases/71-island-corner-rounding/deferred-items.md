# Deferred Items — Phase 71 Plan 01

Out-of-scope items discovered during execution, not fixed per the Scope Boundary rule
(only auto-fix issues directly caused by the current task's changes).

## Pre-existing test failures, unrelated to this plan's changes

Full suite run after Task 3 (`xcodebuild test -scheme Islet -destination 'platform=macOS'`):
584 tests, 7 failures. STATE.md's last-recorded baseline (2026-07-26, Phase 67.1) was
569 tests / 6 failures (4x `LicenseStateTests`, 2x `SettingsViewTests`) — stale by ~4 days
of intervening phases (68-70) that added tests and apparently one more `SettingsViewTests`
failure.

This plan's changes touch only `Islet/Notch/NotchPillView.swift` (corner-radius constants)
and `IsletTests/NotchShapeTests.swift` (2 new tests, both passing). Neither
`SettingsViewTests.swift` nor `LicenseStateTests.swift` was modified by this plan or any
commit in this plan's history — confirmed via `git log -- <file>`, both files' last touches
predate Phase 71 entirely (`cf17509`/`ba43bfa` for SettingsViewTests, `285e8be` for
LicenseStateTests).

**Failures (all pre-existing, out of scope for this plan):**
- `LicenseStateTests.testActiveTrialReturnsDaysRemaining`
- `LicenseStateTests.testExpiredTrialReturnsTrialExpired`
- `LicenseStateTests.testIsEntitledMapping`
- `LicenseStateTests.testMissingTrialStartDateFallsBackToFreshTrial`
- `SettingsViewTests.testProductivityCardsAllNew`
- `SettingsViewTests.testSystemHUDCardsCount`
- `SettingsViewTests.testSystemHUDCardsExistingBeforeNew`

Not fixed here. STATE.md's baseline note should be refreshed the next time someone
touches these test files.
