# Phase 72: Calendar Redesign — Native Calendar Clone - Context

**Gathered:** 2026-07-30
**Status:** Ready for planning

<domain>
## Phase Boundary

The expanded Calendar view (Phase 28, already shipped) gets redesigned into a genuine 1:1 visual clone of macOS's own Calendar widgets — full month grid on the left, a scrollable day-grouped agenda list on the right. The layout is ALREADY two columns in code today (`monthGridColumn` / `dayListColumn` HStack) — the real gap is (1) the day-list is currently single-day-only, not a scrollable multi-day agenda, and (2) the visual badge language doesn't match Apple's own widget styling yet.

**Scope was expanded during discussion**: a pending todo (`2026-07-19-calendar-month-grid-polish.md`, explicitly tagged `resolves_phase: 72`) is folded in fully — chevron spacing, day-number font size, AND event edit/remove (new capability, since `CalendarService` currently only has `createEvent`/`createReminder`, no update/delete).

</domain>

<decisions>
## Implementation Decisions

### Agenda List Scope
- **D-01:** The agenda list (right column) shows the **whole visible month** — every day with events in the currently-viewed month, grouped by day header (e.g. "WEDNESDAY, 15 JUL"). Navigating the month grid's prev/next chevrons changes what the agenda shows (not a fixed rolling window from today).
- **D-02:** Tapping a day in the month grid **scrolls the agenda list** to that day's header — the grid becomes a jump-to-date shortcut into the already-populated agenda, not a separate single-day filter.

### Today/Selected Badge Styling
- **D-03:** Swap confirmed — **today** gets a solid filled red badge (matches the real macOS widget reference), **selected/viewed day** gets a thin **red outline ring** (not white/gray — same accent color as today, but outlined instead of filled). This reverses current code (today=ring, selected=filled).
- **D-04:** Claude's discretion whether the small "has events" dot indicator changes — user said "you decide," resolve against what actually matches the real reference screenshot during UI-spec/planning.

