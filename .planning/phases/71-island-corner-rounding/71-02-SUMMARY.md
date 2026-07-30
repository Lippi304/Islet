---
phase: 71-island-corner-rounding
plan: 02
subsystem: ui
tags: [swiftui, notchshape, corner-radius, wing-tuner, debug-menu]

# Dependency graph
requires:
  - phase: 71-01
    provides: "wingBaseTopCornerRadius (16) / wingBaseBottomCornerRadius (8) named constants, the attachment point for this plan's nudge axis"
provides:
  - "5th DEBUG-only Wing Tuner axis (Corner Radius, ±1/±5 steps) mirroring the existing Leading/Trailing/Margin/Gap mechanism exactly"
  - "wingCornerRadiusNudge computed property, clamped so topCornerRadius+bottomCornerRadius can never reach/exceed the wing's depth-scaled height (self-intersection hardening)"
  - "clipShape(shape) added to wingsShape()'s three content overlays (mediaWingsOrToast()/resumePreviewWings() included), closing a rounder-corner content-bleed gap SHAPE-02 exposed"
affects: [future-wing-tuner-axes, anyone-touching-debug-wingTuner-userdefaults]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "New Wing Tuner axes: 1 AppStorage key (ActivitySettings) + 1 always-compiled #if DEBUG read point (NotchPillView) + 4 NSMenuItems/@objc actions + Reset/Print wiring (AppDelegate) — this plan is the 2nd time this pattern was mechanically repeated, now proven twice"
    - "Corner-radius nudge is clamped at the read-point property, not at the UserDefaults write site — keeps the dev tool unclamped/inspectable in UserDefaults while guaranteeing the rendered shape can never self-intersect"

key-files:
  created: []
  modified:
    - Islet/ActivitySettings.swift
    - Islet/Notch/NotchPillView.swift
    - Islet/AppDelegate.swift
    - IsletTests/ActivitySettingsTests.swift

key-decisions:
  - "Corner-radius clamp implemented as a durable structural guard inside wingCornerRadiusNudge (not a one-time value reset) — protects against any future nudging, not just the specific stale value that caused this session's freeze"
  - "clipShape(shape) added to wingsShape()/mediaWingsOrToast()/resumePreviewWings() content overlays, mirroring blobShape's existing pattern — closes a real visual bleed gap that 71-01's 16/8 radius bump exposed but 71-01 itself didn't touch (D-03/D-04 scope of this plan, not 71-01's)"
  - "Wing Tuner leading/trailing base constants permanently bumped (+6/+10) per live on-device tuning during this plan's UAT; the margin delta was tried (-20) then explicitly reverted back to original per user request — only leading/trailing deltas are baked in"

patterns-established:
  - "Any DEBUG-only Wing Tuner axis must be Reset before ending a tuning session — stale non-zero UserDefaults values silently combine with future source-level base-constant changes and can produce a self-intersecting NotchShape path, which froze the app's render/animation pipeline twice during this plan's own UAT (see Deviations)"

requirements-completed: [SHAPE-03]

# Metrics
duration: multi-session (UAT required 2 freeze-diagnosis rounds)
completed: 2026-07-30
---

# Phase 71 Plan 02: Corner Radius Wing Tuner Axis Summary

**Added a 5th DEBUG-only Wing Tuner axis (Corner Radius, ±1/±5) that live-nudges `wingsShape()`'s top/bottom radii together, on-device approved after closing a content-clipping gap, baking in live-tuned leading/trailing deltas, and hardening the new axis against a self-intersecting-path app freeze discovered twice during UAT.**

## Performance

- **Duration:** multi-session (UAT required 2 freeze-diagnosis rounds before final approval)
- **Completed:** 2026-07-30
- **Tasks:** 3/3 completed (Task 3 was an on-device UAT checkpoint, not a code task)
- **Files modified:** 4 (ActivitySettings.swift, NotchPillView.swift, AppDelegate.swift, ActivitySettingsTests.swift)

## Accomplishments
- `ActivitySettings.debugWingCornerRadiusNudgeKey` added alongside the existing 4 Wing Tuner keys, DEBUG-gated, matching the `debug.wingTuner.<axis>Nudge` naming convention
- `wingCornerRadiusNudge` read point in `NotchPillView.swift` nudges both `wingsShape()` radii by the same delta at render time (D-03: one combined axis, not independent top/bottom)
- 4 new `NSMenuItem`s (Corner Radius -5/-1/+1/+5) + 4 `@objc` actions + updated `debugWingTunerReset()`/`debugWingTunerPrint()` in `AppDelegate.swift`, all routed through the existing shared `adjustWingNudge(_:by:)` helper — no new helper needed
- `testWingCornerRadiusNudgeKeyName` added to `ActivitySettingsTests.swift`, passing
- On-device UAT (Task 3) approved by the user ("ja passt alles wieder") after two real bugs surfaced and were fixed during the walkthrough — see Deviations below for full detail
- Release build confirmed clean (new axis fully `#if DEBUG`-excluded, same proof already used for the existing 4 axes)

