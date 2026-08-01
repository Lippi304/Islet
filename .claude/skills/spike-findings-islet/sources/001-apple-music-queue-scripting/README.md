---
spike: 001
name: apple-music-queue-scripting
type: standard
validates: "Given Music.app is playing, when queried via AppleScript, then the next 5 upcoming tracks (title/artist/artwork) are retrievable, including under shuffle"
verdict: INVALIDATED
related: []
tags: [music, applescript, phase-74]
---

# Spike 001: Apple Music Queue via AppleScript

## What This Validates

Given Music.app is playing, when queried via AppleScript, then the next 5 upcoming tracks
(title, artist, artwork) can be retrieved ahead of time — including when shuffle is on.

## Research

Music.app's AppleScript dictionary exposes `current track`, `current playlist`, `next track` /
`previous track` (playback commands, not queries), and `shuffle enabled` / `shuffle mode`
properties. It does **not** document any "Up Next" or queue object — the visible in-app "Playing
Next" queue is a UI-only feature with no scripting surface. This is corroborated by community
docs (AppleScript Tutorial Wiki, dougscripts.com) — none mention a scriptable queue.

**Chosen approach:** since there's no direct queue API, test the only plausible workaround —
reading `container of current track` (the playlist) and `index of current track`, then reading
`track (index+1)` through `track (index+5)` of that container as a proxy for "next 5".

## How to Run

```bash
bash inspect-sdef.sh                  # confirms no queue API exists in the dictionary
osascript test-shuffle-off.applescript   # live test against a real local playlist, shuffle off
```

`test-shuffle-on.applescript` was written but not run — see Investigation Trail.

## What to Expect

`inspect-sdef.sh` prints no matches for queue/up-next/playingnext. The shuffle-off test either
confirms or refutes that `container`+`index` reliably predicts the next track.

## Investigation Trail

**1. Confirmed no documented queue API.** `sdef /System/Applications/Music.app` (608 lines total)
has zero matches for "queue", "up next", "playingnext". The only playback-advance commands are
`next track` / `previous track`, both side-effecting (they change what's playing — they don't
peek).

**2. `current playlist` is often nil.** Before touching anything, the track already loaded in
Music.app (paused, "Body" by Don Toliver) had `current playlist` = missing value. Its
`container` was a synthetic playlist named **"Scripting"** with `index = 1` and
`class of current track` = **"URL track"** — i.e. Apple Music streaming/Listen-Now content, not
a real user playlist. This alone rules out the container+index trick for anything not explicitly
started from a local playlist.

**3. Tested the workaround against a real local playlist.** Started `track 2 of playlist
"White Girld Music"` (11 tracks, shuffle off) — a genuine library playlist, to give the
container+index approach its best chance. Predicted the next track as `track 3` = "I Kissed a
Girl" (per playlist order). Called `next track` once.

**4. Prediction failed — and not because of shuffle.** The actual next track was **"Needed Me"
by Rihanna**, a song that isn't even one of the playlist's 11 tracks. Inspecting the new current
track showed `container` had changed to **"Scripting (source)"** and `class` was again
**"URL track"**. Apple Music's server-side autoplay/continuation engine silently took over from
the local playlist after a single `next track` call — with shuffle **off**. This is a deeper
problem than "shuffle order is hidden": even deterministic playlist continuation isn't
guaranteed once Apple Music's streaming layer decides to autoplay.

**5. Shuffle-on test skipped.** Since the failure mode (autoplay override, not shuffle) already
invalidates the approach for the "shuffle off, best case" scenario, running the shuffle-on
variant would not change the verdict and would just skip further tracks in the user's real Music
app for no new information. `test-shuffle-on.applescript` is left in this directory in case
someone wants to re-run it later, but its result is a foregone conclusion of the same root cause.

**6. State was restored.** Volume, shuffle-enabled, and player-state (paused) were captured
before mutation and restored after both `inspect-sdef.sh` (read-only, no mutation) and
`test-shuffle-off.applescript` (muted volume during the test, restored to 64 after, paused
afterward — matching the original state).

## Results

**Verdict: INVALIDATED.**

AppleScript cannot reliably provide "next 5 upcoming tracks" for Apple Music:

- No queue/Up-Next API exists in the scripting dictionary at all (confirmed via `sdef`, not
  just docs/web search).
- `current playlist` is frequently unavailable for streamed/Listen-Now content.
- Even in the best case — a real local playlist, shuffle off — the only workaround
  (container + index lookahead) was falsified by a single live test: Apple Music's autoplay
  layer overrode the playlist after one track, landing on a song outside the playlist entirely.
- Shuffle would only make this worse; it isn't the primary failure mode.

**Impact on Phase 74 (NOW-08):** Apple Music cannot be a supported source for the Next Up panel
via AppleScript. Any real "next 5 tracks" data must come from elsewhere (see Spike 002 for
Spotify, Spike 003 for a private-API alternative) — or Apple Music must degrade to an
"unsupported" empty state in the panel.
