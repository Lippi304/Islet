# Phase 24: Drag-In - Context

**Gathered:** 2026-07-11
**Updated:** 2026-07-11 (drop-interception architecture gap, post-Task-3 UAT)
**Status:** Ready for planning

<domain>
## Phase Boundary

Users can drag a file, multiple files, or a folder from Finder (or any other app) onto the **collapsed** island pill — it auto-expands and each item lands in the shelf strip. This is the THIRD attempt at SHELF-01/02: Phase 22 was aborted twice on-device (a Mission-Control top-edge trigger blocking drop completion, then an empirical runtime mismatch where `draggingEntered` never fired reliably without `draggingUpdated` — contradicting Apple's own documented contract). Rather than debug `NSDraggingDestination` further, the user pivoted to a full shell rewrite (Phase 23, now complete and reproven) and this phase retries drag-in via a completely different mechanism: a global-monitor `DragApproachDetector` pattern (mirroring the existing `dragReleaseMonitor`/`mouseMonitor` `NSEvent.addGlobalMonitorForEvents` idiom already in `NotchWindowController`), replacing `NSDraggingDestination` entirely.

Out of scope for this phase: drag-out (Phase 21, already shipped), the shelf data model (Phase 19, already shipped), folder spring-loading/auto-navigating into dropped folder contents (a dropped folder is always one shelf item), and accepting drops while the island is already expanded (explicitly reconsidered and re-locked as out-of-scope below — deferred as a future idea, not built here).

</domain>

<update_20260711>
## Update: Drop-Interception Architecture Gap (post-Task-3 UAT)

Plan 24-02's Tasks 1-2 landed and were on-device UAT'd successfully: the `DragApproachDetector` global-monitor mechanism reliably detects drags and lands items in the shelf (two on-device fixes merged: `dragLandingMargin` correction, `recheckDragAcceptRegion` self-disarm fix — commits `e589150`/`2bebf84`). Task 3's on-device UAT then surfaced a real architecture gap, not a small bug:

Because the panel is deliberately click-through (`ignoresMouseEvents`, no `NSDraggingDestination` — D-05's pivot away from Phase 22's twice-unexplained `draggingEntered` failure), the actual OS-level drag session is never intercepted by Islet at all. It falls through to whatever window is visually underneath the drop point — in practice, the Finder Desktop — which performs its own default same-volume MOVE operation. Confirmed on-device: the user's original file gets relocated to the Desktop as an unwanted side effect, even though the shelf correctly receives its own session copy in parallel.

This update resolves how to fix that, captured as D-10 through D-15 below.
</update_20260711>

<decisions>
## Implementation Decisions

### Approach sensitivity / feel
- **D-01:** The island reacts wide/early — as soon as a drag enters a generously-sized top-of-screen accept zone, well before reaching the pill. Mirrors Phase 22's D-02b widened-zone philosophy and stays maximally forgiving against the Mission-Control edge trigger that killed drop completion in Phase 22's first attempt.
- **D-02:** The drag-accept zone reuses Phase 22's exact geometry: the existing reserved `expandedZone` (`panelFrame.insetBy(dx: -hotZonePadding, dy: -hotZonePadding)`, already computed in `positionAndShow()`) plus a landing margin below the physical top screen edge (D-02c). This geometry was never actually invalidated by Phase 22's failures — only the AppKit delivery mechanism (`NSDraggingDestination`) was. No redesign needed; the new `DragApproachDetector` targets the same accept region.
- **D-03:** Hot/targeted feedback stays single-stage: reuse the existing hover bounce/scale spring animation as-is (Phase 22 D-03/D-06). No new visual effect, no two-stage approach→accept escalation. Keeps this phase focused on proving the detection mechanism, not adding new UI polish.
- **D-04:** The island auto-expands immediately once a drag enters the widened accept zone, before the drop completes — shelf becomes visible while still dragging (Phase 22 D-01, reaffirmed, directly consistent with D-01 above).

### Validation strategy (given 2 prior on-device failures)
- **D-05:** Build an isolated on-device spike FIRST — mirroring Phase 22-01's approach — to verify the `DragApproachDetector` global-monitor mechanism actually fires reliably, BEFORE building the full accept/shelf-landing logic on top of it. Do not build the complete feature in one pass.
- **D-06:** Budget up to 2 on-device validation rounds (one implementation attempt + one fix-and-retry round) before treating the mechanism itself as a blocker again — matches what Phase 22 actually did before the user pivoted architecturally. Do not debug indefinitely past this cap.

### Reliability bar / fallback plan
- **D-07:** "Works reliably across repeated on-device trials" (ROADMAP Success Criteria #3) means: the common case must work consistently, and an occasional missed drop is acceptable IF it fails silently — no crash, no frozen hover/click-through state, no regression to ordinary pointer behavior. Consistent with the codebase's existing silent-no-op precedent (Phase 19 D-02, Phase 20 D-04, Phase 21 D-02). Not zero-defect, but never a broken state.
- **D-08:** If, after the capped 2 validation rounds (D-06), the mechanism is STILL not reliable — STOP execution and return to `/gsd:discuss-phase 24` with findings, rather than shipping something flaky or debugging indefinitely. Same pattern as Phase 22's abort-and-pivot.

### Scope boundary (reaffirmed from Phase 22)
- **D-09 (LOCKED, reconsidered and re-confirmed):** Drag-in is accepted ONLY while the island is collapsed, exactly as ROADMAP Success Criteria #1 states ("onto the collapsed island pill"). Accepting drops while the island is already expanded (Now Playing, idle glance, open shelf) was explicitly raised and REJECTED as in-scope for this phase — it's a new capability beyond SHELF-01/02's wording. Captured as a deferred idea (see below), not built here.

### Drop-interception fix (architecture gap, added post-Task-3 UAT, 2026-07-11)
- **D-10:** Pursue **CGEventTap** first as the mechanism to stop the real OS drag session from reaching whatever's underneath (currently: Finder Desktop's default same-volume move). A tap's callback can swallow/modify an event before it propagates further (e.g., return NULL for the terminating `.leftMouseUp` so Finder's Desktop view never sees the drop complete). Rejected as the first choice: re-attempting a scoped `NSDraggingDestination` (the exact technique that silently failed to fire twice in Phase 22, root cause never identified — retrying without new insight is low-confidence) and the move-back mitigation (kept in reserve as the fallback, see D-14, not the primary approach).
- **D-11:** Request the new **Input Monitoring** permission lazily, at first real use — the first time the user actually drags a file toward the collapsed island — not upfront during app launch. Islet's onboarding flow (Phase 26) doesn't exist yet, so there's no natural home for an upfront pre-explanation screen this phase; matches the project's general lazy-permission-ask preference. `.planning/research/inspiration/notes.md` (Droppy reference) shows the target pre-explanation pattern (one-line reason before the system prompt) to mirror once Phase 26 exists, but that polish is explicitly Phase 26's problem, not this phase's.
- **D-12:** If the user denies (or never grants) Input Monitoring, drag-in silently falls back to today's behavior: the shelf still receives the file copy (already works), but the original file may still get relocated by the OS — no worse than the current known gap, no error dialog. Consistent with the codebase's existing silent-no-op precedent (D-07).
- **D-13:** CGEventTap is itself a brand-new, unproven-in-this-codebase mechanism — same risk category `DragApproachDetector` was in before this phase started. Cap validation at **2 on-device rounds** (mirrors D-05/D-06: one implementation attempt + one fix-and-retry round). If still unreliable after the cap, stop and apply D-14's fallback rather than a fourth architecture pivot or indefinite debugging (same discipline as D-08).
- **D-14:** If CGEventTap is abandoned after the capped rounds, ship with the **move-back mitigation** as the fallback: detect that the OS performed its default same-volume move and move the file back to its original location. Imperfect (heuristic, some edge-case risk — name collisions, timing races) but closes the data-loss risk without triggering a fourth full architecture pivot.
- **D-15:** The tap swallows the terminating drag event for **every** drag landing in the accept zone, regardless of source app or volume — not scoped to only the specific same-volume-move risk. Detecting volume/operation-type ahead of the drop completing is fragile and adds a new failure surface for marginal precision gain; simplest and most consistent behavior wins here.

