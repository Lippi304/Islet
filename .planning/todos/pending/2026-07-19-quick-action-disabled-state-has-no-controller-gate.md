---
created: 2026-07-19T16:05:00.000Z
title: Quick Action disabled state has no controller gate
area: ui
files:
  - Islet/Notch/NotchPillView.swift:201-202,1534-1537
  - Islet/Notch/NotchWindowController.swift:1174-1194
---

## Problem

Found by code review (44-REVIEW.md WR-01), pre-existing since Phase 34, not caused by Phase 44's
width-alignment changes. `quickActionButton(..., enabled: airDropAvailable, ...)` /
`enabled: mailAvailable` only dims the button's opacity — there is no `Button(action:)` in the
view (removed in the Phase 34 UAT revision); selection happens entirely via the controller's
release-point hit-test in `NotchWindowController.handleDragApproachEnd()`, which calls
`handleQuickActionAirDrop()`/`handleQuickActionMail()` unconditionally on a release inside button
index 1/2's frame, never checking `airDropAvailable`/`mailAvailable`.

Currently masked because both flags are hardcoded `true` everywhere (confirmed via grep — no call
site sets them to false), so the fallback-disable path is effectively dead code. If either flag is
ever wired to a real availability check, a visually-dimmed/disabled button would still fire its
action on click.

## Solution

Gate the two release-hit-test cases in `handleDragApproachEnd()` on the same flags the view reads
(thread `airDropAvailable`/`mailAvailable` through to the controller), or drop the dead `enabled:`
parameter/properties entirely until the real fallback-disable path is implemented.
