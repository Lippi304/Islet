---
phase: 06-priority-resolver-settings-v1-ship
plan: 10
subsystem: ui
tags: [swiftui, gesture-handling, now-playing, mediaremote, xctest]

# Dependency graph
requires:
  - phase: 06-priority-resolver-settings-v1-ship
    provides: NotchPillView wingsShape(content:) helper (06-09), handleNowPlaying's `previous` capture (06-08)
provides:
  - Tap-to-toggle gesture scoped per-case in NotchPillView so it never competes with the
    expanded media view's transport Buttons (Finding 15)
  - isSameTrack(_:_:) pure helper + artwork-retention logic in handleNowPlaying so album
    art no longer flickers on a same-track nil callback (Finding 16)
affects: [06-verify-work, any future NotchPillView gesture or NowPlayingPresentation changes]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Per-case .onTapGesture scoping instead of one ancestor-level gesture, to avoid
      SwiftUI ancestor/descendant gesture-resolution ambiguity over nested Buttons"
    - "isSameTrack(_:_:) pure comparison over (title, artist) ignoring the playing/paused
      axis, used to gate a conditional (not unconditional) state assignment"

key-files:
  created: []
  modified:
    - Islet/Notch/NotchPillView.swift
    - Islet/Notch/NowPlayingPresentation.swift
    - Islet/Notch/NotchWindowController.swift
    - IsletTests/NowPlayingPresentationTests.swift

key-decisions:
  - "Tap-to-toggle removed from mediaExpanded's reserved Shuffle/Repeat placeholder
     corners (Color.clear frames) as an accepted tradeoff for eliminating gesture
     ambiguity by construction rather than relying on undocumented SwiftUI gesture
     priority between an ancestor TapGesture and descendant Buttons"

patterns-established:
  - "Pattern: scope tap gestures onto leaf views/helpers, not container ancestors,
     whenever the container hosts interactive descendant controls"

requirements-completed: []  # NOT YET — plan paused at Task 3 (on-device checkpoint); do not mark COORD-01/NOW-01/NOW-02 complete until checkpoint approved and plan fully executed.

# Metrics
duration: ~20min (Tasks 1-2 only; Task 3 checkpoint pending)
completed: PENDING — paused at checkpoint
---

# Phase 06 Plan 10: Tap-gesture scoping + artwork retention Summary

**Scoped the island's tap-to-toggle gesture off the expanded media view's transport button row and added a pure isSameTrack(_:_:) helper so previously-loaded album art is retained across a same-track nil-artwork callback instead of flickering to the placeholder.**

## Status: PAUSED AT CHECKPOINT (Task 3)

Tasks 1 and 2 are complete, committed, and verified (full build + full test suite green).
Task 3 is a `checkpoint:human-verify` (`gate="blocking"`) requiring on-device interaction —
tapping transport buttons on the physical notch, playing/pausing real media in Spotify or
Apple Music, and visually observing for artwork flicker. This is inherently a
hands-on-keyboard verification (native macOS background utility with global event monitors
and IOBluetooth/MediaRemote access) that cannot be safely automated by a background worktree
agent — it requires the user's own interactive session on the physical Mac. This SUMMARY is
committed now (per worktree parallel-executor protocol) so Tasks 1-2's work is preserved
even if this worktree is reclaimed before the checkpoint is resolved.

**`workflow.auto_advance` = false and `_auto_chain_active` = false** (confirmed via
`gsd-sdk query config-get`), so per the standard (non-auto) checkpoint protocol this
plan halts here rather than auto-approving.

## Performance

- **Duration so far:** ~20 min (Tasks 1-2)
- **Tasks:** 2 of 3 complete (Task 3 pending human verification)
- **Files modified:** 4

## Accomplishments

- Finding 15 closed structurally: the single ancestor `.onTapGesture { onClick() }` on
  `body`'s outer `ZStack` is gone; the toggle gesture is now scoped individually onto
  `collapsedIsland`, `expandedIsland`, `mediaUnavailable`, the shared `wingsShape(content:)`
  helper (covers all three wing glances), and `mediaExpanded`'s top (non-button)
  art/title/artist/bars `HStack` — never the bottom row holding the transport `Button`s.
