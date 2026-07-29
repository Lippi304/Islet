---
title: Increased Corner Rounding — Collapsed Wide (Wings) State
trigger_condition: After filetray-convert-button phase — rank 2 of 5 ideas captured 2026-07-29
planted_date: 2026-07-29
---

## Idea

The corners of the notch island in its collapsed-but-wide state (i.e. when a wing is showing
content, not the plain idle pill) should be more rounded than they currently are. Reference
screenshot reviewed (2026-07-29, `image-cache/.../11.png`, a marketing shot from another
Dynamic-Island-style app labeled "Gorgeous volume and brightness HUDs"): shows an OSD-style
HUD bar (sun icon, "Display" label, a yellow level bar, a number on the right — visually the
same shape of wing this project's own `osdWings(for:)` renders). A red arrow points at the
**bottom-left corner** of the bar (where the camera-cutout notch shape meets the wing's own
rounded outer corner) and a red rectangle highlights the **top-right corner** — i.e. both ends
of the wing's outer silhouette need noticeably more rounding than a typical HUD/capsule corner
radius, closer to a fully rounded "pill" look than the current, more rectangular-cornered shape.
The likely single touch point is `wingsShape()` (shared shape renderer in `NotchPillView.swift`)
since every wing already routes through it — confirm the exact current corner-radius value(s)
there before touching anything.

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
