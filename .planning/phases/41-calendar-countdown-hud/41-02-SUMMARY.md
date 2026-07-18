---
phase: 41-calendar-countdown-hud
plan: 02
subsystem: notch-controller
tags: [swiftui, eventkit, dispatchsourcetimer, calendar, countdown, monitor]

# Dependency graph
requires:
  - phase: 41-calendar-countdown-hud
    plan: 01
    provides: CalendarCountdownActivity/IslandPresentation.calendarCountdown, resolve(...)'s calendarCountdown: parameter, nextUpcomingEvent, CalendarService.fetchUpcomingRaw, ActivitySettings.calendarCountdownKey
provides:
  - "CalendarCountdownMonitor — event-driven (.EKEventStoreChanged), one-shot-deadline (never repeating) scheduling monitor"
  - "NotchWindowController.calendarCountdownMonitor / calendarCountdownActivity — toggle-gated lifecycle (start-gated, toggle-off teardown, deinit teardown)"
  - "NotchWindowController.handleCalendarCountdownChange(_:) — ambient-only mutation, zero TransientQueue coupling"
  - "currentPresentation()'s resolve(...) call now feeds calendarCountdown: calendarCountdownActivity"
affects: [41-03-countdown-wing-view-settings-toggle, 41-04-on-device-uat]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "One-shot DispatchSourceTimer with cancel-then-reschedule on every recheck (deadline fire, .EKEventStoreChanged fire, or start()) — no repeating: argument anywhere"
    - "Ambient monitor wiring mirrors FocusModeMonitor's toggle-gated start()/nonisolated stop()/owner-driven deinit teardown shape exactly, but event-driven instead of polling"

key-files:
  created:
    - Islet/Notch/CalendarCountdownMonitor.swift
  modified:
    - Islet/Notch/NotchWindowController.swift
    - Islet.xcodeproj/project.pbxproj

key-decisions:
  - "scheduleNext(from:) arms at most one DispatchSourceTimer deadline: either the 'enter the 1hr countdown window' instant (event still beyond lookahead) or the 'event starts, dismiss + re-arm' instant (event already inside lookahead) — never both, never a repeat"
  - "handleCalendarCountdownChange(_:) body is exactly 3 lines (set property, spring-wrapped renderPresentation(), updateVisibility()) — zero transientQueue/flushTransients/scheduleActivityDismiss references, proving Pitfall 5 independence"
  - "project.pbxproj regenerated via xcodegen generate to register the new CalendarCountdownMonitor.swift source file — required before the build could find the type"

patterns-established: []

requirements-completed: [HUD-08]

# Metrics
duration: 10min
completed: 2026-07-18
---

# Phase 41 Plan 02: Calendar Countdown Monitor + Controller Wiring Summary

**Event-driven, one-shot-deadline CalendarCountdownMonitor wired into NotchWindowController exactly like Focus/Power/Bluetooth — toggle-gated start, toggle-off + deinit teardown, and an ambient-only change handler that never touches TransientQueue.**

## Performance

- **Duration:** 10 min
- **Started:** 2026-07-18T14:39:00+02:00 (approx, continuing directly from 41-01)
- **Completed:** 2026-07-18T14:48:56+02:00
- **Tasks:** 2 completed
- **Files modified:** 3 (1 created, 2 modified)

## Accomplishments
- `CalendarCountdownMonitor` (new file) — `@MainActor final class` constructed with an injected `CalendarService`, registers for `.EKEventStoreChanged`, and on every recheck (initial `start()`, notification fire, or timer fire) cancels any prior timer before arming at most one new one-shot `DispatchSourceTimer` deadline. Zero `repeating:` occurrences, zero `transientQueue`/`scheduleActivityDismiss`/`activityDuration` references — both verified by grep.
- `NotchWindowController` gained `calendarCountdownMonitor`/`calendarCountdownActivity` properties, a toggle-gated `startCalendarCountdownMonitor()` (mirrors `startFocusModeMonitor()`), a 3-line `handleCalendarCountdownChange(_:)` that only mutates the plain ambient property and re-renders, `currentPresentation()`'s `resolve(...)` call now passes `calendarCountdown: calendarCountdownActivity`, `handleSettingsChanged()` gained a Charging/Devices-style toggle-off block, and `deinit` calls `calendarCountdownMonitor?.stop()`.
- `project.pbxproj` regenerated via `xcodegen generate` to register the new source file (the build failed with "cannot find type 'CalendarCountdownMonitor' in scope" until this ran — not a code defect, a required project-file sync step).

