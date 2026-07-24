import Foundation
import CoreServices

// Phase 61 / DL-01 + DL-02 (Plan 04) — the LIVE FSEvents wrapper watching only ~/Downloads.
// Lifecycle skeleton cloned from CapsLockMonitor.swift, MINUS the Accessibility gate — FSEvents
// on the user's own ~/Downloads requires no special TCC permission, unlike CapsLockMonitor's
// .flagsChanged global monitor. Bridges the FSEvents C callback into pure DownloadReading
// values fed to `onEvent`; Plan 04's NotchWindowController wiring forwards those straight into
// DownloadCoordinator.handle(_:).
//
// Pitfall 1 (top-level-only filtering): a write happening INSIDE a Safari .download bundle's
// own contents (e.g. a nested partial-data file) must never re-fire onEvent — only the
// bundle's own top-level create/rename does, since THAT event's parent IS the watched
// Downloads root. Enforced below via deletingLastPathComponent == downloadsPath exactly.
//
// Pitfall 2/3 (cross-batch rename correlation): a single `mv`-style rename (temp path
// disappears, final path appears) can arrive as two SEPARATE FSEvents — sometimes in the same
// callback batch, sometimes in different ones, but always in-order within a batch (FSEvents
// preserves order via eventIds). pendingRenamesByFileID pairs the two halves via the per-event
// file ID (only available with kFSEventStreamCreateFlagUseExtendedData set) — a SEPARATE table
// from DownloadCoordinator's own inFlightDownloads (that one tracks known-in-progress downloads
// for the transient queue; this one only exists to correlate raw FSEvents halves of one mv).
@MainActor
final class DownloadMonitor {
    // nonisolated(unsafe) so stop() can run from NotchWindowController's nonisolated deinit —
    // mirrors CapsLockMonitor.monitorToken / PowerSourceMonitor.runLoopSource.
    private nonisolated(unsafe) var streamRef: FSEventStreamRef?
    private let onEvent: (DownloadReading) -> Void

    // D-07 — the ONLY path this monitor ever watches, no per-browser custom download-folder
    // configuration. Computed once at init, read again inside the callback's top-level filter.
    private let downloadsPath = (NSHomeDirectory() as NSString).appendingPathComponent("Downloads")

    private var pendingRenamesByFileID: [UInt64: String] = [:]
    // Code review WR-03 — an interrupted/coalesced rename (the "moved to" half never arrives)
    // would otherwise leave its "moved away" half in this table for the app's entire lifetime,
    // risking a stale entry mis-correlating with a later, unrelated fileID reuse.
    // ponytail: cap-and-reset instead of proper LRU eviction — this is a rare edge case (an
    // in-flight download's rename literally never completing), so a full reset on overflow is a
    // simple, sufficient ceiling. Upgrade to timestamped eviction if unmatched entries ever
    // become common enough to observe in practice.
    private let pendingRenamesCap = 32

    init(onEvent: @escaping (DownloadReading) -> Void) {
        self.onEvent = onEvent
    }

