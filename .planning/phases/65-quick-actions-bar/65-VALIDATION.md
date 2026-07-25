---
phase: 65
slug: quick-actions-bar
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-26
---

# Phase 65 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest, `IsletTests` target (existing) |
| **Config file** | `Islet.xcodeproj` (scheme-driven, no separate test config file) |
| **Quick run command** | `xcodebuild test -project Islet.xcodeproj -scheme Islet -only-testing:IsletTests/IslandResolverTests` (swap in new/relevant test class) |
| **Full suite command** | `xcodebuild test -project Islet.xcodeproj -scheme Islet` |
| **Estimated runtime** | ~unknown — inherits existing IsletTests suite runtime |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild test -project Islet.xcodeproj -scheme Islet -only-testing:IsletTests/IslandResolverTests` (or the relevant new test class)
- **After every plan wave:** Run `xcodebuild test -project Islet.xcodeproj -scheme Islet`
- **Before `/gsd:verify-work`:** Full suite must be green, PLUS a manual on-device pass tapping all 8 configured actions once (system-call side effects — screen lock, dark mode, DND — cannot be meaningfully asserted by XCTest alone)
- **Max feedback latency:** Full suite run duration (existing IsletTests baseline)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 65-01-TBD | TBD | 0 | QACTION-01 | — | `resolve(selectedView: .quickActions)` returns `.quickActionsBarExpanded`; slot dropdowns persist independently via `@AppStorage` | unit | `xcodebuild test ... -only-testing:IsletTests/IslandResolverTests` | ❌ W0 | ⬜ pending |
| 65-01-TBD | TBD | 0 | QACTION-02 | — | Tapping a configured action slot fires only that action's helper, no other `resolve()` branch triggered | unit + manual | `xcodebuild test ... -only-testing:IsletTests/IslandResolverTests`; manual on-device tap-through for each of the 8 actions | ❌ W0 | ⬜ pending |
| 65-01-TBD | TBD | 0 | QACTION-03 | — | DND/Focus toggle's read-back comparison (`before != after` → success/failure) is a pure, testable function | unit | New `IsletTests/FocusToggleActionTests.swift`, mirroring `MicMuteControllerTests.swift` | ❌ W0 | ⬜ pending |

*Task IDs finalized once the planner assigns concrete plan/task numbers — update this table to match PLAN.md before execution.*

---

## Wave 0 Requirements

- [ ] New test cases in `IsletTests/IslandResolverTests.swift` covering the `.quickActions`/`.quickActionsBarExpanded` resolver branch
- [ ] New `IsletTests/FocusToggleActionTests.swift` — pure before/after comparison logic for the DND read-back check
- [ ] Consider `QuickActionsBarManualSpike.swift` (mirrors existing `*ManualSpike.swift` files) to exercise all 8 real system calls on-device during development, `#if DEBUG`-gated like `NowPlayingMonitor.swift`'s `spikeTriggerAutomationPrompt`

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Display sleep now | QACTION-01/02 | System-call side effect (IOKit), not assertable by XCTest | Tap action on-device, confirm display sleeps |
| Dark/light mode toggle | QACTION-01/02 | System appearance side effect | Tap action on-device, confirm appearance flips |
| Screen lock | QACTION-01/02 | Private API (`SACLockScreenImmediate` via `dlopen`), reliability unconfirmed on current macOS | Tap action on-device, confirm screen locks; flagged for mandatory on-device verification per RESEARCH.md |
| DND/Focus toggle | QACTION-03 | No public write API; best-effort via `shortcuts run` + `INFocusStatusCenter` read-back | Tap action on-device with and without a pre-built "Set Focus" Shortcut configured; confirm visible failure state when Shortcut missing/fails |
| Caffeinate/keep-awake toggle | QACTION-01/02 | System power-management side effect | Tap action on-device, confirm sleep is prevented/allowed |
| Empty Trash | QACTION-01/02 | Filesystem side effect via Apple Events | Tap action on-device, confirm Trash empties |
| Launch app/open URL | QACTION-01/02 | Process/URL-handler side effect | Tap action on-device, confirm target app/URL opens |
| Mic mute/unmute reuse | QACTION-01/02/03 | Live CoreAudio system mute state | Tap action on both Quick Actions bar and Meeting-HUD, confirm same live mute state reflected on both surfaces |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < existing IsletTests baseline
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
