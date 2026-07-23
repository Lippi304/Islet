---
phase: 60-caps-lock-hud-update-activity-restyle
plan: 03
subsystem: ui
tags: [swiftui, settings, appstorage, popover]

# Dependency graph
requires:
  - phase: 60-caps-lock-hud-update-activity-restyle
    plan: 60-01
    provides: "ActivitySettings.updateHudKey + capsLockKey (already-landed AppStorage keys this plan's SettingsView bindings consume directly)"
provides:
  - "updateHudEnabled @AppStorage + 'update' ActivityCardData entry in systemHUDCards — the Update Available card now exists in the Settings grid, default OFF"
  - "showCapsLockPermissionExplanation @State + capsLockPermissionExplanationView popover — Caps Lock's options chevron now opens a working, worded Accessibility permission explanation instead of being wired to nil"
affects: [60-05]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Caps Lock's permission popover clones osdPermissionExplanationView's exact container/button shape (own private var, not a shared generic popover) — third instance of this codebase's one-popover-per-activity convention (Focus, OSD, now Caps Lock)"

key-files:
  created: []
  modified:
    - Islet/SettingsView.swift

key-decisions:
  - "capsLockPermissionExplanationView has no health-check-timer confirmation path (unlike OSD's OSDInterceptor) — its 'Open System Settings' button's job ends at opening the pane, matching the plan's own scoping note"

patterns-established: []

requirements-completed: [CAPS-01, UPDATE-01]

# Metrics
duration: 10min
completed: 2026-07-23
---

# Phase 60 Plan 03: Update Available Card & Caps Lock Permission Popover Summary

**Update Available Settings card added to the System-HUDs grid (default OFF), and Caps Lock's previously-inert options chevron now opens a working, OSD-styled Accessibility permission popover that deep-links to System Settings.**

## Performance

- **Duration:** ~10 min
- **Completed:** 2026-07-23T17:59:55Z
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments
- `updateHudEnabled` `@AppStorage(ActivitySettings.updateHudKey)` + a new `ActivityCardData(id: "update", ...)` entry appended to `systemHUDCards` — exact copy from 60-UI-SPEC.md's New Settings Card table, `isNew: true`, `onOptionsTap: nil` (no permission gate)
- `showCapsLockPermissionExplanation` `@State` flag wires the Caps Lock card's `onOptionsTap` (previously `nil` — RESEARCH.md Pitfall 2), a third `.popover` attachment on the `categorySection(title: "System-HUDs", ...)` call site, and a new `capsLockPermissionExplanationView` cloning `osdPermissionExplanationView`'s exact structure with Caps Lock's own locked copy ("Caps Lock HUD" heading, Accessibility-access body text) and the same Accessibility deep-link URL

## Task Commits

Each task was committed atomically:

1. **Task 1: Update Available Settings card** - `95581c4` (feat)
2. **Task 2: Caps Lock Accessibility permission popover** - `9bf1417` (feat)

## Files Created/Modified
- `Islet/SettingsView.swift` - `updateHudEnabled` AppStorage + `"update"` card; `showCapsLockPermissionExplanation` state, Caps Lock's `onOptionsTap` wiring, third popover attachment, `capsLockPermissionExplanationView`

## Decisions Made
None beyond the plan's own interfaces block — both tasks executed exactly as specified, cloning the existing Focus/OSD popover pattern verbatim per the plan's explicit "own instance, never a shared generic popover" instruction.

## Deviations from Plan

None - plan executed exactly as written. Both tasks' acceptance-criteria greps matched on first attempt; Debug build green after each task.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Both new UI surfaces (`"update"` card, Caps Lock permission popover) are ready for Plan 60-05's consolidated on-device UAT checkpoint — this plan intentionally did not include its own separate checkpoint (per the plan's `<verification>` note, folded into 60-05).
- `NotchPillView`'s `.capsLock`/`.updateAvailable` cases still render `EmptyView()` (60-01's placeholder) — real wing UI for both activities remains out of this plan's scope, per 60-01-SUMMARY.md's "Next Phase Readiness" note; that gap is Plan 60-04's stated scope (`Islet/Notch/NotchPillView.swift`), executed separately after this plan.

---
*Phase: 60-caps-lock-hud-update-activity-restyle*
*Completed: 2026-07-23*

## Self-Check: PASSED

`Islet/SettingsView.swift` confirmed present and modified on disk; both task commit hashes (95581c4, 9bf1417) confirmed in git log; SUMMARY.md itself confirmed present at `.planning/phases/60-caps-lock-hud-update-activity-restyle/60-03-SUMMARY.md`.
