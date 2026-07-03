# Phase 7: Now Playing Progress Bar - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-04
**Phase:** 7-now-playing-progress-bar
**Areas discussed:** Time label format, Visual style & color, Layout & island height, Update smoothness

---

## Time label format

| Option | Description | Selected |
|--------|-------------|----------|
| Elapsed / Total | e.g. "1:23 / 3:45" — matches the literal REQUIREMENTS.md example exactly | ✓ |
| Elapsed · Remaining (counts down) | e.g. "1:23   -2:22" — Apple Music/iOS style, matches the word "remaining" in the requirement text | |

**User's choice:** Elapsed / Total — resolves the REQUIREMENTS.md wording conflict in favor of the example.
**Notes:** REQUIREMENTS.md PBAR-01 says "elapsed/remaining time labels" but its own example "1:23 / 3:45" is an elapsed/total format. The example was treated as authoritative.

| Option | Description | Selected |
|--------|-------------|----------|
| Flanking the bar ends | Elapsed left of bar, total right — Apple Music mini-player style, one row | ✓ |
| Below the bar | Bar on its own row, labels underneath left/right aligned | |

**User's choice:** Flanking the bar ends.
**Notes:** —

---

## Visual style & color

| Option | Description | Selected |
|--------|-------------|----------|
| Accent-tinted fill | Filled portion uses the app's accent color; track stays dim grey/white | ✓ |
| Neutral white/grey | No accent tie-in, plain white fill | |

**User's choice:** Accent-tinted fill.
**Notes:** Extends the Phase 6 D-11 "accent = the small living color" pattern already applied to the equalizer bars and charging bolt.

| Option | Description | Selected |
|--------|-------------|----------|
| Thin line | ~2-3pt tall hairline, rounded caps — Apple Music mini-player style | ✓ |
| Thick capsule | ~5-6pt tall filled capsule — Alcove style | |

**User's choice:** Thin line.
**Notes:** —

| Option | Description | Selected |
|--------|-------------|----------|
| Match title/artist styling | Secondary-grey monospaced-digit numbers, consistent with existing Artist text styling | ✓ |
| Accent-tinted numbers | Time labels also pick up the accent color, matching the bar fill | |

**User's choice:** Match title/artist styling.
**Notes:** —

---

## Layout & island height

| Option | Description | Selected |
|--------|-------------|----------|
| Let the island grow taller | Add ~16-20pt on top of current expanded height, no compromise to existing layout | ✓ |
| Keep current height, tighten existing spacing | Shrink existing paddings/spacers to fit the bar without growing the island | |

**User's choice:** Let the island grow taller.
**Notes:** Today's `mediaExpanded` view only reserves a 4pt spacer (labeled "D-09" in code) for the future seek bar — nowhere near enough for a real bar + flanking labels.

---

## Update smoothness

| Option | Description | Selected |
|--------|-------------|----------|
| Continuous smooth fill | Bar visibly glides forward continuously while playing, like a video scrubber | ✓ |
| Once-per-second tick | Position/label jumps once per second — cheaper, avoids a second continuous animation driver | |

**User's choice:** Continuous smooth fill.
**Notes:** Matches the equalizer bars' existing continuous animation (Phase 4 D-04) rather than introducing a visibly stepped second pattern. Technical basis discussed: the MediaRemote adapter only pushes snapshots on state-change events; a local UI timer extrapolating from the already-available `elapsedTimeMicros`/`timestampEpochMicros`/`playbackRate` fields (via the vendored package's `currentElapsedTime` formula) is required — this is plumbing/research, not a fifth user decision.

---

## Claude's Discretion

- Exact bar height, corner radius, accent/track color values.
- SwiftUI mechanism for the continuous local timer (`TimelineView` vs `Timer.publish` vs mirroring the equalizer bars' existing approach).
- Whether the local timer runs only while the island is expanded (idle-CPU discipline).
- Exact new expanded-island height value and its composition with `NotchPillView.expandedSize`/`NotchGeometry`.
- Bar/label rendering (or absence) in the `mediaUnavailable` and no-media date/time states — untouched view branches.
- Paused-state freeze micro-behavior beyond "holds still" (already implied by PBAR-01).

## Deferred Ideas

- Tap/drag-to-seek — already out of scope per REQUIREMENTS.md, reconfirmed not reopened.
- Accent-tinted time label numbers — rejected in favor of matching title/artist grey.
- Thick Alcove-style capsule bar — rejected in favor of thin line.
- Once-per-second stepped update — rejected in favor of continuous smooth animation.
