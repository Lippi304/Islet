---
phase: 18-song-change-toast
plan: 02
subsystem: ui
tags: [swiftui, appkit, notch-window-controller, checkpoint-pending]

# Dependency graph
requires:
  - phase: 18-song-change-toast
    plan: 01
    provides: TrackToast, songChangeToastContent(...), songChangeToastGate(...), NowPlayingState.songChangeToast, ActivitySettings.songChangeToastKey
provides:
  - Controller wiring: handleNowPlaying detection + scheduleToastDismiss() one-shot timer + toggle-off/interruption live-clear
  - NotchPillView toast render (songChangeToastView + mediaWingsOrToast branch)
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Toast dismiss timer (toastDismissWorkItem) fully independent DispatchWorkItem mirroring scheduleMediaDismiss, never sharing state with mediaDismissWorkItem"
    - "Interruption live-clear inserted at the two single choke points (presentTransientChange() for new-transient-starts, handleClick() for manual-expand) rather than duplicated per caller"

key-files:
  created: []
  modified:
    - Islet/Notch/NotchWindowController.swift
    - Islet/Notch/NotchPillView.swift

key-decisions: []

requirements-completed: []
# NOW-05/NOW-06 code-complete but NOT marked complete here — Task 3 (on-device checkpoint)
# is the plan's own verification gate for these requirements and has not yet run.

# Metrics
duration: ~15min (Tasks 1-2 only; Task 3 checkpoint pending)
completed: 2026-07-09
---

# Phase 18 Plan 02: Song-Change Toast Controller Wiring + Render Summary (Tasks 1-2 of 3)

**Wires Plan 01's pure seam end-to-end: handleNowPlaying detects a genuine song change, gates it through songChangeToastGate, drives a dedicated ~3s auto-dismiss timer, and NotchPillView renders it as a centered expanded blob with title+artist text — code-complete and build-verified, on-device checkpoint (Task 3) not yet run.**

## Performance

- **Duration:** ~15 min (Tasks 1-2)
- **Completed:** 2026-07-09T13:18:44Z (partial — stopped at checkpoint)
- **Tasks:** 2 of 3 completed (Task 3 is a `checkpoint:human-verify`, gate="blocking")
- **Files modified:** 2

## Accomplishments

- `NotchWindowController.handleNowPlaying`: captures the PRE-mutation `hasPlayedSinceLaunch` value (Pitfall 2), evaluates `songChangeToastGate(activeTransient:isExpanded:toastEnabled:)` and `songChangeToastContent(previous:current:hasPlayedSinceLaunch:)` inside the existing spring block AFTER `renderPresentation()` but BEFORE any mutation to `nowPlayingState.songChangeToast` (Pitfall 3 — never schedule-then-suppress), then sets the toast and calls the new `scheduleToastDismiss()`.
- New `toastDismissWorkItem` property + `scheduleToastDismiss()` function, byte-for-byte mirroring `scheduleMediaDismiss(after:)`'s cancel-then-reschedule shape but touching ONLY `nowPlayingState.songChangeToast` (never `presentation`/`artwork`/`position`/`renderPresentation()`/`updateVisibility()`), reusing the existing `activityDuration` (3.0s) constant.
- `handleSettingsChanged()`: toggling `songChangeToastKey` off cancels `toastDismissWorkItem` and clears `nowPlayingState.songChangeToast` live, mirroring the pre-existing `nowPlayingKey` disable branch (Pitfall 4).
- `presentTransientChange()`: clears an in-flight toast the instant `transientQueue.head` transitions nil→non-nil (a new charging/device transient interrupting), covering both interruption paths through this single choke point (RESEARCH.md Pitfall 5).
- `handleClick()`: captures `wasExpanded` before the spring block, clears an in-flight toast the instant the user manually expands (`!wasExpanded && interaction.isExpanded`), the only path that can flip `isExpanded` false→true (RESEARCH.md Pitfall 5, D-04).
- `NotchPillView`: `.nowPlayingWings(let p)` case now calls the new `mediaWingsOrToast(_:)`, which renders `songChangeToastView(_:)` when `nowPlaying.songChangeToast` is non-nil, else falls back unchanged to `mediaWings(p, art:)`. `songChangeToastView` reuses `blobShape(topCornerRadius: 6, bottomCornerRadius: 20)` with default `.center` alignment, a `VStack(spacing: 2)` of bold 15pt title + secondary 12pt artist (both `.lineLimit(1)`/`.truncationMode(.tail)`), `.padding(.horizontal, 16)`.

## Task Commits

1. **Task 1: Controller wiring — detection, ~3s dismiss timer, toggle-off + interruption live-clear**
   - `d198d45` (feat) — `Islet/Notch/NotchWindowController.swift`
2. **Task 2: Toast render — songChangeToastView + mediaWingsOrToast branch**
   - `ff1b35b` (feat) — `Islet/Notch/NotchPillView.swift`

Both tasks verified via `xcodebuild build -project Islet.xcodeproj -scheme Islet -destination 'platform=macOS' -configuration Debug` → `BUILD SUCCEEDED`, run inside this worktree's own project (not a sibling checkout), after each edit.

## Files Created/Modified

