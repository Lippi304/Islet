# Deferred Items — Phase 72 Plan 01

Out-of-scope items discovered during execution, not fixed per the Scope Boundary rule
(only auto-fix issues directly caused by the current task's changes).

## Pre-existing test failures, unrelated to this plan's changes

Full suite run after Task 2 (`xcodebuild test -scheme Islet -destination 'platform=macOS'`):
591 tests, 7 failures. Identical failure set to Phase 71 Plan 01's deferred-items.md
(same 4x `LicenseStateTests` + 3x `SettingsViewTests`), confirming these are still
pre-existing and unrelated to any Calendar work — the count of failures has not changed
since Phase 71 despite two more phases (71-72) landing test-suite changes in between.

This plan's changes touch only `Islet/Calendar/CalendarGlance.swift`,
`Islet/Calendar/CalendarService.swift`, and `IsletTests/CalendarGlanceTests.swift`. Neither
`SettingsViewTests.swift` nor `LicenseStateTests.swift` was modified by this plan or any
commit in this plan's history.

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
