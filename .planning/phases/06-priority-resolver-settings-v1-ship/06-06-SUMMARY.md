---
phase: 06-priority-resolver-settings-v1-ship
plan: 06
subsystem: ui
tags: [swiftui, matchedGeometryEffect, animation, nspanel, accent-theming]

# Dependency graph
requires:
  - phase: 06-priority-resolver-settings-v1-ship
    provides: "06-04 (resolver/queue/device monitor/toggles/accent wiring), 06-05 (v1 ship gate), 06-UAT.md gap findings"
provides:
  - "Charging-splash yield-back to Now-Playing wings is a smooth, single-transaction matchedGeometryEffect morph (no un-animated model-clear snap before the animated presentation switch)"
  - "positionAndShow() no longer forces an unconditional panel redisplay when the frame is unchanged (secondary compounding factor addressed defensively)"
  - "Charging wings' BatteryIndicator forwards the persisted accent, matching the equalizer bars' existing tint"
  - "Charging-cue bolt icon renders green while charging (post-checkpoint visibility fix), dim white while not"
affects: [07-release-polish, future-UAT-passes]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "@Published model mutations that feed a matchedGeometryEffect-driven transition must commit inside the SAME withAnimation(.spring) block as the presentation switch — an un-animated commit immediately before an animated one breaks SwiftUI's frame interpolation"
    - "Guard AppKit-level forced redisplay calls (panel.setFrame(_, display: true)) with an equality check so a no-op reposition doesn't compound an in-flight SwiftUI animation"

key-files:
  created: []
  modified:
    - Islet/Notch/NotchWindowController.swift
    - Islet/Notch/NotchPillView.swift

key-decisions:
  - "syncActivityModels() moved inside withAnimation(.spring) in scheduleActivityDismiss(), immediately before renderPresentation(); transientQueue.advance() stays outside it (pure value mutation, no SwiftUI publish, doesn't need animating)"
  - "positionAndShow()'s panel.setFrame(panelFrame, display: true) now guarded by `if panel.frame != panelFrame` — CGRect is Equatable, no new lookup introduced"
  - "Charging wings' BatteryIndicator(level: percent, accent: accent) forwards the environment accent; device wings' BatteryIndicator(level: battery) deliberately left untouched (user-confirmed, explicit scope exclusion)"
  - "Fullscreen-enter flash (UAT Test 5) explicitly NOT touched — confirmed the same pre-existing Phase-2 window-server compositing limitation, carried forward as accepted, not a Phase-6 regression"
  - "Post-checkpoint deviation: charging bolt icon color changed from Color.yellow to Color.green while charging (user feedback during on-device verify: yellow was too washed out); not-charging dim state unchanged"

patterns-established:
  - "Animate-together rule: any model clear that a matchedGeometryEffect transition depends on must be co-located inside the animating withAnimation block, not sequenced immediately before it"

requirements-completed: [COORD-01, APP-03]

# Metrics
duration: 20min
completed: 2026-07-01
---

# Phase 6 Plan 6: Gap Closure — Charging-Yield Morph + Battery Accent Summary

**Fixed a matchedGeometryEffect-breaking un-animated model commit in the charging-splash yield-back and forwarded the missing accent argument to the charging BatteryIndicator; on-device human-verify confirmed both, plus a live-requested bolt-icon color tweak (yellow → green).**

## Performance

- **Duration:** ~20 min (Tasks 1-2 execution + checkpoint wait + post-approval deviation)
- **Started:** 2026-07-01T12:56:00+02:00
- **Completed:** 2026-07-01T15:04:14+02:00
- **Tasks:** 3 (2 automated + 1 human-verify checkpoint), plus 1 post-checkpoint deviation
- **Files modified:** 2 (`NotchWindowController.swift`, `NotchPillView.swift`)

## Accomplishments

- Closed UAT Gap 1 (Test 1, minor): charging-splash yield-back to the Now-Playing wings is now a smooth, single-transaction width morph — no un-animated snap followed by symbols popping in.
- Closed UAT Gap 2 (Test 4, major): the charging battery indicator now tints with the persisted accent, matching the equalizer bars.
- Confirmed on-device that the device wings' battery indicator remains untouched (green/amber/red regardless of accent) — the intentional scope exclusion held, no regression.
- Reconfirmed the fullscreen-enter flash (UAT Test 5) is unaffected — carried forward as the same accepted, pre-existing Phase-2 limitation.
- Applied a live, user-requested visibility fix to the charging bolt icon's color (yellow → green while charging) discovered during the on-device verification session.

## Task Commits

Each task was committed atomically:

