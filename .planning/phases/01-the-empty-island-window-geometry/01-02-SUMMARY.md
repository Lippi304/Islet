---
phase: 01-the-empty-island-window-geometry
plan: 02
subsystem: notch-overlay
tags: [nspanel, swiftui, nshostingview, nsscreen, notch, all-spaces, click-through, appkit]

# Dependency graph
requires:
  - phase: 01-the-empty-island-window-geometry
    provides: NotchGeometry + DisplayResolver pure seams (notchFrame / selectTargetScreen) and the IsletTests target
provides:
  - NotchPanel.swift — borderless non-activating NSPanel (high level, all-Spaces, click-through) hosting the SwiftUI pill via NSHostingView (ISL-02)
  - NotchShape.swift — asymmetric rounded-pill Shape (top≈6 / bottom≈14)
  - NotchPillView.swift — static black pill in release, tint+offset in DEBUG (D-02)
  - NSScreen+Notch.swift — NSScreen → ScreenDescriptor bridge (CGDisplayIsBuiltin, displayUUID, .descriptor)
  - NotchWindowController.swift — owns the panel; resolve+position; screen-change observer (ISL-06/ISL-07)
affects: [01-03, notch-panel, on-device-tuning, window-level, multi-display]

# Tech tracking
tech-stack:
  added: [NSPanel (.nonactivatingPanel / .borderless), NSHostingView, IOKit CGDisplayIsBuiltin]
  patterns:
    - "AppKit window shell hosting SwiftUI via NSHostingView — small AppKit surface, SwiftUI for all visible UI"
    - "Window controller builds ScreenDescriptors from live NSScreen and delegates to the pure seam (selectTargetScreen / notchFrame) — no math re-derivation"
    - "Re-resolve-and-position on didChangeScreenParametersNotification (debounced, idempotent); hide via orderOut in clamshell, show via orderFrontRegardless"

key-files:
  created:
    - Islet/Notch/NotchPanel.swift
    - Islet/Notch/NotchShape.swift
    - Islet/Notch/NotchPillView.swift
    - Islet/Notch/NSScreen+Notch.swift
    - Islet/Notch/NotchWindowController.swift
    - IsletTests/NotchPanelTests.swift
    - IsletTests/NotchShapeTests.swift
  modified:
    - Islet/AppDelegate.swift
    - Islet.xcodeproj/project.pbxproj

key-decisions:
  - "Custom NSPanel chosen over DynamicNotchKit for the always-visible compact island (resolves the open Phase-1 decision in STATE.md) — DynamicNotchKit centers on transient expand()/hide(), not a persistent pill"
  - "Panel is .nonactivatingPanel + .borderless, never becomes key/main, ignoresMouseEvents — no focus theft, fully click-through (ISL-07)"
  - "Static black pill ships in release; DEBUG renders a visible tint+offset (D-02) so the overlay is locatable during on-device tuning"

patterns-established:
  - "AppDelegate retains the NotchWindowController started in applicationDidFinishLaunching, alongside the existing status item"
  - "NSScreen+Notch builds the ScreenDescriptor the pure DisplayResolver seam expects, keeping NSScreen out of the testable logic"

requirements-completed: [ISL-01, ISL-02, ISL-06, ISL-07]

# Metrics
duration: 5min
completed: 2026-06-26
---

# Phase 1 Plan 02: NSPanel Overlay + Black SwiftUI Pill Summary

**A running, focus-safe, click-through notch overlay: a borderless non-activating `NotchPanel` (all-Spaces, `.statusBar` level) hosting a static black `NotchShape` pill via `NSHostingView`, positioned on the built-in notched display through Plan 01's pure seam (`selectTargetScreen` + `notchFrame`, widthFudge 4), re-resolved on every `didChangeScreenParametersNotification` (hides in clamshell), and wired into `AppDelegate` at launch.**

## Performance

- **Duration:** ~5 min
- **Completed:** 2026-06-26
- **Tasks:** 3
- **Files modified:** 9 (7 created, 2 modified)

## Accomplishments
- ISL-02: `NotchPanel` — a `.borderless` / `.nonactivatingPanel` `NSPanel` that never becomes key/main, joins all Spaces (`collectionBehavior`), sits at a high window level, and is click-through (`ignoresMouseEvents`), hosting the SwiftUI pill via `NSHostingView`.
- `NotchShape` — asymmetric rounded-pill `Shape` (top≈6 / bottom≈14) matched to the notch corners; `NotchPillView` renders pure black in release and a visible tint+offset under `#if DEBUG` (D-02).
- `NSScreen+Notch` bridges live `NSScreen` to the pure `ScreenDescriptor` (via `CGDisplayIsBuiltin`, `displayUUID`, `.descriptor`) so the testable `DisplayResolver` seam stays free of AppKit.
- ISL-06/ISL-07: `NotchWindowController` owns the panel, builds descriptors from `NSScreen.screens`, calls `selectTargetScreen` + `notchFrame` to position the pill on the built-in notched display, and re-runs resolve-and-position on every `didChangeScreenParametersNotification` — hiding (`orderOut`) when no built-in notched screen exists (clamshell), showing via `orderFrontRegardless`.
- `AppDelegate` creates and retains the controller in `applicationDidFinishLaunching`, alongside the existing status item.
- Build succeeds; full `IsletTests` suite green (24 tests, 0 failures — 15 from Plan 01 + 9 new panel/shape tests).

