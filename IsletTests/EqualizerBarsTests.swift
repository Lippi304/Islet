import XCTest
@testable import Islet

// EQ-01/D-07/D-08: EqualizerBars.targetHeight(bar:bucket:) is the pure factory that replaced
// the old per-bar sine-profile model with a periodic reroll-and-spring one (Phase 36). It's
// `internal` (not `private`) so this file can call it directly under `@testable import` —
// same testability precedent the old makeProfiles() established. The "bars actually spring
// on-screen every ~100ms" behavior itself isn't unit-testable via XCTest without
// ViewInspector — verified on-device (Task 3). Here we only sanity-check the factory's range
// and determinism contract.
final class EqualizerBarsTests: XCTestCase {

    func testTargetHeightIsWithinExpectedRange() {
        for bar in 0..<5 {
            for bucket in 0..<50 {
                let height = EqualizerBars.targetHeight(bar: bar, bucket: bucket)
                XCTAssertTrue((4.0...14.0).contains(height), "targetHeight(bar: \(bar), bucket: \(bucket)) = \(height) must be in 4.0...14.0")
            }
        }
    }

    func testTargetHeightIsDeterministic() {
        let first = EqualizerBars.targetHeight(bar: 2, bucket: 7)
        let second = EqualizerBars.targetHeight(bar: 2, bucket: 7)
        XCTAssertEqual(first, second, "targetHeight(bar:bucket:) must return the same value for the same (bar, bucket) pair.")
    }
}
