---
phase: 38-focus-mode-hud
plan: 05
subsystem: notch
tags: [focus-mode, transient-queue, preemption, controller-wiring, hud-05]

# Dependency graph
requires:
  - phase: 38-02-focus-transient-resolver
    provides: "ActiveTransient.focus, isPersistent, TransientQueue.preempt(_:), resolve()'s collapsed-only .focus case"
  - phase: 38-03-focus-mode-monitor
    provides: "FocusModeMonitor (init(onChange:), start(), stop(), isAuthorized) polling INFocusStatusCenter"
provides:
  - "NotchWindowController.focusModeMonitor lifecycle: toggle-gated idempotent start/stop mirroring powerMonitor/bluetoothMonitor"
  - "handleFocusChange(_:) wiring FocusModeMonitor's onChange into the TransientQueue"
  - "D-06 non-self-dismiss guard in scheduleActivityDismiss() (!head.isPersistent)"
  - "D-08 preemption at both Charging/Device enqueue sites (handlePower(_:), DeviceCoordinator enqueue closure)"
affects: [38-06-focus-settings-ui, 38-07-spike-cleanup]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Persistent-transient dismiss-skip via a single guard in the shared scheduleActivityDismiss() rather than a parallel timer/state machine (Pitfall 6 'one pure arbiter, no exceptions')"
    - "One-directional preemption: TransientQueue.preempt(_:) called only from Charging/Device's two enqueue sites, never from Focus's own enqueue path"

key-files:
  created: []
  modified:
    - Islet/Notch/NotchWindowController.swift
    - Islet.xcodeproj/project.pbxproj

key-decisions:
  - "Split Task 1 (lifecycle wiring) into its own commit even though startFocusModeMonitor()'s closure references handleFocusChange(_:) (added in Task 2) -- Task 1's grep-based acceptance criteria (property/function/isAuthorized/stop() counts) all pass standalone; the xcodebuild build verification was deferred to the Task 2 commit since the two tasks are genuinely interdependent within one file, matching this codebase's own precedent (38-02's single-file interdependent hunks)."

patterns-established: []

requirements-completed: [HUD-05]

# Metrics
duration: ~20min
completed: 2026-07-17
---

# Phase 38 Plan 05: Focus Mode Controller Wiring Summary

**`NotchWindowController` now runs the live Focus/DND pipeline end-to-end: toggle-gated `FocusModeMonitor` lifecycle, a one-line `!head.isPersistent` guard that stops the shared 3s auto-dismiss from firing on a standing Focus head, and `TransientQueue.preempt(_:)` wired into both Charging/Device enqueue sites so either immediately displaces a standing Focus splash (which resumes automatically once they clear).**

## Performance

- **Duration:** ~20 min
- **Started:** 2026-07-17T00:05:00Z (approx, first read)
- **Completed:** 2026-07-17T00:12:00Z
- **Tasks:** 2 (both auto)
- **Files modified:** 2 (both existing)

## Accomplishments
- `focusModeMonitor` property + `startFocusModeMonitor()` added mirroring `startPowerMonitor()`'s exact idempotent-start shape; wired into the launch-time gate (`activityEnabled(focusKey) && FocusModeMonitor.isAuthorized`, D-04 -- launch never itself requests permission), `handleSettingsChanged()`'s toggle-on/off branch, and `deinit`'s owner-driven teardown.
- `handleFocusChange(_:)` enqueues `.focus(activity)` on `true` (plain `enqueue`, Focus never preempts -- D-08 is one-directional) and calls `flushTransients(.focus)` on `false` (D-09 silent removal, reusing the exact same `TransientQueue.removeAll(where:)` the Charging/Device disable path already uses).
- `scheduleActivityDismiss()` gained one guard (`guard let head = transientQueue.head, !head.isPersistent else { return }`) immediately after the existing cancel -- every call site (`presentTransientChange()`, the work item's own advance-then-re-arm branch, `flushTransients(_:)`'s promoted-survivor re-arm) inherits the D-06 non-self-dismiss behavior for free, with zero per-site changes.
- D-08 preemption wired at both places a Charging/Device transient can be newly enqueued: `handlePower(_:)`'s charging-enqueue branch and the `DeviceCoordinator` injection closure's `enqueue:` parameter -- both now check `if case .focus = transientQueue.head` and call `preempt(_:)` instead of `enqueue(_:)` in that case only.
- `TransientCategory` extended with `.focus`; `flushTransients(_:)`'s `matches` switch and per-category model-clearing switch both got a `.focus` arm (`syncActivityModels()`'s own `.focus` arm was already present, added as a compiler-forced fix by Plan 38-02).

## Task Commits

Each task was committed atomically:

1. **Task 1: FocusModeMonitor lifecycle — property, idempotent start/stop, launch gating, deinit** - `e0d708c` (feat)
2. **Task 2: handleFocusChange, D-06 non-self-dismiss guard, D-08 preemption, exhaustiveness** - `0c53b28` (feat)

