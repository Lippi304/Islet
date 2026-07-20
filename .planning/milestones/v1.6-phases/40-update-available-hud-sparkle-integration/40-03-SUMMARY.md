---
phase: 40-update-available-hud-sparkle-integration
plan: 03
subsystem: ui
tags: [sparkle, hud, on-device-verification, menu-bar, redesign]

# Dependency graph
requires:
  - phase: 40-update-available-hud-sparkle-integration (Plan 02)
    provides: Collapsed-pill badge overlay (D-05/D-06/D-07) and its click-through wiring
provides:
  - On-device-confirmed Release archive launch with embedded Sparkle.framework under Hardened Runtime (no dyld library-validation crash)
  - Menu-bar status-item red dot as the update-available indicator, replacing the pill badge
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "A fixed-size colored NSView added as an Auto Layout-constrained subview of an NSStatusItem's button is a simpler, always-hit-testable alternative to a SwiftUI-panel overlay for any future menu-bar-adjacent indicator — no dependency on NotchWindowController's click-through hot-zone geometry at all."

key-files:
  created: []
  modified:
    - Islet/AppDelegate.swift
    - Islet/Notch/NotchPillView.swift
    - Islet/Notch/NotchWindowController.swift
    - IsletTests/NotchPillViewTests.swift
  deleted:
    - Islet/Notch/UpdateAvailableState.swift

key-decisions:
  - "Badge-tap dispatch bug (carried over from the prior session's Task 1, unresolved) root-caused on-device this session: tapping the badge's visible screen position passed the click through to whatever was behind the app entirely — confirmed NotchWindowController's hotZone (sized to the collapsed pill's own geometry, computed once in positionAndShow()) does not reliably cover the badge's actual overlay position, so the click never reached SwiftUI. Rather than patch the click-through zone math, the user chose to redesign: move the indicator off the notch pill entirely onto the always-fully-clickable menu-bar status item, which sidesteps the whole class of bug by construction instead of fixing it in place."
  - "Menu-bar indicator implemented as a plain colored NSView (6x6pt, red, Auto Layout-pinned to the status item button's top-trailing corner) rather than baking a dot into the template SF Symbol image — keeps the base icon auto-tinting (isTemplate) for light/dark menu bars while the dot keeps its own fixed red color, which a single composited template image could not do."
  - "This supersedes 40-UI-SPEC.md's D-05/D-06/D-07 (badge on the collapsed pill, hidden while expanded, themed with nowPlayingAccent) — the UI-SPEC document itself was not rewritten (out of scope for a verification-plan deviation); this SUMMARY is the record of the actual shipped design."

requirements-completed: [HUD-06]

# Metrics
duration: ~1.5h (across the badge-tap root-cause investigation, user decision, and redesign)
completed: 2026-07-18
---

# Phase 40 Plan 03: On-Device Verification + Menu-Bar Redesign Summary

**Release-archive launch confirmed crash-free under Hardened Runtime; the collapsed-pill update badge was redesigned to a menu-bar status-item dot after its tap-dispatch bug was root-caused to a click-through hot-zone gap.**

## Performance

- **Duration:** ~1.5h this session (Task 1's remaining bug-hunt + Task 2 + redesign), continuing from a prior session's Task 1 work (4 bugs found/fixed, commit `b80f35d`)
- **Tasks:** 2 checkpoint tasks + 1 unplanned redesign task
- **Files modified:** 5 (4 modified, 1 deleted)

## Accomplishments
- **Task 2 (Release verification) — approved:** Archived a Release build via Xcode's Organizer, exported (`Copy App`), launched the exported `Islet.app` directly from Finder (outside Xcode's debugger). App launched without a dyld "different Team IDs" crash, menu-bar icon appeared, "Check for Updates…" was present and clickable (returned the expected network error against the still-placeholder `SUFeedURL` — an acceptable outcome per the plan).
- **Task 1's carried-over blocker root-caused:** tapping the badge's on-screen position passed the click straight through the app window (confirmed live, not inferred from screenshots) — `NotchWindowController.hotZone` doesn't reliably cover the badge overlay's real position.
- **Redesign, implemented and committed (`30d9f82`):** the badge overlay, its `shouldShowUpdateBadge` gate, `UpdateAvailableState`, `currentPillWidth` tracking, and all associated tests removed from `NotchPillView`/`NotchWindowController`; a small red-dot `NSView` added to the existing menu-bar status item in `AppDelegate`, shown from the same `SPUUpdaterDelegate.updater(_:didFindValidUpdate:)` callback that used to flip the badge's `@Published` flag.
- **Redesign re-verified on-device (mock appcast feed):** dot hidden by default; "Check for Updates…" → "Remind Me Later" → dot appears on the menu-bar icon. Confirmed by the user.
- `xcodebuild build -scheme Islet -configuration Debug` (correct `DEVELOPER_DIR`) exits 0 after the redesign.

