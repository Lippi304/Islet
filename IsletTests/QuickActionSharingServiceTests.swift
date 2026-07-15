import XCTest
@testable import Islet

// Phase 34 / TRAY-02 (T-34-02) — proves QuickActionSharingService's mockable seam works
// without triggering real OS UI. Mirrors LocationServiceTests.swift's FakeLocationService
// precedent: an in-memory fake conforming to SharingServicePerforming, no real
// NSSharingService/AirDrop/Mail invocation executes during this test run.
final class QuickActionSharingServiceTests: XCTestCase {

    private final class FakeSharingService: SharingServicePerforming {
        var canPerformResult = true
        private(set) var performCallCount = 0
        private(set) var lastPerformedItems: [Any]?
        var delegate: NSSharingServiceDelegate?

        func canPerform(withItems items: [Any]) -> Bool { canPerformResult }
        func perform(withItems items: [Any]) {
            performCallCount += 1
            lastPerformedItems = items
        }
    }

    private let testURLs = [URL(fileURLWithPath: "/tmp/a.txt")]

    func testShareCallsPerformOnceWhenCanPerformTrue() {
        let fake = FakeSharingService()
        let sut = QuickActionSharingService(makeService: { _ in fake })
        var finishCallCount = 0

        sut.share(testURLs, via: .sendViaAirDrop, onFinish: { finishCallCount += 1 })

        XCTAssertEqual(fake.performCallCount, 1)
        XCTAssertEqual(fake.lastPerformedItems as? [URL], testURLs)
        // Pitfall 2 — never called synchronously; only the delegate callback/timeout fires it.
        XCTAssertEqual(finishCallCount, 0)
    }

    func testShareCallsOnFinishSynchronouslyWhenCanPerformFalse() {
        let fake = FakeSharingService()
        fake.canPerformResult = false
        let sut = QuickActionSharingService(makeService: { _ in fake })
        var finishCallCount = 0

        sut.share(testURLs, via: .sendViaAirDrop, onFinish: { finishCallCount += 1 })

        XCTAssertEqual(finishCallCount, 1)
        XCTAssertEqual(fake.performCallCount, 0)
    }

    func testDidShareItemsCallsOnFinishExactlyOnce() {
        let fake = FakeSharingService()
        let sut = QuickActionSharingService(makeService: { _ in fake })
        var finishCallCount = 0
        sut.share(testURLs, via: .sendViaAirDrop, onFinish: { finishCallCount += 1 })

        let realService = NSSharingService(named: .sendViaAirDrop)!
        fake.delegate?.sharingService?(realService, didShareItems: [])

        XCTAssertEqual(finishCallCount, 1)
    }

    func testDidFailToShareItemsCallsOnFinishExactlyOnce() {
        let fake = FakeSharingService()
        let sut = QuickActionSharingService(makeService: { _ in fake })
        var finishCallCount = 0
        sut.share(testURLs, via: .sendViaAirDrop, onFinish: { finishCallCount += 1 })

        let realService = NSSharingService(named: .sendViaAirDrop)!
        let error = NSError(domain: "test", code: 1)
        fake.delegate?.sharingService?(realService, didFailToShareItems: [], error: error)

        XCTAssertEqual(finishCallCount, 1)
    }

    func testBothCompletionCallbacksOnSameDelegateFireOnFinishOnlyOnce() {
        // Idempotent `finished` guard (mirrors QuickActionSharingDelegate's own flag).
        let fake = FakeSharingService()
        let sut = QuickActionSharingService(makeService: { _ in fake })
        var finishCallCount = 0
        sut.share(testURLs, via: .sendViaAirDrop, onFinish: { finishCallCount += 1 })

        let realService = NSSharingService(named: .sendViaAirDrop)!
        fake.delegate?.sharingService?(realService, didShareItems: [])
        fake.delegate?.sharingService?(realService, didFailToShareItems: [], error: NSError(domain: "test", code: 1))

        XCTAssertEqual(finishCallCount, 1)
    }
}
