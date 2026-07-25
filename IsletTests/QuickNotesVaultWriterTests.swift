import XCTest
@testable import Islet

// Phase 64 (D-06/D-07) — covers NOTES-02: bounded tail-read decides whether today's
// day heading already exists, append-only FileHandle write never rewrites the whole
// file. Uses the same fixturesDir setUp/tearDown pattern as ClipboardFileStoreTests
// (real disk I/O needs a throwaway root, not a mock).
final class QuickNotesVaultWriterTests: XCTestCase {
    private var fixturesDir: URL!

    override func setUp() {
        super.setUp()
        fixturesDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("QuickNotesVaultWriterTestsFixtures-\(UUID())", isDirectory: true)
        try? FileManager.default.createDirectory(at: fixturesDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: fixturesDir)
        fixturesDir = nil
        super.tearDown()
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        Calendar.current.date(from: DateComponents(
            year: year, month: month, day: day, hour: hour, minute: minute
        ))!
    }

    func testAppendToNonexistentFileCreatesItWithTodayHeadingNoLeadingBlankLine() throws {
        let fileURL = fixturesDir.appendingPathComponent("notes.md")
        let noteDate = date(2026, 7, 25, 14, 32)

        try QuickNotesVaultWriter.append(note: "Erste Notiz.", to: fileURL, at: noteDate)

        let content = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertEqual(content, "## 2026-07-25\n\n- 14:32 Erste Notiz.\n")
    }

    func testTwoAppendsSameDayProduceOneHeadingTwoBullets() throws {
        let fileURL = fixturesDir.appendingPathComponent("notes.md")

        try QuickNotesVaultWriter.append(note: "Erste Notiz.", to: fileURL, at: date(2026, 7, 25, 14, 32))
        try QuickNotesVaultWriter.append(note: "Zweite Notiz.", to: fileURL, at: date(2026, 7, 25, 14, 47))

        let content = try String(contentsOf: fileURL, encoding: .utf8)
        let headingCount = content.components(separatedBy: "## 2026-07-25").count - 1
        let bulletCount = content.split(separator: "\n").filter { $0.hasPrefix("- ") }.count
        XCTAssertEqual(headingCount, 1)
        XCTAssertEqual(bulletCount, 2)
    }

    func testAppendOnNewDayPreservesPriorBytesAndAddsBlankLineNewHeading() throws {
        let fileURL = fixturesDir.appendingPathComponent("notes.md")
        let priorContent = "## 2026-07-24\n\n- 09:00 Yesterday.\n"
        try priorContent.write(to: fileURL, atomically: true, encoding: .utf8)

        try QuickNotesVaultWriter.append(note: "Today.", to: fileURL, at: date(2026, 7, 25, 9, 0))

        let content = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertTrue(content.hasPrefix(priorContent), "Original bytes must survive unchanged as a prefix")
        XCTAssertEqual(
            content,
            priorContent + "\n## 2026-07-25\n\n- 09:00 Today.\n"
        )
    }

    func testAppendToFileNotEndingInNewlineInsertsNewlineNotConcatenated() throws {
        let fileURL = fixturesDir.appendingPathComponent("notes.md")
        // Simulates a hand-edited vault file with no trailing newline (D-07).
        let priorContent = "## 2026-07-25\n\n- 09:00 Existing"
        try priorContent.write(to: fileURL, atomically: true, encoding: .utf8)

        try QuickNotesVaultWriter.append(note: "New.", to: fileURL, at: date(2026, 7, 25, 9, 15))

        let content = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertFalse(content.contains("Existing- 09:15"), "Must never concatenate onto the last existing line")
        XCTAssertEqual(content, priorContent + "\n- 09:15 New.\n")
    }

    func testMultiLineNoteWritesContinuationIndentedByTwoSpaces() throws {
        let fileURL = fixturesDir.appendingPathComponent("notes.md")

        try QuickNotesVaultWriter.append(note: "Line one\nLine two", to: fileURL, at: date(2026, 7, 25, 10, 0))

        let content = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertEqual(content, "## 2026-07-25\n\n- 10:00 Line one\n  Line two\n")
    }

    func testIsValidVaultFolderTrueForExistingDirectory() {
        XCTAssertTrue(QuickNotesVaultWriter.isValidVaultFolder(atPath: fixturesDir.path))
    }

    func testIsValidVaultFolderFalseForNonexistentPath() {
        let missingPath = fixturesDir.appendingPathComponent("does-not-exist").path
        XCTAssertFalse(QuickNotesVaultWriter.isValidVaultFolder(atPath: missingPath))
    }

    func testIsValidVaultFolderFalseForRegularFile() throws {
        let fileURL = fixturesDir.appendingPathComponent("plain-file.txt")
        try Data("not a folder".utf8).write(to: fileURL)

        XCTAssertFalse(QuickNotesVaultWriter.isValidVaultFolder(atPath: fileURL.path))
    }

    // MARK: - removeEntry / listMarkdownFiles (Phase 64-07, gap closure)