### Reference Source (supersedes Droppy screenshot)
- **D-05 [informational]:** The canonical visual reference is now a real macOS Notification Center Calendar widget screenshot the user provided (saved as `reference-macos-calendar-widgets.png` in this phase's directory) — showing two widget variants: (1) a bare month-grid widget with red month label + weekday-letter header + red filled circle on today, and (2) a day+agenda widget (weekday name + big date number + "no events" text) shown beside a month grid. This reference **supersedes** the earlier Droppy screenshot (`calendar-redesign-droppy.md`) for exact colors/typography/badge styling — Droppy's screenshot remains useful context for the overall two-column concept but is not the pixel-fidelity source anymore.
- **D-06 [informational]:** Confirmed with the user: Apple's real Calendar widget **cannot be embedded directly** — no public API exists for a third-party app to host Apple's own system widget (WidgetKit only lets an app host its OWN widgets, not Apple's). This phase is a genuine SwiftUI rebuild matching the reference visually, not a system-widget integration. Do not revisit this as a research question — it's settled.

### Event Edit/Remove (folded-in scope)
- **D-07:** Editing an event opens a **popover on click**, reusing the existing `QuickAddPopover` interaction pattern — pre-filled with the event's current title/date/time, plus a Save button. Not inline text-field editing (that would be a new, unprecedented pattern in this codebase).
- **D-08:** Removing an event uses a **hover-reveal delete (trash) icon** on the row — one click deletes, **no confirm dialog**. Rationale (implicit in the choice): EventKit deletion isn't permanently destructive in the way a hard delete would be, so a confirm step was rejected as unnecessary friction.
- **D-09 (from folded todo):** `CalendarService.swift` needs new update/delete methods — it currently only exposes `createEvent`/`createReminder`. This is real new surface area, not a UI-only change.
- **D-10 (from folded todo):** Chevron arrows in the month header sit too far apart today — move them closer together (pure layout constant change).
- **D-11 (from folded todo):** Day-of-month numbers in the grid are too small — increase font size for legibility; check overall balance against Phase 46's row-padding bump once changed.
- **D-12 (from folded todo):** Event rows need a hover tooltip revealing the full (currently truncated) title, in addition to the new edit/remove affordances from D-07/D-08.

### Claude's Discretion
- Whether the "has events" dot indicator's exact styling changes (D-04).
- Exact mechanism for threading the new agenda-list day-grouping and scroll-to-day behavior (D-01/D-02) — implementation approach, not a locked decision.
- Exact `CalendarService` method signatures for update/delete (D-09).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase definition & requirements
- `.planning/ROADMAP.md` §"Phase 72: Calendar Redesign — Native Calendar Clone" — goal, CALVIEW-08/09 requirements, success criteria (note: SC#1's "replacing today's single-column stack" framing is stale — code is already two-column; the real gap is agenda scope + visual fidelity, see `<domain>` above)
- `.planning/REQUIREMENTS.md` — CALVIEW-08 (two-column layout), CALVIEW-09 (visual match to native Calendar)

### Visual reference
- `.planning/phases/72-calendar-redesign-native-calendar-clone/reference-macos-calendar-widgets.png` — **PRIMARY** visual reference (real macOS Calendar widgets, user-provided 2026-07-30). Use for exact colors (red accent), typography, badge styling.
- `.planning/seeds/calendar-redesign-droppy.md` — original Droppy-inspired seed idea; useful for the overall two-column concept and agenda day-header convention ("WEDNESDAY, 15 JUL"), but superseded by the reference PNG above for pixel-level styling.

### Folded todo
- `.planning/todos/pending/2026-07-19-calendar-month-grid-polish.md` — fully folded into this phase's scope (D-09 through D-12 above). Delete or mark resolved from `.planning/todos/pending/` once this phase ships.

### Codebase (exact integration points, verified by reading the live files)
- `Islet/Notch/NotchPillView.swift` — `calendarContent` (HStack of the two columns, ~line 1584), `monthGridColumn` (~1630, month/year header + chevrons + `LazyVGrid` day badges, `calendarCellSize`/`calendarCellGap` constants), `dayListColumn` (~1686, currently single-selected-day only), `dayEventsList` (~1733, the scrollable event-row rendering with title/color-dot/time)
- `Islet/Calendar/CalendarService.swift` — `createEvent`/`createReminder` only; needs update/delete methods added (D-09)
- `Islet/Calendar/CalendarViewState.swift` — holds `visibleMonth`, `selectedDay`, `monthEvents`
- `Islet/Notch/NotchPillView.swift:1001` — `calendarWidth: CGFloat = 472`, already scales via `resolvedWidthScale` per the existing per-tab width-scaling pattern (Phase 32/67.1) — SC#5's "island widens" likely means bumping this constant further, not building new scaling infrastructure
- `Islet/Notch/NotchPillView.swift` `showsSwitcherRow`/`switcherRowHeight` — the existing Home/Tray/Calendar/Weather switcher pill already serves the role of Droppy's reference "persistent bottom pill" — no new dock/pill needed, this is already covered

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `QuickAddPopover` (Phase 46) — reuse its popover interaction pattern for the new event-edit popover (D-07), pre-filled instead of blank.
- Existing per-tab width-scaling (`resolvedWidthScale` via `calendarWidth`) — reuse for any further island widening, don't build a new mechanism.
- `dayEventsList`'s existing row styling (rounded card, color-dot, title, time) — the visual base to extend with day-group headers, hover tooltip, and edit/remove affordances.

### Established Patterns
- Pure functions `daysInMonth(for:)` / `events(on:events:)` — month math and event lookup are already pure/testable; the new multi-day agenda grouping should reuse/extend these, not reimplement date math.
- "Taps only REPORT intent via `onCalendarMonthChange`/`onCalendarDaySelect`" (Pattern 3 per existing code comments) — no navigation/date math should live in the view; the new scroll-to-day behavior (D-02) should follow this same reporting convention.

### Integration Points
- `calendarContent`'s HStack — column internals change (dayListColumn becomes multi-day/scrollable), the two-column structure itself does not.
- `CalendarService` protocol — needs new update/delete methods (D-09), which then need EventKit-backed implementations and a stub path in any test double.

</code_context>

<specifics>
## Specific Ideas

- User-provided screenshot (`reference-macos-calendar-widgets.png`) shows the exact real macOS Notification Center Calendar widgets: red "JULI" month label, weekday-letter header row (M D M D F S S), red filled circle on today's date (30), and a separate day+agenda widget variant (weekday name "DONNERSTAG" + large date number "30" + "Heute keine Ereignisse" placeholder text) shown beside a month grid.
- User confirmed (in German) they'd ideally want to literally embed the real widget but accepted this isn't possible via public API — proceeding with a faithful rebuild instead.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope (the todo fold-in was an explicit, deliberate scope expansion agreed to by the user, not scope creep).

</deferred>

---

*Phase: 72-Calendar Redesign — Native Calendar Clone*
*Context gathered: 2026-07-30*
