---
status: deferred
trigger: "Während der Animation beim Switch zur anderen Seite (Tab-Wechsel) oder allgemein beim Island-Expandieren ist der schwarze Hintergrund sichtbar und nicht das Liquid Glass."
created: 2026-07-16
updated: 2026-07-16T17:10:00Z
---

## Symptoms

expected: |
  During ANY transition (collapse<->expand morph via matchedGeometryEffect, or tab
  switching within the expanded island e.g. Home -> Tray), the island shape should
  continuously show the narrow native-glass rim (LiquidGlassRimRingShape +
  .glassEffect()) at every frame of the animation, with the dark solid islandFill
  center underneath — same look as the settled/idle state, just animating size/position.
actual: |
  User-supplied screenshot, taken mid-transition (switching to the Tray tab, "No files
  yet" empty state, notch/island still mid-animation per the visible blur/motion cues
  in the screenshot), shows the island as flat, uniform dark/black with NO visible rim
  glass shimmer anywhere along the edge — not even at the rounded corners where the
  ring should be. The rim glass effect appears to be entirely absent DURING the
  animation, only appearing (per prior confirmation) once things settle/are idle.
errors: None reported — visual-only, not a crash.
timeline: |
  This is the FIRST time the native `.glassEffect()` pivot (D-20/D-20a, commits bc04457
  and f107faa) has been screenshotted mid-animation — all prior on-device
  confirmations ("Sieht jetzt nach echtem Liquid Glass aus", "Passt jetzt so") were
  given while looking at the SETTLED/idle state (collapsed pill or fully-expanded
  island, not mid-transition). This may be a gap in what was actually tested, not a
  new regression from unrelated code.
reproduction: |
  Launch Islet (Cmd-R), trigger any island transition — collapse<->expand hover, or
  switching between tabs (Home/Tray/Calendar/Weather) within the expanded island —
  and observe the shape's rim DURING the animation itself, not just before/after.

## Leading Hypothesis

SwiftUI's native `.glassEffect(_:in: someShape)` may not correctly re-render/re-composite
its glass material on every frame when the `in:` shape parameter is a custom `Shape`
whose geometry (via the base `NotchShape`'s `topCornerRadius`/`bottomCornerRadius` and the
overall frame size) is actively changing across an animated transition — possibly requiring
`GlassEffectContainer`/`.glassEffectID(_:in:)`-based transition support (per Apple's Liquid
Glass migration guidance) rather than a bare `.glassEffect(_:in:)` call with a continuously
mutating custom Shape. Under this hypothesis, the system effect may fall back to no
material (transparent -> shows the underlying dark `islandFill` fill with zero glass
compositing) while a geometry-driven transition is in flight, then "catch up" and render
correctly once the transition settles into a steady frame.

Secondary hypothesis: this could simply be a performance/timing artifact of how
`UIVisualEffectView`-backed materials (which `.glassEffect` is built on per
`callstack/liquid-glass`'s LiquidGlassView.swift, which wraps `UIGlassEffect` on a
`UIVisualEffectView`) refresh during CPU/GPU-heavy transition frames — i.e. not a
structural incompatibility but a frame-budget/timing issue during the spring animation.

## Current Focus

status: deferred
hypothesis: Root cause (bare `.glassEffect()` torn down/rebuilt on every switch-case
  change, so it renders no glass material during the add/remove transition) is still
  the likely explanation, but the documented fix mechanism (GlassEffectContainer +
  .glassEffectID) is empirically broken for this view's nesting — it made the whole
  island read as frosted glass at all times instead of fixing the rim-only flicker.
next_action: None — deferred by user decision. A future attempt needs real on-device
  iteration (this environment cannot iterate blind) and should NOT repeat the
  GlassEffectContainer-wraps-the-whole-presentationSwitch structure; see Eliminated.

## Evidence

- timestamp: 2026-07-16T16:40
  checked: Apple developer docs (glassEffect(_:in:), GlassEffectContainer, glassEffectID(_:in:), GlassEffectTransition) via web search; NotchPillView.swift body/switch structure and all 4 liquidGlassEffectLayer call sites.
  found: |
    `.glassEffect()` is documented by Apple as backed by a CABackdropLayer that is
    expensive to composite (3 offscreen textures). Apple explicitly ships
    `GlassEffectContainer` + `.glassEffectID(_:in:)` + `GlassEffectTransition`
    specifically for "views conditionally shown/hidden to trigger morphing" and to
    describe "changes to apply when a glass effect is ADDED or REMOVED from the view
    hierarchy." NotchPillView.body has ONE top-level `switch presentation { ... }`
    (line ~668) and `liquidGlassEffectLayer` is invoked from 4 DIFFERENT case bodies
    (collapsedIsland ~796, mediaExpanded-family ~1744/1880/1952). Every collapse<->
    expand transition AND every tab switch (Home/Tray/Calendar/Weather) changes which
    switch case is active, which means the `.glassEffect(...)` view in the old case is
    torn down and a brand-new one in the new case is built — there is no
    GlassEffectContainer or glassEffectID anywhere in the file (grep confirmed only
    bare `.glassEffect(...)` calls exist).
  implication: |
    Bare `.glassEffect(_:in:)` on views that are added/removed by a switch is exactly
    the unsupported/default-transition path Apple's own container+ID API exists to fix.
    Without it, SwiftUI's default add/remove handling for a CABackdropLayer-backed
    effect plausibly renders only the flat `.tint(Color.black.opacity(0.35))` color
    while the live backdrop blur has not yet materialized — matching the reported
    "flat black, no glass" appearance DURING transitions, and "looks right" once
    settled (no more add/remove churn).
