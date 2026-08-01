# Music Next Up Queue (NOW-08 / Phase 74)

## Requirements

- Apple Music cannot be a supported source for real "next 5 tracks" queue data via AppleScript — no queue API exists, and even playlist-order prediction is unreliable once Apple Music's autoplay layer takes over. The Next Up panel must have a defined behavior for players/sources with no usable queue data.
- Spotify's AppleScript surface has no queue/playlist object at all — a dead end, no partial trick possible. Its real queue API (`GET /me/player/queue`) requires registering a developer app under a Spotify Premium account (new Feb 2026 rule); blocked for this project until a Premium account is available to register it.
- MediaRemote (the private framework Islet already links via MediaRemoteAdapter) tracks a queue *index* and fires a queue-changed notification, but never exposes queue *contents*. No app-agnostic queue data source exists today for "next up" as originally specified.
- A "recently played" history (last 5 tracks) IS buildable app-agnostically today from data Islet already receives, using `MediaController.onTrackInfoReceived` string-based `(title, artist, album)` identity matching — no new dependency, no new permission (Spike 004).
- Music.app's real "Playing Next" panel (History + current + AutoPlay) is readable via the Accessibility API (Spike 005) — but this is Music.app-only (Spotify's Electron renderer exposes no accessibility tree at all) and requires a new Accessibility permission grant.
- Spotify's local IPC surface (port 7768) is confirmed real but its binary framing/method surface is completely undocumented with no reference implementation — reverse-engineering it is out of scope (Spike 006). Not a near-term path.

## How to Build It

There is no proven path to build NOW-08 as originally specified ("next 5 queued tracks,
app-agnostic"). Three real options now exist, each with a different scope/cost tradeoff — a scope
decision is needed before planning Phase 74:

### Option 1 — "Recently Played" history (VALIDATED, Spike 004, lowest cost)

Buildable today, app-agnostic, zero new permissions or dependencies. Pivots the feature from
"predict next" to "show what already played."

- Hook into the same `MediaController.onTrackInfoReceived` closure stream Islet's
  `NowPlayingMonitor` already consumes.
- Gate every incoming event with an `isSameTrack`-style check — key off
  `(title, artist, album-if-both-present)` string identity, mirroring
  `TrackInfo.uniqueIdentifier` / the library's own `isSameTrack(_:_:)`, and matching Islet's
  existing `NowPlayingPresentation.isSameTrack`. Only append to history when the gate says "new
  track," not on every raw event.
- On a genuine track change, push the *previous* current track onto a rolling history list
  (cap at 5), then update current track as normal.
- Do NOT treat "already in history" as a reason to suppress an entry — skip-back to an earlier
  track must append a **new** history entry (chronological log semantic), not be deduplicated as
  a set. Confirmed this is the correct semantic via live multi-track testing.
- Reference implementation: `sources/004-history-from-nowplaying-stream/Sources/HistorySpike/main.swift`
  (standalone SPM executable pinning the exact same `mediaremote-adapter` revision as Islet's
  `Package.resolved`).

### Option 2 — Music.app-only "Up Next" via Accessibility API (PARTIAL, Spike 005, medium cost)

Real, previously-unavailable upcoming-track data — but Music.app only, and costs a new permission.

- Requires `AXIsProcessTrustedWithOptions` — a new Accessibility permission grant not currently in
  Islet's footprint. Prompt the user and justify it; this is a real UX cost to weigh against the
  feature's value.
- Only works when Music.app's "Playing Next" panel is actually open/rendered on screen — AX trees
  only exist for rendered UI, there's no way to query it "in the background."
- Walk the app's window AX tree (`AXUIElementCopyAttributeValue` recursively, filtering to
  text-bearing nodes). Locate the AutoPlay/suggestions header (localized — e.g. German
  "Ähnliche Titel abspielen") and read the `(title, artist, album)` `AXStaticText` triples that
  follow it — do NOT just grab the first N static-text nodes, since the History section (which
  can be much longer than 5 entries) comes first in tree order.
- **Inherits Spike 001's caveat:** the list read this way is Apple's algorithmic AutoPlay
  prediction, not a committed queue — Apple Music's server-side autoplay engine can override it
  once playback actually advances. Frame this in the UI as "what's currently showing as up next,"
  not a guarantee.
