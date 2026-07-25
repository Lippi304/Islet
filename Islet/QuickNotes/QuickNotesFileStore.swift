import Foundation

// Phase 64 (D-18) — stub pending implementation.
enum QuickNotesFileStore {
    static func storageRoot() -> URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("IsletQuickNotes", isDirectory: true)
    }
}
