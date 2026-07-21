# Phase 52: Top-Edge Switcher Layout & Placement Config - Context

**Gathered:** 2026-07-21
**Status:** Ready for planning

<domain>
## Phase Boundary

Add a second, opt-in switcher layout: 4 small icons at the very top edge of the expanded island (2 left of the camera/notch cutout, 2 right) as an alternative to today's pill-below-the-island switcher. The user configures which icon sits in which of the 4 slots, and can switch between the two layouts in Settings. Adds a new presentation mode alongside Phase 28/45's existing `SelectedView`/`IslandPresentation`/`switcherRow` system — no new tabs, no new switcher content, purely a second way to render and arrange the same 4 existing icons (Home/Tray/Calendar/Weather).

</domain>

<decisions>
## Implementation Decisions

### Placement reassignment
- **D-01:** Fully independent per-icon assignment — each of the 4 icons (Home, Tray, Calendar, Weather) can be placed in any of the 4 slots (left-outer, left-inner, right-inner, right-outer), not just a swap of two fixed pairs. (Superseded an initial "fixed-pair swap" answer once the dropdown-count clarification made the actual intent clear.)
- **D-02:** The Settings control is 4 dropdown pickers, one per slot, each offering all 4 icons.
- **D-03:** Placement reassignment applies to BOTH layouts — reassigning which icon goes in which slot also reorders the existing pill-below-island switcher's left-to-right icon order to match. This is a scope expansion onto the already-shipped, Phase-45-morph-fixed `switcherRow` — flag for research/planning as touching stable code, not just adding new code.

### Top-edge icon visual style
- **D-04:** Top-edge icons reuse the existing `navCircleButton` component verbatim (same filled-circle visual, same component) — no new icon treatment. Verify on-device that it physically fits the thinner top-edge strip; if it doesn't, that's a plan-time/UAT finding, not a pre-decided fallback.
- **D-05:** The active tab shows the same filled/highlighted state in top-edge mode as it does in the pill today, using `navCircleButton`'s existing `filled:` parameter — no new selection-state logic needed.

### Mode switch behavior
- **D-06:** When top-edge mode is active, the pill-below-island row is fully removed (not shown, not replaced) — the island's total height shrinks by the pill row's height, content area keeps its current height/size. This is the literal reading of the roadmap's "instead of" framing.
- **D-07:** The layout toggle (pill vs. top-edge) and the 4 placement dropdowns live together in a new dedicated "Switcher" section in Settings' sidebar — following Phase 51's just-established per-feature-section pattern rather than folding into an existing section (e.g. Appearance).

### No-notch fallback
- **D-08:** On a display without a physical camera notch (external monitor, older MacBook), the top-edge layout option — including the new "Switcher" Settings section itself, per D-07 — is hidden entirely rather than shown in a degraded/centered form. The app already computes `hasNotch` (via `auxLeftWidth`/`auxRightWidth` off `NSScreen`, see `NotchGeometry.swift`) — reuse that existing signal to gate visibility.

### Claude's Discretion
- Exact SF Symbol / visual treatment for the new "Switcher" Settings section's sidebar icon.
- Whether `hasNotch` gating hides just the top-edge toggle/dropdowns within the Switcher section, or the entire section — implementation detail; the observable requirement (D-08) is that the option isn't reachable on non-notch displays.
- Any internal state/model needed to represent "which icon is in which of the 4 slots" (e.g. a `[SelectedView]` ordered array vs. 4 discrete `@AppStorage` slot values) — implementation detail for planning.
- Whether the existing pill's reordering (D-03) requires restructuring `switcherRow`'s hardcoded 4-button HStack into something iteration-driven, or can stay a hardcoded switch on slot assignment — implementation detail, must not regress Phase 45's continuous-view-identity morph fix.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Roadmap & requirements
- `.planning/ROADMAP.md` §"Phase 52: Top-Edge Switcher Layout & Placement Config" (~line 862) — goal, 5 success criteria, "Depends on: Nothing (adds a new layout mode to Phase 28/45's existing switcher/tab system)" framing
- `.planning/REQUIREMENTS.md` (SWITCH-03, SWITCH-04, lines 83-84, 163-164) — the two locked requirements this phase satisfies
- `.planning/PROJECT.md` (lines 94-107, "Current Milestone: v1.8") — milestone goal and key context for all 3 v1.8 phases