- `Islet/Notch/NotchWindowController.swift` — `toastDismissWorkItem` property, `hadPlayedSinceLaunch` capture + toast trigger in `handleNowPlaying`, new `scheduleToastDismiss()`, toggle-off live-clear in `handleSettingsChanged()`, interruption live-clear in `presentTransientChange()` and `handleClick()`
- `Islet/Notch/NotchPillView.swift` — `.nowPlayingWings` case now calls `mediaWingsOrToast(_:)`; new `mediaWingsOrToast(_:)` and `songChangeToastView(_:)` functions added above `mediaWings(_:art:)`

## Decisions Made

None beyond the plan's own pre-documented architecture note (toast gating stays in the controller, never in `resolve(...)` — see 18-01-PLAN.md's "Deviation from RESEARCH.md").

## Deviations from Plan

None — plan executed exactly as written. All acceptance criteria (grep counts on `toastDismissWorkItem` ≥ 6, exactly one `scheduleToastDismiss`/`mediaWingsOrToast`/`songChangeToastView`, gate+content evaluated before mutation, `scheduleToastDismiss()` never touching `presentation`/`artwork`/`position`/`renderPresentation()`/`updateVisibility()`, `wasExpanded` captured before the spring block, `blobShape` called with no `alignment:` argument, `VStack(spacing: 2)`) were verified before each commit via direct grep + Read.

## Issues Encountered

None during Tasks 1-2. Build note: the first `xcodebuild build` invocation was accidentally run against a sibling directory (`/Users/lippi304/conductor/workspaces/notch/algiers`, a separate worktree of the same repo pointed at the same base commit but WITHOUT this plan's edits) due to a `cd`-prefixed command masking which tree was active; this could have produced a false-positive "BUILD SUCCEEDED" that didn't actually exercise the new code. Caught before relying on it — both tasks were re-verified with an explicit `-project Islet.xcodeproj` build run from this worktree's own directory, which does contain the edits, and both builds genuinely succeeded.

## User Setup Required

None for Tasks 1-2 (pure code changes, no new dependencies/config).

## Next Phase Readiness — CHECKPOINT REACHED, NOT PLAN-COMPLETE

Task 3 is a `type="checkpoint:human-verify"` (`gate="blocking"`) requiring on-device manual verification (Xcode Cmd-U for Plan 01's 10 unit tests, then a 10-step on-device Cmd-R checklist covering NOW-05/NOW-06, D-02/D-03/D-04, and the Pitfall 5 interruption live-clear). Per this project's `auto_advance: false` config and the manual-verification-note (native macOS app, no headless test runner for the full suite), this checkpoint cannot be resolved by the executor and is returned to the orchestrator/user as-is. NOW-05/NOW-06 requirements are NOT marked complete in this SUMMARY — that should happen only after Task 3's on-device pass, in whatever follow-up step consumes its "approved" resume-signal.

---
*Phase: 18-song-change-toast*
*Completed: Tasks 1-2 of 3 (checkpoint pending)*

## Self-Check: PASSED

Both modified files and both commit hashes verified present (see below).

## Post-checkpoint deviation: toast sizing (on-device feedback)

**Found during:** Task 3 on-device verification round 1 (user tested the build).

**User feedback (verbatim, German):** "Ja es klappt aber mir klappt die Notch zu viel auf. Die Notch klappt ja jetzt voll auf. Ich meinte die soll nur minimal nach unten expandieren um Autor - Titel anzugeigen klein als text also wirklich so expandieren das der Text nebneinander reinpasst" — the toast opened the full expanded island rather than a minimal glance; wanted title/artist side by side on one line.

**Root cause:** `songChangeToastView(_:)` called the shared `blobShape` helper, which hardcoded `.frame(width: Self.expandedSize.width, height: Self.expandedSize.height)` (360×144) — the SAME frame as `expandedIsland`/`mediaExpanded`/`mediaUnavailable`. The content was also a two-line `VStack` (title over artist). Both the frame size and the two-line layout made the toast visually indistinguishable from a full manual expand. This was per 18-UI-SPEC.md's original (now-incorrect) "reuse blobShape exactly, do not invent a new size" guidance — corrected by this on-device round.

**Fix:**
- `blobShape` parameterized with an optional `size: CGSize = Self.expandedSize` param — default preserves all existing callers (`expandedIsland`/`mediaExpanded`/`mediaUnavailable`) unchanged.
- New `Self.toastSize = CGSize(width: 240, height: 56)` constant — a minimal glance frame, confirmed to fit inside the existing panel bounds (the panel is already sized to the UNION of `expandedFrame`/`wingsFrame` in `NotchWindowController`, so no panel-sizing change was needed).
- `songChangeToastView`'s content changed from a two-line `VStack` to a single-line `HStack` (title bold — em-dash — artist secondary), all `.lineLimit(1)`/`.truncationMode(.tail)` so long strings truncate rather than wrap or grow the blob.
- `songChangeToastView` now calls `blobShape(topCornerRadius: 6, bottomCornerRadius: 20, size: Self.toastSize)`.
- `18-UI-SPEC.md`'s Motion & Interaction Contract ("Shape/frame", "Content alignment") and Copywriting Contract ("Toast content format") rows updated to document the superseded original guidance and the corrected values.

**Files modified:** `Islet/Notch/NotchPillView.swift`, `.planning/phases/18-song-change-toast/18-UI-SPEC.md`

**Commit:** `8007647` (fix)

**Build:** `xcodebuild build -project Islet.xcodeproj -scheme Islet -destination 'platform=macOS'` → `BUILD SUCCEEDED`.

**Status:** Task 3 checkpoint remains pending — this fix needs a fresh round of on-device verification before NOW-05/NOW-06 can be marked complete.
