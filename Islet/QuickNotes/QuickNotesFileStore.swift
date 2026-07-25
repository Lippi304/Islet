import Foundation

// Phase 64 (D-18) — persistence shape mirroring
// Islet/Clipboard/ClipboardFileStore.swift's load-never-throws discipline, minus
// the encryption/Keychain layer (notes persist as deliberate plaintext, per
// NOTES-03) and minus the image-file/ClipboardItemRecord indirection (QuickNote
// is directly Codable). Own storage root, never shared with Clipboard's.
enum QuickNotesFileStore {
    static func storageRoot() -> URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("IsletQuickNotes", isDirectory: true)
    }

    // D-18: any failure along this chain (missing file, corrupted JSON) returns
    // [] — never throws, never crashes.
    static func load(root: URL) -> [QuickNote] {
        let indexURL = root.appendingPathComponent("index.json")
        guard let data = try? Data(contentsOf: indexURL),
              let notes = try? JSONDecoder().decode([QuickNote].self, from: data)
        else { return [] }
        return notes
    }

    static func save(_ notes: [QuickNote], root: URL) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(notes)
        try data.write(to: root.appendingPathComponent("index.json"))
    }
}
