---
phase: 9
slug: fullscreen-flash-window-space-retry
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-04
---

# Phase 9 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (via `xcodebuild test -scheme Islet`) |
| **Config file** | `project.yml` (XcodeGen) — `IsletTests` bundle, hosted in `Islet.app` for `@testable import` |
| **Quick run command** | `xcodebuild test -scheme Islet -only-testing:IsletTests/NotchPanelTests -only-testing:IsletTests/VisibilityDecisionTests -only-testing:IsletTests/FullscreenDetectorTests` |
| **Full suite command** | `xcodebuild test -scheme Islet` |
| **Estimated runtime** | ~unchanged from Phase 8 (141 tests as of Phase 8) |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild test -scheme Islet -only-testing:IsletTests/NotchPanelTests -only-testing:IsletTests/VisibilityDecisionTests -only-testing:IsletTests/FullscreenDetectorTests`
- **After every plan wave:** Run `xcodebuild test -scheme Islet` (full suite)
- **Before `/gsd:verify-work`:** Full suite green + the D-03 on-device UAT matrix (hover/click, click-through, all-Spaces visibility, positioning through clamshell/display changes, fullscreen hide/restore, D-07's ordinary Space-switch check)
- **Max feedback latency:** ~unit-test-suite duration (seconds) for automated checks; the FS-01 flash itself is only observable on-device (see Manual-Only Verifications)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 09-01-xx | 01 | 1 | FS-01 (collectionBehavior invariants, D-03) | — | `.canJoinAllSpaces`/`.fullScreenAuxiliary` unchanged by layered CGSSpace addition | unit | `xcodebuild test -scheme Islet -only-testing:IsletTests/NotchPanelTests/testPanelJoinsAllSpacesAboveFullscreenAux` | ✅ | ⬜ pending |
| 09-01-xx | 01 | 1 | FS-01 (focus-safety, D-04) | — | `canBecomeKey`/`canBecomeMain` both false | unit | `xcodebuild test -scheme Islet -only-testing:IsletTests/NotchPanelTests/testPanelNeverBecomesKeyOrMain` | ✅ | ⬜ pending |
| 09-01-xx | 01 | 1 | FS-01 (fullscreen hide/restore, D-03) | — | `shouldShow` predicate unaffected by the Space change | unit | `xcodebuild test -scheme Islet -only-testing:IsletTests/VisibilityDecisionTests` | ✅ | ⬜ pending |
| 09-01-xx | 01 | 1 | FS-01 (flash elimination) | — | Zero visible island flash on fullscreen-enter across trigger matrix | manual | On-device: green-button, menu-bar Enter Full Screen, fullscreen video app, repeated trials | N/A — manual-only | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. `NotchPanelTests`, `VisibilityDecisionTests`, and `FullscreenDetectorTests` already exist from prior phases; no new test scaffolding is required to start Wave 1.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Zero visible island flash on fullscreen-enter | FS-01 | A one-frame compositor-timing artifact cannot be asserted from XCTest — this has always been an on-device visual verification across Phases 2, 6, and 8 | On the built-in display, trigger fullscreen via green-button click, menu-bar "Enter Full Screen", and a fullscreen video app; repeat each trial multiple times; watch for any visible flash of the island during or immediately after the transition |
| Ordinary (non-fullscreen) Space switch regression (D-07) | FS-01 (regression) | Candidate C changes fundamental Space membership; visibility-across-all-Spaces and positioning correctness during a trackpad swipe / Mission Control switch is only observable on-device | Trigger a trackpad swipe or Mission Control Space switch between two ordinary desktop Spaces; confirm the island remains visible and correctly positioned throughout |
| Click-through outside the pill (D-03) | FS-01 (regression) | No existing automated test targets `syncClickThrough` directly; pre-existing gap not introduced by this phase | On-device: click outside the pill's bounds while the panel is visible; confirm clicks pass through to the app beneath |
| Lock-screen / sleep-wake transition (Pitfall 3, Claude's Discretion) | FS-01 (regression) | boring.notch's original PR introducing this exact mechanism had to revert a lock-screen feature due to an undocumented "critical bug" — direct regression precedent for this mechanism | Lock the screen and unlock, and separately put the Mac to sleep and wake it, with the panel visible; confirm the panel remains responsive, is not duplicated, and reappears correctly |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < unit-suite runtime
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
