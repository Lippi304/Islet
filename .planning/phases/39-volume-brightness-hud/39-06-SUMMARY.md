---
phase: 39-volume-brightness-hud
plan: 06
subsystem: ui
tags: [swiftui, settings, appstorage, accessibility, deep-link]

requires:
  - phase: 39-volume-brightness-hud
    provides: "39-05's ActivitySettings.osdSuppressionKey/osdPermissionStatusHint keys; 39-03's OSDInterceptor.isAccessibilityTrusted"
provides:
  - "SettingsView.swift: 'Replace System Volume/Brightness OSD' toggle + explanation popover in the Activities section, off by default"
  - "Accessibility deep-link via x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
affects: [39-07-uat]

tech-stack:
  added: []
  patterns: [permission-toggle-status-hint-popover shell, reused from Focus Mode HUD's shipped pattern]

key-files:
  created: []
  modified:
    - Islet/SettingsView.swift

key-decisions:
  - "Toggle/popover UI built exactly per the locked UI-SPEC contract even though suppression is currently a no-op (per 39-03-SUMMARY.md's suppression-unreliable finding) — the toggle still legitimately gates suppressionArmed()'s boolean and could become functional again in a future macOS/permission-tier change"

patterns-established: []

requirements-completed: [HUD-03, HUD-04]

duration: 15min
completed: 2026-07-17
---

# Phase 39 Plan 06: OSD Suppression Toggle + Explanation Popover Summary

**"Replace System Volume/Brightness OSD" toggle + Accessibility deep-link popover added to Settings, mirroring Focus Mode HUD's shipped shell — but the toggle is a documented no-op since `OSDInterceptor` (Plan 39-03) never actually suppresses the native OSD.**

## Performance

- **Duration:** ~15 min
- **Completed:** 2026-07-17
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments
- Added `osdSuppressionEnabled` `@AppStorage`-backed toggle (default `false`, D-05) to `SettingsView`'s Activities section, labeled exactly `"Replace System Volume/Brightness OSD"` per the UI-SPEC's anti-regression note (never "Volume/Brightness HUD")
- Added `osdPermissionExplanationView` popover with the locked heading/body copy, a `"Not Now"` dismiss that leaves the toggle ON (D-06), and an `"Open System Settings"` primary action that deep-links to `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility` (D-08) — genuinely new code, no existing deep-link call site to copy from
- Added the status-hint block reusing `ActivitySettings.osdPermissionStatusHint(toggleOn:granted:)` (already shipped in Plan 39-05), with the same tap-to-retry affordance as Focus Mode's hint
- Added an inline code comment at the `osdSuppressionEnabled` declaration flagging the no-op status for future readers

## Task Commits

1. **Task 1: OSD suppression toggle + explanation popover with Accessibility deep-link** - `a8127c7` (feat)

## Files Created/Modified
- `Islet/SettingsView.swift` - new `osdSuppressionEnabled`/`showOSDPermissionExplanation` state, toggle + status hint in the Activities section, `osdPermissionExplanationView` computed property

## Decisions Made

**Toggle built as a documented no-op, per explicit instruction carried forward from 39-03-SUMMARY.md.** Plan 39-01's on-device spike concluded `suppression-unreliable`, and Plan 39-03 implemented `OSDInterceptor` as a PERMANENT `.listenOnly`-only detector that never swallows any event regardless of `suppressionArmed()`'s value. This plan built the toggle/popover exactly as specified anyway (locked UI-SPEC copy, structure unchanged) because:
- The toggle still legitimately gates the `suppressionArmed()` closure's boolean value (read fresh on every event in `OSDInterceptor`, even though the result is currently ignored)
- The Settings UI is otherwise complete and consistent with the rest of the permission-toggle pattern established by Focus Mode HUD
- A future macOS release or Accessibility permission-tier change could make suppression viable again, at which point this UI needs no further changes — only `OSDInterceptor`'s internals would need to change

## IMPORTANT: Suppression is a no-op on this build

**Flipping the "Replace System Volume/Brightness OSD" toggle ON — even after granting Accessibility — will NOT make the native macOS volume/brightness OSD disappear.** This is expected behavior, not a bug. Per `39-03-SUMMARY.md`'s on-device spike finding, `OSDInterceptor` is built as a permanent `.listenOnly`-only `CGEventTap` that never swallows any `NX_SYSDEFINED` event, because `.defaultTap` + returning `nil` was confirmed NOT to actually suppress the native OSD on the dev machine (macOS Tahoe). The toggle/hint/popover are all fully functional UI (they correctly track Accessibility-trust state and update the status hint from "Permission needed — tap to grant" to "Active" once granted) — only the actual OSD-hiding effect is absent.

**Flag for Plan 39-07's on-device UAT checkpoint:** do NOT expect the native OSD to visually disappear when this toggle is on and Accessibility is granted. The Volume/Brightness HUD itself (Plans 39-04/39-05) still appears correctly alongside the native OSD regardless of this toggle's state, per D-06 — the toggle never gates the HUD's own visibility.

## Deviations from Plan

None - plan executed exactly as written. The no-op status was an explicit, anticipated constraint from Plan 39-03 (not a deviation discovered during this plan's execution) and is documented above per the orchestrator's instruction.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness

The Settings UI fully implements D-05/D-06/D-08's locked contract. `xcodebuild build -project Islet.xcodeproj -scheme Islet -configuration Debug` succeeds. All 4 acceptance-criteria greps pass (toggle label exactly 1 match, deep-link URL exactly 1 match, `osdSuppressionEnabled` defaults to `false`, "Not Now" branch does not revert the toggle). On-device verification (does the toggle flip, does the popover appear only when untrusted, does the deep-link open the correct pane, does the hint update on grant) plus the no-op-suppression confirmation above are both deferred to Plan 39-07's consolidated UAT checkpoint, per this plan's own `<verification>` note.

---
*Phase: 39-volume-brightness-hud*
*Completed: 2026-07-17*
