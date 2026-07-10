# Phase 21: Drag-Out - Context

**Gathered:** 2026-07-10
**Status:** Ready for planning

<domain>
## Phase Boundary

Users can drag a file already staged in the shelf back out to Finder or any other app, using the item's own local session-copy (`ShelfItem.localURL`) — not the original source file. Standard `NSItemProvider`/`onDrag`, no private API. Validated before the higher-risk drag-in work (Phase 22).

Out of scope for this phase: drag-in (Phase 22), multi-item drag (SHELF-06 and ROADMAP Success Criteria are all singular — "a shelf item"; no selection mechanism exists in the Phase 20 shelf UI to support multi-select anyway), and any change to the shelf data model itself (Phase 19, already shipped).

</domain>

<decisions>
## Implementation Decisions

### Post-drag-out shelf behavior
- **D-01:** The shelf item stays in the shelf after a successful drag-out (copy semantics, not move). The shelf never auto-removes items on its own — only manual delete (per-item or delete-all), app restart, or Mac restart remove items (SHELF-08). User can drag the same item out repeatedly, or remove it manually via its own trash icon.

### Missing-file-on-drag handling
- **D-02:** If a shelf item's local session-copy has vanished when the user starts a drag (ROADMAP Success Criteria #2), the drag is a silent no-op — nothing drops, no crash, no error dialog. The item stays in the shelf, inert, until the user removes it via its own trash icon. Directly mirrors Phase 20's D-04 (missing-file-on-click) for consistency across click and drag.

### Island state during drag gesture
- **D-03:** Starting a shelf-item drag pins the island open — suppresses the hover-out grace-collapse timer for the duration of the drag gesture (drag-start to drag-end/drag-cancel), so the panel cannot collapse mid-drag and orphan the gesture (the pointer necessarily leaves the panel's hot-zone once dragging toward Finder/another app). Normal hover/grace-collapse logic resumes immediately once the drag ends.

### Drag preview appearance
- **D-04:** Use the default system drag preview (the file's own icon, as `NSItemProvider`/`onDrag` renders it out of the box) — matches what Finder shows for the same file, needs no custom rendering. No UI-SPEC hint was flagged for this phase in ROADMAP.md.

### Claude's Discretion
- Exact SwiftUI/AppKit mechanism for initiating the drag (`.onDrag { NSItemProvider(...) }` vs. lower-level `NSDraggingSource`) — not discussed; use the standard SwiftUI-first approach consistent with "no private API."
- How drag-start/drag-end is detected to drive D-03's pin-open/resume — implementation detail for the planner/researcher to resolve against `NotchWindowController`'s existing `pointerInZone`/grace-timer machinery.
- Exact wording/behavior of "drag-cancel" (e.g., ESC during drag, or dropping back inside the shelf itself) for D-03's resume — treat as equivalent to drag-end unless research surfaces a reason not to.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements source
- `.planning/REQUIREMENTS.md` — SHELF-06 ("User can drag a shelf item back out to Finder or any other app"); v1.3 header note: "Standard `NSItemProvider` drag & drop, no private API"
- `.planning/ROADMAP.md` §"Phase 21: Drag-Out" — Goal, Depends on (Phase 20), Success Criteria (3 items)

### Prior phase decisions this phase builds on
- `.planning/phases/19-shelf-data-model/19-CONTEXT.md` — D-03 (local copy populated immediately on add, `localURL` is what gets dragged), D-04 (original file at `originalURL` never touched), D-05 (local copy deleted the instant an item leaves the shelf — relevant boundary: this phase's drags never delete anything, only manual removal does)
- `.planning/phases/20-shelf-view/20-CONTEXT.md` — D-04 (missing-file-on-click precedent, directly reused as D-02 above), D-05 (shelf-area tap-to-collapse — drag gestures on an item must not fall through to this), code_context's Finding-15 scoped-gesture precedent (per-item `Button`/gesture must sit outside the shared `onClick` ancestor scope — the same constraint applies to whatever gesture recognizer initiates the drag)

No other external specs — requirements fully captured in decisions above.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Islet/Notch/ShelfItemView.swift` (Phase 20) — the leaf view this phase adds drag-out behavior to. Currently has `onTap`/`onDelete` closures and a scoped `.onTapGesture` for open + a sibling `Button` overlay for delete (Finding-15 pattern) — the drag gesture must be added without breaking either.
- `Islet/Shelf/ShelfItem.swift` — `localURL` is the file to hand to the drag provider (per phase goal: "the item's own local copy").
- `Islet/Shelf/ShelfCoordinator.swift` / `ShelfFileStore.swift` (Phase 19) — own the real FileManager copy/delete mechanics; this phase reads `localURL` but must not call `remove`/`clear` on drag (per D-01, items are never auto-removed by a drag).

### Established Patterns
- **No existing drag code in the codebase** — confirmed via search (`onDrag`, `NSItemProvider`, `NSDraggingSource`, `NSFilePromiseProvider` all return zero matches). This phase is genuinely greenfield for drag APIs; no existing pattern to mirror for the drag mechanism itself.
- **Single source of truth for click-through** (`Islet/Notch/NotchWindowController.swift` `syncClickThrough()`, `pointerInZone`, `visibleContentZone()`) — the panel is only interactive (`ignoresMouseEvents = false`) when the pointer is inside the visible blob rect. Since a user must already be hovering/clicking within that interactive zone to start a shelf-item drag, drag initiation itself is not blocked by click-through — D-03's pin-open concern is specifically about the pointer LEAVING that zone mid-drag (toward Finder), not about starting it. See the CR-01 gotcha (project memory `cr01-clickthrough-or-defeat-gotcha`) before touching any of this logic — a prior regression here was subtle and passed grep/build gates.
- **Scoped tap-gesture precedent** (Finding 15, reused in Phase 20's `ShelfItemView`): ancestor gesture recognizers must never sit above descendant `Button`s or be ambiguous with them. The new drag gesture on `ShelfItemView` needs the same care alongside the existing `onTapGesture`(open) and `Button`(delete).

### Integration Points
- `NotchWindowController` owns the hover/grace-collapse timer machinery that D-03 needs to suppress — likely a new "drag in progress" flag checked alongside `pointerInZone` in the same places `syncClickThrough()`/the collapse-scheduling logic already check state, following the existing single-arbiter convention (no parallel/duplicate state machine).
- `ShelfItemView` is the drag SOURCE only in this phase (no drop destination anywhere yet — that's Phase 22's job, and Phase 22's own risk note about `ignoresMouseEvents` blocking drag delivery is about receiving drags, not initiating them, so it does not block this phase).

</code_context>

<specifics>
## Specific Ideas

No specific visual references given for this phase — functional behavior (copy semantics, no-op on missing file, pin-open during drag, default OS preview) is fully captured in the decisions above.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 21-Drag-Out*
*Context gathered: 2026-07-10*
