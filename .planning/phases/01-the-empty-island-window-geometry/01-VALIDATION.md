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
> (notch width/height/center) and display-selection logic (built-in notched screen) are
> extracted into pure injectable functions so they are XCTest-unit-testable. This map names
> the test files the plans actually ship. Three verification modes are used honestly:
> **unit** (XCTest assertion), **grep** (structural check of a compiled-out/absent branch
> that a DEBUG-config test bundle cannot assert), and **manual** (pixel-over-hardware /
> live window-server / multi-display states no agent can perform).

| Task ID | Plan | Wave | Requirement | Test File (shipped) | Test Type | Automated Command | Status |
|---------|------|------|-------------|---------------------|-----------|-------------------|--------|
| 1-01-02 | 01 | 0 | ISL-01 | `IsletTests/NotchGeometryTests.swift` | unit | `xcodebuild test -scheme Islet -destination 'platform=macOS' -only-testing:IsletTests/NotchGeometryTests` | ⬜ pending |
| 1-01-03 | 01 | 0 | ISL-06 | `IsletTests/DisplayResolverTests.swift` | unit | `xcodebuild test -scheme Islet -destination 'platform=macOS' -only-testing:IsletTests/DisplayResolverTests` | ⬜ pending |
| 1-02-01 | 02 | 1 | ISL-02 | `IsletTests/NotchPanelTests.swift` | unit | `xcodebuild test -scheme Islet -destination 'platform=macOS' -only-testing:IsletTests/NotchPanelTests` | ⬜ pending |
| 1-02-02 | 02 | 1 | ISL-01 | `IsletTests/NotchShapeTests.swift` | unit | `xcodebuild test -scheme Islet -destination 'platform=macOS' -only-testing:IsletTests/NotchShapeTests` | ⬜ pending |
| 1-02-02 | 02 | 1 | ISL-07 | (none — `NotchPillView.swift`) | grep | grep acceptance criterion: `NotchPillView.swift` has NO `withAnimation`/`.animation(`/`Timer`/`TimelineView`/`repeatForever` (static, D-03) | ⬜ pending |
| 1-02-02 | 02 | 1 | ISL-01/ISL-07 | (none — `NotchPillView.swift`) | grep | grep acceptance criterion: `NotchPillView.swift` contains both the `#if DEBUG` tint branch and the `Color.black` `#else` release branch (the compiled-out release fill cannot be asserted from a DEBUG test bundle) | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky · 🔎 grep · 👁 manual*

> **No `NotchPillViewTests.swift` is created.** ISL-07's "no animation" and the release-config
> `Color.black` pill fill are verified by the grep acceptance criteria in 01-02 Task 2 (and
> re-greped at the 01-03 Task 4 release checkpoint) rather than by a unit test — a compiled-out
> `#else` branch and the *absence* of animation modifiers cannot be honestly asserted from a
> DEBUG-config XCTest bundle. The four visual criteria below (pill-hug, Spaces/above-windows,
> no-focus-steal, idle-invisible) are the 01-03 manual checkpoints.

---

## Wave 0 Requirements

- [ ] `IsletTests` unit-test target added to `project.yml` + `Islet` scheme test action (01-01 Task 1) — without it no XCTest can run
- [ ] Pure-function geometry seam `NotchGeometry.swift` (`hasNotch` / `notchSize` / `notchFrame`) extracted so notch width/height/center is unit-tested without a live `NSScreen` (01-01 Task 2 → `NotchGeometryTests`)
- [ ] Pure-function display-selection seam `DisplayResolver.swift` (`selectTargetScreen(from:)` over injectable `ScreenDescriptor`, selecting by `isBuiltin && hasNotch` — never by array index) extracted for unit testing (01-01 Task 3 → `DisplayResolverTests`)

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