## Task Commits

Each task was committed atomically, plus 4 additional commits generated during Task 3's on-device UAT (all in scope — fixing gaps/bugs this plan's own changes exposed):

1. **Task 1: New @AppStorage key + read point, wire nudge into wingsShape() (D-03/D-04)** - `bd977d1` (feat)
2. **Task 2: AppDelegate menu items, actions, Reset/Print wiring (D-04/D-05)** - `d2185c7` (feat)
3. **UAT gap-closure: clip wing content to NotchShape silhouette** - `8b74f49` (fix)
4. **UAT live-tune bake-in: leading/trailing/margin deltas across all wings** - `b0aea34` (tune)
5. **UAT freeze-fix: clamp corner-radius nudge to prevent self-intersecting NotchShape** - `c732446` (fix)
6. **UAT revert: restore original margin values per user request** - `470015a` (revert)
7. **Task 3: On-device UAT** - no code, approved via resume-signal ("ja passt alles wieder")

**Plan metadata:** this commit (docs: complete plan)

## Files Created/Modified
- `Islet/ActivitySettings.swift` - Added `debugWingCornerRadiusNudgeKey` constant (DEBUG-gated)
- `Islet/Notch/NotchPillView.swift` - Added `debugWingCornerRadiusNudge` @AppStorage + `wingCornerRadiusNudge` read point (with self-intersection clamp), wired into `wingsShape()`; added `.clipShape(shape)` to `wingsShape()`/`mediaWingsOrToast()`/`resumePreviewWings()` content overlays; baked-in leading (+6) and trailing (+10) deltas across all wing base constants
- `Islet/AppDelegate.swift` - 4 new menu items + 4 new `@objc` actions + updated `debugWingTunerReset()`/`debugWingTunerPrint()`
- `IsletTests/ActivitySettingsTests.swift` - Added `testWingCornerRadiusNudgeKeyName`

## Decisions Made
- Corner-radius clamp implemented as a durable structural guard in `wingCornerRadiusNudge` itself (bounds `topCornerRadius+bottomCornerRadius` below the wing's actual depth-scaled height) rather than a one-time reset of the bad value — protects against any future nudge combination, not just this session's specific 26+18=44pt-against-32pt-tall-strip failure
- Leading (+6) and trailing (+10) base-constant deltas from live Wing Tuner tuning were baked into all wings permanently; the margin (-20) delta was baked in then explicitly reverted back to the original per-wing values at the user's request — only leading/trailing changed net
- No independent top/bottom corner-radius axes — one combined nudge per D-03, preserving whatever base 16/8 ratio Plan 71-01 established
- `mediaWingsOrToast()`/`resumePreviewWings()` do not get their own tuner axis (D-06) — but DO now get the same `clipShape(shape)` content-clipping fix as `wingsShape()`, since the clipping gap affected all three call sites equally

## Deviations from Plan

Task 3's on-device UAT was not a clean single-pass approval. It surfaced real gaps and bugs — all within this plan's own scope (SHAPE-02's radius bump + this plan's new tuner axis) — requiring 4 additional commits beyond the 2 planned tasks.

### Auto-fixed Issues

**1. [Rule 1 - Bug] Wing content painted through the silhouette on the concave top corners**
- **Found during:** Task 3 UAT, step 2 (visual rounding check)
- **Issue:** SHAPE-02's 16/8 corner-radius bump (Plan 71-01) grew the concave top-corner cutout on `wingsShape()`/`mediaWingsOrToast()`/`resumePreviewWings()` enough that album art / wing icons painted past the silhouette onto the desktop — none of the three had a `.clipShape` (unlike `blobShape`, which already had one).
- **Fix:** Added `.clipShape(shape)` to all three wing content overlays, mirroring `blobShape`'s existing pattern.
- **Files modified:** `Islet/Notch/NotchPillView.swift`
- **Verification:** On-device visual re-check confirmed content now stops exactly at the silhouette.
- **Committed in:** `8b74f49`

**2. [Rule 1 - Bug, CRITICAL] Stale persisted nudge + new clamp-less corner radius froze the app**
- **Found during:** Task 3 UAT, step 5 (live-tuning the new Corner Radius axis)
- **Issue:** A stale, never-reset `debug.wingTuner.cornerRadiusNudge=10` from a prior tuning session combined with the new 16/8 base radii produced `topCornerRadius=26, bottomCornerRadius=18` — summing to 44pt against a 32pt-tall wing strip, a self-intersecting path. Once fix #1's `clipShape` started applying that broken path as a content mask, the app's render/animation pipeline froze completely (no click response).
- **Fix:** Clamped `wingCornerRadiusNudge` in `wingsShape()` so `topCornerRadius+bottomCornerRadius` can never reach/exceed the wing's actual depth-scaled height, regardless of future nudging — a durable structural fix, not a one-time value reset.
- **Files modified:** `Islet/Notch/NotchPillView.swift`
- **Verification:** Re-tested the same stale-value scenario on-device; no freeze, corners clamp visibly instead.
- **Committed in:** `c732446`

**3. [Rule 3 - Blocking] Second freeze from a stale margin nudge stacked on reverted base margins**
- **Found during:** Task 3 UAT, after commit #4 (margin revert)
- **Issue:** A stale persisted `debug.wingTuner.marginNudge=20` (never reset after earlier live-testing) stacked on top of the just-reverted-to-original base margin, pushing the OSD wing's footprint past its own hard-coded `assert(... < 325pt)` safe-panel-frame budget in `NotchPillView.swift`, tripping the debugger.
- **Fix:** Reset the stale UserDefaults nudge directly (no source change needed) — confirmed via `defaults read com.lippi304.islet` and `log show --predicate 'process == "Islet"'` showing the exact assertion-failure line.
- **Files modified:** none (UserDefaults reset only)
- **Verification:** App relaunched cleanly, no assertion trip, user confirmed "ja passt alles wieder".
- **Committed in:** n/a (no source change; state reset only)

### Live-tuning bake-in (not a bug fix, a design decision made mid-UAT)

**4. Baked in Wing Tuner leading/trailing deltas across all wings**
- **Found during:** Task 3 UAT
- **Change:** User live-tuned leading (+6) and trailing (+10) via the existing tuner and asked to bake these into all wings' base `leadingPad`/`trailingPad` constants permanently (this plan's own axis is corner-radius; leading/trailing were an incidental improvement surfaced during the same session). A margin delta (-20) was also tried and baked in, then explicitly reverted back to the original per-wing values at the user's request in a follow-up commit.
- **Files modified:** `Islet/Notch/NotchPillView.swift`
- **Committed in:** `b0aea34` (bake-in), `470015a` (margin revert)

