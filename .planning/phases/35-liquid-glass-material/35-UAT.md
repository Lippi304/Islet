---
status: partial
phase: 35-liquid-glass-material
source: [35-01-SUMMARY.md, 35-02-SUMMARY.md, 35-03-SUMMARY.md, 35-04-SUMMARY.md, 35-06-SUMMARY.md, 35-07-SUMMARY.md, 35-09-SUMMARY.md]
started: 2026-07-16T00:37:15Z
updated: 2026-07-16T12:08:00Z
---

## Current Test

number: 1
name: Liquid Glass render on collapsed pill / expanded island
expected: |
  Collapsed pill and expanded island show a dark, mostly-opaque glass surface
  with the desktop only bleeding through as a faint colored rim-light right at
  the rounded edge (per reference-transparency-target.png) — not uniformly
  bright/light across the whole surface.
awaiting: user response (round 3 gap logged, remaining checks 2-7 still blocked pending fix)

## Tests

### 1. Liquid Glass render on collapsed pill / expanded island
expected: Visible warped/rippled edge + subtle chromatic fringe on the island material; reads as translucent glass, not flat opaque grey.
result: issue
reported: "Ne gefällt mir überhaupt nicht. Es sollte den glassigen look haben mit transparenz am rand und nicht jetzt einfach Grau sein ohne das man durchgucken kann" (screenshot attached: island shows as a flat opaque grey/dark panel with no visible edge warp, no chromatic fringe, and no transparency — cannot see the desktop/wallpaper through it at all)
severity: major

#### Round 2 (post 35-06/35-07 remediation)
result: issue
reported: "Es ist immer noch so hell." (screenshot attached: expanded island now renders as a fairly bright, uniformly light bluish-grey translucent panel — clearly showing the light-colored Xcode toolbar bleeding through across the WHOLE surface, not just at the rounded edge; center is not dark/opaque like reference-transparency-target.png, which stays solid black in the center with only a thin colored rim-light bleed at the very edge)
severity: major
hypothesis: |
  D-10/D-11 swapped the opaque `gradientMaterial` base for raw `.ultraThinMaterial`
  (NotchPillView.swift islandFill `.liquidGlass` branch, line ~276; liquidGlassEffectLayer
  base fill, line ~315) and layered `liquidGlassEdgeOpacity` on top to ramp alpha from
  edge to center. But `.ultraThinMaterial` is a system vibrancy material whose own
  brightness/tint adapts to whatever is behind it (light Xcode chrome here) — it has no
  inherent "dark glass" tint. The edgeOpacity shader is ramping the alpha of that
  already-bright material, so even the "opaque center" reads as bright, not black.
  The reference image achieves the look via a solid dark/black base with the backdrop
  material only revealed (via a mask/blend) at the rim — not via a globally-applied
  Material whose overall brightness is uncontrolled. Needs a design pivot: composite a
  dark tint UNDERNEATH or blended WITH the material (e.g. black fill + material only
  visible through the edge-opacity mask, rather than material as the base itself), or
  force a fixed dark appearance/tint on the Material regardless of backdrop.

