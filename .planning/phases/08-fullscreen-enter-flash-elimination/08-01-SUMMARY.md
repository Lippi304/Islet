---
phase: 08-fullscreen-enter-flash-elimination
plan: 01
subsystem: fullscreen-detection
tags: [fullscreen, cgs, probe, wave-0, blocked]
status: partial
dependency-graph:
  requires: []
  provides: [FS-01-probe-instrumentation]
  affects: [08-02-PLAN.md, 08-03-PLAN.md]
tech-stack:
  added: []
  patterns:
    - "DEBUG-only @_silgen_name CGS private-notification probe (CGSRegisterNotifyProc/CGSRemoveNotifyProc), mirroring the existing CGSMainConnectionID/CGSCopyManagedDisplaySpaces binding style in FullscreenSpaceProbe.swift"
key-files:
  created: []
  modified:
    - Islet/Notch/FullscreenSpaceProbe.swift
    - Islet/Notch/NotchWindowController.swift
decisions: []
metrics:
  duration: "~20 min (Task 1 only; Task 2 not executed)"
  completed: null
---

# Phase 8 Plan 01: FS-01 CGS Event 106/107 Timing Probe Summary

Built DEBUG-only instrumentation for the one new candidate signal RESEARCH.md identified
(private CGS notifications `CGSClientEnterFullscreen`=106 / `CGSClientExitFullscreen`=107 via
`CGSRegisterNotifyProc`) to measure whether it fires for another process's real fullscreen
transition early enough to eliminate the fullscreen-enter flash. **Task 2 — the on-device D-05
trigger-matrix run and the resulting option-a/option-b/option-c decision — was NOT executed by
this session** and remains a blocking checkpoint awaiting human action on real notch hardware.

## What Was Done (Task 1 — completed, committed)

- **`Islet/Notch/FullscreenSpaceProbe.swift`**: appended (existing
  `isBuiltinDisplayInFullscreenSpace` function untouched) the `kCGSClientEnterFullscreen: UInt32 =
  106` / `kCGSClientExitFullscreen: UInt32 = 107` constants, the `CGSNotifyProc` C-convention
  typealias, and `@_silgen_name` bindings for `CGSRegisterNotifyProc` / `CGSRemoveNotifyProc` —
  same declaration shape as the file's existing `CGSMainConnectionID` /
  `CGSCopyManagedDisplaySpaces` bindings (no `dlopen`, resolves through the existing `import
  CoreGraphics`).
- **`Islet/Notch/NotchWindowController.swift`** (all additions gated `#if DEBUG` / `#endif`):
  - `fullscreenProbeCallback: CGSNotifyProc` (nonisolated static) — hops to main via
    `DispatchQueue.main.async` before touching `self` (T-08-01, no main-thread guarantee on a raw
    CGS callback).
  - `probeContext` (nonisolated lazy var) — the opaque `Unmanaged` pointer passed at both
    registration and teardown (T-08-02, use-after-free mitigation).
  - Registration of both event codes in `start()`, alongside the existing
    `spaceObserver`/`appActivateObserver` registration.
  - `handleFullscreenProbeEvent(type:)` — logs `[FS-01 probe]`, the raw event type, `Date()`, and
    the live `isBuiltinDisplayInFullscreenSpace(...)` read at that instant (the option-a vs.
    option-b measurement).
  - The existing `spaceObserver`/`appActivateObserver` closures now also print
    `[FS-01 probe] activeSpaceDidChange fired at ...` / `[FS-01 probe] didActivateApplication
    fired at ...` before calling `updateVisibility()`, so all signals land in one Console stream
    for direct timing comparison.
  - `deinit` teardown calling `CGSRemoveNotifyProc` for both event codes with the identical
    proc/type/userData triple used at registration.
- Verified: `xcodebuild build -scheme Islet -configuration Debug` succeeds with zero errors;
  `xcodebuild test -scheme Islet -configuration Debug -only-testing:IsletTests` — 141/141 passing
  (no regression).

## What Was NOT Done — Task 2 (blocking checkpoint, requires human on-device action)

Task 2 (`type="checkpoint:decision" gate="blocking"`) requires a human to:
1. Build and run Islet on-device in Debug configuration (real notch hardware — this cannot be
   done from this execution environment).
2. Execute the D-05 trigger matrix (green-button click, menu-bar "Enter Full Screen", a
   fullscreen video app), **at least 3 trials each**, both enter AND exit.
3. Record, for every trial, the raw `[FS-01 probe]` Console lines: does a `CGS event 106` line
   appear for ANOTHER process's fullscreen transition; its timestamp vs. the
   `activeSpaceDidChange`/`didActivateApplication` lines; the logged
   `isBuiltinDisplayInFullscreenSpace` value; and whether the visible flash still appears.
4. Select **option-a**, **option-b**, or **option-c** from `08-01-PLAN.md`'s `<options>` block
   based on that evidence.

This session has no access to physical notch hardware and cannot fabricate this evidence. No
option was selected. Neither `08-02-PLAN.md` (fix path) nor `08-03-PLAN.md` (escalation path) is
unblocked yet.

## Deviations from Plan

None on the completed Task 1 — implemented exactly per `08-01-PLAN.md`'s `<action>` spec
(constant names, typealias, binding shapes, DEBUG gating, teardown triple all match). No auto-fix
issues encountered.

## Resume Instructions

To resume this plan:
1. On the notch MacBook, open the project in Xcode and Run in Debug configuration (the `#if
   DEBUG` probe is active in this build).
2. Open Console.app (or Xcode's console) filtered to the `Islet` process.
3. Execute the D-05 trigger matrix described above and copy the raw `[FS-01 probe]` lines for
   every trial into this plan's checkpoint response.
4. State the selected option (a/b/c) with the supporting evidence — this SUMMARY.md should then
   be updated (or a continuation SUMMARY appended) recording the decision, and execution can
   proceed to whichever of `08-02-PLAN.md` / `08-03-PLAN.md` the decision unblocks.

## Known Stubs

None — Task 1's DEBUG-only probe wiring has no runtime-data stub concerns (it is diagnostic-only
instrumentation, not shipped feature code).

## Threat Flags

None beyond what `08-01-PLAN.md`'s own `<threat_model>` already dispositions (T-08-01 through
T-08-04, all `mitigate`/`accept` and implemented exactly as specified: main-thread hop before
touching `self`; identical teardown triple; only the `type` param is read, `data`/`dataLength`
never dereferenced; entire probe gated `#if DEBUG`).

## Self-Check: PASSED

- FOUND: Islet/Notch/FullscreenSpaceProbe.swift (contains kCGSClientEnterFullscreen,
  kCGSClientExitFullscreen, CGSNotifyProc, CGSRegisterNotifyProc, CGSRemoveNotifyProc)
- FOUND: Islet/Notch/NotchWindowController.swift (contains handleFullscreenProbeEvent, [FS-01
  probe] logging, #if DEBUG registration/teardown)
- FOUND: commit dea30c1 in `git log --oneline`
- Build: `xcodebuild build -scheme Islet -configuration Debug` — BUILD SUCCEEDED
- Tests: 141/141 passing, no regression
