---
phase: 3
slug: charging-activity
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-27
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Derived from `03-RESEARCH.md` § Validation Architecture.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (existing `IsletTests` target, hosted in Islet.app) |
| **Config file** | `project.yml` (XcodeGen) → `IsletTests` target; scheme `Islet` runs it on `test` |
| **Quick run command** | `xcodebuild test -scheme Islet -only-testing:IsletTests/PowerActivityTests -destination 'platform=macOS'` |
| **Full suite command** | `xcodebuild test -scheme Islet -destination 'platform=macOS'` |
| **Estimated runtime** | ~30–60 seconds (Xcode build + boot of test host) |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild test -scheme Islet -only-testing:IsletTests/PowerActivityTests -destination 'platform=macOS'`
- **After every plan wave:** Run `xcodebuild test -scheme Islet -destination 'platform=macOS'` (full suite green)
- **Before `/gsd-verify-work`:** Full suite green **and** on-device UAT (plug/unplug splash, charging-vs-full, on-battery, desktop no-op, fullscreen no-show)
- **Max feedback latency:** ~60 seconds

---

## Per-Task Verification Map

> Task IDs are assigned by the planner. Rows are keyed to requirement + pure-seam test
> functions from the research test matrix; the planner maps each to the owning task/plan.

| Behavior | Requirement | Test Type | Automated Command (test function) | File Exists | Status |
|----------|-------------|-----------|-----------------------------------|-------------|--------|
| `powerActivity` returns `.charging(p)` on AC+charging | CHG-01 | unit | `…/PowerActivityTests/testChargingMapsToCharging` | ❌ W0 | ⬜ pending |
| distinguishes charging from plugged-but-full (`.full`) | CHG-01 | unit | `…/PowerActivityTests/testOnACNotChargingMapsToFull` | ❌ W0 | ⬜ pending |
| `nil` (no splash) when no battery present (desktop) | CHG-01 | unit | `…/PowerActivityTests/testNoBatteryMapsToNil` | ❌ W0 | ⬜ pending |
| percent clamped to 0…100 | CHG-01 | unit | `…/PowerActivityTests/testPercentClamped` | ❌ W0 | ⬜ pending |
| `.onBattery(p)` on unplug | CHG-02 | unit | `…/PowerActivityTests/testOnBatteryMapsToOnBattery` | ❌ W0 | ⬜ pending |
| category transition fires a splash; pure % tick does not | CHG-01/02 | unit | `…/PowerActivityTests/testTransitionTriggersSplash` | ❌ W0 | ⬜ pending |
| wings frame centers on midX + pins to top | CHG-01 | unit | `…/NotchGeometryTests/testWingsFrame*` | ❌ W0 (extend) | ⬜ pending |
| real splash appears/animates/auto-dismisses on plug/unplug; not in fullscreen; no-op on no-battery | CHG-01/02 | manual (on-device) | — (IOKit + AppKit + SwiftUI wiring; UAT) | manual | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `IsletTests/PowerActivityTests.swift` — stubs for CHG-01 / CHG-02 (the `powerActivity(from:)` matrix + the no-battery `nil` path)
- [ ] `Islet/Notch/PowerActivity.swift` — the pure seam under test (`PowerReading` / `ChargingActivity` / `powerActivity(from:)`)
- [ ] (If wings-frame math is added) extend `IsletTests/NotchGeometryTests.swift` + `Islet/Notch/NotchGeometry.swift` with `wingsFrame(...)`
- [ ] (If the splash-debounce predicate is made pure) `shouldTriggerSplash(previous:next:)` + tests
- [ ] Framework install: **none** — `IsletTests` already exists and runs.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Splash appears + slides out wings + battery fills + glow on real plug-in, auto-collapses ~3s | CHG-01 | Real hardware power event + window compositing can't be unit-tested | Run app, plug in the MagSafe/USB-C charger, observe the charging splash beside the notch with battery % then auto-collapse |
| Brief "on battery" splash on unplug | CHG-02 | Hardware event | Unplug the charger while app runs; observe plain-battery splash |
| Charging vs plugged-in-but-full distinction | CHG-01 | Requires a near-full battery state | Plug in at <100% (bolt) vs at 100% (full/green, no bolt) |
| Sane on a Mac with no readable charging state | CHG-01 | Needs a no-battery host (or simulated empty power-source list) | On a Mac mini / external display setup with no battery: no splash, no crash |
| No splash while a fullscreen app owns the notch | CHG-01 | Window-level/Spaces compositing | Enter a true-fullscreen app, plug in: splash must NOT appear (routes through `updateVisibility()`) |
| Idle CPU ~0% (event-driven, no polling) | CHG-01 | Runtime profiling | Activity Monitor / `sample` after the splash collapses — near-0% with no timer ticks |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (`PowerActivity.swift`, `PowerActivityTests.swift`)
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
