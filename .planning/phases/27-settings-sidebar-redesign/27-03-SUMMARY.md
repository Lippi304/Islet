---
phase: 27-settings-sidebar-redesign
plan: 03
subsystem: settings
tags: [swiftui, navigationsplitview, appstorage, tdd]

requires: ["27-01"]
provides:
  - "SettingsView restructured into a NavigationSplitView sidebar (General/Workspace/System/About)"
  - "System section: materialStyle segmented picker + 3 independent accent swatchRow(selection:) pickers"
  - "DiagnosticReport.text(...) 3-accent signature (nowPlayingAccentIndex/chargingAccentIndex/deviceAccentIndex)"
affects: ["27-04"]

tech-stack:
  added: []
  patterns:
    - "NavigationSplitView + List(selection:) sidebar over an enum-driven detail switch, replacing TabView"
    - "swatchRow(selection: Binding<Int>) factored view reused 3x against independent @AppStorage-backed Bindings"

key-files:
  created: []
  modified:
    - Islet/SettingsView.swift
    - Islet/Diagnostics.swift
    - IsletTests/DiagnosticReportTests.swift

key-decisions:
  - "Task 2's TDD RED step used `xcodebuild build-for-testing` (compiles the test target without running it) as the RED/GREEN gate, not `xcodebuild test` — this project's established constraint is that `xcodebuild test` hangs (Bluetooth TCC wait in a full app boot); build-for-testing still proves the test file fails/passes to compile against the real API shape without triggering that hang."
  - "Kept the swatch-circle picker's exact visual body (Circle+overlay+onTapGesture) verbatim, only generalizing the accentIndex reference to a Binding<Int> parameter, per UI-SPEC's explicit 'do not build a second color-picker component' instruction."

requirements-completed: [SETTINGS-01, VISUAL-03]

duration: 35min
completed: 2026-07-12
---

# Phase 27 Plan 03: Settings Sidebar Restructure + Theming Section Summary

**`SettingsView.swift` rebuilt from a 3-tab `TabView` into a 4-section `NavigationSplitView` sidebar (General/Workspace/System/About) with every existing control relocated verbatim, plus a new Theming section (material-style picker + 3 per-element accent pickers) and a matching 3-line `Diagnostics.swift` accent report.**

## Performance

- **Duration:** ~35 min
- **Started:** 2026-07-12T22:00:00Z
- **Completed:** 2026-07-12T22:35:00Z
- **Tasks:** 2 completed (Task 2 followed TDD RED→GREEN)
- **Files modified:** 3

## Accomplishments
- `SidebarSection` enum (`general`/`workspace`/`system`/`about`) drives a `List(selection:)` sidebar + a `switch`-based detail pane inside `NavigationSplitView`; `TabView` fully removed
- General section consolidates Launch-at-login, the 4 activity toggles (Charging/Now Playing/Song-Change Toast/Devices), the Fullscreen toggle, and the Diagnostics button (D-01 catch-all)
- Workspace section renders the exact UI-SPEC placeholder copy ("Nothing to configure yet" / "The Shelf works automatically…") with no Form/Section wrapper (D-03)
- About section relocates the adaptive License block (trial/trialExpired/licensed) + Version label verbatim (D-02)
- System section adds `Section("Appearance Style")` (segmented Gradient/Solid Black picker) + `Section("Accent Colors")` (3 `swatchRow` rows for Now Playing/Charging/Device), all bound to the 4 new `@AppStorage` keys from Plan 01 (D-04/D-05/D-07)
- Single global `accentIndexKey`/`accentIndex` property fully removed from `SettingsView.swift`, replaced by 3 independent per-element `@AppStorage` properties
- `Diagnostics.swift`'s `DiagnosticReport.text(...)` takes 3 accent params and emits 3 report lines (`Now Playing Accent:`/`Charging Accent:`/`Device Accent:`) instead of one combined `Accent index:` line; `saveDiagnosticReport()`'s call site updated to match
- Window frame widened `360×280` → `520×380`; sidebar column `.navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)`

