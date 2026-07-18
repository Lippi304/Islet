---
phase: 35-liquid-glass-material
plan: 8
subsystem: ui
tags: [swiftui, metal, material, liquid-glass]

requires:
  - phase: 35-liquid-glass-material (35-06, 35-07)
    provides: liquidGlassEdgeOpacity shader + .ultraThinMaterial base wiring
provides:
  - On-device UAT round 2 result for GLASS-01 (rejected — surface reads as too bright/light, not dark glass)
affects: [35-liquid-glass-material remediation round 3]

tech-stack:
  added: []
  patterns: []

key-files:
  created: []
  modified: []

key-decisions:
  - "Round 2 checkpoint REJECTED — same Test 1 as round 1, different symptom (too bright/light vs. previously flat opaque grey)"

patterns-established: []

requirements-completed: []

duration: 5min
completed: 2026-07-16
---

# Phase 35 Plan 8: On-Device UAT (Round 2) Summary

**Round 2 on-device UAT REJECTED — Test 1 fails again: island now translucent but reads as uniformly bright/light instead of dark glass with edge-only bleed-through**

## Performance

- **Duration:** ~5 min (verification-only, no code changes)
- **Completed:** 2026-07-16

## Outcome

Checkpoint task 1 (7-step on-device verification) was interrupted at check 1. User report:

> "Es ist immer noch so hell." (screenshot attached)

Screenshot shows the expanded island rendering as a fairly bright, uniformly light bluish-grey translucent panel — the light-colored Xcode toolbar behind it bleeds through across the entire surface, not just at the rounded edge. This does not match `reference-transparency-target.png`, which stays solid black/dark in the center with only a thin colored rim-light bleed right at the edge.

This is a different failure mode than round 1 (35-UAT.md Test 1 round 1: flat opaque grey, no transparency at all). Round 2's remediation (35-06/35-07) successfully made the material translucent — but with no inherent dark tint, so overall brightness now tracks whatever is behind the notch rather than reading as "black glass."

Checks 2-7 remain unexecuted (blocked on Test 1, consistent with round 1's blocking pattern).

## Root Cause Hypothesis (for next remediation round)

`.ultraThinMaterial` (islandFill `.liquidGlass` branch, `liquidGlassEffectLayer` base — both in `Islet/Notch/NotchPillView.swift`) is a system vibrancy material with no fixed dark tint; its brightness adapts to the backdrop content. The `liquidGlassEdgeOpacity` shader ramps alpha from edge to center, but that only controls how much of this already-bright material shows through — it can't make the material itself read as dark. The reference image's look (solid black center, faint colored bleed only at the rim) likely requires a dark/black base composited with the material, where the material/backdrop is only revealed through the edge-opacity mask rather than being the base layer itself.

Full detail: `35-UAT.md` Test 1 Round 2 section (updated in this checkpoint).

## Deviations from Plan

None — this was a verification-only checkpoint; the rejection is the expected "or reports specific gaps" branch documented in the plan's own `<resume-signal>`.

## Next Phase Readiness

**Blocked.** Phase 35 is not done — GLASS-01 requires a further remediation round (design pivot on the material-base compositing approach) before a round 3 UAT checkpoint can re-run this test. Recommend `/gsd-discuss-phase 35` to work through the compositing approach before planning round 3, since round 1's mechanical swap (opaque→raw Material) already failed once and a second purely mechanical fix risks the same outcome.

---
*Phase: 35-liquid-glass-material*
*Completed: 2026-07-16*
