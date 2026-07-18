# Phase 37: Drop-Session Summary Chip - Context

**Gathered:** 2026-07-16
**Status:** Ready for planning

<domain>
## Phase Boundary

Two-part phase: first add an explicit "shelf session" boundary concept to `ShelfViewState`/`ShelfCoordinator` (distinct from today's `isVisible = !items.isEmpty` check), then build a one-shot "N files saved" chip that briefly appears once the island collapses after a Tray session that had at least one drop — reusing Phase 18's song-change-toast pattern (a fading text row under the collapsed wings, its own short auto-dismiss timer, same suppression gate shape). Pure additive feature — no changes to `DeviceCoordinator`, `BluetoothMonitor`, IOKit power monitor, or the drop-in/Quick-Action-picker mechanics from Phase 34.

</domain>

<decisions>
## Implementation Decisions

### Session Boundary (new concept — HUD-07's core prerequisite)
- **D-01:** "Tray closed" = the whole expanded island collapsing back to the idle pill (hover-away grace-collapse or click-away) while Tray was the selected tab — NOT merely switching to another tab (Home/Calendar/Weather) while staying expanded. Matches the literal ROADMAP wording; Tray visually disappears along with everything else at this moment.
- **D-02:** The session boundary resets immediately at the moment of D-01's trigger (island collapse), not on the next new drop. Any file dropped after that point belongs to a fresh session regardless of whether the chip is still showing from the previous one.

### File Count Semantics
- **D-03:** The chip's "N" is a **gross** count — every successful `ShelfCoordinator.append()` call during the session — not a net/current-shelf-state count. If the user drops 3 files then deletes 1 before closing, the chip still says "3 files saved." Reflects "files WERE saved at some point," independent of `clear()`/individual deletes during the same session.

### Chip Visual Design
- **D-04:** Reuse Phase 18's song-change-toast shape and mechanics **verbatim** — the same fading text row under the collapsed wings (`mediaWingsOrToast`-style), same `toastExtraHeight`/`NotchShape` growth mechanics, same independent ~2s auto-dismiss timer. No new visual language for this chip.
- **D-05:** Text uses proper English pluralization: "1 file saved" for N=1, "N files saved" for N≥2 — not a flat always-plural string.

### Suppression & Interaction Rules
- **D-06:** Identical suppression gate shape to Phase 18's `songChangeToastGate` (`activeTransient == nil && !isExpanded && enabled`) — if a Charging/Device transient is active at the moment the chip would fire, the transient wins and the chip is skipped entirely (no queueing). Since the chip fires exactly when `isExpanded` is about to flip false (D-01), this is a direct structural reuse, not just a similar rule.
- **D-07:** If the user re-expands the island (e.g. hovers again) while the chip is still showing, the chip dismisses immediately and the island expands normally — same as today's D-02 Charging/Device-interrupts-toast precedent (`NotchWindowController.swift:703-709`): cancel the dismiss timer and clear the chip's one-shot `@Published` field the instant `isExpanded` flips true.

### Claude's Discretion
- Where the new session-boundary state lives in code (a field on `ShelfCoordinator`, a new small struct, or logic folded into `ShelfViewState`) — implementation shape, not a product decision.
- Exact mechanism for tracking the gross append count per session (e.g. a running counter reset at D-02's boundary vs. a session-start snapshot diffed against total lifetime appends) — planner's call.
- Naming of the new state/field and of the chip's own `@Published` type (mirroring `TrackToast`).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase definition & requirements
- `.planning/ROADMAP.md` §"Phase 37: Drop-Session Summary Chip" (lines 658-669) — Goal and Success Criteria.
- `.planning/REQUIREMENTS.md` line 57 (HUD-07) — requirement text, notes the missing session-boundary concept explicitly.

### Song-change toast precedent (Phase 18) — the pattern this phase reuses
- `Islet/Notch/IslandResolver.swift:160-174` — `songChangeToastGate(activeTransient:isExpanded:toastEnabled:)`, the exact suppression-gate shape D-06 reuses.
- `Islet/Notch/NotchPillView.swift:2021-2083` — `mediaWingsOrToast(_:)` / `toastTextRow(_:)`, the exact rendering code D-04 reuses verbatim (fading text row, `toastExtraHeight` growth).
- `Islet/Notch/NotchWindowController.swift:211-221, 703-709` — `toastDismissWorkItem`, `songToastDuration` (2.0s), and the interrupt-cancels-toast logic D-07 mirrors.
- `Islet/Notch/NowPlayingState.swift:26-33` — `songChangeToast: TrackToast?`, the one-shot `@Published` field pattern the new chip's own field should follow.
- `Islet/Notch/NowPlayingPresentation.swift:80-100` — `TrackToast` struct + `songChangeToastContent(...)` pure-seam content-derivation function, a template for the new chip's own pure seam.

### Shelf code this phase modifies
- `Islet/Shelf/ShelfViewState.swift` — `isVisible` (line 21, `!items.isEmpty`) is the ONE existing visibility check; the new session-boundary concept is additive, does NOT replace this. Comment at lines 10-14 documents the CR-01 click-through regression class — any new state here must not disturb `isVisible`'s existing single-source-of-truth role.
- `Islet/Shelf/ShelfCoordinator.swift` — `append(_:)` (line 29), `remove(id:)` (line 41), `clear()` (line 51) — the exact mutation points D-03's gross session count must observe.
- `Islet/Notch/NotchWindowController.swift:1373` — `handleSwitcherSelect(_:)`, where tab switches happen (relevant context for D-01, though D-01 chose island-collapse over tab-switch as the trigger).
- `Islet/Notch/IslandResolver.swift:65, 121-123` — `.trayExpanded` case and `selectedView == .tray` resolution — confirms Tray is its own dedicated presentation, not an additive strip.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- Phase 18's entire toast stack (`songChangeToastGate`, `mediaWingsOrToast`, `TrackToast`, `toastDismissWorkItem`) is the direct structural template for this phase's chip — D-04/D-06/D-07 all point back to specific existing code to mirror, not new invention.
- `ShelfCoordinator.append/remove/clear` are already the single, tested mutation points (Phase 19 pure-logic-first precedent) — the new session-count logic hooks into these, doesn't duplicate them.

### Established Patterns
- One-shot `@Published` field cleared by its own dismiss timer or an interrupt (Phase 18 precedent, `songChangeToast: TrackToast?`) — this project's established shape for "brief transient text overlay," reused as-is for the new chip.
- Pure-seam content-derivation functions (`songChangeToastContent`) kept separate from the stateful controller — same discipline expected for whatever function decides the new chip's count/text.

### Integration Points
- `NotchWindowController` is where `isExpanded` transitions to false are already observed (grace-collapse timer, click-away) — the chip's trigger (D-01) hooks in here, same layer as the existing toast interrupt logic.
- No `IslandResolver`/`TransientQueue` case needed — ROADMAP Success Criterion #4 and D-04/D-06 both confirm this stays a one-shot orthogonal `@Published` toast, mirroring Phase 18 exactly, not a new resolver-arbitrated activity.

</code_context>

<specifics>
## Specific Ideas

- No visual reference image was supplied for this chip — it's a direct mechanical reuse of Phase 18's already-shipped, already-approved toast design (D-04), not a new look to design from scratch.
- The phrase "N files saved" comes directly from ROADMAP.md's own Success Criterion #2 wording — locked, not open to rephrasing.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope (session boundary, count semantics, chip visuals, and suppression rules are all direct implementation decisions for HUD-07).

### Reviewed Todos (not folded)
None — no pending todos matched this phase's scope during discussion (`todo.match-phase` returned 0 matches).

</deferred>

---

*Phase: 37-Drop-Session Summary Chip*
*Context gathered: 2026-07-16*
</code_context>
