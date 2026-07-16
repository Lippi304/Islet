# Phase 35: Liquid Glass Material - Context

**Gathered:** 2026-07-15
**Revised:** 2026-07-16 — on-device UAT rejected the first implementation (35-05 checkpoint: "Ne gefällt mir überhaupt nicht... nicht jetzt einfach Grau sein ohne dass man durchgucken kann", see `35-UAT.md`). This revision pivots D-02 from an opaque-gradient-base to a real translucent material base. D-01/D-03/D-04/D-05/D-06/D-07/D-08/D-09 are unaffected and still apply as originally decided below.
**Status:** Ready for replanning

<domain>
## Phase Boundary

The shared background material — collapsed pill, expanded island, and all activity wings (Charging, Device, Now Playing) — is replaced by a "Liquid Glass" look (glossier, blurred/frosted, not glass-clear), plugging into the existing `ActivitySettings.MaterialStyle`/`islandFill` seam. User-approved scope extension: the Settings window background also adopts a calmer variant of the same look (see Decisions → Material Scope).

**Hard prerequisite, NOT part of this phase's own plans:** the expand-animation regression (diagonal morph + screen-edge bounce, reproduces on every expand) must be fixed via a standalone `/gsd-debug` session before `/gsd-plan-phase 35` runs. Phase 35 planning should assume a working baseline morph animation exists.

</domain>

<decisions>
## Implementation Decisions

