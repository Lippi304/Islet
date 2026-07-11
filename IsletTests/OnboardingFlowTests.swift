import XCTest
@testable import Islet

// Phase 26 / ONBOARD-01/ONBOARD-03: the PURE onboarding seam -- step-sequencing reducer
// (D-01/D-02/D-09: Welcome -> Trial/License/Buy -> Permissions -> Done, forward/back total
// function) plus the two launch-time gate functions that decide whether onboarding shows at
// all and correctly grandfather an existing pre-Phase-26 user (RESEARCH.md Pitfall 2). Like
// IslandResolver's resolve(...), these are Foundation-only, total, framework-free values --
// no AppKit, no UserDefaults reads inside the functions themselves (the caller passes the
// already-read values in).
final class OnboardingFlowTests: XCTestCase {

    // MARK: nextOnboardingStep(...) -- forward sequence

    func testNextOnboardingStepAdvancesWelcomeToTrialLicenseBuy() {
        XCTAssertEqual(nextOnboardingStep(.welcome, .next), .trialLicenseBuy)
    }

    func testNextOnboardingStepAdvancesTrialLicenseBuyToPermissions() {
        XCTAssertEqual(nextOnboardingStep(.trialLicenseBuy, .next), .permissions)
    }

    func testNextOnboardingStepAdvancesPermissionsToDone() {
        XCTAssertEqual(nextOnboardingStep(.permissions, .next), .done)
    }

    // MARK: nextOnboardingStep(...) -- back sequence

    func testNextOnboardingStepBackFromPermissionsReturnsToTrialLicenseBuy() {
        XCTAssertEqual(nextOnboardingStep(.permissions, .back), .trialLicenseBuy)
    }

    func testNextOnboardingStepBackFromTrialLicenseBuyReturnsToWelcome() {
        XCTAssertEqual(nextOnboardingStep(.trialLicenseBuy, .back), .welcome)
    }

    // MARK: nextOnboardingStep(...) -- idempotent boundaries (total function, no crash)

    func testNextOnboardingStepIsIdempotentAtDone() {
        // No step past Done -- .next at .done is a no-op.
        XCTAssertEqual(nextOnboardingStep(.done, .next), .done)
    }

    func testNextOnboardingStepIsIdempotentAtWelcomeGoingBack() {
        // Nothing before Welcome -- .back at .welcome is a no-op.
        XCTAssertEqual(nextOnboardingStep(.welcome, .back), .welcome)
    }

    // MARK: shouldShowOnboarding(...) -- D-09 launch gate, RESEARCH.md Pitfall 2

    func testShouldShowOnboardingTrueForGenuinelyFreshInstall() {
        XCTAssertTrue(shouldShowOnboarding(isFirstLaunch: true, onboardingCompletedStored: nil))
    }

    func testShouldShowOnboardingFalseForGrandfatheredExistingUser() {
        // Existing user, no stored flag yet -- must NOT be forced through onboarding.
        XCTAssertFalse(shouldShowOnboarding(isFirstLaunch: false, onboardingCompletedStored: nil))
    }

    func testShouldShowOnboardingTrueOnMidFlowQuitRelaunch() {
        // A mid-flow quit/relaunch resumes -- isFirstLaunch is now false but the flag is
        // explicitly false (not nil), so onboarding must still show.
        XCTAssertTrue(shouldShowOnboarding(isFirstLaunch: false, onboardingCompletedStored: false))
    }

    func testShouldShowOnboardingFalseOnceCompletedRegardlessOfFirstLaunch() {
        XCTAssertFalse(shouldShowOnboarding(isFirstLaunch: true, onboardingCompletedStored: true))
        XCTAssertFalse(shouldShowOnboarding(isFirstLaunch: false, onboardingCompletedStored: true))
    }

    // MARK: shouldSeedOnboardingCompletedForExistingUser(...) -- the grandfather write

    func testShouldSeedOnboardingCompletedForExistingUser() {
        XCTAssertTrue(shouldSeedOnboardingCompletedForExistingUser(isFirstLaunch: false, onboardingCompletedStored: nil))
    }

    func testShouldNotSeedForGenuineFreshInstall() {
        // A genuine fresh install must NOT be pre-seeded completed.
        XCTAssertFalse(shouldSeedOnboardingCompletedForExistingUser(isFirstLaunch: true, onboardingCompletedStored: nil))
    }

    func testShouldNotSeedWhenAlreadyHasStoredValue() {
        // Already has a stored value (either true or false) -- nothing to seed.
        XCTAssertFalse(shouldSeedOnboardingCompletedForExistingUser(isFirstLaunch: false, onboardingCompletedStored: true))
        XCTAssertFalse(shouldSeedOnboardingCompletedForExistingUser(isFirstLaunch: false, onboardingCompletedStored: false))
    }
}
