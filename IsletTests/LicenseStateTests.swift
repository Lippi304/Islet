import XCTest
@testable import Islet

// Phase 15 / P15-ITEM4 — LicenseState's 4-way precedence order (DEBUG override →
// persisted license → session activation → trial), pinned via fakes. No real
// Keychain or UserDefaults I/O executes during this test run (mirrors
// LicenseManagerTests.swift's FakeLicenseStore precedent).
final class LicenseStateTests: XCTestCase {

    private final class FakeLicenseManager: LicenseManaging {
        var isLicensed: Bool
        init(isLicensed: Bool) { self.isLicensed = isLicensed }
    }

    private final class FakeTrialManager: TrialStatusProviding {
        var trialStartDateValue: Date?
        init(trialStartDate: Date?) { self.trialStartDateValue = trialStartDate }
        func trialStartDate() -> Date? { trialStartDateValue }
    }

    func testPersistedLicenseWinsOverEverything() {
        let state = LicenseState(
            licenseManager: FakeLicenseManager(isLicensed: true),
            trialManager: FakeTrialManager(trialStartDate: nil)
        )

        XCTAssertEqual(state.status, .licensed)
    }

    func testSessionActivationWinsWhenNotPersistedLicensed() {
        let state = LicenseState(
            licenseManager: FakeLicenseManager(isLicensed: false),
            trialManager: FakeTrialManager(trialStartDate: nil)
        )
        state.sessionActivated = true

        XCTAssertEqual(state.status, .licensed)
    }

    func testActiveTrialReturnsDaysRemaining() {
        let start = Date().addingTimeInterval(-86400) // 1 day ago
        let state = LicenseState(
            licenseManager: FakeLicenseManager(isLicensed: false),
            trialManager: FakeTrialManager(trialStartDate: start)
        )

        XCTAssertEqual(state.status, .trial(daysRemaining: 2))
    }

    func testExpiredTrialReturnsTrialExpired() {
        let start = Date().addingTimeInterval(-4 * 86400) // 4 days ago
        let state = LicenseState(
            licenseManager: FakeLicenseManager(isLicensed: false),
            trialManager: FakeTrialManager(trialStartDate: start)
        )

        XCTAssertEqual(state.status, .trialExpired)
    }

    func testMissingTrialStartDateFallsBackToFreshTrial() {
        let state = LicenseState(
            licenseManager: FakeLicenseManager(isLicensed: false),
            trialManager: FakeTrialManager(trialStartDate: nil)
        )

        XCTAssertEqual(state.status, .trial(daysRemaining: 3))
    }

    func testIsEntitledMapping() {
        let trialState = LicenseState(
            licenseManager: FakeLicenseManager(isLicensed: false),
            trialManager: FakeTrialManager(trialStartDate: nil)
        )
        XCTAssertTrue(trialState.isEntitled)

        let licensedState = LicenseState(
            licenseManager: FakeLicenseManager(isLicensed: true),
            trialManager: FakeTrialManager(trialStartDate: nil)
        )
        XCTAssertTrue(licensedState.isEntitled)

        let expiredState = LicenseState(
            licenseManager: FakeLicenseManager(isLicensed: false),
            trialManager: FakeTrialManager(trialStartDate: Date().addingTimeInterval(-4 * 86400))
        )
        XCTAssertFalse(expiredState.isEntitled)
    }
}
