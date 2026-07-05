---
phase: 10
slug: trial-lockout-gate
status: draft
nyquist_compliant: false
wave_0_complete: false
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
| **Estimated runtime** | ~60 seconds |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild test -scheme Islet -only-testing:IsletTests/TrialLogicTests -only-testing:IsletTests/VisibilityDecisionTests`
- **After every plan wave:** Run `xcodebuild test -scheme Islet` (full suite)
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 10-01-01 | 01 | 0 | TRIAL-01 | Tampering | `trialStatus(startDate:now:length:)` classifies active vs. expired correctly at the boundary | unit | `xcodebuild test -scheme Islet -only-testing:IsletTests/TrialLogicTests` | ❌ W0 | ⬜ pending |
| 10-01-02 | 01 | 0 | TRIAL-01 | Tampering | Trial start survives `defaults delete` + app reinstall (Keychain, not UserDefaults, is authoritative) | manual | — | ✅ N/A | ⬜ pending |
| 10-01-03 | 01 | 0 | TRIAL-02 | — | First-launch-only Settings auto-open fires exactly once, never on subsequent launches | unit + manual | `xcodebuild test -scheme Islet -only-testing:IsletTests/TrialManagerTests` | ❌ W0 | ⬜ pending |
| 10-01-04 | 01 | 1 | LIC-03 | Elevation of Privilege | `shouldShow(..., isLicensed: false)` always hides regardless of target/fullscreen state | unit | `xcodebuild test -scheme Islet -only-testing:IsletTests/VisibilityDecisionTests` | ✅ (needs signature update) | ⬜ pending |
| 10-01-05 | 01 | 1 | LIC-03 | (UX-adjacent) | Flipping the DEBUG stub from invalid→valid unlocks at the next natural transition, not mid-interaction | manual | — | ✅ N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `IsletTests/TrialLogicTests.swift` — new file, covers TRIAL-01's pure classification boundary (active at 2.99 days, expired at exactly 3.0 days, etc.), mirrors `IsletTests/PowerActivityTests.swift`'s style
- [ ] `IsletTests/TrialManagerTests.swift` — new file; needs a small injection seam (e.g. `TrialManager` taking a `KeychainReading`/`KeychainWriting` protocol, or a fake-clock wrapper around `TrialManager`'s pure decision surface) so the "first launch vs. not" boolean logic is testable without touching the real Keychain in CI
- [ ] `IsletTests/VisibilityDecisionTests.swift` — MODIFY existing file: all 6 current test bodies need `isLicensed: true` added to their `shouldShow(...)` calls (breaking signature change), plus new tests for `isLicensed: false` dominating every other combination
- [ ] No new test-framework installation needed — `IsletTests` target and `xcodebuild test -scheme Islet` are already fully wired (`project.yml` lines 66-99)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Trial start survives `defaults delete` + reinstall | TRIAL-01 | Inherently requires an actual delete/reinstall cycle on real hardware | Run app once, note Keychain-stored start date, run `defaults delete <bundle-id>`, delete + reinstall app, confirm start date unchanged |
| First-launch notice text + timing | TRIAL-02 | Requires visual confirmation of window content and one-time-only firing | Fresh install → confirm Settings window auto-opens with trial notice; relaunch → confirm it does NOT reopen |
| Stub flip unlocks at next natural transition | LIC-03 | Interaction-state timing cannot be asserted by a unit test | Trigger locked state, flip DEBUG stub to valid mid-hover/mid-expansion, confirm no abrupt yank — unlock applies at next natural transition |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
