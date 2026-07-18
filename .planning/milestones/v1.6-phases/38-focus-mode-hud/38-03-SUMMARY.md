---
phase: 38-focus-mode-hud
plan: 03
subsystem: notch
tags: [focus-mode, INFocusStatusCenter, monitor, activity-settings, hud-05]

# Dependency graph
requires: ["38-01", "38-02"]
provides:
  - "FocusModeMonitor: @MainActor system-glue class polling INFocusStatusCenter.focusStatus.isFocused every 2.5s, silently degrading on any unauthorized/nil read"
  - "ActivitySettings.focusKey (\"activity.focus\") and focusPermissionStatusHint(toggleOn:granted:) pure D-05 status-hint mapping"
affects: [38-04, 38-05, 38-06, 38-07]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "FocusModeMonitor follows the PowerSourceMonitor/BluetoothMonitor Monitor-protocol shape (nonisolated(unsafe) state, injected onChange closure, start()/stop(), empty deinit with owner-driven teardown) but is the first Monitor in this codebase that must POLL (DispatchSourceTimer, 2.5s/500ms leeway) rather than react to a push notification, since INFocusStatusCenter.focusStatus is not KVO/@objc dynamic"

key-files:
  created: [Islet/Notch/FocusModeMonitor.swift]
  modified: [Islet/ActivitySettings.swift, IsletTests/ActivitySettingsTests.swift]

key-decisions:
  - "Task 1 implemented against Path A (INFocusStatusCenter), NOT the plan's default Path B (Assertions.json + Full Disk Access) — per 38-01-SUMMARY.md's on-device spike result and the plan's own path-a contingency instructions in its objective"
  - "openFullDiskAccessSettings() was NOT built; replaced by static FocusModeMonitor.requestAuthorization(completion:) calling INFocusStatusCenter.default.requestAuthorization, per the plan's explicit Path-A substitution instruction"

patterns-established: []

requirements-completed: []  # HUD-05 not yet complete — this plan ships the Monitor + Settings key/mapping only; resolver/controller/view wiring lands in 38-04/38-05/38-06

# Metrics
duration: ~25min
completed: 2026-07-17
---

# Phase 38 Plan 03: FocusModeMonitor + ActivitySettings Focus Key Summary

