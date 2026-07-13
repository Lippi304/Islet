# Phase 29: NotchShape Flare - Context

**Gathered:** 2026-07-13
**Status:** Ready for planning

<domain>
## Phase Boundary

Every expanded presentation (Home, Tray, Calendar, Weather, Charging/Device wings) gains a new outward-flaring top edge that widens into the screen bezel, threaded through the shared `NotchShape`/`blobShape()`/`wingsShape()` rendering pipeline so it applies automatically wherever those helpers are used. The collapsed/idle pill (`collapsedIsland`) stays pixel-identical to today — flush/straight into the edge, no shape/size/position regression. The flare is a fixed design-language detail (no user-facing toggle) and must animate cleanly as part of the existing collapse↔expand spring morph (SHAPE-01).

</domain>

<decisions>
## Implementation Decisions

### Flare look
- **D-01 (REVISED, 2026-07-13, during Task 3 on-device UAT):** ~~The flare is a subtle widen~~ — superseded. On-device testing of the subtle version ("a touch more pronounced than the 6pt corner curve") read as imperceptible/no visible change. User provided a concrete reference (Droppy's shelf widget, screenshot during Phase 29 execution) and confirmed the flare should match it: a **pronounced concave flare** — the top edge stays NARROW (roughly the physical notch-cutout width) for a short flat run, then sweeps outward via a concave curve down to the presentation's full width, converging into the existing side walls. This is the "dramatic trumpet/bell-shaped flourish" the original D-01 explicitly rejected — that rejection is overridden by this decision.
- **D-02 [informational]:** Exact pt values / exact curve shape are Claude's/executor's discretion, tuned on-device against the Droppy reference — matches this project's established convention (wings sizing in Phase 3/4, bottom-corner radius in Phase 25, spring curves in Phase 2/25 were all tuned this way after an initial implementation pass). The quad-curve-only constraint (29-PATTERNS.md) should still be attempted first; only move to a cubic `addCurve` if a single quad curve genuinely cannot produce a convincing concave-then-converging sweep.

### Coverage — media wings/toast excluded
- **D-03 (LOCKED):** The Now-Playing media wings / song-change-toast glance (`mediaWingsOrToast`, `NotchPillView.swift` ~line 1234) does **NOT** get the flare — it stays flush like the collapsed pill. Flare applies only to the ROADMAP-named set: Home, Tray, Calendar, Weather (all via `blobShape()`) and Charging/Device wings (via `wingsShape()`).
- **D-04:** This is structurally clean to implement — `mediaWingsOrToast` already makes its own inline `NotchShape(...)` call (not routed through `wingsShape()`), so excluding it requires no special-casing; only `blobShape()` and `wingsShape()` need the new flare parameter.

### Flare width behavior
- **D-05 (REVISED, 2026-07-13, alongside D-01):** The "same absolute value, not proportionally scaled" spirit carries over, but the fixed constant moves from an added widen-margin to the **narrow top-band width** itself (matching the Droppy reference: a fixed, narrow flat-top run, identical in every presentation, that then flares out to each presentation's own already-different full width — Home/Tray/Calendar/Weather's wide blob vs. the narrower Charging/Device wings). The flare-out naturally differs in how far it has to sweep per presentation (since it converges into each presentation's own existing width), but the one tunable constant (the narrow top-band width) stays fixed and identical everywhere, preserving D-05's original consistency intent.

### Claude's Discretion
- Exact geometry/math for the widen (e.g., whether `NotchShape` needs a new animatable parameter alongside `topCornerRadius`/`bottomCornerRadius`, or whether the existing quad-curve technique can be extended) — technical implementation, not discussed with the user.
- Exact pt value(s) for the flare widen amount and how it's tuned on-device (see D-02).

### Post-D-01/D-05 implementation detour and final confirmation (2026-07-13, later in the same Task 3 session)
- An early implementation attempt at D-01/D-05 (narrow top band → monotonic concave sweep to full width) recessed the WIDE body away from the true screen edge, which read as "not at the screen edge at all" and was reverted in favor of a "shoulder bulge" design (flush FULL-WIDTH top edge, with a decorative bump that swings outward past the rect and then back inward to rejoin the base width).
- On-device testing of the shoulder-bulge design (after several geometry/rendering-pipeline bugs were found and fixed) read as **"eine Kugel"** (a ball/knob) — a round protrusion, not the flowing, continuous funnel the Droppy reference actually shows. Re-examining the Droppy reference confirms it: a narrow flat band at the very top (matching the physical notch), curving continuously OUTWARD AND DOWNWARD in one direction (never reversing) until it merges into the wide body below — exactly D-01/D-05's ORIGINAL description, not the shoulder-bulge detour.
- **Final confirmation:** the user initially accepted a "wide body recessed, narrow band flush" trade-off, but on seeing it on-device (screenshot showing an apparent gap near the camera), clarified the geometry is the OPPOSITE of what was built. **CORRECTED, final direction (2026-07-13, same session, after on-device review):** the WIDE SIDES (left/right of the physical camera, where the display glass has no notch cutout) stay FLUSH with the true screen edge, exactly like the pre-Phase-29 shape always has. Only a NARROW band directly over/around the physical camera (matching the camera's own footprint — this is the same region the collapsed pill already occupies) dips DOWN slightly, like a shallow notch/dimple, with smooth rounded transitions connecting the flush sides to the dipped center. This is the reverse of D-01/D-05's literal wording above ("top edge stays NARROW... then sweeps outward... to full width") — read D-01/D-05 as superseded by this correction: it is the SIDES that are the "flush/full-width" part, and the CENTER (narrow, camera-width) that recedes, not the other way around. Rationale: the wide sides sit over plain display glass with no hardware obstruction, so they can legitimately reach the true top edge; only the camera region is physically constrained and benefits from a soft, integrated dip rather than fighting the hardware notch with a flat top.
- The rendering-pipeline bugs found/fixed during the shoulder-bulge detour (SwiftUI content-root frame needing to widen for horizontal overflow, panel-frame reservation) are ORTHOGONAL fixes and were reverted once the horizontal-overflow shoulder-bulge design was abandoned — this final "flush sides / notched center" shape also does not need horizontal overflow past the base rect (the notch is an inward dip, not an outward bulge), so those widening mechanisms stay reverted.

### FINAL CORRECTION (2026-07-14) — the whole "centered notch" detour is superseded
- After the centered-notch design (narrow dip around the camera) still read as "nothing changes" across several width/depth tuning rounds, the user provided a tight crop of the actual reference detail: a big, smooth, simple quarter-circle radius at the shape's outer top corners — nothing to do with a notch/dip in the center at all.
- **Confirmed final answer: SHAPE-01 is simply a much LARGER `topCornerRadius` value at the outer top corners of the covered presentations — no new geometry, no notch, no bulge, no separate `topFlareWidth` parameter needed.** `NotchShape` already has a `topCornerRadius: CGFloat` stored property used unconditionally by both the collapsed pill and every expanded presentation (currently `6` everywhere). D-03/D-04 (media wings/toast and collapsed pill excluded from the flare) fall out automatically: leave `collapsedIsland` and `mediaWingsOrToast`'s existing `topCornerRadius: 6` call-site arguments untouched, and only INCREASE the `topCornerRadius` argument passed at the `blobShape()`/`wingsShape()` call sites (Home/Tray/Calendar/Weather/Charging/Device wings) to something visually generous (e.g. `24`–`32pt`) — a big, smooth quarter-circle, not a subtle tweak.
- This supersedes D-01/D-02/D-05 and every geometry variant built during this phase (monotonic funnel, shoulder bulge, centered notch) — `NotchShape.swift`'s `path(in:)` should be reverted to its exact pre-Phase-29 form (no `topFlareWidth` property, no flared branch, no guard) — the ONLY change SHAPE-01 needs is which `topCornerRadius` value gets passed in at 2 call sites in `NotchPillView.swift`.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements & roadmap
- `.planning/REQUIREMENTS.md` — SHAPE-01 definition; also notes "User-configurable flare depth/amount for SHAPE-01 — fixed design language for now" (no Settings toggle, confirmed by D-01/D-02).
- `.planning/ROADMAP.md` §"Phase 29: NotchShape Flare" — goal, success criteria, and the explicit list of covered presentations (Home, Tray, Calendar, Weather, Charging/Device wings).
- `.planning/PROJECT.md` §"Current Milestone: v1.5" — SHAPE-01 target-features bullet.

### Prior related decisions
- `.planning/phases/25-visual-material-theming-redesign/25-CONTEXT.md` D-09 — confirms the EXISTING top-corner quad-curve technique (`topCornerRadius`) already reads as a "flowing merge into the screen edge" and was left unchanged in Phase 25; Phase 29 builds a distinct, more pronounced mechanism on top of/alongside it, not a replacement.
- `.planning/phases/27-settings-sidebar-redesign/27-CONTEXT.md` D-06 — lists the shell-chrome fill sites (`collapsedIsland`, `blobShape`, `wingsShape`, `mediaWingsOrToast`) that any prior shape/material change had to touch consistently; same site list is relevant here for scoping which functions the flare parameter threads through.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Islet/Notch/NotchShape.swift` — the single `Shape` struct (quad-curve top/bottom corners) every collapsed/expanded/wings state renders through via `matchedGeometryEffect(id: "island")`. `topCornerRadius`/`bottomCornerRadius` are plain `CGFloat` stored properties, so SwiftUI's `Shape` animation already interpolates them across the collapse↔expand spring — any new flare parameter should follow the same pattern to get smooth-morph animation "for free" (satisfies Success Criterion #3).

### Established Patterns
- All expanded presentations call `blobShape(topCornerRadius: 6, bottomCornerRadius: 32, ...)` (`NotchPillView.swift` lines ~440, 474, 658, 724, 772, 1492, 1561) — one shared private helper, so adding a flare parameter there covers Home/Tray/Calendar/Weather in one place.
- Charging/Device wings both go through the shared `wingsShape(content:)` helper (`NotchPillView.swift` ~line 1173, `NotchShape(topCornerRadius: 6, bottomCornerRadius: 6)`) — confirmed via comment at line 1182 that both `wings(for:)` (charging) and `deviceWings(for:)` route through it.
- `mediaWingsOrToast` (`NotchPillView.swift` ~line 1234-1253) makes its own standalone `NotchShape(topCornerRadius: 6, bottomCornerRadius: toast != nil ? 16 : 6)` call — does NOT go through `wingsShape()`. This is why D-03/D-04's exclusion is structurally free.
- The collapsed pill (`collapsedIsland`, ~line 409-423) calls plain `NotchShape()` (default `topCornerRadius: 6, bottomCornerRadius: 14`) with no flare parameter passed — must stay untouched per Success Criterion #2.

### Integration Points
- `blobShape()` (private func, `NotchPillView.swift` ~line 1074) and `wingsShape()` (~line 1173) are the two functions that need a new flare parameter threaded into their `NotchShape(...)` construction. `NotchShape.swift` itself needs the new animatable property added alongside `topCornerRadius`/`bottomCornerRadius`.

</code_context>

<specifics>
## Specific Ideas

No screenshot/reference image was provided for the exact flare curve — the user described the desired direction in words only ("subtle widen, a touch more than today's existing corner curve"). No specific pt values or reference app were named; on-device visual tuning is expected to finalize the exact look (see D-02).

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope. (User-configurable flare depth was already explicitly out-of-scope per REQUIREMENTS.md before this discussion started.)

</deferred>

---

*Phase: 29-notchshape-flare*
*Context gathered: 2026-07-13*
