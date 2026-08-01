---
spike: 003
name: private-mediaremote-queue-hook
type: standard
validates: "Given the private MediaRemote framework is already linked (via MediaRemoteAdapter), when probed for undocumented queue/upcoming-track selectors, then queue data is retrievable app-agnostically without per-app scripting"
verdict: INVALIDATED
related: [001, 002]
tags: [mediaremote, private-api, phase-74]
---

# Spike 003: Private MediaRemote Queue Selectors

## What This Validates

Given the private MediaRemote framework is already linked into Islet (via the MediaRemoteAdapter
dependency), when probed for undocumented queue/upcoming-track selectors, then queue data is
retrievable app-agnostically — without per-app AppleScript, and without either the Apple Music or
Spotify blockers found in Spikes 001/002.

## Research

**The framework binary can't be inspected on disk.** Modern macOS ships system private
frameworks only inside the dyld shared cache — `/System/Library/PrivateFrameworks/MediaRemote.framework/Versions/A/`
contains only `Resources` and `_CodeSignature`; the actual Mach-O with symbols doesn't exist as a
standalone file (confirmed: `nm`/`otool`/`file` all fail with "No such file or directory" on the
resolved path). Static symbol dumping would require extracting from the shared cache
(`dyld_shared_cache_util`), a much heavier operation than a spike warrants for a fishing
expedition with no known target symbol name.

**Used the reverse-engineering community's work instead — the correct approach for a private
API.** Two independent, authoritative sources were checked:

1. [davidmurray/ios-reversed-headers MediaRemote.h](https://github.com/davidmurray/ios-reversed-headers/blob/master/MediaRemote/MediaRemote.h)
   — a long-standing reverse-engineered header covering the full `MRMediaRemote*` C function and
   key surface (registration, now-playing info getters, playback commands, route discovery).
2. [ejbills/mediaremote-adapter](https://github.com/ejbills/mediaremote-adapter) — the actively
   maintained Swift package that **is the actual library already vendored into Islet**
   (`MediaRemoteAdapter.framework`, confirmed present in `build/`). This library exists
   specifically to expose as much of MediaRemote as is practically reachable from a third-party
   app, and even bridges through "the system's entitled Perl interpreter" to get past sandbox
   restrictions on `MRMediaRemoteGetNowPlayingInfo`. If an app-agnostic queue-content API existed
   and were reachable, this project — built by people solving exactly this problem — would be
   the most likely place to find it already exposed.

**Findings from both sources, cross-referenced:**

- MediaRemote does have an internal *concept* of a queue: `kMRMediaRemoteNowPlayingInfoQueueIndex`
  (an integer — the current item's position within some queue) and
  `kMRMediaRemoteNowPlayingPlaybackQueueDidChangeNotification` (fires when the queue changes)
  both exist in the reversed header.
- Neither source documents any function or key that returns queue **contents** — no
  `MRMediaRemoteGetQueue`, no `MRMediaRemoteCopyQueueItems`, no array-of-tracks key alongside
  `kMRMediaRemoteNowPlayingInfoQueueIndex`. The queue index tells you *where* you are, not
  *what's next*.
- ejbills/mediaremote-adapter's full public API (`getTrackInfo`, `startListening`, playback
  commands, `likeTrack`/`banTrack`/wishlist, seek helpers) exposes exactly the same
  current-track-only surface MediaRemoteAdapter already gives Islet today — confirming the
  Phase 74 discussion's finding was correct, not just an integration gap in how Islet calls it.

## How to Run

No script — this spike is answered by cross-referencing two independent, current sources against
a well-defined question ("does a queue-contents getter exist"), not by executable experimentation.
Writing a dlopen/dlsym probe would mean guessing at symbol names with no documented or
reverse-engineered candidate to test — that's fishing, not a spike with a hypothesis.

## Investigation Trail

**1. Tried to inspect the real framework binary directly** — the most rigorous option, since it
would give a definitive exported-symbol list rather than relying on secondhand documentation.
Blocked by the dyld shared cache: the on-disk framework has no executable, only resource files.

**2. Fell back to the two best available secondary sources** rather than stopping at "can't
check directly." Chose one older/general (iOS-era reversed header, broad coverage) and one
current/specific (the exact library already in this project, maintained by people solving this
exact integration problem today) to cross-reference against each other.

**3. Found a queue *concept* but not a queue *contents* API** — `QueueIndex` and a
`QueueDidChange` notification exist, which was a promising lead worth chasing, but neither
resolves to anything that returns titles/artists for items other than the current track. This
was pursued rather than stopped at the first negative — searched specifically for
`MRContentItem`, "content items", and other function-name patterns MediaRemote's iOS/CarPlay
cousins use for content lists; no matches.

**4. Cross-checked against the project's own actively maintained dependency.** If a working
queue-content trick existed via MediaRemote, ejbills/mediaremote-adapter — built specifically to
push past MediaRemote's practical limits (it bridges through an entitled Perl interpreter to
bypass sandboxing) — would be the most likely place for it to already be implemented. It isn't.

## Results

**Verdict: INVALIDATED.**

There is no undocumented app-agnostic queue-contents API in MediaRemote reachable from a
third-party process: the framework tracks *that* a queue exists and *where* the current item sits
in it, but never exposes the item list itself — not through the classic reversed header, and not
through the actively maintained library built specifically to maximize what's extractable from
this exact framework.

**Impact on Phase 74 (NOW-08):** All three spiked approaches are now invalidated:

| Source | Verdict | Why |
|---|---|---|
| Apple Music (AppleScript) | ✗ INVALIDATED | No queue API; autoplay overrides even playlist-order prediction |
| Spotify (AppleScript / Web API) | ✗ INVALIDATED | No queue object in AppleScript; Web API blocked by Feb-2026 Premium gate on app registration |
| Private MediaRemote (app-agnostic) | ✗ INVALIDATED | Queue index/notification exist, queue contents never exposed |

There is currently **no data source** that can deliver real "next 5 tracks" for NOW-08 as
specified. This is a decision point for the real build, not just a spike footnote — see the
report's Signal for the Build section.
