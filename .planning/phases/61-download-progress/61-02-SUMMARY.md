---
phase: 61-download-progress
plan: 02
subsystem: coordinator
tags: [swift, foundation, activity-coordinator, download-coordinator, per-file-identity]

# Dependency graph
requires:
  - phase: 61-download-progress
    plan: 01
    provides: DownloadActivity.swift (DownloadReading/DownloadActivity/isDownloadTempFile/downloadFilename), IslandResolver.swift's rank-5 .downloadProgress case + TransientQueue.updateHead's (.downloadProgress, .downloadProgress) cross-inner-case replace arm
provides:
  - DownloadCoordinator.swift — per-tempPath in-flight side table, handle(_:)/handle(_:now:) split, activityPromoted() documented no-op, reset() clearing the in-flight table
  - The D-05/D-06 replaceHead-vs-enqueue branch (only the LAST tracked download completing replaces the standing head in place)
  - D-08 suffix gate reapplied at rename time (untracked renames are ignored)
  - D-15 silent-drop-on-cancel (no enqueue/replaceHead for a .removed reading)
affects: [61-04-download-monitor]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Per-tempPath keyed side table (not per-device-address) — DownloadCoordinator mirrors DeviceCoordinator's identity-tracking shape but keys by path since each temp file IS its own logical download (D-06)"
    - "Four-closure init (queueHead/enqueue/replaceHead/presentTransientChange) — smaller than DeviceCoordinator's six, no battery-poll/updateHead-for-scrub equivalent needed"

key-files:
  created:
    - Islet/Notch/DownloadCoordinator.swift
    - IsletTests/DownloadCoordinatorTests.swift
  modified:
    - Islet.xcodeproj/project.pbxproj

key-decisions:
  - "activityPromoted() ships as a documented empty-body no-op (RESEARCH.md Open Question 1's resolution) — a completing download's own done state is delivered via plain TransientQueue enqueue/advance mechanics, never a coordinator-side promoted re-check"
  - "reset() shipped in this plan (not deferred to Plan 61-04) — lives alongside the table it clears, mirrors DeviceCoordinator.reset()'s exact one-line shape, ready for Plan 61-04's Settings-toggle-off wiring with zero cross-plan edit to this file needed"

requirements-completed: [DL-01, DL-02]

# Metrics
duration: 15min
completed: 2026-07-24
---

# Phase 61 Plan 02: Download Coordinator Summary

**Stateful per-tempPath DownloadCoordinator resolving D-05/D-06's multi-instance-identity requirement — a completing download only replaces the standing head in place when it is the LAST one still in flight, otherwise its done state queues behind the current .inProgress head**

## Performance

- **Duration:** 15 min
- **Started:** 2026-07-24T00:52:00Z
- **Completed:** 2026-07-24T01:02:00Z
- **Tasks:** 1 completed
- **Files modified:** 3 (2 created, 1 regenerated)