- Finding 16 closed: `isSameTrack(_:_:)` added to `NowPlayingPresentation.swift` as a pure,
  unit-tested function; `handleNowPlaying` in `NotchWindowController.swift` now only clears
  `nowPlayingState.artwork` on a nil callback when the track genuinely changed or playback
  stopped (`p == .none || !isSameTrack(previous, p)`) — otherwise it retains the artwork
  already showing.
- Full TDD gate followed for Task 2: RED (4 failing tests referencing the not-yet-existing
  `isSameTrack`, confirmed compile failure) → GREEN (implementation added, all tests pass).
- Full app build (`BUILD SUCCEEDED`) and full test suite (120/120 tests passing, including
  9/9 in `NowPlayingPresentationTests`) confirmed after both tasks.

## Task Commits

Each task was committed atomically:

1. **Task 1: Scope the tap-to-toggle gesture away from the transport button row** - `ee1df46` (fix)
2. **Task 2 (RED): add failing test for isSameTrack** - `cb849f8` (test)
3. **Task 2 (GREEN): retain artwork across a same-track nil callback** - `d2f3d32` (fix)

Task 3 (checkpoint:human-verify) not yet executed — no commit.

**Plan metadata:** (this SUMMARY's own commit, made immediately after this file)

## Files Created/Modified

- `Islet/Notch/NotchPillView.swift` - Removed the container-level `.onTapGesture`; added it
  per-case to `collapsedIsland`, `expandedIsland`, `mediaUnavailable`, `wingsShape(content:)`,
  and `mediaExpanded`'s top HStack only.
- `Islet/Notch/NowPlayingPresentation.swift` - Added `isSameTrack(_:_:)`, a pure
  (title, artist) comparison ignoring the playing/paused axis.
- `Islet/Notch/NotchWindowController.swift` - `handleNowPlaying` now conditionally assigns
  `nowPlayingState.artwork`: direct assignment when `art` is non-nil; otherwise cleared only
  on a genuine track change/stop, retained on a same-track nil callback.
- `IsletTests/NowPlayingPresentationTests.swift` - 4 new tests: `testIsSameTrackAcrossPlayPause`,
  `testIsSameTrackDifferentTitle`, `testIsSameTrackStopClears`, `testIsSameTrackBothNoneIsFalse`.

## Decisions Made

- Tap-to-toggle intentionally dropped from the reserved Shuffle/Repeat placeholder corners in
  `mediaExpanded` (the `Color.clear.frame(width: 28, height: 28)` slots) — a minor, explicitly
  accepted tradeoff per the plan's own action text, in exchange for eliminating the gesture
  ambiguity by construction rather than depending on undocumented SwiftUI gesture-priority
  resolution between an ancestor `TapGesture` and descendant `Button`s.
- `isSameTrack` deliberately ignores the playing/paused axis (compares only `(title, artist)`)
  so a play↔pause transition on the same track still reads as "same track" and retains
  artwork, per the plan's behavior spec.

## Deviations from Plan

None - Tasks 1 and 2 executed exactly as written, including the TDD RED/GREEN sequence.

## Issues Encountered

None for Tasks 1-2. Task 3 (on-device checkpoint) requires human interaction on the physical
notch Mac (rapid transport-button tapping, real Spotify/Apple Music playback, visual artwork-
flicker observation) and cannot be completed by this automated agent — this is the expected,
planned halt point (`checkpoint:human-verify`, `gate="blocking"`), not an error.

## User Setup Required

None - no external service configuration required. Task 3 requires the user to build/launch
the app and interact with it on-device; no credentials or accounts needed.

## Next Phase Readiness

- Tasks 1-2's code changes are complete, committed, and covered by the full automated test
  suite (build + 120 tests green).
- Plan 06-10 is NOT complete: `requirements-completed` above is deliberately left empty and
  should NOT be marked done in ROADMAP.md/REQUIREMENTS.md until Task 3's on-device checkpoint
  is approved by the user (see the CHECKPOINT REACHED message returned alongside this SUMMARY).
- A continuation agent (or the user directly) must build+launch `Islet.app`, perform the three
  on-device checks described in the plan's Task 3, and either approve or report issues before
  this plan can be marked complete.

---
*Phase: 06-priority-resolver-settings-v1-ship*
*Completed: PENDING (paused at Task 3 checkpoint)*
