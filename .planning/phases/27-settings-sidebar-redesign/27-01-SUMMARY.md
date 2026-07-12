---
phase: 27-settings-sidebar-redesign
plan: 01
subsystem: settings
tags: [swiftui, appstorage, environmentkey, userdefaults-migration]

requires: []
provides:
  - "ActivitySettings.MaterialStyle enum (gradient/solidBlack)"
  - "4 new Theming keys: materialStyleKey, nowPlayingAccentKey, chargingAccentKey, deviceAccentKey"
  - "4 new EnvironmentKeys: nowPlayingAccent, chargingAccent, deviceAccent, islandMaterialStyle"
  - "ActivitySettings.migrateLegacyAccentIfNeeded() one-time D-08 migration, wired at launch"
affects: [27-02, 27-03]

tech-stack:
  added: []
  patterns:
    - "Per-element @Environment accent keys (one per lively leaf element) replacing a single shared accent key"
    - "One-time UserDefaults migration guarded by 'any new key already set' idempotency check"

key-files:
  created:
    - IsletTests/ActivitySettingsTests.swift
  modified:
    - Islet/ActivitySettings.swift
    - Islet/AppDelegate.swift

key-decisions:
  - "Kept the existing activityAccent EnvironmentKey (did not remove it as the plan's action text literally said) because NotchPillView.swift/NotchWindowController.swift — Plan 02's files, not this plan's — still read it; removing it now would break the Debug build across a plan boundary. Plan 02 migrates those 2 call sites to the 4 new per-element keys and can then retire activityAccent."
  - "Added a top-level `typealias MaterialStyle = ActivitySettings.MaterialStyle` so EnvironmentKey/EnvironmentValues plumbing outside the enum can use the bare name, matching the plan's acceptance-criteria grep pattern exactly."

requirements-completed: [VISUAL-03]

duration: 20min
completed: 2026-07-12
---

# Phase 27 Plan 01: Theming Data-Model Foundation Summary

**MaterialStyle enum + 4 new per-element accent/material `@AppStorage` keys and `EnvironmentKey`s in `ActivitySettings.swift`, plus a one-time D-08 migration seeding the 3 new accent keys from the legacy single `accentIndex` at launch.**

## Performance

- **Duration:** ~20 min
- **Started:** 2026-07-12T19:40:00Z
- **Completed:** 2026-07-12T20:00:01Z
- **Tasks:** 2 completed
- **Files modified:** 3 (1 created, 2 modified)

## Accomplishments
- `ActivitySettings.MaterialStyle: String, CaseIterable { gradient, solidBlack }` with clamp-to-nil parsing of corrupted values (callers apply `?? .gradient`)
- 4 new keys (`materialStyleKey`, `nowPlayingAccentKey`, `chargingAccentKey`, `deviceAccentKey`) and 4 new `EnvironmentKey`s (`nowPlayingAccent`, `chargingAccent`, `deviceAccent`, `islandMaterialStyle`) added alongside the existing accent mechanism
- `migrateLegacyAccentIfNeeded(defaults:)` seeds all 3 new accent keys from the legacy `accentIndexKey` exactly once — no-op on fresh install, idempotent (never clobbers an already-set key), guarded against a corrupted non-Int legacy value
- `AppDelegate.applicationDidFinishLaunching` calls the migration before `controller.start(isFirstLaunch:)`, mirroring the existing `TrialManager.recordFirstLaunchIfNeeded()` ordering precedent
- 8 new pure-logic tests in `IsletTests/ActivitySettingsTests.swift` covering both tasks' behaviors, following the `LicenseStateTests`/`TrialManagerTests` isolation conventions (isolated `UserDefaults(suiteName:)` per migration test)

## Task Commits

1. **Task 1: MaterialStyle enum + 4 new keys/EnvironmentKeys** - `5fe8cc3` (test), `7a28277` (feat)
2. **Task 2: migrateLegacyAccentIfNeeded() + AppDelegate launch wiring** - `4044aaf` (feat; its 3 tests were included in the Task 1 test commit `5fe8cc3` since all 8 tests were written together)

_Note: TDD tasks may have multiple commits (test → feat)._

## Files Created/Modified
- `Islet/ActivitySettings.swift` - Adds `MaterialStyle`, 4 new keys, 4 new `EnvironmentKey`s, `migrateLegacyAccentIfNeeded()`; keeps the legacy `activityAccent` key alive for Plan 02's not-yet-migrated call sites
- `Islet/AppDelegate.swift` - Calls `ActivitySettings.migrateLegacyAccentIfNeeded()` before `controller.start(isFirstLaunch:)`
- `IsletTests/ActivitySettingsTests.swift` - 8 pure-logic tests (new file)

## Decisions Made
- Kept `activityAccent`/`ActivityAccentKey` in place instead of removing it as the plan's action text says, to avoid breaking the Debug build for `NotchPillView.swift`/`NotchWindowController.swift`, which are out of this plan's `files_modified` scope and are Plan 02's responsibility to migrate. Documented as a deviation below.
- Added a top-level `typealias MaterialStyle = ActivitySettings.MaterialStyle` so the `EnvironmentKey`/`EnvironmentValues` plumbing (declared outside the `ActivitySettings` enum, matching the existing file's structure) can reference the bare type name, exactly matching the plan's acceptance-criteria grep pattern (`var islandMaterialStyle: MaterialStyle`).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking issue] Removing `activityAccent` would have broken the Debug build across a plan boundary**
- **Found during:** Task 1
- **Issue:** The plan's action text says to "replace the single `ActivityAccentKey`/`activityAccent` `EnvironmentKey` block with 4 keys." Doing so literally breaks compilation of `Islet/Notch/NotchPillView.swift` (line 76, `@Environment(\.activityAccent)`) and `Islet/Notch/NotchWindowController.swift` (line 1261, `.environment(\.activityAccent, ...)`) — neither file is in this plan's `files_modified` list; both are explicitly Plan 02's responsibility per the plan's own Purpose statement ("Plan 02 ... consume[s] the keys/EnvironmentKeys/enum defined here").
- **Fix:** Kept `ActivityAccentKey`/`activityAccent` unchanged and ADDED the 4 new keys alongside it, rather than replacing. Updated the file's doc comments to explain the migration is pending on Plan 02.
- **Files modified:** `Islet/ActivitySettings.swift`
- **Verification:** `xcodebuild build -project Islet.xcodeproj -scheme Islet -configuration Debug` exits 0
- **Committed in:** `7a28277`

---

**Total deviations:** 1 auto-fixed (Rule 3)
**Impact on plan:** Necessary to keep the Debug build green without expanding this plan's file scope into Plan 02's files. No scope creep — Plan 02 still does the actual call-site migration and can retire `activityAccent` once done.

## Issues Encountered
None beyond the deviation documented above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
Plan 02 (NotchPillView/NotchWindowController) and Plan 03 (SettingsView) can now consume `MaterialStyle`, the 4 new keys, and the 4 new `EnvironmentKey`s defined here. Plan 02 should migrate `NotchPillView.swift`'s `@Environment(\.activityAccent)` read and `NotchWindowController.swift`'s `.environment(\.activityAccent, ...)` write over to the 3 new per-element accent keys (plus wire `islandMaterialStyle`), then retire `activityAccent`/`ActivityAccentKey` from `ActivitySettings.swift`.

---
*Phase: 27-settings-sidebar-redesign*
*Completed: 2026-07-12*

## Self-Check: PASSED
