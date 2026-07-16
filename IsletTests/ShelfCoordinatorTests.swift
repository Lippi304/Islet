import XCTest
@testable import Islet

// Phase 19 / SHELF-08 (D-05) — real-disk-I/O proof that ShelfCoordinator.remove/clear
// actually delete a removed item's session-temp file, not merely that a hook exists.
// Mirrors ShelfFileStoreTests.swift's real-disk-I/O fixture convention (setUp/tearDown
// creating/removing a throwaway source directory), since this also exercises real disk
// state — NOT ShelfLogicTests.swift's fixture-free convention, which only fits pure
// in-memory logic.
@MainActor
final class ShelfCoordinatorTests: XCTestCase {
    private var fixturesDir: URL!

    override func setUp() {
        super.setUp()
        fixturesDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ShelfCoordinatorTestsFixtures-\(UUID())", isDirectory: true)
        try? FileManager.default.createDirectory(at: fixturesDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: fixturesDir)
        fixturesDir = nil
        super.tearDown()
    }

    private func makeRealItem(named name: String) throws -> ShelfItem {
        let source = fixturesDir.appendingPathComponent(name)
        try Data("bytes-\(name)".utf8).write(to: source)
        let id = UUID()
        let localURL = try ShelfFileStore.makeSessionCopy(of: source, id: id)
        return ShelfItem(id: id, originalURL: source, localURL: localURL, filename: name, addedAt: Date())
    }

    func testRemoveDeletesSessionTempFileFromDisk() throws {
        let coordinator = ShelfCoordinator()
        let item = try makeRealItem(named: "a.pdf")
        XCTAssertTrue(coordinator.append(item))
        XCTAssertTrue(FileManager.default.fileExists(atPath: item.localURL.path))

        let removed = coordinator.remove(id: item.id)

        XCTAssertEqual(removed, item)
        XCTAssertFalse(FileManager.default.fileExists(atPath: item.localURL.path))
    }

    func testRemoveNonExistentIdReturnsNilAndDoesNotCrash() throws {
        let coordinator = ShelfCoordinator()
        let item = try makeRealItem(named: "b.pdf")
        XCTAssertTrue(coordinator.append(item))

        let result = coordinator.remove(id: UUID())   // never existed

        XCTAssertNil(result)
        XCTAssertTrue(FileManager.default.fileExists(atPath: item.localURL.path))   // untouched
    }

    func testClearDeletesBothSessionTempFilesFromDisk() throws {
        let coordinator = ShelfCoordinator()
        let first = try makeRealItem(named: "c.pdf")
        let second = try makeRealItem(named: "d.pdf")
        XCTAssertTrue(coordinator.append(first))
        XCTAssertTrue(coordinator.append(second))

        let removed = coordinator.clear()

        XCTAssertEqual(removed, [first, second])
        XCTAssertFalse(FileManager.default.fileExists(atPath: first.localURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: second.localURL.path))
    }

    func testRejectedDuplicateAppendCleansUpItsOrphanedSessionCopy() throws {
        // WR-01: ShelfLogic.append rejects a duplicate originalURL (D-01/D-02) but the
        // caller had already made a real session-temp copy via makeSessionCopy before
        // calling append. That copy must not be left orphaned on disk.
        let coordinator = ShelfCoordinator()
        let first = try makeRealItem(named: "dup.pdf")
        XCTAssertTrue(coordinator.append(first))

        let source = first.originalURL
        let duplicateLocalURL = try ShelfFileStore.makeSessionCopy(of: source, id: UUID())
        let duplicate = ShelfItem(id: UUID(), originalURL: source, localURL: duplicateLocalURL, filename: "dup.pdf", addedAt: Date())

        XCTAssertFalse(coordinator.append(duplicate))
        XCTAssertFalse(FileManager.default.fileExists(atPath: duplicateLocalURL.path))
        // The original, successfully-appended item's copy is untouched.
        XCTAssertTrue(FileManager.default.fileExists(atPath: first.localURL.path))
    }

