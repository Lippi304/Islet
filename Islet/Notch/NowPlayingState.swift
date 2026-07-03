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
    // PBAR-01 — the live playback-position snapshot (duration/elapsed/timestamp/rate),
    // nil when any raw field is missing. The ProgressBar view derives the drift-corrected
    // elapsed time from this via currentElapsedSeconds(...), never storing a ticking value.
    @Published var position: PlaybackPosition?
}
