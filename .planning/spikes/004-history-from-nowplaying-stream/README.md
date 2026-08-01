---
spike: 004
name: history-from-nowplaying-stream
type: standard
validates: "Given MediaRemoteAdapter's now-playing change notifications over a real listening session, when tracks change (including skip-back, pause/resume), then a deduplicated, correctly-ordered 'recently played' list of the last 5 tracks can be built with no missed or duplicate events"
verdict: VALIDATED
related: [001, 002, 003]
tags: [mediaremote, history, phase-74, frontier]
---

# Spike 004: History from Now-Playing Stream

## What This Validates

Given MediaRemoteAdapter's persistent `onTrackInfoReceived` event stream (the same one Islet's
`NowPlayingMonitor` already consumes), when a real listening session runs — song changes, skips,
skip-backs, pause/resume — then a deduplicated, correctly-ordered "last 5 played" list can be
built purely from that stream, with no missed changes and no false-duplicate entries from
metadata-only refreshes.

This is the frontier spike for the "redefine the feature" pivot named in
`.claude/skills/spike-findings-islet/references/music-next-up-queue.md`: if history-building is
robust, NOW-08 can ship as a "recently played" panel instead of a "next up" queue, using data
Islet already receives today.

## Research

Read the actual `MediaRemoteAdapter` source (local SPM checkout, pinned revision
`cf30c4f1af29b5829d859f088f8dbdf12611a046`) rather than just Islet's wrapper:

- `MediaController.onTrackInfoReceived: ((TrackInfo?) -> Void)?` — closure-based, fires on a
  persistent child process (`perl run.pl ... loop`), not polling.
- `TrackInfo.Payload` has **no stable track ID**. The library's own `uniqueIdentifier` and its
  private `isSameTrack(_:_:)` both key off `(title, artist, album-if-both-present)` string
  comparison — confirming Islet's own `NowPlayingPresentation.isSameTrack` independently arrived
  at the same shape.
- The library **already knows it re-emits for the same track**: `preservingArtworkIfDowngrade`
  exists specifically to patch over repeat events where artwork arrives smaller/nil on a later
  emission for an unchanged track. This is the exact noise a history accumulator has to filter.

**Chosen approach:** a standalone SPM executable (`swift run`, not embedded in Islet) that links
the identical pinned `MediaRemoteAdapter` revision, mirrors the library's `isSameTrack` logic
locally, and accumulates history purely from the closure stream — so the test observes the real
production data path, not a mock.

## How to Run

```bash
cd .planning/spikes/004-history-from-nowplaying-stream
swift build          # already verified: builds clean against the pinned revision
swift run            # or .build/debug/HistorySpike directly
```

Then, with the spike running in the foreground:
1. Play a song in Music.app or Spotify.
2. Let it play a few seconds (artwork/metadata should settle).
3. Skip to the next track (2-3 times).
4. Skip back to a previous track (does it re-appear as a "new" history entry?).
5. Pause, wait a few seconds, resume.
6. Press `Ctrl+C` to stop — prints a summary and writes `events.json` (full timestamped event
   log with category tags: `TRACK_CHANGE`, `REFRESH_IGNORED`, `NIL_EVENT`, `EMPTY_TITLE_EVENT`).

## What to Expect

- Every real track change prints `TRACK CHANGE -> "title" — artist` followed by the current
  5-entry history list.
- Metadata-only re-emissions for the *same* track (typically artwork arriving after the initial
  event) print `REFRESH (same track, ignored)` and must NOT appear as duplicate history entries.
- Skipping back to a track already in history is expected to create a **new** history entry (this
  models "recently played," not "unique tracks played") — worth confirming this is the desired
  semantic before building the real feature.

## Observability

`events.json` (written on Ctrl+C) is the full forensic log: every raw event with an ISO timestamp
and category tag (`TRACK_CHANGE`, `REFRESH_IGNORED`, `NIL_EVENT`, `EMPTY_TITLE_EVENT`), plus an
`artworkDelta` field on refresh events showing whether the library's own dedup-artwork-upgrade
behavior is what's triggering the repeat emission.

