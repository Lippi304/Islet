import XCTest
import AppKit
import ImageIO
import UniformTypeIdentifiers
@testable import Islet

// Phase 70 / D-02, D-05 — real-fixture coverage for ImageConversionService's convert/
// isImageFile. Mirrors ShelfFileStoreTests.swift's setUp/tearDown fixtures-dir convention
// (this is the phase's one file exercising real ImageIO/disk I/O), not
// QuickActionSharingServiceTests.swift's fake-injection convention (70-RESEARCH.md Pattern 1
// — conversion is synchronous/local/no-OS-UI and needs no mock seam).
final class ImageConversionServiceTests: XCTestCase {
    private var fixturesDir: URL!

    override func setUp() {
        super.setUp()
        fixturesDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ImageConversionServiceTestsFixtures-\(UUID())", isDirectory: true)
        try? FileManager.default.createDirectory(at: fixturesDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: fixturesDir)
        fixturesDir = nil
        super.tearDown()
    }

    // Builds a tiny real PNG fixture at `url` via NSBitmapImageRep — test-time-only fixture
    // generation, not the production conversion path (ImageConversionService.swift itself
    // never uses NSBitmapImageRep, see Pitfall 1).
    private func makeFixturePNG(at url: URL) throws {
        let size = CGSize(width: 4, height: 4)
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else {
            XCTFail("could not create fixture bitmap rep")
            return
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor.red.setFill()
        NSRect(origin: .zero, size: size).fill()
        NSGraphicsContext.restoreGraphicsState()

        guard let data = rep.representation(using: .png, properties: [:]) else {
            XCTFail("could not encode fixture PNG")
            return
        }
        try data.write(to: url)
    }

    // Test 1 + 2: convert(_:to:destinationURL:) on a real fixture, for all 4 ImageFormat
    // cases, produces a destination file whose own re-read UTI conforms to the target format
    // — proves a REAL ImageIO re-encode, not a byte copy with a lied-about extension
    // (70-RESEARCH.md Pitfall 1 and Pitfall 2).
    func testConvertsSourceToEachFormatProducesRealReencode() throws {
        let source = fixturesDir.appendingPathComponent("source.png")
        try makeFixturePNG(at: source)

        for format in ImageFormat.allCases {
            let destination = fixturesDir.appendingPathComponent("converted.\(format.fileExtension)")

            try ImageConversionService.convert(source, to: format, destinationURL: destination)

            XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path), "\(format) did not write a file")

            guard let readSource = CGImageSourceCreateWithURL(destination as CFURL, nil),
                  let typeIdentifier = CGImageSourceGetType(readSource) else {
                XCTFail("\(format): could not re-read converted file")
                continue
            }
            let readType = UTType(typeIdentifier as String)
            XCTAssertTrue(readType?.conforms(to: format.utType) ?? false,
                           "\(format): expected UTI conforming to \(format.utType.identifier), got \(typeIdentifier)")
        }
    }

    // Test 3: a non-existent sourceURL throws .sourceUnreadable, never crashes.
    func testConvertThrowsSourceUnreadableForMissingSource() {
        let missingSource = fixturesDir.appendingPathComponent("does-not-exist.png")
        let destination = fixturesDir.appendingPathComponent("out.jpg")

        XCTAssertThrowsError(try ImageConversionService.convert(missingSource, to: .jpg, destinationURL: destination)) { error in
            guard case ImageConversionError.sourceUnreadable = error else {
                XCTFail("expected .sourceUnreadable, got \(error)")
                return
            }
        }
    }

    // Test 4: isImageFile(_:) is content-type-based, not extension-based (D-05's foundation).
    func testIsImageFileDetection() throws {
        let imageFile = fixturesDir.appendingPathComponent("photo.png")
        try makeFixturePNG(at: imageFile)
        XCTAssertTrue(ImageConversionService.isImageFile(imageFile))

        let textFile = fixturesDir.appendingPathComponent("notes.txt")
        try Data("plain text, not an image".utf8).write(to: textFile)
        XCTAssertFalse(ImageConversionService.isImageFile(textFile))

        let extensionlessImage = fixturesDir.appendingPathComponent("extensionless-image")
        try makeFixturePNG(at: extensionlessImage)
        XCTAssertTrue(ImageConversionService.isImageFile(extensionlessImage))
    }
}
