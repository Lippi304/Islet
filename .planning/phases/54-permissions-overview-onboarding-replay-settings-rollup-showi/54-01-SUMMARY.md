---
phase: 54-permissions-overview-onboarding-replay-settings-rollup-showi
plan: 01
subsystem: permissions
tags: [tdd, pure-seam, tcc, coreLocation, eventKit, coreBluetooth, intents, iokit]
requires: []
provides:
  - "PermissionStatus 3-state enum (granted/denied/notYetAsked)"
  - "PermissionKind 5-case enum with System Settings deep-link anchors"
  - "4 pure mapper functions (CLAuthorizationStatus/EKAuthorizationStatus/CBManagerAuthorization/INFocusStatusAuthorizationStatus -> PermissionStatus)"
  - "combinedCalendarReminderStatus(event:reminder:) — D-13 worst-of-two combine rule"
  - "6 live status-read functions (location/bluetooth/focus/calendarEvent/reminder/inputMonitoring)"
affects:
  - "Plan 03's SettingsView Permissions section (consumes this file's read layer)"
tech-stack:
  added: []
  patterns:
    - "pure seam + thin framework glue split (mirrors OnboardingFlow.swift/IslandResolver.swift)"
key-files:
  created:
    - Islet/PermissionStatus.swift
    - IsletTests/PermissionStatusTests.swift
  modified: []
decisions:
  - "EKAuthorizationStatus.writeOnly counts as granted (Open Question 2 resolved per plan's explicit discretion call), never treated as denied"
  - "combinedCalendarReminderStatus resolves worst-of-two: denied > notYetAsked > granted (D-13 locked)"
metrics:
  duration: "15min"
  completed: "2026-07-21"
---

# Phase 54 Plan 01: Permission Status Model Summary

Pure, unit-tested 3-state (`granted`/`denied`/`notYetAsked`) permission-status model with
4 framework-enum mappers, the D-13 Calendar+Reminders worst-of-two combine rule, and 6
live status-read functions for Location, Bluetooth, Focus, Calendar, Reminders, and a
best-effort Input Monitoring read via `IOHIDCheckAccess` — the read layer Plan 03's
SettingsView Permissions section will consume with zero further framework research.

## What Was Built

**Task 1 (TDD, RED then GREEN):**
- `IsletTests/PermissionStatusTests.swift` — 16 tests written first (RED: failed to
  compile since `PermissionStatus.swift` didn't exist yet), mirroring
  `OnboardingFlowTests.swift`'s plain-`XCTestCase`, literal-enum-case, no-mocking shape.
- `Islet/PermissionStatus.swift` (new) — `PermissionStatus` 3-state enum (D-04 locked);
  `PermissionKind` 5-case enum (`location`, `calendarReminders`, `bluetooth`, `focus`,
  `inputMonitoring` — D-01/D-02 locked, Automation/Apple Events deliberately excluded)
  with a `deepLinkAnchor` computed property per case; 4 pure mapper functions, each an
  exhaustive `switch` with `@unknown default -> .notYetAsked`; `combinedCalendarReminderStatus`
  implementing D-13's worst-of-two rule. GREEN: all 16 tests pass.

**Task 2 (auto):**
- Added `import IOKit.hid` and 6 live-read functions to the same file, each a one-line
  call into Task 1's pure mappers: `locationPermissionStatus()`,
  `bluetoothPermissionStatus()` (mirrors the confirmed-working
  `CBManager.authorization == .allowedAlways` read at `NotchWindowController.swift:1896`,
  no new `BluetoothMonitor` property added), `focusPermissionStatus()`,
  `calendarEventPermissionStatus()`, `reminderPermissionStatus()`, and
  `inputMonitoringPermissionStatus()` (best-effort `IOHIDCheckAccess` read with the
  D-03/Pitfall 4 limitation documented inline — no reliable in-app trigger exists for the
  residual "not yet asked" edge case). Zero new monitor/timer classes added. Debug build
  green.

## Verification

- `xcodebuild test -scheme Islet -destination 'platform=macOS' -only-testing:IsletTests/PermissionStatusTests` — 16/16 tests pass.
- `xcodebuild build -scheme Islet -destination 'platform=macOS'` — Debug build succeeded.
- Acceptance-criteria greps: `case granted, denied, notYetAsked` (1), `func combinedCalendarReminderStatus` (1), `@unknown default` (4), 6 live-read functions matched via `grep -cE "^func (location|bluetooth|focus|calendarEvent|reminder|inputMonitoring)PermissionStatus\(\)"`, `class.*Monitor` (0).

## Deviations from Plan

None — plan executed exactly as written. New source file required regenerating the
Xcode project (`xcodegen generate`) so `IsletTests`/`Islet` targets picked up the new
files — a mechanical, expected step given this project's XcodeGen-driven source
discovery (`project.yml`), not a deviation from plan intent.

## TDD Gate Compliance

- RED gate: `test(54-01): add failing tests for permission status mappers` (0890612) —
  confirmed failing to compile (missing symbols) before implementation existed.
- GREEN gate: `feat(54-01): add PermissionStatus enum, pure mappers, PermissionKind anchors` (5555422) —
  all 16 tests pass.
- No REFACTOR commit — functions were small enough on first pass, per the plan's own
  expectation ("no REFACTOR step expected for functions this small").

## Self-Check: PASSED
