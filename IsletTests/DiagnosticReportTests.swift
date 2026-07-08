import XCTest
@testable import Islet

// Quick task 260708-u47 — pins DiagnosticReport's pure text-assembly logic. Mirrors
// LicenseStateTests.swift's style.
final class DiagnosticReportTests: XCTestCase {

    func testLicenseSummaryTrialPluralDays() {
        XCTAssertEqual(DiagnosticReport.licenseSummary(for: .trial(daysRemaining: 2)),
                        "Trial (2 days remaining)")
    }

    func testLicenseSummaryTrialSingularDay() {
        XCTAssertEqual(DiagnosticReport.licenseSummary(for: .trial(daysRemaining: 1)),
                        "Trial (1 day remaining)")
    }

    func testLicenseSummaryTrialExpired() {
        XCTAssertEqual(DiagnosticReport.licenseSummary(for: .trialExpired), "Trial expired")
    }

    func testLicenseSummaryLicensed() {
        XCTAssertEqual(DiagnosticReport.licenseSummary(for: .licensed), "Licensed")
    }

    func testHardwareModelReturnsNonEmptyString() {
        XCTAssertFalse(DiagnosticReport.hardwareModel().isEmpty)
    }

    func testTextContainsAllSectionsWithSuppliedValues() {
        let text = DiagnosticReport.text(
            licenseStatus: .licensed,
            launchAtLogin: true,
            chargingEnabled: true,
            nowPlayingEnabled: false,
            deviceEnabled: true,
            accentIndex: 2,
            nowPlayingHealthy: true
        )

        XCTAssertTrue(text.contains("App Version:"))
        XCTAssertTrue(text.contains("macOS:"))
        XCTAssertTrue(text.contains("Hardware Model:"))
        XCTAssertTrue(text.contains("License: Licensed"))
        XCTAssertTrue(text.contains("Launch at Login: on"))
        XCTAssertTrue(text.contains("Charging: on"))
        XCTAssertTrue(text.contains("Now Playing: off"))
        XCTAssertTrue(text.contains("Devices: on"))
        XCTAssertTrue(text.contains("Accent index: 2"))
        XCTAssertTrue(text.contains("Now Playing bridge: available"))
    }

    func testTextNowPlayingBridgeUnavailable() {
        let text = DiagnosticReport.text(
            licenseStatus: .licensed,
            launchAtLogin: false,
            chargingEnabled: false,
            nowPlayingEnabled: false,
            deviceEnabled: false,
            accentIndex: 0,
            nowPlayingHealthy: false
        )

        XCTAssertTrue(text.contains("Now Playing bridge: unavailable"))
    }

    func testTextNowPlayingBridgeUnknown() {
        let text = DiagnosticReport.text(
            licenseStatus: .licensed,
            launchAtLogin: false,
            chargingEnabled: false,
            nowPlayingEnabled: false,
            deviceEnabled: false,
            accentIndex: 0,
            nowPlayingHealthy: nil
        )

        XCTAssertTrue(text.contains("Now Playing bridge: unknown"))
    }
}
