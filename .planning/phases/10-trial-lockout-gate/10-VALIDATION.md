---
phase: 10
slug: trial-lockout-gate
status: reviewed
nyquist_compliant: true
wave_0_complete: true
created: 2026-07-05
---

# Phase 10 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (bundled with Xcode 26.6 on this build machine) |
| **Config file** | `project.yml` (`IsletTests` target, `xcodegen generate` → `.xcodeproj`) |
| **Quick run command** | `xcodebuild test -scheme Islet -only-testing:IsletTests/TrialLogicTests -only-testing:IsletTests/VisibilityDecisionTests` |
| **Full suite command** | `xcodebuild test -scheme Islet` |
| **Estimated runtime** | ~60 seconds (full suite); scoped per-task commands are the fast path (see Sampling Rate) |

---

## Sampling Rate

- **After every task commit:** Run the scoped `-only-testing:` command relevant to that task (e.g. `xcodebuild test -scheme Islet -only-testing:IsletTests/TrialLogicTests -only-testing:IsletTests/VisibilityDecisionTests`), or a plain `xcodebuild build -scheme Islet` for glue-code tasks with no dedicated unit-test target (e.g. `AppDelegate.swift` wiring) — never the full suite per task
- **After every plan wave:** Run `xcodebuild test -scheme Islet` (full suite) plus, for Plan 10-03, `xcodebuild build -scheme Islet -configuration Release` (dual-config DEBUG-inertness check)
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 60 seconds (full suite, wave-merge only); per-task scoped commands stay well under 30s

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 10-01-01 | 01 | 1 | TRIAL-01 | Tampering | `trialStatus(startDate:now:length:)` classifies active vs. expired correctly at the boundary | unit | `xcodebuild test -scheme Islet -only-testing:IsletTests/TrialLogicTests` | ✅ built in 10-01 (Wave 0 scaffold) | ⬜ pending |
| 10-01-02 | 01 | 1 | TRIAL-01 | Tampering | Trial start survives `defaults delete` + app reinstall (Keychain, not UserDefaults, is authoritative) | manual | — | ✅ N/A | ⬜ pending |
| 10-01-03 | 01 | 1 | TRIAL-02 | — | First-launch-only Settings auto-open fires exactly once, never on subsequent launches | unit + manual | `xcodebuild test -scheme Islet -only-testing:IsletTests/TrialManagerTests` | ✅ built in 10-01 (Wave 0 scaffold) | ⬜ pending |
| 10-02-01 | 02 | 2 | LIC-03 | Elevation of Privilege | `shouldShow(..., isLicensed: false)` always hides regardless of target/fullscreen state | unit | `xcodebuild test -scheme Islet -only-testing:IsletTests/VisibilityDecisionTests` | ✅ built in 10-02 (signature update) | ⬜ pending |
| 10-02-02 | 02 | 2 | LIC-03 | (UX-adjacent) T-10-07 | Flipping the DEBUG stub from invalid→valid unlocks at the next natural transition, not mid-interaction; deferred via `pendingLockoutHide` | build + manual | `xcodebuild build -scheme Islet` (per-task compile check); manual on-device confirmation at Plan 10-04 | ✅ N/A (mechanism unit-tested indirectly via VisibilityDecisionTests; timing itself is manual-only) | ⬜ pending |
| 10-03-01 | 03 | 2 | TRIAL-01, TRIAL-02, LIC-03, T-10-03 | Elevation of Privilege | DEBUG-only stub-flip status item + click routing exist in Debug, absent from Release | build + manual | `xcodebuild build -scheme Islet` (per-task); `xcodebuild build -scheme Islet -configuration Release` (wave-merge) | ✅ N/A (AppDelegate glue, no dedicated unit-test target) | ⬜ pending |
| 10-03-02 | 03 | 2 | TRIAL-02 | — | Trial-started notice line renders from `TrialManager.shared.trialStartDate()` | build | `xcodebuild build -scheme Islet` | ✅ N/A (SwiftUI glue, no dedicated unit-test target) | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `IsletTests/TrialLogicTests.swift` — new file, covers TRIAL-01's pure classification boundary (active at 2.99 days, expired at exactly 3.0 days, etc.), mirrors `IsletTests/PowerActivityTests.swift`'s style — built as part of 10-01-PLAN.md Task 1 (tdd="true")
- [x] `IsletTests/TrialManagerTests.swift` — new file; uses an injectable `KeychainStore` protocol seam so the "first launch vs. not" boolean logic is testable without touching the real Keychain in CI — built as part of 10-01-PLAN.md Task 2 (tdd="true")
- [x] `IsletTests/VisibilityDecisionTests.swift` — MODIFIED by 10-02-PLAN.md Task 1 (tdd="true"): all 6 current test bodies gain `isLicensed: true`, plus 3+ new `isLicensed: false` dominance tests
- [x] No new test-framework installation needed — `IsletTests` target and `xcodebuild test -scheme Islet` are already fully wired (`project.yml` lines 66-99)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Trial start survives `defaults delete` + reinstall | TRIAL-01 | Inherently requires an actual delete/reinstall cycle on real hardware | Run app once, note Keychain-stored start date, run `defaults delete <bundle-id>`, delete + reinstall app, confirm start date unchanged |
| First-launch notice text + timing | TRIAL-02 | Requires visual confirmation of window content and one-time-only firing | Fresh install → confirm Settings window auto-opens with trial notice; relaunch → confirm it does NOT reopen |
| Stub flip unlocks/locks at next natural transition, never abruptly mid-interaction | LIC-03 (D-13) | Interaction-state timing cannot be asserted by a unit test | Trigger locked state, flip DEBUG stub to valid mid-hover/mid-expansion, confirm no abrupt yank — unlock/lock applies at next natural transition. Note: the deferral mechanism itself (`pendingLockoutHide` in `updateVisibility()`, re-checked from `handleHoverExit`'s grace-elapsed collapse and `handleClick`'s toggle-shut path) is now an engineered guard built in 10-02-PLAN.md Task 2, not just incidental timing — this manual check confirms it holds on real hardware |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 60s (per-task commands are scoped `-only-testing:` or single builds; full-suite/dual-config checks are wave-merge only)
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** 2026-07-05 (approved)
