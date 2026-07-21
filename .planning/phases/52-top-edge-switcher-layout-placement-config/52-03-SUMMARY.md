---
phase: 52-top-edge-switcher-layout-placement-config
plan: 03
subsystem: ui
tags: [swiftui, appstorage, settings, notch-geometry, view-switcher]

# Dependency graph
requires:
  - phase: 52-01
    provides: SelectedView(String/Hashable/CaseIterable), ActivitySettings.SwitcherLayout enum + switcherLayoutKey + 4 slot keys
  - phase: 51-settings-reorganization-scroll-fix
    provides: SidebarSection 7-case restructure (Activities/Appearance/Fullscreen/Weather/Diagnostics/Workspace/About), the ScrollView(.vertical){Form{...}.padding(20)} per-section pattern
provides:
  - SettingsView "Switcher" sidebar section (.switcher case) — Pill/Top-Edge layout picker + 4 menu-style slot dropdowns
  - SidebarSection.visibleSections(hasNotch:) — pure D-08 filter, unit-tested
  - SettingsView.SidebarSection bumped private -> internal (testable)
affects: [52-04-on-device-uat]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Settings' 5 switcher @AppStorage vars are an independent reader of the same UserDefaults keys NotchPillView (Plan 52-02) already reads/writes — no shared plumbing, mirrors weatherStyle's existing dual-reader relationship"
    - "hasNotchDisplay refreshed via refreshNotchAvailability() on .onAppear/.onChange(of: appearsActive), reusing selectTargetScreen(from:)?.hasNotch exactly as NotchPillView.topEdgeCutoutWidth does — no controller plumbing, no new detection heuristic"

key-files:
  created:
    - IsletTests/SettingsViewTests.swift
  modified:
    - Islet/SettingsView.swift
    - Islet.xcodeproj/project.pbxproj

key-decisions:
  - "SWITCH-03/SWITCH-04 left Pending in REQUIREMENTS.md (not marked complete by this plan) — mirrors this project's own Phase 45/52-02 precedent of deferring requirement completion until the phase's on-device UAT plan (52-04) confirms the feature actually works end-to-end on real hardware, including the flagged tight 36pt-in-42pt cameraClearance fit"

requirements-completed: []

# Metrics
duration: 20min
completed: 2026-07-21
---

# Phase 52 Plan 03: Switcher Settings UI (SidebarSection + D-08 Gating) Summary

**Settings gained a "Switcher" sidebar section (Pill/Top-Edge layout picker + 4 independent menu-style icon-placement dropdowns) wired to the same @AppStorage keys NotchPillView already renders from, entirely hidden on displays without a physical camera notch via a pure, unit-tested `visibleSections(hasNotch:)` filter.**

## Performance

- **Duration:** 20 min
- **Completed:** 2026-07-21T15:12:26Z
- **Tasks:** 2 completed
- **Files modified:** 3 (2 modified, 1 created)

## Accomplishments
- `SidebarSection` gained a `.switcher` case ("Switcher" title, `square.grid.2x2` icon) plus a new `switcherSection` view: a segmented "Layout" Picker (Pill/Top Edge) and 4 independent `.pickerStyle(.menu)` dropdowns (Left Outer/Left Inner/Right Inner/Right Outer), each offering all 4 icons via a shared `slotOptions` `@ViewBuilder`, defaulting to Home/Tray/Calendar/Weather exactly matching SWITCH-04's locked default.
- 5 new `@AppStorage` vars (`switcherLayout` + 4 slot vars) read/write the identical keys `NotchPillView` already declared in Plan 52-02 — an independent reader of the same shared `UserDefaults` source, not a second source of truth.
- `SidebarSection` bumped `private` → internal so `IsletTests/SettingsViewTests.swift` can reference it via `@testable import Islet`; a new `static func visibleSections(hasNotch:)` hides `.switcher` entirely when `hasNotch` is false (D-08), driving the sidebar's `ForEach` off a new `hasNotchDisplay` `@State` refreshed by `refreshNotchAvailability()` on `.onAppear`/`.onChange(of: appearsActive)` — the exact independent `selectTargetScreen(from:)?.hasNotch` read `NotchPillView.topEdgeCutoutWidth` already uses, no controller plumbing.

## Task Commits

Each task was committed atomically:

1. **Task 1: Switcher SidebarSection case + switcherSection view (D-02/D-07)** — `ddf5628` (feat)
2. **Task 2: D-08 hasNotch gating + visibleSections(hasNotch:) pure function** — `0d9c331` (feat)

