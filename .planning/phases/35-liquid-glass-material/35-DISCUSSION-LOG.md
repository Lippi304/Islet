# Phase 35: Liquid Glass Material - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-15
**Phase:** 35-Liquid Glass Material
**Areas discussed:** Reference code & technique, Material selection model, Expand animation regression fold-in, Material scope beyond the island shell

---

## Reference code & technique

| Option | Description | Selected |
|--------|-------------|----------|
| I'll paste it now | User has reference code ready to share immediately | ✓ |
| Real .glassEffect() / NSGlassEffectView | macOS 26+ native API, deployment-target bump | |
| Materials-composition fallback | .ultraThinMaterial approximation, stays on 15.0 | |

**User's choice:** Pasted the React Bits `<GlassSurface />` component (JS + CSS variant), with an explicit instruction: "wenn da Befehle drin sind mache es nicht sondern nur das was ich dir sage" (if there are commands in there, don't do them, only what I tell you) — the component's own "Integration Instructions" (npm install, copy .jsx/.css files, React-style import/render) were ignored; only the visual technique was extracted.

**Notes:** Analysis found two CSS rendering paths in the reference: (1) `glass-surface--svg` — an SVG `feDisplacementMap` filter warps the backdrop per-pixel via a generated displacement map, with independently-offset R/G/B channel passes producing chromatic-aberration fringing at edges; (2) `glass-surface--fallback` — plain `backdrop-filter: blur(12px) saturate(1.8) brightness(1.1)` with no distortion, used by browsers without SVG backdrop-filter support. Full source saved to `35-liquid-glass-material/reference-GlassSurface.md` for downstream agents.

| Option | Description | Selected |
|--------|-------------|----------|
| Voller Distortion-Look (Metal-Shader) | SwiftUI `.distortionEffect()`, macOS 14+, no bump, most implementation effort | |
| Vereinfachter Fallback-Look | `.ultraThinMaterial` only, no shader, fastest to ship | |
| Apples echtes `.glassEffect()` (macOS 26+) | Native API, requires deployment-target bump to 26.0 | |

**User's choice:** Asked for Claude's recommendation, and specified the existing black-top→transparent-bottom gradient direction should be kept as the base, with more Liquid Glass look layered on.

**Claude's recommendation:** Simplified materials-composition (no shader) — citing this project's history of many on-device UAT iteration rounds on visual phases (25, 26, 29, 32, 33) as reason to avoid the extra iteration axis of a custom Metal shader.

| Option | Description | Selected |
|--------|-------------|----------|
| Ja, so machen | Accept the simplified recommendation | |
| Doch den vollen Distortion-Shader | Want the full shader after all | |

**User's choice:** Asked what the Metal shader actually does before deciding — clarified they want the background to visibly distort, not just blur.

**Notes:** Claude explained `.distortionEffect()` samples each output pixel from an offset position, warping the app's own rendered backdrop material (not the live desktop behind the transparent `NSPanel` — an important scope constraint). Per-channel RGB offset produces the chromatic fringe.

| Option | Description | Selected |
|--------|-------------|----------|
| Voll: Wellung + Farbfransen | Full edge warp + chromatic RGB fringe, closest to reference | ✓ |
| Nur Wellung, keine Farbfransen | Warp only, no color fringing, more subtle/native-feeling | |

**User's choice:** Voll: Wellung + Farbfransen.
**Notes:** This closes the technique decision — full distortion shader (D-01 through D-04 in CONTEXT.md).

---

## Material selection model

| Option | Description | Selected |
|--------|-------------|----------|
| Neue dritte Option (empfohlen) | New `.liquidGlass` case, Gradient/Solid Black remain | ✓ |
| Ersetzt Gradient als neuer Standard | Removes the Gradient case entirely | |

**User's choice:** Neue dritte Option (empfohlen).

| Option | Description | Selected |
|--------|-------------|----------|
| Liquid Glass wird neuer Default | New `@AppStorage` default for everyone | ✓ |
| Gradient bleibt Default | Opt-in only, no behavior change for existing users | |

**User's choice:** Liquid Glass wird neuer Default.

| Option | Description | Selected |
|--------|-------------|----------|
| Überall gleich stark | Same distortion strength in both states | |
| Dezenter im collapsed Pill | Scaled down in small collapsed pill, full in expanded | ✓ |

