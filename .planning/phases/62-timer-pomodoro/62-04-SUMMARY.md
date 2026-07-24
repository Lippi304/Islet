---
phase: 62-timer-pomodoro
plan: 04
subsystem: ui
tags: [swift, swiftui, appkit, notchwindowcontroller, notchpillview, islandresolver, on-device-uat]

requires:
  - phase: 62-timer-pomodoro
    plan: 01
    provides: "TimerActivity.swift's pure value types + helpers, IslandResolver.swift's .timer/.timerExpanded cases and generalized isPersistent/preempt()"
  - phase: 62-timer-pomodoro
    plan: 02
    provides: "TimerActivityState's session mutation layer, TimerMonitor's one-shot deadline scheduler"
  - phase: 62-timer-pomodoro
    plan: 03
    provides: "NotchPillView's timerWings/timerExpandedContent/timerSetupPicker view layer"
provides:
  - "NotchWindowController.swift: TimerActivityState/TimerMonitor construction and wiring, all 6 NotchPillView closures forwarded to real handlers, NSSound.beep() completion sound (D-12/D-13), Pattern 4 dual-enqueue Pomodoro segment auto-advance, generalized preempt() call-site cleanup (SC5) at deviceCoordinator/downloadCoordinator"
  - "IslandResolver.swift: .timerSetup IslandPresentation case (Timer's own idle duration/mode picker tab), resolve() branch, showsSwitcherRow inclusion"
  - "ViewSwitcherState.swift: SelectedView.timer case — Timer as a fixed 5th switcher-tab icon, not one of the 4 configurable slots"
  - "TimerActivity.swift: parseCustomDurationSeconds(_:) — plain-minutes or M:SS custom-duration parsing, 999-minute-equivalent cap"
  - "TimerActivityState.swift: startCountdown/startPomodoro widened from whole minutes to whole seconds, enabling sub-minute custom durations"
  - "NotchPillView.swift: Timer's own dedicated 5th switcher tab (.timerSetup) replacing the original inline Home-overlay picker, adaptive per-mode picker sizing, selected-chip visual state, CustomDurationChip's .popover-based text entry (works around the nonactivatingPanel focus limitation), fully camera-clearance-correct collapsed-pill layout for both Countdown and Pomodoro"
affects: [63-meeting-hud]

tech-stack:
  added: []
  patterns:
    - "TextField-in-popover: any editable text field hosted inside NotchPillView's content MUST be presented via `.popover`, never inline — the whole view tree lives inside a `.nonactivatingPanel` (canBecomeKey/canBecomeMain == false) so an inline TextField can never become first responder. Proven twice now (QuickAddPopover, Phase 28; CustomDurationChip, this plan)."
    - "Collapsed-wing camera-clearance margin must scale with content type, not get copied from an unrelated wing: an icon-only wing (downloadWings, margin=20) and a long-text-label wing (capsLockWings, margin=65, on-device-confirmed) need genuinely different clearance: text sitting close to the camera cutout clips even when the wing's own internal box math looks correct on paper. Verify against real NSFont/NSAttributedString metrics, not estimated character counts, when tuning a new wing's content width."
    - "flushTransients(_:) never calls renderPresentation() itself — every caller must render/updateVisibility/syncClickThrough afterward in its own context, mirroring handleSettingsChanged()'s trailing unconditional render. A standalone caller that forgets this renders a stale presentation forever (real bug found and fixed in handleTimerStop())."

key-files:
  created:
    - .planning/phases/62-timer-pomodoro/62-04-SUMMARY.md
  modified:
    - Islet/Notch/NotchWindowController.swift
    - Islet/Notch/NotchPillView.swift
    - Islet/Notch/IslandResolver.swift
    - Islet/Notch/ViewSwitcherState.swift
    - Islet/Notch/TimerActivity.swift
    - Islet/Notch/TimerActivityState.swift
    - IsletTests/TimerActivityTests.swift
    - IsletTests/TimerActivityStateTests.swift
    - .planning/phases/62-timer-pomodoro/deferred-items.md
    - .planning/REQUIREMENTS.md

