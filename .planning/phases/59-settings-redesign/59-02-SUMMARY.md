---
phase: 59-settings-redesign
plan: 02
subsystem: settings-redesign
tags: [swiftui, appstorage, settings, lazygrid, card-grid, resolver-docs]
dependency_graph:
  requires:
    - Plan 59-01 (ActivityCard.swift, ActivityCardData contract, 8 new key constants, SC5 resolver table)
  provides:
    - Categorized 2-column ActivityCard grid replacing the flat Activities toggle list
    - 8 new default-OFF v1.10 activity @AppStorage properties wired into the grid
  affects:
    - Phases 60-67 (each new activity's own phase plugs its real behavior into the card
      already shipped here, no Settings-side rework needed)
tech_stack:
  added: []
  patterns:
    - "categorySection(title:cards:) shared helper renders one category header + LazyVGrid, reused 3x"
    - "Data-driven ActivityCardData arrays wrapping named @AppStorage $bindings (no dynamic string-keyed @AppStorage)"
key_files:
  created:
    - .planning/phases/59-settings-redesign/59-02-SUMMARY.md
  modified:
    - Islet/SettingsView.swift
    - IsletTests/SettingsViewTests.swift
    - Islet.xcodeproj/project.pbxproj
decisions:
  - "categorySection(title:cards:) is one shared helper called 3x (DRY), not 3 duplicated inline LazyVGrid blocks — matches the plan's own action text and RESEARCH.md Pattern 2"
  - "Focus Mode / Volume & Brightness popovers attached to the System-HUDs categorySection call site (not per-ActivityCard), since both cards live only in that one category — avoids a generic item-based popover router"
metrics:
  duration: 25min + on-device UAT
  completed: 2026-07-23
---

# Phase 59 Plan 02: Settings-Redesign Grid Wiring Summary

Wired the 15-card categorized Activities grid (System-HUDs 8 / Medien 2 / Produktivität 5) into `SettingsView`, replacing the old flat `Form`/`Section("Activities")` toggle list, and closed the phase with an on-device UAT approval covering SC2-SC5.

## What Was Built

**Task 1 — 8 new `@AppStorage` properties + 3 card arrays (`Islet/SettingsView.swift`):** Added `capsLockEnabled`/`downloadProgressEnabled`/`menuBarOverflowEnabled`/`timerEnabled`/`meetingHUDEnabled`/`quickNotesEnabled`/`quickActionsEnabled`/`codingProgressEnabled`, all `= false` with no exceptions (Pitfall 1). Built `systemHUDCards` (8: Charging/Devices/Focus Mode/Volume & Brightness/Calendar Countdown existing-first, then Caps Lock/Download Progress/Menu Bar Overflow "Neu"-badged), `mediaCards` (2: Now Playing/Song-Change Toast, none new), `productivityCards` (5: Timer/Meeting HUD/Quick Notes/Quick Actions/Coding Progress, all new) as `internal` computed `[ActivityCardData]` properties, mirroring `SidebarSection`'s existing private→internal testability-bump precedent. `IsletTests/SettingsViewTests.swift` gained 5 new tests asserting counts (8/2/5) and existing-before-new ordering (D-03/D-07).

**Task 2 — `activitiesSection` rebuilt (`Islet/SettingsView.swift`):** Replaced the flat toggle list with a single `ScrollView(.vertical)` containing a 2-toggle non-card `Form` block (Launch at login / Automatically Check for Updates, D-05) followed by 3 `categorySection(title:cards:)` calls in D-01 order (System-HUDs, Medien, Produktivität). `categorySection` is one shared helper rendering a `Text(title).font(.headline)` header + a fixed 2-column `LazyVGrid` of `ActivityCard(data:)` (D-02), reused for all 3 categories per RESEARCH.md Pattern 2. Focus Mode's and Volume & Brightness's existing permission-explanation popovers (`focusPermissionExplanationView`/`osdPermissionExplanationView`) were relocated — not redesigned — onto the System-HUDs `categorySection` call site (exactly 2 popover attachments, D-08/D-09/D-10, no generic item-based router). `focusPermissionStatusHint`/`osdPermissionStatusHint` left as intentional dead code in `ActivitySettings.swift`, out of this plan's `files_modified` scope.

