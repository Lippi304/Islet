---
phase: 01-the-empty-island-window-geometry
verified: 2026-06-26T23:15:00Z
status: passed
score: 4/4 must-haves verified
overrides_applied: 0
re_verification:
  previous_status: none
  note: initial verification
---

# Phase 1: The Empty Island (Window + Geometry) Verification Report

**Phase Goal:** A static black pill rendered exactly on the notch, above all windows, on the correct display through monitor/clamshell changes
**Verified:** 2026-06-26T23:15:00Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

The four ROADMAP Success Criteria are the contract. Each is backed by both shipped code
(verified statically + by the green automated suite) AND an authoritative on-device sign-off
recorded in 01-03-SUMMARY.md (executed and approved by the user on real macOS 26 notch
hardware during this execution session — treated as the definitive human verification).

| # | Truth (ROADMAP Success Criterion) | Status | Evidence |
|---|-----------------------------------|--------|----------|
| 1 | A black, rounded pill renders over the physical notch, matching the notch's width and corner radius (ISL-01) | ✓ VERIFIED | Pure geometry seam (`notchFrame`/`notchSize`/`hasNotch`, +4 widthFudge, AppKit coordinate flip) covered by 8 green NotchGeometryTests; `NotchShape` (top 6 / bottom 14) + `NotchPillView` render it; `NotchShapeTests` (3) green. On-device: 01-03 Task 1 "pill hugs notch" APPROVED. |
| 2 | The pill stays above other windows and remains visible across all Spaces / desktops (ISL-02) | ✓ VERIFIED | `NotchPanel`: `.statusBar` level, `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]`, `.nonactivatingPanel`, `canBecomeKey/Main == false`, `ignoresMouseEvents = true`; 6 green NotchPanelTests assert each. On-device: 01-03 Task 2 (above-windows/across-Spaces, no focus theft, click-through) APPROVED. |
| 3 | With an external monitor connected and in clamshell, the pill stays on the built-in notch screen (or hides on lid close), never lands on the wrong display, recovering after plug/unplug and resolution changes (ISL-06) | ✓ VERIFIED | Pure `selectTargetScreen` selects by `isBuiltin && hasNotch` (never index), returns nil for clamshell/external-only — 7 green DisplayResolverTests; `NotchWindowController` re-runs on `didChangeScreenParametersNotification`, hides via `orderOut`. On-device: 01-03 Task 3 (correct display + clamshell hide/recover, external monitor present, A3 resolved) APPROVED. |
| 4 | When nothing is happening, the collapsed pill is near-invisible and not animating (ISL-07) | ✓ VERIFIED | `NotchPillView` release branch = `Color.black`, `devOffset == 0`; no animation modifiers (grep: no `withAnimation`/`.animation(`/`Timer`/`TimelineView`/`repeatForever`). On-device: 01-03 Task 4 (release-config idle near-invisible + static) APPROVED. |

**Score:** 4/4 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `Islet/Notch/NotchGeometry.swift` | Pure notch math (hasNotch/notchSize/notchFrame) | ✓ VERIFIED | All 3 functions present; +4 fudge; `BOTTOM-LEFT origin` coordinate-flip comment; consumed by NotchWindowController + DisplayResolver. |
| `Islet/Notch/DisplayResolver.swift` | ScreenDescriptor + selectTargetScreen | ✓ VERIFIED | Selects by `isBuiltin && hasNotch`; no array indexing; forward-note recorded; consumed by NSScreen+Notch + controller. |
| `Islet/Notch/NotchPanel.swift` | Borderless non-activating panel | ✓ VERIFIED | `[.borderless, .nonactivatingPanel]`, `.statusBar`, all-Spaces, `ignoresMouseEvents`, `canBecomeKey/Main` overrides. Instantiated by controller. |
| `Islet/Notch/NotchShape.swift` | Asymmetric rounded pill | ✓ VERIFIED | `struct NotchShape`, top 6 / bottom 14; used by NotchPillView. |
| `Islet/Notch/NotchPillView.swift` | Black release / DEBUG tint, static | ✓ VERIFIED | `#if DEBUG` tint+offset / `#else Color.black` + offset 0; zero animation; hosted in panel. |
| `Islet/Notch/NSScreen+Notch.swift` | NSScreen → ScreenDescriptor bridge | ✓ VERIFIED | `CGDisplayIsBuiltin`, `CGDisplayCreateUUIDFromDisplayID`, `var descriptor`; used by controller. |
| `Islet/Notch/NotchWindowController.swift` | Resolve+position+observer | ✓ VERIFIED | `didChangeScreenParametersNotification`, `selectTargetScreen`, `notchFrame`, `orderOut`, `orderFrontRegardless`, no `makeKeyAndOrderFront`; started+retained by AppDelegate. |
| `Islet/AppDelegate.swift` | Creates & retains controller | ✓ VERIFIED | Retained `notchController`; `controller.start()` in `applicationDidFinishLaunching`; existing status-item / settings-hide / terminate logic intact. |
| `IsletTests/*.swift` (4 files) | Unit tests, `@testable import Islet` | ✓ VERIFIED | All 4 test files present with `import XCTest` + `@testable import Islet`; 24 tests total, 0 failures. |
| `project.yml` | IsletTests target + scheme test action | ✓ VERIFIED | `IsletTests` `bundle.unit-test`, `TEST_HOST`→`Islet.app/.../Islet`, scheme `test:` action; xcodegen regenerate produces NO drift. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| AppDelegate.swift | NotchWindowController | retained property + `start()` in launch | ✓ WIRED | `notchController` retained; `controller.start()` called. |
| NotchWindowController | DisplayResolver | `selectTargetScreen(from:)` over descriptors | ✓ WIRED | Line 36. |
| NotchWindowController | NotchGeometry | `notchFrame(...)` for positioning | ✓ WIRED | Line 37. |
| NotchWindowController | screen-change notification | `didChangeScreenParametersNotification` observer → resolveAndPosition | ✓ WIRED | Lines 21-29, debounced via `DispatchQueue.main.async`. |
| NotchPanel | NotchPillView | `contentView = NSHostingView(rootView: NotchPillView())` | ✓ WIRED | NotchWindowController line 50. |
| NotchGeometryTests | NotchGeometry | `@testable import Islet` | ✓ WIRED | Suite green (8). |
| project.yml | IsletTests target | XcodeGen test target + scheme test action | ✓ WIRED | Suite runs via `xcodebuild test -scheme Islet`. |

