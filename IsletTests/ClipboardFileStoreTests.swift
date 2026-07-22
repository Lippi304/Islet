import XCTest
@testable import Islet
import CryptoKit

// Phase 56 — covers CLIP-04 (SC#1 round-trip) and PRIV-02 (SC#2 plaintext-absence,
// SC#3 delete-path hardening) plus D-04/D-06. Uses the same fixturesDir setUp/
// tearDown deviation as ShelfFileStoreTests (real disk I/O needs a throwaway root).
final class ClipboardFileStoreTests: XCTestCase {
    private var fixturesDir: URL!

    override func setUp() {
        super.setUp()
        fixturesDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ClipboardFileStoreTestsFixtures-\(UUID())", isDirectory: true)
        try? FileManager.default.createDirectory(at: fixturesDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: fixturesDir)
        fixturesDir = nil
        super.tearDown()
    }

    func testSaveThenLoadRoundTripsTextAndImageItems() throws {
        let testKey = SymmetricKey(size: .bits256)
        let textItem = ClipboardItem(id: UUID(), kind: .text("hello clipboard"), timestamp: Date())
        let imageItem = ClipboardItem(id: UUID(), kind: .image(Data("fake image bytes".utf8)), timestamp: Date())

        try ClipboardFileStore.save([textItem, imageItem], root: fixturesDir, key: testKey)
        let loaded = ClipboardFileStore.load(root: fixturesDir, key: testKey)

        XCTAssertEqual(loaded, [textItem, imageItem])
    }

    func testEncryptedFilesContainNoReadablePlaintext() throws {
        let testKey = SymmetricKey(size: .bits256)
        let secretText = "very secret clipboard text"
        let secretImageBytes = Data("very secret image bytes".utf8)
        let textItem = ClipboardItem(id: UUID(), kind: .text(secretText), timestamp: Date())
        let imageItem = ClipboardItem(id: UUID(), kind: .image(secretImageBytes), timestamp: Date())

        try ClipboardFileStore.save([textItem, imageItem], root: fixturesDir, key: testKey)

        let indexData = try Data(contentsOf: fixturesDir.appendingPathComponent("index.json.enc"))
        XCTAssertNil(indexData.range(of: Data(secretText.utf8)))

        let imageFileURL = fixturesDir
            .appendingPathComponent("images")
            .appendingPathComponent(imageItem.id.uuidString + ".enc")
        let imageFileData = try Data(contentsOf: imageFileURL)
        XCTAssertNil(imageFileData.range(of: secretImageBytes))
    }

    func testLoadReturnsEmptyArrayOnCorruptedIndex() throws {
        let testKey = SymmetricKey(size: .bits256)
        try FileManager.default.createDirectory(at: fixturesDir, withIntermediateDirectories: true)
        try Data("not encrypted".utf8).write(to: fixturesDir.appendingPathComponent("index.json.enc"))

        let loaded = ClipboardFileStore.load(root: fixturesDir, key: testKey)

        XCTAssertEqual(loaded, [])
    }

    func testLoadReturnsEmptyArrayWithWrongKey() throws {
        let savingKey = SymmetricKey(size: .bits256)
        let wrongKey = SymmetricKey(size: .bits256)
        let textItem = ClipboardItem(id: UUID(), kind: .text("hello"), timestamp: Date())

        try ClipboardFileStore.save([textItem], root: fixturesDir, key: savingKey)
        let loaded = ClipboardFileStore.load(root: fixturesDir, key: wrongKey)

        XCTAssertEqual(loaded, [])
    }

    func testSaveDeletesOrphanedImageFileButKeepsStillReferencedFile() throws {
        let testKey = SymmetricKey(size: .bits256)
        let imageItemA = ClipboardItem(id: UUID(), kind: .image(Data("image A bytes".utf8)), timestamp: Date())
        let imageItemB = ClipboardItem(id: UUID(), kind: .image(Data("image B bytes".utf8)), timestamp: Date())

        try ClipboardFileStore.save([imageItemA, imageItemB], root: fixturesDir, key: testKey)
        let imagesDir = fixturesDir.appendingPathComponent("images")
        let fileA = imagesDir.appendingPathComponent(imageItemA.id.uuidString + ".enc")
        let fileB = imagesDir.appendingPathComponent(imageItemB.id.uuidString + ".enc")
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileA.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileB.path))
        let fileAContentsBefore = try Data(contentsOf: fileA)

        try ClipboardFileStore.save([imageItemA], root: fixturesDir, key: testKey)

        XCTAssertTrue(FileManager.default.fileExists(atPath: fileA.path))
        XCTAssertEqual(try Data(contentsOf: fileA), fileAContentsBefore)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileB.path))
    }

    func testDeleteOrphanedImageFileOutsideStorageRootIsSafeNoOp() throws {
        let outsideFile = fixturesDir.appendingPathComponent("outside-root.enc")
        try Data("do not delete me".utf8).write(to: outsideFile)
        let storageRoot = fixturesDir.appendingPathComponent("IsletClipboardRoot", isDirectory: true)
        try FileManager.default.createDirectory(at: storageRoot, withIntermediateDirectories: true)

        ClipboardFileStore.deleteOrphanedImageFile(at: outsideFile, root: storageRoot)

        XCTAssertTrue(FileManager.default.fileExists(atPath: outsideFile.path))
        XCTAssertEqual(try Data(contentsOf: outsideFile), Data("do not delete me".utf8))
    }
}
