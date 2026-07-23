---
phase: 60-caps-lock-hud-update-activity-restyle
plan: 05
subsystem: system-glue, ui
tags: [swift, swiftui, accessibility, nsevent, layout]

# Dependency graph
requires:
  - phase: 60-caps-lock-hud-update-activity-restyle
    plan: "60-01"
    provides: "CapsLockActivity/UpdateActivity, IslandResolver .capsLock/.updateAvailable cases"
  - phase: 60-caps-lock-hud-update-activity-restyle
    plan: "60-02"
    provides: "CapsLockMonitor, NotchWindowController signal wiring"
  - phase: 60-caps-lock-hud-update-activity-restyle
    plan: "60-04"
    provides: "capsLockWings/updateWings wing rendering"
provides:
  - "On-device empirical resolution of RESEARCH.md Pitfall 3 (live Accessibility reconcile) and Pitfall 4 (Update wing tap-target reliability)"
  - "CapsLockMonitor health-check retry + modifier-flag dedup"
  - "capsLockWings/updateWings rebuilt on the live-notch-width camera-block mechanism"
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "CapsLockMonitor 5s health-check timer (mirrors OSDInterceptor.reconcileMode()) for delayed Accessibility grant propagation"
    - "capsLockWings/updateWings rebuilt on osdWings' round-15+ proven mechanism: explicit fixed-width camera-block spacer sized from interaction.collapsedNotchSize, not a flexible Spacer()"

key-files:
  created: []
  modified:
    - Islet/Notch/CapsLockMonitor.swift
    - Islet/Notch/NotchPillView.swift

key-decisions:
  - "AXIsProcessTrusted() can read false immediately after a fresh grant even post-relaunch — CapsLockMonitor now arms a 5s retry timer instead of a single check, resolving Pitfall 3 empirically (no relaunch needed once trust propagates)"
  - "NSEvent .flagsChanged fires on every modifier key (Shift/Cmd/Option/Fn), not just Caps Lock — CapsLockMonitor now dedupes against the last reported capsLock state so normal typing no longer re-triggers/re-arms the HUD"
  - "capsLockWings' original Spacer()-based layout (static wingsLabelWidth/2, tuned for the shorter 'Connected' string) could not guarantee clearance for the longer 'Caps Lock On/Off' text — rebuilt on the same live-notch-width + explicit-camera-block mechanism osdWings established, margin=65 confirmed correct on-device"
  - "updateWings had the same Spacer()-based fragility; rebuilt on the same mechanism, tuned to margin=30/pillWidth=52 after on-device iteration (Update's shorter content needs less safety margin than Caps Lock's)"

patterns-established: []

requirements-completed: [CAPS-01, UPDATE-01]

# Metrics
duration: ~3h (extended on-device debugging session)
completed: 2026-07-23
---

# Phase 60 Plan 05: Build/Test Gate + On-Device Checkpoint Summary

**Closed out Phase 60 via the automated build/test gate and an extended on-device UAT that surfaced and fixed 4 real bugs beyond the plan's own scope — a stale-TCC-app-path confusion, two Accessibility-trust and event-filtering bugs in `CapsLockMonitor`, and clipping/sizing bugs in both `capsLockWings` and `updateWings` — before all 11 checklist steps and both RESEARCH.md open questions were confirmed passing.**

## Performance

- **Duration:** ~3h (extended interactive on-device debugging, not a straight walkthrough)
- **Completed:** 2026-07-23
- **Tasks:** 2/2 (build/test gate + on-device checkpoint)

## Accomplishments

