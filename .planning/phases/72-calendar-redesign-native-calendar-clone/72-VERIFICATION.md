---
phase: 72-calendar-redesign-native-calendar-clone
verified: 2026-07-31T00:37:00Z
status: passed
score: 9/9 must-haves verified
overrides_applied: 0
deferred:
  - truth: "ROADMAP SC#1's 'day-grouped' agenda clause / SC#3 (day-header grouping, e.g. 'WEDNESDAY, 15 JUL') / 72-01-PLAN.md & 72-03-PLAN.md's whole-month day-grouped-agenda must_haves"
    addressed_in: "Superseded within this same phase (72-CONTEXT.md 'Revised 2026-07-31', 72-04-SUMMARY.md)"
    evidence: "Real on-device UAT during Plan 72-04's checkpoint found the whole-month day-grouped agenda didn't match user intent; user explicitly directed a revert to a single-day agenda (D-01/D-02 marked SUPERSEDED, not silently overwritten). Per task instructions, the current single-day-agenda behavior is the authoritative, user-approved target — treated as a deliberate scope revision, not a gap."
---

# Phase 72: Calendar Redesign — Native Calendar Clone Verification Report

**Phase Goal:** The expanded Calendar view (Phase 28, already shipped) is widened and redesigned into a genuine 1:1 visual clone of macOS's native Calendar app — full month grid on the left, an agenda list on the right — not just Droppy-inspired, matching Calendar.app's own styling as closely as technically possible.
**Verified:** 2026-07-31
**Status:** passed
**Re-verification:** No — initial verification

## Important note on scope revision honored by this report

