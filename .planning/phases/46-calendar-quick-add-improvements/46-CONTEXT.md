# Phase 46: Calendar Quick-Add Improvements - Context

**Gathered:** 2026-07-19
**Status:** Ready for planning

<domain>
## Phase Boundary

The calendar full view's quick-add popover (`QuickAddPopover` in `Islet/Notch/NotchPillView.swift`) currently has no date/time UI at all — it hardcodes the Event's start to the selected day and end to start+1hr, and the Reminder's due date to the selected day. This phase adds a real date+time picker to that popover, relocates the "+ Add" trigger button, and gives event rows in the day list more breathing room (with the island growing slightly to accommodate it). No new capabilities — pure UI/UX refinement of an already-shipped feature (Phase 28).

1. **CALVIEW-05** — quick-add gains a date+time picker (start/end range for Events, single time for Reminders), defaulting to the tapped day + next full hour (today) or 00:00 (other days).
2. **CALVIEW-06** — the "+ Add" button moves from its currently-clipped right edge to the left, next to the day-list divider.
3. **CALVIEW-07** — day-list event rows get visibly more padding/margin; the island grows a few pt wider and gains extra height to fit.

</domain>

<decisions>
## Implementation Decisions

### Date+time picker UI & editability
- **D-01:** The date itself stays LOCKED to the calendar day the user tapped (`calendarViewState.selectedDay`) — no editable date field in the popover. Only time is a real picker. Matches the requirement wording ("defaulting to the tapped calendar day") and keeps the popover small.
- **D-02:** Use SwiftUI's `.datePickerStyle(.compact)` for the time field(s) — small tappable field with native macOS time-selection UI, minimal vertical footprint, consistent with the rest of the app's system-native control conventions.
- **D-03:** For Events, Start and End are two separate compact `DatePicker`s, each on its own labeled row ("Starts" / "Ends") inside the existing `VStack(alignment: .leading, spacing: 8)` — not a single side-by-side row.
- **D-04:** When the user changes Start, End auto-follows to preserve a 1-hour duration — until the user manually edits End themselves, after which End stops auto-following Start. Least friction for the common case, still fully overridable.
- **D-05 (Reminder):** Reminder popover hides the End field entirely (no disabled/greyed control) — only a single time field is shown, labeled **"Due"** (matches EventKit's `dueDate` terminology).

### Add-button placement
- **D-06:** Button stays in the day-list column's existing top row — flip the current `HStack { Spacer(); QuickAddPopover(...) }` to `HStack { QuickAddPopover(...); Spacer() }` so it sits at the left edge of the day-list column, immediately next to the vertical divider between the month grid and day list. No structural move out of `dayListColumn`.
- **D-07:** The popover must be forced to open toward the day list (right/trailing), e.g. `arrowEdge: .trailing` or equivalent, so it never overlaps the narrow month-grid column on the left — avoids reintroducing a clipping problem in a new spot, which is the whole motivation for CALVIEW-06 in the first place.

### Row padding & island growth
- **D-08:** Calendar gets its OWN height override (a new `calendarContentHeight` constant, analogous to Phase 44's `trayContentHeight` = 117 for Tray) rather than growing the shared `switcherContentHeight` (196, used by Home/Weather/default). Home and Weather stay untouched. Phase 45's morph fix already handles animating between differing per-tab heights, so this is established precedent, not a new risk.
- **D-09:** Row padding target: ~12pt horizontal / ~8pt vertical padding (was 8h/5v), ~8pt inter-row spacing (was 6pt) in `dayEventsList`. A moderate bump — visibly roomier without over-committing to a big height increase.
- **D-10:** `calendarWidth` grows by roughly 10-15pt (460 → ~470-475pt) — a small bump, matching the "a few pt wider" wording literally.
- **D-11:** Exact final row-padding and width numbers may be tuned slightly during planning/UI-phase (D-09/D-10 are directional targets, not hard-locked pixel values) — but the moderate-bump-only intent (not "generous") is locked.

### Claude's Discretion
- Exact pixel values for `calendarContentHeight`, final row padding, and `calendarWidth` within the "moderate bump" / "~10-15pt" ranges given in D-09/D-10 — fine-tuned during planning/UI-phase against the actual rendered layout.
- Whether the reminder default is computed via the same "next full hour if today / 00:00 otherwise" helper as the event start (implementation detail — the requirement text applies this rule uniformly to both kinds' single time value).
- Exact SwiftUI code structure for conditionally rendering Start/End (Event) vs. Due (Reminder) inside `quickAddContent` — could be an `if kind == .event { ... } else { ... }` or a shared row builder; not specified by the user.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements & roadmap
- `.planning/ROADMAP.md` §"Phase 46: Calendar Quick-Add Improvements" (~line 663) — goal, 3 success criteria, CALVIEW-05/06/07
- `.planning/REQUIREMENTS.md` (~line 55-57, 132-134) — CALVIEW-05, CALVIEW-06, CALVIEW-07 exact wording

### Original feature this phase modifies
- `.planning/phases/28-calendar-full-view/28-UI-SPEC.md` — original "Calendar full view" Layout Contract (Quick-add control chrome, day-list scroll box, "+ Add" trigger position) that CALVIEW-06/07 are changing
- `.planning/phases/28-calendar-full-view/28-CONTEXT.md` — original CALVIEW-01..04 decisions (D-03 quick-add scope, Event/Reminder nouns, chip button styling)
- `.planning/phases/28-calendar-full-view/28-PATTERNS.md` — established view patterns this phase must follow (pure functions, no EventKit code in view files)

### Prior precedent for this phase's mechanics
- `.planning/phases/44-tray-quick-action-width-alignment/44-CONTEXT.md` — D-05: `trayContentHeight` per-tab height override precedent this phase's `calendarContentHeight` (D-08) follows
- `.planning/phases/45-view-switcher-morph-fix/45-CONTEXT.md` — `switcherContentHeight`/`blobShape` mechanics, explicit-height-override-wins convention, and confirmation that differing per-tab heights already animate correctly post-Phase-45

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Islet/Calendar/CalendarService.swift` `createEvent(title:start:end:completion:)` and `createReminder(title:dueDate:completion:)` (lines ~136, ~152) — already accept full `Date` start/end/dueDate parameters; no EventKit-layer changes needed, only the caller (`NotchWindowController.handleQuickAdd`, line ~1651) needs to pass real picked dates instead of hardcoded `day`/`day+3600`.
- `QuickAddPopover` (`Islet/Notch/NotchPillView.swift` ~line 3125) — existing popover struct with `@State kind`/`title`, segmented Picker, chip-button styling (`RoundedRectangle` + `Color.white.opacity(0.12)`) to extend with new `@State` for start/end/due dates.
- `QuickAddKind` enum (`Islet/Calendar/CalendarViewState.swift` ~line 19) — `.event`/`.reminder` cases already exist to branch the picker UI on.

### Established Patterns
- `blobShape(...)` (`NotchPillView.swift` ~line 1884) — explicit `height:`/`width:` override always wins over the shared `switcherContentHeight` default (Phase 32/TRAY-05 convention); this is the mechanism D-08's `calendarContentHeight` must plug into, same as `calendarWidth` already does for width.
- `calendarWidth` (line 709, currently 460) and `switcherContentHeight` (line 638, 196) are the two constants D-08/D-10 change; `calendarCellSize`/`calendarCellGap` (18/2) are unrelated and should NOT change.
- No `Date()`/`Date.now()` in pure functions — this project's RESEARCH.md anti-pattern; any "next full hour" default-time computation should take `now` as an explicit parameter (mirrors `CalendarGlance.swift`'s existing discipline).

### Integration Points
- `NotchWindowController.handleQuickAdd(_:title:)` (line ~1651) is the sole call site wiring `QuickAddPopover`'s `onSubmit` to `CalendarService` — its signature will need to grow to accept the picked start/end (or due) `Date`(s), not just `kind`/`title`.
- `dayEventsList(_:)` (`NotchPillView.swift` ~line 1205) is the only place row padding (D-09) changes.
- `dayListColumn` (~line 1158) and `calendarContent` (~line 1056) are where the button-placement (D-06) and width/height (D-08/D-10) changes land respectively.

</code_context>

<specifics>
## Specific Ideas

- Reminder's single time field should be labeled "Due" (EventKit-accurate terminology, not generic "Time").
- End-time auto-follow behavior (D-04) should feel like a normal macOS date-range picker: adjust Start → End shifts with it, until End is touched directly.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

### Reviewed Todos (not folded)
- "Island briefly disappears during click-through" — Tray/drag click-through bug, unrelated to calendar quick-add; not folded.
- "Quick Action disabled state has no controller gate" — Tray Quick Action controller-gate bug, unrelated to calendar quick-add; not folded.

</deferred>

---

*Phase: 46-Calendar Quick-Add Improvements*
*Context gathered: 2026-07-19*
