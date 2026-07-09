# Phase 20: Shelf View - Context

**Gathered:** 2026-07-09
**Status:** Ready for planning

<domain>
## Phase Boundary

With hand-seeded shelf state (Phase 19's `ShelfLogic`/`ShelfItem`/`ShelfCoordinator`), the expanded island renders a full shelf strip: file-type icons, per-item and delete-all removal, click-to-open, and correct gating alongside Charging/Device splashes. Proves the view and panel-sizing math before any live drag risk (Phase 21 drag-out, Phase 22 drag-in) is introduced.

Out of scope for this phase: real drag-in (Phase 22), drag-out to Finder (Phase 21), and the underlying data model (Phase 19, already shipped).

</domain>

<decisions>
## Implementation Decisions

### Panel growth strategy
- **D-01:** The expanded island grows TALLER (dynamic height) only when the shelf has items — mirrors Phase 18's toast-row precedent (`mediaWingsOrToast`'s conditional height): one shape, height grows conditionally, never a fixed always-reserved band.
- **D-02:** The shelf row is appended under ALL expanded branches uniformly — `mediaExpanded`, `expandedIdle`, AND `mediaUnavailable` all get the same shelf strip when it has content. No special-casing any one branch.

### Delete-all confirmation
- **D-03:** SHELF-05's single trash icon clears the whole shelf instantly, no confirmation dialog. Consistent with SHELF-08's session-only premise (nothing precious is destroyed — only the shelf's own temp copies go, originals untouched) and the app's lightweight-utility feel.

### Missing-file-on-click
- **D-04:** If a shelf item's local session-copy is gone when clicked (SHELF-07), the click is a silent no-op — no error dialog, no crash, no auto-removal. The item stays in the shelf, inert, until the user removes it via its own trash icon.

### Shelf-area tap behavior
- **D-05:** Tapping empty space within the shelf strip (not on an item or its trash icon) collapses the island, same as every other non-button region of the expanded blob (Finding 15 precedent: only item-click and trash-click get their own scoped gesture; everything else falls through to the shared `onClick`).

### Claude's Discretion
- Exact file-type icon rendering mechanism (e.g. `NSWorkspace.shared.icon(forFile:)`) — not discussed, use the standard system API.
- Visual layout specifics (icon size, spacing, scroll indicator styling, exact height added per shelf row) — this phase has a UI hint; defer pixel-level decisions to the UI design contract (`/gsd:ui-phase 20`) rather than locking them here.
- Whether the shelf row's per-item trash icon uses the same Finding-15 scoped-gesture technique as the delete-all icon — implementation detail, follow the established pattern.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements source
- `.planning/REQUIREMENTS.md` — SHELF-03, SHELF-04, SHELF-05, SHELF-07, SHELF-09
- `.planning/ROADMAP.md` §"Phase 20: Shelf View" — Goal, Depends on (Phase 19), Success Criteria (5 items), UI hint: yes

### Prior phase decisions this phase builds on
- `.planning/phases/19-shelf-data-model/19-CONTEXT.md` — D-01–D-06 (duplicate handling, local copy strategy, ordering) — this phase consumes `ShelfItem`/`ShelfLogic`/`ShelfCoordinator` as-is, does not modify them.

No other external specs — requirements fully captured in decisions above.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Islet/Shelf/ShelfItem.swift`, `Islet/Shelf/ShelfLogic.swift`, `Islet/Shelf/ShelfCoordinator.swift` (Phase 19) — the pure data model and its real-I/O coordinator this phase renders. `ShelfCoordinator.append/remove/clear` already handle the D-05 (Phase 19) real-deletion side effects; this phase's view/controller only needs to call them.
- `Islet/Notch/BatteryIndicator.swift` pattern — an example of a small, reusable leaf SwiftUI view this phase's per-item icon+trash row can mirror.

### Established Patterns
- **Single shared morph, one `NotchShape`, no cross-fade** (`Islet/Notch/NotchPillView.swift`, D-07): all expanded/wings content morphs one black blob via `matchedGeometryEffect(id: "island", in: ns)`. The shelf row must extend this SAME shape's height, not introduce a second shape.
- **Conditional-height precedent** (`mediaWingsOrToast`, Phase 18 D-08): `NotchShape` height computed as `base + (condition ? extra : 0)`, content in a `VStack` where the conditional row appears/disappears with `.transition(.opacity)`. Direct analog for D-01's dynamic shelf-row growth.
- **Single arbiter, no view-level precedence** (`IslandResolver.swift`, D-05): the controller's pure `resolve(...)` reducer already returns one `IslandPresentation` case per state; SHELF-09's gating (hidden during Charging/Device) falls out for free since `.charging`/`.device` are the transient cases the resolver returns BEFORE ever reaching `.nowPlayingExpanded`/`.expandedIdle`/`.nowPlayingExpanded(_, false)` — no new suppression logic needed in the resolver itself, only in how/where the shelf row is composed into those three view branches.
- **Scoped tap-gesture precedent** (Finding 15, `NotchPillView.swift` lines ~164-174): ancestor `.onTapGesture` is never placed above descendant `Button`s — ambiguous gesture resolution. Any per-item or delete-all trash Button must sit OUTSIDE the shared `onClick` gesture's ancestor scope, exactly like `mediaExpanded`'s transport buttons today.
- **Size constants co-located on `NotchPillView`** (`expandedSize`, `wingsSize`, `toastExtraHeight`): the new shelf-row height addition should follow the same static-constant-with-explanatory-comment convention.

### Integration Points
- `NotchPillView.swift`'s `blobShape(...)` helper (used by `expandedIsland`, `mediaExpanded`, `mediaUnavailable`) is the natural place to grow — D-02 means all three callers need the same conditional extra height, suggesting `blobShape` itself grows a shelf-aware height parameter rather than each caller re-deriving it independently.
- `NotchWindowController` (or wherever the controller currently owns `ShelfCoordinator` — not yet wired, this phase does the first wiring) will need to own a `ShelfCoordinator` instance and publish shelf state the view observes, mirroring how `nowPlaying`/`presentationState`/`outfit` are each a separate `@ObservedObject` the view renders without deciding precedence itself.
- Window/panel frame sizing (`NotchGeometry`) must grow to match the new dynamic content height — same "panel matches content, no runtime resize surprise" contract already established for `expandedSize`/`wingsSize`.

</code_context>

<specifics>
## Specific Ideas

No specific visual references given for this phase (UI-SPEC via `/gsd:ui-phase 20` will cover pixel-level layout). The functional shape is: icons in a horizontally-scrolling row, each with its own small trash icon, one delete-all trash icon at the far right, all appended below whatever expanded content is already showing.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 20-Shelf View*
*Context gathered: 2026-07-09*
