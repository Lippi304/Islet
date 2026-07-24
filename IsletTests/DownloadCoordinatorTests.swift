import XCTest
@testable import Islet

// Phase 61 / DL-01 + DL-02 — regression coverage for DownloadCoordinator's D-08/D-05/D-06/D-15
// correlation algorithm, one test method per behavior-block scenario. Mirrors
// DeviceCoordinatorTests.swift's "no fakes, wire a real `var q = TransientQueue()`, count
// closure calls with local `var ...Count = 0` variables" convention.
@MainActor
final class DownloadCoordinatorTests: XCTestCase {

    func testCreatedMatchingTempPathTracksAndEnqueuesInProgress() {
        var q = TransientQueue()
        var enqueueCount = 0
        var presentCount = 0
        let coordinator = DownloadCoordinator(
            queueHead: { q.head },
            enqueue: { t in enqueueCount += 1; return q.enqueue(t) },
            replaceHead: { q.updateHead($0) },
            removeInProgress: {},
            presentTransientChange: { presentCount += 1 }
        )
        let reading = DownloadReading(path: "/Downloads/movie.crdownload", kind: .created, fileID: 1, renamedTo: nil)
        coordinator.handle(reading, now: Date())
        XCTAssertEqual(enqueueCount, 1)
        XCTAssertEqual(presentCount, 1)
    }

    func testCreatedNonMatchingPathIsIgnored() {
        var q = TransientQueue()
        var enqueueCount = 0
        let coordinator = DownloadCoordinator(
            queueHead: { q.head },
            enqueue: { t in enqueueCount += 1; return q.enqueue(t) },
            replaceHead: { q.updateHead($0) },
            removeInProgress: {},
            presentTransientChange: {}
        )
        let reading = DownloadReading(path: "/Downloads/notes.txt", kind: .created, fileID: 2, renamedTo: nil)
        coordinator.handle(reading, now: Date())
        XCTAssertEqual(enqueueCount, 0)
    }

    func testTwoCreatedDifferentPathsBothTrackedSecondEnqueueDedupsNoOp() {
        var q = TransientQueue()
        var enqueueCount = 0
        let coordinator = DownloadCoordinator(
            queueHead: { q.head },
            enqueue: { t in enqueueCount += 1; return q.enqueue(t) },
            replaceHead: { q.updateHead($0) },
            removeInProgress: {},
            presentTransientChange: {}
        )
        coordinator.handle(DownloadReading(path: "/Downloads/A.crdownload", kind: .created, fileID: 1, renamedTo: nil), now: Date())
        coordinator.handle(DownloadReading(path: "/Downloads/B.crdownload", kind: .created, fileID: 2, renamedTo: nil), now: Date())
        // TransientQueue's own equality dedup collapses the second attempt into a no-op
        // re-enqueue (same head, no pending growth) — not a coordinator-level special case.
        XCTAssertEqual(enqueueCount, 2)
        XCTAssertEqual(q.head, .downloadProgress(.inProgress))
        XCTAssertEqual(q.pendingCount, 0)
    }

    func testRenamedUntrackedPathCallsNeitherEnqueueNorReplaceHead() {
        var q = TransientQueue()
        var enqueueCount = 0
        var replaceHeadCount = 0
        let coordinator = DownloadCoordinator(
            queueHead: { q.head },
            enqueue: { t in enqueueCount += 1; return q.enqueue(t) },
            replaceHead: { t in replaceHeadCount += 1; q.updateHead(t) },
            removeInProgress: {},
            presentTransientChange: {}
        )
        let reading = DownloadReading(path: "/Downloads/movie.crdownload", kind: .renamed, fileID: 1, renamedTo: "/Downloads/movie.mp4")
        coordinator.handle(reading, now: Date())
        XCTAssertEqual(enqueueCount, 0)
        XCTAssertEqual(replaceHeadCount, 0)
    }

