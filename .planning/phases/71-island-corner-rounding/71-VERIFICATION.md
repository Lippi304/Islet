---
phase: 71-island-corner-rounding
verified: 2026-07-30T17:12:07Z
status: passed
score: 4/4 must-haves verified
overrides_applied: 0
---

# Phase 71: Island Corner Rounding Verification Report

**Phase Goal:** The collapsed-wide (wings) island silhouette — every HUD/activity routed through `wingsShape()` (Charging, Device, Now Playing glance, OSD, Timer, Meeting, etc.) — reads as a fully rounded pill shape instead of today's more rectangular corners, with a DEBUG-only live-tuning nudge for the new corner radius, mirroring the existing Wing Tuner mechanism. The idle/collapsed plain pill shape is explicitly unchanged.
**Verified:** 2026-07-30T17:12:07Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Every wing-state HUD routed through `wingsShape()` renders with noticeably more rounded corners at both the cutout-side and outer-edge-side corners | ✓ VERIFIED | `wingBaseTopCornerRadius: CGFloat = 16` / `wingBaseBottomCornerRadius: CGFloat = 8` (NotchPillView.swift:483-484, up from 12/6) applied at the single `wingsShape()` call site (line 3060) that every wing HUD (Charging, Device, Focus, Countdown, OSD, CapsLock, Update, Download, Timer, Meeting) routes through, plus `mediaWingsOrToast()` (line 3241) and `resumePreviewWings()` (line 3313) per D-06. On-device UAT (71-02-SUMMARY.md Task 3) walked through every wing HUD and the Now Playing glance/resume preview and was explicitly approved by the user ("ja passt alles wieder") after two intermediate freeze bugs were found and fixed. |
| 2 | Idle/collapsed plain pill shape is pixel-identical to before — rounding applies only to the wide wing state | ✓ VERIFIED | `collapsedIsland` (NotchPillView.swift:1318-1326) still constructs a bare `let shape = NotchShape()` — no radius arguments, unchanged default 6/14 from `NotchShape.swift`. All 4 `blobShape()` call sites (lines 1159, 2076, 2128, 2414) still read `topCornerRadius: 24, bottomCornerRadius: 32`, byte-for-byte unchanged. On-device UAT step 4 explicitly confirmed the idle pill unchanged. |
| 3 | DEBUG builds expose a "Corner Radius" nudge control alongside the existing Wing Tuner axes, live-adjusts on real hardware via `@AppStorage`, persists across relaunch | ✓ VERIFIED | `ActivitySettings.swift:117` (`#if DEBUG`-gated) declares `debugWingCornerRadiusNudgeKey = "debug.wingTuner.cornerRadiusNudge"`. `NotchPillView.swift:186` declares the matching `@AppStorage` property; `wingCornerRadiusNudge` (line 220) is the always-compiled read point folding to `0` outside DEBUG, wired into `wingsShape()`'s `NotchShape(...)` call (line 3060). `AppDelegate.swift:535-538` adds 4 menu items (±1/±5, no coarse tier), lines 614-617 add the 4 `@objc` actions routed through the shared `adjustWingNudge` helper, lines 624/633-634 wire Reset/Print. On-device UAT step 6 specifically confirmed the corner-radius nudge value persisted across relaunch (per the plan's own walkthrough, distinct from the leading/trailing/margin axes the live-tuning session mostly exercised while diagnosing the two freeze bugs). |
| 4 | Release builds expose no corner-radius tuning UI — DEBUG-only | ✓ VERIFIED | All AppDelegate Corner Radius menu/action code (lines 535-538, 614-617, 624, 633-634) sits inside the `#if DEBUG ... #endif` block spanning lines 499-689. `ActivitySettings.swift`'s key is inside its own `#if DEBUG` block (112-118). Re-ran `xcodebuild build -scheme Islet -configuration Release -destination 'platform=macOS'` — **BUILD SUCCEEDED**. `strings` on the built Release binary for `"Corner Radius"` returned zero matches, confirming the DEBUG menu strings are compiled out, not just source-gated. |

