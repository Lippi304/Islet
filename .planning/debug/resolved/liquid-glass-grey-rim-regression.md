---
status: resolved
trigger: "Liquid Glass Material (Phase 35) rendert im Screenshot nur als schwarze Pille mit grauem Rand — kein Glass-Look, keine Transparenz, kein chromatischer Fringe sichtbar am Rand. User lehnt das explizit ab, obwohl Runde 4 gerade als 'approved' bestätigt wurde."
created: 2026-07-16
updated: 2026-07-16T15:53:00Z
---

## Symptoms

expected: |
  Collapsed pill / expanded island shows a dark, mostly-opaque glass surface with the
  desktop only bleeding through as a faint, narrow, COLORED rim-light (chromatic fringe)
  right at the rounded edge — matching reference-transparency-target.png. This is exactly
  what the round-4 on-device UAT (Plan 35-12) was just approved against.
actual: |
  User-supplied screenshot (running via Xcode Cmd-R) shows a flat black pill/island with
  a plain, uncolored, flat GREY border/rim — no chromatic fringe color, no visible
  desktop bleed-through, nothing reading as "glass". User's exact words: "Das ist einfach
  grauer rand nix mit liquid glass also überhaupt nicht. Irgendwas machst du gewaltig
  falsch."
errors: None reported — this is a visual/rendering regression, not a crash or build failure. Both post-fix builds (xcodebuild -scheme Islet -configuration Debug build) succeeded.
timeline: |
  Round-4 UAT (Plan 35-12) was approved by the user via AskUserQuestion checkpoint,
  reportedly showing the correct dark-center/narrow-colored-rim look. Immediately after
  approval, the orchestrator ran a code review (35-REVIEW.md) which found 1 critical +
  2 warning findings, ALL in files touched by this phase:
    - c4f5b94 "fix(35): gate Settings window Liquid Glass background on materialStyle"
      (Islet/SettingsView.swift only — should be unrelated to the island shader)
    - 9401654 "refactor(35): share liquidGlassEdgeOpacity argument list, hoist shape
      locals" (Islet/Notch/NotchPillView.swift — DIRECTLY touches the island's Liquid
      Glass rendering: introduced `liquidGlassOpacityShader(shape:size:parameters:
      edgeOpacity:centerOpacity:)` shared helper replacing a duplicated inline Shader
      construction, and replaced `NotchShape()` literal re-constructions with a single
      hoisted `let shape = ...` reused by both the fill and the liquidGlassEffectLayer
      overlay call sites in `collapsedIsland` and `mediaWingsOrToast`.)
  The orchestrator only re-verified c4f5b94 on-device (user checked Settings window
  background only, confirmed working) — 9401654 was NEVER re-verified on-device on the
  actual island/pill appearance before phase 35 was marked complete. This screenshot is
  the first on-device look at the island since 9401654 landed.
reproduction: |
  Launch Islet via Xcode (Cmd-R, Debug build), hover/expand the notch to the Home view.
  Grey border appears immediately — user did not report any special steps.

## Leading Hypothesis

The WR-01 refactor in commit 9401654 (`liquidGlassOpacityShader` shared helper) most
likely introduced an argument-order or type regression relative to the original
hand-inlined `Shader(...)` construction it replaced — the original code (pre-refactor)
was confirmed working at round-4 UAT approval; this is the only commit that touches the
Metal shader argument wiring for the island's frost/rim-mask layers between the approved
state and this screenshot. A Metal `[[stitchable]]` argument-order mismatch fails
SILENTLY at runtime (wrong values bound to wrong parameters, no compile error, no crash)
— exactly the kind of failure mode the review itself warned about when flagging WR-01 as
a maintenance risk in the first place.

Secondary/alternative hypothesis: the WR-02 shape-hoisting change (`let shape = ...`
reused across `.fill(...)` and `liquidGlassEffectLayer(shape: shape, ...)`) could have
subtly changed evaluation timing/identity in a way that affects the `.colorEffect(rimMask)`
masking, though this seems less likely since NotchShape should be a plain Equatable value
type.

