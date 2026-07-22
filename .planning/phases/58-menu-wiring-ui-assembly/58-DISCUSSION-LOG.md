# Phase 58: Menu Wiring & UI Assembly - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-22
**Phase:** 58-Menu Wiring & UI Assembly
**Areas discussed:** Image entry appearance, Pasteboard-access prompt, Empty state, Section placement

---

## Image entry appearance

| Option | Description | Selected |
|--------|-------------|----------|
| Small thumbnail | Downscaled preview of the actual image, like Maccy/Paste | ✓ |
| Generic icon + "Image" label | Fixed SF Symbol + plain text, simpler, uniform row height | |

**User's choice:** Small thumbnail (~16-20pt, inline row height)

| Option | Description | Selected |
|--------|-------------|----------|
| Small, ~16-20pt | Matches standard single-line NSMenuItem row height | ✓ |
| Larger, ~32-40pt | More recognizable but taller, less uniform rows | |

**User's choice:** Small, ~16-20pt

---

## Pasteboard-access prompt

| Option | Description | Selected |
|--------|-------------|----------|
| First menu open | Shown before any history exists, sets expectations up front | ✓ |
| First captured item | Tied to something concrete just happened | |

**User's choice:** First menu open

| Option | Description | Selected |
|--------|-------------|----------|
| NSAlert | Native modal, same mechanism as the Phase 57 spike | ✓ |
| Inline row in the menu | Disabled explanatory row, no separate modal | |

**User's choice:** NSAlert

| Option | Description | Selected |
|--------|-------------|----------|
| Claude drafts it | Short plain-language explanation, matches app's existing tone | ✓ |
| I'll describe it | User dictates specific phrasing | |

**User's choice:** Claude drafts it

---

## Empty state

| Option | Description | Selected |
|--------|-------------|----------|
| Disabled placeholder row | Greyed-out "No items yet" row | ✓ |
| Section hidden entirely | Menu looks exactly like today until first capture | |

**User's choice:** Disabled placeholder row

---

## Section placement

| Option | Description | Selected |
|--------|-------------|----------|
| At the top | History + Delete All first, then existing Settings/Check for Updates/Quit — matches CopyClip reference | ✓ |
| At the bottom | Existing items stay first, clipboard section added below Quit | |

**User's choice:** At the top

---

## Claude's Discretion

- Exact SwiftUI row layout inside the `NSHostingView` (spacing, font size, truncation character count)
- Whether the disabled empty-state row / "Delete All History" use literal `isEnabled = false` vs. omission
- Whether the pasteboard-access `NSAlert` is triggered from `AppDelegate` directly or a new coordinator method
- Dynamic menu-rebuild mechanism (`NSMenuDelegate.menuNeedsUpdate` vs. observer-driven rebuild) — not a user-visible behavior difference

## Deferred Ideas

None — discussion stayed within phase scope. Search/filter and per-item delete remain explicitly deferred to a future milestone per `.planning/research/FEATURES.md`, not raised again during this discussion.
