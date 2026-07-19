---
phase: 45-view-switcher-morph-fix
plan: 01
subsystem: ui
tags: [swiftui, matchedGeometryEffect, view-identity, notch-pill, refactor]

# Dependency graph
requires: []
provides:
  - "tabWidth/tabHeight computed properties on NotchPillView reproducing the per-case
    switcher-row width/height mapping"
  - "A single tabContentView call site (one blobShape call) serving all 6 switcher-row
    IslandPresentation cases, replacing 6 independent per-case blobShape calls"
  - "Regression-lock test (testTabWidthHeightMatchesKnownPerCaseValues) covering all
    7 switcher-row presentation states"
affects: [45-02-view-switcher-morph-fix]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Compute a per-case value (CGFloat), never branch the View, when multiple structurally
      distinct case arms must share one continuously-identified SwiftUI subtree for
      matchedGeometryEffect to morph across instead of remove+insert"

key-files:
  created: []
  modified:
    - Islet/Notch/NotchPillView.swift
    - IsletTests/NotchPillViewTests.swift

key-decisions:
  - "Dropped trayFullView's shelfItems: []/shelfVisible: false blobShape override in favor of
    the unified call site's uniform shelfViewState.items/shelfStripVisible arguments — safe
    because shelfStripVisible is a hardcoded false constant (TRAY-01), so hasShelf is always
    false regardless of which case is active; no behavior change"
  - "Did NOT mark SWITCH-01/SWITCH-02 complete in REQUIREMENTS.md — both requirements are also
    listed in 45-02's frontmatter, which performs the actual on-device 12-pairwise-transition
    verification; marking them complete after only the structural refactor (no on-device
    confirmation yet) would misrepresent verification status. Defer to 45-02."

patterns-established:
  - "tabWidth/tabHeight CGFloat properties mirror the existing outer-.frame ternary precedent
    (NotchPillView.swift body) one level deeper, for any future case needing per-branch sizing
    without branching the View itself"

requirements-completed: []  # SWITCH-01/SWITCH-02 remain Pending until 45-02's on-device verification

# Metrics
duration: 10min
completed: 2026-07-19
---

# Phase 45 Plan 01: Consolidate Switcher-Row blobShape Call Sites Summary

**Collapsed 6 independent per-case `blobShape` calls into one shared `tabContentView` call site so all 6 switcher-row tabs share a single continuous SwiftUI view identity for `matchedGeometryEffect` to morph across.**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-07-19T17:12:00+02:00
- **Completed:** 2026-07-19T17:22:21+02:00
- **Tasks:** 2 completed
- **Files modified:** 2

## Accomplishments

- Added `tabWidth`/`tabHeight` computed `CGFloat` properties on `NotchPillView` that reproduce today's exact per-case width/height mapping for all 6 switcher-row `IslandPresentation` cases, locked by a new regression test covering all 7 presentation states (including both weather-style branches).
- Consolidated the 6 former per-case `blobShape` call sites (`homeEmptyState`, `calendarFullView`, `weatherFullView`, `trayFullView`, `mediaExpanded(_:art:)` ×2) into ONE `tabContentView` call, with `presentationSwitch` now routing all 6 cases through a single grouped case arm.
- `switcherRow` is now instantiated from exactly one place (inside the shared `blobShape` call), never duplicated per case — this is the structural fix for SWITCH-01 (disappear/rebuild flicker) and SWITCH-02 (dual-switcherRow z-order glitch during large→small transitions).

## Task Commits

Each task was committed atomically:

1. **Task 1: Add tabWidth/tabHeight contract properties + regression-lock test** - `bff2fc3` (test)
2. **Task 2: Consolidate the 6 per-case blobShape calls into one tabContentView call site** - `625a203` (fix)

_No TDD RED/GREEN split was applicable here — Task 1 is additive-only (new properties + test asserting them, both landing together since the properties already existed to compute the values by construction), and Task 2 is a pure structural refactor with no new behavior to test-first._

## Files Created/Modified

- `Islet/Notch/NotchPillView.swift` — added `tabWidth`/`tabHeight` computed properties; added `tabContentView`; renamed the 6 per-case view producers to content-only (`homeEmptyContent`, `calendarContent`, `weatherContent`, `trayContent`, `mediaContent(_:art:)`, `mediaUnavailableContent`); `presentationSwitch` now routes all 6 switcher-row cases through one grouped case arm to `tabContentView`.
- `IsletTests/NotchPillViewTests.swift` — added `testTabWidthHeightMatchesKnownPerCaseValues`, asserting `tabWidth`/`tabHeight` for all 7 switcher-row presentation states against the known pre-refactor constants, including an explicit UserDefaults-scoped medium/large weather-style check with save/restore.

## Decisions Made

- Kept `tabWidth`/`tabHeight` as internal (not `private`) computed properties so `@testable import Islet` can assert them directly — mirrors the existing `shelfStripVisible` testability precedent in this file.
- Dropped Tray's `shelfItems: []`/`shelfVisible: false` override at the unified call site (uses the same `shelfViewState.items`/`shelfStripVisible` arguments every other case uses) — verified as a no-op behavior change since `shelfStripVisible` is a hardcoded `false` constant regardless of case.
- Did not mark SWITCH-01/SWITCH-02 complete in REQUIREMENTS.md/ROADMAP.md — this plan is the structural code fix only; 45-02 performs the actual on-device 12-pairwise-transition verification these requirements need before they can be honestly marked shipped.

## Deviations from Plan

None — plan executed exactly as written. Both tasks' acceptance criteria (grep checks + `xcodebuild build`) passed on the first attempt; `xcodebuild build-for-testing` was also run (beyond the plan's own gate) to confirm the new test method and all renamed identifiers compile cleanly, per this project's established `xcodebuild-test-headless-hang` convention (build-for-testing compiles without hosting/running the full app, so it's safe to run here, unlike `xcodebuild test`).

## Issues Encountered

None.

## Next Phase Readiness

- 45-02 (on-device 12-pairwise-transition sweep + interrupted-tap retarget checkpoint) can proceed — the structural fix (one `blobShape` call site, `tabWidth`/`tabHeight` computed sizing) is code-complete and build-verified.
- `NotchWindowController.swift`/`IslandResolver.swift`/`ViewSwitcherState.swift` were not touched, confirming research's finding that the AppKit geometry and tap-intent spring wiring were already correct and independent of this SwiftUI-internal restructuring.

---
*Phase: 45-view-switcher-morph-fix*
*Completed: 2026-07-19*

## Self-Check: PASSED

- FOUND: Islet/Notch/NotchPillView.swift
- FOUND: IsletTests/NotchPillViewTests.swift
- FOUND: .planning/phases/45-view-switcher-morph-fix/45-01-SUMMARY.md
- FOUND: bff2fc3 (test commit)
- FOUND: 625a203 (fix commit)
- FOUND: 3d401df (summary commit)
