# Deferred Items — Phase 67.1

Out-of-scope discoveries found during plan execution that were NOT auto-fixed (scope boundary: only
issues directly caused by the current task's changes are in scope).

## From Plan 02 (Site 1 Scale-Aware Rendering)

**Pre-existing SettingsViewTests failures, unrelated to notch scaling:**
- `SettingsViewTests.testProductivityCardsAllNew()` — fails
- `SettingsViewTests.testSystemHUDCardsExistingBeforeNew()` — fails

Found during a full-suite `xcodebuild test -scheme Islet` run (broader than Plan 02's own specified
verification command, which only targets `IsletTests/NotchPillViewTests`). Both tests assert on
`SettingsView().systemHUDCards`/`.productivityCards` `isNew` flags — Settings-grid card metadata from
the v1.10 Settings-Redesign feature (Phase 59), with no relationship to `NotchPillView.swift`,
`NotchGeometry.swift`, or `ActivitySettings.swift`'s scale-offset keys touched by this plan. Not
auto-fixed per the scope boundary rule. Flagging for a future `/gsd-quick` or the next phase touching
`SettingsView.swift`'s card definitions.