**Score:** 4/4 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `Islet/Notch/NotchPillView.swift` | wing base radius constants + `wingsShape()`/`mediaWingsOrToast()`/`resumePreviewWings()` call sites + DEBUG nudge wiring | ✓ VERIFIED | Constants at 483-484; call sites at 3060/3241/3313; `@AppStorage`/read-point at 186/220 |
| `Islet/Notch/NotchShape.swift` | dual-axis (height + width) self-intersection clamp inside `path(in:)`, post-71-REVIEW | ✓ VERIFIED | `path(in:)` (lines 16-48) computes `maxSum = min(rect.height, rect.width/2)` and proportionally scales both radii — closes CR-01 from 71-REVIEW.md, applies to every caller (`blobShape`/`wingsShape`/`mediaWingsOrToast`/`resumePreviewWings`) |
| `Islet/ActivitySettings.swift` | `debugWingCornerRadiusNudgeKey`, DEBUG-gated | ✓ VERIFIED | Line 117, inside `#if DEBUG` (112-118) |
| `Islet/AppDelegate.swift` | 4 menu items + 4 actions + Reset/Print wiring, DEBUG-gated | ✓ VERIFIED | Lines 535-538, 614-617, 624, 633-634, all inside `#if DEBUG` (499-689) |
| `IsletTests/NotchShapeTests.swift` | regression tests for base radii + clamp boundary cases | ✓ VERIFIED | 4 SHAPE-02/CR-01-related tests present and passing: `testWingBaseRadiiProduceAClosedNonEmptyPathAtNominalSize`, `...AtDepthScaleFloor`, `testPathologicalRadiiAreClampedToAValidPathAtWingSize`, `testDefaultRadiiAreClampedToAValidPathAtNarrowWidth` |
| `IsletTests/ActivitySettingsTests.swift` | key-name regression test | ✓ VERIFIED | `testWingCornerRadiusNudgeKeyName` present and passing |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| `wingsShape()` | `NotchShape(topCornerRadius:bottomCornerRadius:)` | direct call-site argument, base + nudge | ✓ WIRED | `NotchPillView.swift:3060`: `Self.wingBaseTopCornerRadius + wingCornerRadiusNudge` / `Self.wingBaseBottomCornerRadius + wingCornerRadiusNudge` |
| AppDelegate `NSMenuItem` actions | `adjustWingNudge(ActivitySettings.debugWingCornerRadiusNudgeKey, by:)` | `@objc` selector | ✓ WIRED | 4 actions at lines 614-617, each calling the shared helper with ±1/±5 |
| `wingCornerRadiusNudge` | `wingsShape()`'s `NotchShape(...)` call | computed property read at render time | ✓ WIRED | Confirmed above; folds to `0` outside DEBUG (line 222) |
| `wingsShape()`/`mediaWingsOrToast()`/`resumePreviewWings()` content | `NotchShape` silhouette | `.clipShape(shape)` | ✓ WIRED | Lines 3108, 3271, 3340 — UAT gap-closure fix (commit `8b74f49`) preventing content bleed past the now-larger concave corners |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| SHAPE-02 | 71-01 | Wing-state HUD renders with noticeably more rounded corners, closer to a full pill | ✓ SATISFIED | 16/8 base radii at all 3 call sites; on-device UAT approved; `[x]` in REQUIREMENTS.md |
| SHAPE-03 | 71-02 | DEBUG-only live-tuning nudge for wing corner radius, wired like existing Wing Tuner | ✓ SATISFIED | 5th Wing Tuner axis fully wired (AppStorage/read-point/menu/Reset/Print); Release-excluded; `[x]` in REQUIREMENTS.md |

No orphaned requirements — REQUIREMENTS.md maps only SHAPE-02/SHAPE-03 to this phase, and both appear in the plans' `requirements:` frontmatter.

### Anti-Patterns Found

None. Scanned all 6 modified/created files (`NotchPillView.swift`, `NotchShape.swift`, `ActivitySettings.swift`, `AppDelegate.swift`, `NotchShapeTests.swift`, `ActivitySettingsTests.swift`) for `TODO`/`FIXME`/`TBD`/`XXX`/`HACK`/`PLACEHOLDER` — zero matches.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| New/regression tests pass (base radii + clamp boundary cases + key-name) | `xcodebuild test -scheme Islet -destination 'platform=macOS' -only-testing:IsletTests/NotchShapeTests -only-testing:IsletTests/ActivitySettingsTests` | 30/30 passed, 0 failures | ✓ PASS |
| Release build compiles with DEBUG UI excluded | `xcodebuild build -scheme Islet -configuration Release -destination 'platform=macOS'` | BUILD SUCCEEDED | ✓ PASS |
| Release binary contains no "Corner Radius" strings | `strings Islet.app/Contents/MacOS/Islet \| grep -i "Corner Radius"` | zero matches | ✓ PASS |
| On-device visual/persistence/reset/print UAT | manual walkthrough (71-02-SUMMARY.md Task 3) | user approved ("ja passt alles wieder") after 2 freeze-diagnosis rounds + 1 code-review Critical finding (CR-01), all fixed and re-verified | ✓ PASS (already completed, documented in SUMMARY/REVIEW) |

### Probe Execution

Not applicable — this is a SwiftUI rendering/DEBUG-menu phase with no `scripts/*/tests/probe-*.sh` convention and none declared in the plans.

### Human Verification Required

None outstanding. This phase's on-device UAT (SHAPE-02 visual rounding across every wing HUD + idle-pill-unchanged, SHAPE-03 live-tune/persist/reset/print) was already run and approved by the user during plan 71-02's Task 3 checkpoint, after two live app freezes were diagnosed and fixed and one additional Critical finding (CR-01, unclamped width-axis self-intersection) was found and fixed via code review (`71-REVIEW.md`) and closed with new regression tests (`testPathologicalRadiiAreClampedToAValidPathAtWingSize`, `testDefaultRadiiAreClampedToAValidPathAtNarrowWidth`). Independent codebase inspection in this verification pass confirms the code backing every one of those approved claims actually exists, is wired, compiles clean in both Debug and Release, and passes its regression tests — no further human testing is needed for this phase to be considered complete.

### Gaps Summary

No gaps. All 4 roadmap success criteria verified against the actual codebase (not just SUMMARY claims): source-level radius bump at all 3 call sites, idle-pill/blobShape non-regression (grep-confirmed byte-for-byte), the 5th Wing Tuner axis fully wired end-to-end, Release-build exclusion confirmed both at the source (`#if DEBUG`) and compiled-binary (`strings`) level, and the post-UAT CR-01 width-axis clamp fix (moved into `NotchShape.path(in:)` itself, protecting every caller) confirmed present with dedicated regression tests. Full relevant test suite (30 tests across `NotchShapeTests`/`ActivitySettingsTests`) re-run fresh during this verification pass and passed clean; Release build re-run fresh and succeeded.

---

_Verified: 2026-07-30T17:12:07Z_
_Verifier: Claude (gsd-verifier)_