- Does **not** extend to Spotify — see What to Avoid.
- Reference implementation: `sources/005-accessibility-api-queue-scraping/Sources/AXQueueSpike/main.swift`.

### Option 3 — Wait for Spotify Premium / Web API

If a Premium account becomes available to register a developer app, Spotify's
`GET /me/player/queue` Web API is real and documented — needs its own follow-up spike (OAuth
Authorization Code Flow + PKCE, loopback redirect URI) before treating it as buildable. Apple
Music would still have no queue source in this scenario. Preferred over Spike 006's local IPC
lead if the Premium gate ever lifts — it's documented and has a reference implementation, unlike
port 7768.

Whichever direction is chosen, the empty/unsupported state for sources without queue data is a
hard requirement of the UI, not an edge case.

## What to Avoid

- **Don't use `container of current track` + index lookahead on Apple Music as a queue proxy.**
  Apple Music's server-side autoplay engine can override the local playlist after a single
  `next track` call, landing on a track that isn't even in the playlist. Confirmed with a live
  test, not just docs.
- **Don't assume `current playlist` is populated.** For streamed/Listen-Now content it's `missing
  value`; the container is a synthetic "Scripting" playlist, not something you can enumerate for
  upcoming tracks.
- **Don't look for a queue/playlist object in Spotify's AppleScript dictionary.** It doesn't
  exist — the dictionary has exactly two classes (`application`, `track`), no `<element>`
  declarations, nothing to iterate.
- **Don't call `next track` speculatively to "peek" at what's next** on either player — it's
  side-effecting (advances real playback), not a query.
- **Don't try to dlopen/dlsym-probe MediaRemote for undocumented queue-content symbols.** Both the
  reversed header and the actively maintained library Islet depends on expose only a queue
  *index* and change notification, never queue contents. Guessing further symbol names is
  fishing, not engineering.
- **Don't build a "unique tracks played" set for the history option.** Skip-back to a track
  already in history must produce a new entry, not be filtered — confirmed as the correct
  semantic in Spike 004's live test. A set-based dedup is the wrong data structure here.
- **Don't append history entries on every `onTrackInfoReceived` event.** The adapter re-emits for
  an unchanged track (e.g. artwork arriving after the initial event, or plain periodic
  re-emission) — a naive accumulator without an `isSameTrack` gate will double-count. Gate first.
- **Don't expect Accessibility to work on Spotify.** Confirmed via two live tests with the Queue
  panel open, plus rejection of the documented Chromium `AXManualAccessibility` force-activation
  attribute (`kAXErrorAttributeUnsupported`) — Spotify's CEF renderer never built an accessibility
  bridge at all. This isn't a permission or timing problem; don't spend more time retrying it.
- **Don't attempt to decode Spotify's port 7768 JSON-RPC protocol.** It's real and responds to
  requests with structured errors, but the binary framing and method surface are completely
  undocumented with zero reference implementation to check against — a full reverse-engineering
  project, not something to reverse from a spike.

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
  or the actively maintained third-party library.
- `TrackInfo.Payload` has no stable track ID anywhere in the MediaRemote data path — any history
  accumulator is committed to string-based `(title, artist, album)` identity, with the known
  (low-probability) false-collision risk that implies.
- Accessibility API access requires a new per-binary permission grant
  (`AXIsProcessTrustedWithOptions`) via System Settings > Privacy & Security > Accessibility — not
  currently part of Islet's footprint.
- Spotify Desktop is CEF-based (Chromium Embedded Framework) with accessibility support compiled
  out — confirmed via `kAXErrorAttributeUnsupported` on the documented force-activation attribute,
  not just an empty tree.
- Spotify's local port 7768 IPC surface is live but undocumented; port 51949 is a static
  capability banner, not an API; port 57621 (legacy `SpotifyWebHelper`) is dead/unresponsive.

## Origin

Synthesized from spikes: 001, 002, 003, 004, 005, 006
Source files available in: sources/001-apple-music-queue-scripting/, sources/002-spotify-queue-scripting/, sources/003-private-mediaremote-queue-hook/, sources/004-history-from-nowplaying-stream/, sources/005-accessibility-api-queue-scraping/, sources/006-spotify-local-connect-endpoint/
