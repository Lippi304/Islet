# Phase 60: Caps Lock HUD + Update-Activity Restyle - Context

**Gathered:** 2026-07-23
**Status:** Ready for planning

<domain>
## Phase Boundary

Two new transient HUDs land in the collapsed island, both using the existing "wings" transient pattern (see `code_context` below): a Caps Lock on/off HUD (event-driven, `NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged)`), and a genuinely new Update-available island HUD (leading icon, "Update" label, trailing version pill) that sits alongside — not replacing — the existing menu-bar red dot. Both register as new `IslandPresentation`/`ActiveTransient` cases, slot into `TransientQueue` at the lowest priority (below OSD), respect the Phase 59 Settings-grid card toggles (both default OFF), and only fire while the island is collapsed.

This phase does NOT touch the menu-bar dot's existing behavior, does NOT change Sparkle's update-check/download/install plumbing, and does NOT fix the unrelated "island disappears during click-through" bug (noted as a risk below, not in scope).

</domain>

<decisions>
## Implementation Decisions

### Update HUD Scope (critical correction to ROADMAP.md wording)
- **D-01:** ROADMAP.md Phase 60 describes UPDATE-01 as "reskinning the existing update-available HUD." **This is stale** — Phase 40 originally built exactly that (a collapsed-pill badge HUD), then redesigned it to a menu-bar status-item red dot (commit `30d9f82`) after an unfixable click-through/hot-zone bug; `Islet/Notch/UpdateAvailableState.swift` was deleted. **There is no existing island HUD to reskin.** UPDATE-01 is a **new** transient built from scratch using the wings pattern, not a restyle of existing code.
- **D-02:** The new Update HUD is added **alongside** the existing menu-bar dot — the dot is NOT removed. Both fire from the same `SPUUpdaterDelegate.updater(_:didFindValidUpdate:)` callback (`Islet/AppDelegate.swift:390`). Rationale: the menu-bar dot is the already-solved, always-clickable fallback; re-touching its click-through geometry is exactly the risk Phase 40 fled from, so the new island HUD doesn't need to replace it to satisfy SC3.

### Caps Lock HUD Content
- **D-03:** Caps Lock HUD shows an icon + text label in **both** the ON state ("Caps Lock On") and the OFF state ("Caps Lock Off") — unlike Charging's wings, which only show the label in the positive state and go icon-only when idle. Rationale: SC1 explicitly requires a HUD for both the on-toggle AND the off-toggle transition, so both need to be legible, not just one.

### Update HUD Version Pill
- **D-04:** The trailing pill on the Update HUD shows the version number only (e.g. "v1.11"), sourced from the `SUAppcastItem` already passed into `didFindValidUpdate(_:didFindValidUpdate:)` (use `item.displayVersionString`). Mirrors `BatteryIndicator`'s role as a compact trailing readout on the Charging wings.

