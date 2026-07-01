---
phase: 06-priority-resolver-settings-v1-ship
plan: 09
subsystem: notch-controller-view
tags: [refactor, dead-code-removal, duplication-cleanup, gap-closure]
dependency-graph:
  requires: [06-08]
  provides: [presentTransientChange-helper, wingsShape-helper]
  affects: [NotchWindowController.swift, NotchPillView.swift]
tech-stack:
  added: []
  patterns:
    - "Extract-method consolidation of duplicated enqueue-render-dismiss triplets into a single presentTransientChange() helper"
    - "Extract-method consolidation of duplicated NotchShape/matchedGeometryEffect wings skeletons into a single wingsShape(content:) generic helper"
key-files:
  created: []
  modified:
    - Islet/Notch/NotchWindowController.swift
    - Islet/Notch/NotchPillView.swift
    - Islet/Notch/IslandPresentationState.swift
  deleted:
    - Islet/Notch/DeviceActivityState.swift
decisions:
  - "DeviceActivityState deleted outright rather than repurposed — it had zero observers anywhere despite being written at 5 controller call sites; the device wings render exclusively from the resolver's IslandPresentation.device payload"
  - "NotchPillView's charging property removed but the controller's own chargingState property is UNCHANGED — it is still mutated internally by handlePower's in-place % tick and is the source the resolver reads to build the IslandPresentation.charging payload"
  - "scheduleActivityDismiss()'s own DispatchWorkItem body is NOT refactored to call presentTransientChange() — its advance-branch conditionally re-arms rather than unconditionally scheduling; calling the shared helper there would double-arm the dismiss"
metrics:
  duration: ~25min
  completed: 2026-07-02
---

# Phase 06 Plan 09: Dead-Code Deletion and Duplication Consolidation Summary

Deleted the fully-unobserved `DeviceActivityState` model and the redundant `charging`
subscription on `NotchPillView`, then extracted the two duplicated code sequences (the
enqueue-render-dismiss triplet in the controller, and the wings-shape skeleton in the view)
that a fresh multi-agent code review flagged as future-fix-drift risk.

## What Was Built

**Task 1 — Finding 9 + Finding 10 (dead code deletion):**
- Deleted `Islet/Notch/DeviceActivityState.swift` outright — it was constructed and written
  at 5 controller call sites but never passed to `NotchPillView` and had zero observers.
- Removed the `deviceState` property declaration and all 5 write sites from
  `NotchWindowController.swift` (`handleDevice`, `scheduleDeviceBatteryRefresh`'s closure,
  `syncActivityModels`, `flushTransients`).
- Removed the redundant `@ObservedObject var charging: ChargingActivityState` property from
  `NotchPillView.swift` and rewrote the adjacent NOTE comment to describe only `nowPlaying`'s
  continued justification.
- Removed the `charging: chargingState` argument from `makeRootView`'s `NotchPillView(...)`
  call site and from all 8 `#Preview` blocks. The controller's own `chargingState` property
  is unchanged — it is still mutated by the in-place % tick and feeds the resolver.
- Fixed a stray `DeviceActivityState` reference discovered in `IslandPresentationState.swift`'s
  comment (out-of-scope file, but required to satisfy the plan's "zero matches anywhere under
  Islet/" acceptance criterion — Rule 1 auto-fix, one-word factual correction only).

**Task 2 — Finding 11 + Finding 12 (duplication extraction):**
- Added `presentTransientChange()` to `NotchWindowController.swift`, consolidating the
  identical `withAnimation(...) { renderPresentation() }` / `updateVisibility()` /
  `scheduleActivityDismiss()` triplet that `handlePower` and `handleDevice` each hand-rolled.
  `handleDevice`'s trailing `scheduleDeviceBatteryRefresh` call stays outside the helper
  (charging has no equivalent step).
- Added `wingsShape<Content: View>(content:)` to `NotchPillView.swift`, consolidating the
  identical `NotchShape → .fill → .matchedGeometryEffect → .frame → .overlay` skeleton that
  `wings(for:)`, `mediaWings(_:art:)`, and `deviceWings(for:)` each repeated. Collapsed the
  three numerically-identical size constants (`wingsSize`/`mediaWingsSize`/`deviceWingsSize`,
  all 290×32) into the single `wingsSize`.

**Task 3 — full-suite regression verification (no source changes):**
- Ran the complete `IsletTests` suite (120 tests, 11 files) after Tasks 1-2. Zero failures,
  confirming the deletions and extractions introduced no behavioral regression.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Stray `DeviceActivityState` reference in an unrelated file's comment**
- **Found during:** Task 1 verification (`grep -rn "deviceState|DeviceActivityState" Islet/`)
- **Issue:** `IslandPresentationState.swift`'s header comment read "Mirrors ChargingActivityState
  / DeviceActivityState exactly" — a prose reference to the just-deleted type, in a file not
  listed in the plan's `files_modified`.
- **Fix:** Trimmed the comment to reference only `ChargingActivityState` (the type that still
  exists). One-word-scope textual correction, no logic change.
- **Files modified:** `Islet/Notch/IslandPresentationState.swift`
- **Commit:** 3690e77

## Verification

- `xcodegen generate` + `xcodebuild build -scheme Islet -destination 'platform=macOS'` →
  `BUILD SUCCEEDED` after both Task 1 and Task 2.
- `xcodebuild test -scheme Islet -destination 'platform=macOS'` → `TEST SUCCEEDED`, 120/120
  tests passing, zero failures — run after Task 2 and again standalone in Task 3.
- `grep -rn "deviceState\|DeviceActivityState" Islet/` → 0 matches.
- `find Islet -name "DeviceActivityState.swift"` → no output (file deleted).
- `grep -c "@ObservedObject var charging" Islet/Notch/NotchPillView.swift` → 0.
- `grep -c "charging: ChargingActivityState()" Islet/Notch/NotchPillView.swift` → 0.
- `grep -c "presentTransientChange()" Islet/Notch/NotchWindowController.swift` → 3 (declaration
  + handlePower + handleDevice call sites).
- `grep -c "wingsShape {" Islet/Notch/NotchPillView.swift` → 3 (wings/mediaWings/deviceWings).
- `grep -c "mediaWingsSize\|deviceWingsSize" Islet/Notch/NotchPillView.swift` → 0.

## Known Stubs

None — this plan is pure deletion and extract-method refactoring; no new UI surface or data
flow was introduced.

## Self-Check: PASSED

- FOUND: Islet/Notch/NotchWindowController.swift (modified, both commits)
- FOUND: Islet/Notch/NotchPillView.swift (modified, both commits)
- FOUND: Islet/Notch/IslandPresentationState.swift (modified, Task 1 commit)
- MISSING (expected — deleted): Islet/Notch/DeviceActivityState.swift
- FOUND commit 3690e77 (Task 1) in `git log --oneline`
- FOUND commit 0e05213 (Task 2) in `git log --oneline`