### Claude's Discretion
- Exact AppKit/Foundation mechanism for the `DragApproachDetector` (which `NSEvent` types to monitor, how to read the systemwide drag pasteboard to obtain file URLs without `NSDraggingDestination`) — not discussed with the user; research/planner resolves this against the documented Phase 22 failure (empirical `draggingEntered`/`draggingUpdated` mismatch) and the existing `dragReleaseMonitor` global-monitor idiom already in `NotchWindowController`.
- How "an active drag session" is detected to gate the widened accept zone — must route through the SAME single arbiter that already owns `ignoresMouseEvents`/`syncClickThrough()` per the architecture risk flagged in Phase 22's context (project memory `cr01-clickthrough-or-defeat-gotcha`) — NOT a parallel flag.
- Multi-file/folder drag ordering into the shelf — follows Phase 19 D-06 (append in drop order), same as every other shelf-add path. Kept as Claude's discretion per this discussion (not re-litigated).
- Behavior when a drag carries non-file content (no file URL) — treat as a no-drop/reject, consistent with the shelf's file-only model.
- Behavior when drag-in is attempted while a Charging/Device splash is actively suppressing the shelf (SHELF-09) — default to the same silent-no-op precedent already established elsewhere unless research surfaces a reason to special-case it.
- Exact margin value for the landing-below-top-edge accept condition (D-02c inherited from Phase 22) — measure against the reserved footprint's existing height.
- Exact CGEventTap event mask/tap location (`.cgSessionEventTap` vs `.cgAnnotatedSessionEventTap`, which event types to intercept beyond the terminating mouse-up) and how the Input Monitoring permission-check/prompt call is wired — not discussed with the user; research must validate whether swallowing a raw event actually prevents the Window Server's own drag-session completion (the STATE.md blocker note flags this as genuinely uncertain, not assumed to "just work"), same isolated-spike-first discipline as D-05 applied to this new mechanism.
- Exact detection method for the D-14 move-back fallback (only needed if D-13's cap is hit) — e.g., comparing the original source path's existence post-drop vs. searching the likely destination — deferred until/unless the fallback is actually triggered, not designed preemptively.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements source
- `.planning/REQUIREMENTS.md` — SHELF-01 ("User can drag a file, multiple files, or a folder onto the collapsed island — it auto-expands and the item(s) land in a shelf strip below the expanded view"), SHELF-02 ("Drop target shows 'hot'/targeted visual feedback while a file is being dragged over, before release")
- `.planning/ROADMAP.md` §"Phase 24: Drag-In" — Goal, Depends on (Phase 23 — hard dependency), 4 Success Criteria, explicit `DragApproachDetector` naming
- `.planning/ROADMAP.md` §"Phase 22: Drag-In" (superseded) — full abort record, kept for traceability

### Why this phase exists — the two prior failures (MUST read before designing the detector)
- `.planning/STATE.md` "Blockers/Concerns" — the canonical abort record: `NotchPanel.draggingEntered` never fired on-device twice despite a confirmed-working spike using the same technique; root cause never fully resolved before the user pivoted. Explicitly warns the `DragApproachDetector` pattern is itself UNPROVEN in this codebase and needs its own isolated on-device validation (this discussion's D-05/D-06 operationalize that warning).
- `.planning/phases/22-drag-in/22-01-SUMMARY.md` — the first failure: A1 (drag delivery survives click-through) CONFIRMED, but the drop never completed because the drag path crosses macOS's top-edge Mission Control trigger before reaching the tiny hot-zone. Root cause of D-01/D-02 above (wide/early zone, reused geometry).
- `.planning/phases/22-drag-in/22-CONTEXT.md` — full record of the D-01 through D-07 decisions this phase carries forward (auto-expand timing, widened accept zone, hot feedback reuse, collapsed-only scope) plus the architecture-risk note about routing drag-state through the single `syncClickThrough()` arbiter.
- `.planning/phases/23-shell-parity-rewrite/23-CONTEXT.md` — confirms the residual Phase-22 `NSDraggingDestination` scaffold was deleted entirely (D-01 in that phase) — Phase 24 builds the `DragApproachDetector` from scratch against the reproven shell, no old scaffold to reconcile.
- `.planning/phases/21-drag-out/21-CONTEXT.md` — the CR-01 gotcha (project memory `cr01-clickthrough-or-defeat-gotcha`): `syncClickThrough()`'s expanded branch must stay a pure `visibleContentZone()` check, never OR'd with `pointerInZone` — this exact regression class must not be reintroduced by any new drag-session-active state.

### Why D-10 through D-15 exist — the Task-3 architecture gap (MUST read before designing the interception fix)
- `.planning/STATE.md` "Blockers/Concerns" (`[Phase 24, NEW 2026-07-11]` entry) — the canonical record of the Task 3 UAT finding: `DragApproachDetector` works, but the click-through panel never intercepts the real OS drag, so Finder's Desktop performs its own same-volume move on the original file. This entry is also the source of the CGEventTap lead (D-10).
- `.planning/phases/24-drag-in/24-02-PLAN.md` — Task 3, paused mid-checkpoint (not approved, not skipped) — the concrete task this discussion unblocks.
- `.planning/research/inspiration/notes.md` (line 10) — Droppy's permission pre-explanation screen (Accessibility, Screen Recording, Input Monitoring) — the reference pattern for D-11's eventual onboarding-quality permission ask (Phase 26 scope), and evidence Droppy likely uses the same CGEventTap-class mechanism.

No other external specs — requirements fully captured in decisions above.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Islet/Notch/DragDropSupport.swift` — Phase 22's pure, AppKit-glue-free seams, MERGED and reusable as-is: `fileURLs(from pasteboard: NSPasteboard) -> [URL]` (reduces a drop pasteboard to file URLs, folder URLs returned as-is per Out of Scope) and `shouldAcceptDrop(isExpanded: Bool, urls: [URL]) -> Bool` (D-09's collapsed-only + non-empty-payload gate). Neither function has a spatial/screen-coordinate component — the `DragApproachDetector`'s geometry gate is a separate concern.
- `Islet/Notch/NotchWindowController.swift` `dragReleaseMonitor` (Phase 21, ~line 219, 1278-1296) — an existing `NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp])` global monitor pattern used for the drag-OUT pin-open mechanism. This is the direct architectural precedent/template for the new `DragApproachDetector`'s global-monitor approach (likely `.leftMouseDragged`/`.leftMouseUp` monitoring) — same idiom, new direction (drag-in detection vs. drag-out release detection).
- `Islet/Notch/NotchWindowController.swift` `syncClickThrough()` — the SINGLE arbiter for `ignoresMouseEvents`. Confirmed present and unchanged post-Phase-23 rewrite. Any new drag-session-active signal for the widened accept zone must route through here.
- `Islet/Notch/NotchWindowController.swift` `positionAndShow()` — already computes `expandedZone = panelFrame.insetBy(dx: -hotZonePadding, dy: -hotZonePadding)`, the exact rect D-02 reuses as the drag-accept region.
- `Islet/Notch/NotchPanel.swift` — CONFIRMED zero drag code post-Phase-23 (D-01 of that phase deleted the scaffold entirely). The `DragApproachDetector` starts from a clean slate here.
- `Islet/Shelf/ShelfCoordinator.swift` — `append`, the Phase 19 add path the drop handler calls into.

### Established Patterns
- **Global-monitor idiom already proven in this codebase** — `dragReleaseMonitor` (Phase 21) and `mouseMonitor` (`.mouseMoved`, core hover detection) both use `NSEvent.addGlobalMonitorForEvents`, armed/removed at session start/end with a safety-net `DispatchWorkItem` fallback (`dragPinSafetyNetWorkItem`, 20s cap). The `DragApproachDetector` should likely follow the same arm/disarm/safety-net shape.
- **Single arbiter, no parallel state machine** (`syncClickThrough()`) — the single most important invariant, reconfirmed intact after the Phase 23 rewrite. Any drag-approach state must be one more input into this existing decision point.
- **Silent no-op for edge cases** — the established default across Phase 19/20/21 (missing file, empty shelf, duplicate add) that this phase's D-07 reliability bar explicitly extends to occasional missed drops.

### Integration Points
- `NotchWindowController` — the natural home for the new `DragApproachDetector` (parallel to how `dragReleaseMonitor` already lives there), wired into `syncClickThrough()` and the existing `expandedZone` geometry.

### Post-Task-3 addition: no existing analog for CGEventTap
- Unlike `DragApproachDetector` (which had `dragReleaseMonitor`/`mouseMonitor` as direct same-file precedent — see `24-PATTERNS.md`), **CGEventTap has zero precedent anywhere in this codebase.** This is a genuinely new mechanism (`CGEvent.tapCreate`, a new Info.plist Input Monitoring usage description, likely a new small owning type rather than forcing it into `NotchWindowController`) and needs its own research/pattern pass before planning — `24-PATTERNS.md`'s "no new files" conclusion was scoped to the original detection+shelf-landing work and does NOT extend to this fix.

</code_context>

<specifics>
## Specific Ideas

No specific visual references given for this phase — functional behavior (wide/early reaction, reused accept-zone geometry, single-stage hover-bounce feedback, isolated-spike-first sequencing, graceful-degrade reliability bar) is fully captured in the decisions above. The user's framing throughout was risk-management given the two prior failures, not new visual/UX invention.

</specifics>

<deferred>
## Deferred Ideas

- **Accepting drag-in while the island is already expanded** — explicitly raised during discussion and rejected as in-scope for Phase 24 (D-09). ROADMAP/REQUIREMENTS scope this phase to collapsed-only. If wanted, this is a new capability for a future phase/requirement.

</deferred>

---

*Phase: 24-Drag-In*
*Context gathered: 2026-07-11*
