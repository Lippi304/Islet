# Phase 32: Tray Widening - Context

**Gathered:** 2026-07-14
**Status:** Ready for planning

<domain>
## Phase Boundary

The Tray view (and only the Tray view) renders wider with larger file tiles, so more files are visible side-by-side without scrolling — reusing `blobShape()`'s existing `width:` override precedent (already used by `onboardingCarousel`). Folded into this phase: the Tray panel also shrinks vertically to hug its actual content instead of reserving the shared `switcherContentHeight` (196pt) box, closing the pending todo discovered during Phase 31's on-device verification.

</domain>

<decisions>
## Implementation Decisions

### Growth scope (width)
- **D-01:** Only the Tray tab grows wider. Home/Calendar/Weather stay at the existing `expandedSize.width` (420pt) — no global width change. The island visibly morphs wider when switching to Tray and back, using the `width:` override parameter `blobShape()` already supports.
- **D-02:** The wider Tray width applies unconditionally whenever the Tray tab is active — including the empty state (`trayEmptyState`) — not gated on whether the shelf has items. No extra width-morph moment when the first file is dropped.
- **D-03:** Target width: **~840pt (double the current 420pt)**, as a first pass. Exact pixel value is Claude's/planner's call within that "roughly double" intent — not a hard-locked number.

### Tile / icon size
- **D-04:** File icons in `shelfRow`/`ShelfItemView` grow moderately, not proportionally to the width doubling. Target: **~40×40pt** (up from the current 28×28pt). Filename caption width (`maxWidth: 44`) should be revisited alongside this so text doesn't look cramped next to larger icons — Claude's/planner's call on the exact value.

