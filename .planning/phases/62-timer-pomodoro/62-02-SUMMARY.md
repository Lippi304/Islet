---
phase: 62-timer-pomodoro
plan: 02
subsystem: ui
tags: [swift, xctest, tdd, foundation-only, dispatchsourcetimer]

requires:
  - phase: 62-timer-pomodoro
    plan: 01
    provides: "TimerActivity.swift's pure TimerMode/TimerPhase/TimerContext/TimerActivity value types + nextPhase() helper, the contract this plan's mutation layer builds against"
provides:
  - "TimerActivityState.swift: @MainActor ObservableObject session mutation holder implementing D-08 (pause/resume/reset), D-09 (add-minute while running or paused), D-10 (stop = full reset), D-11 (Pomodoro auto-advance-on-deadline), every method with a now:-parameterized testable overload, deadline exposed private(set) for external re-arming reads"
  - "TimerMonitor.swift: @MainActor one-shot DispatchSourceTimer deadline scheduler, arm(at:)/stop() mirroring CalendarCountdownMonitor's cancel-then-reschedule discipline"
affects: [62-04]

tech-stack:
  added: []
  patterns:
    - "Testable now: overload discipline (DownloadCoordinator precedent) applied to every TimerActivityState mutation method — public no-arg wrapper reads Date(), forwards to a now:-parameterized overload that never reads the live clock"
    - "Controller-reads-@Published, controller-enqueues (ChargingActivityState precedent) — TimerActivityState does not reach into TransientQueue itself, unlike DownloadCoordinator's closure-reach-back shape"

key-files:
  created:
    - Islet/Notch/TimerActivityState.swift
    - IsletTests/TimerActivityStateTests.swift
    - Islet/Notch/TimerMonitor.swift
  modified:
    - Islet.xcodeproj/project.pbxproj

key-decisions:
  - "Header-comment wording avoided the literal substring 'Date()' outside the no-arg wrapper lines themselves (mirrors 62-01's own self-verification-grep fix) — keeps the file's Date() grep footprint exactly matching the acceptance criterion's intent"

patterns-established: []

requirements-completed: [TIMER-02, TIMER-04]

duration: ~20min
completed: 2026-07-24
---

# Phase 62 Plan 02: TimerActivityState + TimerMonitor Summary

**Stateful session-mutation layer (pause/resume/reset/add-minute/stop/Pomodoro auto-advance, D-08/D-09/D-10/D-11) plus a one-shot DispatchSourceTimer deadline scheduler mirroring CalendarCountdownMonitor's proven cancel-then-reschedule discipline.**

## Performance

- **Duration:** ~20 min
- **Completed:** 2026-07-24
- **Tasks:** 2/2 completed
- **Files modified:** 1 modified (project.pbxproj via xcodegen regen), 3 created

## Accomplishments

- `TimerActivityState.swift` — `@MainActor final class TimerActivityState: ObservableObject` with `@Published var activity: TimerActivity?` and `private(set) var deadline: Date?` as the sole external-read seam; `startCountdown`/`startPomodoro`/`pause`/`resume`/`reset`/`addMinute`/`stop`/`handleDeadlineReached`, all 7 mutation methods carrying a `now:`-parameterized testable overload with zero live `Date()` reads inside the overload body.
- `IsletTests/TimerActivityStateTests.swift` — 12 tests (TDD RED→GREEN), all green: countdown/Pomodoro start deadlines, pause capturing exact remaining, resume recomputing a fresh deadline (no drift), reset restarting the current segment at full duration (both running-then-reset and paused-then-reset cases), add-minute extending the live deadline or the paused remaining (D-09 + A5), stop's full field reset with no leaked Pomodoro state, and the Pomodoro auto-advance return-tuple contract (segmentDone splash + already-advanced next state) for both work→break and break→work (cycle increment) transitions.
- `TimerMonitor.swift` — `@MainActor final class TimerMonitor` with `arm(at: Date?)`/`nonisolated func stop()`, verbatim cancel-then-reschedule shape from `CalendarCountdownMonitor.armTimer(at:)`/`stop()`, `max(0, ...)` guard against a negative deadline reaching `DispatchSourceTimer.schedule` (T-62-03).
- Full `IsletTests` suite run (509 tests): 505/509 green — the same 4 pre-existing, out-of-scope failures documented in `deferred-items.md` (`CalendarGlanceTests` x2, `ClipboardFileStoreTests`, `SettingsViewTests`), zero new regressions from either new file.

