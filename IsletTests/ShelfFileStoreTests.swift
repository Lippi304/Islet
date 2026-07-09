import XCTest
@testable import Islet

// Phase 19 / SHELF-08 (D-03/D-04/D-05) — real-disk-I/O coverage for ShelfFileStore's
// makeSessionCopy/deleteSessionCopy. Unlike ShelfLogicTests.swift's fixture-free
// convention, this file uses setUp()/tearDown() to create/remove a throwaway source-file
// test directory — an intentional deviation from the fixture-free convention, since this
// is the one file in the phase that exercises real disk I/O and needs a stable place to
// seed source files.
final class ShelfFileStoreTests: XCTestCase {
    private var fixturesDir: URL!

    override func setUp() {
        super.setUp()
        fixturesDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ShelfFileStoreTestsFixtures-\(UUID())", isDirectory: true)
        try? FileManager.default.createDirectory(at: fixturesDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: fixturesDir)
        fixturesDir = nil
        super.tearDown()
    }

    func testMakeSessionCopyMatchesSourceContents() throws {
        let source = fixturesDir.appendingPathComponent("a.pdf")
        let contents = Data("hello shelf".utf8)
        try contents.write(to: source)

        let id = UUID()
        let localURL = try ShelfFileStore.makeSessionCopy(of: source, id: id)

        XCTAssertNotEqual(localURL, source)
        XCTAssertTrue(FileManager.default.fileExists(atPath: localURL.path))
        XCTAssertEqual(try Data(contentsOf: localURL), contents)
    }

    func testMakeSessionCopyLeavesSourceUntouched() throws {
        // D-04: the original source file is never written to, moved, or deleted.
        let source = fixturesDir.appendingPathComponent("b.pdf")
        let contents = Data("original bytes".utf8)
        try contents.write(to: source)

        _ = try ShelfFileStore.makeSessionCopy(of: source, id: UUID())

        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
        XCTAssertEqual(try Data(contentsOf: source), contents)
    }

    func testDeleteSessionCopyRemovesFileFromDisk() throws {
        let source = fixturesDir.appendingPathComponent("c.pdf")
        try Data("bytes".utf8).write(to: source)

        let localURL = try ShelfFileStore.makeSessionCopy(of: source, id: UUID())
        XCTAssertTrue(FileManager.default.fileExists(atPath: localURL.path))

        ShelfFileStore.deleteSessionCopy(at: localURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: localURL.path))
    }

    func testDeleteSessionCopyIsIdempotent() throws {
        // D-05: calling deleteSessionCopy a second time on an already-deleted localURL
        // does not throw and does not crash.
        let source = fixturesDir.appendingPathComponent("d.pdf")
        try Data("bytes".utf8).write(to: source)

        let localURL = try ShelfFileStore.makeSessionCopy(of: source, id: UUID())
        ShelfFileStore.deleteSessionCopy(at: localURL)
        ShelfFileStore.deleteSessionCopy(at: localURL)   // second call — no crash

        XCTAssertFalse(FileManager.default.fileExists(atPath: localURL.path))
    }

    func testMakeSessionCopyRejectsPathTraversalFilename() {
        // T-19-01: a sourceURL whose lastPathComponent is ".." or "." must be rejected
        // BEFORE any file I/O is attempted.
        let traversalSource = fixturesDir.appendingPathComponent("..")
        XCTAssertThrowsError(try ShelfFileStore.makeSessionCopy(of: traversalSource, id: UUID())) { error in
            XCTAssertEqual(error as? ShelfFileStoreError, .invalidFilename)
        }

        let dotSource = fixturesDir.appendingPathComponent(".")
        XCTAssertThrowsError(try ShelfFileStore.makeSessionCopy(of: dotSource, id: UUID())) { error in
            XCTAssertEqual(error as? ShelfFileStoreError, .invalidFilename)
        }
    }
}
