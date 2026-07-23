---
phase: 60-caps-lock-hud-update-activity-restyle
plan: 04
subsystem: ui
tags: [swift, swiftui, wings, caps-lock, sparkle-update]

# Dependency graph
requires:
  - phase: 60-caps-lock-hud-update-activity-restyle
    plan: "60-01"
    provides: "CapsLockActivity (.on/.off), UpdateActivity (version: String), IslandPresentation .capsLock/.updateAvailable cases"
provides:
  - "wingsShape(onTap:) — optional per-wing tap override, first non-nil use in the codebase"
  - "capsLockWings(for:) / updateWings(for:) — real wing rendering for both new HUDs"
  - "UpdateVersionPill — standalone compact version-pill view"
  - "NotchPillView.onUpdateTap closure property"
affects: [60-05]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "wingsShape's onTap override is the mechanism any future wing needing a non-universal tap action should reuse (mirrors onClick's declaration style)"

key-files:
  created: []
  modified:
    - Islet/Notch/NotchPillView.swift

key-decisions:
  - "Caps Lock wing conveys state via text alone ('Caps Lock On'/'Caps Lock Off'), no status dot — per UI-SPEC's explicit unrequested-scope warning (D-03)"
  - "UpdateVersionPill built as its own small standalone view, not a BatteryIndicator parameterization — no level/fill-bar concept applies to a version string"

requirements-completed: []

# Metrics
duration: 12min
completed: 2026-07-23
---

# Phase 60 Plan 04: Caps Lock / Update Wing Rendering Summary

**Both new HUDs now render through the codebase's single shared `wingsShape` template, which gains its first-ever optional per-wing tap override so the Update wing can trigger Sparkle's install flow instead of the universal expand-to-Home.**

## Performance

- **Duration:** 12 min
- **Started:** 2026-07-23T20:01:33+02:00 (previous plan's completion commit)
- **Completed:** 2026-07-23T20:04:29+02:00
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments
- `wingsShape` gained a purely-additive `onTap: (() -> Void)? = nil` parameter — every pre-existing call site (`wings(for:)`, `deviceWings(for:)`, `focusWings(for:)`, `osdWings(for:)`, `countdownWings(for:)`) compiles unchanged, confirmed by a clean Debug build with zero call-site edits required
- `capsLockWings(for:)` renders `capslock.fill` (white, fixed) + `"Caps Lock On"`/`"Caps Lock Off"` text — both icon and label always visible in both states, no status dot (D-03)
- `updateWings(for:)` renders `arrow.triangle.2.circlepath` + `"Update"` label on the left and a new `UpdateVersionPill` (`"v<version>"`) on the right, and is the one wing call site in the codebase passing a non-nil `onTap` override (`onUpdateTap`) instead of the universal `onClick()`
- `presentationSwitch`'s exhaustive switch now handles `.capsLock`/`.updateAvailable` with real views, replacing Plan 60-01's placeholder `EmptyView()`

## Task Commits

Each task was committed atomically:

1. **Task 1: wingsShape gains an optional per-wing tap override** - `3149c0e` (feat)
2. **Task 2: capsLockWings/updateWings/UpdateVersionPill + presentationSwitch wiring** - `ddbba8b` (feat)

## Files Created/Modified
- `Islet/Notch/NotchPillView.swift` — `wingsShape`'s new `onTap` param; `onUpdateTap` closure property (near `onClick`); `capsLockWings(for:)` and `updateWings(for:)` functions (placed after `osdWings(for:)`); `UpdateVersionPill` struct (placed after `OSDLevelBar`); `presentationSwitch`'s `.capsLock`/`.updateAvailable` arms rewired from `EmptyView()` to the new functions

## Decisions Made
- None beyond the plan's own locked interfaces/UI-SPEC — plan executed exactly as written, no deviations.

## Deviations from Plan

None - plan executed exactly as written. Both tasks' acceptance-criteria greps (`onTap: (() -> Void)? = nil`, `.onTapGesture { (onTap ?? onClick)() }`, `func capsLockWings`, `func updateWings`, `struct UpdateVersionPill`, both `presentationSwitch` case arms) all match; Debug build green after each task.

## Issues Encountered

None.

## Threat Flags

None — this plan renders wing UI against the existing `wingsShape`/tap-gesture pattern; no new network endpoints, auth paths, file access, or schema changes introduced. T-60-11 (from the plan's own threat model) is explicitly deferred to Plan 60-05's on-device checkpoint (click-through verification cannot be asserted via XCTest, per this codebase's established precedent).

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Both HUDs are now visually complete and wired into `presentationSwitch`. Plan 60-05's on-device checkpoint must verify: (1) repeated taps across the Update wing's full rendered area reliably trigger `onUpdateTap` with zero click-through (T-60-11), and (2) both wings visually match 60-UI-SPEC.md's locked dimensions/copy/colors on real notched hardware.
- `onUpdateTap` currently defaults to a no-op — a later plan (or Plan 60-05 itself, if in scope) must wire it to the real Sparkle install-flow call at the controller layer; this plan only built the view-layer contract per its own explicit scope ("the visual/interaction half of both requirements").

---
*Phase: 60-caps-lock-hud-update-activity-restyle*
*Completed: 2026-07-23*

## Self-Check: PASSED

`Islet/Notch/NotchPillView.swift` and this SUMMARY.md confirmed present on disk; both task commit hashes (3149c0e, ddbba8b) confirmed in git log.
