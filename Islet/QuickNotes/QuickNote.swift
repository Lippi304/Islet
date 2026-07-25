import Foundation

// Phase 64 (NOTES-02/NOTES-03) — the pure Quick Notes value, mirroring
// Islet/Clipboard/ClipboardItem.swift's shape minus the Kind enum: a note is
// always plain text, never image data.
struct QuickNote: Equatable, Codable {
    let id: UUID
    var text: String
    var timestamp: Date
}
