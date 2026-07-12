---
phase: 26-onboarding-flow
plan: 04
subsystem: ui
tags: [swiftui, appkit, nspanel, onboarding, notarization-target, deployment-target]

# Dependency graph
requires:
  - phase: 26-onboarding-flow (plans 01-03)
    provides: OnboardingFlow pure seams, OnboardingViewState, onboardingCarousel view contract, launch-time onboarding gate
provides:
  - Full interactive onboarding session wired into NotchWindowController (Welcome -> Trial/License/Buy -> Permissions -> Done)
  - Onboarding-aware click geometry + collapse guards (visibleContentZone/positionAndShow/handleClick/handleHoverExit)
  - Real Bluetooth/Location/Calendar permission-request handlers per Permissions row
  - Settings window auto-restore-at-launch fix (.defaultLaunchBehavior(.suppressed), macOS 15.0 deployment floor)
  - SwiftUI launch-time reentrancy fix (deferred interaction.phase/syncClickThrough priming)
  - Round 1-5 visual redesign of the onboarding carousel (Droppy-inspired: centered text, pill permission rows, circular nav, glow)
affects: [phase-27-settings-sidebar, phase-28-calendar-full-view, future-onboarding-iteration]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Onboarding-aware geometry branch in visibleContentZone()/positionAndShow(), scoped so syncClickThrough()'s interactive-value logic stays untouched (CR-01 discipline)"
    - "blobShape() optional width/height override parameters (mirrors the existing single-purpose-override convention already used for the shelf row)"
    - "ZStack(alignment: .bottom) + Spacer-bracketed content for a fixed-position nav row independent of sibling content height"
    - "Deferred @Published priming (DispatchQueue.main.async) for state mutations that are new to the synchronous AppDelegate.applicationDidFinishLaunching call path, to avoid racing SwiftUI's own App/Scene-graph launch setup"

key-files:
  created: []
  modified:
    - Islet/Notch/NotchWindowController.swift
    - Islet/Notch/NotchPillView.swift
    - Islet/IsletApp.swift
    - project.yml
    - Islet.xcodeproj/project.pbxproj
    - .planning/phases/26-onboarding-flow/26-UI-SPEC.md
    - .planning/phases/26-onboarding-flow/26-04-PLAN.md
    - .planning/PROJECT.md

key-decisions:
  - "Task 3's how-to-verify reset instructions were missing a Keychain trial-date reset (TrialManager is deliberately Keychain-backed, survives `defaults delete`) — fixed in the plan doc, not a code bug"
  - "onboardingCarousel's blobShape grows to onboardingSize.height but the outer body .frame() didn't — same clipping regression class as the Phase 21 shelf bug, just not propagated to the new .onboarding case; fixed by branching the outer frame on isOnboardingPresentation"
  - "On-device UAT diverged the onboarding carousel's visuals from the original locked 26-UI-SPEC.md across 5 rounds (Droppy-app comparison, explicit user direction each round): centered text, wider/taller panel (360x240 -> 420x320), pill-shaped permission rows, icon-only circular nav buttons, static green border+glow on granted rows — 26-UI-SPEC.md updated after every round to keep the design contract truthful"
  - "Settings window re-opening at launch was AppKit's own window-state restoration (independent of app logic), not a regression in this plan's code — fixed via .defaultLaunchBehavior(.suppressed) (macOS 15+), which required bumping the project's deployment target 14.0 -> 15.0 (user-approved, logged in PROJECT.md Key Decisions)"
  - "Xcode-only Thread 1 EXC_BREAKPOINT ('Publishing changes from within view updates') traced to interaction.phase = .expanded being the one @Published mutation Phase 26 added directly to the synchronous start()-inside-applicationDidFinishLaunching call path, racing SwiftUI's own App/Scene-graph launch setup; deferred that one mutation (+ its trailing syncClickThrough()) to the next run-loop turn rather than wrapping unrelated code"

patterns-established:
  - "Multi-round on-device UAT checkpoints for genuinely new UI: fix -> rebuild -> re-present checkpoint per round, updating the locked UI-SPEC.md after each visual revision so it never silently drifts from shipped code"

requirements-completed: [ONBOARD-01, ONBOARD-02, ONBOARD-03]

# Metrics
duration: ~25h wall-clock across 7 rounds of on-device UAT (2 automated tasks ~15min; remainder is checkpoint iteration, not continuous work)
completed: 2026-07-12
---

# Phase 26 Plan 04: Onboarding Interactive Wiring + On-Device UAT Summary

**Wired the full onboarding session (Welcome -> Trial/License/Buy -> Permissions -> Done) into `NotchWindowController`/`NotchPillView` with real independent Bluetooth/Calendar/Location permission prompts, then closed 7 rounds of on-device UAT covering a test-setup gap, two real layout-clipping bugs, a 5-round Droppy-inspired visual redesign, a Settings-window-state-restoration bug (with an approved macOS 15.0 deployment bump), and a SwiftUI launch-time reentrancy crash.**

