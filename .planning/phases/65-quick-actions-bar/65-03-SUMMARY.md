---
phase: 65-quick-actions-bar
plan: 03
subsystem: system-integration
tags: [applescript, appkit, nsworkspace, quick-actions]

requires:
  - phase: 65-quick-actions-bar/01
    provides: QuickActionsBarCatalog.Action enum this plan's 3 mechanisms will be wired to in a later plan
provides:
  - "DarkModeToggleAction.toggle(completion:) — AppleScript System Events dark-mode flip, errorDict-gated"
  - "DarkModeToggleAction.isDarkMode — pure AppKit read (NSApp.effectiveAppearance)"
  - "EmptyTrashAction.empty(completion:) — AppleScript Finder empty-trash, errorDict-gated"
  - "LaunchAction.launch(target:) / .resolvedURL(from:) — validated-input-only NSWorkspace passthrough"
affects: [65-05, 65-06, 65-07, 65-08]

tech-stack:
  added: []
  patterns:
    - "AppleScript + explicit errorDict check (this codebase's ONE existing precedent, NowPlayingMonitor.swift's spikeTriggerAutomationPrompt) — never assume success from the absence of a thrown Swift error"
    - "One validation chokepoint before any execution-adjacent API call (resolvedURL(from:)) — mirrors SettingsView.swift's NSOpenPanel-only-input discipline"

key-files:
  created:
    - Islet/Notch/QuickActionsBar/DarkModeToggleAction.swift
    - Islet/Notch/QuickActionsBar/EmptyTrashAction.swift
    - Islet/Notch/QuickActionsBar/LaunchAction.swift
  modified:
    - Islet.xcodeproj/project.pbxproj

key-decisions: []

requirements-completed: [QACTION-01]

duration: 15min
completed: 2026-07-26
---

# Phase 65 Plan 03: Quick Actions Bar — Dark Mode, Empty Trash, Launch App/URL Summary

**3 isolated action files: 2 AppleScript+errorDict mechanisms (Dark Mode toggle, Empty Trash) matching this codebase's one existing precedent, plus an AppKit-passthrough Launch App/URL action with a single validated-input chokepoint (no shell/AppleScript injection surface)**

## Performance

- **Duration:** ~15 min
- **Completed:** 2026-07-26
- **Tasks:** 2 completed
- **Files modified:** 4 (3 created, 1 regenerated)

## Accomplishments
- `DarkModeToggleAction.toggle(completion:)` flips System Events dark mode via `NSAppleScript`, reporting `errorDict == nil` honestly rather than assuming success from a non-throw
- `DarkModeToggleAction.isDarkMode` — synchronous, side-effect-free `Bool` read via `NSApp.effectiveAppearance.bestMatch(from:)`
- `EmptyTrashAction.empty(completion:)` empties Trash via Finder's own AppleScript dictionary exclusively (never `FileManager` directly on `~/.Trash`, per RESEARCH.md Anti-Patterns)
- `LaunchAction.launch(target:)` / `.resolvedURL(from:)` — the one validation chokepoint gating an existing file path or scheme-bearing URL only; empty/malformed strings resolve to `nil` and become a silent no-op, never reaching a shell/AppleScript command

## Task Commits

Each task was committed atomically:

1. **Task 1: DarkModeToggleAction + EmptyTrashAction (AppleScript + errorDict)** - `51cd42d` (feat)
2. **Task 2: LaunchAction (AppKit passthrough + validated-input-only config)** - `93ac5f1` (feat)

## Files Created/Modified
- `Islet/Notch/QuickActionsBar/DarkModeToggleAction.swift` - New file: `toggle(completion:)` + `isDarkMode`
- `Islet/Notch/QuickActionsBar/EmptyTrashAction.swift` - New file: `empty(completion:)`
- `Islet/Notch/QuickActionsBar/LaunchAction.swift` - New file: `launch(target:)` + `resolvedURL(from:)`
- `Islet.xcodeproj/project.pbxproj` - regenerated via `xcodegen generate` (twice, once per task) to register each new file in the build target

## Decisions Made

None beyond what the plan itself specified — both tasks implemented the RESEARCH.md code examples and interfaces verbatim.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None. Both `xcodegen generate && xcodebuild -project Islet.xcodeproj -scheme Islet -configuration Debug build` runs succeeded on the first attempt.

## User Setup Required

None - no external service configuration required. On-device verification (dark mode actually flips, Trash actually empties without a confirmation dialog, a launched app/URL actually opens) is deferred to Plan 65-08 per this phase's own convention (mirrors 65-02's deferral of DisplaySleepAction/ScreenLockAction/CaffeinateToggleAction on-device checks).

## Next Phase Readiness

All 3 mechanisms are stable, standalone contracts — `DarkModeToggleAction.toggle(completion:)`/`.isDarkMode`, `EmptyTrashAction.empty(completion:)`, `LaunchAction.launch(target:)`/`.resolvedURL(from:)` — none yet reference `QuickActionsBarCatalog.swift` (wiring deferred to Plan 65-07 per plan objective). No blockers.

## Self-Check: PASSED

All 3 created files verified present on disk; both task commit hashes (`51cd42d`, `93ac5f1`) verified present in `git log --oneline --all`.

---
*Phase: 65-quick-actions-bar*
*Completed: 2026-07-26*
