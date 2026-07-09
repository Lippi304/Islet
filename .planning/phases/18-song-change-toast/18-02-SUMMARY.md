---
phase: 18-song-change-toast
plan: 02
subsystem: ui
tags: [swiftui, appkit, notch-window-controller]

# Dependency graph
requires:
  - phase: 18-song-change-toast
    plan: 01
    provides: TrackToast, songChangeToastContent(...), songChangeToastGate(...), NowPlayingState.songChangeToast, ActivitySettings.songChangeToastKey
provides:
  - Controller wiring: handleNowPlaying detection + scheduleToastDismiss() one-shot timer + toggle-off/interruption live-clear
  - NotchPillView toast render: wings row unchanged + fading centered single-line title/artist text row
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Toast dismiss timer (toastDismissWorkItem) fully independent DispatchWorkItem mirroring scheduleMediaDismiss, never sharing state with mediaDismissWorkItem"
    - "Interruption live-clear inserted at the two single choke points (presentTransientChange() for new-transient-starts, handleClick() for manual-expand) rather than duplicated per caller"
    - "Toast renders as a same-shape growth of the existing wings capsule (unchanged row 1 + conditional fading row 2), not a separate blob — matches DynamicLake's visual precedent"
    - "Toast has its own independent dismiss duration (songToastDuration = 2.0s), decoupled from the shared activityDuration (3.0s) used by charging/device splashes"

key-files:
  created: []
  modified:
    - Islet/Notch/NotchWindowController.swift
    - Islet/Notch/NotchPillView.swift
    - .planning/phases/18-song-change-toast/18-UI-SPEC.md

key-decisions:
  - "Toast redesigned mid-plan from a standalone expanded blob to a fading text row grown directly under the unchanged wings capsule, after on-device feedback rejected two blob-based attempts (see Deviations)"
  - "Toast auto-dismiss uses its own 2.0s duration, independent of the shared 3.0s activityDuration used by charging/device transients"

requirements-completed: [NOW-05, NOW-06]

# Metrics
duration: ~15min code (Tasks 1-2) + 5 rounds of on-device iteration (Task 3)
completed: 2026-07-09
---

# Phase 18 Plan 02: Song-Change Toast Controller Wiring + Render Summary

**Wires Plan 01's pure seam end-to-end: handleNowPlaying detects a genuine song change, gates it through songChangeToastGate, drives an independent ~2s auto-dismiss timer, and NotchPillView renders it as the existing wings capsule growing a small fading text row underneath (title — artist), refined over 5 on-device feedback rounds to match a DynamicLake-style reference.**

## Performance

- **Duration:** ~15 min (Tasks 1-2 code) + 5 rounds of on-device iteration (Task 3)
- **Completed:** 2026-07-09
- **Tasks:** 3 of 3 completed (Task 3 checkpoint approved by user after round 5)
- **Files modified:** 3 (2 code, 1 spec doc)

## Accomplishments

- `NotchWindowController.handleNowPlaying`: captures the PRE-mutation `hasPlayedSinceLaunch` value (Pitfall 2), evaluates `songChangeToastGate(activeTransient:isExpanded:toastEnabled:)` and `songChangeToastContent(previous:current:hasPlayedSinceLaunch:)` inside the existing spring block AFTER `renderPresentation()` but BEFORE any mutation to `nowPlayingState.songChangeToast` (Pitfall 3 — never schedule-then-suppress), then sets the toast and calls the new `scheduleToastDismiss()`.
- New `toastDismissWorkItem` property + `scheduleToastDismiss()` function, byte-for-byte mirroring `scheduleMediaDismiss(after:)`'s cancel-then-reschedule shape but touching ONLY `nowPlayingState.songChangeToast` (never `presentation`/`artwork`/`position`/`renderPresentation()`/`updateVisibility()`), using its own independent `songToastDuration` (2.0s — see Deviations round 5).
- `handleSettingsChanged()`: toggling `songChangeToastKey` off cancels `toastDismissWorkItem` and clears `nowPlayingState.songChangeToast` live, mirroring the pre-existing `nowPlayingKey` disable branch (Pitfall 4).
- `presentTransientChange()`: clears an in-flight toast the instant `transientQueue.head` transitions nil→non-nil (a new charging/device transient interrupting), covering both interruption paths through this single choke point (RESEARCH.md Pitfall 5).
- `handleClick()`: captures `wasExpanded` before the spring block, clears an in-flight toast the instant the user manually expands (`!wasExpanded && interaction.isExpanded`), the only path that can flip `isExpanded` false→true (RESEARCH.md Pitfall 5, D-04).
- `NotchPillView`: the toast renders as a growth of the SAME wings shape rather than a separate blob — row 1 (art + equalizer, unchanged) always shows, and a second row fades in below it (centered "title — artist", one line, truncating) only while `nowPlaying.songChangeToast` is non-nil, matching a DynamicLake reference the user provided (final design from round 3, refined in rounds 4-5 — see Deviations).

## Task Commits

1. **Task 1: Controller wiring — detection, ~2s dismiss timer, toggle-off + interruption live-clear**
   - `d198d45` (feat) — `Islet/Notch/NotchWindowController.swift`
2. **Task 2: Toast render — songChangeToastView + mediaWingsOrToast branch (initial version, superseded — see Deviations)**
   - `ff1b35b` (feat) — `Islet/Notch/NotchPillView.swift`
