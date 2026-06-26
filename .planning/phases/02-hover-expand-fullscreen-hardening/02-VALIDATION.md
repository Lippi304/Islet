---
phase: 2
slug: hover-expand-fullscreen-hardening
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-27
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (hosted `IsletTests` bundle from Phase 1) |
| **Config file** | `project.yml` (XcodeGen — `IsletTests` target) |
| **Quick run command** | `xcodebuild test -scheme Islet -only-testing:IsletTests/NotchGeometryTests` |
| **Full suite command** | `xcodebuild test -scheme Islet -destination 'platform=macOS'` |
| **Estimated runtime** | ~30–60 seconds |

---

## Sampling Rate

- **After every task commit:** Run the quick command for the touched seam
- **After every plan wave:** Run the full suite command
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** ~60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| (populated by planner from RESEARCH.md § Validation Architecture) | | | | | | | | | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Pure-logic seams identified in RESEARCH.md § Validation Architecture (unit-testable):
- [ ] `expandedNotchFrame` geometry — extends `NotchGeometry` (ISL-04)
- [ ] hover/grace-delay state machine — pure state transitions (ISL-03)
- [ ] `isTrueFullscreen` predicate + `shouldShow` visibility decision (ISL-05)
- [ ] Update existing `testPanelIsClickThrough` — `ignoresMouseEvents` is now conditional

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Click-to-open never steals focus from foreground app | ISL-03 | Focus theft only observable against a live foreground app | Expand island while typing in another app; confirm caret/focus stays |
| Trackpad haptic + bounce on hover-enter | ISL-03 | Haptics require physical trackpad | Move pointer onto pill; feel haptic, see bounce |
| True-fullscreen hide / restore (native FS, FS video, QuickLook) | ISL-05 | Requires real fullscreen apps + notch hardware | Enter each fullscreen kind; confirm no ghost bar, then exit restores |
| Spring morph quality (no flicker/jump/cross-fade) | ISL-04 | Subjective Alcove-quality feel | Click to expand/collapse repeatedly; observe morph |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
