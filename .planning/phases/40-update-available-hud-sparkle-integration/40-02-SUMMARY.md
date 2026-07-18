---
phase: 40-update-available-hud-sparkle-integration
plan: 02
subsystem: ui
tags: [swiftui, notch-pill, badge, sparkle, hud]

# Dependency graph
requires:
  - phase: 40-update-available-hud-sparkle-integration (Plan 01)
    provides: UpdateAvailableState carrier + onUpdateBadgeTapped closure wired to Sparkle's checkForUpdates(nil)
provides:
  - shouldShowUpdateBadge(updateAvailable:isExpanded:) pure gate in NotchPillView.swift
  - Collapsed-only corner badge overlay on NotchPillView's body, themed with nowPlayingAccent
  - Real UpdateAvailableState/onUpdateBadgeTapped threaded from NotchWindowController.makeRootView
affects: [40-03-on-device-verification]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Overlay attached to the shared outer ZStack container (not inside any IslandPresentation case body) renders identically across every presentation case — same technique available for any future cross-cutting badge/indicator"

key-files:
  created: []
  modified:
    - Islet/Notch/NotchPillView.swift
    - Islet/Notch/NotchWindowController.swift
    - IsletTests/NotchPillViewTests.swift

key-decisions:
  - "updateAvailableState/onUpdateBadgeTap given defaults on NotchPillView (unlike every other @ObservedObject/closure in the struct, which are non-defaulted and explicitly passed at all ~13 #Preview call sites) — the badge is purely additive to every existing preview scenario, so defaulting avoids touching 13 preview blocks for zero behavioral gain; NotchWindowController.makeRootView still passes the real objects"
  - "New constructor arguments inserted in property DECLARATION order (right after shelfViewState), not appended at the call site's end — NotchPillView has no explicit init, so Swift's synthesized memberwise initializer requires call-site argument order to match declaration order"

requirements-completed: [HUD-06]

# Metrics
duration: ~20min
completed: 2026-07-18
---

# Phase 40 Plan 02: Update-Available Badge Wiring Summary

**Collapsed-only, theme-accented corner badge on the notch pill, gated by a pure `shouldShowUpdateBadge` function and wired to Sparkle's real `checkForUpdates(nil)` via the live `NotchWindowController` instance.**

## Performance

- **Duration:** ~20 min
- **Tasks:** 2 completed
- **Files modified:** 3

## Accomplishments
- `shouldShowUpdateBadge(updateAvailable:isExpanded:)` — pure top-level function in `NotchPillView.swift`, `updateAvailable && !isExpanded`, covered by a 4-case truth table
- Badge overlay (`Image(systemName: "arrow.up.circle.fill")`) attached to `body`'s outer `ZStack` via `.overlay(alignment: .topTrailing)`, gated on presence (not opacity), renders across every `IslandPresentation` case (D-05) and never while expanded (D-06)
- Badge reuses the existing `nowPlayingAccent` environment value for its color — no new `EnvironmentKey` (D-07)
- Tap forwards to `onUpdateBadgeTap()`, threaded in `NotchWindowController.makeRootView` to the real `onUpdateBadgeTapped` closure from Plan 01 (→ Sparkle's `checkForUpdates(nil)`) (D-08)
- All 13 existing `#Preview` blocks in `NotchPillView.swift` compile unmodified — the new properties default to a fresh `UpdateAvailableState()` and a no-op closure

## Task Commits

Each task was committed atomically:

1. **Task 1: Badge overlay on NotchPillView (D-05/D-06/D-07/D-08)** - `6a2fe53` (feat)
2. **Task 2: Wire the real state into NotchWindowController's live NotchPillView instance** - `5390407` (feat)

## Files Created/Modified
- `Islet/Notch/NotchPillView.swift` - `shouldShowUpdateBadge` pure function; `updateAvailableState`/`onUpdateBadgeTap` defaulted properties; `.overlay(alignment: .topTrailing)` badge on `body`
- `Islet/Notch/NotchWindowController.swift` - `makeRootView` now passes `updateAvailableState: updateAvailableState, onUpdateBadgeTap: { [weak self] in self?.onUpdateBadgeTapped() }` into the live `NotchPillView` instance
- `IsletTests/NotchPillViewTests.swift` - 4 new test methods covering all `(updateAvailable, isExpanded)` combinations for `shouldShowUpdateBadge`

## Decisions Made
- Kept the badge overlay attached to the same container as `presentationSwitch` (not duplicated into each `IslandPresentation` case), exactly as the plan specified, so it can never drift out of sync with a future new presentation case.
- Inserted the two new `NotchPillView` constructor arguments at the call site in property-declaration order (after `shelfViewState`, before `onboardingState`) rather than after `onQuickAdd` as the plan's illustrative snippet showed — required because `NotchPillView` has no explicit `init`, so the compiler-synthesized memberwise initializer enforces declaration order for labeled arguments. Confirmed via a build attempt with the plan's literal snippet order, which failed to compile; corrected order builds clean. Documented in code comment at the call site.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Constructor argument order in NotchWindowController's NotchPillView call**
- **Found during:** Task 2 (`xcodebuild build -scheme Islet -configuration Debug`)
- **Issue:** The plan's illustrative snippet placed `updateAvailableState:`/`onUpdateBadgeTap:` immediately after `onQuickAdd:` (the last parameter in declaration order). `NotchPillView` has no custom `init`, so Swift's synthesized memberwise initializer requires call-site labeled arguments to appear in the exact order the properties are declared in the struct — and Task 1 (per the plan's own instruction) declared `updateAvailableState`/`onUpdateBadgeTap` right after `shelfViewState`, near the top of the struct, not at the end.
- **Fix:** Moved the two new arguments in the `NotchPillView(...)` call to immediately follow `shelfViewState:`, matching the struct's actual property order.
- **Files modified:** `Islet/Notch/NotchWindowController.swift`
- **Verification:** `xcodebuild build -scheme Islet -configuration Debug` exits 0.
- **Committed in:** `5390407` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 bug — argument-order correction required for the plan's own literal acceptance criteria to compile)
**Impact on plan:** Purely a call-site ordering fix; no change to the properties themselves, the badge behavior, or scope. Necessary to make Task 2 buildable at all.

## Issues Encountered
None beyond the deviation above.

## User Setup Required

None - no external service configuration required this plan.

## Next Phase Readiness

- The badge renders and taps through to the real Sparkle check end-to-end; Plan 03 only needs
  to verify this on-device (visual placement, tap non-activation, theme-accent correctness) using
  Plan 01's `docs/appcast-mock.xml`.
- No blockers.

---
*Phase: 40-update-available-hud-sparkle-integration*
*Completed: 2026-07-18*
