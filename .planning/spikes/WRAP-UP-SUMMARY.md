# Spike Wrap-Up Summary

**Date:** 2026-08-01 (updated)
**Spikes processed:** 6
**Feature areas:** Music Next Up Queue (NOW-08)
**Skill output:** `./.claude/skills/spike-findings-islet/`

## Processed Spikes
| # | Name | Type | Verdict | Feature Area |
|---|------|------|---------|--------------|
| 001 | apple-music-queue-scripting | standard | ✗ INVALIDATED | Music Next Up Queue |
| 002 | spotify-queue-scripting | standard | ✗ INVALIDATED | Music Next Up Queue |
| 003 | private-mediaremote-queue-hook | standard | ✗ INVALIDATED | Music Next Up Queue |
| 004 | history-from-nowplaying-stream | standard | ✓ VALIDATED | Music Next Up Queue |
| 005 | accessibility-api-queue-scraping | standard | ⚠ PARTIAL | Music Next Up Queue |
| 006 | spotify-local-connect-endpoint | standard | ✗ INVALIDATED | Music Next Up Queue |

## Key Findings (Spikes 001-003 — original scope)

All three candidate data sources for NOW-08 ("next 5 queued tracks") are invalidated:

- **Apple Music (AppleScript):** No queue/Up-Next API exists in the scripting dictionary at all.
  The only workaround (playlist container + index lookahead) was falsified by a live test —
  Apple Music's server-side autoplay engine overrode the local playlist after a single `next
  track` call, landing on a track outside the playlist entirely. Not a shuffle problem; would
  fail even with shuffle off.
- **Spotify (AppleScript / Web API):** AppleScript's dictionary has no playlist/queue class at
  all — a stronger dead end than Apple Music's. The real path, `GET /me/player/queue`, is
  documented and real, but registering the required developer app now requires (as of the
  February 2026 Web API changelog) an active Spotify Premium subscription on the registering
  account — which the project owner does not currently have. Reversible if a Premium account
  becomes available.
- **Private MediaRemote framework:** Cross-referencing the classic reversed header
  (`ios-reversed-headers`) against the actively maintained library Islet already depends on
  (`ejbills/mediaremote-adapter`) confirmed the framework tracks a queue *index* and a
  queue-changed *notification*, but never exposes queue *contents* — no app-agnostic route
  exists, even through undocumented selectors.

**Net result:** No currently available data source can deliver real "next 5 tracks" for NOW-08
as specified. This is a scope decision for the user before Phase 74 planning proceeds — not a
build blocker to route around silently. Options are captured in the generated skill's reference
file (redefine the feature around current-track-only data, wait for Spotify Premium, or descope
to Spotify-Premium-only with an explicit unsupported state for everything else).

## Key Findings (Spikes 004-006 — frontier follow-up)

Three follow-up spikes explored whether any *other* angle could recover real upcoming-track
data, or whether a redefined feature could ship instead:

- **Spike 004 (history pivot) — VALIDATED.** A deduplicated, correctly-ordered "last 5 played"
  history is buildable today, purely from Islet's existing `MediaController.onTrackInfoReceived`
  stream — no new dependency, no new permission. String-based `(title, artist, album)` identity
  matching (mirroring the upstream library's own dedup logic) survives sustained refresh noise
  with zero false duplicates, and skip-back correctly produces a new chronological entry rather
  than being suppressed. This is the lowest-cost path to ship *some* form of NOW-08.
- **Spike 005 (Accessibility API) — PARTIAL.** Music.app's real "Playing Next" panel (History +
  current track + AutoPlay suggestions) is fully readable via `AXUIElement` as plain
  `(title, artist, album)` static text — genuine, previously-unavailable upcoming-track data,
  not algorithmic reconstruction. But it's Music.app-only: Spotify's Electron/CEF renderer
  exposes no accessibility tree at all (confirmed via two live tests plus rejection of the
  documented `AXManualAccessibility` force-activation attribute), and it costs a new
  Accessibility permission grant not currently in Islet's footprint. Inherits Spike 001's
  caveat — the AutoPlay list is Apple's algorithmic prediction, overridable once playback
  advances.
- **Spike 006 (local IPC) — INVALIDATED.** Spotify Desktop runs a real local JSON-RPC surface on
  `127.0.0.1:7768` (confirmed via structured error responses, not silence), but its binary
  framing and method surface are completely undocumented with no reference implementation to
  check against — reverse-engineering it would violate the project's no-blind-fishing
  convention. Not a viable near-term path; the two dead legacy ports (51949, 57621) were also
  ruled out.

**Net result (updated):** NOW-08 as originally specified remains unbuildable app-agnostically,
but two real, scoped alternatives now exist instead of zero: a "recently played" history
(safest, ship today) or a Music.app-only "up next" via Accessibility API (real data, higher
cost). Full build recipes for both are in the updated skill reference file. Still needs a scope
decision from the user before Phase 74 planning.
