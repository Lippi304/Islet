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

## Post-checkpoint deviation, round 3 (on-device feedback — supersedes round 2)

**Found during:** Task 3 on-device verification round 2 (user tested round 2's standalone 240×56 blob fix).

**User feedback (verbatim, German):** "Ne es soll das so bleiben und ganz klein darunter, also so hier von DynamicLake geklaut wirklich halt nur leicht weiter nach unten expandieren und den titel mit Sänger rein faden." — the user rejected round 2's fix outright. Two reference screenshots were provided: (1) the CURRENT collapsed media-wings glance (art left, equalizer right) — keep this exactly as-is; (2) a DynamicLake screenshot showing that same top capsule staying visually intact, with a second row fading in directly below it (still one continuous rounded black shape, bottom corners more rounded/blob-like), showing the track title + artist as one line of text, the whole shape only modestly taller than the collapsed capsule. The DynamicLake screenshot also showed transport buttons, but the user's own words only asked for "titel mit Sänger" (title with artist) — no playback controls were requested, and this phase's original scope (18-UI-SPEC.md, ROADMAP, CONTEXT.md D-01) is a passive text-only toast, so no buttons were added.

**Root cause:** Round 2 replaced the wings row ENTIRELY with a different, standalone shape (`songChangeToastView` via `blobShape(... size: Self.toastSize)`) — an either/or branch in `mediaWingsOrToast`. This changed the wings' own look (no equalizer bars visible during a toast) and read as a different UI element popping in, not "the same wings, expanding slightly."

**Fix (redesign, not a tweak):**
- `mediaWingsOrToast` is no longer an if/else between two shapes. It now always renders the SAME content — row 1 (`mediaWingsRow`, factored byte-for-byte out of the old `mediaWings(_:art:)`: art left, equalizer right, unchanged paddings) — and conditionally grows to add row 2 (`toastTextRow`) only while `nowPlaying.songChangeToast` is non-nil.
- The combined shape is built directly (`NotchShape(topCornerRadius: 6, bottomCornerRadius: toast != nil ? 16 : 6)`), sized `width: Self.wingsSize.width` (290, unchanged footprint) and `height: Self.wingsSize.height + (toast != nil ? Self.toastExtraHeight : 0)` — 32pt normally, 64pt with a toast (new `Self.toastExtraHeight = 32` constant replaces round 2's `Self.toastSize`).
- `toastTextRow` renders one combined `Text("\(title) — \(artist)")`, 12pt medium white, `.lineLimit(1)`/`.truncationMode(.tail)`, left-aligned, and carries `.transition(.opacity)` so it fades in/out under the controller's existing spring wrapper (D-08: the view drives no animation of its own — every mutation of `songChangeToast` in `NotchWindowController` already runs inside `withAnimation(.spring(...))`).
- Dead code removed: `Self.toastSize` constant, the round-2 `songChangeToastView` function, and `blobShape`'s round-2 `size:` parameter (checked all three remaining callers — `expandedIsland`/`mediaExpanded`/`mediaUnavailable` — none needed it after the toast stopped being a `blobShape` caller).
- `18-UI-SPEC.md` updated: Design System/Copywriting/Motion-Interaction/Typography/Color rows now describe the round-3 final design (wings unchanged + fading single-line text row, ~64pt total height, bottom corners 16 while toast shows, text-only, no controls), with round 1/round 2 history kept struck through for traceability.

**Files modified:** `Islet/Notch/NotchPillView.swift`, `.planning/phases/18-song-change-toast/18-UI-SPEC.md`

**Commit:** `fc69db2` (fix)

**Build:** `xcodebuild build -project Islet.xcodeproj -scheme Islet -destination 'platform=macOS'` → `BUILD SUCCEEDED`.

**Status:** Task 3 checkpoint remains pending — a THIRD round of on-device verification is needed before NOW-05/NOW-06 can be marked complete. This round changes the STRUCTURE (wings row unchanged + a small fading text row below it) rather than the previous two rounds' size-only tweaks, so verification should specifically confirm the wings row looks identical to before this phase and that only a small text strip appears below it.

**Round 4 (minor tweak, on-device feedback):** Round 3's structure was confirmed working on-device; only the text row's alignment needed fixing — user asked for it centered ("Lass es mittig stehen nicht linksbündig") instead of left-aligned under the art. Fix: `toastTextRow`'s `.frame(... alignment:)` changed from `.leading` to `.center`; wings row untouched. Commit: `6f7fddf` (fix). Build: `BUILD SUCCEEDED`.