    func testSingleTrackedDownloadRenamedReplacesHeadInPlace() {
        var q = TransientQueue()
        var enqueueCount = 0
        var replaceHeadCount = 0
        let coordinator = DownloadCoordinator(
            queueHead: { q.head },
            enqueue: { t in enqueueCount += 1; return q.enqueue(t) },
            replaceHead: { t in replaceHeadCount += 1; q.updateHead(t) },
            removeInProgress: {},
            presentTransientChange: {}
        )
        coordinator.handle(DownloadReading(path: "/Downloads/movie.crdownload", kind: .created, fileID: 1, renamedTo: nil), now: Date())
        enqueueCount = 0   // reset after setup — only the rename's own effect is under test

        coordinator.handle(DownloadReading(path: "/Downloads/movie.crdownload", kind: .renamed, fileID: 1, renamedTo: "/Downloads/movie.mp4"), now: Date())
        XCTAssertEqual(enqueueCount, 0)
        XCTAssertEqual(replaceHeadCount, 1)
        XCTAssertEqual(q.head, .downloadProgress(.done(filename: "movie.mp4")))
    }

    func testTwoTrackedDownloadsFirstRenameEnqueuesSecondRenameReplacesHead() {
        var q = TransientQueue()
        var enqueueCount = 0
        var replaceHeadCount = 0
        let coordinator = DownloadCoordinator(
            queueHead: { q.head },
            enqueue: { t in enqueueCount += 1; return q.enqueue(t) },
            replaceHead: { t in replaceHeadCount += 1; q.updateHead(t) },
            removeInProgress: {},
            presentTransientChange: {}
        )
        coordinator.handle(DownloadReading(path: "/Downloads/A.pdf.crdownload", kind: .created, fileID: 1, renamedTo: nil), now: Date())
        coordinator.handle(DownloadReading(path: "/Downloads/B.pdf.crdownload", kind: .created, fileID: 2, renamedTo: nil), now: Date())
        enqueueCount = 0
        replaceHeadCount = 0

        // A finishes first while B is still in flight — must enqueue behind the standing
        // .inProgress head, not replace it in place.
        coordinator.handle(DownloadReading(path: "/Downloads/A.pdf.crdownload", kind: .renamed, fileID: 1, renamedTo: "/Downloads/A.pdf"), now: Date())
        XCTAssertEqual(enqueueCount, 1)
        XCTAssertEqual(replaceHeadCount, 0)
        XCTAssertEqual(q.head, .downloadProgress(.inProgress))

        // B finishes — now the last download in flight — must replace the head in place.
        coordinator.handle(DownloadReading(path: "/Downloads/B.pdf.crdownload", kind: .renamed, fileID: 2, renamedTo: "/Downloads/B.pdf"), now: Date())
        XCTAssertEqual(replaceHeadCount, 1)
        XCTAssertEqual(q.head, .downloadProgress(.done(filename: "B.pdf")))
    }

    func testRemovedTrackedPathSilentlyDropsNoEnqueueOrReplaceHeadCalls() {
        var q = TransientQueue()
        var enqueueCount = 0
        var replaceHeadCount = 0
        var removeInProgressCount = 0
        let coordinator = DownloadCoordinator(
            queueHead: { q.head },
            enqueue: { t in enqueueCount += 1; return q.enqueue(t) },
            replaceHead: { t in replaceHeadCount += 1; q.updateHead(t) },
            removeInProgress: { removeInProgressCount += 1 },
            presentTransientChange: {}
        )
        coordinator.handle(DownloadReading(path: "/Downloads/movie.crdownload", kind: .created, fileID: 1, renamedTo: nil), now: Date())
        enqueueCount = 0

        coordinator.handle(DownloadReading(path: "/Downloads/movie.crdownload", kind: .removed, fileID: 1, renamedTo: nil), now: Date())
        XCTAssertEqual(enqueueCount, 0)
        XCTAssertEqual(replaceHeadCount, 0)
        // Bug fix regression: cancelling the ONLY in-flight download must dismiss the
        // standing .inProgress transient via removeInProgress(), or the spinner never stops
        // (found via on-device UAT — .inProgress is documented as never-self-elapsing).
        XCTAssertEqual(removeInProgressCount, 1)

        // D-15 — a removed (cancelled) download's entry is gone; a subsequent rename for the
        // same path is treated as untracked, not as a completion.
        coordinator.handle(DownloadReading(path: "/Downloads/movie.crdownload", kind: .renamed, fileID: 1, renamedTo: "/Downloads/movie.mp4"), now: Date())
        XCTAssertEqual(enqueueCount, 0)
        XCTAssertEqual(replaceHeadCount, 0)
    }

