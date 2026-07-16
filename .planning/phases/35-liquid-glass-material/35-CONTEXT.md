# Phase 35: Liquid Glass Material - Context

**Gathered:** 2026-07-15
**Revised (round 2):** 2026-07-16 — on-device UAT rejected the first implementation (35-05 checkpoint: "Ne gefällt mir überhaupt nicht... nicht jetzt einfach Grau sein ohne dass man durchgucken kann", see `35-UAT.md`). This revision pivoted D-02 from an opaque-gradient-base to a real translucent material base (D-10/D-11).
**Revised (round 3):** 2026-07-16 — round 2's shipped fix (35-06/35-07: raw `.ultraThinMaterial` base) was ALSO rejected on-device (35-08 checkpoint: "Es ist immer noch so hell.", see `35-UAT.md` Test 1 Round 2). Root cause: `.ultraThinMaterial` is a vibrancy material with no inherent dark tint — both `islandFill`'s `.liquidGlass` branch AND the overlay's own base fill are the same bright, backdrop-adapting material, so the edge-opacity ramp only modulates alpha between two identically-bright layers. D-10/D-11 are superseded by D-12/D-13/D-14 below. D-01/D-03/D-04/D-05/D-06/D-07/D-08/D-09 remain unaffected and still apply as originally decided below.
**Status:** Ready for replanning (round 3)

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

