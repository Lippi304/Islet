---
phase: 28-calendar-full-view
verified: 2026-07-13T14:04:32Z
status: human_needed
score: 6/6 must-haves verified
overrides_applied: 0
human_verification:
  - test: "Re-exercise Tray click-through with a non-empty shelf, after the CR-01 code-review fix"
    expected: "With the shelf non-empty and the Tray tab open, clicking in the transparent band below Tray's rendered card (where the additive shelf strip used to be reserved) passes through to whatever is underneath — it must NOT be swallowed by the invisible panel."
    why_human: "Click-through/hit-testing is real AppKit pointer-event runtime behavior (NSPanel.ignoresMouseEvents), not something grep/static-read can confirm. This exact regression class (cr01-clickthrough-or-defeat-gotcha) has recurred multiple times in this codebase already. The fix (isTrayPresentation exclusion) was code-reviewed, applied, and build-gated, but the phase's 6-round on-device UAT approval happened BEFORE this fix existed — no human has clicked through the fixed geometry on a real device yet."
  - test: "Re-exercise quick-add immediately after paging to a different month (CR-02 code-review fix)"
    expected: "After clicking the next/prev-month chevron and then '+ Add' without tapping a day cell first, the created Event/Reminder lands on a day inside the NOW-DISPLAYED month (selectedDay snaps to the 1st of the new month), never on a stale day from the month you navigated away from."
    why_human: "This is a real EventKit write whose correctness (which real calendar day the event/reminder lands on) can only be confirmed by checking Calendar.app/Reminders.app after the interaction — the date-arithmetic fix reads correctly in source but was only verified via build success, not an on-device click-through-and-check round."
---

# Phase 28: Calendar Full View Verification Report

