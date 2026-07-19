---
phase: 45
slug: view-switcher-morph-fix
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-07-19
---

# Phase 45 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (existing `IsletTests` target) |
| **Config file** | `project.yml` (XcodeGen-managed target; no separate test-runner config) |
| **Quick run command** | `xcodebuild -scheme Islet -destination 'platform=macOS' build` (build-only gate — see caveat below) |
| **Full suite command** | Manual `Cmd-U` in Xcode (GUI) |
| **Estimated runtime** | ~30-60s build; manual Cmd-U + on-device sweep untimed |

**Caveat (project memory, `xcodebuild-test-headless-hang`):** `xcodebuild test` hangs on this project — the test target hosts the full `Islet.app`, which boots the real `NSPanel`/`MediaRemote`/`IOBluetooth` stack even under test. Use `xcodebuild build` (or `build-for-testing`) as the automated gate; route actual test EXECUTION to a manual `Cmd-U` pass in Xcode, per this project's established convention.

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild -scheme Islet -destination 'platform=macOS' build`
- **After every plan wave:** Manual `Cmd-U` full XCTest suite run in Xcode
- **Before `/gsd:verify-work`:** Full on-device D-03 pairwise sweep (all 12 transitions, both directions) — LOCKED user decision, stricter than ROADMAP's "or representative sample" fallback
- **Max feedback latency:** ~60s (build gate)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 45-01-01 | 01 | 0 | SWITCH-01 | — | Regression lock: per-case `tabWidth`/`tabHeight` mapping stays byte-identical to today's values after refactor | unit | `xcodebuild build` then manual `Cmd-U` running new `NotchPillViewTests` case | ❌ Wave 0 — new test | ⬜ pending |
| 45-XX-XX | TBD | TBD | SWITCH-01 (animation) | — | One continuous spring morph, no disappear/rebuild flicker | manual-only | On-device walk (D-03) | — | ⬜ pending |
| 45-XX-XX | TBD | TBD | SWITCH-02 | — | No large→small z-order glitch behind switcher buttons | manual-only | On-device walk (D-03) | — | ⬜ pending |
| 45-XX-XX | TBD | TBD | D-03 | — | All 12 pairwise transitions, both directions, glitch-free | manual (mandatory, locked) | Xcode GUI run on-device | — | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `IsletTests/NotchPillViewTests.swift` — add a case asserting per-case `tabWidth`/`tabHeight` (or equivalent) mapping is preserved post-refactor, mirroring the existing `testShelfStripVisibleIsAlwaysFalse` pattern (direct `NotchPillView` instantiation, `@MainActor`). If the refactor's width/height properties are `private`, bump to `internal` for testability only (precedented: `shelfStripVisible` Phase 31, `EqualizerBars.makeProfiles()`) — no behavior change.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Continuous spring morph, no disappear/rebuild flicker | SWITCH-01 | SwiftUI view-identity/animation continuity during a live `matchedGeometryEffect` transition is not inspectable via XCTest — no ViewInspector/snapshot-testing dependency in this project | On-device: switch between views and visually confirm one continuous morph, no flicker |
| No large→small z-order glitch (island behind switcher buttons) | SWITCH-02 | Z-order during a live remove/insert-vs-update animation is a rendering-time concern, not statically testable | On-device: perform Calendar→Tray (and other large→small) transitions, confirm island never renders behind switcher pill buttons |
| All 12 pairwise transitions glitch-free, both directions | D-03 | Full pairwise on-device sweep is a locked user decision (stricter than a sample) | Walk Home↔Tray, Home↔Calendar, Home↔Weather, Tray↔Calendar, Tray↔Weather, Calendar↔Weather (12 total, both directions each) in Xcode GUI on-device build |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
