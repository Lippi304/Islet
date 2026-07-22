# Phase 42: Dual-Activity Display - Research

**Researched:** 2026-07-18
**Domain:** SwiftUI dual-namespace `matchedGeometryEffect`, pure-resolver additive extension, AppKit click-through geometry
**Confidence:** HIGH (this is a pure codebase-extension phase — no new frameworks, no new dependencies; every claim below is grounded in the actual source read this session)

## Summary

Phase 42 adds a second, simultaneously-visible shape (the secondary bubble) to a resolver and view architecture that has, since Phase 6, structurally assumed exactly one visible `IslandPresentation` shape at a time sharing one `matchedGeometryEffect(id: "island", in: ns)` identity. The work splits cleanly into three independently-verifiable pieces: (1) a pure, additive `secondary:` output on `resolve()` driven by a small ordered ranking table scoped to exactly Countdown/NowPlaying (D-01–D-04), (2) a second SwiftUI shape composed alongside — not inside — the existing `presentationSwitch`, carrying its own distinct `matchedGeometryEffect` id so it morphs independently of the primary pill (D-05–D-09), and (3) wiring the secondary bubble into the SAME `onClick`-style tap-to-expand affordance every other wing already uses (D-12), which is where this phase's one real risk lives: `NotchWindowController`'s click-through hot-zone (`hotZone`) is fixed to the small collapsed-pill rect, not to the actual rendered width of wing-tier content — a bubble rendered further out than that rect may silently swallow clicks unless the interactive zone is verified/widened, mirroring the exact class of bug the Phase 40 badge-tap regression was.

**Primary recommendation:** Extend `resolve()` with an additive `secondary: SecondaryActivity?` output field computed by a small literal ordered-pair table scoped to (Countdown, NowPlaying); compose the secondary bubble in `NotchPillView.body`'s outer `ZStack` (not inside `presentationSwitch`) using a distinct `matchedGeometryEffect(id: "secondaryBubble", in: ns)` on the SAME shared `@Namespace`; and treat the click-through hot-zone extension for the bubble's real screen position as its own explicit task, verified on-device, not assumed to fall out for free.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Primary/secondary ranking decision | Pure resolver (`IslandResolver.swift`) | — | Single arbiter discipline (Pitfall 6/PITFALLS.md) — no view-layer precedence logic, ever |
| Secondary bubble rendering (shape, artwork crop, spring) | SwiftUI view (`NotchPillView.swift`) | — | View is a pure consumer of the resolver's verdict, same as every existing case |
| Secondary bubble tap → expand | AppKit click-through geometry (`NotchWindowController.swift`) + SwiftUI `onTapGesture` | — | The SwiftUI gesture only fires if AppKit's `ignoresMouseEvents` already let the click through — this is the phase's real risk surface |
| Staggered reveal timing (D-11) | Controller (`NotchWindowController`, spring wrapper) | View (relative `.animation`/delay) | Mirrors existing precedent: the controller decides WHEN to mutate state under `withAnimation`, the view expresses HOW it animates |

## User Constraints (from CONTEXT.md)

<user_constraints>
### Locked Decisions

