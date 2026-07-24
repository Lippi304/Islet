# Deferred Items — Phase 62 (timer-pomodoro)

## Plan 62-01

Pre-existing, out-of-scope test failures observed during the full `IsletTests` run (497
tests, 4 failures) after Task 2's changes — none touch files this plan modified
(`Islet/Notch/IslandResolver.swift`, `Islet/Notch/TimerActivity.swift`,
`Islet/Notch/NotchWindowController.swift` [1-line exhaustive-switch fix],
`Islet/Notch/NotchPillView.swift` [1-line exhaustive-switch fix]) or their dependencies.
Not fixed per the scope-boundary rule (only auto-fix issues directly caused by this
plan's changes).

- `CalendarGlanceTests.testDefaultQuickAddTimeForTodayReturnsNextFullHour()` — wall-clock-
  dependent, matches the "2 pre-existing unrelated CalendarGlanceTests failures" already
  noted in STATE.md's Phase 52-04 entry.
- `CalendarGlanceTests.testDefaultQuickAddTimeRollsOverToNextDayAtMidnightBoundary()` —
  same as above.
- `ClipboardFileStoreTests.testSaveDeletesOrphanedImageFileButKeepsStillReferencedFile()` —
  unrelated Phase 56 clipboard-persistence subsystem, no relationship to this plan's files.
- `SettingsViewTests.testSystemHUDCardsCount()` — unrelated Settings-Redesign grid card
  count assertion (`Islet/SettingsView.swift`/`Islet/ActivityCard.swift`), no relationship
  to this plan's files.