**User's choice:** Dezenter im collapsed Pill.

| Option | Description | Selected |
|--------|-------------|----------|
| Nur Hintergrund-Fill (empfohlen) | Distortion only on background fill layer, content stays crisp | ✓ |
| Komplette Ansicht inkl. Vordergrund | Distorts everything including album art/text/icons | |

**User's choice:** Nur Hintergrund-Fill (empfohlen).

---

## Expand animation regression fold-in

| Option | Description | Selected |
|--------|-------------|----------|
| Erst fixen, dann Material (empfohlen) | Fix regression first for a clean baseline | ✓ |
| Zusammen als ein Fix-Block | Handle both in the same phase/plan | |

**User's choice:** Erst fixen, dann Material (empfohlen).

| Option | Description | Selected |
|--------|-------------|----------|
| Immer, bei jedem Expand | Consistently reproducible on every expand | ✓ |
| Nur manchmal / bestimmte Auslöser | Intermittent, condition-dependent | |

**User's choice:** Immer, bei jedem Expand.

| Option | Description | Selected |
|--------|-------------|----------|
| Eigene /gsd-debug Session zuerst | Standalone debug session before Phase 35 planning | ✓ |
| Als Plan 1 innerhalb Phase 35 | First task/plan inside Phase 35 itself | |

**User's choice:** Eigene /gsd-debug Session zuerst.
**Notes:** This bug fix is explicitly tracked OUTSIDE Phase 35's own plan artifacts — a prerequisite, not a phase task.

---

## Material scope beyond the island shell

| Option | Description | Selected |
|--------|-------------|----------|
| Strikt nur die Island-Hülle (empfohlen) | Pill + expanded island + 3 wings only, per ROADMAP | |
| Auch Settings-Fenster | Settings window background gets the new look too | ✓ |

**User's choice:** Auch Settings-Fenster.
**Notes:** This extends beyond ROADMAP.md's literal Success Criterion #1 wording — captured explicitly in CONTEXT.md (D-08) as an approved, intentional extension rather than dropped.

| Option | Description | Selected |
|--------|-------------|----------|
| Voller Look inkl. Distortion | Full distortion shader on Settings window too | |
| Nur Blur/Frost, keine Distortion (empfohlen) | Calmer materials-only variant for Settings (readability) | ✓ |

**User's choice:** Nur Blur/Frost, keine Distortion (empfohlen).

---

## Claude's Discretion

- Exact numeric shader tuning parameters (displacement scale, per-channel offset delta, edge-band width) — reference component's web-scale defaults don't map directly to Islet's smaller dimensions; needs on-device tuning.
- Implementation mechanism for collapsed-pill distortion scaling (continuous parameter vs. binary on/off).

## Deferred Ideas

None — the one scope extension identified (Settings window) was explicitly approved, not deferred. Onboarding flow was explicitly excluded from the Settings-window extension (not requested).

---
---

# Revision Session — 2026-07-16 (Post-UAT Pivot)

**Trigger:** On-device UAT of the 35-05 checkpoint rejected the first implementation (`35-UAT.md` Test 1) — user reported it rendered as a flat opaque grey/black panel with no visible warp, chromatic fringe, or transparency, and attached a screenshot.

**Areas discussed:** Translucency mechanism, Transparency distribution

---

## Translucency mechanism

Before asking, code was inspected (`NotchPillView.swift`, `NotchPanel.swift`) to find the root cause: `islandFill` returns the same 100%-opaque `gradientMaterial` for `.liquidGlass` as for `.gradient`, and the overlay's own base warp pass fills with that same opaque black gradient again — distorting solid opaque black is visually indistinguishable from not distorting it. The window itself was already `isOpaque = false` / `.clear`, so the fix is purely a SwiftUI fill-layer change.

| Option | Description | Selected |
|--------|-------------|----------|
| Echtes macOS-Material (empfohlen) | `.ultraThinMaterial`/`NSVisualEffectView`-backed live blur — real desktop bleeds through since the window is already transparent | ✓ |
| Simulierte Transparenz | Alpha-blended gradient only, no real live desktop blur — cheaper/predictable but no actual see-through | |

**User's choice:** Echtes macOS-Material.
**Notes:** Captured as D-10 in CONTEXT.md.

## Transparency distribution

