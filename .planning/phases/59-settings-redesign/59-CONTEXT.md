# Phase 59: Settings-Redesign - Context

**Gathered:** 2026-07-23
**Status:** Ready for planning

<domain>
## Phase Boundary

The Activities-related sections of the Settings window are replaced by one categorized, 2-column grid of Live-Activity cards — one card per activity (existing + new), each showing a static illustration icon, title, one-line description, an on/off toggle, and (where applicable) an options affordance. Every brand-new v1.10 Live Activity defaults OFF; every already-shipped activity's current toggle state is preserved exactly on upgrade. A reviewed resolver-priority table documents where all v1.10 activities slot into `IslandResolver`/`TransientQueue`.

This phase does NOT build any of the 8 new activities themselves (Caps Lock, Timer/Pomodoro, Meeting-HUD, Quick Notes, Quick Actions bar, Menübar-Overflow, Coding-Progress, Download-Progress) — only the grid container, the card component, the migration-safe default-OFF wiring, and the resolver-priority table those later phases will plug into.

</domain>

<decisions>
## Implementation Decisions

### Grid Layout
- **D-01:** Cards are grouped into fixed categories with visible headers: **System-HUDs**, **Medien**, **Produktivität** — not a flat list, not alphabetical.
- **D-02:** Grid is fixed at **2 columns** (not 3, not adaptive/responsive) — matches the current fixed-width Settings window.
- **D-03:** Within each category, already-shipped activities are ordered before new v1.10 activities.
- **D-04:** New (v1.10-introduced) activities' cards carry a visible **"Neu"-Badge** to help users discover them, since they're defaulted OFF and could otherwise go unnoticed.

### Grid Contents & Categorization
- **D-05:** "Launch at login" and "Automatically Check for Updates" are **not** cards in the grid — they stay as plain toggles in a separate general/non-activity section, since they produce no island content.
- **D-06:** "Song-Change Toast" gets **its own card** (not folded as a sub-option under the "Now Playing" card), consistent with "one card per toggle."
- **D-07:** Category assignments for existing activities: **System-HUDs** = Charging, Device/Bluetooth, Focus Mode HUD, OSD-Suppression, Calendar Countdown. **Medien** = Now Playing, Song-Change Toast. **Produktivität** = reserved for new v1.10 activities (Timer/Pomodoro, Meeting-HUD, Quick Notes, Quick Actions bar).

### Card Options Affordance
- **D-08:** Focus Mode HUD's and OSD-Suppression's existing "+Popover" (extra config) stays attached to the card, not moved to a separate detail sheet.
- **D-09:** The card component gets a **generic, optional options-slot affordance** (icon/chevron) now, in Phase 59 — not deferred to whichever later phase first needs it. This is a deliberate foundation choice: later phases (Timer duration, Meeting-HUD calendar picker, etc.) fill the slot instead of redesigning the card.
- **D-10:** The new generic options-slot **replaces** today's separate "+Popover" icon on Focus Mode HUD / OSD-Suppression — one unified options icon across all cards, not two icons side by side.

### Mini Preview
- **D-11:** Card preview is a **static illustration icon** per activity (SF-Symbol-style, in the activity's pill color/shape) — explicitly NOT a live-updating real-data preview (no real battery %, no real album art). Rationale: matches the actual Droppy reference grid (which itself uses static icons, not live values), and avoids needing a live data source for 8 new activities that are default-OFF anyway (nothing live to show).
- **D-12:** Claude designs both the illustration icons and the one-line description copy for every card — user reviews the result during on-device UAT rather than pre-approving mockups/sketches.

### Claude's Discretion
- Exact resolver-priority table format/location (comment block vs. separate doc) for SC5 — no user preference expressed; Claude picks whatever the researcher/planner finds cleanest given `IslandResolver.swift`'s existing comment-based rank convention (ranks are named comments, not raw ints — new v1.10 cases slot in between existing named ranks, not renumbered).
- Exact migration mechanism for default-OFF new activities — reuse the existing `ActivitySettings.migrateLegacyAccentIfNeeded()` pattern (absent `@AppStorage` key ⇒ default applies; presence-check before ever writing) rather than inventing a new versioned-migration system, since no explicit migration write is needed for brand-new keys.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Droppy reference material
- `.planning/research/inspiration/notes.md` — line 43 (HUD settings grid with mini-preview reference), lines 32/36 (sidebar-categorized redesign precedent, live-preview concept mention)

### Existing Settings/Activities implementation
- `Islet/SettingsView.swift` — `SidebarSection` enum (lines 96-137), `activitiesSection` (lines 262-348) being replaced
- `Islet/ActivitySettings.swift` — `@AppStorage` key namespace for all activity toggles; `migrateLegacyAccentIfNeeded()` (lines 124-137) is the precedent pattern for safe-default migration

### Resolver/priority
- `Islet/Notch/IslandResolver.swift` — `IslandPresentation` enum (lines 61-77), `ActiveTransient` enum (lines 81-85), `TransientQueue` struct (lines ~277-355)

### Requirements
- `.planning/REQUIREMENTS.md` — SETTINGS-04 (line 82), SETTINGS-05 (line 83)
- `.planning/ROADMAP.md` — Phase 59 section (Success Criteria 1-5)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- None directly reusable for the grid/card UI itself — no `LazyVGrid`/`GridItem` usage exists anywhere except the unrelated Calendar month grid (`NotchPillView.swift:1244`); no `Card`/`MiniPill` component exists. The grid and card component are net-new.
- `ActivitySettings`'s `@AppStorage` key namespace and its `migrateLegacyAccentIfNeeded()` presence-check pattern are directly reusable for wiring new activity keys safely.

### Established Patterns
- `SettingsView`'s sidebar uses plain `Button`s instead of `List(selection:)` — documented as deliberately broken-avoidance (comment at lines 154-160); any new grid UI should follow the same non-`List` convention within `SettingsView`.
- Existing activities toggles all default to `true` except permission-gated ones (`focusKey`, `osdSuppressionKey` default `false`) — the same "default true for pre-v1.10, false for v1.10+" split continues.

### Integration Points
- New grid replaces `activitiesSection` inside the existing `NavigationSplitView` sidebar structure from v1.8 — the sidebar itself (Activities/Appearance/Fullscreen/Weather/Diagnostics/Workspace/About) is untouched; only the Activities detail view changes.
- `IslandResolver`/`TransientQueue` need new `IslandPresentation`/`ActiveTransient` cases for each new v1.10 activity, added later per-phase — Phase 59 only produces the priority table, not the new cases themselves (those don't exist until their own phase).

</code_context>

<specifics>
## Specific Ideas

- Grid should read visually like Droppy's HUD settings grid (see canonical ref above) — categorized sections of cards with icon + title + description + toggle, not a flat toggle list.
- "Neu"-Badge on new-activity cards is explicitly to prevent the 8 new default-OFF activities from going unnoticed by users who don't read changelogs.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope. (The generic options-slot, D-09, is a forward-looking foundation decision for THIS phase to build, not a deferred capability — it ships now, empty for most cards, filled in by later phases.)

</deferred>

---

*Phase: 59-Settings-Redesign*
*Context gathered: 2026-07-23*