- timestamp: 2026-07-16T17:05
  checked: On-device rebuild after reverting GlassEffectContainer/.glassEffectID back to
    the bare .glassEffect() call, per user request.
  found: |
    User confirmed the whole-island milky/frosted regression is gone — island back to
    the previously-known-good look (rim-only glass, dark center visible). User was then
    asked whether to keep chasing the original momentary black-during-transition
    flicker or accept it as a known cosmetic limitation for now, and chose to accept it
    for now, not pursue further today.
  implication: |
    The regression from the round-1 fix attempt is fully undone. The ORIGINAL trigger
    symptom (momentary flat-black rim during transitions) is UNCHANGED from before this
    debug session — never fixed, only investigated and root-caused. User has explicitly
    accepted this as a known, deferred cosmetic limitation rather than continuing to
    iterate blind in this session.

## Eliminated

- hypothesis: "Wrapping presentationSwitch in a shared GlassEffectContainer + tagging the rim
  view with .glassEffectID('islandRim', in: ns) fixes the flat-black-during-transition bug
  without side effects, per Apple's documented container/ID semantics."
  evidence: |
    User on-device screenshot + explicit German feedback after the round-1 fix: the ENTIRE
    island (not just the thin rim) rendered as uniform milky/frosted glass at all times,
    with content underneath only visible as blurred smudges — worse than the original bug
    (previously only the settled/idle state was correct; now nothing is). Web search of
    Apple's GlassEffectContainer docs confirms this contradicts documented behavior (only
    `.glassEffect()`-tagged views should receive the glass look), meaning this codebase's
    specific nesting triggers an undocumented/unpredictable interaction not safely
    diagnosable without on-device iteration. REVERTED — do not repeat this exact structure
    (GlassEffectContainer wrapping the entire multi-case presentationSwitch) in a future
    attempt; if retried, scope the container much narrower (e.g. only inside
    liquidGlassEffectLayer itself) and iterate on-device incrementally, not in one blind
    jump.
  timestamp: 2026-07-16T16:50
- hypothesis: "Original root cause: bare .glassEffect() has no support for add/remove morphing
  across switch-case teardown, causing the momentary flat-black-during-transition symptom."
  evidence: |
    Not disproven — the attempted fix (GlassEffectContainer+glassEffectID) for this exact
    mechanism caused a worse regression, so that specific fix approach is eliminated even
    though the underlying diagnosis may still be correct. Deferred/unresolved rather than
    actively re-attempted this round — see Resolution below.
  timestamp: 2026-07-16T16:50

## Resolution
root_cause: |
  Likely (not fully proven): the native `.glassEffect()` rim overlay in NotchPillView is
  torn down and rebuilt on every switch-case change (collapse<->expand, and each tab
  switch), since `liquidGlassEffectLayer` is called from 4 separate case bodies under one
  top-level `switch presentation`. Apple's docs describe exactly this "conditionally
  shown/hidden" scenario as needing `GlassEffectContainer` + `.glassEffectID(_:in:)` for
  correct add/remove transition behavior; a bare `.glassEffect(_:in:)` on a view that is
  added/removed plausibly falls back to rendering only its flat `.tint(...)` color until
  the live backdrop blur catches up post-settle, matching the reported symptom.
fix: |
  NOT APPLIED. Round 1 attempted the documented fix (GlassEffectContainer +
  .glassEffectID wrapping the entire presentationSwitch) but it caused a confirmed worse
  regression (whole island reads as frosted glass instead of just the rim) and was
  reverted back to the bare, per-call-site `.glassEffect(.regular.tint(...), in:
  LiquidGlassRimRingShape(...))` that was already on-device-confirmed correct at
  idle/settled state before this debug session began. `presentationSwitch` remains
  extracted as a `@ViewBuilder` property (harmless refactor, no behavior change).
  User confirmed the revert restores the known-good look and explicitly chose to accept
  the original momentary black-during-transition flicker as a known cosmetic limitation
  for now, rather than pursue a further fix attempt in this session.
verification: |
  On-device confirmed by user: regression from round 1 is gone, island matches
  previously-known-good rendering (rim-only glass, dark center, not milky/frosted). The
  ORIGINAL trigger symptom (brief flat-black rim during transitions) was NOT re-tested/
  re-fixed — user accepted it as a known limitation rather than continuing this session.
files_changed:
  - Islet/Notch/NotchPillView.swift
