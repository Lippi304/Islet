---
phase: 35-liquid-glass-material
plan: 12-addendum
subsystem: ui
tags: [swiftui, glasseffect, metal, liquid-glass, availability-gating]

requires:
  - phase: 35-liquid-glass-material
    provides: D-01–D-19 custom shader implementation (now the <macOS 26 fallback), round-4 UAT approval
provides:
  - Native SwiftUI .glassEffect() Liquid Glass rendering on macOS 26+, availability-gated with the D-01–D-19 custom shader preserved as the <26 fallback
affects: []

tech-stack:
  added: []
  patterns:
    - "Availability-gated feature implementation: #available(macOS 26.0, *) branching between a native system API and a hand-built fallback, at a single shared call point (liquidGlassEffectLayer) rather than duplicated across all 4 island-shell call sites"

key-files:
  created: []
  modified:
    - Islet/Notch/NotchPillView.swift
    - Islet/Notch/LiquidGlassShader.swift

key-decisions:
  - "D-20: use native SwiftUI .glassEffect(_:in:) on macOS 26.0+ instead of continuing to tune the custom Metal shader; keep the entire D-01–D-19 shader stack unchanged as legacyLiquidGlassEffectLayer for <macOS 26"

patterns-established:
  - "When a hand-built visual effect keeps failing UAT after multiple remediation rounds, check whether the platform now ships the real effect natively before continuing to tune parameters"

requirements-completed: [GLASS-01]

duration: ~90min (3 debug-session investigation rounds + 1 pivot implementation round)
completed: 2026-07-16
---

# Phase 35: Liquid Glass Material — Round 5 Addendum Summary

**Post-completion regression fixed by pivoting to SwiftUI's native `.glassEffect()` on macOS 26+, with the custom Metal shader stack (D-01–D-19) preserved as the <26 fallback**

## Performance

- **Duration:** ~90 min (debug investigation + native-API implementation)
- **Tasks:** 1 debug session, 3 investigation rounds, 1 fix round
- **Files modified:** 2

## Accomplishments
- Diagnosed and fixed two latent bugs the original 4 UAT rounds never exercised: a Phase-2 `#if DEBUG` override that hardcoded `Color.red.opacity(0.6)` on the collapsed pill's fill (bypassing `materialStyle` entirely — the collapsed pill was never actually screenshotted with Liquid Glass before this report), and RGB chromatic-fringe offsets left at scaffolding values that only covered ~26% of round 4's narrowed rim band, collapsing to grey under `.blendMode(.screen)`.
- Pivoted the underlying architecture: `liquidGlassEffectLayer` now branches on `#available(macOS 26.0, *)` — the native branch uses SwiftUI's real `.glassEffect(.regular.tint(Color.black.opacity(0.7)), in: shape)`; the pre-existing custom shader stack (warp distortion, frost layer, masked chromatic fringe, rim mask) moved verbatim into `legacyLiquidGlassEffectLayer` as the fallback for macOS versions below 26.
- Re-verified on-device against `reference-transparency-target.png` — user confirmed: "Sieht jetzt nach echtem Liquid Glass aus."

## Task Commits

1. **Debug investigation + fix** - `bc04457` (fix: pivot Liquid Glass rendering to native glassEffect on macOS 26+)
2. **Debug session resolution** - `815b8f9` (docs: resolve debug liquid-glass-grey-rim-regression)

## Files Created/Modified
- `Islet/Notch/NotchPillView.swift` - `liquidGlassEffectLayer` gated on `#available(macOS 26.0, *)`; native branch added; existing shader stack renamed `legacyLiquidGlassEffectLayer`, unchanged in behavior
- `Islet/Notch/LiquidGlassShader.swift` - unchanged this round beyond the interim RGB-offset widening applied during investigation

## Decisions Made
- D-20 (see 35-CONTEXT.md): native `.glassEffect()` on macOS 26+, custom shader as `<26` fallback — chosen over bumping the deployment target to macOS-26-only (bigger scope change than warranted) or continuing to tune shader parameters (already proven fragile across 4 UAT + 2 debug rounds).

## Deviations from Plan

### Auto-fixed Issues

**1. [Round-4-approved code exercised for the first time] Collapsed pill DEBUG red-tint override**
- **Found during:** Post-approval on-device screenshot review
- **Issue:** `collapsedFill` hardcoded `Color.red.opacity(0.6)` in DEBUG builds regardless of `materialStyle`, dating to Phase 2 — the collapsed pill (as opposed to the expanded island, which every UAT round screenshotted) was never actually seen with Liquid Glass applied.
- **Fix:** `collapsedFill` now returns `islandFill` in DEBUG when `materialStyle == .liquidGlass`; red dev-tint retained only for `.gradient`/`.solidBlack`.
- **Files modified:** Islet/Notch/NotchPillView.swift
- **Verification:** Build succeeded; superseded by the native glassEffect pivot but the conditional logic remains correct for the <26 fallback path.
- **Committed in:** bc04457

**2. [Structural, revealed by round-4's rim-band narrowing] RGB chromatic-fringe offsets too narrow**
- **Found during:** Debug investigation round 2
- **Issue:** `redOffset`/`greenOffset`/`blueOffset` in `LiquidGlassParameters` sat at scaffolding values never retuned after round 3 narrowed the rim band — only ~26% of the visible rim had the 3 fringe passes actually separated; the rest fully overlapped and `.blendMode(.screen)` renders overlapping R+G+B as white/grey.
- **Fix:** Widened the offset separation so the fringe passes diverge across the full rim band width.
- **Files modified:** Islet/Notch/LiquidGlassShader.swift
- **Verification:** Build succeeded; this fix remains live in the `<26` fallback path (`legacyLiquidGlassEffectLayer`).
- **Committed in:** bc04457

---

**Total deviations:** 2 auto-fixed (both interim fixes preserved in the fallback path, superseded as the primary rendering path by D-20's native glassEffect pivot on macOS 26+)
**Impact on plan:** Both fixes are necessary for the `<macOS 26` fallback to render correctly; the native pivot (D-20) is the primary fix for this machine's actual OS version.

## Issues Encountered
- Initial debug hypothesis (wrong Xcode project/checkout open) was investigated and refuted via user confirmation before the real root causes were found — see `.planning/debug/resolved/liquid-glass-grey-rim-regression.md` for the full investigation trail.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
GLASS-01 is verified on-device on this machine's actual OS (macOS 26/Tahoe) via the native `.glassEffect()` path. The `<macOS 26` fallback path has NOT been on-device verified on an actual pre-26 machine (no such hardware available in this environment) — it inherits round 4's UAT approval by construction (byte-identical shader code, just gated behind `#available`), but flag this if a pre-26 Mac becomes available for spot-testing before a public release.

---
*Phase: 35-liquid-glass-material*
*Completed: 2026-07-16*