### Layout shape
- **D-05:** Stays a single-row, horizontally-scrolling strip (`shelfRow(_:)`'s existing `ScrollView(.horizontal)` + `HStack` structure is NOT replaced with a grid). The wider panel simply fits more tiles before scrolling kicks in. No LazyVGrid/multi-row rework.

### Vertical shrink-to-fit (folded todo)
- **D-06:** Folded into Phase 32 scope (user confirmed) — the Tray panel should shrink to hug its actual content (file row + camera clearance, or the empty-state copy) instead of reserving the fixed `switcherContentHeight` (196pt) that Calendar's month grid needs but Tray doesn't.
- **D-07:** **Known trade-off, explicitly accepted:** `blobShape`'s `showSwitcher: true` path currently forces ALL tabs (Home/Calendar/Weather/Tray) to the same `switcherContentHeight` specifically so the switcher row (Home/Tray/Calendar/Weather icons) sits at an identical Y position on every tab — a deliberate Phase 28-04-round-5 fix for a misclick regression (switcher position shifting between tabs caused clicks to land on the wrong spot mid-transition). Shrinking Tray's height independently means the switcher icons will sit at a **different, higher** Y position on Tray than on Home/Calendar/Weather. **User explicitly accepted this** rather than requiring the larger structural fix (decoupling switcher-row position from content height, e.g. via a bottom-anchored overlay) needed to keep the icons pixel-identical across all tabs.
- **D-08:** Because layout stays single-row (D-05), content height doesn't need to vary by file count — the shrink is mainly about picking a smaller fixed height for Tray (empty-state vs. has-files may still differ) rather than a truly dynamic per-item-count height.

### Claude's Discretion
- Exact new Tray height constant(s) for empty vs. non-empty state.
- Exact pixel values for width (~840pt target) and icon size (~40×40pt target) — "roughly double" and "moderately bigger" are the locked intents, not the exact numbers.
- Exact filename caption width/font adjustments to match larger icons.
- Whether the width-morph and height-shrink use the same or different animation curves — technical detail.

### Folded Todos
- **"Tray panel oversized vertically, shrink to fit content"** (`.planning/todos/pending/2026-07-14-tray-panel-oversized-vertically-shrink-to-fit-content.md`) — originally filed as its own candidate/quick-task during Phase 31's on-device verification (empty black gap between file row and switcher icons, caused by the fixed 196pt `switcherContentHeight` box). User confirmed folding it into Phase 32 since both issues touch the same `blobShape`/Tray layout code. Delete this todo file once Phase 32 ships it.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase definition
- `.planning/ROADMAP.md` §"Phase 32: Tray Widening" — goal, 4 success criteria, depends-on note re: Phase 31
- `.planning/REQUIREMENTS.md` line 22 — TRAY-05 exact wording

### Regression-class precedent (must follow)
- Project memory `cr01-clickthrough-or-defeat-gotcha` — any change to `visibleContentZone()`/click-through hit-testing needs an explicit on-device hover→expand→move-down trace before being considered verified (ROADMAP success criterion 4 for this phase codifies this explicitly)
- Phase 28-04 round 5 rationale (see `Islet/Notch/NotchPillView.swift` comment block directly above `blobShape()`, ~line 1079) — why `switcherContentHeight` is currently shared/fixed across all tabs; the shrink-to-fit work (D-06/D-07) deliberately reintroduces a controlled version of the Y-position variance that fix eliminated, with explicit user sign-off

### Folded todo (prior finding)
- `.planning/todos/pending/2026-07-14-tray-panel-oversized-vertically-shrink-to-fit-content.md` — root-cause note and affected files, folded into this phase per D-06

### Prior phase (dependency)
- `.planning/phases/31-shelf-consolidation-to-tray-only/31-CONTEXT.md` — confirms `visibleContentZone()` and `shelfStripVisible` state going into this phase; Phase 32 is the second (and per Phase 31's own scoping, the ONLY planned) touch of `visibleContentZone()`

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `blobShape()`'s `width:` optional override parameter (`Islet/Notch/NotchPillView.swift` ~line 1092) — already exists and is already used by `onboardingCarousel` (though currently at the same 420pt value as everything else); Tray widening is the first caller to actually diverge the value.
- `blobShape()`'s `height:` optional override parameter — exists but is currently overridden by `showSwitcher: true` forcing `switcherContentHeight` (see D-07) — the shrink-to-fit work needs to either bypass that force for Tray specifically or introduce an equivalent Tray-specific constant.

### Established Patterns
- Named size constants as the codebase convention (`expandedSize`, `wingsSize`, `shelfRowHeight`, `switcherRowHeight`, `switcherContentHeight`, `onboardingSize`) rather than inline magic numbers — a new Tray-specific width/height constant should follow this pattern.
- `shelfRow(_:)` and `ShelfItemView` are reused verbatim across Home/Calendar/Weather/Tray (Pattern 3: shelf-item rendering is never reinvented) — icon-size change in `ShelfItemView` (currently hardcoded 28×28 at line 17) affects ALL callers, not just Tray, since there's only one `ShelfItemView`. Planner/researcher should confirm whether that's intended (it wasn't explicitly asked) or whether Tray needs its own larger-icon variant.
- CR-01 discipline: any `visibleContentZone()` change requires an explicit on-device hover→expand→move-down trace before being considered verified.

### Integration Points
- `Islet/Notch/NotchPillView.swift` — `trayFullView` (~line 738, currently calls `blobShape` with no `width:` override, `showSwitcher: true`), `blobShape()` (~line 1089), `shelfRow(_:)` (~line 1158), `switcherRow`/`switcherContentHeight` (~line 316, ~1136)
- `Islet/Notch/ShelfItemView.swift` — icon `.frame(width: 28, height: 28)` (line 17), filename caption `.frame(maxWidth: 44)` (line 23)
- `Islet/Notch/NotchWindowController.swift` — `visibleContentZone()` must be updated to match Tray's new (wider AND shorter) geometry; this is the second and last planned touch per Phase 31's dependency note

</code_context>

<specifics>
## Specific Ideas

- User's own words on target size: "mach mal so doppelt so breit erstmal" (make it about double wide for now) — width ≈ 840pt.
- User explicitly flagged wanting the vertical oversizing (screenshot shown at session start: files appearing to peek out over the island's top edge, large black gap below the file row) addressed together with the widening, not as an afterthought — hence folding the todo into this phase rather than deferring it.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope (width, icon size, layout shape, and the folded height todo all fall within Tray Widening's domain).

### Reviewed Todos (not folded)
None — the one matching todo (`todo.match-phase 32`, score 0.9) was folded in (see Folded Todos above).

</deferred>

---

*Phase: 32-tray-widening*
*Context gathered: 2026-07-14*
