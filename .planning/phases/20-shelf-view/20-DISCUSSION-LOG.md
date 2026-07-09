# Phase 20: Shelf View - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-09
**Phase:** 20-Shelf View
**Areas discussed:** Panel growth strategy, Delete-all confirmation, Missing-file-on-click, Shelf-area tap behavior

---

## Panel growth strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Grow dynamically | Mirrors Phase 18's toast-row precedent: one shape, height grows only when the shelf has content. | ✓ |
| Always reserve the band | A fixed-height shelf area is always part of the layout, whether or not it has items. | |

**User's choice:** Grow dynamically
**Notes:** —

| Option | Description | Selected |
|--------|-------------|----------|
| All expanded branches | mediaExpanded, expandedIdle, and mediaUnavailable all get the same shelf row when it has content. | ✓ |
| Only Now Playing + idle glance | Exclude the "nicht verfügbar" health-failure state. | |

**User's choice:** All expanded branches
**Notes:** —

---

## Delete-all confirmation

| Option | Description | Selected |
|--------|-------------|----------|
| Instant, no confirmation | Matches SHELF-08's session-only premise; one click, gone. | ✓ |
| Confirm before clearing | A native confirmation alert/sheet appears before wiping every item. | |

**User's choice:** Instant, no confirmation
**Notes:** —

---

## Missing-file-on-click

| Option | Description | Selected |
|--------|-------------|----------|
| Silent no-op | Click does nothing if the file is gone; item stays in shelf, inert. | ✓ |
| Auto-prune and remove from shelf | A dead item is detected on click and immediately removed. | |
| Show an error message | A visible alert/toast tells the user the file couldn't be opened. | |

**User's choice:** Silent no-op
**Notes:** —

---

## Shelf-area tap behavior

| Option | Description | Selected |
|--------|-------------|----------|
| Yes, collapses like the rest | Empty strip space falls through to the shared onClick, matching every other non-button region of the blob. | ✓ |
| No, the whole strip is gesture-inert | The shelf area never collapses the island regardless of where you tap in it. | |

**User's choice:** Yes, collapses like the rest
**Notes:** —

---

## Claude's Discretion

- Exact file-type icon rendering mechanism (e.g. `NSWorkspace.shared.icon(forFile:)`).
- Visual layout specifics (icon size, spacing, scroll indicator styling, exact height per shelf row) — deferred to the UI design contract (`/gsd:ui-phase 20`).
- Whether per-item trash icons use the same Finding-15 scoped-gesture technique as the delete-all icon.

## Deferred Ideas

None — discussion stayed within phase scope.
