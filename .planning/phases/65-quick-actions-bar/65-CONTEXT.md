# Phase 65: Quick Actions Bar - Context

**Gathered:** 2026-07-26
**Status:** Ready for planning

<domain>
## Phase Boundary

A configurable row of up to ~8 instant-fire actions (mic mute, display sleep now, dark/light mode toggle, screen lock, Do Not Disturb toggle, caffeinate/keep-awake toggle, empty Trash, launch app/open URL) is enabled and ordered in Settings, then fires immediately from the notch with no further expansion beyond the bar itself.

**Requirements (locked via REQUIREMENTS.md, not re-discussed here):**
- **QACTION-01:** Settings lets the user enable/reorder a Quick Actions bar from the fixed catalog.
- **QACTION-02:** Tapping an enabled action performs it immediately without expanding the notch any further than the action bar itself.
- **QACTION-03:** The Do Not Disturb/Focus action is documented as best-effort (no stable public macOS API) — a failure is visible to the user, not silently swallowed.

**Depends on Phase 63:** reuses the `MicMuteController` Meeting-HUD already built — do not build the CoreAudio mute helper twice (locked, Phase 63 D-04).

</domain>

<decisions>
## Implementation Decisions

### Bar placement
- **D-01:** Quick Actions is a new switcher-tab presentation, joining the existing catalog of assignable slot types (Home/Weather/Calendar/Tray) rather than becoming a dedicated always-visible strip or being merged into Home. It becomes a 5th option in Phase 52's existing per-slot dropdown catalog — the switcher row's 4-slot layout math (`switcherRowHeight`, slot count) is unchanged; this is purely a catalog addition, not a structural resize. Resolves the reserved "relationship unclear, rank TBD" comment in `IslandResolver.swift`.

### Settings config UI
- **D-02:** The bar's own internal action slots are configured via per-slot dropdown pickers — the same UI mechanism Phase 52 (SWITCH-03/04) already built for the switcher row (`orderedSlotIcons`, independent `@AppStorage` per slot). One dropdown per bar position, each choosing a catalog action or "none." Not a drag-reorder checklist — no such component exists in this codebase today, and the dropdown pattern is already proven.

### Bar capacity
- **D-03:** The bar is fixed at ~8 total slots, matching the roadmap's literal "~8-action row." The multiple independent launch slots (D-05) share this same fixed pool — configuring more launchers means giving up other catalog actions, the bar does not grow past 8 or become scrollable.

### Tap feedback
- **D-04:** A brief icon pulse/flash animation confirms every tap, uniformly across all actions — not left to per-action discretion. Actions with their own visible state (mute icon, dark-mode icon) may additionally swap their icon, but the pulse confirms the tap registered even for one-shot actions (empty Trash, caffeinate) that have no other visible effect on the bar itself.

### Launch action
- **D-05:** "Launch app/open URL" is not a single fixed catalog entry — the user can configure multiple independent launch slots, each bound to its own app or URL. These launch slots draw from the same fixed 8-slot pool (D-03), not an unbounded addition.

### Claude's Discretion
- Exact SF Symbols/icons for each catalog action.
- Exact pulse/flash animation timing and visual style (D-04).
- DND/Focus action's exact failure-state visual treatment (QACTION-03 requires visibility, not silence, but the specific look — icon strike-through, brief error color, disabled state — is unspecified; not discussed in this session, resolve during UI-spec).
- Naming of the new `IslandPresentation`/switcher-slot case for Quick Actions.
- Technical mechanism for each non-mute action (display sleep, dark mode, screen lock, DND, caffeinate, empty Trash, launch app/URL) — research/planning task, only the mic-mute mechanism is locked (reuses `MicMuteController`).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase definition & requirements
- `.planning/ROADMAP.md` §"Phase 65: Quick Actions Bar" — goal, success criteria, depends-on note re: Phase 63
- `.planning/REQUIREMENTS.md` lines 106-110 — QACTION-01, QACTION-02, QACTION-03 exact wording

