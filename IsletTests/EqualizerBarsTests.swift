import XCTest
@testable import Islet

// Item 6 (D-03/D-06): EqualizerBars.makeProfiles() is the pure factory extracted so the
// random per-bar profile can be seeded once via @State instead of re-rolled on every
// parent re-render. The "stays stable across SwiftUI re-renders" invariant itself isn't
// unit-testable via XCTest without ViewInspector — it's verified on-device (Task 2). Here
// we only sanity-check the extracted factory's shape and value ranges.
final class EqualizerBarsTests: XCTestCase {

    func testMakeProfilesReturnsBarCountProfiles() {
        let profiles = EqualizerBars.makeProfiles()
        XCTAssertEqual(profiles.count, 5, "makeProfiles() must return exactly EqualizerBars.barCount profiles.")
    }

    func testMakeProfilesValuesAreWithinExpectedRanges() {
        let profiles = EqualizerBars.makeProfiles()
        for profile in profiles {
            XCTAssertTrue((3...6).contains(profile.low), "low must be in 3...6, got \(profile.low)")
            XCTAssertTrue((10...16).contains(profile.high), "high must be in 10...16, got \(profile.high)")
            XCTAssertTrue((0.55...1.05).contains(profile.period), "period must be in 0.55...1.05, got \(profile.period)")
            XCTAssertTrue((0...1).contains(profile.phase), "phase must be in 0...1, got \(profile.phase)")
        }
    }
}
