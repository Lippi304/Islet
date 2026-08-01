# Music Next Up Queue (NOW-08 / Phase 74)

## Requirements

- Apple Music cannot be a supported source for real "next 5 tracks" queue data via AppleScript — no queue API exists, and even playlist-order prediction is unreliable once Apple Music's autoplay layer takes over. The Next Up panel must have a defined behavior for players/sources with no usable queue data.
- Spotify's AppleScript surface has no queue/playlist object at all — a dead end, no partial trick possible. Its real queue API (`GET /me/player/queue`) requires registering a developer app under a Spotify Premium account (new Feb 2026 rule); blocked for this project until a Premium account is available to register it.
- MediaRemote (the private framework Islet already links via MediaRemoteAdapter) tracks a queue *index* and fires a queue-changed notification, but never exposes queue *contents*. No app-agnostic queue data source exists today. NOW-08 as specified ("next 5 queued tracks") cannot be built against any currently available data source — needs a scope decision before planning.

## How to Build It

There is no proven path to build NOW-08 as originally specified. Before planning Phase 74, the
scope decision has to be one of:

1. **Redefine the feature.** Drop "next 5 tracks" and replace with something the current-track-only
   MediaRemote API can actually support — e.g. a "just played" history (Islet already receives
   now-playing updates over time, so a rolling history list is buildable today), or a manual
   "peek" action that calls `next track` and immediately reports back (destructive — see What to
   Avoid).
2. **Wait for Spotify Premium.** If a Premium account becomes available to register a developer
   app, Spotify's `GET /me/player/queue` Web API is real and documented — this would need its own
   follow-up spike (OAuth Authorization Code Flow + PKCE, loopback redirect URI) before treating
   it as buildable. Apple Music would still have no queue source even in this scenario.
3. **Descope to Spotify-only, Premium-gated.** Ship Next Up only when Spotify is the active player
   and the user's account has Premium; degrade Apple Music (and free-tier Spotify) to an
   "unsupported" empty state.

Whichever direction is chosen, the empty/unsupported state for sources without queue data is a
hard requirement of the UI, not an edge case — with all three current data sources invalidated,
it is the *default* state for every player.

## What to Avoid

- **Don't use `container of current track` + index lookahead on Apple Music as a queue proxy.**
  It looks plausible (works for a real local playlist with shuffle off, on paper) but fails in
  practice: Apple Music's server-side autoplay engine can override the local playlist after a
  single `next track` call, landing on a track that isn't even in the playlist. Confirmed with a
  live test, not just docs.
- **Don't assume `current playlist` is populated.** For streamed/Listen-Now content it's `missing
  value`; the container is a synthetic "Scripting" playlist, not something you can enumerate for
  upcoming tracks.
- **Don't look for a queue/playlist object in Spotify's AppleScript dictionary.** It doesn't
  exist — the dictionary has exactly two classes (`application`, `track`), no `<element>`
  declarations, nothing to iterate.
- **Don't call `next track` speculatively to "peek" at what's next** on either player — it's
  side-effecting (advances real playback), not a query. Any "peek" implementation must warn the
  user it will skip the current track, or be built as an explicit user-initiated skip rather than
  a queue preview.
- **Don't try to dlopen/dlsym-probe MediaRemote for undocumented queue-content symbols.** The
  reversed header (`ios-reversed-headers`) and the actively maintained library Islet already
  depends on (`ejbills/mediaremote-adapter`) were both cross-referenced — neither exposes a
  queue-contents getter. `kMRMediaRemoteNowPlayingInfoQueueIndex` and
  `kMRMediaRemoteNowPlayingPlaybackQueueDidChangeNotification` exist but only tell you the current
  position within a queue, never the queue's items. Guessing further symbol names against this
  framework is fishing, not engineering — the two best available sources for this framework have
  already been checked.

## Constraints

- Apple Music AppleScript dictionary: no queue/Up-Next object at any layer (confirmed via `sdef`,
  608 lines, zero matches for queue/up-next/playingnext).
- Spotify AppleScript dictionary: two classes only (`application`, `track`), no element
  declarations — structurally incapable of exposing a track list.
- Spotify Web API `/me/player/queue` requires OAuth Authorization Code Flow + PKCE, a registered
  app with a `127.0.0.1` loopback redirect URI (bare `localhost` rejected), and — as of the
  February 2026 Web API changelog — the registering account must hold an active Spotify Premium
  subscription. This gates the developer, not just the end user.
- MediaRemote is a private framework that only ships inside the dyld shared cache on modern
  macOS — no on-disk Mach-O to inspect with `nm`/`otool`. Its queue awareness is limited to an
  index + change notification; no queue-contents API exists in either the classic reversed header
  or the actively maintained third-party library built specifically to maximize what's extractable
  from it.

## Origin

Synthesized from spikes: 001, 002, 003
Source files available in: sources/001-apple-music-queue-scripting/, sources/002-spotify-queue-scripting/, sources/003-private-mediaremote-queue-hook/
