---
phase: 34
slug: quick-action-destination-picker
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-15
---

# Phase 34 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest, `IsletTests` target (XcodeGen `project.yml`) |
| **Config file** | `project.yml` — shared `Islet` scheme |
| **Quick run command** | `xcodebuild build -scheme Islet -destination 'platform=macOS'` (build-only gate — `xcodebuild test` hangs headless in this project; see project memory `xcodebuild-test-headless-hang`) |
| **Full suite command** | Manual Cmd-U in Xcode (NOT `xcodebuild test`) |
| **Estimated runtime** | ~30-60s (build gate) |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild build -scheme Islet -destination 'platform=macOS'`
- **After every plan wave:** Manual Cmd-U in Xcode (full `IsletTests` suite)
- **Before `/gsd:verify-work`:** Full suite must be green (manual Cmd-U), PLUS the mandatory on-device CR-01 hover→expand→move-down trace for the new picker geometry, PLUS a real on-device AirDrop/Mail hand-off trial
- **Max feedback latency:** 60 seconds (build gate)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 34-01-01 | 01 | 0 | TRAY-02 | — | N/A | unit | `xcodebuild build -scheme Islet` — extend `IslandResolverTests.swift` with `.quickActionPicker` case | ❌ Wave 0 | ⬜ pending |
| 34-01-02 | 01 | 0 | TRAY-04 | — | N/A | unit | `xcodebuild build -scheme Islet` — new `QuickActionSharingServiceTests.swift` (mockable seam) | ❌ Wave 0 | ⬜ pending |
| 34-01-03 | 01 | 0 | TRAY-03 | — | N/A | unit | `xcodebuild build -scheme Islet` — extend/add `ShelfCoordinatorTests.swift` glue test | ⚠️ Partial Wave 0 | ⬜ pending |
| 34-02-01 | 02 | 1+ | TRAY-02 | — | N/A | manual on-device | Cmd-U + hover→expand→move-down CR-01 trace | N/A | ⬜ pending |
| 34-02-02 | 02 | 1+ | TRAY-03 | — | N/A | manual on-device | Cmd-U — Drop stages file, switches to Tray | N/A | ⬜ pending |
| 34-02-03 | 02 | 1+ | TRAY-04 | — | N/A | manual on-device | Real AirDrop/Mail hand-off trial (cannot be automated) | N/A | ⬜ pending |
| 34-02-04 | 02 | 1+ | D-04/D-05 | — | N/A | unit + manual | `xcodebuild build -scheme Islet` — extend `IslandResolverTests.swift`; manual charger-plug-in-during-picker trial | ❌ Wave 0 | ⬜ pending |
| 34-02-05 | 02 | 1+ | D-06/D-07 | — | N/A | unit + manual | `xcodebuild build -scheme Islet`; manual grace-collapse dismissal trigger | ❌ Wave 0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `IslandResolverTests.swift` — extend with `.quickActionPicker` resolver-branch cases (covers TRAY-02, D-04/D-05)
- [ ] New `QuickActionSharingServiceTests.swift` — mockable seam for `canPerform`/`perform` call verification without triggering real OS UI (covers TRAY-04's testable half)
- [ ] Possibly extend `ShelfCoordinatorTests.swift` or add a new small test for the "picker Drop → append + view switch" glue (covers TRAY-03's new-glue half; the underlying `append`/`makeSessionCopy` primitives are already covered)
- [ ] Framework install: none — `IsletTests` target and `Islet` scheme already exist and are wired

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Real AirDrop hand-off (system share sheet appears, transfer completes) | TRAY-04 | OS-level UI interaction with nearby devices cannot be automated or simulated in CI | Drop a file, choose AirDrop, confirm the system AirDrop UI appears and a real device can receive the file |
| Real Mail.app compose-with-attachment hand-off | TRAY-04 | Requires Mail.app to actually launch/foreground and receive the attachment — OS-level, not automatable | Drop a file, choose Mail, confirm Mail.app opens a new compose window with the file attached |
| CR-01 click-through trace for the new picker presentation's `visibleContentZone()` geometry | TRAY-02 | This project's own recurring failure mode (CR-01) — click-through hit-testing regressions are only caught by an actual hover→expand→move-down mouse trace on-device, not by any automated test | Hover to expand picker, move mouse down through the picker area, confirm clicks pass through/register correctly at every zone boundary |
| Charging/Device transient interrupting an open picker, then picker auto-resuming with same pending file(s) | D-04/D-05 | Requires physically plugging in a charger or connecting a Bluetooth device while the picker is open — hardware-triggered, not automatable | Open picker via file drop, plug in charger mid-picker, confirm charging splash shows then picker resumes with the same file still pending |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