1. **Task 1: Fix charging-yield width jump — animate the model clear with the presentation switch** - `42fbf62` (fix)
2. **Task 2: Fix charging battery indicator accent — forward the environment accent at the call site** - `d40807f` (fix)
3. **Task 3: On-device verify (checkpoint)** - no code commit; human-verify checkpoint, APPROVED (see Checkpoint Result below)
4. **Post-checkpoint deviation: charging bolt icon green instead of yellow** - `74f9481` (fix)

**Plan metadata:** (this commit, docs: complete 06-06 plan)

## Files Created/Modified

- `Islet/Notch/NotchWindowController.swift` - `scheduleActivityDismiss()` now commits `syncActivityModels()` inside the same `withAnimation(.spring)` block as `renderPresentation()`; `positionAndShow()` guards the forced `panel.setFrame(_, display: true)` redisplay behind `if panel.frame != panelFrame`.
- `Islet/Notch/NotchPillView.swift` - Charging wings' `BatteryIndicator` call now forwards `accent: accent`; the charging-cue bolt icon's charging-state color changed from `Color.yellow` to `Color.green` (post-checkpoint deviation).

## Decisions Made

- `transientQueue.advance()` deliberately stays OUTSIDE the `withAnimation` block in `scheduleActivityDismiss()` — it's a pure value mutation with no SwiftUI publish, animating it would add nothing.
- The device wings' `BatteryIndicator(level: battery)` call was explicitly NOT touched — its green/amber/red-regardless-of-accent behavior is a documented, user-confirmed design decision, not a bug.
- The fullscreen-enter flash was explicitly left unaddressed — no application-layer fix exists (window-server compositing limitation from Phase 2, a debounce was already tried and reverted).

## Deviations from Plan

### Auto-fixed / User-requested Issues

**1. [Post-checkpoint, user-requested] Charging bolt icon color changed from yellow to green**
- **Found during:** Task 3 on-device human-verify checkpoint — the coordinator relayed live user feedback that the yellow charging-cue bolt was too washed out/hard to see.
- **Issue:** `Image(systemName: "bolt.fill")` in `wings(for activity:)` used `.foregroundStyle(isCharging ? Color.yellow : Color.white.opacity(0.6))` — insufficient visibility while charging.
- **Fix:** Changed the charging-state color to `Color.green`: `.foregroundStyle(isCharging ? Color.green : Color.white.opacity(0.6))`. The not-charging dim state and the `.symbolRenderingMode(.hierarchical)` modifier were left unchanged, per explicit instruction.
- **Files modified:** `Islet/Notch/NotchPillView.swift`
- **Verification:** `xcodegen generate && xcodebuild build -scheme Islet -destination 'platform=macOS'` → `BUILD SUCCEEDED`.
- **Committed in:** `74f9481`

---

**Total deviations:** 1 (user-requested visibility tweak during checkpoint, not a Rule 1-4 auto-fix — explicitly directed by the coordinator relaying user feedback)
**Impact on plan:** Small, scoped, cosmetic-only change to a single color value on the same line the plan's Task 2 already touched; no scope creep, no architectural change.

## Checkpoint Result

**Task 3 (human-verify, gate="blocking"): APPROVED.**

- Item 1 (smooth charging-yield morph): PASS.
- Item 2 (tinted charging battery accent): PASS.
- Item 3 (device battery indicator unchanged): PASS — confirmed still plain green/amber/red, not tinted by accent.
- Item 4 (fullscreen-enter flash): informational only, not a pass/fail gate — not evaluated as a regression check; carried forward as the accepted, pre-existing Phase-2 limitation documented in `.planning/debug/fullscreen-enter-flash.md`. Not closed by this plan, and not expected to be.

## Issues Encountered

None beyond the user-requested bolt-icon color tweak documented above.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- All three 06-UAT.md gaps are now resolved/accounted for: Gap 1 and Gap 2 closed with code fixes and on-device verification; Gap 3 (fullscreen flash) explicitly reconfirmed as an accepted carry-over, not a new regression.
- Phase 6 (Priority Resolver, Settings & v1 Ship) is now fully closed across all 6 plans (06-01 through 06-06).
- COORD-01 and APP-03 requirements are complete.
- No blockers for the next phase.

## Self-Check: PASSED

- FOUND: `Islet/Notch/NotchWindowController.swift` (modified, contains `if panel.frame != panelFrame`)
- FOUND: `Islet/Notch/NotchPillView.swift` (modified, contains `BatteryIndicator(level: percent, accent: accent)` and `Color.green`)
- FOUND: commit `42fbf62` in `git log --oneline --all`
- FOUND: commit `d40807f` in `git log --oneline --all`
- FOUND: commit `74f9481` in `git log --oneline --all`

---
*Phase: 06-priority-resolver-settings-v1-ship*
*Completed: 2026-07-01*
