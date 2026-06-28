import XCTest
@testable import Islet

// Phase 6 / COORD-01: the PURE priority resolver + transient queue seam (the single
// arbiter, D-05). Like PowerActivity, DeviceActivity, and NowPlayingPresentation,
// resolve(...) and TransientQueue are total, framework-free values importing ONLY
// Foundation — no AppKit, no SwiftUI, no Timer/clock — so the riskiest coordination
// logic (D-02 rank Charging > Device > Now Playing, D-04 transient-over-expanded then
// yield to the highest-priority ambient, D-03 bounded de-duped sequential queue) is
// verified deterministically by an automated agent in milliseconds (RED→GREEN).
//
// The controller wiring (Plan 04, Wave 2) feeds the live @Published activities through
// this seam; settings toggles are applied BEFORE the resolver, never inside it.
final class IslandResolverTests: XCTestCase {

    // MARK: resolve(...) — D-02 rank ordering + D-04 transient-over-expanded

    func testChargingOutranksDeviceAndMedia() {
        // D-02 rank 1 + D-04: a charging transient wins even with media playing AND the
        // island user-expanded — the highest-priority transient always shows.
        let r = resolve(activeTransient: .charging(.charging(percent: 47)),
                        nowPlaying: .playing(title: "Song", artist: "Artist"),
                        nowPlayingHealthy: true,
                        isExpanded: true)
        XCTAssertEqual(r, .charging(.charging(percent: 47)))
    }

    func testDeviceOutranksAmbientMedia() {
        // D-02 rank 2: a device transient beats ambient now-playing wings (not expanded).
        let r = resolve(activeTransient: .device(.connected(name: "AirPods Pro", glyph: .airpodsPro, battery: nil)),
                        nowPlaying: .playing(title: "Song", artist: "Artist"),
                        nowPlayingHealthy: true,
                        isExpanded: false)
        XCTAssertEqual(r, .device(.connected(name: "AirPods Pro", glyph: .airpodsPro, battery: nil)))
    }

    func testNoTransientWhilePlayingReturnsToWings() {
        // D-02 ambient yield (rank 3): with no transient and media playing, the resolver
        // yields to the now-playing wings — NOT idle.
        let r = resolve(activeTransient: nil,
                        nowPlaying: .playing(title: "Song", artist: "Artist"),
                        nowPlayingHealthy: true,
                        isExpanded: false)
        XCTAssertEqual(r, .nowPlayingWings(.playing(title: "Song", artist: "Artist")))
    }

    func testNoTransientNoMediaIsIdle() {
        // No transient, nothing playing, collapsed → the static idle pill.
        let r = resolve(activeTransient: nil,
                        nowPlaying: .none,
                        nowPlayingHealthy: true,
                        isExpanded: false)
        XCTAssertEqual(r, .idle)
    }

    // MARK: resolve(...) — D-12 expanded health axis

    func testUnhealthyExpandedShowsUnavailable() {
        // D-12: expanded with an UNHEALTHY now-playing API → the "nicht verfügbar"
        // expanded state, regardless of the (stale) snapshot.
        let r = resolve(activeTransient: nil,
                        nowPlaying: .none,
                        nowPlayingHealthy: false,
                        isExpanded: true)
        XCTAssertEqual(r, .nowPlayingExpanded(.none, healthy: false))
    }

    func testExpandedHealthyNoMediaIsExpandedIdle() {
        // D-12: expanded, healthy API, nothing playing → the expanded idle (date/time) view.
        let r = resolve(activeTransient: nil,
                        nowPlaying: .none,
                        nowPlayingHealthy: true,
                        isExpanded: true)
        XCTAssertEqual(r, .expandedIdle)
    }

    func testExpandedHealthyPlayingShowsMediaControls() {
        // D-12: expanded, healthy API, media playing → the expanded media-controls view.
        let r = resolve(activeTransient: nil,
                        nowPlaying: .playing(title: "Song", artist: "Artist"),
                        nowPlayingHealthy: true,
                        isExpanded: true)
        XCTAssertEqual(r, .nowPlayingExpanded(.playing(title: "Song", artist: "Artist"), healthy: true))
    }