## Performance

- **Duration:** ~25h wall-clock (2026-07-11 19:41 -> 2026-07-12 20:40), almost entirely on-device UAT iteration across 7 checkpoint rounds; the 2 automated tasks themselves were ~15 min of implementation each
- **Tasks:** 2 automated (Task 1, Task 2) + 1 checkpoint (Task 3, approved after 7 rounds of fix-and-retest)
- **Files modified:** 8 (2 Swift source, 1 Xcode project config pair, 1 build config, 3 planning docs)

## Accomplishments

- Onboarding-aware click geometry: `visibleContentZone()`/`positionAndShow()` correctly size and hit-test the taller onboarding card without reintroducing the CR-01 click-through regression
- Real per-row permission requests: each Permissions row's Grant independently triggers its own live Bluetooth/Calendar/Location system prompt via the controller's existing permission-request functions
- Settings hand-off (license entry / Buy Islet) and Finish (persist + collapse + start deferred monitors) fully wired
- 5-round on-device visual redesign of the carousel against a Droppy reference, with `26-UI-SPEC.md` kept truthful after every round
- Two real, non-visual bugs found and fixed during UAT: an outer-frame height-clipping regression (same class as a prior Phase-21 bug) and a Settings-window auto-restore-at-launch bug
- A genuine SwiftUI/AppKit launch-time reentrancy crash (Xcode's "Publishing changes from within view updates" trap) root-caused and fixed at the source, not silenced

## Task Commits

1. **Task 1: Onboarding-aware click geometry + collapse guards + panel sizing** - `207a4ce` (feat)
2. **Task 2: Step/permission/settings/finish handlers + hosting-view wiring** - `0149e22` (feat)
3. **Task 3: On-device UAT (checkpoint, 7 rounds)** - see Deviations below for the full round-by-round commit list

**Plan metadata:** this file + STATE.md/ROADMAP.md update commit

## Files Created/Modified

- `Islet/Notch/NotchWindowController.swift` - onboarding-aware `visibleContentZone()`/`positionAndShow()`, `handleClick()`/`handleHoverExit()` guards, `advanceOnboarding()`/`grantOnboardingPermission()`/`openOnboardingSettings()`/`finishOnboarding()`, deferred launch-time phase/click-through priming (round 7 crash fix)
- `Islet/Notch/NotchPillView.swift` - `onboardingCarousel(_:)` + all 4 step views, `blobShape()` width/height override params, outer body frame clipping fix, 5 rounds of visual redesign (centering, pill rows, circular nav, glow)
- `Islet/IsletApp.swift` - `.defaultLaunchBehavior(.suppressed)` on the Settings `Window` scene
- `project.yml` / `Islet.xcodeproj/project.pbxproj` - deployment target 14.0 -> 15.0 (required for `.defaultLaunchBehavior`)
- `.planning/phases/26-onboarding-flow/26-UI-SPEC.md` - updated after every visual-revision round to match shipped code
- `.planning/phases/26-onboarding-flow/26-04-PLAN.md` - Task 3 reset instructions corrected to include the Keychain trial-date reset
- `.planning/PROJECT.md` - new Key Decisions row logging the macOS 15.0 deployment floor revision

## Decisions Made

See `key-decisions` in frontmatter above — five decisions, all made during on-device UAT and documented at the point of discovery: the Task 3 test-setup gap, the outer-frame clipping bug, the 5-round visual redesign superseding the original locked UI-SPEC, the Settings-restoration bug + deployment-target bump, and the launch-time reentrancy fix.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking, test setup] Task 3 how-to-verify reset instructions missing a Keychain reset**
- **Found during:** First Task 3 retest attempt — onboarding never showed despite a "fresh install" reset
- **Issue:** `TrialManager.recordFirstLaunchIfNeeded()` is Keychain-backed and deliberately survives `defaults delete` (D-10); the plan's reset steps only cleared UserDefaults/TCC
- **Fix:** Added `security delete-generic-password -s com.lippi304.islet.trial -a trialStartDate` to the reset instructions; documented why the app's own "Debug: Reset Trial" menu action can't substitute (it re-arms immediately)
- **Files modified:** `.planning/phases/26-onboarding-flow/26-04-PLAN.md`
- **Committed in:** `da64871`

**2. [Rule 1 - Bug] Onboarding card clipped — outer body frame didn't grow for the `.onboarding` case**
- **Found during:** Task 3 round 1 on-device UAT
- **Issue:** `onboardingCarousel`'s `blobShape` correctly grew to `onboardingSize.height`, but `NotchPillView.body`'s outer `.frame()` still only accounted for `expandedSize.height` + shelf — the exact clipping regression class already fixed once for the shelf row (Phase 21), not propagated to the new onboarding case. Clipped the bottom corner radius (squared-off look) and made Next unreachable
- **Fix:** Added `isOnboardingPresentation` and branched the outer frame's height (later also width) on it
- **Files modified:** `Islet/Notch/NotchPillView.swift`
- **Committed in:** `a1496b2`

