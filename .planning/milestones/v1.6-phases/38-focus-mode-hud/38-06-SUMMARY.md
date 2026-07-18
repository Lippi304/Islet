---
phase: 38-focus-mode-hud
plan: 06
subsystem: ui
tags: [swiftui, settings, focus-mode, permissions, INFocusStatusCenter, hud-05]

# Dependency graph
requires:
  - phase: 38-03
    provides: "FocusModeMonitor.isAuthorized / requestAuthorization(completion:), ActivitySettings.focusKey / focusPermissionStatusHint(toggleOn:granted:)"
provides:
  - "SettingsView Focus Mode HUD toggle (@AppStorage(ActivitySettings.focusKey), defaults false, D-01)"
  - "Live D-05 status hint (\"Permission needed — tap to grant\" / \"Active\") in the Activities section"
  - "D-02 permission-request trigger on the off-to-on toggle flip only"
  - "Path-A (INFocusStatusCenter) permission explanation popover with locked 38-UI-SPEC.md copy"
affects: [38-05, 38-07]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "First Settings row to attach .popover(isPresented:) directly to a Toggle (mirrors NotchPillView.swift's QuickAddPopover .popover idiom, the codebase's one existing precedent)"

key-files:
  created: []
  modified: [Islet/SettingsView.swift, Islet.xcodeproj/project.pbxproj]

key-decisions:
  - "Built ONLY the Path-A (INFocusStatusCenter) permission explanation variant — 38-01-SUMMARY.md's on-device spike locked detection to Path A, not the FDA fallback the plan's Task 2 <action> describes as its default; per 38-03-SUMMARY.md's explicit Next-Phase-Readiness instruction and this plan's own path-a contingency clause"
  - "Regenerated Islet.xcodeproj via xcodegen — FocusModeMonitor.swift (shipped in 38-03) was missing from PBXFileReference/PBXBuildFile/PBXSourcesBuildPhase, a pre-existing gap left by 38-03's merge that blocked this plan's build (Rule 3 fix, folded into Task 1's commit)"

patterns-established: []

requirements-completed: [HUD-05]

# Metrics
duration: ~20min
completed: 2026-07-17
---

# Phase 38 Plan 06: Focus Mode HUD Settings UI Summary

**SettingsView.swift gets an opt-in "Focus Mode HUD" toggle (default OFF), a live D-05 permission-status hint, and the codebase's first manual OS-permission explanation popover — built exclusively against the Path-A (INFocusStatusCenter) copy variant the Phase 38 spike confirmed.**

## Performance

- **Duration:** ~20 min
- **Started:** 2026-07-17T00:00:00Z (approx, first tool call)
- **Completed:** 2026-07-17T00:11:36Z
- **Tasks:** 2 (both auto)
- **Files modified:** 2 (Islet/SettingsView.swift, Islet.xcodeproj/project.pbxproj)

## Accomplishments
- Added `@AppStorage(ActivitySettings.focusKey) private var focusEnabled = false` — the one activity toggle in this codebase that defaults OFF (D-01), plus `Toggle("Focus Mode HUD", isOn: $focusEnabled)` in the existing Activities section
- Wired a live D-05 status hint (`ActivitySettings.focusPermissionStatusHint(toggleOn:granted:)`) below the toggle, tappable to re-open the explanation popover — the only user-initiated retry path (D-04, no automatic re-prompt)
- `.onChange(of: focusEnabled)` requests the permission explanation ONLY on an off-to-on flip while `FocusModeMonitor.isAuthorized` is false (D-02) — never at launch
- Built the Path-A (`INFocusStatusCenter`) permission explanation popover with 38-UI-SPEC.md's exact locked copy ("Allow Focus Status Access" / "Continue" → `FocusModeMonitor.requestAuthorization(completion:)`), NOT the Full Disk Access variant — confirmed against `FocusModeMonitor.swift`'s actual shipped API before wiring
- Fixed a pre-existing blocking gap: `Islet.xcodeproj` had never been regenerated after Plan 38-03 added `FocusModeMonitor.swift`, so this plan's `FocusModeMonitor.isAuthorized`/`requestAuthorization` calls failed to compile until `xcodegen generate` re-synced the project file (Rule 3)

