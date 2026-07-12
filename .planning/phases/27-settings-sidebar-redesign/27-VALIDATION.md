---
phase: 27
slug: settings-sidebar-redesign
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-12
---

# Phase 27 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest, `IsletTests` target (28 existing test files, e.g. `LicenseStateTests.swift`, `InteractionStateTests.swift`) |
| **Config file** | `project.yml` (XcodeGen) generates `Islet.xcodeproj`; no separate test-runner config |
| **Quick run command** | `xcodebuild build -project Islet.xcodeproj -scheme Islet -configuration Debug` |
| **Full suite command** | Manual: open `Islet.xcodeproj` in Xcode, Cmd-U (`IsletTests` scheme) |
| **Estimated runtime** | ~30-60 seconds (build only — `xcodebuild test` hangs in this repo, see below) |

**Project-specific constraint (load-bearing, do not deviate):** `xcodebuild test` hangs because the test target hosts the full `Islet.app`, which boots the real `NSPanel`/MediaRemote/IOBluetooth stack — there is no headless test mode. The automated gate for this phase is `xcodebuild build` (compiles + catches type errors, including the `AnyShapeStyle`-class of error the research flags). Real XCTest execution is always manual, via Cmd-U in Xcode.

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild build -project Islet.xcodeproj -scheme Islet -configuration Debug`
- **After every plan wave:** Same build command (Release configuration too, per established Release-parity discipline) + manual Cmd-U for any new `ActivitySettingsTests.swift` cases
- **Before `/gsd:verify-work`:** Full on-device UAT pass covering all 4 sidebar sections + both theming controls
- **Max feedback latency:** ~60 seconds (build gate)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| TBD | TBD | TBD | SETTINGS-01 | — | N/A | manual | on-device UAT | N/A — manual by design | ⬜ pending |
| TBD | TBD | TBD | VISUAL-03 | V5 clamp-to-default | `MaterialStyle(rawValue:)` and accent index parsing fall back to default on corrupted/out-of-range value | unit | `xcodebuild build` + `IsletTests/ActivitySettingsTests.swift` via Cmd-U | ❌ W0 | ⬜ pending |

*Filled in by the planner once task IDs exist — see Wave 0 Requirements below for the concrete new test file.*

---

## Wave 0 Requirements

- [ ] `IsletTests/ActivitySettingsTests.swift` — new file; covers `MaterialStyle` rawValue parsing/clamping (mirroring the existing `accent(for:)` out-of-range-clamp test discipline) and the 3-key accent migration/seeding logic
- [ ] No new fixtures/conftest-equivalent needed — existing plain-fake precedent (no test framework beyond XCTest) is sufficient
- [ ] Framework install: none — XCTest is already fully wired

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Sidebar restructure, every existing control present + functional per section | SETTINGS-01 | Zero View-level SwiftUI tests exist or are planned for `SettingsView`'s view hierarchy | Open Settings, click through all 4 sidebar sections (General/Workspace/System/About), confirm every existing control (4 activity toggles, launch-at-login, fullscreen toggle, diagnostics button, license block, accent picker) renders and functions in its new section |
| License/login-item state stays synced across section switches | SETTINGS-01 (Criterion 3) | State-hoisting correctness can only be observed by rapid UI interaction, not asserted in a unit test | Rapidly click between General ↔ About and back several times; confirm the license countdown and login-item toggle never flash a stale/default value for a frame |
| Material-style/accent live-apply to the notch shell | VISUAL-03 | Rendering correctness across the collapsed pill, expanded island, and all 3 wing glances requires visual on-device confirmation | Change each Theming control (material style, 3 accent pickers) one at a time; observe the collapsed pill, expanded island, and charging/now-playing/device wings update live with no app restart |
| NavigationSplitView window sizing | SETTINGS-01 | Layout correctness (no overlap, no unexpected collapse) is a visual judgment call, flagged by research as needing on-device tuning | Open Settings, confirm sidebar and detail columns are both fully visible with no overlap or squeeze at the chosen frame size |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
