---
status: complete
phase: 28-calendar-full-view
source: [28-VERIFICATION.md]
started: 2026-07-13T14:06:20Z
updated: "2026-07-28T22:35:00.000Z"
---

## Current Test

[testing complete]

## Tests

### 1. Tray click-through fix (CR-01)
expected: With the shelf non-empty, open the Tray tab, then click in the blank area below the files card (where the old additive shelf-strip band used to be). The click should pass through to whatever is behind the notch (desktop/app underneath) — it must NOT be swallowed by the panel and must NOT collapse the notch instead of clicking through.
result: pass

### 2. Quick-add-after-month-navigation fix (CR-02)
expected: Open the Calendar tab, page to a different month using the chevrons (without tapping any day cell), then use "+ Add" to create an Event or Reminder. Check Calendar.app/Reminders.app afterward — the new item must land on a day in the month currently displayed on screen, not a stale day left over from before navigating.
result: pass

## Summary

total: 2
passed: 2
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps
