# Phase 45: View Switcher Morph Fix - Context

**Gathered:** 2026-07-19
**Status:** Ready for planning

<domain>
## Phase Boundary

Fix two related SwiftUI transition bugs in the Home/Tray/Calendar/Weather switcher pill (no new capabilities — pure animation/transition fix on already-shipped views):

1. **SWITCH-01** — switching tabs currently shows a disappear/rebuild flicker instead of one continuous spring morph directly to the new tab's size.
2. **SWITCH-02** — a large→small transition (e.g. Calendar → Tray) briefly renders the shrinking island shape behind/underneath the switcher pill buttons during the morph.

Root cause context (confirmed via code read, not yet fixed — for the researcher/planner, not re-litigated with the user): `presentationSwitch` (`NotchPillView.swift` ~line 774) is a `@ViewBuilder switch` over the `IslandPresentation` enum; each tab (`.trayExpanded`, `.calendarExpanded`, `.weatherExpanded`, `.homeEmpty`/`.homeLastPlayed`) maps to its own private helper (`trayFullView`, `calendarFullView`, `weatherFullView`, etc.) that independently calls `blobShape(...)` with its own `.matchedGeometryEffect(id: "island", in: ns)` and its own nested `switcherRow` instance. Switching between switch-cases changes the rendered subtree's structural identity, which SwiftUI treats as remove+insert rather than a resize — this is the mechanism behind both bugs. The four tabs also genuinely differ in both width and height (`switcherContentHeight` = 196 for Home/Calendar/Weather's default vs. `trayContentHeight` = 117 for Tray, per Phase 44's D-10; `calendarWidth` vs. `expandedSize.width` for width), so the fix must produce a real continuous resize, not just suppress a flicker.

</domain>

<decisions>
## Implementation Decisions

### Interrupted mid-morph tapping
- **D-01:** If the user taps a new tab while the island is still mid-morph toward a previously-tapped tab, the spring must retarget immediately toward the new tab — standard SwiftUI spring retargeting behavior. Never ignore the tap and never queue it for after the current morph finishes; a rapid tap sequence must read as one continuous redirect, not two discrete hops.

### Transition feel
- **D-02:** The tab-switch morph must reuse the exact same spring animation (same `.spring(response:dampingFraction:)` parameters) already driving the island's existing expand/collapse `matchedGeometryEffect` transitions — no new/distinct spring tuning for tab switches specifically. Consistency with the rest of the app's motion language is the priority, not a bespoke feel.

### Verification rigor
- **D-03:** All 12 pairwise tab-to-tab transitions (Home↔Tray, Home↔Calendar, Home↔Weather, Tray↔Calendar, Tray↔Weather, Calendar↔Weather, both directions each) must be explicitly walked and confirmed glitch-free on-device — matches ROADMAP success criterion #3 literally. This is stricter than Phase 43/44's "quick representative check" precedent; the user explicitly wants full pairwise coverage for this phase, not a sample.

### Claude's Discretion
- Exact mechanism for making `presentationSwitch`'s tab cases participate in one continuous morph (e.g. restructuring away from a hard `switch`-per-case, a shared container with conditional content, or another approach) — implementation detail for research/planning to determine. The user was not asked to choose an approach; only the observable behavior (D-01/D-02/D-03) was decided.
- Whether/how the interrupted-mid-morph retarget (D-01) requires any special-cased animation-cancellation code, or falls out naturally once the structural-identity-change root cause is fixed — for research/planning to determine.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements & roadmap
- `.planning/ROADMAP.md` §"Phase 45: View Switcher Morph Fix" (~line 640) — goal, 3 success criteria (including the literal "all 12 pairwise transitions" wording D-03 confirms), SWITCH-01/SWITCH-02
- `.planning/REQUIREMENTS.md` (~line 50-51) — SWITCH-01, SWITCH-02 exact wording

### Prior phase precedent this phase's constants depend on
- `.planning/phases/44-tray-quick-action-width-alignment/44-CONTEXT.md` — D-09/D-10: `trayContentHeight` was tied to `quickActionPickerContentHeight` (117), diverging from the other tabs' `switcherContentHeight` (196) — this height gap is the concrete "large→small" case SWITCH-02 names (Calendar → Tray)
- `.planning/phases/32-tray-widening/32-CONTEXT.md` — established `traySize`/`trayContentHeight` and the switcher-row-position-jump fix (28-04 round 5) that centralized `baseHeight` decisions in `blobShape` — relevant precedent for any restructuring touching that same function

