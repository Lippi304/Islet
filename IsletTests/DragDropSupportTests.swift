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

    // Phase 70 / Task 2 — regression: count: 3 must produce frames numerically identical to
    // the OLD hardcoded-3 function for the same card, hand-computed here.
    func testComputeQuickActionButtonFramesCountThreeMatchesOldHardcodedBehavior() {
        let card = CGRect(x: 0, y: 0, width: 650, height: 117)
        let buttonRowHeight = NotchPillView.quickActionButtonRowHeight
        let gap: CGFloat = 16
        let chipWidth = NotchPillView.quickActionButtonWidth
        let totalContentWidth = 3 * chipWidth + 2 * gap
        let centeringInset = (card.width - totalContentWidth) / 2
        let expectedY = card.maxY - NotchPillView.cameraClearance - buttonRowHeight
        let expected = (0..<3).map { i in
            CGRect(x: card.minX + centeringInset + CGFloat(i) * (chipWidth + gap), y: expectedY,
                   width: chipWidth, height: buttonRowHeight)
        }

        XCTAssertEqual(computeQuickActionButtonFrames(card: card, count: 3), expected)
    }

    // Phase 70 / Task 2 — count: 4 produces exactly 4 frames, each quickActionButtonWidth wide,
    // 16pt apart, centered within card, and mutually non-overlapping.
    func testComputeQuickActionButtonFramesCountFourProducesFourNonOverlappingFrames() {
        let card = CGRect(x: 0, y: 0, width: 650, height: 117)
        let frames = computeQuickActionButtonFrames(card: card, count: 4)

        XCTAssertEqual(frames.count, 4)
        for frame in frames {
            XCTAssertEqual(frame.width, NotchPillView.quickActionButtonWidth)
        }

        let sorted = frames.sorted { $0.minX < $1.minX }
        for i in 0..<(sorted.count - 1) {
            XCTAssertEqual(sorted[i + 1].minX - sorted[i].maxX, 16, accuracy: 0.001)
            XCTAssertLessThanOrEqual(sorted[i].maxX, sorted[i + 1].minX)
        }

        let totalContentWidth = frames.last!.maxX - frames.first!.minX
        let expectedCenteringInset = (card.width - totalContentWidth) / 2
        XCTAssertEqual(frames.first!.minX - card.minX, expectedCenteringInset, accuracy: 0.001)
    }
}
