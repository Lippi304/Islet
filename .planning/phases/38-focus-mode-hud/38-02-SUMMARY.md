---
phase: 38-focus-mode-hud
plan: 02
subsystem: resolver
tags: [swift, xctest, tdd, island-resolver, pure-logic]

requires:
  - phase: 06-priority-resolver-settings-v1-ship
    provides: IslandResolver.swift / TransientQueue (the single arbiter this plan extends)
provides:
  - "FocusActivity.swift: pure Foundation-only FocusActivity enum + focusActivity(from:) TOTAL mapping"
  - "IslandResolver.swift: ActiveTransient.focus(FocusActivity), IslandPresentation.focus(FocusActivity)"
  - "ActiveTransient.isPersistent (true only for .focus) — the D-06 auto-dismiss-skip seam"
  - "TransientQueue.preempt(_:) — D-08 immediate front-of-pending preemption"
  - "resolve(...)'s where-guarded .focus case — D-07 collapsed-only win"
affects: [38-03-focus-mode-monitor, 38-04-focus-hud-view, 38-05-controller-wiring]

tech-stack:
  added: []
  patterns:
    - "Pure Foundation-only presentation seam (mirrors PowerActivity.swift / DeviceActivity.swift): plain enum + TOTAL mapping function, no system frameworks, unit-tested with hand-built values"
    - "TransientQueue additive-method extension (preempt alongside enqueue) rather than modifying existing FIFO semantics"

key-files:
  created:
    - Islet/Notch/FocusActivity.swift
    - IsletTests/FocusActivityTests.swift
  modified:
    - Islet/Notch/IslandResolver.swift
    - IsletTests/IslandResolverTests.swift
    - Islet/Notch/NotchWindowController.swift
    - Islet/Notch/NotchPillView.swift

key-decisions:
  - "preempt(_:) implemented as an additive TransientQueue method (guard case .focus = head else { enqueue(t) }) rather than modifying enqueue(_:) — enqueue(_:) verified byte-identical via git diff"
  - "Compiler-forced non-exhaustive-switch fixes in NotchWindowController.swift and NotchPillView.swift were made minimally (chargingState clear + EmptyView() stub) rather than building any real Focus HUD view, staying inside this plan's pure-logic-only scope"

patterns-established:
  - "Focus HUD view rendering is deferred to a later plan (38-04/38-05) — NotchPillView's presentationSwitch has a placeholder .focus -> EmptyView() case marked with a comment, not a real implementation"

requirements-completed: [HUD-05]

duration: ~15min
completed: 2026-07-17
---

# Phase 38 Plan 02: Focus Transient Resolver/Queue Logic Summary

**Pure Foundation-only FocusActivity seam plus IslandResolver/TransientQueue extensions (collapsed-only win, non-self-dismissing persistence flag, front-of-pending preemption) — all verified failing-first, zero AppKit/system-framework code.**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-07-17T01:52:00+02:00
- **Completed:** 2026-07-17T01:57:00+02:00
- **Tasks:** 2
- **Files modified:** 6 (2 created, 4 modified)

## Accomplishments

