---
created: 2026-07-19T13:23:31.888Z
title: Island briefly disappears during click-through
area: ui
files:
  - Islet/Notch/NotchWindowController.swift
---

## Problem

Reported during Phase 44 / 44-02 on-device UAT (D-08a click-through trace: hover→expand→move
pointer down past the bottom edge of the expanded island). The island briefly disappears during
this trace. User confirmed this is out of scope for Phase 44 (DRAG-02/TRAY-06) — status
unconfirmed as pre-existing vs. newly surfaced by the wider Quick Action picker geometry in Plan
44-01, deferred for a dedicated investigation rather than guessed at inline.

Related project memory: `cr01-clickthrough-or-defeat-gotcha` — syncClickThrough()'s expanded
branch must be pure `visibleContentZone()`, never OR'd with `pointerInZone`, or the empty-shelf
click-swallowing regression comes back. This may be a related but distinct symptom (disappearing,
not click-swallowing) in the same click-through/hot-zone code path.

## Solution

TBD — needs a `/gsd-debug` session with an explicit on-device hover→expand→move-down trace
(same rigor as the CR-01 investigation) to determine root cause before attempting a fix.