key-decisions:
  - "Timer moved OUT of Home into its own dedicated 5th switcher-tab (SelectedView.timer / IslandPresentation.timerSetup) mid-UAT (round 1) — the originally-planned inline picker overlaid on Home's 3 sub-states badly overflowed for Pomodoro and conflated two unrelated concerns (Now Playing vs Timer setup) in one tab. Timer is a FIXED icon appended after the 4 configurable switcher slots, not itself configurable, gated on the existing timerEnabled toggle."
  - "Custom-duration cap raised 180 -> 999 minutes (round 1), then the format itself widened to accept M:SS (round 5-6) — TimerActivityState.startCountdown/startPomodoro's public API was widened from whole-Int minutes to whole-Int seconds end-to-end (the internal TimeInterval deadline math was already seconds-granular; only the entry API needed changing) so a custom '5:30' entry reaches TimerMonitor's deadline arithmetic exactly, not rounded to a whole minute."
  - "The Pomodoro collapsed-pill dot/label clipping (rounds 3, 4, 6) was root-caused only in round 6: the camera-clearance margin (20, copied from the icon-only downloadWings) was the actual bug, not the content-side box width rounds 3-4 kept tuning. Fixed by reusing capsLockWings' own on-device-proven margin (65) for text-adjacent content, verified against real NSFont metrics rather than guessed pixel counts."

patterns-established:
  - "Pattern 4 dual-enqueue (Timer Pomodoro auto-advance): updateHead() the just-elapsed segment's splash, then preempt() the next running segment — TransientQueue.advance()'s existing generic promotion mechanism carries the next segment in with zero new queue mechanics once the splash's shared ~3s dismiss elapses."

requirements-completed: [TIMER-01, TIMER-02, TIMER-03, TIMER-04]

duration: multi-session (checkpoint, 6 on-device UAT rounds)
completed: 2026-07-24
---

# Phase 62 Plan 04: Timer/Pomodoro Controller Wiring & On-Device UAT Summary

**Wired TimerActivityState/TimerMonitor into NotchWindowController end-to-end (deadline-fire orchestration, NSSound.beep() completion sound, Pomodoro auto-advance, SC5 preempt() cleanup), then iterated through 6 rounds of on-device UAT that moved Timer to its own switcher tab, added M:SS custom-duration parsing, and root-caused a persistent collapsed-pill camera-cutout text clip to a copy-pasted wing-clearance constant.**

## Performance

- **Duration:** multi-session (checkpoint, 6 on-device UAT rounds)
- **Completed:** 2026-07-24
- **Tasks:** 3/3 completed (Task 3 = the on-device UAT checkpoint, approved after 6 rounds)
- **Files modified:** 9 (7 source/test files, `deferred-items.md`, `REQUIREMENTS.md`)

## Accomplishments

- `NotchWindowController.swift` — `TimerActivityState`/`TimerMonitor` constructed alongside `downloadCoordinator`; all 6 `NotchPillView` Timer closures (`onStartCountdown`/`onStartPomodoro`/`onTimerPauseResume`/`onTimerReset`/`onTimerAddTime`/`onTimerStop`) forwarded to real handlers; `handleTimerDeadlineReached()` plays `NSSound.beep()` (D-12/D-13) and drives Pattern 4's dual-enqueue so a Pomodoro segment transition auto-promotes the next segment with zero extra taps; `deviceCoordinator`/`downloadCoordinator`'s `enqueue` closures simplified to the generalized `preempt(t)` call, closing the SC5 Download-Progress preemption gap at the real call sites.
- Full Timer/Pomodoro feature on-device-approved after 6 UAT rounds: live countdown, pause/resume/reset/add-time/stop, completion splash+sound (including while unfocused), Pomodoro work/break auto-advance with cycle counting, Charging/Device interruption-and-resume (SC5), Settings toggle-off force-stop, and Calendar-tab-priority-over-Timer-controls.
- Timer promoted from an inline Home overlay to its own dedicated 5th switcher tab (`SelectedView.timer` / `IslandPresentation.timerSetup`), with an adaptive-height duration/mode picker (compact for Countdown, taller for Pomodoro) and a clear selected-chip visual state.
- Custom-duration entry widened from "whole minutes only, capped at 180" to "whole minutes or M:SS, capped at the 999-minute equivalent in seconds" — `TimerActivityState.startCountdown`/`startPomodoro`'s public API widened end-to-end from minutes to seconds to carry the extra precision through to the actual deadline.
- Root-caused a collapsed-pill camera-cutout text clip that survived 3 rounds of content-box tuning: the wing's own camera-clearance `margin` (20, copied from an icon-only sibling wing) was the actual bug. Fixed by reusing `capsLockWings`' own on-device-proven `margin=65` for text-adjacent content, with the fix verified against real `NSFont`/`NSAttributedString` metrics rather than another guessed pixel width.
- Full `IsletTests` suite: 509/509 (excluding 2 documented manual-only hardware-spike tests) with the same 4 pre-existing, unrelated failures throughout every round — zero regressions introduced across the whole plan.

