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
    let hasArtwork: Bool           // presence only; the image itself is a Plan-02 @Published concern
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
