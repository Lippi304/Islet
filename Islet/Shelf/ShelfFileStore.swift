import Foundation

// Phase 19 / SHELF-08 (D-03/D-04/D-05) — the ONE place in the codebase that performs
// real FileManager/NSTemporaryDirectory() I/O for the shelf (19-PATTERNS.md confirmed
// zero prior art), kept as a small standalone helper (not a method on ShelfLogic) so
// ShelfLogic itself stays a pure, side-effect-free reducer — mirrors how
// DeviceCoordinator performs IOBluetooth IO around TransientQueue's pure calls rather
// than putting IO inside TransientQueue itself.
enum ShelfFileStoreError: Error, Equatable {
    case invalidFilename
}

enum ShelfFileStore {
    // D-03: copies a dropped file's bytes into a per-item session-temp subfolder
    // immediately on add. T-19-01 (Tampering, mitigate): `filenameComponent` is
    // validated BEFORE the destination path is constructed or any disk I/O happens —
    // this is a SECURITY check, not just a validity check, preventing a crafted
    // sourceURL (e.g. one whose last path component is "..") from writing outside the
    // intended IsletShelf/<uuid>/ subfolder.
    static func makeSessionCopy(of sourceURL: URL, id: UUID) throws -> URL {
        let filenameComponent = sourceURL.lastPathComponent
        guard filenameComponent != ".", filenameComponent != "..", !filenameComponent.isEmpty else {
            throw ShelfFileStoreError.invalidFilename
        }

        let itemDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("IsletShelf", isDirectory: true)
            .appendingPathComponent(id.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: itemDir, withIntermediateDirectories: true)

        let destination = itemDir.appendingPathComponent(filenameComponent)
        // D-04: copyItem only reads sourceURL, never mutates it.
        try FileManager.default.copyItem(at: sourceURL, to: destination)
        return destination
    }

    // D-05: removes the entire per-item IsletShelf/<uuid>/ subfolder (not just the
    // file), so nothing lingers. Non-throwing — D-05 callers should never need to
    // handle a delete failure; `try?` makes double-delete and already-gone paths
    // silent no-ops (idempotent).
    //
    // CR-01 guard: only ever delete a directory that actually lives under this
    // store's own IsletShelf temp root. `localURL` on a ShelfItem is a plain,
    // freely constructible `var` — nothing else in the type system stops a future
    // caller from passing a URL that was never produced by makeSessionCopy. Without
    // this check, that mistake would recursively delete the parent directory of an
    // arbitrary real file (e.g. the user's Downloads folder). A URL outside the
    // shelf root is a silent no-op, same idempotency stance as an already-deleted path.
    static func deleteSessionCopy(at localURL: URL) {
        let itemDir = localURL.deletingLastPathComponent().standardizedFileURL
        let shelfRoot = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("IsletShelf", isDirectory: true)
            .standardizedFileURL
        guard itemDir.path.hasPrefix(shelfRoot.path + "/") else { return }
        try? FileManager.default.removeItem(at: itemDir)
    }
}
