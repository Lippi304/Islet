# Phase 46: Calendar Quick-Add Improvements - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-19
**Phase:** 46-Calendar Quick-Add Improvements
**Areas discussed:** Date+time picker UI & editability, Add-button placement, Row padding & island growth, Reminder time-only picker

---

## Date+time picker UI & editability

| Option | Description | Selected |
|--------|-------------|----------|
| Locked to tapped day | Only time is a real picker; date comes from the tapped calendar day | ✓ |
| Editable date + time | Full date+time picker, lets user pick a different day | |

**User's choice:** Locked to tapped day.

| Option | Description | Selected |
|--------|-------------|----------|
| Compact | `.datePickerStyle(.compact)`, small tappable field, native macOS UI | ✓ |
| Stepper/wheel inline | Always-visible wheel, more vertical space | |
| Graphical | Full calendar+clock face, too large for 220pt popover | |

**User's choice:** Compact.

| Option | Description | Selected |
|--------|-------------|----------|
| Two compact pickers, one row each | "Starts"/"Ends" rows in the existing VStack | ✓ |
| Side-by-side on one row | Start/End share one HStack row, tighter horizontally | |

**User's choice:** Two compact pickers, one row each.

| Option | Description | Selected |
|--------|-------------|----------|
| Auto-follow, stays independent once touched | End = Start+1hr, shifts with Start until manually edited | ✓ |
| Always independent | End computed once at popover-open, never auto-updates | |

**User's choice:** Auto-follow, stays independent once touched.

---

## Add-button placement

| Option | Description | Selected |
|--------|-------------|----------|
| Same row, now left-aligned | Flip the existing `HStack{Spacer(); button}` to `HStack{button; Spacer()}` | ✓ |
| Anchored to the divider itself | Pull button out of dayListColumn, place beside the divider line | |

**User's choice:** Same row, now left-aligned.

| Option | Description | Selected |
|--------|-------------|----------|
| Force rightward | Popover forced to open toward the day list, avoiding overlap with month grid | ✓ |
| Leave default | SwiftUI's default popover positioning | |

**User's choice:** Force rightward.

---

## Row padding & island growth

| Option | Description | Selected |
|--------|-------------|----------|
| Calendar-only override | New `calendarContentHeight` constant, following Phase 44's `trayContentHeight` precedent | ✓ |
| Grow the shared box globally | Bump `switcherContentHeight`, affecting Home/Weather too | |

**User's choice:** Calendar-only override.

| Option | Description | Selected |
|--------|-------------|----------|
| Moderate bump | ~12pt horizontal / 8pt vertical padding, 8pt inter-row spacing | ✓ |
| Generous bump | ~16pt horizontal / 10-12pt vertical padding, 10pt spacing | |
| You decide | Claude picks exact values during planning/UI-phase | |

**User's choice:** Moderate bump.

| Option | Description | Selected |
|--------|-------------|----------|
| Small bump, ~10-15pt | 460 → ~470-475pt | ✓ |
| You decide | Claude picks exact width during planning/UI-phase | |

**User's choice:** Small bump, ~10-15pt.

---

## Reminder time-only picker

| Option | Description | Selected |
|--------|-------------|----------|
| Hide end field entirely | Only render the single time picker for Reminders, no End row at all | ✓ |
| Same two-field layout, End disabled/greyed | Keep both rows for both kinds, grey out End for Reminders | |

**User's choice:** Hide end field entirely.

| Option | Description | Selected |
|--------|-------------|----------|
| "Due" | Matches EventKit's `dueDate` terminology | ✓ |
| "Time" | Generic, symmetric with Start/End labels | |

**User's choice:** "Due".

---

## Claude's Discretion

- Exact pixel values for `calendarContentHeight`, final row padding, and `calendarWidth` within the "moderate bump" / "~10-15pt" ranges — fine-tuned during planning/UI-phase.
- Whether the reminder default time uses the same "next full hour if today / 00:00 otherwise" helper as the event start.
- Exact SwiftUI code structure for conditionally rendering Start/End (Event) vs. Due (Reminder) inside `quickAddContent`.

## Deferred Ideas

None — discussion stayed within phase scope. Two pending todos ("Island briefly disappears during click-through", "Quick Action disabled state has no controller gate") were reviewed via `cross_reference_todos` but confirmed unrelated (Tray/click-through, not calendar quick-add) and left out.
