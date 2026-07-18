---
phase: 36-cosmetic-restyles-signature-animation
plan: 3
subsystem: ui
tags: [swiftui, coretext, core-text, font-licensing, signature-animation, onboarding]

# Dependency graph
requires: []
provides:
  - Bundled OFL-licensed Dancing Script font, replacing the flagged demo-licensed LastoriaBoldRegular.otf (D-12 resolved)
  - SignatureHeading.loadSignatureFont(size:) — runtime font registration + Bold (wght=700) variation-attribute CTFont construction
  - SignatureHeading.glyphPaths(for:font:) — Core Text per-glyph vector Path extraction, Y-up-to-Y-down oriented, advance-positioned
  - SignatureHeading.totalWidth(for:) — content-width accumulator
  - SignatureHeading: View — standalone, unwired, static-fill render of "Meet Islet" in solid orange
affects: [36-04]

# Tech tracking
tech-stack:
  added: [Dancing Script variable font (OFL 1.1, Google Fonts), Core Text (CTFontManagerRegisterFontsForURL, CTFontCreatePathForGlyph, CTFontGetAdvancesForGlyphs, CTFontGetGlyphsForCharacters)]
  patterns: ["Run-once font registration via a private static let lazy-static", "internal (not private) static factory functions for @testable import access, mirroring EqualizerBars.makeProfiles()"]

key-files:
  created:
    - Islet/Fonts/DancingScript-Variable.ttf
    - Islet/Fonts/DancingScript-OFL.txt
    - Islet/Notch/SignatureHeading.swift
    - IsletTests/SignatureHeadingTests.swift
  modified:
    - Islet.xcodeproj/project.pbxproj (xcodegen regeneration to pick up new sources)

key-decisions:
  - "Dancing Script Bold (OFL 1.1) locked as the D-12 font substitute, downloaded directly from the confirmed google/fonts repo path rather than any third-party mirror"
  - "SignatureHeading kept fully unwired from onboardingWelcomeStep in this plan — Plan 36-04 owns both the animation layer and the wiring, avoiding a partially-animated user-visible state"

patterns-established:
  - "Glyph outline extraction: CTFontCreatePathForGlyph with a translation+flip CGAffineTransform (Y-up Core Text space to Y-down SwiftUI space, ascent-shifted) is the reusable technique for any future per-glyph vector rendering in this codebase"

requirements-completed: [ONBOARD-04]

# Metrics
duration: ~20min
completed: 2026-07-16
---

# Phase 36 Plan 3: Signature Font Bundling + Glyph Extraction Contract Summary

**Bundled Dancing Script (OFL) replacing a demo-licensed font, and built a Core Text glyph-outline extraction contract (`SignatureHeading.glyphPaths(for:font:)`) that Plan 36-04 will animate with `.trim(from:to:)`.**

## Performance

- **Duration:** ~20 min
- **Completed:** 2026-07-16T18:21:45Z
- **Tasks:** 3 completed
- **Files modified:** 5 (4 created, 1 regenerated)

## Accomplishments
- Resolved the D-12 flagged font-license risk: `LastoriaBoldRegular.otf` (personal-use-only demo font) is never used; Dancing Script Bold (SIL OFL 1.1, Google Fonts, Impallari Type) is bundled and verified as a genuine TrueType binary with its license text committed
- Built the genuinely new, no-prior-analog Core Text glyph-extraction pipeline: per-character `CGGlyph` resolution → `CTFontCreatePathForGlyph` outline → Y-up-to-Y-down flip (ascent-shifted `CGAffineTransform`) → advance-positioned `Path`
- `SignatureHeading` renders as a standalone, buildable, unwired `View` — solid-orange "Meet Islet" glyphs, correctly oriented — ready for Plan 36-04 to animate and wire into onboarding
- Sanity test suite confirms the extraction contract's shape (10 entries incl. space, non-empty outlines, correct width accumulation)

## Task Commits

Each task was committed atomically:

1. **Task 1: Bundle the OFL-licensed font + runtime registration helper** - `746d78b` (feat)
2. **Task 2: Glyph path extraction + static (non-animated) render** - `1d49c77` (feat)
3. **Task 3: Glyph extraction sanity tests** - `a6852e2` (test)

_Note: Task 3 was `tdd="true"` but tested a contract already implemented in Tasks 1-2 per the plan's own explicit task sequencing (font bundling → extraction/render → sanity tests) — no separate RED/GREEN pair was applicable since no new production behavior was introduced by the test task itself._

## Files Created/Modified
- `Islet/Fonts/DancingScript-Variable.ttf` - OFL-licensed variable-weight script font (133,636 bytes, verified TrueType)
- `Islet/Fonts/DancingScript-OFL.txt` - License provenance text, committed for compliance record
- `Islet/Notch/SignatureHeading.swift` - Font loader + glyph extraction + standalone static-render View
- `IsletTests/SignatureHeadingTests.swift` - Sanity tests on `glyphPaths(for:font:)` count/non-emptiness and `totalWidth(for:)` accumulation

## Decisions Made
- Font sourced directly from the previously-verified `google/fonts` repo path (`ofl/dancingscript/`) rather than any third-party mirror, matching the threat model's T-36-05 mitigation
- `SignatureHeading` deliberately left as a `struct: View` with `internal` static factory functions (`loadSignatureFont`, `glyphPaths`, `totalWidth`) — mirrors `EqualizerBars.makeProfiles()`'s established testability precedent in this codebase

## Deviations from Plan

None - plan executed exactly as written. (One in-flight self-correction: the `Color.orange` fill call was written as `.color(Color.orange)` rather than an inferred `.color(.orange)` shorthand, purely to satisfy the plan's literal acceptance-criteria grep — no behavior difference, not a deviation.)

## Issues Encountered
- The worktree branch (`worktree-agent-a02814bf4b8baabb5`) was created from a stale base commit that predated all of Phase 36's planning work (font-file, PLAN.md, UI-SPEC.md, etc. did not exist on disk). Resolved with a pure fast-forward merge (`git merge --ff-only gsd-new-project-setup`) — safe because the worktree branch was a strict ancestor of `gsd-new-project-setup` with zero divergent commits of its own (verified via `git merge-base`), so no work was lost or overwritten.

## User Setup Required

None - no external service configuration required. The font is bundled directly in the app; no Apple Developer/API keys involved.

## Next Phase Readiness
- Plan 36-04 can proceed directly: `SignatureHeading.glyphPaths(for:font:)` and `.totalWidth(for:)` are the stable contract to animate with `.trim(from:to:)` per-glyph, staggered 0.2s per character index, then wire into `onboardingWelcomeStep`
- No blockers. `NotchPillView.swift` confirmed untouched by this plan (verified via acceptance-criteria grep before and after each task)

---
*Phase: 36-cosmetic-restyles-signature-animation*
*Completed: 2026-07-16*

## Self-Check: PASSED

All created files verified present on disk; all 4 task/plan commits (`746d78b`, `1d49c77`, `a6852e2`, `3c5ae36`) verified present in `git log`.
