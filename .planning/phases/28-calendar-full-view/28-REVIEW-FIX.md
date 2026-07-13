---
phase: 28-calendar-full-view
fixed_at: 2026-07-13T15:53:00Z
fix_scope: critical_warning
findings_in_scope: 6
fixed: 6
skipped: 0
status: all_fixed
---

# Phase 28: Code Review Fix Report

All 6 in-scope findings (2 Critical, 4 Warning) from `28-REVIEW.md` were fixed and committed
atomically. The 2 Info findings (IN-01, IN-02) were left untouched per `fix_scope:
critical_warning`. Each fix was rebuilt (`xcodebuild build -project Islet.xcodeproj -scheme
Islet -configuration Debug -destination 'platform=macOS'`) and confirmed `BUILD SUCCEEDED`
before committing.

## CR-01: Tray click-through phantom band

**Fixed.** `Islet/Notch/NotchWindowController.swift` (`visibleContentZone()`) and
`Islet/Notch/NotchPillView.swift` (`body`'s outer `.frame()`) both computed shelf height purely
from `shelfViewState.isVisible`, ignoring that `trayFullView` deliberately renders with
`shelfVisible: false` (its own content IS the files view, so the additive shelf strip must not
also append below it). While Tray was open with a non-empty shelf, the click-through hit-test
zone was 56pt (`shelfRowHeight`) taller than what's actually drawn — clicks landing in that
blank/transparent band were swallowed instead of passing through.

Added an `isTrayPresentation` check to both call sites (mirroring the existing
`isOnboardingPresentation` pattern in `NotchPillView`) so `shelfHeight`/the frame's shelf term
is excluded whenever `.trayExpanded` is the active presentation.

Commit: `e10b160`

## CR-02: Quick-Add stale-month bug

**Fixed.** `handleCalendarMonthChange(_:)` in `NotchWindowController.swift` updated
`calendarViewState.visibleMonth` but never touched `selectedDay`, so navigating to a different
month left `selectedDay` pointing at a day in a month no longer displayed (typically "today",
seeded when the Calendar tab opened). `handleQuickAdd(_:title:)` unconditionally read this stale
value, silently creating an event/reminder on a day in the wrong month with zero error or
confirmation.

`selectedDay` now snaps to the new month (via `Calendar.current.isDate(_:equalTo:toGranularity:)`)
whenever it falls outside the newly-visible month.

Commit: `e10b160`

## WR-01: Duplicated `showsSwitcherRow` precedence list

**Fixed.** `NotchPillView.swift` and `NotchWindowController.swift` each hand-maintained an
identical `switch` over `IslandPresentation` cases that show the switcher row, with a comment
in each noting it "mirrors" the other but nothing enforcing agreement — precisely the failure
class CR-01/CR-02 demonstrated.

Hoisted into one shared `showsSwitcherRow(for:)` free function in `Islet/Notch/IslandResolver.swift`.
`NotchWindowController`'s duplicate `private func` was deleted (its call site now resolves to
the shared function). `NotchPillView`'s computed property now delegates to
`Islet.showsSwitcherRow(for: presentation)` (module-qualified — Swift treats the bare call as
ambiguous with the property of the same base name).

Commit: `f1976a2`

## WR-02: Magic number `32` for camera clearance

**Fixed.** The camera/notch clearance `.padding(.top, 32)` was a bare literal repeated at 7 call
sites in `NotchPillView.swift` (lines 444, 477, 657, 723, 771, 1526, 1558 per the review — shifted
slightly by the time of the fix), unlike `shelfRowHeight`/`switcherRowHeight`/
`switcherContentHeight` in the same file, which are already named constants for exactly this
reason.

Extracted `static let cameraClearance: CGFloat = 32` and updated all 7 call sites to
`.padding(.top, Self.cameraClearance)`.

Commit: `d06cb59`

## WR-03: Quick-Add empty-title validation

**Fixed.** The "Add Event"/"Add Reminder" button in `QuickAddPopover.quickAddContent`
(`NotchPillView.swift`) was always enabled and called `onSubmit(kind, title)` regardless of
whether `title` was empty or whitespace-only, silently creating a blank-titled
`EKEvent`/`EKReminder`.

The submit button now carries `.disabled(title.trimmingCharacters(in:
.whitespacesAndNewlines).isEmpty)`, and the action itself re-trims and guards before calling
`onSubmit` (belt-and-suspenders against any programmatic bypass of the disabled state).

Commit: `b686c8b`

## WR-04: Duplicate RGB-extraction in `CalendarService.swift`

**Fixed.** `fetchUpcoming` and `fetchMonth` in `EventKitService` each contained an identical
~10-line block mapping `ek.calendar.color` to `red/green/blue` `Double`s with the same
`1.0/1.0/1.0` fallback.

Factored into a private `mapToEventInput(_ ek: EKEvent) -> EventInput` helper, called from both
`fetchUpcoming` and `fetchMonth`.

Commit: `96faac9`

## Info findings (out of scope, untouched)

- IN-01 (`blobShape`'s dead `height:` fallback) — not touched.
- IN-02 (no `#Preview` coverage for the 3 new Phase 28 presentations) — not touched.

## Build verification

Every commit above was preceded by a full `xcodebuild build -project Islet.xcodeproj -scheme
Islet -configuration Debug -destination 'platform=macOS'` run, each ending in
`** BUILD SUCCEEDED **`.
