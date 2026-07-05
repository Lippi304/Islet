---
phase: 10-trial-lockout-gate
plan: 03
subsystem: licensing
tags: [appkit, nsstatusitem, swiftui, settings, trial-ux]

# Dependency graph
requires:
  - phase: 10-trial-lockout-gate (plan 01)
    provides: "TrialManager.shared (recordFirstLaunchIfNeeded/trialStartDate/debugResetTrial) and LicenseState.shared (isEntitled/DebugOverride) consumed directly per the plan's interface contract"
provides:
  - "AppDelegate first-launch detection + auto-open of the existing Settings window (TRIAL-02, D-02/D-03)"
  - "D-05 locked-state menu-bar click routing (applyMenuBarClickRouting), re-applied live via a UserDefaults observer"
  - "DEBUG-only secondary status item exposing the 3 stub-flip testing actions (D-08/D-09), fully absent from Release"
  - "SettingsView trial-started notice line (TRIAL-02)"
affects: [10-04-priority-resolver-wiring, 11-settings-ui]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "NSStatusItem.menu vs button.action mutual exclusivity toggle (applyMenuBarClickRouting) for a locked-state click shortcut"
    - "Second, independent NSStatusItem for DEBUG-only controls so they stay reachable regardless of the primary item's click-routing state"
    - "UserDefaults.didChangeNotification observer re-applies derived UI state after any license-state write, mirroring NotchWindowController's existing defaultsObserver pattern"

key-files:
  created: []
  modified:
    - Islet/AppDelegate.swift
    - Islet/SettingsView.swift

key-decisions:
  - "First-launch skips hideSettingsWindowOnLaunch entirely (sets didHideSettingsAtLaunch = true directly) rather than racing it against the auto-open — resolves RESEARCH.md Open Question 1 exactly as recommended (zero flicker risk)"
  - "DEBUG stub controls live on a SEPARATE NSStatusItem, not inside the primary menu, so they remain clickable even while the primary item is in the D-05 locked-click state"
  - "Trial-started notice line placed as a plain Form row (not a Section) before the login-item Toggle, matching the file's existing single-row LabeledContent(\"Version\") precedent"

patterns-established: []

requirements-completed: [TRIAL-01, TRIAL-02, LIC-03]

# Metrics
duration: ~15min
completed: 2026-07-05
---

# Phase 10 Plan 03: AppDelegate/SettingsView Trial & Lockout Wiring Summary

**First-launch Settings auto-open with a trial-started notice, D-05 locked-state menu-bar click routing, and a DEBUG-only 3-action stub-flip status item, all wired into the existing AppDelegate/SettingsView without any new window/alert/notification type**

## Performance

- **Duration:** ~15 min
- **Completed:** 2026-07-05
- **Tasks:** 2 completed
- **Files modified:** 2

## Accomplishments
- `AppDelegate.applicationDidFinishLaunching` now calls `TrialManager.shared.recordFirstLaunchIfNeeded()` before `controller.start()`, so `LicenseState.shared` has a valid trial start date the very first time `updateVisibility()` runs
- First launch skips the existing `hideSettingsWindowOnLaunch()` retry loop entirely and auto-opens the existing Settings window once instead (D-02/D-03) — zero race, zero flicker
- `applyMenuBarClickRouting(isLicensed:)` toggles `statusItem.menu` / `button.action` in mutual exclusion (D-05/Pitfall 3), called once at setup and re-applied live via a `UserDefaults.didChangeNotification` observer whenever license state changes
- A DEBUG-only secondary `NSStatusItem` ("🐞") exposes Force Expired / Force Licensed / Reset Trial (D-08/D-09), fully wrapped in `#if DEBUG` — confirmed absent from the Release build surface via grep and a Debug-config build (Release build itself deferred to wave-merge per the plan's own verification note)
- `SettingsView` now shows "Your 3-day trial started — ends <date>" whenever a trial start date exists, with no Phase 11 (Buy Now/license-key) content pulled forward
- Per D-06, no icon-swap/dimming/badge logic was added anywhere — confirmed via grep (zero matches for `button?.image`/`dimm`/`badge` in the diff)

## Task Commits

Each task was committed atomically:

1. **Task 1: First-launch auto-open, D-05 click routing, DEBUG stub menu** - `2b2c8a4` (feat)
2. **Task 2: Trial-started notice line in SettingsView** - `9badfdd` (feat)

## Files Created/Modified
- `Islet/AppDelegate.swift` - promoted `menu` to a stored property; first-launch detection + auto-open; `applyMenuBarClickRouting` (D-05); `licenseObserver` (UserDefaults-driven re-apply); `#if DEBUG` secondary status item + 3 stub-flip actions (D-08/D-09)
- `Islet/SettingsView.swift` - one conditional `Text` row rendering the trial-started notice, placed before the "Launch Islet at login" toggle

## Decisions Made
- Followed the plan's exact resolution of RESEARCH.md Open Question 1 (skip-the-hide-entirely) and Open Question 2 (3-case `LicenseStatus`, already built in Plan 01) verbatim — no deviations from the specified interface contract.
- DEBUG stub menu uses a second, independent `NSStatusItem` (not a submenu inside the primary menu) per the plan's explicit rationale — keeps the 3 testing actions reachable even while the primary item is nil-menu'd in the locked state.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None. Both tasks' `xcodebuild build -scheme Islet` (Debug) verification commands succeeded on the first attempt. The plan's `<verification>` Release-configuration build is explicitly scoped to wave-merge (not per-task) per `10-VALIDATION.md`'s sampling policy, and is not run by this plan-executor — it will run once this wave's other parallel plan (10-02) also lands.

## Known Stubs

None new. `LicenseState.status`'s pre-existing defensive fallback (documented in 10-01-SUMMARY.md) is unchanged by this plan. `.licensed` remains reachable today only via the DEBUG "Force Licensed" stub action added in this plan — the real Polar.sh path is Phase 12, as designed.

## Threat Flags

None beyond what the plan's own `<threat_model>` already registers (T-10-03 DEBUG-gating, T-10-05 click-routing mutual exclusivity) — both mitigations were implemented exactly as specified and verified via grep in each task's acceptance criteria.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- `AppDelegate` and `SettingsView` are fully wired for TRIAL-02's first-launch notice and LIC-03's locked-state UX; Plan 04 (priority-resolver wiring, wave 3) and Phase 11 (Settings UI against a stubbed `LicenseService`) can build on this directly.
- The Release-configuration build + zero-DEBUG-symbol check specified in this plan's `<verification>` section still needs to run once at wave-merge, alongside Plan 02's own changes to `NotchWindowController`/`FullscreenDetector` — no blocker, just sequencing per the plan's sampling policy.

---
*Phase: 10-trial-lockout-gate*
*Completed: 2026-07-05*