## Files Created/Modified
- `Islet/SettingsView.swift` — `.switcher` SidebarSection case, 5 switcher `@AppStorage` vars, `switcherSection`/`slotOptions` views, dispatch wiring, `visibleSections(hasNotch:)`, `hasNotchDisplay` state, `refreshNotchAvailability()`
- `IsletTests/SettingsViewTests.swift` — `testVisibleSectionsIncludesSwitcherWhenHasNotchIsTrue`/`testVisibleSectionsExcludesSwitcherWhenHasNotchIsFalse`
- `Islet.xcodeproj/project.pbxproj` — regenerated via `xcodegen generate` to pick up the new test file (mechanical, no manual edits)

## Decisions Made
None beyond what's captured in `key-decisions` above.

## Deviations from Plan

**1. [Rule 3 - blocking, stale plan references] Plan's exact line numbers, `SidebarSection` shape, and dispatch-switch style no longer matched the current file**
- **Found during:** Task 1, before any edit
- **Issue:** 52-03-PLAN.md was authored against a pre-Phase-51 `SettingsView.swift` (a `private enum SidebarSection` with 7 different cases at lines 81-109, a single-line `case .foo: fooSection` switch dispatch at lines 145-162, `fullscreenSection` at lines 301-331). Phase 51 (landed after this plan was written, per its own SUMMARY.md) fully restructured the file: current `SidebarSection` has cases `activities, appearance, fullscreen, weather, diagnostics, workspace, about`, the dispatch switch uses a 2-line-per-case style, and section view bodies live at different locations entirely.
- **Fix:** Applied the plan's actual intent (add `.switcher` case with title/icon, add 5 `@AppStorage` vars below `weatherStyle`, add a `switcherSection` view mirroring the *current* `fullscreenSection`'s shape, wire into the *current* dispatch switch using its established 2-line-per-case style) rather than the plan's literal stale line numbers/single-line dispatch snippet. Inserted `.switcher` immediately after `.appearance` in the case list (plan's own "Claude's Discretion" note — CONTEXT.md locks no exact sidebar position).
- **Files modified:** `Islet/SettingsView.swift`
- **Commit:** `ddf5628`

**2. [Cosmetic, not a Rule 1-4 deviation] `case .switcher: switcherSection` dispatch written on 2 lines, not 1**
- **Found during:** Task 1 acceptance-criteria verification
- **Issue:** The plan's acceptance criterion `grep -c "case .switcher: switcherSection" Islet/SettingsView.swift == 1` assumes a single-line `case .foo: fooSection` dispatch style (the pre-Phase-51 convention). The current file's dispatch switch (all 7 pre-existing cases) uses a 2-line style (`case .foo:` / `    fooSection`), established by Phase 51 and unrelated to this plan.
- **Fix:** Matched the current file's actual 2-line dispatch style for consistency with the other 7 cases rather than special-casing `.switcher` as the one single-line case. This grep-literal acceptance check does not pass verbatim, but the functional requirement (switcher selection renders `switcherSection`) is satisfied and confirmed both by the Debug build and visual code inspection.
- **Files modified:** `Islet/SettingsView.swift`
- **Commit:** `ddf5628`

## Issues Encountered
None beyond the stale-plan-reference deviation above. Debug build green after both tasks; `SettingsViewTests` (2/2) green.

## User Setup Required

None — no external service configuration required.

## Known Stubs

None. `switcherSection`'s 5 Pickers are fully wired to live `@AppStorage` state (the same keys `NotchPillView` renders from); `visibleSections(hasNotch:)` reads real `NSScreen`/`selectTargetScreen` geometry, not mock data.

## Threat Flags

None beyond what the plan's own `<threat_model>` already anticipated (T-52-03 accept — `@AppStorage` type-safe fallback; T-52-04 accept — hardware-capability gating is a UX affordance, not a security boundary).

## Next Phase Readiness

The Switcher Settings UI is code-complete: the 5 `@AppStorage` controls are reachable from the sidebar (except when `hasNotch` is false, per D-08, unit-test-locked) and drive the exact same UserDefaults keys `NotchPillView`'s `switcherRow`/`topEdgeSwitcherRow` already render from live, with zero relaunch needed. **SWITCH-03/SWITCH-04 are intentionally left `Pending` in REQUIREMENTS.md** — mirrors this project's own Phase 45/52-02 precedent of deferring requirement completion until the phase's on-device UAT plan (`52-04-PLAN.md`, already present in this phase directory) confirms the feature actually works end-to-end on real hardware, including RESEARCH.md's flagged tight 36pt-in-42pt `cameraClearance` fit for the top-edge icons. No blockers — Plan 52-04 can proceed directly.

---
*Phase: 52-top-edge-switcher-layout-placement-config*
*Completed: 2026-07-21*

## Self-Check: PASSED

All modified/created files (`Islet/SettingsView.swift`, `IsletTests/SettingsViewTests.swift`, this SUMMARY.md) verified present on disk; both task commits (ddf5628, 0d9c331) verified present in git log.
