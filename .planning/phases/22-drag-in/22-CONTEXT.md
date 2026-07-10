# Phase 22: Drag-In - Context

**Gathered:** 2026-07-10
**Status:** Ready for planning (revised 2026-07-10 after 22-01 on-device spike found a hot-zone/Mission-Control blocker — see "Hot-Zone Fallback" below; D-02 below is superseded)

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
- **D-02 (SUPERSEDED 2026-07-10 — see "Hot-Zone/Mission-Control Fallback" below):** The drag-in drop zone is the SAME hot-zone geometry already used for hover/click (`pointerInZone` / the existing hit-test rect in `NotchWindowController`) — no separate, larger padded zone just for dragging. This was contradicted by the 22-01 on-device spike: the tiny hot-zone sits flush against the physical screen top edge, and the drag path crosses macOS's own top-edge Mission Control trigger before reaching it. Replaced by D-02b/D-05/D-06/D-07 below.

### Hot/targeted visual feedback (SHELF-02)
- **D-03:** Use the existing hover bounce/scale-up spring animation (D-01 from Phase 2 — hover gives an affordance via a spring scale, never auto-expands on its own) as the drag-hot feedback. No new visual effect (no glow, no accent-color flash) — drag-hover reuses the same affordance the pointer-hover state already produces.

### Drop scope boundary
- **D-04:** Drag-in is accepted ONLY while the island is collapsed, exactly as ROADMAP Success Criteria #1 states ("onto the collapsed island pill"). Dropping while the island is already expanded (showing Now Playing, idle glance, or an already-open shelf) is explicitly OUT of scope for this phase — no drop-destination registration needed for the expanded state. If a future need arises, it's a new phase/requirement.

### Hot-Zone/Mission-Control Fallback (revision, 2026-07-10)

The 22-01 on-device spike confirmed AppKit drag delivery reaches the click-through panel (A1, unchanged), but found a NEW, separate blocker: the drop never completes because the drag path crosses macOS's own top-edge Mission Control trigger before reaching the tiny hot-zone (`22-01-SUMMARY.md`, `22-RESEARCH.md` Open Question 4). D-02 above is superseded by the following:

- **D-02b (Drag-accept zone reuses the existing reserved footprint):** The drag-accept region is NOT a newly-invented zone — it reuses the panel's existing always-reserved expanded+wings footprint (the `expandedZone`-equivalent region: `panelFrame.insetBy(dx: -hotZonePadding, dy: -hotZonePadding)`, already computed in `positionAndShow()` and already sized/reserved even while collapsed, per Phase 20's D-01 unconditional-reservation pattern). No separate drag-only geometry to design or maintain.
- **D-02c (Landing margin below the physical top edge):** Because that reserved footprint is still top-pinned flush to the literal screen edge (`topPinnedFrame` in `NotchGeometry.swift` — nothing can extend further up, there's no screen real estate above the physical notch), the drop-ACCEPT logic must require the release point to land at least some margin below that top edge, rather than accepting only when flush against it. This gives the user room to complete the drop without needing to dwell at the exact top row that triggers macOS's Mission Control-during-drag gesture. Exact margin value is Claude's Discretion (research/measure against the reserved footprint's existing height).
- **D-05 (Auto-expand trigger widens with the accept zone):** D-01's auto-expand-on-drag-enter now triggers off the SAME wider reserved footprint (as soon as AppKit's own `draggingEntered` fires) instead of the old tiny hot-zone. This is earlier and more forgiving than the original click-based hover trigger — intentional, since it's what gives the user enough runway to avoid the Mission Control edge before releasing.
- **D-06 (Drag-hot feedback fires with the same wider trigger):** D-03's drag-hot bounce/scale feedback fires at the exact same moment as D-05's wider auto-expand trigger — one signal drives both, not two separately-timed triggers. Avoids a visible expand/feedback timing mismatch.
- **D-07 (Ordinary hover/click hot-zone is UNCHANGED):** All of the above widening applies ONLY while an active drag session is in flight. The normal (non-drag) mouse hover/click hot-zone (`pointerInZone` / `hotZone` as used today) stays exactly as small/precise as it is now — zero change to existing non-drag hover/click UX.
- **Known architecture risk for planner/researcher (not a user decision, flagging so it isn't missed):** any new "drag session is active" state that gates the widened zone must route through the SAME single arbiter that already owns `ignoresMouseEvents`/`syncClickThrough()` — NOT a parallel flag. This is the exact CR-01 regression class from Phase 21 (project memory `cr01-clickthrough-or-defeat-gotcha`): a second, independently-checked flag for "is a drag in flight" is how click-swallowing regressions happen. The drag-active signal must be one more input INTO `syncClickThrough()`'s existing decision, not a bypass around it.

### Claude's Discretion
- Exact AppKit mechanism for registering the panel/view as a drag destination (`NSDraggingDestination` conformance point — view vs. panel, `registerForDraggedTypes`) — not discussed; planner/researcher resolves against the existing single-arbiter click-through convention.
- Exact margin value for D-02c's "landing below the top edge" requirement — planner/researcher measures against the reserved footprint's existing height and macOS's typical Mission-Control-during-drag dwell geometry.
- How "an active drag session" is detected to gate D-02b/D-05/D-07's widening (e.g., driven directly by `draggingEntered`/`draggingExited` callbacks already firing on the panel, vs. a global drag-session monitor mirroring Phase 21's `dragReleaseMonitor`) — implementation detail, must route through the single arbiter per the architecture risk note above.
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
- **RESOLVED + new blocker (revision, 2026-07-10):** `.planning/phases/22-drag-in/22-01-SUMMARY.md` — the spike's on-device test. A1 CONFIRMED YES (drag delivery survives click-through). NEW finding: the drop never completes because the drag path crosses macOS's top-edge Mission Control trigger before reaching the tiny hot-zone. `.planning/phases/22-drag-in/22-RESEARCH.md` Open Questions 1 (resolved) and 4 (new, drives the D-02b/D-02c/D-05/D-06/D-07 fallback decisions above). `.planning/STATE.md` "Blockers/Concerns" — records the routing back to this discuss-phase.

