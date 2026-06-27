---
phase: 03-charging-activity
plan: 01
subsystem: power
tags: [power, iokit, charging, tdd, geometry, swift, xctest]

# Dependency graph
requires:
  - phase: 01-the-empty-island-window-geometry
    provides: NotchGeometry pure seam (notchFrame/expandedNotchFrame center-on-midX + pin-to-top contract that wingsFrame extends)
  - phase: 02-hover-expand-fullscreen-hardening
    provides: NotchInteractionState 3-state machine + ObservableObject pattern (ChargingActivityState mirrors it; left untouched per Pattern 2)
provides:
  - "PowerActivity.swift — pure power→presentation seam: PowerReading struct, ChargingActivity enum, powerActivity(from:) total mapping, shouldTriggerSplash(previous:next:) category-transition debounce"
  - "ChargingActivityState — ObservableObject publishing ChargingActivity? as a SEPARATE model (Pattern 2, not a new InteractionPhase case)"
  - "NotchGeometry.wingsFrame(collapsed:wingsSize:) — wide/flat sideways frame for the wings layout"
  - "PowerActivityTests + NotchGeometryTests wings cases — full classification/clamp/debounce + wings-geometry coverage"
affects: [03-02 wings layout, 03-03 IOKit PowerSourceMonitor + panel sizing, charging splash view]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Pure power→presentation seam (no IOKit/AppKit/SwiftUI) mirroring NotchGeometry/NotchInteractionState — riskiest classification logic is unit-tested in ms"
    - "Pattern 2: charging splash as a separate @Published ChargingActivity? model, NOT folded into the user-gesture phase enum — keeps the Phase-2 3-state machine + its tests intact"
    - "Category-transition splash debounce (Pitfall 4): fires only on charging/full/onBattery kind change, ignores pure percent ticks"

key-files:
  created:
    - Islet/Notch/PowerActivity.swift
    - Islet/Notch/ChargingActivityState.swift
    - IsletTests/PowerActivityTests.swift
  modified:
    - Islet/Notch/NotchGeometry.swift
    - IsletTests/NotchGeometryTests.swift

key-decisions:
  - "powerActivity(from:) returns nil when no battery is present (desktop/empty source list) → graceful no-op splash"
  - "Percent clamped via min(max(r.percent,0),100) so a malformed IOPS reading can never produce an out-of-range value (T-03-01 mitigated)"
  - "shouldTriggerSplash compares an internal percent-ignoring SplashCategory: nil→activity fires, activity→nil does not (clearing is not a new splash)"
  - "wingsFrame uses the IDENTICAL center-on-midX + pin-to-top contract as expandedNotchFrame; wings seed 360x40 keeps the union with the 360x72 expanded frame stable (Pattern 4 — no mid-animation resize)"

patterns-established:
  - "Pure framework-free seam first (Nyquist/Wave-0): classification + geometry are total functions verified before any IOKit/AppKit wiring exists"
  - "Pattern 2 separate published activity model alongside the untouched interaction machine"

requirements-completed: [CHG-01, CHG-02]

# Metrics
duration: 4min
completed: 2026-06-27
---

# Phase 3 Plan 01: Charging Power→Presentation & Wings Geometry Seam Summary

**Pure, unit-tested power→presentation seam (PowerReading → ChargingActivity, clamped, nil-on-no-battery, category-transition splash debounce) plus a separate ChargingActivityState model and a wingsFrame geometry extension — the contracts every later Phase-3 wave implements against.**

## Performance

- **Duration:** ~4 min
- **Started:** 2026-06-27T16:21:42Z
- **Completed:** 2026-06-27T16:25:31Z
- **Tasks:** 2
- **Files modified:** 5 (3 created, 2 modified)

## Accomplishments
- `PowerActivity.swift` — the PURE classification seam: `PowerReading` struct, three-case `ChargingActivity` enum (D-04), the total `powerActivity(from:)` mapping (charging vs full vs onBattery vs nil), and the `shouldTriggerSplash(previous:next:)` category-transition debounce. Imports only Foundation — no IOKit/AppKit/SwiftUI.
- `ChargingActivityState` — an `ObservableObject` publishing `ChargingActivity?` as a SEPARATE model (Pattern 2), leaving the Phase-2 hover/click/grace 3-state machine and all its tests untouched.
- `NotchGeometry.wingsFrame(collapsed:wingsSize:)` — the wide/flat sideways frame, centered on the collapsed pill's midX and pinned to the top edge, mirroring `expandedNotchFrame` exactly.
- Full RED→GREEN XCTest coverage: 12 `PowerActivityTests` (the locked classification matrix, percent clamp low/high, no-battery nil, and the five splash-debounce edges) + 3 new `wingsFrame` cases. Whole suite green: **68 tests, 0 failures.**

