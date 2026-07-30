---
phase: 71-island-corner-rounding
plan: 01
subsystem: ui
tags: [swiftui, notchshape, corner-radius, wings]

# Dependency graph
requires: []
provides:
  - "wingBaseTopCornerRadius (16) / wingBaseBottomCornerRadius (8) named constants on NotchPillView"
  - "wingsShape(), mediaWingsOrToast(), resumePreviewWings() all render through the new 16/8 base radii"
  - "2 new NotchShapeTests regression tests proving the new radii stay valid at nominal size and the resolvedWingDepthScale 0.8x floor"
affects: [71-02-island-corner-rounding, future SHAPE work]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Named-constant corner-radius pattern for wing-state HUDs (mirrors blobShape's existing 24/32 literals)"

key-files:
  created: []
  modified:
    - Islet/Notch/NotchPillView.swift
    - IsletTests/NotchShapeTests.swift

key-decisions:
  - "16/8 chosen as the exact 4/3-scaled-up pair from 12/6, preserving the 2:1 top:bottom ratio (D-01/D-02)"
  - "mediaWingsOrToast()'s toast-active bottom radius (16) deliberately left unchanged — pre-existing blob-like growth behavior, unrelated to the SHAPE-02 baseline bump"

patterns-established:
  - "Wing-state HUDs share two named radius constants instead of scattering literal 12/6 (or now 16/8) across call sites"

requirements-completed: [SHAPE-02]

# Metrics
duration: 12min
completed: 2026-07-30
---

# Phase 71 Plan 01: Wing Base Corner Radius Bump Summary

**Bumped every wing-state HUD's corner radii from 12/6 to a rounder 16/8 pair via two new named constants (`wingBaseTopCornerRadius`/`wingBaseBottomCornerRadius`), applied at `wingsShape()`, `mediaWingsOrToast()`, and `resumePreviewWings()`, with 2 new regression tests proving the new radii stay valid at the depth-scale floor.**

## Performance

- **Duration:** 12 min
- **Started:** 2026-07-30T14:18:00Z
- **Completed:** 2026-07-30T14:30:00Z
- **Tasks:** 3/3 completed
- **Files modified:** 2

## Accomplishments
- Every `wingsShape()`-routed HUD (Charging, Device, Focus, Countdown, OSD, CapsLock, Update, Download, Timer, Meeting) now renders with the new 16/8 base radii instead of 12/6
- Now Playing glance (`mediaWingsOrToast`) and idle-hover resume preview (`resumePreviewWings`) also carry the new radii, per D-06, even though neither calls `wingsShape()` directly
- `collapsedIsland` and all 4 `blobShape()` call sites confirmed pixel-identical (grep-verified: bare `NotchShape()`, `topCornerRadius: 24, bottomCornerRadius: 32` unchanged)
- 2 new `NotchShapeTests` regression tests prove the 16/8 pair produces a valid, closed, non-empty path both at the nominal 290x32 wings rect and at the 290x25.6 `resolvedWingDepthScale` 0.8x floor (the worst-case Pitfall 1 scenario)

## Task Commits

Each task was committed atomically:

1. **Task 1: Add wing base radius constants, update wingsShape() call site (D-01/D-02, SHAPE-02)** - `ebeb1a9` (feat)
2. **Task 2: Bump mediaWingsOrToast() and resumePreviewWings() literals to match (D-06)** - `4020738` (feat)
3. **Task 3: Regression tests for the new radii + no-touch guard for collapsedIsland/blobShape** - `6796975` (test)

**Plan metadata:** pending (docs: complete plan)

## Files Created/Modified
- `Islet/Notch/NotchPillView.swift` - Added `wingBaseTopCornerRadius`/`wingBaseBottomCornerRadius` constants; updated `wingsShape()`, `mediaWingsOrToast()`, and `resumePreviewWings()` call sites to use them
- `IsletTests/NotchShapeTests.swift` - Added `testWingBaseRadiiProduceAClosedNonEmptyPathAtNominalSize` and `testWingBaseRadiiProduceAClosedNonEmptyPathAtDepthScaleFloor`

## Decisions Made
- 16/8 chosen as the exact plan-specified values (4/3-scaled from 12/6, same 2:1 ratio) — no deviation from the plan's literal instructions
- `mediaWingsOrToast()`'s toast-active bottom radius literal (16) left untouched per the plan's explicit D-06 exception — it already exceeds the new base and belongs to pre-existing toast-row-growth behavior, not this bump

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

Full-suite `xcodebuild test` (post-Task-3 verification step) surfaced 7 pre-existing failures (4x `LicenseStateTests`, 3x `SettingsViewTests`) against STATE.md's stale 2026-07-26 baseline of 6 known failures. Confirmed via `git log -- <file>` that neither test file was touched by this plan or any commit in its history (last touches: `cf17509`/`ba43bfa` for SettingsViewTests, `285e8be` for LicenseStateTests, all predating Phase 71). Out of scope per the Scope Boundary rule — logged to `deferred-items.md`, not fixed. The 2 new `NotchShapeTests` this plan added both pass; zero new failures attributable to this plan's changes.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Plan 71-02 (DEBUG-only live-tuning nudge axis for corner radius, per the phase's stated scope) can proceed — the two new named constants (`wingBaseTopCornerRadius`/`wingBaseBottomCornerRadius`) this plan established are the natural attachment point for a future tuning UI. No blockers.

---
*Phase: 71-island-corner-rounding*
*Completed: 2026-07-30*

## Self-Check: PASSED

All created/modified files and all 3 task commits (`ebeb1a9`, `4020738`, `6796975`) confirmed present via `git log --oneline --all`.
