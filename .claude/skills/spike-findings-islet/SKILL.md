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
- MediaRemote (the private framework Islet already links via MediaRemoteAdapter) tracks a queue *index* and fires a queue-changed notification, but never exposes queue *contents*. No app-agnostic queue data source exists today. NOW-08 as specified ("next 5 queued tracks") cannot be built against any currently available data source — needs a scope decision before planning.
</requirements>

<findings_index>
## Feature Areas

| Area | Reference | Key Finding |
|------|-----------|-------------|
| Music Next Up Queue (NOW-08) | references/music-next-up-queue.md | All three candidate data sources (Apple Music AppleScript, Spotify AppleScript/Web API, private MediaRemote) are invalidated — NOW-08 needs a scope decision before Phase 74 planning, not a build recipe |

## Source Files

Original spike source files are preserved in `sources/` for complete reference.
</findings_index>

<metadata>
## Processed Spikes

- 001-apple-music-queue-scripting
- 002-spotify-queue-scripting
- 003-private-mediaremote-queue-hook
</metadata>
