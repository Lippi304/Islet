# Phase 72: Calendar Redesign — Native Calendar Clone - Research

**Researched:** 2026-07-30
**Domain:** SwiftUI layout/visual redesign + EventKit CRUD extension (native macOS, no external packages)
**Confidence:** HIGH

## Summary

This phase extends already-shipped, already-two-column code (`calendarContent` in
`NotchPillView.swift`) rather than building new layout infrastructure. The real work is three
separate, independently-verifiable changes: (1) turn `dayListColumn` from a single-selected-day
list into a scrollable, multi-day agenda grouped by day header with tap-to-scroll from the month
grid, (2) restyle the month grid's badges (today=filled, selected=outline — a swap from today's
code) and add a weekday-letter header row that **does not currently exist anywhere in the
codebase**, and (3) add event edit/delete, which is blocked on one concrete gap: `EventInput`
(`Islet/Calendar/CalendarGlance.swift`) carries no event identifier, so `CalendarService` cannot
implement `updateEvent`/`deleteEvent` without EventKit's `eventIdentifier` reaching the view layer
first. This is a small, mechanical fix (add one `String` field, `EKEvent.eventIdentifier`,
force-unwrapped is unsafe — `eventIdentifier` is non-nil once an event has been saved via
`store.events(matching:)`, so it is safe to read as non-optional at that call site) but it must
happen before update/delete can be wired, and no existing test double or protocol stub currently
exists for `CalendarService` to update in parallel.

**Primary recommendation:** Extend `EventInput` with an `id: String` (from `EKEvent.eventIdentifier`),
add `updateEvent(id:title:start:end:completion:)` / `deleteEvent(id:completion:)` to
`CalendarService`/`EventKitService` using `store.event(withIdentifier:)` + `store.save(_:span:)` /
`store.remove(_:span:)`, extract a new pure `eventsByDay(events:calendar:)` grouping function into
`CalendarGlance.swift` (mirrors `events(on:events:)`), and drive the day-list column with a
`ScrollViewReader` whose `.onChange(of: calendarViewState.selectedDay)` calls `scrollTo(_:anchor:)`
— all native SwiftUI/EventKit, zero new dependencies.

## User Constraints (from CONTEXT.md)

### Locked Decisions

**Agenda List Scope**
- D-01: The agenda list (right column) shows the **whole visible month** — every day with events
  in the currently-viewed month, grouped by day header (e.g. "WEDNESDAY, 15 JUL"). Navigating the
  month grid's prev/next chevrons changes what the agenda shows (not a fixed rolling window from
  today).
- D-02: Tapping a day in the month grid **scrolls the agenda list** to that day's header — the
  grid becomes a jump-to-date shortcut into the already-populated agenda, not a separate
  single-day filter.

**Today/Selected Badge Styling**
- D-03: Swap confirmed — **today** gets a solid filled red badge (matches the real macOS widget
  reference), **selected/viewed day** gets a thin **red outline ring** (not white/gray — same
  accent color as today, but outlined instead of filled). This reverses current code
  (today=ring, selected=filled).
- D-04: Claude's discretion whether the small "has events" dot indicator changes — user said "you
  decide," resolve against what actually matches the real reference screenshot during
  UI-spec/planning.

**Reference Source (supersedes Droppy screenshot)**
- D-05: The canonical visual reference is now a real macOS Notification Center Calendar widget
  screenshot (`reference-macos-calendar-widgets.png` in this phase's directory) — showing a bare
  month-grid widget (red month label + weekday-letter header + red filled circle on today) and a
  day+agenda widget (weekday name + big date number + placeholder text) beside a month grid. This
  reference supersedes the Droppy screenshot for exact colors/typography/badge styling; Droppy's
  screenshot remains useful for the overall two-column concept and agenda day-header convention.
- D-06: Confirmed — Apple's real Calendar widget cannot be embedded (no public API for hosting a
  system widget). This is a genuine SwiftUI rebuild, not a widget integration. Settled, do not
  revisit.

**Event Edit/Remove (folded-in scope)**
- D-07: Editing an event opens a **popover on click**, reusing `QuickAddPopover`'s interaction
  pattern — pre-filled with title/date/time, plus Save. Not inline editing.
- D-08: Removing an event uses a **hover-reveal delete (trash) icon** — one click deletes, **no
  confirm dialog**.