### Material Redesign (Post-UAT Pivot — 2026-07-16, round 2)
User rejected the first on-device build (`35-UAT.md` Test 1): *"Ne gefällt mir überhaupt nicht. Es sollte den glassigen look haben mit transparenz am rand und nicht jetzt einfach Grau sein ohne dass man durchgucken kann"* — it should have the glassy look with transparency at the edge, not just be flat grey with nothing to see through. User supplied a reference screenshot (Droppy's onboarding panel, saved to `reference-transparency-target.png`) showing the pattern they want: panel center stays dark/readable, but the desktop wallpaper visibly bleeds through right at the rounded edges.

- **D-10 [SUPERSEDED 2026-07-16 round 3 by D-12]:** ~~Replace the opaque `gradientMaterial` base with a real, live-blurring macOS material (SwiftUI `Material`, e.g. `.ultraThinMaterial`/`.regularMaterial`, backed by `NSVisualEffectView` under the hood) for the `.liquidGlass` case only.~~ Round 2 on-device UAT (`35-UAT.md` Test 1 Round 2) showed this reads as uniformly bright/light — `.ultraThinMaterial` is a vibrancy material with no inherent dark tint, so its brightness tracks whatever's behind the notch (e.g. a light Xcode toolbar) across the WHOLE surface, not just at the edge. Replaced by D-12.
- **D-11 [SUPERSEDED 2026-07-16 round 3 by D-13]:** ~~Material opacity/blur is edge-weighted, not uniform: more transparent/blurred right at the rounded edge, progressively more opaque/dark toward the center.~~ The *concept* (edge-weighted reveal) was correct, but round 2 applied the ramp to the wrong layer — it ramped the alpha of the (already-bright) material itself, with no dark layer underneath to fall back to. Replaced by D-13, which keeps the same falloff-driver idea but ramps a dark frost layer's alpha instead.

### Material Redesign — Round 3 (Post Round-2-UAT Pivot — 2026-07-16)
User rejected the round-2 build (`35-UAT.md` Test 1 Round 2): *"Es ist immer noch so hell."* — screenshot showed a uniformly bright bluish-grey panel with the light Xcode toolbar bleeding through across the entire surface, not just at the edge. Confirmed root cause via code inspection: both `islandFill`'s `.liquidGlass` branch (`NotchPillView.swift:276`) and `liquidGlassEffectLayer`'s own base fill (`NotchPillView.swift:315`) are `.ultraThinMaterial` — there is no solid dark color anywhere in the stack, so "revealing less material at the edge" just reveals more of the *same* bright material underneath, not darkness.

- **D-12:** Introduce a genuine solid dark ("frost") layer as the TRUE, always-present base — reusing the original pre-D-10 `gradientMaterial`-style near-opaque black (not raw `.ultraThinMaterial`) as the default state everywhere on the shape. The live-blurring `.ultraThinMaterial`/backdrop is only revealed through a masked band right at the rounded edge (same technique the user's own reference component uses in dark mode: `reference-GlassSurface.md` documents a `background: hsl(0 0% 0% / var(--glass-frost, 0))` black frost layer composited over the distorted/blurred backdrop — darkness comes from an added black layer, not from tinting the material itself). Center is dark/opaque regardless of backdrop; only the rim shows a real blurred refraction of what's behind. This directly targets the round-2 failure: no matter how the edge-ramp is tuned, if both layers are material, the center can never read as dark.
- **D-13:** The edge-opacity ramp (D-11's concept, kept) now controls the **black frost layer's** opacity, inverted from round 2: high frost-opacity toward the center (fully dark, backdrop hidden), low frost-opacity right at the rounded edge (frost fades out, revealing the blurred/warped material+backdrop underneath). Reuse the same `edgeDist`/border-band falloff already in `LiquidGlassShader.metal` (Step 3-5) as the single driver — same source of truth, just applied to the frost's alpha instead of the material's alpha as in round 2's (superseded) D-11.
- **D-14:** Rim band width — **narrow**: only a thin sliver right at the rounded edge shows the bleed-through, matching `reference-transparency-target.png` (thin colored rim-light, not a broad soft gradient). User confirmed this over the wider/softer alternative.
- **D-15 (Liquid Glass vs. Solid Black differentiation):** The center is allowed to be exactly as dark/opaque as the existing `.solidBlack` material style — no forced extra transparency in the center to manufacture a visual difference. The user-visible distinction between `.liquidGlass` and `.solidBlack` is the rim bleed-through + the existing warp/chromatic-fringe effect (D-01/D-03), not center darkness. Confirmed by user over the alternative (deliberately keeping the center 85-90% opaque to feel "more glass").
- **Retuning note:** the existing tuned constants in `LiquidGlassParameters` (`backgroundOpacity: 0.04/0.07`, R/G/B fringe `.opacity(0.10)`) and the round-2 edge/center opacity values were calibrated against the wrong layer/base and should be treated as stale starting points, not locked values, once D-12/D-13 change what's being ramped. Same "Claude's Discretion — on-device tuning" grant as D-01 applies.

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
- `.planning/phases/35-liquid-glass-material/reference-GlassSurface.md` — full React Bits `<GlassSurface />` source (JS + CSS) with SwiftUI porting notes worked out during discussion. **Read this before writing any shader code** — it documents the exact displacement-map/channel-offset technique and which parts map to which SwiftUI APIs. The warp math (D-01) is still correct; only the fill layer it's applied to changes (D-12/D-13). **Round 3 addition:** lines ~230, ~255-257 document the component's own dark-mode darkening mechanism — a black `--glass-frost` overlay (`hsl(0 0% 0% / var(--glass-frost, 0))`) composited on top of the blurred/distorted backdrop, controlled by the `backgroundOpacity` prop. This is the direct precedent for D-12's black-frost-layer approach — darkness comes from an added opaque layer, not from tinting the material/blur itself.
- `.planning/phases/35-liquid-glass-material/reference-transparency-target.png` — user-supplied screenshot (Droppy onboarding) showing the target transparency distribution: dark/readable center, desktop visibly bleeding through at the rounded edges. Grounds D-13's edge-weighted frost-opacity decision and D-14's narrow-rim-width decision.

### Roadmap & requirements
- `.planning/ROADMAP.md` §"Phase 35: Liquid Glass Material" (lines 581-592) — Success Criteria; note Success Criterion #1's scope is extended by D-08 above (Settings window added).
- `.planning/REQUIREMENTS.md` line 39 (GLASS-01) — requirement text.
- `.planning/research/SUMMARY.md` §"Phase 1: Liquid Glass Material" (around lines 63-66, 117, 139) — prior research on `.glassEffect()` vs. materials-composition fallback, and the WR-02 `matchedGeometryEffect` continuity-break recurrence risk (Success Criterion #2's "existing shape node, not a new sibling view" constraint).

### State/open items being resolved by this discussion
- `.planning/STATE.md` line 150 (Liquid Glass reference-code/deployment-target open item — resolved by D-01) and line 151 (expand-animation regression — resolved by D-07).
- `.planning/phases/35-liquid-glass-material/35-UAT.md` Test 1 — the round-1 on-device rejection; resolved (then superseded) by D-10/D-11.
- `.planning/phases/35-liquid-glass-material/35-UAT.md` Test 1 Round 2 / `35-08-SUMMARY.md` — the round-2 on-device rejection ("Es ist immer noch so hell") that triggered THIS revision; resolved by D-12/D-13/D-14.

### Existing (round-2 attempt) implementation — read before replanning
- `Islet/Notch/LiquidGlassShader.swift` / `Islet/Notch/LiquidGlassShader.metal` — the D-01 warp shader from Plans 35-01/35-02, including the `liquidGlassEdgeOpacity` colorEffect from Plan 35-07. Warp math still correct; the edge-falloff logic is reusable for D-13, just needs to drive a different layer's alpha.
- `Islet/Notch/NotchPillView.swift:263-278` — `islandFill`. The `.liquidGlass` branch (currently line 276: `AnyShapeStyle(.ultraThinMaterial)`) needs to become the D-12 solid dark frost base instead of raw material.
- `Islet/Notch/NotchPillView.swift:306-360` — `liquidGlassEffectLayer`. Currently: base fill is `.ultraThinMaterial` (line 315) with `liquidGlassEdgeOpacity` ramping that same layer's alpha (lines 320-333). Per D-12/D-13, this needs restructuring so the translucent material/backdrop is the layer being REVEALED (at low frost-opacity, i.e. at the edge) rather than the layer whose own alpha is ramped directly — a solid dark frost fill needs to sit in the stack with its alpha driven (inverted) by the same edge falloff.
- `Islet/Notch/NotchPanel.swift:9-18` — confirms the window is already `isOpaque = false` / `backgroundColor = .clear`; no window-level change needed.

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

### Post-UAT Pivot — Round 2 (2026-07-16)
- User's rejection, verbatim: *"Ne gefällt mir überhaupt nicht. Es sollte den glassigen look haben mit transparenz am rand und nicht jetzt einfach Grau sein ohne das man durchgucken kann"* — plus a screenshot of the flat opaque-grey result (no visible warp, no fringe, no see-through).
- User's reference for the target look: a Droppy onboarding screenshot (`reference-transparency-target.png`) — dark/readable panel center, desktop wallpaper visibly bleeding through at the rounded edges. This is the concrete visual target for D-13's edge-weighted opacity.
- Confirmed during round-2 revision: the "zero visible effect" symptom and the "not translucent enough" design gap are the SAME root cause (opaque base + opaque overlay), not two separate problems — see D-02's superseded note. No separate rendering-bug investigation needed.

### Post-UAT Pivot — Round 3 (2026-07-16)
- User's rejection, verbatim: *"Es ist immer noch so hell."* — screenshot showed a fairly bright, uniformly light bluish-grey panel with the light Xcode toolbar bleeding through across the WHOLE surface, not just the edge; center did not read as dark/opaque like the reference image.
- Confirmed during this revision (code inspection, not a new bug): `.ultraThinMaterial` has no inherent dark tint — it's a vibrancy material whose brightness tracks the backdrop. Both fill sites (`islandFill` and `liquidGlassEffectLayer`'s base) were the same raw material, so there was never a dark layer to fall back to.
- User pointed to their own reference component's dark-mode CSS (`reference-GlassSurface.md`) as the precedent for how to actually darken it: a solid black `--glass-frost` overlay composited on top of the blurred backdrop, not a tint applied to the material itself — this directly grounds D-12.
- User confirmed: narrow rim-bleed width (D-14) over a broader soft gradient, and that Liquid Glass's center is allowed to be exactly as dark as Solid Black (D-15) — the warp+fringe effect is a sufficient visual differentiator on its own, no artificial extra transparency needed in the center.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope (the one scope extension, Settings-window material, was explicitly approved and captured in Decisions → Material Scope, not deferred).

</deferred>

---

*Phase: 35-Liquid Glass Material*
*Context gathered: 2026-07-15, revised 2026-07-16 (round 2), revised 2026-07-16 (round 3)*