## Task Commits

Each task was committed atomically:

1. **Task 1: CalendarCountdownMonitor.swift — event-driven, one-shot-deadline scheduling** - `4d94d7c` (feat)
2. **Task 2: NotchWindowController wiring** - `b4aab15` (feat, includes the xcodegen-regenerated project.pbxproj)

## Files Created/Modified
- `Islet/Notch/CalendarCountdownMonitor.swift` (new) — the monitor: `start()`/`recheck()`/`scheduleNext(from:)`/`armTimer(at:)`/`nonisolated stop()`/`deinit`
- `Islet/Notch/NotchWindowController.swift` — monitor property + ambient state property, `startCalendarCountdownMonitor()`, `handleCalendarCountdownChange(_:)`, `currentPresentation()`'s new argument, `handleSettingsChanged()` toggle-off block, `deinit` teardown
- `Islet.xcodeproj/project.pbxproj` — registers `CalendarCountdownMonitor.swift` in the Islet target (xcodegen-regenerated, 4-line diff)

## Decisions Made
- The plan's own acceptance-criteria greps (`repeating:`, `transientQueue|scheduleActivityDismiss|activityDuration`) are literal substring matches against the whole file including comments. The first draft's explanatory comments used those exact substrings (e.g. "NO repeating: argument", "NotchWindowController.scheduleActivityDismiss()") purely as prose, which would have failed the grep despite the actual code being correct. Reworded the comments to convey the same information without the literal trigger strings — a documentation-only adjustment, no behavior change.
- `project.pbxproj` needed a full `xcodegen generate` regeneration (not a manual edit) to add the new file — verified the resulting diff was a clean, minimal 4-line addition (one `PBXBuildFile`, one `PBXFileReference`, one group entry, one Sources-phase entry) before committing, with no unrelated churn.

## Deviations from Plan

**1. [Rule 3 - Blocking issue] project.pbxproj required xcodegen regeneration**
- **Found during:** Task 2 build verification
- **Issue:** `xcodebuild build` failed with `error: cannot find type 'CalendarCountdownMonitor' in scope` — Task 1's new file was on disk but never added to the Xcode project's Sources build phase (this project uses `xcodegen`/`project.yml` as the source of truth, not manual pbxproj edits).
- **Fix:** Ran `xcodegen generate`, verified the diff was minimal and expected, then included `project.pbxproj` in Task 2's commit.
- **Files modified:** `Islet.xcodeproj/project.pbxproj`
- **Commit:** `b4aab15`

**2. [Rule 1 - Bug] Acceptance-criteria grep false-negative from prose comments**
- **Found during:** Task 1 acceptance-criteria verification
- **Issue:** Explanatory comments in the new file contained the literal substrings the plan's own greps check for as absence proof (`repeating:`, `scheduleActivityDismiss`), even though no such code existed — the greps would have reported a false failure.
- **Fix:** Reworded the two comments to describe the same thing without the trigger substrings; re-ran the greps to confirm 0 counts.
- **Files modified:** `Islet/Notch/CalendarCountdownMonitor.swift`
- **Commit:** `4d94d7c`

## Issues Encountered
None beyond the two deviations above.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- `CalendarCountdownMonitor` is live, builds, and is wired into `NotchWindowController` exactly like every sibling monitor — `currentPresentation()` now feeds real `calendarCountdownActivity` state into `resolve(...)`, so `IslandPresentation.calendarCountdown` can actually become non-nil on a real device with a real upcoming event.
- Plan 03 (countdown wing view + Settings toggle) can now build the real `.calendarCountdown` view arm — `NotchPillView.presentationSwitch`'s Plan-01 placeholder (`EmptyView()`) is the only thing standing between this plan's live data and an actual visible countdown.
- No automated unit test exists for `CalendarCountdownMonitor` itself (system glue over `NotificationCenter`/`DispatchSourceTimer`/an injected protocol) — matches the established `FocusModeMonitor`/`PowerSourceMonitor` precedent. Manual on-device verification of actual scheduling behavior (arm-instant, dismiss/re-arm, back-to-back events) is Plan 04's job, per this plan's own `<verification>` section.
- Build is green after each task (`xcodebuild -project Islet.xcodeproj -scheme Islet -configuration Debug build`).

---
*Phase: 41-calendar-countdown-hud*
*Completed: 2026-07-18*
