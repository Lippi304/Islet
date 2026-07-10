# Phase 21: Drag-Out - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-10
**Phase:** 21-Drag-Out
**Areas discussed:** Post-drag-out shelf behavior, Missing-file-on-drag handling, Island state during drag gesture, Drag preview appearance

---

## Post-drag-out shelf behavior

| Option | Description | Selected |
|--------|-------------|----------|
| Stays in shelf (copy semantics) | Matches SHELF-08's premise and Phase 20's D-04 no-op precedent — shelf never auto-removes on its own; user can drag it out again or remove manually | ✓ |
| Auto-removed (move semantics) | Item vanishes from shelf the instant the drop succeeds elsewhere; requires reliable drop-success detection, which drag APIs report unreliably | |
| You decide | | |

**User's choice:** Stays in shelf (copy semantics)
**Notes:** None.

---

## Missing-file-on-drag handling

| Option | Description | Selected |
|--------|-------------|----------|
| No-op drag, item stays inert | Matches Phase 20's D-04 missing-file-on-click precedent; drag doesn't start, item remains until manually removed | ✓ |
| Auto-prune from shelf | Self-healing but introduces a new kind of auto-removal not used anywhere else in the shelf | |
| You decide | | |

**User's choice:** No-op drag, item stays inert
**Notes:** None.

---

## Island state during drag gesture

| Option | Description | Selected |
|--------|-------------|----------|
| Pin open while dragging | Suppress the hover-out grace-collapse from drag-start to drag-end, since the pointer necessarily leaves the hot-zone while dragging toward Finder | ✓ |
| Let it collapse normally | No special handling; island may visually collapse mid-drag while the OS-level drag session continues independently | |
| You decide | | |

**User's choice:** Pin open while dragging
**Notes:** None.

---

## Drag preview appearance

| Option | Description | Selected |
|--------|-------------|----------|
| Default system icon | NSItemProvider's default preview (the file's own icon), matches Finder, no custom rendering needed | ✓ |
| Custom preview matching shelf row | Mirrors ShelfItemView's icon+filename look; more polished but new UI work for a briefly-seen preview | |
| You decide | | |

**User's choice:** Default system icon
**Notes:** No UI-SPEC hint was flagged for this phase in ROADMAP.md.

---

## Claude's Discretion

- Exact SwiftUI/AppKit mechanism for initiating the drag (`.onDrag` vs. lower-level `NSDraggingSource`) — use the standard SwiftUI-first approach.
- How drag-start/drag-end is detected to drive the island pin-open/resume behavior — left to research/planning against `NotchWindowController`'s existing hover machinery.
- Exact handling of drag-cancel (ESC, drop back into the shelf) for the pin-open resume — treat as equivalent to drag-end unless research finds a reason not to.

## Deferred Ideas

None — discussion stayed within phase scope.