## Current Focus

reasoning_checkpoint:
  hypothesis: |
    Wrong-checkout hypothesis REFUTED by user (confirmed algiers/Islet.xcodeproj was open).
    NEW root cause: `collapsedFill` (NotchPillView.swift ~line 2213), a `#if DEBUG` dev
    affordance dating back to Phase 2 (commit 95168a3, long before Phase 35), hardcodes
    `Color.red.opacity(0.6)` as the COLLAPSED pill's base fill in every DEBUG build,
    completely bypassing `islandFill` (and therefore the user's `.liquidGlass`
    materialStyle selection) for the collapsed pill specifically. `liquidGlassEffectLayer`
    still renders on top (it only checks `materialStyle`, independent of `collapsedFill`),
    but it composites its dark frost + rim-masked chromatic-fringe + white-wash layers
    against this light red/vibrancy-adapted `.ultraThinMaterial` backdrop instead of the
    dark `gradientMaterial` backdrop every UAT round was actually tuned/tested against.
    The `.blendMode(.screen)` fringe passes + white wash (already diagnosed in round 3 as
    "can only lighten, never darken") wash this lighter, non-black backdrop toward flat
    grey — same underlying mechanism as round 3's rejection, just newly exposed because
    round-4 testing verified the EXPANDED island, never the DEBUG-only collapsed pill.
  confirming_evidence:
    - "`collapsedFill` (NotchPillView.swift line 2213) `#if DEBUG` branch returns `AnyShapeStyle(Color.red.opacity(0.6))` unconditionally, `#else` branch returns `islandFill`. `git log -L` on this property traces the red-tint override back to commit 95168a3 (Phase 2, 'morph NotchPillView via matchedGeometryEffect') — it predates Phase 35 (Liquid Glass) by dozens of phases and was never touched/reconsidered when GLASS-01 was implemented."
    - "`collapsedIsland` (line 717-747) calls `.fill(collapsedFill)` — NOT `.fill(islandFill)` — then separately `.overlay(liquidGlassEffectLayer(...))`. `liquidGlassEffectLayer`'s only gate is `if materialStyle == .liquidGlass` (line 348) — it does not know or care what `collapsedFill` returned, so in DEBUG it always renders the full glass stack on top of the red tint, never the intended dark gradientMaterial."
    - "By contrast, `blobShape` (used for the expanded Home view / Now Playing wings / all `mediaWingsOrToast` call sites) calls `.fill(islandFill)` directly (line 1679) with NO DEBUG override — the expanded island has always rendered against the correct dark backdrop."
    - "All 3 rejected UAT rounds' verbatim user feedback in 35-UAT.md describes 'island'/'expanded island' screenshots ('Es ist immer noch so hell' / 'so komisch silbern' — round 2/3), never 'Pille'. The user's current report says 'schwarze Pille mit grauem Rand' (pill, not island) — this project's own vocabulary (CLAUDE.md) distinguishes the compact 'pill' from the expanded 'island', consistent with this being the first time the collapsed pill was actually screenshotted with Liquid Glass selected."
    - "35-12-SUMMARY.md (round-4 approval) records a <5min verification-only checkpoint claiming '7 checks passed' including collapsed-pill wing subtlety, but 35-UAT.md itself was never updated past round 3 — the round-4 approval detail (what was actually looked at) isn't independently documented, consistent with the collapsed pill's DEBUG-only red-tint contamination being missed in a fast approval pass."
    - "Re-read commit 9401654 (WR-01/WR-02) in full via `git show`: both the shader-argument hoist and the shape-hoist are byte-identical value transformations (same literal args before/after in both `collapsedIsland` and `mediaWingsOrToast`) — reconfirms this commit is a functional no-op, not the cause."
  falsification_test: "If the user confirms the screenshot is actually of the EXPANDED island/Home view (not the small collapsed pill), or if temporarily patching collapsedFill to return islandFill in DEBUG and rebuilding still shows a flat grey rim on the collapsed pill, this hypothesis is refuted and investigation must look elsewhere (e.g. actual Xcode DerivedData staleness, or a real distortionEffect/colorEffect runtime failure)."
  fix_rationale: "Root cause is the collapsed pill's backdrop color, not the shader math (already proven correct) or the round-4 rim-masking fix (already proven correct against the dark backdrop it was tuned for). Minimal fix: make collapsedFill respect materialStyle == .liquidGlass even in DEBUG (return islandFill in that one case), keeping the red dev-tint only for .gradient/.solidBlack where a flat color swap is harmless. This restores the same dark backdrop the expanded island (and every approved UAT round) already renders against, without touching any shader/parameter code that UAT already validated."
  blind_spots: "Have not directly seen the user's screenshot pixel-for-pixel to 100% confirm it's the collapsed pill rather than expanded island. Have not yet rebuilt+visually reverified on-device (requires human checkpoint, per fix_and_verify protocol) — self-verification is limited to a successful compile + code-path tracing."

next_action: |
  SUPERSEDED by Round 3 (below) — the round-1 fix (collapsedFill DEBUG-tint) is still
  correct and kept, but round-2's on-device re-verification was overtaken by the user's
  scope pivot before it happened. See "## Round 3 — Scope-changing user decision" for the
  current next_action.

## Round 2 — Expanded island still grey, no color fringe (collapsedFill fix insufficient)

reasoning_checkpoint:
  hypothesis: |
    User's new screenshot is confirmed to be the EXPANDED island (Home view), which
    already renders via `islandFill` with no DEBUG override — so the collapsedFill fix
    was correct but did not address this. Root cause is a genuine parameter-tuning gap:
    LiquidGlassParameters.expanded/.collapsed's redOffset/greenOffset/blueOffset are far
    too small relative to the rim mask band width (edgeSize + blurWidth) to produce a
    visually separated colored fringe — nearly the entire visible rim band shows all 3
    R/G/B fringe passes overlapping, and `.blendMode(.screen)` on 3 overlapping saturated
    colors at the same opacity produces white/grey, not color. Only a thin sliver at the
    very outer edge (where channels haven't all "caught up" yet) would show partial color,
    and that sliver is itself softened away by blurWidth's smoothstep. This reproduces the
    exact "flat grey rim, no chromatic fringe" the user reports, on a genuinely dark center
    (which the round 3/4 frost-masking fix DID correctly deliver).
  confirming_evidence:
    - "`liquidGlassEffectLayer` (NotchPillView.swift lines 369-398): each fringe pass fills
      the WHOLE shape with a solid saturated color (Color.red/green/blue.opacity(fringeOpacity)),
      distorted by a per-channel shader whose only difference is distortionScale+offset, then
      masked by the SAME rimMask (t=0 at boundary → mask=1, t=1 at edgeSize+blurWidth inward →
      mask=0) and screen-blended. Where all 3 channels are simultaneously non-zero (true for
      most of the mask's visible band, since only the OUTERMOST few points differ in warped
      boundary position between channels), screen-blending 3 same-opacity saturated primaries
      necessarily approaches white/grey."
    - "Computed rim-band width vs. channel-offset magnitude for .expanded (size min=144pt,
      borderWidth=0.05, blurWidth=2.5): band = 144*0.05 + 2.5 = 9.7pt. blueOffset=2.5pt is only
      ~26% of that band; greenOffset=1.25pt is ~13%. So at best ~26% of the visible rim band
      could show any channel separation at all, and that thin band is itself blurred by the
      same smoothstep/blurWidth used for the falloff — leaving no perceptible color, only the
      dominant ~74% full-overlap (white/grey) zone. Same order-of-magnitude ratio for .collapsed
      (band = 38*0.07 + 1.2 = 3.86pt; blueOffset=1pt is ~26%)."
    - "git log -p --follow on LiquidGlassShader.swift shows redOffset/greenOffset/blueOffset
      have been IDENTICAL (0/0.5/1 collapsed, 0/1.25/2.5 expanded) since the very first
      scaffolding commit ec71f57 (Plan 35-02, before ANY on-device UAT ran) — never touched
      by the round-2 (8957ef8) or round-3 (0d19a37) retunes, which DID change borderWidth/
      blurWidth/edgeOpacity/centerOpacity/backgroundOpacity twice each. The file's own D-04
      comment says these are UAT-tunable starting points 'expected to be adjusted during
      Plan 35-03/35-05's UAT' — they never were, across 4 rounds."
    - "Round-4's own remediation notes (D-16/D-17/D-18, lines 301-320) explicitly anticipated
      this exact failure mode as a follow-up tuning knob: 'if fringe reads as too faint after
      masking, tune fringeOpacity/offsets upward' — confirming this is expected, not-yet-done
      tuning work, not a code regression."
  falsification_test: |
    If, after increasing greenOffset/blueOffset (and fringeOpacity) and rebuilding, the user
    still reports a flat grey rim with zero visible color separation, this hypothesis is
    refuted and the investigation must look at whether .blendMode(.screen) itself (rather
    than e.g. .colorDodge or additive) is fundamentally the wrong compositing choice for 3
    same-opacity full-saturation layers, regardless of offset magnitude.
  fix_rationale: |
    Increasing the per-channel offset separation (without touching borderWidth/blurWidth/
    edgeOpacity/centerOpacity — the already-UAT-approved dark-center frost masking) makes a
    much larger fraction of the visible rim band show genuine non-overlapping channel content
    instead of full-overlap white/grey, while the innermost sliver near the mask's t=1 falloff
    naturally stays white (matches D-17's "white wash reads as rim highlight" intent). This
    addresses the root cause (insufficient spatial fringe separation) rather than a symptom.
  blind_spots: |
    Cannot render/screenshot Metal shader output myself — this is a reasoned parameter change
    based on the geometry/compositing math, not a directly observed on-device result. Exact
    tuned values are a starting point, likely to need one more human on-device iteration.
    Have not touched fringeOpacity dramatically to avoid overcorrecting into a gaudy rainbow.

next_action: |
  Increase redOffset/greenOffset/blueOffset (and modestly fringeOpacity) in both
  LiquidGlassParameters.collapsed and .expanded so channel separation covers a much larger
  fraction of the rim mask band, then rebuild and request on-device re-verification of BOTH
  the collapsed pill and expanded island for visible colored rim fringe.

## Round 3 — Scope-changing user decision: pivot to native SwiftUI Liquid Glass (macOS 26+)

reasoning_checkpoint:
  hypothesis: |
    NOT a bug hypothesis — a user-directed scope pivot. After round 2's fix (widened
    chromatic-fringe offsets) was applied but before its on-device re-verification, the
    user reviewed github.com/callstack/liquid-glass (a wrapper around Apple's REAL native
    Liquid Glass API) and concluded the actual root cause spanning all 4 UAT rounds + 2
    debug rounds is architectural, not a specific tunable bug: the project has been
    hand-approximating Apple's real "Liquid Glass" material with a custom Metal shader
    (warp distortion + RGB chromatic-fringe screen-blend + edge-opacity masking), which is
    inherently fragile to get pixel-right — every round fixed one visible symptom
    (washout, wrong backdrop, insufficient fringe separation) only to reveal the next.
    Apple ships the REAL thing natively as of macOS/iOS 26 via SwiftUI's `.glassEffect(_:in:)`
    modifier, and the build machine already runs macOS 26 (Tahoe). User explicitly chose
    the RECOMMENDED option: availability-gate the native effect on macOS 26.0+, keep the
    existing custom shader stack completely unchanged as the <macOS 26 fallback. Round 2's
    fringe-offset widening remains correct and necessary for that fallback path — it is
    NOT reverted, only superseded as the primary rendering path on this machine.
  confirming_evidence:
    - "User-supplied decision (DATA_START/DATA_END block, this session): explicit pivot
      instruction citing Apple's own docs (developer.apple.com/documentation/swiftui/view/glasseffect(_:in:),
      developer.apple.com/documentation/swiftui/glass) confirming `.glassEffect(_:in:)` is
      available macOS 26.0+/iOS 26.0+ and renders a real system Liquid Glass material."
    - "WebSearch confirmed the exact API surface: `func glassEffect<S: Shape>(_ glass: Glass = .regular, in shape: S = DefaultGlassEffectShape, isEnabled: Bool = true) -> some View`, with `Glass.regular.tint(Color)` for dark tinting — matches the syntax the user asked to be verified rather than guessed."
    - "`NotchShape` (Islet/Notch/NotchShape.swift:9) already conforms to `Shape` (`struct NotchShape: Shape`), confirmed via grep before implementing — no protocol-conformance blocker for the `in shape:` generic parameter."
    - "All 4 call sites (collapsedIsland, blobShape, wingsShape, mediaWingsOrToast) share exactly one function, `liquidGlassEffectLayer(shape:size:parameters:)` (NotchPillView.swift) — confirmed via grep — making it the single architecturally-correct gate point for both the native and fallback paths."
  falsification_test: |
    If `xcodebuild -scheme Islet -configuration Debug build` fails to type-check either the
    `#available(macOS 26.0, *)` native branch or the `else` fallback branch, the API surface
    was guessed incorrectly and must be re-verified against Apple docs before proceeding.
    (Build succeeded — see verification below. On-device visual confirmation is separate and
    still pending, since native Liquid Glass rendering can only be judged on the real screen.)
  fix_rationale: |
    Gating inside `liquidGlassEffectLayer` itself (rather than duplicating the gate at all 4
    call sites) is the minimal-diff, single-source-of-truth location: every call site already
    routes through this one function, so the pivot is invisible to callers. The custom shader
    stack (now renamed `legacyLiquidGlassEffectLayer`, body byte-for-byte unchanged, including
    round 1's collapsedFill DEBUG-tint fix and round 2's widened RGB offsets which it still
    depends on via `islandFill`/`LiquidGlassParameters`) is preserved verbatim as the fallback
    for <macOS 26 — this addresses the user's explicit "do not delete or break this path"
    requirement, not just the symptom on this one machine.
  blind_spots: |
    Tint alpha (`Color.black.opacity(0.7)`) is a starting point by direct analogy to the
    existing shader's centerOpacity (0.90/0.92) and D-15's "allowed as dark as .solidBlack"
    intent, not an on-device-verified value — same "tunable starting point" caveat every
    other constant in this file carries. Cannot visually render/screenshot native Liquid
    Glass myself; this is architecturally correct and compiles, but the actual on-screen
    look (tint darkness, whether the system's own chromatic/refraction behavior reads as
    "glass" per reference-transparency-target.png) is unverified until the on-device
    checkpoint below.

next_action: |
  Awaiting human on-device verification (Cmd-R from algiers/Islet.xcodeproj, macOS 26/Tahoe
  build machine): confirm the collapsed pill AND expanded island now render via the native
  system Liquid Glass material (not the custom shader) and that the dark tint reads
  correctly against reference-transparency-target.png. If the tint is too light/dark or the
  native material's own behavior doesn't match expectations, the tunable is
  `Color.black.opacity(0.7)` in `liquidGlassEffectLayer` (NotchPillView.swift).

## Evidence

- timestamp: 2026-07-16T15:20:00Z
  checked: Diff of commit 9401654 (liquidGlassOpacityShader refactor) against its parent, cross-referenced with LiquidGlassShader.metal's liquidGlassEdgeOpacity signature
  found: Argument order and values are byte-identical before/after the refactor (size, topCornerRadius, bottomCornerRadius, borderWidth, blurWidth, edgeOpacity, centerOpacity) — matches the Metal function signature exactly. 35-REVIEW.md independently confirms no argument-order mismatch.
  implication: Leading hypothesis (WR-01 argument desync) is REFUTED — this commit cannot be the cause.
- timestamp: 2026-07-16T15:24:00Z
  checked: c4f5b94 diff (CR-01 Settings fix)
  found: Only modifies Islet/SettingsView.swift's window `.background`, gated on materialStyle for the Settings window chrome only. Never touches NotchPillView.swift or any island rendering.
  implication: Ruled out as unrelated to the island/pill symptom.
