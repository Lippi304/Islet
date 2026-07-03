---
phase: 07-now-playing-progress-bar
fixed_at: 2026-07-03T23:00:08Z
review_path: .planning/phases/07-now-playing-progress-bar/07-REVIEW.md
iteration: 1
findings_in_scope: 3
fixed: 3
skipped: 0
status: all_fixed
---

# Phase 7: Code Review Fix Report

**Fixed at:** 2026-07-03T23:00:08Z
**Source review:** .planning/phases/07-now-playing-progress-bar/07-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 3 (critical_warning scope — CR-* and WR-* only; IN-01 and IN-02 excluded)
- Fixed: 3
- Skipped: 0

## Fixed Issues

### CR-01: `ProgressBar.formatTime` traps on NaN/Infinite input despite the comment claiming full defensive coverage

**Files modified:** `Islet/Notch/NotchPillView.swift`
**Commit:** f5604e3
**Applied fix:** Guarded both `elapsed` and `total` for finiteness in `ProgressBar.body` before
they reach `formatTime`/fraction computation (`rawElapsed`/`rawTotal` fall back to `0` when
non-finite), and added a defense-in-depth `guard seconds.isFinite else { return "0:00" }` inside
`formatTime` itself, matching both halves of the review's suggested fix. Verified with
`swiftc -parse` (no errors) and by re-reading the modified section.

### WR-01: Elapsed time text is not clamped to duration, unlike the progress bar fill

**Files modified:** `Islet/Notch/NotchPillView.swift`
**Commit:** 4ada41e
**Applied fix:** Built on the CR-01 finiteness guard by clamping the finite `elapsed` value to
`total` (when `total > 0`) before it is used for both the `Text(Self.formatTime(elapsed))` label
and the fill `fraction`, so the elapsed label can no longer show a value past the track's total
duration. Verified with `swiftc -parse` (no errors) and by re-reading the modified section.

### WR-02: `nowPlayingState.position` is not cleared alongside `presentation`/`artwork` in three teardown paths

**Files modified:** `Islet/Notch/NotchWindowController.swift`
**Commit:** 26c6263
**Applied fix:** Added `nowPlayingState.position = nil` (or `self.nowPlayingState.position = nil`
in the closure call site) immediately next to the existing `artwork = nil` assignment at all
three cited locations: `handleSettingsChanged` (Now Playing disabled branch, ~line 871),
`scheduleMediaDismiss` (~line 1015), and `handleAdapterTerminated` (~line 1032). Restores the
presentation/artwork/position reset symmetry documented elsewhere in the file. Verified with
`swiftc -parse` (no errors) and by re-reading all three modified sections.

## Skipped Issues

None — all in-scope findings were fixed.

---

_Fixed: 2026-07-03T23:00:08Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
