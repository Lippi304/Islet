---
phase: 08
slug: fullscreen-enter-flash-elimination
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-04
---

# Phase 08 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest, hosted unit-test bundle `IsletTests` (`@testable import Islet`) |
| **Config file** | `project.yml` (XcodeGen) → `IsletTests` target |
| **Quick run command** | `xcodebuild test -scheme Islet -only-testing:IsletTests/FullscreenDetectorTests` |
| **Full suite command** | `xcodebuild test -scheme Islet` |
| **Estimated runtime** | ~30 seconds (quick), full suite per project baseline |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild test -scheme Islet -only-testing:IsletTests/FullscreenDetectorTests` (and `VisibilityDecisionTests` if extended)
- **After every plan wave:** Run `xcodebuild test -scheme Islet` (full suite)
- **Before `/gsd:verify-work`:** Full suite green + the on-device D-05 trigger matrix (repeated trials, all 3 methods) signed off
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 08-00-0X | 00 | 0 | FS-01 | — | On-device CGS timing probe confirms whether event 106/107 fires early enough relative to the compositor flash | manual | n/a — DEBUG-timing probe, not a test file | ❌ W0 | ⬜ pending |
| 08-01-0X | 01 | 1 | FS-01 | — | `shouldShow(...)` correctly ANDs the new `pendingFullscreenTransition` input (if bounded-flag design is needed) | unit | `xcodebuild test -scheme Islet -only-testing:IsletTests/FullscreenDetectorTests` | ✅ exists, extend | ⬜ pending |
| 08-01-0X | 01 | 1 | FS-01 | — | Bounded timeout actually clears `pendingFullscreenTransition` (no permanent hide) | unit | `xcodebuild test -scheme Islet -only-testing:IsletTests/VisibilityDecisionTests` (extend) | ❌ W0 — only if flag design lands | ⬜ pending |
| 08-01-0X | 01 | 1 | FS-01 | — | No visible flash across all 3 D-05 trigger methods, repeated trials; existing hide-during/restore-after-fullscreen behavior unregressed | manual on-device | n/a — visual, the actual success criterion | — | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] **On-device CGS timing probe** (this phase's crux) — register `CGSRegisterNotifyProc` for events 106/107 (`CGSClientEnterFullscreen`/`CGSClientExitFullscreen`) and manually observe firing/timing across the D-05 trigger matrix (green-button, menu bar, video app) BEFORE committing to a design. Decides between "just 2 more observers" (simple) vs. "bounded `pendingFullscreenTransition` flag" (if the CGS current-space-type read lags behind the 106 event).
- [ ] Extend `IsletTests/FullscreenDetectorTests.swift` and/or `VisibilityDecisionTests.swift` — only once the Wave-0 probe determines which design is needed.

*Framework install: none — XCTest infra already exists.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| CGS event 106/107 firing/timing relative to compositor flash | FS-01 | Requires live WindowServer connection + real on-device fullscreen transition; cannot be synthesized in CI/automation (TCC/Accessibility restrictions block synthetic fullscreen triggers) | Register `CGSRegisterNotifyProc` for events 106/107 per RESEARCH.md "Candidate Signal Investigation"; trigger fullscreen via green-button/menu-bar/video app; log timestamps relative to observed flash |
| Zero visible island flash across D-05 trigger matrix, repeated trials | FS-01 | Visual regression on physical notch hardware — no automated screen-flash detector in this project | Trigger native fullscreen via (1) green-button, (2) menu bar "View > Enter Full Screen", (3) fullscreen video app (QuickTime/Safari); repeat each ≥3x; confirm zero flash and unregressed hide/restore behavior |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