### Data-Flow Trace (Level 4)

The pill renders a static fill (no dynamic data source), so the position is the only "live"
value. It flows: live `NSScreen.screens` → `.descriptor` (real `safeAreaInsets.top` /
`auxiliaryTop{Left,Right}Area.width` / `CGDisplayIsBuiltin`) → pure `selectTargetScreen` →
pure `notchFrame` → `panel.setFrame`. No hardcoded-empty source; no static fallback. On-device
sign-off confirms real geometry produces the correct on-notch frame.

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| NotchWindowController | `frame` (panel frame) | `NSScreen.screens.descriptor` → notchFrame | Yes (real system insets; confirmed on hardware) | ✓ FLOWING |
| NotchPillView | fill color (static) | compile-time `#if DEBUG` constant | N/A (intentionally static, ISL-07) | ✓ FLOWING (static by design) |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Full unit suite passes | `xcodebuild test -scheme Islet -destination 'platform=macOS' -only-testing:IsletTests` | 24 executed, 0 failures — TEST SUCCEEDED | ✓ PASS |
| Geometry math (ISL-01) | `-only-testing:.../NotchGeometryTests` | 8 / 0 failures | ✓ PASS |
| Display selection (ISL-06) | `-only-testing:.../DisplayResolverTests` | 7 / 0 failures | ✓ PASS |
| Panel config (ISL-02/D-07) | `-only-testing:.../NotchPanelTests` | 6 / 0 failures | ✓ PASS |
| Shape bounds (ISL-01) | `-only-testing:.../NotchShapeTests` | 3 / 0 failures | ✓ PASS |
| XcodeGen drift | `xcodegen generate` then `git status Islet.xcodeproj` | no changes (clean) | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| ISL-01 | 01-01, 01-02, 01-03 | Black rounded island over the notch, matching width/radius | ✓ SATISFIED | NotchGeometry/NotchShape green (11 tests) + 01-03 Task 1 on-device approval. |
| ISL-02 | 01-02, 01-03 | Stays above windows, visible across all Spaces | ✓ SATISFIED | NotchPanel config + NotchPanelTests (6) + 01-03 Task 2 on-device approval. |
| ISL-06 | 01-01, 01-02, 01-03 | Correct display on external/clamshell, never wrong display | ✓ SATISFIED | DisplayResolver + controller observer + DisplayResolverTests (7) + 01-03 Task 3 on-device approval (A3 resolved, external monitor present). |
| ISL-07 | 01-02, 01-03 | Idle pill near-invisible, not animating | ✓ SATISFIED | NotchPillView release Color.black + zero animation (grep) + 01-03 Task 4 on-device release-config approval. |

No orphaned requirements: REQUIREMENTS.md maps exactly ISL-01/02/06/07 to Phase 1, all four
claimed by plan frontmatter.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| (none) | — | — | — | No TODO/FIXME/placeholder; no `makeKeyAndOrderFront` in controller; no animation modifiers in the static pill; release `Color.black` present. Clean. |

### Human Verification Required

None outstanding. The four manual visual criteria (notch-hug, above-windows-across-Spaces /
no-focus-theft / click-through, clamshell hide/recover with external monitor, release-config
idle-invisible+static) and both on-device open questions (A2 window level vs the macOS 26 menu
bar; A3 clamshell drop-out) were executed and APPROVED by the user on real macOS 26 notch
hardware during this execution session, recorded authoritatively in 01-03-SUMMARY.md. A2 resolved
to `.statusBar` (no bump needed); A3 confirmed. No re-test requested.

### Gaps Summary

No gaps. Every ROADMAP Success Criterion is backed by shipped, substantive, wired code; the full
24-test automated suite passes with zero failures; the pure geometry/selection seam is property-
based (never index) and covered deterministically; the overlay panel is non-activating, never-key,
click-through, all-Spaces, status-bar level; the controller re-resolves on every screen change and
hides in clamshell; and the four manual-only visual criteria plus A2/A3 were signed off on real
hardware. XcodeGen regeneration shows no project drift. Requirements ISL-01/02/06/07 are fully
covered with no orphans.

---

_Verified: 2026-06-26T23:15:00Z_
_Verifier: Claude (gsd-verifier)_
