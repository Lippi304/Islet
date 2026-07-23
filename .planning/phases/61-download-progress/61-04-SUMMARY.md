---
phase: 61-download-progress
plan: 04
subsystem: system-glue
tags: [swift, fsevents, coreservices, download-monitor, notchwindowcontroller-wiring]

# Dependency graph
requires:
  - phase: 61-download-progress
    plan: 01
    provides: DownloadReading/DownloadEventKind (DownloadActivity.swift) this monitor lifts FSEvents callbacks into
  - phase: 61-download-progress
    plan: 02
    provides: DownloadCoordinator's four-closure init (queueHead/enqueue/replaceHead/presentTransientChange), handle(_:), reset()
provides:
  - DownloadMonitor.swift — FSEventStreamCreate wrapper watching only ~/Downloads, top-level-only filtering (Pitfall 1), cross-batch rename correlation via a per-fileID side table (Pitfall 2/3), idempotent start()/nonisolated stop()
  - NotchWindowController's downloadCoordinator construction (Focus-preempt-aware enqueue, OSD-style in-place replaceHead) and downloadMonitor ownership/lifecycle (launch-time gate, Settings-toggle-gated start/stop, deinit teardown)
  - TransientCategory/flushTransients exhaustive coverage for .downloadProgress
affects: [61-05-on-device-uat]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "FSEvents C-callback bridging via Unmanaged.passUnretained/fromOpaque (FSEventStreamContext.info), with all per-event dictionary/pointer extraction happening INSIDE the free-function callback before handing plain values to a MainActor.assumeIsolated block — avoids both a captured-self @convention(c) closure (impossible) and an unsafe async hop past the callback's pointer-validity window"

key-files:
  created:
    - Islet/Notch/DownloadMonitor.swift
  modified:
    - Islet/Notch/NotchWindowController.swift
    - Islet.xcodeproj/project.pbxproj

key-decisions:
  - "MainActor.assumeIsolated (not DispatchQueue.main.async) bridges the FSEvents C callback into the @MainActor DownloadMonitor instance — the callback is scheduled on FSEventStreamSetDispatchQueue(.main), so it is genuinely already on the main queue/thread; async-dispatching would be both redundant and unsafe, since eventPaths/eventFlags are only valid for the callback's own duration and must be extracted into plain Swift values synchronously first"

requirements-completed: [DL-01, DL-02]

# Metrics
duration: 20min
completed: 2026-07-24
---

# Phase 61 Plan 04: Download Monitor & Controller Wiring Summary

**New FSEventStreamCreate-based DownloadMonitor watching only ~/Downloads (top-level filtering + cross-batch rename correlation), wired into NotchWindowController exactly like CapsLockMonitor with a Focus-preempt-aware/OSD-style downloadCoordinator construction**

## Performance

- **Duration:** ~20 min
- **Completed:** 2026-07-24T01:12:12+02:00
- **Tasks:** 2 completed
- **Files modified:** 3 (1 created, 2 modified/regenerated)

