---
phase: 41
slug: calendar-countdown-hud
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-07-18
---

# Phase 41 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest, `IsletTests` target (defined in `project.yml`) |
| **Config file** | `project.yml` (XcodeGen), `IsletTests` scheme |
| **Quick run command** | `xcodebuild -project Islet.xcodeproj -scheme Islet -configuration Debug build` — **use `build`, NOT `test`** (project memory: `xcodebuild test` hangs headless because `IsletTests` is hosted inside the full `Islet.app`, which boots the `NSPanel`/`MediaRemote`/`IOBluetooth` stack) |
| **Full suite command** | Manual `Cmd-U` in Xcode (routes around the headless-hang gap above) |
| **Estimated runtime** | ~30-60s build |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild -project Islet.xcodeproj -scheme Islet -configuration Debug build`
- **After every plan wave:** Manual `Cmd-U` full suite in Xcode
- **Before `/gsd:verify-work`:** Full manual `Cmd-U` pass + all on-device checkpoints below must be green
- **Max feedback latency:** ~60 seconds (build-only gate)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 41-01-xx | 01 | 1 | HUD-08 | — | `resolve(...)` returns `.calendarCountdown` ahead of `.nowPlayingWings` when both inputs are present (D-01) | unit | add to `IsletTests/IslandResolverTests.swift`, run via Cmd-U | ✅ file exists, ❌ new test case — Wave 0/1 | ⬜ pending |
| 41-01-xx | 01 | 1 | HUD-08 | — | `resolve(...)` never returns `.calendarCountdown` while `isExpanded == true` or while any `ActiveTransient` is present | unit | same file | ❌ new test case — Wave 0/1 | ⬜ pending |
| 41-0x-xx | TBD | TBD | HUD-08 | — | `nextUpcomingEvent(events:now:lookahead:)` excludes already-started events, includes events exactly at the 1hr boundary, returns nil on empty/all-past input | unit | new `IsletTests/CalendarGlanceTests.swift` test cases (or extend an existing calendar test file if one exists) | ❌ Wave 0 — confirm whether a `CalendarGlanceTests.swift` already exists before creating a new file | ⬜ pending |
| 41-0x-xx | TBD | TBD | HUD-08 | — | Live minute-countdown visible, correct icon/side placement, urgency color switch at 60s, no idle-wakeup regression, re-arm on back-to-back events | manual-only | on-device UAT (Activity Monitor Idle Wake Ups check per Success Criterion #3; wall-clock observation for #1/#2/#4) | N/A — cannot be automated (real EventKit calendar + real wall-clock timing + Activity Monitor) | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] Confirm whether `IsletTests` already has a `CalendarGlanceTests.swift` — CONFIRMED PRESENT (contradicts 41-RESEARCH.md's initial "no dedicated test file yet" scan; `41-PATTERNS.md` verified `IsletTests/CalendarGlanceTests.swift` already exists with full coverage of `nextRelevantEvent`/`daysInMonth`/`events(on:)`). `41-01-PLAN.md` Task 1 adds the new `nextUpcomingEvent` test cases to this existing file rather than creating a new one — no gap remains.

*No framework install needed — `IsletTests` target and XCTest are already fully configured.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|--------------------|
| Live minute-countdown display, icon/side placement, urgency color switch at 60s | HUD-08 | Requires a real EventKit calendar event and real wall-clock observation | Create a real calendar event starting within 1 hour, confirm the pill shows the calendar icon (left) and live mm:ss countdown (right), confirm the color switches orange→red inside the final 60s |
| No idle-wakeup regression from minute-boundary scheduling | HUD-08 (Success Criterion #3) | Only observable via Activity Monitor's Idle Wake Ups column on a running app | With the countdown active, watch Activity Monitor's Idle Wake Ups column for Islet — confirm no measurable regression vs. baseline (deadline-driven `DispatchSourceTimer`, not a 60s repeater) |
| Countdown dismisses at event start using its own scheduling, not the shared 3s `activityDuration` auto-dismiss | HUD-08 (Success Criterion #2) | Requires wall-clock observation across the event start boundary | Let a real event reach its start time, confirm the countdown wing dismisses at/shortly after start and that no other ambient/transient activity's dismiss timing is disturbed |
| Countdown yields to higher-priority Charging/Device transients and re-arms correctly for back-to-back events | HUD-08 (Success Criterion #4), D-09 | Requires triggering a real transient (e.g. plug in charger) during an active countdown, and a real back-to-back calendar scenario | Trigger a Charging/Device transient while the countdown is visible, confirm the countdown yields; schedule two back-to-back events, confirm the countdown re-arms for the second event after the first dismisses |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references — `CalendarGlanceTests.swift` already exists, no scaffold gap
- [x] No watch-mode flags
- [x] Feedback latency < 60s per task (build-only gate; project-wide `xcodebuild build` latency of ~30-60s is an accepted inherent constraint, not a plan defect)
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved
