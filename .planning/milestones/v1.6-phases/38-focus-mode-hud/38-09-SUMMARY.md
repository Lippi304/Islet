---
phase: 38-focus-mode-hud
plan: 09
subsystem: ui
tags: [swiftui, intents, infocusstatuscenter, entitlements, notch]

requires:
  - phase: 38-focus-mode-hud
    provides: FocusActivity/FocusModeMonitor/IslandResolver plumbing (38-01..38-08)
provides:
  - handleFocusChange's off-branch re-renders/re-shows visibility after flushing the Focus transient
  - com.apple.developer.usernotifications.communication entitlement (required for INFocusStatusCenter.focusStatus.isFocused to resolve real values, not just false)
  - Focus wing visual redesign: icon-only left flank (no "Focus" text), green dot + "On" text right flank
affects: [39-volume-brightness-hud]

tech-stack:
  added: []
  patterns: []

key-files:
  created: []
  modified:
    - Islet/Notch/NotchWindowController.swift
    - Islet/Islet.entitlements
    - Islet/Notch/NotchPillView.swift

key-decisions:
  - "INFocusStatusCenter authorization alone is insufficient — macOS also requires the Communication Notifications entitlement to read real Focus state, or focusStatus.isFocused silently resolves to false forever (not nil)"
  - "Focus wing left flank narrowed to 118pt (icon-only, no label) and right flank widened to 160pt (dot + 'On' text) per live on-device design iteration — deviates from 38-UI-SPEC.md's original icon+'Focus'-label left / bare-dot right contract"

patterns-established: []

requirements-completed: [HUD-05]

duration: ~5h (multi-round on-device UAT with 2 additional defects found)
completed: 2026-07-17
---

# Phase 38 Plan 09: Focus HUD render-tail fix + Communication Notifications entitlement + wing redesign

**`handleFocusChange`'s off-branch now re-renders after flushing the Focus transient, the Communication Notifications entitlement was added so `INFocusStatusCenter` actually reports live Focus state, and the Focus wing was redesigned to an icon-only left flank / dot+"On"-label right flank per on-device UAT feedback.**

## Performance

- **Tasks:** 3 (2 auto + 1 blocking checkpoint), plus 2 deviations found during the checkpoint
- **Files modified:** 3 (`NotchWindowController.swift`, `Islet.entitlements`, `NotchPillView.swift`)
- **Completed:** 2026-07-17

## Accomplishments
- Closed the last known BLOCKER from 38-VERIFICATION.md: `handleFocusChange(false)` now calls `renderPresentation()`/`updateVisibility()` after `flushTransients(.focus)`, so the Focus pill disappears promptly when Focus/DND turns off — no longer requires an unrelated event to trigger the redraw.
- Discovered and fixed a hard-crash on first Focus-authorization grant: missing `NSFocusStatusUsageDescription` Info.plist key (mirrors the earlier NSBluetoothAlwaysUsageDescription gap, project memory A1).
- Discovered and fixed a silent functional dead-end: `INFocusStatusCenter.focusStatus.isFocused` requires the `com.apple.developer.usernotifications.communication` entitlement even after authorization succeeds — without it, the OS logs `DNDErrorDomain 1004 "App is missing Communication Notifications entitlement"` and `isFocused` always resolves to `false`. This was the exact dead-end 38-RESEARCH.md predicted for this API; the Wave-1 spike (38-01) confirmed `authorizationStatus == .authorized` but never tested an actual `isFocused` read against live Focus state, so the gap went uncaught until this plan's on-device UAT.
- Redesigned the Focus wing per live user feedback: dropped the "Focus" text label (icon-only left flank), added a green dot + "On" text on the right flank, and re-tuned flank widths (118pt left / 160pt right) after an over-aggressive first attempt (100pt) rendered the icon under the physical camera housing.

## Task Commits

1. **Task 1: Add the missing render tail to handleFocusChange's off-branch** - `85bbc2c` (fix)
2. **Task 2: Debug build gate** - verification only, no commit (build succeeded)
3. **Deviation: NSFocusStatusUsageDescription Info.plist key** - `4337f20` (fix)
4. **Worktree merge** - `c3e190f` (merge)
5. **Deviation: Communication Notifications entitlement + Focus wing redesign** - `29660f8` (fix)

## Files Created/Modified
- `Islet/Notch/NotchWindowController.swift` - `handleFocusChange`'s off-branch now mirrors `handleSettingsChanged`'s render tail
- `Islet/Islet.entitlements` - added `com.apple.developer.usernotifications.communication`
- `Islet/Notch/NotchPillView.swift` - `focusWings(for:)` redesigned: icon-only left (118pt), dot+"On" right (160pt)

