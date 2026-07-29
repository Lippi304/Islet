import XCTest
@testable import Islet

// Phase 19 / SHELF-08 — regression coverage for ShelfLogic's PURE append/remove/clear/
// dedupe rules. Mirrors IslandResolverTests.swift's TransientQueue section: one test
// method per behavior, a fresh `var logic = ShelfLogic()` per test, no shared fixture,
// no setUp/tearDown, no mocking framework.
final class ShelfLogicTests: XCTestCase {

    func testAppendAddsToEndInDropOrder() {
        // D-06: new items append to the end, oldest-first, in exactly drop order.
        var logic = ShelfLogic()
        let a = ShelfItem(id: UUID(), originalURL: URL(fileURLWithPath: "/a.pdf"),
                           localURL: URL(fileURLWithPath: "/tmp/a.pdf"), filename: "a.pdf",
                           addedAt: Date(timeIntervalSinceReferenceDate: 0))
        let b = ShelfItem(id: UUID(), originalURL: URL(fileURLWithPath: "/b.pdf"),
                           localURL: URL(fileURLWithPath: "/tmp/b.pdf"), filename: "b.pdf",
                           addedAt: Date(timeIntervalSinceReferenceDate: 1))
        let c = ShelfItem(id: UUID(), originalURL: URL(fileURLWithPath: "/c.pdf"),
                           localURL: URL(fileURLWithPath: "/tmp/c.pdf"), filename: "c.pdf",
                           addedAt: Date(timeIntervalSinceReferenceDate: 2))
        XCTAssertTrue(logic.append(a))
        XCTAssertTrue(logic.append(b))
        XCTAssertTrue(logic.append(c))
        XCTAssertEqual(logic.items.map(\.filename), ["a.pdf", "b.pdf", "c.pdf"])
    }

    func testAppendDuplicateOriginalURLIsSilentNoOp() {
        // D-01/D-02: same originalURL → no-op, existing item's position/addedAt untouched.
        var logic = ShelfLogic()
        let original = ShelfItem(id: UUID(), originalURL: URL(fileURLWithPath: "/a.pdf"),
                                  localURL: URL(fileURLWithPath: "/tmp/a.pdf"), filename: "a.pdf",
                                  addedAt: Date(timeIntervalSinceReferenceDate: 0))
        let dupe = ShelfItem(id: UUID(), originalURL: URL(fileURLWithPath: "/a.pdf"),
                              localURL: URL(fileURLWithPath: "/tmp/a-copy.pdf"), filename: "a.pdf",
                              addedAt: Date(timeIntervalSinceReferenceDate: 999))
        XCTAssertTrue(logic.append(original))
        XCTAssertFalse(logic.append(dupe))
        XCTAssertEqual(logic.items, [original])   // unchanged — dupe never entered
    }

    func testAppendSameFilenameDifferentOriginalURLBothCoexist() {
        // D-01: dedupe key is originalURL only, never filename — two files named the same
        // but sourced from different paths both remain in the shelf.
        var logic = ShelfLogic()
        let first = ShelfItem(id: UUID(), originalURL: URL(fileURLWithPath: "/folderA/report.pdf"),
                               localURL: URL(fileURLWithPath: "/tmp/report-1.pdf"), filename: "report.pdf",
                               addedAt: Date(timeIntervalSinceReferenceDate: 0))
        let second = ShelfItem(id: UUID(), originalURL: URL(fileURLWithPath: "/folderB/report.pdf"),
                                localURL: URL(fileURLWithPath: "/tmp/report-2.pdf"), filename: "report.pdf",
                                addedAt: Date(timeIntervalSinceReferenceDate: 1))
        XCTAssertTrue(logic.append(first))
        XCTAssertTrue(logic.append(second))
        XCTAssertEqual(logic.items, [first, second])
    }

