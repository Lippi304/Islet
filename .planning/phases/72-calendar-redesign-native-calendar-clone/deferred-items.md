# Deferred Items — Phase 72 Plan 01

Out-of-scope items discovered during execution, not fixed per the Scope Boundary rule
(only auto-fix issues directly caused by the current task's changes).

## Pre-existing test failures, unrelated to this plan's changes

Full suite run after Task 2 (`xcodebuild test -scheme Islet -destination 'platform=macOS'`):
591 tests, 7 failures. Identical failure set to Phase 71 Plan 01's deferred-items.md
(same 4x `LicenseStateTests` + 3x `SettingsViewTests`), confirming these are still
pre-existing and unrelated to any Calendar work — the count of failures has not changed
since Phase 71 despite two more phases (71-72) landing test-suite changes in between.

This plan's changes touch only `Islet/Calendar/CalendarGlance.swift`,
`Islet/Calendar/CalendarService.swift`, and `IsletTests/CalendarGlanceTests.swift`. Neither
`SettingsViewTests.swift` nor `LicenseStateTests.swift` was modified by this plan or any
commit in this plan's history.

**Failures (all pre-existing, out of scope for this plan):**
- `LicenseStateTests.testActiveTrialReturnsDaysRemaining`
- `LicenseStateTests.testExpiredTrialReturnsTrialExpired`
- `LicenseStateTests.testIsEntitledMapping`
- `LicenseStateTests.testMissingTrialStartDateFallsBackToFreshTrial`
- `SettingsViewTests.testProductivityCardsAllNew`
- `SettingsViewTests.testSystemHUDCardsCount`
- `SettingsViewTests.testSystemHUDCardsExistingBeforeNew`

Not fixed here. STATE.md's baseline note should be refreshed the next time someone
touches these test files.

## Plan 72-02 confirmation (2026-07-30)

Re-ran the full suite after Plan 72-02's two tasks (`monthGridColumn`/`weekdayHeaderRow`
changes in `Islet/Notch/NotchPillView.swift` only): identical 591 tests, 7 failures, same
failure set listed above. Confirmed via `git log` that neither `SettingsViewTests.swift`
nor `LicenseStateTests.swift` was touched by this plan (last touched by unrelated
`cf17509`/`ba43bfa`/`3a1d14d` commits, all pre-Phase-72). Zero new failures from this
plan's changes.

## Plan 72-03 confirmation (2026-07-30) — 2 time-of-day-dependent flakes, not regressions

Full suite run after both of Plan 72-03's tasks (`xcodebuild test -scheme Islet -destination
'platform=macOS'`): 591 tests, **9** failures — the 7 pre-existing baseline above PLUS 2 new
failures:
- `CalendarGlanceTests.testEndedEventTodayIsSkippedInFavorOfUpcomingOne`
- `CalendarGlanceTests.testMultipleRelevantEventsTodayReturnsEarliestStarting`

**Root cause confirmed as a pre-existing test-design flaw, not a regression from this plan.**
Both tests call `nextRelevantEvent(events:now:)` (Phase 14 code — `Islet/Calendar/
CalendarGlance.swift`, untouched by either of Plan 72-03's two commits, which only modified
`Islet/Notch/NotchPillView.swift`) with `now = Date()` (the real wall clock) and construct
event start times via `now.addingTimeInterval(3600)`/`(2 * 3600)`. This test suite happened to
run at 23:15-23:24 local time; adding 1-2 hours pushed the event's `start` past midnight into
the next calendar day, so `calendar.isDate($0.start, inSameDayAs: now)` correctly evaluates
`false` — the test's own hardcoded `isToday: true` expectation is simply wrong whenever the
suite runs within ~2 hours of midnight. This is a latent flake in tests written in Phase 14
(before Plan 72-03 even existed), not caused by any Calendar-redesign work.

Not fixed here (out of scope — Rule 1/Scope Boundary: this plan's own files are
`Islet/Notch/NotchPillView.swift` only; `CalendarGlanceTests.swift`'s pre-existing tests are a
separate file from a much earlier phase). Flagged for whoever next touches
`CalendarGlanceTests.swift`: either inject a fixed `now` far from midnight, or clamp the
`addingTimeInterval` offsets to stay within the same calendar day.

## Plan 72-04 revision confirmation (2026-07-31) — same 7 pre-existing failures, 4 fewer tests

Full suite run after the D-01/D-02 revision + D-13..D-17 hover-affordance commit
(`xcodebuild test -scheme Islet -destination 'platform=macOS'`): 587 tests, 7 failures —
identical failure set to the original 7 pre-existing baseline above. Test count dropped from
591→587 because this revision removed the now-dead `eventsByDay(events:calendar:)` function
(Plan 72-01) and its 4 unit tests — the whole-month agenda that called it was reverted back to
a single-day list, and grep confirmed no other caller existed. Zero new failures from this
revision.

## Intermittent hover-detection latency on new calendar hover affordances (D-14/D-15/D-16/D-17)

Reported during the real on-device UAT that approved Task 2 (2026-07-31): hover states
(day-cell white ring, chevron circular hover, agenda-row outline, "+ Add" border) are
sometimes detected with a slight delay rather than perfectly live — inconsistent, sometimes
instant, sometimes laggy. The user specifically noted it feels worse when another app is
running fullscreen, and smoother otherwise.

**Not treated as a bug in this plan's hover-affordance code** — all 4 hover mechanics
themselves are confirmed correct and were approved as-is. The symptom pattern (worse
specifically when another app holds a fullscreen Space) points at Space-switch/mouse-tracking
overhead for Islet's always-on-top overlay window while a fullscreen Space is active elsewhere
— a known category of issue for notch-style panels (see this project's own `NotchWindowController`
CGS-Space handling, Phase 9), not something specific to `onHover` usage in `NotchPillView.swift`.

Needs investigation as a separate follow-up (likely a mouse-tracking/Space-switching
performance issue at the window/panel level, not this plan's SwiftUI `.onHover` code). Not a
blocker for this phase — flagged here for whoever next investigates fullscreen/Space-related
overlay performance.
