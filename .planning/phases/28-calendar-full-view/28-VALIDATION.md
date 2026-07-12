---
phase: 28
slug: calendar-full-view
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-13
---

# Phase 28 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (existing `IsletTests` target) |
| **Config file** | `project.yml` (XcodeGen-managed `IsletTests` target — no separate test config file) |
| **Quick run command** | `xcodebuild build -project Islet.xcodeproj -scheme Islet -configuration Debug` |
| **Full suite command** | Manual Cmd-U in Xcode (`IsletTests` scheme) — `xcodebuild test` hangs on this project (see `xcodebuild-test-headless-hang` memory: test target hosts the full NSPanel/MediaRemote/IOBluetooth-booting app) |
| **Estimated runtime** | ~30s build gate; manual Cmd-U pass ~1-2 min |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild build -project Islet.xcodeproj -scheme Islet -configuration Debug`
- **After every plan wave:** Full Cmd-U pass in Xcode (`IsletTests` scheme) — confirm all new + existing test methods pass
- **Before `/gsd:verify-work`:** Full suite must be green via manual Cmd-U, plus on-device UAT checkpoints for CALVIEW-01/02/03 (switcher visibility, empty-state copy, quick-add round-trip, Reminders permission prompt timing) — these involve a live EventKit store and real permission dialogs that cannot be automated, matching this project's established human-verify convention (Phase 26 precedent).
- **Max feedback latency:** ~30s (build gate)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 28-01-01 | 01 | 0 | CALVIEW-01 | — | N/A | unit | Cmd-U `IslandResolverTests` (new `.calendarExpanded`/`selectedView` cases) | ❌ W0 — extend existing file (confirm exact name during planning) |
| 28-01-02 | 01 | 0 | CALVIEW-02 | — | N/A | unit | Cmd-U `CalendarGlanceTests` (extended day-bucketing empty-state case) | ❌ W0 — extend `IsletTests/CalendarGlanceTests.swift` |
| 28-02-01 | 02 | 1 | CALVIEW-03 | T-14-06 | Plain `String` pass-through only for event/reminder titles, never interpolated into format/log/shell strings | unit + manual | Cmd-U for pure input-mapping; manual on-device UAT for real `EKEventStore`/`EKReminderStore` save round-trip | ❌ W0 — new pure mapping test file if a mapping function is extracted |
| 28-03-01 | 03 | 1 | CALVIEW-04 | — | Single `EKEventStore` instance — no duplicated fetch/mapping logic | structural | `grep -c "EKEventStore()" Islet/Calendar/*.swift` returns `1` | N/A — structural check, not a test file |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Confirm exact filename of the existing resolver test file (likely `IsletTests/IslandResolverTests.swift`) before extending it with `.calendarExpanded`/`selectedView` test cases.
- [ ] `IsletTests/CalendarGlanceTests.swift` — extend with new pure month/day-bucketing function tests (no new file needed).
- [ ] No framework install needed — XCTest is already wired via the existing `IsletTests` target.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Switcher reveals `.calendarExpanded` with month grid + day list rendering correctly | CALVIEW-01 | Visual rendering, hover/click interaction — no headless UI test harness for this NSPanel app | On-device: click Calendar icon in switcher, confirm month grid + day list render |
| Empty-state day shows explicit copy, not blank area | CALVIEW-02 | Visual rendering of empty state | On-device: select a day with no events, confirm empty-state copy appears |
| Quick-add Event or Reminder round-trip (including first-use Reminders permission prompt timing) | CALVIEW-03 | Live `EKEventStore`/`EKReminderStore` save + real macOS permission dialog cannot be unit-tested | On-device: quick-add an Event, then a Reminder (first use — confirm permission prompt appears at that point, not earlier); confirm both persist |
| Single shared EventKit service layer (no duplicated logic) | CALVIEW-04 | Structural/architectural, confirmed via grep not runtime behavior | `grep -c "EKEventStore()" Islet/Calendar/*.swift` — must equal `1` |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
