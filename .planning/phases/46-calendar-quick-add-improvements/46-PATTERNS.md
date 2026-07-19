# Phase 46: Calendar Quick-Add Improvements - Pattern Map

**Mapped:** 2026-07-19
**Files analyzed:** 3 modified (0 new files — pure refinement of Phase 28's shipped feature)
**Analogs found:** 3 / 3 (all self-analogs — this phase extends existing structures in place)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|--------------------|------|-----------|-----------------|----------------|
| `Islet/Notch/NotchPillView.swift` (`QuickAddPopover`, `dayListColumn`, `dayEventsList`, `tabWidth`/`tabHeight`, `calendarWidth`/new `calendarContentHeight`) | component | request-response (render + user action) | itself — Phase 45's `tabWidth`/`tabHeight` switch (L94-109) is the exact mechanism for D-08; Phase 28's `QuickAddPopover`/`dayListColumn`/`dayEventsList` are what D-01..D-11 extend in place | exact (self-analog) |
| `Islet/Notch/NotchWindowController.swift` (`handleQuickAdd`, `onQuickAdd` closure signature) | controller | event-driven | itself — `handleQuickAdd` (L1651-1661) is the sole call site to widen | exact (self-analog) |
| `Islet/Calendar/CalendarGlance.swift` (new pure helper, e.g. `defaultQuickAddTime(selectedDay:now:)`) | utility (pure business logic) | transform | itself — `nextRelevantEvent(events:now:)` (L37+) is the "explicit `now:` parameter, Foundation-only, total function" pattern this new helper must follow | exact (self-analog) |

**No new files.** `CalendarService.swift`'s `createEvent(title:start:end:completion:)` / `createReminder(title:dueDate:completion:)` (lines ~136, ~152) already accept full `Date` parameters — zero EventKit-layer changes.

## Pattern Assignments

### `Islet/Notch/NotchPillView.swift` — `QuickAddPopover` struct (CALVIEW-05, D-01..D-05, D-07)

**Analog:** itself (`Islet/Notch/NotchPillView.swift:3125-3193`)

**Current full struct** (lines 3125-3193) — this is what gets extended, not replaced:
```swift
private struct QuickAddPopover: View {
    @State private var isShowing = false
    @State private var kind: QuickAddKind = .event
    @State private var title = ""
    let onSubmit: (QuickAddKind, String) -> Void

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
        .popover(isPresented: $isShowing) {
            quickAddContent
        }
    }

    private var quickAddContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Type", selection: $kind) {
                Text("Event").tag(QuickAddKind.event)
                Text("Reminder").tag(QuickAddKind.reminder)
            }
            .pickerStyle(.segmented)
            TextField("What's this for?", text: $title)
                .font(.system(size: 12, weight: .regular, design: .rounded))
            Button(action: {
                let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedTitle.isEmpty else { return }
                onSubmit(kind, trimmedTitle)
                title = ""
                isShowing = false
            }) {
                Text(kind == .event ? "Add Event" : "Add Reminder")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.12))
                    )
            }
            .buttonStyle(.plain)
            .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(12)
        .frame(width: 220)
    }
}
```

**What changes (per UI-SPEC Layout Contract + CONTEXT D-01..D-07):**
- `onSubmit` signature grows to carry the picked date(s): `(QuickAddKind, String, Date, Date?) -> Void` (start/due, optional end for Reminder-hides-End) — pick ONE shape the planner locks; must thread through to `NotchWindowController.onQuickAdd`.
- `.popover(isPresented: $isShowing)` gains `arrowEdge: .trailing` (D-07) — the existing call has no `attachmentAnchor`/`arrowEdge` argument today, add it directly to this exact call site (line 3148).
- New `@State` for `startTime: Date`, `endTime: Date`, `endManuallyEdited: Bool = false` — seeded via the new pure helper (see `CalendarGlance.swift` below), NOT via inline `Date()`.
- Inside `quickAddContent`'s `VStack(alignment: .leading, spacing: 8)` (unchanged container, spacing token already 8pt — matches UI-SPEC's "sm" token), insert `if kind == .event { startRow; endRow } else { dueRow }` — new private helper views following the SAME row shape: `HStack { Text(label)...; DatePicker("", selection: $binding, displayedComponents: .hourAndMinute).datePickerStyle(.compact) }`.
- `endManuallyEdited` resets on `isShowing` false→true transition — mirrors this file's existing `@State` reset-on-popover-dismiss convention (no direct precedent in THIS struct, but `OnboardingDoneStep`'s reset-to-system-state pattern at line 3239-3241 is the closest "revert local `@State` to a known-good value" idiom in this file).
- Popover width 220 → 240 (UI-SPEC "Popover width" row) — the single `.frame(width: 220)` at line 3191 is the one call site.

