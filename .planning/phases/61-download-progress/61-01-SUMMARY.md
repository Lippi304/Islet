---
phase: 61-download-progress
plan: 01
subsystem: resolver
tags: [swift, swiftui, foundation, island-resolver, download-activity, pattern-1-seam]

# Dependency graph
requires:
  - phase: 60-caps-lock-update-hud
    provides: the rank-5/6 ActiveTransient precedent (CapsLockActivity/UpdateActivity) this plan's downloadProgress case slots ahead of, and the placeholder-EmptyView() NotchPillView pattern this plan reuses for its own not-yet-built wing UI
provides:
  - DownloadActivity.swift (new Pattern-1 seam) — DownloadEventKind, DownloadReading, DownloadActivity(.inProgress/.done(filename:)), isDownloadTempFile(path:), downloadFilename(fromPath:)
  - IslandPresentation/ActiveTransient.downloadProgress(DownloadActivity) at rank 5 (collapsed-only, sub-state-persistent)
  - resolve()'s new collapsed-only .downloadProgress branch (D-03)
  - ActiveTransient.isPersistent sub-state split (.inProgress true / .done false, D-02/D-13)
  - TransientQueue.updateHead's (.downloadProgress, .downloadProgress) cross-inner-case replace arm
affects: [61-02-download-coordinator, 61-03-notchpillview-wiring, 61-04-download-monitor, 61-05-on-device-uat]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Pattern-1 seam file (raw reading + presentation enum + pure helpers, Foundation-only) — DownloadActivity.swift mirrors DeviceActivity.swift exactly, not the narrower two-case-enum-only sketch in 61-PATTERNS.md"
    - "Sub-state-aware isPersistent split within one ActiveTransient case (downloadProgress(.inProgress) persistent, downloadProgress(.done) not) — first instance of this pattern in the resolver, generalizes beyond the existing whole-case isPersistent checks"

key-files:
  created:
    - Islet/Notch/DownloadActivity.swift
    - IsletTests/DownloadActivityTests.swift
  modified:
    - Islet/Notch/IslandResolver.swift
    - IsletTests/IslandResolverTests.swift
    - Islet/Notch/NotchWindowController.swift
    - Islet/Notch/NotchPillView.swift
    - Islet.xcodeproj/project.pbxproj

key-decisions:
  - "DownloadActivity.swift follows DeviceActivity.swift's Pattern-1 file convention (reading type + presentation enum + pure helpers all in one file), per the plan's own explicit override of 61-PATTERNS.md's narrower framing"
  - "capsLock/updateAvailable ranks shifted 5/6 -> 6/7 (comment-only, D-01) to make room for downloadProgress at rank 5"

patterns-established:
  - "Sub-state-level isPersistent split (Pitfall 4 pattern) — a single ActiveTransient case whose persistence depends on its inner enum case, not the case itself"

requirements-completed: [DL-01, DL-02]

# Metrics
duration: 12min
completed: 2026-07-24
---

# Phase 61 Plan 01: Download Progress Foundation Summary

**New DownloadActivity.swift Pattern-1 seam (DownloadReading/DownloadActivity/D-08 temp-suffix detection/D-12 filename extraction) plus IslandResolver rank-5 wiring with a sub-state-aware isPersistent split (.inProgress never self-elapses, .done self-elapses at ~3s)**

## Performance

- **Duration:** 12 min
- **Started:** 2026-07-23T22:40:38Z
- **Completed:** 2026-07-23T22:52:45Z
- **Tasks:** 2 completed
- **Files modified:** 7 (2 created, 5 modified)

## Accomplishments
- `DownloadActivity.swift` — Foundation-only Pattern-1 seam: `DownloadEventKind`, `DownloadReading` (with a T-61-01 untrusted-path security doc comment), `DownloadActivity` (.inProgress/.done(filename:)), `isDownloadTempFile(path:)` (D-08, 3 known suffixes), `downloadFilename(fromPath:)` (D-12)
- `IslandResolver.swift` — `.downloadProgress(DownloadActivity)` added to both `IslandPresentation` and `ActiveTransient` at rank 5; `resolve()` gates it collapsed-only (D-03); `isPersistent` sub-state split (D-02/D-13); `TransientQueue.updateHead` gained the `(.downloadProgress, .downloadProgress)` cross-inner-case replace arm that Plan 61-02's `DownloadCoordinator` needs to transition `.inProgress` directly to `.done(filename:)`
- 8 new `DownloadActivityTests` + 4 new/2 extended `IslandResolverTests` — 87/87 combined tests pass (0 failures)

## Task Commits

Each task was committed atomically:

1. **Task 1: Pure model — DownloadActivity, DownloadReading, D-08/D-12 helpers** - `68ffb3a` (feat)
2. **Task 2: IslandResolver rank-5 case + sub-state isPersistent + updateHead arm** - `77e1680` (feat)

**Plan metadata:** (this commit, follows)

_Both tasks followed the TDD RED->GREEN cycle (test file written first against the not-yet-existing/not-yet-extended type, confirmed to fail to compile, then the implementation landed) within a single commit each — the plan's own `tdd="true"` tasks did not request separate test/feat commits._

## Files Created/Modified
- `Islet/Notch/DownloadActivity.swift` - new Pattern-1 seam: DownloadEventKind/DownloadReading/DownloadActivity + isDownloadTempFile/downloadFilename
- `IsletTests/DownloadActivityTests.swift` - 8 tests for the above
- `Islet/Notch/IslandResolver.swift` - rank-5 `.downloadProgress` case (both enums), collapsed-only resolve() branch, sub-state isPersistent, updateHead cross-inner-case arm, Resolver-Priority Reference Table comment update
- `IsletTests/IslandResolverTests.swift` - 4 new tests + 2 extended assertions on `testActiveTransientIsPersistentFlags`
- `Islet/Notch/NotchWindowController.swift` - `syncActivityModels()`'s switch completed with a `.downloadProgress` arm (Rule 3, see Deviations)
- `Islet/Notch/NotchPillView.swift` - `presentationSwitch`'s switch completed with a `.downloadProgress: EmptyView()` placeholder arm (Rule 3, see Deviations)
- `Islet.xcodeproj/project.pbxproj` - regenerated via `xcodegen generate` (Rule 3, see Deviations)

