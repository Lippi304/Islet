---
created: 2026-07-19T20:50:50.304Z
title: Calendar month-grid polish (arrows, day numbers, event hover/edit)
area: ui
files:
  - Islet/Notch/NotchPillView.swift
---

## Problem

Raised by the user during Phase 46's on-device verification checkpoint (46-03), explicitly out of
scope for that phase's CALVIEW-05/06/07 requirements. Three separate polish items on the Calendar
tab's month grid / day list:

1. The month/year header's prev/next chevron arrows sit too far apart — move them closer together.
2. The day-of-month numbers in the calendar grid are too small — increase their font size for
   legibility (this may also interact with the day-list row padding bump from Phase 46 — check
   overall Calendar tab balance once font size changes).
3. Event rows in the day list truncate long titles (e.g. "Spain - Arge..." for "Spain - Argentina").
   Add a hover tooltip that reveals the full title, plus make the row support click-to-edit and
   click-to-remove for that event (currently rows are display-only).

## Solution

TBD — needs its own discuss-phase pass. Item 3 (edit/remove) is the biggest scope: likely needs a
small popover or inline editing UI reusing patterns from `QuickAddPopover` (Phase 46), plus a
`CalendarService` update/delete path (check whether `CalendarService.swift` already exposes
update/delete methods or only `createEvent`/`createReminder`). Items 1-2 are pure layout/constant
tweaks in `NotchPillView.swift`'s month-grid section.
