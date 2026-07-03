import Foundation

// Phase 4 / NOW-01 + NOW-03 — the PURE now-playing presentation seam (Pattern 1).
//
// Like NotchGeometry, NotchInteractionState, and PowerActivity, these are plain values
// + a total function importing ONLY Foundation — no MediaRemote, no AppKit, no NSImage,
// no Process here; that wiring lives in Plan 02. Tests build TrackSnapshot by hand, so the
// riskiest classification logic (the D-01 source allowlist, empty/nil-title rejection, and
// the playing/paused/none mapping) is unit-tested in milliseconds. Plan 02's monitor owns
// the real adapter stream and lifts a TrackSnapshot out of TrackInfo.Payload to feed in here.
//
// IMPORTANT: there is deliberately NO `.unavailable` case here. The D-12 "Now Playing
// nicht verfügbar" health state (adapter blocked / dead) is an ORTHOGONAL axis on the
// @Published model in Plan 02, NOT something derived from a snapshot. Keeping it out of
// this enum is what stops D-11 ("healthy API, nothing playing" → .none) from collapsing
// into D-12 ("the API itself is unavailable"). A nil snapshot here always means D-11.

// The minimal raw snapshot NowPlayingMonitor (Plan 02) lifts out of TrackInfo.Payload.
// Plain values (no NSImage — artwork presence only) so tests construct it by hand; mirrors
// PowerReading's role. The real NSImage flows to the @Published model in Plan 02, never
// through this pure seam.
struct TrackSnapshot: Equatable {
    let bundleIdentifier: String?  // the source app — checked against allowedBundleIDs (D-01)
    let isPlaying: Bool?           // nil → state unknown (A4: treat as paused)
    let title: String?             // nil / empty → nothing to show → .none
    let artist: String?            // nil → "" so the title still renders
    // PBAR-01 — raw playback-position fields lifted from TrackInfo.Payload (all Optional,
    // default nil so every existing hand-built TrackSnapshot(...) call site keeps compiling).
    // `var` (not `let`) is required here: Swift's synthesized memberwise init only treats a
    // stored property's initializer as a default *parameter* value for `var` properties —
    // for `let` properties with an initializer, the memberwise init drops the parameter
    // entirely (verified against the toolchain), which would break every 4-arg call site.
    var durationMicros: Double? = nil
    var elapsedTimeMicros: Double? = nil
    var timestampEpochMicros: Double? = nil
    var playbackRate: Double? = nil
}

// The presentation the media view renders. `.unavailable` (D-12 health) is intentionally
// NOT here — see the file header.
enum NowPlayingPresentation: Equatable {
    case playing(title: String, artist: String)
    case paused(title: String, artist: String)
    case none   // healthy API, nothing playing / non-allowlisted source (D-11)
}

// D-01: only these two sources are surfaced in v1. Everything else (browsers, other
// players) maps to .none — no glance, no controls.
let allowedBundleIDs: Set<String> = ["com.spotify.client", "com.apple.Music"]

// TOTAL pure mapping. nil snapshot == "no media" (D-11) → .none, never .unavailable.
func nowPlayingPresentation(from s: TrackSnapshot?) -> NowPlayingPresentation {
    guard let s,
          let bundle = s.bundleIdentifier, allowedBundleIDs.contains(bundle),  // D-01 allowlist
          let title = s.title, !title.isEmpty                                   // empty/nil title → none
    else { return .none }
    let artist = s.artist ?? ""
    return (s.isPlaying == true) ? .playing(title: title, artist: artist)       // A4: nil isPlaying → paused
                                 : .paused(title: title, artist: artist)
}

// 06-10 Finding 16 — pure same-track comparison so NotchWindowController.handleNowPlaying
// can retain previously-loaded artwork across a callback that carries no image for the SAME
// track (the documented artwork-latency case: album art can arrive a beat after metadata),
// while still clearing it on a genuine track change or a stop. `true` only when BOTH sides
// have a non-nil (title, artist) pair AND those pairs are equal — a play↔pause transition on
// the same track is "same track" (the playing/paused axis is deliberately ignored), a title
// change or a transition to/from `.none` is not.
func isSameTrack(_ a: NowPlayingPresentation, _ b: NowPlayingPresentation) -> Bool {
    func titleArtist(_ p: NowPlayingPresentation) -> (title: String, artist: String)? {
        switch p {
        case .playing(let t, let a), .paused(let t, let a): return (t, a)
        case .none: return nil
        }
    }
    guard let ta = titleArtist(a), let tb = titleArtist(b) else { return false }
    return ta == tb
}

