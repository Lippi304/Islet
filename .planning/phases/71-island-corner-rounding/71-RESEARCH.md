# Phase 71: Island Corner Rounding - Research

**Researched:** 2026-07-30
**Domain:** SwiftUI custom `Shape` geometry tuning + DEBUG-only `@AppStorage`/`NSMenu` live-tuner pattern (native macOS app, no external dependencies)
**Confidence:** HIGH — every claim in this document is `[VERIFIED: direct code read]` against the actual working tree at `/Users/lippi304/conductor/workspaces/notch/algiers`, not training-data inference. This is a pure in-repo geometry/tuning-UI change with zero external libraries, zero network calls, zero new APIs.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Both `topCornerRadius` and `bottomCornerRadius` (currently 12/6 in `wingsShape()`'s `NotchShape` call) increase, but the top/bottom asymmetry stays — not a fully uniform "true pill" (which would push both toward ~16, half the 32pt wing height). User explicitly rejected the uniform-pill option.
- **D-02:** Exact starting numbers are the planner's/executor's call, not baked in during discussion — refine via the new DEBUG tuner (D-03) on real hardware, consistent with how every other wing constant in this codebase was tuned (see the many "Round N: baked in from on-device tuning" comments in `NotchPillView.swift`).
- **D-03:** The new SHAPE-03 tuner is **one combined "Corner Radius" `@AppStorage` axis**, not two independent Top/Bottom axes. It shifts both `topCornerRadius` and `bottomCornerRadius` by the same delta, preserving whatever fixed asymmetry ratio the planner bakes in (D-01/D-02). Matches the seed's "a new nudge axis" (singular) framing.
- **D-04:** Wire it exactly like the existing Wing Tuner: `#if DEBUG`-gated `@AppStorage` key in `ActivitySettings.swift`, always-0-in-Release computed read point in `NotchPillView.swift` (mirrors `wingLeadingNudge`/`wingMarginNudge` etc.), NSMenu buttons + Reset + Print actions in `AppDelegate.swift`.
- **D-05:** The new Corner Radius nudge uses **two step sizes: ±1 and ±5** — a fine step for precision plus a coarse jump for fast large adjustments, mirroring the existing Margin axis's multi-tier button convention (as opposed to Leading/Trailing's single ±2 step). Given the corner radius's small usable range (~6-16pt total), do not add a ±10/±20 tier — that would overshoot immediately.

### Claude's Discretion

- Exact final `topCornerRadius`/`bottomCornerRadius` starting values (D-02).
- Exact menu item ordering/labels for the new tuner buttons, following the existing Wing Tuner menu's visual convention.

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SHAPE-02 | The collapsed-wide (wings) island state renders with noticeably more rounded corners at both ends of its outer silhouette, closer to a full pill shape than today's more rectangular corners | Single call site identified (`NotchPillView.swift:3041`), exact current values (12/6) confirmed, path-validity math derived (see Common Pitfalls #1/#2), and the scope-accuracy discrepancy around "Now Playing glance" documented (see Common Pitfalls #3) so the planner writes an accurate task list |
| SHAPE-03 | (DEBUG only) A new live-tuning nudge control for the wing corner radius, wired the same way as the existing Wing Tuner (`@AppStorage`, DEBUG-menu-only) | Exact 3-file Wing Tuner wiring pattern extracted verbatim from `ActivitySettings.swift`/`NotchPillView.swift`/`AppDelegate.swift` (see Code Examples) — new axis is a direct mechanical extension of this pattern |
</phase_requirements>

## Summary

This is a small, self-contained, zero-dependency phase: two `CGFloat` literals at one call site (`wingsShape()`, `NotchPillView.swift:3041`) change from `NotchShape(topCornerRadius: 12, bottomCornerRadius: 6)` to larger, on-device-tuned values, plus one new `@AppStorage`-backed DEBUG nudge axis wired through the exact same 3-file pattern (`ActivitySettings.swift` key → `NotchPillView.swift` computed read point → `AppDelegate.swift` `NSMenu` buttons) already proven by the existing Leading/Trailing/Margin/Gap Wing Tuner axes. `NotchShape` itself needs zero code changes — it already takes `topCornerRadius`/`bottomCornerRadius` as plain stored properties, and every consumer (the `.fill`, the Liquid Glass rim overlay, the `matchedGeometryEffect` morph) reads those properties generically off the `shape` instance, so the new radii propagate everywhere `wingsShape()` is called with zero secondary code changes.

