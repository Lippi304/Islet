# Phase 34: Quick Action Destination Picker - Context

**Gathered:** 2026-07-15
**Status:** Ready for planning

<domain>
## Phase Boundary

Dropping a file onto the island (from any tab) no longer silently stages it into the shelf. Instead it shows a Droppy-style Quick Action destination picker — Drop / AirDrop / Mail — and the file only goes somewhere once the user picks one (TRAY-02, TRAY-03, TRAY-04). This is Phase 34 of the v1.5 milestone, the last phase in that still-open-in-parallel milestone. Today's silent "drop → stage into shelf" behavior at `NotchWindowController.handleDragApproachEnd()` is exactly the site this phase changes.

</domain>

<decisions>
## Implementation Decisions

### Picker takeover & trigger
- **D-01:** The picker is a full-takeover presentation — its own `IslandResolver`/`IslandPresentation` case, replacing whatever tab was showing (Home/Weather/Calendar/Tray), the same shape as the existing Charging/Device wings splash but interactive instead of auto-dismissing. Not an overlay/sheet layered on top of the current tab.
- **D-02:** The picker shows a small preview of what's being dropped (file icon + filename, or a file count + generic icon for multiple files) alongside the 3 destination buttons — reuses the existing `ShelfItemView` icon+filename convention.
- **D-03:** A multi-file drop (several files dragged in at once) gets ONE picker and ONE destination decision for the whole batch — not one picker per file. Matches how AirDrop/Mail already handle multiple attachments in a single share/compose action, and how today's silent multi-file drop-to-shelf behaves.

### Precedence & pending-drop lifecycle
- **D-04:** If a Charging/Device transient fires while the picker is open, it interrupts the picker exactly like it already interrupts every other expanded presentation today — this reuses `IslandResolver.resolve()`'s existing D-04 rule ("a transient briefly wins even over a user-expanded island"; see `IslandResolver.swift` line ~52 comment) rather than inventing a new precedence tier. Resolves the open question flagged in STATE.md Blockers/Concerns.
- **D-05:** The pending drop (the file(s) already copied in and awaiting a destination choice) survives the interruption — it's held in a small pending-decision state, and the picker auto-resumes with the same file(s) still awaiting a choice once the Charging/Device transient's `TransientQueue` drains. No data loss from an unlucky-timing charger plug-in.

### No-choice / cancel behavior
- **D-06:** The user can dismiss the picker without choosing a destination — reuses the existing hover-away grace-collapse mechanism already in `NotchWindowController` (no new cancel button/UI needed).
- **D-07:** If the picker is dismissed without a choice, the dropped file(s) are simply discarded — nothing is staged anywhere. No silent auto-default to "Drop" as a safety net; a real destination choice is required for the file to go anywhere, matching the explicit intent of the feature.