- D-09: `CalendarService.swift` needs new update/delete methods (currently only
  `createEvent`/`createReminder`) — real new surface area.
- D-10: Chevron arrows in the month header sit too far apart — move closer together (layout
  constant change).
- D-11: Day-of-month numbers are too small — increase font size; check balance against Phase 46's
  row-padding bump once changed.
- D-12: Event rows need a hover tooltip revealing the full (currently truncated) title, in
  addition to edit/remove affordances.

### Claude's Discretion
- Whether the "has events" dot indicator's exact styling changes (D-04).
- Exact mechanism for threading the new agenda-list day-grouping and scroll-to-day behavior
  (D-01/D-02) — implementation approach, not a locked decision.
- Exact `CalendarService` method signatures for update/delete (D-09).

### Deferred Ideas (OUT OF SCOPE)
None — the discussion stayed within phase scope; the todo fold-in was a deliberate, user-agreed
scope expansion, not scope creep.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CALVIEW-08 | Expanded Calendar view widened into a two-column layout — full month grid left, scrollable day-grouped agenda list right | Column structure already exists (`calendarContent`/`monthGridColumn`/`dayListColumn`); gap is `dayListColumn` is single-day-only. See Architecture Patterns § Pattern 1 (multi-day agenda) and Code Examples for the `eventsByDay` grouping + `ScrollViewReader` scroll-to-day pattern. |
| CALVIEW-09 | Visual design (colors, date badges, event row styling, typography) matches macOS's native Calendar app as closely as technically possible | Reference screenshot analyzed (see Summary); badge swap (D-03), weekday header row (net-new, confirmed absent from codebase), chevron spacing (D-10), font size (D-11) all mapped to exact code sites in Architecture Patterns and Common Pitfalls. |

</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Month grid rendering + badge styling | SwiftUI View (`monthGridColumn`) | — | Pure presentation, already isolated in its own computed property |
| Weekday header row (net-new) | SwiftUI View (`monthGridColumn`) | Foundation (`Calendar.shortWeekdaySymbols`/`firstWeekday`) | Locale-correct label ordering is a system Calendar API concern, not a view concern |
| Day → events grouping for agenda | Pure function (`CalendarGlance.swift`) | — | Mirrors existing `events(on:events:)`/`daysInMonth(for:)` — no navigation/date math in the view (Pattern 3, already an established convention in this codebase) |
| Scroll-to-day on grid tap | SwiftUI View (`dayListColumn`, `ScrollViewReader`) | `CalendarViewState` (`selectedDay` as the trigger) | View-local scroll position is not app state; only the "which day is selected" fact belongs in `CalendarViewState` |
| Event create/update/delete | `CalendarService`/`EventKitService` (Calendar domain layer) | `NotchWindowController` (handler wiring, mirrors `handleQuickAdd`) | EventKit access is already quarantined behind the `CalendarService` protocol seam (Phase 14 D-02) — update/delete must go through the same seam, not a new one |
| Edit popover UI | SwiftUI View (new sibling of `QuickAddPopover`) | `NotchWindowController` (new `handleEventEdit`/`handleEventDelete` handlers) | Reuses the popover-trigger pattern already proven for quick-add; state ownership (title/date fields) stays view-local exactly like `QuickAddPopover` |
| Hover-reveal delete icon | SwiftUI View (per-row private `View` struct with local `@State isHovering`) | — | Exact precedent already in this file: `TransportButton` (`NotchPillView.swift:4552`) uses a local `@State private var isHovering` + `.onHover` — no controller-owned hover-index state needed for a simple per-row toggle |
| Island width for two-column layout | `NotchPillView.Self.calendarWidth` constant × `resolvedWidthScale` | — | Existing per-tab width-scaling mechanism (Phase 32/67.1); SC#5 is a constant bump, not new infrastructure |

## Standard Stack

### Core
No new libraries. This phase is 100% SwiftUI + EventKit, both already linked frameworks in this
project (per `CLAUDE.md`'s stack section — SwiftUI/AppKit/EventKit are the established stack, no
third-party dependency is warranted for a native-clone visual redesign or a CRUD extension of an
already-integrated system framework).

