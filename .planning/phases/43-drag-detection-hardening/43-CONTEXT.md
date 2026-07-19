# Phase 43: Drag Detection Hardening - Context

**Gathered:** 2026-07-19
**Status:** Ready for planning

<domain>
## Phase Boundary

The island's auto-expand / Quick Action destination picker only fires on a genuine external file drag approaching the island — a plain click or hover on the collapsed or expanded island never triggers it. This closes the false-trigger regression reported since Phase 24/34 shipped (DRAG-01). No new capabilities — implementation hardening of existing drag-approach detection only.

</domain>

<decisions>
## Implementation Decisions

### False-trigger scope
- **D-01:** The bug is NOT limited to clicking — dragging *anything* near/over the notch (a Finder window being moved, a non-file drag, etc.) currently expands the island, not just an ordinary click. Any left-mouse-drag gesture with the pointer inside the accept zone reproduces it.
- **D-02 [informational]:** When the false-trigger fires, the island does NOT show the 3 Quick Action buttons (Drop/AirDrop/Mail) — it opens the standard expanded view instead. This matches the root cause: `pendingDrop` stays nil (no real files on the drag pasteboard) so `IslandResolver` never resolves to `.quickActionPicker`, but `interaction.phase` is still force-transitioned to `.expanded` by `recheckDragAcceptRegion()` regardless of whether real drag content exists. Diagnostic only — explains why the false-trigger symptom looks the way it does; the fix in D-01 (gating `recheckDragAcceptRegion` on genuine drag content) makes this observation moot rather than requiring its own plan action.
- **D-03:** After a false-trigger, the island also stops auto-collapsing on its own — it stays expanded until the user manually clicks it shut again (the normal grace-collapse timer no longer fires). The user confirmed this is the SAME bug/SAME fix, not a separate issue: fixing the false-trigger arm condition is expected to also restore normal auto-collapse behavior, since both symptoms stem from the same erroneous `.dragEntered` transition. If any residual auto-collapse issue remains after gating the false-trigger, it stays in scope for this phase to close.

### Verification strictness
- **D-04:** A short manual on-device check is sufficient (no formal multi-scenario UAT checklist needed in the plan): ordinary click → nothing opens; hover with no drag → nothing opens; real file dragged from Finder → Quick Action picker shows and auto-collapses correctly afterward.

### Latency trade-off
- **D-05:** An imperceptible delay on the genuine drag-trigger path (e.g. waiting one extra event tick to confirm the drag pasteboard actually changed for this gesture) is acceptable if that's what a stricter real-drag gate requires. Hard requirement is only that it must not *feel* slower — no perceptible added latency budget beyond that.

### Claude's Discretion
- Exact mechanism for distinguishing a genuine external file drag from an incidental `.leftMouseDragged` tick (e.g. gating on `dragPasteboardChangeCount` actually changing for this gesture, rather than only tracking it) is an implementation detail — researcher/planner decide the precise fix.
- Whether the auto-collapse regression (D-03) needs its own explicit code change beyond the false-trigger gate fix, or falls out naturally once `.dragEntered` stops firing spuriously, is for research/planning to determine.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements & roadmap
- `.planning/ROADMAP.md` (Phase 43 section, ~line 609) — goal, success criteria, DRAG-01
- `.planning/REQUIREMENTS.md` (line 41) — DRAG-01 full requirement text
- `.planning/PROJECT.md` (line 79) — original bug report framing

### Prior precedent for this class of bug
- Memory: `cr01-clickthrough-or-defeat-gotcha` — CR-01 click-through hot-zone fix required an explicit hover→expand→move-down on-device trace, not just grep/build gates; same category of geometry/event-edge bug as this phase's root cause.

No other external specs — requirements fully captured in decisions above.

</canonical_refs>

<code_context>
## Existing Code Insights

### Root cause (confirmed via code read, not yet fixed)
- `Islet/Notch/NotchWindowController.swift` `recheckDragAcceptRegion()` (~line 1096): arms `isDragApproaching` and force-transitions `interaction.phase` to `.expanded` via `nextState(_:.dragEntered)` based PURELY on `isWithinDragAcceptRegion` geometry (pointer-in-zone), on every `.leftMouseDragged` tick. It does not check whether a genuine external drag with real file content is actually in progress.
- `handleDragApproachTick()` (~line 1062) tracks `dragPasteboardChangeCount` (comparing `NSPasteboard(name: .drag).changeCount` to the last seen value) but — per its own comment — this is used ONLY to keep the stored count current, never as a gate. `recheckDragAcceptRegion()` calls `fileURLs(from: NSPasteboard(name: .drag))` to populate `pendingDrop`, but that pasteboard is a persistent system-wide named pasteboard: its content is whatever was last written by ANY real drag anywhere on the system, and stays stale until overwritten. An ordinary click (which produces a tiny incidental `.leftMouseDragged` from mouse-down/up wobble) or any unrelated drag gesture over the zone therefore reads stale/absent pasteboard state and force-expands the island without ever needing real file content.
- `InteractionPhase`/`nextState` (`Islet/Notch/NotchInteractionState.swift`): `.dragEntered` transitions `.collapsed`/`.hovering` → `.expanded` unconditionally — it's geometry-agnostic by design (comment: "the CALLER gates WHICH geometry triggers this event"), so the caller (`recheckDragAcceptRegion`) is the only place that can add a genuine-drag gate.
- `IslandResolver.swift` (~line 146): `.quickActionPicker` only resolves when `pendingDrop != nil` — this explains why the false-trigger shows the standard expanded view, not the 3-button picker (D-02).
- `isWithinDragAcceptRegion` (`Islet/Notch/DragDropSupport.swift` line 27) is pure geometry (`zone.contains(point) && point.y <= maxY`) — no drag-content awareness, correctly scoped as a pure/testable helper; the content-genuineness check belongs at the call site, not here.

### Established patterns
- Pure/testable seam convention: geometry and pasteboard-URL helpers live in `DragDropSupport.swift` as free functions (`isWithinDragAcceptRegion`, `fileURLs`), unit-tested via `@testable import Islet` (see `IsletTests/DragApproachGeometryTests.swift`). Any new gating logic should follow this pattern if it's pure enough to extract.
- Edge-tracking discipline: `isDragApproaching`, `pointerInZone` are both edge-tracked booleans (armed on enter, disarmed unconditionally on `.leftMouseUp`/geometry-exit) — mirror this shape for any new gate state rather than introducing a different lifecycle.

### Integration points
- `recheckDragAcceptRegion()` and `handleDragApproachTick()` in `NotchWindowController.swift` are the two functions this phase will most likely touch.
- `dragApproachMonitor` / `dragEndMonitor` (armed in `start(isFirstLaunch:)`, torn down in `deinit`) are the global `.leftMouseDragged`/`.leftMouseUp` monitors driving this whole path — always-on, not DEBUG-gated (SHELF-01/02 must work in Release).

</code_context>

<specifics>
## Specific Ideas

- User's own words on the bug: "Es vergrößert sich die Notch halt direkt sobald man irgendwas zieht, egal ob Fenster oder File oder sowas. Was mir aber aufgefallen ist, dass nicht diese 3 Drop-Buttons gezeigt werden, sondern standardmäßig die Notch — und die Island schließt sich auch dann nicht mehr selber, sondern erst wenn man sie selber nochmal per Klick anklickt."

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 43-Drag Detection Hardening*
*Context gathered: 2026-07-19*
