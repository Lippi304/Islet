import Foundation

// Phase 55 — the clipboard's append/evict-at-cap/clear rules as a PURE value type.
// Mirrors ShelfLogic's shape (private(set) items array, mutating func API, zero
// AppKit/NSPasteboard/FileManager) and this project's existing cap/FIFO-eviction
// mechanics used elsewhere in the notch's activity-arbitration layer. Deliberately
// departs from ShelfLogic.append's dedupe behavior per D-02: a duplicate moves the
// EXISTING entry to the newest position with a refreshed timestamp — it never
// no-ops and never creates a second entry. This is the one deliberate divergence
// from the Shelf precedent. Independent of any monitor/menu axis by design (SC-4).
struct ClipboardStore: Equatable {
    private(set) var items: [ClipboardItem] = []
    let cap = 30   // D-01: plain inline let, not configurable, not shared

    // D-02: a match on Kind (exact text match, or byte-identical image Data) is a
    // duplicate — the existing entry is removed and `item` (carrying its own fresh
    // timestamp) is reinserted at the newest end. D-03: no validation on content size.
    mutating func append(_ item: ClipboardItem) {
        if let index = items.firstIndex(where: { $0.kind == item.kind }) {
            items.remove(at: index)
            items.append(item)
            return
        }
        items.append(item)
        if items.count > cap { items.removeFirst() }   // D-01: FIFO evict oldest past cap
    }

    mutating func clear() {
        items.removeAll()
    }
}
