---
phase: 07-now-playing-progress-bar
reviewed: 2026-07-04T00:53:00Z
depth: standard
files_reviewed: 6
files_reviewed_list:
  - Islet/Notch/NowPlayingPresentation.swift
  - Islet/Notch/NowPlayingMonitor.swift
  - Islet/Notch/NowPlayingState.swift
  - Islet/Notch/NotchWindowController.swift
  - Islet/Notch/NotchPillView.swift
  - IsletTests/NowPlayingPresentationTests.swift
findings:
  critical: 1
  warning: 2
  info: 2
  total: 5
status: issues_found
---

# Phase 7: Code Review Report

**Reviewed:** 2026-07-04T00:53:00Z
**Depth:** standard
**Files Reviewed:** 6
**Status:** issues_found

## Summary

Reviewed the Now Playing progress bar feature (PBAR-01): the new pure `PlaybackPosition` /
`currentElapsedSeconds` / `resolvePublishedPosition` seam in `NowPlayingPresentation.swift`,
its wiring through `NowPlayingMonitor.swift` and `NowPlayingState.swift`, the controller glue
in `NotchWindowController.handleNowPlaying`, and the new `ProgressBar` view in
`NotchPillView.swift`, plus the accompanying unit tests.

The pure seam itself (`playbackPosition`, `currentElapsedSeconds`, `resolvePublishedPosition`)
is well-tested and behaves correctly for every traced transition (play→pause freeze, track
change, nil-position pass-through). The defect surface is concentrated in the untested
View-layer math added directly inside `ProgressBar.body`: a genuine crash path
(`Int` conversion of a non-finite `Double`) that the code's own comment claims to guard
against but doesn't, plus a cosmetic clamping gap and a stale-state symmetry gap in the
controller's teardown paths.

## Critical Issues

### CR-01: `ProgressBar.formatTime` traps on NaN/Infinite input despite the comment claiming full defensive coverage

**File:** `Islet/Notch/NotchPillView.swift:568-574` and `:600-603`

**Issue:** The comment at line 572-573 claims: *"Defensive clamp (T-07-02): a zero/negative
duration or an out-of-range elapsed value can never produce a NaN width or an overflowing
Capsule frame."* This is only true for `fraction` (line 574, clamped via `min(max(…,0),1)`).
`elapsed` (line 568-570) and `total` (line 571) are passed **unclamped** into
`Self.formatTime(elapsed)` / `Self.formatTime(total)` (lines 577, 586), and `formatTime` does:

```swift
private static func formatTime(_ seconds: TimeInterval) -> String {
    let s = max(0, Int(seconds.rounded()))   // line 601
    ...
}
```

`Int(_:)` on a `Double` that is `.nan` or `.infinity` is a Swift runtime trap (fatal error,
not a throwable/catchable error) — it crashes the process. `elapsed` is computed as
`elapsedAtSnapshot + (now - timestampAtSnapshot) * rate`
(`NowPlayingPresentation.swift:112-114`); `rate`, `timestampAtSnapshot`, `duration`, and
`elapsedAtSnapshot` all originate from `TrackSnapshot`'s raw `Double?` fields, which are lifted
directly from the external `MediaRemoteAdapter` process's JSON payload
(`NowPlayingMonitor.swift:74-82`) with no finiteness validation anywhere in the pipeline. A
malformed/unexpected value from that external process (e.g. `rate == .infinity`, or
`now == timestampAtSnapshot` combined with a non-finite `rate`, which produces `NaN` via
`0 * .infinity`) reaches `formatTime` unchecked and crashes the app the next time the
progress row renders.

**Fix:** Guard both `elapsed` and `total` for finiteness before formatting (and before the
fraction computation, for defense in depth):

```swift
let rawElapsed = position.map {
    currentElapsedSeconds($0, isPlaying: isPlaying, now: context.date.timeIntervalSince1970)
} ?? 0
let total = (position?.duration).flatMap { $0.isFinite ? $0 : nil } ?? 0
let elapsed = rawElapsed.isFinite ? min(max(rawElapsed, 0), total > 0 ? total : rawElapsed) : 0
```
and/or add a finiteness guard inside `formatTime` itself:
```swift
private static func formatTime(_ seconds: TimeInterval) -> String {
    guard seconds.isFinite else { return "0:00" }
    let s = max(0, Int(seconds.rounded()))
    return String(format: "%d:%02d", s / 60, s % 60)
}
```