- **Task 1 (build/test gate):** Debug and Release builds both green; Release build's symbol table confirmed to exclude `debugSpikeSimulateUpdateAvailable` (0 matches via build-log grep). Cmd+U full `IsletTests` suite confirmed green by the user (aside from the 2 pre-existing, documented `CalendarGlanceTests` failures).
- **Task 2 (on-device checkpoint), all 11 steps confirmed**, including the two explicitly-flagged open research questions:
  - **RESEARCH.md Pitfall 3 (live Accessibility reconcile) — RESOLVED:** empirically, a single `AXIsProcessTrusted()` check at toggle-time could read `false` even with the grant visibly checked in System Settings (root-caused via a red herring first — the user had granted Accessibility/Input Monitoring to a stale `/Applications/Islet.app` copy, not the actively-running DerivedData Debug build; once corrected to the right binary, `AXIsProcessTrusted()` still initially read `false`). Fixed with a 5s health-check retry timer in `CapsLockMonitor`, mirroring `OSDInterceptor.reconcileMode()`'s already-proven pattern — trust propagates and the monitor installs live, no relaunch required.
  - **RESEARCH.md Pitfall 4 (Update wing tap-target reliability) — RESOLVED:** confirmed reliable across 5+ repeated taps at different points on the wing after the width/positioning fixes below; zero click-through.
  - **New bug found and fixed — Caps Lock HUD never dismissing:** `NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged)` fires on every modifier key (Shift/Cmd/Option/Fn), not just Caps Lock. The callback re-triggered `handleCapsLockChange` on every one of them, continuously re-enqueuing/re-arming the dismiss timer during ordinary typing. Fixed by deduping against the last reported Caps Lock boolean state so `onChange` only fires on an actual transition.
  - **New bug found and fixed — text/content clipped under the camera housing:** `capsLockWings`' original `Spacer()`-based layout (reusing the shared `wingsLabelWidth/2` constant, tuned for the shorter "Connected" string elsewhere in the codebase) left "Caps Lock On/Off"'s leading "C" rendering under the physical camera. `updateWings` had the same underlying fragility. Both wings were rebuilt on `osdWings`' own round-15+ proven mechanism — an explicit fixed-width camera-block spacer sized from the live OS-reported notch width (`interaction.collapsedNotchSize`) instead of a flexible `Spacer()` — then tuned against the real device across several rounds (capsLockWings: margin=65; updateWings: margin=30, tighter content boxes) to balance clearance against visual width.

## Task Commits

Four commits during this checkpoint (beyond the original 2-task plan, all discovered via on-device UAT):

1. `fix(60-05): CapsLockMonitor health-check retry for delayed Accessibility grant`
2. `fix(60-05): capsLockWings text clipped under camera housing`
3. `fix(60-05): CapsLockMonitor fired on every modifier key, not just Caps Lock`
4. `fix(60-05): updateWings sizing rebuilt and tuned on-device`

## Deviations from Plan

Significant — the plan's own `<threat_model>` anticipated this checkpoint would be "the sole verification path" for exactly this class of issue (Accessibility TCC state, tap-target/click-through geometry) since neither can be asserted via XCTest. What actually surfaced went beyond the 2 explicitly-flagged open questions: a genuine Accessibility live-reconcile bug (not just an unresolved question — the single-check approach was actually broken), a modifier-key event-filtering bug with no prior flag in RESEARCH.md, and layout-clipping bugs in both new wings (the `Spacer()`-based mechanism `capsLockWings`/`updateWings` originally used, from Plan 60-04, turned out to share the same fundamental fragility `osdWings` needed 16 documented rounds to fix in an earlier phase). All fixes stayed within Rule 3 (blocking bug fixes surfaced by verification) — no scope-creep beyond what on-device testing required to pass the plan's own `must_haves`.

## Issues Encountered

None outstanding — all issues found during this checkpoint were root-caused and fixed within this same plan, then re-verified on-device before approval.

## Next Phase Readiness

Phase 60 (Caps Lock HUD + Update-Activity Restyle) is fully verified: CAPS-01 and UPDATE-01 both closed, all 4 ROADMAP Success Criteria confirmed on-device, both RESEARCH.md open questions resolved empirically. No carry-over items.

---
*Phase: 60-caps-lock-hud-update-activity-restyle*
*Completed: 2026-07-23*

## Self-Check: PASSED

Both modified files (`CapsLockMonitor.swift`, `NotchPillView.swift`) confirmed present with their fixes; all 6 commits from this checkpoint confirmed in git log; user confirmed all 11 on-device checklist steps and the Cmd+U test suite passing.
