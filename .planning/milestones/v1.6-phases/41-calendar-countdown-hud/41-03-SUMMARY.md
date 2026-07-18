---
phase: 41-calendar-countdown-hud
plan: 03
subsystem: ui
tags: [swiftui, timelineview, calendar, countdown, settings]

# Dependency graph
requires:
  - phase: 41-calendar-countdown-hud
    plan: 01
    provides: CalendarCountdownActivity/IslandPresentation.calendarCountdown, ActivitySettings.calendarCountdownKey, presentationSwitch placeholder arm
  - phase: 41-calendar-countdown-hud
    plan: 02
    provides: CalendarCountdownMonitor + NotchWindowController wiring feeding real calendarCountdownActivity into resolve(...)
provides:
  - "countdownWings(for:) — icon-left/mm:ss-right collapsed wing, single TimelineView(.periodic) drives synchronized icon+text urgency coloring"
  - "urgencyColor(for:at:) / formatMMSS(_:) pure helpers"
  - "presentationSwitch's .calendarCountdown arm now renders the real view (Plan 01 placeholder replaced in place)"
  - "Settings > Activities > 'Calendar Countdown' toggle, default ON, no permission popover"
affects: [41-04-on-device-uat]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "One TimelineView(.periodic(from:by:)) tick closure computes ONE color value applied to both icon and text foregroundStyle, preventing the icon/text desync a naive Image-outside/Text-inside split would cause"

key-files:
  created: []
  modified:
    - Islet/Notch/NotchPillView.swift
    - Islet/SettingsView.swift

key-decisions:
  - "countdownWings(for:) placed directly after focusWings(for:) in NotchPillView.swift, mirroring its icon-left/Spacer/content-right wingsShape(leftWidth:rightWidth:) structure verbatim"
  - "leftWidth 118pt / rightWidth default 145pt per UI-SPEC's locked dimensions — reused verbatim from Focus's on-device-proven icon-only-flank floor, no new geometry math"
  - "Settings toggle placed directly after Toggle(\"Devices\") and before the Focus Mode HUD block — plain opt-out group, not the permission-gated group"

patterns-established: []

requirements-completed: [HUD-08]

# Metrics
duration: 8min
completed: 2026-07-18
---

# Phase 41 Plan 03: Countdown Wing View + Settings Toggle Summary

**countdownWings(for:) renders a calendar icon + live mm:ss countdown flanking the notch, both recoloring orange→red together from one shared per-tick TimelineView value, plus a default-ON Settings toggle with no permission surface.**

## Performance

- **Duration:** 8 min
- **Started:** 2026-07-18T14:48:00+02:00
- **Completed:** 2026-07-18T14:56:29+02:00
- **Tasks:** 2 completed
- **Files modified:** 2

## Accomplishments
- `countdownWings(for:)` added to `NotchPillView.swift`, wired into `presentationSwitch` in place of Plan 01's placeholder `EmptyView()` arm — the whole `HStack { Image; Spacer; Text }` lives inside ONE `TimelineView(.periodic(from: .now, by: 1))` closure so `urgencyColor(for:at:)` is computed once per tick and applied to both the icon's and text's `.foregroundStyle`, structurally preventing the icon/text color desync the UI-SPEC and 41-RESEARCH.md's literal snippet both warned against.
- `urgencyColor(for:at:)` (instant `< 60s → .red : .orange` threshold, no gradient) and `formatMMSS(_:)` (zero-padded `mm:ss`) added as small private pure helpers.
- No title, no hover modifier, no new tap-gesture code added — tap-to-expand falls out for free from `wingsShape`'s existing `.onTapGesture { onClick() }`, and `CalendarCountdownActivity` structurally has no title field to render even if someone tried.
- Settings gained a default-ON `Toggle("Calendar Countdown", isOn: $calendarCountdownEnabled)` in the plain `Section("Activities")` block, placed right after `Toggle("Devices")` and before the permission-gated Focus Mode HUD toggle — no `.onChange`/`.popover`, matching D-03's "no new permission surface" contract (EventKit auth is reused as-is).

## Task Commits

Each task was committed atomically:

1. **Task 1: countdownWings(for:) view + urgency helpers** - `00a9fb0` (feat)
2. **Task 2: Settings toggle** - `1589027` (feat)

## Files Created/Modified
- `Islet/Notch/NotchPillView.swift` - Added `urgencyColor(for:at:)`, `formatMMSS(_:)`, `countdownWings(for:)`; replaced the `presentationSwitch` placeholder arm with `countdownWings(for: activity)`
- `Islet/SettingsView.swift` - Added `calendarCountdownEnabled` `@AppStorage` property and the `"Calendar Countdown"` `Toggle` in `Section("Activities")`

## Decisions Made
- Both new helpers and the view were placed immediately after `focusWings(for:)` (not at the end of the file) so the reading order in `NotchPillView.swift` groups all collapsed-wing view builders together, matching this file's existing organization.
- Confirmed via source read (not just grep) that both `.foregroundStyle(color)` calls sit lexically inside the same `TimelineView` trailing closure — satisfies the plan's acceptance criteria beyond what a plain grep count could prove.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- `countdownWings(for:)` is live, wired into `presentationSwitch`, and builds cleanly against Plan 02's real `CalendarCountdownActivity`/`calendarCountdownActivity` data — the collapsed pill can now actually show a ticking, color-shifting countdown on a real device with a real upcoming event.
- The Settings toggle exists and defaults ON; toggling it off is wired through `NotchWindowController.handleSettingsChanged()`'s existing Plan-02 teardown block.
- Plan 04's on-device UAT is the first point this can be visually verified — no automated test exists for SwiftUI wing rendering in this codebase (matches every prior wing's precedent), and the per-second tick / 60s color-threshold crossing / icon-text sync are manual-only per this plan's own `<verification>` section.
- Build is green after each task (`xcodebuild -project Islet.xcodeproj -scheme Islet -configuration Debug build`).

---
*Phase: 41-calendar-countdown-hud*
*Completed: 2026-07-18*

## Self-Check: PASSED
