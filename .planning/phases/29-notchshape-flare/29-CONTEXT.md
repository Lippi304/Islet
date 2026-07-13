# Phase 29: NotchShape Flare - Context

**Gathered:** 2026-07-13
**Status:** Ready for planning

<domain>
## Phase Boundary

Every expanded presentation (Home, Tray, Calendar, Weather, Charging/Device wings) gains a new outward-flaring top edge that widens into the screen bezel, threaded through the shared `NotchShape`/`blobShape()`/`wingsShape()` rendering pipeline so it applies automatically wherever those helpers are used. The collapsed/idle pill (`collapsedIsland`) stays pixel-identical to today — flush/straight into the edge, no shape/size/position regression. The flare is a fixed design-language detail (no user-facing toggle) and must animate cleanly as part of the existing collapse↔expand spring morph (SHAPE-01).

</domain>

<decisions>
## Implementation Decisions

### Flare look
- **D-01 (LOCKED):** The flare is a **subtle widen** — the top edge widens only a little before curving into the bezel, closer to today's existing 6pt quad-curve top corner, just a touch more pronounced. Not a dramatic trumpet/bell-shaped flourish. User explicitly rejected the "pronounced flare" option.
- **D-02 [informational]:** Exact pt values for the widen amount are Claude's/planner's discretion, tuned on-device — matches this project's established convention (wings sizing in Phase 3/4, bottom-corner radius in Phase 25, spring curves in Phase 2/25 were all tuned this way after an initial implementation pass).

### Coverage — media wings/toast excluded
- **D-03 (LOCKED):** The Now-Playing media wings / song-change-toast glance (`mediaWingsOrToast`, `NotchPillView.swift` ~line 1234) does **NOT** get the flare — it stays flush like the collapsed pill. Flare applies only to the ROADMAP-named set: Home, Tray, Calendar, Weather (all via `blobShape()`) and Charging/Device wings (via `wingsShape()`).
- **D-04:** This is structurally clean to implement — `mediaWingsOrToast` already makes its own inline `NotchShape(...)` call (not routed through `wingsShape()`), so excluding it requires no special-casing; only `blobShape()` and `wingsShape()` need the new flare parameter.

### Flare width behavior
- **D-05 (LOCKED):** The flare uses the **same absolute widen amount** across every covered presentation, regardless of shape width. The full expanded views (Home/Tray/Calendar/Weather, wide) and the Charging/Device wings (~290-305pt, narrower) all get the identical fixed flare — not a proportionally-scaled one. User explicitly chose consistency over per-width scaling.

### Claude's Discretion
- Exact geometry/math for the widen (e.g., whether `NotchShape` needs a new animatable parameter alongside `topCornerRadius`/`bottomCornerRadius`, or whether the existing quad-curve technique can be extended) — technical implementation, not discussed with the user.
- Exact pt value(s) for the flare widen amount and how it's tuned on-device (see D-02).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements & roadmap
- `.planning/REQUIREMENTS.md` — SHAPE-01 definition; also notes "User-configurable flare depth/amount for SHAPE-01 — fixed design language for now" (no Settings toggle, confirmed by D-01/D-02).
- `.planning/ROADMAP.md` §"Phase 29: NotchShape Flare" — goal, success criteria, and the explicit list of covered presentations (Home, Tray, Calendar, Weather, Charging/Device wings).
- `.planning/PROJECT.md` §"Current Milestone: v1.5" — SHAPE-01 target-features bullet.

### Prior related decisions
- `.planning/phases/25-visual-material-theming-redesign/25-CONTEXT.md` D-09 — confirms the EXISTING top-corner quad-curve technique (`topCornerRadius`) already reads as a "flowing merge into the screen edge" and was left unchanged in Phase 25; Phase 29 builds a distinct, more pronounced mechanism on top of/alongside it, not a replacement.
- `.planning/phases/27-settings-sidebar-redesign/27-CONTEXT.md` D-06 — lists the shell-chrome fill sites (`collapsedIsland`, `blobShape`, `wingsShape`, `mediaWingsOrToast`) that any prior shape/material change had to touch consistently; same site list is relevant here for scoping which functions the flare parameter threads through.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Islet/Notch/NotchShape.swift` — the single `Shape` struct (quad-curve top/bottom corners) every collapsed/expanded/wings state renders through via `matchedGeometryEffect(id: "island")`. `topCornerRadius`/`bottomCornerRadius` are plain `CGFloat` stored properties, so SwiftUI's `Shape` animation already interpolates them across the collapse↔expand spring — any new flare parameter should follow the same pattern to get smooth-morph animation "for free" (satisfies Success Criterion #3).

### Established Patterns
- All expanded presentations call `blobShape(topCornerRadius: 6, bottomCornerRadius: 32, ...)` (`NotchPillView.swift` lines ~440, 474, 658, 724, 772, 1492, 1561) — one shared private helper, so adding a flare parameter there covers Home/Tray/Calendar/Weather in one place.
- Charging/Device wings both go through the shared `wingsShape(content:)` helper (`NotchPillView.swift` ~line 1173, `NotchShape(topCornerRadius: 6, bottomCornerRadius: 6)`) — confirmed via comment at line 1182 that both `wings(for:)` (charging) and `deviceWings(for:)` route through it.
- `mediaWingsOrToast` (`NotchPillView.swift` ~line 1234-1253) makes its own standalone `NotchShape(topCornerRadius: 6, bottomCornerRadius: toast != nil ? 16 : 6)` call — does NOT go through `wingsShape()`. This is why D-03/D-04's exclusion is structurally free.
- The collapsed pill (`collapsedIsland`, ~line 409-423) calls plain `NotchShape()` (default `topCornerRadius: 6, bottomCornerRadius: 14`) with no flare parameter passed — must stay untouched per Success Criterion #2.

### Integration Points
- `blobShape()` (private func, `NotchPillView.swift` ~line 1074) and `wingsShape()` (~line 1173) are the two functions that need a new flare parameter threaded into their `NotchShape(...)` construction. `NotchShape.swift` itself needs the new animatable property added alongside `topCornerRadius`/`bottomCornerRadius`.

</code_context>

<specifics>
## Specific Ideas

No screenshot/reference image was provided for the exact flare curve — the user described the desired direction in words only ("subtle widen, a touch more than today's existing corner curve"). No specific pt values or reference app were named; on-device visual tuning is expected to finalize the exact look (see D-02).

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope. (User-configurable flare depth was already explicitly out-of-scope per REQUIREMENTS.md before this discussion started.)

</deferred>

---

*Phase: 29-notchshape-flare*
*Context gathered: 2026-07-13*
