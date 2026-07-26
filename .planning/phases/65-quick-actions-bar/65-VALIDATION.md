---
phase: 65
slug: quick-actions-bar
status: draft
nyquist_compliant: true
wave_0_complete: true
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
| **Quick run command** | `xcodegen generate && xcodebuild test -project Islet.xcodeproj -scheme Islet -only-testing:IsletTests/IslandResolverTests` (swap in new/relevant test class) |
| **Full suite command** | `xcodegen generate && xcodebuild test -project Islet.xcodeproj -scheme Islet` |
| **Estimated runtime** | ~unknown — inherits existing IsletTests suite runtime |

---

## Sampling Rate

- **After every task commit:** Run `xcodegen generate && xcodebuild test -project Islet.xcodeproj -scheme Islet -only-testing:IsletTests/IslandResolverTests` (or the relevant new test class) — `xcodegen generate` is mandatory before every build/test in this plan set, since every task that adds a new `.swift` file (Plans 01/02/03/04/05/08) targets `project.yml`'s glob sources, which do not auto-discover new files without regeneration
- **After every plan wave:** Run `xcodegen generate && xcodebuild test -project Islet.xcodeproj -scheme Islet`
- **Before `/gsd:verify-work`:** Full suite must be green, PLUS a manual on-device pass tapping all 8 configured actions once (system-call side effects — screen lock, dark mode, DND — cannot be meaningfully asserted by XCTest alone; this is Plan 65-08 Task 2's checkpoint)
- **Max feedback latency:** Full suite run duration (existing IsletTests baseline)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 65-01 Task 2 | 65-01 | 1 | QACTION-01 | T-65-01 | `resolve(selectedView: .quickActions)` returns `.quickActionsBarExpanded`; `showsSwitcherRow(for:)` returns `true`; a standing transient still outranks the selection | unit | `xcodebuild test -project Islet.xcodeproj -scheme Islet -only-testing:IsletTests/IslandResolverTests` | ✅ | ⬜ pending |
| 65-01 Task 2 | 65-01 | 1 | QACTION-02 | — | `NotchPillView.swift`'s `presentationSwitch`/`icon(for:)` exhaustively cover the 2 new enum cases (compile-gate, not a behavioral test — full-scheme build is part of the `xcodebuild test` command above) | build | `xcodebuild test -project Islet.xcodeproj -scheme Islet -only-testing:IsletTests/IslandResolverTests` | ✅ | ⬜ pending |
| 65-04 Task 1 | 65-04 | 1 | QACTION-03 | T-65-07, T-65-08 | `FocusToggleAction.focusStateChanged(before:after:)` pure comparison; `toggle(onResult:)`/`isConfirmedOn` never crash when unauthorized; zero references to `ActivitySettings.focusKey` | unit | `xcodebuild test -project Islet.xcodeproj -scheme Islet -only-testing:IsletTests/FocusToggleActionTests` | ✅ | ⬜ pending |
| 65-02/65-03 Tasks 1-2 | 65-02, 65-03 | 1 | QACTION-01 | T-65-03, T-65-04, T-65-05, T-65-06 | `DisplaySleepAction`/`ScreenLockAction`/`CaffeinateToggleAction`/`DarkModeToggleAction`/`EmptyTrashAction`/`LaunchAction` all compile, callable, no force-unwraps, no shell/AppleScript string interpolation of external input | build | `xcodegen generate && xcodebuild -project Islet.xcodeproj -scheme Islet -configuration Debug build` | ✅ | ⬜ pending |
| 65-06 Task 2 | 65-06 | 2 | QACTION-01 | T-65-06 (Settings side) | 8 independent slot pickers persist via `@AppStorage`; Launch slot's app-picker only ever writes an `NSOpenPanel`-sourced value, never a free-text field | build + manual | `xcodebuild build`; manual on-device tap-through (Plan 65-08 checkpoint) | ✅ | ⬜ pending |
| 65-07 Tasks 1-2 | 65-07 | 3 | QACTION-01, QACTION-02, QACTION-03 | T-65-12, T-65-13 | `handleQuickActionTap(_:slotIndex:)` dispatches all 9 `Action` cases; disabling the Settings toggle falls a stale switcher-slot selection back to Home; DND failure sets/auto-clears `quickActionsBarFeedback.lastFailedAction` | build + full suite | `xcodebuild build && xcodebuild test -project Islet.xcodeproj -scheme Islet` | ✅ | ⬜ pending |
| 65-08 Task 1 | 65-08 | 4 | QACTION-01, QACTION-02, QACTION-03 | T-65-14 | `QuickActionsBarManualSpike.swift` is `#if DEBUG`-only; Release build excludes it | build (Debug + Release) | `xcodegen generate && xcodebuild ... Debug build && xcodebuild ... Release build` | ✅ | ⬜ pending |
| 65-08 Task 2 | 65-08 | 4 | QACTION-01, QACTION-02, QACTION-03 | — | All 8 actions confirmed on real hardware; Screen Lock (RESEARCH.md A2) and DND (with/without Shortcut) explicitly confirmed; mic-mute parity between Quick Actions bar and Meeting-HUD confirmed | manual (checkpoint) | On-device checkpoint per `65-08-PLAN.md` Task 2 (`gate="blocking"`, `autonomous: false`) | ✅ | ⬜ pending |

---

## Wave 0 Requirements

- [x] New test cases in `IsletTests/IslandResolverTests.swift` covering the `.quickActions`/`.quickActionsBarExpanded` resolver branch — landed as Plan 65-01 Task 2 (TDD, `<behavior>` block, 4 test cases)
- [x] New `IsletTests/FocusToggleActionTests.swift` — pure before/after comparison logic for the DND read-back check — landed as Plan 65-04 Task 1 (TDD, `<behavior>` block, 2 test cases)
- [x] `QuickActionsBarManualSpike.swift` (mirrors existing `*ManualSpike.swift` files) to exercise all 8 real system calls on-device during development, `#if DEBUG`-gated like `NowPlayingMonitor.swift`'s `spikeTriggerAutomationPrompt` — landed as Plan 65-08 Task 1

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

All 8 rows above are covered by Plan 65-08 Task 2's checkpoint (`65-08-PLAN.md`, `<how-to-verify>`
steps 1-6).

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < existing IsletTests baseline
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