    // MARK: TransientQueue — D-03 bounded, de-duped, sequential coexistence

    private let charging = ActiveTransient.charging(.charging(percent: 50))
    private let device = ActiveTransient.device(.connected(name: "AirPods Pro", glyph: .airpodsPro, battery: nil))

    func testEnqueueIntoEmptyShowsImmediately() {
        // D-03: the first transient into an empty queue becomes the head and shows now.
        var q = TransientQueue()
        XCTAssertTrue(q.enqueue(charging))
        XCTAssertEqual(q.head, charging)
        XCTAssertEqual(q.pendingCount, 0)
    }

    func testEnqueueWhileShowingEnqueuesBehind() {
        // D-03: a second distinct transient while one is showing → enqueued behind
        // (returns false), the head is unchanged (no overlap).
        var q = TransientQueue()
        _ = q.enqueue(charging)
        XCTAssertFalse(q.enqueue(device))
        XCTAssertEqual(q.head, charging)
        XCTAssertEqual(q.pendingCount, 1)
    }

    func testQueueDedupsDuplicateHead() {
        // D-03 dedup: re-enqueuing the SAME transient as the head → no-op (false),
        // pending depth unchanged (never stacks the depth).
        var q = TransientQueue()
        _ = q.enqueue(charging)
        XCTAssertFalse(q.enqueue(charging))
        XCTAssertEqual(q.pendingCount, 0)
    }

    func testQueueDedupsAgainstPending() {
        // D-03 dedup: a transient already pending is not enqueued a second time.
        var q = TransientQueue()
        _ = q.enqueue(charging)        // head
        _ = q.enqueue(device)          // pending: [device]
        XCTAssertFalse(q.enqueue(device))
        XCTAssertEqual(q.pendingCount, 1)
    }

    func testAdvancePromotesPending() {
        // D-03 sequential: advance() promotes the next pending entry to head.
        var q = TransientQueue()
        _ = q.enqueue(charging)        // head = charging
        _ = q.enqueue(device)          // pending: [device]
        XCTAssertTrue(q.advance())
        XCTAssertEqual(q.head, device)
        XCTAssertEqual(q.pendingCount, 0)
    }

    func testAdvanceEmptyReturnsToAmbient() {
        // D-03: advancing with nothing pending clears the head → back to the ambient state.
        var q = TransientQueue()
        _ = q.enqueue(charging)
        XCTAssertTrue(q.advance())
        XCTAssertNil(q.head)
        XCTAssertEqual(q.pendingCount, 0)
    }

    func testQueueBoundedDropsOldestPending() {
        // D-03 bound (T-06-01): enqueuing 4 distinct transients after the head caps pending
        // at maxDepth (2), dropping the OLDEST pending; the head is never dropped.
        var q = TransientQueue()
        let a = ActiveTransient.charging(.charging(percent: 10))
        let b = ActiveTransient.charging(.charging(percent: 20))
        let c = ActiveTransient.charging(.charging(percent: 30))
        let d = ActiveTransient.charging(.charging(percent: 40))
        let e = ActiveTransient.charging(.charging(percent: 50))
        XCTAssertTrue(q.enqueue(a))     // head = a
        XCTAssertFalse(q.enqueue(b))    // pending: [b]
        XCTAssertFalse(q.enqueue(c))    // pending: [b, c]
        XCTAssertFalse(q.enqueue(d))    // pending: [c, d]  (b dropped — oldest)
        XCTAssertFalse(q.enqueue(e))    // pending: [d, e]  (c dropped — oldest)
        XCTAssertEqual(q.head, a)       // head never dropped
        XCTAssertEqual(q.pendingCount, 2)
        // The oldest survivors advance in FIFO order: d then e.
        _ = q.advance(); XCTAssertEqual(q.head, d)
        _ = q.advance(); XCTAssertEqual(q.head, e)
    }
}