    func testRemovedOneOfTwoInFlightDoesNotCallRemoveInProgress() {
        var q = TransientQueue()
        var enqueueCount = 0
        var removeInProgressCount = 0
        let coordinator = DownloadCoordinator(
            queueHead: { q.head },
            enqueue: { t in enqueueCount += 1; return q.enqueue(t) },
            replaceHead: { q.updateHead($0) },
            removeInProgress: { removeInProgressCount += 1 },
            presentTransientChange: {}
        )
        coordinator.handle(DownloadReading(path: "/Downloads/A.crdownload", kind: .created, fileID: 1, renamedTo: nil), now: Date())
        coordinator.handle(DownloadReading(path: "/Downloads/B.crdownload", kind: .created, fileID: 2, renamedTo: nil), now: Date())

        // Cancel A while B is still in flight — the shared generic .inProgress indicator is
        // still accurate (B is still downloading), so it must NOT be dismissed.
        coordinator.handle(DownloadReading(path: "/Downloads/A.crdownload", kind: .removed, fileID: 1, renamedTo: nil), now: Date())
        XCTAssertEqual(removeInProgressCount, 0)
        XCTAssertEqual(q.head, .downloadProgress(.inProgress))

        // Now cancel B too — this WAS the last one in flight — must dismiss.
        coordinator.handle(DownloadReading(path: "/Downloads/B.crdownload", kind: .removed, fileID: 2, renamedTo: nil), now: Date())
        XCTAssertEqual(removeInProgressCount, 1)
    }

    func testRenamedCompletingWhileStalePendingInProgressPromotesDoneNotStuckInProgress() {
        // Code review CR-01 regression: a download that finishes while a higher-priority
        // transient (Charging/Device) is head must not leave a stale, never-self-elapsing
        // .inProgress stuck in `pending` ahead of the real .done splash.
        var q = TransientQueue()
        let coordinator = DownloadCoordinator(
            queueHead: { q.head },
            enqueue: { q.enqueue($0) },
            replaceHead: { q.updateHead($0) },
            removeInProgress: {
                q.removeAll(where: { t in
                    if case .downloadProgress(.inProgress) = t { return true }
                    return false
                })
            },
            presentTransientChange: {}
        )
        // Charging is already standing when the download starts.
        _ = q.enqueue(.charging(.charging(percent: 50)))
        XCTAssertEqual(q.head, .charging(.charging(percent: 50)))

        // Download starts while Charging is head — .inProgress goes to `pending`, not head.
        coordinator.handle(DownloadReading(path: "/Downloads/movie.crdownload", kind: .created, fileID: 1, renamedTo: nil), now: Date())
        XCTAssertEqual(q.head, .charging(.charging(percent: 50)))
        XCTAssertEqual(q.pendingCount, 1)

        // Download finishes before Charging's dismiss timer elapses.
        coordinator.handle(DownloadReading(path: "/Downloads/movie.crdownload", kind: .renamed, fileID: 1, renamedTo: "/Downloads/movie.mp4"), now: Date())
        XCTAssertEqual(q.head, .charging(.charging(percent: 50)))   // Charging untouched

        // Simulate Charging's dismiss timer elapsing (NotchWindowController's scheduleActivityDismiss
        // calls transientQueue.advance() on its own timer — not exercised here, only its effect).
        _ = q.advance()
        // Must promote the DONE splash, not a stuck stale .inProgress.
        XCTAssertEqual(q.head, .downloadProgress(.done(filename: "movie.mp4")))
    }

    func testRenamedWithNilRenamedToReconcilesLastInFlightViaRemoveInProgress() {
        // Code review WR-01 regression: the defensive nil-renamedTo branch must not silently
        // strand a standing .inProgress transient with no owner left to dismiss it.
        var q = TransientQueue()
        var removeInProgressCount = 0
        let coordinator = DownloadCoordinator(
            queueHead: { q.head },
            enqueue: { q.enqueue($0) },
            replaceHead: { q.updateHead($0) },
            removeInProgress: { removeInProgressCount += 1 },
            presentTransientChange: {}
        )
        coordinator.handle(DownloadReading(path: "/Downloads/movie.crdownload", kind: .created, fileID: 1, renamedTo: nil), now: Date())

        coordinator.handle(DownloadReading(path: "/Downloads/movie.crdownload", kind: .renamed, fileID: 1, renamedTo: nil), now: Date())
        XCTAssertEqual(removeInProgressCount, 1)
    }