**3. [Rule 4-adjacent, explicit user direction each round] 5-round visual redesign of the onboarding carousel vs. Droppy reference**
- **Found during:** Task 3 rounds 2-5
- **Issue/request:** User compared against a competitor app ("Droppy") and requested, round by round: wider margins + centered text (round 2), a vertically-centered content layout with a fixed-position nav row (round 3, also fixed a real nav-Y cross-step inconsistency bug), a centered Done toggle + checkmark-only granted state (round 4), a static green border+glow on granted rows (round 5)
- **Fix:** Implemented each round; `26-UI-SPEC.md` updated after every round so the locked design contract never silently diverged from shipped code
- **Files modified:** `Islet/Notch/NotchPillView.swift`, `.planning/phases/26-onboarding-flow/26-UI-SPEC.md`
- **Committed in:** `4a9a482`/`1832ae4` (round 2), `9f77dd6`/`1ecdc00` (round 3), `a3217de`/`e6504ef` (round 4), `b02fbc1`/`5f1a504` (round 5)

**4. [Rule 1 - Bug] Settings window re-opening automatically at launch**
- **Found during:** Task 3 round 6 on-device UAT
- **Issue:** AppKit's own window-state restoration re-showed the Settings `Window(id:)` scene at launch, independent of `AppDelegate`'s already-correct `hideSettingsWindowOnLaunch()` — surfaced by repeated Xcode Stop/Cmd-R cycles during this UAT session leaving stale restoration state
- **Fix:** `.defaultLaunchBehavior(.suppressed)` on the Settings scene (macOS 15+ only; SwiftUI's `SceneBuilder` has no `if #available`/type-eraser path, so this required bumping the deployment target 14.0 -> 15.0 across `project.yml`, user-approved and logged as a revised Key Decision in `PROJECT.md`)
- **Files modified:** `Islet/IsletApp.swift`, `project.yml`, `Islet.xcodeproj/project.pbxproj`, `.planning/PROJECT.md`
- **Committed in:** `2a875ec`, `8d09324`

**5. [Rule 1 - Bug] Xcode-only crash: "Publishing changes from within view updates"**
- **Found during:** Task 3 round 7 on-device UAT
- **Issue:** `NotchWindowController.start()` runs synchronously inside `AppDelegate.applicationDidFinishLaunching`, which fires while SwiftUI's own App/Scene graph is still mid-setup for launch. `interaction.phase = .expanded` was the one `@Published` mutation Phase 26 added directly to that synchronous path, racing SwiftUI's in-flight launch transaction and tripping Xcode's SwiftUI Runtime Issue breakpoint
- **Fix:** Deferred exactly that mutation + its trailing `syncClickThrough()` to the next main run-loop turn via `DispatchQueue.main.async`, scoped to the two calls that were genuinely new to this path — not a blanket wrapper. Verified via headless reset+relaunch reproduction attempts (didn't reproduce outside Xcode's more heavily-instrumented debug launch, consistent with a timing-sensitive reentrancy race) and a full clean rebuild
- **Files modified:** `Islet/Notch/NotchWindowController.swift`
- **Committed in:** `767c862`

---

**Total deviations:** 5 auto-fixed (1 test-setup gap, 2 real bugs, 1 multi-round explicit-direction visual redesign, 1 launch-time reentrancy crash)
**Impact on plan:** All fixes were necessary for the plan's own stated success criteria (a working, on-device-verified onboarding flow); the visual redesign was explicit, requested, round-by-round user direction rather than scope creep, and the UI-SPEC was kept in sync throughout. No functional deviation from the plan's Task 1/Task 2 architecture.

## Issues Encountered

None beyond what's documented in Deviations above — every round's root cause was found and fixed at the source (no silenced warnings, no bandaid `DispatchQueue.main.async` wraps without a traced reason).

## User Setup Required

None - no external service configuration required. (The macOS 15.0 deployment target bump was a project-config change, not an external service — approved by the user in-session.)

## Next Phase Readiness

- Phase 26 (Onboarding Flow) is code-complete and on-device UAT approved across all 4 steps, all 3 requirements (ONBOARD-01/02/03)
- `26-UI-SPEC.md` accurately reflects shipped visuals (400 -> 420 width, 300 -> 320 height, centered text, pill rows, circular nav, glow) for any future iteration
- Deployment target is now macOS 15.0 project-wide — future phases can rely on `.defaultLaunchBehavior` and other macOS-15+ APIs without an availability guard
- No known blockers for Phase 27 (Settings Sidebar Redesign) or Phase 28 (Calendar Full View)

---
*Phase: 26-onboarding-flow*
*Completed: 2026-07-12*
