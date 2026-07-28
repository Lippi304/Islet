---
phase: 66-men-bar-overflow-ice-style-mvp
plan: 03
subsystem: menu-bar
tags: [cleanup, settings, nsstatusitem, macos]

requires:
  - phase: 66-men-bar-overflow-ice-style-mvp
    provides: "Plan 66-01's NO-GO verdict on the private-CGS mechanism (files this plan deletes); Plan 66-02's MenuBarOverflowController + menuBarOverflowRevealedKey (the live mechanism this plan leaves untouched)"
provides:
  - "Codebase free of the superseded private-CGS spike (MenuBarOverflowBridging.swift, MenuBarOverflowManualSpike.swift)"
  - "SettingsView.swift with zero Menübar-Overflow Settings surface, matching D-02/D-04's 'no toggle, always-on' decision"
affects: [66-04]

tech-stack:
  added: []
  patterns: []

key-files:
  created: []
  modified:
    - Islet/SettingsView.swift
    - Islet.xcodeproj/project.pbxproj

key-decisions: []

requirements-completed: [MENUBAR-01, MENUBAR-03]

duration: ~10min
completed: 2026-07-28
---

# Phase 66 Plan 03: Cleanup — Spike Deletion & Settings Card Removal Summary

**Deleted the NO-GO'd private-CGS menu-bar-overflow spike (2 files) and removed the stale Phase-59-era "Menu Bar Overflow" Settings card/toggle, leaving zero Settings surface for the feature per D-02/D-04.**

## Performance

- **Duration:** ~10 min
- **Completed:** 2026-07-28
- **Tasks:** 2/2 completed
- **Files modified:** 2 (0 created, 2 modified; 2 deleted)

## Accomplishments
- Deleted `Islet/Notch/MenuBarOverflowBridging.swift` (private CGS* window-enumeration shim + synthetic-CGEvent-drag `moveMenuBarItem()`) and `IsletTests/MenuBarOverflowManualSpike.swift` (its Cmd-U-only manual spike test) — confirmed NO-GO on-device in 66-01, no production code ever referenced either file's symbols
- Regenerated `project.pbxproj` via `xcodegen generate` to drop both file references
- Removed `SettingsView.swift`'s stale `menuBarOverflowEnabled` `@AppStorage` binding and the `id: "menuBarOverflow"` `ActivityCardData` entry (the Phase-59-era "coming soon" placeholder card) — the feature now activates automatically at launch (Plan 66-02) with no on/off toggle, no permission card, no placeholder
- Confirmed `ActivitySettings.menuBarOverflowRevealedKey` (the live reveal/hide UI-state key `MenuBarOverflowController` reads/writes) remains correctly wired and was not touched by this cleanup — only the now-orphaned Settings-card binding was removed
- Release build succeeds clean after both deletions

## Task Commits

1. **Task 1: Delete the superseded Ice-mechanism spike files** - `86157c7` (chore)
2. **Task 2: Remove the stale menuBarOverflow Settings card/toggle** - `d608c4e` (fix)

## Files Created/Modified
- `Islet/Notch/MenuBarOverflowBridging.swift` - Deleted (private-CGS spike, NO-GO'd in 66-01)
- `IsletTests/MenuBarOverflowManualSpike.swift` - Deleted (Cmd-U manual spike test for the above)
- `Islet/SettingsView.swift` - Removed the `menuBarOverflowEnabled` `@AppStorage` binding and its `ActivityCardData` entry; every sibling toggle/card left untouched
- `Islet.xcodeproj/project.pbxproj` - xcodegen regenerate (both file references dropped)

## Decisions Made
None — plan executed exactly as written, no deviations required.

## Deviations from Plan
None — plan executed exactly as written.

## Issues Encountered
None.

## Self-Check: PASSED

- GONE: Islet/Notch/MenuBarOverflowBridging.swift (confirmed absent)
- GONE: IsletTests/MenuBarOverflowManualSpike.swift (confirmed absent)
- FOUND: commit 86157c7
- FOUND: commit d608c4e
- Symbol reference count (`MenuBarOverflowBridging|moveMenuBarItem|MenuBarOverflowManualSpike` in Islet/IsletTests): 0
- `menuBarOverflow` references in SettingsView.swift: 0
- Release build: BUILD SUCCEEDED

## Next Phase Readiness
- Phase 66's Menübar-Overflow feature is now fully clean: `MenuBarOverflowController` (Plan 66-02) is the sole live mechanism, unconditionally active with no dead spike code and no Settings surface anywhere in the codebase.
- On-device UAT of the actual reveal/hide chevron behavior (built in 66-02) remains outstanding and is not part of this plan's scope.

---
*Phase: 66-men-bar-overflow-ice-style-mvp*
*Completed: 2026-07-28*