---

**Total deviations:** 3 auto-fixed (2x Rule 1 bug, 1x Rule 3 blocking) + 1 mid-UAT design bake-in (user-directed, not a deviation rule).
**Impact on plan:** All fixes were necessary for correctness (content clipping, freeze prevention) or were explicit user-directed refinements surfaced by the live-tuning workflow this plan's own tuner axis enables. No scope creep beyond wing-state HUD rendering.

## Known Footgun (flag for future sessions)

Both freezes (deviations #2 and #3) were caused by the **same class of bug**: a live-tuned `debug.wingTuner.*` UserDefaults value left persisted (never reset via "Reset Wing Tuner") stacking on top of a source-level base-constant change made in a later session. This is a project memory (`wingtuner_stale_nudge_freeze.md`) — anyone adding a 6th Wing Tuner axis, or changing any wing base constant, should click "Reset Wing Tuner" before ending their tuning session, and should be aware that stale nudges can combine with future base-constant edits in ways that produce invalid (self-intersecting) shapes. The corner-radius axis is now clamp-protected against this; the other 4 axes are not (matches T-71-04's accepted threat disposition — no clamp on the other axes, by established project precedent).

## Issues Encountered

None beyond the UAT-loop deviations documented above. Full `xcodebuild test` re-run (post-fix, IsletTests/NotchShapeTests + IsletTests/ActivitySettingsTests, 28 tests) passed clean after a `xcodebuild clean` resolved a one-off transient codesign failure on the first attempt (known local Xcode/DerivedData flake, not a code issue — resolved by clean rebuild). Release build confirmed clean.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Phase 71 (Island Corner Rounding) is now fully complete — both SHAPE-02 (Plan 71-01, visual rounding) and SHAPE-03 (this plan, DEBUG tuner axis) are on-device verified. No blockers for Phase 72 (Calendar Redesign), the next phase in the v1.11 milestone's stated order.

---
*Phase: 71-island-corner-rounding*
*Completed: 2026-07-30*

## Self-Check: PASSED

All 4 modified files (`Islet/ActivitySettings.swift`, `Islet/Notch/NotchPillView.swift`, `Islet/AppDelegate.swift`, `IsletTests/ActivitySettingsTests.swift`) confirmed present. All 6 task/UAT commits (`bd977d1`, `d2185c7`, `8b74f49`, `b0aea34`, `c732446`, `470015a`) confirmed present via `git log --oneline --all`. Fresh re-run of `xcodebuild test -only-testing:IsletTests/NotchShapeTests -only-testing:IsletTests/ActivitySettingsTests` (28 tests, 0 failures) and `xcodebuild build -configuration Release` both passed clean.
