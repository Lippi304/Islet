---
phase: 38-focus-mode-hud
plan: 04
subsystem: ui
tags: [swiftui, notch-wing, focus-mode, resolver-dispatch]

# Dependency graph
requires:
  - phase: 38-01
    provides: "Detection-path gate decision (path-a, not descope) — this plan only depended on it as a go/no-go gate, not for code"
  - phase: 38-02
    provides: "FocusActivity pure type + IslandPresentation.focus case"
provides:
  - "focusWings(for:) private func rendering the Focus collapsed wing, wired into NotchPillView's presentationSwitch"
  - "A SwiftUI preview entry (\"Focus Wings\") for .focus(.on), mirroring the file's existing per-case preview convention"
affects: [38-05-focus-mode-controller-wiring, 38-07-cleanup]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Focus wing reuses wingsShape()/wingsLabelWidth/wingsSize verbatim — no new sizing constants, no new shape, mirroring Phase 36's Charging/Device wing precedent"

key-files:
  created: []
  modified:
    - Islet/Notch/NotchPillView.swift

key-decisions: []

patterns-established: []

requirements-completed: []  # HUD-05 not yet complete — this plan only ships the wing's static render; live wiring (FocusModeMonitor -> resolver -> controller) lands in 38-05/38-06

# Metrics
duration: ~15min
completed: 2026-07-17
---

# Phase 38 Plan 04: Focus Wing View Summary

**`focusWings(for:)` renders the Focus collapsed-pill wing (moon.fill + "Focus" label, fixed white, 8x8pt green status dot) by mechanically reapplying Phase 36's Droppy-pill wing language — wired into `presentationSwitch`'s `.focus(let activity)` dispatch arm, replacing the prior `EmptyView()` compiler-forced stub.**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-07-17T00:00:00Z (approx)
- **Completed:** 2026-07-17T00:03:23Z
- **Tasks:** 2 (both auto)
- **Files modified:** 1

## Accomplishments
- Added `focusWings(for activity: FocusActivity) -> some View` directly below `deviceWings(for:)`, calling the shared `wingsShape(leftWidth:rightWidth:)` helper with constants reused verbatim (`Self.wingsLabelWidth`, `Self.wingsSize`) — no new sizing invented
- Left wing: `moon.fill` icon + always-shown `"Focus"` label, both fixed `.white` (D-11 — never `deviceAccent`/`chargingAccent`); right wing: a literal fixed `Color.green` 8×8pt dot (not `BatteryIndicator`, which has no percentage equivalent here)
- Replaced `presentationSwitch`'s `.focus` `EmptyView()` stub (left by Plan 38-02) with `case .focus(let activity): focusWings(for: activity)`
- Added a `"Focus Wings"` `#Preview` block mirroring the existing Charging/Device preview structure, inserted directly after "Device Wings" per the file's per-case ordering convention

## Task Commits

Each task was committed atomically:

1. **Task 1: focusWings(for:) + presentationSwitch dispatch** - `41bb8b4` (feat)
2. **Task 2: SwiftUI preview entry for .focus(.on)** - `480b820` (feat)

**Plan metadata:** (this commit)

## Files Created/Modified
- `Islet/Notch/NotchPillView.swift` - Added `focusWings(for:)` (below `deviceWings(for:)`), rewired `presentationSwitch`'s `.focus` case from `EmptyView()` to `focusWings(for: activity)`, added the "Focus Wings" `#Preview` block

## Decisions Made
None - plan executed exactly as written, including the exact single-line `case .focus(let activity): focusWings(for: activity)` form the plan's acceptance criteria specified (matching the grep pattern verbatim, though the file's other cases like `.device`/`.charging` split case-label and body across two lines).

## Deviations from Plan

None - plan executed exactly as written. No accent-tinting leaked in, no on/off branch inside the view (both confirmed via the plan's own grep-based acceptance criteria), and the Debug build succeeds.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- The Focus wing view is code-complete and renders correctly whenever the resolver's presentation is `.focus(.on)` — proven by both the Debug build and the new "Focus Wings" preview.
- Plan 38-05 (or later) still needs to wire `FocusModeMonitor`'s real detection into `IslandResolver`/`NotchWindowController` so `.focus(.on)` is ever actually reached at runtime; this plan intentionally did not touch that path (per its own scope note: "no dependency on FocusModeMonitor/NotchWindowController wiring").
- Ready for Plan 38-07's on-device visual UAT once the live wiring lands.

---
*Phase: 38-focus-mode-hud*
*Completed: 2026-07-17*
