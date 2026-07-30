# Phase 72: Calendar Redesign — Native Calendar Clone - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-30
**Phase:** 72-Calendar Redesign — Native Calendar Clone
**Areas discussed:** Todo fold-in, Agenda list scope, Today/selected badge swap, Reference priority, Event edit/remove UI

---

## Todo Fold-in

| Option | Description | Selected |
|--------|-------------|----------|
| Fold in fully | Chevron spacing, font size, AND event edit/remove all join Phase 72 scope | ✓ |
| Fold in layout only | Only cheap layout tweaks, defer edit/remove | |
| Keep separate | Leave the todo untouched for a later phase | |

**User's choice:** Fold in fully.
**Notes:** CalendarService only has createEvent/createReminder today — folding in edit/remove is a real scope addition, not just a UI tweak.

---

## Agenda List Scope

| Option | Description | Selected |
|--------|-------------|----------|
| Rolling window from today | Today + next N days, independent of grid navigation | |
| Whole visible month | Every day with events in the currently-viewed month | ✓ |
| Selected day forward | Starts at selected day, lists forward from there | |

**User's choice:** Whole visible month.

| Option | Description | Selected |
|--------|-------------|----------|
| Scrolls agenda to that day | Grid tap jumps the already-populated agenda to that day | ✓ |
| Just visual selection, no agenda effect | Grid tap only moves the badge, agenda unaffected | |

**User's choice:** Scrolls agenda to that day.

---

## Today/Selected Badge Swap

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, swap it | Today=filled, selected=outlined (matches ROADMAP wording) | ✓ |
| No, keep current | Leave selected=filled/today=ring as today's code has it | |

**User's choice:** Yes, swap it.

| Option | Description | Selected |
|--------|-------------|----------|
| Keep as-is | Has-events dot indicator unchanged | |
| You decide | Claude resolves during UI-spec/planning | ✓ |

**User's choice:** You decide.

---

## Reference Priority (Droppy vs real Apple Calendar)

| Option | Description | Selected |
|--------|-------------|----------|
| I'll provide a Calendar.app screenshot | User supplies a real reference | ✓ |
| Use Droppy's screenshot as reference | Treat existing Droppy screenshot as close enough | |

**User's choice:** Provided a real macOS Notification Center Calendar widget screenshot (2 widget variants — month grid, and day+agenda). Saved as `reference-macos-calendar-widgets.png`.
**Notes:** User initially asked whether Apple's real widget could be embedded directly instead of rebuilt — answered: no public API exists for a third-party app to host Apple's own system widget; confirmed this phase is a SwiftUI rebuild.

Follow-up — selected-day outline badge color, since Apple's widget shows no selection state:

| Option | Description | Selected |
|--------|-------------|----------|
| Dünner weißer/grauer Ring | Neutral, dezenter as today's red | |
| Dünner roter Ring | Same accent as today, outlined instead of filled | ✓ |
| Du entscheidest | Claude decides at UI-spec | |

**User's choice:** Dünner roter Ring (thin red ring).

---

## Event Edit/Remove UI

| Option | Description | Selected |
|--------|-------------|----------|
| Popover on click (reuse QuickAddPopover) | Pre-filled popover, same pattern as "+ Add" | ✓ |
| Inline editing | Row fields become editable directly, new pattern | |

**User's choice:** Popover on click, reusing QuickAddPopover pattern.

| Option | Description | Selected |
|--------|-------------|----------|
| Swipe or hover-reveal delete button | Trash icon on hover, one click deletes, no confirm | ✓ |
| Delete with confirm dialog | Trash icon on hover, but asks to confirm first | |

**User's choice:** Hover-reveal delete, no confirm dialog.

---

## Claude's Discretion

- Has-events dot indicator styling (may or may not change from current tiny white dot).
- Exact scroll-to-day mechanism for the agenda list.
- `CalendarService` update/delete method signatures.

## Deferred Ideas

None — the todo fold-in was a deliberate, agreed-upon scope expansion, not scope creep.
