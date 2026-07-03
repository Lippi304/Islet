---
phase: 07-now-playing-progress-bar
plan: 01
subsystem: ui
tags: [swiftui, timelineview, media-remote, now-playing, progress-bar]

# Dependency graph
requires:
  - phase: 04-now-playing
    provides: TrackSnapshot pure seam, NowPlayingMonitor MediaRemote glue, NowPlayingState @Published model, mediaExpanded SwiftUI layout
provides:
  - PlaybackPosition pure struct + playbackPosition(from:) + currentElapsedSeconds(...) pure formula in NowPlayingPresentation.swift
  - TrackSnapshot carrying durationMicros/elapsedTimeMicros/timestampEpochMicros/playbackRate
  - NowPlayingState.position published axis
  - ProgressBar SwiftUI view rendered inside mediaExpanded (elapsed/total m:ss labels + accent-filled capsule track)
  - expandedSize grown from 128 to 144pt to fit the new progress row
  - resolvePublishedPosition(...) pure resolver in NowPlayingPresentation.swift — freezes a drift-corrected estimate across a play->pause transition instead of trusting a possibly-stale MediaRemote snapshot
affects: [07-now-playing-progress-bar (Task 3 on-device RE-verification, still pending)]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "TimelineView(.animation(paused:)) idle-CPU gate reused a second time (EqualizerBars precedent) for a ticking display value"
    - "Pure playback-position math (epoch time + rate) isolated in the Foundation-only seam, ported verbatim from the vendored adapter formula, unit-tested outside SwiftUI"
    - "Cross-callback state resolution (previous vs incoming position) kept as a pure, TOTAL function in the seam rather than ad-hoc glue in the controller — mirrors isSameTrack's role as the seam's cross-callback comparison primitive"

key-files:
  created: []
  modified:
    - Islet/Notch/NowPlayingPresentation.swift
    - Islet/Notch/NowPlayingMonitor.swift
    - Islet/Notch/NowPlayingState.swift
    - Islet/Notch/NotchWindowController.swift
    - Islet/Notch/NotchPillView.swift
    - IsletTests/NowPlayingPresentationTests.swift

key-decisions:
  - "TrackSnapshot's 4 new raw fields declared as `var ... = nil` (not `let`) — Swift's synthesized memberwise init only treats a stored property's initializer as a default *parameter* value for `var` properties; `let` properties with an initializer get their memberwise-init parameter dropped entirely, which would have broken every existing 4-arg TrackSnapshot(...) call site in the test file."
  - "Bugfix: on a play->pause transition, prefer OUR OWN drift-corrected estimate (extrapolated from the last known-good playing position) over the incoming snapshot's raw elapsedAtSnapshot — MediaRemote's paused snapshot can carry a stale sample, and this is immune to that upstream sampling lag without needing to touch the untouched currentElapsedSeconds paused-freeze guard."

patterns-established:
  - "Pattern: a second TimelineView(.animation(paused:)) consumer inside the same view file (ProgressBar following EqualizerBars) confirms the idle-CPU gate is the house pattern for any continuously-changing but paused-freezable display value."

requirements-completed: []  # PBAR-01 code-complete; awaiting Task 3 on-device RE-verification approval before being marked done

# Metrics
duration: ~6min (Tasks 1-2) + bugfix pass (Task 3 checkpoint pending re-verification)
completed: 2026-07-03
---

# Phase 07 Plan 01: Now Playing Progress Bar (Tasks 1-2 of 3 + bugfix) Summary

**Playback position plumbed end-to-end (TrackSnapshot -> pure seam -> NowPlayingState -> SwiftUI) and a TimelineView-gated ProgressBar rendered in the expanded Now Playing view. On-device UAT (Task 3) surfaced a pause-transition backward-flash bug, now fixed with a pure drift-corrected resolver — a FRESH on-device re-verification pass is still pending.**

## Performance