- **D-01:** Calendar Countdown is always primary (the main pill) when both Countdown and Now-Playing are live — continues Phase 41's D-01 ranking (Countdown > Now-Playing), just changes what happens to the loser: instead of going fully invisible, it becomes the secondary.
- **D-02:** Phase 41's D-01 ("Countdown suppresses Now-Playing entirely") is SUPERSEDED, not kept as a fallback: whenever both are live, Now-Playing is always visible as the secondary round bubble.
- **D-03:** The ranking is expressed as a small ordered table (not an if/else chain) inside the resolver, but scoped to exactly the 2 entries that exist today (Countdown, Now-Playing). No speculative 3rd/4th ambient activity is designed for (YAGNI).
- **D-04:** When only one of the two ambient activities is live, behavior is byte-for-byte unchanged from today — single activity renders as the normal primary pill, `secondary` is `nil`, no empty bubble ever renders.
- **D-05:** The secondary bubble is a ROUND circle positioned to the right of the primary pill — the general shape for ANY secondary activity, not Now-Playing-specific.
- **D-06:** For Now-Playing specifically, the bubble shows the real album-cover artwork, circularly cropped. Inherits existing artwork-latency handling (art fills in asynchronously).
- **D-07:** The bubble is smaller than the primary pill (~24-28pt, vs. the existing 32pt wing/pill height).
- **D-08:** Small visible gap between the primary pill and the secondary bubble (not touching/overlapping).
- **D-09:** The secondary bubble morphs in/out via its own `matchedGeometryEffect` (its own distinct id/namespace, separate from the primary pill's existing shared `"island"` id).
- **D-10:** A standing transient (Charging, Device, Focus, or Volume/Brightness OSD) suppresses BOTH the primary pill and the secondary bubble at once — falls out for free from `resolve()`'s existing early-return switch on `activeTransient`.
- **D-11:** When the transient ends, the primary pill reappears first, and the secondary bubble morphs in with a slight delay afterward (staggered two-step reveal).
- **D-12:** Tapping the secondary bubble expands to that activity's own view — a real, independent tap target, not inert.
- **D-13:** No hover-reveal or highlight on the secondary bubble (mirrors Phase 41 D-08 — Countdown pill has no hover-reveal either).

### Claude's Discretion

- Exact pixel values for bubble diameter (24-28pt range), gap width (D-08), and stagger delay duration (D-11) — resolve against on-device measurement, per project precedent (Phase 41's countdown wing width fix).
- Whether the ranking table is a literal `[(ActivityKind, ActivityKind)]`-style structure or a small dedicated enum/function — implementation choice; must read as an explicit ordered table, not scattered conditionals.

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope. 3+ concurrent activities and generalizing beyond Countdown+Music are already correctly out of scope per REQUIREMENTS.md (not proposed as in-scope here).
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DUAL-01 | When two top-priority activities are live simultaneously, the collapsed state shows a main pill plus a small secondary bubble instead of one activity strictly winning | See "Don't Hand-Roll" for the ranking-table pattern, "Architecture Patterns" for the dual-namespace `matchedGeometryEffect` composition, and "Common Pitfalls" for the click-through hot-zone risk that determines whether D-12's tap target actually works on-device |
</phase_requirements>

## Standard Stack

No new dependencies. This phase is a pure extension of existing Foundation-only pure logic (`IslandResolver.swift`) and existing SwiftUI/AppKit view code (`NotchPillView.swift`, `NotchWindowController.swift`). No `## Package Legitimacy Audit` section is required — no packages are installed.

### Core (existing, reused)
| Component | Location | Purpose | Why reused, not rebuilt |
|-----------|----------|---------|--------------------------|
| `resolve(...)` | `Islet/Notch/IslandResolver.swift:117` | The single pure arbiter (TOTAL function, Foundation-only) | Every phase since 6 routes precedence through here; PITFALLS.md Pitfall 6 forbids a second arbiter |
| `IslandPresentation` enum | `Islet/Notch/IslandResolver.swift:61` | What the island renders | ROADMAP explicitly forbids reshaping this — the secondary rides on an additive field, not a new case |
| `@Namespace private var ns` | `Islet/Notch/NotchPillView.swift:198` | The one shared `matchedGeometryEffect` namespace group | D-09 says "own distinct id" not necessarily "own `@Namespace`" — see Architecture Patterns for why reusing `ns` with a new `id:` is the correct, lower-risk reading |
| `wingsShape(leftWidth:rightWidth:content:)` | `Islet/Notch/NotchPillView.swift:1947` | Independently-sized flanking geometry precedent | Closest existing precedent for asymmetric secondary geometry (CONTEXT.md canonical ref) — informs, but the bubble needs its OWN shape call, not a `wingsShape` reuse (wings render ONE shape, the bubble is a SECOND simultaneous shape) |
| `artThumbnail(_:side:corner:)` | `Islet/Notch/NotchPillView.swift:2519` | Album-art rendering with nil→placeholder fallback | D-06's artwork source; currently clips to `RoundedRectangle` — the bubble needs a `Circle()` clip instead, see Code Examples |
| `TransientQueue` / `ActiveTransient` | `Islet/Notch/IslandResolver.swift:81,251` | Transient suppression (D-10) | Already returns early before the ambient branch is reached — no new code required for D-10 |

## Package Legitimacy Audit

Not applicable — this phase installs no external packages.

## Architecture Patterns

### System Architecture Diagram

```
NotchWindowController.currentPresentation()
        │
        │  calendarCountdown: CalendarCountdownActivity?
        │  nowPlaying: NowPlayingPresentation (post nowPlayingLaunchGate)
        ▼
IslandResolver.resolve(...)  [PURE — Foundation only]
        │
        ├─ activeTransient? ──yes──► return .charging/.device/.focus/.osd
        │                             (secondary is NEVER populated here — D-10 falls out free,
        │                              since resolve() returns a SINGLE IslandPresentation and
        │                              the view only renders `secondary` alongside the ambient
        │                              branch's output — see Pitfall 1 below for the wiring detail)
        │
        ├─ isExpanded? ──yes──► existing expanded branches (UNCHANGED)
        │
        └─ ambient branch (NEW: D-01/D-02/D-03 ranking table lives HERE)
                │
                │  both Countdown AND NowPlaying live?
                ├─ yes → primary = .calendarCountdown(...)  [D-01: countdown always wins primary]
                │        secondary = .nowPlaying(...)        [D-02: loser demoted, not hidden]
                ├─ only one live → primary = that one, secondary = nil        [D-04]
                └─ neither live → existing .idle fallback, secondary = nil
        │
        ▼
IslandPresentationState.presentation  (existing @Published, UNCHANGED shape)
IslandPresentationState.secondary     (NEW @Published field, additive)
        │
        ▼
NotchPillView.body
    ZStack(alignment: .top) {
        presentationSwitch            ← UNCHANGED, renders `presentation` exactly as today
        if let secondary { secondaryBubble(secondary) }   ← NEW, composed ALONGSIDE, not inside
    }
```

### Recommended Project Structure

No new files. Additive changes to 3 existing files:
```
Islet/Notch/
├── IslandResolver.swift          # + SecondaryActivity enum, + ranking table fn, + resolve() secondary: param
├── IslandPresentationState.swift # + @Published var secondary: SecondaryActivity?
└── NotchPillView.swift           # + secondaryBubble(_:) view fn, + composition in body's ZStack
```

### Pattern 1: Additive resolver output — return a tuple-like verdict, not a new enum case

**What:** `resolve(...)` currently returns a single `IslandPresentation`. Per ROADMAP's explicit constraint ("the existing `IslandResolver.resolve()` single-winner pass... otherwise unchanged"), the cleanest additive shape is either (a) `resolve()` gains a second return value via a tuple `(IslandPresentation, SecondaryActivity?)`, or (b) a SEPARATE small pure function `resolveSecondary(...)` called alongside `resolve(...)` with the same inputs. Given CONTEXT.md's Integration Points note ("the ambient branch... is the exact branch that needs the new secondary: output"), **(a) is closer to what the codebase's own comments anticipate** — the ambient branch already has both `calendarCountdown` and `nowPlaying` in scope at the exact point it decides between them, so computing `secondary` as a byproduct of that SAME branch (not a second independent pass re-deriving the same inputs) avoids the two ever disagreeing. Precedent: this project has an established pattern of "same live state, one function decides, no second computation of the same facts" (see `IslandResolver.swift`'s own comment on `songChangeToastGate` reading from "the exact same live state resolve(...) itself consumes... so the two can never disagree").

**When to use:** The ambient branch's `if let countdown = calendarCountdown { return .calendarCountdown(countdown) }` (line 170) is the literal edit point — this is where D-01/D-02/D-03's table must be consulted instead of the current unconditional early-return.

**Example (pattern, not final code — planner's call on tuple vs. struct wrapper):**
```swift
// Source: pattern derived from IslandResolver.swift:166-175 (existing ambient branch),
// adapted per ROADMAP additive constraint
struct AmbientVerdict {
    let presentation: IslandPresentation
    let secondary: SecondaryActivity?
}

// D-03: literal ordered table, scoped to exactly 2 entries — not a speculative N-entry design.
// Reads top-to-bottom as "if X is live, X is primary" — exactly what D-03 asks for.
private let ambientPriorityTable: [(check: (CalendarCountdownActivity?, NowPlayingPresentation) -> Bool, makePrimary: ...)] = [...]
// OR simpler, equally "explicit table not conditionals": a fixed-order array of cases checked
// in sequence, since there are only 2 today (YAGNI per D-03's own discretion note).
```

### Pattern 2: Second simultaneous `matchedGeometryEffect` shape — same `@Namespace`, distinct `id:`

**What:** Every existing shape (`collapsedIsland`, `blobShape`, `wingsShape`, `mediaWingsOrToast`) carries `.matchedGeometryEffect(id: "island", in: ns)` on the SAME shared `@Namespace private var ns` (`NotchPillView.swift:198`) — today only ONE such shape renders per frame, so SwiftUI always has exactly one source/destination pair to morph between. D-09 requires the secondary bubble to be "the FIRST case where two shapes render simultaneously, each with its own distinct id."

**Critical constraint (verified from source, `NotchPillView.swift` comments at lines 850-858, 1803-1808, 1956-1958):** every single existing `matchedGeometryEffect` call was bug-fixed in a documented "island-expand-diagonal-bounce" round to require the ORDER `.matchedGeometryEffect(...)` BEFORE `.frame(...)` — placing `.frame` first overrides the effect's own size interpolation and produces a diagonal-jump bounce instead of a symmetric grow. **This exact ordering constraint applies identically to the new secondary bubble's shape call** — it is not something D-09 introduces new risk for, but it IS something the plan/implementation must not silently regress on (this project has hit this bug 3 times already on different call sites).

**Should the bubble use a SECOND `@Namespace` or the SAME `ns` with a new `id:`?** ROADMAP's success criterion says "distinct `matchedGeometryEffect` namespaces." Reading strictly, `matchedGeometryEffect`'s uniqueness key is the `(id, namespace)` PAIR — two shapes in the SAME `@Namespace` with DIFFERENT `id:` values are already fully independent for animation purposes (SwiftUI does not attempt to morph between different ids in the same namespace). A genuinely separate `@Namespace` is not required for correctness; it only becomes relevant if some future geometry-reader code enumerates a namespace's members by namespace alone. Given YAGNI (D-03's own stated discretion applies in spirit here) and that this project's convention is ONE shared `ns` for the whole view, **recommend: same `ns`, new distinct `id:` (e.g. `"secondaryBubble"`)** — satisfies "distinct id" literally, avoids introducing a second `@Namespace` for no functional benefit, and the planner should treat ROADMAP's "namespaces" wording as satisfied by id-level distinctness unless on-device testing shows otherwise (flagged as an Open Question below since this is a judgment call, not a verified SwiftUI framework guarantee).

**Example:**
```swift
// Source: pattern extrapolated from NotchPillView.swift:839-868 (collapsedIsland) — the
// established shape/effect/frame ordering this project has bug-fixed 3 times already.
@ViewBuilder
private func secondaryBubble(_ activity: SecondaryActivity) -> some View {
    if case .nowPlaying(let art) = activity {
        Circle()
            .fill(islandFill)                                  // reuse existing fill token
            .matchedGeometryEffect(id: "secondaryBubble", in: ns)  // MUST precede .frame — see above
            .frame(width: Self.secondaryBubbleDiameter, height: Self.secondaryBubbleDiameter)
            .overlay(
                artThumbnailCircular(art)                       // NEW: Circle-clipped variant of artThumbnail
            )
            .onTapGesture { onSecondaryTap() }                  // D-12: independent tap target
            .transition(.scale.combined(with: .opacity))        // D-11: bubble's own morph-in/out
    }
}
```

### Pattern 3: Composition point — `body`'s `ZStack`, not `presentationSwitch`

**What:** `presentationSwitch` (`NotchPillView.swift:715-757`) is a `@ViewBuilder` `switch` that returns exactly ONE view per `IslandPresentation` case. ROADMAP's success criterion #4 requires "every existing `IslandPresentation` switch site... otherwise unchanged." The secondary bubble is therefore composed in `body`'s outer `ZStack(alignment: .top)` (`NotchPillView.swift:763-770`), as a SIBLING to `presentationSwitch`, not a new case inside it.

**When to use:** Always for this feature — this is not a judgment call, it is the literal mechanism that makes the extension additive per D-09/success-criterion-4.

**Example:**
```swift
// Source: pattern extrapolated from NotchPillView.swift:763-770 (existing body ZStack)
ZStack(alignment: .top) {
    presentationSwitch                              // UNCHANGED
    if let secondary = presentationState.secondary {
        secondaryBubble(secondary)
            .offset(x: /* to the right of the primary pill, D-05/D-08 */)
    }
}
```
Positioning the bubble "to the right of the primary pill" (D-05) inside a `.top`-aligned `ZStack` needs an explicit `.offset(x:)` or an `.alignmentGuide` — recommend `.alignmentGuide` over `.offset(x:)` given this project's OWN documented finding (STATE.md Phase 39-07): `.offset()` inside this view hierarchy's shape-composition pattern was found NOT to move the real render position reliably in at least one prior case (`wingsShape`'s content `ZStack`). The bubble sits in `body`'s top-level `ZStack`, not inside `wingsShape`'s content `ZStack`, so that specific bug may not reproduce — but given it already burned 16 on-device rounds once, treat any `.offset()` use here as unverified until confirmed on-device, and prefer `HStack`-based layout (mirrors the Phase 39-07 lesson's own recommended fix: "default to HStack + explicit-width-spacers... unless a strong reason exists to deviate") if the primary pill and bubble can be expressed as siblings in a horizontal stack instead.

### Anti-Patterns to Avoid
- **Deciding primary/secondary in the view layer:** any `if activity == .calendarCountdown && nowPlaying != .none` conditional inside `NotchPillView.swift` would violate the "one pure arbiter" discipline (PITFALLS.md Pitfall 6) that every prior phase in this codebase has held to without exception.
- **A new `IslandPresentation` case for the dual state:** explicitly forbidden by ROADMAP/CONTEXT.md — `secondary` must be an additive field alongside the existing enum, not a `.dualActivity(primary:secondary:)` case.
- **`.frame()` before `.matchedGeometryEffect()`:** documented, repeatedly-hit bug in this exact codebase (3 prior fixes). Any new shape call must apply the effect first.
- **Assuming the bubble's tap target works without checking `hotZone`:** see Common Pitfalls — this is the single highest-risk item in the phase.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Ranking two competing ambient activities | A bespoke priority-scoring system, weighted ranks, or a generic N-activity slot allocator | A literal 2-entry ordered check inside the existing ambient branch (D-03) | D-03 explicitly scopes this to exactly today's 2 activities; YAGNI — a generic ranking engine for a problem with exactly 2 known instances is pure speculative complexity |
| Circular artwork crop | A custom `Shape`/`Path` circle-mask implementation | SwiftUI's built-in `.clipShape(Circle())`, mirroring `artThumbnail`'s existing `.clipShape(RoundedRectangle(...))` pattern one line over | Direct precedent already in the same file (`NotchPillView.swift:2519-2536`) — same mechanism, different `Shape` |
| Staggered two-step reveal (D-11) | A custom sequencing/state-machine abstraction | SwiftUI's built-in `.animation(_:value:)` with a `DispatchQueue.main.asyncAfter` delay on the `secondary` mutation (mirrors how `graceWorkItem`/`dismissWorkItem` already stagger timing elsewhere in `NotchWindowController`) | This project already has an established "delay via `DispatchWorkItem` + `asyncAfter`" convention for every existing timed transition (grace-collapse, activity dismiss) — reuse it, don't invent a new primitive |

**Key insight:** every piece of this phase has a near-exact precedent already living in this file. The discipline is reuse-the-pattern, not invent-something-new — the only genuinely new territory is two `matchedGeometryEffect` shapes rendering at once, which is a well-documented, well-understood SwiftUI capability (distinct ids don't interfere), not a framework gap.

## Common Pitfalls

### Pitfall 1: Secondary suppressed during a transient is not automatic — must be wired explicitly
**What goes wrong:** CONTEXT.md D-10 asserts this "falls out for free" because `resolve()`'s transient switch already returns early. This is true for `resolve()`'s own `presentation` return value — but if `secondary` becomes a field on `IslandPresentationState` that the CONTROLLER sets independently (rather than something bundled into the SAME return value as `presentation`), a naive implementation could update `presentation` (to `.charging(...)`) via the early-return path while leaving `secondary` stale from the last ambient resolve, because the code path that would have cleared `secondary` was never reached.
**Why it happens:** Splitting one verdict into two independently-mutated `@Published` fields creates two places that must agree, exactly the anti-pattern `songChangeToastGate`'s own doc comment warns is normally wrong for this codebase (it's only safe there because the toast gate reads the SAME live state on every call).
**How to avoid:** Whatever the return shape is (tuple, struct, or two params), the CALLER (`NotchWindowController.currentPresentation()`) must always set BOTH `presentation` and `secondary` from ONE `resolve(...)` call, on every call, not just the ambient-branch calls. A transient branch's early return must yield `secondary = nil` as part of that same return, not rely on a separate code path to clear it.
**Warning signs:** A secondary bubble still visible (stale) during a Charging/Device/Focus/OSD splash — this is the exact regression D-10's success criterion is designed to catch.

### Pitfall 2: Click-through hot-zone is fixed to the SMALL collapsed pill, not to wing-tier content width
**What goes wrong:** `NotchWindowController.swift:995` sets `hotZone = collapsedFrame.insetBy(dx: -hotZonePadding, dy: -hotZonePadding)` — `collapsedFrame` is the tiny measured-notch rect (~179×32pt on the build machine, per project memory), NOT the wider wings/bubble rendering width. `handlePointer(at:)` (`NotchWindowController.swift:1217`) uses `activeZone = interaction.isExpanded ? (expandedZone ?? hotZone) : hotZone` — while the island is in its ambient/collapsed tier (which is where BOTH the primary countdown/media wing AND the new secondary bubble render, since neither is `isExpanded`), the ONLY zone gating whether AppKit even delivers a click to the SwiftUI view at all is this small fixed `hotZone`. A secondary bubble positioned to the right of the primary pill (D-05) is, by construction, further from the notch center than the small `hotZone` rect covers.
**Why it happens:** This is not a new bug this phase introduces — it is a pre-existing, undocumented-until-now gap in how far the interactive click-through zone extends for ANY wing-tier content (Charging/Device/NowPlaying/Countdown wings render at 290pt / `wingsLabelWidth`-driven widths, all wider than the ~179pt `hotZone`). The project has already hit this exact class of bug once: STATE.md Phase 40-03 documents a "badge-tap bug" root-caused to "`NotchWindowController`'s click-through `hotZone` didn't reliably cover the badge overlay's actual position" — the fix there was to SIDESTEP the geometry entirely (move the indicator to the menu bar) rather than widen the zone. That sidestep is not available here — D-12 requires the bubble to be a real in-notch tap target, so the geometry problem must be solved directly this time, not routed around.
**How to avoid:** Before finalizing bubble placement, the plan must include an explicit on-device verification step: does tapping the secondary bubble's actual screen position (to the right of, and further out than, today's small `hotZone`) register as a click at all? If not, `hotZone`'s computation (or the check in `handlePointer`/`syncClickThrough`) needs to grow to cover the bubble's real position while the ambient/wing tier is showing — mirroring how `visibleContentZone()` already does per-presentation-aware sizing for the EXPANDED tier (`NotchWindowController.swift:1250-1307`), just not yet for the collapsed/wing tier.
**Warning signs:** Bubble renders correctly, spring animates correctly, but tapping it does nothing (click passes through to whatever app is under the notch) — this would look like a "gesture didn't fire" bug but is actually an AppKit `ignoresMouseEvents` geometry bug, much harder to spot from the SwiftUI side alone.

