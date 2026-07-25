import Foundation

// Phase 64 (NOTES-02/NOTES-03) — the pure Quick Notes value, mirroring
// Islet/Clipboard/ClipboardItem.swift's shape minus the Kind enum: a note is
// always plain text, never image data.
// Phase 64-07 (gap closure) — fileName records which vault .md file this note
// was written to, so a future delete/submit can target the exact file the note
// actually lives in (Plan 64-08). The custom Decodable init below makes old,
// already-persisted index.json entries (written before this field existed)
// decode successfully instead of being silently dropped by
// QuickNotesFileStore.load's "any decode failure returns []" discipline.
struct QuickNote: Equatable, Codable {
    let id: UUID
    var text: String
    var timestamp: Date
    var fileName: String = ActivitySettings.quickNotesDefaultFileName

    enum CodingKeys: String, CodingKey {
        case id, text, timestamp, fileName
    }

    init(id: UUID, text: String, timestamp: Date, fileName: String = ActivitySettings.quickNotesDefaultFileName) {
        self.id = id
        self.text = text
        self.timestamp = timestamp
        self.fileName = fileName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        fileName = try container.decodeIfPresent(String.self, forKey: .fileName) ?? ActivitySettings.quickNotesDefaultFileName
    }
}
