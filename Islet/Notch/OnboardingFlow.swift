import Foundation

// Phase 26 / ONBOARD-01/ONBOARD-03: the PURE onboarding seam. Like NotchInteractionState's
// nextState(...) and IslandResolver's resolve(...), this imports ONLY Foundation -- no
// AppKit, no UserDefaults reads inside the functions themselves (the caller reads
// isFirstLaunch/onboardingCompletedStored and passes them in) -- so the step sequencing and
// the launch-gate decisions are unit-tested in milliseconds.
//
// D-01/D-09: onboarding is a forced flow -- once shown, it is never pre-empted by any
// transient/expanded island state (see IslandResolver.resolve(...)'s onboardingStep-first
// precedence check). D-01 (this file's own CONTEXT.md numbering) also requires the launch
// gate to correctly grandfather an existing pre-Phase-26 user: RESEARCH.md's Pitfall 2 calls
// out that a naive "no stored flag => show onboarding" check would incorrectly force EVERY
// existing user through onboarding on their next launch (they have no stored
// onboardingCompleted key either, since the key didn't exist before this phase).
// shouldShowOnboarding/shouldSeedOnboardingCompletedForExistingUser exist as two SEPARATE
// pure functions specifically to make that distinction explicit and testable in isolation.

enum OnboardingStep: Equatable, CaseIterable {
    case welcome
    case trialLicenseBuy
    case permissions
    case done
}

enum OnboardingEvent: Equatable {
    case next
    case back
}

enum OnboardingPermission: Equatable {
    case bluetooth
    case calendar
    case location
}

// TOTAL pure reducer -- D-09 step sequence: Welcome -> Trial/License/Buy -> Permissions ->
// Done, reversible via .back. Idempotent at both ends (no step past Done, nothing before
// Welcome) so this can never produce an out-of-range/malformed step.
func nextOnboardingStep(_ current: OnboardingStep, _ event: OnboardingEvent) -> OnboardingStep {
    switch (current, event) {
    case (.welcome, .next):         return .trialLicenseBuy
    case (.trialLicenseBuy, .next): return .permissions
    case (.trialLicenseBuy, .back): return .welcome
    case (.permissions, .next):     return .done
    case (.permissions, .back):     return .trialLicenseBuy
    default:                        return current   // idempotent no-ops (.done+.next, .welcome+.back)
    }
}

// TOTAL pure gate -- decides whether onboarding shows THIS launch. `onboardingCompletedStored`
// is the raw UserDefaults-backed value (nil = key never written). A stored value always wins
// (true -> never re-shown; false -> a mid-flow quit/relaunch resumes, regardless of
// isFirstLaunch now being false). Only when nothing is stored yet does isFirstLaunch decide --
// this is the ONLY path a genuinely fresh install takes.
func shouldShowOnboarding(isFirstLaunch: Bool, onboardingCompletedStored: Bool?) -> Bool {
    switch onboardingCompletedStored {
    case true?:  return false
    case false?: return true
    case nil:    return isFirstLaunch
    }
}

// TOTAL pure gate -- the grandfather write RESEARCH.md's Pitfall 2 requires: an EXISTING user
// (isFirstLaunch == false) with no stored flag yet must have onboardingCompleted seeded to
// true so they are never gated. A genuine fresh install (isFirstLaunch == true) must NOT be
// pre-seeded -- shouldShowOnboarding's nil branch is exactly what lets it show for them.
func shouldSeedOnboardingCompletedForExistingUser(isFirstLaunch: Bool, onboardingCompletedStored: Bool?) -> Bool {
    onboardingCompletedStored == nil && !isFirstLaunch
}
