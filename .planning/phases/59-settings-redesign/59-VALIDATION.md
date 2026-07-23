---
phase: 59
slug: settings-redesign
status: draft
nyquist_compliant: false
wave_0_complete: false
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
| TBD | TBD | TBD | SETTINGS-04 | — | Grid renders one card per activity, grouped by category | unit | `xcodebuild build` + `ActivityCardTests`-style assertions on card array counts/ordering | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | SETTINGS-04 | — | Toggling a card enables/disables the activity exactly like today (SC2) | manual | N/A — on-device UAT checklist item | — | ⬜ pending |
| TBD | TBD | TBD | SETTINGS-05 | — | Every new v1.10 activity key defaults `false` (SC3) | unit | `ActivitySettingsTests.swift`-style `XCTAssertEqual(defaults.bool(forKey:), false)` per new key | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | SETTINGS-05 | — | Existing activity toggle state preserved exactly across upgrade (SC4) | unit | New test: seed `UserDefaults(suiteName:)` with non-default value for an existing key, assert card-array binding reads seeded value | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | SETTINGS-04/05 | — | Resolver-priority table exists and matches current code (SC5) | manual | N/A — plan-checker/human review against `IslandResolver.swift`'s `resolve()`/`TransientQueue` logic | — | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `IsletTests/ActivitySettingsTests.swift` — add default-value assertions for the 8 new keys (covers SETTINGS-05 SC3)
- [ ] A new or extended test — pre-seeded `UserDefaults(suiteName:)` domain asserting existing-key values survive unchanged through the new card-array binding path (covers SETTINGS-05 SC4; this is the one genuinely new test shape this phase needs)
- [ ] No new test framework/config needed — `IsletTests` target and XCTest already fully cover this phase's testing needs

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|--------------------|
| Toggling a card enables/disables the activity exactly like today | SETTINGS-04 (SC2) | No headless mechanism observes actual `IslandPresentation` behavior change | Toggle each card on/off in Settings, confirm the island shows/hides the activity |
| Resolver-priority table matches current code | SETTINGS-04/05 (SC5) | Documentation-review checkpoint, not a runtime test | Compare the authored table against `IslandResolver.swift`'s `resolve()`/`TransientQueue` logic line-by-line |
| Fresh-install default-OFF check for new activities | SETTINGS-05 (SC3) | Requires a genuinely fresh `UserDefaults` domain, not simulable headlessly in this repo's CI | Fresh install/reset defaults, open Settings, confirm all 8 new activity cards show OFF |
| Pre-seeded-domain upgrade-simulation check | SETTINGS-05 (SC4) | Requires simulating an upgrading user's pre-existing `UserDefaults` state on-device | Pre-seed defaults matching a pre-v1.10 user, launch app, confirm existing toggle states unchanged |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
