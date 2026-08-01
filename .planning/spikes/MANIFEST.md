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
- MediaRemote (the private framework Islet already links via MediaRemoteAdapter) tracks a queue *index* and fires a queue-changed notification, but never exposes queue *contents* — confirmed against the actively maintained library itself, not just old docs (Spike 003). No app-agnostic queue data source exists today. NOW-08 as specified ("next 5 queued tracks") cannot be built against any currently available data source — needs a scope decision before planning.
- A "recently played" history (last 5 tracks) is buildable app-agnostically from MediaRemoteAdapter's existing `onTrackInfoReceived` stream today, with no new dependency — string-based `(title, artist, album)` identity matching (mirroring the upstream library's own dedup logic) correctly survives sustained refresh noise and produces a true chronological log where skip-back adds a new entry rather than being suppressed (Spike 004). This is a proven, buildable alternative to a "next up" queue if the feature is redefined around history instead of prediction.
- Music.app's visible "Playing Next" panel (History + current track + AutoPlay suggestions) is fully readable via the Accessibility API — real `(title, artist, album)` upcoming-track data, not algorithmically reconstructed (Spike 005). It inherits Spike 001's caveat: the AutoPlay list is a prediction Apple's own engine can override once playback advances, not a committed queue. Requires a new Accessibility permission grant, a UX cost not currently in Islet's footprint. Spotify exposes no accessibility tree for its Queue panel at all — confirmed via two live tests and rejection of the documented Chromium full-tree-activation attribute (`AXManualAccessibility` → unsupported). Any AX-based approach is Music.app-only; no single solution covers both players.

## Spikes

| # | Name | Type | Validates | Verdict | Tags |
|---|------|------|-----------|---------|------|
| 001 | apple-music-queue-scripting | standard | Given Music.app is playing, when queried via AppleScript, then the next 5 upcoming tracks (title/artist/artwork) are retrievable, including under shuffle | ✗ INVALIDATED | music, applescript, phase-74 |
| 002 | spotify-queue-scripting | standard | Given Spotify is playing, when queried via AppleScript or the local Spotify Web API, then the next 5 queued tracks are retrievable | ✗ INVALIDATED | spotify, applescript, phase-74 |
| 003 | private-mediaremote-queue-hook | standard | Given the private MediaRemote framework is already linked (via MediaRemoteAdapter), when probed for undocumented queue/upcoming-track selectors, then queue data is retrievable app-agnostically without per-app scripting | ✗ INVALIDATED | mediaremote, private-api, phase-74 |
| 004 | history-from-nowplaying-stream | standard | Given MediaRemoteAdapter's now-playing change notifications over a real listening session, when tracks change (including skip-back, pause/resume), then a deduplicated, correctly-ordered "recently played" list of the last 5 tracks can be built with no missed or duplicate events | ✓ VALIDATED | mediaremote, history, phase-74, frontier |
| 005 | accessibility-api-queue-scraping | standard | Given Music.app's "Playing Next" panel or Spotify's Queue view is open on screen, when queried via the macOS Accessibility API (AXUIElement), then the next 5 upcoming track titles/artists are extractable as UI text nodes | ⚠ PARTIAL | music, spotify, accessibility, phase-74, frontier |
| 006 | spotify-local-connect-endpoint | standard | Given Spotify desktop is running, when Islet probes Spotify's local Connect/Zeroconf discovery endpoint (127.0.0.1), then track or queue data is inspectable without OAuth or a Premium-gated developer app | PENDING | spotify, local-api, phase-74, frontier |
