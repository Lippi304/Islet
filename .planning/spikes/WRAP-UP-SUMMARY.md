# Spike Wrap-Up Summary

**Date:** 2026-08-01
**Spikes processed:** 3
**Feature areas:** Music Next Up Queue (NOW-08)
**Skill output:** `./.claude/skills/spike-findings-islet/`

## Processed Spikes
| # | Name | Type | Verdict | Feature Area |
|---|------|------|---------|--------------|
| 001 | apple-music-queue-scripting | standard | ✗ INVALIDATED | Music Next Up Queue |
| 002 | spotify-queue-scripting | standard | ✗ INVALIDATED | Music Next Up Queue |
| 003 | private-mediaremote-queue-hook | standard | ✗ INVALIDATED | Music Next Up Queue |

## Key Findings

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
