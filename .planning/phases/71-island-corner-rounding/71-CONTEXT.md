# Phase 71: Island Corner Rounding - Context

**Gathered:** 2026-07-30
**Status:** Ready for planning

<domain>
## Phase Boundary

Every wing-state HUD that routes through `wingsShape()` in `NotchPillView.swift` (Charging, Device, Now Playing glance, OSD, Timer, Meeting, etc.) gets a noticeably more rounded silhouette, closer to a pill than today's more rectangular corners. A new DEBUG-only live-tuning nudge for the wing corner radius is added, mirroring the existing Wing Tuner mechanism. The idle/collapsed plain pill shape is explicitly unchanged — this phase touches `wingsShape()` only, never `blobShape()`/`collapsedIsland`.

</domain>

<decisions>
## Implementation Decisions

### Target Roundness
- **D-01:** Both `topCornerRadius` and `bottomCornerRadius` (currently 12/6 in `wingsShape()`'s `NotchShape` call) increase, but the top/bottom asymmetry stays — not a fully uniform "true pill" (which would push both toward ~16, half the 32pt wing height). User explicitly rejected the uniform-pill option.
- **D-02:** Exact starting numbers are the planner's/executor's call, not baked in during discussion — refine via the new DEBUG tuner (D-03) on real hardware, consistent with how every other wing constant in this codebase was tuned (see the many "Round N: baked in from on-device tuning" comments in `NotchPillView.swift`).

### Tuner Axis Structure
- **D-03:** The new SHAPE-03 tuner is **one combined "Corner Radius" `@AppStorage` axis**, not two independent Top/Bottom axes. It shifts both `topCornerRadius` and `bottomCornerRadius` by the same delta, preserving whatever fixed asymmetry ratio the planner bakes in (D-01/D-02). Matches the seed's "a new nudge axis" (singular) framing.
- **D-04:** Wire it exactly like the existing Wing Tuner: `#if DEBUG`-gated `@AppStorage` key in `ActivitySettings.swift`, always-0-in-Release computed read point in `NotchPillView.swift` (mirrors `wingLeadingNudge`/`wingMarginNudge` etc.), NSMenu buttons + Reset + Print actions in `AppDelegate.swift`.

### Nudge Granularity
- **D-05:** The new Corner Radius nudge uses **two step sizes: ±1 and ±5** — a fine step for precision plus a coarse jump for fast large adjustments, mirroring the existing Margin axis's multi-tier button convention (as opposed to Leading/Trailing's single ±2 step). Given the corner radius's small usable range (~6-16pt total), do not add a ±10/±20 tier — that would overshoot immediately.

### Claude's Discretion
- Exact final `topCornerRadius`/`bottomCornerRadius` starting values (D-02).
- Exact menu item ordering/labels for the new tuner buttons, following the existing Wing Tuner menu's visual convention.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Original idea / reference
- `.planning/seeds/island-corner-rounding.md` — original idea, reference screenshot description (bottom-left/top-right corner emphasis), rank 2 of 5 ideas

### Shape geometry
- `Islet/Notch/NotchShape.swift` — the shape being tuned; `topCornerRadius`/`bottomCornerRadius` params, asymmetric-by-design (small top, larger bottom on the idle notch; wings currently invert that ratio at 12/6)
- `Islet/Notch/NotchPillView.swift` `wingsShape()` (~line 3034) — the single call site that instantiates `NotchShape(topCornerRadius: 12, bottomCornerRadius: 6)` for every wing state; every wing HUD routes through this one function

### Wing Tuner mechanism (pattern to mirror for SHAPE-03)
- `Islet/Notch/NotchPillView.swift` (~lines 178-218) — existing `wingLeadingNudge`/`wingTrailingNudge`/`wingMarginNudge`/`wingGapNudge` `@AppStorage`-backed computed properties, `#if DEBUG`/`#else return 0` pattern
- `Islet/ActivitySettings.swift` (~lines 109-115) — existing Wing Tuner `@AppStorage` key constants (`debugWingLeadingNudgeKey`, `debugWingMarginNudgeKey`, etc.)
- `Islet/AppDelegate.swift` (~lines 515-622) — existing Wing Tuner NSMenu wiring: per-axis ± step buttons (Leading ±2; Margin ±5/±10/±20), Reset, and Print Wing Tuner Values actions

No other external specs — requirements fully captured in `.planning/REQUIREMENTS.md` (SHAPE-02, SHAPE-03) and ROADMAP.md's Phase 71 entry.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `NotchShape` (Islet/Notch/NotchShape.swift) — already parameterized by `topCornerRadius`/`bottomCornerRadius`, no shape-code changes needed, only the values passed at the `wingsShape()` call site
- Wing Tuner `@AppStorage`/NSMenu pattern — directly reusable template for the new Corner Radius axis, same file locations, same three-file wiring (ActivitySettings key → NotchPillView read point → AppDelegate menu)

### Established Patterns
- All wing-constant tuning in this codebase follows a "propose a value → live-tune on hardware via a DEBUG menu → bake in the on-device-confirmed number with a `// Quick task ... Round N: baked in from on-device tuning` comment" convention. This phase's SHAPE-03 tuner should be built and used the same way for its own SHAPE-02 target values.
- `NotchShape`'s corner radii are always symmetric left/right by construction (one shared `topCornerRadius` covers both top corners, one shared `bottomCornerRadius` covers both bottom corners) — the reference screenshot's "bottom-left" and "top-right" callouts are consistent with this; there is no independent 4-corner control, nor was one requested.

### Integration Points
- `wingsShape()` is the single, universal entry point — every current and future wing HUD (Charging, Device, Now Playing glance, OSD, Timer, Meeting) gets the new radius automatically with zero per-wing changes.
- `blobShape()` (idle/collapsed pill, separate call sites like the switcher row's `topCornerRadius: 24, bottomCornerRadius: 32`) is explicitly out of scope — do not touch.

</code_context>

<specifics>
## Specific Ideas

Reference screenshot (2026-07-29, described in the seed, not re-fetched): a marketing shot from another Dynamic-Island-style app ("Gorgeous volume and brightness HUDs") with a red arrow at the bottom-left corner and a red rectangle at the top-right corner of an OSD-style wing bar — both ends of the wing's outer silhouette should read as noticeably more rounded than today, though not pushed all the way to a uniform full pill (see D-01).

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 71-Island Corner Rounding*
*Context gathered: 2026-07-30*
