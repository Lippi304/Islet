---
phase: 06-priority-resolver-settings-v1-ship
plan: 11
subsystem: now-playing
tags: [swift, protocol-extraction, code-review-cleanup, mediaremote]

# Dependency graph
requires:
  - phase: 06-priority-resolver-settings-v1-ship
    provides: 06-10's NowPlayingPresentation.swift edits (isSameTrack) — this plan touches a different part of the same file
provides:
  - "TrackSnapshot.hasArtwork dead field deleted from the pure presentation seam and its one construction site"
  - "NowPlayingService protocol in NowPlayingMonitor.swift mirroring the class's exact public surface"
  - "NotchWindowController's nowPlayingMonitor stored property typed against NowPlayingService, not the concrete class"
affects: [now-playing, notch-window-controller]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "NowPlayingService protocol seam per CLAUDE.md's MediaRemote isolation mandate — future Apple breaks are a one-file swap of the concrete NowPlayingMonitor conformer"

key-files:
  created: []
  modified:
    - Islet/Notch/NowPlayingPresentation.swift
    - Islet/Notch/NowPlayingMonitor.swift
    - Islet/Notch/NotchWindowController.swift
    - IsletTests/NowPlayingPresentationTests.swift

key-decisions:
  - "hasArtwork removed entirely rather than kept-but-unused — it was never read outside constructors/tests, confirmed by fresh reads of nowPlayingPresentation(from:) and isSameTrack"
  - "NowPlayingService protocol excludes init (AnyObject-conforming protocols don't need to mirror initializers); the controller still constructs the concrete NowPlayingMonitor directly at its one construction site"
  - "stop() marked nonisolated in the protocol to match the class, so the controller's nonisolated deinit keeps compiling through the protocol-typed property under strict concurrency checking"

requirements-completed: [NOW-01, NOW-03]

# Metrics
duration: ~15min
completed: 2026-07-02
---

# Phase 6 Plan 11: Now-Playing Bridge Gap Closure Summary

**Deleted the dead `TrackSnapshot.hasArtwork` field and introduced a `NowPlayingService` protocol seam so `NotchWindowController` no longer holds the concrete `NowPlayingMonitor` class directly, closing CLAUDE.md's explicit MediaRemote isolation mandate.**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-07-01T22:05:00Z (approx)
- **Completed:** 2026-07-01T22:20:32Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- Removed the unread `hasArtwork: Bool` field from `TrackSnapshot`, its single construction site in `NowPlayingMonitor.start()`, and all 10 test construction call sites in `NowPlayingPresentationTests.swift`
- Extracted a `NowPlayingService` protocol above `NowPlayingMonitor` mirroring its exact public surface (`start`, `nonisolated stop`, `togglePlayPause`, `nextTrack`, `previousTrack`, `runHealthCheck(then:)`)
- `NowPlayingMonitor` now conforms to `NowPlayingService`; `NotchWindowController`'s stored property is re-typed as `NowPlayingService?` with zero call-site edits elsewhere in the file
- Full test suite (124 tests) and build both green under Swift's strict-concurrency checker with the `nonisolated` protocol requirement in place

## Task Commits

Each task was committed atomically:

1. **Task 1: Delete the dead TrackSnapshot.hasArtwork field** - `bf502a4` (refactor)
2. **Task 2: Extract NowPlayingService protocol and type the controller's stored property against it** - `fb7eeb7` (refactor)

_Note: this plan has no docs/plan-metadata commit in worktree mode — the orchestrator commits SUMMARY.md separately after merge._

## Files Created/Modified
- `Islet/Notch/NowPlayingPresentation.swift` - `TrackSnapshot` struct loses the unread `hasArtwork` field
- `Islet/Notch/NowPlayingMonitor.swift` - drops `hasArtwork` from its one `TrackSnapshot(...)` construction site; adds `protocol NowPlayingService: AnyObject` above the class and makes `NowPlayingMonitor` conform to it
- `Islet/Notch/NotchWindowController.swift` - `private var nowPlayingMonitor: NowPlayingMonitor?` retyped to `private var nowPlayingMonitor: NowPlayingService?`; all 8 call sites (declaration, construction, 3 transport closures, settings-toggle stop, deinit stop) otherwise unchanged
- `IsletTests/NowPlayingPresentationTests.swift` - all 10 `TrackSnapshot(...)` construction call sites drop the trailing `hasArtwork:` argument

## Decisions Made
- Confirmed via fresh read that `isSameTrack` (added by 06-10 in the same file) never references `hasArtwork`, so deleting the field is safe with no ripple into 06-10's logic
- `NowPlayingService`'s `init` was deliberately left out of the protocol — the controller only ever constructs the concrete `NowPlayingMonitor` type at its single construction site in `startNowPlayingMonitor()`; the protocol governs the post-construction lifecycle/transport surface only
- `stop()` kept `nonisolated` in the protocol declaration specifically so the controller's nonisolated `deinit` continues to compile calling it through the protocol-typed property — verified by a clean strict-concurrency build

## Deviations from Plan

None - plan executed exactly as written. The plan document referenced "12 existing" `hasArtwork` test call sites; the actual count in the current file was 10 (the file evolved since the plan's interface excerpt was captured, consistent with the plan's own warning to "re-read fresh, do not rely on stale line numbers"). All 10 were located via `grep -n "hasArtwork"` before editing and all were updated; the acceptance criterion (`grep -rn "hasArtwork"` returns zero matches, full suite green) was met exactly as specified.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
Both Finding 13 (dead `hasArtwork` field) and Finding 14 (missing `NowPlayingService` protocol seam) from the fresh multi-agent code review are closed. `NotchWindowController.swift` now satisfies CLAUDE.md's "isolate all now-playing code behind one Swift protocol/service" mandate with zero behavioral change — full 124-test suite green, build succeeds under Swift's strict-concurrency checker. No blockers for subsequent Phase 6 gap-closure plans in this wave.

---
*Phase: 06-priority-resolver-settings-v1-ship*
*Completed: 2026-07-02*
