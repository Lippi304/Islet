---
phase: 28-calendar-full-view
reviewed: 2026-07-13T15:50:00Z
depth: standard
files_reviewed: 11
files_reviewed_list:
  - Islet/Calendar/CalendarGlance.swift
  - Islet/Calendar/CalendarService.swift
  - Islet/Calendar/CalendarViewState.swift
  - Islet/Notch/IslandResolver.swift
  - Islet/Notch/NotchPillView.swift
  - Islet/Notch/NotchWindowController.swift
  - Islet/Notch/ViewSwitcherState.swift
  - Islet/Shelf/ShelfViewState.swift
  - IsletTests/CalendarGlanceTests.swift
  - IsletTests/IslandResolverTests.swift
  - project.yml
findings:
  critical: 2
  warning: 4
  info: 2
  total: 8
status: issues_found
---

# Phase 28: Code Review Report

**Reviewed:** 2026-07-13T15:50:00Z
**Depth:** standard
**Files Reviewed:** 11
**Status:** issues_found

## Summary

Reviewed the Calendar Full View phase after its 6-round on-device UAT history, with
particular attention to (1) leftover dead code from superseded approaches (`forcedByTray`,
`isCalendarPresentation`, `calendarContentHeight`) — confirmed fully removed, only historical
comments remain; (2) whether `IslandResolverTests.swift` covers the final round-5 precedence
(Tray as its own `IslandPresentation` case) — confirmed it does, tests are current, not stale;
and (3) whether the SwiftUI content geometry (`NotchPillView.swift`) and the AppKit panel/
click-through geometry (`NotchWindowController.swift`) stayed in lockstep through the repeated
geometry rewrites — this is where the real defects are. Tracing the exact boolean/height math
at every call site turned up a genuine click-through regression in the new dedicated Tray view
(the same CR-01 "phantom interactive band" bug class this codebase has hit before), plus a
calendar quick-add logic bug where month navigation silently desyncs the "selected day" from
what's visually displayed. The pure seams (`IslandResolver.swift`, `CalendarGlance.swift`) are
clean, total, and well-tested; the defects are concentrated in the AppKit/SwiftUI geometry glue
and in a couple of quality/duplication issues in the newer view code.

## Critical Issues

### CR-01: Tray view's click-through zone extends into a phantom, non-rendered band when the shelf has items

**File:** `Islet/Notch/NotchWindowController.swift:969-994` (specifically line 976), cross-referenced
with `Islet/Notch/NotchPillView.swift:713-726` (`trayFullView`)

**Issue:** `trayFullView` deliberately calls `blobShape(..., shelfItems: [], shelfVisible: false,
showSwitcher: true)` — it passes `shelfVisible: false` on purpose (per its own doc comment) so
the additive shelf strip is never appended a second time below the Tray card, since Tray's own
content already **is** the files view. This makes `blobShape`'s internal `hasShelf` false for
Tray, so the actually-rendered black shape height is `switcherContentHeight + switcherRowHeight`
(240pt), never `+ shelfRowHeight`.

However, `NotchWindowController.visibleContentZone()` (the function that decides which region of
the panel is click-through-interactive) computes its own `shelfHeight` purely from the **global**
`shelfViewState.isVisible` flag:

```swift
let shelfHeight = shelfViewState.isVisible ? NotchPillView.shelfRowHeight : 0
...
height: (switcherRowShowing ? NotchPillView.switcherContentHeight : expandedSize.height) + shelfHeight + switcherHeight
```

It has no awareness that the **current presentation is `.trayExpanded`**, the one case that
already renders the shelf's contents as its main content and intentionally suppresses the
additive strip. So whenever the shelf has at least one item (`shelfViewState.isVisible == true`)
and the user has the Tray tab open, `visibleContentZone()` reports a content box 56pt (`shelfRowHeight`)
taller than what `blobShape` actually draws. Any pointer that lands in that extra 56pt band —
which is genuinely blank/transparent, nothing is rendered there — is treated as "inside the
visible content" by `syncClickThrough()`, so `panel.ignoresMouseEvents` is set to `false` there.
The result: clicks in that transparent band are swallowed by Islet's invisible panel instead of
passing through to whatever is underneath — the exact class of regression this project's own
memory notes call out for `syncClickThrough()`/`visibleContentZone()` (`cr01-clickthrough-or-defeat-gotcha`),
reintroduced by the round-5 Tray-as-its-own-view change.

**Fix:** Make the shelf-height term presentation-aware, mirroring `trayFullView`'s own
`shelfVisible: false` override:

```swift
let isTrayPresentation: Bool = { if case .trayExpanded = presentationState.presentation { return true }; return false }()
let shelfHeight = (shelfViewState.isVisible && !isTrayPresentation) ? NotchPillView.shelfRowHeight : 0
```

(The outer SwiftUI `.frame()` in `NotchPillView.body` has the same unconditional
`shelfViewState.isVisible` term and should get the analogous fix — it's currently harmless only
because the panel is already reserved to the max union height, but it's the same drift and will
bite the next time someone reads that height for something other than transparent overflow.)

### CR-02: Quick-Add silently creates the event/reminder on a stale day after month navigation

**File:** `Islet/Notch/NotchWindowController.swift:1192-1220` (`handleCalendarMonthChange`,
`handleQuickAdd`)

**Issue:** `handleCalendarMonthChange(_:)` updates `calendarViewState.visibleMonth` and clears
`monthEvents`, but never touches `calendarViewState.selectedDay`:

```swift
private func handleCalendarMonthChange(_ delta: Int) {
    guard let newMonth = Calendar.current.date(byAdding: .month, value: delta, to: calendarViewState.visibleMonth) else { return }
    calendarViewState.visibleMonth = newMonth
    calendarViewState.monthEvents = nil
    refreshCalendarMonth()
}
```

After navigating to a different month without tapping a day cell, `selectedDay` still points at
whatever day was selected before navigating (typically "today," seeded when the Calendar tab was
opened) — a date that belongs to a month that is no longer the one on screen. No grid cell
renders as selected (`isDate(inSameDayAs:)` never matches a day outside the visible month), so
there's no visual indication anything is "selected" at all.

`handleQuickAdd(_:title:)` unconditionally uses this stale value:

```swift
private func handleQuickAdd(_ kind: QuickAddKind, title: String) {
    let day = calendarViewState.selectedDay
    ...
}
```

So a user who pages to next month and taps "+ Add" (there is no requirement to tap a day first —
the day-list column and the "+ Add" trigger are both always visible/enabled) gets their new event
or reminder silently created on a day in a **different, no-longer-displayed month**, with zero
error or confirmation. This is a real, easily-triggered data-placement bug in a phase whose whole
purpose is calendar quick-add.

**Fix:** Either (a) snap `selectedDay` to the 1st of the new month inside
`handleCalendarMonthChange` so it always stays inside `visibleMonth`, or (b) disable/hide the
Quick-Add trigger when `selectedDay` is not within `visibleMonth`:

```swift
private func handleCalendarMonthChange(_ delta: Int) {
    guard let newMonth = Calendar.current.date(byAdding: .month, value: delta, to: calendarViewState.visibleMonth) else { return }
    calendarViewState.visibleMonth = newMonth
    if !Calendar.current.isDate(calendarViewState.selectedDay, equalTo: newMonth, toGranularity: .month) {
        calendarViewState.selectedDay = newMonth   // keep selection inside the visible month
    }
    calendarViewState.monthEvents = nil
    refreshCalendarMonth()
}
```

## Warnings

### WR-01: `showsSwitcherRow` precedence list is hand-duplicated across two files

**File:** `Islet/Notch/NotchPillView.swift:62-67` and `Islet/Notch/NotchWindowController.swift:659-664`

**Issue:** The set of `IslandPresentation` cases that show the switcher row (and therefore drive
both the panel/click-through geometry and the actual rendered layout) is defined twice, in two
separate files, with a comment in each explicitly noting it "mirrors" the other. They happen to
agree today, but nothing enforces that — this is precisely the failure mode CR-01/CR-02 above
demonstrate: a future case added to one switch and forgotten in the other silently desyncs
render vs. click-through geometry again, exactly as has already happened multiple times in this
file's history (per this file's own extensive changelog comments).

**Fix:** Hoist the case list into one place both files can reference — e.g. a
`static func showsSwitcherRow(_ presentation: IslandPresentation) -> Bool` on `IslandPresentation`
itself (or a free function next to `resolve(...)` in `IslandResolver.swift`), and have both
`NotchPillView` and `NotchWindowController` call the same function instead of maintaining
parallel switches.

### WR-02: Camera-clearance magic number `32` duplicated across 7+ call sites instead of a shared constant

**File:** `Islet/Notch/NotchPillView.swift:444, 477, 657, 723, 771, 1526, 1558`

**Issue:** Every switcher-row-showing presentation pins its content with `.padding(.top, 32)`
("camera/notch clearance — matches mediaExpanded's convention," per the repeated comment), but
`32` is a bare literal at each of the 7 call sites rather than a named `static let` — unlike
`shelfRowHeight`, `switcherRowHeight`, `switcherContentHeight`, etc., which this same file
already promotes to constants specifically so a single tuning pass updates every consumer. If
this measured camera-clearance value ever needs to change again (as several other geometry
constants in this file already have, per the round 4/5 history), a future edit is likely to miss
one of the 7 sites.

**Fix:** Extract `static let cameraClearance: CGFloat = 32` and reference it at all 7 sites.

### WR-03: Quick-Add has no validation against an empty title

**File:** `Islet/Notch/NotchPillView.swift:1763-1780` (`QuickAddPopover.quickAddContent`)

**Issue:** The "Add Event"/"Add Reminder" button is always enabled and calls
`onSubmit(kind, title)` regardless of whether `title` is empty or whitespace-only, silently
creating a blank-titled `EKEvent`/`EKReminder`.

**Fix:** Disable the submit button (or trim-and-guard before calling `onSubmit`) when
`title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty`.

### WR-04: Duplicate RGB-extraction block in `EventKitService`

**File:** `Islet/Calendar/CalendarService.swift:58-68` and `:94-104`

**Issue:** `fetchUpcoming` and `fetchMonth` each contain an identical ~10-line block that maps
`ek.calendar.color` to `red/green/blue` `Double`s with the same `1.0/1.0/1.0` fallback. Copy-
pasted logic like this is exactly the kind of place a future fix (e.g., a colorspace edge case)
gets applied to one call site and not the other.

**Fix:** Factor into a private helper, e.g. `private func mapToEventInput(_ ek: EKEvent) -> EventInput`,
and call it from both `fetchUpcoming` and `fetchMonth`.

## Info

### IN-01: `blobShape`'s `height:` parameter fallback is dead code

**File:** `Islet/Notch/NotchPillView.swift:1064-1082` (specifically line 1075)

**Issue:** `blobShape(...)` computes `baseHeight = showSwitcher ? Self.switcherContentHeight :
(height ?? Self.expandedSize.height)`. Every current call site that passes `showSwitcher: true`
(6 of the 7 callers) never reaches the `height ?? ...` branch at all; the one caller that omits
`showSwitcher` (`onboardingCarousel`) always supplies an explicit `height:` argument
(`Self.onboardingSize.height`). So `Self.expandedSize.height` as a `height:` fallback is
currently unreachable from any live call site — harmless, but worth pruning or noting so a future
reader doesn't assume it's exercised.

### IN-02: No DEBUG `#Preview` coverage for the three new Phase 28 presentations

**File:** `Islet/Notch/NotchPillView.swift:1840-2001`

**Issue:** The file's own header comment above the `#if DEBUG` preview block describes these
previews as a "build-time correctness artifact: proves BOTH layouts compile and render without
running the app." Every pre-Phase-28 `IslandPresentation` case has a preview, but
`.calendarExpanded`, `.weatherExpanded`, and `.trayExpanded` (all added this phase) have none —
a regression in one of those three view bodies would only surface on-device, not at the next
build/preview-render pass.

**Fix:** Add a `#Preview` for each of the three new cases, following the existing pattern (seed
an `IslandPresentationState(...)` with the case and a populated `CalendarViewState`/`outfit`/
`ShelfViewState`).

---

_Reviewed: 2026-07-13T15:50:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
