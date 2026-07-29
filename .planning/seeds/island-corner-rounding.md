---
title: Increased Corner Rounding — Collapsed Wide (Wings) State
trigger_condition: After filetray-convert-button phase — rank 2 of 5 ideas captured 2026-07-29
planted_date: 2026-07-29
---

## Idea

The corners of the notch island in its collapsed-but-wide state (i.e. when a wing is showing
content, not the plain idle pill) should be more rounded than they currently are. User provided
a reference screenshot with a red rectangle + red arrow pointing at the specific corner/edge of
the island that needs more rounding (not captured/attached in this seed — re-share when this is
picked up, and confirm exactly which corner(s)/edge(s): the `wingsShape()` shared shape renderer
in `NotchPillView.swift` is the likely single touch point, given every wing already routes
through it).

User also asked for a DEBUG-only live-tuning tool for this, mirroring the existing "Wing Tuner"
mechanism (`wingLeadingNudge`/`wingTrailingNudge`/`wingMarginNudge`/`wingGapNudge` — see
`NotchPillView.swift`, wired via `@AppStorage` and the AppDelegate "Wing Tuner" debug menu) — a
new nudge axis for corner radius, live-adjustable on real hardware the same way width/margin
already are.

## Why

User's own stated priority — rank 2 of the ordered list, right after the File Tray Convert
Button idea.

## Priority

Rank 2 of 5 ideas captured 2026-07-29 (see also [[filetray-convert-button]],
[[calendar-redesign-droppy]], [[timer-slider-redesign]], [[music-next-up-queue]]).
