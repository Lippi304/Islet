# Phase 65 — Deferred Items

## Pre-existing SettingsViewTests failures (out of scope for 65-01)

Full `xcodebuild test -project Islet.xcodeproj -scheme Islet` run after Plan 01 shows 2 failures,
both in `IsletTests/SettingsViewTests.swift`, neither touching any file this plan modified:

- `SettingsViewTests.testProductivityCardsAllNew()`
- `SettingsViewTests.testSystemHUDCardsExistingBeforeNew()`

Confirmed pre-existing: `git diff 8342959 HEAD -- Islet/SettingsView.swift IsletTests/SettingsViewTests.swift`
shows zero diff — neither file was touched by any 65-01 commit. Root cause is presumably an
`isNew`/card-ordering drift from an earlier phase (last touched in commit `2227ff9`, "gray out
unimplemented Settings cards with Coming Soon"), unrelated to the Quick Actions Bar resolver/
catalog work. Left unfixed per the executor's scope boundary rule — flagged here for whichever
phase next touches `SettingsView.swift` (likely 65-06/65-07, the Settings wiring plans).
