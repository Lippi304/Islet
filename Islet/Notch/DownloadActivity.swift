import Foundation

// Phase 61 / DL-01 + DL-02 — the PURE download→presentation seam (Pattern 1).
//
// Like DeviceActivity.swift, this file holds BOTH the raw reading type a later
// system-glue monitor (DownloadMonitor, Plan 61-04) lifts values into, AND the
// presentation enum, AND the stateless D-08/D-12 helpers — no state across calls.
// `DownloadCoordinator.swift` (Plan 61-02) is the STATEFUL layer (the per-tempPath
// in-flight side table); nothing here holds state.
//
// SECURITY (T-61-01): `path`/`renamedTo` are UNTRUSTED — they ultimately derive from a
// browser-controlled/attacker-influenceable download filename. Never interpolate either
// into a format string, shell command, or further path-construction call beyond plain
// display (enforced at the UI layer, Plan 61-03).

// The 3 raw filesystem-change kinds DownloadMonitor (Plan 61-04) classifies FSEvents
// flags into.
enum DownloadEventKind: Equatable {
    case created
    case renamed
    case removed
}

// The minimal raw reading DownloadMonitor (Plan 61-04) lifts out of FSEvents callbacks.
// Plain values so tests construct it by hand, mirroring DeviceReading's convention.
// For `.created`/`.removed`, `path` is the temp path and `renamedTo` is nil. For
// `.renamed`, `path` is the OLD (temp) path and `renamedTo` is the NEW (final) path.
struct DownloadReading: Equatable {
    let path: String
    let kind: DownloadEventKind
    let fileID: UInt64?
    let renamedTo: String?
}

// The presentation payload (D-09: `.inProgress` carries no filename; D-12: `.done`
// carries the real, final filename).
enum DownloadActivity: Equatable {
    case inProgress
    case done(filename: String)
}

// D-08's exact 3 known temp-file suffixes — Chrome/Edge, Firefox, Safari.
private let downloadTempSuffixes = [".crdownload", ".part", ".download"]

// Pure D-08 suffix check, no state, no I/O.
func isDownloadTempFile(path: String) -> Bool {
    downloadTempSuffixes.contains { path.hasSuffix($0) }
}

// Pure D-12 final-name extraction, no state, no I/O.
func downloadFilename(fromPath path: String) -> String {
    (path as NSString).lastPathComponent
}
