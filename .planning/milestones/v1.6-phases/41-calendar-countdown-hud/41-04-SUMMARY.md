---
phase: 41-calendar-countdown-hud
plan: 04
subsystem: ui
tags: [swiftui, notch, calendar, eventkit, on-device-uat]

requires:
  - phase: 41-calendar-countdown-hud (41-01, 41-02, 41-03)
    provides: CalendarGlance.nextUpcomingEvent, CalendarService.fetchUpcomingRaw, CalendarCountdownActivity, CalendarCountdownMonitor, NotchPillView.countdownWings(for:), Settings toggle
provides:
  - On-device confirmation that the full Calendar Countdown pipeline (EventKit -> CalendarCountdownMonitor -> IslandResolver -> NotchPillView) satisfies all 4 ROADMAP success criteria
  - Fix for a real-hardware layout bug found during this checkpoint (countdown text clipped under the camera housing)
affects: [phase-42-dual-activity]

tech-stack:
  added: []
  patterns: []

key-files:
  created: []
  modified:
    - Islet/Notch/NotchPillView.swift

key-decisions:
  - "countdownWings' rightWidth widened from wingsSize.width/2 (145pt, icon-only tuning) to wingsLabelWidth/2 (200pt, label-clearing tuning) — the mm:ss text needs the same camera-clearing flank deviceWings already uses for its 'Connected' label"

patterns-established: []

requirements-completed: [HUD-08]

duration: ~15min (checkpoint round-trip + fix)
completed: 2026-07-18
---

# Phase 41: Calendar Countdown HUD Summary

**On-device UAT confirmed the Calendar Countdown HUD pipeline works end-to-end, after fixing a camera-cutout text-clipping bug found during verification**

## Performance

- **Duration:** ~15 min (Task 1 automated gate + Task 2 checkpoint round-trip, including one on-device bug found and fixed)
- **Completed:** 2026-07-18T13:08:34Z
- **Tasks:** 2/2
- **Files modified:** 1 (fix only; Task 1/2 are verification-only, no planned file changes)

## Accomplishments
- Debug build + full Cmd-U `IsletTests` suite confirmed green by the user before the on-device checkpoint
- All 10 on-device UAT steps approved by the user, covering all 4 ROADMAP success criteria and every locked CONTEXT.md decision (D-01, D-03, D-05 through D-09) with no automated test coverage
- Found and fixed a real-hardware-only bug: the countdown's `mm:ss` text partially rendered under the physical camera housing

## Task Commits

1. **Task 1: Debug build + full Cmd-U gate** — no commit (verification-only; build reconfirmed green, user ran Cmd-U manually in Xcode)
2. **Task 2: Consolidated on-device UAT** — `0fc05b6` (fix: revert premature HUD-08 completion mark caught during checkpoint), `ee5c440` (fix: widen countdown wing right flank to clear camera cutout)

## Files Created/Modified
- `Islet/Notch/NotchPillView.swift` — `countdownWings(for:)` rightWidth changed from `wingsSize.width / 2` (145pt) to `wingsLabelWidth / 2` (200pt) so the countdown text clears the physical camera cutout, matching the pattern `deviceWings(for:)` already established for its "Connected" label

## Decisions Made
- Reused the existing `wingsLabelWidth` constant for the fix rather than introducing a new magic number, consistent with this file's established convention (see `deviceWings`/`focusWings` comments)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Countdown text rendering under camera housing**
- **Found during:** Task 2 (on-device UAT, checkpoint step 2/3)
- **Issue:** User reported the leading minute digit of the `mm:ss` countdown was hidden behind the built-in camera on real hardware — `countdownWings`' right flank (145pt) left only ~35pt of visible text room after the 20pt trailing padding, too narrow for the 5-character monospaced string to clear the ~89.5pt-wide camera cutout
- **Fix:** Widened `rightWidth` to `wingsLabelWidth / 2` (200pt), matching the label-clearing flank `deviceWings` already uses for its "Connected" text
- **Files modified:** `Islet/Notch/NotchPillView.swift`
- **Verification:** `xcodebuild -scheme Islet -configuration Debug build` green; user re-verified on-device and approved
- **Committed in:** `ee5c440`

**2. [Rule 3 - Blocking] Reverted premature HUD-08 completion mark**
- **Found during:** orchestrator review after Wave 2 (41-03) completed, before dispatching this plan
- **Issue:** 41-03's executor marked HUD-08 "Complete" in REQUIREMENTS.md/ROADMAP.md before this UAT gate had run, breaking the pattern 41-01/41-02 deliberately followed (leave Pending until UAT passes, matching Phase 38's HUD-05 precedent) and this plan's own stated purpose as "the phase's hard merge gate"
- **Fix:** Reverted HUD-08 to Pending in both files; this plan now marks it Complete for real, after approval
- **Files modified:** `.planning/REQUIREMENTS.md`
- **Verification:** Grep confirmed both `- [ ]` and traceability-table `Pending` markers restored before this checkpoint ran
- **Committed in:** `0fc05b6`

---

**Total deviations:** 2 auto-fixed (1 missing critical — real-hardware layout bug, 1 blocking — tracking correctness)
**Impact on plan:** Both fixes necessary; no scope creep. The camera-cutout fix is exactly the class of bug this checkpoint exists to catch (real hardware, not simulator/unit-testable).

## Issues Encountered
None beyond the deviations above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
HUD-08 is fully shipped — all 4 ROADMAP success criteria confirmed on real hardware, no known gaps. Phase 42 (Dual-Activity Display, DUAL-01) can now build on the Calendar Countdown as one of its two proven single-winner ambient activities.

---
*Phase: 41-calendar-countdown-hud*
*Completed: 2026-07-18*