| Framework | Version | Purpose | Why Standard |
|-----------|---------|---------|---------------|
| SwiftUI | ships with target SDK (Xcode 26.6 on this machine) | Layout, `ScrollViewReader`, hover state | Already 95% of this app's UI per `CLAUDE.md` |
| EventKit | ships with target SDK | `EKEventStore.event(withIdentifier:)`, `.save(_:span:)`, `.remove(_:span:)` | Already the sole calendar-data source (`EventKitService`); update/delete are sibling methods to the existing `createEvent`/`createReminder` |

### Supporting
None.

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `ScrollViewReader.scrollTo` for D-02's jump-to-date | A rebuilt/filtered `ScrollView` per selection | Rejected — would violate Pattern 3 (view holding navigation state) and re-fetch/re-render the whole list on every tap instead of just scrolling |
| Adding a real `Identifiable` wrapper type around `EventInput` | Adding a plain `id: String` field to the existing struct | Plain field chosen — smaller diff, `EventInput` is already a flat value type (`Equatable`) used across 3+ call sites; a wrapper type would need a migration across all of them for no added benefit |

**Installation:** None — no `npm install`/`SPM add` step. Purely internal-file changes.

## Package Legitimacy Audit

Not applicable — this phase adds zero external packages. All work is internal Swift files plus
calls into already-linked Apple frameworks (SwiftUI, EventKit, Foundation).

## Architecture Patterns

### System Architecture Diagram

```
[Month grid tap: onCalendarDaySelect(day)]
        |
        v
[NotchWindowController.handleCalendarDaySelect] --sets--> [CalendarViewState.selectedDay]
        |
        v (SwiftUI @Published triggers re-render)
[dayListColumn's ScrollViewReader] --.onChange(of: selectedDay)--> [proxy.scrollTo(dayKey, anchor: .top)]
        |
        v
[Agenda ForEach, grouped via eventsByDay(events: monthEvents, calendar:)]
   each day-group --> day header Text ("WEDNESDAY, 15 JUL") --.id(dayKey)--
                   --> ForEach event rows (existing dayEventsList row styling, extended)

[Event row tap] --> [edit popover, reuses QuickAddPopover pattern, pre-filled]
        |
        v (Save)
[NotchWindowController.handleEventEdit] --> [CalendarService.updateEvent(id:title:start:end:)]
        |                                          |
        v                                          v
[refreshCalendarMonth()]                 [EKEventStore.event(withIdentifier:) -> .save(_:span:)]

[Event row hover -> trash icon] --tap--> [NotchWindowController.handleEventDelete]
        |
        v
[CalendarService.deleteEvent(id:)] --> [EKEventStore.event(withIdentifier:) -> .remove(_:span:)]
        |
        v
[refreshCalendarMonth()]  (re-fetches monthEvents, agenda re-groups automatically)
```

Entry points are the two existing tap-report callbacks (`onCalendarMonthChange`,
`onCalendarDaySelect`) plus two new ones for edit/delete, mirroring `onQuickAdd`'s exact shape.
Nothing new writes navigation state from inside a view — same discipline as the rest of this file.

### Recommended Project Structure
No new files needed. All changes land in the three files CONTEXT.md already identified:
```
Islet/
├── Notch/NotchPillView.swift       # monthGridColumn, dayListColumn, dayEventsList, new edit
│                                     popover struct, new per-row hover-delete view struct
├── Calendar/CalendarService.swift   # + updateEvent/deleteEvent on protocol + EventKitService
├── Calendar/CalendarGlance.swift    # + eventsByDay(events:calendar:) pure grouping function
└── Calendar/CalendarViewState.swift # unchanged (visibleMonth/selectedDay/monthEvents suffice)
Islet/Notch/NotchWindowController.swift  # + handleEventEdit/handleEventDelete handlers
IsletTests/CalendarGlanceTests.swift     # + tests for eventsByDay
```

### Pattern 1: Multi-day agenda grouping (pure function, mirrors `events(on:events:)`)
**What:** Group `[EventInput]` by calendar day, sorted ascending by day then by start time.
**When to use:** Feeding the day-list column's `ForEach` and computing stable `.id()`s for
`ScrollViewReader`.
**Example:**
```swift
// New addition to Islet/Calendar/CalendarGlance.swift — mirrors events(on:events:)'s exact
// contract: Foundation-only, total, never crashes on an empty array, `calendar:` defaulted.
func eventsByDay(events: [EventInput], calendar: Calendar = .current) -> [(day: Date, events: [EventInput])] {
    let grouped = Dictionary(grouping: events) { calendar.startOfDay(for: $0.start) }
    return grouped
        .sorted { $0.key < $1.key }
        .map { (day: $0.key, events: $0.value.sorted { $0.start < $1.start }) }
}
```

### Pattern 2: Scroll-to-day on grid tap
**What:** `ScrollViewReader` wraps the agenda `ScrollView`; each day-group header carries
`.id(day)` (the `Date` from `eventsByDay`, already `Hashable`); a `.onChange(of:
calendarViewState.selectedDay)` on the reader's content calls `scrollTo`.
**When to use:** D-02's jump-to-date behavior.
**Example:**
```swift
// Source: SwiftUI ScrollViewReader — Apple Developer Documentation
// (developer.apple.com/documentation/swiftui/scrollviewreader)
ScrollViewReader { proxy in
    ScrollView(.vertical) {
        LazyVStack(alignment: .leading, spacing: 12) {
            ForEach(eventsByDay(events: monthEvents ?? [], calendar: .current), id: \.day) { group in
                Text(group.day, format: .dateTime.weekday(.wide).day().month(.abbreviated))
                    .id(group.day)   // scroll target
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                dayEventsRows(group.events)   // existing per-event row rendering, extended
            }
        }
    }
    .onChange(of: calendarViewState.selectedDay) { _, newDay in
        let key = Calendar.current.startOfDay(for: newDay)
        withAnimation { proxy.scrollTo(key, anchor: .top) }
    }
}
```

### Pattern 3: Locale-correct weekday header row (net-new — does not exist in codebase today)
**What:** A 7-column row of weekday letters above the day grid, rotated to match
`calendar.firstWeekday` — the SAME rotation `daysInMonth(for:)` already computes for its leading
`nil` padding, so the header MUST use the identical rotation or the letters will not line up with
the day-number columns beneath them.
**When to use:** SC#2's "weekday header row" requirement.
**Example:**
```swift
// Foundation Calendar API — developer.apple.com/documentation/foundation/calendar/veryshortweekdaysymbols
// Locale-aware (matches the reference PNG's German "M D M D F S S" for a de_DE locale
// automatically — no hardcoded weekday strings).
private var rotatedWeekdaySymbols: [String] {
    let calendar = Calendar.current
    let symbols = calendar.veryShortWeekdaySymbols   // index 0 = Sunday, always
    let firstWeekdayIndex = calendar.firstWeekday - 1 // Calendar.firstWeekday is 1-based
    return Array(symbols[firstWeekdayIndex...] + symbols[..<firstWeekdayIndex])
}
```

### Anti-Patterns to Avoid
- **Re-fetching `monthEvents` on every day-select tap:** D-02 is a pure scroll, not a filter —
  `calendarViewState.monthEvents` is already the whole month (set by `refreshCalendarMonth()`);
  `handleCalendarDaySelect` should keep doing exactly what it does today (set `selectedDay` only).
- **Hand-rolling event identity via array index for edit/delete:** the existing `dayEventsList`
  uses `id: \.offset` for pure display — safe there, but do NOT carry that pattern into
  edit/delete closures. Capture the real `EventInput.id` (EKEvent identifier) in the row's
  edit/delete closures, not the row's position in the array.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|--------------|-----|