## Files Created/Modified
- `Islet/Notch/NotchWindowController.swift` — `focusModeMonitor` property, `startFocusModeMonitor()`, launch-time gate line, `handleSettingsChanged()` Focus block, `deinit` teardown line (Task 1); `handleFocusChange(_:)`, `scheduleActivityDismiss()`'s persistence guard, `handlePower(_:)`/`DeviceCoordinator` enqueue-closure D-08 preemption, `TransientCategory.focus` + `flushTransients(_:)` extension (Task 2).
- `Islet.xcodeproj/project.pbxproj` — regenerated via `xcodegen generate` to add `FocusModeMonitor.swift`/`FocusActivity.swift` (Plan 38-03's files, never registered in the project file until now — see Deviations).

## Decisions Made
- Committed Task 1's file-lifecycle code before Task 2's `handleFocusChange(_:)` existed, even though `startFocusModeMonitor()`'s closure references it — Task 1's own grep-based acceptance criteria all pass without a successful build, and the two tasks are inherently interdependent within a single file (same pattern as 38-02's RED/GREEN split). Full `xcodebuild build` verification happened once, after Task 2 landed.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Regenerated `Islet.xcodeproj/project.pbxproj` via `xcodegen generate`**
- **Found during:** Task 2 build verification
- **Issue:** `xcodebuild build` failed with `error: cannot find type 'FocusModeMonitor' in scope` at the Task 1 property declaration. `Islet/Notch/FocusModeMonitor.swift` and `Islet/Notch/FocusActivity.swift` (both added by Plan 38-03/38-02) exist on disk but were never registered in `Islet.xcodeproj/project.pbxproj` — this project uses XcodeGen (`project.yml`, auto-discovers sources by folder glob) and `xcodegen generate` was not re-run/committed after those files were added.
- **Fix:** Ran `xcodegen generate`, which added the two missing file references (4-line diff in `project.pbxproj`). Confirmed no other unrelated changes in the diff.
- **Files modified:** `Islet.xcodeproj/project.pbxproj`
- **Verification:** `xcodebuild build -project Islet.xcodeproj -scheme Islet -configuration Debug` succeeds after regeneration.
- **Committed in:** `0c53b28` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Necessary to unblock this plan's own build verification; the missing project-file registration was a latent gap from Plan 38-03, not introduced by this plan. No scope creep — only the two already-existing Focus files were registered.

## Issues Encountered

The plan's Task 2 acceptance criteria includes `grep -n "case focus"` (literal, no dot) expecting "at least 3 matches (TransientCategory, flushTransients matches switch, syncActivityModels switch)". None of the three actual additions produce that literal substring: `TransientCategory`'s declaration reads `case charging, device, focus` (comma-separated, "focus" isn't preceded by "case "), and both switch arms use dotted case-matching syntax (`case .focus:` / `case (.focus, .focus):`). This appears to be an imprecision in the plan's own acceptance-criteria text — the plan's explicit `<action>` instructions (which I followed verbatim) cannot produce a literal "case focus" match either. All three intended additions are present and verified individually via targeted greps (`case .focus:` for syncActivityModels, `(.focus, .focus)` for the matches switch, `device, focus` for the enum). Not treated as a blocker.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness
- HUD-05's live pipeline is now code-complete: monitor lifecycle, non-self-dismiss, bidirectional preemption at both enqueue sites, and silent off-flush are all wired through the existing `TransientQueue`/`IslandResolver` arbiter with zero scattered priority logic — satisfying ROADMAP Success Criterion #4.
- **Plan 38-06** (Settings UI) can now wire the Focus toggle to `ActivitySettings.focusKey` and `FocusModeMonitor.requestAuthorization(completion:)` at the moment the user flips it on (D-02) — the controller-side gating (`activityEnabled(focusKey) && FocusModeMonitor.isAuthorized`) is already in place in both the launch path and `handleSettingsChanged()`.
- **Plan 38-07** (on-device UAT / spike cleanup) is the first point this plan's 4 must_haves truths (D-04/D-06/D-08/D-09) get real-hardware confirmation — none of it was exercised on-device in this plan, only build-verified.
- The `xcodegen generate` gap fixed here means any FUTURE plan adding a new `.swift` file under `Islet/` should verify `git diff --stat Islet.xcodeproj/project.pbxproj` shows the new file before considering that plan's build verification trustworthy — this is now the second time in Phase 38 a plan's summary needed to record this (38-03 was the first, undetected until this plan).

## Self-Check: PASSED

- FOUND: commit e0d708c
- FOUND: commit 0c53b28
- FOUND: `private var focusModeMonitor: FocusModeMonitor?` in Islet/Notch/NotchWindowController.swift
- FOUND: `private func startFocusModeMonitor()` in Islet/Notch/NotchWindowController.swift
- FOUND: `private func handleFocusChange(_ isFocused: Bool)` in Islet/Notch/NotchWindowController.swift
- FOUND: `!head.isPersistent` guard in `scheduleActivityDismiss()`
- FOUND: `transientQueue.preempt` at 2 sites (handlePower charging branch, DeviceCoordinator enqueue closure)
- Debug build (`xcodebuild build -project Islet.xcodeproj -scheme Islet -configuration Debug`) succeeded after both tasks

---
*Phase: 38-focus-mode-hud*
*Completed: 2026-07-17*