## Task Commits

Each task was committed atomically:

1. **Task 1: Toggle row + status hint + onChange permission trigger** - `662bc04` (feat)
2. **Task 2: Permission explanation popover** - `545649a` (feat)

## Files Created/Modified
- `Islet/SettingsView.swift` — added `focusEnabled`/`showFocusPermissionExplanation` state, the `Toggle("Focus Mode HUD", ...)` row with its `.onChange` permission trigger and `.popover` attachment, the tappable status-hint `Text`, and the `focusPermissionExplanationView` computed property (Path-A copy only)
- `Islet.xcodeproj/project.pbxproj` — regenerated via `xcodegen generate`; adds the missing `FocusModeMonitor.swift` file reference/build-file/sources-phase entries (4 lines total, no other churn)

## Decisions Made
- Path-A-only popover copy, per the mandatory pre-read of `38-03-SUMMARY.md` and this plan's own contingency clause — see `key-decisions` above.
- Folded the `xcodegen generate` fix into Task 1's commit rather than a separate commit, since it was a strict prerequisite for Task 1's own acceptance-criteria build to pass (Rule 3, not a new task).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] `Islet.xcodeproj` missing `FocusModeMonitor.swift` from the build target**
- **Found during:** Task 1 first build attempt
- **Issue:** `xcodebuild build` failed with `cannot find 'FocusModeMonitor' in scope` at all 3 call sites in `SettingsView.swift`. `Islet.xcodeproj/project.pbxproj` had zero references to `FocusModeMonitor.swift` even though Plan 38-03 committed the file — the project file was never regenerated after that plan's merge.
- **Fix:** Ran `xcodegen generate` (the project's documented single source of truth, per `project.yml`'s own header comment) to re-sync the `.xcodeproj` from the `Islet/` folder contents.
- **Files modified:** `Islet.xcodeproj/project.pbxproj` (4 lines added — file reference, build file, group entry, sources-phase entry — no other churn)
- **Verification:** `grep -c FocusModeMonitor Islet.xcodeproj/project.pbxproj` went from 0 to 4; `xcodebuild build -configuration Debug` succeeded
- **Committed in:** `662bc04` (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Necessary to unblock Task 1's build; no scope creep beyond the missing project-file registration.

## Issues Encountered
None beyond the project-file gap above.

## User Setup Required

None — no external service configuration required. `INFocusStatusCenter.default.requestAuthorization` (triggered by the "Continue" button) will be exercised for the first time on-device only when a user actually flips the Focus Mode HUD toggle on.

## Next Phase Readiness

- D-01 through D-05 are all satisfied: opt-in default (D-01), request-only-on-flip (D-02), the Path-A `requestAuthorization` trigger (substituting D-03's FDA deep link, since Path A won the spike), silent-inert-on-decline (D-04), and the legible persistent status hint (D-05).
- **Plan 38-05** (controller start/stop wiring) is unaffected by this plan — it already gates `FocusModeMonitor.start()` on `ActivitySettings.focusKey` + `FocusModeMonitor.isAuthorized`, both of which this plan's toggle now drives correctly.
- **Plan 38-07** (spike cleanup) is unaffected — this plan touched only `SettingsView.swift` and the project file, not `FocusDetectionSpike.swift`.
- HUD-05 requirement is now considered complete from the Settings-UI side; overall phase-level completion depends on the other Phase 38 plans' own readiness notes.

## Self-Check: PASSED

- FOUND: Islet/SettingsView.swift (`Toggle("Focus Mode HUD"`, `focusPermissionExplanationView`, `onChange(of: focusEnabled)`)
- FOUND: commit 662bc04
- FOUND: commit 545649a
- Debug build (`xcodebuild build -project Islet.xcodeproj -scheme Islet -configuration Debug`) succeeded after both tasks

---
*Phase: 38-focus-mode-hud*
*Completed: 2026-07-17*
