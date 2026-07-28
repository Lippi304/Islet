---
created: 2026-07-28T22:41:00.000Z
title: SettingsViewTests card-count drift (8 vs 9, calendarCountdown isNew)
area: settings
files:
  - IsletTests/SettingsViewTests.swift
  - Islet/SettingsView.swift
---

## Problem

Found incidentally during a full Cmd-U run (2026-07-28) while confirming Phase 27's
verification checkpoints for v1.4's close-out — unrelated to Phase 27 itself. 3 of 575 tests
failed:

- `testSystemHUDCardsCount` — expected 9, got 8.
- `testSystemHUDCardsExistingBeforeNew` — `calendarCountdown` should be `isNew`, isn't.
- `testProductivityCardsAllNew` — assertion failed (not yet inspected in detail).

Looks like drift from a later phase that added a new System HUD card (candidate: Menübar-Overflow
Phase 66, or another v1.10 HUD) without updating this test's expected count/isNew flags — not
investigated further, priority was closing out v1.4's own checkpoints.

## Solution

TBD — needs a `/gsd-debug` session (or a quick direct read of `SettingsView.swift`'s HUD card
list vs. `SettingsViewTests.swift`'s expectations) to determine which card was added and whether
the test or the `isNew` flag is the one that's actually wrong.
