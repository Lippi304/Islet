---
phase: 31-shelf-consolidation-to-tray-only
plan: 01
subsystem: ui
tags: [swiftui, xctest, click-through, notch-panel]

# Dependency graph
requires:
  - phase: quick-260714-3k6
    provides: shelfStripVisible gate + visibleContentZone() simplification (the behavior this plan verifies and locks)
provides:
  - "IsletTests/NotchPillViewTests.swift - regression lock (testShelfStripVisibleIsAlwaysFalse) preventing TRAY-01's Tray-only shelf gate from silently regressing"
  - "shelfStripVisible access bumped private -> internal (testability only, value/behavior unchanged)"
  - "On-device confirmation that the shipped shelfStripVisible/visibleContentZone() change has no CR-01-class click-through regression"
  - "TRAY-01 formally marked delivered in ROADMAP.md/REQUIREMENTS.md, crediting quick task 260714-3k6"
affects: [32-tray-widening]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Access-level-for-testability bump (private -> internal, no explicit internal keyword) mirroring EqualizerBars.makeProfiles() precedent"

key-files:
  created:
    - IsletTests/NotchPillViewTests.swift
  modified:
    - Islet/Notch/NotchPillView.swift
    - Islet.xcodeproj/project.pbxproj
    - .planning/ROADMAP.md
    - .planning/REQUIREMENTS.md

key-decisions:
  - "shelfStripVisible's private -> internal bump is the only source touch, per D-03 - implementation shape (hardcoded false) untouched"
  - "Test class marked @MainActor (Rule 1 fix, not in original plan) - NotchPillView's constructor args include @MainActor-isolated initializers (e.g. BasicOutfitState), so a synchronous nonisolated test function failed to compile without it; matches ShelfViewStateTests/ShelfCoordinatorTests convention already in the codebase"
  - "Tray panel vertical oversizing (excess black space between file row and icon row) found during the on-device checkpoint is out of scope for this plan (D-01/D-05) - captured as a standalone todo for Phase 32 or a follow-up quick task, not fixed here"

patterns-established: []

requirements-completed: [TRAY-01]

# Metrics
duration: ~25min
completed: 2026-07-14
---

# Phase 31 Plan 01: Verify-and-Close Shelf Consolidation Summary

**Locked the already-shipped shelfStripVisible=false gate with an XCTest regression test, confirmed on-device that its click-through hit-testing has no CR-01-style dead-click regression, and formally closed TRAY-01**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-07-14T02:35:00Z (approx, first task commit)
- **Completed:** 2026-07-14T04:41:00Z (final docs commit)
- **Tasks:** 3
- **Files modified:** 5 (2 source, 1 project file, 2 planning docs)

## Accomplishments

- `shelfStripVisible` (already hardcoded `{ false }` since quick task 260714-3k6) bumped from `private` to internal access, following the exact `EqualizerBars.makeProfiles()` precedent already established in the same file, so a test can assert it directly under `@testable import`
- New `IsletTests/NotchPillViewTests.swift` with `testShelfStripVisibleIsAlwaysFalse` — a permanent regression lock; both `xcodebuild build` and `xcodebuild build-for-testing` pass
- User approved the full 5-step on-device CR-01-class hover→expand→move-down click-through trace on Home/Calendar/Weather/Tray with an empty and populated shelf — no dead-click zone, no unexpected collapse, no phantom click-swallowing; no contingency fix was needed
- TRAY-01 formally marked delivered in ROADMAP.md (Phase 31 checklist + v1.5 progress 2/6→3/6) and REQUIREMENTS.md (checklist + traceability table), crediting quick task 260714-3k6 as the implementation source

## Task Commits

Each task was committed atomically:

1. **Task 1: Access-level bump + shelfStripVisible regression test** - `ce6417d` (test)
2. **Task 2: On-device CR-01-class click-through trace** - checkpoint, no code commit (user approved, no contingency fix needed)
3. **Task 3: Formal closeout — mark TRAY-01 delivered** - `d424d05` (docs)

## Files Created/Modified