### AirDrop/Mail — non-key-panel risk & fallback
- **D-08:** Islet's `NotchPanel` is permanently non-activating/non-key (ISL-03 core value: never steals focus). If the phase's own on-device spike (flagged in STATE.md as unverified/must-spike-first) finds that the system AirDrop/Mail share sheet only appears from a momentarily key/focused window, a narrowly-scoped exception is acceptable: the panel may become key for the instant of invoking that one action (the user just explicitly clicked a button asking for exactly this), then must revert to non-activating immediately after. This is NOT a general focus-behavior change.
- **D-09:** If the spike finds no working approach at all for AirDrop and/or Mail (even with D-08's narrow exception), the phase still ships: Drop (TRAY-03) ships on schedule since it carries no such risk, and AirDrop/Mail (TRAY-04) appear as visibly disabled buttons (grayed out) rather than blocking the whole phase. TRAY-04 becomes a fast follow-up once a working approach exists, not a phase-blocking dependency.

### Claude's Discretion
- Exact visual treatment of the drop preview (icon+filename layout, exact spacing) and of the disabled-button state for AirDrop/Mail if D-09's fallback is needed.
- Exact SF Symbols for the Drop/AirDrop/Mail buttons — no specific icons were locked; match the spirit of Droppy's icon+label buttons.
- Where the pending-drop state lives in code (a new small struct/state object vs. fields on `NotchWindowController`) — implementation shape, not a product decision.
- Naming of the new `IslandPresentation`/resolver case for the picker.
- Whether the picker reuses `ShelfCoordinator.append`'s session-copy mechanism directly for the "Drop" destination, or routes through a new intermediate step — technical detail for research/planning.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase definition & requirements
- `.planning/ROADMAP.md` §"Phase 34: Quick Action Destination Picker" — goal, depends-on note re: Phase 31 (drop feedback deferred here)
- `.planning/REQUIREMENTS.md` lines 19-21 — TRAY-02, TRAY-03, TRAY-04 exact wording
- `.planning/REQUIREMENTS.md` Out of Scope table — `NSSharingServicePicker` (the generic system share picker) is explicitly ruled out: research found the Services/Sharing menu machinery likely requires a key window, so a custom 3-button SwiftUI picker calling `NSSharingService(named:).perform(withItems:)` directly is the chosen mechanism instead (this is what D-08's spike concerns). Also: Mail attachment support is Mail.app-specific — other default mail clients degrade to an unattached `mailto:`, an already-accepted limitation, not something this phase needs to solve.

### Open risks flagged ahead of this discussion (both addressed above)
- `.planning/STATE.md` §Blockers/Concerns — "Quick Action picker precedence tier (Phase 34) — whether a Charging/Device transient interrupts an open picker or queues behind it is an explicit open product decision" → resolved by D-04/D-05.
- `.planning/STATE.md` §Blockers/Concerns — "`NSSharingService`/`NSSharingServicePicker` behavior from Islet's permanently non-key `NotchPanel` is unverified in this codebase... Phase 34 must spike this in isolation before committing to the full picker plan" → the spike itself is a research/planning task, not re-litigated here; D-08/D-09 set the product-shape fallback rules for whatever the spike finds.

### Prior phase (scope handoff)
- `.planning/phases/31-shelf-consolidation-to-tray-only/31-CONTEXT.md` D-06 — "the interim UX gap where dropping a file on Home/Calendar/Weather gives zero visible feedback... is known and intentional — TRAY-02/03/04 (Phase 34) is what adds drop feedback." Confirms this phase's exact starting gap.

### Inspiration reference (thin — no runtime-picker screenshot exists)
- `.planning/research/inspiration/notes.md` §"Full Settings walkthrough" — the ONLY Droppy reference to a "Quick Action" concept is one line about a *Settings config screen* ("Quick Action layout picker with a live island preview", image `8.png`) — there is no captured screenshot of Droppy's actual runtime drop-triggered picker UI. The picker's visual shape in this phase is this discussion's own design (D-01/D-02), not a traced reference.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `NotchWindowController.handleDragApproachEnd()` (`Islet/Notch/NotchWindowController.swift` ~line 931) — the exact site that currently unconditionally stages dropped files via `shelfCoordinator.append(item)`; this phase branches this into showing the picker instead of auto-staging.
- `ShelfCoordinator.append(_:)` / `ShelfFileStore.makeSessionCopy(of:id:)` (`Islet/Shelf/ShelfCoordinator.swift`) — already does the exact file-copy-in mechanism the "Drop" destination needs; reuse verbatim, don't reinvent.
- `IslandResolver.resolve()` / `ActiveTransient` / `IslandPresentation` (`Islet/Notch/IslandResolver.swift`) — the single pure arbiter; the picker's new case slots in here, and D-04 means no new precedence logic is needed (transients already win unconditionally over any `isExpanded` branch case).
- `showsSwitcherRow(for:)` (`IslandResolver.swift` ~line 66) — the shared single-source-of-truth for which presentations show the switcher row; the picker case needs an explicit decision here too (does the switcher stay visible during the picker, or is it hidden like Charging/Device wings are?) — left to planning since it wasn't asked directly, but note the precedent that transient wings (Charging/Device) do NOT show the switcher row today.
- Phase 21's drag-pin pattern (best-effort `.leftMouseUp` release monitor + a 20s safety-net fallback, `Islet/Notch/NotchWindowController.swift`) — precedent for "hold state open across an async user decision"; relevant if research finds the pending-drop state (D-05) needs a similar safety-net timeout to avoid a permanently-stuck picker in some edge case (e.g. app losing event delivery) — not required by any decision above, but worth researching against.

### Established Patterns
- "Single pure `IslandResolver` as the ONE arbiter for all activity priority" (Phase 6, COORD-01) — the picker's precedence (D-04) rides this existing pattern rather than adding a parallel one.
- CR-01 discipline: any change to `visibleContentZone()`/click-through hit-testing needs an explicit on-device hover→expand→move-down trace before being considered verified — the picker is a NEW presentation case, so its own click-through geometry is new surface, not just a re-touch of existing code; treat it as needing this trace like every prior new-presentation phase.
- "Isolate the fragile/uncertain thing behind its own seam" (`NowPlayingMonitor`, `WeatherService` protocol precedent) — the AirDrop/Mail invocation (genuinely uncertain, per D-08) should go through its own narrow seam so a future macOS change or spike finding doesn't ripple through the picker's UI code.

### Integration Points
- `Islet/Notch/NotchWindowController.swift` — `handleDragApproachEnd()` (branch point), `visibleContentZone()` (new case's click-through geometry), `positionAndShow` (panel-frame reservation for the new case)
- `Islet/Notch/NotchPillView.swift` — new view for the picker (3 buttons + preview), following the existing per-presentation view pattern (`weatherFullContent`, `trayFullView`, etc.)
- `Islet/Notch/IslandResolver.swift` — new `IslandPresentation` case + its `resolve()` branch + `showsSwitcherRow()` entry
- `Islet/Shelf/ShelfCoordinator.swift` — "Drop" destination routes through here unchanged

</code_context>

<specifics>
## Specific Ideas

- No specific visual reference exists for the runtime picker itself (see canonical_refs — Droppy's only "Quick Action" mention is a Settings config screenshot, not the actual drop-triggered UI). The 3-button Drop/AirDrop/Mail shape comes from `.planning/PROJECT.md`'s v1.5 milestone goal text, not a traced image.
- User confirmed (this discussion) that Islet's hard "never steal focus" rule (ISL-03) can flex narrowly and only for the exact instant AirDrop/Mail is invoked by explicit user click — not a general softening of that rule.

</specifics>

<deferred>
## Deferred Ideas

None new — discussion stayed within phase scope (picker UI/trigger, precedence, cancel behavior, and the AirDrop/Mail fallback plan are all direct implementation decisions for TRAY-02/03/04).

Already-known deferrals (from REQUIREMENTS.md v2 candidates, not re-litigated here):
- "Open Tray After Drop" convenience setting for the picker's "Drop" outcome — Droppy-precedented, explicitly not in this milestone's ask.

### Reviewed Todos (not folded)
- "Tray panel oversized vertically, shrink to fit content" (`2026-07-14-tray-panel-oversized-vertically-shrink-to-fit-content.md`) — matched Phase 34 by keyword ("tray") but was already resolved and shipped by Phase 32 (per `32-CONTEXT.md`'s Folded Todos section); the stale pending-todo file was deleted during this discussion as housekeeping, not folded into Phase 34 scope.

</deferred>

---

*Phase: 34-quick-action-destination-picker*
*Context gathered: 2026-07-15*
