---
phase: 54
slug: permissions-overview-onboarding-replay
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-22
---

# Phase 54 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (existing target: `IsletTests`) |
| **Config file** | `project.yml` (XcodeGen-generated Xcode project; no separate XCTest config file) |
| **Quick run command** | `xcodebuild test -scheme Islet -destination 'platform=macOS' -only-testing:IsletTests/SettingsViewTests -only-testing:IsletTests/OnboardingFlowTests` |
| **Full suite command** | `xcodebuild test -scheme Islet -destination 'platform=macOS'` |
| **Estimated runtime** | ~403-test suite per STATE.md's Phase 52 precedent — a few minutes |

---

## Sampling Rate

- **After every task commit:** Run the quick run command above (SettingsViewTests + OnboardingFlowTests, plus any new pure-function test file)
- **After every plan wave:** Run the full suite command
- **Before `/gsd:verify-work`:** Full suite must be green, plus on-device UAT (see Manual-Only Verifications)
- **Max feedback latency:** ~180 seconds (full suite)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 54-01-01 | 01 | 1 | ARCH-P2 | — | `SidebarSection.visibleSections(hasNotch:)` includes/excludes `.permissions` correctly | unit | `xcodebuild test -only-testing:IsletTests/SettingsViewTests` | ✅ `IsletTests/SettingsViewTests.swift` exists | ⬜ pending |
| 54-01-02 | 01 | 1 | ARCH-P2 | — | Combined Calendar+Reminders worst-status-wins resolution (D-13) is a pure, unit-testable function | unit | new test file, e.g. `PermissionStatusTests.swift` | ❌ Wave 0 | ⬜ pending |
| 54-02-01 | 02 | 2 | ARCH-P2 | T-54-01 | `replayOnboarding()` restores `interaction.phase` and never writes `onboardingCompletedKey` | manual-only | — | N/A | ⬜ pending |
| 54-02-02 | 02 | 2 | ARCH-P2 | T-54-02 | 5 permission status reads reflect real System Settings state; deep-links land on the correct pane | manual-only | — | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `IsletTests/PermissionStatusTests.swift` — new file, only if the combined Calendar+Reminders status-resolution logic (D-13) is factored into a pure function (recommended by research — mirrors the codebase's existing pure-function precedent, e.g. `nextOnboardingStep`).

*`SettingsViewTests.swift` and `OnboardingFlowTests.swift` already exist and can be extended — no Wave 0 work needed for those.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `replayOnboarding()`/replay-exit correctly restore `interaction.phase` and never touch `onboardingCompletedKey` | ARCH-P2 | Requires observing real island visual state across a live replay session — matches this codebase's own precedent of on-device UAT for all `NotchWindowController` interaction-state changes (Phase 43/45/48) | Trigger Replay Onboarding from About, click through, verify the island's collapsed/expanded state before and after replay is unchanged and no first-launch behavior recurs on next real launch |
| 5 permission status reads reflect real System Settings state, and each of the 5 deep-links opens the correct System Settings pane | ARCH-P2 | TCC-gated reads (`CLLocationManager`, `EKEventStore`, `CBManager`, `INFocusStatusCenter`, `IOHIDCheckAccess`) cannot be simulated in a unit test without mocking every framework — not worth the abstraction cost per this codebase's existing precedent (`LocationProvider`/`CalendarService`/`FocusModeMonitor`/`BluetoothMonitor` are themselves UAT-verified, not unit-tested, for live OS-facing behavior) | For each of the 5 permissions: toggle it granted/denied/reset in System Settings, confirm the Settings row reflects the change, tap a denied row and confirm the correct System Settings pane opens, tap a never-asked row and confirm the native OS dialog appears |
| Onboarding replay's new close/X button (D-12) actually exits cleanly without a partial-onboarding side effect | ARCH-P2 | Same reasoning as the replay-state row above — a UI interaction test across app-lifecycle state | Start a replay, click X partway through, confirm the app returns to its exact pre-replay state |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 180s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
