import XCTest
@testable import Islet

// Phase 10 / TRIAL-01: the PURE trial-classification seam. Like PowerActivity's
// powerActivity(from:), trialStatus(startDate:now:trialLength:) is a total,
// framework-free function — no Security/Keychain, no Date() call inside — so the
// riskiest classification logic (the exact 3-day active/expired boundary) is
// verified deterministically by an automated agent in milliseconds.
// TrialManager.swift (Task 2) owns the real Keychain read and feeds startDate/now
// values in here.
final class TrialLogicTests: XCTestCase {

    private let trialLength: TimeInterval = 3 * 86400

    func testZeroElapsedIsActiveWithFullDaysRemaining() {
        // Fresh trial start: now == startDate → still fully active, 3 days remaining.
        let t0 = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertEqual(trialStatus(startDate: t0, now: t0, trialLength: trialLength), .active(daysRemaining: 3))
    }

    func testNearBoundaryRoundsUpAndNeverZero() {
        // 2.99 days elapsed: 0.01 days (864s) remaining → rounds up to 1 day, never 0.
        let t0 = Date(timeIntervalSince1970: 1_000_000)
        let now = t0.addingTimeInterval(2.99 * 86400)
        XCTAssertEqual(trialStatus(startDate: t0, now: now, trialLength: trialLength), .active(daysRemaining: 1))
    }

    func testExactBoundaryElapsedEqualsLengthIsExpired() {
        // Elapsed == trialLength exactly → expired (boundary is exclusive: elapsed < trialLength
        // required to stay active).
        let t0 = Date(timeIntervalSince1970: 1_000_000)
        let now = t0.addingTimeInterval(trialLength)
        XCTAssertEqual(trialStatus(startDate: t0, now: now, trialLength: trialLength), .expired)
    }

    func testWellPastExpiryIsExpired() {
        let t0 = Date(timeIntervalSince1970: 1_000_000)
        let now = t0.addingTimeInterval(10 * 86400)
        XCTAssertEqual(trialStatus(startDate: t0, now: now, trialLength: trialLength), .expired)
    }

    func testJustBeforeExpiryIsActive() {
        // 1 second before the boundary must still be active (elapsed < trialLength).
        let t0 = Date(timeIntervalSince1970: 1_000_000)
        let now = t0.addingTimeInterval(trialLength - 1)
        if case .active = trialStatus(startDate: t0, now: now, trialLength: trialLength) {
            // pass
        } else {
            XCTFail("Expected .active one second before the exact boundary")
        }
    }
}