## Task Commits

Each task was committed atomically:

1. **Task 1: TimerActivityState.swift + TimerActivityStateTests.swift** - `26a2f05` (feat, TDD RED→GREEN)
2. **Task 2: TimerMonitor.swift one-shot deadline scheduler** - `27337a8` (feat)

**Plan metadata:** (this commit, docs: complete plan)

## Files Created/Modified

- `Islet/Notch/TimerActivityState.swift` - Session mutation holder (pause/resume/reset/add-minute/stop/handleDeadlineReached), all D-08/D-09/D-10/D-11 logic
- `IsletTests/TimerActivityStateTests.swift` - 12 tests covering every mutation method's deterministic `now:`-driven behavior
- `Islet/Notch/TimerMonitor.swift` - One-shot deadline scheduler, `arm(at:)`/`stop()`
- `Islet.xcodeproj/project.pbxproj` - Regenerated via `xcodegen generate` to pick up both new source files (folder-based source discovery, no manual project-file editing)

## Decisions Made

- Reworded the file-header comment on `TimerActivityState.swift` to avoid the literal substring `Date()` outside the no-arg wrapper lines, so `grep -n "Date()"` returns matches ONLY inside the 7 no-arg public wrappers as the plan's acceptance criterion states — mirrors the exact self-verification fix 62-01 already applied to its own `preempt()` comment.

## Deviations from Plan

### Auto-fixed Issues

None requiring a code change. One documentation-only clarification below (not a Rule 1-4 deviation, since no incorrect behavior was ever shipped):

**Acceptance-criterion grep imprecision (informational only, no code change needed):** The plan's literal acceptance-criteria grep — `grep -c "func .*(now: Date)" Islet/Notch/TimerActivityState.swift` reports at least 7 — undercounts to 5 as written, because plain `grep`'s basic regex treats `(`/`)` as literal characters: the pattern only matches when `now: Date)` is *immediately* preceded by an opening paren, i.e. only single-parameter overloads (`pause(now: Date)`, `resume(now: Date)`, `reset(now: Date)`, `addMinute(now: Date)`, `handleDeadlineReached(now: Date)`). The two multi-parameter overloads (`startCountdown(minutes: Int, now: Date)`, `startPomodoro(workMinutes: Int, breakMinutes: Int, now: Date)`) don't literally contain the substring `(now: Date)` since another parameter precedes `now:`. Verified via `grep -n "now: Date" ... | grep "func "` that all 7 methods genuinely have a `now:`-parameterized testable overload as required — the underlying acceptance intent is fully met, only the example grep command in the plan text undercounts for 2-parameter signatures. No code change was warranted (reordering parameters to put `now:` first would contradict the plan's own explicitly-specified call signatures, e.g. `state.startCountdown(minutes: 10, now: t0)`, which the tests already use verbatim).

## Issues Encountered

- Headless `xcodebuild test` intermittently hung on this machine during this session (the Bluetooth-TCC-authorization-wait mode documented in `.planning/PROJECT.md` and 62-01's own SUMMARY) — one attempt against the `TimerActivityStateTests`-only filter had to be killed and retried after a stuck process was observed consuming near-zero CPU for 30+ seconds. A clean single retry (no concurrent invocations) succeeded immediately. The full-suite run afterward completed normally in ~2 minutes with no hang.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- `TimerActivityState` and `TimerMonitor` are both locked and unit/build-verified — Plan 62-03 (view rendering, replacing the `EmptyView()` stubs left by Plan 62-01) and Plan 62-04 (controller wiring: constructing both classes, reading `TimerActivityState.deadline` to re-arm `TimerMonitor`, calling `handleDeadlineReached()` on fire and pushing the returned `splash`/`next` pair into `TransientQueue`) can build directly against this contract with no further changes to either file.
- No blockers.

---
*Phase: 62-timer-pomodoro*
*Completed: 2026-07-24*

## Self-Check: PASSED

All 3 created files confirmed present on disk; both task commits (26a2f05, 27337a8) confirmed in git log.
