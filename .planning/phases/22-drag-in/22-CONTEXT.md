# Phase 22: Drag-In - Context

**Gathered:** 2026-07-10
**Status:** Ready for planning

<domain>
## Phase Boundary

Users can drag a file, multiple files, or a folder from Finder (or any other app) onto the **collapsed** island pill — it auto-expands and each item lands in the shelf strip. While a file is being dragged over the pill before release, the drop target shows visible "hot"/targeted feedback (SHELF-02). This is the single highest-uncertainty integration point of the v1.3 milestone: whether the click-through `NSPanel` (`ignoresMouseEvents`) can receive AppKit drag-destination events at all, and whether `.mouseMoved` tracking survives a drag gesture without freezing the hover/collapse state machine.

Out of scope for this phase: drag-out (Phase 21, already shipped), the shelf data model (Phase 19, already shipped), folder spring-loading/auto-navigating into dropped folder contents (a dropped folder is always one shelf item — REQUIREMENTS.md Out of Scope), and accepting drops while the island is already expanded (locked as out-of-scope below, D-04).

</domain>

<decisions>
## Implementation Decisions

### Auto-expand timing
- **D-01:** The island expands immediately on drag-ENTER (as soon as a dragged file touches the collapsed pill's drop zone) — not only after the drop completes. The user sees the shelf open before releasing, mirroring macOS Dock spring-loading. The drop then lands into the now-visible expanded/shelf view.

### Drop-zone hit area
- **D-02:** The drag-in drop zone is the SAME hot-zone geometry already used for hover/click (`pointerInZone` / the existing hit-test rect in `NotchWindowController`) — no separate, larger padded zone just for dragging. Reuses the existing single-arbiter hit-test convention rather than introducing a second zone concept.

### Hot/targeted visual feedback (SHELF-02)
- **D-03:** Use the existing hover bounce/scale-up spring animation (D-01 from Phase 2 — hover gives an affordance via a spring scale, never auto-expands on its own) as the drag-hot feedback. No new visual effect (no glow, no accent-color flash) — drag-hover reuses the same affordance the pointer-hover state already produces.

### Drop scope boundary
- **D-04:** Drag-in is accepted ONLY while the island is collapsed, exactly as ROADMAP Success Criteria #1 states ("onto the collapsed island pill"). Dropping while the island is already expanded (showing Now Playing, idle glance, or an already-open shelf) is explicitly OUT of scope for this phase — no drop-destination registration needed for the expanded state. If a future need arises, it's a new phase/requirement.

### Claude's Discretion
- Exact AppKit mechanism for registering the panel/view as a drag destination (`NSDraggingDestination` conformance point — view vs. panel, `registerForDraggedTypes`) — not discussed; planner/researcher resolves against the existing single-arbiter click-through convention.
- How drag-enter/drag-exit is detected to drive D-01's auto-expand and D-03's bounce feedback (e.g., `draggingEntered`/`draggingExited` vs. a new SwiftUI `.onDrop` modifier with `isTargeted`) — implementation detail.
- Behavior when a drag carries non-file `NSItemProvider` content (e.g., dragged text/image data with no file URL) — treat as a no-drop/reject, consistent with the shelf's file-only model; exact rejection mechanism is an implementation detail.
- Behavior when a drag-in is attempted while a Charging/Device splash is actively suppressing the shelf (SHELF-09) — not discussed in depth; default to the same silent-no-op precedent already established for other edge cases (Phase 19 D-02, Phase 20 D-04, Phase 21 D-02) unless research surfaces a reason to special-case it.
- Multi-file/folder drag ordering into the shelf (which item appended first) — follows Phase 19 D-06 (append in drop order), same as any other addition path.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements source
- `.planning/REQUIREMENTS.md` — SHELF-01 ("User can drag a file, multiple files, or a folder onto the collapsed island — it auto-expands and the item(s) land in a shelf strip below the expanded view"), SHELF-02 ("Drop target shows 'hot'/targeted visual feedback while a file is being dragged over, before release"); v1.3 header note: "Standard `NSItemProvider` drag & drop, no private API"
- `.planning/REQUIREMENTS.md` Out of Scope table — "Folder spring-loading (auto-navigating into dropped folder contents)" is explicitly excluded; a dropped folder is one shelf item
- `.planning/ROADMAP.md` §"Phase 22: Drag-In" — Goal, Depends on (Phase 21), Success Criteria (4 items)

### Prior phase decisions this phase builds on
- `.planning/phases/19-shelf-data-model/19-CONTEXT.md` — D-01/D-02 (duplicate = same `originalURL`, silent no-op — applies directly to drag-in duplicates), D-03 (local session-copy made immediately on add — this phase's drop handler must populate `ShelfItem.localURL` the same way any other add path does), D-06 (append order = drop order)
- `.planning/phases/20-shelf-view/20-CONTEXT.md` — D-04 (missing-file silent no-op precedent, reused as the default for the Claude's-Discretion Charging/Device-splash edge case above)
- `.planning/phases/21-drag-out/21-CONTEXT.md` — code_context's click-through single-arbiter note and the CR-01 gotcha (project memory `cr01-clickthrough-or-defeat-gotcha`): `syncClickThrough()` is the ONE place that decides `ignoresMouseEvents`; the expanded-state branch must stay a pure `visibleContentZone()` check, never OR'd with the broader `pointerInZone`. Any new drag-related state (e.g., "drag in progress") must route through this same single arbiter, not a parallel flag.

### Known technical risk (for research, not a locked decision)
- `.planning/STATE.md` "Blockers/Concerns" — flags that `ignoresMouseEvents = true` blocking AppKit drag-destination delivery entirely is an UNVERIFIED assumption drawn from general AppKit knowledge, not a re-fetched Apple doc page or on-device test. An on-device spike verifying whether a click-through, non-activating `NSPanel` (`.borderless`, `.nonactivatingPanel`, `ignoresMouseEvents` toggling like `Islet/Notch/NotchPanel.swift`) can register as a drag destination and receive `draggingEntered`/`performDragOperation` is needed before committing to the full drag-in architecture. This is a research/spike task, not something the user was asked to decide.

No other external specs — requirements fully captured in decisions above.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Islet/Notch/NotchPanel.swift` — the borderless, non-activating `NSPanel` this phase must make a drag destination. `ignoresMouseEvents` starts `true`, flipped by `NotchWindowController` only inside the hover hot-zone (see below) — the exact mechanism a drag-destination registration must coexist with.
- `Islet/Notch/NotchWindowController.swift` `syncClickThrough()` (~line 770) — the SINGLE arbiter for `ignoresMouseEvents`; while collapsed, interactivity is `pointerInZone`, while expanded it's `visibleContentZone()?.contains(lastPointerLocation)`. D-02 (drop-zone hit area) reuses `pointerInZone`'s existing geometry rather than adding a new zone.
- `Islet/Notch/NotchWindowController.swift` `handleHoverEnter()`/`handleHoverExit()` — the existing hover bounce/scale spring (D-03 reuses this for drag-hot feedback) and the grace-collapse timer (`graceWorkItem`) that Phase 21's `isDraggingShelfItem` flag already pins open during an outbound drag — the same pin-open pattern likely applies to an inbound drag so the panel doesn't collapse mid-hover-with-drag.
- `Islet/Shelf/ShelfCoordinator.swift` — `append`/the Phase 19 add path this phase's drop handler calls into; already handles local-copy creation and dedup, this phase just needs to hand it dropped `URL`s.
- `Islet/Shelf/ShelfViewState.swift` / `resyncShelfViewState()` (`NotchWindowController`) — the existing resync path called after any shelf mutation (e.g., `pruneMissingFiles()` in `handleClick()`); a drop handler should call the same helper after appending.

### Established Patterns
- **No existing drag-DESTINATION code anywhere** — confirmed via grep (`NSDraggingDestination`, `registerForDraggedTypes`, `draggingEntered`, `performDragOperation` all return zero matches). Phase 21 added only a drag SOURCE (`ShelfItemView.onDrag`); this phase is genuinely greenfield for the destination side.
- **Single arbiter, no parallel state machine** (`syncClickThrough()`, reinforced by the CR-01 gotcha) — any new "drag in progress" bookkeeping must be checked in the same places `pointerInZone`/`visibleContentZone()` already are, not as an independent flag with its own logic path.
- **Isolate the most uncertain integration in its own step** (project convention per `.planning/STATE.md` roadmap-evolution note: "the one genuinely uncertain integration point — drag delivery through the click-through `NSPanel` — is isolated in its own last phase") — the researcher/planner should front-load a spike/proof-of-concept for drag-destination delivery before designing the rest of the phase's plan.

### Integration Points
- `NotchPanel.swift` init — where `NSDraggingDestination` registration (`registerForDraggedTypes`) would need to be added, likely on the hosting view rather than the panel itself, given SwiftUI's `NSHostingView` architecture.
- `NotchWindowController` — owns `panel`, `pointerInZone`, `syncClickThrough()`, `handleHoverEnter/Exit`, `graceWorkItem`, and `shelfCoordinator`/`resyncShelfViewState()` — the natural place to add `draggingEntered`/`draggingExited`/`performDragOperation` handling (or a SwiftUI-level `.onDrop` if research finds that path viable given the click-through panel).

</code_context>

<specifics>
## Specific Ideas

No specific visual references given for this phase — functional behavior (drag-enter auto-expand, hover-zone-only drop target, reused hover-bounce feedback, collapsed-only scope) is fully captured in the decisions above.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope. (Accepting drops while already expanded was explicitly considered and locked OUT of scope, D-04 — not deferred as a future idea, just not built here unless a future phase adds it.)

</deferred>

---

*Phase: 22-Drag-In*
*Context gathered: 2026-07-10*
