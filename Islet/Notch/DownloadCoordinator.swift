import Foundation

// Phase 61 / DL-01 + DL-02 — the STATEFUL per-tempPath layer that turns DownloadMonitor's
// (Plan 61-04) raw create/rename/remove readings into the queue-facing
// `.downloadProgress(DownloadActivity)` transient. Mirrors DeviceCoordinator's
// address-keyed side table (per PATTERNS.md), keyed by tempPath instead since each temp
// file IS its own logical download (D-06), not a shared device address.
//
// Resolves D-05/D-06's multi-instance-identity requirement (per-file in-flight tracking,
// replaceHead only when the LAST download completes) and RESEARCH.md's Open Question 1: a
// completing download's own done state is delivered via plain TransientQueue
// enqueue/advance mechanics, never a coordinator-side promoted re-check (unlike
// DeviceCoordinator's battery-poll follow-up) — see activityPromoted() below.
@MainActor
final class DownloadCoordinator: ActivityCoordinator {
    typealias Reading = DownloadReading

    // Phase 61 / D-05/D-06 — per-tempPath in-flight side table, keyed by tempPath (each temp
    // file is its own logical download).
    private struct InFlightDownload: Equatable {
        let tempPath: String
        let fileID: UInt64?
        let startedAt: Date
    }
    private var inFlightDownloads: [String: InFlightDownload] = [:]

    // Four reach-back closures — SMALLER than DeviceCoordinator's six (no battery-poll/
    // updateHead-for-scrub equivalent needed). `enqueue` is expected to already carry the
    // caller's own preempt-if-Focus-else-enqueue logic (mirrors DeviceCoordinator's own
    // `enqueue` closure contract — this coordinator never inspects `queueHead()` to decide
    // Focus-preemption itself). `replaceHead` is expected to do `transientQueue.updateHead(t)`
    // PLUS re-arm the shared ~3s dismiss timer (mirrors `handleOSDKeyPress`'s in-place
    // branch) — Plan 61-04 wires both.
    private let queueHead: () -> ActiveTransient?
    private let enqueue: (ActiveTransient) -> Bool
    private let replaceHead: (ActiveTransient) -> Void
    private let presentTransientChange: () -> Void

    init(queueHead: @escaping () -> ActiveTransient?,
         enqueue: @escaping (ActiveTransient) -> Bool,
         replaceHead: @escaping (ActiveTransient) -> Void,
         presentTransientChange: @escaping () -> Void) {
        self.queueHead = queueHead
        self.enqueue = enqueue
        self.replaceHead = replaceHead
        self.presentTransientChange = presentTransientChange
    }

    // ActivityCoordinator conformance — reads the live clock and forwards to the testable
    // overload below (mirrors DeviceCoordinator's handle(_:)/handle(_:now:) split).
    func handle(_ reading: DownloadReading) {
        handle(reading, now: Date())
    }

    // The testable overload — no Date() call anywhere inside this body, so `startedAt`
    // timestamps are deterministic in tests.
    func handle(_ reading: DownloadReading, now: Date) {
        switch reading.kind {
        case .created:
            // D-08 — a non-matching-suffix path is ignored entirely: no tracking, no enqueue.
            guard isDownloadTempFile(path: reading.path) else { return }
            inFlightDownloads[reading.path] = InFlightDownload(tempPath: reading.path, fileID: reading.fileID, startedAt: now)
            // D-05's "shows only the most recently started one" falls out for free here: every
            // in-progress download renders the SAME generic value (D-09), so TransientQueue's
            // own equality-based dedup naturally collapses a second concurrent download into a
            // no-op re-enqueue attempt with zero visual change.
            if enqueue(.downloadProgress(.inProgress)) { presentTransientChange() }

        case .renamed:
            // D-08 re-applied at rename time — an untracked path can't be "this download's"
            // completion.
            guard inFlightDownloads.removeValue(forKey: reading.path) != nil else { return }
            guard let finalPath = reading.renamedTo else { return }
            let doneActivity = ActiveTransient.downloadProgress(.done(filename: downloadFilename(fromPath: finalPath)))

            if inFlightDownloads.isEmpty {
                // This WAS the last tracked download (D-05/D-06) — replace the standing head in
                // place if it is currently a downloadProgress transient in EITHER inner case (the
                // stale .inProgress, or a different download's still-showing .done splash);
                // otherwise fall back to plain enqueue (D-05's "fires independently later").
                if case .downloadProgress = queueHead() {
                    replaceHead(doneActivity)
                } else if enqueue(doneActivity) {
                    presentTransientChange()
                }
            } else {
                // Another download is still in flight — D-05's literal "the older download's own
                // done state still fires independently later": queue behind the current
                // .inProgress head, never replace it while a real download is still active.
                _ = enqueue(doneActivity)
            }

        case .removed:
            // D-15 — cancelled downloads silently drop, regardless of whether the path was
            // tracked: no enqueue/replaceHead call at all.
            inFlightDownloads.removeValue(forKey: reading.path)
        }
    }

    // RESEARCH.md Open Question 1's resolution: unlike DeviceCoordinator's battery-poll
    // follow-up, Download has no deferred side-effect that needs re-checking once a different
    // transient is promoted to head — a completing download's own .done transition is fully
    // handled inside handle(_:now:)'s .renamed branch above, via plain TransientQueue
    // enqueue/advance mechanics. This empty body still satisfies ActivityCoordinator's
    // protocol requirement.
    func activityPromoted() {}

    // Mirrors DeviceCoordinator.reset()'s exact one-line shape — clears the in-flight table on
    // Settings toggle-off. Consumed by Plan 61-04's handleSettingsChanged toggle-off branch.
    func reset() { inFlightDownloads.removeAll() }
}