    func testAppendSameOriginalURLDifferentFilenameBothCoexist() {
        // Phase 70 regression — Convert derives multiple DIFFERENT output files (different
        // filename/extension) from the SAME originalURL. originalURL-only dedup rejected
        // every conversion after the first from a given source as a false-positive
        // duplicate; the compound (originalURL, filename) key must let them coexist.
        var logic = ShelfLogic()
        let png = ShelfItem(id: UUID(), originalURL: URL(fileURLWithPath: "/photo.jpg"),
                             localURL: URL(fileURLWithPath: "/tmp/photo.png"), filename: "photo.png",
                             addedAt: Date(timeIntervalSinceReferenceDate: 0))
        let heic = ShelfItem(id: UUID(), originalURL: URL(fileURLWithPath: "/photo.jpg"),
                              localURL: URL(fileURLWithPath: "/tmp/photo.heic"), filename: "photo.heic",
                              addedAt: Date(timeIntervalSinceReferenceDate: 1))
        XCTAssertTrue(logic.append(png))
        XCTAssertTrue(logic.append(heic))
        XCTAssertEqual(logic.items, [png, heic])
    }

    func testAppendSameOriginalURLAndFilenameStillRejectsDuplicate() {
        // The compound key still blocks a genuine re-drop/re-convert-to-the-SAME-format:
        // same originalURL AND same filename is unambiguously the same duplicate D-01/D-02
        // always meant to reject.
        var logic = ShelfLogic()
        let original = ShelfItem(id: UUID(), originalURL: URL(fileURLWithPath: "/photo.jpg"),
                                  localURL: URL(fileURLWithPath: "/tmp/photo.png"), filename: "photo.png",
                                  addedAt: Date(timeIntervalSinceReferenceDate: 0))
        let dupe = ShelfItem(id: UUID(), originalURL: URL(fileURLWithPath: "/photo.jpg"),
                              localURL: URL(fileURLWithPath: "/tmp/photo-copy.png"), filename: "photo.png",
                              addedAt: Date(timeIntervalSinceReferenceDate: 1))
        XCTAssertTrue(logic.append(original))
        XCTAssertFalse(logic.append(dupe))
        XCTAssertEqual(logic.items, [original])
    }

    func testRemoveByIdRemovesAndReturnsItem() {
        var logic = ShelfLogic()
        let a = ShelfItem(id: UUID(), originalURL: URL(fileURLWithPath: "/a.pdf"),
                           localURL: URL(fileURLWithPath: "/tmp/a.pdf"), filename: "a.pdf",
                           addedAt: Date(timeIntervalSinceReferenceDate: 0))
        let b = ShelfItem(id: UUID(), originalURL: URL(fileURLWithPath: "/b.pdf"),
                           localURL: URL(fileURLWithPath: "/tmp/b.pdf"), filename: "b.pdf",
                           addedAt: Date(timeIntervalSinceReferenceDate: 1))
        _ = logic.append(a)
        _ = logic.append(b)

        let removed = logic.remove(id: a.id)
        XCTAssertEqual(removed, a)
        XCTAssertEqual(logic.items, [b])

        // Non-existent id → nil, items unchanged.
        XCTAssertNil(logic.remove(id: a.id))
        XCTAssertEqual(logic.items, [b])
    }

    func testClearEmptiesAndReturnsAllItemsInOrder() {
        var logic = ShelfLogic()
        let a = ShelfItem(id: UUID(), originalURL: URL(fileURLWithPath: "/a.pdf"),
                           localURL: URL(fileURLWithPath: "/tmp/a.pdf"), filename: "a.pdf",
                           addedAt: Date(timeIntervalSinceReferenceDate: 0))
        let b = ShelfItem(id: UUID(), originalURL: URL(fileURLWithPath: "/b.pdf"),
                           localURL: URL(fileURLWithPath: "/tmp/b.pdf"), filename: "b.pdf",
                           addedAt: Date(timeIntervalSinceReferenceDate: 1))
        _ = logic.append(a)
        _ = logic.append(b)

        let removed = logic.clear()
        XCTAssertEqual(removed, [a, b])
        XCTAssertTrue(logic.items.isEmpty)
    }
}