## Task Commits

1. **Task 1: NavigationSplitView shell + General/Workspace/About** - `bd77d92` (feat)
2. **Task 2: System (Theming) section + Diagnostics 3-accent report** - `ae664d5` (test, RED), `515b81e` (feat, GREEN)

_Note: TDD tasks may have multiple commits (test → feat)._

## TDD Gate Compliance

- RED: `ae664d5` — `IsletTests/DiagnosticReportTests.swift` updated to the new 3-param call signature and 3-line assertions; confirmed failing via `xcodebuild build-for-testing` (test target failed to compile against the still-old `Diagnostics.swift` signature — the compiled-language equivalent of a failing test for this codebase's established `xcodebuild test`-hangs constraint).
- GREEN: `515b81e` — `Diagnostics.swift` and `SettingsView.swift` updated; `xcodebuild build` and `xcodebuild build-for-testing` both succeed.
- REFACTOR: not needed — no cleanup pass required after GREEN.

## Files Created/Modified
- `Islet/SettingsView.swift` — `TabView` → `NavigationSplitView`; `SidebarSection` enum; `generalSection`/`workspaceSection`/`systemSection`/`aboutSection` computed properties; `swatchRow(selection:)`; 4 new `@AppStorage` Theming properties replacing the old single accent property
- `Islet/Diagnostics.swift` — `DiagnosticReport.text(...)` signature + report body changed from 1 combined accent line to 3 independent accent lines
- `IsletTests/DiagnosticReportTests.swift` — 3 call sites + 1 assertion block updated to the new 3-accent API

## Decisions Made
- Used `xcodebuild build-for-testing` (compile-only) instead of `xcodebuild test` (run) as this plan's RED/GREEN verification step, consistent with this project's documented `xcodebuild test` hang (full `Islet.app` boots `NSPanel`/MediaRemote/IOBluetooth, which blocks headless). A manual Cmd-U pass in Xcode is still the authoritative test-execution gate per the plan's own `<verify><human-check>` note — see Known Follow-ups below.
- Kept the swatch-circle picker's visual body byte-identical to the pre-existing Appearance-tab picker, only parameterizing the bound index as `Binding<Int>`, per UI-SPEC's Don't-Hand-Roll instruction.

## Deviations from Plan

None - plan executed exactly as written (Task 1 and Task 2 both followed their `<action>` blocks verbatim; no Rule 1-4 fixes were needed).

## Issues Encountered
None.

## User Setup Required

**Manual Cmd-U verification recommended before considering this plan's Theming section fully human-verified** (Task 2's `<verify><human-check>` requirement, per this project's established `xcodebuild test`-hangs constraint):
1. Open `Islet.xcodeproj` in Xcode.
2. Select the `IsletTests` scheme (or leave `Islet` selected — Cmd-U runs the test bundle either way).
3. Press Cmd-U.
4. Confirm all `DiagnosticReportTests` methods pass, including `testTextContainsAllSectionsWithSuppliedValues`'s new 3-line accent assertions.

This is a routing note (matches every prior TDD plan in this project since `xcodebuild test` cannot run headless), not a blocking gate — `xcodebuild build` and `xcodebuild build-for-testing` (compile-only) both already passed automatically during execution.

## Next Phase Readiness
Plan 04 can proceed. `SettingsView.swift`'s sidebar shell, Theming section, and `Diagnostics.swift`'s 3-accent report are all in place and build-green. Manual Cmd-U confirmation of `DiagnosticReportTests` is the one outstanding on-device-style step (see User Setup Required above), matching this project's standing test-execution routing convention rather than a new gap introduced by this plan.

---
*Phase: 27-settings-sidebar-redesign*
*Completed: 2026-07-12*

## Self-Check: PASSED
