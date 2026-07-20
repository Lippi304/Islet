# Phase 42: Dual-Activity Display - Context

**Gathered:** 2026-07-18
**Status:** Ready for planning

<domain>
## Phase Boundary

When two top-priority ambient activities are live simultaneously — today, the only proven pairing is Calendar Countdown (Phase 41) + Now-Playing — the collapsed island shows a main pill (primary) plus a small round secondary bubble instead of one activity strictly suppressing the other. This extends `IslandResolver` additively (an ordered ranking table + a `secondary:` field), does NOT touch the expanded views, does NOT change any existing `ActiveTransient`/transient behavior beyond "a transient still wins over both slots at once," and does NOT generalize beyond the two-activity case (a third concurrent slot is explicitly out of scope per REQUIREMENTS.md).

</domain>

<decisions>
## Implementation Decisions

### Primary/Secondary assignment
- **D-01:** Calendar Countdown is always primary (the main pill) when both Countdown and Now-Playing are live — this continues Phase 41's D-01 ranking (Countdown > Now-Playing), just changes what happens to the loser: instead of going fully invisible, it becomes the secondary.
- **D-02:** Phase 41's D-01 ("Countdown suppresses Now-Playing entirely") is SUPERSEDED, not kept as a fallback: whenever both are live, Now-Playing is always visible as the secondary round bubble. There is no scenario in this phase where Now-Playing goes fully invisible while actually playing and Countdown is active.
- **D-03:** The ranking is expressed as a small ordered table (not an if/else chain) inside the resolver, but scoped to exactly the 2 entries that exist today (Countdown, Now-Playing). No speculative 3rd/4th ambient activity is designed for — extend the table later if/when a new ambient activity is added (YAGNI).
- **D-04:** When only one of the two ambient activities is live, behavior is byte-for-byte unchanged from today — single activity renders as the normal primary pill, `secondary` is `nil`, no empty bubble ever renders.

### Secondary bubble — visual design
- **D-05:** The secondary bubble is a ROUND circle positioned to the right of the primary pill — this is the general shape for ANY secondary activity, not something Now-Playing-specific.
- **D-06:** For Now-Playing specifically, the bubble shows the real album-cover artwork, circularly cropped (not a generic icon). Inherits the project's existing artwork-latency handling (art fills in asynchronously once available, per PROJECT.md's known NowPlaying artwork-latency note).
- **D-07:** The bubble is smaller than the primary pill (~24-28pt, vs. the existing 32pt wing/pill height) — visually reads as clearly secondary/subordinate.
- **D-08:** Small visible gap between the primary pill and the secondary bubble (not touching/overlapping) — two distinct shapes, not one fused object.
- **D-09:** The secondary bubble morphs in/out via its own `matchedGeometryEffect` (its own distinct id/namespace, separate from the primary pill's existing shared `"island"` id) — springs in/out consistently with the rest of the project's morph-everything animation language, not a plain fade.

### Transient interaction (Charging/Device/Focus/OSD)
- **D-10:** A standing transient (Charging, Device, Focus, or Volume/Brightness OSD) suppresses BOTH the primary pill and the secondary bubble at once — mirrors the existing `resolve()` switch-on-`activeTransient` structure exactly (it already returns a single `IslandPresentation` case early, before the ambient branch is ever reached), so this is the natural behavior, not new code, and is explicitly identical across all 4 transient types — no per-transient special case.
- **D-11:** When the transient ends and the resolver falls back to the ambient branch, the primary pill reappears first, and the secondary bubble morphs in with a slight delay afterward (a staggered, two-step reveal) rather than both appearing in the same animation frame.

### Tap/click on the secondary bubble
- **D-12:** Tapping the secondary bubble expands to that activity's own view — e.g. tapping the Now-Playing secondary circle while Countdown is primary opens Home/the media view, exactly as tapping Now-Playing as primary would today. The bubble is a real, independent tap target, not inert.
  - **SUPERSEDED (2026-07-19, Plan 42-04 Task 3 on-device UAT):** Tapping the bubble now toggles play/pause directly instead of expanding — an explicit live user decision made during on-device verification, not a bug or scope drift. Full rationale in `42-04-SUMMARY.md`.
- **D-13:** No hover-reveal or highlight on the secondary bubble — stays consistent with Phase 41 D-08 (Countdown pill has no hover-reveal either); hovering the bubble does nothing extra.
  - **SUPERSEDED (2026-07-19, Plan 42-04 Task 3 on-device UAT):** Hovering the bubble now darkens it and reveals a play/pause SF Symbol glyph reflecting current playback state — an explicit live user decision made during on-device verification. Full rationale in `42-04-SUMMARY.md`.

### Claude's Discretion
- Exact pixel values for the bubble diameter (within the ~24-28pt range), the gap width (D-08), and the stagger delay duration (D-11) are implementation details for planning/research to resolve against real on-device measurement, mirroring the project's established "tune small geometry constants on-device" precedent (e.g. Phase 41's countdown wing width fix).
- Whether the new ranking table lives as a literal `[(ActivityKind, ActivityKind)]`-style structure or a small dedicated enum/function is a research/planning implementation choice — the requirement is only that it reads as an explicit ordered table, not scattered conditionals (ROADMAP Success Criterion 2).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase scope & requirements
- `.planning/ROADMAP.md` §"Phase 42: Dual-Activity Display" — the 4 success criteria this phase must satisfy, and its explicit dependency on Phase 41
- `.planning/REQUIREMENTS.md` — DUAL-01 (the requirement itself), plus the "Out of Scope" note explicitly capping this at exactly two concurrent activities (no 3+ slot model)