- **Duration:** ~6 min (Tasks 1-2) + bugfix pass
- **Started:** 2026-07-03T22:34:00Z (approx)
- **Completed (Tasks 1-2):** 2026-07-03T22:40:00Z
- **Tasks:** 2 of 3 completed (Task 3 is a `checkpoint:human-verify` gate, not executable by an agent)
- **Files modified:** 6 (Tasks 1-2) + 3 (bugfix)

## Accomplishments
- `PlaybackPosition` pure struct + `playbackPosition(from:)` + `currentElapsedSeconds(...)` added to the pure Foundation-only seam, porting the vendored `TrackInfo.Payload.currentElapsedTime` formula verbatim (paused-freeze guard first, per RESEARCH.md Pitfall 1)
- `TrackSnapshot` extended with the 4 raw payload fields; `NowPlayingMonitor` lifts them from the adapter payload
- `NowPlayingState.position` published inside the same spring block as `presentation` in `handleNowPlaying`
- New `ProgressBar` SwiftUI view: `TimelineView(.animation(paused: !(isPlaying && position != nil)))` gate (mirrors the `EqualizerBars` idle-CPU precedent), Unix-epoch-correct elapsed math, clamped fraction, accent-filled/grey-track capsules, m:ss labels styled like the artist text, zero gesture handlers, opacity-based nil fallback
- `expandedSize` grown from 128pt to 144pt to fit the new 20pt progress row
- 4 new unit tests added (13/13 in `NowPlayingPresentationTests`, 135/135 full suite); `xcodebuild build` clean

## Task Commits

Each task was committed atomically:

1. **Task 1: Extend the pure seam and plumb duration/elapsed/timestamp/rate to NowPlayingState** - `fce9378` (feat)
2. **Task 2: Render the ProgressBar in the expanded Now Playing view** - `247506f` (feat)
3. **Task 3: On-device UAT — bar smoothness, paused-freeze, layout fit, inertness** - user ran UAT and reported a bug (see "On-Device UAT Bugfix" below); NOT yet approved — a fresh on-device re-verification pass is required before this checkpoint can close
4. **Bugfix: freeze paused position using drift-corrected estimate instead of stale MediaRemote sample** - `83ca61f` (fix)

**Plan metadata:** not yet committed — plan is not complete until Task 3 is approved.

## On-Device UAT Bugfix

**Reported (German, verbatim):** "Bug den ich sehe wenn man über notch auf pause drückt spult er in der
sekunde kurz 1-3 sekunden zurück aber springt dann wieder auf den richtigen weg also der flasht kurz mit den
sekunden zurück." — Translation: when pausing playback via the notch, the progress bar/elapsed-time briefly
flashes backward by 1-3 seconds, then snaps back to the correct position.

**Root cause:** `handleNowPlaying(_:_:)` assigned `nowPlayingState.position = playbackPosition(from: snapshot)`
directly, trusting the incoming `TrackSnapshot`'s raw `elapsedTimeMicros`/`timestampEpochMicros` fields
verbatim. MediaRemote's paused snapshot can carry a STALE `elapsedTimeMicros` — a periodic position sample
taken 1-3s before the actual pause moment, not freshly resampled at the exact instant `isPlaying` flips to
`false`. Since a paused `currentElapsedSeconds` call just returns `elapsedAtSnapshot` directly (the correct
paused-freeze guard from Task 1, left untouched), the bar rendered that stale, lower elapsed value
immediately — a visible backward jump — until a later, corrected MediaRemote snapshot arrived with the true
paused elapsed value and the bar jumped forward to it. `isPlaying` and `position` are updated atomically from
the same snapshot in the same `withAnimation` block, so this was NOT a race between two independent streams —
it was specifically the snapshot's OWN elapsed/timestamp pair being stale at the moment of a play->pause
transition.

