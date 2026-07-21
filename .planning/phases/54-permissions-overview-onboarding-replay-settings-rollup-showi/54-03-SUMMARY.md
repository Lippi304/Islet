---
phase: 54-permissions-overview-onboarding-replay-settings-rollup-showi
plan: 03
subsystem: ui
tags: [swiftui, settings, permissions, tcc, onboarding]

# Dependency graph
requires:
  - phase: 54-01 (PermissionStatus.swift live-read layer)
    provides: locationPermissionStatus()/bluetoothPermissionStatus()/focusPermissionStatus()/calendarEventPermissionStatus()/reminderPermissionStatus()/inputMonitoringPermissionStatus()/combinedCalendarReminderStatus(), PermissionKind.deepLinkAnchor
  - phase: 54-02 (onboarding replay mechanism)
    provides: replayOnboarding()/requestBluetoothPermission() on NotchWindowController
provides:
  - Settings > Permissions sidebar section — 5-row always-visible list + live "X of 5 granted" summary, tap-to-act (deep-link when denied, native prompt when not-yet-asked, inert when granted)
  - "Replay Onboarding" button in About, wired to the real replayOnboarding() entry point
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "permissionRow/statusView/handlePermissionTap follow this file's existing diagnosticsSection/aboutSection ScrollView+Form+.padding(20) shape and the osdPermissionExplanationView deep-link precedent verbatim"

key-files:
  created: []
  modified:
    - Islet/SettingsView.swift
    - IsletTests/SettingsViewTests.swift

key-decisions:
  - "Plan executed exactly as written across both implementation tasks — no deviations, no Rule 1-4 fixes needed"

patterns-established: []

requirements-completed: [ARCH-P2]

# Metrics
duration: 20min
completed: 2026-07-22
---

# Phase 54 Plan 03: Permissions Overview + Onboarding Replay Settings Wiring Summary

**Settings "Permissions" sidebar section (5-row live status list + "X of 5 granted" summary, tap-to-act per D-05/D-06) and a "Replay Onboarding" button in About wired to Plan 02's replay mechanism — closes ARCH-P2 end-to-end, on-device UAT approved.**

## Performance

- **Duration:** ~20 min (2 implementation tasks + on-device UAT checkpoint)
- **Completed:** 2026-07-22
- **Tasks:** 3 (2 auto + 1 checkpoint:human-verify)
- **Files modified:** 2

## Accomplishments
- `SidebarSection.permissions` case added between Weather and Diagnostics, always visible on both notch and non-notch displays (not filtered by `visibleSections(hasNotch:)`, unlike `.switcher`).
- `permissionsSection` view: live "X of 5 granted" summary row above a `VStack` of 5 always-visible rows (Location, Calendar+Reminders combined, Bluetooth, Focus, Input Monitoring), each reading Plan 01's `PermissionStatus.swift` live-read functions via `refreshPermissionStatuses()`.
- `handlePermissionTap(kind:status:)`: granted rows are inert (`.disabled(status == .granted)`), denied rows deep-link to the specific System Settings > Privacy & Security pane (reuses the existing `osdPermissionExplanationView` URL-scheme precedent), not-yet-asked rows trigger the real native OS permission dialog per kind (`CLLocationManager`, `EKEventStore`, Bluetooth/Focus via `NotchWindowController`).
- `refreshPermissionStatuses()` called from both `.onAppear` and `.onChange(of: appearsActive)`, appended to (not replacing) the existing refresh-on-refocus discipline.
- "Replay Onboarding" button added to `aboutSection`'s `Form`, directly below Credits, calling `notchController?.replayOnboarding()` through `AppDelegate` — D-09 locked location, not moved into the new Permissions section.
- 2 new regression tests (`testVisibleSectionsIncludesPermissionsWhenHasNotchIsTrue`/`...IsFalse`) confirming `.permissions` survives `visibleSections(hasNotch:)` in both filter states.
- On-device UAT (Task 3): all 9 checklist steps confirmed by the user — Permissions section rows/summary/deep-links, Replay Onboarding carousel (Next-through-Done and mid-flow X close), state-restore after replay, and no first-launch onboarding regression. User reply: "approved".

## Task Commits

Each task was committed atomically:

1. **Task 1: Permissions sidebar section (5-row list + summary + tap-to-act)** - `3a1d14d` (feat)
2. **Task 2: Replay Onboarding button in About** - `0a548ed` (feat)
3. **Checkpoint breadcrumb (Tasks 1-2 done, Task 3 UAT pending)** - `b38c469` (docs)

**Task 3 (on-device UAT checkpoint):** no code commit — verdict recorded via user's "approved" reply covering all 9 verification steps.

## Files Created/Modified
- `Islet/SettingsView.swift` - `.permissions` `SidebarSection` case + title/icon/detail-switch wiring; 5 new `@State` permission-status properties; `refreshPermissionStatuses()`; `permissionsSection`/`permissionRow(...)`/`statusView(for:)`/`handlePermissionTap(kind:status:)`; `import CoreLocation`/`import EventKit`; "Replay Onboarding" button in `aboutSection`
- `IsletTests/SettingsViewTests.swift` - 2 new regression tests for `.permissions` surviving `visibleSections(hasNotch:)` in both states

## Decisions Made
- Plan executed exactly as written across both implementation tasks — the plan's own interfaces (Plan 01's read layer, Plan 02's `replayOnboarding()`/`requestBluetoothPermission()`) were thin and complete enough that no deviation was needed.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None. On-device UAT confirmed the full ARCH-P2 flow on the first round, no iteration or design supersession needed (unlike several prior phases' UAT rounds).

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- ARCH-P2 is now closed end-to-end (Permissions rollup tap-to-act + safe onboarding replay, both on-device verified).
- Phase 54 (permissions-overview-onboarding-replay-settings-rollup-showi) is now 3/3 plans complete.

---
*Phase: 54-permissions-overview-onboarding-replay-settings-rollup-showi*
*Completed: 2026-07-22*

## Self-Check: PASSED
- FOUND: Islet/SettingsView.swift
- FOUND: IsletTests/SettingsViewTests.swift
- FOUND: .planning/phases/54-permissions-overview-onboarding-replay-settings-rollup-showi/54-03-SUMMARY.md
- FOUND commit: 3a1d14d
- FOUND commit: 0a548ed
- FOUND commit: b38c469
