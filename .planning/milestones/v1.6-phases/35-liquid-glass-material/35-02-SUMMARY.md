---
phase: 35-liquid-glass-material
plan: 2
subsystem: ui
tags: [metal, shader, distortionEffect, swiftui, liquid-glass]

# Dependency graph
requires:
  - phase: 35-liquid-glass-material plan 1 (UI-SPEC/CONTEXT)
    provides: Material/Shader Contract table, D-01/D-04 decisions, reference-GlassSurface.md technique
provides:
  - "Islet's first Metal shader: liquidGlassDistortion(...) [[stitchable]] rounded-rect edge-warp function"
  - "LiquidGlassParameters.collapsed/.expanded starting-point contract"
  - "liquidGlassChannelShaders(...) building base + R/G/B chromatic-fringe Shader values"
affects: [35-03-wire-shader-into-island-shell]

# Tech tracking
tech-stack:
  added: [Metal shading language (.metal source file, first in project)]
  patterns: ["[[stitchable]] Metal function contract for SwiftUI .distortionEffect()", "collapsed/expanded binary parameter discretization (D-04)"]

key-files:
  created:
    - Islet/Notch/LiquidGlassShader.metal
    - Islet/Notch/LiquidGlassShader.swift
  modified:
    - Islet.xcodeproj/project.pbxproj (xcodegen-regenerated to register the 2 new source files)

key-decisions:
  - "brightness (UI-SPEC table row) implemented as no separate LiquidGlassParameters field — folded into the Metal shader's smoothstep edge-falloff curve instead, per the UI-SPEC's own documented implementation note"
  - "liquidGlassChannelShaders(...) unrolls 4 explicit Shader(...) constructions (not a private helper) to keep each Shader's argument list directly grep-able/auditable — matches the plan's literal acceptance criteria"

patterns-established:
  - "New Metal shader files need no manual Xcode project surgery — project.yml's `sources: path: Islet` glob picks them up automatically via `xcodegen generate`"

requirements-completed: [GLASS-01]

# Metrics
duration: 25min
completed: 2026-07-16
---

# Phase 35 Plan 2: Liquid Glass Shader Scaffolding Summary

**Islet's first Metal shader (`liquidGlassDistortion`, a `[[stitchable]]` rounded-rect edge-warp function) plus a Swift parameter contract (`LiquidGlassParameters.collapsed`/`.expanded`) and a 4-Shader chromatic-fringe builder (`liquidGlassChannelShaders`) — compiling but uncalled, ready for Plan 35-03 to wire into the island shell.**

## Performance

- **Duration:** 25 min
- **Started:** 2026-07-16T00:16:53Z
- **Completed:** 2026-07-16T00:22:43Z
- **Tasks:** 2 completed
- **Files modified:** 3 (2 created, 1 xcodegen-regenerated)

