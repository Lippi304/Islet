---
phase: 3
slug: charging-activity
status: validated
nyquist_compliant: true
wave_0_complete: true
created: 2026-06-27
validated: 2026-06-27
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
| `powerActivity` returns `.charging(p)` on AC+charging | CHG-01 | unit | `…/PowerActivityTests/testChargingMapsToCharging` | ✅ | ✅ green |
| distinguishes charging from plugged-but-full (`.full`) | CHG-01 | unit | `…/PowerActivityTests/testOnACNotChargingMapsToFull` (+ `testChargedMapsToFull` for `kIOPSIsChargedKey`) | ✅ | ✅ green |
| `nil` (no splash) when no battery present (desktop) | CHG-01 | unit | `…/PowerActivityTests/testNoBatteryMapsToNil` | ✅ | ✅ green |
| percent clamped to 0…100 | CHG-01 | unit | `…/PowerActivityTests/testPercentClampedLow` + `testPercentClampedHigh` | ✅ | ✅ green |
| `.onBattery(p)` classification on unplug (model only — no splash, CHG-02 connect-only) | CHG-02 | unit | `…/PowerActivityTests/testOnBatteryMapsToOnBattery` | ✅ | ✅ green |
| category transition fires a splash; pure % tick does not | CHG-01/02 | unit | `…/PowerActivityTests/shouldTriggerSplash` suite — 9 cases (`testPlugInWhileDischargingTriggers`, `testPlugInAlreadyFullTriggers`, `testNilToOnACTriggers`, `testSameCategoryTickDoesNotTrigger`, `testTopOffChargingToFullDoesNotTrigger`, `testUnplugDoesNotTrigger`, `testUnplugWhileFullDoesNotTrigger`, `testNilToOnBatteryDoesNotTrigger`, `testActivityToNilDoesNotTrigger`) | ✅ | ✅ green |
| connect-only: unplug deliberately shows nothing (CHG-02 descope) | CHG-02 | unit | `…/PowerActivityTests/testUnplugDoesNotTrigger`, `testUnplugWhileFullDoesNotTrigger`, `testActivityToNilDoesNotTrigger` | ✅ | ✅ green |
| wings frame centers on midX + pins to top | CHG-01 | unit | `…/NotchGeometryTests/testWingsFrameCentersOnMidXAndPinsTop`, `testWingsFrameOnNonZeroOriginScreen`, `testWingsFrameDegenerateEqualsCollapsedWhenSameSize` | ✅ | ✅ green |
| real splash appears/animates/auto-dismisses on plug; not in fullscreen; no-op on no-battery | CHG-01 | manual (on-device) | — (IOKit + AppKit + SwiftUI wiring; UAT) | manual | ✅ green (UAT 2026-06-27) |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

**Result:** 16 `PowerActivityTests` + 3 `wingsFrame` cases in `NotchGeometryTests` — all green
(`xcodebuild test … -only-testing:IsletTests/PowerActivityTests -only-testing:IsletTests/NotchGeometryTests` → 32 executed, 0 failures, 2026-06-27).

---

## Wave 0 Requirements

- [x] `IsletTests/PowerActivityTests.swift` — full CHG-01 / CHG-02 matrix (16 tests: `powerActivity(from:)` matrix + no-battery `nil` path + `shouldTriggerSplash` suite)
- [x] `Islet/Notch/PowerActivity.swift` — the pure seam under test (`PowerReading` / `ChargingActivity` / `powerActivity(from:)`)
- [x] Extended `IsletTests/NotchGeometryTests.swift` + `Islet/Notch/NotchGeometry.swift` with `wingsFrame(...)` (3 tests)
- [x] `shouldTriggerSplash(previous:next:)` made pure in `PowerActivity.swift` + 9 tests (transition-gated, connect-only)
- [x] Framework install: **none** — `IsletTests` already exists and runs.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Splash appears + slides out wings + battery fills + glow on real plug-in, auto-collapses ~3s | CHG-01 | Real hardware power event + window compositing can't be unit-tested | Run app, plug in the MagSafe/USB-C charger, observe the charging splash beside the notch with battery % then auto-collapse |
| ~~Brief "on battery" splash on unplug~~ **DESCOPED → connect-only** (CHG-02, UAT 2026-06-27) | CHG-02 | No longer manual — the "no splash on unplug" behavior is now asserted by automated tests (`testUnplugDoesNotTrigger`, `testUnplugWhileFullDoesNotTrigger`, `testActivityToNilDoesNotTrigger`) | n/a — unplug deliberately shows nothing; verify only that unplugging produces no splash |
| Charging vs plugged-in-but-full distinction | CHG-01 | Requires a near-full battery state | Plug in at <100% (bolt) vs at 100% (full/green, no bolt) |
| Sane on a Mac with no readable charging state | CHG-01 | Needs a no-battery host (or simulated empty power-source list) | On a Mac mini / external display setup with no battery: no splash, no crash |
| No splash while a fullscreen app owns the notch | CHG-01 | Window-level/Spaces compositing | Enter a true-fullscreen app, plug in: splash must NOT appear (routes through `updateVisibility()`) |
| Idle CPU ~0% (event-driven, no polling) | CHG-01 | Runtime profiling | Activity Monitor / `sample` after the splash collapses — near-0% with no timer ticks |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references (`PowerActivity.swift`, `PowerActivityTests.swift`)
- [x] No watch-mode flags
- [x] Feedback latency < 60s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** ✅ validated 2026-06-27 — all automated-testable requirements green; remaining items are genuinely manual (hardware power events, window compositing, idle-CPU profiling).

---

## Validation Audit 2026-06-27

All planned pure-seam tests already existed and ran green — no gaps to fill, no auditor spawned.
CHG-02 reconciled to its connect-only descope (the no-splash-on-unplug behavior is now covered by automated tests rather than manual UAT).

| Metric | Count |
|--------|-------|
| Gaps found | 0 |
| Resolved | 0 |
| Escalated | 0 |
| Automated tests (Phase 3 scope) | 19 (16 `PowerActivityTests` + 3 `wingsFrame`) |
| Manual-only (legitimate) | 5 (splash render, charging-vs-full, no-battery host, fullscreen no-show, idle-CPU) |
