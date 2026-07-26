---
phase: 65-quick-actions-bar
plan: 04
subsystem: quick-actions-bar
tags: [swiftui, tdd, intents, focus-dnd]

requires:
  - phase: 65-01
    provides: QuickActionsBarCatalog.Action catalog contract this action slots into
  - phase: 38-focus-mode-hud
    provides: FocusModeMonitor.isAuthorized/requestAuthorization (reused verbatim, never duplicated)
provides:
  - FocusToggleAction.toggle(onResult:) — best-effort Focus/DND toggle with mandatory before/after INFocusStatusCenter read-back
  - FocusToggleAction.isConfirmedOn — live read for Plan 65-05's DND tile confirmed-on state
  - FocusToggleAction.focusStateChanged(before:after:) — pure comparison, unit-tested
  - FocusToggleAction.focusShortcutName — fixed Shortcut-name constant this mechanism depends on
affects: [65-05, 65-07]

tech-stack:
  added: []
  patterns:
    - "Isolate a fragile/uncertain OS surface (no public Focus write API) behind its own one-file seam, mirroring FocusModeMonitor.swift's own Intents isolation"
    - "Never trust a write call's lack of thrown error as success — always re-read the verification oracle (INFocusStatusCenter) before/after and compare, never assume"

key-files:
  created:
    - Islet/Notch/QuickActionsBar/FocusToggleAction.swift
    - IsletTests/FocusToggleActionTests.swift
  modified:
    - Islet.xcodeproj/project.pbxproj

key-decisions:
  - "@MainActor added to FocusToggleAction (Rule 3, blocking-issue fix, not in original plan interface): FocusModeMonitor.isAuthorized is itself MainActor-isolated, so the build fails without it. Matches the caller's real isolation (a UI tap) rather than working around it with MainActor.assumeIsolated."

requirements-completed: [QACTION-03]

duration: 15min
completed: 2026-07-26
---

# Phase 65 Plan 04: FocusToggleAction Summary

**Best-effort Do Not Disturb/Focus toggle via a fixed `/usr/bin/shortcuts run` invocation, whose success is reported only after re-reading `INFocusStatusCenter` before and after and confirming the live state actually changed — never inferred from the shell call's exit status alone**

## Performance

- **Duration:** ~15 min
- **Completed:** 2026-07-26
- **Tasks:** 1 completed
- **Files modified:** 3 (2 created, 1 modified — project.pbxproj)

## Accomplishments
- `FocusToggleAction.swift` created exactly per RESEARCH.md Pattern 2's target shape: `toggle(onResult:)` guards on `FocusModeMonitor.isAuthorized` first, snapshots Focus state before invoking the fixed `"Islet Toggle Focus"` Shortcut, then re-reads after a 0.5s settle delay and reports success only when the two reads genuinely differ (`focusStateChanged(before:after:)`)
- `isConfirmedOn` live read added for Plan 65-05's DND tile green "confirmed-on" icon state, isolating the `Intents` surface to this one file (Pattern 1) so `NotchPillView.swift` never imports `Intents` directly
- Pure `focusStateChanged(before:after:)` comparison extracted and unit-tested in isolation (TDD RED→GREEN), mirroring `MicMuteControllerTests`' "assert the one property that actually matters" discipline for code with no injectable seam
- Zero references to `ActivitySettings.focusKey` (Phase 38's unrelated ambient HUD toggle) — grep-verified at 0

## Task Commits

Each task was committed atomically, following the TDD RED/GREEN gate:

1. **Task 1 (TDD RED):** `29231dc` (test) — 4 XCTest cases added; confirmed genuinely RED by temporarily moving `FocusToggleAction.swift` out of the tree and re-running the build (`Build input file cannot be found` — a real compile failure, not a false-positive pass)
2. **Task 1 (TDD GREEN):** `f14069e` (feat) — `FocusToggleAction.swift` restored/implemented; all 4 tests pass, full-scheme build green

**Plan metadata:** _pending final docs commit_

## Files Created/Modified
- `Islet/Notch/QuickActionsBar/FocusToggleAction.swift` - New file: `toggle(onResult:)`, `isConfirmedOn`, `focusStateChanged(before:after:)`, `focusShortcutName`
- `IsletTests/FocusToggleActionTests.swift` - New file: 4 XCTest cases (2 pure comparison cases, 2 no-crash-when-unauthorized cases)
- `Islet.xcodeproj/project.pbxproj` - regenerated via `xcodegen generate` to register both new files in their build targets

## Decisions Made
- `@MainActor` added to `enum FocusToggleAction` and to `FocusToggleActionTests` (Rule 3 — blocking-issue auto-fix, not specified in the plan's interface excerpt): `FocusModeMonitor.isAuthorized` is itself `@MainActor`-isolated (per `FocusModeMonitor.swift`'s own class-level annotation), so the plan's exact RESEARCH.md Code Example failed to compile without it. Matches every real call site (a Quick Actions Bar tap is always on the main actor) rather than working around the isolation with `MainActor.assumeIsolated`. Mirrors the project's existing `DeviceCoordinatorTests`/`NotchPillViewTests` precedent for `@MainActor`-marked test classes.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking build error] Added `@MainActor` to `FocusToggleAction` and its test class**
- **Found during:** Task 1, first build attempt
- **Issue:** `FocusModeMonitor.isAuthorized` is `@MainActor`-isolated; `FocusToggleAction.toggle(onResult:)` referenced it from a nonisolated context, causing a compile error (`main actor-isolated static property 'isAuthorized' can not be referenced from a nonisolated context`)
- **Fix:** Marked `enum FocusToggleAction` `@MainActor` (matches its only real caller context — a UI tap) and `FocusToggleActionTests` `@MainActor` (mirrors `DeviceCoordinatorTests`/`NotchPillViewTests` precedent already established in this codebase)
- **Files modified:** `Islet/Notch/QuickActionsBar/FocusToggleAction.swift`, `IsletTests/FocusToggleActionTests.swift`
- **Commit:** `f14069e`

