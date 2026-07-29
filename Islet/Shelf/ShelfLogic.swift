import Foundation

// Phase 19 / SHELF-08 — the shelf's append/remove/dedupe/clear rules as a PURE value
// type. Mirrors TransientQueue (Islet/Notch/IslandResolver.swift): a struct with
// mutating func operations, no AppKit, no FileManager, no Timer/clock inside — the
// controller (Plan 19-01 Task 3, ShelfCoordinator) is the one that performs the actual
// file copy/delete around calls into this type. D-06: append-only, oldest-first
// ordering. D-01/D-02: duplicate detection keyed on (originalURL, filename), a silent
// no-op that leaves the existing item's position/addedAt untouched.
struct ShelfLogic: Equatable {
    private(set) var items: [ShelfItem] = []

    // D-06: append-only, oldest-first. D-01/D-02: a duplicate (originalURL, filename)
    // pair is a silent no-op — returns false, the existing item's position and addedAt
    // are untouched. Returns true iff `item` was actually appended.
    //
    // Phase 70 fix — filename joined the key alongside originalURL: Convert derives
    // multiple DIFFERENT output files (different filename/extension) from the SAME
    // originalURL, and originalURL alone rejected every conversion after the first one
    // from a given source as a false-positive duplicate, silently discarding the
    // freshly-converted file. originalURL-only remains correct for Drop/AirDrop/Mail,
    // where re-dropping the same file always produces the identical filename too.
    @discardableResult
    mutating func append(_ item: ShelfItem) -> Bool {
        let isDuplicate = items.contains { existing in
            existing.originalURL == item.originalURL && existing.filename == item.filename
        }
        guard !isDuplicate else { return false }
        items.append(item)
        return true
    }

    // Removes the item with the given id, if present. Returns the removed item (the
    // caller uses this to know which localURL to delete per D-05) or nil if no match.
    @discardableResult
    mutating func remove(id: UUID) -> ShelfItem? {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return nil }
        return items.remove(at: index)
    }

    // Clears every item. Returns the removed items (the caller deletes each localURL
    // per D-05).
    @discardableResult
    mutating func clear() -> [ShelfItem] {
        let removed = items
        items.removeAll()
        return removed
    }
}
