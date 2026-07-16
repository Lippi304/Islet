# GSD Debug Knowledge Base

Resolved debug sessions. Used by `gsd-debugger` to surface known-pattern hypotheses at the start of new investigations.

---

## island-expand-diagonal-bounce — expand animation slides diagonally and bounces off screen edge instead of morphing
- **Date:** 2026-07-15
- **Error patterns:** matchedGeometryEffect, diagonal, bounce, morph, expand, collapsed, island, frame ordering, modifier order, size interpolation, anchor
- **Root cause:** All four `.matchedGeometryEffect(id: "island", ...)` call sites in NotchPillView.swift (collapsedIsland, blobShape, wingsShape, mediaWingsOrToast) applied `.frame(...)` BEFORE `.matchedGeometryEffect`. This is backwards per SwiftUI's actual implementation (matchedGeometryEffect is itself built from an internal frame+offset) — a local `.frame` placed before it overrides the effect's own size interpolation, breaking the size-morph portion of the transition while position/translate still partially applies, producing a diagonal slide from a stale anchor instead of a symmetric grow.
- **Fix:** Reordered all four call sites so `.matchedGeometryEffect(id: "island", in: ns)` precedes `.frame(...)`. This matches SwiftUI's documented-correct order and the file's own pre-existing doc comments, which had drifted out of sync with the actual code.
- **Files changed:** Islet/Notch/NotchPillView.swift
---

## liquid-glass-grey-rim-regression — hand-rolled Liquid Glass shader reads as flat grey pill, never true glass, across 4 UAT rounds
- **Date:** 2026-07-16
- **Error patterns:** liquid glass, grey rim, flat grey, chromatic fringe, no color, no transparency, screen blend, washed out, collapsedFill, DEBUG tint, materialStyle, rim mask, blendMode screen, custom shader, glassEffect
- **Root cause:** Deepest root cause was architectural, not a tuning bug: the project hand-approximated Apple's real "Liquid Glass" material with a custom Metal shader (warp distortion + RGB chromatic-fringe screen-blend + edge-opacity masking) instead of checking for a native platform API first. Apple ships the real material natively as of macOS/iOS 26 via SwiftUI's `.glassEffect(_:in:)`, which existed and should have been checked before building a shader approximation — 4 UAT rounds of "fix one visible symptom, reveal the next" were the cost of not checking. Two narrower symptom-bugs were found and fixed along the way while the shader was still the active path: (a) a `#if DEBUG` dev affordance (`collapsedFill`, dating to Phase 2, long before the Liquid Glass phase) hardcoded `Color.red.opacity(0.6)` as the collapsed pill's base fill in every DEBUG build, silently bypassing the user's `.liquidGlass` materialStyle for that one view — the collapsed pill was never actually screenshotted with real Liquid Glass active before this bug report, because the DEBUG override always won; (b) `LiquidGlassParameters`'s RGB chromatic-fringe channel offsets (redOffset/greenOffset/blueOffset) were frozen at their original scaffolding values and never retuned after later rounds shrank the rim mask band width (borderWidth/blurWidth) — the offsets covered only ~26% of the actual rim band, so most of the visible rim showed all 3 R/G/B fringe passes fully overlapping, and `.blendMode(.screen)` on overlapping same-opacity saturated primaries collapses to white/grey instead of color.
- **Fix:** Final fix: gated `liquidGlassEffectLayer` on `#available(macOS 26.0, *)` — native branch renders `Color.clear.glassEffect(.regular.tint(Color.black.opacity(0.7)), in: shape)` clipped to `NotchShape`; the entire pre-existing custom shader stack was preserved verbatim (renamed `legacyLiquidGlassEffectLayer`) as the <macOS 26 fallback. Interim fixes kept alive inside that fallback path: `collapsedFill` now returns `islandFill` when `materialStyle == .liquidGlass` instead of the DEBUG red tint; `LiquidGlassParameters.collapsed`/`.expanded` greenOffset/blueOffset widened (collapsed 0.5/1 → 1.4/2.8; expanded 1.25/2.5 → 3.5/7) with fringeOpacity nudged up, so channel separation covers most of the rim band instead of ~26% of it.
- **Files changed:** Islet/Notch/NotchPillView.swift, Islet/Notch/LiquidGlassShader.swift
---