#### Round 3 (post 35-09 remediation)
result: issue
reported: "Es ist immer noch so komisch silbern und nichts in Richtung liquid glass." (screenshot attached: expanded island still renders as a uniform, medium-grey/silvery frosted panel across the WHOLE surface — no visible dark, near-opaque center contrasted against a thin transparent rim as in reference-transparency-target.png; overall look reads flat/silvery rather than glassy)
severity: major
hypothesis: |
  35-09's frost-over-material fix (islandFill/liquidGlassEffectLayer, NotchPillView.swift
  ~line 304-362) should produce a dark, near-opaque center (frost layer alpha ramped via
  the liquidGlassEdgeOpacity shader, centerOpacity 0.90/0.92) with only a thin edge reveal
  of the .ultraThinMaterial backdrop. But the ZStack still ends with 3 chromatic-fringe
  passes composited via `.blendMode(.screen)` (lines ~349/358/366), followed by a
  trailing `.overlay(Color.white.opacity(parameters.backgroundOpacity))` glossy wash
  (line ~360, flagged in Plan 35-09's own code comment as an untouched candidate).
  Screen blend mode can only LIGHTEN whatever is underneath it
  (result = 1-(1-a)(1-b)), never darken — so regardless of how dark/opaque the frost
  layer's centerOpacity is tuned, the fringe passes + white wash push the WHOLE surface
  (center included) toward a lighter, washed-out/silvery result, flattening the intended
  dark-center/narrow-rim contrast into a uniform grey. Needs a design pivot on the
  fringe/wash compositing: either drop `.screen` for a blend mode that can darken (e.g.
  normal blend at low opacity, or `.multiply` for the wash), reduce
  fringeOpacity/backgroundOpacity further, or — most likely correct per D-13's "same
  falloff drives everything" intent — apply the fringe/wash ONLY within the same
  edge-opacity mask the frost layer uses, so it only tints the visible rim and never
  touches the dark center.

### 2. Collapse/expand transition smoothness
expected: No artifacts, no dropped frames, no diagonal-jump/bounce regression.
result: blocked
blocked_by: prior-phase
reason: Blocked on Test 1 — no point verifying transition smoothness of an effect that isn't visually present yet.

### 3. All 3 wings show Liquid Glass (Now Playing, Charging, Device)
expected: All 3 wings show same warp+fringe as pill/expanded island, collapsed pill visibly subtler (D-04).
result: blocked
blocked_by: prior-phase
reason: Blocked on Test 1.

### 4. Foreground content stays crisp (only background material warps)
expected: Text/icons never distort, only the black background material shows warp.
result: blocked
blocked_by: prior-phase
reason: Blocked on Test 1.

### 5. Settings Theming picker — 3rd Liquid Glass segment + default selection
expected: 3rd "Liquid Glass" segment exists, selected by default, live-updates island, zero regression to Gradient/Solid Black.
result: blocked
blocked_by: prior-phase
reason: Blocked on Test 1 (same underlying material rendering).

### 6. Settings window's own calmer frosted background (no warp)
expected: Calm frosted/blurred dark gradient with rim-light edge, no warp, text readable.
result: blocked
blocked_by: prior-phase
reason: Blocked on Test 1.

### 7. D-06 default-selection behavior (fresh install vs. existing preference)
expected: Fresh install defaults to Liquid Glass; existing explicit Gradient/Solid Black preference is respected.
result: blocked
blocked_by: prior-phase
reason: Blocked on Test 1.

## Summary

total: 7
passed: 0
issues: 1
pending: 0
skipped: 0
blocked: 6

## Gaps

- truth: "The collapsed pill and expanded island render a translucent Liquid Glass look — visible edge warp, subtle chromatic fringe, and see-through transparency — not a flat opaque grey/black surface"
  status: failed
  reason: "User reported: 'Ne gefällt mir überhaupt nicht. Es sollte den glassigen look haben mit transparenz am rand und nicht jetzt einfach Grau sein ohne das man durchgucken kann' — screenshot shows a flat opaque grey panel, no visible warp/fringe, no transparency to see through"
  severity: major
  test: 1
  root_cause: "D-02: opaque gradientMaterial base hides distortion entirely — superseded by D-10/D-11"
  artifacts: []
  missing: []
  debug_session: ""

- truth: "The collapsed pill and expanded island read as dark glass with the desktop only bleeding through faintly at the rounded edge, not uniformly bright across the whole surface"
  status: failed
  reason: "Round 2 (post 35-06/35-07): User reported 'Es ist immer noch so hell.' — screenshot shows a fairly bright, uniformly light bluish-grey panel with the light Xcode toolbar bleeding through across the entire surface, not just at the edge; no dark/opaque center like reference-transparency-target.png"
  severity: major
  test: 1
  root_cause: "hypothesis (unconfirmed): raw .ultraThinMaterial as the base has no inherent dark tint — its brightness adapts to the backdrop, so the edgeOpacity alpha ramp modulates an already-bright surface instead of revealing backdrop through an otherwise-dark one. See 35-UAT.md Test 1 Round 2 hypothesis for detail."
  artifacts: []
  missing: []
  debug_session: ""

- truth: "The collapsed pill and expanded island render a dark, near-opaque glass center contrasted against a thin, colored transparent rim at the rounded edge (per reference-transparency-target.png), not a uniform grey/silvery panel"
  status: failed
  reason: "Round 3 (post 35-09 remediation): User reported 'Es ist immer noch so komisch silbern und nichts in Richtung liquid glass.' — screenshot shows a uniform, medium-grey/silvery frosted panel across the whole surface, no dark near-opaque center visible, no clear narrow-rim contrast"
  severity: major
  test: 1
  root_cause: "hypothesis (unconfirmed): the 3 chromatic-fringe passes use .blendMode(.screen) and are followed by a trailing Color.white.opacity() overlay wash (NotchPillView.swift liquidGlassEffectLayer, ~lines 349-360) — screen blend mode can only lighten, never darken, so it washes out the frost layer's intended dark, near-opaque center regardless of how dark centerOpacity is tuned. See 35-UAT.md Test 1 Round 3 hypothesis for detail."
  artifacts: []
  missing: []
  debug_session: ""
