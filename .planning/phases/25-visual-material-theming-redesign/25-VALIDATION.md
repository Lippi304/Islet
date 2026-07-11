---
phase: 25
slug: visual-material-theming-redesign
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-07-11
---

# Phase 25 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (existing — `IsletTests/` target) |
| **Config file** | `Islet.xcodeproj` / `project.yml` (existing scheme) |
| **Quick run command** | `xcodebuild build -project Islet.xcodeproj -scheme Islet -configuration Debug` |
| **Full suite command** | Manual Cmd-U in Xcode (per project memory `xcodebuild-test-headless-hang` — `xcodebuild test` hangs headless because tests boot the full `Islet.app` incl. `NSPanel`/MediaRemote/IOBluetooth; route actual test execution to manual Cmd-U, use `build` as the automated gate) |
| **Estimated runtime** | ~30-60s (build gate) |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild build -project Islet.xcodeproj -scheme Islet -configuration Debug`
- **After every plan wave:** Same build gate + manual on-device visual/feel check (real notch hardware required — a simulator/preview cannot validate "no dropped frames on the real never-focused panel")
- **Before `/gsd:verify-work`:** Full on-device UAT pass (collapse↔expand↔wings↔shelf, all activity types), matching this project's established manual-UAT convention for visual/feel phases (Phase 18, 20, 21, 23)
- **Max feedback latency:** ~60s (build) + on-device check per wave

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 25-01-* | 01 | 1 | VISUAL-01 | — | N/A | build-gate + manual visual UAT | `xcodebuild build -project Islet.xcodeproj -scheme Islet -configuration Debug` | ✅ | ⬜ pending |
| 25-02-* | 02 | 1/2 | VISUAL-02 | — | N/A | manual-only (on-device UAT) | N/A — animation feel is not testable via XCTest | ❌ N/A by nature | ⬜ pending |

*Exact task IDs finalized by the planner. `NotchShapeTests.swift` / `InteractionStateTests.swift` cover the pure geometry/state-machine logic this phase does not touch and must stay green throughout.*

---

## Wave 0 Requirements

Existing infrastructure (`NotchShapeTests.swift`, `InteractionStateTests.swift`, `EqualizerBarsTests.swift`) already covers the pure logic adjacent to this phase's scope. No new test files or fixtures required.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Gradient renders correctly (opaque near notch, ~50% floor only near bottom edge) at all 3 shape contexts (pill/wings/expanded), no artifacts mid-morph | VISUAL-01 | Rendering-appearance requirement — no snapshot-testing library in this project's dependency graph, and adding one for a 2-file visual tuning phase is disproportionate | Open Islet.app on-device, observe collapsed pill, hover-widen, and click-expand states; confirm gradient depth matches D-02 and no banding/hard-edge artifacts during the morph |
| Spring feel: deliberately slow with a single visible overshoot-and-settle bounce, no dropped frames | VISUAL-02 | Animation *feel* is not testable via XCTest; this project's established convention (Phase 18, 5 rounds) treats spring tuning as on-device-only | Trigger hover-widen and click-expand repeatedly on-device (real notch hardware, 60Hz non-ProMotion), confirm slowness reads as "ultra fluid," confirm one clear overshoot then settle, confirm no frame drops |
| Activity content (Now Playing, Charging, idle glance) renders unchanged inside new chrome | VISUAL-01/02 (scope boundary) | Regression check against out-of-scope content — visual comparison only | On-device, cycle through each activity type inside the new gradient chrome; confirm layout/content identical to pre-phase behavior |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify (build gate) or are explicitly manual-only per the table above
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify (build gate applies to every task)
- [ ] Wave 0 covers all MISSING references — N/A, none missing
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s (build) + on-device check per wave
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