### Prior phase this one builds on (Countdown as the proven single-winner input)
- `.planning/phases/41-calendar-countdown-hud/41-CONTEXT.md` — D-01 (the ranking rule this phase supersedes per D-02 above), D-04 (mm:ss live-refresh mechanism, relevant to how the secondary bubble's own content might need similar TimelineView-gated refresh if it ever shows live-updating content), D-09 (back-to-back event re-arm — the countdown's own lifecycle is unaffected by this phase)
- `.planning/research/PITFALLS.md` Pitfall 5/6 — the dual-activity risk this phase exists to resolve, and the "one pure arbiter" invariant (every new HUD type routes through `IslandResolver`, no view-layer bypass) that D-10 must respect

### Resolver architecture (what this phase extends)
- `Islet/Notch/IslandResolver.swift` — the single pure arbiter. Current shape: `switch activeTransient` returns early for any standing transient (lines 130-138, directly supports D-10 for free); the ambient branch (lines 166-174) currently picks exactly ONE of Countdown/Now-Playing via `if let countdown ... else ambient` — this is the exact branch that needs the new `secondary:` output and ranking table (D-01/D-02/D-03).
- `Islet/Notch/IslandResolver.swift:61-77` — `IslandPresentation` enum; per ROADMAP's explicit constraint, this phase must NOT reshape this enum — the secondary activity rides on an additive new field alongside it, not a new case merged into it.

### View/animation architecture (matchedGeometryEffect precedent)
- `Islet/Notch/NotchPillView.swift:198` — the single shared `@Namespace private var ns`, and every existing shape (`collapsedIsland`, `blobShape`, `wingsShape`) carries the SAME `matchedGeometryEffect(id: "island", in: ns)` — today only ONE shape renders at a time. D-09 requires the secondary bubble to be the FIRST case where two shapes render simultaneously, each with its own distinct id (likely still `in: ns`, but a new `id:` — planner's call whether a second `@Namespace` is also needed, per ROADMAP's "distinct namespaces" wording).
- `Islet/Notch/NotchPillView.swift:1947-1993` (`wingsShape`) — the closest existing precedent for a secondary, independently-sized shape flanking the main content (its `leftWidth`/`rightWidth` independent-flank pattern); not directly reusable (it's one shape, not two), but establishes the project's convention for asymmetric secondary geometry.
- `Islet/Notch/NotchPillView.swift:716-757` (`presentationSwitch`) — confirms every `IslandPresentation` case renders through ONE exhaustive switch returning ONE view; the secondary bubble must be composed alongside this switch's output (e.g. in `body`'s `ZStack`), not as a new case inside it — consistent with ROADMAP's "every existing IslandPresentation switch site otherwise unchanged" success criterion.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `NowPlayingPresentation`'s existing artwork field — reused as-is for the secondary bubble's album-cover content (D-06), no new artwork-fetch path needed.
- `wingsShape`'s independent left/right flank sizing pattern — informs how the secondary bubble might size independently of the primary pill without one `.frame` fighting the other.

### Established Patterns
- "One pure arbiter" discipline (PITFALLS.md Pitfall 6) — every new HUD type routes through `IslandResolver`; this phase's `secondary:` field must be resolver-owned output, not a view-layer computation.
- Single shared `@Namespace`/`matchedGeometryEffect(id: "island")` convention — currently assumes exactly one visible shape at a time; this phase is the first to break that assumption, so whatever shape it takes should be documented clearly for future phases that might add more overlay-style elements.
- `resolve()`'s early-return switch on `activeTransient` (D-10's free win) — any new ambient-tier output must be added only in the branch reached when `activeTransient == nil`, matching every prior ambient-tier phase's (17, 18, 41) integration point.

### Integration Points
- `IslandResolver.swift`'s ambient branch (post-`isExpanded`, pre-`nowPlayingLaunchGate`) — where the D-01/D-02/D-03 ranking-with-secondary-output logic replaces today's `if let countdown ... else ambient` single-winner check.
- `NotchPillView.swift`'s `body`/`presentationSwitch` boundary — where the secondary bubble view gets composed alongside (not inside) the existing exhaustive switch.

</code_context>

<specifics>
## Specific Ideas

- The secondary bubble is explicitly described as "diese extra runde Pille... rechts davon als Kreis" (this extra round pill... to the right, as a circle) — a small round circle to the right of the main pill, not a second rectangular wing or badge shape.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope. (3+ concurrent activities and generalizing beyond Countdown+Music are already correctly out of scope per REQUIREMENTS.md, not proposed as in-scope here.)

### Reviewed Todos (not folded)
None — no pending todos matched this phase's scope (`cross_reference_todos` returned 0 matches).

</deferred>

---

*Phase: 42-Dual-Activity Display*
*Context gathered: 2026-07-18*