## Decisions Made
- Communication Notifications entitlement was added directly (paid Apple Developer Team already configured on this project, `DEVELOPMENT_TEAM: R7AGU84UX7`) rather than treating this as a D-12 descope trigger — user confirmed they have the required account.
- Focus wing visual contract deviates from `38-UI-SPEC.md`'s original "icon + 'Focus' label left / bare dot right" spec — user directed a live redesign during UAT (icon-only left, dot+"On" right) after seeing the pill render for the first time (it had never actually been visible before this plan, due to the two defects above masking it). `38-UI-SPEC.md` is now stale on this point; not updated in this plan (out of scope) — flag for a docs-sync pass.

## Deviations from Plan

### Auto-fixed Issues

**1. [Blocking — crash] Missing NSFocusStatusUsageDescription Info.plist key**
- **Found during:** Task 3 (on-device UAT, Scenario C — first permission grant)
- **Issue:** App hard-crashed (`__abort_with_payload`) the instant Focus authorization was requested — Info.plist lacked the required privacy-usage-description key for `INFocusStatusCenter`.
- **Fix:** Added `INFOPLIST_KEY_NSFocusStatusUsageDescription` to `project.yml`, regenerated via `xcodegen generate`.
- **Files modified:** `project.yml`, `Islet.xcodeproj/project.pbxproj` (worktree), merged to `Islet.xcodeproj/project.pbxproj` in main.
- **Verification:** Debug build succeeded; on-device grant flow no longer crashes.
- **Committed in:** `4337f20`, merged via `c3e190f`

**2. [Blocking — silent functional dead-end] Missing Communication Notifications entitlement**
- **Found during:** Task 3 (on-device UAT, Scenario A — Focus pill never appeared despite granted authorization)
- **Issue:** `INFocusStatusCenter.focusStatus.isFocused` resolved to `false` on every poll regardless of actual Focus state; Xcode console showed `DNDErrorDomain 1004 "App is missing Communication Notifications entitlement."` Diagnosed via temporary debug logging (added and removed within this session, not committed).
- **Fix:** Added `com.apple.developer.usernotifications.communication` to `Islet.entitlements`.
- **Files modified:** `Islet/Islet.entitlements`
- **Verification:** On-device UAT confirmed the pill now appears/disappears correctly with real Focus/DND state.
- **Committed in:** `29660f8`

**3. [Non-blocking — visual redesign] Focus wing layout changed from spec**
- **Found during:** Task 3 (on-device UAT, first time the pill was ever actually visible)
- **Issue:** `38-UI-SPEC.md`'s icon+"Focus"-label / bare-dot layout, once finally visible, didn't match what the user wanted live.
- **Fix:** Icon-only left flank (moon, no text), dot+"On" text right flank; flank widths tuned iteratively (118pt/160pt) after confirming the safe minimum to clear the physical camera housing (~112pt).
- **Files modified:** `Islet/Notch/NotchPillView.swift`
- **Verification:** User approved final layout on-device ("passt").
- **Committed in:** `29660f8`

---

**Total deviations:** 3 (2 blocking, 1 non-blocking visual). All three were required to actually deliver HUD-05's on-screen behavior — the feature had never been visibly confirmed working end-to-end before this plan, since both blockers masked it.
**Impact on plan:** Significant scope growth beyond the plan's stated file scope (`project.yml`, `Islet.xcodeproj`, `Islet.entitlements`, `NotchPillView.swift` were all explicitly or implicitly out of 38-09's original file list). Justified: without these fixes, Task 3's checkpoint could never pass, and HUD-05 would ship broken (crash-on-grant, permanently-false Focus detection).

## Issues Encountered
See Deviations above — both blockers were root-caused via targeted temporary debug logging (removed before this commit) plus Apple documentation research (WebSearch) confirming the entitlement requirement.

## Next Phase Readiness
- HUD-05 is now fully code-complete and on-device confirmed: Scenario A (auto-dismiss on Focus-off), Scenario B (toggle-off stays off after relaunch), Scenario C (first-grant flow without re-toggle/relaunch) all confirmed by the user.
- `38-UI-SPEC.md` is stale on the Focus Wing Contract section (still describes the old icon+label/bare-dot design) — flag for a docs-sync pass, not blocking.
- The general left/right wing flank asymmetry (icon-only sides using a wider flank than needed) also affects Charging/Bluetooth wings per user observation — explicitly deferred by the user as a future general fix, not part of this plan.
- Phase 39 (Volume & Brightness HUD) should be aware: any future `Intents`-adjacent system API may carry similar hidden entitlement requirements beyond basic `authorizationStatus` — worth an explicit isAuthorized-vs-actually-works check early in that phase's spike.

---
*Phase: 38-focus-mode-hud*
*Completed: 2026-07-17*
