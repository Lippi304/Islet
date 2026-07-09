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
                                    isPlaying: true, title: "Song", artist: "Artist")
        XCTAssertEqual(nowPlayingPresentation(from: spotify), .playing(title: "Song", artist: "Artist"))

        let music = TrackSnapshot(bundleIdentifier: "com.apple.Music",
                                  isPlaying: false, title: "Song", artist: "Artist")
        XCTAssertEqual(nowPlayingPresentation(from: music), .paused(title: "Song", artist: "Artist"))

        // D-01: any non-allowlisted bundle id → .none, even with a perfectly valid title.
        let chrome = TrackSnapshot(bundleIdentifier: "com.google.Chrome",
                                   isPlaying: true, title: "YouTube video", artist: "Channel")
        XCTAssertEqual(nowPlayingPresentation(from: chrome), .none)

        // A nil bundle id (source unknown) is also outside the allowlist → .none.
        let noBundle = TrackSnapshot(bundleIdentifier: nil,
                                     isPlaying: true, title: "Song", artist: "Artist")
        XCTAssertEqual(nowPlayingPresentation(from: noBundle), .none)
    }

    // MARK: NOW-01 — title/artist mapping; empty/nil title → .none

    func testNoTitleMapsToNone() {
        // Allowlisted source but no title (nil) → nothing meaningful to show → .none.
        let nilTitle = TrackSnapshot(bundleIdentifier: "com.spotify.client",
                                     isPlaying: true, title: nil, artist: "Artist")
        XCTAssertEqual(nowPlayingPresentation(from: nilTitle), .none)

        // Allowlisted source but an empty title → still .none (empty is not a real track).
        let emptyTitle = TrackSnapshot(bundleIdentifier: "com.apple.Music",
                                       isPlaying: true, title: "", artist: "Artist")
        XCTAssertEqual(nowPlayingPresentation(from: emptyTitle), .none)
    }

    // MARK: NOW-03 — playing vs paused classification (+ artist mapping)

    func testPlayingVsPausedClassification() {
        // isPlaying true → .playing with title + artist.
        let playing = TrackSnapshot(bundleIdentifier: "com.spotify.client",
                                    isPlaying: true, title: "Track", artist: "Band")
        XCTAssertEqual(nowPlayingPresentation(from: playing), .playing(title: "Track", artist: "Band"))

        // isPlaying false → .paused with title + artist.
        let paused = TrackSnapshot(bundleIdentifier: "com.spotify.client",
                                   isPlaying: false, title: "Track", artist: "Band")
        XCTAssertEqual(nowPlayingPresentation(from: paused), .paused(title: "Track", artist: "Band"))

        // Artist nil → mapped to "" so the title still shows (no optional bleeding into the view).
        let noArtist = TrackSnapshot(bundleIdentifier: "com.apple.Music",
                                     isPlaying: true, title: "Track", artist: nil)
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
                                         isPlaying: nil, title: "Track", artist: "Band")
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

    // MARK: songChangeToastContent(...) / TrackToast — Phase 18 NOW-05 regression coverage

    func testSongChangeToastContentForGenuineChange() {
        // A genuine change from one playing track to another, after launch, toasts the new track.
        XCTAssertEqual(songChangeToastContent(previous: .playing(title: "A", artist: "X"),
                                              current: .playing(title: "B", artist: "Y"),
                                              hasPlayedSinceLaunch: true),
                       TrackToast(title: "B", artist: "Y"))
    }

    func testSongChangeToastContentForGenuineChangeFromPausedTrack() {
        // A genuine change is still a genuine change even if the previous track was paused.
        XCTAssertEqual(songChangeToastContent(previous: .paused(title: "A", artist: "X"),
                                              current: .playing(title: "B", artist: "Y"),
                                              hasPlayedSinceLaunch: true),
                       TrackToast(title: "B", artist: "Y"))
    }

    func testSongChangeToastContentNilForSameTrackPlayPause() {
        // Same track, play->pause is NOT a genuine change (isSameTrack semantics).
        XCTAssertNil(songChangeToastContent(previous: .playing(title: "A", artist: "X"),
                                            current: .paused(title: "A", artist: "X"),
                                            hasPlayedSinceLaunch: true))
    }

    func testSongChangeToastContentNilWhenNotYetPlayedSinceLaunch() {
        // Pitfall 2: the very first track after launch never toasts, gated on the
        // PRE-callback hasPlayedSinceLaunch value.
        XCTAssertNil(songChangeToastContent(previous: .none,
                                            current: .playing(title: "A", artist: "X"),
                                            hasPlayedSinceLaunch: false))
    }

    func testSongChangeToastContentNilForStop() {
        // Pitfall 1: a stop is not a genuine change, never toast a blank title.
        XCTAssertNil(songChangeToastContent(previous: .playing(title: "A", artist: "X"),
                                            current: .none,
                                            hasPlayedSinceLaunch: true))
    }

    // MARK: PBAR-01 — PlaybackPosition mapping + drift-corrected elapsed formula

    func testPlaybackPositionAllFieldsPresent() {
        let snapshot = TrackSnapshot(bundleIdentifier: "com.spotify.client",
                                     isPlaying: true, title: "Track", artist: "Band",
                                     durationMicros: 225_000_000,
                                     elapsedTimeMicros: 83_000_000,
                                     timestampEpochMicros: 1_700_000_000_000_000,
                                     playbackRate: 1.0)
        XCTAssertEqual(playbackPosition(from: snapshot),
                        PlaybackPosition(duration: 225.0, elapsedAtSnapshot: 83.0,
                                          timestampAtSnapshot: 1_700_000_000.0, rate: 1.0))
    }

    func testPlaybackPositionNilWhenAnyFieldMissing() {
        // Missing durationMicros (the other 3 present) -> nil, never a partial value.
        let missingDuration = TrackSnapshot(bundleIdentifier: "com.spotify.client",
                                            isPlaying: true, title: "Track", artist: "Band",
                                            durationMicros: nil,
                                            elapsedTimeMicros: 83_000_000,
                                            timestampEpochMicros: 1_700_000_000_000_000,
                                            playbackRate: 1.0)
        XCTAssertNil(playbackPosition(from: missingDuration))
    }

    func testCurrentElapsedSecondsWhilePlaying() {
        let position = PlaybackPosition(duration: 225.0, elapsedAtSnapshot: 10.0,
                                        timestampAtSnapshot: 1000.0, rate: 1.0)
        XCTAssertEqual(currentElapsedSeconds(position, isPlaying: true, now: 1005.0), 15.0)
    }

    func testCurrentElapsedSecondsPausedFreezesAtSnapshot() {
        // Same position, but paused with a far-future `now` — deliberately provoking drift
        // if the guard were missing (RESEARCH.md Pitfall 1). The paused branch must ignore
        // `now` entirely.
        let position = PlaybackPosition(duration: 225.0, elapsedAtSnapshot: 10.0,
                                        timestampAtSnapshot: 1000.0, rate: 1.0)
        XCTAssertEqual(currentElapsedSeconds(position, isPlaying: false, now: 999_999.0), 10.0)
    }

    // MARK: PBAR-01 bugfix — pause-transition position freeze

    func testResolvePublishedPositionFreezesOnPlayToPauseSameTrack() {
        // Last known-good PLAYING position: elapsedAtSnapshot 10.0 @ t=1000.0, rate 1.0.
        let previousPosition = PlaybackPosition(duration: 225.0, elapsedAtSnapshot: 10.0,
                                                 timestampAtSnapshot: 1000.0, rate: 1.0)
        // Incoming PAUSED snapshot's raw position is STALE — it claims elapsed 8.0 (a
        // sample taken before the real pause instant), which would be a visible backward
        // jump from the last-rendered 10.0+ if trusted verbatim.
        let incomingPosition = PlaybackPosition(duration: 225.0, elapsedAtSnapshot: 8.0,
                                                 timestampAtSnapshot: 1002.0, rate: 1.0)
        let previous = NowPlayingPresentation.playing(title: "Track", artist: "Band")
        let incoming = NowPlayingPresentation.paused(title: "Track", artist: "Band")

        let resolved = resolvePublishedPosition(previous: previous, previousPosition: previousPosition,
                                                  incoming: incoming, incomingPosition: incomingPosition,
                                                  now: 1004.0)

        // Expected: our own drift-corrected estimate from the PREVIOUS playing position,
        // extrapolated to `now` (1004.0) — NOT the incoming snapshot's raw 8.0.
        // currentElapsedSeconds(previousPosition, isPlaying: true, now: 1004.0)
        //   = 10.0 + (1004.0 - 1000.0) * 1.0 = 14.0
        XCTAssertEqual(resolved, PlaybackPosition(duration: 225.0, elapsedAtSnapshot: 14.0,
                                                    timestampAtSnapshot: 1004.0, rate: 1.0))
    }

    func testResolvePublishedPositionPassesThroughOnPausedToPaused() {
        // Previous already .paused (not .playing) -> not a play->pause transition -> pass
        // through the incoming value unchanged, even though a previousPosition exists.
        let previousPosition = PlaybackPosition(duration: 225.0, elapsedAtSnapshot: 10.0,
                                                 timestampAtSnapshot: 1000.0, rate: 1.0)
        let incomingPosition = PlaybackPosition(duration: 225.0, elapsedAtSnapshot: 10.0,
                                                 timestampAtSnapshot: 1000.0, rate: 1.0)
        let previous = NowPlayingPresentation.paused(title: "Track", artist: "Band")
        let incoming = NowPlayingPresentation.paused(title: "Track", artist: "Band")

        let resolved = resolvePublishedPosition(previous: previous, previousPosition: previousPosition,
                                                  incoming: incoming, incomingPosition: incomingPosition,
                                                  now: 1004.0)
        XCTAssertEqual(resolved, incomingPosition)
    }

    func testResolvePublishedPositionPassesThroughOnPlayingToPlaying() {
        // Previous and incoming both .playing (no pause transition) -> pass through.
        let previousPosition = PlaybackPosition(duration: 225.0, elapsedAtSnapshot: 10.0,
                                                 timestampAtSnapshot: 1000.0, rate: 1.0)
        let incomingPosition = PlaybackPosition(duration: 225.0, elapsedAtSnapshot: 12.0,
                                                 timestampAtSnapshot: 1002.0, rate: 1.0)
        let previous = NowPlayingPresentation.playing(title: "Track", artist: "Band")
        let incoming = NowPlayingPresentation.playing(title: "Track", artist: "Band")

        let resolved = resolvePublishedPosition(previous: previous, previousPosition: previousPosition,
                                                  incoming: incoming, incomingPosition: incomingPosition,
                                                  now: 1004.0)
        XCTAssertEqual(resolved, incomingPosition)
    }

    func testResolvePublishedPositionPassesThroughOnTrackChange() {
        // A play->pause transition, but a DIFFERENT track -> isSameTrack is false -> pass
        // through the incoming value (don't freeze using the old track's position).
        let previousPosition = PlaybackPosition(duration: 225.0, elapsedAtSnapshot: 10.0,
                                                 timestampAtSnapshot: 1000.0, rate: 1.0)
        let incomingPosition = PlaybackPosition(duration: 180.0, elapsedAtSnapshot: 2.0,
                                                 timestampAtSnapshot: 1002.0, rate: 1.0)
        let previous = NowPlayingPresentation.playing(title: "Old Track", artist: "Band")
        let incoming = NowPlayingPresentation.paused(title: "New Track", artist: "Band")

        let resolved = resolvePublishedPosition(previous: previous, previousPosition: previousPosition,
                                                  incoming: incoming, incomingPosition: incomingPosition,
                                                  now: 1004.0)
        XCTAssertEqual(resolved, incomingPosition)
    }

    func testResolvePublishedPositionPassesThroughWhenPreviousPositionNil() {
        // A genuine play->pause/same-track transition, but no previousPosition on record
        // (e.g. the very first callback) -> nothing to extrapolate from -> pass through.
        let incomingPosition = PlaybackPosition(duration: 225.0, elapsedAtSnapshot: 8.0,
                                                 timestampAtSnapshot: 1002.0, rate: 1.0)
        let previous = NowPlayingPresentation.playing(title: "Track", artist: "Band")
        let incoming = NowPlayingPresentation.paused(title: "Track", artist: "Band")

        let resolved = resolvePublishedPosition(previous: previous, previousPosition: nil,
                                                  incoming: incoming, incomingPosition: incomingPosition,
                                                  now: 1004.0)
        XCTAssertEqual(resolved, incomingPosition)
    }

    func testResolvePublishedPositionPassesThroughWhenIncomingPositionNil() {
        // A genuine play->pause/same-track transition, but the incoming snapshot carries no
        // position at all -> nothing to shape into a PlaybackPosition -> pass through nil.
        let previousPosition = PlaybackPosition(duration: 225.0, elapsedAtSnapshot: 10.0,
                                                 timestampAtSnapshot: 1000.0, rate: 1.0)
        let previous = NowPlayingPresentation.playing(title: "Track", artist: "Band")
        let incoming = NowPlayingPresentation.paused(title: "Track", artist: "Band")

        let resolved = resolvePublishedPosition(previous: previous, previousPosition: previousPosition,
                                                  incoming: incoming, incomingPosition: nil,
                                                  now: 1004.0)
        XCTAssertNil(resolved)
    }
}
