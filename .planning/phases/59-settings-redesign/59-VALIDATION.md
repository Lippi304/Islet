---
phase: 59
slug: settings-redesign
status: final
nyquist_compliant: true
wave_0_complete: true
created: 2026-07-23
---

# Phase 59 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest, `IsletTests` target (`@testable import Islet`) |
| **Config file** | `Islet.xcodeproj` / `project.yml` (xcodegen-managed), no separate test config |
| **Quick run command** | `xcodebuild -project Islet.xcodeproj -scheme Islet build` (build-only — do NOT run `xcodebuild test` headlessly; it hangs in this repo due to a Bluetooth TCC-authorization wait in `BluetoothMonitor`, documented in `PROJECT.md` line 425, reconfirmed at Phase 56/58) |
| **Full suite command** | Manual Cmd-U in Xcode (interactive session required) |
| **Estimated runtime** | ~30-60s (build-only quick run) |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild -project Islet.xcodeproj -scheme Islet build`
- **After every plan wave:** Manual Cmd-U in Xcode for the full `IsletTests` suite (existing `ActivitySettingsTests`, new card/migration tests, `IslandResolverTests` regression)
- **Before `/gsd:verify-work`:** On-device UAT (SC2 toggle-behavior, SC3 fresh-install default-OFF check, SC4 pre-seeded-domain upgrade-simulation check) must pass
- **Max feedback latency:** ~60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 59-01-01 | 01 | 1 | SETTINGS-05 | T-59-01 | Existing activity toggle state preserved exactly across upgrade, proven against a pre-seeded (not fresh) `UserDefaults` domain, not a key-name string match (SC4) | unit | `xcodebuild build` — `IsletTests/ActivitySettingsTests.swift::testChargingAppStorageReadsSeededValueNotCompiledDefault` | ✅ | ⬜ pending |
| 59-01-03 | 01 | 1 | SETTINGS-04/05 | — | Resolver-priority table exists and matches current code (SC5) | manual | N/A — table authored in 59-01 Task 3, accuracy reviewed against live `resolve()`/`TransientQueue` logic in 59-02 Task 3 UAT step 12 | — | ⬜ pending |
| 59-02-01 | 02 | 2 | SETTINGS-04 | — | Grid renders one card per activity, grouped by category (D-01/D-02/D-03/D-07) | unit | `xcodebuild build` — `IsletTests/SettingsViewTests.swift` `systemHUDCards`/`mediaCards`/`productivityCards` count/ordering/`isNew` assertions | ✅ | ⬜ pending |
| 59-02-01 | 02 | 2 | SETTINGS-05 | T-59-01 | Every new v1.10 activity key defaults `false`, no exceptions (SC3) | unit (declaration) + manual (runtime) | `grep -cE '@AppStorage\(ActivitySettings\.\w+Key\) private var \w+Enabled = false'` returns 8 (Task 1 acceptance_criteria) + on-device UAT step 8 | ✅ (grep) / manual UAT (runtime) | ⬜ pending |
| 59-02-03 | 02 | 2 | SETTINGS-04 | T-59-03 | Toggling a card enables/disables the activity exactly like today (SC2) | manual | N/A — on-device UAT checkpoint, step 6 | — | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `IsletTests/ActivitySettingsTests.swift` — default-value coverage for the 8 new keys (SETTINGS-05 SC3) — key-name existence via 59-01 Task 1's `testNewV110KeyNames()`; compiled `= false` default via 59-02 Task 1's `@AppStorage` declarations, grep-verified in that task's acceptance_criteria; runtime confirmed on-device in 59-02 Task 3 UAT step 8.
- [x] Pre-seeded `UserDefaults(suiteName:)` domain test asserting existing-key values survive unchanged through the read path (SETTINGS-05 SC4) — covered by 59-01 Task 1's new `testChargingAppStorageReadsSeededValueNotCompiledDefault()`.
- [x] No new test framework/config needed — `IsletTests` target and XCTest already fully cover this phase's testing needs.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|--------------------|
| Toggling a card enables/disables the activity exactly like today | SETTINGS-04 (SC2) | No headless mechanism observes actual `IslandPresentation` behavior change | Toggle each card on/off in Settings, confirm the island shows/hides the activity |
| Resolver-priority table matches current code | SETTINGS-04/05 (SC5) | Documentation-review checkpoint, not a runtime test | Compare the authored table against `IslandResolver.swift`'s `resolve()`/`TransientQueue` logic line-by-line |
| Fresh-install default-OFF check for new activities | SETTINGS-05 (SC3) | Requires a genuinely fresh `UserDefaults` domain, not simulable headlessly in this repo's CI | Fresh install/reset defaults, open Settings, confirm all 8 new activity cards show OFF |
| Pre-seeded-domain upgrade-simulation check | SETTINGS-05 (SC4) | Requires simulating an upgrading user's pre-existing `UserDefaults` state on-device (real app process, not just the isolated unit test) | Pre-seed defaults matching a pre-v1.10 user, launch app, confirm existing toggle states unchanged |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies — every `auto`/`tdd` task across both plans carries an `<automated>xcodebuild -project Islet.xcodeproj -scheme Islet build</automated>` verify; the sole `checkpoint:human-verify` task (59-02 Task 3) is the phase-gate UAT, not a substitute for a missing automated check.
- [x] Sampling continuity: no 3 consecutive tasks without automated verify — 59-01 Tasks 1-3 and 59-02 Tasks 1-2 all carry `xcodebuild build`; only 59-02 Task 3 (on-device UAT) is manual, and it is the terminal phase-gate task, not a mid-sequence gap.
- [x] Wave 0 covers all MISSING references — both RESEARCH.md Wave 0 Gaps items are now implemented: SC3 via 59-02 Task 1's `= false` declarations (grep-verified) + UAT step 8, SC4 via 59-01 Task 1's new `testChargingAppStorageReadsSeededValueNotCompiledDefault` test.
- [x] No watch-mode flags — confirmed, all automated verification is one-shot `xcodebuild build`.
- [x] Feedback latency < 60s — `xcodebuild build` runs in ~30-60s per the Test Infrastructure table above.
- [x] `nyquist_compliant: true` set in frontmatter — set above; the previously-missing SC4 automated regression test now exists in 59-01 Task 1.

**Approval:** approved (Task ID/Plan/Wave references filled in against 59-01/59-02; SC4 automated-regression gap closed by 59-01 Task 1's pre-seeded-domain test, matching PATTERNS.md's `UserDefaults(suiteName:)` precedent)