## Accomplishments
- `DownloadMonitor.swift` — `@MainActor final class DownloadMonitor` cloning `CapsLockMonitor`'s lifecycle skeleton (idempotent `start()`, `nonisolated stop()`, empty `deinit`) minus the Accessibility gate; watches only `NSHomeDirectory()/Downloads` via `FSEventStreamCreate` with `kFSEventStreamCreateFlagFileEvents | UseCFTypes | UseExtendedData`, `sinceWhen: kFSEventStreamEventIdSinceNow` (D-14), 0.3s latency, scheduled on `DispatchQueue.main`
- Pitfall 1 (top-level-only filtering): every event's `deletingLastPathComponent` must exactly equal the watched Downloads path or it's skipped, so writes inside a Safari `.download` bundle's own contents never re-fire `onEvent`
- Pitfall 2/3 (cross-batch rename correlation): a `pendingRenamesByFileID: [UInt64: String]` side table pairs a rename's "moved away"/"moved to" halves across separate callback batches via the per-event file ID (from `kFSEventStreamCreateFlagUseExtendedData`), degrading gracefully to plain create/remove when a file ID or a matching pending entry is unavailable
- `NotchWindowController` now owns `downloadCoordinator`/`downloadMonitor` exactly like `deviceCoordinator`/`capsLockMonitor`: `downloadCoordinator` is constructed with a Focus-preempt-aware `enqueue` (mirrors `deviceCoordinator`'s own shape verbatim) and an OSD-style in-place `replaceHead` (`updateHead` + spring re-render + `scheduleActivityDismiss()` re-arm, mirrors `handleOSDKeyPress`'s branch verbatim); `startDownloadMonitor()` mirrors `startCapsLockMonitor()`'s idempotent shape; the launch-time gate and `handleSettingsChanged()`'s toggle-off branch (which also calls `downloadCoordinator.reset()` and `flushTransients(.downloadProgress)`) both gate on `ActivitySettings.downloadProgressKey`
- `TransientCategory`/`flushTransients` gained a `.downloadProgress` case (`syncActivityModels()` already had it from Plan 61-01's Rule-3 deviation); `deinit` gained `downloadMonitor?.stop()`

## Task Commits

Each task was committed atomically:

1. **Task 1: DownloadMonitor (net-new FSEvents wrapper)** - `62f6ad6` (feat)
2. **Task 2: NotchWindowController wiring** - `146b9a9` (feat)

**Plan metadata:** (this commit, follows)

## Files Created/Modified
- `Islet/Notch/DownloadMonitor.swift` - new FSEvents wrapper: `start()`/`stop()`, `handleBatch(_:)`, the free-function C callback `downloadMonitorFSEventsCallback`
- `Islet/Notch/NotchWindowController.swift` - `downloadCoordinator`/`downloadMonitor` properties + construction, `startDownloadMonitor()`, launch-time gate, `handleSettingsChanged()` toggle block, `TransientCategory`/`flushTransients` `.downloadProgress` coverage, `deinit` teardown
- `Islet.xcodeproj/project.pbxproj` - regenerated via `xcodegen generate` to include the new file

## Decisions Made
- The FSEvents C callback (`downloadMonitorFSEventsCallback`) extracts every event's path/fileID/flags into plain Swift values BEFORE calling into the `@MainActor`-isolated instance, then hands off via `MainActor.assumeIsolated { monitor.handleBatch(events) }` rather than `DispatchQueue.main.async` — the callback is already guaranteed to run on the main queue (`FSEventStreamSetDispatchQueue(stream, .main)`), and the raw `eventPaths`/`eventFlags` pointers FSEvents supplies are only valid for the callback's own duration, so deferring extraction via an async hop would be unsafe.
- `pendingRenamesByFileID` is a table private to `DownloadMonitor`, deliberately separate from `DownloadCoordinator`'s own `inFlightDownloads` — one correlates raw FSEvents halves of a single `mv`, the other tracks known-in-progress downloads for the transient queue.

## Deviations from Plan
None — plan executed exactly as written. The FSEvents C-callback bridging shape (Unmanaged pointer passing, extended-data dictionary extraction, `MainActor.assumeIsolated` hop) was verified directly against a real `xcodebuild build` success rather than an external sample repo, since the plan's own Interfaces block flagged RESEARCH.md's sketch as illustrative-only and asked for cross-checking before treating it as final — the compiler is the strongest possible verification of the exact Swift/C bridging shape here.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness

`DownloadMonitor.swift` and `NotchWindowController`'s full ownership/wiring are in place and Debug-build-verified (both `build` and `build-for-testing` succeed with zero new warnings), unblocking:
- Plan 61-05 (on-device UAT) — the one remaining verification this plan's own `<verification>` section explicitly defers: live FSEvents timing/correlation behavior (a real browser download, a real Safari `.download` bundle, rapid multi-file drops, and the Settings-toggle-off live-stop/reset/flush behavior) cannot be asserted via XCTest and needs real hardware.

No blockers.

## Self-Check: PASSED

- FOUND: Islet/Notch/DownloadMonitor.swift
- FOUND commit 62f6ad6 in git log
- FOUND commit 146b9a9 in git log

---
*Phase: 61-download-progress*
*Completed: 2026-07-24*
