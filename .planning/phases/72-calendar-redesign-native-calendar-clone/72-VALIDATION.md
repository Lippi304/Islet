---
phase: 72
slug: calendar-redesign-native-calendar-clone
status: draft
nyquist_compliant: false
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

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| TBD-01 | TBD | 0 | CALVIEW-08 | — | N/A | unit | `xcodebuild test -scheme Islet -destination 'platform=macOS' -only-testing:IsletTests/CalendarGlanceTests` | ❌ W0 (extend existing file) | ⬜ pending |
| TBD-02 | TBD | TBD | CALVIEW-08 | — | N/A | manual-only | on-device checkpoint (two-column layout, agenda scroll-to-day, no clipping at new width) | — | ⬜ pending |
| TBD-03 | TBD | TBD | CALVIEW-09 | — | N/A | manual-only | on-device checkpoint against `reference-macos-calendar-widgets.png` (badges, weekday header, chevrons, fonts) | — | ⬜ pending |
| TBD-04 | TBD | TBD | D-09 (update/delete) | T-14-06 | Untrusted `EKEvent.title` never interpolated into non-Text rendering; always `.lineLimit(1)`/`.truncationMode(.tail)` | manual-only | requires live `EKEventStore` (Calendar permission) — no test double exists for `CalendarService`/`EventKitService` | ❌ — planner decides: add protocol stub, or leave manual/on-device (consistent with `createEvent`/`createReminder` precedent) | ⬜ pending |

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

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < seconds
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