No other external specs — requirements fully captured in decisions above.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Islet/Notch/NotchPanel.swift` — the borderless, non-activating `NSPanel` this phase must make a drag destination. `ignoresMouseEvents` starts `true`, flipped by `NotchWindowController` only inside the hover hot-zone (see below) — the exact mechanism a drag-destination registration must coexist with. Already carries the throwaway 22-01 spike scaffold (`registerForDraggedTypes([.fileURL])` + 4 stub `NSDraggingDestination` methods) — 22-03 replaces the stubs with real handling, per `22-01-SUMMARY.md`.
- `Islet/Notch/NotchWindowController.swift` `syncClickThrough()` (~line 770) — the SINGLE arbiter for `ignoresMouseEvents`; while collapsed, interactivity is `pointerInZone`, while expanded it's `visibleContentZone()?.contains(lastPointerLocation)`. D-02 (superseded) originally reused `pointerInZone`'s geometry as-is for drag too; D-02b/D-05/D-06/D-07 now route a new "drag session active" signal INTO this same arbiter (see architecture risk note in `<decisions>`) rather than adding a parallel flag.
- `Islet/Notch/NotchWindowController.swift` `positionAndShow()` (~line 601-666) — already computes `expandedZone = panelFrame.insetBy(dx: -hotZonePadding, dy: -hotZonePadding)`, where `panelFrame = expandedFrame.union(wings)` is the ALWAYS-reserved (even while collapsed, per Phase 20 D-01) big footprint. D-02b reuses this exact existing rect as the drag-accept zone — no new geometry computation needed.
- `Islet/Notch/NotchGeometry.swift` `topPinnedFrame()` (~line 62) — the shared helper behind both `expandedNotchFrame()` and `wingsFrame()`; confirms all reserved frames (collapsed, expanded, wings) share the exact same top-pinned Y (`collapsed.maxY`, flush to the physical screen edge) — this is WHY D-02c's "landing margin below the top edge" has to be an explicit accept-condition, not something free from a taller reserved rect alone.
- `Islet/Notch/NotchWindowController.swift` `handleHoverEnter()`/`handleHoverExit()` — the existing hover bounce/scale spring (D-03/D-06 reuse this for drag-hot feedback) and the grace-collapse timer (`graceWorkItem`) that Phase 21's `isDraggingShelfItem` flag already pins open during an outbound drag — the same pin-open pattern likely applies to an inbound drag so the panel doesn't collapse mid-hover-with-drag.
- `Islet/Shelf/ShelfCoordinator.swift` — `append`/the Phase 19 add path this phase's drop handler calls into; already handles local-copy creation and dedup, this phase just needs to hand it dropped `URL`s.
- `Islet/Shelf/ShelfViewState.swift` / `resyncShelfViewState()` (`NotchWindowController`) — the existing resync path called after any shelf mutation (e.g., `pruneMissingFiles()` in `handleClick()`); a drop handler should call the same helper after appending.

### Established Patterns
- **Drag delivery already reaches the panel via its full reserved window frame, not just the pill** — CONFIRMED on-device (22-01-SUMMARY.md, A1): `registerForDraggedTypes` operates at the window level, so `draggingEntered` already fires across the whole `panelFrame` (collapsed OR expanded, since the panel is always pre-sized to the union per Phase 20's static-max-reservation pattern). The remaining gap is ACCEPT-gating logic (D-02/old), not AppKit delivery.
- **Single arbiter, no parallel state machine** (`syncClickThrough()`, reinforced by the CR-01 gotcha) — any new "drag in progress" bookkeeping must be checked in the same places `pointerInZone`/`visibleContentZone()` already are, not as an independent flag with its own logic path. This directly governs how D-02b/D-05/D-07's widening must be wired.
- **Isolate the most uncertain integration in its own step** (project convention per `.planning/STATE.md` roadmap-evolution note: "the one genuinely uncertain integration point — drag delivery through the click-through `NSPanel` — is isolated in its own last phase") — already done via the 22-01 spike; the remaining hot-zone/Mission-Control fallback is the next isolated increment.

### Integration Points
- `NotchPanel.swift` — `NSDraggingDestination` conformance + `registerForDraggedTypes` already scaffolded (22-01); 22-03 replaces the 4 throwaway stub bodies with real closure-forwarding into `NotchWindowController`.
- `NotchWindowController` — owns `panel`, `pointerInZone`, `expandedZone`, `syncClickThrough()`, `handleHoverEnter/Exit`, `graceWorkItem`, and `shelfCoordinator`/`resyncShelfViewState()` — the natural place to add `draggingEntered`/`draggingExited`/`performDragOperation` handling AND the new drag-session-active signal that feeds `syncClickThrough()` per D-02b/D-05/D-06/D-07.

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
