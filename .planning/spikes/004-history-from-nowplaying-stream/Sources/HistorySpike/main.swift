import Foundation
import MediaRemoteAdapter

// Spike 004: does MediaController's onTrackInfoReceived stream let us build a
// correct, deduplicated "last 5 played" history? Mirrors the library's own
// isSameTrack (title+artist, album equal-or-empty) since that's the only
// identity signal available — there's no stable track ID.

struct TrackKey: Equatable, CustomStringConvertible {
    let title: String
    let artist: String
    let album: String

    var description: String { "\"\(title)\" — \(artist)" }

    static func same(_ a: TrackInfo.Payload, _ b: TrackInfo.Payload) -> Bool {
        guard (a.title ?? "") == (b.title ?? ""), (a.artist ?? "") == (b.artist ?? "") else { return false }
        let aAlbum = a.album ?? "", bAlbum = b.album ?? ""
        return aAlbum == bAlbum || aAlbum.isEmpty || bAlbum.isEmpty
    }
}

struct HistoryEntry {
    let key: TrackKey
    let enteredAt: Date
}

final class HistoryAccumulator {
    private(set) var currentPayload: TrackInfo.Payload?
    private(set) var history: [HistoryEntry] = []
    private let cap = 5

    var eventLog: [[String: Any]] = []
    var rawCount = 0
    var refreshCount = 0
    var changeCount = 0
    var nilCount = 0

    let iso = ISO8601DateFormatter()

    func log(_ category: String, _ fields: [String: Any] = [:]) {
        var entry: [String: Any] = ["ts": iso.string(from: Date()), "category": category]
        entry.merge(fields) { a, _ in a }
        eventLog.append(entry)
    }

    func handle(_ info: TrackInfo?) {
        rawCount += 1
        guard let payload = info?.payload else {
            nilCount += 1
            log("NIL_EVENT")
            print("[\(ts())] NIL (nothing playing / no track info)")
            return
        }

        guard let title = payload.title, !title.isEmpty else {
            log("EMPTY_TITLE_EVENT")
            print("[\(ts())] EMPTY_TITLE event ignored (isPlaying=\(payload.isPlaying ?? false))")
            return
        }

        let newKey = TrackKey(title: title, artist: payload.artist ?? "", album: payload.album ?? "")

        if let current = currentPayload, TrackKey.same(current, payload) {
            refreshCount += 1
            let artworkDelta = (payload.artworkDataBase64?.count ?? 0) - (current.artworkDataBase64?.count ?? 0)
            log("REFRESH_IGNORED", ["track": newKey.description, "artworkDelta": artworkDelta, "elapsedMicros": payload.elapsedTimeMicros ?? -1])
            print("[\(ts())] REFRESH (same track, ignored)   \(newKey)   artworkDelta=\(artworkDelta)")
            currentPayload = payload
            return
        }

        // Real track change.
        changeCount += 1
        if let current = currentPayload {
            let previousKey = TrackKey(title: current.title ?? "", artist: current.artist ?? "", album: current.album ?? "")
            history.insert(HistoryEntry(key: previousKey, enteredAt: Date()), at: 0)
            if history.count > cap { history.removeLast(history.count - cap) }
        }
        currentPayload = payload
        log("TRACK_CHANGE", ["track": newKey.description])
        print("[\(ts())] TRACK CHANGE -> \(newKey)")
        printHistory()
    }

    func printHistory() {
        print("   history (last \(history.count)):")
        for (i, entry) in history.enumerated() {
            print("     \(i + 1). \(entry.key)")
        }
    }

    func printSummary() {
        print("""

        === Summary ===
        raw events:        \(rawCount)
        track changes:      \(changeCount)
        refreshes ignored: \(refreshCount)
        nil events:        \(nilCount)
        final history:
        """)
        printHistory()
    }

    func exportLog(to path: String) {
        let data = try? JSONSerialization.data(withJSONObject: eventLog, options: [.prettyPrinted])
        try? data?.write(to: URL(fileURLWithPath: path))
        print("Event log written to \(path) (\(eventLog.count) events)")
    }

    private func ts() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: Date())
    }
}

let accumulator = HistoryAccumulator()
let controller = MediaController()

controller.onTrackInfoReceived = { info in
    accumulator.handle(info)
}
controller.onListenerTerminated = {
    print("[\(Date())] Listener terminated unexpectedly.")
}

print("""
Spike 004: history-from-nowplaying-stream
Listening for now-playing changes. Play music, skip tracks, skip back to a
previous track, pause/resume. Press Ctrl+C to stop and dump the event log.
""")

signal(SIGINT, SIG_IGN)
let sigintSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
sigintSource.setEventHandler {
    accumulator.printSummary()
    accumulator.exportLog(to: FileManager.default.currentDirectoryPath + "/events.json")
    exit(0)
}
sigintSource.resume()

controller.startListening()

RunLoop.main.run()
