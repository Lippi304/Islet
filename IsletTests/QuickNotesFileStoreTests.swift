import XCTest
@testable import Islet

// Phase 64 (D-18) — covers the round-trip and corrupted-input load-never-throws
// discipline. Uses the same fixturesDir setUp/tearDown pattern as
// ClipboardFileStoreTests, minus the encryption-specific assertions (no key
// exists) and minus the orphaned-image-file tests (QuickNote has no image branch).
final class QuickNotesFileStoreTests: XCTestCase {
    private var fixturesDir: URL!

    override func setUp() {
        super.setUp()
        fixturesDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("QuickNotesFileStoreTestsFixtures-\(UUID())", isDirectory: true)
        try? FileManager.default.createDirectory(at: fixturesDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: fixturesDir)
        fixturesDir = nil
        super.tearDown()
    }

    func testSaveThenLoadRoundTripsNotes() throws {
        let noteA = QuickNote(id: UUID(), text: "erste Notiz", timestamp: Date())
        let noteB = QuickNote(
            id: UUID(), text: "zweite Notiz\nmit zweiter Zeile", timestamp: Date(),
            fileName: "Work.md"
        )

        try QuickNotesFileStore.save([noteA, noteB], root: fixturesDir)
        let loaded = QuickNotesFileStore.load(root: fixturesDir)

        XCTAssertEqual(loaded, [noteA, noteB])
        XCTAssertEqual(loaded.last?.fileName, "Work.md")
    }

    // Phase 64-07 (gap closure) — a pre-existing index.json written before fileName
    // existed must still decode, defaulting to ActivitySettings.quickNotesDefaultFileName,
    // instead of being silently dropped by load()'s "any decode failure returns []" guard.
    func testLoadDecodesOldJSONMissingFileNameAsDefault() throws {
        let id = UUID()
        let timestamp = Date()
        let oldJSON = """
        [
            {
                "id": "\(id.uuidString)",
                "text": "alte Notiz",
                "timestamp": \(timestamp.timeIntervalSinceReferenceDate)
            }
        ]
        """
        try Data(oldJSON.utf8).write(to: fixturesDir.appendingPathComponent("index.json"))

        let loaded = QuickNotesFileStore.load(root: fixturesDir)

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.fileName, ActivitySettings.quickNotesDefaultFileName)
    }

    func testLoadReturnsEmptyArrayOnMissingIndex() {
        let loaded = QuickNotesFileStore.load(root: fixturesDir)
        XCTAssertEqual(loaded, [])
    }

    func testLoadReturnsEmptyArrayOnCorruptedIndex() throws {
        try Data("not json".utf8).write(to: fixturesDir.appendingPathComponent("index.json"))

        let loaded = QuickNotesFileStore.load(root: fixturesDir)

        XCTAssertEqual(loaded, [])
    }
}
