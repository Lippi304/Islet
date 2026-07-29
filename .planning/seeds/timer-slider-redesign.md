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
   ruler/slider control — numbers (seconds) along a horizontal bar the user can drag/scrub to
   pick a duration — plus a "Start Timer" button below it, a readout of the full selected
   duration, and (per the reference image) a speaker icon to toggle whether a sound plays when
   the timer ends.

User provided a reference screenshot (not captured/attached in this seed — re-share when this is
picked up for the exact ruler/slider visual style, tick spacing, and speaker-icon placement).

## Why

User's own stated priority — rank 4 of the ordered list. This is a bigger structural change than
the other 4 ideas (removes an existing mode, not just adds a control), so it likely needs its own
careful discuss-phase pass to confirm what "remove Pomodoro" should do to any persisted user
settings/state tied to it.

## Priority

Rank 4 of 5 ideas captured 2026-07-29 (see also [[filetray-convert-button]],
[[island-corner-rounding]], [[calendar-redesign-droppy]], [[music-next-up-queue]]).
