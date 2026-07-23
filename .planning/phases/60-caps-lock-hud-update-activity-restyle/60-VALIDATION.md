---
phase: 60
slug: caps-lock-hud-update-activity-restyle
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-23
---

# Phase 60 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (`IsletTests/`), `@testable import Islet` |
| **Config file** | Xcode scheme `Islet` (no standalone `.xctestplan` found) |
| **Quick run command** | Xcode `Cmd+U` (headless `xcodebuild test` is documented in this project to hang — see `PROJECT.md`; do NOT rely on scripted test execution) |
| **Full suite command** | Same — manual Cmd+U in Xcode is this project's only confirmed-working test-execution path |
| **Estimated runtime** | Manual, ~1-2 min per Cmd+U run |

---

## Sampling Rate

- **After every task commit:** Cmd+U on the affected test class (`IslandResolverTests`, `ActivitySettingsTests`)
- **After every plan wave:** Full Cmd+U suite (all `IsletTests/*.swift`)
- **Before `/gsd:verify-work`:** Full suite green (aside from the 2 pre-existing unrelated `CalendarGlanceTests` failures noted in STATE.md Phase 52) plus on-device checkpoint approval
- **Max feedback latency:** Manual — no automated CI in this project (build/test is Xcode-only)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 60-01-TBD | TBD | 0 | CAPS-01 | V4 (Accessibility gate) | Global monitor never fires without `AXIsProcessTrusted()` | unit | Cmd+U → `IslandResolverTests.testCapsLockCollapsedOnly` | ❌ Wave 0 | ⬜ pending |
| 60-01-TBD | TBD | 0 | CAPS-01 | — | `resolve()` falls through to expanded view when `isExpanded` | unit | Cmd+U → `IslandResolverTests.testCapsLockFallsThroughWhenExpanded` | ❌ Wave 0 | ⬜ pending |
| 60-01-TBD | TBD | — | CAPS-01 | V4 | Accessibility-gated activation only observable on-device | manual/on-device | on-device checkpoint | N/A | ⬜ pending |
| 60-02-TBD | TBD | 0 | UPDATE-01 | — | `resolve()` returns `.updateAvailable` when collapsed, falls through when expanded | unit | Cmd+U → `IslandResolverTests.testUpdateAvailableCollapsedOnly` / `testUpdateAvailableFallsThroughWhenExpanded` | ❌ Wave 0 | ⬜ pending |
| 60-02-TBD | TBD | 0 | UPDATE-01 | — | New `updateHudKey` toggle defaults OFF and gates HUD activation | unit | Cmd+U → `ActivitySettingsTests` | ❌ Wave 0 | ⬜ pending |
| 60-02-TBD | TBD | — | UPDATE-01 | — | Tap-to-install triggers correct action, no click-through regression | manual/on-device | on-device checkpoint (mock appcast) | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky — exact Task IDs/Plan/Wave to be finalized by the planner; this map records the required coverage per requirement.*

---

## Wave 0 Requirements

- [ ] `IsletTests/IslandResolverTests.swift` — add `testCapsLockCollapsedOnly`, `testCapsLockFallsThroughWhenExpanded`, `testUpdateAvailableCollapsedOnly`, `testUpdateAvailableFallsThroughWhenExpanded` (mirrors existing `testFocus*`/`testOSD*` naming convention already in the file)
- [ ] `IsletTests/ActivitySettingsTests.swift` — add coverage for the new `updateHudKey` default-false behavior (mirrors existing per-key tests)
- [ ] No framework install needed — XCTest already fully wired

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Accessibility-gated global monitor actually fires `.flagsChanged` only when trusted, and reconciles correctly (live vs. relaunch) when trust is granted mid-session | CAPS-01 | TCC permission state cannot be simulated in XCTest; live vs. relaunch reconciliation is an open research question (A2) | Toggle Caps Lock with Accessibility ungranted (expect no HUD) → grant Accessibility via Settings deep-link → toggle again without relaunching (confirm whether HUD now fires or an app relaunch is required) → toggle on/off, confirm HUD auto-dismiss ~1-2s each direction |
| Update HUD tap-to-install hits the correct target without reproducing the Phase 40 click-through/hot-zone bug | UPDATE-01 | Click-through/window hot-zone behavior cannot be asserted via XCTest, per this codebase's own established precedent | Trigger a mock `didFindValidUpdate` callback, confirm Update HUD appears with icon/label/version pill, tap it, confirm install flow triggers and no disappearing-island/click-through glitch occurs |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < N/A (manual Cmd+U only, per project constraint)
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