**Phase Goal:** Users get a full calendar view — month grid, day detail, and quick-add — as a third view alongside Home and Tray, sharing one EventKit service layer with the existing glance.
**Verified:** 2026-07-13T14:04:32Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | A third view (Calendar) is reachable via a switcher pill below the expanded island, showing a month grid + selected day's event list | ✓ VERIFIED | `IslandResolver.swift` `case calendarExpanded`, `resolve(selectedView: .calendar)` returns it before Now-Playing (round-4 precedence fix); `NotchPillView.swift` `calendarFullView` renders `LazyVGrid` via `daysInMonth(for:)` + day-list via `events(on:events:)`. Switcher pill is now 4 icons (Home/Tray/Calendar/Weather, user-confirmed round-4 addendum in `28-CONTEXT.md`), all wired via `navCircleButton` at lines 1122-1131. |
| 2 | Selecting a day with no events shows an explicit "No events today" empty state, not a blank area | ✓ VERIFIED | `NotchPillView.swift:593` renders `Text("No events today")` when `dayEvents` (via `calendarViewState.monthEvents.map { events(on:...) }`) is a non-nil empty array; nil (not-yet-loaded) renders nothing, matching Pitfall-4 discipline — never flashes before first fetch. |
| 3 | The user can quick-add a Calendar Event or a Reminder (their choice) without leaving the island | ✓ VERIFIED | `QuickAddPopover` (file-scope private struct, `NotchPillView.swift:1733`) presents a segmented `Picker` (`.event`/`.reminder`), submits via `onQuickAdd` closure → `NotchWindowController.handleQuickAdd` → `CalendarService.createEvent`/`createReminder`. Popover presented via `.popover(isPresented:)`, island never closes. WR-03 empty-title guard confirmed present (`.disabled(...)` + re-trim-and-guard in the action closure). |
| 4 | The full calendar view and the existing Home-glance next-event feature share one EventKit service layer — no duplicated fetch/mapping logic | ✓ VERIFIED | `grep -v '^\s*//' CalendarService.swift \| grep -c "EKEventStore()"` = `1` (single store instance for `fetchUpcoming`/`fetchMonth`/`createEvent`/`createReminder`). WR-04 fix confirmed landed: both fetch methods call a shared private `mapToEventInput(_:)` helper — no duplicated RGB-extraction logic. |
| 5 | Today is selected by default when the calendar view opens, and prev/next month navigation works | ✓ VERIFIED | `handleSwitcherSelect` resets `selectedDay`/`visibleMonth` to `Date()` on entering Calendar (D-07). `handleCalendarMonthChange` advances `visibleMonth` and (CR-02 fix, confirmed in code) snaps `selectedDay` back inside the newly-visible month via `Calendar.current.isDate(_:equalTo:toGranularity:.month)` so quick-add can never silently target a stale month. |
| 6 | Selecting Tray reveals the files view without breaking click-through (D-02, amended round 5 to a dedicated `.trayExpanded` case) | ✓ VERIFIED (code) / _needs on-device re-check_ | `IslandResolver.swift` gained `case trayExpanded` (round-5 amendment, superseding the original additive-shelf-strip plan — documented, user-confirmed in `28-CONTEXT.md`'s round-5 addendum). CR-01 code-review finding (Tray's click-through zone extending 56pt into a phantom transparent band when the shelf has items) was found, fixed (`isTrayPresentation` exclusion at both `NotchWindowController.visibleContentZone()` and `NotchPillView.body`'s outer `.frame`), and build-gated — but the phase's on-device UAT approval predates this fix; no human has re-clicked the corrected zone on a real device. See Human Verification below. |

**Score:** 6/6 truths verified in code; 2 of the 6 have code-level fixes that were never re-exercised on a physical device after landing (see Human Verification Required).

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `Islet/Calendar/CalendarGlance.swift` | `daysInMonth(for:)`, `events(on:events:)` pure functions | ✓ VERIFIED | Both present, Foundation-only, no `Date()`/`Date.now` literals; 4 dedicated unit tests (`CalendarGlanceTests.swift`) covering July-2026 padding, Feb-2028 leap year, sort-ascending, empty-array safety. |
| `Islet/Notch/ViewSwitcherState.swift` | `SelectedView` enum + `ViewSwitcherState` carrier | ✓ VERIFIED | `enum SelectedView { home, tray, calendar, weather }` (weather added round 4, documented addendum) + `ViewSwitcherState: ObservableObject`. |
| `Islet/Calendar/CalendarViewState.swift` | `CalendarViewState` carrier + `QuickAddKind` | ✓ VERIFIED | `visibleMonth`/`selectedDay`/`monthEvents` (nil-means-loading) + `enum QuickAddKind { event, reminder }`. |
| `Islet/Calendar/CalendarService.swift` | `fetchMonth`, `createEvent`, `createReminder` on the existing protocol/conformer | ✓ VERIFIED | All 3 present on protocol + `EventKitService` conformer; `requestFullAccessToReminders()` appears exactly once (lazy, first-use-only, per D-04); single `EKEventStore()` instance confirmed. |
| `project.yml` | Reminders Info.plist keys (D-05) | ✓ VERIFIED | `INFOPLIST_KEY_NSRemindersUsageDescription` + `INFOPLIST_KEY_NSRemindersFullAccessUsageDescription` both present (line 68-69). |
| `Islet/Notch/IslandResolver.swift` | `.calendarExpanded` case + `selectedView` param, amended with `.weatherExpanded`/`.trayExpanded` | ✓ VERIFIED | All 3 new cases present; `resolve(...)` precedence matches the round-4/round-5 addenda (Calendar/Weather/Tray checked before Now-Playing; onboarding/transients still outrank everything). `showsSwitcherRow(for:)` hoisted here per WR-01 fix. |
| `Islet/Notch/NotchPillView.swift` | switcher pill, `calendarFullView`, `weatherFullView`, `trayFullView`, `QuickAddPopover` | ✓ VERIFIED | 4-icon switcher (`navCircleButton` x4), all 3 dedicated full-views present and rendering real data through Plan-01's pure functions; `cameraClearance` constant (WR-02 fix) applied at all padding call sites. |
| `Islet/Notch/NotchWindowController.swift` | state ownership, resolver/geometry wiring, all 4 interaction handlers | ✓ VERIFIED | `handleSwitcherSelect`/`handleCalendarMonthChange`/`handleCalendarDaySelect`/`handleQuickAdd` all present and route through the shared `calendarService`; CR-01/CR-02 fixes present (see Truths table). |
| `Islet/Shelf/ShelfViewState.swift` | `isVisible` single source of truth | ✓ VERIFIED | Simplified to `!items.isEmpty` after round-5 removed `forcedByTray` (dead once Tray became its own resolver case) — matches the round-5 addendum exactly. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `CalendarGlance.swift events(on:events:)` | `NotchPillView.swift calendarFullView` | day-list filters `calendarViewState.monthEvents` through `events(on:events:)` | ✓ WIRED | Confirmed at `NotchPillView.swift:567`. |
| `NotchWindowController.currentPresentation()` | `IslandResolver.resolve(...)` | `selectedView: viewSwitcherState.selectedView` argument | ✓ WIRED | Confirmed passed at the `resolve(...)` call site. |
| `NotchWindowController.visibleContentZone()` | `ShelfViewState.isVisible` | shelf-height computed from `.isVisible`, presentation-aware via `isTrayPresentation` (CR-01 fix) | ✓ WIRED | Confirmed. |
| `NotchWindowController.handleQuickAdd(...)` | `CalendarService.createEvent`/`createReminder` | quick-add routes through the shared `calendarService` | ✓ WIRED | `grep -c "calendarService.createEvent\|calendarService.createReminder"` = 2. |
| `NotchPillView.swift` / `NotchWindowController.swift` `showsSwitcherRow` | single shared definition | WR-01 fix hoists into `IslandResolver.swift` | ✓ WIRED | Both files call the one `showsSwitcherRow(for:)` free function; no duplicated switch remains. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|---------------------|--------|
| `calendarFullView` month grid / day list | `calendarViewState.monthEvents` | `CalendarService.fetchMonth(containing:)` → real `EKEventStore.calendars(for: .event)` query, mapped via `mapToEventInput` | Yes | ✓ FLOWING |
| `weatherFullView` | existing `WeatherGlance`/`WeatherKitService` seam | Reused verbatim, no new fetch | Yes (pre-existing) | ✓ FLOWING |
| `trayFullView` | `shelfViewState.items` | Existing Phase 20/24 drag-in pipeline, unchanged | Yes | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Debug build compiles clean with all Phase 28 code | `xcodebuild build -project Islet.xcodeproj -scheme Islet -configuration Debug -destination 'platform=macOS'` | `** BUILD SUCCEEDED **` | ✓ PASS |
| CALVIEW-04 single-store structural check | `grep -v '^\s*//' Islet/Calendar/CalendarService.swift \| grep -c "EKEventStore()"` | `1` | ✓ PASS |
| All 6 review-flagged fixes present in source (not just claimed in REVIEW-FIX.md) | targeted `grep` for `isTrayPresentation`, CR-02 snap logic, `showsSwitcherRow(for:)`, `cameraClearance`, `trimmingCharacters`+`.disabled`, `mapToEventInput` | All 6 found at the exact locations REVIEW-FIX.md claims | ✓ PASS |
| All 15 commits referenced across 28-04-SUMMARY.md / 28-REVIEW-FIX.md exist in git history | `git cat-file -e <sha>` for each of 15 SHAs | All 15 `FOUND` | ✓ PASS |

`xcodebuild test` was not run (project's own documented headless-hang precedent — the test bundle hosts inside the full `Islet.app`, which boots `NSPanel`/MediaRemote/IOBluetooth and hangs non-interactively; `IsletTests`'s new `CalendarGlanceTests`/`IslandResolverTests` methods were confirmed present by direct file read instead, matching this project's established Cmd-U-is-manual convention).

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|--------------|--------|----------|
| CALVIEW-01 | 28-01, 28-03, 28-04 | Calendar full view as a third view alongside Home/Tray | ✓ SATISFIED | Switcher pill + `.calendarExpanded` case, verified above. Note: REQUIREMENTS.md's own checkbox/table still shows this "Pending" — see Anti-Patterns/bookkeeping note below; this is a documentation-sync gap, not a code gap. |
| CALVIEW-02 | 28-01, 28-03 | Explicit empty state for a day with no events | ✓ SATISFIED | "No events today" state confirmed rendering. |
| CALVIEW-03 | 28-02, 28-03, 28-04 | Quick-add Event or Reminder, user's choice | ✓ SATISFIED | `QuickAddPopover` + `createEvent`/`createReminder`, lazy Reminders permission confirmed single call site. |
| CALVIEW-04 | 28-01, 28-02, 28-04 | Shared EventKit service layer, no duplication | ✓ SATISFIED | Single `EKEventStore()`, shared `mapToEventInput` helper (post WR-04 fix). |

**Orphaned requirements check:** `.planning/REQUIREMENTS.md`'s Phase-28 traceability table lists exactly CALVIEW-01/02/03/04 — matches the 4 IDs claimed across the phase's 4 plans. No orphans.

**Bookkeeping gap (non-blocking):** `.planning/REQUIREMENTS.md` line 34-37 (checkbox list) and line 86-89 (traceability table) still show all 4 CALVIEW IDs as unchecked/"Pending", even though `.planning/ROADMAP.md` line 84 already marks `[x] Phase 28: Calendar Full View ... (completed 2026-07-13)`. This is the same class of drift called out in this project's own memory (`gsd-phase-complete-roadmap-gaps`) — the orchestrator's phase-complete step updates ROADMAP but REQUIREMENTS.md's own checkboxes/table need the same manual pass. Flagged as an Info-level finding for the orchestrator to close when marking the phase done, not a phase-goal failure.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| — | — | No `TBD`/`FIXME`/`XXX`/`TODO`/`PLACEHOLDER` found in any of the 8 files this phase modified | — | None — clean |
| `.planning/REQUIREMENTS.md` | 34-37, 86-89 | CALVIEW-01..04 still marked unchecked/"Pending" despite ROADMAP.md marking the phase complete | ℹ️ Info | Documentation bookkeeping only, not a code defect — see above |
| `Islet/Notch/NotchPillView.swift` | 1064-1082 | IN-01 (REVIEW.md): `blobShape`'s `height:` fallback is dead code (unreachable from any live call site) | ℹ️ Info | Left untouched per REVIEW-FIX.md's declared `fix_scope: critical_warning` — confirmed not fixed, as documented |
| `Islet/Notch/NotchPillView.swift` | 1840-2001 | IN-02 (REVIEW.md): no `#Preview` coverage for `.calendarExpanded`/`.weatherExpanded`/`.trayExpanded` | ℹ️ Info | Left untouched per REVIEW-FIX.md's declared scope — confirmed not fixed, as documented |

No blocker-level anti-patterns found. Both Info items from REVIEW.md were correctly left out of scope by REVIEW-FIX.md (`fix_scope: critical_warning`) and are confirmed still absent from the code — consistent with what was claimed, not silently dropped.

## Human Verification Required

### 1. Tray click-through re-check after the CR-01 fix

**Test:** With one or more files on the shelf (non-empty), open the Tray tab, then click in the area below Tray's rendered files card where the additive shelf strip used to reserve extra height.
**Expected:** The click passes through to whatever app/window is underneath — it must NOT be swallowed by Islet's invisible panel (no phantom interactive band).
**Why human:** Click-through is real `NSPanel.ignoresMouseEvents` runtime behavior, not verifiable by static code read. This regression class has recurred multiple times in this codebase (project memory: `cr01-clickthrough-or-defeat-gotcha`). The fix landed via code review AFTER the phase's 6-round on-device UAT was already approved — no human has exercised the corrected geometry on a real device.

### 2. Quick-add-after-month-navigation re-check after the CR-02 fix

**Test:** Open Calendar, click the next-month (or prev-month) chevron at least once WITHOUT tapping a day cell, then tap "+ Add" and create an Event or Reminder.
**Expected:** The created item lands on a real day inside the now-displayed month (confirm in Calendar.app/Reminders.app) — never silently on a stale day from the month you navigated away from.
**Why human:** This is a real EventKit write; correctness of which calendar day it lands on can only be confirmed by checking the system app after the interaction, not by reading the date-arithmetic fix in isolation.

## Gaps Summary

No code-level gaps. All 4 ROADMAP Success Criteria / CALVIEW-01-04 requirements have real, wired, non-stub implementations, confirmed against the FINAL (amended) decisions recorded in `28-CONTEXT.md`'s round-4/round-5 addenda (4-icon switcher with Weather, "smart Home", dedicated Tray view) rather than the original locked design. Both code-review critical bugs (CR-01, CR-02) and all 4 warnings were confirmed fixed in the actual source, not just claimed in `28-REVIEW-FIX.md`. The only open item is that 2 of those fixes (CR-01's click-through correction, CR-02's stale-month correction) were never re-exercised on a physical device after landing, since the phase's on-device UAT approval predates the code-review pass — hence `status: human_needed` rather than `passed`. A non-blocking documentation-bookkeeping gap (REQUIREMENTS.md checkboxes/table not yet marked complete) was also noted for the orchestrator to close.

---

_Verified: 2026-07-13T14:04:32Z_
_Verifier: Claude (gsd-verifier)_
