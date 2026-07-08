---
phase: 16
slug: notchwindowcontroller-device-coordinator-extraction-prove-th
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-07-08
---

# Phase 16 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (`IsletTests` target) |
| **Config file** | `project.yml` (XcodeGen) — scheme `Islet` is shared/checked-in |
| **Quick run command** | `xcodebuild build -scheme Islet -configuration Debug` |
| **Full suite command** | Manual: open Xcode, Cmd-U on the `Islet` scheme |
| **Estimated runtime** | ~30s build; Cmd-U manual, no fixed automated runtime |

**Known project pitfall — do not run `xcodebuild test` headlessly.** `IsletTests` is hosted inside the full `Islet.app`, which boots the real `NSPanel`/`MediaRemote`/`IOBluetooth` stack on test-runner launch and hangs in a headless context. Automated gates use `xcodebuild build` (compiles the test target too, catching type errors) as the sampling proxy; actual test EXECUTION is manual Cmd-U in Xcode.

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild build -scheme Islet -configuration Debug`
- **After every plan wave:** Manual Cmd-U in Xcode for the full `IsletTests` suite (20+ files, must stay green)
- **Before `/gsd:verify-work`:** Full on-device Bluetooth checklist (D-03's four scenarios) MUST pass — hard requirement, not a nice-to-have
- **Max feedback latency:** ~30s (build gate); Cmd-U and on-device checks are unbounded/manual

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 16-01-* | 01 | 1 | D-01 (BluetoothMonitor ownership unchanged) | — | N/A | build-only | `xcodebuild build -scheme Islet` | ✅ | ⬜ pending |
| 16-01-* | 01 | 1 | D-02 (DeviceCoordinator reproduces dedup/debounce/launch-grace logic) | T-05-01 / — | Untrusted `DeviceReading.name` stays plain-String-only, never reformatted unsafely | unit | new `DeviceCoordinatorTests.swift` — `xcodebuild build-for-testing -scheme Islet` then manual Cmd-U | ❌ W0 | ⬜ pending |
| 16-01-* | 01 | 1 | D-02 (matchPendingBatteryPoll identity-match + cap-at-2 preserved) | T-06-09 / — | Debounce + maxDepth bound not weakened | unit | same file | ❌ W0 | ⬜ pending |
| 16-02-* | 02 | 2 | D-03 (reconnect-flap debounce) | — | N/A | manual on-device | n/a — physical Bluetooth device required | ❌ needs UAT checklist | ⬜ pending |
| 16-02-* | 02 | 2 | D-03 (launch-grace suppression) | — | N/A | manual on-device | n/a | ❌ needs UAT checklist | ⬜ pending |
| 16-02-* | 02 | 2 | D-03 (genuine disconnect edge) | — | N/A | manual on-device | n/a | ❌ needs UAT checklist | ⬜ pending |
| 16-02-* | 02 | 2 | D-03 (battery-poll promotion) | — | N/A | manual on-device | n/a | ❌ needs UAT checklist | ⬜ pending |
| — | — | — | Regression (existing 20-file IsletTests suite stays green) | — | N/A | full suite | manual Cmd-U | ✅ exists | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*
*Task IDs are placeholders — planner assigns exact IDs; wave numbers reflect the extraction-then-verify split expected from CONTEXT.md D-03.*

---

## Wave 0 Requirements

- [ ] `IsletTests/DeviceCoordinatorTests.swift` — new file, covers extracted stateful bookkeeping (dedup, debounce, launch-grace, pending-poll cap/identity-match). Mirror `LicenseStateTests.swift`'s constructor-fakes pattern; mirror `IslandResolverTests.swift`'s pattern for exercising the real (non-faked) `TransientQueue` struct directly.
- [ ] `16-HUMAN-UAT.md` (or equivalent) — dedicated on-device UAT checklist document for D-03's four scenarios, mirroring the Phase 2 precedent (`02-HUMAN-UAT.md`). No test framework install needed — this is a manual document, not a code file.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|--------------------|
| Reconnect-flap debounce | D-03 | Requires a real IOBluetooth device firing repeated connection events within the ~3s window; not exercisable via unit test | Connect a real Bluetooth device, then trigger a second connection event for the same address within 3s — confirm only one splash fires |
| Launch-grace suppression | D-03 | Requires the app to launch with a device already connected to observe `bluetoothStartedAt`/`deviceLaunchGrace` gating in real time | Have a device already connected before launching Islet — confirm no splash fires at launch, but a later genuine disconnect still fires |
| Genuine disconnect edge | D-03 | Requires real IOBluetooth disconnect notification, not simulatable in a unit test | Disconnect a connected real device — confirm a disconnect splash fires exactly once |
| Battery-poll promotion | D-03 | Requires two real devices connecting in sequence so the second is enqueued behind the current head, then promoted | Connect device A, then connect device B (enqueued behind A) — dismiss/advance A, confirm B's deferred battery refresh still fires on promotion |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (`DeviceCoordinatorTests.swift`, on-device UAT checklist)
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s (build gate)
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
