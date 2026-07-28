---
phase: quick-260729-0zh
plan: 01
subsystem: ui
tags: [swiftui, debug-tooling, notch, wing-tuner, click-through-hit-test]

# Dependency graph
requires:
  - phase: quick-260729-0b5
    provides: Wing Tuner Margin nudge key (debugWingMarginNudgeKey), Preview Wing debug submenu
provides:
  - Meeting wing's Margin nudge now has a real, click-through-safe effect
  - Non-persistent Preview actions stay visible until Reset Wing Tuner instead of auto-dismissing
affects: [wing-tuner, debug-menu]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "static var computed from a shared UserDefaults-backed nudge key (not a stored static let), so a single value feeds both a wing's render and NotchWindowController's click-through hit-test zone without desyncing"

key-files:
  created: []
  modified:
    - Islet/Notch/NotchPillView.swift
    - Islet/Notch/NotchWindowController.swift
    - Islet/AppDelegate.swift

key-decisions:
  - "meetingWingMargin converted from static let to a DEBUG-aware computed static var reusing the existing debugWingMarginNudgeKey — Release #else branch returns the byte-identical original literal 20"
  - "debugCancelPendingDismiss()/debugClearAllPreviews() are #if DEBUG-gated in their entirety (not just access-level widened) since they change real production dismiss/queue state"
  - "debugWingTunerReset() marked @MainActor (Rule 3 fix) — required once it started calling the MainActor-isolated NotchWindowController"

patterns-established: []

requirements-completed: []

# Metrics
duration: ~15min
completed: 2026-07-29
---

# Quick Task 260729-0zh: Wing Tuner Round 3 Summary

**Meeting wing's Margin nudge now moves the mute-icon area (was a documented no-op) via a shared DEBUG-aware computed property; 7 non-persistent Preview actions now stay visible until "Reset Wing Tuner" instead of auto-dismissing after ~1.5-3s.**

## Performance

- **Duration:** ~15 min
- **Tasks:** 2/2 (Task 3 is an on-device checkpoint, not executed by this agent)
- **Files modified:** 3

## Accomplishments

- `meetingWingMargin` is now a `static var` computed from `20 + debugWingMarginNudgeKey`'s stored delta in DEBUG, and the plain literal `20` in Release — the exact same value now feeds both `meetingWings(for:)`'s render and `NotchWindowController.collapsedInteractiveZone()`'s click-through widen, so the fix can never desync render from hit-test.
- 7 non-persistent "Preview: X" debug actions (Charging, Device, Caps Lock, OSD Volume, OSD Brightness, Update, Countdown) now call a new `debugCancelPendingDismiss()` right after triggering, cancelling the auto-dismiss timer `scheduleActivityDismiss()` just armed.
- `debugWingTunerReset()` now also calls a new `debugClearAllPreviews()`, force-clearing whatever wing is currently previewed back to idle, in addition to its existing 4 nudge-value resets.

## Task Commits

Each task was committed atomically:

1. **Task 1: Fix Meeting wing's Margin nudge without desyncing the click-through zone** - `f7f6026` (fix)
2. **Task 2: Keep previewed non-persistent wings visible until Reset** - `5fa2dd5` (feat)

_Task 3 (`checkpoint:human-verify`, gate=blocking) requires the actual user on real hardware — not executed by this agent, reported as pending below._

## Files Created/Modified

- `Islet/Notch/NotchPillView.swift` - `meetingWingMargin` converted from `static let` to a DEBUG-aware computed `static var`
- `Islet/Notch/NotchWindowController.swift` - added `#if DEBUG`-gated `debugCancelPendingDismiss()` and `debugClearAllPreviews()`
- `Islet/AppDelegate.swift` - 7 Preview actions call the new cancel function; `debugWingTunerReset()` calls the new clear-all function and is now `@MainActor`

## Decisions Made

- Followed the plan's exact computed-property approach for `meetingWingMargin` — no architectural deviation, single shared source preserved per the plan's stated invariant.
- Marked `debugWingTunerReset()` `@MainActor` (see Deviations below) rather than dispatching asynchronously, matching this file's existing convention where every function calling `notchController` (a `@MainActor`-isolated class) is itself `@MainActor`-annotated.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added `@MainActor` to `debugWingTunerReset()`**
- **Found during:** Task 2 (Debug build after wiring `debugClearAllPreviews()` into `debugWingTunerReset()`)
- **Issue:** `NotchWindowController` is a `@MainActor`-isolated class. `debugWingTunerReset()` was a plain (non-`MainActor`) `@objc private func`, so the new call to `notchController?.debugClearAllPreviews()` failed to compile: "call to main actor-isolated instance method ... in a synchronous nonisolated context."
- **Fix:** Added `@MainActor` to `debugWingTunerReset()`'s declaration, matching the existing convention already used by every other `AppDelegate` function that calls into `notchController` (all 12 Preview actions that touch `notchController` are `@MainActor @objc private func`).
- **Files modified:** `Islet/AppDelegate.swift`
- **Verification:** Debug and Release builds both succeeded after the fix.
- **Committed in:** `5fa2dd5` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Necessary compile fix, zero behavior change beyond what the plan specified. No scope creep.

## Issues Encountered

None beyond the deviation above.

## User Setup Required

None - no external service configuration required.

## Checkpoint Pending

**Task 3 (`checkpoint:human-verify`, gate=blocking) was NOT executed by this agent** — it requires the user to run the app on real hardware (Cmd-R, Debug scheme) and manually verify:
1. Meeting wing Margin nudge visibly shifts the mute-icon area, live, both directions.
2. Mute icon remains clickable at every nudge value (no click-through regression) — this is the actual regression risk the fix must not introduce.
3. All 7 non-persistent Preview actions stay visible past their old ~1.5-3s auto-dismiss point.
4. "Reset Wing Tuner" clears the current preview AND zeroes the 4 nudge values.
5. A REAL (non-preview) transient (e.g. actually plugging in the charger) still auto-dismisses normally, unaffected by this change.

Full verification steps are in `260729-0zh-PLAN.md`'s Task 3 `<how-to-verify>` block. Resume signal: "approved" or a description of any issue found.

## Next Phase Readiness

- Both `auto` tasks complete and committed; Debug and Release builds both green.
- Awaiting on-device UAT round before this quick task can be considered fully closed.

---
*Phase: quick-260729-0zh*
*Completed: 2026-07-29 (Tasks 1-2; checkpoint pending)*
