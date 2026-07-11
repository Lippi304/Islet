---
phase: 26
slug: onboarding-flow
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-11
---

# Phase 26 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (native Xcode test target `IsletTests`) |
| **Config file** | none — standard Xcode scheme, no `.xctestplan` found |
| **Quick run command** | `xcodebuild build -project Islet.xcodeproj -scheme Islet -configuration Debug` (build-only gate) |
| **Full suite command** | Manual `Cmd-U` in Xcode (per project memory `xcodebuild-test-headless-hang`: `xcodebuild test` hangs because tests boot the real `NSPanel`/MediaRemote/IOBluetooth stack) |
| **Estimated runtime** | ~30s build gate; Cmd-U run a few minutes |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild build -project Islet.xcodeproj -scheme Islet -configuration Debug`
- **After every plan wave:** Full Cmd-U run in Xcode GUI for pure-logic suites (`IslandResolverTests`, `InteractionStateTests`, any new `OnboardingFlowTests`/gate tests) + a Release-configuration build pass (per project memory `release-library-validation-crash`)
- **Before `/gsd:verify-work`:** On-device manual UAT for all 3 permission prompts + full carousel flow (skippable-per-step behavior, Settings round-trip for license entry, Done screen's Launch-at-Login toggle) — this phase's core behaviors (real system permission prompts, real window focus handoff, real animation feel) are exactly what XCTest cannot exercise (per `xcodebuild-test-headless-hang` and `feedback-xcode-gui-not-terminal` memories)
- **Max feedback latency:** ~30s (build gate)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 26-01-xx | 01 | 1 | ONBOARD-01 | T-26-02 | New `.onboarding` case wins over `.idle`/transients in `resolve()` when onboarding flag unset | unit | `IslandResolverTests.swift::testOnboardingOutranksEverything()` | ❌ Wave 0 (extend existing file) | ⬜ pending |
| 26-01-xx | 01 | 1 | ONBOARD-01 | — | Step sequencing (welcome → trial/license/buy → permissions → done, Next/Back) | unit | New `OnboardingFlowTests.swift` (pure-reducer shape, mirrors `InteractionStateTests.swift`) | ❌ Wave 0 | ⬜ pending |
| 26-0x-xx | TBD | TBD | ONBOARD-02 | T-26-01 | Bluetooth/location/calendar NOT called when `onboarding.completed == false` at genuinely fresh launch | unit (pure gate function) | `shouldGatePermissionCallsAtLaunch(isFirstLaunch:onboardingCompleted:)` tested in gate-function test file | ❌ Wave 0 | ⬜ pending |
| 26-0x-xx | TBD | TBD | ONBOARD-02 | — | Each permission row fires exactly its own system prompt, independently | manual-only | On-device Cmd-U cannot exercise real TCC prompts | N/A — manual | ⬜ pending |
| 26-0x-xx | TBD | TBD | ONBOARD-03 | T-26-03 | Onboarding flag persists, flow shows exactly once | unit | `UserDefaults`-backed flag, injected `UserDefaults(suiteName:)` fixture (mirrors `TrialManagerTests.swift`) | ❌ Wave 0 | ⬜ pending |
| 26-0x-xx | TBD | TBD | ONBOARD-03 | — | No gesture/tutorial screen exists anywhere in the flow | manual/code-review | Grep-verifiable: no new gesture/tutorial-named view | N/A | ⬜ pending |

*Task IDs and plan/wave numbers to be filled in by the planner once PLAN.md files exist.*

---

## Wave 0 Requirements

- [ ] `OnboardingFlowTests.swift` — if a dedicated pure `OnboardingFlow.swift` seam is added, needs its own test file from the start (Wave 1, not retrofitted)
- [ ] Extend `IslandResolverTests.swift` with the onboarding-precedence case
- [ ] No framework install needed — XCTest is already fully wired

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Each permission row (Bluetooth/Calendar/Location) fires its own real system TCC prompt, in sequence | ONBOARD-02 | Real IOBluetooth/CLLocationManager/EKEventStore calls can't be exercised headlessly; TCC prompts require a real interactive launch | Fresh install (or reset TCC + onboarding flag), launch app, tap each permission row's Continue/Grant individually, confirm each fires its own system dialog and denial/skip shows quiet "not granted" state without blocking |
| Notch-hosted carousel navigation (Next/Back) inside the real expanded `NotchPanel`, matching Droppy reference feel | ONBOARD-01 | Visual/animation polish and `matchedGeometryEffect` morph feel are not XCTest-verifiable | On-device: step through Welcome → Trial/License/Buy → Permissions → Done, confirm spring animation and shape morph read as intended |
| Settings round-trip for license-key entry and skipped-permission re-grant, then resume back to notch | ONBOARD-01/ONBOARD-02 | Cross-window focus handoff (`NotchPanel.canBecomeKey=false` invariant) can only be verified with real window state | On-device: trigger Settings hand-off from onboarding, complete/cancel in Settings, confirm flow resumes/completes correctly |
| Onboarding shows exactly once across app relaunches | ONBOARD-03 | Persisted flag behavior across real process restarts | Fresh install → complete onboarding → quit/relaunch app → confirm onboarding does not reappear |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s (build gate)
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