## Task Commits
1. **Task 2: Release archive verification** — no code change, verification-only (approved this session).
2. **Redesign: move update indicator from pill badge to menu-bar dot** — `30d9f82` (fix)

## Files Created/Modified
- `Islet/AppDelegate.swift` — added `updateDotView`, wired it into the status item's button via Auto Layout, `didFindValidUpdate` now shows the dot instead of setting `updateAvailableState.updateAvailable`; removed the now-unused `onUpdateBadgeTapped` closure wiring.
- `Islet/Notch/NotchPillView.swift` — removed `shouldShowUpdateBadge`, the badge `.overlay` block, `updateAvailableState`/`onUpdateBadgeTap` properties, and the now-dead `currentPillWidth` width-tracking (`@State` + `.background(GeometryReader)`) that existed solely to size the badge overlay. Reverted the temporary `devOffset = 0` diagnostic used to test the click-through hypothesis back to its original `#if DEBUG` value.
- `Islet/Notch/NotchWindowController.swift` — removed `updateAvailableState`/`onUpdateBadgeTapped` properties and their pass-through into `makeRootView`'s `NotchPillView(...)` call.
- `Islet/Notch/UpdateAvailableState.swift` — deleted (no longer referenced anywhere).
- `IsletTests/NotchPillViewTests.swift` — removed the 4 `shouldShowUpdateBadge` truth-table tests.

## Decisions Made
- Did not attempt to fix the click-through hot-zone geometry to make the pill badge tappable — the user preferred a structural redesign (menu-bar dot, always fully hit-testable) over patching `NotchWindowController`'s zone math for one feature.
- Kept the base menu-bar icon's `isTemplate = true` auto-tinting; the red dot is a separate, non-template subview rather than part of a single composited image, so it keeps a fixed red color independent of the auto-tint.
- `40-UI-SPEC.md`'s D-05/D-06/D-07 (badge-on-pill decisions) are superseded by this SUMMARY, not edited in place — the UI-SPEC document still describes the original design for historical reference.

## Deviations from Plan

### Scope Change (user-directed)

**1. Update-available indicator redesigned mid-checkpoint, from collapsed-pill badge to menu-bar status-item dot**
- **Found during:** Task 1 resumption (root-causing the carried-over badge-tap-dispatch bug)
- **Issue:** The badge-tap bug (open since the prior session) was confirmed on-device to be a real click-through pass-through, not a SwiftUI gesture-priority issue — `NotchWindowController`'s `hotZone` doesn't reliably cover the badge's actual screen position.
- **User decision:** Rather than fix the hot-zone geometry, move the indicator off the pill entirely onto the always-clickable menu-bar icon (small red dot).
- **Fix:** Implemented as described in Accomplishments above; committed as `30d9f82`.
- **Verification:** Build succeeds (`xcodebuild build -scheme Islet -configuration Debug`, exit 0); on-device retest with the mock appcast feed confirms the dot shows/hides correctly.

---

**Total deviations:** 1 user-directed scope change (redesign), superseding Plan 02's original badge implementation entirely.
**Impact on plan:** Task 1's original 13-step badge-specific checklist (color-follows-accent, disappears-on-expand, VoiceOver label, etc.) no longer applies — those steps tested a UI surface that no longer exists. The badge-independent parts of Task 1 already confirmed in the prior session remain valid: no unprompted Sparkle permission alert on second launch, no click-through/hover regression elsewhere on the pill (CR-01 trace), Settings "Automatically Check for Updates" toggle persists correctly, and "Check for Updates…" → Sparkle's dialog works via the menu item (unchanged by this redesign).

## Issues Encountered
- Xcode hung during the Release archive (Product > Archive) this session, requiring a machine restart before Task 2 could complete — no code or planning state was lost (working tree was clean at the time).

## User Setup Required

None — no external service configuration required this plan. (The local mock-appcast HTTP server used twice during testing this session was stopped and `project.yml`'s `SUFeedURL` confirmed reverted to the D-01 placeholder before this SUMMARY was written; `git status` is clean.)

## Next Phase Readiness

- Phase 40 (HUD-06) is functionally complete: Sparkle backend, menu-bar update indicator, and Release-build launch all confirmed on-device.
- No blockers carried forward.

---
*Phase: 40-update-available-hud-sparkle-integration*
*Completed: 2026-07-18*

## Self-Check: PASSED

All modified files verified present/absent on disk as listed above; redesign commit `30d9f82`
verified present in `git log`; `xcodebuild build -scheme Islet -configuration Debug` verified
exit 0 after the redesign; `git status` verified clean (no leftover mock-feed config).