// PBAR-01 — the pure playback-position seam (Plan 07-01). Mirrors the file's existing
// discipline: plain values + total functions, Foundation only, no SwiftUI/AppKit. Ported
// VERBATIM from the vendored TrackInfo.Payload.currentElapsedTime formula (pinned commit
// cf30c4f1af29b5829d859f088f8dbdf12611a046) so the drift-correction math has one source of
// truth, unit-tested here instead of only exercised on-device.
struct PlaybackPosition: Equatable {
    let duration: TimeInterval          // seconds
    let elapsedAtSnapshot: TimeInterval // seconds, as of timestampAtSnapshot
    let timestampAtSnapshot: TimeInterval // Unix epoch seconds
    let rate: Double
}

// TOTAL pure mapping. nil unless ALL 4 raw TrackSnapshot fields are present — per
// UI-SPEC.md's Copywriting Contract, a nil result is what later makes the view render the
// progress row at opacity(0), never a "--:--" placeholder string.
func playbackPosition(from snapshot: TrackSnapshot?) -> PlaybackPosition? {
    guard let snapshot,
          let durationMicros = snapshot.durationMicros,
          let elapsedTimeMicros = snapshot.elapsedTimeMicros,
          let timestampEpochMicros = snapshot.timestampEpochMicros,
          let playbackRate = snapshot.playbackRate
    else { return nil }
    return PlaybackPosition(duration: durationMicros / 1_000_000,
                             elapsedAtSnapshot: elapsedTimeMicros / 1_000_000,
                             timestampAtSnapshot: timestampEpochMicros / 1_000_000,
                             rate: playbackRate)
}

// TOTAL pure formula, ported VERBATIM from TrackInfo.Payload.currentElapsedTime (RESEARCH.md
// Pattern 2). The paused guard MUST come first — RESEARCH.md Pitfall 1 documents that
// reordering this (computing the `now`-based drift correction before checking isPlaying)
// causes a paused track to silently drift forward every time the view re-renders.
func currentElapsedSeconds(_ position: PlaybackPosition, isPlaying: Bool, now: TimeInterval) -> TimeInterval {
    guard isPlaying else { return position.elapsedAtSnapshot }
    return position.elapsedAtSnapshot + ((now - position.timestampAtSnapshot) * position.rate)
}

// Bugfix (on-device UAT, Task 3): resolves which PlaybackPosition to publish across a
// play→pause transition. MediaRemote's paused snapshot can carry a stale elapsedTimeMicros
// (a periodic sample taken before the real pause instant), which would otherwise render a
// brief backward jump before a later corrected snapshot arrives. On a genuine play→pause
// transition for the SAME track, freeze using our own drift-corrected estimate (extrapolated
// from the last known-good PLAYING position to `now`) instead of trusting the snapshot's raw
// value — immune to upstream sampling lag. Every other transition (resume, track change,
// stop, repeated paused emission) passes the incoming value through unchanged.
func resolvePublishedPosition(previous: NowPlayingPresentation, previousPosition: PlaybackPosition?,
                               incoming: NowPlayingPresentation, incomingPosition: PlaybackPosition?,
                               now: TimeInterval) -> PlaybackPosition? {
    guard case .playing = previous, case .paused = incoming,
          isSameTrack(previous, incoming),
          let prevPos = previousPosition, let newPos = incomingPosition
    else { return incomingPosition }
    let frozenElapsed = currentElapsedSeconds(prevPos, isPlaying: true, now: now)
    return PlaybackPosition(duration: newPos.duration, elapsedAtSnapshot: frozenElapsed,
                             timestampAtSnapshot: now, rate: newPos.rate)
}
