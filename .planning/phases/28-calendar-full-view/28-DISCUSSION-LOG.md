# Phase 28: Calendar Full View - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-13
**Phase:** 28-calendar-full-view
**Areas discussed:** View switcher, Reminders permission timing, Month grid/day list interaction

---

## View switcher

| Option | Description | Selected |
|--------|-------------|----------|
| 3-Icon-Pill (Droppy-Stil) | Small capsule below the island with 3 icons (Home/Tray/Calendar), active one highlighted — the idea explicitly deferred from Phase 25's discussion for Phase 28 | ✓ |
| Swipe/Klick-Zyklus | Cycle through the 3 views by click/swipe, no permanently visible switcher — more minimal but less discoverable | |
| Claude entscheidet | Leave the mechanism to planner/researcher, only require "a way to reach the Calendar view exists" | |

**User's choice:** 3-Icon-Pill (Droppy-Stil)
**Notes:** Resolves the deferred idea explicitly flagged in `25-CONTEXT.md` ("Likely home: Phase 28"). Scouting found no existing Home/Tray view-switching mechanism at all — today's shelf is additive (grows the pill height when non-empty), not a separate presentation state — so this is genuinely new UI work, captured as D-01/D-02.

---

## Reminders permission timing

| Option | Description | Selected |
|--------|-------------|----------|
| Lazy beim ersten Quick-Add | Prompt appears only the first time the user picks "Reminder" instead of "Event" — mirrors LocationProvider's lazy-request pattern, no onboarding change needed (Phase 26 already shipped) | ✓ |
| Reminder-Option erstmal weglassen | Quick-add for Events only this round, Reminder choice deferred to a follow-up scope — would not fully satisfy CALVIEW-03 | |

**User's choice:** Lazy beim ersten Quick-Add
**Notes:** Scouting confirmed zero `EKReminder` code and no Reminders Info.plist keys exist yet (`project.yml` only has Calendar keys) — two new keys (`NSRemindersUsageDescription`, `NSRemindersFullAccessUsageDescription`) must be added (D-05). Calendar event creation itself needs no new entitlement — `EventKitService` already requests full (read/write) access, not read-only (D-06), resolving the open question flagged in STATE.md's Blockers/Concerns section.

---

## Month grid / day list interaction

| Option | Description | Selected |
|--------|-------------|----------|
| Tag antippen filtert die Liste | Today selected by default on open; tapping a day in the grid switches the list to that day; month navigable via prev/next | ✓ |
| Nur aktueller Monat, kein Vor/Zurück | Simpler first version — grid shows only the current month, no navigation to other months in this phase's scope | |

**User's choice:** Tag antippen filtert die Liste
**Notes:** Matches the Droppy reference (month grid left, "Today" list right) in `.planning/research/inspiration/notes.md`. Captured as D-07 (day-tap filters list, today default) and D-08 (month prev/next navigation included in scope).

---

## Claude's Discretion

- Exact switcher-pill visual treatment (icon set, spacing, active-state highlight) — Droppy reference exists, exact SwiftUI layout is a UI-phase decision.
- Whether `CalendarService` gets a new protocol method for month-range fetch vs. a separate method on the same conformer — CALVIEW-04 requires no duplicated logic, exact seam shape is implementation judgment.
- Exact `IslandPresentation` case naming and how the switcher pill's Tray-selection reconciles with the shelf's existing additive auto-expand-on-drop behavior — must not regress Phase 24.
- Exact empty-state copy/visual for a day with no events (CALVIEW-02 requires an explicit empty state, wording is open).
- Whether the switcher pill is visible during Charging/Device/Now-Playing wings or suppressed like the shelf (SHELF-09 precedent) — not discussed, needs research/planning judgment.
- New `EKReminder`-mapping types mirroring `EventInput`/`CalendarGlance`'s plain-struct, untrusted-title-as-string convention.

## Deferred Ideas

None — discussion stayed within phase scope.
