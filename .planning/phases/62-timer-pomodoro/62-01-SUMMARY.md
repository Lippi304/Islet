---
phase: 62-timer-pomodoro
plan: 01
subsystem: ui
tags: [swift, xctest, tdd, foundation-only, resolver]

requires:
  - phase: 61-download-progress
    provides: "DownloadActivity.swift's pure-value-type-file shape (mirrored verbatim) and ActiveTransient.isPersistent's sub-state-split precedent (.downloadProgress(.inProgress))"
provides:
  - "TimerActivity.swift: TimerMode/TimerPhase/TimerContext/TimerActivity pure value types + isRunningOrPaused/timerPillLabel/nextPhase/validateCustomDurationMinutes/completionSplashText pure helpers"
  - "IslandResolver.swift: .timer/.timerExpanded IslandPresentation cases, .timer ActiveTransient case, generalized isPersistent (any persistent head, not just Focus), generalized preempt() (guards on currentHead.isPersistent, not hardcoded .focus), timer arm in updateHead"
affects: [62-02, 62-03, 62-04, 63-meeting-hud]

tech-stack:
  added: []
  patterns:
    - "Pure-seam-first: TimerActivity.swift built and unit-tested before any AppKit/SwiftUI wiring (mirrors Phase 19/22-01/38-01/47 precedent)"
    - "Pattern 4: .timerExpanded is the first IslandPresentation case with its own dedicated expanded content — resolve()'s .timer arm diverges from every other transient's collapsed-only fallthrough shape"

key-files:
  created:
    - Islet/Notch/TimerActivity.swift
    - IsletTests/TimerActivityTests.swift
    - .planning/phases/62-timer-pomodoro/deferred-items.md
  modified:
    - Islet/Notch/IslandResolver.swift
    - IsletTests/IslandResolverTests.swift
    - Islet/Notch/NotchWindowController.swift
    - Islet/Notch/NotchPillView.swift

key-decisions:
  - "preempt()'s hardcoded `guard case .focus = head` replaced with `guard let currentHead = head, currentHead.isPersistent`, generalizing beyond Focus to ANY persistent head (Download-in-progress, Timer) — closes a real, previously-undetected gap where a standing Download-Progress splash silently blocked Charging/Device from preempting it"
  - "NotchWindowController.syncActivityModels() and NotchPillView.presentationSwitch got minimal Rule-3 exhaustive-switch fixes (chargingState.activity = nil / EmptyView() stubs) so the build stays green after adding new enum cases — real UI wiring for Timer is explicitly Plan 62-03's job, not this plan's"

patterns-established:
  - "Pattern 4 (dedicated expanded presentation): a transient case can resolve to its OWN expanded IslandPresentation case instead of falling through to Home/Calendar/Weather/Tray when isExpanded is true — first proven by .timer -> .timerExpanded"

requirements-completed: [TIMER-01, TIMER-04]

duration: ~25min
completed: 2026-07-24
---

# Phase 62 Plan 01: TimerActivity Model + IslandResolver Generalization Summary

**Pure Foundation-only TimerActivity value-type model (countdown + Pomodoro shapes) plus a generalized IslandResolver `isPersistent`/`preempt()` that now handles any persistent transient head, not just Focus — closing a real Download-Progress preemption gap.**

## Performance

- **Duration:** ~25 min
- **Completed:** 2026-07-24T12:48:17Z
- **Tasks:** 2/2 completed
- **Files modified:** 4 modified, 3 created

## Accomplishments

- `TimerActivity.swift` — a fully Foundation-only, zero-`Date()`-call-site pure value-type model (`TimerMode`, `TimerPhase`, `TimerContext`, `TimerActivity`) with 5 pure helper functions, all unit-tested (8/8 `TimerActivityTests` green).
- `IslandResolver.swift`'s `ActiveTransient.isPersistent`/`TransientQueue.preempt()` generalized beyond the single hardcoded `.focus` case to any persistent head — proven both by new Timer-specific tests and by a regression test (`testPreemptNowGeneralizedForDownloadProgressHead`) closing a latent Download-Progress preemption bug found during Phase 62 research.
- `.timer`/`.timerExpanded` land as the first `IslandPresentation` transient with its own DEDICATED expanded-controls presentation — `resolve()`'s `.timer` arm returns `.timerExpanded(t)` rather than falling through to Home/Calendar/Weather/Tray like every prior transient.
- Full `IsletTests` suite run (497 tests): 84/84 `IslandResolverTests` green (78 pre-existing + 6 new/extended), zero regressions from the `preempt()` body replacement.

## Task Commits

Each task was committed atomically:

1. **Task 1: TimerActivity.swift pure model + TimerActivityTests.swift** - `7bebb4c` (feat, TDD RED→GREEN)
2. **Task 2: IslandResolver.swift generalization (SC5) + IslandResolverTests.swift extension** - `3a457da` (feat, TDD RED→GREEN)

**Plan metadata:** (this commit, docs: complete plan)

## Files Created/Modified

