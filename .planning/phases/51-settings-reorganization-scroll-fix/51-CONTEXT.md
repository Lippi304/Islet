# Phase 51: Settings Reorganization & Scroll Fix - Context

**Gathered:** 2026-07-21
**Status:** Ready for planning

<domain>
## Phase Boundary

Fix the Settings window's scroll-cutoff bug (Weather/Diagnostics controls currently unreachable below the fold) and split the crowded General tab into focused, dedicated sidebar sections. Restructures Phase 27's existing `NavigationSplitView` sidebar `SettingsView` — no new subsystem, no new settings/behavior added, every control that exists today must still exist and work after the split.

</domain>

<decisions>
## Implementation Decisions

### Sidebar structure & naming
- **D-01:** The "System" tab is renamed to "Appearance" — same content (Appearance Style segmented picker + Accent Colors swatch rows), just renamed and repositioned among the new split sections. Not a separate/new section.
- **D-02:** "Launch Islet at login" (currently the first control at the top of General) folds into the new "Activities" section, alongside the 8 existing activity toggles (Charging, Now Playing, Song-Change Toast, Devices, Calendar Countdown, Focus Mode HUD, OSD suppression, Auto-Update Check).
- **D-03:** "Diagnostics" (currently a single "Save Diagnostic Report…" button) gets its own dedicated sidebar section, matching the roadmap's explicit listing — not folded into About or elsewhere.
- **D-04:** Claude picks the SF Symbol icons for the new sections (Activities, Appearance, Fullscreen, Weather, Diagnostics) — no back-and-forth needed on icon choice. Reuse "paintbrush" for Appearance (carried over from System's existing icon).

### Window sizing
- **D-05:** The Settings window stays fixed at 520×380 (unchanged). Each section's content scrolls internally if it overflows — this is the actual scroll fix. Activities remains the tallest section (Launch at Login + 8 toggles + conditional permission-hint text) and will scroll; other new sections (Fullscreen, Weather, Diagnostics) are short enough to need no scrolling normally. Rejected: growing the window taller or making it user-resizable — unnecessary complexity for content that fits fine once split and scrollable.

### Sidebar section order
- **D-06:** Final sidebar order, top to bottom: **Activities, Appearance, Fullscreen, Weather, Diagnostics, Workspace, About.** The 5 split-out sections lead (most-used first, per the roadmap's own listed order), followed by the two untouched existing tabs (Workspace, About) in their current relative position.

### Claude's Discretion
- Exact SF Symbol per new section beyond Appearance's carried-over "paintbrush" (Activities/Fullscreen/Weather/Diagnostics) — per D-04, pick something sensible (e.g. bolt for Activities, arrow.up.left.and.arrow.down.right for Fullscreen, cloud.sun for Weather, stethoscope/wrench for Diagnostics).
- Root cause of the current scroll bug (why the existing `Form` inside `NavigationSplitView`'s detail pane isn't scrolling today) and the exact scroll-fix mechanism (e.g. explicit `ScrollView` wrapper per section) — implementation detail for planning/research, not surfaced as a user decision.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Roadmap & requirements
- `.planning/ROADMAP.md` (Phase 51 entry, lines ~840-855) — goal, success criteria, "Depends on: Nothing (restructures Phase 27's existing NavigationSplitView sidebar SettingsView)" framing
- `.planning/REQUIREMENTS.md` (SETTINGS-02, SETTINGS-03, lines 78-79, 161-162) — the two locked requirements this phase must satisfy
- `.planning/PROJECT.md` (lines 94-107, "Current Milestone: v1.8") — milestone goal and key context for all 3 v1.8 phases

### Existing code (Phase 27's sidebar, unmodified architecture)
- `Islet/SettingsView.swift` — the entire file this phase restructures. Key locations: `SidebarSection` enum (line 80), sidebar `ForEach` with manual `Button`-based selection (lines 106-131, NOT `List(selection:)` — that was a proven-broken approach on this setup per the inline Plan 27-04 comment, must not be reintroduced), `generalSection` (line 194, the catch-all being split), `systemSection` (line 428, becoming "Appearance"), fixed `.frame(width: 520, height: 380)` (line 189)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `SidebarSection` enum (`SettingsView.swift:80-102`) — `CaseIterable, Identifiable` with `title`/`icon` computed properties; extend with new cases (`.activities`, `.appearance`, `.fullscreen`, `.weather`, `.diagnostics`) replacing `.general`/`.system`, keeping `.workspace`/`.about`.
- Manual `Button`-based sidebar list (lines 113-130) — proven to work reliably on this setup; the switch-based detail-pane dispatch (lines 134-145) is the pattern to extend for the new sections, not `List(selection:)`.
- Each existing detail-pane section (`generalSection`, `systemSection`, `workspaceSection`, `aboutSection`) is a `Form { ... }.padding(20)` — same shape to replicate for the 5 new sections.

### Established Patterns
- Content already exists per-`Section("...")` block inside the monolithic `generalSection` Form (Activities, Fullscreen, Weather, Diagnostics are already named `Section`s at lines 219, 279, 287, 297) — the split is mostly promoting these existing `Section` blocks to their own top-level `SidebarSection` detail views, not writing new UI from scratch.
- Liquid Glass background styling (lines 171-188) and the fixed `.frame` apply at the `NavigationSplitView` level, outside the per-section switch — unaffected by the section split.

### Integration Points
- `@AppStorage`-backed state vars (`chargingEnabled`, `weatherStyle`, `materialStyle`, etc.) are declared at `SettingsView` struct scope, not per-section — no state-ownership changes needed when moving `Section` blocks to new `SidebarSection` cases.

</code_context>

<specifics>
## Specific Ideas

No specific visual references given — this phase reorganizes existing, already-styled controls into new sidebar buckets. No new visual design needed beyond icon selection (Claude's discretion, D-04).

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

### Reviewed Todos (not folded)
- **Calendar month-grid polish** (`.planning/todos/pending/2026-07-19-calendar-month-grid-polish.md`) — matched by generic "ui" keyword scoring, not actually related to Settings; skipped.
- **Island briefly disappears during click-through** (`.planning/todos/pending/2026-07-19-island-briefly-disappears-during-click-through.md`) — same, unrelated; skipped.
- **Quick Action disabled state has no controller gate** (`.planning/todos/pending/2026-07-19-quick-action-disabled-state-has-no-controller-gate.md`) — same, unrelated; skipped.

</deferred>

---

*Phase: 51-settings-reorganization-scroll-fix*
*Context gathered: 2026-07-21*
