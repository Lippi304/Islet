---
phase: 71
slug: island-corner-rounding
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-30
---

# Phase 71 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (existing `IsletTests` target) |
| **Config file** | none — standard Xcode test target wired into the `Islet.xcodeproj` scheme |
| **Quick run command** | `xcodebuild test -scheme Islet -destination 'platform=macOS' -only-testing:IsletTests/NotchShapeTests -only-testing:IsletTests/ActivitySettingsTests` |
| **Full suite command** | `xcodebuild test -scheme Islet -destination 'platform=macOS'` |
| **Estimated runtime** | ~90 seconds (quick) / full suite per project baseline |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild test -scheme Islet -destination 'platform=macOS' -only-testing:IsletTests/NotchShapeTests -only-testing:IsletTests/ActivitySettingsTests`
- **After every plan wave:** Run `xcodebuild test -scheme Islet -destination 'platform=macOS'` (full suite — baseline is 569 tests / 6 known pre-existing failures per STATE.md; confirm zero *new* failures)
- **Before `/gsd-verify-work`:** Full suite must be green (modulo the 6 documented pre-existing failures), plus on-device UAT for SC#1/SC#3
- **Max feedback latency:** ~90 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 71-01-XX | 01 | 1 | SHAPE-02 | — | New wings radii produce a valid, closed, non-self-intersecting `NotchShape` path at nominal (290×32) and depth-scale-floor (290×25.6) rect sizes | unit | `xcodebuild test -scheme Islet -only-testing:IsletTests/NotchShapeTests` | ✅ existing file, extend | ⬜ pending |
| 71-01-XX | 01 | 1 | SHAPE-02 | — | Idle/collapsed pill unchanged (SC#2 regression guard) | unit | `xcodebuild test -scheme Islet -only-testing:IsletTests/NotchShapeTests` | ✅ existing file, extend | ⬜ pending |
| 71-02-XX | 02 | 1 | SHAPE-03 | — | New `@AppStorage` key exists with correct string literal, DEBUG-gated | unit | `xcodebuild test -scheme Islet -only-testing:IsletTests/ActivitySettingsTests` | ✅ existing file, extend | ⬜ pending |
| 71-02-XX | 02 | 1 | SHAPE-03 | — | Release builds compile cleanly with corner-radius tuning UI excluded (SC#4) | unit | `xcodebuild build -scheme Islet -configuration Release` | ✅ existing convention | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `IsletTests/NotchShapeTests.swift` — add test asserting new base top/bottom radii produce a valid closed path at both nominal (290×32) and depth-scale-floor (290×25.6) wings rect sizes (Pitfall #1 regression guard)
- [ ] `IsletTests/ActivitySettingsTests.swift` — add test asserting the new `debugWingCornerRadiusNudgeKey` literal string, mirroring `testNewV110KeyNames`'s existing style
- [ ] No framework install needed — `IsletTests` target and XCTest already fully wired

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Wing corners visually read as "noticeably more rounded" matching reference screenshot | SHAPE-02 (SC#1) | No automated visual-diff in this codebase; matches established on-device screenshot comparison convention (SHAPE-01/Phase 29 precedent) | Trigger each wing-state HUD (Charging, Device, OSD, Timer, Meeting, etc. — and Now Playing per D-06) on real hardware, compare against reference screenshot's bottom-left/top-right emphasis |
| Now Playing glance (`mediaWingsOrToast`/`resumePreviewWings`) rounding matches new baked-in values (D-06) | SHAPE-02 | Same reason — visual-only, no automated diff | Trigger Now Playing wing + resume-preview hover on real hardware, confirm corners match other wing HUDs |
| Corner Radius nudge live-adjusts on real hardware and persists across relaunch | SHAPE-03 (SC#3) | `@AppStorage` live-update/persistence has never had an automated test in this codebase for the other 4 axes either | Use DEBUG menu Corner Radius ±1/±5 buttons, observe live change, quit and relaunch app, confirm value persisted |
| Reset/Print Wing Tuner actions include the new Corner Radius axis | SHAPE-03 | Manual UI action, no automated coverage for existing 4 axes either | Click "Reset Wing Tuner" — confirm Corner Radius nudge zeroes; click "Print Wing Tuner Values" — confirm output includes a `cornerRadiusNudge=` field |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 90s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