- `Islet/Notch/TimerActivity.swift` - Pure TimerMode/TimerPhase/TimerContext/TimerActivity model + 5 stateless helpers
- `IsletTests/TimerActivityTests.swift` - 8 tests covering pill label, phase toggle, duration validation, completion text, isRunningOrPaused, Equatable
- `Islet/Notch/IslandResolver.swift` - `.timer`/`.timerExpanded` cases, generalized `isPersistent`/`preempt()`, `resolve()` timer arm, `updateHead` timer arm, doc-comment updates
- `IsletTests/IslandResolverTests.swift` - New Phase 62 MARK block (5 new tests) + extended `testActiveTransientIsPersistentFlags` with 4 new `.timer` assertions
- `Islet/Notch/NotchWindowController.swift` - 1-line exhaustive-switch fix in `syncActivityModels()` for the new `.timer` `ActiveTransient` case (Rule 3, blocking)
- `Islet/Notch/NotchPillView.swift` - 1-line exhaustive-switch fix (`EmptyView()` stub) in `presentationSwitch` for the new `.timer`/`.timerExpanded` `IslandPresentation` cases (Rule 3, blocking) — real rendering deferred to Plan 62-03

## Decisions Made

- `preempt()`'s guard generalized to `currentHead.isPersistent` rather than adding a second explicit `case .downloadProgress`/`case .timer` branch — a single generalized guard is the correct fix per the plan's own SC5 framing, and it automatically covers any future persistent transient (e.g. Phase 63's Meeting HUD) without further resolver surgery.
- Minimal exhaustive-switch stubs added to `NotchWindowController.swift`/`NotchPillView.swift` rather than deferring the whole plan on a build failure — these are 1-line, behavior-preserving additions (no product behavior change, `.timer` renders nothing yet) that unblock Task 2's own verification; real UI wiring is explicitly out of this plan's scope per its own `<objective>`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] NotchWindowController.swift exhaustive-switch fix**
- **Found during:** Task 2 (IslandResolver.swift generalization)
- **Issue:** Adding `.timer` to `ActiveTransient` broke `syncActivityModels()`'s exhaustive switch — compile error, not listed in the plan's `<files>`.
- **Fix:** Added `case .timer: chargingState.activity = nil // Phase 62 / TIMER-01..04: not charging -- no standing charging splash`, mirroring the existing pattern for every other non-charging case.
- **Files modified:** Islet/Notch/NotchWindowController.swift
- **Verification:** `xcodebuild build-for-testing` succeeds; full test suite run confirms zero regressions.
- **Committed in:** 3a457da (Task 2 commit)

**2. [Rule 3 - Blocking] NotchPillView.swift exhaustive-switch fix**
- **Found during:** Task 2 (IslandResolver.swift generalization)
- **Issue:** Adding `.timer`/`.timerExpanded` to `IslandPresentation` broke `presentationSwitch`'s exhaustive switch — compile error, not listed in the plan's `<files>`.
- **Fix:** Added `case .timer, .timerExpanded: EmptyView()` with a comment flagging this as a resolver-seam-only stub; real rendering is Plan 62-03's job (mirrors the project's own seam-then-view sequencing convention).
- **Files modified:** Islet/Notch/NotchPillView.swift
- **Verification:** `xcodebuild build-for-testing` succeeds; full test suite run confirms zero regressions.
- **Committed in:** 3a457da (Task 2 commit)

**3. [Rule 1 - Bug] Reworded a code comment matching the plan's own forbidden-literal grep**
- **Found during:** Task 2 self-verification (acceptance criteria grep check)
- **Issue:** My explanatory comment for the `preempt()` change contained the literal string `` `guard case .focus = head` `` inside backticks, which the acceptance criterion's own grep (`grep -n "guard case .focus = head"` must return zero matches) would false-positive against.
- **Fix:** Reworded the comment to describe the old guard without reproducing its literal source text.
- **Files modified:** Islet/Notch/IslandResolver.swift
- **Verification:** `grep -n "guard case .focus = head" Islet/Notch/IslandResolver.swift` returns no matches; build still green.
- **Committed in:** 3a457da (Task 2 commit)

---

**Total deviations:** 3 auto-fixed (2 blocking exhaustive-switch fixes, 1 self-verification wording fix)
**Impact on plan:** All auto-fixes necessary to keep the build green after the planned enum-case additions. Zero product-behavior change (the two stubs render nothing / clear no state that wasn't already nil). No scope creep — no Timer UI was built.

## Issues Encountered

- Headless `xcodebuild test` (per `.planning/PROJECT.md`, historically hangs due to a Bluetooth TCC-authorization wait) ran successfully in this environment for both `-only-testing:IsletTests/TimerActivityTests`, `-only-testing:IsletTests/IslandResolverTests`, and a full unfiltered run — no hang observed this session. Used as the primary automated verification instead of a manual Cmd-U pass.
- A full-suite run (497 tests) surfaced 4 pre-existing, unrelated failures (2 wall-clock-dependent `CalendarGlanceTests`, 1 `ClipboardFileStoreTests`, 1 `SettingsViewTests`) — none touch files this plan modified or their dependencies. Logged to `.planning/phases/62-timer-pomodoro/deferred-items.md`, not fixed, per the scope-boundary rule.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- `TimerActivity`, `IslandPresentation.timer`/`.timerExpanded`, and the generalized `isPersistent`/`preempt()` seam are locked and unit-tested — Plans 62-02 (stateful pause/resume/deadline-math), 62-03 (view rendering, replacing the `EmptyView()` stubs), and 62-04 (controller wiring) can build directly against this contract with no further resolver changes.
- No blockers. The 4 deferred pre-existing test failures should be picked up independently (likely a `/gsd-quick` task), not blocking Phase 62's continuation.

---
*Phase: 62-timer-pomodoro*
*Completed: 2026-07-24*

## Self-Check: PASSED

All 7 created/modified files confirmed present on disk; both task commits (7bebb4c, 3a457da) confirmed in git log.
