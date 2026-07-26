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

**Pre-existing LicenseStateTests failures, unrelated to notch scaling:**
- `LicenseStateTests.testActiveTrialReturnsDaysRemaining()` — fails
- `LicenseStateTests.testExpiredTrialReturnsTrialExpired()` — fails
- `LicenseStateTests.testIsEntitledMapping()` — fails
- `LicenseStateTests.testMissingTrialStartDateFallsBackToFreshTrial()` — fails

Confirmed pre-existing via `git stash` + re-run on unmodified code during Plan 06's Task 3 test gate —
same 4 failures with zero Phase 67.1 changes applied. Unrelated to `NotchWindowController.swift`/
`NotchPillView.swift`. Likely tied to the trial-date/DEBUG-override issue already noted in this
session (trial start date mirror uninitialized/expired). Flagging for a future `/gsd-quick` on
`LicenseState`/`TrialManager`.

## From Plan 06 (Collapsed-Pill Live Re-Measurement Fix, D-09/D-10)

**Live Activity HUD overlays (brightness/volume/battery/music) don't scale with the collapsed pill's
live-measured size at non-baseline resolutions:**

During Plan 06's Task 4 on-device UAT, user confirmed the collapsed pill itself now correctly and
immediately matches the real camera cutout after a live resolution switch (D-09/D-10 fixed). But user
also reported: at higher-density resolutions (more points, e.g. 1710×1112) the collapsed pill correctly
shrinks in points to match the smaller real notch (expected D-02/D-09 behavior — collapsed pill is
deliberately never auto-scaled), but the Live Activity HUD overlays that render inside/over it
(brightness, music now-playing, battery/charging — the OSD-style indicators, not the D-01-scaled
expanded content) have their own fixed pixel sizing that doesn't shrink to match, so icons get clipped.
At lower-density resolutions (fewer points, bigger real notch) the reverse — those HUD overlays look
too small for the now-bigger pill. User additionally requested the ability to manually resize these
collapsed-state Live Activity displays.

Out of scope for 67.1-06 (D-09/D-10 only covers the collapsed pill's own geometry, and D-09 explicitly
locks the collapsed pill against D-01/D-03/D-04 scaling — this is a different subsystem, the OSD/Live-
Activity overlay renderers). Flagging as a new gap for a future phase/gsd-discuss-phase covering
Live-Activity-HUD sizing.

## From Plan 10 (Music-Play Wing Camera-Clearance Fix)

**`MeetingMonitorManualSpike.testManualDetectionHeuristic()` fails under a full `xcodebuild test` run,
unrelated to this plan's `NotchPillView.swift` changes:**

The test file's own header comment (`IsletTests/MeetingMonitorManualSpike.swift:4-7`) states: "MANUAL
SPIKE — DO NOT RUN VIA `xcodebuild test` (the full Islet.app test host hangs headless — this project's
established xcodebuild-test-headless-hang precedent). Run via Xcode Cmd-U for THIS single test method
only." It runs a live 3-minute `RunLoop` window expecting a human to join/leave real Zoom/Discord calls
and read console output — it is not a real pass/fail assertion (`XCTAssertTrue(true, ...)` unconditionally
at the end) and was never meant to execute headless in a batch run. Zero relationship to
`mediaWingsOrToast`/`mediaWingsRow`/`mediaWingContentWidth()` (this plan's only changed function group).
Not one of the 6 pre-existing failures already documented above from Plans 02/06, but same category
(pre-existing, environment/harness limitation, not caused by this plan). Not auto-fixed per the scope
boundary rule. Flagging for a future `/gsd-quick` to add an `XCTSkip`/environment guard so full-suite
runs don't report it as a failure.
