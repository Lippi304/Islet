# Phase 25: Visual/Material Theming Redesign - Research

**Researched:** 2026-07-11
**Domain:** SwiftUI custom `Shape` gradient fills + spring animation tuning, inside an existing `NSPanel`/`NSHostingView` notch overlay
**Confidence:** MEDIUM-HIGH (technique confirmed against Apple's documented `ShapeStyle`/`LinearGradient`/`Animation.spring` semantics; exact numeric spring values are inherently an on-device-tuned "feel," never officially published by Apple — flagged ASSUMED where applicable)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Pure black → transparent, no grey tint mixed in (user explicitly confirmed "no" when asked about a lighter grey vs. pure black gradient).
- **D-02:** The gradient stays opaque/near-opaque for most of the shape's height — it should NOT reach near-full transparency. Only the bottom edge fades down to roughly ~50% opacity (Droppy reference screenshot: long solid black stretch, mild transparency only right at the very bottom). This is meaningfully less transparent than a generic "fade to 0%" gradient — err toward "still reads as a solid black shape" over "see-through."
- **D-03 (LOCKED):** The existing per-element accent tinting on activity content (equalizer bars, charging glyph, device battery icon — Phase 6 D-11) is UNTOUCHED by this phase either way, since that's activity-content rendering, already out of scope. But beyond that, this phase introduces NO new color — text/icons on the new gradient chrome stay pure white, nothing tinted.
- **D-04:** VISUAL-03 (Theming Settings section, per-element accent colors, alternate app icon variants) is DESCOPED from Phase 25, deferred to Phase 27 (Settings Sidebar Redesign). Already applied to REQUIREMENTS.md/ROADMAP.md (verified this session: Phase 25's requirement list is VISUAL-01/VISUAL-02 only; VISUAL-03 traces to Phase 27).
- **D-05:** Deliberately slow, not snappy — the slowness itself is what should read as "ultra fluid" even on a 60Hz (non-ProMotion) display. Explicitly slower than the current `response: 0.35` spring in `NotchWindowController.swift`.
- **D-06:** A real overshoot-and-settle bounce — the shape grows slightly LARGER than its actual target size, then springs back down to the correct size — not just a smooth ease-in. Applies to both the hover-widen transition and the full click-to-expand transition (no asymmetry requested).
- **D-07:** Exact spring numbers (response/dampingFraction or equivalent) are Claude's discretion — tune via on-device iteration, matching this project's established pattern (e.g. Phase 18's 5-round on-device toast tuning). Current values (0.35 / 0.65) are the "too fast, not enough overshoot" reference point to move away from, not a starting point to preserve.
- **D-08:** The expanded blob's bottom-corner radius should be noticeably MORE rounded than today's `bottomCornerRadius: 20` (used by `mediaExpanded`/`expandedIsland`/`mediaUnavailable`) — reference: Droppy's expanded view reads distinctly "prall"/rounder at the bottom. Exact value is Claude's discretion / on-device tuning; direction is "significantly rounder," not a specific pt value.
- **D-09 (confirmed, no change needed):** The existing top-corner "flowing merge into the screen edge" look is ALREADY implemented via `NotchShape.swift`'s quad-curve top-corner technique (ISL-01, Phase 1). User confirmed this already matches the Droppy reference — preserve as-is; only the `topCornerRadius` numeric value is open to minor on-device tuning, no new shape mechanism needed.
- **D-10 (confirmed, no change needed):** The collapsed pill's position under the physical camera/notch is already correct — no change.
- **D-11 (confirmed, no change needed):** The collapsed media-glance layout (album art LEFT, animated equalizer bars RIGHT — `mediaWingsRow`) must be preserved exactly as-is; this phase only changes the shape's material/fill, never its content layout.

### Claude's Discretion
- Exact gradient stop positions/percentages (where along the height the ~50% floor is reached) — tune on-device against D-02's "long opaque stretch, mild fade only near the very bottom" description.
- Exact spring response/damping values (D-07).
- Exact bottom-corner-radius value (D-08).
- Exact `topCornerRadius` tuning if any (D-09).
- Whether the gradient is implemented as a SwiftUI `LinearGradient` fill on `NotchShape`, a `.mask`, or another mechanism — technical implementation, not discussed with the user.
- Whether the material appearance needs any special-casing per shape (pill vs. wings vs. expanded blob use different `NotchShape` radius configs today), or whether one shared gradient definition just works — research/planner judgment call.

### Deferred Ideas (OUT OF SCOPE)
- **3-icon view-switcher pill (Home / Tray / third view)** — a small rounded capsule below the main island with 3 tappable icon buttons to switch between "surfaces." User explicitly wants this eventually but flagged it as "later," not part of Phase 25's material/animation-only scope. Likely home: Phase 28 (Calendar Full View).
- **VISUAL-03 (Theming Settings section, per-element accent colors, app icon variants)** — descoped from Phase 25 (see D-04), relocated to Phase 27.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-------------------|
| VISUAL-01 | The collapsed pill, expanded island, and activity wings render with one shared vertical alpha-gradient material — opaque/solid black nearest the physical notch, increasingly transparent toward the bottom edge — replacing the current flat fill. Individual activity content views are unaffected. | Standard Stack (`LinearGradient`/`ShapeStyle`), Architecture Pattern 1 (shared gradient definition + relative `UnitPoint` stops), Code Examples, Common Pitfalls #2 (opacity floor / pure-black discipline) |
| VISUAL-02 | The expand/collapse animation uses a fluid, deliberately-paced spring with a subtle bounce-in on open, matching the iPhone Dynamic Island feel — no dropped frames, no jarring overshoot beyond the intended subtle in-bounce | Standard Stack (`Animation.spring`), Architecture Pattern 2 (controller-owned spring retuning), Code Examples, Common Pitfalls #3/#4 (multi-bounce risk, grace-delay interaction) |
</phase_requirements>

## Summary

This phase is a pure rendering + animation-constant change to code that already exists and already works. There is no new architecture: `NotchPillView.swift`'s four `.fill(Color.black)` call sites become `.fill(LinearGradient(...))` (or a shared computed `ShapeStyle`), and `NotchWindowController.swift`'s two `private let` spring constants (`springResponse`/`springDamping`, 13 confirmed call sites, all reading the same two properties) are retuned. `NotchShape` itself needs no structural change (confirmed by D-09).

The gradient technique is straightforward and low-risk: `LinearGradient` conforms to `ShapeStyle`, so `.fill(LinearGradient(...))` on a `Shape` is both the simplest AND the most performant option (more direct than `.overlay().mask()`, which should be reserved for cases needing an independent masking shape — not needed here). Using relative `UnitPoint`s (`.top`/`.bottom` or explicit `UnitPoint(x:y:)` values) is the load-bearing detail: SwiftUI computes gradient stop positions relative to the shape's *current* bounding box on every frame, so the gradient automatically re-fits itself at each interpolated frame of the collapsed↔wings↔expanded morph without any extra code — it does NOT need to know about `matchedGeometryEffect` at all. This also means the same gradient definition (one shared `static let` or computed property) can be reused verbatim across all three material contexts (collapsed pill, wings, expanded blob) per D-02's requirement of one consistent black-to-~50%-opacity look, addressing the phase's "Claude's Discretion" question about per-shape special-casing — none is needed.

The one genuine technical uncertainty worth flagging to the planner: `NotchShape` has **no explicit `animatableData` conformance** (verified by code + grep — no `animatableData` anywhere in the codebase). This means when `topCornerRadius`/`bottomCornerRadius` change value between call sites (e.g., wings' `6/6` → expanded's `6/20`), the *radius itself* does not interpolate smoothly through Apple's `Animatable` machinery — only the `.frame()` size/position interpolates, via `matchedGeometryEffect`. In practice this has apparently read as correct to the user across four prior phases of on-device UAT (D-09 explicitly reconfirms it "already matches the Droppy reference"), so this is pre-existing, accepted behavior — not a regression to introduce — but D-08 (raising `bottomCornerRadius` from 20 to a noticeably larger value) makes the radius delta bigger, which is the direction most likely to make any latent "snap" newly visible. Flag this for on-device verification during D-08's radius tuning, same as the corner-radius pitfall documented below.

**Primary recommendation:** Add one shared gradient definition (a `static let` or computed `LinearGradient` property on `NotchPillView`) using relative `UnitPoint` stops with a stop schedule that keeps the fade compressed near the bottom (e.g., locations `[0.0, 0.65, 1.0]` with colors `[.black, .black, .black.opacity(0.5)]` — exact stop position is Claude's discretion per D-02, tune on-device). Swap all four `.fill(Color.black)` sites to `.fill(thatGradient)`. Retune `springResponse`/`springDamping` upward (slower) and downward (more visible single overshoot) respectively, starting from response ≈0.5–0.7 / dampingFraction ≈0.55–0.7, and iterate on-device per D-07's established convention — do not treat these starting numbers as final.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Gradient material fill | SwiftUI View layer (`NotchPillView.swift`) | — | Pure declarative `.fill(ShapeStyle)` on the existing `NotchShape`; no AppKit/window involvement |
| Spring animation curve | AppKit glue layer (`NotchWindowController.swift`) | SwiftUI View layer (renders the interpolation) | Per this project's established pattern (D-08/ISL-04): the controller owns ALL `withAnimation` wrapping; the view never animates itself |
| Shape geometry (corner radii) | SwiftUI View layer (`NotchShape.swift`) | — | No change this phase (D-09) — existing quad-curve mechanism stays; only the numeric `bottomCornerRadius` argument passed in at call sites changes (D-08) |
| Window/panel hosting | AppKit (`NotchPanel`/`NSHostingView`) | — | Untouched by this phase — no frame-size, hit-testing, or panel-lifecycle changes; gradient/spring changes are invisible to this tier |

## Standard Stack

### Core
| API | Availability | Purpose | Why Standard |
|-----|--------------|---------|---------------|
| `LinearGradient` (`SwiftUI.ShapeStyle`) | macOS 11.0+ | Vertical black→transparent fill | First-party `ShapeStyle` conformer; drop-in replacement for `Color.black` in every existing `.fill(...)` call. `[CITED: developer.apple.com/documentation/swiftui/lineargradient]` |
| `Animation.spring(response:dampingFraction:blendDuration:)` | macOS 10.15+ | Fluid, deliberately-paced, overshoot-and-settle expand/collapse | Already the sole animation primitive in this codebase (13 call sites, one pair of tunable constants); no reason to introduce a second animation API for one phase's tuning pass. `[CITED: developer.apple.com/documentation/swiftui/animation/spring(response:dampingfraction:blendduration:)]` |

### Supporting
None — this phase adds zero new dependencies, zero new types, and zero new files. It is a values-and-fill-style change inside two existing files.

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `.spring(response:dampingFraction:blendDuration:)` (existing API) | `.spring(duration:bounce:)` / `.bouncy(duration:extraBounce:)` (macOS 14+ Spring-duration API) | The newer duration/bounce-based spring presets are available at this project's macOS 14.0 floor and arguably describe "deliberately slow, gently bouncy" more directly (`duration` = how slow, `extraBounce` = how much overshoot). **Not recommended for this phase**: switching APIs touches all 13 call sites for no functional gain — the existing `response`/`dampingFraction` pair already expresses the same physics and is the established, working pattern (ponytail: reuse before rewrite). Worth knowing this exists if on-device tuning of `response`/`dampingFraction` proves fiddly. `[ASSUMED: iOS 17/macOS 14 SDK parity — not independently verified against macOS-specific release notes this session]` |
| `.fill(LinearGradient(...))` directly on `NotchShape` | `.overlay(LinearGradient...).mask(NotchShape())` | `.fill()` is the more direct, more performant path — `LinearGradient` already conforms to `ShapeStyle`, so no separate masking shape is needed. `.mask()` exists for cases needing a masking shape distinct from the fill shape, which does not apply here. `[CITED via WebSearch cross-reference, MEDIUM confidence — see Sources]` |

**Installation:** None — no package manager changes, no `project.yml` changes, no new Swift Package dependencies. Pure Swift source edits in two existing files.

## Package Legitimacy Audit

Not applicable — this phase introduces zero external packages. No `slopcheck`/registry verification needed.

## Architecture Patterns

### System Architecture Diagram

```
User pointer/click event
        │
        ▼
NotchWindowController (AppKit glue)
  handleHoverEnter / handleHoverExit / handleClick
  presentTransientChange / scheduleActivityDismiss
        │
        │  withAnimation(.spring(response: springResponse,
        │                        dampingFraction: springDamping))  ◄── Phase 25 retunes these 2 constants
        ▼
interaction.phase / presentationState.presentation mutated
        │
        │  (SwiftUI observes @Published change, re-renders)
        ▼
NotchPillView.body → switch presentation { ... }
        │
        ├─► collapsedIsland ──┐
        ├─► blobShape(...) ───┤
        ├─► wingsShape(...) ──┤──► NotchShape(topCornerRadius:, bottomCornerRadius:)
        └─► mediaWingsOrToast─┘         .fill(Color.black)          ◄── Phase 25: → .fill(gradient)
                                        .matchedGeometryEffect(id: "island", in: ns)
                                        .frame(width:, height:)
                                             │
                                             ▼
                                  NSHostingView (inside NotchPanel, an NSPanel)
                                             │
                                             ▼
                                     Rendered on-screen, real notch hardware
```

### Recommended Project Structure
No new files or folders. Both edits land in existing locations:
```
Islet/Notch/
├── NotchShape.swift            # unchanged (D-09)
├── NotchPillView.swift         # 4 fill sites: Color.black → shared LinearGradient
└── NotchWindowController.swift # 2 constants retuned: springResponse, springDamping
```

### Pattern 1: Shared gradient as a single source of truth
**What:** One `static let` (or computed property, if any values need to vary — none do per D-02) defining the `LinearGradient`, referenced by all four fill sites.
**When to use:** Any time multiple render call sites must look visually identical (D-02's "one shared material" requirement) — avoids drift where wings/pill/expanded blob accidentally get slightly different gradients.
**Example:**
```swift
// Source: SwiftUI LinearGradient/ShapeStyle docs — https://developer.apple.com/documentation/swiftui/lineargradient
// [CITED: Apple SwiftUI documentation]
private static let islandMaterial = LinearGradient(
    stops: [
        .init(color: .black, location: 0.0),
        .init(color: .black, location: 0.65),          // D-02: long solid stretch — tune this stop on-device
        .init(color: .black.opacity(0.5), location: 1.0) // D-02: ~50% floor at the very bottom, not lower
    ],
    startPoint: .top,     // relative UnitPoint — re-fits to the shape's CURRENT frame every animation frame
    endPoint: .bottom
)

// Then, at every call site (collapsedIsland, blobShape, wingsShape, mediaWingsOrToast):
NotchShape(topCornerRadius: ..., bottomCornerRadius: ...)
    .fill(Self.islandMaterial)          // was: .fill(Color.black)
    .matchedGeometryEffect(id: "island", in: ns)
    .frame(width: ..., height: ...)
```
**Why relative `UnitPoint`s matter:** `.top`/`.bottom` (or an explicit `UnitPoint(x: 0.5, y: 0)` / `(x: 0.5, y: 1)`) resolve relative to the shape's bounding box **at render time**, not a fixed pixel offset. Because SwiftUI re-evaluates the fill on every interpolated frame of the `matchedGeometryEffect`/`.frame()` size animation, the gradient automatically re-stretches to match — collapsed (38pt tall), wings (32pt), and expanded (144pt) all get the SAME proportional 65%-solid/35%-fade split with zero extra code. `[CITED: Apple's documented UnitPoint-relative-to-bounding-box behavior for gradients applied via ShapeStyle]`

### Pattern 2: Controller-owned spring retuning (no view changes needed)
**What:** Both constants live in exactly one place (`NotchWindowController.swift` lines 264–265); every `withAnimation(.spring(response: springResponse, dampingFraction: springDamping))` call site (13 confirmed via grep) reads them.
**When to use:** This is already the established pattern — Phase 25 does NOT need to touch any of the 13 call sites individually, only the two `private let` declarations.
```swift
// Before (current, "too fast, not enough overshoot" per D-07):
private let springResponse: Double = 0.35
private let springDamping: Double = 0.65

// After — starting point for on-device iteration (D-07: exact values are Claude's discretion):
private let springResponse: Double = 0.6   // slower — larger response = longer time-to-settle
private let springDamping: Double = 0.62   // lower = more visible overshoot before settling
```
**Why these starting ranges:** `response` roughly governs the period/speed of the spring's oscillation — increasing it from 0.35 slows the whole motion down, which is what D-05 asks for ("deliberately slow... even on 60Hz"). `dampingFraction` governs how much the spring overshoots before settling: `1.0` = critically damped (no overshoot, current default-Apple value is `0.825`), values below `1.0` underdamp and overshoot, and very low values (`<0.5`) start to oscillate multiple times before settling (which Success Criterion #2 explicitly rules out: "no jarring overshoot beyond the intended subtle in-bounce"). A `dampingFraction` in the ~0.55–0.7 band should give ONE visible overshoot-and-settle without multiple bounces — this is a starting range for on-device tuning, not a final answer. `[CITED: Apple's documented spring semantics for response/dampingFraction — developer.apple.com/documentation/swiftui/animation/spring(response:dampingfraction:blendduration:); the specific numeric recommendation for "iPhone Dynamic Island feel" is ASSUMED — Apple does not publish exact Dynamic Island spring constants]`

### Anti-Patterns to Avoid
- **Introducing a second animation API (`.bouncy`/`.spring(duration:bounce:)`) alongside the existing `response`/`dampingFraction` calls:** would fragment the single-source-of-truth pattern this codebase already relies on (13 call sites, one pair of constants) for zero benefit — tune the existing two numbers instead.
- **`.overlay(gradient).mask(shape)` instead of `.fill(gradient)`:** unnecessary extra compositing pass; `LinearGradient` is a first-class `ShapeStyle` and `.fill()` accepts it directly.
- **Per-call-site gradient definitions:** would risk the four fill sites (collapsed/blob/wings/toast) drifting out of visual sync — use one shared definition (Pattern 1).
- **Absolute-pixel gradient stops (e.g. `UnitPoint(x: 0.5, y: 100)`):** breaks the "same material at every size" requirement — always use relative (0...1) `UnitPoint` locations so the gradient auto-adapts across the 32pt/38pt/144pt height range.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Vertical alpha gradient | A custom `Shape`/`Path`-based gradient renderer, or a `CAGradientLayer` bridge | `LinearGradient` (`ShapeStyle`) directly on the existing `NotchShape` | First-party, zero extra code, already interpolates correctly across the shape morph via relative `UnitPoint`s |
| "Bouncy, slow" motion curve | A custom `Animatable`/keyframe/`TimelineView`-driven easing function | SwiftUI's built-in physics-based `.spring(response:dampingFraction:)` | Already the load-bearing primitive for every other animation in this app (D-08: the view drives no animation, the controller's spring wrapper is the ONLY animation driver) — retuning 2 numbers achieves the goal without adding a second animation system |

**Key insight:** Both "hand-roll" temptations are unnecessary because this phase's entire scope already maps onto two existing, well-understood SwiftUI primitives (`ShapeStyle` fills and `Animation.spring`). Nothing here justifies new abstractions.

## Common Pitfalls

### Pitfall 1: Corner-radius change may not interpolate smoothly (pre-existing, not introduced by this phase)
**What goes wrong:** `NotchShape`'s `topCornerRadius`/`bottomCornerRadius` are plain `CGFloat` stored properties with NO explicit `animatableData` conformance (verified: zero `animatableData`/`AnimatablePair`/`VectorArithmetic` references anywhere in the codebase). Per SwiftUI's `Animatable` protocol, without this the shape's *radius* value does not tween through `withAnimation` — only the `.frame()` size/position (driven by `matchedGeometryEffect`) smoothly interpolates. The radius itself effectively "snaps" to its new value.
**Why it happens:** SwiftUI's default `animatableData` for a custom `Shape` is `EmptyAnimatableData` unless explicitly overridden.
**How to avoid:** This is pre-existing, user-confirmed-acceptable behavior (D-09: "already matches the Droppy reference... preserve as-is"), so no fix is in scope for Phase 25. BUT — D-08 increases the expanded blob's `bottomCornerRadius` from 20 to a "significantly rounder" value, widening the delta between wings (6) and expanded (6/much-larger). A bigger delta makes any latent snap more visible. Flag for on-device verification during D-08 tuning: if the radius pop becomes newly noticeable, the fix is adding `var animatableData: AnimatablePair<CGFloat, CGFloat>` to `NotchShape` (a small, contained addition, NOT a shape-mechanism change, consistent with D-09's "no new mechanism" boundary).
**Warning signs:** A visible "kink" or instantaneous corner-shape change partway through the collapse↔expand morph, especially right as the bottom-corner radius jumps between states.

### Pitfall 2: Gradient looking "too transparent" or "too grey" if D-01/D-02's opacity floor and pure-black-only decisions aren't followed exactly
**What goes wrong:** A naive "fade to 0% opacity" gradient (the generic default most SwiftUI tutorials show) reads as noticeably more see-through than the Droppy reference the user pointed to, and mixing in a grey base color (instead of pure black) was explicitly rejected (D-01).
**Why it happens:** Default `LinearGradient(colors: [.black, .clear], ...)` fades all the way to fully transparent, and `Color.gray`/system materials are an easy but wrong reach for "frosted" look.
**How to avoid:** Use `.black.opacity(0.5)` as the floor color (never `.clear`), and push the transition-start location well past the midpoint (e.g. `location: 0.6–0.7` for the last solid-black stop) so most of the shape's height stays visually opaque, per D-02. Tune the exact stop location on-device per Claude's Discretion.
**Warning signs:** The island reading as "glassy"/"frosted" rather than "solid black with a small transparent hint at the bottom edge."

### Pitfall 3: Retuning the spring too far toward multi-bounce jelly motion
**What goes wrong:** Pushing `dampingFraction` too low (e.g. below ~0.4–0.5) in pursuit of "visible overshoot" can produce 2+ visible oscillations, which Success Criterion #2 explicitly forbids ("no jarring overshoot beyond the intended subtle in-bounce").
**Why it happens:** `dampingFraction` is inversely related to bounce count — the lower it goes, the more oscillation cycles before settling.
**How to avoid:** Start in the ~0.55–0.7 range (single visible overshoot-and-settle) and only go lower if on-device feel is still too flat; watch for a SECOND overshoot appearing, which is the signal to raise `dampingFraction` back up.
**Warning signs:** The island appears to "wobble" more than once, or feels "jiggly" rather than "premium fluid."

### Pitfall 4: Slower spring conflicting with the grace-collapse delay
**What goes wrong:** `NotchWindowController`'s `graceDelay` (0.4s, hover-exit-to-collapse timer) is a separate constant from `springResponse`. If `springResponse` is tuned significantly slower (e.g., > graceDelay), a rapid hover-exit-then-re-enter could visually overlap two spring animations mid-flight, or the collapse could still be settling when a new hover-enter fires.
**Why it happens:** These two timing constants are independent and were tuned together at 0.35/0.4s originally; only one (spring) is in this phase's scope.
**How to avoid:** During on-device tuning (D-07), specifically test rapid hover-enter/exit/re-enter cycles at the new, slower spring values — not just a single clean expand/collapse. If interrupted-animation artifacts appear, note this as a candidate follow-up for `graceDelay` (out of this phase's stated scope, but flag as an Open Question for the planner rather than silently fixing it).
**Warning signs:** A "double-morph" flicker or the island briefly snapping to an intermediate size during fast pointer movement across the hot-zone boundary.

## Code Examples

### Shared gradient definition + fill-site swap
```swift
// Source: SwiftUI ShapeStyle/LinearGradient docs (Apple) — pattern verified against this
// codebase's existing 4 fill sites in NotchPillView.swift (collapsedIsland, blobShape,
// wingsShape, mediaWingsOrToast).
// [CITED: developer.apple.com/documentation/swiftui/lineargradient]
extension NotchPillView {
    fileprivate static let islandMaterial = LinearGradient(
        stops: [
            .init(color: .black, location: 0.0),
            .init(color: .black, location: 0.65),
            .init(color: .black.opacity(0.5), location: 1.0)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}
```

### Spring constant retune (only these 2 lines change)
```swift
// Source: this codebase, NotchWindowController.swift lines 264-265 — the single tuning point
// for all 13 withAnimation(.spring(response:dampingFraction:)) call sites.
private let springResponse: Double = 0.6    // was 0.35 — slower per D-05
private let springDamping: Double = 0.62    // was 0.65 — more visible overshoot per D-06
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|---------------|--------|
| `spring(response:dampingFraction:blendDuration:)` as the only spring API | `spring(duration:bounce:)` / `.bouncy`/`.smooth`/`.snappy` presets also available | iOS 17 / macOS 14 (2023) | Available at this project's macOS 14.0 floor, but NOT recommended for adoption this phase (see Alternatives Considered) — noted for awareness only. `[ASSUMED — SDK-generation parity, not independently re-verified this session]` |

**Deprecated/outdated:** None relevant — `LinearGradient` and `.spring(response:dampingFraction:blendDuration:)` are both stable, non-deprecated APIs at the macOS 14.0 deployment floor.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|----------------|
| A1 | `.spring(duration:bounce:)`/`.bouncy` presets are available at macOS 14.0 (this project's deployment floor), by SDK-generation parity with iOS 17 | Alternatives Considered, State of the Art | Low — this phase doesn't recommend adopting them; only relevant if the planner or executor later wants to switch animation APIs |
| A2 | Starting numeric ranges (`response` ≈0.5–0.7, `dampingFraction` ≈0.55–0.7) will produce the "deliberately slow, single visible overshoot" feel the user wants | Pattern 2, Code Examples | Low — D-07 already establishes these are Claude's discretion, tuned on-device across multiple rounds (established project convention per Phase 18's 5-round precedent); wrong starting values just mean more tuning rounds, not a wrong architecture |
| A3 | The bottom-of-gradient stop location (`0.65`) matches D-02's "long solid stretch, mild fade only near the very bottom" description well enough as a starting point | Pattern 1, Code Examples | Low — explicitly flagged as Claude's Discretion / on-device tunable in CONTEXT.md; wrong value is a 1-line tweak, not a rework |
| A4 | `NotchShape`'s missing `animatableData` conformance causes a visible "snap" rather than a smooth interpolation of corner radius (vs. the frame-size interpolation, which IS smooth via `matchedGeometryEffect`) | Common Pitfalls #1 | Medium — if this reasoning is wrong (i.e., SwiftUI happens to still interpolate smoothly through some other mechanism, or the deltas are too small to perceive), then no `animatableData` fix is needed at all; if right and unaddressed, D-08's larger radius delta could look worse than intended. Either way, resolvable via a 3-line `animatableData` addition if it becomes visible during Plan execution's on-device tuning — does not block planning. |

## Open Questions (RESOLVED)

1. **Does the existing `graceDelay` (0.4s) need retuning alongside the spring, or does it stay fixed?**
   - What we know: `graceDelay` is a separate, independent constant governing how long after hover-exit the collapse fires; it was tuned together with the OLD spring values.
   - What's unclear: Whether a significantly slower spring (per D-05) will feel mismatched against an unchanged 0.4s grace window during rapid interaction.
   - Recommendation: Out of this phase's explicit scope (CONTEXT.md only calls out `springResponse`/`springDamping` as touched constants) — but flag to the planner as a "watch for during on-device tuning" item, not a blocker. If it surfaces as a real issue, it's a 1-line follow-up, not a new phase.
   - **RESOLVED:** operationalized in 25-01-PLAN.md Task 3, check 6 — flagged as a follow-up if observed, not fixed in this phase.

2. **Will `NotchShape` need an `animatableData` conformance added as part of D-08's larger bottom-corner-radius change?**
   - What we know: The property currently doesn't interpolate (Pitfall 1); D-09 confirms the CURRENT (smaller) radius deltas already read correctly to the user.
   - What's unclear: Whether D-08's bigger radius jump crosses a visibility threshold.
   - Recommendation: Treat as a contingency, not a required task — plan the gradient + spring work first, on-device-verify the D-08 radius change, and only add `animatableData` if a visible pop appears.
   - **RESOLVED:** operationalized in 25-01-PLAN.md Task 3, check 5 — contingency 3-line fix applied only if a visible pop appears on-device.

## Environment Availability

Skipped — this phase has no external tool/service/runtime dependencies. All work is Swift source edits building against the SDK already in use by the rest of the project (Xcode 16+/macOS 14.0 deployment target, per CLAUDE.md's Technology Stack section).

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (existing — `IsletTests/` target) |
| Config file | `Islet.xcodeproj` / `project.yml` (existing scheme) |
| Quick run command | `xcodebuild build -project Islet.xcodeproj -scheme Islet -configuration Debug` (build gate — per project memory `xcodebuild-test-headless-hang`, `xcodebuild test` hangs headless because tests boot the full `Islet.app` incl. `NSPanel`/MediaRemote/IOBluetooth; route actual test *execution* to manual Cmd-U in Xcode, use `build` as the automated gate) |
| Full suite command | Manual Cmd-U in Xcode (per project memory — do not attempt headless `xcodebuild test`) |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|---------------------|--------------|
| VISUAL-01 | Gradient material renders correctly at all 3 shape contexts (pill/wings/expanded) | build-gate + manual visual UAT | `xcodebuild build ...` (compiles) + on-device visual check (real notch panel) | ✅ build gate exists; ❌ no automated visual/snapshot test — this is inherently a rendering-appearance requirement, manual-only is appropriate |
| VISUAL-02 | Spring feel (slow, single overshoot, no dropped frames) | manual-only (on-device UAT) | N/A — animation *feel* is not testable via XCTest; existing `NotchShapeTests.swift`/`InteractionStateTests.swift` cover the PURE geometry/state-machine logic these constants don't touch | ❌ N/A by nature — justified: this project's established convention (Phase 18, 5 rounds) already treats spring/animation tuning as on-device-only, never unit-tested |
| VISUAL-01/02 | `NotchShape` path math itself stays correct (unchanged, D-09) | unit | `xcodebuild build ...` then Cmd-U → `NotchShapeTests` | ✅ `IsletTests/NotchShapeTests.swift` exists, covers path/bounds math — unaffected by this phase's fill/animation-only changes, should stay green |

### Sampling Rate
- **Per task commit:** `xcodebuild build -project Islet.xcodeproj -scheme Islet -configuration Debug` (compile gate)
- **Per wave merge:** Same build gate + manual on-device visual/feel check (real notch hardware required — a simulator/preview cannot validate "no dropped frames on the real never-focused panel," Success Criterion #4)
- **Phase gate:** Full on-device UAT pass (collapse↔expand↔wings↔shelf, all activity types) before `/gsd:verify-work`, matching this project's established manual-UAT convention for visual/feel phases (Phase 18, 20, 21, 23)

### Wave 0 Gaps
None — existing test infrastructure (`NotchShapeTests.swift`, `InteractionStateTests.swift`, `EqualizerBarsTests.swift`) already covers the pure logic adjacent to this phase's scope; this phase's actual changes (fill style, spring constants) are inherently visual/feel properties that this project has consistently and deliberately left to manual on-device UAT rather than automated snapshot testing (no snapshot-testing library is in this project's dependency graph, and adding one for a 2-file visual tuning phase would be disproportionate — ponytail: don't hand-roll/add-a-dependency for what on-device UAT already covers per established convention).

## Security Domain

Not applicable — this phase introduces no new trust boundary, no new external input, no new data flow, no new persisted state, and no new dependency. It is a rendering-style (`ShapeStyle`) and animation-constant change to code that already renders trusted, locally-computed values (shape geometry, spring timing). No ASVS category applies.

## Project Constraints (from CLAUDE.md)

- **Tech stack:** Native Swift + SwiftUI/AppKit only — satisfied, no new frameworks introduced.
- **Swift language mode:** Build settings target Swift 5 language mode (per CLAUDE.md's beginner-friendly guidance) — no Swift 6 strict-concurrency concerns triggered by this phase's changes (no new `async`/actor code).
- **Avoid unnecessary complexity / builder is a first-time programmer:** Both technique choices in this research (`.fill(LinearGradient)`, retuning 2 existing constants) are the SIMPLEST available options, deliberately avoiding new animation systems or masking layers.
- **No Core Animation / hand-rolled `CALayer` animations:** Satisfied — this research explicitly recommends staying within SwiftUI's `Animation.spring` API, per CLAUDE.md's "Animation approach" guidance ("Avoid Core Animation / hand-rolled CALayer animations — unnecessary complexity for a beginner when SwiftUI gives this for free").
- **`matchedGeometryEffect` + spring as "the Dynamic-Island feel":** This phase is a direct continuation of CLAUDE.md's own documented approach ("Use matchedGeometryEffect with a shared @Namespace... Wrap state changes in withAnimation(.spring(...))") — no deviation, only retuning existing values.

## Sources

### Primary (HIGH confidence)
- Apple Developer Documentation — `LinearGradient` (ShapeStyle conformance) — https://developer.apple.com/documentation/swiftui/lineargradient
- Apple Developer Documentation — `Animation.spring(response:dampingFraction:blendDuration:)` — https://developer.apple.com/documentation/swiftui/animation/spring(response:dampingfraction:blendduration:)
- This codebase — `Islet/Notch/NotchShape.swift`, `Islet/Notch/NotchPillView.swift`, `Islet/Notch/NotchWindowController.swift` (read in full/near-full this session) — direct source-of-truth for all integration points, existing patterns, and the 13 confirmed spring call sites.
- Project memory — `xcodebuild-test-headless-hang` (routes test execution to manual Cmd-U, not headless `xcodebuild test`).

### Secondary (MEDIUM confidence)
- [Interpolating corner radius with matchedGeometryEffect — Apple Developer Forums](https://developer.apple.com/forums/thread/709240) — corroborates the "one shape, mutate values, avoid switching between shape instances" pattern this codebase already follows.
- [Mastering Masking in SwiftUI — Deepak Tundwal, Medium](https://dtundwal.medium.com/mastering-masking-in-swiftui-a-guide-to-dynamic-uis-38928b35cafb) and related masking articles — cross-referenced to confirm `.fill(ShapeStyle)` is preferred over `.overlay().mask()` for direct gradient fills.
- [Understanding Spring Animations in SwiftUI — createwithswift.com](https://www.createwithswift.com/understanding-spring-animations-in-swiftui/) and [Learning SwiftUI Spring Animations — Amos Gyamfi, Medium](https://medium.com/@amosgyamfi/learning-swiftui-spring-animations-the-basics-and-beyond-4fb032212487) — corroborate `response`/`dampingFraction` semantics (speed vs. overshoot) used to derive the starting-range recommendation.

### Tertiary (LOW confidence)
- General web search results regarding `.bouncy`/`spring(duration:bounce:)` macOS 14 availability — not independently confirmed against Apple's official macOS 14 release notes this session; treated as ASSUMED (A1) and explicitly not recommended for adoption.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — `LinearGradient`/`Animation.spring` are stable, well-documented, already-in-use-in-this-codebase APIs; no new dependency risk.
- Architecture: HIGH — zero new files/types; all 4 fill sites and both spring constants located and confirmed via direct source read.
- Pitfalls: MEDIUM — the `animatableData`/corner-radius-snap pitfall (Pitfall 1 / A4) is a reasoned inference from SwiftUI's documented `Animatable` defaults, not confirmed via an on-device screen-recording this session; flagged for on-device verification during D-08 execution rather than blocking planning.

**Research date:** 2026-07-11
**Valid until:** 30 days (stable, first-party SwiftUI APIs at a fixed macOS 14.0 deployment floor — low churn risk)
