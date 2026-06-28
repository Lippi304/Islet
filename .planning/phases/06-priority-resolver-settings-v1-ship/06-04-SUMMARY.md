---
phase: 06-priority-resolver-settings-v1-ship
plan: 04
subsystem: coordination
tags: [swift, swiftui, appkit, iobluetooth, resolver, integration, battery, on-device]

# Dependency graph
requires:
  - phase: 06-priority-resolver-settings-v1-ship
    provides: "IslandResolver + TransientQueue (06-01), DeviceActivityState + BluetoothMonitor + deviceWings (06-02), ActivitySettings toggles + accent palette (06-03)"
provides:
  - "NotchPillView renders ONE IslandPresentation via a single switch (the precedence if-chain is gone)"
  - "NotchWindowController is the single arbiter: TransientQueue + handleDevice + BluetoothMonitor + toggle-gated monitors + accent injection, resolver-driven render, one one-shot dismiss advancing the queue"
  - "Live Bluetooth device battery % (IOBluetoothDevice.batteryPercentSingle) shown in the device glance via a reusable BatteryIndicator, reused by the charging glance"
affects: [06-05-ship-gate]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Single arbiter (D-05): the view renders resolve(...)'s verdict; the controller is the sole show/hide + ranking site"
    - "IOBluetooth private batteryPercent* read via KVC (guarded by responds(to:)) off the device object BluetoothMonitor already holds — same source as Alcove/Hammerspoon; the private BluetoothManager.framework was empirically dead (powered=0 in-app)"
    - "Connect-edge tracking + at-launch grace so a stable device splashes once on a real edge, not perpetually"
    - "Bounded poll for the post-connect HFP battery (AT+IPHONEACCEV lands after the connect edge)"

key-files:
  created:
    - Islet/Notch/BatteryIndicator.swift
  modified:
    - Islet/Notch/NotchPillView.swift
    - Islet/Notch/NotchWindowController.swift
    - Islet/Notch/BluetoothMonitor.swift
    - Islet/Notch/DeviceActivity.swift
    - Islet/IslandPresentationState.swift
    - project.yml
    - IsletTests/DeviceActivityTests.swift
    - IsletTests/IslandResolverTests.swift

key-decisions:
  - "A1 RESOLVED: NSBluetoothAlwaysUsageDescription is REQUIRED on macOS 26 (absence hard-crashes at first IOBluetooth register) — added to project.yml"
  - "Device battery source = IOBluetoothDevice.batteryPercentSingle (the Jabra returns 50); BluetoothManager.framework rejected after an in-app probe showed powered=0/empty; no public path (IORegistry/plist/system_profiler) has the HFP value"
  - "Device glance shows glyph (left) + battery indicator with % INSIDE the body (right); the connection sign (checkmark/xmark) is the fallback when no battery is reported. No device NAME (drops the untrusted-name render surface)"
  - "Now-Playing toggle uses a clean perl-child restart (A4 primary) with a .none-forcing fallback"
  - "BluetoothMonitor connect/disconnect callbacks hop to main (IOBluetooth delivers them off-main; @MainActor does not bind ObjC-runtime selectors)"

requirements-completed: [COORD-01, DEV-01, DEV-02, APP-03]

# Metrics
duration: multi-session (checkpoint + post-checkpoint iteration)
completed: 2026-06-28
---

# Phase 6 Plan 04: Live Integration (single arbiter) + Device Battery Summary

**Wired Wave 1 into the live app: the view renders ONE `IslandPresentation` (no precedence if-chain), the controller is the single arbiter (queue + handleDevice + BluetoothMonitor + live toggles + accent), and — after on-device UAT — the connected Bluetooth device's real battery % is read from `IOBluetoothDevice.batteryPercentSingle` and shown in a compact battery indicator reused by the charging glance.**

## Accomplishments
- **COORD-01:** `NotchPillView` renders the resolver verdict via a single `switch`; `NotchWindowController` owns the `TransientQueue`, advances it off one one-shot dismiss, keeps a single `updateVisibility()`, gates each monitor on its settings toggle (prefer stop) with live flush, and injects the persisted accent.
- **DEV-01/DEV-02 (code-complete → on-device verified):** the device connect/disconnect splash works; the device's **battery %** is shown (Jabra Elite 8 Active = 50% confirmed) — read off `IOBluetoothDevice`'s private `batteryPercent*` via KVC.
- **APP-03:** the three activity toggles start/stop monitors live and persist; the accent tints the lively elements.
- New `BatteryIndicator` (compact horizontal battery, % inside the body, green / amber<20 / red<10), reused by the charging glance.
- Full suite **119/119** green.

## Task Commits
1. **Task 1: render single IslandPresentation + accent** — `4d0c646`
2. **Task 2: controller arbiter wiring** — `b7d9668`
3. **Task 3: on-device human-verify** — approved (see post-checkpoint fixes below)

### Post-checkpoint fixes (from on-device UAT)
- `d9e1925` hop IOBluetooth callbacks to main (island vanished once a device auto-connected — off-main NSWindow calls)
- `1b16171` connect-edge-only splash + at-launch suppression (splash no longer sticks) + glyph/connection-sign layout
- `e796c3e` read device battery (IOBluetooth) + BatteryIndicator
- `115eafe` poll the HFP battery shortly after connect
- `cabfc86` % inside the battery body (it was sliding under the camera on the ~58pt wing)
- `0d73073` shrink the indicator to ~original size
- `f319e69` wings width 290pt

## Decisions Made
- See key-decisions (A1 resolved; IOBluetooth battery source; battery-in-body layout; clean NP restart; main-hop).

## Deviations from Plan
- The plan's Tasks 1–2 landed as written. The bulk of the work was **post-checkpoint iteration** driven by on-device UAT: a threading crash, the perpetual-splash bug, and a new **device-battery feature** the user requested (researched + adversarially verified before building — the private `BluetoothManager` path was rejected in favor of `IOBluetoothDevice.batteryPercentSingle`, proven on-device). The single-arbiter architecture (Task 2) was unaffected.

## Issues Encountered
- IOBluetooth delivers connect/disconnect on its own coordinator queue, not main (fixed with a main-hop).
- The HFP battery value is not in any public surface (IORegistry/plist/system_profiler) — only the private IOBluetooth property; and it can arrive a beat after the connect edge (handled with a bounded poll).
- `BluetoothManager.framework` reported `powered=0`/empty even inside the TCC-granted app — not usable.

## Known Stubs
None. Deferred carry-overs (not blockers): full multi-device Bluetooth UAT and real Developer-ID notarize/staple (the 06-05 ship gate).

## User Setup Required
None (Bluetooth permission prompt handled by NSBluetoothAlwaysUsageDescription).

## Next Phase Readiness
- The island now coexists by one ranked policy with live device battery — the v1 core experience is complete. Plan 05 (the ship gate / dry-run, APP-04) can proceed.

---
*Phase: 06-priority-resolver-settings-v1-ship*
*Completed: 2026-06-28*