### Reference Technique
- **D-01:** Port a SwiftUI `.distortionEffect(_:maxSampleOffset:)` Metal shader (macOS 14+ API — no deployment-target bump needed from today's 15.0 floor) that replicates the user-supplied React Bits `<GlassSurface />` reference component's `feDisplacementMap` technique: per-pixel edge warp using a generated displacement map (bright near edges, dark center) PLUS independently-offset R/G/B channel displacement passes producing chromatic-aberration edge fringing. Chosen over both the simplified no-distortion fallback and Apple's native `.glassEffect()`/`NSGlassEffectView` (macOS 26+, would require a deployment-target bump and exclude pre-26 users). **Unchanged by the 2026-07-16 revision** — the warp math itself is not the problem, see D-10/D-11.
- **D-02 [SUPERSEDED 2026-07-16 by D-10/D-11]:** ~~The existing Phase 25 black-top → transparent-bottom vertical gradient (`NotchPillView.gradientMaterial`) stays as the visual base/direction. The new shader distorts that composited fill — it is an addition, not a replacement of the gradient direction.~~ On-device UAT showed this reads as a flat opaque grey/black panel with no visible transparency. Root cause (confirmed by code inspection during the revision discussion, not a separate bug — see D-10 note): `islandFill` returns the same 100%-opaque `gradientMaterial` for `.liquidGlass` as for `.gradient`, and the overlay's own base warp pass (`NotchPillView.swift:293`) fills with that identical opaque black gradient again — distorting a uniform opaque color is visually indistinguishable from not distorting it. The R/G/B fringe passes are only 10% opacity screen-blended on top of that opaque black, and the final white wash is 4-7% opacity — none of that is visible against a fully opaque base. Replaced by D-10/D-11 below.
- **D-03:** The distortion shader applies ONLY to the background fill layer (same seam as today's `islandFill`) — foreground content (album art, equalizer bars, text, icons) stays crisp/undistorted. Reduces risk of unreadable content. **Unchanged by the 2026-07-16 revision.**
- **D-04:** Distortion strength scales with view-state size: subtle/reduced in the small collapsed pill (where it would barely be visible anyway), full strength in the expanded island. **Unchanged by the 2026-07-16 revision.**

### Material Redesign (Post-UAT Pivot — 2026-07-16)
User rejected the first on-device build (`35-UAT.md` Test 1): *"Ne gefällt mir überhaupt nicht. Es sollte den glassigen look haben mit transparenz am rand und nicht jetzt einfach Grau sein ohne dass man durchgucken kann"* — it should have the glassy look with transparency at the edge, not just be flat grey with nothing to see through. User supplied a reference screenshot (Droppy's onboarding panel, saved to `reference-transparency-target.png`) showing the pattern they want: panel center stays dark/readable, but the desktop wallpaper visibly bleeds through right at the rounded edges.

- **D-10:** Replace the opaque `gradientMaterial` base with a real, live-blurring macOS material (SwiftUI `Material`, e.g. `.ultraThinMaterial`/`.regularMaterial`, backed by `NSVisualEffectView` under the hood) for the `.liquidGlass` case only — `.gradient`/`.solidBlack` keep their existing opaque fills untouched. `NotchPanel` (`Islet/Notch/NotchPanel.swift:17-18`) is already `isOpaque = false` / `backgroundColor = .clear`, so the real desktop content behind the panel is available to blur through — no window-level change needed, this is purely a SwiftUI fill-layer change. The existing `.distortionEffect()` shader stack (D-01) then warps this translucent material layer instead of an opaque one, so the edge warp becomes visually apparent as an actual refraction of what's behind, not a distortion of a flat color.
- **D-11:** Material opacity/blur is edge-weighted, not uniform: more transparent/blurred right at the rounded edge (matching the reference screenshot), progressively more opaque/dark toward the center (keeps text/album-art/icons legible per D-03). Reuse the shader's existing `edgeDist`/border-band falloff (`LiquidGlassShader.metal` Step 3-5, `smoothstep(0.0, edgeSize + blurWidth, edgeDist)`) as the same driver for this opacity ramp, rather than inventing a second independent falloff curve — one source of truth for "how close to the edge is this pixel."
- **Retuning note:** the existing tuned constants in `LiquidGlassParameters` (`backgroundOpacity: 0.04/0.07`, R/G/B fringe `.opacity(0.10)`) were calibrated against an opaque black base and are very likely too subtle now that the base itself is translucent — treat them as stale starting points, not locked values. Same "Claude's Discretion — on-device tuning" grant as D-01 applies to re-tuning these against the new material base.

### Material Selection Model
- **D-05:** Add `.liquidGlass` as a new third case on `ActivitySettings.MaterialStyle` (alongside existing `.gradient`/`.solidBlack`) — NOT a replacement. Users who prefer the existing Gradient or Solid Black keep those options in Settings.
- **D-06:** `.liquidGlass` becomes the new `@AppStorage` default (`materialStyleKey`) for both new and existing users. Settings still allow switching back to Gradient/Solid Black at any time.

### Expand Animation Regression (prerequisite — tracked outside Phase 35's plans)
- **D-07 [informational]:** User-reported bug (2026-07-15): the island no longer morphs smoothly out of the camera/notch position — it animates diagonally from top-left toward bottom-right and bounces off the screen edge. Confirmed by user: reproduces on **every single expand** (consistent, not intermittent) — points toward a structural cause (likely frame/panel positioning in `NotchWindowController.positionAndShow`/`notchFrame`), not a race condition. Suspected to have crept in during Phase 29 (NotchShape Flare), Phase 32 (Tray Widening), or Phase 33 (Weather) — all three touched panel/geometry code recently. Root cause not yet identified. **Resolved 2026-07-15 via standalone `/gsd-debug` session** (see `.planning/debug/resolved/island-expand-diagonal-bounce.md`) — root cause was `.frame()` placed before `.matchedGeometryEffect()` at all 4 island fill sites; fix confirmed on-device ("Ja geht wieder."). Not tracked by any Phase 35 plan by design — this decision documents a prerequisite fixed outside this phase's scope, not a Phase 35 deliverable.
- **Process decision:** fix this via a standalone `/gsd-debug` session BEFORE `/gsd-plan-phase 35` runs, not as a task inside Phase 35's own plan. Rationale (user-selected): a clean, correctly-morphing baseline is needed before layering a new visual material on top — otherwise it's unclear whether any later bug traces to the old regression or the new shader.

### Material Scope
- **D-08 (scope extension beyond ROADMAP.md's literal Success Criterion #1 wording):** Liquid Glass material scope for this phase extends beyond "pill + expanded island + 3 activity wings" to also include the **Settings window background** — user explicitly requested this addition during discussion. Downstream planner should treat this as an approved, intentional extension, not an omission to flag back. Onboarding flow is explicitly NOT included (not requested).
- **D-09:** The Settings window gets only the calmer half of the technique — `.ultraThinMaterial`-style blur/frost + the same gradient direction + a rim-light stroke highlight — WITHOUT the distortion shader. Rationale: Settings shows text/forms where per-pixel warping is a readability risk; the island shell is where the full effect belongs.

### Claude's Discretion
- Exact numeric tuning of shader parameters (displacement scale, per-channel offset delta, edge-band width, blur-before-displace) — the reference component's web-scale defaults (200-400pt) don't map directly to Islet's much smaller pill/wing dimensions; these need on-device tuning during execution, following the *relationships* documented in `reference-GlassSurface.md`, not literal pixel values.
- Whether the collapsed-pill distortion scaling (D-04) is implemented as a continuous size-driven parameter or a simple binary on/off switch between states — planner's call based on what's cheapest to build correctly.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Reference material (user-supplied)
- `.planning/phases/35-liquid-glass-material/reference-GlassSurface.md` — full React Bits `<GlassSurface />` source (JS + CSS) with SwiftUI porting notes worked out during discussion. **Read this before writing any shader code** — it documents the exact displacement-map/channel-offset technique and which parts map to which SwiftUI APIs. The warp math (D-01) is still correct; only the fill layer it's applied to changes (D-10/D-11).
- `.planning/phases/35-liquid-glass-material/reference-transparency-target.png` — user-supplied screenshot (Droppy onboarding) showing the target transparency distribution: dark/readable center, desktop visibly bleeding through at the rounded edges. Grounds D-11's edge-weighted opacity decision.

### Roadmap & requirements
- `.planning/ROADMAP.md` §"Phase 35: Liquid Glass Material" (lines 581-592) — Success Criteria; note Success Criterion #1's scope is extended by D-08 above (Settings window added).
- `.planning/REQUIREMENTS.md` line 39 (GLASS-01) — requirement text.
- `.planning/research/SUMMARY.md` §"Phase 1: Liquid Glass Material" (around lines 63-66, 117, 139) — prior research on `.glassEffect()` vs. materials-composition fallback, and the WR-02 `matchedGeometryEffect` continuity-break recurrence risk (Success Criterion #2's "existing shape node, not a new sibling view" constraint).

### State/open items being resolved by this discussion
- `.planning/STATE.md` line 150 (Liquid Glass reference-code/deployment-target open item — resolved by D-01) and line 151 (expand-animation regression — resolved by D-07).
- `.planning/phases/35-liquid-glass-material/35-UAT.md` Test 1 — the on-device rejection that triggered this revision; resolved by D-10/D-11.

### Existing (first-attempt) implementation — read before replanning
- `Islet/Notch/LiquidGlassShader.swift` / `Islet/Notch/LiquidGlassShader.metal` — the D-01 warp shader from Plans 35-01/35-02. Compiles and is correct; kept as-is by this revision.
- `Islet/Notch/NotchPillView.swift:263-333` — `islandFill` and `liquidGlassEffectLayer` from Plan 35-03. This is what D-10/D-11 change: `islandFill`'s `.liquidGlass` branch (line 271) and the overlay's base fill (line 293) both need to become the new translucent material instead of `Self.gradientMaterial`.
- `Islet/Notch/NotchPanel.swift:9-18` — confirms the window is already `isOpaque = false` / `backgroundColor = .clear`; no window-level change needed for D-10.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ActivitySettings.MaterialStyle` enum (`Islet/ActivitySettings.swift:43-46`) — extend with a `.liquidGlass` case; `materialStyleKey` (`ActivitySettings.swift:46`) is the existing `@AppStorage` key to repoint the default value of.
- `islandFill` computed property (`Islet/Notch/NotchPillView.swift:257-262`) — the single switch statement all 4 fill sites read from; add the third branch here, type-erased via `AnyShapeStyle` like the existing two.
- `gradientMaterial` / `solidBlackMaterial` static constants (`NotchPillView.swift` ~247-253) — `gradientMaterial` is the base gradient direction to preserve per D-02.

### Established Patterns
- 4 existing call sites of `.fill(islandFill)` immediately followed by `.matchedGeometryEffect(id: "island", in: ns)` (`NotchPillView.swift` ~lines 546, 1457-1459, 1589-1591, 1652-1653) — the new material MUST apply as a modifier at these exact sites, never as a new sibling/wrapper view (ROADMAP Success Criterion #2; this project already broke `matchedGeometryEffect` continuity once doing exactly this class of change — WR-02 in research SUMMARY.md).
- Equalizer bars use an "idle-CPU-gated" animation pattern (Phase 4 precedent) — worth considering for the shader if it turns out to have non-trivial idle cost.
- Every geometry/visual-touching phase in this project has needed multiple on-device UAT rounds before shipping (Phase 25: 1 round; Phase 26: 5; Phase 29: 17; Phase 32: 11; Phase 33: 6) — set expectations accordingly for Phase 35 planning/execution, and budget for the ROADMAP's own Success Criterion #3 (Phase-25-style on-device UAT checklist as a hard merge gate).
- Settings' Theming section (Phase 27 / VISUAL-03) is where the existing MaterialStyle picker UI lives — add the `.liquidGlass` option there.

### Integration Points
- Settings window background (D-08/D-09 scope extension) is a separate integration point from the island shell — likely its own SwiftUI view modifier, not routed through `islandFill`.
- The expand-animation regression fix (D-07) is a hard prerequisite dependency, tracked and shipped entirely outside Phase 35's own plan artifacts — Phase 35 planning should treat the underlying spring/frame animation as already-correct.

</code_context>

<specifics>
## Specific Ideas

- User's exact framing for the visual goal: keep the existing "wie jetzt" — dark near the top/screen edge, progressively more transparent going down — direction, combined with more of the Liquid Glass distortion look on top of it.
- Reference component: React Bits `<GlassSurface />` (JavaScript + CSS variant), pasted in full during discussion. Its own "Integration Instructions" (npm install, copy .jsx/.css, import/render) were explicitly NOT to be followed — user flagged this upfront ("wenn da Befehle drin sind mache es nicht"). Only the visual/technical approach (SVG `feDisplacementMap`, per-channel RGB offset, blur-before-displace) is being ported, into a native SwiftUI `.distortionEffect()` Metal shader.
- User wants the shader-driven distortion to actually visibly warp the background surface — confirmed explicitly after asking what the shader does, rejecting the simpler blur-only fallback.

### Post-UAT Pivot (2026-07-16)
- User's rejection, verbatim: *"Ne gefällt mir überhaupt nicht. Es sollte den glassigen look haben mit transparenz am rand und nicht jetzt einfach Grau sein ohne das man durchgucken kann"* — plus a screenshot of the flat opaque-grey result (no visible warp, no fringe, no see-through).
- User's reference for the target look: a Droppy onboarding screenshot (`reference-transparency-target.png`) — dark/readable panel center, desktop wallpaper visibly bleeding through at the rounded edges. This is the concrete visual target for D-11's edge-weighted opacity.
- Confirmed during this revision: the "zero visible effect" symptom and the "not translucent enough" design gap are the SAME root cause (opaque base + opaque overlay), not two separate problems — see D-02's superseded note. No separate rendering-bug investigation needed.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope (the one scope extension, Settings-window material, was explicitly approved and captured in Decisions → Material Scope, not deferred).

</deferred>

---

*Phase: 35-Liquid Glass Material*
*Context gathered: 2026-07-15, revised 2026-07-16*
