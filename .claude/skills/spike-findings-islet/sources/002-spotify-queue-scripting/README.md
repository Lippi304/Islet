---
spike: 002
name: spotify-queue-scripting
type: standard
validates: "Given Spotify is playing, when queried via AppleScript or the local Spotify Web API, then the next 5 queued tracks are retrievable"
verdict: INVALIDATED
related: [001]
tags: [spotify, applescript, phase-74]
---

# Spike 002: Spotify Queue via Scripting/Local API

## What This Validates

Given Spotify is playing, when queried via AppleScript or Spotify's Web API, then the next 5
queued tracks (title, artist, artwork) can be retrieved.

## Research

**AppleScript.** Spotify.app was not even running on this machine (installed but closed) —
`sdef` works on the app bundle directly, no need to launch it. Full dictionary dump: 137 lines,
two classes total — `application` and `track` (single item: current track's name, artist, album,
artwork URL, etc.). No `playlist`/`queue` class, no `<element>` declarations anywhere, meaning
there is no scriptable list of tracks at all — not even the "predict from playlist order" trick
that (partially) applies to Music.app (Spike 001). Commands are limited to
`play` / `pause` / `playpause` / `next track` / `previous track` / `play track <uri>`. This is a
strictly weaker surface than Music.app's — AppleScript is a complete dead end for Spotify, no
live test needed to prove it (there's nothing to query).

**Web API.** Spotify's official Web API has `GET /me/player/queue`
([docs](https://developer.spotify.com/documentation/web-api/reference/get-queue)), which returns
the actual currently-playing item plus the up-next queue. This is the real, documented path —
but it requires:

1. OAuth Authorization Code Flow with PKCE (implicit grant was retired; see
   [OAuth Migration notice](https://developer.spotify.com/blog/2025-10-14-reminder-oauth-migration-27-nov-2025), Nov 2025).
2. An app registered at developer.spotify.com with a `127.0.0.1`-loopback redirect URI
   (the literal string `localhost` is now rejected).
3. **New as of the [February 2026 Web API changelog](https://developer.spotify.com/documentation/web-api/references/changes/february-2026):
   the Spotify account used to create the developer app must hold an active Spotify Premium
   subscription.** This gate applies to whoever registers the app (i.e. whoever builds this
   feature into Islet) — not just the end user granting OAuth consent later.

## How to Run

```bash
bash inspect-sdef.sh   # confirms Spotify's AppleScript surface has no track-list/queue object
```

No script was written for the Web API path — see Investigation Trail for why.

## What to Expect

`inspect-sdef.sh` prints two classes (`application`, `track`), no `<element>` lines, and no
queue/up-next matches.

## Investigation Trail

**1. Confirmed AppleScript dead end without launching Spotify.** `sdef` reads the app bundle's
static dictionary — no need to run the app. Result: no playlist class, no element declarations,
nothing to iterate over except the single current-track object. This is a stronger negative
result than Music.app's case (Spike 001), where at least a `playlist`/`container` object exists
even though it proved unreliable in practice.

**2. Found the real path, then hit an account-level gate.** Spotify's Web API does expose
`/me/player/queue` — this is the correct, documented answer to "how would this actually work."
But before attempting a live OAuth flow, checked the current (2026) requirements and found the
Premium-account gate on app registration introduced in February 2026.

**3. Checked with the user directly rather than guessing.** Asked whether to register a
throwaway dev app and live-test the endpoint. The user does not have Spotify Premium, so they
cannot create a developer app under the current rule — this blocks the feature at the
registration step, before OAuth or any user-facing consent screen would even come into play.
This is a project-level blocker, not a "couldn't test today" gap: whoever maintains Islet's
Spotify integration needs a Premium account to obtain a client ID in the first place.

**4. No live test was run** for the Web API path as a result — there is nothing to test without
a client ID, and fabricating one isn't possible without the account prerequisite.

## Results

**Verdict: INVALIDATED** (for this project, as currently accountable).

- AppleScript: dead end, proven without ambiguity — no queue, no playlist, no track list of any
  kind in Spotify's scripting dictionary.
- Web API: the correct and only real path (`GET /me/player/queue`), but registering the
  developer app it depends on requires a Spotify Premium account, which the project owner does
  not currently have. This is reversible — the verdict would flip to VALIDATED (pending an
  actual OAuth implementation spike) if a Premium account becomes available to register the app.

**Impact on Phase 74 (NOW-08):** Spotify cannot be a supported source for the Next Up panel
right now. Combined with Spike 001 (Apple Music also invalidated), this means **no local-app
queue data source works out of the box for either major player** — the app-agnostic private-API
route (Spike 003) is now the only path that could still validate the feature at all.