    func testRemoveEntryDeletesOnlyMatchingBulletLeavesOthersByteIdentical() throws {
        let fileURL = fixturesDir.appendingPathComponent("notes.md")
        let noteA = QuickNote(id: UUID(), text: "Erste Notiz.", timestamp: date(2026, 7, 25, 14, 32))
        let noteB = QuickNote(id: UUID(), text: "Zweite Notiz.", timestamp: date(2026, 7, 25, 14, 47))
        try QuickNotesVaultWriter.append(note: noteA.text, to: fileURL, at: noteA.timestamp)
        try QuickNotesVaultWriter.append(note: noteB.text, to: fileURL, at: noteB.timestamp)

        let result = try QuickNotesVaultWriter.removeEntry(matching: noteA, from: fileURL)

        XCTAssertEqual(result, .removed)
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertFalse(content.contains("Erste Notiz."))
        XCTAssertTrue(content.contains("## 2026-07-25"))
        XCTAssertTrue(content.contains("- 14:47 Zweite Notiz."))
    }

    func testRemoveEntryRemovesMultiLineContinuationLines() throws {
        let fileURL = fixturesDir.appendingPathComponent("notes.md")
        let multiLine = QuickNote(id: UUID(), text: "Line one\nLine two", timestamp: date(2026, 7, 25, 10, 0))
        let after = QuickNote(id: UUID(), text: "After note.", timestamp: date(2026, 7, 25, 10, 5))
        try QuickNotesVaultWriter.append(note: multiLine.text, to: fileURL, at: multiLine.timestamp)
        try QuickNotesVaultWriter.append(note: after.text, to: fileURL, at: after.timestamp)

        let result = try QuickNotesVaultWriter.removeEntry(matching: multiLine, from: fileURL)

        XCTAssertEqual(result, .removed)
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertFalse(content.contains("Line one"))
        XCTAssertFalse(content.contains("Line two"))
        XCTAssertTrue(content.contains("- 10:05 After note."))
    }

    func testRemoveEntryReturnsNotFoundWhenLineAlreadyGone() throws {
        let fileURL = fixturesDir.appendingPathComponent("notes.md")
        let note = QuickNote(id: UUID(), text: "Erste Notiz.", timestamp: date(2026, 7, 25, 14, 32))
        try QuickNotesVaultWriter.append(note: note.text, to: fileURL, at: note.timestamp)
        let beforeBytes = try Data(contentsOf: fileURL)

        let alreadyGone = QuickNote(id: UUID(), text: "Never written.", timestamp: date(2026, 7, 25, 15, 0))
        let result = try QuickNotesVaultWriter.removeEntry(matching: alreadyGone, from: fileURL)

        XCTAssertEqual(result, .notFound)
        let afterBytes = try Data(contentsOf: fileURL)
        XCTAssertEqual(beforeBytes, afterBytes)
    }

    func testRemoveEntryReturnsNotFoundForNonexistentFileWithoutCreatingIt() throws {
        let fileURL = fixturesDir.appendingPathComponent("does-not-exist.md")
        let note = QuickNote(id: UUID(), text: "Some note.", timestamp: date(2026, 7, 25, 12, 0))

        let result = try QuickNotesVaultWriter.removeEntry(matching: note, from: fileURL)

        XCTAssertEqual(result, .notFound)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testRemoveEntryTargetsRequestedOccurrenceAmongDuplicates() throws {
        let fileURL = fixturesDir.appendingPathComponent("notes.md")
        let noteDate = date(2026, 7, 25, 14, 32)
        let duplicateText = "Same note."
        // Two byte-identical entries (same text, same to-the-minute timestamp).
        try QuickNotesVaultWriter.append(note: duplicateText, to: fileURL, at: noteDate)
        try QuickNotesVaultWriter.append(note: duplicateText, to: fileURL, at: noteDate)
        let noteFixture = QuickNote(id: UUID(), text: duplicateText, timestamp: noteDate)

        let result = try QuickNotesVaultWriter.removeEntry(matching: noteFixture, occurrence: 1, from: fileURL)

        XCTAssertEqual(result, .removed)
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        let bulletCount = content.components(separatedBy: "- 14:32 Same note.").count - 1
        XCTAssertEqual(bulletCount, 1, "Exactly one of the two duplicate bullets must remain")
    }

    func testListMarkdownFilesReturnsOnlyMdFilesSorted() throws {
        try Data("a".utf8).write(to: fixturesDir.appendingPathComponent("Zebra.md"))
        try Data("b".utf8).write(to: fixturesDir.appendingPathComponent("Apple.md"))
        try Data("c".utf8).write(to: fixturesDir.appendingPathComponent("notes.txt"))

        let result = QuickNotesVaultWriter.listMarkdownFiles(inFolder: fixturesDir.path)

        XCTAssertEqual(result, ["Apple.md", "Zebra.md"])
    }

    func testListMarkdownFilesReturnsEmptyForMissingFolder() {
        let missingPath = fixturesDir.appendingPathComponent("does-not-exist").path

        let result = QuickNotesVaultWriter.listMarkdownFiles(inFolder: missingPath)

        XCTAssertEqual(result, [])
    }
}
