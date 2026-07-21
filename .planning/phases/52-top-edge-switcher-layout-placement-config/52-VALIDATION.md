---
phase: 52
slug: top-edge-switcher-layout-placement-config
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-07-21
---

# Phase 52 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest, `@testable import Islet` |
| **Config file** | `project.yml` (xcodegen) — `IsletTests` target, shared `Islet` scheme with `test` action |
| **Quick run command** | `xcodebuild test -scheme Islet -only-testing:IsletTests/NotchPillViewTests -only-testing:IsletTests/NotchGeometryTests` |
| **Full suite command** | `xcodebuild test -scheme Islet` (or Cmd-U in Xcode — this project has a documented headless `xcodebuild test` hang precedent per STATE.md; Cmd-U is the established fallback/confirmation step) |
| **Estimated runtime** | ~60-90 seconds (quick) / ~3-5 minutes (full) |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild test -scheme Islet -only-testing:IsletTests/NotchPillViewTests -only-testing:IsletTests/NotchGeometryTests`
- **After every plan wave:** Run `xcodebuild test -scheme Islet` (full suite) or Cmd-U in Xcode
- **Before `/gsd:verify-work`:** Full suite must be green, PLUS an on-device UAT checkpoint for two hardware-dependent findings this research could not verify from source alone: (1) whether the 36pt `navCircleButton` visually fits inside the 42pt `cameraClearance` band (Pitfall 3, D-04), and (2) whether the computed cutout-gap width visually clears the real camera housing on the user's actual MacBook model (Pitfall 2)
- **Max feedback latency:** 90 seconds (quick) / 300 seconds (full)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 52-01-T1 | 52-01 | 1 | SWITCH-04 | — / — | `SelectedView` becomes `@AppStorage`-compatible; `orderedSlotIcons(...)` gives pill + top-edge row one shared ordering source (D-03) | unit (tdd) | `xcodebuild test -scheme Islet -only-testing:IsletTests/NotchPillViewTests` | ✅ task-scoped | ⬜ pending |
| 52-01-T2 | 52-01 | 1 | SWITCH-04 | — / — | `ActivitySettings.SwitcherLayout` enum + 4 slot keys added | unit (tdd) | `xcodebuild test -scheme Islet -only-testing:IsletTests/NotchPillViewTests` | ✅ task-scoped | ⬜ pending |
| 52-01-T3 | 52-01 | 1 | SWITCH-04 | — / — | `NotchGeometry.topEdgeCutoutGap(...)` uses `notchSize(...).width`, not `auxLeftWidth + auxRightWidth` (Pitfall 2) | unit (tdd) | `xcodebuild test -scheme Islet -only-testing:IsletTests/NotchGeometryTests` | ✅ task-scoped | ⬜ pending |
| 52-02-T1 | 52-02 | 2 | SWITCH-04 | — / — | `switcherRow` reorders from shared `orderedSlotIcons` (D-03) | unit (tdd) | `xcodebuild test -scheme Islet -only-testing:IsletTests/NotchPillViewTests` | ✅ task-scoped | ⬜ pending |
| 52-02-T2 | 52-02 | 2 | SWITCH-03 | — / — | `blobShape`/outer-frame/`visibleContentZone` three-site height-math fix: top-edge mode removes exactly the pill row's height, not the whole switcher content height (D-06, Pitfall 1) | unit (tdd) | `xcodebuild test -scheme Islet -only-testing:IsletTests/NotchPillViewTests` (extends `testTabWidthHeightMatchesKnownPerCaseValues`-style locked-values test) | ✅ task-scoped | ⬜ pending |
| 52-02-T3 | 52-02 | 2 | SWITCH-03 | — / V5 (fallback decode) | `topEdgeSwitcherRow` renders 2+2 icons clear of camera cutout, reuses `navCircleButton` verbatim (D-04/D-05); `SelectedView(rawValue:)` falls back safely (`?? .home`) on corrupted stored value | unit (tdd) | `xcodebuild test -scheme Islet -only-testing:IsletTests/NotchPillViewTests` | ✅ task-scoped | ⬜ pending |
| 52-03-T1 | 52-03 | 2 | SWITCH-04 | — / — | New "Switcher" Settings sidebar section: Pill/Top-Edge layout picker + 4 slot dropdowns, default Home+Tray left / Calendar+Weather right (D-01, D-02, D-07) | manual (Settings UI, no automated test per plan) | — | N/A | ⬜ pending |
| 52-03-T2 | 52-03 | 2 | SWITCH-03 | — / — | `visibleSections(hasNotch:)` pure function hides `.switcher` section entirely on non-notch displays (D-08) | unit (tdd) | `xcodebuild test -scheme Islet -only-testing:IsletTests/NotchGeometryTests` (or new `SettingsViewTests.swift`) | ✅ task-scoped | ⬜ pending |
| 52-04-T1 | 52-04 | 3 | SWITCH-03, SWITCH-04 (SC#5) | — / — | Full build + full test regression gate; existing pill-mode tests (`testShelfStripVisibleIsAlwaysFalse`, `testTabWidthHeightMatchesKnownPerCaseValues`) pass unmodified | regression | `xcodebuild test -scheme Islet` (or Cmd-U) | ✅ existing | ⬜ pending |
| 52-04-T2 | 52-04 | 3 (blocking) | SWITCH-03 (SC#2), SWITCH-04 (SC#2/#3/#4) | — / — | On-device UAT: 36pt `navCircleButton` fits 42pt `cameraClearance` (D-04/Pitfall 3); cutout-gap clears real camera housing (Pitfall 2); reorder propagates live; all 5 ROADMAP success criteria walked through | manual (checkpoint:human-verify, gate=blocking) | — (see Manual-Only Verifications below) | N/A | ⬜ pending |

---

## Wave 0 Requirements

- [ ] Extend `IsletTests/NotchPillViewTests.swift` with a top-edge-mode `tabHeight`/`tabWidth` locked-value case (Pitfall 1 regression lock)
- [ ] New pure function `orderedSlotIcons(...)` (or equivalent) + test for default values and override behavior (SWITCH-04)
- [ ] New pure function for cutout-gap-width derivation (or inline in `NotchPillView` if planner judges extraction unnecessary) + test (Pitfall 2)
- [ ] If `SidebarSection` visibility filtering is extracted as a pure function (recommended, mirrors `showsSwitcherRow(for:)`), add its test to a new or existing test file
- Framework install: none — `XCTest`/`IsletTests` target already fully configured

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| 36pt `navCircleButton` visually fits inside 42pt `cameraClearance` band | SWITCH-03 (SC#2), D-04 | Visual/hardware fit cannot be verified from source alone — requires real notched MacBook display | Build and run on-device; enable top-edge layout in Settings; visually confirm no icon clipping or overlap with camera housing |
| Computed cutout-gap width clears real camera housing across MacBook models | SWITCH-04 (SC#2), Pitfall 2 | Physical camera housing dimensions vary by model and cannot be verified from source | Build and run on-device on the user's actual MacBook; visually confirm left/right icon groups clear the camera cutout with no overlap |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 300s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-07-21 (gsd-plan-checker verification pass — no blockers)