## Task Commits

Each task was committed atomically; Task 3 (the on-device UAT checkpoint) generated 5 additional fix/feature commits across 6 rounds before approval:

1. **Task 1: Construction, closure wiring, settings gating, SC5 call-site cleanup** - `50cd6a3` (feat)
2. **Task 2: Handler bodies, deadline-fire orchestration, geometry Site 3** - `7b74784` (feat)
3. **Task 3: On-device UAT** (checkpoint, approved after 6 rounds):
   - Round 1 (bugs + design changes: unresponsive custom field, non-functional expanded buttons, collapsed-pill alignment, duration cap, adaptive picker sizing, Timer's own switcher tab) - `589a4be` (fix)
   - Round 2 (layout polish: per-mode picker box sizing, padding, button spacing, selected-chip state) - `dcc07f5` (fix)
   - Round 3 (collapsed-pill spacing: dot/label clip investigation, per-mode width budget) - `5245286` (fix)
   - Round 5 (M:SS custom-duration parsing feature) - `7fb9096` (feat)
   - Round 6 (root-cause fix: camera-clearance margin, not content-box width) - `b09a001` (fix)

**Plan metadata:** (this commit, docs: complete plan)

## Files Created/Modified

- `Islet/Notch/NotchWindowController.swift` — Timer construction/wiring, deadline-fire orchestration, `.timerSetup` geometry (Sites 2/3), `handleTimerStop()`'s missing-render fix
- `Islet/Notch/NotchPillView.swift` — `.timerSetup` switcher tab, adaptive picker sizing, `CustomDurationChip` (`.popover`-based text entry + M:SS format), selected-chip state on `chipButton`, collapsed-pill (`timerWings`) and expanded-control (`timerExpandedContent`) layout fixes
- `Islet/Notch/IslandResolver.swift` — `.timerSetup` `IslandPresentation` case, `resolve()` branch, `showsSwitcherRow` inclusion
- `Islet/Notch/ViewSwitcherState.swift` — `SelectedView.timer` case
- `Islet/Notch/TimerActivity.swift` — `parseCustomDurationSeconds(_:)` (supersedes `validateCustomDurationMinutes`)
- `Islet/Notch/TimerActivityState.swift` — `startCountdown`/`startPomodoro` widened minutes -> seconds
- `IsletTests/TimerActivityTests.swift` / `IsletTests/TimerActivityStateTests.swift` — updated/extended for the seconds-based API and the new parser
- `.planning/phases/62-timer-pomodoro/deferred-items.md` — logged one flaky manual-only spike test observed during a full-suite run
- `.planning/REQUIREMENTS.md` — TIMER-01..04 marked Complete

## Decisions Made

See `key-decisions` in frontmatter — Timer's move to its own switcher tab, the seconds-granular custom-duration API widening, and the camera-clearance-margin root cause are the three decisions with the most carry-forward relevance for future wings/tabs.

## Deviations from Plan

The plan's own scope (controller wiring + on-device UAT) was executed as written for Tasks 1-2. Task 3's on-device UAT then surfaced substantial UAT-driven revisions across 6 rounds — all pre-approved by the user/coordinator ("implement everything directly, use your own judgment") rather than re-litigated as scope-creep asks. Documented here per the standard deviation-logging convention.

### Auto-fixed Issues (bugs found during UAT)

**1. [Rule 1 - Bug] Custom-duration TextField completely unresponsive**
- **Found during:** Task 3, round 1
- **Issue:** The Custom-duration TextField, embedded inline in `NotchPillView`'s content, could never receive keyboard focus — the whole view is hosted inside a `.nonactivatingPanel` (`NotchWindowController` sets `canBecomeKey`/`canBecomeMain == false`), a hard AppKit constraint no SwiftUI binding fix can work around.
- **Fix:** Presented the TextField inside a `.popover` instead (`CustomDurationChip`) — a popover opens its own separate, key-capable window, the same mechanism `QuickAddPopover` (Phase 28, Calendar quick-add) already proved works in this exact architecture.
- **Files modified:** `Islet/Notch/NotchPillView.swift`
- **Verification:** Debug build green; on-device UAT round 2+ confirmed the field is editable.
- **Committed in:** `589a4be`

**2. [Rule 1 - Bug] Expanded Stop button silently did nothing**
- **Found during:** Task 3, round 1
- **Issue:** `handleTimerStop()` called `flushTransients(.timer)` standalone; `flushTransients(_:)` itself never calls `renderPresentation()` (every other caller relies on a render happening elsewhere in the same call context, e.g. `handleSettingsChanged()`'s own trailing unconditional render) — so `presentationState.presentation` never updated and the view kept rendering the stale `.timerExpanded` screen forever.
- **Fix:** `handleTimerStop()` now renders/updates visibility/click-through itself, mirroring the Settings-toggle-off pattern. Pause/Reset/Add-Time's own chain was re-verified correct (a defensive `syncClickThrough()` call and an alignment-consistency normalization were added, but no further logic bug was found there).
- **Files modified:** `Islet/Notch/NotchWindowController.swift`
- **Verification:** Debug build green; on-device UAT round 2+ confirmed all 4 expanded buttons work.
- **Committed in:** `589a4be`

**3. [Rule 1 - Bug] Pomodoro dot/"Work"/"Break" text clipped by the camera cutout — 3 rounds to root-cause**
- **Found during:** Task 3, rounds 1, 3, 4, 6
- **Issue:** The collapsed-pill countdown text was first "centered under the notch" (round 1), then repeatedly still clipped by the camera cutout after 3 rounds of content-box-width tuning (rounds 3-4: 130 -> 145, alignment flipped to `.trailing`, a `Spacer(minLength:0)`-based overflow-direction fix, a per-mode width budget split). None of these eliminated the clip because the actual bug was never the content box: `timerWings`' camera-clearance `margin` (20) was copied verbatim from the icon-only `downloadWings`, drastically insufficient for a >10-character text label sitting immediately after it. `capsLockWings` had already solved this exact problem class and documents the fix in its own on-device-measured comment history (`margin=65`, confirmed minimum after `55` still clipped comparable text).
- **Fix:** Reused `capsLockWings`' own proven `margin=65` for the Pomodoro-labeled case (Countdown's short digit-only content keeps `margin=20`, unaffected). Rebalanced the content-side box (144pt) and label font (11pt, digits stay 13pt) to fit the now-larger camera reservation within the shared ~325pt safe panel-frame budget, with every number verified against real `NSFont`/`NSAttributedString` metrics rather than estimated.
- **Files modified:** `Islet/Notch/NotchPillView.swift`
- **Verification:** Debug build green; geometry re-verified via a standalone Swift script measuring real font metrics against the budget and the leftWidth/rightWidth assert at both the fallback and real-hardware notch widths; on-device UAT round 6 (final round) confirmed fully visible, user typed "approved".
- **Committed in:** `5245286` (rounds 3-4 partial fixes), `b09a001` (round 6 root-cause fix)

### Auto-added Missing Functionality / Requested Design Changes (Rule 2 / user-directed)

**4. [Design change, user-directed] Custom-duration cap raised 180 -> 999 minutes, then format widened to accept M:SS**
- **Found during:** Task 3, rounds 1 and 5-6
- **Change:** `validateCustomDurationMinutes` (cap 1-180) -> raised cap to 1-999 (round 1) -> superseded by `parseCustomDurationSeconds` (round 5-6), accepting a plain number (whole minutes, unchanged shorthand) or `M:SS` (e.g. "5:30" -> 330s), same 999-minute-equivalent ceiling expressed in seconds. `TimerActivityState.startCountdown`/`startPomodoro` widened from whole-Int minutes to whole-Int seconds end-to-end so the extra precision reaches the real deadline arithmetic.
- **Files modified:** `Islet/Notch/TimerActivity.swift`, `Islet/Notch/TimerActivityState.swift`, `Islet/Notch/NotchWindowController.swift`, `Islet/Notch/NotchPillView.swift`, both Timer test files
- **Verification:** New/updated unit tests (`testParseCustomDurationSecondsPlainMinutes`/`ColonFormat`/`Bounds`); Debug build green; on-device UAT round 6 confirmed "0:30", "5:30", and plain "5" each produce the expected duration.
- **Committed in:** `589a4be` (cap raise), `7fb9096` (M:SS format)

**5. [Design change, user-directed] Timer moved to its own dedicated 5th switcher tab**
- **Found during:** Task 3, round 1
- **Change:** The originally-planned inline "Start Timer" button + picker overlay on Home's 3 sub-states overflowed badly for Pomodoro and conflated Now-Playing and Timer-setup concerns in one tab. Replaced with a new `SelectedView.timer` case (a FIXED 5th switcher icon, not one of the 4 configurable slots) and a new `IslandPresentation.timerSetup` case with its own adaptively-sized picker box (compact for Countdown, taller for Pomodoro).
- **Files modified:** `Islet/Notch/ViewSwitcherState.swift`, `Islet/Notch/IslandResolver.swift`, `Islet/Notch/NotchPillView.swift`, `Islet/Notch/NotchWindowController.swift` (geometry Sites 2/3)
- **Verification:** Debug build green; full `IsletTests` suite green throughout; on-device UAT rounds 2-6 confirmed the tab navigates correctly and never conflicts with an active Timer transient (which still always wins per D-04, unchanged).
- **Committed in:** `589a4be`

**6. [Polish, user-directed] Selected-chip visual state**
- **Found during:** Task 3, round 2
- **Change:** Duration/mode chips (Countdown, Pomodoro Work, Pomodoro Break, each independent) had no visual indication of which was chosen. Added an optional `selected: Bool` parameter to the shared `chipButton` helper (brighter fill + white border ring, mirrors `navCircleButton`'s existing filled/outlined convention) — defaults `false` so every pre-existing `chipButton` call site (Grant/License/Buy) is visually unchanged.
- **Files modified:** `Islet/Notch/NotchPillView.swift`
- **Verification:** Debug build green; on-device UAT round 3+ confirmed the selected state is visible.
- **Committed in:** `dcc07f5`

---

**Total deviations:** 3 auto-fixed bugs (2 straightforward, 1 requiring 3 UAT rounds to root-cause), 3 user-directed design/polish changes beyond the original plan scope.
**Impact on plan:** All changes were either genuine bug fixes (Rule 1) or explicitly user-approved scope expansions during the plan's own on-device UAT checkpoint — no unrequested scope creep. The plan's original architecture (TimerActivityState/TimerMonitor construction, Pattern 4 dual-enqueue, SC5 cleanup) needed zero changes across all 6 rounds; every revision was in the view/controller wiring layer UAT is specifically meant to catch.

## Issues Encountered

- One flaky test observed during a full-suite run: `AudioOutputMonitorManualSpike.testManualDeviceEnumerationAndSwitch()` (Phase 47, unrelated to Timer) — its own file header explicitly says "DO NOT RUN VIA `xcodebuild test`" (needs real CoreAudio hardware + a 15s wait); a pre-existing, documented headless-run hazard, not a regression. Logged to `deferred-items.md`; re-confirmed clean (509/509, same 4 pre-existing failures) with that spike excluded.
- Headless `xcodebuild test` (per `.planning/PROJECT.md`'s documented Bluetooth-TCC-authorization-wait hang caveat) ran without hanging throughout this plan's entire execution.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- Phase 62 (Timer/Pomodoro) is code-complete and fully on-device UAT-approved. All 4 requirements (TIMER-01..04) and ROADMAP Success Criterion 5 (SC5, the generalized `preempt()`) are demonstrated working on real hardware.
- Zero regressions in any pre-existing transient category (Charging/Device/Focus/OSD/CapsLock/UpdateAvailable/Download) from the `preempt()`/`enqueue()` call-site simplification — re-verified across all 6 UAT rounds.
- `.timerSetup`'s three-site geometry pattern (Site 1 `tabHeight`, Site 2 `positionAndShow`'s panel union, Site 3 `visibleContentZone`'s click-through) and the camera-clearance-margin lesson (verify against real font metrics for any wing with adjacent text, don't copy an icon-only wing's margin) are both directly reusable for Phase 63's Meeting HUD, which also needs its own dedicated expanded presentation and collapsed-pill text.
- No blockers.

---
*Phase: 62-timer-pomodoro*
*Completed: 2026-07-24*

## Self-Check: PASSED

All 9 modified files confirmed present on disk; all 7 task/round commits (`50cd6a3`, `7b74784`, `589a4be`, `dcc07f5`, `5245286`, `7fb9096`, `b09a001`) confirmed in git log.