### Pitfall 3: `matchedGeometryEffect` id collision if the bubble ever reuses `"island"`
**What goes wrong:** Every existing shape shares `id: "island"` specifically BECAUSE only one renders at a time — this is what makes the single black shape morph seamlessly between Charging/Device/NowPlaying/Countdown/idle. If the secondary bubble is accidentally given `id: "island"` too (e.g. copy-pasted from `wingsShape`'s pattern without updating the id), SwiftUI will attempt to treat it as a competing source/destination for the SAME morph target as the primary pill, producing undefined/glitchy geometry — likely the exact "geometry collisions" success criterion #3 warns against.
**Why it happens:** Every other shape-creation call site in this file is copy-paste-and-adjust from `wingsShape`/`blobShape`/`collapsedIsland`, all of which hardcode `"island"`.
**How to avoid:** The new shape call must use a distinct literal id (e.g. `"secondaryBubble"`) — grep for `"island"` after implementation to confirm no accidental copy-paste left it in.

### Pitfall 4: Staggered reveal (D-11) racing the existing `activityDuration`/spring-wrapper convention
**What goes wrong:** Every existing timed state change in `NotchWindowController` goes through `withAnimation(.spring(response: springResponse, dampingFraction: springDamping))` (`springResponse = 0.6`, `springDamping = 0.62`, `NotchWindowController.swift:386-387`) wrapping a SINGLE state mutation. D-11 asks for TWO sequential visual reveals (primary first, secondary "with a slight delay afterward") from what is conceptually one resolver transition (transient-ends → back to ambient). A naive single `withAnimation` wrapping both `presentation` and `secondary` mutations at once would make them appear simultaneously, not staggered.
**Why it happens:** The codebase's existing convention is "one spring wraps one state change" — D-11 needs a genuinely two-step sequence, which has no exact precedent yet (the closest is the toast's own delayed-appearance-then-auto-dismiss pattern, `NotchWindowController`'s `mediaDismissWorkItem`/`dismissWorkItem` `DispatchWorkItem` + `asyncAfter` convention).
**How to avoid:** Set `presentation` (primary) inside the immediate `withAnimation` block as today, then schedule a SEPARATE `DispatchWorkItem` (mirroring `graceWorkItem`'s exact shape) that sets `secondary` inside its OWN `withAnimation` block after the stagger delay (Claude's Discretion — exact duration TBD on-device, likely 100-200ms based on similar Apple Dynamic Island stagger timings, but this is an assumption, not verified).

## Code Examples

### Circular artwork crop (extends existing `artThumbnail` pattern)
```swift
// Source: adapted from NotchPillView.swift:2518-2536 (artThumbnail) — same nil→placeholder
// structure, Circle() clip instead of RoundedRectangle
@ViewBuilder
private func artThumbnailCircular(_ art: NSImage?, diameter: CGFloat) -> some View {
    if let art {
        Image(nsImage: art)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: diameter, height: diameter)
            .clipShape(Circle())
    } else {
        Circle()
            .fill(Color.white.opacity(0.12))
            .frame(width: diameter, height: diameter)
            .overlay(
                Image(systemName: "music.note")
                    .font(.system(size: diameter * 0.45))
                    .foregroundStyle(.white.opacity(0.7))
            )
    }
}
```

### Ordered ranking table shape (D-03 — illustrative, planner finalizes exact form)
```swift
// Source: pattern only — mirrors this file's existing convention of small, explicit,
// comment-documented pure functions (see nowPlayingLaunchGate, nowPlayingHealthGate)
// D-01/D-02/D-03: explicit 2-entry table, not an if/else chain. Reads as data.
private func resolveAmbientPair(countdown: CalendarCountdownActivity?,
                                 nowPlaying: NowPlayingPresentation) -> (primary: IslandPresentation?, secondary: SecondaryActivity?) {
    // Ordered: first matching row wins. Exactly 2 rows today (D-03 — extend later, not now).
    if let countdown {
        let secondary: SecondaryActivity? = (nowPlaying != .none) ? .nowPlaying(nowPlaying) : nil
        return (.calendarCountdown(countdown), secondary)   // D-01/D-02
    }
    if nowPlaying != .none {
        return (.nowPlayingWings(nowPlaying), nil)           // D-04: single activity, unchanged
    }
    return (nil, nil)   // falls through to existing .idle
}
```

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | A new `id:` within the SAME shared `@Namespace` satisfies ROADMAP's "distinct matchedGeometryEffect namespaces" wording, without needing a genuinely separate `@Namespace` | Architecture Patterns, Pattern 2 | Low — if wrong, adding a second `@Namespace private var secondaryNS` is a one-line, low-risk change; does not invalidate anything else in this research |
| A2 | The stagger delay (D-11) should be ~100-200ms, based on general Apple Dynamic Island precedent | Common Pitfalls, Pitfall 4 | Low — explicitly flagged in CONTEXT.md as Claude's Discretion, resolved via on-device tuning regardless of this research's guess |
| A3 | `hotZone`'s fixed small-rect sizing (Pitfall 2) will actually block bubble taps, not just theoretically could | Common Pitfalls, Pitfall 2 | Medium — this is read directly from source (`NotchWindowController.swift:995,1217`), so the MECHANISM is verified fact, not assumed; what's assumed is that no other code path (not found in this session's read) compensates for it before the bubble's tap gesture would fire. Planner should treat this as a mandatory on-device verification task, not skip it on the assumption the mechanism read is wrong |

**If this table is empty:** N/A — 3 assumptions logged above, all low-to-medium risk, all flagged for on-device confirmation during planning/execution rather than blocking research.

## Open Questions

1. **Does the existing `hotZone` already fail to cover the outer edges of TODAY's wings (Charging/Device/NowPlaying), or does some other mechanism compensate?**
   - What we know: `hotZone` is fixed to the small collapsed-pill rect (`NotchWindowController.swift:995`); `handlePointer` gates click-through on this same small zone whenever `isExpanded == false` (`NotchWindowController.swift:1217`); wings render at 290pt / `wingsLabelWidth`-driven widths, wider than the pill.
   - What's unclear: Whether this is a live, unnoticed limitation on today's wings (tap-to-toggle only working near notch-center) or whether something else (not found in this session's read of `NotchWindowController.swift`/`NotchPillView.swift`) compensates.
   - Recommendation: Planner should schedule an EARLY on-device spike task (before building the bubble's visual layer) that simply taps the far-right edge of an existing wing (e.g. the Charging percentage text) and confirms whether it currently registers a click. This single test resolves Pitfall 2 definitively before any bubble-specific work begins, and de-risks the rest of the phase.

2. **Exact stagger delay and bubble diameter/gap values**
   - What we know: Ranges given in CONTEXT.md (24-28pt diameter), explicit Claude's Discretion.
   - What's unclear: Real on-screen proportions against the measured notch (179×32pt on the build machine per project memory).
   - Recommendation: Tune on-device per this project's established precedent (Phase 41 countdown wing width fix, Phase 39-07 OSD wing calibration) — start at the geometric midpoint of the given ranges and iterate.

## Environment Availability

Skipped — this phase has no external tool/service/runtime dependencies beyond the existing Xcode/Swift toolchain already verified working in every prior phase of this project.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (existing `IsletTests` target) |
| Config file | Standard Xcode test target — no separate config |
| Quick run command | `xcodebuild build -scheme Islet` (per project memory: `xcodebuild test` hangs headless — tests are hosted in the full `Islet.app`; route actual test execution to manual Cmd-U in Xcode GUI) |
| Full suite command | Manual Cmd-U in Xcode (per `xcodebuild-test-headless-hang` project memory) |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DUAL-01 | Both Countdown + NowPlaying live → primary=.calendarCountdown, secondary=.nowPlaying | unit | `IslandResolverTests.swift`, new test method, run via Cmd-U | ✅ file exists, add test method |
| DUAL-01 (D-04) | Only one live → secondary is nil, byte-identical to today | unit (regression) | Existing `testNoTransientWhilePlayingReturnsToWings`-style tests extended/added | ✅ |
| DUAL-01 (D-10) | Transient active → both primary AND secondary suppressed | unit | New test mirroring `testChargingOutranksDeviceAndMedia` but asserting `secondary == nil` | ✅ |
| DUAL-01 (D-12) | Tap on bubble → expands to that activity | manual-only | On-device tap test — AppKit click-through geometry (Pitfall 2) is not unit-testable | N/A — human-verify checkpoint required |
| DUAL-01 (criterion 3) | No geometry glitches/dropped frames between primary/secondary shapes | manual-only | On-device visual UAT | N/A — human-verify checkpoint required |

### Sampling Rate
- **Per task commit:** `xcodebuild build -scheme Islet` (compiles, catches type errors in the new resolver/view code)
- **Per wave merge:** Full Cmd-U run in Xcode GUI (per project's own established headless-hang workaround) + on-device visual check of the dual-activity state
- **Phase gate:** Full suite green + on-device human-verify checkpoint covering D-12 (tap target) and success criterion 3 (no visual glitches) before `/gsd:verify-work`

### Wave 0 Gaps
None — `IslandResolverTests.swift` already exists with the exact pattern (build-by-hand `CalendarCountdownActivity`/`NowPlayingPresentation` values, assert `resolve(...)` output) this phase's new tests extend. No new test infrastructure needed.

## Security Domain

Not applicable — this phase touches no authentication, session, input-validation-from-untrusted-source, or cryptography surface. The `SecondaryActivity`/artwork data flows entirely from already-trusted local sources (MediaRemote adapter, EventKit) that existing phases (4, 41) already established as trusted inputs; no new external/untrusted data enters the system in this phase.

## Sources

### Primary (HIGH confidence — direct source read this session)
- `Islet/Notch/IslandResolver.swift` (full file) — `resolve()`, `IslandPresentation`, `ActiveTransient`, `TransientQueue`, existing ambient-branch precedence logic
- `Islet/Notch/IslandPresentationState.swift` (full file) — the `@Published` carrier shape
- `Islet/Notch/NowPlayingPresentation.swift` (full file) — `NowPlayingPresentation`, artwork-latency handling precedent
- `Islet/Notch/NotchPillView.swift` (targeted reads: lines 190-260, 680-870, 1730-2340, 2510-2560) — `@Namespace`/`matchedGeometryEffect` convention, `presentationSwitch`, `blobShape`/`wingsShape`/`collapsedIsland`, `countdownWings`, `mediaWingsOrToast`, `artThumbnail`
- `Islet/Notch/NotchWindowController.swift` (targeted reads: lines 740-1000, 1190-1420) — `currentPresentation()`, `positionAndShow()`, `hotZone`/`expandedZone`/`visibleContentZone()`, `handlePointer(at:)`, `syncClickThrough()`
- `IsletTests/IslandResolverTests.swift` (partial read) — existing test conventions for `resolve()`
- `.planning/phases/42-dual-activity-display/42-CONTEXT.md` — locked decisions
- `.planning/REQUIREMENTS.md`, `.planning/STATE.md` — DUAL-01 scope, project decision history, Phase 40-03 badge-tap bug precedent

### Secondary (MEDIUM confidence)
None — this phase required no external/web research; it is a pure codebase-extension whose entire domain is internal to files already read directly.

### Tertiary (LOW confidence)
None.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new dependencies, every reused component read directly from source
- Architecture: HIGH — composition point, additive-field shape, and namespace/id strategy all grounded in direct source reads and this project's own documented conventions
- Pitfalls: HIGH on mechanism (hotZone/handlePointer code read directly), MEDIUM on real-world impact (whether it actually blocks bubble taps needs on-device confirmation — flagged as Open Question 1, not asserted as fact)

**Research date:** 2026-07-18
**Valid until:** No expiry concern — this is an internal-codebase-only research pass with no external library/API surface to go stale; valid as long as `IslandResolver.swift`/`NotchPillView.swift`/`NotchWindowController.swift` are unchanged from this session's reads.
