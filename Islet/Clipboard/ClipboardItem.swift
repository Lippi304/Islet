import Foundation

// Phase 55 — the PURE clipboard item value, establishing the append/evict-at-cap/
// clear contract before Phase 56 (encrypted persistence), Phase 57 (live pasteboard
// monitor), and Phase 58 (menu wiring) exist. Like ShelfItem, a plain Foundation-only
// struct — no AppKit, no NSPasteboard — so ClipboardStore's append/dedupe/evict rules
// are unit-tested in milliseconds. Kind is this codebase's first associated-value enum
// (QuickAddKind/OSDKeyKind/PermissionKind are all no-payload) — the shape below is
// standard Swift, not a codebase-specific pattern.
struct ClipboardItem: Equatable, Codable {
    let id: UUID
    var kind: Kind
    var timestamp: Date

    // Exactly two cases, no raw values — a constructed value can never be both text
    // and image, or neither, at once. Equatable/Codable synthesize automatically since
    // both String and Data conform.
    enum Kind: Equatable, Codable {
        case text(String)
        case image(Data)
    }
}
