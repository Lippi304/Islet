---
phase: 5
slug: device-connected-activity
status: approved
nyquist_compliant: true
wave_0_complete: false
created: 2026-06-28
---

# Phase 5 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (`IsletTests` bundle, hosted in the app for `@testable import Islet`) |
| **Config file** | `project.yml` (XcodeGen) — `IsletTests` target; run `xcodegen generate` after adding sources |
| **Quick run command** | `xcodebuild test -scheme Islet -only-testing:IsletTests/DeviceActivityTests` |
| **Full suite command** | `xcodebuild test -scheme Islet` |
| **Estimated runtime** | ~5 seconds for the pure `DeviceActivityTests` subset; ~30-60 seconds for the full suite (XCTest build + run) |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild test -scheme Islet -only-testing:IsletTests/DeviceActivityTests` (pure seam — runs in ms once built)
- **After every plan wave:** Run `xcodebuild test -scheme Islet` (full suite — guards against Phase 1-4 regressions)
- **Before `/gsd-verify-work`:** Full suite must be green AND on-device UAT complete (connect/disconnect both fire, no intrusive prompt, splash + ~3s dismiss correct, idle CPU ~0%)
- **Max feedback latency:** 60 seconds (full suite build + run on the macOS 26 build machine)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 05-01-01 | 01 | 1 | DEV-01 / DEV-02 | T-05-01 / T-05-06 | RED tests assert untrusted `device.name` → plain `String` (no format-string) and the pure debounce predicate is deterministic | unit (RED) | `xcodebuild test -scheme Islet -only-testing:IsletTests/DeviceActivityTests` | ❌ W0 (this task creates it) | ⬜ pending |
| 05-01-02 | 01 | 1 | DEV-01 / DEV-02 | T-05-01 / T-05-06 | `deviceLabel` returns name as inert `String`; `shouldShowDeviceSplash` is a pure no-clock predicate | unit (GREEN) | `xcodebuild test -scheme Islet -only-testing:IsletTests/DeviceActivityTests` | ✅ (after 05-01-01) | ⬜ pending |
| 05-01-03 | 01 | 1 | DEV-01 / DEV-02 | T-05-04 | Spike registers ONLY connect/disconnect notifications — NO `pairedDevices()`/scanning; decides if usage-description key is needed (no intrusive prompt) | manual / on-device spike (build-gated) | `xcodebuild build -scheme Islet` | ✅ `Islet/AppDelegate.swift` | ⬜ pending |
| 05-02-01 | 02 | 2 | DEV-01 / DEV-02 | — | `DeviceActivityState` is a plain `@Published` holder (no logic, no IOBluetooth) | build (no new pure logic) | `xcodebuild build -scheme Islet` | ❌ W2 (this task creates it) | ⬜ pending |
| 05-02-02 | 02 | 2 | DEV-01 / DEV-02 | T-05-02 / T-05-03 / T-05-04 | Every callback `DispatchQueue.main.async`-hops before `onEvent`; disconnect tokens retained then `.unregister()`-ed in `nonisolated stop()`; NO `pairedDevices()`/scanning | build (on-device-verified glue) | `xcodebuild build -scheme Islet` | ❌ W2 (this task creates it) | ⬜ pending |
| 05-03-01 | 03 | 3 | DEV-01 / DEV-02 | T-05-01 | Device-name `Text` bounded `.lineLimit(1)` + `.truncationMode(.tail)` (inert to format specifiers); shared `matchedGeometryEffect(id: "island")` morph | build (UI render) | `xcodebuild build -scheme Islet` | ✅ `Islet/Notch/NotchPillView.swift` (edited) | ⬜ pending |
| 05-03-02 | 03 | 3 | DEV-01 / DEV-02 | T-05-03 / T-05-05 | `handleDevice` gates via pure `shouldShowDeviceSplash` (burst/debounce); single `updateVisibility()` site; one-shot `DispatchWorkItem` dismiss; `deinit` tears down all tokens + pending dismiss | integration (full suite) | `xcodebuild test -scheme Islet` | ✅ `Islet/Notch/NotchWindowController.swift` (edited) | ⬜ pending |
| 05-03-03 | 03 | 3 | DEV-01 / DEV-02 | T-05-01 / T-05-03 / T-05-04 / T-05-05 | On-device UAT: connect/disconnect splash, D-04 burst/flap suppression, D-05 yield, D-06 hover-pause + fullscreen-hide, no intrusive prompt, ~0% idle CPU | manual / on-device UAT (build-gated) | `xcodebuild test -scheme Islet` | ✅ `Islet/Notch/NotchPillView.swift`, `Islet/Notch/NotchWindowController.swift` | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `IsletTests/DeviceActivityTests.swift` (Plan 01 Task 1, Wave 1) — the pure mapping + glyph table + at-launch burst-suppression + reconnect-debounce matrix (clone `PowerActivityTests.swift`), RED→GREEN; covers DEV-01 / DEV-02 pure logic
- [ ] **IOBluetooth permission spike** (Plan 01 Task 3, Wave 1) — register connect/disconnect in the signed `.app` on macOS 26, observe prompt + event delivery; decides Success Criterion 3 + whether `project.yml` needs `INFOPLIST_KEY_NSBluetoothAlwaysUsageDescription`. This is the gating spike — run it before Plan 02's monitor wiring.
- [ ] No new framework install — IOBluetooth is a system framework, auto-linked by `import`; no shared `conftest`/fixtures needed (XCTest hand-builds `DeviceReading` structs, mirroring `PowerActivityTests`).

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| IOBluetooth callbacks fire, hop to main, drive `@Published`; `deinit` unregisters; NO permission prompt | DEV-01 / DEV-02 | Real BT hardware cannot be unit-tested (mirrors PowerSourceMonitor/NowPlayingMonitor on-device verification) | Plan 01 Task 3 spike: run signed `.app`, connect/disconnect AirPods + a mouse; record A1 (prompt?), A2 (burst-on-wake?), A3 (name populated?) |
| Wings render + island morph + ~3s dismiss + hover-pause + fullscreen-hide + D-05 yield | DEV-01 / DEV-02 | Visual/animation + real BT hardware; needs the physical notch MacBook | Plan 03 Task 3 UAT: run `.app`, drive items 1-9 (connect audio + peripheral, disconnect, quit/wake burst, flap, music-overlap yield, hover-pause, fullscreen-hide, no prompt, idle CPU) |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references (DeviceActivityTests.swift + the IOBluetooth permission spike)
- [x] No watch-mode flags (single-shot `xcodebuild test` / `xcodebuild build` only)
- [x] Feedback latency < 60s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-06-28
