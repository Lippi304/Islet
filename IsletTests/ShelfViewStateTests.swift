import XCTest
@testable import Islet

// Phase 20 / SHELF-04/05 / SHELF-07 (D-04) — proves the resync contract Plan 20-02's
// NotchWindowController handlers rely on (`viewState.items = coordinator.logic.items`
// called immediately after every ShelfCoordinator mutation) plus the pure
// shouldOpenShelfItem gate. Reuses ShelfCoordinatorTests.swift's exact real-disk-IO
// fixture convention since ShelfCoordinator.append/remove/clear perform real FileManager
// side effects this test must exercise for real, not fabricate.
@MainActor
final class ShelfViewStateTests: XCTestCase {
    private var fixturesDir: URL!

    override func setUp() {
        super.setUp()
        fixturesDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ShelfViewStateTestsFixtures-\(UUID())", isDirectory: true)
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

    func testAppendThenResyncReflectsInViewState() throws {
        let coordinator = ShelfCoordinator()
        let viewState = ShelfViewState()
        let item = try makeRealItem(named: "a.pdf")

        XCTAssertTrue(coordinator.append(item))
        viewState.items = coordinator.logic.items

        XCTAssertEqual(viewState.items, [item])
    }

    func testRemoveThenResyncReflectsInViewState() throws {
        let coordinator = ShelfCoordinator()
        let viewState = ShelfViewState()
        let first = try makeRealItem(named: "b.pdf")
        let second = try makeRealItem(named: "c.pdf")
        XCTAssertTrue(coordinator.append(first))
        XCTAssertTrue(coordinator.append(second))

        coordinator.remove(id: first.id)
        viewState.items = coordinator.logic.items

        XCTAssertEqual(viewState.items, [second])
    }

    func testClearThenResyncReflectsInViewState() throws {
        let coordinator = ShelfCoordinator()
        let viewState = ShelfViewState()
        let first = try makeRealItem(named: "d.pdf")
        let second = try makeRealItem(named: "e.pdf")
        XCTAssertTrue(coordinator.append(first))
        XCTAssertTrue(coordinator.append(second))

        coordinator.clear()
        viewState.items = coordinator.logic.items

        XCTAssertTrue(viewState.items.isEmpty)
    }

    func testShouldOpenShelfItemGate() {
        XCTAssertTrue(shouldOpenShelfItem(fileExists: true))
        XCTAssertFalse(shouldOpenShelfItem(fileExists: false))
    }

    func testShouldBeginShelfItemDragGate() {
        XCTAssertTrue(shouldBeginShelfItemDrag(fileExists: true))
        XCTAssertFalse(shouldBeginShelfItemDrag(fileExists: false))
    }
}