    // Idempotent start (mirrors CapsLockMonitor.start()'s guard) — no permission check needed.
    func start() {
        guard streamRef == nil else { return }

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let flags = FSEventStreamCreateFlags(
            kFSEventStreamCreateFlagFileEvents |
            kFSEventStreamCreateFlagUseCFTypes |
            kFSEventStreamCreateFlagUseExtendedData
        )

        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            downloadMonitorFSEventsCallback,
            &context,
            [downloadsPath] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),  // D-14 — never replay history
            0.3,  // latency (seconds) — coalesces rapid events, well inside SC1's budget
            flags
        ) else { return }

        streamRef = stream
        FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
        FSEventStreamStart(stream)
    }

    nonisolated func stop() {
        if let stream = streamRef {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            streamRef = nil
        }
    }

    deinit {
        // Empty by design — owner's deinit calls stop(), mirrors every other monitor.
    }

    // Called by the free-function C callback below (already hopped to main / this instance).
    // Classifies each pre-extracted event in the batch per Pitfall 1/2/3, in the given order.
    fileprivate func handleBatch(_ events: [(path: String, fileID: UInt64?, flags: FSEventStreamEventFlags)]) {
        for event in events {
            // Pitfall 1 — only top-level entries directly inside the watched Downloads folder.
            guard (event.path as NSString).deletingLastPathComponent == downloadsPath else { continue }

            let exists = FileManager.default.fileExists(atPath: event.path)
            let renamed = event.flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemRenamed) != 0
            let created = event.flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemCreated) != 0
            let removed = event.flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemRemoved) != 0

            if renamed {
                if !exists {
                    // "Moved away" half.
                    if let fileID = event.fileID {
                        if pendingRenamesByFileID.count >= pendingRenamesCap { pendingRenamesByFileID.removeAll() }
                        pendingRenamesByFileID[fileID] = event.path
                    } else {
                        onEvent(DownloadReading(path: event.path, kind: .removed, fileID: nil, renamedTo: nil))
                    }
                } else {
                    // "Moved to" half.
                    if let fileID = event.fileID, let oldPath = pendingRenamesByFileID.removeValue(forKey: fileID) {
                        onEvent(DownloadReading(path: oldPath, kind: .renamed, fileID: fileID, renamedTo: event.path))
                    } else {
                        onEvent(DownloadReading(path: event.path, kind: .created, fileID: event.fileID, renamedTo: nil))
                    }
                }
            } else if created, exists {
                onEvent(DownloadReading(path: event.path, kind: .created, fileID: event.fileID, renamedTo: nil))
            } else if removed, !exists {
                onEvent(DownloadReading(path: event.path, kind: .removed, fileID: event.fileID, renamedTo: nil))
            }
        }
    }
}

// Free C-function-pointer callback — @convention(c) closures/functions cannot capture context,
// so `self` is recovered via Unmanaged.fromOpaque(clientCallBackInfo) (bridged in via
// FSEventStreamContext.info in start() above), mirroring PowerSourceMonitor's identical
// Pitfall-2 bridging shape. The per-event dictionaries/pointers FSEvents hands us are only
// valid for the duration of this call, so extraction into plain values happens HERE, before
// handing off to the MainActor-isolated instance method.
private func downloadMonitorFSEventsCallback(
    streamRef: ConstFSEventStreamRef,
    clientCallBackInfo: UnsafeMutableRawPointer?,
    numEvents: Int,
    eventPaths: UnsafeMutableRawPointer,
    eventFlags: UnsafePointer<FSEventStreamEventFlags>,
    eventIds: UnsafePointer<FSEventStreamEventId>
) {
    guard let clientCallBackInfo else { return }
    let monitor = Unmanaged<DownloadMonitor>.fromOpaque(clientCallBackInfo).takeUnretainedValue()
    guard let dicts = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue() as NSArray as? [[String: Any]] else { return }

    var events: [(path: String, fileID: UInt64?, flags: FSEventStreamEventFlags)] = []
    events.reserveCapacity(numEvents)
    for i in 0..<numEvents where i < dicts.count {
        guard let path = dicts[i][kFSEventStreamEventExtendedDataPathKey as String] as? String else { continue }
        let fileID = (dicts[i][kFSEventStreamEventExtendedFileIDKey as String] as? NSNumber)?.uint64Value
        events.append((path, fileID, eventFlags[i]))
    }

    // FSEventStreamSetDispatchQueue(stream, DispatchQueue.main) guarantees this callback
    // already runs on the main queue — assumeIsolated asserts that synchronously (never an
    // async hop, which would be unsafe anyway: eventPaths/eventFlags are only valid for this
    // call's duration, already fully extracted into `events` above).
    MainActor.assumeIsolated {
        monitor.handleBatch(events)
    }
}
