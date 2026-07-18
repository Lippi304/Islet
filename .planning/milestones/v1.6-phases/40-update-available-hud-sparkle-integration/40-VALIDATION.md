---
phase: 40
slug: update-available-hud-sparkle-integration
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-18
---

# Phase 40 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest, `IsletTests` bundle target (`xcodebuild -scheme Islet`) |
| **Config file** | `project.yml`'s `IsletTests` target block (no separate config file) |
| **Quick run command** | `xcodebuild build -scheme Islet -configuration Debug` (build-only gate — see caveat below) |
| **Full suite command** | `Cmd-U` in Xcode (manual) — **NOT** `xcodebuild test` |
| **Estimated runtime** | ~30-60s build |

**Critical project-specific caveat** (project memory `xcodebuild-test-headless-hang`): `xcodebuild test` hangs in this project because tests are hosted inside the full `Islet.app`, which boots the real `NSPanel`/`MediaRemote`/`IOBluetooth` machinery. Use `build` as the automated per-task gate; route actual test execution to a manual `Cmd-U` pass in Xcode.

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild build -scheme Islet -configuration Debug`
- **After every plan wave:** Run `Cmd-U` full suite in Xcode (manual)
- **Before `/gsd:verify-work`:** Full manual `Cmd-U` pass + all on-device checkpoints below must be green
- **Max feedback latency:** ~60 seconds (build-only gate)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 40-01-xx | 01 | 1 | HUD-06 | — | `SPUStandardUpdaterController` constructs without crashing, "Check for Updates…" menu item present and wired | build-only smoke check | `xcodebuild build -scheme Islet -configuration Debug` | N/A — no pure-logic file to unit test | ⬜ pending |
| 40-0x-xx | TBD | TBD | HUD-06 | — | Badge renders when `updateAvailable == true && !isExpanded`, absent otherwise | manual on-device / Cmd-U, or unit test if `shouldShowUpdateBadge(updateAvailable:isExpanded:) -> Bool` is factored out | `Cmd-U` in Xcode | ❌ W0 — no dedicated badge-visibility test exists yet | ⬜ pending |
| 40-0x-xx | TBD | TBD | HUD-06 | — | Release build launches without a Gatekeeper/library-validation crash with Sparkle embedded | manual, on-device, `-configuration Release` | manual archive + launch | N/A — inherently Release-only manual check | ⬜ pending |
| 40-0x-xx | TBD | TBD | HUD-06 | — | Tapping the badge/menu item surfaces Sparkle's dialog without breaking click-through/non-activating guarantees | manual on-device | N/A — human on-device check | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Optional: `shouldShowUpdateBadge(updateAvailable:isExpanded:) -> Bool` pure function + `UpdateAvailableStateTests.swift` (or an addition to `NotchPillViewTests.swift`) — matches this codebase's convention of a pure-logic test per boolean-gated presentation branch (`FocusActivityTests`, `OSDActivityTests`, `PowerActivityTests`). Planner discretion (YAGNI) if judged unnecessary given the badge's trivial gating logic.

*No test-framework install needed — `IsletTests` already exists and covers this project's testing conventions.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|--------------------|
| Release build launches without Gatekeeper/library-validation crash with Sparkle embedded | HUD-06 | Requires archived Release build + real launch outside Xcode debugger | Archive with `-configuration Release`, launch the built `.app` directly, confirm no crash |
| Tapping badge/menu item surfaces Sparkle dialog without stealing focus or breaking click-through | HUD-06 | Requires human observation of focus/panel behavior on-device | Trigger update-available state, tap badge, confirm Sparkle's dialog appears and panel click-through/non-activating behavior elsewhere is unaffected |
| No unprompted Sparkle permission alert on second launch (`SUEnableAutomaticChecks` Info.plist pitfall) | HUD-06 | Runtime permission-prompt behavior only observable via real app launches | Launch app twice, confirm no unexpected Sparkle permission dialog appears |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