- timestamp: 2026-07-16T15:28:00Z
  checked: `defaults read com.lippi304.islet theming.materialStyle`
  found: Returns "liquidGlass" — the persisted preference on this machine is correct.
  implication: Rules out the alternate theory that NotchWindowController.currentTheme()'s `?? .gradient` fallback (a third, independently-hardcoded default location not covered by D-06's two known locations) was silently selecting Gradient at runtime.
- timestamp: 2026-07-16T15:35:00Z
  checked: /Users/lippi304/conductor/repos/notch (separate git worktree/checkout, branch `main`, HEAD 1a29925) vs /Users/lippi304/conductor/workspaces/notch/algiers (this workspace, branch gsd-new-project-setup, HEAD b5f0efb)
  found: main's NotchPillView.swift/ActivitySettings.swift have ZERO Liquid Glass code and no `materialStyle`/`MaterialStyle` concept at all — predates Phase 27. `git merge-base main gsd-new-project-setup` equals main's own HEAD, confirming main is a strict ancestor (genuinely behind), not a conflicting branch. main's collapsedIsland fill is plain `.fill(Color.black)`.
  implication: A Cmd-R build from the main repo checkout would render exactly what the user described — a flat black pill with only an antialiased/grey edge, no gradient, no glass, no fringe. This is the most likely root cause: wrong Xcode project was open/run.

