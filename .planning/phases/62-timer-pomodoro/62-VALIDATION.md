---
phase: 62
slug: timer-pomodoro
status: draft
nyquist_compliant: false
wave_0_complete: false
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
| TBD | TBD | 0 | TIMER-01 | — | N/A | unit | Cmd-U: `TimerActivityTests.swift` (new) | ❌ W0 | ⬜ pending |
| TBD | TBD | 0 | TIMER-02 | — | N/A | unit | Cmd-U: `TimerActivityStateTests.swift` (new) | ❌ W0 | ⬜ pending |
| TBD | TBD | — | TIMER-03 | — | N/A | manual-only | Manual on-device checkpoint (audio+splash firing) | ❌ W0 (deadline-firing logic is unit-testable via fake clock; audio/visual firing itself is not) | ⬜ pending |
| TBD | TBD | 0 | TIMER-04 | — | N/A | unit | Cmd-U: `TimerActivityTests.swift` (new) | ❌ W0 | ⬜ pending |
| TBD | TBD | — | SC5 | — | N/A | unit | Cmd-U: `IslandResolverTests.swift` (extend) | ✅ file exists, needs new cases | ⬜ pending |

*Plan/Wave/Task IDs to be filled in by the planner once PLAN.md files exist.*

---

## Wave 0 Requirements

- [ ] `IsletTests/TimerActivityTests.swift` — pure `TimerActivity`/`formatMMSS`-adjacent mapping tests (mirrors `DownloadActivityTests.swift`'s plain-XCTAssert style, no shared fixture)
- [ ] `IsletTests/TimerActivityStateTests.swift` — pause/resume/add-time deadline-math tests, using a testable overload (no live `Date()` calls), mirroring `DownloadCoordinatorTests.swift`'s "testable overload takes `now:`" convention
- [ ] Extend `IsletTests/IslandResolverTests.swift` — new `.timer`/`.timerExpanded` resolve() branch tests, plus a regression test for the generalized `preempt()` guard against a `.downloadProgress(.inProgress)` head (closing the latent Download-Progress preemption gap found during research)
- [ ] Framework install: none — XCTest is already fully configured project-wide

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|--------------------|
| Completion splash + system sound fire correctly, even when app isn't focused | TIMER-03 | `NSSound.beep()` has no XCTest-observable return value; splash timing/visual correctness cannot be asserted headlessly | Start a short (~10s) timer, switch focus to another app, confirm the completion splash renders in the collapsed wing (per resolved Open Question 2) and the system alert sound plays |
| Timer's expanded controls take priority over an active Calendar/Weather/Tray tab | Resolved Open Question 1 | Resolver branch ordering is verifiable by test, but the *felt* UX priority is a manual on-device check | With a timer running, select the Calendar tab, then expand the island — confirm Timer controls (not Calendar) are shown |
| A running timer survives a Charging/Device interruption and resumes its live countdown afterward | SC5 | Requires a real hardware interrupt (plug/unplug) to trigger Charging/Device preemption | Start a timer, plug/unplug power to trigger a Charging transient, confirm Timer resumes its live countdown afterward |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
