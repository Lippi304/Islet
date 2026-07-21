import AppKit

// Phase 4 / NOW-01/02/03 — the SEPARATE @Published media model, mirroring
// ChargingActivityState. Deliberately NOT folded into NotchInteractionState or
// ChargingActivityState, so the Phase-2 gesture machine + Phase-3 charging splash stay
// untouched and D-14 precedence is a one-line `if` in the view.
//
// Plain published holder: no methods, no timers, no MediaRemote. The monitor (this plan)
// lifts payloads → TrackSnapshot → the pure seam and sets `presentation`; the controller
// (Plan 04) drives `isHealthy` from the launch probe (D-12) + onListenerTerminated (D-13).
final class NowPlayingState: ObservableObject {
    // The classified media presentation (D-11 .none = healthy, no media).
    @Published var presentation: NowPlayingPresentation = .none
    // The pre-decoded album art (arrives with the payload, may be nil → placeholder).
    // Plan 03's view shows a music-note placeholder when nil.
    @Published var artwork: NSImage?
    // D-12 health axis, ORTHOGONAL to presentation. false → on expand show
    // "Now Playing nicht verfügbar". Default true (assume healthy until the launch
    // probe says otherwise).
    @Published var isHealthy: Bool = true
    // Phase 17 / NOW-04 — D-01/D-02: has a .playing presentation been observed at least once
    // since this Islet process launched? ORTHOGONAL to presentation (mirrors isHealthy's own
    // orthogonality). Default false (gated) — set to true ONCE in handleNowPlaying on the first
    // .playing snapshot and NEVER reset (D-02: no re-arm for the rest of the process lifetime).
    @Published var hasPlayedSinceLaunch: Bool = false
    // Phase 18 / NOW-05 — the toast's OWN title/artist snapshot, stored SEPARATELY from
    // `presentation` (D-03: during a rapid skip the toast can show an OLDER settled track
    // while `presentation` has already moved on to a newer one — never alias this to
    // `presentation`). Default nil. Set by the controller (Plan 02) when a genuine change
    // passes the suppression gate; cleared by the toast's own dismiss timer, by an
    // interrupting transient/manual-expand starting (Plan 02 Task 1), or by the toggle
    // being turned off mid-toast.
    @Published var songChangeToast: TrackToast? = nil
    // PBAR-01 — the live playback-position snapshot (duration/elapsed/timestamp/rate),
    // nil when any raw field is missing. The ProgressBar view derives the drift-corrected
    // elapsed time from this via currentElapsedSeconds(...), never storing a ticking value.
    @Published var position: PlaybackPosition?
    // Phase 30 / HOME-02 — D-07/D-08: the most-recently-playing track, kept ALIVE across the
    // transition to `.none` (unlike `presentation`/`artwork`, which the controller clears on
    // stop). Session-only — never persisted, never reset except by app relaunch (fresh process
    // state). Overwritten every time a NEW track starts .playing (D-08), never frozen on first
    // capture. Plan 02 (NotchWindowController.swift) populates it; this plan only declares the
    // contract.
    @Published var lastKnownTrack: LastPlayedTrack? = nil
    // Phase 53 / RESUME-02 — D-03's orthogonal failure flag. Set true by
    // NotchWindowController's inferred-timeout watcher (handleResumeTap) when a resume tap
    // produces no fresh .playing snapshot in time; read by NotchPillView.resumePreviewWings
    // to swap the EqualizerBars slot for "Wiedergabe nicht möglich". Reset to false at the
    // start of every resume attempt and on every fresh hover-entry so a stale failure never
    // reappears on a later unrelated hover.
    @Published var resumePreviewFailed: Bool = false
}

// Phase 30 / HOME-02 — the sticky last-played snapshot's data contract. Plain struct, no
// Equatable conformance: nothing in this phase compares two instances, and a hand-written
// `==` ignoring `NSImage` would exist for zero consumers.
struct LastPlayedTrack {
    let title: String
    let artist: String
    let artwork: NSImage?
}
