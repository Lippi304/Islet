---
phase: 62-timer-pomodoro
plan: 03
subsystem: ui
tags: [swift, swiftui, notchpillview, timeline-view]

requires:
  - phase: 62-timer-pomodoro
    plan: 01
    provides: "TimerActivity.swift's pure TimerMode/TimerPhase/TimerContext/TimerActivity value types + timerPillLabel/validateCustomDurationMinutes/completionSplashText helpers; IslandResolver.swift's .timer/.timerExpanded IslandPresentation cases"
  - phase: 62-timer-pomodoro
    plan: 02
    provides: "TimerActivityState/TimerMonitor's mutation contract this plan's init closures (onTimerPauseResume/onTimerReset/onTimerAddTime/onTimerStop/onStartCountdown/onStartPomodoro) will be wired against by Plan 62-04"
provides:
  - "NotchPillView.swift: timerWings(for:) collapsed pill (live mm:ss + Pomodoro cycle label/dot + completion splash), timerExpandedContent(for:) D-08 4-button expanded control row, timerSetupPicker inline duration/mode picker + startTimerButton Home entry point (D-01..D-05), 6 new init closures (onTimerPauseResume/onTimerReset/onTimerAddTime/onTimerStop/onStartCountdown/onStartPomodoro), presentationSwitch wiring for .timer and .timerExpanded"
affects: [62-04]

tech-stack:
  added: []
  patterns:
    - "timerTick(for:at:) plain (non-@ViewBuilder) helper extracted so a TimelineView content closure never contains a bare switch-statement doing variable assignment — @ViewBuilder tries to build every top-level statement as a View and a Void-typed assignment expression fails with \"type '()' cannot conform to 'View'\"; a single `let tick = timerTick(...)` declaration inside the closure sidesteps this. Shared verbatim by timerWings(for:) and timerExpandedContent(for:)."
    - "durationChipsRow(presets:selectedMinutes:isCustomSelected:) — one shared preset-chip+Custom-chip row reused by the Countdown/Work/Break sections of timerSetupPicker instead of tripling near-identical HStack+chipButton code."

key-files:
  created: []
  modified:
    - Islet/Notch/NotchPillView.swift

key-decisions:
  - "TIMER-03 (completion HUD splash + notification sound) NOT marked Complete in REQUIREMENTS.md despite being listed in this plan's frontmatter requirements array — this plan only builds the SPLASH RENDERING (timerWings' .completed/.segmentDone branch); the system notification sound (D-12, the other half of TIMER-03) is Plan 62-04's controller-wiring job. Marking it complete here would be premature."

patterns-established: []

requirements-completed: []

duration: ~35min
completed: 2026-07-24
---

# Phase 62 Plan 03: Timer/Pomodoro View Layer Summary

**The entire Timer/Pomodoro view layer in NotchPillView.swift — collapsed pill live countdown, D-08's 4-button expanded control row, and the Home "Start Timer" duration/mode picker — built entirely from existing primitives (wingsShape/blobShape/navCircleButton/chipButton/formatMMSS), zero new visual primitives.**

## Performance

- **Duration:** ~35 min
- **Completed:** 2026-07-24
- **Tasks:** 3/3 completed
- **Files modified:** 1 (NotchPillView.swift)

## Accomplishments