Per the verification task instructions, a mid-execution, real on-device UAT-driven design revision occurred during Plan 72-04: the whole-month, day-grouped, scroll-to-day agenda built in Plan 72-03 (per the *original* D-01/D-02 decisions) was reverted to a single-day agenda (today or the selected day only, replaced on tap) after the real user rejected the whole-month version live. This is recorded in `72-CONTEXT.md` ("Revised 2026-07-31", D-01/D-02 marked SUPERSEDED) and `72-04-SUMMARY.md`. This report treats the **current single-day-agenda behavior as the authoritative, user-approved target**, per explicit instruction — the original whole-month/day-grouped wording in ROADMAP.md's SC#3, SC#1's "day-grouped" clause, and 72-01/72-03-PLAN.md's original must_haves is treated as superseded, not a gap.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Two-column layout (month grid left, agenda right) renders, reusing existing width-scaling, no clipping at current width | ✓ VERIFIED | `calendarContent` (NotchPillView.swift:1597-1622) is an `HStack` of `monthGridColumn` + divider + `dayListColumn`; `calendarWidth: CGFloat = 472` (line 1014) scales via `resolvedWidthScale` (line 1279, pre-existing Phase 32/46 pattern, no new infra). On-device UAT step 9 (72-04-SUMMARY.md) explicitly confirmed "no visual clipping or crowding at the current island width (472pt) after the cell/font size bumps" — approved. |
| 2 | Month grid visually matches reference: locale-aware weekday header row, today=filled red badge, selected=red ring (mutually exclusive), tightened chevron spacing, red month/year label | ✓ VERIFIED | `rotatedWeekdaySymbols`/`weekdayHeaderRow` (1646-1664) use `Calendar.veryShortWeekdaySymbols` rotated by `firstWeekday` — locale-aware, no hardcoded array. `DayCell` (1701-1730): `.background(Circle().fill(isToday ? Color.red : Color.clear))` + `.overlay(Circle().strokeBorder(isSelected && !isToday ? Color.red : Color.clear, lineWidth: 1.5))` — today and selected-ring never coexist. `ChevronHoverButton`s wrapped in `HStack(spacing: 8)` around `MonthYearPickerButton` (1670-1674). Month/year label `.foregroundStyle(Color.red)` (1771). Day-number font 11px inside 22×22pt cell (`calendarCellSize = 22`, line 867; font size 11, line 1712). On-device UAT step 2 approved this side-by-side against the reference PNG. |
| 3 | Agenda list shows real events with colored accent dot, title, time, matching native row styling as closely as technically possible (day-grouping superseded — see note above) | ✓ VERIFIED | `dayEventsList`/`EventRow` (1877-1891, 4709-4764): color-dot `Circle`, `Text(event.title)`, time `Text`, rounded-card background — row styling intact. Day-grouping (`eventsByDay`) was built (Plan 72-01/72-03), then deliberately removed as dead code after the D-01/D-02 revert (confirmed: `grep -rn eventsByDay` returns zero hits in `CalendarGlance.swift`/`NotchPillView.swift`/`CalendarGlanceTests.swift`) — this is the superseded item noted above, not a regression. |
| 4 | Existing quick-add (CALVIEW-05/06/07) continues to work unchanged inside the redesigned layout | ✓ VERIFIED | `QuickAddPopover` (NotchPillView.swift:5141+) retains its full date/time-picker form, trigger position, and submit guard; only its submit-button font (14→13px, UI-SPEC 4-size scale) and a new D-17 hover border were added — no functional regression. On-device UAT step 8 (create-event regression check) approved. |
| 5 | Editing an event through the redesigned view persists the change in real Calendar.app (D-07/D-09) | ✓ VERIFIED | `EventEditPopover` (5322+) seeds real `event.title/start/end`, guards empty title, calls `onSave(event.id, ...)`. `NotchWindowController.handleEventEdit` (line 2481) calls `calendarService.updateEvent(id:title:start:end:completion:)` → `EventKitService.updateEvent` (`CalendarService.swift:169-185`) does a real `store.event(withIdentifier:)` lookup + `store.save(event, span: .thisEvent)`. Wired at the `NotchPillView(...)` call site (`onEventEdit: { [weak self] ... self?.handleEventEdit(...) }`, line 3159). On-device UAT step 6 confirmed a real title edit round-tripped through Calendar.app — approved. |
| 6 | Deleting an event removes it from Calendar.app immediately, no confirm dialog (D-08) | ✓ VERIFIED | `EventRow`'s trash `Button` (4737-4743) calls `onDelete()` directly, no alert/confirm. `handleEventDelete` (NotchWindowController.swift:2487) calls `calendarService.deleteEvent(id:completion:)` → real `store.remove(event, span: .thisEvent)` (`CalendarService.swift:187-195`). On-device UAT step 5 confirmed real Calendar.app deletion — approved. |
| 7 | Full-title hover tooltip works (D-12) | ✓ VERIFIED | `EventRow`'s title `Text` carries `.help(event.title)` (line 4729) — native OS tooltip, untrusted text never in a custom render path. On-device UAT step 7 approved. |
| 8 | 5 new white hover affordances (D-13 popover trigger is separate; D-14/D-15/D-16/D-17 hover rings/borders) exist and work | ✓ VERIFIED | `DayCell` white hover ring (line 1716, D-14); `ChevronHoverButton` circular white hover fill (1736-1752, D-15); `EventRow` white outline on hover (4753-4756, D-16); `QuickAddPopover` trigger white hover border (5178-5182, D-17); `MonthYearPickerButton` month/year popover (1760-1823, D-13). On-device UAT round 2 approved all, with one documented non-blocking caveat (intermittent hover-detection latency, logged in `deferred-items.md`, attributed to Space-switch/overlay window mechanics, not this phase's `.onHover` code). |
| 9 | Full Debug build succeeds; test suite has no *new* failures vs. documented baseline | ✓ VERIFIED | `xcodebuild build -scheme Islet -destination 'platform=macOS'` re-run independently by this verifier: **BUILD SUCCEEDED**. 72-04-SUMMARY.md documents 587 tests / 7 failures — the same pre-existing 7 (4× `LicenseStateTests`, 3× `SettingsViewTests`), test count dropped 591→587 only because the 4 now-dead `eventsByDay` tests were removed alongside the function itself; confirmed via `deferred-items.md`'s per-plan failure-count trail. |

**Score:** 9/9 truths verified

### Deferred Items

| # | Item | Addressed In | Evidence |
|---|------|-------------|----------|
| 1 | ROADMAP SC#1's "day-grouped" clause / SC#3 (day-header grouping) / original 72-01/72-03 whole-month must_haves | Superseded within Phase 72 itself | `72-CONTEXT.md` "Revised 2026-07-31" section; `72-04-SUMMARY.md` — explicit user-directed on-device UAT revision, not a later phase, but this task's explicit instruction is to treat it as the authoritative target rather than a gap |

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `Islet/Calendar/CalendarGlance.swift` | `EventInput.id` field | ✓ VERIFIED | `struct EventInput` has `let id: String` (line 16) |
| `Islet/Calendar/CalendarService.swift` | `updateEvent`/`deleteEvent` (protocol + impl) | ✓ VERIFIED | Protocol lines 47/54; `EventKitService` impl lines 169/187; both guard-else `completion(false)`, never crash |
| `Islet/Notch/NotchPillView.swift` | `weekdayHeaderRow`, `DayCell` badge swap, `EventRow`, `EventEditPopover`, `MonthYearPickerButton`, `ChevronHoverButton` | ✓ VERIFIED | All present and wired (see truths 2/3/5/6/7/8 evidence above) |
| `Islet/Notch/NotchWindowController.swift` | `handleEventEdit`/`handleEventDelete`/`handleCalendarMonthYearSelect` + closure wiring | ✓ VERIFIED | Lines 2451, 2481, 2487; wired at `NotchPillView(...)` call site lines 3153/3159/3160 |
| `IsletTests/CalendarGlanceTests.swift` | Updated fixtures, no dead `eventsByDay` tests | ✓ VERIFIED | 19 test methods present, zero `eventsByDay` references |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `mapToEventInput(_:)` | `EventInput.id` | `ek.eventIdentifier ?? ""` | ✓ WIRED | `CalendarService.swift:149` — single call site, 1 match |
| `EventRow`'s trash/edit tap | `NotchPillView.onEventEdit`/`onEventDelete` | direct closure forwarding | ✓ WIRED | `dayEventsList` construction (1882-1886) forwards `onEdit: onEventEdit`, `onDelete: { onEventDelete(event.id) }` |
| `NotchPillView.onEventEdit`/`onEventDelete` | `NotchWindowController.handleEventEdit`/`handleEventDelete` | `[weak self]` closure at view-init call site | ✓ WIRED | `NotchWindowController.swift:3159-3160` |
| `handleEventEdit`/`handleEventDelete` | `CalendarService.updateEvent`/`deleteEvent` | direct method call | ✓ WIRED | `NotchWindowController.swift:2481-2491` |
| `weekdayHeaderRow`/`LazyVGrid` | `Self.calendarCellSize`/`calendarCellGap` | shared static constants | ✓ WIRED | Both reference the same constants symbolically (1656-1664, 1678) |
| Month-grid day tap | `dayListColumn`'s rendered day | `onCalendarDaySelect` → `calendarViewState.selectedDay` → `dayEventsList(events(on: selectedDay, ...))` | ✓ WIRED | `handleCalendarDaySelect` (NotchWindowController.swift:2444) sets `selectedDay`; `dayListColumn` (NotchPillView.swift:1833) recomputes `dayEvents` from it directly — replaces rather than scrolls, per the revised D-01/D-02 design |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|---------------------|--------|
| `dayListColumn`/`dayEventsList` | `calendarViewState.monthEvents` | `CalendarService.fetchMonth` → real `EKEventStore` query (`refreshCalendarMonth`, NotchWindowController.swift:2391-2394) | Yes | ✓ FLOWING |
| `DayCell`'s `hasEvents` | `calendarViewState.monthEvents` via `events(on:events:)` | Same real fetch above | Yes | ✓ FLOWING |
| `EventEditPopover`/`EventRow` | `event: EventInput` (real `id`/`title`/`start`/`end`/color from `mapToEventInput`) | `EKEvent` via `EventKitService` | Yes | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Full Debug build succeeds | `xcodebuild build -scheme Islet -destination 'platform=macOS'` | `** BUILD SUCCEEDED **` | ✓ PASS |
| No `eventsByDay` dead code remains | `grep -rn eventsByDay Islet/ IsletTests/` | 0 matches | ✓ PASS |
| `EventInput.id`/`updateEvent`/`deleteEvent` exist and are real EventKit-backed | manual code read (`CalendarService.swift:16,47,54,169-195`) | Confirmed | ✓ PASS |

Interactive hover/scroll/popover/visual-fidelity behavior itself was not re-run by this verifier (requires a running app + real Calendar.app + mouse interaction) — this class of check was already executed and approved during Plan 72-04's `checkpoint:human-verify` gate (real user, real hardware, 2 UAT rounds, second round approved all 14 revised verification steps per `72-04-SUMMARY.md`). This report treats that documented, resume-signal-gated approval as legitimate evidence (a human already signed off in-session), not as an unverified SUMMARY claim — distinguishing it from unverifiable narrative text.

### Probe Execution

No `scripts/*/tests/probe-*.sh`-style probes exist for this phase (Swift/Xcode project, not a script-based migration/tooling phase). Skipped — N/A.

### Requirements Coverage

| Requirement | Source Plan(s) | Description | Status | Evidence |
|-------------|-----------------|--------------|--------|----------|
| CALVIEW-08 | 72-01, 72-03, 72-04 | Two-column layout — full month grid left, agenda list right | ✓ SATISFIED | `calendarContent` HStack (truth 1); agenda mechanism revised to single-day per user-approved on-device UAT (deferred item above), which itself is a form of the "agenda list right" requirement |
| CALVIEW-09 | 72-02, 72-04 | Visual design matches macOS's native Calendar app as closely as technically possible | ✓ SATISFIED | Badge swap, weekday header, chevron spacing, red accents, hover affordances (truths 2, 8); on-device UAT step 2 approved side-by-side against `reference-macos-calendar-widgets.png` |

REQUIREMENTS.md (lines 91-92, 184-185) marks both CALVIEW-08 and CALVIEW-09 as "Complete", mapped to Phase 72 — consistent with this verification. No orphaned requirement IDs found for Phase 72 (all IDs declared across the 4 plans' frontmatter are accounted for above; no additional Phase-72-mapped IDs exist in REQUIREMENTS.md beyond these two).

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| — | — | No `TBD`/`FIXME`/`XXX`/`TODO`/placeholder markers found in any of the 4 files modified by this phase (`CalendarGlance.swift`, `CalendarService.swift`, `NotchPillView.swift`, `NotchWindowController.swift`) | — | none |

3 pre-existing, already-tracked Warnings from the independent code review (`72-REVIEW.md`, not re-litigated here as new findings):
- **WR-01** (info-level for this report): No request-generation guard on `refreshCalendarMonth`'s fetch — a rapid double-navigation could apply a stale month's events over a newer one. Does not block any of this phase's must-haves (single-user, local, no crash) but is a real, still-open latent bug — worth a follow-up.
- **WR-02** (info-level for this report): No `end > start` validation on event create/edit — a user could submit a negative-duration event. Non-blocking for this phase's goal (visual clone + working CRUD), but a real data-quality gap.
- **WR-03** (info-level for this report): `EventInput.id` empty-string fallback could collide across events sharing a nil `eventIdentifier`, breaking `ForEach` identity in an edge case. Non-blocking; documented, accepted risk.

None of these 3 warnings are BLOCKERs against this phase's must-haves — they are correctly scoped as non-blocking code-quality issues by the independent reviewer, and this verifier concurs based on the same code (a rare event-loss/wrong-target-row edge case, not a failure of the phase's core observable truths).

### Housekeeping note (non-blocking)

`.planning/todos/pending/2026-07-19-calendar-month-grid-polish.md` — the todo that was explicitly folded into this phase's scope (D-09 through D-12, per `72-CONTEXT.md`'s canonical_refs) — still exists in `pending/`, not deleted or marked resolved, even though its content (CalendarService update/delete, chevron spacing, day-number font, hover tooltip) was fully implemented. This is a planning-hygiene loose end, not a functional gap — the actual capability it described exists and works.

### Human Verification Required

None — the phase's own `checkpoint:human-verify` gate (Plan 72-04, Task 2) already executed and was approved by the real user across 2 rounds (one triggering the D-01/D-02 design revision), covering every visual-fidelity, hover, scroll/single-day-replace, and Calendar.app round-trip item that would otherwise require human testing.

### Gaps Summary

No blocking gaps. All 9 observable truths derived from ROADMAP.md's Success Criteria and the 4 plans' must_haves are verified against the actual codebase (not just SUMMARY.md claims) — data-layer contracts (EventInput.id, CalendarService.updateEvent/deleteEvent), month-grid visual redesign (weekday header, badge swap, chevron spacing, red accents), agenda + event CRUD (hover-delete, edit popover, tooltip), and controller wiring are all present, substantive, and wired end-to-end. The one deliberate scope revision (whole-month day-grouped agenda → single-day agenda) is explicitly instructed to be treated as the authoritative, user-approved target rather than a gap, and is recorded as a `deferred` item per that instruction. The independent code review's 3 Warnings remain open as non-blocking, already-tracked technical debt (stale-fetch race, missing time-ordering validation, empty-id collision risk) — none of them prevent the phase's goal from being achieved.

---

*Verified: 2026-07-31*
*Verifier: Claude (gsd-verifier)*
