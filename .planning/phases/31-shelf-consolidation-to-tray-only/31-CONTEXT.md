# Phase 31: Shelf Consolidation to Tray-Only - Context

**Gathered:** 2026-07-14
**Status:** Ready for planning

<domain>
## Phase Boundary

File-shelf content and the drop-triggered strip reveal exist only on the Tray tab; the additive shelf-strip-under-other-tabs behavior is removed via one shared gating function (TRAY-01).

**Key finding: this is already implemented.** Quick task `260714-3k6` (2026-07-14, commits `3c6b6fb`/`4011ca1`/`bc1e73a`/`db11d72`) shipped the `shelfStripVisible` gate ahead of this phase's formal planning, anticipating exactly this requirement. Phase 31 is therefore scoped as **verify & close only** — no new feature code, just re-proving the shipped behavior against the phase's 3 success criteria and formally closing out TRAY-01.

</domain>

<decisions>
## Implementation Decisions

### Scope
- **D-01:** Phase 31 is verify-and-close only. No new feature work — the user explicitly confirmed this after being shown that quick task 260714-3k6 already delivered the gating change.
- **D-02:** The plan's job is to (a) re-run this project's mandatory on-device hover→expand→move-down click-through trace (the CR-01 regression class — see Canonical References) against the shipped `shelfStripVisible`/`visibleContentZone()` change, since the quick task's own on-device UAT rounds tested media-overflow and empty-state clearance, not this specific click-through path; (b) add a regression test that locks `shelfStripVisible == false` / shelf-strip-hidden-on-non-Tray behavior so it can't silently regress; (c) formally mark TRAY-01 delivered in ROADMAP.md/REQUIREMENTS.md, crediting quick task 260714-3k6 as the implementation source.
- **D-03:** Do not touch `shelfStripVisible`'s implementation shape (hardcoded-`false` computed property vs. inlining vs. removal) unless verification surfaces an actual bug — this is an implementation-shape call for the researcher/planner, not something the user needs to weigh in on.

### Confirmed already satisfied (no action needed)
- **D-04:** Success criterion 1 (no shelf-strip UI on Home/Calendar/Weather) — met. `NotchPillView.shelfStripVisible` is `false`, wired into all 5 non-Tray `blobShape` call sites (homeEmptyState, calendarFullView, weatherFullView, mediaExpanded, mediaUnavailable).
- **D-05:** Success criterion 2 (Tray still shows full shelf content unchanged) — met. `trayFullView` renders the shelf directly via its own `shelfRow(_:)` path with `shelfVisible: false` passed to `blobShape` for unrelated reasons (it's a dedicated files-only presentation, not the additive strip) — confirmed untouched by the quick task.
- **D-06:** The interim UX gap where dropping a file on Home/Calendar/Weather now gives zero visible feedback (no strip reveal, no view-switch) until the user manually checks Tray is **known and intentional** — TRAY-02/03/04 (Phase 34, Quick Action destination picker) is what adds drop feedback and the auto-switch-to-Tray behavior. Not in scope for Phase 31.

### Claude's Discretion
- Whether the regression test lives in `NotchPillViewTests` or a new file, and its exact assertions — technical detail, planner/executor decide.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Prior implementation (what already shipped)
- `.planning/quick/260714-3k6-notch-island-verbreitern-und-file-shelf-/260714-3k6-SUMMARY.md` — full account of the `shelfStripVisible` gate, the `visibleContentZone()` simplification, and 3 on-device UAT rounds (none of which specifically re-ran the CR-01 click-through trace for this exact change)
- `.planning/quick/260714-3k6-notch-island-verbreitern-und-file-shelf-/260714-3k6-PLAN.md` — original plan for the quick task

### Phase definition
- `.planning/ROADMAP.md` §"Phase 31: Shelf Consolidation to Tray-Only" — goal, 3 success criteria, depends-on note re: Phase 32
- `.planning/REQUIREMENTS.md` line 18 — TRAY-01 exact wording

### Regression-class precedent (must follow)
- Project memory `cr01-clickthrough-or-defeat-gotcha` — any change to `visibleContentZone()`/click-through hit-testing needs an explicit on-device hover→expand→move-down trace; grep/build gates alone have missed this regression class before (see `NotchWindowController.swift` comments at the `visibleContentZone()` definition, which already reference CR-01 for this exact change)

### Code touched by the prior shipment (verify against, don't re-modify without cause)
- `Islet/Notch/NotchPillView.swift` — `shelfStripVisible` (line ~58), 5 `blobShape` call sites, `trayFullView`/`trayEmptyState`
- `Islet/Notch/NotchWindowController.swift` — `visibleContentZone()` (line ~962), `handleDragApproachEnd()` (drop handling, tab-agnostic — confirmed still works for D-06)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `NotchPillView.shelfStripVisible` — the single shared gate the phase goal asked for; already exists, already always `false`.
- `NotchWindowController.visibleContentZone()` — already simplified to drop the shelf-height term for non-Tray presentations; unified with the existing `switcherContentHeight` convention from Phase 28.

### Established Patterns
- Single shared boolean/property gates (e.g. `cameraClearance`, `switcherContentHeight`, now `shelfStripVisible`) as this codebase's convention for cross-cutting geometry/visibility toggles, instead of threading parameters through multiple call sites.
- CR-01 discipline: any `visibleContentZone()` change requires an explicit on-device hover→expand→move-down trace before being considered verified — codified in project memory, not just this phase.

### Integration Points
- None new — this phase verifies existing wiring, it doesn't add integration points.

</code_context>

<specifics>
## Specific Ideas

No new specific requirements — the "specific idea" here is the discovered fact that the work is already done; the plan should read like a verification/closure plan, not a build plan.

</specifics>

<deferred>
## Deferred Ideas

- Drop feedback on non-Tray tabs (haptic/toast/auto-switch when a file lands in the shelf while viewing Home/Calendar/Weather) — explicitly Phase 34 (TRAY-02/03/04, Quick Action destination picker), not Phase 31. Confirmed via ROADMAP.md dependency structure, not re-litigated in this discussion.

### Reviewed Todos (not folded)
None — `gsd-sdk query todo.match-phase 31` returned 0 matches.

</deferred>

---

*Phase: 31-shelf-consolidation-to-tray-only*
*Context gathered: 2026-07-14*
