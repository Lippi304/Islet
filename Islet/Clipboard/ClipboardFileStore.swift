import Foundation
import CryptoKit

// Phase 56 / CLIP-04 / PRIV-02 (D-04 / D-06) — the ONE place performing real
// FileManager I/O + AES-GCM encryption for the clipboard, kept as a standalone
// enum (not a method on ClipboardStore) so ClipboardStore stays a pure,
// side-effect-free reducer — mirrors ShelfFileStore's stated rationale
// relative to ShelfLogic.
enum ClipboardFileStoreError: Error, Equatable {
    case sealFailed
}

// The on-disk JSON-index shape. Image bytes are never stored inline — only a
// filename reference (Pitfall 4) — so the index blob stays small regardless
// of how many/large the persisted images are.
struct ClipboardItemRecord: Codable {
    let id: UUID
    let kind: String
    let text: String?
    let imageFilename: String?
    let timestamp: Date
}

enum ClipboardFileStore {
    static func storageRoot() -> URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("IsletClipboard", isDirectory: true)
    }

    // D-04: any single failure along this chain (missing file, corrupted
    // ciphertext, wrong key, malformed JSON) returns [] — never throws, never
    // crashes.
    static func load(root: URL, key: SymmetricKey) -> [ClipboardItem] {
        let indexURL = root.appendingPathComponent("index.json.enc")
        guard let combined = try? Data(contentsOf: indexURL),
              let plaintext = try? decrypt(combined, using: key),
              let records = try? JSONDecoder().decode([ClipboardItemRecord].self, from: plaintext)
        else { return [] }

        let imagesDir = root.appendingPathComponent("images", isDirectory: true)
        return records.compactMap { record -> ClipboardItem? in
            switch record.kind {
            case "text":
                return ClipboardItem(id: record.id, kind: .text(record.text ?? ""), timestamp: record.timestamp)
            case "image":
                guard let imageFilename = record.imageFilename else { return nil }
                let imageURL = imagesDir.appendingPathComponent(imageFilename)
                guard let combined = try? Data(contentsOf: imageURL),
                      let imageData = try? decrypt(combined, using: key)
                else { return nil }
                return ClipboardItem(id: record.id, kind: .image(imageData), timestamp: record.timestamp)
            default:
                return nil
            }
        }
    }

    // D-06: writes new image files and the new index FIRST (Pitfall 3 — a
    // mid-save crash must never leave a referenced-but-missing file), then
    // sweeps images/ for filenames not referenced by the incoming `items`
    // array and deletes them.
    static func save(_ items: [ClipboardItem], root: URL, key: SymmetricKey) throws {
        let imagesDir = root.appendingPathComponent("images", isDirectory: true)
        try FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)

        var records: [ClipboardItemRecord] = []
        var expectedImageFilenames = Set<String>()

        for item in items {
            switch item.kind {
            case .text(let text):
                records.append(ClipboardItemRecord(id: item.id, kind: "text", text: text, imageFilename: nil, timestamp: item.timestamp))
            case .image(let data):
                let filename = item.id.uuidString + ".enc"
                expectedImageFilenames.insert(filename)
                let encrypted = try encrypt(data, using: key)
                try encrypted.write(to: imagesDir.appendingPathComponent(filename))
                records.append(ClipboardItemRecord(id: item.id, kind: "image", text: nil, imageFilename: filename, timestamp: item.timestamp))
            }
        }

        let plaintext = try JSONEncoder().encode(records)
        let encryptedIndex = try encrypt(plaintext, using: key)
        try encryptedIndex.write(to: root.appendingPathComponent("index.json.enc"))

        let onDiskFiles = (try? FileManager.default.contentsOfDirectory(at: imagesDir, includingPropertiesForKeys: nil)) ?? []
        for fileURL in onDiskFiles where !expectedImageFilenames.contains(fileURL.lastPathComponent) {
            deleteOrphanedImageFile(at: fileURL, root: root)
        }
    }

    // SC#3/D-06: internal (not private) so tests can call it directly — mirrors
    // ShelfFileStore.deleteSessionCopy's access level and exact guard shape.
    static func deleteOrphanedImageFile(at fileURL: URL, root: URL) {
        let fileURL = fileURL.standardizedFileURL
        let root = root.standardizedFileURL
        guard fileURL.path.hasPrefix(root.path + "/") else { return }
        try? FileManager.default.removeItem(at: fileURL)
    }

    private static func encrypt(_ plaintext: Data, using key: SymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.seal(plaintext, using: key)
        guard let combined = sealedBox.combined else {
            throw ClipboardFileStoreError.sealFailed
        }
        return combined
    }

    private static func decrypt(_ combined: Data, using key: SymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.SealedBox(combined: combined)
        return try AES.GCM.open(sealedBox, using: key)
    }
}
