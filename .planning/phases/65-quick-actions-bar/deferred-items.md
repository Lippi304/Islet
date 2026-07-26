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

## Pre-existing MeetingMonitorManualSpike flakiness (out of scope for Phase 65)

Phase 65's post-execution regression gate ran the full test suite twice. First run: 3 failures
(the 2 pre-existing `SettingsViewTests` failures above, plus a genuine Phase 65 regression in
`NotchPillViewTests.testOrderedSlotViewsDefaultsToTodaysPillOrder` — fixed live, see that test's
own updated doc comment). Second run (after the fix): 0 failures in `SettingsViewTests`/
`NotchPillViewTests`, but a new single failure in `IsletTests/MeetingMonitorManualSpike.swift`
(`testManualDetectionHeuristic`) — a Phase 63 file untouched by any Phase 65 commit. That file's
own doc comment says it "exercises MicMuteController's read + toggle" against real hardware/app
state (Discord voice-call presence) and is explicitly a manual verification spike, not a
CI-stable regression test. A follow-up isolated re-run reported "Executed 0 tests" yet still
listed the same failure in xcodebuild's summary — inconsistent tooling output, not investigated
further since the file is entirely outside Phase 65's scope. Flagged here for whoever next
revisits Phase 63/Meeting-HUD closure.
