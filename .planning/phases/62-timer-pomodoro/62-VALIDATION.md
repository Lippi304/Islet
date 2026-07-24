---
phase: 62
slug: timer-pomodoro
status: approved
nyquist_compliant: true
wave_0_complete: true
created: 2026-07-24
---

# Phase 62 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (existing target `IsletTests`) |
| **Config file** | `project.yml` (XcodeGen-managed target, no separate test-plan file) |
| **Quick run command** | Manual Cmd-U in Xcode (headless `xcodebuild test` is documented to hang in this repo — a pre-existing Bluetooth-TCC-authorization wait affects the full app's boot path, per `.planning/PROJECT.md` line 425 and `.planning/phases/09-fullscreen-flash-window-space-retry/deferred-items.md`) |
| **Full suite command** | Manual Cmd-U (same caveat — no separate "full" vs "quick" split exists in this project; `xcodebuild build` is used for CI-style gating instead) |
| **Estimated runtime** | ~30-60s manual Cmd-U pass |

---

## Sampling Rate

- **After every task commit:** Manual Cmd-U for the touched test file(s) — no faster automated quick-run given the headless-hang constraint documented in this project
- **After every plan wave:** Full manual Cmd-U pass across `IsletTests` target
- **Before `/gsd:verify-work`:** Full manual Cmd-U green + on-device UAT (TIMER-03's audio/splash firing, SC5's preempt-and-resume behavior)
- **Max feedback latency:** ~60 seconds (manual Cmd-U run)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 62-01 Task 1 | 62-01 | 1 | TIMER-01, TIMER-04 | — | N/A | unit | Cmd-U: `IsletTests/TimerActivityTests.swift` (new) | ✅ created by plan | ✅ satisfied (TDD, inline) |
| 62-01 Task 2 | 62-01 | 1 | SC5 | T-62-01, T-62-02 | Validated custom-duration input; generalized `isPersistent`/`preempt()` | unit | Cmd-U: `IsletTests/IslandResolverTests.swift` (extended) | ✅ file exists, extended | ✅ satisfied (TDD, inline) |
| 62-02 Task 1 | 62-02 | 2 | TIMER-02, TIMER-04 | — | N/A | unit | Cmd-U: `IsletTests/TimerActivityStateTests.swift` (new, 12 tests) | ✅ created by plan | ✅ satisfied (TDD, inline) |
| 62-02 Task 2 | 62-02 | 2 | TIMER-02, TIMER-04 | T-62-03 | `max(0, ...)` deadline guard | build | `xcodebuild build` (no dedicated test file, mirrors `CalendarCountdownMonitor` precedent) | N/A — build-only per project convention | ✅ satisfied (build verify) |
| 62-03 Task 1 | 62-03 | 2 | TIMER-01, TIMER-03, TIMER-04 | — | N/A | build | `xcodebuild build` | N/A — view-layer, manual visual check deferred to 62-04 UAT | ✅ satisfied (build verify) |
| 62-03 Task 2 | 62-03 | 2 | TIMER-02 | — | N/A | build | `xcodebuild build` | N/A — view-layer, manual visual check deferred to 62-04 UAT | ✅ satisfied (build verify) |
| 62-03 Task 3 | 62-03 | 2 | TIMER-01, TIMER-04 | T-62-04 | `validateCustomDurationMinutes(_:)` gates every custom entry before reaching a controller closure | build | `xcodebuild build` | N/A — view-layer, manual visual check deferred to 62-04 UAT | ✅ satisfied (build verify) |
| 62-04 Task 1 | 62-04 | 3 | TIMER-01, TIMER-02, TIMER-03, TIMER-04, SC5 | T-62-05 | Generalized `preempt()` call-site simplification, behavior-preserving | build | `xcodebuild build` | N/A — controller wiring | ✅ satisfied (build verify) |
| 62-04 Task 2 | 62-04 | 3 | TIMER-01, TIMER-02, TIMER-03, TIMER-04 | — | N/A | build | `xcodebuild build` | N/A — controller wiring | ✅ satisfied (build verify) |
| 62-04 Task 3 | 62-04 | 3 | TIMER-01, TIMER-02, TIMER-03, TIMER-04, SC5 | — | N/A | manual-only | On-device checkpoint, 10-step checklist | ❌ no automated coverage possible (audio/visual/hardware-interrupt firing) — covered by Manual-Only Verifications table below | ⬜ pending (checkpoint, gated on execution) |

---

## Wave 0 Requirements

- [x] `IsletTests/TimerActivityTests.swift` — pure `TimerActivity`/`formatMMSS`-adjacent mapping tests (mirrors `DownloadActivityTests.swift`'s plain-XCTAssert style, no shared fixture) — satisfied inline via TDD in 62-01 Task 1
- [x] `IsletTests/TimerActivityStateTests.swift` — pause/resume/add-time deadline-math tests, using a testable overload (no live `Date()` calls), mirroring `DownloadCoordinatorTests.swift`'s "testable overload takes `now:`" convention — satisfied inline via TDD in 62-02 Task 1
- [x] Extend `IsletTests/IslandResolverTests.swift` — new `.timer`/`.timerExpanded` resolve() branch tests, plus a regression test for the generalized `preempt()` guard against a `.downloadProgress(.inProgress)` head (closing the latent Download-Progress preemption gap found during research) — satisfied inline via TDD in 62-01 Task 2
- [x] Framework install: none — XCTest is already fully configured project-wide

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|--------------------|
| Completion splash + system sound fire correctly, even when app isn't focused | TIMER-03 | `NSSound.beep()` has no XCTest-observable return value; splash timing/visual correctness cannot be asserted headlessly | Start a short (~10s) timer, switch focus to another app, confirm the completion splash renders in the collapsed wing (per resolved Open Question 2) and the system alert sound plays — covered by 62-04 Task 3 (UAT step 5) |
| Timer's expanded controls take priority over an active Calendar/Weather/Tray tab | Resolved Open Question 1 | Resolver branch ordering is verifiable by test, but the *felt* UX priority is a manual on-device check | With a timer running, select the Calendar tab, then expand the island — confirm Timer controls (not Calendar) are shown — covered by 62-04 Task 3 (UAT step 10) |
| A running timer survives a Charging/Device interruption and resumes its live countdown afterward | SC5 | Requires a real hardware interrupt (plug/unplug) to trigger Charging/Device preemption | Start a timer, plug/unplug power to trigger a Charging transient, confirm Timer resumes its live countdown afterward — covered by 62-04 Task 3 (UAT step 7) |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify (62-04 Task 3's manual-only checkpoint is the sole exception, and it is checkpoint-exempt per Nyquist rules — the two preceding tasks in the same plan both carry `xcodebuild build` automated verification)
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 60s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved — all 4 PLAN.md files (62-01..62-04) satisfy Nyquist checks 8a-8d; TDD plans (62-01, 62-02) create their own tests inline; 62-03/62-04 rely on `xcodebuild build` automated verification per every `auto`-type task, with 62-04's sole `checkpoint:human-verify` task exempted and covered by the Manual-Only Verifications table above.