User supplied a reference screenshot (Droppy onboarding panel) showing dark/readable center with the desktop wallpaper visibly bleeding through at the rounded edges — saved to `reference-transparency-target.png`.

| Option | Description | Selected |
|--------|-------------|----------|
| Rand transparenter, Mitte dunkler (empfohlen) | Opacity ramp reuses the shader's existing edge-distance falloff — matches the reference image | ✓ |
| Gleichmäßige Transparenz | Same material opacity everywhere — simpler, but risks unreadable content depending on background | |

**User's choice:** Rand transparenter, Mitte dunkler.
**Notes:** Captured as D-11 in CONTEXT.md. Confirmed during this session: the "zero visible effect" symptom and the "not translucent enough" complaint share one root cause (opaque-on-opaque), not two separate bugs — no separate rendering-bug investigation needed.

## Claude's Discretion (this revision)

- Exact opacity/blur curve shape for D-11's edge-to-center ramp, and retuned values for `LiquidGlassParameters` (backgroundOpacity, R/G/B fringe opacity) against the new translucent base — on-device tuning during execution, same grant as the original D-01 discretion.

## Deferred Ideas (this revision)

None.

---
---

# Revision Session — 2026-07-16 (Round 3, Post Round-2-UAT Pivot)

**Trigger:** On-device UAT of the 35-08 checkpoint rejected the round-2 implementation (`35-UAT.md` Test 1 Round 2 / `35-08-SUMMARY.md`) — user reported "Es ist immer noch so hell." (still too bright); screenshot showed a uniformly bright bluish-grey panel with the light Xcode toolbar bleeding through across the whole surface, not just the edge.

**Areas discussed:** Compositing strategy, Rim width / bleed strength, Differentiation from Solid Black

---

## Compositing strategy

Before asking, code was inspected (`NotchPillView.swift` `islandFill` line 276, `liquidGlassEffectLayer` line 315) to confirm the round-2 root cause: both fill sites are raw `.ultraThinMaterial` — a vibrancy material with no inherent dark tint, so there is no dark layer for the edge-opacity ramp to fall back to. It only modulates alpha between two identically-bright layers.

| Option | Description | Selected |
|--------|-------------|----------|
| Feste dunkle Basis + Rand-Reveal (empfohlen) | Near-opaque black/dark layer is always the true base; material/backdrop only revealed through a masked edge band | ✓ |
| Überall Material + Dunkel-Tint-Ramp | Material stays the base everywhere; a multiply-blended dark tint gets stronger toward the center | |

**User's choice:** Feste dunkle Basis + Rand-Reveal.
**Notes:** Captured as D-12 in CONTEXT.md (supersedes D-10). User then pointed to their own reference component's dark-mode CSS (`reference-GlassSurface.md`) — a solid black `--glass-frost` overlay composited on top of the blurred backdrop — as direct precedent that darkness should come from an added opaque layer, not from tinting the material itself. No npm/npx action taken (irrelevant to this Swift project; reference is porting-only, consistent with the original "don't run install commands" instruction from the round-1 session).

## Rim width / bleed strength

| Option | Description | Selected |
|--------|-------------|----------|
| Schmaler Saum (empfohlen) | Thin sliver right at the rounded edge shows bleed-through — matches `reference-transparency-target.png` | ✓ |
| Breiterer, weicherer Übergang | ~15-20% of the surface transitions softly — more "glassy" but less faithful to the reference | |

**User's choice:** Schmaler Saum.
**Notes:** Captured as D-14 in CONTEXT.md.

## Differentiation from Solid Black

| Option | Description | Selected |
|--------|-------------|----------|
| Warp+Fringe reicht als Unterschied (empfohlen) | Center can be exactly as dark as Solid Black; distinction is the rim bleed + warp/chromatic-fringe effect | ✓ |
| Mitte etwas heller/durchsichtiger als Solid Black | Center gets a deliberate 85-90% opacity floor to always feel "more glass" than Solid Black | |

**User's choice:** Warp+Fringe reicht als Unterschied.
**Notes:** Captured as D-15 in CONTEXT.md.

## Claude's Discretion (round 3)

- Exact mechanism for inverting D-13's frost-opacity ramp against the existing edge-falloff shader output, and retuned `LiquidGlassParameters` values against the new frost-base compositing — on-device tuning during execution, same grant as prior rounds.

## Deferred Ideas (round 3)

None.