### Prior precedent for this class of bug
- Project memory `cr01-clickthrough-or-defeat-gotcha` — not directly applicable (different code path — click-through hot-zone, not view-switch morph — confirmed distinct during this discussion, see Deferred below) but same project convention of requiring an explicit on-device trace, not just build/grep gates, before considering a geometry/transition fix verified

</canonical_refs>

<code_context>
## Existing Code Insights

### Root cause (confirmed via code read, not yet fixed)
- `Islet/Notch/NotchPillView.swift` `presentationSwitch` (~line 774-816) — `@ViewBuilder switch` over `IslandPresentation`; each tab case renders a structurally distinct subtree (own `blobShape` call, own `matchedGeometryEffect(id: "island", in: ns)`, own nested `switcherRow`). SwiftUI treats a case change as remove+insert, not resize — this is why the disappear/rebuild flicker (SWITCH-01) and the behind-buttons glitch (SWITCH-02) both happen at case-transition boundaries.
- `blobShape<Content: View>(...)` (~line 1884) — shared helper every tab's full-view function calls; computes `baseHeight`/`totalHeight` per-call (explicit `height:` override wins over the `showSwitcher` default per Phase 32/TRAY-05), applies `.matchedGeometryEffect(id: "island", in: ns)` before `.frame(...)`, and renders `content()` + `switcherRow` + optional `shelfRow` inside a `VStack` under `.overlay(alignment: .top)`.
- Confirmed height/width divergence across tabs: `switcherContentHeight` = 196 (Home/Calendar/Weather default), `trayContentHeight` = 117 (Tray, Phase 44 D-10), `calendarWidth` vs. `expandedSize.width` (Calendar is wider) — real geometry differences the morph must animate across, not just a flicker-suppression problem.
- `switcherRow` (~line 1952) — the Home/Tray/Calendar/Weather nav-button row; instantiated fresh inside every tab's own `blobShape` call rather than existing once outside the switch.

### Established patterns
- Geometry "three-site rule" (documented at `NotchWindowController.swift` ~line 1019, reused by every prior full-view phase including 44): any full-view geometry change must keep the frame reservation (`positionAndShow()`), the `contentSize` branch, and the SwiftUI view's own `blobShape` call all in sync.
- `matchedGeometryEffect` ordering convention (documented repeatedly in `NotchPillView.swift`, e.g. ~line 1908-1913): must precede `.frame`, not follow it — multiple past bugs from getting this backwards.

### Integration points
- `Islet/Notch/NotchPillView.swift` — `presentationSwitch` (~774), `blobShape` (~1884), `switcherRow` (~1952), the four tab full-view functions (`trayFullView`, `calendarFullView`, `weatherFullView`, home's `homeEmptyState`/`mediaExpanded`).
- `Islet/Notch/NotchWindowController.swift` — frame reservation / `contentSize` sites that must stay in sync with whatever geometry restructuring the fix requires (three-site rule).
- `Islet/Notch/ViewSwitcherState.swift` — `SelectedView` enum and `ViewSwitcherState.selectedView`, the tap-intent source `onSwitcherSelect` reports to; relevant to D-01's retarget behavior.

</code_context>

<specifics>
## Specific Ideas

No specific visual reference given beyond the ROADMAP wording — the user confirmed the existing expand/collapse spring should be reused as-is (D-02) rather than describing a new feel.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

### Reviewed Todos (not folded)
- **"Island briefly disappears during click-through"** (`.planning/todos/pending/2026-07-19-island-briefly-disappears-during-click-through.md`) — surfaced by the todo-matcher (score 0.9, keyword overlap on "disappears") but the user confirmed it should stay deferred: it's about the click-through hot-zone code path (`syncClickThrough()`/`visibleContentZone()`, hover→expand→move-pointer-down trace) during Phase 44 UAT, not the `presentationSwitch` tab-morph code this phase targets. Needs its own `/gsd-debug` session.
- **"Quick Action disabled state has no controller gate"** (`.planning/todos/pending/2026-07-19-quick-action-disabled-state-has-no-controller-gate.md`) — surfaced by the todo-matcher (score 0.7) but clearly out of domain (Quick Action button enablement gating, unrelated to tab-switch morph); not presented to the user as a real candidate.

</deferred>

---

*Phase: 45-view-switcher-morph-fix*
*Context gathered: 2026-07-19*