## Decisions Made
- `DownloadActivity.swift` built as a full Pattern-1 file (reading type + presentation enum + helpers together), per the plan's explicit interfaces-block instruction overriding 61-PATTERNS.md's narrower sketch — matches `DeviceActivity.swift`'s proven precedent.
- `capsLock`/`updateAvailable` rank comments shifted 5/6 -> 6/7 in both enums, both `resolve()` case-arm comments, and the Resolver-Priority Reference Table — comment-only, zero behavior change (D-01).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Regenerated Islet.xcodeproj via xcodegen**
- **Found during:** Task 2 (IslandResolver rank-5 wiring)
- **Issue:** After adding `Islet/Notch/DownloadActivity.swift` and `IsletTests/DownloadActivityTests.swift` (Task 1), a Task-1-only app build succeeded — but that build never actually compiled either new file, because this project's `project.pbxproj` lists source files explicitly rather than syncing a folder automatically (confirmed: neither file appeared anywhere in `project.pbxproj` even after the Task 1 commit). Once `IslandResolver.swift` (Task 2) referenced `DownloadActivity` by name, the build failed with "cannot find type 'DownloadActivity' in scope" — the new type genuinely wasn't part of the compiled module. This exact gap was previously hit and fixed the same way in Phase 59-02 (`ActivityCard.swift`).
- **Fix:** Ran `xcodegen generate` (project.yml already declares `sources: - path: Islet` / `- path: IsletTests`, i.e. folder-based generation — it just hadn't been re-run since the new files were added) to regenerate `project.pbxproj` with both new files included.
- **Files modified:** `Islet.xcodeproj/project.pbxproj` (8-line additive diff, no removals)
- **Verification:** `grep -c "DownloadActivity" project.pbxproj` went from 0 to 8; subsequent `xcodebuild build` and `build-for-testing` both succeeded.
- **Committed in:** `77e1680` (Task 2 commit)

**2. [Rule 3 - Blocking] Completed 2 now-non-exhaustive switches**
- **Found during:** Task 2 (IslandResolver rank-5 wiring)
- **Issue:** Adding `.downloadProgress(DownloadActivity)` to `ActiveTransient` and `IslandPresentation` made two pre-existing exhaustive switches in other files non-exhaustive: `NotchWindowController.syncActivityModels()` (switches on `transientQueue.head: ActiveTransient?`) and `NotchPillView.presentationSwitch` (switches on `presentation: IslandPresentation`) — neither is in this plan's declared `files_modified` list, but both are direct, mechanical compile-blocking consequences of the new case this plan itself adds.
- **Fix:** `syncActivityModels()` got a `case .downloadProgress: chargingState.activity = nil` arm, identical in shape to the existing `.osd`/`.capsLock`/`.updateAvailable` arms. `presentationSwitch` got a `case .downloadProgress: EmptyView()` placeholder arm — mirroring the exact precedent Phase 60-01 set for `.capsLock`/`.updateAvailable` ("real wing UI ships in a later phase plan"; this phase's real wing UI ships in Plan 61-03).
- **Files modified:** `Islet/Notch/NotchWindowController.swift`, `Islet/Notch/NotchPillView.swift`
- **Verification:** `xcodebuild build` succeeded with zero remaining exhaustiveness errors; full test suite run confirms no behavior regression (download progress renders nothing yet, exactly as intended until Plan 61-03).
- **Committed in:** `77e1680` (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (both Rule 3 — blocking, mechanical, zero design judgment involved)
**Impact on plan:** Both fixes were required for the plan's own stated acceptance criteria (`xcodebuild build` succeeding) to be achievable at all. No scope creep — no new product behavior was added beyond the plan's own contract (the placeholder EmptyView() renders nothing, matching the 60-01 precedent exactly).

## Issues Encountered
None beyond the two Rule 3 deviations above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness

`DownloadActivity.swift`'s types and `IslandResolver.swift`'s rank-5 `.downloadProgress` case, collapsed-only resolve() branch, sub-state `isPersistent`, and cross-inner-case `updateHead` arm are all in place and unit-tested, unblocking:
- Plan 61-02 (`DownloadCoordinator`) — can now call `transientQueue.preempt(.downloadProgress(.inProgress))` and `updateHead(.downloadProgress(.done(filename:)))` exactly as the interfaces block specified.
- Plan 61-03 (NotchPillView wiring) — replaces the placeholder `EmptyView()` arm with real wing UI; this is the one open item this plan intentionally left unfinished (by design, matching the 60-01 CapsLock/UpdateAvailable precedent).
- Plan 61-04 (`DownloadMonitor`) — has `DownloadReading`/`DownloadEventKind` to lift FSEvents callbacks into.

No blockers. Full Cmd+U suite (excluding pre-existing, unrelated failures — see below) is green.

### Known pre-existing test failures (not introduced by this plan)

None of the following touch any file this plan modified (`DownloadActivity.swift`, `IslandResolver.swift`, `NotchWindowController.swift`, `NotchPillView.swift`, their test files, or `project.pbxproj`) — confirmed present in the full-suite run and unrelated to this plan's diff:
- `CalendarGlanceTests.testDefaultQuickAddTimeForTodayReturnsNextFullHour` / `testDefaultQuickAddTimeRollsOverToNextDayAtMidnightBoundary` — already documented as pre-existing in `STATE.md` (Phase 52 note).
- `ClipboardFileStoreTests.testSaveDeletesOrphanedImageFileButKeepsStillReferencedFile` — flaky byte-count string comparison ("41 bytes" != "41 bytes"), unrelated to this plan.
- `SettingsViewTests.testSystemHUDCardsCount` — expects 8, `SettingsView().systemHUDCards.count` is actually 9; neither `ActivityCard.swift` nor `SettingsView.swift` was touched by this plan.
- `AudioOutputMonitorManualSpike.testManualDeviceEnumerationAndSwitch` — failed only in the full-suite parallel run, passed cleanly (60s) when run in isolation; a hardware/timing-dependent manual spike test, unrelated to this plan.

## Self-Check: PASSED

- FOUND: Islet/Notch/DownloadActivity.swift
- FOUND: IsletTests/DownloadActivityTests.swift
- FOUND: Islet/Notch/IslandResolver.swift (modified)
- FOUND: IsletTests/IslandResolverTests.swift (modified)
- FOUND commit 68ffb3a in git log
- FOUND commit 77e1680 in git log

---
*Phase: 61-download-progress*
*Completed: 2026-07-24*
