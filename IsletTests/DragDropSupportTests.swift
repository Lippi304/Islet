import XCTest
import AppKit
@testable import Islet

// Phase 22 / SHELF-01 / SHELF-02 — regression coverage for DragDropSupport.swift's two pure
// functions. Mirrors ShelfLogicTests.swift's fixture-free convention: one test method per
// behavior, no setUp/tearDown, no mocking framework. Uses a fresh, uniquely-named pasteboard
// per test -- never NSPasteboard.general, which would pollute the real system clipboard.
final class DragDropSupportTests: XCTestCase {

    private func freshPasteboard() -> NSPasteboard {
        NSPasteboard(name: NSPasteboard.Name("DragDropSupportTests-\(UUID())"))
    }

    func testFileURLsReturnsSingleFileURL() {
        let pasteboard = freshPasteboard()
        pasteboard.clearContents()
        let url = URL(fileURLWithPath: "/tmp/a.pdf")
        pasteboard.writeObjects([url as NSURL])

        XCTAssertEqual(fileURLs(from: pasteboard), [url])
    }

    func testFileURLsReturnsMultipleFileURLsInWriteOrder() {
        let pasteboard = freshPasteboard()
        pasteboard.clearContents()
        let urls = [
            URL(fileURLWithPath: "/tmp/a.pdf"),
            URL(fileURLWithPath: "/tmp/b.pdf"),
            URL(fileURLWithPath: "/tmp/c.pdf"),
        ]
        pasteboard.writeObjects(urls.map { $0 as NSURL })

        XCTAssertEqual(fileURLs(from: pasteboard), urls)
    }

    func testFileURLsReturnsFolderURLAsSingleItem() {
        // REQUIREMENTS.md Out of Scope, Pitfall 4: a folder URL must be returned as ONE item,
        // never enumerated -- fileURLs(from:) only reads pasteboard metadata, not disk, so the
        // directory need not actually exist.
        let pasteboard = freshPasteboard()
        pasteboard.clearContents()
        let folderURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        pasteboard.writeObjects([folderURL as NSURL])

        XCTAssertEqual(fileURLs(from: pasteboard), [folderURL])
    }

    func testFileURLsReturnsEmptyForNonFilePayload() {
        let pasteboard = freshPasteboard()
        pasteboard.clearContents()
        pasteboard.setString("hello", forType: .string)

        XCTAssertTrue(fileURLs(from: pasteboard).isEmpty)
    }

    func testShouldAcceptDropRejectsWhenExpanded() {
        // D-04: collapsed-only accept gate.
        XCTAssertFalse(shouldAcceptDrop(isExpanded: true, urls: [URL(fileURLWithPath: "/tmp/a.pdf")]))
    }

    func testShouldAcceptDropRejectsEmptyURLs() {
        XCTAssertFalse(shouldAcceptDrop(isExpanded: false, urls: []))
    }

    func testShouldAcceptDropAcceptsCollapsedWithURLs() {
        XCTAssertTrue(shouldAcceptDrop(isExpanded: false, urls: [URL(fileURLWithPath: "/tmp/a.pdf")]))
    }
}