### Priority / Rank Placement
- **D-05:** Both new transients rank **below OSD** (the current lowest rank, 4) in `TransientQueue` (`Islet/Notch/IslandResolver.swift:319`) — i.e. rank 5/6, added as new named-comment ranks per the existing convention (`Islet/Notch/IslandResolver.swift:94-99`), not renumbered. Rationale: they're the newest, least urgent signals — an in-progress Charging/Device/Focus/OSD transient should never be pre-empted by a Caps Lock toggle or an update notification.
- **D-06 (Claude's Discretion):** Exact relative order between Caps Lock (rank 5) and Update (rank 6) vs. the reverse — low-stakes, the two are extremely unlikely to collide with each other. Whichever order reads more naturally in the ranked-comment list is fine.

### Visibility Scope
- **D-07:** Both new HUDs are **collapsed-only** — same rule as Focus (`Islet/Notch/IslandResolver.swift:98`, D-07) and OSD (`:99`, D-11) — they do NOT pre-empt an expanded view (Calendar/Tray/Weather/Home), unlike Charging/Device which show regardless of expand state. Matches CAPS-01's literal "collapsed island" wording and keeps low-urgency signals from yanking the user out of an expanded tab.

### Claude's Discretion
- Exact SF Symbol choice for the Caps Lock icon (e.g. `capslock.fill`) and its color treatment for on vs. off states — no user preference expressed beyond "label + icon for both states."
- D-06 above (Caps Lock vs. Update relative rank order).
- Whether the Update HUD's tap-to-install gesture reuses `wings(for:)`'s existing tap-handling wiring or needs its own — implementation detail for planning/research to resolve.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Transient wings pattern (the shape both new HUDs must match)
- `Islet/Notch/NotchPillView.swift:2355-2395` — `wings(for:)`, the Charging HUD: leading icon+label HStack, `Spacer()`, trailing `BatteryIndicator` — the exact "leading icon, label, trailing pill" shape both CAPS-01 and UPDATE-01 must replicate.
- `Islet/Notch/NotchPillView.swift:2588` — `focusWings(for:)` (collapsed-only precedent, Phase 38/HUD-05).
- `Islet/Notch/NotchPillView.swift:2721` — `osdWings(for:)` (collapsed-only precedent, Phase 39/HUD-03/HUD-04, self-elapsing 1.5s timer).

### Resolver / priority
- `Islet/Notch/IslandResolver.swift:94-108` — `IslandPresentation` enum, named-rank-comment convention (D-02 rank 1-4 documented inline).
- `Islet/Notch/IslandResolver.swift:114-117` — `ActiveTransient` enum (mirrors `IslandPresentation`'s transient cases).
- `Islet/Notch/IslandResolver.swift:319` (`struct TransientQueue`) through ~`:369-371` (same-activity replace-in-place rules) — where new rank cases and their queue-replace rules get added.
- `Islet/Notch/IslandResolver.swift:82-87` — existing forward-looking comment block already anticipating Phase 60-67's new activities; Caps Lock/Update HUD ranks should update this comment.

### Caps Lock event source (net-new — no existing pattern in this codebase)
- `NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged)` — required by ROADMAP.md SC2; no existing global-monitor code exists in `Islet/` to model against (grep for `flagsChanged`/`capsLock`/`CapsLock` returns only the Phase 59 `@AppStorage` key and Settings card, no monitor implementation).

### Update HUD data source
- `Islet/AppDelegate.swift:390-391` — `SPUUpdaterDelegate.updater(_:didFindValidUpdate:)`, the existing callback that currently only unhides `updateDotView`; the new island HUD triggers from the same callback.
- `Islet/AppDelegate.swift:13,106` — `updateDotView` (the menu-bar red dot being kept, not replaced).

### Phase 59 Settings-grid wiring (both new activities already have their card + toggle)
- `Islet/ActivitySettings.swift:35` — `capsLockKey` AppStorage key (already exists, default OFF).
- `Islet/SettingsView.swift:61` — `capsLockEnabled` `@AppStorage` binding.
- `Islet/SettingsView.swift:194-197` — Caps Lock's `ActivityCardData` entry in the Settings grid (`isNew: true`, already wired).
- **Note:** grep found no equivalent `updateHudKey`/similar AppStorage key yet for the Update HUD toggle specifically — Phase 59's card grid may only have wired Caps Lock's key so far. Verify during research whether an Update-HUD-specific toggle key exists or needs adding (SC4 requires it to "respect the Settings grid's on/off toggle").

### Original (superseded) Update HUD attempt — historical reference only
- `.planning/milestones/v1.6-phases/40-update-available-hud-sparkle-integration/40-03-SUMMARY.md` — the click-through bug root cause and the menu-bar-dot redesign decision. Read this before designing the new HUD's tap target — the SAME `NotchWindowController.hotZone` geometry gap that killed the original attempt still exists in the codebase and will need to actually work this time (unlike the old pill badge, D-02 above no longer requires removing the dot as a fallback, which lowers the stakes if the tap target has issues again).
- `.planning/milestones/v1.6-phases/40-update-available-hud-sparkle-integration/40-UI-SPEC.md` — original (superseded) visual spec; historical reference for the "leading icon, label, trailing pill" shape language only.

### Requirements / roadmap
- `.planning/REQUIREMENTS.md:87` — CAPS-01.
- `.planning/REQUIREMENTS.md:91` — UPDATE-01.
- `.planning/ROADMAP.md:1003-1016` — Phase 60 section (Success Criteria 1-4). **Note SC3's "reskinned" wording is superseded by D-01 above — treat SC3 as "new HUD built matching the Droppy layout," not "existing code restyled."**

### Prior phase context (Settings-grid card model this phase registers against)
- `.planning/phases/59-settings-redesign/59-CONTEXT.md` — D-09/D-10 (generic options-slot on cards — likely N/A for these two simple on/off activities, no per-activity config needed), D-07 (category = System-HUDs for both).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `wings(for:)` (`NotchPillView.swift:2355`) is the direct template to copy/adapt for both new HUDs — same `wingsShape`, same leading-icon+label / `Spacer()` / trailing-element structure.
- `BatteryIndicator` (`Islet/Notch/BatteryIndicator.swift`) is the closest existing "trailing pill" component — worth checking whether its styling (not its content) can be reused/adapted for the version pill.
- `ActivitySettings.capsLockKey` and its Settings card are already wired from Phase 59 — this phase only needs to read the toggle, not create it.

### Established Patterns
- Named-rank-comment convention in `TransientQueue`/`IslandPresentation` (not raw ints) — new cases slot in between/after existing named ranks per Phase 59's D-01 discretion note.
- `ChargingActivityState` (`Islet/Notch/ChargingActivityState.swift`) shows the "separate `@Published` model alongside the untouched interaction-state machine" pattern for a transient's underlying state — likely the model shape for a `CapsLockActivityState`.
- Collapsed-only transients (Focus, OSD) fall through to the `isExpanded` branch unmodified when expanded (`IslandResolver.swift:166-168`) — the mechanism both new HUDs' resolver cases should copy.

### Integration Points
- `IslandResolver.swift`'s `resolve(...)` reducer and `promote(...)`/queue-replace logic (`:163-169`, `:369-371`) are the two places new cases must be added — mirroring exactly how `.focus`/`.osd` were added in Phases 38/39.
- `AppDelegate.swift`'s `didFindValidUpdate` callback is the single trigger point for the Update HUD — no new Sparkle wiring needed, just an additional signal alongside the existing dot-unhide call.
- Caps Lock needs a genuinely new event source (global `NSEvent` monitor) wired into whatever owns the other hardware-driven monitors (see `PowerSourceMonitor.swift` for the closest existing "OS-level monitor → published state" pattern, even though it's IOKit-based, not NSEvent-based).

</code_context>

<specifics>
## Specific Ideas

- Both HUDs should look and feel identical in structural terms to the Charging wings (same shape, same icon-left/content-right layout) — the "Droppy look" reference from ROADMAP.md's UPDATE-01 wording (leading icon, label, trailing pill) is realized by literally reusing `wings(for:)`'s structure, not inventing a new shape.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

### Reviewed Todos (not folded)
- **"Island briefly disappears during click-through"** (`2026-07-19-island-briefly-disappears-during-click-through.md`, `Islet/Notch/NotchWindowController.swift`) — reviewed, not folded into Phase 60's scope (it's an existing, separately-tracked bug in the hover→expand→move-down trace). **Flagged as a risk, not a blocker:** it lives in the same click-through/hot-zone code path (`NotchWindowController.syncClickThrough()`/`hotZone`) that the new Update HUD's tap-to-install target depends on, and is the same code path Phase 40's original pill-badge redesign fled from after hitting an unfixable variant of this class of bug. Research/planning should do a quick sanity check that the new tap target doesn't reproduce it, but a full fix stays out of scope for Phase 60.
- **"Calendar month-grid polish"** and **"Quick Action disabled state has no controller gate"** — reviewed, false-positive keyword matches (grid/state/island), not relevant to Phase 60's scope.

</deferred>

---

*Phase: 60-Caps Lock HUD + Update-Activity Restyle*
*Context gathered: 2026-07-23*