## Task Commits

Each task was committed atomically:

1. **Task 1: borderless non-activating NotchPanel + NSScreen→ScreenDescriptor bridge** - `a78b1c4` (feat)
2. **Task 2: asymmetric NotchShape + static black / DEBUG-tinted NotchPillView** - `5cd6ca8` (feat)
3. **Task 3: NotchWindowController resolve+position+observer wired into AppDelegate** - `c891ff2` (feat)

_Plan metadata commit (SUMMARY) is created by the orchestrator after the wave._

## Files Created/Modified
- `Islet/Notch/NotchPanel.swift` - `NotchPanel` NSPanel subclass: borderless, non-activating, high level, all-Spaces, click-through.
- `Islet/Notch/NotchShape.swift` - Asymmetric rounded-pill `Shape` (top≈6 / bottom≈14).
- `Islet/Notch/NotchPillView.swift` - SwiftUI pill: black in release, tinted+offset in DEBUG (`#if DEBUG`).
- `Islet/Notch/NSScreen+Notch.swift` - `NSScreen` → `ScreenDescriptor` bridge (`CGDisplayIsBuiltin`, displayID, displayUUID, `.descriptor`).
- `Islet/Notch/NotchWindowController.swift` - Owns the panel; resolve+position via the pure seam; `didChangeScreenParametersNotification` observer.
- `Islet/AppDelegate.swift` - Creates & retains `NotchWindowController` at launch.
- `IsletTests/NotchPanelTests.swift` - Panel configuration tests (style mask, level, collection behavior, click-through).
- `IsletTests/NotchShapeTests.swift` - Shape geometry tests.
- `Islet.xcodeproj/project.pbxproj` - Regenerated by `xcodegen` (new source/test files).

## Decisions Made
- **Custom NSPanel over DynamicNotchKit** for the always-visible compact island — resolves the pending Phase-1 decision recorded in STATE.md. DynamicNotchKit is oriented at transient `expand()`/`hide()` events, not a persistent compact pill.
- Panel never becomes key/main and ignores mouse events → no focus theft, fully click-through (ISL-07).
- DEBUG tint+offset (D-02) so the overlay is locatable during Plan 03 on-device tuning; release ships pure black.

## Deviations from Plan

### Auto-fixed Issues

**1. [Documentation-only] Comment rewordings to satisfy grep acceptance criteria**
- **Found during:** Tasks 2 and 3 (acceptance-criteria grep checks).
- **Issue:** The plan's grep acceptance criteria require certain literal tokens to be absent from source; two comments in `NotchPillView.swift` and `NotchWindowController.swift` contained those tokens incidentally.
- **Fix:** Reworded the two comments (no behavior change).
- **Verification:** Full `IsletTests` suite re-ran green after each change.

**Total deviations:** 2 documentation-only comment rewordings. No behavior change, no scope creep.

## Issues Encountered
- **Worktree base fix:** the worktree branch was created from a stale "Initial commit" (`15b83c5`) instead of the feature-branch HEAD `4836ae3`. Resolved before any task by `git reset --hard 4836ae3` (clean tree, nothing lost); all commits build on the correct base, on top of Plan 01's merged seams.
- **SUMMARY recovery (orchestrator note):** the executor left this SUMMARY uncommitted in the worktree; `git worktree remove --force` discarded it. The orchestrator reconstructed this file from the executor's completion report, the plan `must_haves`, and the three committed diffs (`a78b1c4`, `5cd6ca8`, `c891ff2`) before verification. All factual claims here are cross-checked against the merged source on `gsd-new-project-setup`.

## Known Stubs
None. The pill is intentionally static (no hover/expand yet — that is later-phase work); all wiring (panel, positioning, screen-change observer, launch) is fully implemented.

## Deferred to Plan 03 (visual / on-device — not agent-assertable)
- Notch-hug accuracy, Spaces/fullscreen persistence, plug-unplug + clamshell recovery, no-focus-steal confirmation on-device.
- Open question A2: `.statusBar` vs `.mainMenu+1` window level over the Tahoe menu bar.
- Open question A3: built-in display dropping out of `NSScreen.screens` in clamshell.

## Next Phase Readiness
- The overlay is on-screen and stable in code; Plan 03 tunes window level (A2) and multi-display/clamshell behavior (A3) on the real device, modifying `NotchPanel.swift`, `NotchPillView.swift`, and `NSScreen+Notch.swift`.

## Self-Check: PASSED

All 7 created files and the 2 modified files exist on disk on `gsd-new-project-setup`; all 3 task commits (`a78b1c4`, `5cd6ca8`, `c891ff2`) are present in git history.

---
*Phase: 01-the-empty-island-window-geometry*
*Completed: 2026-06-26*