## Warnings

### WR-01: Elapsed time text is not clamped to duration, unlike the progress bar fill

**File:** `Islet/Notch/NotchPillView.swift:568-577`

**Issue:** `fraction` (the visual fill) is clamped to `[0, 1]` at line 574, but the elapsed
label text at line 577 (`Text(Self.formatTime(elapsed))`) uses the raw, unclamped `elapsed`
value. Because `elapsed` is a live extrapolation (`elapsedAtSnapshot + (now - timestamp) *
rate`) that keeps advancing every animation frame until the next real MediaRemote snapshot
arrives, it will routinely exceed `total` for a brief window near the end of a track (e.g.
showing `3:47` next to a `3:45` total while the fill bar is already pinned at 100%). This is
a genuine, easily reproducible display inconsistency, not merely a style nit.

**Fix:** Clamp `elapsed` to `total` (when `total > 0`) before formatting, e.g.:
```swift
let elapsed = total > 0 ? min(rawElapsed, total) : rawElapsed
```

### WR-02: `nowPlayingState.position` is not cleared alongside `presentation`/`artwork` in three teardown paths

**File:** `Islet/Notch/NotchWindowController.swift:1012-1013` (`scheduleMediaDismiss`),
`:1028-1029` (`handleAdapterTerminated`), `:870-871` (`handleSettingsChanged`, Now Playing
disabled branch)

**Issue:** All three sites reset `nowPlayingState.presentation = .none` and
`nowPlayingState.artwork = nil` together, but leave `nowPlayingState.position` untouched. In
the traced call paths this happens to be harmless today — `resolvePublishedPosition` only
reuses `previousPosition` when `previous` is `.playing`, so a stale position sitting behind a
`.none` presentation is never read before the next real `handleNowPlaying` callback
overwrites it. However, this breaks the symmetry the rest of the codebase deliberately
maintains (`presentation`/`artwork` are always reset together — see the inline comments at
each of these sites), is inconsistent with the "never storing a ticking value" contract
documented on `NowPlayingState.position`, and is a latent trap for any future code path that
reads `nowPlaying.position` without first checking `presentation`.

**Fix:** Add `self.nowPlayingState.position = nil` (or `nowPlayingState.position = nil` in the
non-closure call site) next to each `artwork = nil` assignment at the three locations above.

## Info

### IN-01: Repeated magic number `1_000_000` in `playbackPosition(from:)`

**File:** `Islet/Notch/NowPlayingPresentation.swift:102-105`

**Issue:** The micros-to-seconds conversion factor `1_000_000` is repeated three times inline.

**Fix:** Extract a named constant, e.g. `private let microsPerSecond = 1_000_000.0`, for
readability and to make the unit conversion self-documenting.

### IN-02: Progress-bar boundary math (elapsed clamp, NaN handling, fraction derivation) lives untested in the View layer

**File:** `Islet/Notch/NotchPillView.swift:563-597`

**Issue:** The rest of this feature (`playbackPosition`, `currentElapsedSeconds`,
`resolvePublishedPosition`) deliberately lives in the pure, Foundation-only seam in
`NowPlayingPresentation.swift` specifically so the riskiest math is unit-testable
(per the file's own stated discipline and `IsletTests/NowPlayingPresentationTests.swift`'s
thorough coverage of that seam). The `elapsed`/`total`/`fraction` derivation inside
`ProgressBar.body` — which is exactly where CR-01 and WR-01 live — was written directly in
SwiftUI code instead, so it has zero unit test coverage and was not caught before review.

**Fix:** Consider extracting a pure `func progressBarFraction(elapsed:total:) -> (text
values, fraction)` (or similar) into the pure seam, mirroring the existing pattern, so the
clamping/finiteness rules can be unit-tested the same way the rest of PBAR-01 is.

---

_Reviewed: 2026-07-04T00:53:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
