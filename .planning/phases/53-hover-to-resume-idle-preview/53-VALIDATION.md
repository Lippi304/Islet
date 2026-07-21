---
phase: 53
slug: hover-to-resume-idle-preview
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-21
---

# Phase 53 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest, `@testable import Islet` (existing `IsletTests` target) |
| **Config file** | `project.yml` (xcodegen) — shared `Islet` scheme |
| **Quick run command** | `xcodebuild build -project Islet.xcodeproj -scheme Islet -configuration Debug` (compile gate — see project-known limitation below) |
| **Full suite command** | Manual Cmd-U in Xcode |
| **Estimated runtime** | ~30-60 seconds (build) / ~3-5 minutes (manual full suite) |

**Known project limitation (STATE.md/PROJECT.md, confirmed):** `xcodebuild test` hangs headless in this repo/worktree due to a `BluetoothMonitor`/`IOBluetoothCoreBluetoothCoordinator` TCC-authorization wait introduced in Phase 6. This phase follows the established convention: automated verification uses `xcodebuild build` (compile-only gate) plus a manual Cmd-U pass in Xcode for actually running the XCTest suite. Do not add an `xcodebuild test` step to any plan's automated gate.

---

## Sampling Rate

- **After every task commit:** `xcodebuild build -project Islet.xcodeproj -scheme Islet -configuration Debug`
- **After every plan wave:** Debug + Release build, plus a manual Cmd-U pass for any new/changed pure-function unit tests
- **Before `/gsd:verify-work`:** Full build green (Debug + Release) PLUS a blocking on-device UAT covering all 4 ROADMAP success criteria — this phase's core behavior (MediaRemote transport resume) cannot be verified by automated tests alone
- **Max feedback latency:** 60 seconds (build) / on-device UAT session for manual checks

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| TBD | TBD | TBD | RESUME-01 | — / — | Hover preview gated on `hasPlayedSinceLaunch && lastKnownTrack != nil` renders the same visual as active Now Playing | unit | `xcodebuild build -project Islet.xcodeproj -scheme Islet -configuration Debug` + manual Cmd-U for new pure-function tests | ❌ Wave 0 | ⬜ pending |
| TBD | TBD | TBD | RESUME-02 | — / — | Resume tap dispatches `togglePlayPause()`; inferred-timeout failure detection shows clear feedback when no `.playing` snapshot arrives in time | manual (on-device UAT) | none automatable — on-device checkpoint required | N/A | ⬜ pending |

*Filled in by the planner once concrete task IDs exist; rows above are placeholders derived from RESEARCH.md's Phase Requirements → Test Map.*

---

## Wave 0 Requirements

- [ ] If a new `IslandPresentation` case is chosen (RESEARCH.md Open Question 2): extend `IslandResolverTests.swift` with cases for the hover-preview branch's gating logic (`hasPlayedSinceLaunch`, `lastKnownTrack != nil`, hover flag)
- [ ] No new test file needed for the transport call itself — the resume-inference timeout logic is controller-side glue, verified on-device (not unit-tested), mirroring `runHealthCheck`'s D-12 precedent

*Existing infrastructure (`IsletTests`, `IslandResolverTests.swift`, `NotchPillViewTests.swift`) covers everything else this phase touches.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Resume actually works (or fails with clear feedback) for a stopped/quit session | RESUME-02, SC#3, SC#4 | Depends on live macOS MediaRemote/Now-Playing-pointer state, which cannot be simulated in XCTest | Build and run on-device; test all 4 combinations: (Spotify paused-then-resume, Spotify quit-then-resume, Apple Music paused-then-resume, Apple Music quit-then-resume); confirm resume works where the transport supports it and clear failure feedback appears where it doesn't |
| Click-through hot-zone reliably covers the full 290×32pt hover-preview footprint | RESUME-01, SC#1 | Real click-through/hover hit-testing against physical notch geometry cannot be verified from source alone | On real notched hardware, hover across the full width of the preview (including album-art left edge and equalizer right edge) and confirm no premature grace-collapse or dead click zones |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s (build) / on-device UAT for manual checks
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
