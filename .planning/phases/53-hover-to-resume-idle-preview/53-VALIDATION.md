---
phase: 53
slug: hover-to-resume-idle-preview
status: approved
nyquist_compliant: true
wave_0_complete: true
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

## Architecture Decision (affects this file)

Per 53-01-PLAN.md's `<objective>`, the planner chose the VIEW-LOCAL branch architecture (off the
existing `.idle` `IslandPresentation` case) over a new resolver case, per 53-CONTEXT.md's explicit
"Claude's Discretion" grant. This means `IslandResolver.swift`/`IslandResolverTests.swift` are
NOT touched by this phase — RESEARCH.md's Wave 0 gap ("If a new IslandPresentation case is
chosen, extend IslandResolverTests.swift...") does not apply. No new unit test file is created;
the hover-preview's gating logic (`hasPlayedSinceLaunch`, `lastKnownTrack != nil`,
`interaction.isHovering`) is plain view-local SwiftUI logic, not independently unit-testable in
this codebase's existing convention (mirrors `collapsedIsland`/`mediaWingsOrToast`, neither of
which have dedicated unit tests either).

---

## Sampling Rate

- **After every task commit:** `xcodebuild build -project Islet.xcodeproj -scheme Islet -configuration Debug`
- **After every plan wave:** Debug + Release build, plus a manual Cmd-U pass to confirm no existing test regresses
- **Before `/gsd:verify-work`:** Full build green (Debug + Release) PLUS a blocking on-device UAT covering all 4 ROADMAP success criteria — this phase's core behavior (MediaRemote transport resume) cannot be verified by automated tests alone
- **Max feedback latency:** 60 seconds (build) / on-device UAT session for manual checks

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 53-01-T1 | 53-01 | 1 | RESUME-02 | T-53-02 | Blocking on-device spike: does `togglePlayPause()` resume a stopped/quit session for Spotify/Apple Music (4 combinations)? | manual (on-device checkpoint) | none automatable — human-verify checkpoint | N/A | ⬜ pending |
| 53-01-T2 | 53-01 | 1 | RESUME-01 | T-53-01, T-53-04 | `idleOrResumePreview` gated on `hasPlayedSinceLaunch && lastKnownTrack != nil && interaction.isHovering` renders `resumePreviewWings` (mediaWingsRow reuse for success, failure text for D-03) | compile-gate (view logic not independently unit-tested, mirrors `collapsedIsland`/`mediaWingsOrToast` precedent) | `xcodebuild build -project Islet.xcodeproj -scheme Islet -configuration Debug` | ✅ (NotchPillView.swift, NowPlayingState.swift, existing) | ⬜ pending |
| 53-01-T3 | 53-01 | 1 | RESUME-02 | T-53-02, T-53-05 | `handleResumeTap()` dispatches `togglePlayPause()` + arms inferred-timeout watcher (Pattern 2); `collapsedInteractiveZone()` widens conditionally per Pitfall 1 | compile-gate | `xcodebuild build ... -configuration Debug && xcodebuild build ... -configuration Release` | ✅ (NotchWindowController.swift, existing) | ⬜ pending |
| 53-02-T1 | 53-02 | 2 | RESUME-01, RESUME-02 | T-53-07 | Full on-device UAT: all 4 ROADMAP SC, full-width hit-testing, no-expansion-on-click (D-01), regression check | manual (on-device checkpoint) | none automatable — human-verify checkpoint | N/A | ⬜ pending |

---

## Wave 0 Requirements

- [x] Resolved: no new `IslandPresentation` case chosen (view-local branch instead, per Architecture Decision above) — `IslandResolverTests.swift` is NOT extended, no Wave 0 gap remains.
- [x] No new test file needed for the transport call itself — the resume-inference timeout logic is controller-side glue, verified on-device (not unit-tested), mirroring `runHealthCheck`'s D-12 precedent.

*Existing infrastructure (`IsletTests`, `IslandResolverTests.swift`, `NotchPillViewTests.swift`) is unaffected by this phase and needs no new coverage.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Resume actually works (or fails with clear feedback) for a stopped/quit session | RESUME-02, SC#3, SC#4 | Depends on live macOS MediaRemote/Now-Playing-pointer state, which cannot be simulated in XCTest | 53-01-T1 (spike, via existing Home Last-Played play button) then 53-02-T1 (full UAT, via the new hover-preview itself): test all 4 combinations (Spotify paused-then-resume, Spotify quit-then-resume, Apple Music paused-then-resume, Apple Music quit-then-resume); confirm resume works where the transport supports it and clear failure feedback appears where it doesn't |
| Click-through hot-zone reliably covers the full 290×32pt hover-preview footprint | RESUME-01, SC#1 | Real click-through/hover hit-testing against physical notch geometry cannot be verified from source alone | 53-02-T1: on real notched hardware, hover across the full width of the preview (including album-art left edge and equalizer right edge) and confirm no premature grace-collapse or dead click zones |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies (checkpoint tasks use `<human-check>` instead, per this project's own checkpoint convention)
- [x] Sampling continuity: no 3 consecutive tasks without automated verify (53-01: checkpoint, build, build; 53-02: single checkpoint plan)
- [x] Wave 0 covers all MISSING references (none remain — view-local architecture resolved the only gap)
- [x] No watch-mode flags
- [x] Feedback latency < 60s (build) / on-device UAT for manual checks
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved (2026-07-21) — filled in during `/gsd:plan-phase 53`.
