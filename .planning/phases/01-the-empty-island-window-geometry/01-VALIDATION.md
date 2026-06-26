---
phase: 1
slug: the-empty-island-window-geometry
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-26
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (Xcode 26.6 / Swift 6.3.3) |
| **Config file** | none — Wave 0 adds an `IsletTests` (or `notchTests`) unit-test target |
| **Quick run command** | `xcodebuild test -scheme <Scheme> -destination 'platform=macOS' -only-testing:<TestTarget>` |
| **Full suite command** | `xcodebuild test -scheme <Scheme> -destination 'platform=macOS'` |
| **Estimated runtime** | ~20–40 seconds (clean unit-only run) |

---

## Sampling Rate

- **After every task commit:** Run the quick test command (unit tests only)
- **After every plan wave:** Run the full suite command
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** ~40 seconds

---

## Per-Task Verification Map

> Populated by the planner from RESEARCH.md "## Validation Architecture". Geometry math
> (notch width/height/center) and display-selection logic (built-in notched screen by
> CGDisplay UUID) are extracted into pure injectable functions so they are XCTest-unit-testable.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 1-01-01 | 01 | 0 | — | — | N/A | unit | `xcodebuild test -only-testing:<TestTarget>` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `IsletTests` (or `notchTests`) unit-test target added to the Xcode project — without it no XCTest can run
- [ ] Pure-function geometry seam (notch width/height/center from `NSScreen` inputs) extracted so it can be unit-tested without a live screen
- [ ] Pure-function display-selection seam (built-in notched screen resolver, keyed by CGDisplay UUID) extracted for unit testing

*If none: "Existing infrastructure covers all phase requirements."*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Black rounded pill renders over the physical notch at correct width/radius | ISL-01 | Requires visual confirmation against real hardware | Launch app; confirm pill sits over the notch, matches width, corners look seamless (use D-02 debug tint to verify alignment) |
| Pill stays above other windows and visible across all Spaces | ISL-02 | Requires live window-server / Mission Control behavior | Open fullscreen apps and switch Spaces; confirm pill persists on top and is not captured by Mission Control oddly |
| Correct display + clamshell behavior on plug/unplug and resolution change | ISL-06 | Requires external monitor + lid open/close hardware states | Connect external monitor, enter clamshell, change resolution, unplug; confirm pill stays on built-in notch screen or hides when lid closed, recovers each time |
| Collapsed pill is near-invisible and not animating when idle | ISL-07 | Requires visual observation over time | Leave app idle; confirm no animation, pill is unobtrusive |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 40s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
