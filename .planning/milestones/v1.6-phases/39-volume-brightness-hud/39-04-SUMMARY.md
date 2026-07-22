---
phase: 39-volume-brightness-hud
plan: 04
subsystem: ui
tags: [swiftui, notch-panel, osd, volume-hud, brightness-hud]

# Dependency graph
requires:
  - phase: 39-volume-brightness-hud
    provides: "OSDActivity pure value type + osdVolumeActivity/osdBrightnessActivity mapping functions (Plan 39-02)"
provides:
  - "osdWings(for:) collapsed-pill OSD wing view, wired into presentationSwitch's .osd dispatch"
  - "OSDLevelBar — new minimal two-layer Capsule fill-bar private view (not BatteryIndicator)"
affects: [39-05, 39-06, 39-07]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "OSD wing reapplies wingsShape() + focusWings' icon-only-left-flank convention verbatim — no new shape wrapper"
    - "OSDLevelBar reapplies ProgressBar's GeometryReader/Capsule fill technique for a minimal, numberless progress indicator"

key-files:
  created: []
  modified:
    - Islet/Notch/NotchPillView.swift

key-decisions:
  - "osdWings(for:) placed immediately after focusWings(for:) — mirrors that function's structure (single centered icon-only left flank, no label)"
  - "New OSDLevelBar private struct instead of reusing BatteryIndicator — BatteryIndicator's outline/nub/centered percentage text directly conflicts with D-01's no-numeric-text rule"
  - "Wing widths (118/190) taken verbatim from 39-UI-SPEC.md's starting values, flagged for on-device tuning in Plan 39-07 per the plan's own note, mirroring Focus's own live-redesign precedent"

patterns-established: []

requirements-completed: [HUD-03, HUD-04]

# Metrics
duration: ~15min
completed: 2026-07-17
---

# Phase 39 Plan 04: OSD Wing View Summary

**`osdWings(for:)` collapsed-pill Volume/Brightness HUD wing — icon-only left flank + a new minimal two-layer Capsule fill bar on the right, wired into `presentationSwitch`'s `.osd` case.**

## Performance

- **Duration:** ~15 min
- **Completed:** 2026-07-17
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments
- Added `osdWings(for:)` to `NotchPillView.swift`, reapplying `wingsShape(leftWidth: 118, rightWidth: 190)` and the established fixed-color/no-internal-animation wing conventions
- Added a new private `OSDLevelBar` view — a minimal `GeometryReader`/`ZStack`/`Capsule` fill bar (150×5pt) reapplying `ProgressBar`'s existing fill technique, deliberately NOT `BatteryIndicator` (whose chrome includes numeric percentage text, forbidden by D-01)
- Wired `case .osd(let activity): osdWings(for: activity)` into `presentationSwitch`, replacing the Plan 39-02 compiler-forced `EmptyView()` stub
- Icon swap (`speaker.wave.3.fill` / `speaker.slash.fill`) and bar-drain-to-0 both driven by the single `OSDActivity.isMuted` computed property (D-03) — no independent mute check
- Brightness always renders `sun.max.fill` with no muted-equivalent state
- Both icon and bar use fixed colors (white icon; `Color.green` volume bar, `Color.orange` brightness bar) — never accent-tinted (D-02)

## Task Commits

1. **Task 1: osdWings(for:) — icon-left wing + minimal fill-bar right wing** - `0bb9426` (feat)

**Plan metadata:** committed separately per worktree protocol (SUMMARY.md + REQUIREMENTS.md only; STATE.md/ROADMAP.md owned by orchestrator)

## Files Created/Modified
- `Islet/Notch/NotchPillView.swift` - Added `osdWings(for:)`, `OSDLevelBar` private struct, and the `.osd` dispatch case in `presentationSwitch`

## Decisions Made
- Used `Color.green`/`Color.orange` (explicit `Color.` prefix) rather than the `.green`/`.orange` shorthand, matching the acceptance criteria's grep check and the file's existing convention (e.g. `wings(for:)`'s `Color.green` charging accent) for a fixed, non-accent-tinted color that's unambiguously distinct from `deviceAccent`/`chargingAccent`
- `fraction` computed as `activity.isMuted ? 0.0 : CGFloat(percent) / 100.0` — reads `isMuted` once and reuses it for both the icon swap and the bar drain, satisfying D-03's "same computed property" requirement structurally (not just by convention)

## Deviations from Plan

None - plan executed exactly as written. One minor self-correction during execution: the first draft used Swift's `.green`/`.orange` color-literal shorthand inside `osdWings`, which passed the build but failed the plan's own `grep -n "Color.green\|Color.orange"` acceptance criterion (that check requires the explicit `Color.` prefix to be present in the file, and the shorthand doesn't produce that substring). Corrected to `Color.green`/`Color.orange` before committing — this is not a deviation from what the plan asked for, just fixing a literal-form mismatch against the acceptance grep during the same task, before any commit was made.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- `osdWings(for:)` is reachable from `presentationSwitch` the moment `IslandPresentation.osd(_)` resolves — Plan 39-05 (controller-side wiring: `VolumeReader`/`BrightnessReader` system glue, resolver dispatch, spring-wrapped mutations) can now proceed against a real view target instead of the `EmptyView()` stub
- 118/190 wing widths and the 150×5pt bar are placeholder-tuned per `39-UI-SPEC.md`'s starting values only — flagged for on-device retuning in Plan 39-07's consolidated UAT checkpoint, not verified visually here (build-only verification per this plan's own `<verification>` scope)
- No blockers

---
*Phase: 39-volume-brightness-hud*
*Completed: 2026-07-17*

## Self-Check: PASSED
