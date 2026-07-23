import XCTest
@testable import Islet

// Phase 61 / DL-01/DL-02 — pure DownloadActivity/DownloadReading/D-08/D-12 helper tests.
// Mirrors DeviceActivityTests' plain XCTAssert style, no shared fixture/setUp.
final class DownloadActivityTests: XCTestCase {

    func testIsDownloadTempFileDetectsCrdownload() {
        XCTAssertTrue(isDownloadTempFile(path: "/Users/x/Downloads/movie.crdownload"))
    }

    func testIsDownloadTempFileDetectsPart() {
        XCTAssertTrue(isDownloadTempFile(path: "/Users/x/Downloads/movie.part"))
    }

    func testIsDownloadTempFileDetectsDownload() {
        XCTAssertTrue(isDownloadTempFile(path: "/Users/x/Downloads/MyFile.download"))
    }

    func testIsDownloadTempFileNegativeForOtherSuffix() {
        // D-08 negative — no other suffix matches.
        XCTAssertFalse(isDownloadTempFile(path: "/Users/x/Downloads/invoice.pdf"))
    }

    func testDownloadFilenameExtractsLastPathComponent() {
        XCTAssertEqual(downloadFilename(fromPath: "/Users/x/Downloads/invoice.pdf"), "invoice.pdf")
    }

    func testDownloadFilenameNoSpecialCasingOfSpacesOrParens() {
        XCTAssertEqual(downloadFilename(fromPath: "/Users/x/Downloads/a b (1).zip"), "a b (1).zip")
    }

    func testDownloadActivityEquatableDistinctCases() {
        XCTAssertNotEqual(DownloadActivity.inProgress, DownloadActivity.done(filename: "x.pdf"))
    }

    func testDownloadReadingConstructsAndComparesByHand() {
        let a = DownloadReading(path: "p", kind: .renamed, fileID: 1, renamedTo: "q")
        let b = DownloadReading(path: "p", kind: .renamed, fileID: 1, renamedTo: "q")
        XCTAssertEqual(a, b)
    }
}
