import XCTest
@testable import Islet

// Phase 64 (NOTES-03, D-14/D-17) — regression coverage for QuickNotesStore's
// PURE append/evict-at-cap/remove(id:) rules. Mirrors ClipboardStoreTests.swift's
// shape: one test method per behavior, a fresh `var store = QuickNotesStore()`
// per test, no setUp/tearDown, no mocking.
final class QuickNotesStoreTests: XCTestCase {

    func testAppendPast30NotesEvictsOldest() {
        // D-14: cap = 30, FIFO evict oldest past cap.
        var store = QuickNotesStore()
        for i in 0...30 {
            let note = QuickNote(id: UUID(), text: "note-\(i)",
                                  timestamp: Date(timeIntervalSinceReferenceDate: Double(i)))
            store.append(note)
        }
        XCTAssertEqual(store.items.count, 30)
        XCTAssertFalse(store.items.contains(where: { $0.text == "note-0" }))
        XCTAssertTrue(store.items.contains(where: { $0.text == "note-30" }))
    }

    func testAppendingIdenticalTextCreatesTwoSeparateEntries() {
        // Discretion note: no dedupe branch — append is the simpler default for notes.
        var store = QuickNotesStore()
        let first = QuickNote(id: UUID(), text: "same text", timestamp: Date(timeIntervalSinceReferenceDate: 0))
        let second = QuickNote(id: UUID(), text: "same text", timestamp: Date(timeIntervalSinceReferenceDate: 1))
        store.append(first)
        store.append(second)

        XCTAssertEqual(store.items.count, 2)
        XCTAssertEqual(store.items, [first, second])
    }

    func testRemoveByIdDeletesOnlyThatEntry() {
        // D-17: remove(id:) deletes only the matching entry, leaves every other
        // entry's text/timestamp untouched.
        var store = QuickNotesStore()
        let keepA = QuickNote(id: UUID(), text: "keep A", timestamp: Date(timeIntervalSinceReferenceDate: 0))
        let toRemove = QuickNote(id: UUID(), text: "remove me", timestamp: Date(timeIntervalSinceReferenceDate: 1))
        let keepB = QuickNote(id: UUID(), text: "keep B", timestamp: Date(timeIntervalSinceReferenceDate: 2))
        store.append(keepA)
        store.append(toRemove)
        store.append(keepB)

        store.remove(id: toRemove.id)

        XCTAssertEqual(store.items.count, 2)
        XCTAssertTrue(store.items.contains(keepA))
        XCTAssertTrue(store.items.contains(keepB))
        XCTAssertFalse(store.items.contains(where: { $0.id == toRemove.id }))
    }

    func testRemoveByIdWithAbsentIdIsSafeNoOp() {
        // D-17: no crash, no change, if the id isn't present.
        var store = QuickNotesStore()
        let note = QuickNote(id: UUID(), text: "only note", timestamp: Date())
        store.append(note)

        store.remove(id: UUID())

        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(store.items, [note])
    }
}