**Fix:** Added `resolvePublishedPosition(...)` to `NowPlayingPresentation.swift` (pure, TOTAL, Foundation-only,
no force-unwraps). On a genuine same-track play->pause transition, it freezes using OUR OWN drift-corrected
estimate — `currentElapsedSeconds` computed from the previously-known PLAYING position, extrapolated to `now`
— instead of trusting the incoming snapshot's raw (possibly stale) `elapsedAtSnapshot`. Every other transition
(resume, track change, stop, repeated paused emission, missing previous/incoming position) passes the incoming
value through unchanged. `NotchWindowController.handleNowPlaying` now captures `previousPosition =
nowPlayingState.position` alongside the existing `previous = nowPlayingState.presentation` capture (before
either is overwritten) and resolves through this function inside the same spring block.

**Tests added:** 6 new cases in `IsletTests/NowPlayingPresentationTests.swift` under `// MARK: PBAR-01 bugfix —
pause-transition position freeze` — freeze-on-play-to-pause-same-track (asserts the exact extrapolated value),
plus 5 pass-through cases (paused->paused, playing->playing, track change, nil previousPosition, nil
incomingPosition). Full suite: 141/141 green. `xcodebuild build` clean.

**Status: Task 3 (on-device UAT) is STILL PENDING.** This fix is code-complete and unit-tested but has NOT been
verified on real notch hardware with real MediaRemote playback — an agent cannot self-certify this. A fresh
on-device re-verification pass by the user is required, re-running the original Task 3 `<how-to-verify>` steps
with particular attention to step 4 (pause playback; confirm the bar and both labels freeze immediately with
zero backward flash and zero drift after 10+ seconds).

## Files Created/Modified
- `Islet/Notch/NowPlayingPresentation.swift` - `PlaybackPosition` struct + `playbackPosition(from:)` + `currentElapsedSeconds(...)`; `TrackSnapshot` gains 4 new `var ... = nil` fields; bugfix adds `resolvePublishedPosition(...)`
- `Islet/Notch/NowPlayingMonitor.swift` - lifts `durationMicros`/`elapsedTimeMicros`/`timestampEpochMicros`/`playbackRate` from the vendored payload into `TrackSnapshot`
- `Islet/Notch/NowPlayingState.swift` - `@Published var position: PlaybackPosition?`
- `Islet/Notch/NotchWindowController.swift` - `handleNowPlaying` assigns `nowPlayingState.position` inside the existing spring block; bugfix captures `previousPosition` and resolves through `resolvePublishedPosition(...)`
- `Islet/Notch/NotchPillView.swift` - new `ProgressBar: View`; `mediaExpanded` wires it in place of the old D-09 spacer; `expandedSize` 128 -> 144
- `IsletTests/NowPlayingPresentationTests.swift` - 4 new PBAR-01 tests (`testPlaybackPositionAllFieldsPresent`, `testPlaybackPositionNilWhenAnyFieldMissing`, `testCurrentElapsedSecondsWhilePlaying`, `testCurrentElapsedSecondsPausedFreezesAtSnapshot`) + 6 new bugfix tests under `// MARK: PBAR-01 bugfix — pause-transition position freeze`

