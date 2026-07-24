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

## Plan 62-04 (round 5, item I)

- `AudioOutputMonitorManualSpike.testManualDeviceEnumerationAndSwitch()` — appeared once in
  a full-suite `xcodebuild test` run alongside the 4 failures above (490 tests executed
  instead of the usual 509, elapsed time also shorter). The test's own file header
  explicitly states "MANUAL SPIKE — DO NOT RUN VIA `xcodebuild test`" (real CoreAudio
  hardware enumeration + a 15s `RunLoop.current.run` wait, Phase 47) — a pre-existing,
  documented headless-run hazard, not a regression from this plan's Timer/Pomodoro changes
  (`Islet/Notch/TimerActivity.swift`, `TimerActivityState.swift`, `NotchPillView.swift`,
  `NotchWindowController.swift`). Not fixed per the scope-boundary rule; re-run the targeted
  Timer test suite (`-only-testing:IsletTests/TimerActivityTests`
  `-only-testing:IsletTests/TimerActivityStateTests` etc.) to confirm this plan's own tests
  independently of this flake.