**Segmented Picker convention already established, do not touch** (lines 3158-3162) — reused verbatim, no change needed.

**Trimmed-title guard convention already established, do not touch** (lines 3169-3170) — the new `onSubmit` call just gains extra Date arguments alongside the existing `kind, trimmedTitle`.

---

### `Islet/Notch/NotchPillView.swift` — `dayListColumn` (CALVIEW-06, D-06, D-07)

**Analog:** itself (lines 1158-1179)

**Current code to flip** (lines 1160-1166):
```swift
return VStack(alignment: .trailing, spacing: 4) {
    // CALVIEW-03 — the "+ Add" trigger, top-right of the day-list column
    // (28-UI-SPEC.md Layout Contract).
    HStack {
        Spacer()
        QuickAddPopover(onSubmit: onQuickAdd)
    }
```
**Change (D-06):** flip child order to `HStack { QuickAddPopover(onSubmit: onQuickAdd); Spacer() }` — same `VStack(alignment: .trailing, spacing: 4)` outer container, no structural move out of `dayListColumn` (per D-06's explicit "no structural move" instruction).

---

### `Islet/Notch/NotchPillView.swift` — `dayEventsList` row padding (CALVIEW-07, D-09)

**Analog:** itself (lines 1205-1234)

**Current row styling to bump** (lines 1207, 1224-1225):
```swift
VStack(alignment: .leading, spacing: 6) {          // → spacing: 8 (D-09)
    ForEach(...) { _, event in
        HStack(spacing: 6) { ... }
        .padding(.horizontal, 8)                    // → 12 (D-09)
        .padding(.vertical, 5)                       // → 8 (D-09)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.06))     // UNCHANGED — reuse exactly
        )
    }
}
```
Three exact-number edits, nothing structural — row background/corner-radius/color convention (`Color.white.opacity(0.06)`, 8pt radius) is explicitly "Unchanged" per UI-SPEC Color section, do not touch.

---

### `Islet/Notch/NotchPillView.swift` — `calendarWidth` / new `calendarContentHeight` (CALVIEW-07, D-08, D-10)

**Analog:** Phase 45's `tabWidth`/`tabHeight` per-case switch (lines 94-109) — THE established mechanism for per-tab size overrides, more precise than the older `blobShape height:` override text in CONTEXT.md's D-08 note (that mechanism now lives here, one layer up):
```swift
var tabWidth: CGFloat {
    switch presentation {
    case .calendarExpanded: return Self.calendarWidth
    case .trayExpanded: return Self.traySize.width
    default: return Self.expandedSize.width
    }
}

var tabHeight: CGFloat {
    switch presentation {
    case .calendarExpanded: return Self.switcherContentHeight   // ← CHANGE to Self.calendarContentHeight
    case .trayExpanded: return Self.trayContentHeight
    case .weatherExpanded: return weatherStyle == .large ? Self.weatherLargeContentHeight : Self.weatherMediumContentHeight
    default: return Self.homeContentHeight
    }
}
```
**Change:** add `static let calendarContentHeight: CGFloat = 220` (new constant, doc-commented analogously to `trayContentHeight`/`weatherLargeContentHeight`'s own box-math comments at lines ~611-637) near `calendarWidth` (line 709); flip line 104's `.calendarExpanded` case in `tabHeight` from `Self.switcherContentHeight` to `Self.calendarContentHeight`. `calendarWidth` itself (line 709) is a one-line constant edit: `460` → `472`.

**Do NOT touch** `Self.switcherContentHeight` (line 638, 196pt) — Home/NowPlaying/default `tabHeight` branches still fall through to it via `Self.homeContentHeight`/`default:`; confirm during planning which constant `default:` actually resolves to (verify `homeContentHeight` is NOT the same symbol as `switcherContentHeight` before assuming zero collateral change — grep both names at plan time).

---

### `Islet/Notch/NotchWindowController.swift` — `handleQuickAdd` (CALVIEW-05 wiring)

**Analog:** itself (lines 1651-1661)

**Current code:**
```swift
private func handleQuickAdd(_ kind: QuickAddKind, title: String) {
    let day = calendarViewState.selectedDay
    switch kind {
    case .event:
        calendarService.createEvent(title: title, start: day, end: day.addingTimeInterval(3600)) { [weak self] _ in
            self?.refreshCalendarMonth()
        }
    case .reminder:
        calendarService.createReminder(title: title, dueDate: day) { _ in }
    }
}
```
**Change:** signature grows to accept the picked `Date`(s) from `QuickAddPopover`'s widened `onSubmit`, e.g. `handleQuickAdd(_ kind: QuickAddKind, title: String, start: Date, end: Date)` (End ignored for `.reminder`, passed as `dueDate: end` or a separate optional — planner's call, see CONTEXT.md's "Claude's Discretion" note). Both `CalendarService` calls need ZERO changes — `createEvent(title:start:end:completion:)` / `createReminder(title:dueDate:completion:)` already accept arbitrary `Date`s (verified at `CalendarService.swift:136,152`); only the arguments passed here change from `day`/`day.addingTimeInterval(3600)` to the real picked values.

**Sibling call site to update in lockstep** — `NotchPillView`'s `onQuickAdd` property (line 219: `var onQuickAdd: (QuickAddKind, String) -> Void = { _, _ in }`) and its wiring at `NotchWindowController.swift:2011` (`onQuickAdd: { [weak self] kind, title in self?.handleQuickAdd(kind, title: title) }`) — both closure signatures must widen identically to `QuickAddPopover.onSubmit`'s new signature. Three sites, one signature — same "keep call sites in lockstep" discipline the 28-PATTERNS.md CR-01 click-through section already established for this codebase (different feature, same discipline).

---

### `Islet/Calendar/CalendarGlance.swift` — new pure default-time helper (CALVIEW-05 default time rule)

**Analog:** itself — `nextRelevantEvent(events:now:)` (lines 37+) and the file's own header discipline (lines 1-11):
```swift
import Foundation

// `now` is ALWAYS an explicit parameter -- never Date()/Date.now inside this function --
// mirroring DeviceActivity.swift's "caller passes now" discipline so tests stay deterministic.
func nextRelevantEvent(events: [EventInput], now: Date) -> CalendarGlance? {
    let calendar = Calendar.current
    if let todayEvent = events
        .filter({ calendar.isDate($0.start, inSameDayAs: now) && $0.end > now })
        .sorted(by: { $0.start < $1.start })
        .first {
        return CalendarGlance(title: todayEvent.title, startDate: todayEvent.start, isToday: true, ...)
    }
    // ... tomorrow fallback, then nil
}
```
**New helper to add**, same file, same discipline (Foundation-only, `now:`/`selectedDay:` explicit parameters, total function, `Calendar.current`):
```swift
// CALVIEW-05 default time — next full hour if selectedDay is today, else 00:00.
func defaultQuickAddTime(selectedDay: Date, now: Date) -> Date {
    let calendar = Calendar.current
    guard calendar.isDateInToday(selectedDay) else {
        return calendar.startOfDay(for: selectedDay)
    }
    let nextHour = calendar.date(byAdding: .hour, value: 1, to: now) ?? now
    let components = calendar.dateComponents([.year, .month, .day, .hour], from: nextHour)
    return calendar.date(from: components) ?? nextHour
}
```
Called from `QuickAddPopover`'s `@State` initial-value seed (via `.onAppear`/`isShowing` toggle, since `@State` default values can't call an instance method with live `calendarViewState.selectedDay`) — never `Date()` inline inside `NotchPillView.swift` (hard project convention, reaffirmed in UI-SPEC's Verification Notes).

**Test analog** — `IsletTests/CalendarGlanceTests.swift` (whole file, established Given/When/Then + `XCTAssertEqual` shape, per `28-PATTERNS.md`'s own Tests section) is where a `defaultQuickAddTime` unit test belongs, same file, same shape.

---

## Shared Patterns

### Explicit `now:`/reference-date parameter, no inline `Date()` in pure logic
**Source:** `Islet/Calendar/CalendarGlance.swift` lines 1-11, 37
**Apply to:** The new `defaultQuickAddTime(selectedDay:now:)` helper — this is the ONE hard constraint UI-SPEC's Verification Notes calls out explicitly for this phase.

### Per-tab width/height override via `tabWidth`/`tabHeight` switch (NOT `blobShape height:` directly)
**Source:** `Islet/Notch/NotchPillView.swift` lines 94-109 (Phase 45 consolidation)
**Apply to:** `calendarContentHeight`'s wiring (D-08) — this switch is now the single source of truth `blobShape`'s `height:`/`width:` parameters read from (see call site at line 840).

### Reusable chrome primitives — do not reimplement
**Source:** `Islet/Notch/NotchPillView.swift` — `chipButton` (L1859), segmented `Picker` convention (`Islet/SettingsView.swift` L238-242, already used at L3158-3162)
**Apply to:** Any new button/label inside `quickAddContent` — reuse existing font/padding/fill conventions verbatim (12px semibold rounded trigger, 14px semibold rounded submit, `Color.white.opacity(0.12)` fill).

### Untrusted external text handling (T-14-06) — unaffected but must not regress
**Source:** `Islet/Notch/NotchPillView.swift` line 1213-1217 (`.lineLimit(1)`/`.truncationMode(.tail)` on `dayEventsList`'s `event.title`)
**Apply to:** Verify these two modifiers survive the D-09 padding edit untouched — this phase changes padding numbers only, not the `Text(event.title)` modifier chain.

### Lockstep call-site signature changes (3-site discipline)
**Source:** `28-PATTERNS.md`'s CR-01 click-through precedent (different feature, same discipline) — this phase's own 3 sites are: `QuickAddPopover.onSubmit` (NotchPillView.swift ~3129), `NotchPillView.onQuickAdd` property (~219), `NotchWindowController.handleQuickAdd` + its wiring closure (~1651, ~2011)
**Apply to:** Any plan touching quick-add's Date-passing — all 3-4 sites must change together or the build breaks.

## No Analog Found

| File/Element | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `DatePicker(.compact)` usage | UI control | request-response | No existing `DatePicker` anywhere in the codebase (grep confirms zero hits in `NotchPillView.swift`) — this is a first-party SwiftUI control per UI-SPEC's Registry Safety note, no in-house analog exists; follow standard SwiftUI `DatePicker(_:selection:displayedComponents:)` API + `.onChange(of:)` (the file's own `OnboardingDoneStep.launchAtLogin` `.onChange` at line 3226 is the closest same-file `.onChange` idiom to copy for `endManuallyEdited`'s flip-on-edit logic). |

## Metadata

**Analog search scope:** `Islet/Notch/NotchPillView.swift`, `Islet/Notch/NotchWindowController.swift`, `Islet/Calendar/CalendarGlance.swift`, `Islet/Calendar/CalendarViewState.swift`, `Islet/Calendar/CalendarService.swift`, `.planning/phases/28-calendar-full-view/28-PATTERNS.md`, `.planning/phases/44-tray-quick-action-width-alignment/`, `.planning/phases/45-view-switcher-morph-fix/`
**Files scanned:** 5 Swift source files (targeted line ranges) + 1 prior PATTERNS.md (whole file, reused as a base since this phase modifies files that same map already fully classified)
**Pattern extraction date:** 2026-07-19
