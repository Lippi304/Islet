---
phase: 52
slug: top-edge-switcher-layout-placement-config
status: draft
nyquist_compliant: false
wave_0_complete: false
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
| TBD-01 | TBD | 0 | SWITCH-03 | — / — | `tabHeight`/`tabWidth` in top-edge mode reserve `switcherContentHeight` for content but NOT `+switcherRowHeight` for the absent pill row | unit | `xcodebuild test -scheme Islet -only-testing:IsletTests/NotchPillViewTests` | ❌ W0 — extend `testTabWidthHeightMatchesKnownPerCaseValues`-style locked-values test | ⬜ pending |
| TBD-02 | TBD | 0 | SWITCH-03 | — / — | `hasNotch` gates Settings `.switcher` section visibility (D-08) | unit | `xcodebuild test -scheme Islet -only-testing:IsletTests/NotchGeometryTests` | ❌ W0 — extract `visibleSidebarSections(hasNotch:)` pure function, mirroring `showsSwitcherRow(for:)` | ⬜ pending |
| TBD-03 | TBD | 0 | SWITCH-04 | — / — | Default slot assignment is Home+Tray left, Calendar+Weather right | unit | New test asserting `@AppStorage` default values / default `orderedSlotIcons` array | ❌ W0 | ⬜ pending |
| TBD-04 | TBD | 0 | SWITCH-04 | — / V5 (fallback decode) | Reassigning a slot updates both `switcherRow`'s pill order and top-edge row position from one shared state; `SelectedView(rawValue:)` falls back safely (`?? .home`) on corrupted stored value | unit | New test overriding `UserDefaults` slot keys (mirrors `weatherStyleKey` override-and-restore pattern), asserting `orderedSlotIcons` reflects override | ❌ W0 | ⬜ pending |
| TBD-05 | TBD | 0 | SWITCH-04 | — / — | Cutout-gap width uses `notchSize(...).width`, not `auxLeftWidth + auxRightWidth` (Pitfall 2) | unit | If extracted as `topEdgeCutoutGap(descriptor:)`, directly testable with hand-built `ScreenDescriptor` values, mirroring `DisplayResolverTests.swift` | ❌ W0 | ⬜ pending |
| TBD-06 | TBD | — | SWITCH-03 (SC#5) | — / — | Existing pill mode shows no regression | regression | `testShelfStripVisibleIsAlwaysFalse` + `testTabWidthHeightMatchesKnownPerCaseValues` (existing, `NotchPillViewTests.swift`) must still pass unmodified | ✅ existing | ⬜ pending |

*Task IDs above are placeholders (`TBD-NN`) — the planner assigns real plan/task IDs; this map's rows must be re-keyed to match once PLAN.md files exist.*

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

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 300s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
