---
title: Music "Next Up" Queue Expansion
trigger_condition: Spotify Premium account becomes available to register a developer app (unblocks the official `GET /me/player/queue` Web API), OR Apple Music/Spotify ship a real public queue API, OR the user reconsiders the Music.app-only Accessibility API tradeoff (silently toggling Music.app's own "Playing Next" panel in the background)
planted_date: 2026-07-29
---

## Idea

In the expanded Now Playing view, next to the back button there's currently a 3-dots ("⋯" with
lines) affordance on the left side. User wants tapping/clicking this to expand a "Next Up" list
showing the next 5 songs in the queue — each row with album art, title, and artist.

Reference screenshot reviewed (2026-07-29, `image-cache/.../14.png`, from "Droppy"): a two-column
expanded player. Left column: the existing Now Playing content (album art, title with
explicit/lyrics badges, artist, scrubber with elapsed/remaining time, then a control row of 4
icons — a "list" icon [☰ with dots — this IS the "3 dots with lines" the user described] on the
far left, back, pause, forward, then a device icon — followed by an output-device picker list
e.g. "MacBook Pro Speakers" (checked) / "Living Room"). Right column: "Playing Next" header + a
scrollable list of upcoming tracks, each row = small album art thumbnail + title + artist, with a
small reorder/queue icon on the far right of each row. The left-column "list" icon is what
toggles this right-column queue open/closed. Islet's existing Now Playing wing should already
have equivalents for most left-column elements (art/title/artist/scrubber/controls/device
picker) — this idea only adds the right-column queue panel + the toggle affordance.

## Why

User's own stated priority — rank 5 (last) of the ordered list.

## Priority

Rank 5 of 5 ideas captured 2026-07-29 (see also [[filetray-convert-button]],
[[island-corner-rounding]], [[calendar-redesign-droppy]], [[timer-slider-redesign]]).

## Status (2026-08-01): Deferred back to seed after Phase 74 spikes

This became Phase 74 (NOW-08) in the v1.11 roadmap, then was spiked (6 experiments,
`.planning/spikes/001` through `006`) before planning to prove feasibility. Findings, packaged
into the `spike-findings-islet` project skill (`.claude/skills/spike-findings-islet/references/music-next-up-queue.md`):

- **Apple Music AppleScript, Spotify AppleScript/Web API, and the private MediaRemote
  framework are all invalidated** — none exposes real "next N queued tracks" data
  (Spikes 001-003).
- **A "recently played" history is buildable today**, app-agnostic, no new permission
  (Spike 004, VALIDATED) — but the user confirmed (2026-08-01 explore session) this doesn't
  satisfy the actual desire: he wants to see forward, what's coming up in the next skips, not
  a backward-looking log. This option was explicitly rejected as not matching the original ask.
- **Music.app's real "Playing Next" panel is readable via the Accessibility API** (Spike 005,
  PARTIAL) — genuine forward-looking data (History + current + AutoPlay suggestions) for
  Music.app, which is the user's primary player. But the AX tree only exists once that panel is
  actually rendered on screen in Music.app itself — there's no way to query it "in the
  background." Building this into Islet would require either the user manually opening
  Music.app's own panel each time, or Islet silently toggling it open via UI-scripting behind
  the scenes. The user explicitly rejected the "silently manipulate a foreign app's UI in the
  background" approach as too fragile/hacky (2026-08-01) — decided to abandon rather than ship
  it that way.
- **Spotify's local IPC surface (port 7768) is real but completely undocumented** — reverse
  engineering it is out of scope (Spike 006, INVALIDATED).

**Net decision:** Phase 74 pulled from the active v1.11 roadmap (NOW-08 marked deferred in
REQUIREMENTS.md). Revisit only if one of the trigger conditions above changes the calculus —
don't re-attempt the history pivot (already explicitly rejected as not matching the ask) or the
background-AX-toggle approach (already explicitly rejected as too fragile) without the user
first indicating something changed their mind on those specific tradeoffs.