3. **Task 3: On-device checkpoint** — approved by user after round 5 (no dedicated commit; see round commits below)

Both Tasks 1-2 verified via `xcodebuild build -project Islet.xcodeproj -scheme Islet -destination 'platform=macOS' -configuration Debug` → `BUILD SUCCEEDED`, run inside this worktree's own project.

## Files Created/Modified

- `Islet/Notch/NotchWindowController.swift` — `toastDismissWorkItem` property, `hadPlayedSinceLaunch` capture + toast trigger in `handleNowPlaying`, `scheduleToastDismiss()` (independent `songToastDuration`), toggle-off live-clear in `handleSettingsChanged()`, interruption live-clear in `presentTransientChange()` and `handleClick()`
- `Islet/Notch/NotchPillView.swift` — `mediaWingsOrToast(_:)` grows the unchanged wings row with a conditional fading, centered text row (final round-3 redesign, superseding the initial round-1/round-2 standalone-blob approach)
- `.planning/phases/18-song-change-toast/18-UI-SPEC.md` — updated across rounds to document the final design (struck-through history kept for traceability)

## Decisions Made

- Toast gating stays entirely in the controller (`songChangeToastGate`/`songChangeToastContent` called from `handleNowPlaying`), never inside `resolve(...)` — pre-documented architecture note, see 18-01-PLAN.md's "Deviation from RESEARCH.md".
- Toast visual design was redesigned mid-plan (round 3) from a standalone expanded blob to a fading text row grown under the existing wings capsule — see Deviations for the full arc and rationale.
- Toast auto-dismiss decoupled to its own 2.0s duration, independent from the shared 3.0s `activityDuration` used by charging/device transients (round 5).

## Deviations from Plan

### Post-checkpoint iteration (Task 3, rounds 2-5 — on-device feedback)

The plan's originally written design (`songChangeToastView` as a standalone `blobShape` call, per 18-UI-SPEC.md's initial guidance) rendered correctly but did not match what the user actually wanted once seen on-device. Five rounds of on-device verification refined it to the final shape:

1. **Initial render (Task 2, commit `ff1b35b`):** toast rendered via the shared `blobShape` helper, same 360×144 frame as a full manual expand, two-line `VStack` (title over artist).
2. **Round 2 feedback — "too large, looks like a full expand"** (commit `8007647`): user wanted only a minimal glance, title+artist on one line. Fix: parameterized `blobShape` with an optional `size:` (default unchanged for other callers), added a standalone 240×56 `toastSize`, single-line `HStack`. This was itself rejected in round 3.
3. **Round 3 feedback — reference screenshots (DynamicLake), reject the standalone blob entirely** (commit `fc69db2`, the design that stuck): the user wanted the *existing* wings capsule (art + equalizer) to stay visually unchanged and simply grow a little, with a second row of text fading in underneath — not a different shape popping in. Redesigned `mediaWingsOrToast` from an if/else between two shapes into always-render-row-1 (`mediaWingsRow`, factored verbatim out of the old `mediaWings(_:art:)`) + conditionally-added row 2 (`toastTextRow`, combined "title — artist" text, `.transition(.opacity)`). New `Self.toastExtraHeight = 32` constant added to the wings frame height when a toast is active; the round-2 `toastSize` constant and `blobShape`'s `size:` param were removed as dead code (checked all remaining callers first). No transport controls were added — the user's own wording only asked for title/artist text, matching the phase's original text-only scope (18-UI-SPEC.md, ROADMAP, D-01).
4. **Round 4 — centering** (commit `6f7fddf`): text row was left-aligned under the art; user asked for it centered. One-line fix (`.frame(alignment:)` `.leading` → `.center`).
5. **Round 5 — independent dismiss duration** (commit `881d460`): user asked the toast to disappear 1s sooner than before. Added a dedicated `songToastDuration = 2.0` constant used only by `scheduleToastDismiss()`, leaving the shared `activityDuration` (3.0s, still used by `scheduleActivityDismiss()` for charging/device splashes) untouched.

Each round was build-verified (`xcodebuild build` → `BUILD SUCCEEDED`) and documented in `.planning/phases/18-song-change-toast/18-UI-SPEC.md` as it happened, with prior guidance kept struck through for traceability rather than deleted.

**Task 3 (on-device checkpoint): approved by user after round 5.**

## Issues Encountered

Build note (Tasks 1-2): the first `xcodebuild build` invocation was accidentally run against a sibling directory (a separate worktree of the same repo pointed at the same base commit but WITHOUT this plan's edits) due to a `cd`-prefixed command masking which tree was active. Caught before relying on it — both tasks were re-verified with an explicit `-project Islet.xcodeproj` build run from this worktree's own directory, which genuinely succeeded.

## User Setup Required

None — pure code changes, no new dependencies/config. The "Song-Change Toast" toggle in Settings' Activities tab was already added by Plan 01 (default on).

## Next Phase Readiness

Plan 02 complete. NOW-05 (song-change toast trigger/suppress/interrupt semantics) and NOW-06 (Settings toggle, live-clear) are both implemented, on-device verified across 5 iteration rounds, and approved by the user. Phase 18's remaining work (if any) can proceed independently.

---
*Phase: 18-song-change-toast*
*Completed: 3 of 3 tasks*

## Self-Check: PASSED

All modified files and all commit hashes verified present.
