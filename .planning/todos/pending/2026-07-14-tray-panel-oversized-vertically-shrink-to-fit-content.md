---
created: 2026-07-14T02:39:44.685Z
title: Tray panel oversized vertically, shrink to fit content
area: ui
files:
  - Islet/Notch/NotchPillView.swift (trayFullView)
  - Islet/Notch/NotchWindowController.swift (visibleContentZone())
---

## Problem

On the Tray tab, the black island panel reserves far more vertical height than its
content needs: there's a large empty black gap between the file-shelf row (thumbnails +
trash icon) and the bottom control-icon row (home/tray/calendar/weather). Files also
appear to peek out over the panel's top rounded edge. Observed on-device during Phase 31's
CR-01 click-through checkpoint (2026-07-14) — confirmed purely visual/sizing, NOT a
click-through or dead-zone regression (hover/expand/move-down trace passed cleanly on
Home/Calendar/Weather/Tray).

Likely cause: `trayFullView`'s panel height still reserves space sized for the old
shelf-band layout (pre quick-task 260714-3k6 shelf consolidation), rather than hugging
the current file row + icon row content.

## Solution

TBD — candidate for Phase 32 (Tray Widening) since it already touches Tray layout and
`visibleContentZone()`, or a standalone quick task if Phase 32 doesn't naturally cover
vertical sizing (Phase 32's stated scope is width/tile-size only, not height). Panel
height should hug content: files row + icons row directly below, no reserved dead space.