| Finding an event to update/delete | A local cache/dictionary keyed by title+date | `store.event(withIdentifier:)` | EventKit's own identifier lookup is O(1) against the real store and handles the case where the event was externally modified/deleted between fetch and edit (returns `nil`, which the new methods already handle via `completion(false)`) |
| Day-grouping for the agenda | A hand-rolled loop building `[String: [EventInput]]` inline in the view | `Dictionary(grouping:by:)` in a new pure `CalendarGlance.swift` function | Matches this codebase's own established pure-function-for-date-math convention (`daysInMonth`, `events(on:)`) — keeps it unit-testable without EventKit/permission context |
| Scroll-to-element | Manual `GeometryReader` offset math | `ScrollViewReader` + `.id()` + `scrollTo` | Native SwiftUI API purpose-built for exactly this; `GeometryReader`-based scrolling is fragile and unnecessary complexity for a beginner-maintained codebase (per `CLAUDE.md`'s "avoid unnecessary complexity" constraint) |
| Locale-aware weekday labels | Hardcoded `["M","D","M","D","F","S","S"]` string array | `Calendar.current.veryShortWeekdaySymbols` rotated by `firstWeekday` | Hardcoding German letters would be wrong for any other system locale, and would silently misalign with `daysInMonth`'s own locale-aware leading-pad math the moment locale differs |

**Key insight:** Every piece of this phase has a direct existing precedent in the same file/module
(`events(on:)`, `daysInMonth(for:)`, `TransportButton`'s hover pattern, `QuickAddPopover`'s
popover-trigger pattern). The work is extension-by-analogy, not new-pattern invention.

## Common Pitfalls

### Pitfall 1: `EventInput` has no identifier — update/delete are unimplementable without it
**What goes wrong:** `CalendarService.updateEvent`/`deleteEvent` need to find the specific
`EKEvent` to mutate, but `EventInput` (the plain value type crossing the EventKit boundary) only
carries `title`/`start`/`end`/color — no `eventIdentifier`. Building update/delete methods first
without this field means they have no way to be called correctly from the view layer.
**Why it happens:** `EventInput` was designed (Phase 14) purely for read/display — create-only
quick-add never needed to reference a specific already-existing event.
**How to avoid:** Add `let id: String` to `EventInput`, populate it from `ek.eventIdentifier` in
`mapToEventInput(_:)` (currently in `CalendarService.swift`). `eventIdentifier` is documented
optional on `EKCalendarItem` but is guaranteed non-nil for any event returned from
`store.events(matching:)` (only nil before the item is first saved) — safe to force-read via
`ek.eventIdentifier ?? ""` with an empty-string fallback that simply makes update/delete no-ops
(never crashes, mirrors this file's own `T-28-05` "never crash on save error" discipline).
**Warning signs:** If a plan proposes `updateEvent`/`deleteEvent` signatures before touching
`EventInput`, flag it — the CalendarService change and the `EventInput` change are not
independent; `EventInput` must land first (or in the same task).

### Pitfall 2: Weekday header row does not exist yet — grep confirmed, do not assume it's a restyle
**What goes wrong:** SC#2 reads as if the weekday row just needs restyling (the phase description
groups it with "already two-column"). It is net-new code, not a restyle — a repo-wide grep for
`weekdaySymbols`/any weekday-letter rendering in `Islet/Notch/NotchPillView.swift` and
`Islet/Calendar/*.swift` returns zero matches.
**Why it happens:** The Droppy/reference screenshots always show the weekday row, so it reads as
"already there, matching Apple" in a quick description skim.
**How to avoid:** Plan a real new sub-view (`weekdayHeaderRow`) inside `monthGridColumn`, using
the rotated-symbols pattern above — must align exactly with the `LazyVGrid`'s 7-column layout
(`calendarCellSize`/`calendarCellGap`) or the letters will not sit above the correct date column.
**Warning signs:** A plan task that says "restyle weekday header" instead of "add weekday header".

### Pitfall 3: Badge swap (D-03) is a two-line change, easy to get backwards
**What goes wrong:** Current code (`monthGridColumn`, ~line 1663-1664) has
`.background(Circle().fill(...isSelected...))` (selected=filled) and
`.overlay(Circle().strokeBorder(...isToday && !isSelected...))` (today=ring). D-03 reverses this:
today=filled red, selected=outline red ring. A careless edit could flip only one of the two
conditionals and leave the pair inconsistent (e.g. both today AND selected filled on the day that
is both).
**Why it happens:** The two states currently share one `ZStack` with two independent modifiers
keyed off `isSelected`/`isToday && !isSelected` — swapping requires touching both conditions in
tandem, plus swapping `Color.white.opacity(...)` for the red accent color from the reference PNG.
**How to avoid:** Write the new logic as one pair: `isToday` -> filled red circle;
`isSelected && !isToday` -> red-stroked ring (today already wins visually when both are true —
matches the reference PNG where today's cell is a plain filled circle with no additional ring).
**Warning signs:** Any diff that changes only one of the two modifier lines.

### Pitfall 4: Hover-reveal delete icon needs per-row local state, not shared controller state
**What goes wrong:** This codebase has two different hover patterns: controller-owned
`presentationState.hoveredQuickActionButtonIndex` (for a small fixed set of buttons) and
per-row local `@State private var isHovering` inside a small private `View` struct
(`TransportButton`, line 4552). Using the controller-owned pattern for a `ForEach` of an
unbounded, refetch-changing event list would require indexing into a dynamic array by position —
fragile the moment the list re-sorts/re-fetches mid-hover.
**Why it happens:** Both patterns exist in the same file; picking the wrong one by analogy to the
nearer example (`quickActionButton`, which IS controller-owned) is an easy mistake.
**How to avoid:** Extract the event row into its own small private `View` struct (mirrors
`TransportButton` exactly) with local `@State private var isHovering`, gating the trash icon's
opacity/visibility on that local state — no controller state needed for this.
**Warning signs:** A plan adding a new `@Published`/`presentationState` field for "hovered event
row index".

### Pitfall 5: `ScrollView` + `LazyVStack` day-header `.id()` collisions across months
**What goes wrong:** If a plan uses `Calendar.current.isDate(..., inSameDayAs:)`-style loose
comparison for `.id()` instead of the exact `startOfDay(for:)` `Date` value, two different months'
identical day-of-month (e.g. the 15th of July and the 15th of August, if ever both present in
`monthEvents` due to a stale-refetch race) could collide. In practice `monthEvents` is always
scoped to exactly one visible month (`fetchMonth(containing:)`), so this is a low-probability edge
case — but `Dictionary(grouping:)` with `startOfDay(for:)` as the key is inherently safe regardless
(distinct `Date` values, not string labels), so no special handling is needed as long as Pattern 1
above is followed as written (do not substitute a formatted `String` day-label as the grouping key).
**Warning signs:** A plan grouping by `String` (formatted day label) instead of by `Date`.

## Code Examples

### EKEventStore update — reusing the existing full-access grant (no new permission prompt)
```swift
// Source: EventKit — developer.apple.com (EKEventStore.event(withIdentifier:), .save(_:span:))
// Mirrors createEvent's exact "no new permission request needed" comment (D-06 in CalendarService.swift).
func updateEvent(id: String, title: String, start: Date, end: Date, completion: @escaping (Bool) -> Void) {
    guard let event = store.event(withIdentifier: id) as? EKEvent else {
        completion(false)   // event no longer exists (deleted externally) — never crash
        return
    }
    event.title = title // T-14-06: plain String, never interpolated.
    event.startDate = start
    event.endDate = end
    do {
        try store.save(event, span: .thisEvent)
        completion(true)
    } catch {
        completion(false) // T-28-05: never crash on a thrown save error.
    }
}
```

### EKEventStore delete — no confirm dialog (D-08), one-click
```swift
// Source: EventKit — developer.apple.com (EKEventStore.remove(_:span:))
func deleteEvent(id: String, completion: @escaping (Bool) -> Void) {
    guard let event = store.event(withIdentifier: id) as? EKEvent else {
        completion(false)
        return
    }
    do {
        try store.remove(event, span: .thisEvent)
        completion(true)
    } catch {
        completion(false)
    }
}
```
Note: `store.event(withIdentifier:)` returns `EKCalendarItem?`, not `EKEvent?` directly — the
`as? EKEvent` cast is required (it can also return an `EKReminder` for a reminder identifier, which
is never the case here since `EventInput.id` only ever comes from `mapToEventInput`'s `EKEvent`
path).

## State of the Art

Not applicable — EventKit's `event(withIdentifier:)`/`save(_:span:)`/`remove(_:span:)` trio has
been stable API since early EventKit (pre-Swift), no deprecation or replacement to account for.
SwiftUI's `ScrollViewReader` has been stable since iOS 14/macOS 11 — no version gate needed given
this project's macOS 14.0 floor (`CLAUDE.md`).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `EKEvent.eventIdentifier` is guaranteed non-nil for any event returned from `store.events(matching:)` (only nil pre-save) | Pitfall 1, Code Examples | Low — even if occasionally nil in some edge case, the `?? ""` fallback degrades to a no-op update/delete (never crashes), consistent with this codebase's existing "settle false, never retry/nag" error discipline |
| A2 | `store.event(withIdentifier:)` returns `EKCalendarItem?` requiring an `as? EKEvent` cast (not directly typed `EKEvent?`) | Code Examples | Low — verified via web search against Apple documentation search results (EventKit API surface, stable for over a decade); worst case is a compile error the planner/executor catches immediately, not a runtime risk |

## Open Questions (RESOLVED)

1. **Exact red accent color value for badges/labels (D-03/D-05)**
   - What we know: the reference PNG shows a specific red (system red, visually close to
     `Color.red`/`NSColor.systemRed`) for both the month label and today's filled circle.
   - What's unclear: whether to use SwiftUI's semantic `.red`/`Color.red` (which adapts
     slightly per appearance) or a fixed RGB sampled from the reference PNG for pixel exactness.
   - Recommendation: use `Color.red` (system semantic) first — matches the reference closely
     enough per visual inspection, and stays consistent with this codebase's existing practice of
     using semantic SwiftUI colors (`.white.opacity(...)`, `.secondary`) rather than fixed RGB
     literals everywhere else in this file. Only sample exact RGB from the PNG if on-device
     comparison shows a visible mismatch.

2. **"Has events" dot indicator styling (D-04, explicitly Claude's discretion)**
   - What we know: current code shows a small white dot under the day number when
     `hasEvents` is true; the reference PNG's bare month-grid widget shows NO dot indicators at
     all (Apple's real widget relies on the agenda list itself, not grid dots, to convey "has
     events").
   - What's unclear: whether to keep the dot (existing, low-risk) or remove it entirely to match
     Apple's real widget more literally.
   - Recommendation: keep it — CONTEXT.md's D-04 explicitly leaves this open and the phase's
     success criteria don't mention removing it; removing a working, useful affordance not asked
     for by any locked decision risks user pushback. Flag for a one-line confirmation during
     planning/discussion rather than silently deciding.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode / xcodebuild | Build + test | ✓ | Xcode 26.6 (build 17F113) | — |
| Swift toolchain | Compile | ✓ | Swift 6.3.3 | — |
| EventKit.framework | Event fetch/create/update/delete | ✓ (already linked, used since Phase 14) | ships with SDK | — |
| Calendar access permission | All EventKit calls | Runtime-only, not verifiable from this research session | — | Already handled — every existing `CalendarService` method has a documented "settle empty/false on denial, never retry" fallback; update/delete should mirror it exactly |

No missing dependencies. This phase requires no new tool, package, or entitlement.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (existing `IsletTests` target) |
| Config file | none — standard Xcode test target, no separate config |
| Quick run command | `xcodebuild test -scheme Islet -destination 'platform=macOS' -only-testing:IsletTests/CalendarGlanceTests` |
| Full suite command | `xcodebuild test -scheme Islet -destination 'platform=macOS'` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CALVIEW-08 | `eventsByDay(events:calendar:)` groups/sorts correctly (empty input, single day, multiple days, cross-day-boundary events) | unit | `xcodebuild test -scheme Islet -destination 'platform=macOS' -only-testing:IsletTests/CalendarGlanceTests` | ❌ Wave 0 (extend existing file) |
| CALVIEW-08 | Two-column layout renders, agenda scrolls to tapped day, no clipping at new `calendarWidth` | manual-only | on-device checkpoint (visual/interaction, no SwiftUI snapshot infra exists in this project) | — |
| CALVIEW-09 | Badge styling (today filled / selected ring), weekday header alignment, chevron spacing, font sizes match reference PNG | manual-only | on-device checkpoint, side-by-side against `reference-macos-calendar-widgets.png` | — |
| D-09 (update/delete surface) | `EventInput.id` populated correctly from `EKEvent.eventIdentifier` | unit | can be tested indirectly only via a live `EKEventStore` (requires Calendar permission) — **no existing test double for `CalendarService`/`EventKitService` exists in this codebase today** (confirmed: zero grep hits for a stub/mock/fake calendar service) | ❌ — planner should decide whether a protocol stub is worth adding for this phase or left as manual/on-device verification only, consistent with `createEvent`/`createReminder` never having been unit-tested either |

### Sampling Rate
- **Per task commit:** `xcodebuild test -scheme Islet -destination 'platform=macOS' -only-testing:IsletTests/CalendarGlanceTests` (fast, seconds)
- **Per wave merge:** full `IsletTests` suite (per Phase 67.1's precedent: 569 tests, ~pre-existing 6 known failures unrelated to this phase — do not treat those as new regressions)
- **Phase gate:** full suite green + on-device UAT checkpoint comparing rendered Calendar tab against `reference-macos-calendar-widgets.png` before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `IsletTests/CalendarGlanceTests.swift` — add tests for the new `eventsByDay(events:calendar:)` function (mirrors the existing `testEventsOnDayReturnsOnlyMatchingDaySortedAscending`/`testEventsOnDayReturnsEmptyArrayForEmptyEventsWithoutCrashing` pair already in that file)
- [ ] No new test target/framework install needed — `IsletTests` already exists and is wired into the `Islet` scheme

## Security Domain

`security_enforcement` is not set in `.planning/config.json` (absent = enabled per policy), so
this section is included even though this phase's actual security surface is minimal (a local,
un-sandboxed, single-user macOS app with no network/auth boundary — see `CLAUDE.md`'s "no
sandboxing" constraint, which is an accepted, documented tradeoff for this project, not something
this phase should revisit).

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-------------------|
| V2 Authentication | no | N/A — no auth boundary in this app |
| V3 Session Management | no | N/A |
| V4 Access Control | no | N/A — Calendar/Reminders access is OS-level TCC permission, already gated per D-03/D-06 in `CalendarService.swift` |
| V5 Input Validation | yes | Reuse `QuickAddPopover`'s existing trimmed-empty-title guard (line ~5024) for the new edit popover — do not skip it just because the field is pre-filled |
| V6 Cryptography | no | N/A — no secrets/crypto in this phase |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|----------------------|
| Untrusted `EKEvent.title` (subscribed/shared calendars can set arbitrary text) rendered without bounding | Tampering (malformed display content) | Already enforced codebase-wide as `T-14-06`: plain `String` only, never interpolated into format/log/shell strings, always `.lineLimit(1)`/`.truncationMode(.tail)` at render time. The new edit popover's pre-filled `TextField` and the new hover tooltip (D-12) MUST continue this discipline — the tooltip in particular is new render surface for the same untrusted string and needs the same lineLimit/truncation treatment (or an explicit, deliberate exception if the tooltip is meant to show the FULL untruncated title, in which case it still must never be interpolated into anything other than a plain `Text` view). |
| `EventInput.id` (from `eventIdentifier`) used as an EventKit store lookup key | Tampering | Not attacker-influenceable in this app's real flow (identifiers originate from the local `EKEventStore`, round-trip through the SwiftUI view, back to the same store) — no injection risk since it's only ever used as a dictionary/store key via `store.event(withIdentifier:)`, never interpolated into any string. |

## Sources

### Primary (HIGH confidence)
- Live codebase read (`Islet/Notch/NotchPillView.swift`, `Islet/Calendar/CalendarService.swift`,
  `Islet/Calendar/CalendarGlance.swift`, `Islet/Calendar/CalendarViewState.swift`,
  `IsletTests/CalendarGlanceTests.swift`) — exact current implementation, confirmed via direct
  file reads and targeted `grep`, not training-data assumption.
- `reference-macos-calendar-widgets.png` — direct visual inspection of the user-provided
  canonical reference image.
- `.planning/phases/72-calendar-redesign-native-calendar-clone/72-CONTEXT.md` — locked decisions
  D-01 through D-12.

### Secondary (MEDIUM confidence)
- [EventKit Changes for Swift — Apple Developer](https://developer.apple.com/library/archive/releasenotes/General/APIDiffsMacOSX10_11/Swift/EventKit.html) — `EKEventStore.remove(_:span:)`/`event(withIdentifier:)` API shape, cross-checked against training knowledge; this API surface has been stable for a decade with no deprecation notices found.
- [How to remove an existing Event from Apple Calendar — Apple Developer Forums](https://developer.apple.com/forums/thread/36930) — corroborates the `store.remove(event, span: .thisEvent, commit: true)` call pattern.

### Tertiary (LOW confidence)
None — every claim above was either verified directly against the live codebase, the user-provided
reference image, or cross-checked via web search against Apple's own documentation/forums.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — zero new dependencies, entirely existing frameworks already in production use in this exact file/module
- Architecture: HIGH — every pattern proposed has a direct, cited precedent already in the live codebase (grep-verified line numbers)
- Pitfalls: HIGH — Pitfall 1 (missing identifier) and Pitfall 2 (missing weekday header) are both confirmed by direct grep against the live source, not inferred

**Research date:** 2026-07-30
**Valid until:** Codebase-coupled research — valid until `NotchPillView.swift`/`CalendarService.swift`/`CalendarGlance.swift` are next modified by an unrelated phase (EventKit API itself won't drift; treat as valid indefinitely for the API claims, but re-verify line numbers/exact code shape if execution is delayed past the next phase).