### Prior phase precedent (architecture this phase depends on)
- `.planning/phases/63-meeting-hud/63-CONTEXT.md` D-02, D-04 — the `MicMuteController` this phase's mic-mute action reuses verbatim; the system-wide CoreAudio mute mechanism (not any per-app API).
- `.planning/phases/59-settings-redesign/59-CONTEXT.md` D-07, D-09 — the "Produktivität" category card reserved for this phase, and the generic per-card options-slot affordance this phase's Settings UI fills in.

### Codebase (exact integration points, verified by reading the live file)
- `Islet/Notch/IslandResolver.swift` (Phase 59's Resolver-Priority Reference Table comment block) — the exact "Quick Actions bar (Phase 65) — relationship unclear, possibly an always-visible strip rather than a presentation case — rank TBD" line this phase's D-01 resolves.
- `Islet/Notch/NotchPillView.swift:193-199` (`orderedSlotIcons`) and `:2531-2553` (switcher slot dropdown wiring, Phase 52 SWITCH-03/04) — the shared slot-assignment mechanism D-01 (switcher catalog) and D-02 (bar's internal slots) both extend/reuse.
- `Islet/Notch/MicMuteController.swift` — existing shared mute primitive (built Phase 63), reused verbatim, no new mute helper.
- `Islet/ActivitySettings.swift` — `@AppStorage` key namespace + `migrateLegacyAccentIfNeeded()` presence-check pattern (Phase 59), reusable for wiring new default-OFF keys per action slot.

No external specs beyond the above — requirements fully captured in decisions above.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `MicMuteController` (`Islet/Notch/MicMuteController.swift`) — built in Phase 63, reused verbatim for the mic-mute action.
- `orderedSlotIcons(...)` + per-slot `@AppStorage` dropdown mechanism (`NotchPillView.swift` ~193-199, ~2531-2553, Phase 52) — directly reused for both the switcher-tab catalog entry (D-01) and the bar's own internal 8-slot configuration (D-02).
- `ActivitySettings`'s `@AppStorage` namespace and `migrateLegacyAccentIfNeeded()` presence-check pattern (Phase 59) — reusable for safely wiring new default-OFF settings keys per slot.

### Established Patterns
- Fixed catalog + per-slot dropdown (not drag-reorder) is this codebase's established Settings config pattern (Phase 52) — this phase follows it rather than introducing a new UI paradigm.
- "Isolate the fragile/uncertain thing behind its own seam" (`NowPlayingMonitor`, `MeetingMonitor` precedent) — the DND/Focus toggle (QACTION-03, no stable public API) is the one catalog action with genuine platform-API uncertainty and should get its own isolated helper, mirroring that discipline.

### Integration Points
- `Islet/Notch/IslandResolver.swift` — new switcher-slot case (naming TBD) alongside the existing `selectedView` cases (Home/Weather/Calendar/Tray); resolves the reserved Phase 65 rank-TBD comment.
- `Islet/Notch/NotchPillView.swift` — new expanded view rendering the 8-slot action row, following the existing per-presentation view pattern (`weatherFullContent`, `trayFullView`, etc.); `orderedSlotIcons` extended with the new catalog entry.
- Settings — the Phase 59 "Produktivität" card's options-slot (D-09) surfaces this phase's per-slot dropdowns (D-02) plus the switcher-catalog dropdown entry (D-01).
- New per-action helpers as needed: a DND/Focus toggle helper (isolated seam, no public API — research must confirm best-effort mechanism); display sleep, dark/light mode, screen lock, caffeinate, empty Trash likely resolve to more straightforward system calls, to be confirmed in research.

</code_context>

<specifics>
## Specific Ideas

No specific visual references supplied — the action catalog list itself comes verbatim from `.planning/ROADMAP.md`'s Phase 65 success criteria, not a traced reference image.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

### Reviewed Todos (not folded)
- "Quick Action disabled state has no controller gate" (`2026-07-19-quick-action-disabled-state-has-no-controller-gate.md`) — matched Phase 65 by keyword ("quick action") but is actually about Phase 34's unrelated drag-drop AirDrop/Mail destination picker (`handleDragApproachEnd()`'s dead `enabled:` gate), not this phase's Settings-configured action bar. Left unfolded; still open against Phase 34's code if ever revisited.

</deferred>

---

*Phase: 65-Quick Actions Bar*
*Context gathered: 2026-07-26*
