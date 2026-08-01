---
name: spike-findings-islet
description: Implementation blueprint from spike experiments. Requirements, proven patterns, and verified knowledge for building islet. Auto-loaded during implementation work.
---

<context>
## Project: islet

Islet is a native macOS Swift app that turns the MacBook's notch into an interactive
"Dynamic Island" — now-playing media controls, HUD replacement, drag-and-drop file shelf,
charging/device animations, and a timer.

Spike sessions wrapped: 2026-08-01
</context>

<requirements>
## Requirements

- Apple Music cannot be a supported source for real "next 5 tracks" queue data via AppleScript — no queue API exists, and even playlist-order prediction is unreliable once Apple Music's autoplay layer takes over. The Next Up panel must have a defined behavior for players/sources with no usable queue data.
- Spotify's AppleScript surface has no queue/playlist object at all — a dead end, no partial trick possible. Its real queue API (`GET /me/player/queue`) requires registering a developer app under a Spotify Premium account (new Feb 2026 rule); blocked for this project until a Premium account is available to register it.
- MediaRemote (the private framework Islet already links via MediaRemoteAdapter) tracks a queue *index* and fires a queue-changed notification, but never exposes queue *contents*. No app-agnostic queue data source exists today for "next up" as originally specified.
- A "recently played" history (last 5 tracks) IS buildable app-agnostically today from Islet's existing MediaRemoteAdapter stream, with no new dependency or permission — the safest path to ship NOW-08 in some form.
- Music.app's real "Playing Next" panel is readable via the Accessibility API — a genuine but Music.app-only, new-permission-cost option for actual upcoming-track data.
- NOW-08 as originally specified ("next 5 queued tracks, app-agnostic") cannot be built against any currently available data source — needs a scope decision (history pivot, Music.app-only AX, or wait for Spotify Premium) before planning Phase 74.
</requirements>

<findings_index>
## Feature Areas

| Area | Reference | Key Finding |
|------|-----------|-------------|
| Music Next Up Queue (NOW-08) | references/music-next-up-queue.md | Original "next 5 queued tracks" spec is unbuildable app-agnostically. Three real options instead: (1) "recently played" history — VALIDATED, lowest cost, ship today; (2) Music.app-only "up next" via Accessibility API — PARTIAL, real data but new permission + single-app; (3) wait for Spotify Premium Web API. Needs a scope decision before Phase 74 planning. |

## Source Files

Original spike source files are preserved in `sources/` for complete reference.
</findings_index>

<metadata>
## Processed Spikes

- 001-apple-music-queue-scripting
- 002-spotify-queue-scripting
- 003-private-mediaremote-queue-hook
- 004-history-from-nowplaying-stream
- 005-accessibility-api-queue-scraping
- 006-spotify-local-connect-endpoint
</metadata>
