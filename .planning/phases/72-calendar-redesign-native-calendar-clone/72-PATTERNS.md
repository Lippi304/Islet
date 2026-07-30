# Phase 72: Calendar Redesign — Native Calendar Clone - Pattern Map

**Mapped:** 2026-07-30
**Files analyzed:** 6 (all modified, zero net-new files)
**Analogs found:** 6 / 6 (all self-analogs — every change extends an existing pattern already in the same file/module, per RESEARCH.md's "extension-by-analogy, not new-pattern invention" finding)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `Islet/Calendar/CalendarGlance.swift` (+`eventsByDay`, +`id` on `EventInput`) | model / utility (pure functions) | transform | same file: `events(on:events:)` (lines 115-119) | exact |
| `Islet/Calendar/CalendarService.swift` (+`updateEvent`/`deleteEvent`) | service | CRUD | same file: `createEvent`/`createReminder` (lines 136-177) | exact |
| `Islet/Calendar/CalendarViewState.swift` (unchanged, read-only reference) | store (`ObservableObject`) | event-driven | n/a — no change needed | exact (no-op) |
| `Islet/Notch/NotchPillView.swift` — `monthGridColumn` (badge swap D-03, weekday header net-new, chevron spacing D-10, font size D-11) | component (SwiftUI view) | request-response (tap → report intent) | same file, same computed property (lines 1630-1680) | exact |
| `Islet/Notch/NotchPillView.swift` — `dayListColumn`/`dayEventsList` → multi-day agenda + `ScrollViewReader` + hover-delete row + edit popover | component (SwiftUI view) | streaming/list-render | same file: `dayEventsList` (1733-1763) for row styling; `TransportButton` (4552-4572) for hover pattern; `QuickAddPopover` (4949-5108) for edit-popover pattern | exact |
| `Islet/Notch/NotchWindowController.swift` (+`handleEventEdit`/`handleEventDelete`) | controller | request-response | same file: `handleQuickAdd`/`handleCalendarDaySelect` (2444-2463) | exact |
| `IsletTests/CalendarGlanceTests.swift` (+tests for `eventsByDay`) | test | transform | same file: `testEventsOnDayReturnsOnlyMatchingDaySortedAscending`/`...WithoutCrashing` (111-134) | exact |

## Pattern Assignments

### `Islet/Calendar/CalendarGlance.swift` — add `eventsByDay(events:calendar:)` + `id` field on `EventInput`

**Analog:** same file, `events(on:events:calendar:)` (lines 115-119) and the `EventInput` struct (lines 15-22)

**Struct pattern to extend** (lines 15-22):
```swift
struct EventInput: Equatable {
    let title: String
    let start: Date
    let end: Date
    let colorRed: Double
    let colorGreen: Double
    let colorBlue: Double
}
```
Add `let id: String` here (populated from `EKEvent.eventIdentifier ?? ""` at the `mapToEventInput` call site in `CalendarService.swift` — see Pitfall 1 in RESEARCH.md). This is a plain field addition to a flat `Equatable` value type, not a new wrapper type (Alternatives Considered table in RESEARCH.md already ruled out a wrapper).

**Pure-function pattern to mirror** (lines 112-119):
```swift
// Phase 28 / CALVIEW-02 — the day-detail event filter Plan 03's calendarFullView reads
// through. Identical contract to nextRelevantEvent: Foundation-only, total, never crashes on
// an empty `events` array.
func events(on day: Date, events: [EventInput], calendar: Calendar = .current) -> [EventInput] {
    events
        .filter { calendar.isDate($0.start, inSameDayAs: day) }
        .sorted { $0.start < $1.start }
}
```
Every pure function in this file follows the exact same contract: `calendar: Calendar = .current` defaulted last param, Foundation-only (no EventKit/AppKit import), total (never crashes on empty input), doc comment naming the originating Phase/requirement ID. `eventsByDay(events:calendar:)` must match this contract exactly (RESEARCH.md Pattern 1 already gives the literal implementation to drop in — no further design needed).

---

### `Islet/Calendar/CalendarService.swift` — add `updateEvent`/`deleteEvent`

**Analog:** same file, `createEvent`/`createReminder` (protocol lines 35-46, implementation lines 136-177)

**Protocol doc-comment convention** (lines 35-39):
```swift
/// Create a new Calendar event via the quick-add UI.
/// - Note: `completion` is ALWAYS delivered on the MAIN thread (contract — see file header).
///   D-06: no new permission request here — Calendar write access is already covered by
///   `requestFullAccessToEvents()` elsewhere in this file. Settles `false` on any save error.
func createEvent(title: String, start: Date, end: Date, completion: @escaping (Bool) -> Void)
```
New protocol methods must carry the same "MAIN thread" + "no new permission request" + "settles false on error" doc-comment shape.

**Implementation pattern** (lines 136-150):
```swift
func createEvent(title: String, start: Date, end: Date, completion: @escaping (Bool) -> Void) {
    // D-06: no new permission request needed — full write access to Events is already
    // granted via requestFullAccessToEvents() (called from fetchUpcoming/fetchMonth).
    let event = EKEvent(eventStore: store)
    event.title = title // T-14-06: plain String, never interpolated.
    event.startDate = start
    event.endDate = end
    event.calendar = store.defaultCalendarForNewEvents
    do {
        try store.save(event, span: .thisEvent)
        completion(true)
    } catch {
        completion(false) // T-28-05: never crash on a thrown save error.
    }
}
```
`updateEvent`/`deleteEvent` swap the `EKEvent(eventStore:)` construction for `store.event(withIdentifier:) as? EKEvent` lookup (guard-else `completion(false)`, never crash — same `T-28-05` discipline), then `store.save(_:span:)` / `store.remove(_:span:)` inside the same `do/catch → completion(false)` shape. RESEARCH.md's Code Examples section already has the exact drop-in bodies for both.

**mapToEventInput extension point** (lines 124-134):
```swift
private func mapToEventInput(_ ek: EKEvent) -> EventInput {
    var red = 1.0, green = 1.0, blue = 1.0
    if let rgb = ek.calendar.color.usingColorSpace(.deviceRGB) {
        red = Double(rgb.redComponent)
        green = Double(rgb.greenComponent)
        blue = Double(rgb.blueComponent)
    }
    // T-14-06: ek.title is UNTRUSTED — passed through as a plain String only.
    return EventInput(title: ek.title ?? "", start: ek.startDate, end: ek.endDate,
                      colorRed: red, colorGreen: green, colorBlue: blue)
}
```
Add `id: ek.eventIdentifier ?? ""` to this single `EventInput(...)` construction — it is the ONE call site (already factored out per the `WR-04` comment) that both `fetchUpcoming` and `fetchMonth` route through, so this is the only place needing a touch for the identifier to reach the view layer.

---

### `Islet/Notch/NotchPillView.swift` — `monthGridColumn` (badge swap, weekday header, chevron spacing, font size)

**Analog:** same computed property (lines 1630-1680)

**Chevron spacing (D-10) — current code** (lines 1632-1650):
```swift
HStack {
    Button(action: { onCalendarMonthChange(-1) }) {
        Image(systemName: "chevron.left")
            .font(.system(size: 12))
            .foregroundStyle(.white.opacity(0.7))
    }
    .buttonStyle(.plain)
    Spacer()
    Text(calendarViewState.visibleMonth, format: .dateTime.month(.wide).year())
        .font(.system(size: 13, weight: .semibold, design: .rounded))
        .foregroundStyle(.white)
    Spacer()
    Button(action: { onCalendarMonthChange(1) }) {
        Image(systemName: "chevron.right")
            .font(.system(size: 12))
            .foregroundStyle(.white.opacity(0.7))
    }
    .buttonStyle(.plain)
}
```
Two bare `Spacer()`s push the chevrons to the outer edges — D-10 ("move closer together") means replacing one/both `Spacer()` with a fixed-width `Spacer().frame(maxWidth: N)` or wrapping the whole `HStack` differently; this is a layout-constant change only, no structural rework.

**Badge swap (D-03) — current code, the exact pair to invert together** (lines 1654-1672):
```swift
let isSelected = Calendar.current.isDate(day, inSameDayAs: calendarViewState.selectedDay)
let isToday = Calendar.current.isDateInToday(day)
let hasEvents = calendarViewState.monthEvents.map { !events(on: day, events: $0).isEmpty } ?? false
ZStack(alignment: .bottom) {
    Text(day, format: .dateTime.day())
        .font(.system(size: 9, weight: isSelected ? .semibold : .regular, design: .rounded))
        .foregroundStyle(.white)
        .frame(width: Self.calendarCellSize, height: Self.calendarCellSize)
        .background(Circle().fill(Color.white.opacity(isSelected ? 0.18 : 0)))
        .overlay(Circle().strokeBorder(Color.white.opacity(isToday && !isSelected ? 0.6 : 0), lineWidth: 1))
    if hasEvents {
        Circle()
            .fill(Color.white.opacity(0.6))
            .frame(width: 2, height: 2)
            .offset(y: -1)
    }
}
.frame(width: Self.calendarCellSize, height: Self.calendarCellSize)
.onTapGesture { onCalendarDaySelect(day) }
```
Per RESEARCH.md Pitfall 3, the `.background(...)` (currently keyed on `isSelected`, fill) and `.overlay(...)` (currently keyed on `isToday && !isSelected`, stroke) modifiers must be swapped AS A PAIR: `.background` → keyed on `isToday` with `Color.red` fill; `.overlay` → keyed on `isSelected && !isToday` with red `strokeBorder`. `hasEvents` dot block is untouched per D-04 (kept, per RESEARCH.md's Open Question #2 recommendation).

**Font size (D-11):** the `.font(.system(size: 9, ...))` on the day-number `Text` (line 1660) is the value to bump — cross-check against `Self.calendarCellSize` (18pt, line 854) and `Self.calendarCellGap` (2pt, line 855) so the larger glyph still fits the fixed 18×18pt cell frame without clipping.

**Weekday header row (net-new, Pattern 3 in RESEARCH.md) — no analog in this codebase; use the exact code RESEARCH.md already derived:**
```swift
private var rotatedWeekdaySymbols: [String] {
    let calendar = Calendar.current
    let symbols = calendar.veryShortWeekdaySymbols   // index 0 = Sunday, always
    let firstWeekdayIndex = calendar.firstWeekday - 1 // Calendar.firstWeekday is 1-based
    return Array(symbols[firstWeekdayIndex...] + symbols[..<firstWeekdayIndex])
}
```
Render as a `HStack`/`LazyVGrid` row of 7 `Text` cells, each sized `Self.calendarCellSize` wide with `Self.calendarCellGap` spacing — MUST reuse the same two constants the day-grid's own `LazyVGrid` uses (lines 1651-1652) or the letters will not align with the date columns beneath (RESEARCH.md Pitfall 2's exact warning).

---

### `Islet/Notch/NotchPillView.swift` — `dayListColumn`/`dayEventsList` → scrollable multi-day agenda

**Analog:** same file, `dayListColumn` (1686-1707) + `dayEventsList` (1733-1763)

**Current single-day structure to replace** (lines 1686-1707):
```swift
private var dayListColumn: some View {
    let dayEvents = calendarViewState.monthEvents.map { events(on: calendarViewState.selectedDay, events: $0) }
    return VStack(alignment: .trailing, spacing: 4) {
        HStack {
            QuickAddPopover(onSubmit: onQuickAdd, selectedDay: calendarViewState.selectedDay)
            Spacer()
        }
        Group {
            if let dayEvents {
                if dayEvents.isEmpty {
                    calendarEmptyState
                } else {
                    dayEventsList(dayEvents)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
}
```
This becomes `eventsByDay(events: calendarViewState.monthEvents ?? [], calendar: .current)`-driven, wrapped in the `ScrollViewReader` from RESEARCH.md Pattern 2 (`.onChange(of: calendarViewState.selectedDay) { proxy.scrollTo(...) }`). The `nil` → render-nothing / `[]` → `calendarEmptyState` distinction (Pitfall 4, "never flash empty before first fetch") must be preserved at the whole-month level, not per-day.

**Row styling to extend, not replace** (lines 1733-1763, `dayEventsList`):
```swift
private func dayEventsList(_ dayEvents: [EventInput]) -> some View {
    ScrollView(.vertical) {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(dayEvents.enumerated()), id: \.offset) { _, event in
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(red: event.colorRed, green: event.colorGreen, blue: event.colorBlue))
                        .frame(width: 6, height: 6)
                    Text(event.title)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 4)
                    Text(event.start, format: .dateTime.hour().minute())
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                )
            }
        }
    }
    .scrollIndicators(.never)
}
```
CRITICAL per RESEARCH.md Anti-Patterns: this uses `id: \.offset` for pure display — safe here, but the NEW edit/delete closures on each row must capture the real `event.id` (the `EKEvent` identifier field added to `EventInput`), never the array offset. Keep `.lineLimit(1)`/`.truncationMode(.tail)` on `event.title` (T-14-06 mandatory for untrusted EventKit strings) — the new hover tooltip (D-12) is ADDITIONAL render surface for the same untrusted string and needs the same discipline (plain `Text` only, never interpolated).

**Hover-reveal delete icon — analog is `TransportButton`, NOT the controller-owned hover pattern** (lines 4552-4572):
```swift
private struct TransportButton: View {
    let systemName: String
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isHovering ? Color.white.opacity(0.40) : Color.clear)
                )
        }
        .frame(width: 32, height: 32)
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}
```
Per RESEARCH.md Pitfall 4, the new per-row event view (extracted from the inline `ForEach` body above) must be its own small private `View` struct with local `@State private var isHovering = false` + `.onHover { isHovering = $0 }`, gating the trash-icon's visibility — explicitly NOT the controller-owned `presentationState.hoveredQuickActionButtonIndex` pattern used elsewhere in this file (see next excerpt for contrast, so the planner does not reach for the wrong precedent by proximity).

**Contrast — the WRONG pattern to avoid for this feature** (controller-owned hover state, do not mirror for per-row event hover):
```swift
// line 2108 call site:
isHovered: presentationState.hoveredQuickActionButtonIndex == index)
```
This indexes a FIXED, small set of buttons by position — fragile for an unbounded, re-sortable/re-fetching `ForEach` of events (exact reasoning in RESEARCH.md Pitfall 4).

**Edit popover — analog is `QuickAddPopover`, pre-filled instead of blank** (lines 4949-5047, trigger + content shape):
```swift
private struct QuickAddPopover: View {
    @State private var isShowing = false
    @State private var kind: QuickAddKind = .event
    @State private var title = ""
    @State private var startTime: Date = Date()
    @State private var endTime: Date = Date()
    @State private var endManuallyEdited = false
    @State private var isProgrammaticEndUpdate = false
    let onSubmit: (QuickAddKind, String, Date, Date?) -> Void
    let selectedDay: Date

    var body: some View {
        Button(action: { isShowing = true }) {
            Text("+ Add")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.12))
                )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isShowing, arrowEdge: .trailing) {
            quickAddContent
        }
        .onChange(of: isShowing) { _, newValue in
            guard newValue else { return }
            let seed = defaultQuickAddTime(selectedDay: selectedDay, now: Date())
            startTime = seed
            endTime = seed.addingTimeInterval(3600)
            endManuallyEdited = false
        }
    }
    ...
    // Submit-button guard (line 5024, V5 Input Validation — reuse verbatim for the edit popover):
    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedTitle.isEmpty else { return }
```
A new sibling `private struct EventEditPopover: View` (D-07) mirrors this shape exactly: `Button` trigger → `.popover(isPresented:)` → `quickAddContent`-equivalent form, but `.onChange(of: isShowing)` seeds `title`/`startTime`/`endTime` FROM the tapped `EventInput` (not from `defaultQuickAddTime`), plus a `let eventID: String` stored property threaded through to the new `onSubmit`/`onEventEdit` closure. The trimmed-empty-title guard (line 5024) must be reused verbatim per RESEARCH.md's V5 Input Validation note — do not skip it just because the field starts pre-filled.

---

### `Islet/Notch/NotchWindowController.swift` — `handleEventEdit`/`handleEventDelete`

**Analog:** same file, `handleQuickAdd`/`handleCalendarDaySelect` (lines 2444-2463)

**Handler shape to mirror** (lines 2448-2463):
```swift
// Phase 28 / CALVIEW-03 — quick-add for both Event and Reminder, routed through the SAME
// shared CalendarService (CALVIEW-04). ... refreshes the month afterward so a new event
// appears in the day list immediately ...
private func handleQuickAdd(_ kind: QuickAddKind, title: String, start: Date, end: Date?) {
    switch kind {
    case .event:
        calendarService.createEvent(title: title, start: start, end: end ?? start.addingTimeInterval(3600)) { [weak self] _ in
            self?.refreshCalendarMonth()
        }
    case .reminder:
        calendarService.createReminder(title: title, dueDate: start) { _ in }
    }
}
```
`handleEventEdit(id:title:start:end:)` / `handleEventDelete(id:)` follow the identical shape: call the matching `CalendarService` method, `[weak self]` completion closure calls `self?.refreshCalendarMonth()` on success (mirrors the diagram in RESEARCH.md's System Architecture section exactly — "refreshCalendarMonth() ... re-fetches monthEvents, agenda re-groups automatically").

**View-initializer wiring convention to extend** (lines 3122-3127, the closure-forwarding block):
```swift
onSwitcherSelect: { [weak self] view in self?.handleSwitcherSelect(view) },
onCalendarMonthChange: { [weak self] delta in self?.handleCalendarMonthChange(delta) },
onCalendarDaySelect: { [weak self] day in self?.handleCalendarDaySelect(day) },
// Phase 46-02 / CALVIEW-05 — forwards QuickAddPopover's real picked Start/End
// (Event) or Due (Reminder) Date(s) into handleQuickAdd.
onQuickAdd: { [weak self] kind, title, start, end in self?.handleQuickAdd(kind, title: title, start: start, end: end) },
```
New `onEventEdit`/`onEventDelete` closures get added to this same trailing-closure list in `NotchPillView(...)`'s call site, `[weak self]`-captured, one-line forward to the new controller methods — no new wiring mechanism.

---

### `IsletTests/CalendarGlanceTests.swift` — tests for `eventsByDay`

**Analog:** same file, `testEventsOnDayReturnsOnlyMatchingDaySortedAscending`/`testEventsOnDayReturnsEmptyArrayForEmptyEventsWithoutCrashing` (lines 111-134):
```swift
func testEventsOnDayReturnsOnlyMatchingDaySortedAscending() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    let day = calendar.date(from: DateComponents(year: 2026, month: 7, day: 15))!
    let otherDay = calendar.date(from: DateComponents(year: 2026, month: 7, day: 16))!
    let later = EventInput(title: "Later", start: calendar.date(byAdding: .hour, value: 14, to: day)!,
                            end: calendar.date(byAdding: .hour, value: 15, to: day)!,
                            colorRed: 0, colorGreen: 0, colorBlue: 0)
    let earlier = EventInput(title: "Earlier", start: calendar.date(byAdding: .hour, value: 9, to: day)!,
                              end: calendar.date(byAdding: .hour, value: 10, to: day)!,
                              colorRed: 0, colorGreen: 0, colorBlue: 0)
    let otherDayEvent = EventInput(title: "Other Day", start: otherDay, end: otherDay.addingTimeInterval(3600),
                                    colorRed: 0, colorGreen: 0, colorBlue: 0)
    let result = events(on: day, events: [later, otherDayEvent, earlier], calendar: calendar)
    XCTAssertEqual(result, [earlier, later])
}

func testEventsOnDayReturnsEmptyArrayForEmptyEventsWithoutCrashing() {
    let result = events(on: Date(), events: [])
    XCTAssertEqual(result, [])
}
```
New tests for `eventsByDay(events:calendar:)` follow the same shape: fixed UTC `Calendar(identifier: .gregorian)`, hand-constructed `EventInput` fixtures (now requiring the new `id:` field — use any placeholder string, e.g. `"test-id"`), `XCTAssertEqual` against an expected `[(day: Date, events: [EventInput])]` array, plus one empty-input-never-crashes case (T-14-02 discipline, present in every pure-function test group in this file). NOTE: `EventInput` gains a new `id: String` field — every existing fixture construction in this file (11 call sites) will need that field added once `id` lands; this is a mechanical, non-semantic edit across the existing tests, not new test design.

## Shared Patterns

### Pattern 3 discipline — "taps only report intent"
**Source:** `Islet/Notch/NotchPillView.swift` lines 1615-1616 (doc comment) + `NotchWindowController.swift` lines 2444-2463
**Apply to:** All new view-layer taps (event-row tap → edit popover, trash-icon tap → delete, grid-tap → scroll)
No navigation/date/EventKit math lives in the view — every new interaction reports intent via a closure (`onEventEdit`/`onEventDelete`, mirroring `onCalendarDaySelect`/`onQuickAdd`'s exact shape) and the controller performs the real work + `refreshCalendarMonth()`.

### T-14-06 — untrusted EventKit string discipline
**Source:** `Islet/Calendar/CalendarService.swift` lines 11-14 (file header) + `NotchPillView.swift` line 1745-1746 (`.lineLimit(1)`/`.truncationMode(.tail)`)
**Apply to:** Event-row title rendering, new hover tooltip (D-12), edit popover's pre-filled `TextField`
`ek.title` (and therefore `EventInput.title`) is untrusted external data. Plain `String` only, never interpolated into format/log/shell strings; render-time bounding required everywhere it's displayed, including the new tooltip surface.

### T-28-05 — never crash on a thrown EventKit save/remove error
**Source:** `Islet/Calendar/CalendarService.swift` lines 144-149 (`createEvent`'s `do/catch`)
**Apply to:** New `updateEvent`/`deleteEvent` methods
`do { try store.save/remove(...) ; completion(true) } catch { completion(false) }` — identical shape, no new error type, no retry/nag.

### Per-tab width-scaling (Phase 32/67.1) — reuse, do not extend
**Source:** `Islet/Notch/NotchPillView.swift` line 96 (`Self.calendarWidth * resolvedWidthScale`) + line 1001 (`static let calendarWidth: CGFloat = 472`) + lines 2902-2904 (`resolvedWidthScale`)
```swift
static let calendarWidth: CGFloat = 472
...
private var resolvedWidthScale: CGFloat {
    resolvedIslandScale(auto: autoIslandScale, manualOffset: 0)
}
```
**Apply to:** Any island-widening need from this phase (SC#5) — bump the `calendarWidth` constant only; `resolvedWidthScale` already applies automatically to every `.calendarExpanded` frame (line 96). No new scaling mechanism should be built.

### Popover trigger pattern
**Source:** `Islet/Notch/NotchPillView.swift` lines 4973-4988 (`QuickAddPopover.body`)
**Apply to:** New `EventEditPopover` (D-07)
`Button(action: { isShowing = true }) { ...chip styling... }.popover(isPresented: $isShowing, arrowEdge: .trailing) { content }` — reuse the exact chip visual (`RoundedRectangle` + `Color.white.opacity(0.12)` fill, per that file's own "chipButton convention" comment at line 4970) for visual consistency between quick-add and edit triggers.

## No Analog Found

None. Every file/change in this phase has a direct existing precedent in the same file or module (RESEARCH.md's own "Key insight": extension-by-analogy throughout). The one genuinely net-new element — the weekday header row — still has a fully-specified implementation in RESEARCH.md's Pattern 3 (no analog needed; it's a straight Foundation `Calendar` API composition, not a UI pattern requiring a codebase precedent).

## Metadata

**Analog search scope:** `Islet/Notch/NotchPillView.swift`, `Islet/Notch/NotchWindowController.swift`, `Islet/Calendar/CalendarService.swift`, `Islet/Calendar/CalendarGlance.swift`, `Islet/Calendar/CalendarViewState.swift`, `IsletTests/CalendarGlanceTests.swift` — all 6 files this phase touches, no broader search needed since every change is same-file/same-module extension (confirmed via RESEARCH.md's exhaustive line-numbered live-codebase reads).
**Files scanned:** 6 (all fully read or targeted-range read; `NotchPillView.swift` and `NotchWindowController.swift` read via non-overlapping targeted ranges per their >2000-line size).
**Pattern extraction date:** 2026-07-30
