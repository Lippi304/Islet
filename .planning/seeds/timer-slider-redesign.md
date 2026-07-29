---
title: Timer Redesign — Remove Pomodoro, Ruler-Style Duration Slider (Droppy-inspired)
trigger_condition: After calendar-redesign-droppy phase — rank 4 of 5 ideas captured 2026-07-29
planted_date: 2026-07-29
---

## Idea

Again inspired by Droppy. Two parts:

1. **Remove Pomodoro entirely from the code** — user was explicit: "erstmal wieder aus dem Code
   entfernen", i.e. actually delete the Pomodoro mode/logic, not just hide it. Note:
   `timerWings(for:)` in `NotchPillView.swift` currently branches on an `isPomodoro` flag
   (`margin: CGFloat = (isPomodoro ? 55 : 10) + wingMarginNudge`) — this and any other
   Pomodoro-specific branching/state need to be located and removed when this is picked up.
2. **New timer-setup UI**: a single plain timer (no Pomodoro concept at all), presented as a
   ruler/slider control the user can drag/scrub to pick a duration — plus a "Start Timer" button
   below it, a readout of the full selected duration, and a speaker icon to toggle whether a
   sound plays when the timer ends.

Reference screenshot reviewed (2026-07-29, `image-cache/.../13.png`, from "Droppy"): a
horizontal ruler across the top with major tick labels `70 75 80 85 90 95 100` and dense minor
tick marks between them, an orange fill from the left edge up to a small triangle indicator
sitting under the currently-selected tick (85 in the screenshot), unfilled/greyed ticks beyond
the selection. Below the ruler, left-to-right: an orange pill-shaped "Start Timer" button, a
circular speaker/sound-toggle icon button, a circular stopwatch/clock icon button, then a large
orange total-duration readout `1:26:00` on the right. **Flag for discuss-phase:** the user's own
description called the ruler units "Sekunden" (seconds), but `70–100` ticks paired with a total
of `1:26:00` (1h26m) imply the ruler is actually in **minutes**, not seconds (100 seconds would
be under 2 minutes total, not 1h26m) — confirm the intended unit with the user before building,
don't assume from the German wording alone.

## Why

User's own stated priority — rank 4 of the ordered list. This is a bigger structural change than
the other 4 ideas (removes an existing mode, not just adds a control), so it likely needs its own
careful discuss-phase pass to confirm what "remove Pomodoro" should do to any persisted user
settings/state tied to it.

## Priority

Rank 4 of 5 ideas captured 2026-07-29 (see also [[filetray-convert-button]],
[[island-corner-rounding]], [[calendar-redesign-droppy]], [[music-next-up-queue]]).