The one finding that materially affects planning is a **scope-accuracy gap between the phase's own stated goal and the actual code**: the phase description names "Now Playing glance" as one of the HUDs that gets rounder via `wingsShape()`, but direct code read shows `mediaWingsOrToast()` (the live Now-Playing wing + song-change toast) and `resumePreviewWings()` (the idle-hover "resume last track" preview) each instantiate their **own** separate `NotchShape` and never call `wingsShape()` at all. Under a strict reading of CONTEXT.md's own phase boundary ("this phase touches `wingsShape()` only") and SC#1's own wording ("every wing-state HUD that routes through `wingsShape()`"), these two Now-Playing-related wings are *not* in scope and will stay at their current 6/6 and 6/toast-dependent radii while every other wing (Charging, Device, Focus/DND, Calendar Countdown, OSD, Caps Lock, Update, Download, Timer, Meeting — 10 functions, all confirmed calling `wingsShape()`) gets rounder. This needs a one-line confirmation from the planner/user before task-writing, not a silent decision either way — see Common Pitfalls #3 and Open Questions #1.

**Primary recommendation:** Bump `wingsShape()`'s single `NotchShape(topCornerRadius: 12, bottomCornerRadius: 6)` call site to noticeably larger, still-asymmetric values (e.g. a `+4` bump to something like 16/10 as a *starting point* for on-device tuning, not a locked number — see Pitfall #1 for the hard ceiling this must respect), then mechanically extend the existing Wing Tuner 3-file pattern with one new `debugWingCornerRadiusNudgeKey` axis using ±1/±5 step buttons, exactly mirroring the Margin axis's multi-tier button layout. Confirm the Now Playing glance scope question with the user during planning before writing the task list.

## Architectural Responsibility Map

