---
phase: 49-favorite-like-spike
plan: 02
subsystem: infra
tags: [applescript, apple-music, osascript]

# Dependency graph
requires: []
provides:
  - "Honest, on-device-verified verdict for ROADMAP Phase 49 Success Criterion #2 (Apple Music `current track`/`loved` AppleScript reliability): matrix-shows-different-behavior — `name of current track` succeeds in all 4 states, `loved` (get+set) fails uniformly in all 4 states with error -10001, not the -1728 RESEARCH.md predicted"
affects: [49-04-favorite-like-spike, 50-favorite-like-implementation]

# Tech tracking
tech-stack:
  added: []
  patterns: []

key-files:
  created: []
  modified: []

key-decisions:
  - "SC#2 verdict: matrix-shows-different-behavior — RESEARCH.md's -1728 prediction (streaming-only tracks only) did not reproduce; instead `loved of current track` (both get and set) fails with -10001 ('descriptor types don't match') in ALL 4 states (library/streaming x play/pause), while `name of current track` succeeds in all 4 states"
  - "Phase 50's star button cannot use AppleScript `loved` for Apple Music at all on this OS/Music.app build — the property itself is broken via scripting bridge, independent of library/streaming status, so Phase 50 needs a documented Apple-Music-unavailable fallback or an alternative read/write path"

patterns-established: []

requirements-completed: []  # D-05 is a CONTEXT.md decision ID, not a formal REQUIREMENTS.md entry — no REQUIREMENTS.md checkbox to mark for this phase (FAV-01..03 belong to Phase 50)

# Metrics
duration: <1min active (single checkpoint task, no code)
completed: 2026-07-20
---

# Phase 49 Plan 02: Apple Music current track/loved Matrix Summary

**On-device osascript matrix (3 commands x 4 states) found Apple Music's `loved` property broken via AppleScript in every state tested — not the streaming-only -1728 bug RESEARCH.md predicted, but a uniform -10001 descriptor-type error.**

## Performance

- **Duration:** <1 min active work (single checkpoint:human-verify task, no code to write)
- **Started:** 2026-07-20T16:00:00Z (approx)
- **Completed:** 2026-07-20T16:06:00Z (approx)
- **Tasks:** 1 (checkpoint:human-verify)
- **Files modified:** 0

## Accomplishments
- Ran all 12 `osascript` command invocations (3 commands x 4 states: library-playing, library-paused, streaming-playing, streaming-paused) directly against this project's own dev hardware's real Music.app, per D-05.
- Resolved ROADMAP Phase 49 Success Criterion #2 with an honest, on-device-verified verdict that deviates from RESEARCH.md's forum-sourced prediction.

## Task Commits

Task 1 (checkpoint:human-verify) produced no code commit — verification-only, verdict recorded in this file.

**Plan metadata:** (this commit, follows) `docs: complete plan`

## Files Created/Modified
None — this plan is a pure on-device verification spike with no code changes.

## Full Matrix Results (12 command runs)

Commands run in Terminal via `osascript -e` for each state:
```
osascript -e 'tell application "Music" to get name of current track'
osascript -e 'tell application "Music" to get loved of current track'
osascript -e 'tell application "Music" to set loved of current track to true'
```

| State | Track | `name` result | `loved` (get) result | `loved` (set) result |
|---|---|---|---|---|
| Library track, playing/paused (state A) | "Der Pate" | Success — returned "Der Pate" | FAILED: `32:37: execution error: „Music" hat einen Fehler erhalten: Die Typen der Deskriptoren passen nicht. (-10001)` | FAILED: `28:62: execution error: „Music" hat einen Fehler erhalten: Die Typen der Deskriptoren passen nicht. (-10001)` |
| Library track, playing/paused (state B) | "Alpträume" | Success — returned "Alpträume" | FAILED: same `-10001` error | FAILED: same `-10001` error |
| Streaming-only track, playing/paused (state A) | "Diamonds" | Success — returned "Diamonds" | FAILED: same `-10001` error | FAILED: same `-10001` error |
| Streaming-only track, playing/paused (state B) | "Diamonds" | Success — returned "Diamonds" | FAILED: same `-10001` error | FAILED: same `-10001` error |

Confirmed by user: all 4 tracks are real songs (not audiobooks/podcasts); the two "library" tracks were in the user's own playlist (library-resident) but not starred/loved yet, one run playing and one paused; the two "streaming" runs (both "Diamonds") covered one playing and one paused state, with the track confirmed NOT in the user's library/playlist.

## Decisions Made

- **SC#2 verdict — `matrix-shows-different-behavior`:** RESEARCH.md (citing Apple Developer Forums thread 798267) predicted error `-1728` ("Can't get name of current track") specifically for streaming-only tracks, with library tracks working normally. The actual on-device result differs: `name of current track` succeeds in **all 4 states** (library and streaming, playing and paused) — `-1728` never occurred. Instead, `loved of current track` (both `get` and `set`) fails **uniformly in all 4 states** with error `-10001` ("Die Typen der Deskriptoren passen nicht" / "descriptor types don't match"), completely independent of library/streaming status or play state. This points to a different, more fundamental bug: the `loved` property itself appears broken via AppleScript on this OS version/Music.app build, not a streaming-only edge case as RESEARCH.md's forum source predicted.
- **Implication for Phase 50:** Phase 50's star button cannot rely on AppleScript `loved` for Apple Music at all on this hardware/OS/Music.app build — the failure is not scoped to streaming-only tracks (which could be handled as a documented edge case) but blocks read AND write for every track type tested. Phase 50 planning needs either a documented Apple-Music-unavailable/broken-property fallback UI state, or a fresh spike into an alternative read/write mechanism (e.g. a different Apple Music scripting object model path, or Media Player framework equivalent) before committing to AppleScript `loved` as the implementation path.

## Deviations from Plan

None — plan executed exactly as written (a single checkpoint:human-verify task, no code). The *on-device result* deviated from RESEARCH.md's prediction, which is the plan's own expected possible outcome (see plan's `<how-to-verify>` step 5 framing and `<resume-signal>`'s `matrix-shows-different-behavior` option) — not a plan-execution deviation.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Plan 49-04 (consolidated go/no-go) can now read this file for Success Criterion #2's final verdict: **matrix-shows-different-behavior** — `loved` (get+set) fails with `-10001` in all 4 states tested, `name` succeeds in all 4 states. This is a more severe finding than RESEARCH.md's predicted streaming-only `-1728` edge case: it blocks Apple Music `loved` read/write entirely on this hardware, not just for streaming-only tracks.
- Phase 50's planner must budget for either a documented Apple-Music-broken fallback state for the star button, or a fresh investigation into why `loved` fails with `-10001` (possibly an Apple Music scripting-dictionary version mismatch, or a Music.app build regression) before committing to AppleScript `loved` as Apple Music's write path.
- No blockers for Plan 49-03 (Spotify OAuth) or 49-01 (already complete) — Plan 49-04 depends on all three (49-01/49-02/49-03).

---
*Phase: 49-favorite-like-spike*
*Completed: 2026-07-20*