**`FocusModeMonitor` polls `INFocusStatusCenter.focusStatus.isFocused` (Path A, not the plan's default Path B) every 2.5s with silent-degrade-on-failure semantics, plus `ActivitySettings.focusKey`/`focusPermissionStatusHint(toggleOn:granted:)` for the Settings layer Plan 38-06 wires up.**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-07-17T00:03:33Z (approx, first tool call)
- **Completed:** 2026-07-17 (this session)
- **Tasks:** 2 (1 auto, 1 auto+tdd)
- **Files modified:** 3 (1 created, 2 modified)

## Accomplishments
- Read `38-01-SUMMARY.md` FIRST per the plan's mandatory first step, confirmed the on-device spike locked detection to Path A (`INFocusStatusCenter`), not the plan's Path-B-by-default Task 1 action text
- Implemented `FocusModeMonitor.swift` against `38-RESEARCH.md`'s Architecture Patterns §1 `INFocusStatusCenter` code example (verified against the actual API usage already proven compiling in `Islet/FocusDetectionSpike.swift`'s Probe A), following `PowerSourceMonitor.swift`/`BluetoothMonitor.swift`'s exact lifecycle shape
- Added `ActivitySettings.focusKey` + `focusPermissionStatusHint(toggleOn:granted:)` via a full RED→GREEN TDD cycle: 3 failing test methods committed first (confirmed via `xcodebuild build-for-testing` compile failure — this project's tests hang under `xcodebuild test`, so a compile-time RED substitutes for the usual "run and watch it fail" step, per project convention), then the minimal implementation making the build succeed

## Task Commits

Each task was committed atomically:

1. **Task 1: FocusModeMonitor.swift — the detection-path glue** - `35a9bfa` (feat)
2. **Task 2 RED: failing tests for focusKey + permission status hint** - `b9bc3b7` (test)
3. **Task 2 GREEN: focusKey + focusPermissionStatusHint implementation** - `2d43fd4` (feat)

## Files Created/Modified
- `Islet/Notch/FocusModeMonitor.swift` (new) — `@MainActor final class FocusModeMonitor`: `DispatchSourceTimer`-driven 2.5s/500ms-leeway poll of `INFocusStatusCenter.default.focusStatus.isFocused`, gated on `authorizationStatus == .authorized`; `onChange(Bool)` fires only on an unambiguous authorized+non-nil read, otherwise the tick is silently skipped (no crash, no stale-state guess); `static var isAuthorized`; `static func requestAuthorization(completion:)`; `nonisolated func stop()`; empty `deinit` matching `PowerSourceMonitor`'s Swift-5-mode comment.
- `Islet/ActivitySettings.swift` — added `static let focusKey = "activity.focus"` (the one activity toggle that will default OFF, per D-01) and `static func focusPermissionStatusHint(toggleOn:granted:) -> String?` returning `nil`/`"Permission needed — tap to grant"`/`"Active"` verbatim per `38-UI-SPEC.md`'s Settings Permission Contract.
- `IsletTests/ActivitySettingsTests.swift` — added a `// MARK: Phase 38 / HUD-05` section with 4 test methods: `testFocusKeyName`, `testFocusPermissionHintNilWhenToggleOff`, `testFocusPermissionHintNeedsGrant`, `testFocusPermissionHintActive` (the 3 plan-specified behaviors plus one extra key-name check mirroring the existing `testNewKeyNames` pattern already in this file).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `focusKey` declaration initially misaligned, breaking the acceptance-criteria grep**
- **Found during:** Task 2 GREEN verification
- **Issue:** First-pass implementation column-aligned `static let focusKey      = "activity.focus"` with the sibling keys above it (matching their alignment style), which caused the plan's exact-string acceptance grep (`grep -n 'static let focusKey = "activity.focus"'`, single space) to return 0 matches.
- **Fix:** Removed the alignment padding, single space around `=` (matching the newer `materialStyleKey`/`weatherStyleKey` declarations already in the file rather than the older aligned block).
- **Files modified:** `Islet/ActivitySettings.swift`
- **Commit:** `2d43fd4` (folded into the GREEN commit, not a separate fix commit)

### Path-A Substitution (per the plan's own explicit contingency, not a deviation from correct behavior — documented per the plan's requirement to record it)

The plan's Task 1 `<action>` text is written against Path B (`~/Library/DoNotDisturb/DB/Assertions.json` + Full Disk Access) by default, with an explicit fallback clause: *"If 38-01-SUMMARY.md instead recorded `path-a`: replace the file-read logic in `poll()`/`isAuthorized` with `INFocusStatusCenter.default.authorizationStatus == .authorized` + `INFocusStatusCenter.default.focusStatus.isFocused`... and rename `openFullDiskAccessSettings()` to a `requestAuthorization(completion: @escaping (Bool) -> Void)` method calling `INFocusStatusCenter.default.requestAuthorization` instead."*

`38-01-SUMMARY.md` recorded `path-a`. This plan was executed accordingly:
- `poll()` reads `INFocusStatusCenter.default.authorizationStatus`/`focusStatus.isFocused`, not `Assertions.json`.
- `static var isAuthorized` checks `INFocusStatusCenter.default.authorizationStatus == .authorized`, not a `FileManager.default.contents(atPath:)` probe.
- `openFullDiskAccessSettings()` was never built. In its place: `static func requestAuthorization(completion: @escaping (Bool) -> Void)`, calling `INFocusStatusCenter.default.requestAuthorization { status in completion(status == .authorized) }`.
- The `x-apple.systempreferences:...Privacy_AllFiles` deep link (D-03, Full-Disk-Access-specific) was NOT implemented — it is only needed for Path B. Plan 38-06 (Settings UI) must build the `INFocusStatusCenter`-path explanation surface from `38-UI-SPEC.md`'s "If `INFocusStatusCenter` path wins" variant instead of the Full-Disk-Access variant.
- The acceptance criteria's literal grep checks (`nonisolated func stop`, `static var isAuthorized`, no force-unwraps) all still apply and pass — those checks are path-agnostic.

This substitution was explicit, plan-directed (not an ad-hoc Rule 1-4 judgment call), and is the reason this file exists in its current form rather than matching Task 1's literal default action text word-for-word.

## Issues Encountered

None beyond the alignment/grep fix above.

## User Setup Required

None — no external service configuration required. `INFocusStatusCenter.default.requestAuthorization` will be exercised for the first time on-device only once Plan 38-06 wires the Settings toggle (D-02: authorization is requested at toggle-flip time, not before).

## Next Phase Readiness

- **Plan 38-04** (resolver/controller wiring: `ActiveTransient.focus`, the `where !isExpanded` D-07 guard, the non-self-dismissal and preemption logic from `38-RESEARCH.md` §4/§5) can now consume `FocusModeMonitor`'s `onChange: (Bool) -> Void` closure and `FocusActivity.on` (already merged from 38-02).
- **Plan 38-05** (`NotchWindowController` start/stop wiring) can gate `FocusModeMonitor.start()` on `ActivitySettings.focusKey` being enabled AND `FocusModeMonitor.isAuthorized` being true, mirroring the existing Charging/Device monitor-gating convention.
- **Plan 38-06** (Settings UI) must build the `INFocusStatusCenter`-variant permission explanation surface (`"Allow Focus Status Access"` / `"Continue"` triggering `FocusModeMonitor.requestAuthorization(completion:)`) per `38-UI-SPEC.md`'s Path-A branch — NOT the Full Disk Access / `"Open System Settings"` variant, since Path A won the spike.
- **Plan 38-07** (spike cleanup) is unaffected by this plan's substitution — it still deletes `Islet/FocusDetectionSpike.swift` and its `AppDelegate.swift` call site once the real Monitor (this plan) is confirmed working on-device.
- HUD-05 requirement remains **not yet complete** — this plan ships only the Monitor + Settings key/mapping; the resolver case, controller wiring, wing view, and Settings toggle UI all ship in later Phase 38 plans.

## Self-Check: PASSED

- FOUND: Islet/Notch/FocusModeMonitor.swift
- FOUND: commit 35a9bfa
- FOUND: commit b9bc3b7
- FOUND: commit 2d43fd4
- FOUND: `static let focusKey = "activity.focus"` in Islet/ActivitySettings.swift
- FOUND: `func focusPermissionStatusHint` in Islet/ActivitySettings.swift
- Debug build (`xcodebuild build -project Islet.xcodeproj -scheme Islet -configuration Debug`) succeeded after both tasks

---
*Phase: 38-focus-mode-hud*
*Completed: 2026-07-17*