## Accomplishments
- `Islet/Notch/LiquidGlassShader.metal` — a single `[[stitchable]] float2 liquidGlassDistortion(...)` function implementing the 7-step rounded-rect edge-warp falloff (blend top/bottom corner radii by vertical position → rounded-box SDF → inward edge distance → edge-band width → smoothstep transition → epsilon-guarded outward direction → apply warp), ported from `reference-GlassSurface.md`'s `feDisplacementMap` SVG filter technique, reading `topCornerRadius`/`bottomCornerRadius` as arguments (never hardcoded, per the UI-SPEC borderRadius hard constraint).
- `Islet/Notch/LiquidGlassShader.swift` — `LiquidGlassParameters.collapsed`/`.expanded` (D-04's binary discretization, midpoints of the UI-SPEC ranges) and `liquidGlassChannelShaders(...)` building `base` + 3 independently-offset (red/green/blue) `Shader` values from one `distortionScale` + per-channel offset, mirroring the reference's `scale = distortionScale + offset` formula.
- Confirmed via project-wide grep that neither new symbol (`liquidGlassDistortion`, `liquidGlassChannelShaders`, `LiquidGlassParameters`) is referenced anywhere outside these two new files — genuinely a scaffolding-only, interface-first step as the plan specifies.

## Task Commits

Each task was committed atomically:

1. **Task 1: liquidGlassDistortion Metal shader function** - `f5f8046` (feat)
2. **Task 2: LiquidGlassParameters + per-channel Shader construction** - `ec71f57` (feat)

_Note: no plan-metadata commit yet — this SUMMARY.md commit serves that role (worktree mode)._

## Files Created/Modified
- `Islet/Notch/LiquidGlassShader.metal` - project's first Metal shader; `[[stitchable]] liquidGlassDistortion(...)` edge-warp function
- `Islet/Notch/LiquidGlassShader.swift` - `LiquidGlassParameters` struct + `.collapsed`/`.expanded` statics, `LiquidGlassChannelShaders` struct, `liquidGlassChannelShaders(...)` builder function
- `Islet.xcodeproj/project.pbxproj` - xcodegen-regenerated (`xcodegen generate`) to add PBXFileReference/PBXBuildFile entries for the 2 new source files; no manual edits

## Decisions Made
- Skipped a private `shader(distortionScale:)` helper inside `liquidGlassChannelShaders` (which would have been the more DRY approach) in favor of 4 explicit unrolled `Shader(...)` constructions, because the plan's acceptance criteria requires `name: "liquidGlassDistortion"` to appear literally 4 times in the file (verified via `grep -c`) — a helper would collapse that to 1 occurrence. This is a deliberate acceptance-criteria-driven choice, not accidental duplication.
- `brightness` from the UI-SPEC table has no `LiquidGlassParameters` field — confirmed via the UI-SPEC's own resolution note that it's folded into the Metal shader's falloff curve; documented with inline comments in both new files for future traceability.

## Deviations from Plan

None - plan executed exactly as written. Both tasks' acceptance criteria (grep checks + `xcodebuild build`) verified to pass exactly as specified.

## Issues Encountered
- Local Xcode toolchain was missing the Metal Toolchain component (`error: cannot execute tool 'metal' due to missing Metal Toolchain`) on the first build attempt — this is a first-time-only environment prerequisite for compiling any `.metal` file on this machine (not caused by the shader code itself). Resolved by running `xcodebuild -downloadComponent MetalToolchain` (one-time ~688MB download), after which both tasks' `xcodebuild build -scheme Islet -destination 'platform=macOS'` verification commands succeeded with zero errors.

## User Setup Required

None - no external service configuration required. (The Metal Toolchain download above was a one-time local dev-machine setup step, not a per-user/per-install requirement — it's now cached in this machine's Xcode installation for all future `.metal` builds.)

## Next Phase Readiness
- Plan 35-03 can now consume `LiquidGlassShader.metal`'s `liquidGlassDistortion` function and `LiquidGlassShader.swift`'s `LiquidGlassParameters`/`liquidGlassChannelShaders(...)` directly — both compile cleanly, expose exactly the interface the UI-SPEC's Material/Shader Contract table describes, and are ready to be wired into the 4 existing `.fill(islandFill)` call sites via `.distortionEffect()`.
- No blockers. The one open item (whether distortion intensity uses a binary collapsed/expanded switch vs. continuous interpolation) was explicitly left as Claude's Discretion by the UI-SPEC and resolved here as binary (`.collapsed`/`.expanded` statics) — Plan 35-03 should treat this as settled unless on-device UAT says otherwise.

## Known Stubs

None. Both files are genuinely scaffolding-only per the plan's own design (interface-first contract step) — this is explicitly documented as intentional in the plan's `<objective>` and `<success_criteria>`, not an unplanned stub.

## Self-Check: PASSED

- FOUND: Islet/Notch/LiquidGlassShader.metal
- FOUND: Islet/Notch/LiquidGlassShader.swift
- FOUND commit f5f8046
- FOUND commit ec71f57

---
*Phase: 35-liquid-glass-material*
*Completed: 2026-07-16*
