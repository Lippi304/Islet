---
phase: 72
slug: calendar-redesign-native-calendar-clone
status: final
nyquist_compliant: true
wave_0_complete: false
created: 2026-07-30
---

# Phase 72 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (existing `IsletTests` target) |
| **Config file** | none — standard Xcode test target, no separate config |
| **Quick run command** | `xcodebuild test -scheme Islet -destination 'platform=macOS' -only-testing:IsletTests/CalendarGlanceTests` |
| **Full suite command** | `xcodebuild test -scheme Islet -destination 'platform=macOS'` |
| **Estimated runtime** | ~seconds (quick) / full suite per Phase 67.1 precedent: 569 tests, ~6 known pre-existing unrelated failures |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild test -scheme Islet -destination 'platform=macOS' -only-testing:IsletTests/CalendarGlanceTests`
- **After every plan wave:** Run `xcodebuild test -scheme Islet -destination 'platform=macOS'` (full `IsletTests` suite)
- **Before `/gsd-verify-work`:** Full suite must be green (excluding the ~6 pre-existing unrelated failures) + on-device UAT checkpoint comparing rendered Calendar tab against `reference-macos-calendar-widgets.png`
- **Max feedback latency:** seconds (unit tests only; no UI snapshot infra exists in this project)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|--------|
| 72-01 Task 1 | 72-01 | 1 | CALVIEW-08 (eventsByDay grouping) | — | N/A | unit (TDD) | `xcodebuild test -scheme Islet -destination 'platform=macOS' -only-testing:IsletTests/CalendarGlanceTests` | ⬜ pending |
| 72-01 Task 2 | 72-01 | 1 | D-09 (CalendarService update/delete) | T-14-06 | Untrusted `EKEvent.title` never interpolated outside plain `Text`/native tooltip | build | `xcodebuild build -scheme Islet -destination 'platform=macOS'` | ⬜ pending |
| 72-02 Task 1 | 72-02 | 1 | CALVIEW-09 (weekday header, D-10) | — | N/A | build + grep | `xcodebuild build ... && grep -c "private var rotatedWeekdaySymbols"/"weekdayHeaderRow"` | ⬜ pending |
| 72-02 Task 2 | 72-02 | 1 | CALVIEW-09 (D-03 badge swap, D-05 red accent, D-11 font/cell) | — | N/A | build + grep | `xcodebuild build ... && grep -n "static let calendarCellSize"` | ⬜ pending |
| 72-03 Task 1 | 72-03 | 2 | CALVIEW-08 (D-01/D-02 agenda), D-08 delete, D-12 tooltip | T-14-06 | `event.title` stays in plain `Text`/`.help()`, never interpolated elsewhere | build | `xcodebuild build -scheme Islet -destination 'platform=macOS'` | ⬜ pending |
| 72-03 Task 2 | 72-03 | 2 | CALVIEW-09, D-07 edit popover | — | N/A | build | `xcodebuild build -scheme Islet -destination 'platform=macOS'` | ⬜ pending |
| 72-04 Task 1 | 72-04 | 3 | D-09 (controller wiring) | — | N/A | build + full test | `xcodebuild build ... && xcodebuild test -scheme Islet -destination 'platform=macOS'` | ⬜ pending |
| 72-04 Task 2 | 72-04 | 3 | CALVIEW-08, CALVIEW-09 (all, consolidated) | — | N/A | manual-only (checkpoint:human-verify, blocking) | on-device UAT against `reference-macos-calendar-widgets.png`: two-column layout, agenda scroll-to-day, badges/header/chevrons/fonts, event CRUD round-trip | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `IsletTests/CalendarGlanceTests.swift` — add unit tests for new `eventsByDay(events:calendar:)` function (empty input, single day, multiple days, cross-day-boundary events) — mirrors existing `testEventsOnDayReturnsOnlyMatchingDaySortedAscending`/`testEventsOnDayReturnsEmptyArrayForEmptyEventsWithoutCrashing` pair
- [ ] No new test target/framework install needed — `IsletTests` already exists and is wired into the `Islet` scheme

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Two-column layout render, agenda scroll-to-tapped-day, no clipping at new `calendarWidth` | CALVIEW-08 | No SwiftUI snapshot infra exists in this project | Launch app, open Calendar tab, tap grid days, confirm agenda scrolls and no content clips at the widened island width |
| Badge styling (today filled / selected outlined ring), weekday header alignment, chevron spacing, font sizes vs. reference PNG | CALVIEW-09 | Visual fidelity to Apple's native widget cannot be asserted by unit tests | Side-by-side on-device comparison against `reference-macos-calendar-widgets.png` |
| `EventInput.id` populated correctly from `EKEvent.eventIdentifier`; update/delete round-trip via `CalendarService` | D-09 | Requires live `EKEventStore` with granted Calendar permission; no existing test double for `CalendarService` | Create, edit, and delete an event via the redesigned UI; confirm changes persist in Calendar.app |
| Hover-reveal delete icon (D-08) and edit popover pre-fill (D-07) | CALVIEW-09 / D-07 / D-08 | Hover state and popover interaction not covered by XCTest in this codebase | Hover an agenda row, confirm trash icon reveals; tap event to confirm edit popover pre-fills existing title/date/time |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or are the exempt `checkpoint:human-verify` task (72-04 Task 2)
- [x] Sampling continuity: no 3 consecutive tasks without automated verify (only the final task, 72-04 Task 2, is manual-only)
- [x] Wave 0 covers all MISSING references (72-01 Task 1 adds `eventsByDay` unit tests per Wave 0 Requirements above)
- [x] No watch-mode flags
- [x] Feedback latency < seconds for unit tests (full-suite `xcodebuild test` runs longer, inherent to the compiled-Swift toolchain — same precedent as Phase 67.1, not practically avoidable)
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved (post-planning, via gsd-plan-checker verification — 2026-07-30)