## Decisions Made
- **`var` not `let` for the 4 new `TrackSnapshot` fields:** verified against the toolchain that Swift's synthesized memberwise init only exposes a default-valued parameter for `var` stored properties — a `let` property with an initializer gets silently dropped from the memberwise init parameter list. Using `let` would have broken all 9 pre-existing 4-arg `TrackSnapshot(...)` call sites in the test file at compile time. Confirmed via a standalone `swift` script reproduction before applying the fix. Documented inline in the source.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `TrackSnapshot`'s new fields changed from `let` to `var` to preserve backward-compatible memberwise-init defaults**
- **Found during:** Task 1 (first `xcodebuild test` run after extending `TrackSnapshot`)
- **Issue:** The plan's action text specified adding the 4 new fields "following the struct's existing all-Optional convention" without specifying `let` vs `var`; declaring them as `let ... = nil` compiles fine on its own but silently drops them from the synthesized memberwise initializer's parameter list (Swift compiler behavior, verified via isolated repro), breaking every existing 4-arg `TrackSnapshot(bundleIdentifier:isPlaying:title:artist:)` call site in `NowPlayingPresentationTests.swift` with "Extra arguments at positions #5-#8".
- **Fix:** Changed the 4 new fields from `let` to `var` with the same `= nil` defaults, restoring 4-arg-call compatibility while keeping 8-arg calls (as used in `NowPlayingMonitor.swift` and the new PBAR-01 tests) working.
- **Files modified:** `Islet/Notch/NowPlayingPresentation.swift`
- **Verification:** Full test suite green (135/135), including all pre-existing 4-arg `TrackSnapshot` constructions.
- **Committed in:** `fce9378` (Task 1 commit)

**2. [Rule 1 - Bug] Reworded an in-code comment to avoid tripping Task 2's acceptance-criteria grep**
- **Found during:** Task 2 (acceptance-criteria self-check)
- **Issue:** An explanatory comment inside `ProgressBar`'s body mentioned the literal string `timeIntervalSinceReferenceDate` (naming the WRONG epoch API to warn against using it), which caused the acceptance-criteria check `grep -c "timeIntervalSinceReferenceDate"` scoped to the `ProgressBar` struct body to return `1` instead of the required `0`.
- **Fix:** Reworded the comment to describe the wrong epoch ("the 2001-epoch reference date EqualizerBars' own arbitrary sine-phase clock uses") without spelling out the literal API name, preserving the explanatory intent without tripping the literal-string check.
- **Files modified:** `Islet/Notch/NotchPillView.swift`
- **Verification:** `sed -n '/struct ProgressBar/,/^}/p' ... | grep -c "timeIntervalSinceReferenceDate"` now returns `0`; build still succeeds.
- **Committed in:** `247506f` (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (both Rule 1 - bug fixes required to meet the plan's own stated acceptance criteria)
**Impact on plan:** Both fixes were required for correctness/compile-ability and to satisfy the plan's own acceptance-criteria greps. No scope creep — no behavior beyond what Task 1/Task 2 specified was added.

## Issues Encountered
None beyond the two auto-fixed deviations above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness

**This plan is NOT complete.** Task 3 (`checkpoint:human-verify`, `gate="blocking"`, `autonomous: false`) requires on-device UAT on real notch hardware with real MediaRemote playback (Spotify/Apple Music) — this cannot be fabricated or simulated by an agent. The first UAT pass surfaced the pause-transition backward-flash bug documented above; that bug is now fixed and unit-tested, but the fix itself needs a FRESH on-device re-verification pass — an agent cannot self-certify on-device behavior. Re-run the full original checklist, with extra attention to step 4:

1. Build and run Islet on-device; start playback in Spotify or Apple Music.
2. Expand the island; confirm the progress row appears between art/title/artist and the transport controls, no clipping/cramping.
3. Watch the bar glide continuously (not once-per-second) with the elapsed label incrementing in sync.
4. Pause playback; confirm the bar and both labels freeze immediately — **no backward flash** — with zero drift after 10+ seconds.
5. Click and drag on the bar; confirm zero effect on playback (no seek, no visual response).
6. Resume playback; confirm the bar resumes gliding from the correct (unchanged) position.

Once approved (or further issues triaged and resolved), the plan can be finalized: a follow-up commit should mark `PBAR-01` complete in `REQUIREMENTS.md`, update `STATE.md`/`ROADMAP.md`, and commit final plan metadata — none of which this worktree agent performs (per its instructions, STATE.md/ROADMAP.md are orchestrator-owned).

---
*Phase: 07-now-playing-progress-bar*
*Completed: Tasks 1-2 + bugfix, 2026-07-04 — Task 3 checkpoint pending fresh on-device re-verification*
