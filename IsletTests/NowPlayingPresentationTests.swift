import XCTest
@testable import Islet

// Phase 4 / NOW-01 + NOW-03: the PURE now-playing presentation seam. Like
// NotchGeometry and PowerActivity, nowPlayingPresentation(from:) is a total,
// framework-free function — no MediaRemote, no AppKit, no NSImage — so the riskiest
// classification logic (D-01 source allowlist, empty/nil title rejection, the
// playing/paused/none mapping, and the D-11 "no media" vs D-12 "unavailable"
// distinction) is verified deterministically by an automated agent in milliseconds.
// Plan 02 owns the real adapter stream and lifts a TrackSnapshot out of
// TrackInfo.Payload to feed values in here.
final class NowPlayingPresentationTests: XCTestCase {

    // MARK: NOW-01 — the D-01 source allowlist (Spotify + Apple Music only)

    func testAllowlistFiltersBundleID() {
        // Both allowlisted sources with a title classify to a real presentation (non-.none).
        let spotify = TrackSnapshot(bundleIdentifier: "com.spotify.client",
                                    isPlaying: true, title: "Song", artist: "Artist", hasArtwork: true)
        XCTAssertEqual(nowPlayingPresentation(from: spotify), .playing(title: "Song", artist: "Artist"))

        let music = TrackSnapshot(bundleIdentifier: "com.apple.Music",
                                  isPlaying: false, title: "Song", artist: "Artist", hasArtwork: true)
        XCTAssertEqual(nowPlayingPresentation(from: music), .paused(title: "Song", artist: "Artist"))

        // D-01: any non-allowlisted bundle id → .none, even with a perfectly valid title.
        let chrome = TrackSnapshot(bundleIdentifier: "com.google.Chrome",
                                   isPlaying: true, title: "YouTube video", artist: "Channel", hasArtwork: true)
        XCTAssertEqual(nowPlayingPresentation(from: chrome), .none)

        // A nil bundle id (source unknown) is also outside the allowlist → .none.
        let noBundle = TrackSnapshot(bundleIdentifier: nil,
                                     isPlaying: true, title: "Song", artist: "Artist", hasArtwork: true)
        XCTAssertEqual(nowPlayingPresentation(from: noBundle), .none)
    }

    // MARK: NOW-01 — title/artist mapping; empty/nil title → .none

    func testNoTitleMapsToNone() {
        // Allowlisted source but no title (nil) → nothing meaningful to show → .none.
        let nilTitle = TrackSnapshot(bundleIdentifier: "com.spotify.client",
                                     isPlaying: true, title: nil, artist: "Artist", hasArtwork: true)
        XCTAssertEqual(nowPlayingPresentation(from: nilTitle), .none)

        // Allowlisted source but an empty title → still .none (empty is not a real track).
        let emptyTitle = TrackSnapshot(bundleIdentifier: "com.apple.Music",
                                       isPlaying: true, title: "", artist: "Artist", hasArtwork: true)
        XCTAssertEqual(nowPlayingPresentation(from: emptyTitle), .none)
    }

    // MARK: NOW-03 — playing vs paused classification (+ artist mapping)

    func testPlayingVsPausedClassification() {
        // isPlaying true → .playing with title + artist.
        let playing = TrackSnapshot(bundleIdentifier: "com.spotify.client",
                                    isPlaying: true, title: "Track", artist: "Band", hasArtwork: true)
        XCTAssertEqual(nowPlayingPresentation(from: playing), .playing(title: "Track", artist: "Band"))

        // isPlaying false → .paused with title + artist.
        let paused = TrackSnapshot(bundleIdentifier: "com.spotify.client",
                                   isPlaying: false, title: "Track", artist: "Band", hasArtwork: true)
        XCTAssertEqual(nowPlayingPresentation(from: paused), .paused(title: "Track", artist: "Band"))

        // Artist nil → mapped to "" so the title still shows (no optional bleeding into the view).
        let noArtist = TrackSnapshot(bundleIdentifier: "com.apple.Music",
                                     isPlaying: true, title: "Track", artist: nil, hasArtwork: false)
        XCTAssertEqual(nowPlayingPresentation(from: noArtist), .playing(title: "Track", artist: ""))
    }

    // MARK: NOW-03 — D-11: nil snapshot is "no media", NOT "unavailable"

    func testNilSnapshotMapsToNone() {
        // A nil snapshot means the API is healthy but nothing is playing → .none (D-11).
        // This is deliberately NOT an unavailable state — D-12 health is an orthogonal
        // @Published axis modeled in Plan 02, never derived from a snapshot here.
        XCTAssertEqual(nowPlayingPresentation(from: nil), .none)
    }

    // MARK: NOW-03 — A4: track loaded but play-state unknown → .paused

    func testNilIsPlayingMapsToPaused() {
        // isPlaying nil (a track is loaded but the adapter didn't report a state) → .paused:
        // safest default, shows the track without claiming it is actively playing.
        let unknownState = TrackSnapshot(bundleIdentifier: "com.spotify.client",
                                         isPlaying: nil, title: "Track", artist: "Band", hasArtwork: true)
        XCTAssertEqual(nowPlayingPresentation(from: unknownState), .paused(title: "Track", artist: "Band"))
    }

    // MARK: 06-10 Finding 16 — isSameTrack(_:_:): retain artwork across a same-track nil
    // callback (album art can arrive a beat after metadata), clear it on a genuine track
    // change or a stop.

    func testIsSameTrackAcrossPlayPause() {
        // Same title+artist, only the playing/paused axis differs — a play<->pause
        // transition on the SAME track must read as "same track" (retain artwork).
        XCTAssertTrue(isSameTrack(.playing(title: "A", artist: "B"), .paused(title: "A", artist: "B")))
    }

    func testIsSameTrackDifferentTitle() {
        // Different title -> different track -> artwork must clear.
        XCTAssertFalse(isSameTrack(.playing(title: "A", artist: "B"), .playing(title: "C", artist: "B")))
    }

    func testIsSameTrackStopClears() {
        // Playback stopped (-> .none) -> artwork must clear.
        XCTAssertFalse(isSameTrack(.playing(title: "A", artist: "B"), .none))
    }

    func testIsSameTrackBothNoneIsFalse() {
        // No track on either side -> nothing to retain.
        XCTAssertFalse(isSameTrack(.none, .none))
    }
}
