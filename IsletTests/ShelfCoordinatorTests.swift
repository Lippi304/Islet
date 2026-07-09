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

    func testDoubleRemoveAndClearOnEmptyAreSafeNoOps() throws {
        let coordinator = ShelfCoordinator()
        let item = try makeRealItem(named: "e.pdf")
        XCTAssertTrue(coordinator.append(item))

        XCTAssertNotNil(coordinator.remove(id: item.id))
        XCTAssertNil(coordinator.remove(id: item.id))   // second removal — safe no-op

        XCTAssertTrue(coordinator.clear().isEmpty)      // clear on already-empty shelf — safe no-op
    }
}
