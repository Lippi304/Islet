import XCTest
@testable import Islet

// Phase 55 — regression coverage for ClipboardStore's PURE append/evict-at-cap/D-02-
// dedupe/clear rules. Mirrors ShelfLogicTests.swift's shape: one test method per
// behavior, a fresh `var store = ClipboardStore()` per test, no setUp/tearDown, no
// shared fixture, no mocking framework.
final class ClipboardStoreTests: XCTestCase {

    func testAppendPast30ItemsEvictsOldest() {
        // D-01: cap = 30, FIFO evict oldest past cap.
        var store = ClipboardStore()
        for i in 0...30 {
            let item = ClipboardItem(id: UUID(), kind: .text("item-\(i)"),
                                      timestamp: Date(timeIntervalSinceReferenceDate: Double(i)))
            store.append(item)
        }
        XCTAssertEqual(store.items.count, 30)
        XCTAssertFalse(store.items.contains(where: { $0.kind == .text("item-0") }))
    }

    func testAppendDuplicateTextMovesExistingEntryToNewestWithRefreshedTimestamp() {
        // D-02: exact text match moves the EXISTING entry to the newest position with
        // a refreshed timestamp — never a no-op, never a second entry.
        var store = ClipboardStore()
        let original = ClipboardItem(id: UUID(), kind: .text("hello"),
                                      timestamp: Date(timeIntervalSinceReferenceDate: 0))
        let other = ClipboardItem(id: UUID(), kind: .text("world"),
                                   timestamp: Date(timeIntervalSinceReferenceDate: 1))
        let dupe = ClipboardItem(id: UUID(), kind: .text("hello"),
                                  timestamp: Date(timeIntervalSinceReferenceDate: 999))
        store.append(original)
        store.append(other)
        store.append(dupe)

        XCTAssertEqual(store.items.count, 2)
        XCTAssertEqual(store.items.last?.kind, .text("hello"))
        XCTAssertEqual(store.items.last?.timestamp, Date(timeIntervalSinceReferenceDate: 999))
    }

    func testAppendDuplicateImageMovesExistingEntryToNewestWithRefreshedTimestamp() {
        // D-02 applies uniformly to the image Kind case — byte-identical Data counts
        // as a duplicate.
        var store = ClipboardStore()
        let imageA = Data([0x01, 0x02, 0x03])
        let imageB = Data([0xAA, 0xBB, 0xCC])
        let original = ClipboardItem(id: UUID(), kind: .image(imageA),
                                      timestamp: Date(timeIntervalSinceReferenceDate: 0))
        let other = ClipboardItem(id: UUID(), kind: .image(imageB),
                                   timestamp: Date(timeIntervalSinceReferenceDate: 1))
        let dupe = ClipboardItem(id: UUID(), kind: .image(imageA),
                                  timestamp: Date(timeIntervalSinceReferenceDate: 999))
        store.append(original)
        store.append(other)
        store.append(dupe)

        XCTAssertEqual(store.items.count, 2)
        XCTAssertEqual(store.items.last?.kind, .image(imageA))
        XCTAssertEqual(store.items.last?.timestamp, Date(timeIntervalSinceReferenceDate: 999))
    }

    func testClearEmptiesStore() {
        // SC-3: clear() removes every item in one call, provably empty by construction.
        var store = ClipboardStore()
        store.append(ClipboardItem(id: UUID(), kind: .text("a"), timestamp: Date()))
        store.append(ClipboardItem(id: UUID(), kind: .text("b"), timestamp: Date()))
        store.clear()
        XCTAssertTrue(store.items.isEmpty)
    }
}