- `FocusActivity.swift` — a single-case `FocusActivity` enum (`.on`, no `.off`, no named-mode payload per D-09/Out-of-Scope) plus the TOTAL `focusActivity(from:)` mapping, mirroring `PowerActivity.swift`'s file-header/doc-comment discipline exactly.
- `IslandResolver.swift` extended with `ActiveTransient.focus(FocusActivity)` / `IslandPresentation.focus(FocusActivity)`, a `where`-guarded `resolve(...)` case (`case .focus(let f) where !isExpanded: return .focus(f)`) that proves D-07's collapsed-only win falls through cleanly to the existing `isExpanded` branch when expanded, `ActiveTransient.isPersistent` (true only for `.focus`, D-06), and `TransientQueue.preempt(_:)` (D-08 — immediate front-of-pending displacement, `enqueue(_:)` untouched).
- Both tasks followed strict RED→GREEN discipline: tests written first, confirmed to fail via `xcodebuild build-for-testing` compile errors (the project's `xcodebuild test` hangs — see project convention), then minimal implementation added and the build confirmed green.

## Task Commits

Each task committed atomically as RED then GREEN (TDD discipline):

1. **Task 1: FocusActivity.swift pure seam**
   - `9905cfe` `test(38-02): add failing test for FocusActivity pure seam` (RED)
   - `9281267` `feat(38-02): implement FocusActivity pure seam` (GREEN)
2. **Task 2: IslandResolver.swift — new transient case, persistence flag, preemption, collapsed-only guard**
   - `379afcd` `test(38-02): add failing tests for Focus transient resolver/queue behavior` (RED)
   - `1ded108` `feat(38-02): add Focus transient case, persistence flag, preemption to IslandResolver` (GREEN)

## Files Created/Modified

- `Islet/Notch/FocusActivity.swift` — new pure model: `enum FocusActivity { case on }` + `focusActivity(from isFocused: Bool) -> FocusActivity?`
- `IsletTests/FocusActivityTests.swift` — 2 XCTest methods covering the total mapping matrix
- `Islet/Notch/IslandResolver.swift` — `ActiveTransient.focus`, `IslandPresentation.focus`, `ActiveTransient.isPersistent`, `TransientQueue.preempt(_:)`, the `where`-guarded `resolve(...)` case
- `IsletTests/IslandResolverTests.swift` — 4 new XCTest methods under a new `// MARK: Phase 38 / HUD-05` section
- `Islet/Notch/NotchWindowController.swift` — 1-line compiler-forced fix: `syncActivityModels()`'s switch over `transientQueue.head` gained a `.focus` case (clears `chargingState.activity`, mirroring `.device`)
- `Islet/Notch/NotchPillView.swift` — 1-case compiler-forced fix: `presentationSwitch`'s exhaustive switch over `IslandPresentation` gained a `.focus -> EmptyView()` placeholder, explicitly commented as a stub for a later plan (38-04/38-05 build the real Focus HUD wing view)

## Decisions Made

- `preempt(_:)` added as an ADDITIVE method next to `enqueue(_:)` rather than modifying the existing FIFO enqueue logic — `enqueue(_:)`'s body was verified byte-identical before/after via `git diff` (acceptance criterion explicitly required this).
- The two compiler-forced non-exhaustive-switch fixes were kept to the absolute minimum needed to keep `xcodebuild build` green (a one-line model-clear and an `EmptyView()` stub), preserving this plan's "zero AppKit, zero system frameworks, zero detection-path dependency" scope — no real Focus HUD view or system glue was built here.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Compiler-forced non-exhaustive-switch fix in `NotchWindowController.syncActivityModels()`**
- **Found during:** Task 2 (`xcodebuild build` after adding `ActiveTransient.focus`)
- **Issue:** Adding the new `ActiveTransient.focus` case made the existing `switch transientQueue.head { case .charging; case .device; case nil }` in `syncActivityModels()` non-exhaustive — build failed with "switch must be exhaustive".
- **Fix:** Added `case .focus: chargingState.activity = nil`, mirroring the existing `.device` case's behavior (Focus is not the charging category, so any standing charging model must be cleared).
- **Files modified:** `Islet/Notch/NotchWindowController.swift`
- **Verification:** `xcodebuild build -configuration Debug` succeeds after the fix.
- **Committed in:** `1ded108` (Task 2 commit)

**2. [Rule 3 - Blocking] Compiler-forced non-exhaustive-switch fix in `NotchPillView.presentationSwitch`**
- **Found during:** Task 2 (`xcodebuild build` after adding `IslandPresentation.focus`)
- **Issue:** Adding `IslandPresentation.focus` made `presentationSwitch`'s exhaustive switch over `IslandPresentation` non-exhaustive — build failed.
- **Fix:** Added a `case .focus: EmptyView()` branch with a comment explicitly marking it as a compiler-forced stub only — the real Focus HUD wing view is out of this plan's pure-logic-only scope and belongs to a later plan (38-04/38-05).
- **Files modified:** `Islet/Notch/NotchPillView.swift`
- **Verification:** `xcodebuild build -configuration Debug` succeeds after the fix; the plan's own acceptance criteria explicitly anticipated this exact class of fix ("if the build fails with a non-exhaustive-switch error anywhere else, that is expected and must be fixed as part of this task").
- **Committed in:** `1ded108` (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (both Rule 3 - blocking, compiler-forced, explicitly anticipated by the plan text)
**Impact on plan:** Both fixes are minimal, additive, and stay inside the plan's pure-logic scope — no real Focus HUD view or system glue was built ahead of schedule. No scope creep.

## Issues Encountered

None beyond the two anticipated compiler-forced fixes above.

## Manual Verification Still Needed

Per project convention (`xcodebuild test` hangs in this environment — a Bluetooth TCC-authorization wait in `BluetoothMonitor`, see `.planning/phases/09-fullscreen-flash-window-space-retry/deferred-items.md`), the automated gate used throughout this plan was `xcodebuild build-for-testing` / `xcodebuild build`, NOT `xcodebuild test`. All 6 new test methods (2 in `FocusActivityTests`, 4 in `IslandResolverTests`) compile and are believed correct by construction (RED confirmed via compile failure referencing the not-yet-existing symbols; GREEN confirmed via successful build), but **actually running them has not been verified in this session**. The user should run the full suite via Cmd-U in Xcode to confirm all 6 new tests plus the full pre-existing suite pass before this plan is considered fully done.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- The resolver/queue pipeline now has real, tested state to arbitrate for Focus Mode HUD (D-06/D-07/D-08 all covered), independent of Plan 38-01's detection-path spike outcome.
- Plan 38-03 (FocusModeMonitor, system glue) can now feed a `Bool` into `focusActivity(from:)` to produce real `FocusActivity` values.
- Plan 38-04/38-05 must replace the `NotchPillView` `.focus -> EmptyView()` stub with the real Focus HUD wing view and wire the controller to read `ActiveTransient.isPersistent` (skip the 3s auto-dismiss) and call `TransientQueue.preempt(_:)` instead of `enqueue(_:)` for Charging/Device when Focus is the standing head.
- Manual Cmd-U verification of the 6 new tests (see "Manual Verification Still Needed" above) is a pending, non-blocking follow-up for the user.

---
*Phase: 38-focus-mode-hud*
*Completed: 2026-07-17*