**Task 3 — On-device UAT (blocking checkpoint):** User ran the full 12-step checklist against the real running Islet app and approved — no issues reported. Confirmed: 3 category headers render in D-01 order, each a genuine 2-column grid (not flat/alphabetical); System-HUDs' 5 existing cards before its 3 "Neu"-badged new cards; Medien's 2 cards unbadged; Produktivität's 5 cards all "Neu"-badged; Charging toggle OFF/ON drives the real HUD (SC2); Focus Mode/Volume & Brightness chevrons reopen the exact pre-existing permission popovers; a fresh install reads all 8 new cards OFF (SC3); a pre-seeded UserDefaults domain preserves an existing user's toggle state instead of the compiled default (SC4); "Launch at login"/"Auto-Update" remain plain toggles; the pane scrolls to reach every category and both toggles; the SC5 resolver-priority table in `IslandResolver.swift` matches real `resolve()` logic.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - blocking fix] `Islet.xcodeproj` was missing `ActivityCard.swift` from its Sources build phase**
- **Found during:** Task 1 build verification
- **Issue:** Build failed with "cannot find type 'ActivityCardData' in scope" / "cannot find 'ActivityCardData' in scope" across every new card-array declaration, despite Plan 59-01's `59-01-SUMMARY.md` claiming a green build. The project file (`Islet.xcodeproj/project.pbxproj`) had never actually been regenerated after `Islet/ActivityCard.swift` was added on disk in Plan 59-01 — the file existed and was committed, but xcodegen's generated `.xcodeproj` had no `PBXFileReference`/`PBXBuildFile` entries for it.
- **Fix:** Ran `xcodegen generate` to regenerate `Islet.xcodeproj` from `project.yml` (the project's documented single source of truth for its Xcode project), which picked up `ActivityCard.swift` automatically via its folder-based source discovery.
- **Files modified:** `Islet.xcodeproj/project.pbxproj`
- **Commit:** ba43bfa

### Discretionary/Documented (no user permission needed, Rule 1-3 scope)

**2. Shared `categorySection` helper vs. the plan's literal acceptance-criteria grep counts**
- **Issue:** The plan's own acceptance criteria expected `grep -c 'LazyVGrid'` to return 3 and `grep -c 'ActivityCard(data:'` to return >=3, implying 3 non-shared inline blocks. The plan's action text and RESEARCH.md Pattern 2 both explicitly recommend ONE `categorySection(title:cards:)` helper called 3 times (DRY) — which is what was built, and which naturally reduces the literal text-occurrence counts to 2 and 1 respectively (the shared code exists once in source, executes 3 times at runtime).
- **Resolution:** Kept the DRY shared-helper implementation (matching the plan's own prescribed architecture and avoiding a 3x code duplication that would produce a larger, harder-to-maintain diff for zero behavioral benefit). Verified the actual `done:` criterion — 3 correctly-ordered/badged category grids rendering 15 total cards — via the card-array unit tests (Task 1) and the Task 3 on-device UAT, both of which passed.
- **Files:** `Islet/SettingsView.swift`
- **Commit:** aca7a13

## Known Stubs

None — all 15 cards are fully wired to real `@AppStorage` persistence (7 existing keys, byte-for-byte unchanged; 8 new keys, all default OFF). The 8 new activities' actual island-content behavior is out of this phase's scope by design (Phases 60-67 each build their own activity behind the card already shipped here).

## Self-Check: PASSED

- FOUND: `Islet/ActivityCard.swift` (Plan 59-01, unmodified this plan)
- FOUND: `Islet/SettingsView.swift` (8 new `@AppStorage` properties, 3 card arrays, rebuilt `activitiesSection`)
- FOUND: `IsletTests/SettingsViewTests.swift` (5 new Phase 59 tests)
- FOUND: `Islet.xcodeproj/project.pbxproj` (regenerated, includes `ActivityCard.swift`)
- FOUND commit ba43bfa (Task 1)
- FOUND commit aca7a13 (Task 2)
- FOUND commit 5057837 (checkpoint-reached STATE.md note)
- `xcodebuild -project Islet.xcodeproj -scheme Islet build` — BUILD SUCCEEDED
- `xcodebuild -project Islet.xcodeproj -scheme Islet build-for-testing` — TEST BUILD SUCCEEDED
- On-device UAT (Task 3, 12 steps) — user-approved, no issues

Phase 59 (Settings-Redesign) is now 2/2 plans complete — SETTINGS-04/SETTINGS-05 shipped and on-device verified.