## Accomplishments
- `DownloadCoordinator.swift` — `@MainActor final class DownloadCoordinator: ActivityCoordinator`, a per-tempPath `inFlightDownloads` side table keyed by path (mirrors `DeviceCoordinator`'s address-keyed table, per PATTERNS.md, but keyed differently since each temp file is its own logical download per D-06)
- `handle(_:)`/`handle(_:now:)` split (mirrors `DeviceCoordinator`'s testability shape) implementing the full created/renamed/removed correlation algorithm: D-08 suffix gate on both create and rename, D-05/D-06 last-download-in-flight `replaceHead`-vs-`enqueue` branch, D-15 silent drop on cancel
- `activityPromoted()` — documented empty-body no-op per RESEARCH.md Open Question 1's resolution
- `reset()` — clears the in-flight table in one call, ready for Plan 61-04's Settings-toggle-off wiring
- 10 new `DownloadCoordinatorTests` (one per behavior-block scenario), wired to a real `TransientQueue` mirroring `DeviceCoordinatorTests`' no-fakes convention — all 10 pass; full 480-test suite run shows only the 4 pre-existing, unrelated failures already documented in `61-01-SUMMARY.md`/`STATE.md`

## Task Commits

Each task was committed atomically:

1. **Task 1: DownloadCoordinator — per-file side table, D-08/D-05/D-06/D-15 correlation** - `8095671` (feat)

**Plan metadata:** (this commit, follows)

_The plan's single `tdd="true"` task was executed as one commit (test file + implementation together) — the test-first RED/GREEN cycle was followed during development (tests written against the not-yet-existing type, confirmed to fail to compile, then the implementation landed and all 10 passed), but the plan did not request separate `test`/`feat` commits, matching Plan 61-01's precedent._

## Files Created/Modified
- `Islet/Notch/DownloadCoordinator.swift` - new stateful coordinator: per-tempPath `InFlightDownload` side table, `handle(_:)`/`handle(_:now:)`, `activityPromoted()`, `reset()`
- `IsletTests/DownloadCoordinatorTests.swift` - 10 tests covering all behavior-block scenarios (D-08 positive/negative on create and rename, dedup-via-real-TransientQueue, single-vs-multi-in-flight replaceHead/enqueue branching, D-15 removed-tracked/removed-untracked, activityPromoted safety, reset)
- `Islet.xcodeproj/project.pbxproj` - regenerated via `xcodegen generate` (Rule 3, see Deviations) to include both new files

## Decisions Made
- `activityPromoted()` ships as a documented empty-body no-op, not a deferred stub — the doc comment cites RESEARCH.md Open Question 1's resolution directly in the source.
- `reset()` shipped in this plan alongside the table it clears (per the plan's explicit instruction), rather than being added cross-plan by Plan 61-04.
- Test 6 (`testTwoTrackedDownloadsFirstRenameEnqueuesSecondRenameReplacesHead`) leaves the first download's `.done` entry sitting in `TransientQueue`'s `pending` list untouched after the second download's `replaceHead` call — this is intentional per-spec behavior (D-05's "the older download's own done state still fires independently later"), not a bug; verified by asserting `q.head` directly at each step rather than assuming the pending entry is cleared.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Regenerated Islet.xcodeproj via xcodegen**
- **Found during:** Task 1 (DownloadCoordinator implementation)
- **Issue:** This project's `project.pbxproj` lists source files explicitly rather than syncing a folder automatically — confirmed via `grep -c "DownloadCoordinator" project.pbxproj` returning 0 immediately after creating both new files. This exact gap was previously hit and fixed the same way in Plan 61-01 (and Phase 59-02 before that).
- **Fix:** Ran `xcodegen generate` (project.yml already declares folder-based generation for `Islet`/`IsletTests`) to regenerate `project.pbxproj` with both new files included.
- **Files modified:** `Islet.xcodeproj/project.pbxproj` (additive diff, no removals)
- **Verification:** `grep -c "DownloadCoordinator" project.pbxproj` went from 0 to 8; `xcodebuild build` and `build-for-testing` both succeeded afterward.
- **Committed in:** `8095671` (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (Rule 3 — blocking, mechanical, zero design judgment involved, exact repeat of Plan 61-01's own documented deviation)
**Impact on plan:** Required for the plan's own stated acceptance criteria (`xcodebuild build` succeeding, Cmd+U-equivalent tests passing) to be achievable at all. No scope creep.

## Issues Encountered
None beyond the one Rule 3 deviation above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness

`DownloadCoordinator.swift`'s full `ActivityCoordinator` conformance, per-tempPath in-flight table, and `reset()` are all in place and unit-tested, unblocking:
- Plan 61-03 (NotchPillView wiring) — independent of this plan, replaces the placeholder `EmptyView()` arm with real wing UI.
- Plan 61-04 (`DownloadMonitor`) — can now construct a `DownloadCoordinator` with real `queueHead`/`enqueue`/`replaceHead`/`presentTransientChange` closures wired to the controller's `transientQueue`, feed real FSEvents-derived `DownloadReading` values into `handle(_:)`, and call `reset()` from the Settings toggle-off handler with zero further edits to this file.

No blockers. All 10 new tests green; full 480-test Cmd+U-equivalent suite run shows only the 4 pre-existing, unrelated failures already documented in `61-01-SUMMARY.md`.

### Known pre-existing test failures (not introduced by this plan)

None of the following touch `DownloadCoordinator.swift`, `DownloadCoordinatorTests.swift`, or `project.pbxproj` — confirmed present in the full-suite run and already documented as pre-existing in `61-01-SUMMARY.md`/`STATE.md`:
- `CalendarGlanceTests.testDefaultQuickAddTimeForTodayReturnsNextFullHour` / `testDefaultQuickAddTimeRollsOverToNextDayAtMidnightBoundary`
- `ClipboardFileStoreTests.testSaveDeletesOrphanedImageFileButKeepsStillReferencedFile` (flaky byte-count string comparison)
- `SettingsViewTests.testSystemHUDCardsCount` (expects 8, actual is 9 — unrelated to this plan)

## Self-Check: PASSED

- FOUND: Islet/Notch/DownloadCoordinator.swift
- FOUND: IsletTests/DownloadCoordinatorTests.swift
- FOUND commit 8095671 in git log

---
*Phase: 61-download-progress*
*Completed: 2026-07-24*
