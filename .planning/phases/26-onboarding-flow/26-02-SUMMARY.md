---
phase: 26-onboarding-flow
plan: 02
subsystem: ui
tags: [swiftui, onboarding, notch-panel, launch-at-login, permissions]

# Dependency graph
requires:
  - phase: 26-01
    provides: "OnboardingFlow.swift pure step reducer (OnboardingStep/OnboardingEvent/OnboardingPermission), IslandResolver's .onboarding(OnboardingStep) case + resolve(...) onboardingStep-first precedence"
provides:
  - "OnboardingViewState (3 per-permission @Published Bool? granted flags, controller-owned)"
  - "NotchPillView.onboardingSize constant (360x240, fixed panel size for all 4 onboarding steps)"
  - "blobShape(...) extended with an optional height override, backward-compatible for every existing caller"
  - "onboardingCarousel(_:) rendering the real Welcome/Trial-License-Buy/Permissions/Done step content per 26-UI-SPEC.md"
  - "6 new NotchPillView init params (onboardingState @ObservedObject + 5 no-op-defaulted closures) ready for Plan 26-04 to wire to real controller behavior"
affects: [26-03, 26-04]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Separate @Published view-state model, controller-owned, view-render-only (OnboardingViewState mirrors IslandPresentationState/ShelfViewState exactly)"
    - "blobShape height parameter defaults to nil -> Self.expandedSize.height, so extending a shared shape helper never changes existing callers' byte-for-byte output"
    - "Per-step content factored into small private computed properties (onboardingWelcomeStep etc.) + a standalone OnboardingDoneStep struct for the one step needing its own scoped @State"

key-files:
  created:
    - Islet/Notch/OnboardingViewState.swift
  modified:
    - Islet/Notch/NotchPillView.swift
    - Islet/Notch/NotchWindowController.swift

key-decisions:
  - "permissionRow renders the Grant chip only while granted == nil (never attempted this session); once an attempt settles true/false, the chip is replaced by the granted-state view (green Granted / grey Not granted) -- no re-ask affordance, matching D-03's 'no re-ask/nudge' rule and D-02's requirement for a real tappable Grant control"
  - "Done step's Launch-at-Login toggle factored into a standalone private struct (OnboardingDoneStep) rather than a NotchPillView property, so its @State is scoped to just that step's lifetime and never leaks across other presentation cases"
  - "NotchWindowController gained a private onboardingState = OnboardingViewState() property + passed it into makeRootView -- required because the new onboardingState init param is non-defaulted; Plan 26-04 owns wiring real permission-request writes into it"

patterns-established:
  - "onboardingCarousel(_:) follows blobShape's existing content-closure shape exactly (same call pattern as expandedIsland/mediaExpanded), shelfItems always [] during onboarding"
  - "chipButton(_:fontSize:action:) factors the shared Next/Back/Finish/Grant chip style (RoundedRectangle + Color.white.opacity(0.12)) into one reusable helper"

requirements-completed: [ONBOARD-01, ONBOARD-02]

# Metrics
duration: 22min
completed: 2026-07-11
---

# Phase 26 Plan 02: Onboarding Carousel View Contract Summary

**Notch-hosted 4-step onboarding carousel (Welcome/Trial-License-Buy/Permissions/Done) rendered inside the real expanded blobShape chrome, with per-permission granted-state tracking in a new OnboardingViewState and a verbatim Launch-at-Login mirror on the Done step.**

## Performance

- **Duration:** 22 min
- **Started:** 2026-07-11T17:14:00Z (approx, first file read)
- **Completed:** 2026-07-11T17:36:58Z
- **Tasks:** 2 completed
- **Files modified:** 3 (1 created, 2 modified)

## Accomplishments
- `OnboardingViewState` — a plain `@Published` holder for 3 permission granted/not-granted flags, mirroring `IslandPresentationState`'s established shape exactly
- `blobShape(...)` extended with an optional `height` override, zero behavior change for `expandedIsland`/`mediaExpanded`/`mediaUnavailable`
- The real `.onboarding(step)` presentation case now renders `onboardingCarousel(_:)` — all 4 steps, exact Copywriting Contract strings, correct typography/spacing per `26-UI-SPEC.md`
- Permissions step: 3 independent rows (Bluetooth/Calendar/Location), each with its own Grant chip that transitions to a quiet green/grey state once an attempt settles (D-02/D-03)
- Trial/License/Buy step: both buttons route exclusively through `onOnboardingOpenSettings()` — zero new license/validation logic (D-05 LOCKED, verified via `grep -c LicenseState` = 0)
- Done step: `OnboardingDoneStep` mirrors `SettingsView.swift`'s Launch-at-Login toggle verbatim, same `LaunchAtLogin`/`SMAppService.mainApp` state (D-10)
- All 8 existing `#Preview` blocks updated to compile with the new non-defaulted `onboardingState` param

