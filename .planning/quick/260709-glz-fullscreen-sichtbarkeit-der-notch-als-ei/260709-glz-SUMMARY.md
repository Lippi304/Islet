---
phase: quick-260709-glz
plan: 01
subsystem: ui
tags: [swiftui, appstorage, userdefaults, settings, notch-visibility]

requires:
  - phase: quick-260708-u47
    provides: existing SettingsView Section pattern, ActivitySettings key namespace
provides:
  - "ActivitySettings.hideInFullscreenKey — shared UserDefaults key"
  - "NotchWindowController.hideInFullscreen as a computed, live-reading property"
  - "SettingsView Fullscreen section with a working toggle"
affects: []

tech-stack:
  added: []
  patterns:
    - "Preference seams pre-documented in code comments (e.g. NotchWindowController line 49-52) turned into a computed property reading via the existing activityEnabled(_:) default-true helper — no new UserDefaults read path invented."

key-files:
  created: []
  modified:
    - Islet/ActivitySettings.swift
    - Islet/Notch/NotchWindowController.swift
    - Islet/SettingsView.swift

key-decisions:
  - "Toggle placed in its own new 'Fullscreen' Section rather than inside 'Activities' — it gates visibility, not a live-activity source."

patterns-established: []

requirements-completed: []

duration: 15min
completed: 2026-07-09
---

# Quick Task 260709-glz: Fullscreen-Sichtbarkeit als Einstellung Summary

**Fullscreen-hide behavior of the notch island is now a persisted, live-editable Settings toggle instead of a hardcoded-always-on constant.**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-07-09T09:47:00Z (approx)
- **Completed:** 2026-07-09T10:02:32Z
- **Tasks:** 2/2
- **Files modified:** 3

## Accomplishments
- `ActivitySettings.hideInFullscreenKey` added as the shared UserDefaults key namespace entry
- `NotchWindowController.hideInFullscreen` turned from a hardcoded `let true` into a computed property reading the key via the existing `activityEnabled(_:)` default-true helper — zero migration needed, existing users keep today's hide-in-fullscreen behavior unchanged
- New "Fullscreen" section in Settings with a "Hide notch in fullscreen" toggle, defaulting to on, live-applying via the existing `UserDefaults.didChangeNotification` → `updateVisibility()` path (no new observer wiring required)

## Task Commits

1. **Task 1: Add the persisted key and turn hideInFullscreen into a read** - `f9213d8` (feat)
2. **Task 2: Add the Settings toggle** - `18dc05a` (feat)

## Files Created/Modified
- `Islet/ActivitySettings.swift` - added `hideInFullscreenKey` constant
- `Islet/Notch/NotchWindowController.swift` - `hideInFullscreen` is now a computed property reading the new key
- `Islet/SettingsView.swift` - new `@AppStorage` property + "Fullscreen" section with toggle

## Decisions Made
- Toggle lives in its own "Fullscreen" section (not inside "Activities") since it is a visibility preference, not a live-activity on/off switch, per the plan's explicit instruction.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- No follow-up work required; the seam documented in `NotchWindowController.swift` (line 49-52) is now closed.
- Manual on-device verification recommended per the plan's `<done>` criteria for Task 2 (flip toggle off, enter fullscreen in another app, confirm island stays visible) since `xcodebuild test` hangs headless in this project (project memory: `xcodebuild-test-headless-hang`).

---
*Phase: quick-260709-glz*
*Completed: 2026-07-09*

## Self-Check: PASSED

All created/modified files verified present; both task commits (f9213d8, 18dc05a) verified in git log.