- `timerWings(for:)` — the collapsed pill: live `mm:ss` countdown for `.running`/`.paused` via one shared `TimelineView` tick closure (icon/label/digits computed together, no desync risk), optional Pomodoro `"Work · Cycle N"`/`"Break · Cycle N"` label (D-07) with a green live-session dot shown only during the Work segment, and a standard 14pt checkmark + copy completion splash for `.completed`/`.segmentDone` (Open Question 2 resolved: NOT the 28px `homeEmptyContent` icon scale). Mirrors `downloadWings`' margin/leftWidth/rightWidth/assert baseline verbatim.
- `timerExpandedContent(for:)` — the first `IslandPresentation` case with its own dedicated top-level `presentationSwitch` arm (Pattern 4, placed right after `.quickActionPicker`), rendering the live countdown above exactly 4 `navCircleButton`s: Pause/Resume (filled, glyph toggles `pause.fill`↔`play.fill`), Reset/Add-Time/Stop (outlined) — Stop deliberately not color-coded red per 62-UI-SPEC.md.
- `timerSetupPicker` + `startTimerButton` — the "Start Timer" chip (D-01 exact wording) reachable from all 3 Home sub-states (Now Playing/Last Played via `mediaContent`, Nothing Playing via `homeEmptyContent`), gated on the existing `ActivitySettings.timerKey` `@AppStorage`. Opens an inline `Countdown`/`Pomodoro` segmented picker (D-03) with preset+custom duration chips (D-02/D-04/D-05); every custom entry is validated through `validateCustomDurationMinutes(_:)` before ever reaching `onStartCountdown`/`onStartPomodoro` — an invalid entry blocks dismissal and shows the locked `"Enter a number between 1 and 180."` copy (T-62-04).
- 6 new init closures added: `onTimerPauseResume`/`onTimerReset`/`onTimerAddTime`/`onTimerStop`/`onStartCountdown`/`onStartPomodoro`, all defaulted to no-ops so existing `#Preview`s keep compiling without a controller.
- Full `IsletTests` suite (509 tests): 505/509 green — the same 4 pre-existing, out-of-scope failures documented in `deferred-items.md` (`CalendarGlanceTests` x2, `ClipboardFileStoreTests`, `SettingsViewTests`), zero new regressions from any of the 3 tasks.

## Task Commits

Each task was committed atomically:

1. **Task 1: timerWings(for:) — collapsed pill + completion splash** - `783c957` (feat)
2. **Task 2: timerExpandedContent(for:) — D-08 expanded control row** - `4b58981` (feat)
3. **Task 3: Duration/mode picker + "Start Timer" Home entry (D-01..D-05)** - `66047ee` (feat)

**Plan metadata:** (this commit, docs: complete plan)

## Files Created/Modified

- `Islet/Notch/NotchPillView.swift` — `timerWings(for:)`, `timerTick(for:at:)` (shared plain helper), `timerAccessibilityLabel(for:)`, `timerExpandedContent(for:)`, `startTimerButton`, `durationChipsRow(presets:selectedMinutes:isCustomSelected:)`, `timerSetupPicker`, `startTimerSetup()`, 6 new init closures, 1 new `@AppStorage` (`timerEnabled`), 11 new `@State` properties, `presentationSwitch` wiring for `.timer`/`.timerExpanded`, `tabContentView`'s 3 new `where isTimerSetupPresented` guarded arms.

## Decisions Made

- Extracted `timerTick(for:at:)` as a plain (non-`@ViewBuilder`) helper function shared by both `timerWings(for:)` and `timerExpandedContent(for:)` — see Deviations below for why this was necessary, not optional.
- `durationChipsRow(...)` extracted as a small shared helper for the 3 nearly-identical preset+Custom chip rows (Countdown/Work/Break) rather than tripling the same ~10 lines of `chipButton` calls inline.
- TIMER-03 left `Pending` in `REQUIREMENTS.md` (see key-decisions above) — the splash rendering this plan built is only half the requirement; the notification sound is Plan 62-04's job.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] TimelineView content closure could not contain a bare switch-statement doing assignment**
- **Found during:** Task 1 build verification (first `xcodebuild` attempt)
- **Issue:** The plan's literal instruction ("computing `remaining` ... inside the single TimelineView tick closure") was implemented as a `let remaining: TimeInterval; let timerContext: TimerContext; switch activity { case ...: remaining = ...; timerContext = ... }` block directly inside `TimelineView(...) { context in ... }`'s trailing closure. `TimelineView`'s `content:` parameter is `@ViewBuilder`-annotated, and `@ViewBuilder` attempts to interpret every top-level statement as a view-building expression — the bare assignment statements (`remaining = ...`, type `Void`) failed with "type '()' cannot conform to 'View'".
- **Fix:** Extracted the switch into a plain (non-`@ViewBuilder`) helper function `timerTick(for activity: TimerActivity, at date: Date) -> (remaining: TimeInterval, context: TimerContext)`, called via a single `let tick = timerTick(for: activity, at: context.date)` declaration inside the closure — `@ViewBuilder` tolerates `let`/`var` declarations without invoking `buildExpression` on them, only on bare statement expressions. Shared by both `timerWings(for:)` (Task 1) and `timerExpandedContent(for:)` (Task 2), so the fix paid for itself twice.
- **Files modified:** Islet/Notch/NotchPillView.swift
- **Verification:** Debug build succeeds after the fix; the shared helper is used identically in both call sites, so the "desync" invariant (icon/label/digits all derived from one computed value per tick) is preserved.
- **Committed in:** `783c957` (Task 1 commit; Task 2 reused the same helper with no further changes needed)

