import MediaRemoteAdapter
import AppKit

// Phase 4 / NOW-01 + NOW-02 + NOW-03 — the THIN MediaRemote glue (Plan 02).
//
// This is the ONLY file in the app that imports MediaRemoteAdapter. Per the CLAUDE.md
// mandate ("isolate all now-playing code behind one Swift protocol/service so swapping
// the implementation is a one-file change"), the fragile private-MediaRemote bridge is
// quarantined here. A future Apple break is a one-file fix.
//
// Mirrors PowerSourceMonitor.swift's discipline: a @MainActor thin glue with injected
// closures, a start()/stop() lifecycle, and explicit child teardown — NOT a pure
// fixture-tested seam. The riskiest CLASSIFICATION logic lives in the pure
// NowPlayingPresentation.swift seam (Plan 01), unit-tested in ms; this glue is verified
// ON-DEVICE (real MediaRemote IPC / process lifecycle can't be unit-tested — see
// 04-VALIDATION.md).
//
// Research corrections honored over CONTEXT.md/CLAUDE.md (RESEARCH §Pattern 2, A1/A2):
//   - STREAM via `onTrackInfoReceived` + `startListening()` — ONE persistent `loop` child,
//     never re-spawned per update (success-criterion-4). `getTrackInfo {…}` is the ONE-SHOT
//     (it re-spawns perl per call) and is used ONLY for the launch health probe, NEVER for
//     live updates (A1).
//   - The wrapper ALREADY dispatches every callback to `DispatchQueue.main.async`
//     (verified in MediaController.swift), so we add NO second main-hop (A2). We still treat
//     all callbacks as main-thread.
//
// Health-check semantics (D-12, Pattern 3 option a — a documented design choice, A3):
// the Swift wrapper does NOT expose ungive's `test` subcommand, so the launch health probe
// is synthesized. `getTrackInfo`'s nil is ambiguous (no-media OR a failed bridge — Pitfall
// 1), and `onListenerTerminated` does NOT fire for a child that never emitted (eventCount==0
// — Pitfall 2). Therefore we treat "a callback arrived at all within the timeout" as healthy
// and "no callback within the timeout" as unavailable. This probe is what covers the
// blocked-at-launch case; mid-session death is covered separately by onListenerTerminated.

// CLAUDE.md's "Now Playing — the MediaRemote reality" mandate: "isolate all now-playing
// code behind one Swift protocol/service so swapping the implementation is a one-file
// change." NotchWindowController holds its stored property typed against this protocol,
// not the concrete NowPlayingMonitor class below — a future MediaRemote break is a
// one-file swap of the concrete conformer.
protocol NowPlayingService: AnyObject {
    func start()
    nonisolated func stop()
    func togglePlayPause()
    func nextTrack()
    func previousTrack()
    func runHealthCheck(then setHealthy: @escaping (Bool) -> Void)
}

@MainActor
final class NowPlayingMonitor: NowPlayingService {
    // nonisolated(unsafe) so stop() can run from NotchWindowController's nonisolated deinit
    // (T-04-12 child teardown), mirroring PowerSourceMonitor's nonisolated(unsafe) runLoopSource.
    // The controller is constructed + driven on main for the whole app lifetime; the deinit
    // teardown at app-quit is the sole nonisolated reader, calling only stopListening() (child
    // process termination), so there is no concurrent access.
    private nonisolated(unsafe) let controller = MediaController()
    // nil snapshot = "no media now" (the engine emitted NIL → D-11). Non-nil = a track
    // update. The NSImage is the pre-decoded artwork (decoded inside the wrapper).
    private let onSnapshot: (TrackSnapshot?, NSImage?) -> Void
    // D-13 mid-session child death — fires only after at least one emission (eventCount != 0).
    private let onTerminated: () -> Void

    init(onSnapshot: @escaping (TrackSnapshot?, NSImage?) -> Void,
         onTerminated: @escaping () -> Void) {
        self.onSnapshot = onSnapshot
        self.onTerminated = onTerminated
    }

    func start() {
        controller.onTrackInfoReceived = { [weak self] info in
            guard let self else { return }
            // NIL payload → no media (D-11). No second main-hop (the wrapper already hopped).
            guard let p = info?.payload else { self.onSnapshot(nil, nil); return }
            let snap = TrackSnapshot(bundleIdentifier: p.bundleIdentifier,
                                     isPlaying: p.isPlaying,
                                     title: p.title,
                                     artist: p.artist,
                                     durationMicros: p.durationMicros,
                                     elapsedTimeMicros: p.elapsedTimeMicros,
                                     timestampEpochMicros: p.timestampEpochMicros,
                                     playbackRate: p.playbackRate)
            self.onSnapshot(snap, p.artwork)   // artwork already off-thread-decoded by the wrapper
        }
        controller.onListenerTerminated = { [weak self] in self?.onTerminated() }   // D-13
        controller.startListening()   // ONE persistent `loop` child — emits the current session immediately
    }

    // Mirror PowerSourceMonitor.stop(): terminate the child. nonisolated so the controller's
    // nonisolated deinit can call it (Plan 04) — no orphaned perl (T-04-04 / T-04-12). The body
    // is a thread-safe child-process termination on the nonisolated(unsafe) controller.
    nonisolated func stop() { controller.stopListening() }

    // NOW-02 — transport rides the EXISTING child's stdin (no re-spawn):
    func togglePlayPause() { controller.togglePlayPause() }
    func nextTrack()       { controller.nextTrack() }
    func previousTrack()   { controller.previousTrack() }

    // D-12 launch-time health check (Pattern 3 option a — see file header for the why).
    // "A callback arrived at all" → healthy; "no callback within the timeout" → unavailable.
    func runHealthCheck(then setHealthy: @escaping (Bool) -> Void) {
        var settled = false
        controller.getTrackInfo { info in
            if settled { return }
            settled = true
            setHealthy(true)   // heard back → the bridge is alive
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if settled { return }
            settled = true
            setHealthy(false)   // never heard back → D-12 "nicht verfügbar"
        }
    }
}
