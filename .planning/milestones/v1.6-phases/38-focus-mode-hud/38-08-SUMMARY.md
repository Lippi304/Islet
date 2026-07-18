---
phase: 38-focus-mode-hud
plan: 08
subsystem: ui
tags: [swiftui, appkit, focus-mode, infocusstatuscenter, notchwindowcontroller]

# Dependency graph
requires:
  - phase: 38-focus-mode-hud (plans 01-07)
    provides: Focus Mode HUD feature (FocusActivity, IslandResolver .focus case, FocusModeMonitor, Settings toggle+popover) plus 38-VERIFICATION.md's defect findings (CR-01, CR-02/WR-02)
provides:
  - "activityEnabled(_:) gives ActivitySettings.focusKey its own false default (all other keys unchanged at true)"
  - "NotchWindowController.focusPermissionGranted() entry point that re-runs handleSettingsChanged()'s start-gate"
  - "SettingsView's Continue button threads requestAuthorization's completion (main-dispatched) into focusPermissionGranted() on success"
affects: [38-focus-mode-hud phase closure, any future work touching NotchWindowController's toggle-gated monitor lifecycle]

# Tech tracking
tech-stack:
  added: []
  patterns: ["Per-key default in activityEnabled(_:) instead of a single shared fallback — precedent for any future activity toggle that must default OFF"]

key-files:
  created: []
  modified:
    - Islet/Notch/NotchWindowController.swift
    - Islet/SettingsView.swift

key-decisions:
  - "Both fixes scoped exactly as VERIFICATION.md specified — no changes to IslandResolver.swift, NotchPillView.swift, TransientQueue, or FocusDetectionSpike.swift"
  - "Task 3 (on-device UAT) deferred to end-of-phase human verification per workflow.human_verify_mode default (config.json has no explicit override) — code-complete, not yet on-device re-confirmed"

requirements-completed: [HUD-05]

# Metrics
duration: 9min
completed: 2026-07-17
---

# Phase 38 Plan 08: Focus Mode HUD Gap Closure (CR-01, CR-02/WR-02) Summary

**Fixed `activityEnabled(_:)`'s shared `?? true` fallback to give `ActivitySettings.focusKey` its own `false` default, and added `NotchWindowController.focusPermissionGranted()` wired from SettingsView's Continue-button completion so a first permission grant starts the Focus monitor immediately.**

## Performance

- **Duration:** 9 min
- **Started:** 2026-07-17T00:58:52Z
- **Completed:** 2026-07-17T01:02:22Z
- **Tasks:** 2 of 3 (Task 3 is an on-device checkpoint, deferred — see below)
- **Files modified:** 2

## Accomplishments
- CR-01 closed in code: `activityEnabled(ActivitySettings.focusKey)` now computes `defaultValue = (key == ActivitySettings.focusKey) ? false : true` instead of a blanket `?? true`, matching `SettingsView.swift`'s `@AppStorage(ActivitySettings.focusKey) private var focusEnabled = false`. Both existing call sites (`start()`, `handleSettingsChanged()`) pick up the corrected default automatically — no call-site edits needed.
- CR-02/WR-02 closed in code: added a non-private `focusPermissionGranted()` on `NotchWindowController` that re-runs `handleSettingsChanged()`; `SettingsView`'s Continue button now threads `requestAuthorization`'s `Bool` completion through `DispatchQueue.main.async` and calls `(NSApp.delegate as? AppDelegate)?.notchController?.focusPermissionGranted()` only `if granted`, reusing the exact access idiom already established for `nowPlayingState.isHealthy`.
- Debug build (`xcodebuild build -scheme Islet -configuration Debug`) succeeds with both fixes in place — `** BUILD SUCCEEDED **`.

## Task Commits

Each task was committed atomically:

1. **Task 1: Fix CR-01 (activityEnabled focusKey default) and CR-02/WR-02 (thread permission-grant completion)** - `ad9dd9c` (fix)
2. **Task 2: Debug build gate** - no commit (verification-only task, no files modified; build succeeded, working tree stayed clean)

**Plan metadata:** committed together with this SUMMARY.md at plan close.

## Files Created/Modified
- `Islet/Notch/NotchWindowController.swift` - `activityEnabled(_:)` now returns a per-key default (`false` for `focusKey`, `true` for every other key); new non-private `focusPermissionGranted()` method added after `startFocusModeMonitor()`
- `Islet/SettingsView.swift` - Continue button's action now threads `requestAuthorization`'s completion through `DispatchQueue.main.async`, calling `focusPermissionGranted()` on the controller only when `granted == true`

## Decisions Made
- No architectural changes needed — both defects were exactly as narrow as VERIFICATION.md described (a one-line default-value bug and a discarded completion handler). No Rule 4 escalation required.
- Confirmed via `git diff`/`git status` that `IslandResolver.swift`, `NotchPillView.swift`, `TransientQueue`, and `FocusDetectionSpike.swift` remain untouched — resolver/queue/view layer scope boundary held.

## Deviations from Plan

None - plan executed exactly as written. Both fixes match the plan's literal code snippets; no auto-fixes, no blocking issues, no additional scope.

## Issues Encountered
None.

## User Setup Required

None - no external service configuration required.

## Human verification needed

Task 3 (`checkpoint:human-verify`, gate: `blocking`) requires an on-device Xcode build+run (Cmd-R) re-verification that cannot be automated in this environment. Per `workflow.human_verify_mode` defaulting to `end-of-phase` (no override present in `.planning/config.json`), this plan's Task 1 (code fix) and Task 2 (Debug build gate) were completed in full; Task 3's content is recorded verbatim below for the phase's end-of-phase verifier to consolidate into `HUMAN-UAT.md`.

**What was built:**
CR-01 fix: `activityEnabled(_:)` now defaults `focusKey` to `false` instead of the shared `true`, so a fresh/toggle-OFF install no longer silently auto-starts Focus monitoring just because OS authorization happens to already be granted.
CR-02/WR-02 fix: granting Focus permission through the in-app "Continue" popover now calls `NotchWindowController.focusPermissionGranted()` on success, which re-runs the same start-gate `handleSettingsChanged()` uses — so the monitor actually starts on the first grant, with no undocumented toggle-off/on or relaunch needed.

**How to verify:**
Open Xcode, build and run Islet on-device (Cmd-R), and perform BOTH of the following scenarios in order. For EACH step, record the VERBATIM observed behavior (not a blanket "approved") — the prior UAT's blanket sign-off is exactly what VERIFICATION.md flagged as insufficient evidence, so precise per-step notes are required this time.

**Scenario A — Fresh-install / toggle-still-OFF auto-start check (CR-01):**
1. Quit Islet if running. In Terminal, run `defaults delete com.yourcompany.Islet activity.focus 2>/dev/null` (or the app's actual bundle identifier — check Settings.app or the Xcode project if unsure) to reset the Focus toggle to its default state, OR confirm via Settings that "Focus Mode HUD" already shows OFF and was never touched this session.
2. Confirm `INFocusStatusCenter` authorization is already granted from a prior session/spike (Settings should show no "Permission needed" hint the first time you open the Focus row, OR you know authorization was granted during Phase 38's earlier spike/UAT on this machine).
3. Relaunch Islet (quit fully, reopen).
4. Toggle macOS Focus/Do Not Disturb ON via Control Center.
5. Record: did the Focus HUD pill appear in the notch? (Expected: NO — the toggle is OFF.)

**Scenario B — First-grant flow without any toggle-off/on workaround (CR-02/WR-02):**
1. If Focus authorization was granted in Scenario A's setup, you'll need a clean unauthorized state to test this properly — if unable to fully revoke `INFocusStatusCenter` authorization via System Settings, note this limitation explicitly rather than skipping the scenario.
2. With authorization NOT yet granted, open Islet Settings and flip "Focus Mode HUD" toggle ON.
3. The permission explanation popover should appear — click "Continue".
4. Grant the OS permission dialog that appears.
5. Do NOT re-toggle the switch off/on, and do NOT relaunch the app.
6. Toggle macOS Focus/Do Not Disturb ON via Control Center.
7. Record: did the Focus HUD pill appear? (Expected: YES, without any additional manual workaround.)

**Resume signal:** Report the verbatim observed result for each numbered step in both scenarios (not just "approved"/"works") — e.g. "Scenario A step 5: HUD did not appear, toggle stayed OFF" and "Scenario B step 7: HUD appeared within ~1s of toggling Focus on, no re-toggle needed."

## Next Phase Readiness
Both CR-01 and CR-02/WR-02 are code-complete and Debug-build-verified. Phase 38 (Focus Mode HUD) is code-complete pending the on-device Task 3 re-verification above — this is the only remaining item before the phase can formally close.

---
*Phase: 38-focus-mode-hud*
*Completed: 2026-07-17*