**2. [Rule 1 - Bug] Self-verification grep collision on `"Start Timer"`**
- **Found during:** Task 3 self-verification (acceptance criteria grep check)
- **Issue:** An explanatory comment above the new `timerEnabled` `@AppStorage` property contained the literal string `"Start Timer"` in backticks, which the acceptance criterion's own grep (`grep -n '"Start Timer"' ... returns exactly 1 match`) would false-positive against (2 matches instead of 1) — mirrors the identical self-verification-grep class of fix Plan 62-01 already applied to its own `preempt()` comment.
- **Fix:** Reworded the comment to reference `startTimerButton` (the symbol name) instead of the literal button-label string.
- **Files modified:** Islet/Notch/NotchPillView.swift
- **Verification:** `grep -n '"Start Timer"' Islet/Notch/NotchPillView.swift` returns exactly 1 match (the real `chipButton("Start Timer")` call site); build still green.
- **Committed in:** `66047ee` (Task 3 commit)

---

**Total deviations:** 2 auto-fixed (1 blocking `@ViewBuilder` compile fix affecting both Tasks 1 and 2, 1 self-verification wording fix in Task 3)
**Impact on plan:** Both fixes were mechanical corrections needed to make the plan's own literal instructions compile/pass their own acceptance criteria — zero product-behavior change, zero scope creep.

## Issues Encountered

None beyond the 2 deviations documented above. `xcodebuild test` (headless, per `.planning/PROJECT.md`'s documented hang caveat) completed normally this session in ~132s with no hang.

## User Setup Required

None — no external service configuration required. `timerEnabled` defaults to `false` (Settings toggle exists from Phase 59's Settings-Redesign foundation; this plan reads the same key, no new Settings UI needed).

## Next Phase Readiness

- `timerWings(for:)`, `timerExpandedContent(for:)`, `timerSetupPicker`/`startTimerButton`, and all 6 new init closures are locked and build-verified — Plan 62-04 (controller wiring: constructing `TimerActivityState`/`TimerMonitor`, forwarding the 6 closures to their real mutation methods, playing the D-12 completion sound, and the on-device UAT checkpoint) can build directly against this contract with no further view-layer changes expected.
- Full on-device visual verification (wing width tuning, expanded-box content fit, picker layout) is explicitly deferred to Plan 62-04's checkpoint per this plan's own `<verification>` section — nothing here has been visually confirmed on real hardware yet.
- No blockers. TIMER-03 stays `Pending` in `REQUIREMENTS.md` until Plan 62-04 wires the completion notification sound.

---
*Phase: 62-timer-pomodoro*
*Completed: 2026-07-24*

## Self-Check: PASSED

`Islet/Notch/NotchPillView.swift` confirmed present on disk; all 3 task commits (783c957, 4b58981, 66047ee) confirmed in git log.
