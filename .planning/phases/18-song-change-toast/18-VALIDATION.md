---
phase: 18
slug: song-change-toast
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-07-09
---

# Phase 18 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (native, via `xcodebuild`) |
| **Config file** | `project.yml` (XcodeGen) → generates `Islet.xcodeproj`; scheme `Islet`, test target `IsletTests` |
| **Quick run command** | `xcodebuild build -project Islet.xcodeproj -scheme Islet -configuration Debug` (build-as-gate) |
| **Full suite command** | Manual Cmd-U in Xcode GUI (documented project pitfall — `xcodebuild test` hangs) |
| **Estimated runtime** | ~30s (build) / manual for Cmd-U |

**Known project pitfall (confirmed applicable here):** `xcodebuild test` hangs because tests are
hosted inside the full `Islet.app`, which boots the `NSPanel`/MediaRemote/IOBluetooth stack at
test-runner launch. Use `xcodebuild build` as the automated commit-time gate (compiles + type-
checks new pure-seam code and its tests); route actual test EXECUTION to a manual Cmd-U in Xcode,
exactly as done for Phase 17. No task in this phase may assume `xcodebuild test` completes
headlessly.

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild build -project Islet.xcodeproj -scheme Islet -configuration Debug`
- **After every plan wave:** Manual Cmd-U run of `IslandResolverTests` (+ `NowPlayingPresentationTests` if a new pure helper lands there) in Xcode GUI
- **Before `/gsd:verify-work`:** Full manual Cmd-U pass + on-device verification of toast timing/suppression/toggle behavior
- **Max feedback latency:** ~30s (build gate); manual pass at wave/phase boundaries

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 18-01-XX | 01 | 0 | NOW-05 | — | N/A | unit | `xcodebuild build ...` (compile gate) + manual Cmd-U | ❌ Wave 0 — new cases needed in `IslandResolverTests.swift` | ⬜ pending |
| 18-01-XX | 01 | 1+ | NOW-05 (timer wiring) | — | N/A | manual-only | — (controller/timer, `@MainActor`, `DispatchWorkItem`) | N/A | ⬜ pending |
| 18-0X-XX | TBD | TBD | NOW-06 | — | N/A | manual-only | — (SwiftUI view + `@AppStorage` + live controller state) | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `IsletTests/IslandResolverTests.swift` — extend (not new file) with cases covering:
      genuine-change → toast shown; same-track (play↔pause) → toast NOT re-triggered; D-02
      (active transient present) → toast suppressed; D-04 (`isExpanded: true`) → toast
      suppressed; first-track-after-launch (`hasPlayedSinceLaunch` pre-value false) → toast
      suppressed
- [ ] Framework install: none — XCTest already configured and working for this target

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| ~3s auto-dismiss, restart on rapid skip (D-03), suppressed toast leaves no stale timer | NOW-05 | Controller/timer wiring is `@MainActor`, `DispatchWorkItem`-based; this codebase's established discipline verifies pure seams via unit test and controller wiring on-device | Play a track, skip rapidly through several songs, confirm only the final track gets a full ~3s toast display and no toast lingers or double-fires |
| Toggle on/off in Settings; toggling off mid-toast clears it live | NOW-06 | `SettingsView`/`@AppStorage` toggle wiring has no existing automated-test precedent in this codebase (existing 3 toggles are also manual-only) | Open Settings → Activities tab, toggle the new switch off while a toast is showing, confirm it clears immediately; toggle back on and confirm subsequent track changes show the toast again |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s (build gate)
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
