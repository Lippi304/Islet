---
phase: 64-quick-notes-obsidian-export
plan: 03
subsystem: ui
tags: [swiftui, appkit, nsopenpanel, settings, appstorage]

requires:
  - phase: 64-01
    provides: QuickNotesFormatter/QuickNotesFileStore data model and persistence layer
provides:
  - "ActivitySettings.quickNotesVaultFolderPathKey — shared UserDefaults key for the chosen vault folder path"
  - "quickNotesVaultPickerView — Settings popover with NSOpenPanel folder picker + current-path display"
  - "Quick Notes card's onOptionsTap wired to open the picker popover"
affects: [64-04-capture-popover, 64-02-vault-writer]

tech-stack:
  added: []
  patterns:
    - "3-part popover wiring (@State Bool -> onOptionsTap closure -> .popover(isPresented:)) reused verbatim for a 4th card, following Focus/OSD/Caps-Lock"

key-files:
  created: []
  modified:
    - Islet/ActivitySettings.swift
    - Islet/SettingsView.swift

key-decisions:
  - "Vault path stored as plain String UserDefaults value (D-09) — Islet is not sandboxed, no security-scoped bookmark needed"
  - "Path only ever comes from NSOpenPanel's own return value, never user-typed text (T-64-07, no path-injection surface)"

patterns-established:
  - "quickNotesVaultPickerView clones focusPermissionExplanationView's popover shape (spacing 8 / 15pt semibold title / 12pt body / HStack row / padding 16 / width 280) even though it isn't a permission-explanation popover — reuses the established visual contract for all Settings card popovers"

requirements-completed: [NOTES-02]

duration: 10min
completed: 2026-07-25
---

# Phase 64 Plan 3: Quick Notes Vault Folder Picker Summary

**Quick Notes Settings card now opens a native NSOpenPanel-based folder picker popover that persists the chosen Obsidian vault path as a plain UserDefaults string.**

## Performance

- **Duration:** 10 min
- **Started:** 2026-07-25T13:00:00Z
- **Completed:** 2026-07-25T13:10:00Z
- **Tasks:** 2 completed
- **Files modified:** 2

## Accomplishments
- Added `ActivitySettings.quickNotesVaultFolderPathKey`, a plain String UserDefaults key deliberately excluded from `defaultsToFalseKeys` (that set is Bool-only)
- Wired the Quick Notes card's `onOptionsTap` to a new `showQuickNotesVaultPicker` popover, following the exact Focus/OSD/Caps-Lock 3-part pattern
- Built `quickNotesVaultPickerView`: shows "No folder selected." or the current path, a "Choose Folder…" button that opens a directory-only `NSOpenPanel` and writes the result into the shared `@AppStorage` binding, and a "Done" button

## Task Commits

Each task was committed atomically:

1. **Task 1: ActivitySettings key + SettingsView state/wiring skeleton** - `441da18` (feat)
2. **Task 2: quickNotesVaultPickerView (folder picker + current-path display)** - `a28b769` (feat)

## Files Created/Modified
- `Islet/ActivitySettings.swift` - Added `quickNotesVaultFolderPathKey`
- `Islet/SettingsView.swift` - Added `showQuickNotesVaultPicker` state, `quickNotesVaultFolderPath` @AppStorage, wired `onOptionsTap`, attached `.popover` to the Produktivität categorySection, added `quickNotesVaultPickerView`

## Decisions Made
None beyond what the plan specified — plan executed exactly as written.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Plan 64-04 (capture popover) can now read `ActivitySettings.quickNotesVaultFolderPathKey` to check path validity before appending a note.
- Plan 64-02 (vault writer) can now rely on this Settings card as the user's real, persisted vault-folder source.
- On-device manual verification (per 64-UI-SPEC.md: open Settings, click Quick Notes options button, choose a folder, confirm path persists/displays) not yet performed in this automated session — recommended before closing the phase.

## Self-Check: PASSED

All created/modified files and commit hashes verified present.

---
*Phase: 64-quick-notes-obsidian-export*
*Completed: 2026-07-25*