## Task Commits

Each task was committed atomically:

1. **Task 1: OnboardingViewState + blobShape height parameter + onboardingSize constant** - `4193bf8` (feat)
2. **Task 2: onboardingCarousel(step:) view, new init params, Done-screen Launch-at-Login mirror** - `37e1e9e` (feat)

_No plan-metadata commit yet — SUMMARY.md commit is next (worktree mode: STATE.md/ROADMAP.md excluded, orchestrator owns those after the wave)._

## Files Created/Modified
- `Islet/Notch/OnboardingViewState.swift` - new `ObservableObject` with 3 `@Published var ...Granted: Bool?` fields (nil = not yet attempted, per D-03)
- `Islet/Notch/NotchPillView.swift` - `onboardingSize` constant, `blobShape` height override, `.onboarding(let step)` case wired to the real `onboardingCarousel(_:)`, 4 step content views, `permissionRow`, `chipButton`, `onboardingNavRow`, `OnboardingDoneStep`, 6 new init params, 8 updated `#Preview`s
- `Islet/Notch/NotchWindowController.swift` - added `onboardingState` property + passed into `makeRootView` (Rule 3 blocking-compile fix, see Deviations)

## Decisions Made
- Grant-chip vs. granted-state-view logic: chip shows only while `granted == nil`; both `true` and `false` replace it with the (green/grey) state view, since D-03 forbids a re-ask/nudge affordance once an attempt has settled
- Done step's toggle state scoped to a standalone `OnboardingDoneStep` struct, not a `NotchPillView` property (would otherwise leak `@State` across every unrelated presentation case)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] NotchWindowController.makeRootView missing the new required `onboardingState` argument**
- **Found during:** Task 2 build verification
- **Issue:** `NotchPillView`'s new `onboardingState: OnboardingViewState` init param is non-defaulted (matching the `outfit`/`shelfViewState` convention per the plan's own interfaces block), which broke the existing `NotchWindowController.makeRootView(accentIndex:)` call site — a file this plan's `files_modified` frontmatter did not list, but the compile error is a direct, unavoidable consequence of this plan's own required-param change.
- **Fix:** Added a `private let onboardingState = OnboardingViewState()` property to `NotchWindowController`, mirroring the exact existing `shelfViewState` pattern (same file, same ownership-contract doc comment style), and passed it into `makeRootView`'s `NotchPillView(...)` construction. Plan 26-04 owns wiring real permission-request writes into this instance — this plan only needed the property to exist so the build compiles.
- **Files modified:** `Islet/Notch/NotchWindowController.swift`
- **Verification:** `xcodebuild build -scheme Islet -destination 'platform=macOS' -configuration Debug` → `BUILD SUCCEEDED`
- **Committed in:** `37e1e9e` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Necessary to make the plan's own required-param change compile; no scope creep — the added property is a bare `ObservableObject` instantiation with no new logic, correctly deferred to Plan 26-04 for real wiring.

## Issues Encountered

**Worktree build-path mismatch:** the plan's `<verify>` commands hardcode `cd /Users/lippi304/conductor/workspaces/notch/algiers && xcodegen generate && xcodebuild ...`. That path is a *separate* git checkout (branch `gsd-new-project-setup`), not this worktree (`worktree-agent-a0cbf8fd057fc093e`) — running the verify command there would have built and validated a different checkout's code, silently missing this plan's actual changes. Confirmed via `git rev-parse --show-toplevel`/`git branch --show-current` in both locations. Resolution: ran `xcodegen generate && xcodebuild build ...` from the worktree's own root instead (same project.yml/Islet.xcodeproj exists there), which correctly caught the Task 2 blocking compile error documented above. No plan or code change needed — purely an execution-environment adjustment for this parallel worktree run.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- The view-layer contract (init params, closures, constants, permission-row rendering rules) is fully in place for Plan 26-04 to wire real controller behavior: `NotchWindowController` must drive `onboardingState`'s 3 flags from real `LocationProvider`/`CalendarService`/`BluetoothMonitor` outcomes, and forward `onOnboardingNext`/`onOnboardingBack`/`onOnboardingGrant`/`onOnboardingOpenSettings`/`onOnboardingFinish` to the real `OnboardingFlow.swift` reducer + Settings hand-off + the `onboarding.completed` persisted flag.
- Visual/copy correctness against `26-UI-SPEC.md` is NOT yet human-verified on-device — deferred to Plan 26-04's checkpoint per this plan's own `<verification>` note ("this plan produces the view code; the checkpoint is where a human actually sees it rendered in the real notch panel").
- No blockers.

---
*Phase: 26-onboarding-flow*
*Completed: 2026-07-11*