This is a single-process native macOS app — no browser/server/CDN tiers apply. The relevant tiers are:

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Wing corner-radius geometry (SHAPE-02) | SwiftUI View layer (`NotchPillView.swift`, `wingsShape()`) | Shape primitive (`NotchShape.swift`) | `NotchShape` is a dumb, already-parameterized `Shape` struct; all actual radius *values* live at the one call site in `NotchPillView.swift`, not in the shape definition itself |
| Liquid Glass rim overlay geometry | SwiftUI View layer (`liquidGlassEffectLayer`/`legacyLiquidGlassEffectLayer`) | — | Reads `shape.topCornerRadius`/`shape.bottomCornerRadius` directly off the passed-in `NotchShape` instance — auto-inherits any radius change, zero code change needed here |
| DEBUG live-tuning control surface (SHAPE-03) | AppKit (`AppDelegate.swift`, `NSStatusItem`/`NSMenu`) | SwiftUI `@AppStorage` read point (`NotchPillView.swift`) | Matches the existing Wing Tuner: AppKit owns the menu/button UI (there is no in-panel SwiftUI settings surface for this dev tool), SwiftUI owns reading the persisted value at render time |
| Nudge persistence across relaunch | `UserDefaults` / `@AppStorage` (`ActivitySettings.swift` key constant) | — | Plain `UserDefaults.standard` reads/writes, identical mechanism to every other Wing Tuner axis — no new persistence layer |
| Release-build gating (SC#4) | Swift compiler `#if DEBUG` | — | Compile-time exclusion, not a runtime flag — the existing 4 axes already prove this compiles cleanly out of Release builds |

## Standard Stack

No new libraries, packages, or frameworks are needed for this phase. Every mechanism required (`SwiftUI.Shape`, `@AppStorage`, `AppKit.NSMenu`/`NSStatusItem`) is already in active use in this exact file trio for the Wing Tuner precedent this phase mirrors.

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Extending `NotchShape`'s existing `topCornerRadius`/`bottomCornerRadius` params | Adding a new 4-corner-radius shape variant | Rejected by the user's own CONTEXT.md (`code_context` section): "there is no independent 4-corner control, nor was one requested" — `NotchShape`'s radii are symmetric left/right by construction and that's sufficient for the reference screenshot's bottom-left/top-right emphasis |
| One combined nudge `@AppStorage` axis (D-03) | Two independent Top/Bottom nudge axes | Rejected by locked decision D-03 — matches the seed's singular "a new nudge axis" framing |

## Package Legitimacy Audit

Not applicable — this phase installs no external packages. Nothing to run through slopcheck or a registry check.

## Architecture Patterns

### Data Flow Diagram

```
AppDelegate.setupDebugMenu()  [#if DEBUG only]
    │
    │  NSMenuItem action (e.g. "Corner Radius +1")
    ▼
adjustWingNudge(ActivitySettings.debugWingCornerRadiusNudgeKey, by: 1)
    │
    │  UserDefaults.standard.set(current + delta, forKey:)
    ▼
UserDefaults (persisted, survives relaunch)
    │
    │  @AppStorage(ActivitySettings.debugWingCornerRadiusNudgeKey) — live-observed
    ▼
NotchPillView.debugWingCornerRadiusNudge (Double, #if DEBUG @AppStorage / #else unused)
    │
    │  computed property, Release always returns 0
    ▼
NotchPillView.wingCornerRadiusNudge: CGFloat   [always-compiled read point]
    │
    │  + baked-in top/bottom constants
    ▼
wingsShape()  →  NotchShape(topCornerRadius: BASE_TOP + nudge, bottomCornerRadius: BASE_BOTTOM + nudge)
    │
    ├──► shape.fill(islandFill)                              — visible pill outline
    ├──► liquidGlassEffectLayer(shape:, size:, parameters:)   — rim overlay auto-inherits shape.topCornerRadius/bottomCornerRadius
    └──► 10 wing-content callers (wings(for:), deviceWings(for:), focusWings(for:),
         countdownWings(for:), osdWings(for:), capsLockWings(for:), updateWings(for:),
         downloadWings(for:), timerWings(for:), meetingWings(for:))
              — every one of these renders through this ONE wingsShape() call, so the
                radius change is automatic for all 10 with zero per-wing edits

NOT in this flow (own separate NotchShape instantiation, does NOT call wingsShape()):
    mediaWingsOrToast()     — NotchShape(topCornerRadius: 6, bottomCornerRadius: toast != nil ? 16 : 6)
    resumePreviewWings()    — NotchShape(topCornerRadius: 6, bottomCornerRadius: 6)
    blobShape() callers     — expanded island / switcher row, explicitly out of scope (D-01 domain statement)
    collapsedIsland         — idle pill, explicitly out of scope (SC#2)
```

### Pattern 1: Single-call-site shape parameterization

**What:** `NotchShape` (`Islet/Notch/NotchShape.swift`) is a plain `Shape` struct with two `var` stored properties (`topCornerRadius`, `bottomCornerRadius`), no default-value coupling to any caller. Every rendering context (idle pill, expanded blob, wings, media glance, resume preview) instantiates its own `NotchShape(topCornerRadius:bottomCornerRadius:)` with its own literal values at its own call site.
**When to use:** This is why SHAPE-02 is safe to implement as a one-call-site edit — there is no shared "the" default to worry about breaking other silhouettes.
**Example (current code, `NotchPillView.swift:3041`):**
```swift
// Source: Islet/Notch/NotchPillView.swift:3034-3041 (direct code read, 2026-07-30)
private func wingsShape<Content: View>(
    leftWidth: CGFloat = Self.wingsSize.width / 2,
    rightWidth: CGFloat = Self.wingsSize.width / 2,
    depthScale: CGFloat = 1.0,
    onTap: (() -> Void)? = nil,
    @ViewBuilder content: () -> Content
) -> some View {
    let shape = NotchShape(topCornerRadius: 12, bottomCornerRadius: 6)   // flatter than the downward blob; smaller radius than blobShape's 24
    let size = CGSize(width: leftWidth + rightWidth, height: Self.wingsSize.height * depthScale)
    return shape
        .fill(islandFill)
        .matchedGeometryEffect(id: "island", in: ns)
        .frame(width: size.width, height: size.height)
        .animation(nil, value: size)
        .overlay(liquidGlassEffectLayer(shape: shape, size: size, parameters: .expanded))
        .overlay(content().frame(width: size.width, height: size.height, alignment: .leading))
        .alignmentGuide(HorizontalAlignment.center) { _ in leftWidth }
        .onTapGesture { (onTap ?? onClick)() }
}
```
This is the ONLY line that needs its literal `12`/`6` replaced with `BASE_TOP + wingCornerRadiusNudge` / `BASE_BOTTOM + wingCornerRadiusNudge` (plus the new nudge computed property added near the existing 4 at lines 191-218).

### Pattern 2: DEBUG-only `@AppStorage` nudge axis, 3-file wiring

**What:** Every existing Wing Tuner axis (Leading/Trailing/Margin/Gap) follows an identical 3-file shape. The new Corner Radius axis is a direct, mechanical fifth instance of this exact pattern — no new mechanism to design.
**When to use:** SHAPE-03, verbatim.

**File 1 — `Islet/ActivitySettings.swift:109-117` (key constant):**
```swift
// Source: Islet/ActivitySettings.swift:109-117 (direct code read, 2026-07-30)
#if DEBUG
static let debugWingLeadingNudgeKey = "debug.wingTuner.leadingNudge"
static let debugWingTrailingNudgeKey = "debug.wingTuner.trailingNudge"
static let debugWingMarginNudgeKey = "debug.wingTuner.marginNudge"
static let debugWingGapNudgeKey = "debug.wingTuner.gapNudge"
// NEW for SHAPE-03:
static let debugWingCornerRadiusNudgeKey = "debug.wingTuner.cornerRadiusNudge"
#endif
```

**File 2 — `Islet/Notch/NotchPillView.swift:181-218` (storage + always-compiled read point):**
```swift
// Source: Islet/Notch/NotchPillView.swift:181-218 (direct code read, 2026-07-30)
#if DEBUG
@AppStorage(ActivitySettings.debugWingLeadingNudgeKey) private var debugWingLeadingNudge: Double = 0
@AppStorage(ActivitySettings.debugWingTrailingNudgeKey) private var debugWingTrailingNudge: Double = 0
@AppStorage(ActivitySettings.debugWingMarginNudgeKey) private var debugWingMarginNudge: Double = 0
@AppStorage(ActivitySettings.debugWingGapNudgeKey) private var debugWingGapNudge: Double = 0
// NEW for SHAPE-03:
@AppStorage(ActivitySettings.debugWingCornerRadiusNudgeKey) private var debugWingCornerRadiusNudge: Double = 0
#endif

private var wingMarginNudge: CGFloat {
    #if DEBUG
    return CGFloat(debugWingMarginNudge)
    #else
    return 0
    #endif
}
// NEW for SHAPE-03, same shape:
private var wingCornerRadiusNudge: CGFloat {
    #if DEBUG
    return CGFloat(debugWingCornerRadiusNudge)
    #else
    return 0
    #endif
}
```

**File 3 — `Islet/AppDelegate.swift:522-537` (menu) and `:598-625` (actions):**
```swift
// Source: Islet/AppDelegate.swift:527-532 — Margin's existing multi-tier ±5/±10/±20 button
// convention is the template D-05 explicitly says to mirror for the new ±1/±5 axis:
wingTunerMenu.addItem(withTitle: "Margin -20", action: #selector(debugWingMarginMinus20), keyEquivalent: "")
wingTunerMenu.addItem(withTitle: "Margin -10", action: #selector(debugWingMarginMinus10), keyEquivalent: "")
wingTunerMenu.addItem(withTitle: "Margin -5", action: #selector(debugWingMarginMinus), keyEquivalent: "")
wingTunerMenu.addItem(withTitle: "Margin +5", action: #selector(debugWingMarginPlus), keyEquivalent: "")
wingTunerMenu.addItem(withTitle: "Margin +10", action: #selector(debugWingMarginPlus10), keyEquivalent: "")
wingTunerMenu.addItem(withTitle: "Margin +20", action: #selector(debugWingMarginPlus20), keyEquivalent: "")
// NEW for SHAPE-03 (D-05: ±1/±5 only, no ±10/±20 tier — usable range is only ~6-16pt total):
wingTunerMenu.addItem(withTitle: "Corner Radius -5", action: #selector(debugWingCornerRadiusMinus5), keyEquivalent: "")
wingTunerMenu.addItem(withTitle: "Corner Radius -1", action: #selector(debugWingCornerRadiusMinus1), keyEquivalent: "")
wingTunerMenu.addItem(withTitle: "Corner Radius +1", action: #selector(debugWingCornerRadiusPlus1), keyEquivalent: "")
wingTunerMenu.addItem(withTitle: "Corner Radius +5", action: #selector(debugWingCornerRadiusPlus5), keyEquivalent: "")

// Source: Islet/AppDelegate.swift:593-596 — the shared helper every axis's actions call:
private func adjustWingNudge(_ key: String, by delta: Double) {
    let current = UserDefaults.standard.double(forKey: key)
    UserDefaults.standard.set(current + delta, forKey: key)
}
// NEW actions, same one-line-body style as every existing axis (lines 598-609):
@objc private func debugWingCornerRadiusMinus5() { adjustWingNudge(ActivitySettings.debugWingCornerRadiusNudgeKey, by: -5) }
@objc private func debugWingCornerRadiusMinus1() { adjustWingNudge(ActivitySettings.debugWingCornerRadiusNudgeKey, by: -1) }
@objc private func debugWingCornerRadiusPlus1() { adjustWingNudge(ActivitySettings.debugWingCornerRadiusNudgeKey, by: 1) }
@objc private func debugWingCornerRadiusPlus5() { adjustWingNudge(ActivitySettings.debugWingCornerRadiusNudgeKey, by: 5) }
```
Also extend `debugWingTunerReset()` (line 611-617) to zero the new key, and `debugWingTunerPrint()` (line 619-625) to include it in the printed line — both currently hardcode the 4 existing keys and must be updated to a 5th, not left silently stale (a real "forgot to wire the reset/print" trap given how mechanical this pattern is to copy-paste).

### Anti-Patterns to Avoid

- **Adding a new SwiftUI in-panel settings row for this control:** The existing Wing Tuner is deliberately AppKit-menu-only (a 🐞 status-bar item), not a SwiftUI settings surface — mirror that, don't invent a new UI surface for a dev-only tool.
- **Scaling the nudge or base radii by `resolvedWingDepthScale`:** The existing 4 axes (Leading/Trailing/Margin/Gap) are all fixed-point additive nudges, not depth-scaled — the Corner Radius axis should follow the same convention (a flat point delta), not attempt to scale with the wing's manual depth slider. See Pitfall #1 for why the radii and the depth scale interact dangerously if mixed carelessly.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Live on-device geometry tuning | A new settings panel, a config file, a recompile-per-attempt loop | The existing `@AppStorage` + `NSMenu` Wing Tuner pattern (Pattern 2 above) | Every other wing constant in this codebase (margins, paddings, camera-block widths) was tuned this exact way — proven, zero-friction, and the user explicitly asked for it to be "wired exactly like the existing Wing Tuner" (D-04) |
| Asymmetric rounded-rect corners | A new custom `Shape` with 4 independent corner radii, or SwiftUI's `UnevenRoundedRectangle` | `NotchShape`'s existing `topCornerRadius`/`bottomCornerRadius` params (already symmetric left/right, matches the reference screenshot's needs per CONTEXT.md) | User's own `code_context` section confirms no 4-corner control was requested or needed |

**Key insight:** This entire phase is additive-constant tuning inside an established pattern, not new architecture. The temptation to "improve" the Wing Tuner mechanism while touching it (e.g. consolidating the 5 axes into a struct, adding SwiftUI stepper controls) should be resisted — it's out of scope and risks regressing the 4 working axes for a phase whose only job is a 5th one.

## Common Pitfalls

### Pitfall 1: Corner radii are NOT scaled by `resolvedWingDepthScale` — the depth-scale floor can make oversized radii overflow the rect

**What goes wrong:** `wingsShape()`'s `frame(width:height:)` uses `Self.wingsSize.height * depthScale` (line 3042), but the `NotchShape(topCornerRadius:bottomCornerRadius:)` values passed at line 3041 are fixed literals, never multiplied by `depthScale`. `resolvedWingDepthScale` clamps to `0.8...1.5` (`[VERIFIED: direct code read]` `NotchGeometry.swift:120`, confirmed via `resolvedIslandScale(auto:manualOffset:range:)`'s default parameter). At the minimum clamp (0.8), the wing's rendered height is `32 * 0.8 = 25.6pt`, not the nominal 32pt design height.
**Why it happens:** `NotchShape.path(in:)` (`NotchShape.swift:16-32`) requires `topCornerRadius + bottomCornerRadius <= rect.height` for its `addLine` between the two quad curves to stay non-inverted (the line goes from `rect.minY + topCornerRadius` down to `rect.maxY - bottomCornerRadius`; if the radii sum exceeds the rect height, that line's start point is below its end point and the path self-intersects/degenerates).
**How to avoid:** Whatever base top/bottom values D-02 lands on, plus the maximum nudge the tuner allows (D-05's own stated "~6-16pt total" usable range gives an implicit ceiling), the **sum must stay comfortably under 25.6pt** (the worst-case depth-scaled height), not just under the nominal 32pt. Recommend keeping headroom to ~20pt sum max as a safety margin, and — more importantly — actually test the shape at `resolvedWingDepthScale`'s floor (0.8×) during on-device tuning, not just at the default 1.0× scale, since the manual Depth slider (`islandDepthScaleOffset`, `@AppStorage`) is user-reachable and can independently push depthScale down from auto.
**Warning signs:** A visibly broken/self-intersecting pill outline, or a flat-clipped corner, appearing only when the manual Depth Scale slider is pulled down — not visible during default on-screen tuning.

### Pitfall 2: "Now Playing glance" is named in the phase goal but its code does not route through `wingsShape()` — scope mismatch needs resolving before planning

**What goes wrong:** The phase description and CONTEXT.md's `canonical_refs` section assert "every wing HUD routes through this one function [`wingsShape()`]" and list "Now Playing glance" as one of the covered activities. Direct code read contradicts this: `mediaWingsOrToast()` (`NotchPillView.swift:3205-3247`, the live Now-Playing wing + song-change toast) builds `NotchShape(topCornerRadius: 6, bottomCornerRadius: toast != nil ? 16 : 6)` directly (line 3215) and never calls `wingsShape()`. Likewise `resumePreviewWings()` (`:3280-3308`, the idle-hover "resume last track" preview) builds `NotchShape(topCornerRadius: 6, bottomCornerRadius: 6)` directly (line 3281), also never calling `wingsShape()`. Confirmed by grep: only 10 functions call `wingsShape()` — `wings(for: ChargingActivity)`, `deviceWings(for:)`, `focusWings(for:)`, `countdownWings(for:)`, `osdWings(for:)`, `capsLockWings(for:)`, `updateWings(for:)`, `downloadWings(for:)`, `timerWings(for:)`, `meetingWings(for:)` — and Now Playing/media is not among them.
**Why it happens:** `mediaWingsOrToast` predates the Wing Tuner camera-clearance conversion effort (per its own code comments, it was the "one remaining wing never converted" in some rounds) and has its own bespoke sizing/toast-growth logic that was never folded into the shared `wingsShape()` helper.
**How to avoid:** This is a scope decision, not a code-correctness bug — surface it explicitly to the user/planner rather than silently picking a side. Two honest options: (a) strictly scope to `wingsShape()`'s one call site as CONTEXT.md's domain statement literally says, and correct the phase's own goal wording (Now Playing glance stays visually as-is) — or (b) also update `mediaWingsOrToast`'s and `resumePreviewWings`' own separate `NotchShape(...)` literals to the same new base values (not the nudge — the DEBUG tuner per D-04 only needs to cover `wingsShape()`'s call site; whether these two get the *baked-in* final numbers too is the open question), to actually deliver "every HUD... reads as a fully rounded pill" as literally promised. Either is a small, cheap decision — but it changes the task list (1 call site vs. 3), so it should be resolved before task-writing, not discovered mid-execution.
**Warning signs:** On-device UAT where the user notices Now Playing's wing/toast still looks "squarer" than Charging/OSD/Timer/etc. right after this phase ships, despite the phase claiming "every" HUD was covered.

### Pitfall 3: Reset/Print actions are easy to forget when copy-pasting a 5th axis

**What goes wrong:** `debugWingTunerReset()` (`AppDelegate.swift:611-617`) and `debugWingTunerPrint()` (`:619-625`) both hardcode exactly 4 keys today. A mechanical copy-paste of "add one more axis" that only adds the menu items + individual `@objc` actions (and skips these two shared functions) leaves the new Corner Radius nudge un-resettable via the "Reset Wing Tuner" button and invisible in the "Print Wing Tuner Values" output — silently breaking the documented tuning workflow ("nudge until it looks right, click Print, paste to Claude, click Reset, move to the next wing" — comment at `AppDelegate.swift:518-521`) for this one axis only.
**Why it happens:** These two functions are not auto-derived from the menu item list; they're separately hand-maintained arrays of `UserDefaults.standard.set(0.0, forKey:)` calls / string interpolations.
**How to avoid:** Explicitly include updating both `debugWingTunerReset()` and `debugWingTunerPrint()` as their own checklist item in the plan, not just "add the new axis."
**Warning signs:** Clicking "Reset Wing Tuner" and the Corner Radius nudge visibly staying applied; the printed values line missing a `cornerRadiusNudge=` field.

## Code Examples

See **Architecture Patterns → Pattern 1 and Pattern 2** above for the full, verbatim current-code excerpts (`wingsShape()`'s call site, the 3-file Wing Tuner wiring) and the corresponding new-code sketches for SHAPE-02/SHAPE-03. All code shown is `[VERIFIED: direct code read]` from the actual working tree, not reconstructed from memory.

## State of the Art

Not applicable — this is a pure in-repo constant/pattern change with no external library or API surface to be "current" or "outdated" against. `NotchShape`'s `addQuadCurve`-based path construction (`NotchShape.swift`) and `@AppStorage`-backed dev tooling are both this project's own established, unchanging conventions (see `ISL-01` comment header, and the many "Quick task 260728-wg7" comments tracing the Wing Tuner's own introduction).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | A starting bump like 16/10 (from today's 12/6) is a reasonable first on-device-tuning value | Summary / Primary recommendation | Low — explicitly framed as a non-locked starting point (D-02 leaves the exact number to on-device tuning via the new SHAPE-03 tool itself), not a claim requiring separate user confirmation |

No other claims in this document are assumed — every factual statement about current code, call sites, function names, line numbers, and constant values was confirmed via direct `Read`/`grep` against the working tree during this research session, tagged `[VERIFIED: direct code read]` throughout.

**If this table is near-empty:** Correct — this phase requires no external-knowledge claims (no library APIs, no package versions, no compliance/security standards) that could be stale or hallucinated. The only genuine open item is the scope question in Pitfall #2 / Open Questions #1, which is a **decision**, not an assumption to verify.

## Open Questions

1. **(RESOLVED: see CONTEXT.md D-06)** Does "Now Playing glance" (mentioned in the phase Goal) need its own `NotchShape` literals updated, given it does not route through `wingsShape()`?
   - What we know: `mediaWingsOrToast()` and `resumePreviewWings()` each build a separate `NotchShape` and are not touched by a `wingsShape()`-only edit. CONTEXT.md's own domain statement scopes strictly to `wingsShape()`.
   - What's unclear: Whether the user's mental model of "every HUD gets rounder" implicitly includes these two, or whether they were simply mis-described as routing through `wingsShape()` and are correctly out of scope.
   - Recommendation: Planner should ask this as a single confirming question before writing tasks (or the discuss-phase agent should have caught it — flagging here since this research happened after CONTEXT.md was already locked). If in scope, add 2 small extra call-site edits (no new mechanism, same literal-value bump) — cheap either way, but changes the task list and the SC#1 acceptance check.

## Environment Availability

Skipped — this phase has no external dependencies (pure Swift/SwiftUI/AppKit code change inside the existing Xcode project, no new packages, no new frameworks, no new system permissions).

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (existing `IsletTests` target) |
| Config file | none — standard Xcode test target wired into the `Islet.xcodeproj` scheme, no separate `.xctestplan` found |
| Quick run command | `xcodebuild test -scheme Islet -destination 'platform=macOS' -only-testing:IsletTests/NotchShapeTests` |
| Full suite command | `xcodebuild test -scheme Islet -destination 'platform=macOS'` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SHAPE-02 | New wings radii produce a valid, closed, non-self-intersecting `NotchShape` path at the nominal wings rect (290×32) AND at the depth-scale floor rect (290×25.6, per Pitfall #1) | unit | `xcodebuild test -scheme Islet -only-testing:IsletTests/NotchShapeTests` | ✅ `IsletTests/NotchShapeTests.swift` exists with the exact precedent pattern (`testLargerTopCornerRadiusProducesAClosedNonEmptyPath`, lines 47-53) — extend with 2 new test methods, no new file needed |
| SHAPE-02 | The rounding visually reads as "noticeably more rounded... matching the reference screenshot" (SC#1) | manual (on-device UAT) | — no automated visual-diff exists in this codebase; matches this project's own established convention of on-device screenshot comparison for every prior shape-tuning phase (SHAPE-01/Phase 29 precedent) | N/A — manual-only by design |
| SHAPE-02 | Idle/collapsed pill is pixel-identical to today (SC#2) | unit (regression guard) | `xcodebuild test -scheme Islet -only-testing:IsletTests/NotchShapeTests` | ✅ existing `testPathIsNonEmpty`/`testPathStaysWithinItsRect` cover `NotchShape()`'s default-radii (idle) path structurally; add one explicit assertion that `collapsedIsland`'s call site literal values are unchanged (grep-based structural check, mirrors this codebase's existing "grep-based structural invariant" convention seen in `STATE.md`'s Phase 67.1 verification notes) |
| SHAPE-03 | New `@AppStorage` key exists with the correct string literal, DEBUG-gated | unit | `xcodebuild test -scheme Islet -only-testing:IsletTests/ActivitySettingsTests` | ✅ `IsletTests/ActivitySettingsTests.swift` exists with the exact precedent pattern (`testNewV110KeyNames`, `testSwitcherKeyNames` — literal-string key-name assertions), extend with a `testWingCornerRadiusNudgeKeyName` following the same style |
| SHAPE-03 | Live-adjusts on real hardware via `@AppStorage`, persists across relaunch (SC#3) | manual (on-device UAT) | — `@AppStorage`'s live-update and cross-relaunch persistence for the other 4 axes has never had an automated test in this codebase either (confirmed: no test file references `debugWing*` beyond key-name checks) | N/A — manual-only by design, matches existing Wing Tuner precedent exactly |
| SHAPE-03 | Release builds expose no corner-radius tuning UI (SC#4) | unit | `xcodebuild build -scheme Islet -configuration Release` (build-time `#if DEBUG` exclusion — no test needed, the existing 4 axes' Release-clean build is the proof this mechanism works) | ✅ covered by the existing Release build verification convention (see `STATE.md` Phase 67.1 Plan 05 Task 1: "Release build succeeded") |

### Sampling Rate
- **Per task commit:** `xcodebuild test -scheme Islet -only-testing:IsletTests/NotchShapeTests -only-testing:IsletTests/ActivitySettingsTests`
- **Per wave merge:** `xcodebuild test -scheme Islet -destination 'platform=macOS'` (full suite — this project's baseline is 569 tests / 6 known pre-existing failures per `STATE.md`; the plan should confirm zero *new* failures, not zero failures)
- **Phase gate:** Full suite green (modulo the 6 documented pre-existing failures) before `/gsd:verify-work`, plus the on-device UAT checkpoint for SC#1/SC#3 (visual rounding + live-tuning persistence — neither is automatable)

### Wave 0 Gaps
- [ ] `IsletTests/NotchShapeTests.swift` — add a test asserting the new base top/bottom radii produce a valid closed path at both the nominal (290×32) and depth-scale-floor (290×25.6) wings rect sizes — the concrete regression guard for Pitfall #1
- [ ] `IsletTests/ActivitySettingsTests.swift` — add a test asserting the new `debugWingCornerRadiusNudgeKey` literal string, mirroring `testNewV110KeyNames`'s existing style
- [ ] No framework install needed — `IsletTests` target and XCTest are already fully wired

## Security Domain

This phase has no attack surface: no network calls, no user-supplied input parsing (the DEBUG nudge menu is a fixed, hardcoded set of `NSMenuItem`s with no free-text entry, identical to the 4 existing Wing Tuner axes), no new persisted data beyond a `Double` delta in `UserDefaults` (same class of data as the 4 existing nudge keys, already shipping). No ASVS category meaningfully applies.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-------------------|
| V2 Authentication | no | N/A — no auth surface touched |
| V3 Session Management | no | N/A |
| V4 Access Control | no | N/A — DEBUG-only gating is a build-time compiler directive (`#if DEBUG`), not an access-control boundary; Release builds cannot reach this code at all (compiled out), which is a stronger guarantee than a runtime permission check |
| V5 Input Validation | n/a (trivial) | The only "input" is fixed ±1/±5 button taps, not free text — no injection surface. Recommend (not required) clamping the resulting nudged radii to a sane non-negative floor (e.g. `max(0, base + nudge)`) purely for UI robustness against a user mashing the minus button past zero, mirroring the existing axes' lack of explicit clamping (none of Leading/Trailing/Margin/Gap clamp either — this project's own precedent is "no clamp, trust the dev using the dev tool") |
| V6 Cryptography | no | N/A |

### Known Threat Patterns for this stack

Not applicable — no threat patterns from OWASP ASVS map meaningfully onto a local, compile-time-gated, hardcoded-menu developer tuning tool with no network or file I/O beyond `UserDefaults`.

## Sources

### Primary (HIGH confidence — direct code read against the working tree, 2026-07-30)
- `Islet/Notch/NotchShape.swift` — full file read, shape path construction math
- `Islet/Notch/NotchPillView.swift` — `wingsShape()` (lines 3034-3091), Wing Tuner storage/read-points (181-218), `mediaWingsOrToast()` (3184-3247), `resumePreviewWings()` (3269-3308), `resolvedWingDepthScale` (2905-2907), `liquidGlassEffectLayer`/`legacyLiquidGlassEffectLayer` (706-761), full grep of all `wingsShape(` call sites and all `*Wings(for:` function definitions
- `Islet/ActivitySettings.swift` — Wing Tuner key constants (109-117)
- `Islet/AppDelegate.swift` — `setupDebugMenu()` Wing Tuner menu construction (499-568), Wing Tuner `@objc` actions (590-625)
- `Islet/Notch/NotchGeometry.swift` — `resolvedIslandScale(auto:manualOffset:range:)` default clamp range (line 120)
- `IsletTests/NotchShapeTests.swift` — existing shape-path test precedent
- `IsletTests/ActivitySettingsTests.swift` — existing key-name test precedent (grep of `func test` names)
- `.planning/config.json` — confirmed `nyquist_validation: true`
- `CLAUDE.md` (project root) — confirmed no additional project constraints beyond the general Swift/SwiftUI stack guidance already reflected above

### Secondary (MEDIUM confidence)
None used — no WebSearch/Context7 lookups were needed for this phase; it is entirely an in-repo pattern-extension task.

### Tertiary (LOW confidence)
None.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no external stack involved, pure in-repo pattern reuse, every line verified against the actual working tree
- Architecture: HIGH — single call site confirmed by exhaustive grep, data flow traced end-to-end through actual function bodies
- Pitfalls: HIGH — Pitfall #1 (depth-scale/radius-sum math) and #3 (Reset/Print staleness) derived from direct reading of the exact functions involved; Pitfall #2 (Now Playing scope gap) is a directly observed code/spec discrepancy, not a guess

**Research date:** 2026-07-30
**Valid until:** Effectively indefinite for the code-structure claims (this is this project's own source, not a third-party API that can drift) — re-verify only if another phase touches `wingsShape()`, `NotchShape`, or the Wing Tuner mechanism before Phase 71 executes.