    func testDoubleRemoveAndClearOnEmptyAreSafeNoOps() throws {
        let coordinator = ShelfCoordinator()
        let item = try makeRealItem(named: "e.pdf")
        XCTAssertTrue(coordinator.append(item))

        XCTAssertNotNil(coordinator.remove(id: item.id))
        XCTAssertNil(coordinator.remove(id: item.id))   // second removal — safe no-op

        XCTAssertTrue(coordinator.clear().isEmpty)      // clear on already-empty shelf — safe no-op
    }

    func testPruneMissingFilesRemovesOnlyItemsWithDeletedBackingFile() throws {
        let coordinator = ShelfCoordinator()
        let present = try makeRealItem(named: "f.pdf")
        let missing = try makeRealItem(named: "g.pdf")
        XCTAssertTrue(coordinator.append(present))
        XCTAssertTrue(coordinator.append(missing))
        try FileManager.default.removeItem(at: missing.localURL)   // simulate external deletion

        let pruned = coordinator.pruneMissingFiles()

        XCTAssertEqual(pruned, [missing])
        XCTAssertEqual(coordinator.logic.items, [present])
    }

    func testPruneMissingFilesOnFullyIntactShelfIsANoOp() throws {
        let coordinator = ShelfCoordinator()
        let item = try makeRealItem(named: "h.pdf")
        XCTAssertTrue(coordinator.append(item))

        XCTAssertTrue(coordinator.pruneMissingFiles().isEmpty)
        XCTAssertEqual(coordinator.logic.items, [item])
    }

    // MARK: sessionFilesSaved / resetSession() — Phase 37 / HUD-07 (D-02/D-03)

    func testAppendingNewItemIncrementsSessionFilesSaved() throws {
        let coordinator = ShelfCoordinator()
        let item = try makeRealItem(named: "i.pdf")

        XCTAssertTrue(coordinator.append(item))

        XCTAssertEqual(coordinator.sessionFilesSaved, 1)
    }

    func testAppendingRejectedDuplicateDoesNotIncrementSessionFilesSaved() throws {
        let coordinator = ShelfCoordinator()
        let first = try makeRealItem(named: "j.pdf")
        XCTAssertTrue(coordinator.append(first))

        let source = first.originalURL
        let duplicateLocalURL = try ShelfFileStore.makeSessionCopy(of: source, id: UUID())
        let duplicate = ShelfItem(id: UUID(), originalURL: source, localURL: duplicateLocalURL, filename: "j.pdf", addedAt: Date())

        XCTAssertFalse(coordinator.append(duplicate))
        XCTAssertEqual(coordinator.sessionFilesSaved, 1)
    }

    func testRemoveDoesNotDecrementSessionFilesSaved() throws {
        let coordinator = ShelfCoordinator()
        let item = try makeRealItem(named: "k.pdf")
        XCTAssertTrue(coordinator.append(item))

        coordinator.remove(id: item.id)

        XCTAssertEqual(coordinator.sessionFilesSaved, 1)
    }

    func testClearDoesNotResetSessionFilesSaved() throws {
        let coordinator = ShelfCoordinator()
        let first = try makeRealItem(named: "l.pdf")
        let second = try makeRealItem(named: "m.pdf")
        XCTAssertTrue(coordinator.append(first))
        XCTAssertTrue(coordinator.append(second))

        coordinator.clear()

        XCTAssertEqual(coordinator.sessionFilesSaved, 2)
    }

    func testResetSessionReturnsCountAndZeroesItAtomically() throws {
        let coordinator = ShelfCoordinator()
        let first = try makeRealItem(named: "n.pdf")
        let second = try makeRealItem(named: "o.pdf")
        XCTAssertTrue(coordinator.append(first))
        XCTAssertTrue(coordinator.append(second))

        let claimed = coordinator.resetSession()

        XCTAssertEqual(claimed, 2)
        XCTAssertEqual(coordinator.sessionFilesSaved, 0)
        XCTAssertEqual(coordinator.resetSession(), 0)
    }
}