## Investigation Trail

**1. Confirmed no stable track ID exists anywhere in the data path.** Read `TrackInfo.swift` and
`MediaController.swift` directly (not just Islet's wrapper) — `Payload` has no `id`/`persistentID`
field. `uniqueIdentifier` is a computed `"\(title)-\(artist)-\(album)"` string. Any accumulator is
therefore committed to string-based identity, with the known false-positive/negative risks that
implies (two different tracks with identical title+artist+album would collide; the same logical
track with an album tag mismatch across sources would split).

**2. Confirmed the library expects repeat emissions for an unchanged track.** Found
`preservingArtworkIfDowngrade` — private logic whose entire purpose is compensating for the
adapter emitting the same track twice with different artwork completeness. This means a naive
accumulator that appends on every event (rather than gating on `isSameTrack`) would be wrong by
construction, not just imprecise. Confirmed the mirrored gate before writing the harness rather
than discovering it empirically.

**3. Built against the real pinned dependency, not a mock.** `Package.swift` pins the exact same
`mediaremote-adapter` revision as Islet's `Package.resolved`
(`cf30c4f1af29b5829d859f088f8dbdf12611a046`) — `swift build` fetches, compiles, and links clean
(31.95s cold build). Smoke-tested with a 4-second run: starts listening, correctly emits a
`NIL_EVENT` when nothing is playing, shuts down cleanly on `SIGINT`, and writes a valid
`events.json`. Confirms the harness itself works before handing off for a live multi-track
listening session.

**4. Live multi-track session confirmed all three risk areas.** User ran a real session against
Apple Music: play → let settle → skip forward twice → skip back twice → let sit. Observed:

- **Sustained refresh noise did not pollute history.** Track "QUALITÄT" sat active for 16+
  seconds and fired ~10 `REFRESH_IGNORED` events (`artworkDelta=0` — not even an artwork cause,
  just periodic re-emission from the adapter) with zero false `TRACK_CHANGE` entries. The
  `isSameTrack`-style gate is robust against emission noise well beyond the artwork-upgrade case
  it was originally built for in the upstream library.
- **Skip-back produces a new history entry, not a suppressed dupe.** Sequence observed:
  QUALITÄT → Wendy → Space Coupe → Wendy → QUALITÄT. Skipping back to "Wendy" (already 2 slots
  back in history) correctly appended a *new* entry rather than being filtered as already-seen —
  confirms the "recently played" semantic (chronological log) rather than "unique tracks" (set),
  which was the open question going in.
- **Rapid back-to-back changes were not dropped or coalesced.** Wendy → Space Coupe fired as two
  distinct `TRACK_CHANGE` events within the same wall-clock second, both captured correctly in
  order.
- **No missed changes across the whole session** — every skip and skip-back the user performed
  produced exactly one `TRACK_CHANGE`, never zero, never more than one.

## Results

**VALIDATED.** A deduplicated, correctly-ordered "last 5 played" history is buildable purely from
`MediaController.onTrackInfoReceived`, using string-based `(title, artist, album)` identity
matching — the same shape the upstream library and Islet's existing `NowPlayingPresentation`
already independently use. No missed track changes, no false-duplicate entries from refresh
noise, and skip-back behaves as a real chronological "recently played" log rather than a
deduplicated set (confirmed as the intended semantic).

**Caveats carried into the real build:**
- Identity is string-based, not a stable ID — two genuinely different tracks sharing an identical
  `(title, artist, album)` triple would incorrectly collide as "the same track." Low risk in
  practice, not zero.
- This only proves the *history* pivot (Option 1 from the findings skill). It does not resurrect
  "next up" queue data — Apple Music, Spotify AppleScript, and MediaRemote's queue API remain
  invalidated (Spikes 001-003).

## Origin

Standalone SPM package, not derived from prior spikes. Cross-references findings from Spike 003
(no stable queue/track ID exists anywhere in MediaRemote) and Islet's existing
`NowPlayingPresentation.isSameTrack` (confirms the same dedup shape was independently required in
production code).
