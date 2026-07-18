---
phase: 36-cosmetic-restyles-signature-animation
plan: 2
subsystem: notch-pill-view
tags: [swiftui, equalizer, animation, skiper-ui, attribution]
requires: []
provides:
  - "EqualizerBars (EQ-01): 5 bars, 1pt wide, 4pt gap, fixed white, targetHeight(bar:bucket:)-driven reroll-and-spring motion replacing the old per-bar sine wave"
  - "Skiper UI attribution row in Settings > About (Registry Safety requirement)"
affects:
  - Islet/Notch/NotchPillView.swift
  - Islet/SettingsView.swift
tech-stack:
  added: []
  patterns:
    - "targetHeight(bar:bucket:) — Hasher-derived deterministic pseudo-random height per (bar, bucket) pair, combined with TimelineView(.animation(paused:)) bucket = Int(t / 0.1) for a ~100ms reroll-and-spring motion inside the pre-existing idle-CPU gate (D-08)"
key-files:
  created: []
  modified:
    - Islet/Notch/NotchPillView.swift
    - IsletTests/EqualizerBarsTests.swift
    - Islet/SettingsView.swift
decisions:
  - "abs(hasher.finalize()) required (not just % 1000) — Hasher.finalize() returns a signed Int and Swift's % preserves the dividend's sign, so an unguarded negative hash would map below the 4...14 floor."
requirements-completed: [EQ-01]
metrics:
  duration: "2 sessions (Tasks 1-2 auto; Task 3 on-device checkpoint approved in follow-up session)"
  completed: "2026-07-16"
---

# Phase 36 Plan 2: Equalizer Bars Motion/Geometry Redesign + Skiper UI Attribution Summary

Rewrote `EqualizerBars` from a continuous per-bar sine wave to a Skiper25-style reroll-and-spring motion (`targetHeight(bar:bucket:)`, ~100ms bucket cadence), thinned/de-accented the bars to the locked visual spec, and added the mandatory Skiper UI attribution line to Settings > About.

## Performance

- **Tasks:** 3 (2 auto + 1 checkpoint:human-verify)
- **Files modified:** 3 (`NotchPillView.swift`, `EqualizerBarsTests.swift`, `SettingsView.swift`)

## Accomplishments
- `EqualizerBars` renders 5 bars, 1pt wide, 4pt apart, fixed solid white (no more `nowPlayingAccent` tint) — both call sites updated to drop the `tint:` argument.
- Motion replaced: `makeProfiles()`/`height(_:at:)` (per-bar low/high/period/phase sine model) removed entirely; new `static func targetHeight(bar:bucket:)` combines `bar`/`bucket` via `Hasher`, guards the signed-Int `%` sign-preservation trap with `abs(hasher.finalize())`, and maps into `4...14`. A per-bar `.animation(.spring(response: 0.25, dampingFraction: 0.7), value: bucket)` makes all 5 bars spring-jump to new heights simultaneously roughly every 100ms while playing.
- The pre-existing `TimelineView(.animation(paused: !isPlaying))` idle-CPU gate (D-08) is untouched — paused bars sit at a fixed flat 4pt with zero running clock.
- Settings > About gained a `Section("Credits")` with the exact locked string: "Equalizer bar animation inspired by Skiper UI (skiper25.com)".
- On-device UAT (Task 3) confirmed thin/white/snappy bar motion, correct pause behavior, and the visible Credits attribution — user replied "approved".

## Task Commits

Each task was committed atomically:

1. **Task 1: Rewrite EqualizerBars motion + geometry** - `978d464` (feat)
2. **Task 2: Skiper UI attribution row in Settings** - `c07c677` (feat)
3. **Task 3: On-device UAT checkpoint** - state transition only, no code changes; user approved on-device in a follow-up session.

## Files Created/Modified
- `Islet/Notch/NotchPillView.swift` - `EqualizerBars` rewritten to `targetHeight(bar:bucket:)` reroll-and-spring motion; both call sites drop `tint:`
- `IsletTests/EqualizerBarsTests.swift` - Tests rewritten against `targetHeight(bar:bucket:)` (range `4...14` + determinism), replacing the old `makeProfiles()` tests
- `Islet/SettingsView.swift` - New `Section("Credits")` in `aboutSection` with the locked Skiper UI attribution string

## Decisions Made
- `abs(hasher.finalize())` is required, not optional, before the `% 1000` reduction — `Hasher.finalize()` returns a signed `Int` and Swift's `%` operator preserves the dividend's sign, so a negative hash would otherwise produce a negative remainder and map below the `4...14` floor. (Caught and fixed in-plan before Task 1's commit, per the plan's own explicit acceptance criterion grep.)

## Deviations from Plan

None - plan executed exactly as written. (The plan's own PLAN.md was revised once, before execution, to correct the Hasher sign-preservation formula — that revision is reflected in the action text Task 1 was executed against, not a runtime deviation.)

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- EQ-01 complete; both call sites and tests confirmed via `xcodebuild build -scheme Islet -destination 'platform=macOS'` (BUILD SUCCEEDED, re-confirmed at plan close).
- Phase 36 wave 2 (this plan) is now complete; wave 3 (36-04, signature stroke-reveal animation) can proceed — it depends on 36-03 (already complete), not on this plan.

## Self-Check: PASSED

- `Islet/Notch/NotchPillView.swift` - FOUND
- `IsletTests/EqualizerBarsTests.swift` - FOUND
- `Islet/SettingsView.swift` - FOUND
- Commit `978d464` - FOUND (`git log --oneline` confirmed)
- Commit `c07c677` - FOUND (`git log --oneline` confirmed)
- `xcodebuild build -scheme Islet -destination 'platform=macOS'` - BUILD SUCCEEDED (final re-run before this summary)

---
*Phase: 36-cosmetic-restyles-signature-animation*
*Completed: 2026-07-16*