## Task Commits

Each task was committed atomically:

1. **Task 1 (TDD): pure power→presentation seam** — RED `3305ae0` (test) → GREEN `be30a6b` (feat)
2. **Task 2: ChargingActivityState model + wingsFrame geometry** — `265cc68` (feat)

**Plan metadata:** committed separately (docs: complete plan) after this SUMMARY.

_Note: Task 1 is TDD (test → feat); no refactor commit was needed — the GREEN implementation was already minimal._

## Files Created/Modified
- `Islet/Notch/PowerActivity.swift` (created) - PowerReading, ChargingActivity, powerActivity(from:), shouldTriggerSplash(previous:next:) — pure seam, Foundation-only
- `Islet/Notch/ChargingActivityState.swift` (created) - `final class ChargingActivityState: ObservableObject { @Published var activity: ChargingActivity? }` (Pattern 2)
- `IsletTests/PowerActivityTests.swift` (created) - 12 tests: classification matrix + clamp + no-battery nil + 5 debounce edges
- `Islet/Notch/NotchGeometry.swift` (modified) - appended `wingsFrame(collapsed:wingsSize:)` after `expandedNotchFrame`
- `IsletTests/NotchGeometryTests.swift` (modified) - added `// MARK: wingsFrame (CHG-01)` with 3 cases (center+pin, non-zero origin, degenerate)

## Decisions Made
- **No-battery → nil:** `powerActivity(from:)` returns nil when `isPresent` is false, so a desktop or transient empty power-source list produces no splash rather than a bogus state.
- **Percent clamp:** `min(max(r.percent, 0), 100)` guards every output against a malformed IOPS reading (mitigates threat T-03-01; covered by testPercentClampedLow/High).
- **Debounce via percent-ignoring category:** an internal `SplashCategory` (none/charging/full/onBattery) is compared; the splash fires only on a kind change and never on a pure percent tick, and `nil→activity` fires while `activity→nil` does not (mitigates threat T-03-02).
- **wingsFrame seed 360x40:** chosen wide+flat so the union with the existing 360x72 expanded frame needs no runtime panel resize (Pattern 4), and so its contract is byte-identical to `expandedNotchFrame`.

## Deviations from Plan

None - plan executed exactly as written.

The only non-task edits were two documentation-comment rewordings in `PowerActivity.swift` and `ChargingActivityState.swift`: the original comments literally contained the strings `import IOKit` / `import AppKit` / `import SwiftUI` and `InteractionPhase`, which the plan's own acceptance-criteria `grep -c ... = 0` guards counted as matches. The comments were reworded to express the same purity constraint without the literal tokens. No code/behavior changed; the suite stayed green across both edits.

## Issues Encountered
- **Worktree base mismatch (resolved before any work):** this parallel worktree branch was initially created from an unrelated "Initial commit" rather than the feature-branch HEAD `032e32e`, so `.planning/` and `Islet/` were absent. Reset the branch onto `032e32e` (`reset --soft` then `reset --hard HEAD`) per the worktree_branch_check instructions; merge-base then matched and the full project tree was present. No work was lost.
- **`--no-verify` blocked:** a local `block-no-verify` pre-commit hook rejects the flag the parallel_execution instructions request. Committed with hooks enabled instead; all three commits succeeded cleanly.

## User Setup Required

None - no external service configuration required. This plan is pure Swift logic + unit tests; the IOKit read and the SwiftUI splash view land in later Phase-3 plans.

## Next Phase Readiness
- **Contracts locked for downstream Phase-3 waves:** Plan 02 (wings layout) consumes `wingsFrame` + `ChargingActivity`; Plan 03 (IOKit `PowerSourceMonitor` + panel sizing) lifts a `PowerReading` out of the IOPS dictionary, maps it via `powerActivity(from:)`, debounces with `shouldTriggerSplash`, and sets `ChargingActivityState.activity` on the main thread.
- The realistic security surface (IOKit ownership, `@convention(c)` context-pointer lifetime, main-thread hop) is deferred to Plan 03 and enumerated in its threat model — this plan is pure and carries only two all-low threats, both mitigated and tested.
- Full suite green (68 tests); the Phase-2 3-state machine is provably untouched (InteractionStateTests still pass).

## Self-Check: PASSED

- Created files verified on disk: PowerActivity.swift, ChargingActivityState.swift, PowerActivityTests.swift, 03-01-SUMMARY.md
- Modified files verified: NotchGeometry.swift, NotchGeometryTests.swift
- Commits verified in git log: 3305ae0 (test), be30a6b (feat), 265cc68 (feat)
- Full XCTest suite green: 68 tests, 0 failures

---
*Phase: 03-charging-activity*
*Completed: 2026-06-27*
