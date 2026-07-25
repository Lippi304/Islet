# Phase 63 — Deferred Items

Out-of-scope discoveries logged during execution. Per the executor's SCOPE BOUNDARY rule these
are NOT fixed here — they are pre-existing failures in files no Phase 63 plan touches.

## Pre-existing test failures (found during Plan 63-03's full-suite run)

Full suite at commit `e30199f`: **526 tests, 4 failures.** All 4 live in test files that never
reference `IslandPresentation`, `ActiveTransient`, or `meetingWings` — confirmed by grep — and
none of the production files they cover were modified by Phase 63.

| Test | File:line | Symptom | Assessment |
|------|-----------|---------|------------|
| `testDefaultQuickAddTimeForTodayReturnsNextFullHour` | `IsletTests/CalendarGlanceTests.swift:209` | `2026-07-18 22:00` != `2026-07-19 13:00` | Wall-clock/timezone-dependent test — asserts against a hardcoded date that has since passed. |
| `testDefaultQuickAddTimeRollsOverToNextDayAtMidnightBoundary` | `IsletTests/CalendarGlanceTests.swift:230` | `2026-07-18 22:00` != `2026-07-19 22:00` | Same root cause as above (off-by-one-day, same fixture). |
| `testSaveDeletesOrphanedImageFileButKeepsStillReferencedFile` | `IsletTests/ClipboardFileStoreTests.swift:91` | `"41 bytes"` != `"41 bytes"` | Compares two objects whose *descriptions* are identical — the assertion is on a type whose `==` differs from its printed form. Pre-existing flake/assertion bug. |
| `testSystemHUDCardsCount` | `IsletTests/SettingsViewTests.swift:39` | actual `9` != expected `8` | A 9th System-HUD card was added to `Islet/SettingsView.swift` without updating the count. That file was last modified in **Phase 60-03** (`9bf1417`), long before Phase 63. |

**Recommendation:** fold into a `/gsd-quick` test-hygiene pass. The Calendar pair should take
`now` as an injected parameter (the exact discipline `MeetingActivity.swift` already follows),
and `testSystemHUDCardsCount` should assert against a named constant rather than a literal so
adding a card fails loudly at the definition site instead of in an unrelated suite.