### Prior phase precedent this phase builds on
- `.planning/phases/45-view-switcher-morph-fix/45-CONTEXT.md` — root-cause detail on `presentationSwitch`'s structural-identity morph fix; the top-edge layout addition and the pill reordering (D-03) must not reintroduce the disappear/rebuild flicker or behind-buttons glitch this phase fixed
- `.planning/phases/51-settings-reorganization-scroll-fix/51-CONTEXT.md` — the 7-section sidebar structure (`SidebarSection` enum in `Islet/SettingsView.swift`) the new "Switcher" section (D-07) extends
- `.planning/phases/44-tray-quick-action-width-alignment/44-CONTEXT.md` / `.planning/phases/32-tray-widening/32-CONTEXT.md` — prior precedent on the switcher/blobShape geometry this phase's height-shrink (D-06) touches

### Existing code (Phase 28/45's switcher system, unmodified architecture)
- `Islet/Notch/ViewSwitcherState.swift` — `SelectedView` enum (`.home`/`.tray`/`.calendar`/`.weather`) and `ViewSwitcherState.selectedView`, the single source of truth for the active tab
- `Islet/Notch/NotchPillView.swift` — `switcherRow` (~line 2041, the pill's hardcoded 4-`navCircleButton` HStack, D-03's reorder target), `presentationSwitch` (~line 774, the `IslandPresentation` switch Phase 45 fixed), `blobShape` (~line 1884, `showSwitcher`-gated pill row inclusion, D-06's shrink point)
- `Islet/Notch/IslandResolver.swift` — `IslandPresentation` enum (~line 61)
- `Islet/Notch/NotchGeometry.swift` / `Islet/Notch/NSScreen+Notch.swift` — existing `hasNotch(safeAreaTop:auxLeftWidth:auxRightWidth:)` function and `NSScreen.descriptor` bridge; D-08's fallback gate reuses this, not a new detection mechanism
- `Islet/SettingsView.swift` — `SidebarSection` enum (post-Phase-51, 7 cases: activities/appearance/fullscreen/weather/diagnostics/workspace/about) the new "Switcher" section (D-07) extends; same `Form`-per-section pattern to replicate

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `navCircleButton` (used throughout `NotchPillView.swift`'s `switcherRow`) — reuse verbatim for top-edge icons per D-04, including its existing `filled:` selection-state parameter (D-05).
- `hasNotch(safeAreaTop:auxLeftWidth:auxRightWidth:)` (`NotchGeometry.swift`) and `ScreenDescriptor`/`NSScreen.descriptor` (`NSScreen+Notch.swift`) — already compute real camera-cutout presence/width from `auxiliaryTopLeftArea`/`auxiliaryTopRightArea`; currently only consumed by `NotchWindowController.swift` for window positioning, not yet exposed to SwiftUI content — will need a path to reach the Settings view and/or the top-edge layout view for D-08's gating and for actually flanking the cutout.
- `SidebarSection` enum (`SettingsView.swift`, post-Phase-51) — extend with a new `.switcher` case following the exact same pattern Phase 51 established for the other 5 split sections.

### Established Patterns
- Phase 45's "one continuous view identity" rule for `presentationSwitch`/`blobShape` — any change to `switcherRow` or the pill/top-edge toggle must keep tab-switch morphing glitch-free; a naive top-edge-vs-pill conditional render is the same class of structural-identity risk Phase 45 already fixed once.
- Phase 51's "one `SidebarSection` case + `Form` per section" pattern — the new "Switcher" section should look identical in shape to Activities/Appearance/etc.
- `@AppStorage`-backed state vars declared at `SettingsView` struct scope (Phase 51 code_context) — the new layout-mode toggle and 4 slot-assignment values likely follow the same convention.

### Integration Points
- `Islet/Notch/NotchPillView.swift` — where the top-edge icon row itself renders, gated by the new layout-mode setting, positioned relative to `blobShape`'s frame using the notch's real `auxLeftWidth`/`auxRightWidth`.
- `Islet/SettingsView.swift` — new `.switcher` `SidebarSection` case, `hasNotch`-gated per D-08.
- `Islet/Notch/ViewSwitcherState.swift` — `SelectedView` stays the source of truth for which tab is active; slot-assignment is a separate, new piece of state (which icon → which position), not a change to `SelectedView` itself.

</code_context>

<specifics>
## Specific Ideas

No specific visual reference given — user confirmed reusing the existing `navCircleButton` component as-is (D-04) rather than describing a new look.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

### Reviewed Todos (not folded)
- No pending todos matched this phase's domain (`.planning/todos/pending/` contains only calendar-grid, click-through, and Quick-Action-gating items — all unrelated to switcher layout/placement).

</deferred>

---

*Phase: 52-top-edge-switcher-layout-placement-config*
*Context gathered: 2026-07-21*