    func testRenamedWithNilRenamedToOneOfTwoInFlightDoesNotCallRemoveInProgress() {
        var q = TransientQueue()
        var removeInProgressCount = 0
        let coordinator = DownloadCoordinator(
            queueHead: { q.head },
            enqueue: { q.enqueue($0) },
            replaceHead: { q.updateHead($0) },
            removeInProgress: { removeInProgressCount += 1 },
            presentTransientChange: {}
        )
        coordinator.handle(DownloadReading(path: "/Downloads/A.crdownload", kind: .created, fileID: 1, renamedTo: nil), now: Date())
        coordinator.handle(DownloadReading(path: "/Downloads/B.crdownload", kind: .created, fileID: 2, renamedTo: nil), now: Date())

        // A's rename malforms (nil renamedTo) while B is still in flight — must NOT dismiss the
        // still-accurate shared .inProgress indicator.
        coordinator.handle(DownloadReading(path: "/Downloads/A.crdownload", kind: .renamed, fileID: 1, renamedTo: nil), now: Date())
        XCTAssertEqual(removeInProgressCount, 0)
    }

    func testRemovedUntrackedPathIsSafeNoOp() {
        var enqueueCount = 0
        var replaceHeadCount = 0
        var removeInProgressCount = 0
        var presentCount = 0
        let coordinator = DownloadCoordinator(
            queueHead: { nil },
            enqueue: { _ in enqueueCount += 1; return false },
            replaceHead: { _ in replaceHeadCount += 1 },
            removeInProgress: { removeInProgressCount += 1 },
            presentTransientChange: { presentCount += 1 }
        )
        let reading = DownloadReading(path: "/Downloads/never-seen.crdownload", kind: .removed, fileID: 1, renamedTo: nil)
        coordinator.handle(reading, now: Date())
        XCTAssertEqual(enqueueCount, 0)
        XCTAssertEqual(replaceHeadCount, 0)
        XCTAssertEqual(removeInProgressCount, 0)
        XCTAssertEqual(presentCount, 0)
    }

    func testActivityPromotedIsSafeNoOpCallingNoClosures() {
        var enqueueCount = 0
        var replaceHeadCount = 0
        var presentCount = 0
        var queueHeadCallCount = 0
        let coordinator = DownloadCoordinator(
            queueHead: { queueHeadCallCount += 1; return nil },
            enqueue: { _ in enqueueCount += 1; return false },
            replaceHead: { _ in replaceHeadCount += 1 },
            removeInProgress: {},
            presentTransientChange: { presentCount += 1 }
        )
        coordinator.activityPromoted()
        XCTAssertEqual(enqueueCount, 0)
        XCTAssertEqual(replaceHeadCount, 0)
        XCTAssertEqual(presentCount, 0)
        XCTAssertEqual(queueHeadCallCount, 0)
    }

    func testResetClearsInFlightTable() {
        var q = TransientQueue()
        var enqueueCount = 0
        var replaceHeadCount = 0
        let coordinator = DownloadCoordinator(
            queueHead: { q.head },
            enqueue: { t in enqueueCount += 1; return q.enqueue(t) },
            replaceHead: { t in replaceHeadCount += 1; q.updateHead(t) },
            removeInProgress: {},
            presentTransientChange: {}
        )
        coordinator.handle(DownloadReading(path: "/Downloads/movie.crdownload", kind: .created, fileID: 1, renamedTo: nil), now: Date())
        coordinator.reset()
        enqueueCount = 0
        replaceHeadCount = 0

        // After reset(), a rename for a path tracked BEFORE the reset is treated as untracked.
        coordinator.handle(DownloadReading(path: "/Downloads/movie.crdownload", kind: .renamed, fileID: 1, renamedTo: "/Downloads/movie.mp4"), now: Date())
        XCTAssertEqual(enqueueCount, 0)
        XCTAssertEqual(replaceHeadCount, 0)
    }
}