- `Islet/Notch/NotchPillView.swift` - `shelfStripVisible` access bumped `private` → internal (default), comment added citing the new test and the `makeProfiles()` precedent; value/body/call-sites untouched
- `IsletTests/NotchPillViewTests.swift` - new file, `@MainActor final class NotchPillViewTests`, single `testShelfStripVisibleIsAlwaysFalse()` assertion using the `#Preview`'s 8-argument construction
- `Islet.xcodeproj/project.pbxproj` - regenerated via `xcodegen generate` to register the new test file (this project uses an explicit XcodeGen-managed file list, not synchronized groups)
- `.planning/ROADMAP.md` - Phase 31 checked off with completion date; v1.5 progress line bumped 2/6→3/6 (50%); Phase 31 detail section's Plans line and checklist flipped to complete
- `.planning/REQUIREMENTS.md` - TRAY-01 checklist item checked off; traceability table row flipped Pending→Complete

## Decisions Made

- The access-level bump is the only permitted source change per D-03 (Swift access control, not the hardcoded-`false` implementation shape) — confirmed correct, no further discussion needed
- Test class required `@MainActor` (not specified in the plan's interfaces) because `NotchPillView`'s constructor takes several `@MainActor`-isolated `ObservableObject` initializers (e.g. `BasicOutfitState()`); the same pattern already exists in `ShelfViewStateTests`/`ShelfCoordinatorTests`, so this was a straightforward Rule 1 auto-fix, not a new pattern
- The Tray-panel vertical-oversizing observation from the on-device checkpoint was deliberately NOT fixed here — it's a pure visual/sizing issue unrelated to click-through correctness, explicitly out of scope per D-01 (verify-and-close only)/D-05 (trayFullView confirmed untouched); captured as `.planning/todos/pending/2026-07-14-tray-panel-oversized-vertically-shrink-to-fit-content.md` for Phase 32 or a follow-up quick task

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Test class needed `@MainActor` to compile**
- **Found during:** Task 1, `xcodebuild build-for-testing` gate
- **Issue:** `testShelfStripVisibleIsAlwaysFalse()` constructs `NotchPillView` with `BasicOutfitState()` and other `@MainActor`-isolated initializers; without `@MainActor` on the test class, the compiler rejected the synchronous call from a nonisolated context (`call to main actor-isolated initializer 'init()' in a synchronous nonisolated context`)
- **Fix:** Added `@MainActor` to `NotchPillViewTests`, mirroring the existing `ShelfViewStateTests`/`ShelfCoordinatorTests`/`DeviceCoordinatorTests`/`NotchPanelTests` convention in the same test suite
- **Files modified:** `IsletTests/NotchPillViewTests.swift`
- **Verification:** `xcodebuild build-for-testing -scheme Islet` reports TEST BUILD SUCCEEDED; `xcodebuild build -scheme Islet` reports BUILD SUCCEEDED
- **Committed in:** `ce6417d` (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - compile-blocking bug, immediately visible from the build gate, not a design change)
**Impact on plan:** No scope creep — the fix is purely mechanical (an actor-isolation annotation matching an existing codebase convention), does not touch `shelfStripVisible`'s value or any call site.

## Issues Encountered

None beyond the deviation above. The plan's acceptance criterion cited `xcodebuild build` (not `build-for-testing`) as the gate; that command alone does not compile the `IsletTests` target under this project's scheme configuration (`IsletTests: [test]`, not `all`), so `build-for-testing` was additionally run to actually prove the new test file compiles — this surfaced the `@MainActor` issue above before the on-device checkpoint, as intended by Task 1's `done` criteria.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- TRAY-01 is fully closed: shipped (quick task 260714-3k6), regression-locked (this plan's Task 1), and on-device verified with no CR-01-class regression (this plan's Task 2).
- Phase 32 (Tray Widening) can proceed against `visibleContentZone()` touched only once so far, per the dependency note in ROADMAP.md.
- One new pending todo (Tray panel vertical oversizing — excess black space, files peeking over the icon row) is available for Phase 32's planning or an earlier standalone quick task; not a blocker.

---
*Phase: 31-shelf-consolidation-to-tray-only*
*Completed: 2026-07-14*

## Self-Check: PASSED

- FOUND: IsletTests/NotchPillViewTests.swift
- FOUND: commit ce6417d
- FOUND: commit d424d05
- FOUND: .planning/todos/pending/2026-07-14-tray-panel-oversized-vertically-shrink-to-fit-content.md