## Eliminated

- hypothesis: 9401654's liquidGlassOpacityShader refactor (WR-01) desynced the shader argument order from the original inline construction
  evidence: Diff shows byte-identical argument order/values before and after; matches Metal function signature; independently confirmed by 35-REVIEW.md
  timestamp: 2026-07-16T15:20:00Z
- hypothesis: 9401654's shape-hoisting (WR-02) changed evaluation timing/identity affecting the rim mask
  evidence: NotchShape() is a plain value-type struct constructed identically with no arguments in both the before/after versions; no functional difference possible
  timestamp: 2026-07-16T15:22:00Z
- hypothesis: c4f5b94 (Settings background gate) leaked into island rendering
  evidence: Diff confined entirely to SettingsView.swift's window background; zero overlap with NotchPillView.swift
  timestamp: 2026-07-16T15:24:00Z
- hypothesis: NotchWindowController.currentTheme()'s `?? .gradient` fallback (undiscovered third hardcoded default location) resolved materialStyle to .gradient instead of .liquidGlass at runtime
  evidence: `defaults read com.lippi304.islet theming.materialStyle` returns "liquidGlass" on this machine — the key is present and correct
  timestamp: 2026-07-16T15:28:00Z

## Resolution
root_cause: |
  ROUND 3 REFRAMING (user-directed, supersedes-in-priority but does not invalidate rounds
  1-2 below): the deeper root cause across all 4 UAT rounds + 2 debug rounds is that the
  custom Metal shader stack is a hand-built APPROXIMATION of Apple's real "Liquid Glass"
  material (warp distortion + RGB chromatic-fringe screen-blend + edge-opacity masking),
  which is inherently fragile to get pixel-right — each round fixed one visible symptom
  only to reveal the next (wrong backdrop, then insufficient fringe separation, then...).
  Apple ships the REAL Liquid Glass material natively as of macOS/iOS 26 via SwiftUI's
  `.glassEffect(_:in:)` modifier. User explicitly chose to pivot to the native API on
  macOS 26.0+ (this build machine's actual OS) rather than continue tuning the shader.

  TWO independent issues, found in sequence (rounds 1-2, still valid for the <macOS 26
  fallback path, which retains the full custom shader stack unchanged):
  1. `collapsedFill` (NotchPillView.swift), a `#if DEBUG` dev affordance dating back to
     Phase 2 (commit 95168a3), hardcoded `Color.red.opacity(0.6)` as the COLLAPSED pill's
     base fill in every DEBUG build, bypassing the user's `.liquidGlass` selection for that
     one view. Fixed round 1 (see below) — but the user's follow-up screenshot proved this
     was NOT the whole story, since it showed the EXPANDED island (which never had this
     bug) still reading as flat grey.
  2. LiquidGlassParameters.collapsed/.expanded's redOffset/greenOffset/blueOffset — the
     values controlling how far apart the 3 chromatic-fringe passes' warped edges land —
     were frozen at their original Plan 35-02 scaffolding values across all 4 UAT rounds,
     never retuned when round 3 (D-12–D-15) shrank borderWidth/blurWidth (the rim band the
     offsets must spatially separate within). Computed against the actual rim-band width
     (edgeSize + blurWidth), the old blueOffset covered only ~26% of the band, so ~74% of
     the visible rim showed all 3 R/G/B fringe passes fully overlapping — which
     `.blendMode(.screen)` renders as white/grey, not color. This is why a genuinely dark
     center (correctly delivered by the round-3/4 frost-masking fix) still read as
     "flat grey rim, zero liquid glass" once the collapsedFill bug was ruled out.
fix: |
  1. NotchPillView.swift `collapsedFill`: `#if DEBUG` branch now returns `islandFill` when
     `materialStyle == .liquidGlass`, keeping the red dev-tint only for `.gradient`/
     `.solidBlack`.
  2. LiquidGlassShader.swift `LiquidGlassParameters.collapsed`/`.expanded`: widened
     greenOffset/blueOffset (collapsed 0.5/1 → 1.4/2.8; expanded 1.25/2.5 → 3.5/7) so
     channel separation covers most of the rim mask band instead of ~26% of it, and
     nudged fringeOpacity up (collapsed 0.15→0.20, expanded 0.20→0.25) to keep the
     now-thinner per-channel color visible against the dark frost. No `.metal` file,
     `.blendMode`, borderWidth/blurWidth/edgeOpacity/centerOpacity changes — the
     already-UAT-approved dark-center masking is untouched.
  3. ROUND 3 (pivot): `liquidGlassEffectLayer` (NotchPillView.swift) now branches on
     `#available(macOS 26.0, *)`. Native branch: `Color.clear.frame(...).glassEffect(
     .regular.tint(Color.black.opacity(0.7)), in: shape).allowsHitTesting(false)` — renders
     Apple's real system Liquid Glass material clipped to `NotchShape`, dark-tinted per
     D-15's "allowed as dark as .solidBlack" intent. Fallback branch (`else`): the ENTIRE
     pre-existing shader stack (warp distortion, frost layer, 3 chromatic-fringe
     screen-blend passes, rim mask, white wash) moved verbatim into a new
     `legacyLiquidGlassEffectLayer` function, byte-for-byte unchanged from rounds 1-2 —
     still depends on `islandFill`/`collapsedFill` (round 1 fix) and
     `LiquidGlassParameters` (round 2 fix), both kept intact. Single gate point covers all
     4 call sites (collapsedIsland, blobShape, wingsShape, mediaWingsOrToast) since they
     all route through `liquidGlassEffectLayer`.
verification: |
  Rounds 1-2 self-verified: `xcodebuild -scheme Islet -configuration Debug build` succeeds.
  Round 3 self-verified: `xcodebuild -scheme Islet -configuration Debug build` succeeds
  with BOTH the `#available(macOS 26.0, *)` native branch and the `else` fallback branch
  type-checking (Swift compiles all `#available` branches regardless of the running OS).
  HUMAN-CONFIRMED on-device (Cmd-R from algiers/Islet.xcodeproj, macOS 26/Tahoe build
  machine): "Sieht jetzt nach echtem Liquid Glass aus" — dark, transparent glass matching
  reference-transparency-target.png. Native `.glassEffect(_:in:)` path confirmed working
  on both the collapsed pill and expanded island. Fix confirmed end-to-end.
files_changed:
  - Islet/Notch/NotchPillView.swift
  - Islet/Notch/LiquidGlassShader.swift