**2. [Rule 1 - Bug] Removed literal `"ActivitySettings.focusKey"` string from a code comment**
- **Found during:** Task 1, acceptance-criteria grep check
- **Issue:** A doc comment describing the decoupling from Phase 38's ambient Focus HUD literally contained the string `ActivitySettings.focusKey`, causing the plan's own `grep -c "ActivitySettings.focusKey" ... ` acceptance check to return 1 instead of the required 0 (grep can't distinguish "mentioned in prose" from "used in code")
- **Fix:** Reworded the comment to describe the same fact without the literal matching string
- **Files modified:** `Islet/Notch/QuickActionsBar/FocusToggleAction.swift`
- **Commit:** `f14069e`

## Issues Encountered

None beyond the two auto-fixed deviations above.

## User Setup Required

None for this plan's code. Functional note carried forward for Plan 65-08 (on-device verification, per this phase's own convention for uncertain mechanisms): the toggle mechanism depends on a Shortcut literally named "Islet Toggle Focus" existing in the user's Shortcuts app and toggling Focus/DND — if absent, `shortcuts run` fails/no-ops and `toggle(onResult:)` correctly reports failure (the intended "visible, not silent" behavior), but the feature won't do anything useful until that Shortcut is created. No in-app setup UI was built for this per RESEARCH.md Open Question 1's explicit recommendation.

## Next Phase Readiness

`FocusToggleAction.toggle(onResult:)`, `.isConfirmedOn`, `.focusShortcutName`, `.focusStateChanged(before:after:)` are a stable, tested contract. Plan 65-05 (DND tile UI) can call `isConfirmedOn` for icon state and `toggle(onResult:)` for the tap action without touching `Intents` directly. Plan 65-07 (controller wiring) gates this action's availability on `ActivitySettings.quickActionsKey` — no dependency on this file's internals beyond the 4 public members above.

## Self-Check: PASSED

- `Islet/Notch/QuickActionsBar/FocusToggleAction.swift`: FOUND
- `IsletTests/FocusToggleActionTests.swift`: FOUND
- Commit `29231dc`: FOUND in `git log --oneline --all`
- Commit `f14069e`: FOUND in `git log --oneline --all`
- `xcodebuild test -project Islet.xcodeproj -scheme Islet -only-testing:IsletTests/FocusToggleActionTests`: 4/4 tests passed
- `grep -c "ActivitySettings.focusKey" Islet/Notch/QuickActionsBar/FocusToggleAction.swift` → 0
- `grep -c "FocusModeMonitor.isAuthorized" Islet/Notch/QuickActionsBar/FocusToggleAction.swift` → 3 (≥1 required)

---
*Phase: 65-quick-actions-bar*
*Completed: 2026-07-26*
