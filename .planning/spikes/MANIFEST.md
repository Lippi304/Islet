# Spike Manifest

## Idea

Validate whether "Next Up" queue data (next 5 tracks: title, artist, artwork) can actually
be retrieved for Phase 74 / NOW-08 (Music Next Up Queue). MediaRemoteAdapter — the private
MediaRemote framework wrapper Islet already uses for Now Playing — only exposes current-track
metadata and playback state. It has no queue or upcoming-track API. Discussed during Phase 74's
discuss-phase (2026-08-01); flagged as a technical blocker that needs proving before planning.

## Requirements

- Apple Music cannot be a supported source for real "next 5 tracks" queue data via AppleScript — no queue API exists, and even playlist-order prediction is unreliable once Apple Music's autoplay layer takes over (Spike 001). The Next Up panel must have a defined behavior for players/sources with no usable queue data.
- Spotify's AppleScript surface has no queue/playlist object at all (Spike 002) — a dead end, no partial trick possible. Its real queue API (`GET /me/player/queue`) requires registering a developer app under a Spotify Premium account (new Feb 2026 rule); blocked for this project until a Premium account is available to register it.

## Spikes

| # | Name | Type | Validates | Verdict | Tags |
|---|------|------|-----------|---------|------|
| 001 | apple-music-queue-scripting | standard | Given Music.app is playing, when queried via AppleScript, then the next 5 upcoming tracks (title/artist/artwork) are retrievable, including under shuffle | ✗ INVALIDATED | music, applescript, phase-74 |
| 002 | spotify-queue-scripting | standard | Given Spotify is playing, when queried via AppleScript or the local Spotify Web API, then the next 5 queued tracks are retrievable | ✗ INVALIDATED | spotify, applescript, phase-74 |
| 003 | private-mediaremote-queue-hook | standard | Given the private MediaRemote framework is already linked (via MediaRemoteAdapter), when probed for undocumented queue/upcoming-track selectors, then queue data is retrievable app-agnostically without per-app scripting | PENDING | mediaremote, private-api, phase-74 |
