# Phase 45: View Switcher Morph Fix - Research

**Researched:** 2026-07-19
**Domain:** SwiftUI view identity / `matchedGeometryEffect` continuity across `@ViewBuilder switch` branches
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** If the user taps a new tab while the island is still mid-morph toward a previously-tapped tab, the spring must retarget immediately toward the new tab — standard SwiftUI spring retargeting behavior. Never ignore the tap and never queue it for after the current morph finishes; a rapid tap sequence must read as one continuous redirect, not two discrete hops.
- **D-02:** The tab-switch morph must reuse the exact same spring animation (same `.spring(response:dampingFraction:)` parameters) already driving the island's existing expand/collapse `matchedGeometryEffect` transitions — no new/distinct spring tuning for tab switches specifically. Consistency with the rest of the app's motion language is the priority, not a bespoke feel.
- **D-03:** All 12 pairwise tab-to-tab transitions (Home↔Tray, Home↔Calendar, Home↔Weather, Tray↔Calendar, Tray↔Weather, Calendar↔Weather, both directions each) must be explicitly walked and confirmed glitch-free on-device — matches ROADMAP success criterion #3 literally. This is stricter than Phase 43/44's "quick representative check" precedent; the user explicitly wants full pairwise coverage for this phase, not a sample.

### Claude's Discretion

- Exact mechanism for making `presentationSwitch`'s tab cases participate in one continuous morph (e.g. restructuring away from a hard `switch`-per-case, a shared container with conditional content, or another approach) — implementation detail for research/planning to determine. The user was not asked to choose an approach; only the observable behavior (D-01/D-02/D-03) was decided.
- Whether/how the interrupted-mid-morph retarget (D-01) requires any special-cased animation-cancellation code, or falls out naturally once the structural-identity-change root cause is fixed — for research/planning to determine.

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope. Two todos were reviewed and confirmed genuinely out of domain:
- "Island briefly disappears during click-through" — different code path (click-through hot-zone `syncClickThrough()`/`visibleContentZone()`), not the tab-morph code this phase targets. Needs its own `/gsd-debug` session.
- "Quick Action disabled state has no controller gate" — unrelated (Quick Action button enablement), not in domain.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-------------------|
| SWITCH-01 | Switching between Home/Tray/Calendar/Weather tabs animates the island continuously (single spring morph via the existing `matchedGeometryEffect`) directly to the new tab's size — no intermediate disappear/rebuild flicker | Root cause confirmed by code read (see Architecture Patterns): `presentationSwitch` calls `blobShape(...)` from 6 textually-distinct switch-case branches (one shared function, but SwiftUI's structural-identity model treats each branch as a distinct subtree). Fix mechanism: collapse to ONE `blobShape` call site outside the switch, computing per-case width/height as plain values (mirrors the codebase's own existing `isTrayPresentation ? … : …` pattern at the outer `body` frame), with an inner `@ViewBuilder` switch/if for content only. See Code Examples. |
| SWITCH-02 | The visual glitch where the island briefly renders behind the switcher pill buttons during a large→small transition (e.g. Calendar → Tray) is eliminated | Same root cause: every branch currently instantiates its OWN `switcherRow`, nested inside its own VStack inside its own `.overlay`. During a remove+insert cycle, two separate `switcherRow` instances (departing + arriving) can transiently coexist with undefined z-order relative to each other's animating shape. Collapsing to one `blobShape` call site makes `switcherRow` render from exactly ONE continuously-existing instance (per blobShape's own internal VStack: `content()` then `switcherRow`), which structurally cannot go behind/in front of "the wrong" shape because there is only ever one shape+one switcherRow pair animating together. |
</phase_requirements>

## Summary

The root cause (already confirmed by the user during discuss-phase and re-confirmed here via direct code read) is a textbook instance of SwiftUI's **structural identity** model, documented by Apple's own WWDC21 "Demystify SwiftUI" session: a `@ViewBuilder switch` (or `if/else`) assigns each case its own position in the view-type tree. Even though `NotchPillView.presentationSwitch` (`Islet/Notch/NotchPillView.swift:774-816`) routes all 6 switcher-row-showing tab cases through the *same* `blobShape(...)` helper function, each case calls it from a *textually distinct branch* — 6 separate call sites (`homeEmptyState` ~965, `mediaExpanded` ~2787, `mediaUnavailable` ~2894, `calendarFullView` ~1020, `weatherFullView` ~1213, `trayFullView` ~1433). SwiftUI's diffing treats a branch change as removing the old subtree and inserting a new one — not as updating one continuously-existing view — which breaks both the `matchedGeometryEffect`-driven frame morph (SWITCH-01) and produces two transiently-coexisting `switcherRow` instances with undefined relative z-order during the crossfade (SWITCH-02).

Code inspection found the fix boundary is **narrower and simpler than the 6 call sites suggest**: across all 6 cases, `topCornerRadius` (24), `bottomCornerRadius` (32), `alignment` (`.top`), `shelfItems`/`shelfVisible` (effectively always `[]`/`false` — `shelfStripVisible` is a hardcoded `false` constant per Phase 31/TRAY-01), and `showSwitcher` (always `true`) are **already identical constants**. Only `width` and `height` genuinely vary per case, plus the inner content. This means the concrete fix is: hoist ONE `blobShape` call outside the switch, compute `width`/`height` as plain per-case values (the codebase already has this exact pattern at `body`'s own outer `.frame(width:height:)`, lines 888-895, via `isTrayPresentation`/`isCalendarPresentation`/`isOnboardingPresentation` booleans), and put only the genuinely-different content in an inner `@ViewBuilder` switch/if passed as `blobShape`'s trailing closure.

D-01 (interrupted-tap spring retargeting) requires no special-cased cancellation code: `NotchWindowController.handleSwitcherSelect(_:)` (line 1605) already wraps `viewSwitcherState.selectedView = view; renderPresentation()` in the exact shared `withAnimation(.spring(response: 0.6, dampingFraction: 0.62))` (D-02 is *already* satisfied structurally — no new spring tuning needed). Once the outer shape/frame keeps continuous identity across cases, a second `withAnimation` call targeting the same still-animating `CGFloat` frame properties on the same view will retarget automatically — this is standard SwiftUI spring-interruption behavior, not something that needs to be built.

The AppKit "three-site rule" geometry (frame reservation in `NotchWindowController.positionAndShow()`, the `contentSize` branch in `visibleContentZone()`) does **not** need to change: `positionAndShow()` already reserves a single static UNION frame covering every presentation up front (it is not re-computed per tab switch), and `visibleContentZone()`'s per-case `contentSize` branch is a pure geometric lookup keyed off the `IslandPresentation` enum case — entirely independent of how `NotchPillView`'s SwiftUI internals are structured. As long as the fix does not change which width/height value each case maps to, no `NotchWindowController.swift` changes are required — this fix is purely internal to `NotchPillView.swift`.

**Primary recommendation:** Collapse `presentationSwitch`'s 6 switcher-row-showing cases (`.homeEmpty`, `.homeLastPlayed` (via `mediaExpanded`), `.nowPlayingExpanded(_, true)` (via `mediaExpanded`), `.nowPlayingExpanded(_, false)` (`mediaUnavailable`), `.calendarExpanded`, `.weatherExpanded`, `.trayExpanded`) into ONE `blobShape` call site with computed `tabWidth`/`tabHeight` value properties and an inner content-only switch. Leave every other `presentationSwitch` case (onboarding, charging, device, focus, osd, nowPlayingWings, calendarCountdown, quickActionPicker, idle) untouched — they are not part of the 4-tab switcher and are out of this phase's scope.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Tab-switch morph animation (shape/frame continuity, `matchedGeometryEffect`) | SwiftUI View (`NotchPillView.presentationSwitch`/`blobShape`) | — | Purely a rendering/animation concern; this is the ONLY tier this phase touches |
| Tab tap intent + spring wrapping | Controller (`NotchWindowController.handleSwitcherSelect`) | — | Already correct/complete (D-01/D-02 satisfied structurally today) — no change needed |
| Which tab shows which presentation case | Resolver (`IslandResolver.resolve`, `showsSwitcherRow(for:)`) | — | Pure function, already correct, untouched by this phase |
| Click-through hit-zone sizing per active tab | AppKit Window (`NotchWindowController.visibleContentZone`/`positionAndShow`) | — | Independent of SwiftUI view identity; only needs to stay in sync if the width/height *values* per case change (they must not) |

## Standard Stack

No new libraries, frameworks, or packages are introduced by this phase. This is a pure internal SwiftUI restructuring using APIs already in use throughout `NotchPillView.swift`:

| API | Purpose | Why Standard (for this codebase) |
|-----|---------|-----------------------------------|
| `matchedGeometryEffect(id:in:)` [VERIFIED: Apple Developer Documentation] | Continuous geometry interpolation between two states of the SAME identified view | Already the mechanism driving every other expand/collapse transition in this file; this phase does not add a new technique, it fixes the precondition (stable view identity) that makes it work |
| `withAnimation(.spring(response:dampingFraction:))` [VERIFIED: existing codebase, `NotchWindowController.swift:392-393`] | Wraps state mutations that drive the morph | Already correctly wired at `handleSwitcherSelect` (line 1605) with `springResponse = 0.6`, `springDamping = 0.62` — the exact constants D-02 requires reusing, unchanged |
| `@ViewBuilder` switch/if (content-only) | Branches purely the rendered content, not the animated container's identity | This is the crux of the fix — see Architecture Patterns |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Single `blobShape` call + inner content switch | `.id()`-based forced-identity tricks | `.id()` intentionally triggers a NEW identity (used for triggering `.transition()`s) — the opposite of what's needed here (continuous identity is the whole fix) |
| Single `blobShape` call + inner content switch | `AnyView` type-erasure to unify branch types | Explicitly discouraged by Apple's own WWDC21 guidance — hides structural information from SwiftUI's diffing and does not by itself fix identity across a switch; the codebase itself avoids `AnyView` throughout (confirmed: `grep -c AnyView` across `NotchPillView.swift` returns none in the read sections) |
| Single `blobShape` call + inner content switch | Bespoke `AnimatableModifier`/custom `Animatable` conformance for the frame size | Unnecessary complexity — `matchedGeometryEffect` + `.frame` already interpolates size correctly once identity is stable; hand-rolling this class of animation is explicitly against this codebase's own established convention (RESEARCH.md's own historical "no Core Animation, SwiftUI gives this for free" position from earlier phases) |

**Installation:** None — no dependency changes.

## Package Legitimacy Audit

Not applicable — this phase installs no external packages.

## Architecture Patterns

### System Architecture Diagram

```
User taps switcher-row icon (Home/Tray/Calendar/Weather)
        │
        ▼
NotchPillView.switcherRow → onSwitcherSelect(view) closure
        │
        ▼
NotchWindowController.handleSwitcherSelect(_:)          [UNCHANGED — already correct]
        │  withAnimation(.spring(response: 0.6, dampingFraction: 0.62)) {
        │      viewSwitcherState.selectedView = view
        │      renderPresentation()  ──► IslandResolver.resolve(...) [pure, UNCHANGED]
        │  }
        ▼
IslandPresentationState.presentation  (published, drives SwiftUI re-render)
        │
        ▼
NotchPillView.body → presentationSwitch                  [FIX LIVES HERE]
        │
        │  BEFORE (broken): 6 separate `blobShape(...)` call sites, one per
        │  switch-case branch → SwiftUI sees 6 distinct structural subtrees →
        │  case change = remove old subtree + insert new one (flicker + z-order glitch)
        │
        │  AFTER (fixed): ONE blobShape(width: tabWidth, height: tabHeight) { innerSwitch }
        │  call site, outside the case branching → SwiftUI sees ONE continuously-
        │  identified subtree → case change = animated property update (continuous morph)
        ▼
blobShape(...)  →  NotchShape.matchedGeometryEffect("island", in: ns).frame(width:height:)
        │             .overlay(alignment: .top) { VStack { content(); switcherRow } }
        ▼
Rendered island: shape morphs continuously; switcherRow never duplicated/re-inserted
```

### Recommended Restructuring (NotchPillView.swift)

The 6 relevant `presentationSwitch` cases (`.homeEmpty`, `.homeLastPlayed`, `.nowPlayingExpanded(_, true)`, `.nowPlayingExpanded(_, false)`, `.calendarExpanded`, `.weatherExpanded`, `.trayExpanded`) currently each own a private `blobShape(...)` call. Confirmed identical across ALL of them: `topCornerRadius: 24`, `bottomCornerRadius: 32`, `alignment: .top`, `shelfItems: []`-equivalent (shelfVisible always resolves to `false` per the hardcoded `shelfStripVisible` constant), `showSwitcher: true`. Only `width`/`height`/content genuinely differ:

| Case | width | height |
|------|-------|--------|
| `.homeEmpty` / `.homeLastPlayed` / `.nowPlayingExpanded` (both healthy states) | `expandedSize.width` (420, default) | `homeContentHeight` (170) |
| `.calendarExpanded` | `calendarWidth` (460) | `switcherContentHeight` (196, default fallthrough) |
| `.weatherExpanded` | `expandedSize.width` (420, default) | `weatherStyle == .large ? weatherLargeContentHeight (410) : weatherMediumContentHeight (290)` |
| `.trayExpanded` | `traySize.width` (650) | `trayContentHeight` (117) |

### Pattern 1: Hoist the shared frame above the content switch
**What:** Replace N per-case `blobShape` calls with ONE call site whose `width:`/`height:` are computed value properties (not branched Views), and whose trailing `content:` closure contains a `@ViewBuilder` switch purely over the presentation's *content*.
**When to use:** Any time multiple `@ViewBuilder switch`/`if` branches need to participate in one continuous `matchedGeometryEffect`/frame animation.
**Example:**
```swift
// Existing precedent for this exact "compute value, don't branch View" pattern is
// ALREADY in this file at body's own outer .frame (NotchPillView.swift:888-895):
.frame(width: isTrayPresentation ? Self.traySize.width
       : (isCalendarPresentation ? Self.calendarWidth
       : (isOnboardingPresentation ? Self.onboardingSize.width : Self.expandedSize.width)),
       height: /* ... same ternary shape for height ... */)

// Applying the SAME technique one level deeper, inside presentationSwitch, for the
// tab-content cases (sketch — planner refines exact property names/placement):
private var tabWidth: CGFloat {
    switch presentation {
    case .calendarExpanded: return Self.calendarWidth
    case .trayExpanded: return Self.traySize.width
    default: return Self.expandedSize.width   // home / weather
    }
}
private var tabHeight: CGFloat {
    switch presentation {
    case .calendarExpanded: return Self.switcherContentHeight
    case .trayExpanded: return Self.trayContentHeight
    case .weatherExpanded: return weatherStyle == .large ? Self.weatherLargeContentHeight : Self.weatherMediumContentHeight
    default: return Self.homeContentHeight     // homeEmpty / homeLastPlayed / nowPlayingExpanded
    }
}

// ONE call site replacing the 6 separate blobShape(...) invocations:
private var tabContentView: some View {
    blobShape(topCornerRadius: 24, bottomCornerRadius: 32, alignment: .top,
              width: tabWidth, height: tabHeight,
              shelfItems: [], shelfVisible: false, showSwitcher: true) {
        switch presentation {                       // CONTENT-ONLY switch — no shape/
        case .calendarExpanded: calendarContent      // matchedGeometryEffect/switcherRow
        case .weatherExpanded: weatherContent        // branching happens here anymore
        case .trayExpanded: trayContent
        case .nowPlayingExpanded(let p, true): mediaContent(p, art: nowPlaying.artwork)
        case .nowPlayingExpanded(_, false): mediaUnavailableContent
        case .homeLastPlayed: mediaContent(/* synthesized paused state */, art: nowPlaying.lastKnownTrack?.artwork)
        case .homeEmpty: homeEmptyContent
        default: EmptyView()   // unreachable for this call site — presentationSwitch only
                                // routes here for the 6 cases above; kept exhaustive for Swift
        }
    }
}
```
Note: `calendarContent`/`weatherContent`/`trayContent`/`mediaContent`/`homeEmptyContent`/`mediaUnavailableContent` are the EXISTING per-case content bodies (the `HStack`/`Group`/`VStack` currently passed as `blobShape`'s trailing closure in each of the 6 functions) — extracted as plain content-only computed properties/functions, with the `blobShape(...)` wrapper call removed from each (since it now lives once, at the new shared call site).

### Anti-Patterns to Avoid
- **Keeping the switch at the `blobShape` call-site level:** If `blobShape(...)` is still called from inside separate switch branches (even if refactored to look tidier), the structural-identity bug is NOT fixed — the fix specifically requires exactly ONE `blobShape` invocation textually, with the switch moved to be *inside* its content closure.
- **`AnyView`-erasing each case's content to "unify types":** Does not address structural identity from a switch/if — Apple's WWDC21 guidance explicitly discourages `AnyView` for this exact reason; it hides the type from SwiftUI's diffing rather than giving it a stable identity.
- **Re-computing `.frame` values per case AFTER `matchedGeometryEffect`:** The codebase has an established, hard-won convention (multiple documented bugfixes, e.g. the `island-expand-diagonal-bounce` comment at `NotchPillView.swift:1908-1913`): `.matchedGeometryEffect` must precede `.frame`, never follow it. `blobShape`'s existing internal ordering already does this correctly (line 1913-1914) and must not be disturbed by the restructuring.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|--------------|-----|
| Continuous size morph between differently-sized SwiftUI subtrees | Custom `Animatable`/`AnimatableModifier` conformance, manual `GeometryReader`-based interpolation | `matchedGeometryEffect` + stable view identity (single call site) | The existing mechanism already does exactly this once its precondition (identity) is met — this codebase has never needed a custom animatable type for any prior expand/collapse morph |
| Retargeting an in-flight spring toward a new tap target | Explicit cancel-then-restart animation code, `Animation` state machines | Plain `withAnimation(.spring(...))` called again on the same still-mutating state | SwiftUI springs retarget automatically when a second `withAnimation` targets the same animatable property on the same-identity view mid-flight — this is default platform behavior, not something to build |

**Key insight:** This entire phase is a *removal* of accidental complexity (6 duplicated call sites and their duplicated `switcherRow` instances), not an addition of new animation machinery. The shortest correct diff is very likely also the right one here.

## Common Pitfalls

### Pitfall 1: Fixing the outer shape but leaving inner content unswitched-through
**What goes wrong:** If any of the 6 cases still constructs its OWN `NotchShape`/`.matchedGeometryEffect`/`switcherRow` anywhere (even conditionally, even once) instead of routing through the single shared call site, that one case will still flicker/z-glitch relative to its neighbors, and — worse — a *partial* fix can look correct for some of the 12 pairwise transitions and wrong for others, making the on-device D-03 sweep essential (not skippable) even after code review looks clean.
**Why it happens:** Six call sites existed because each tab's helper function was written independently over multiple phases (28, 30, 32, 33) — easy to miss one during consolidation.
**How to avoid:** After the refactor, `grep -c "blobShape(" NotchPillView.swift` restricted to the tab-content region should show exactly 1 call site covering all 6 cases (plus the separate, intentionally-untouched calls for onboarding/quickActionPicker, which are NOT part of the switcher-tab set and correctly remain independent).
**Warning signs:** Any case still has its own `private func xFullView` wrapping a `blobShape(...)` call.

### Pitfall 2: Treating `.homeEmpty`/`.homeLastPlayed`/`.nowPlayingExpanded` as "not really the Home tab" and leaving them out of the unification
**What goes wrong:** The switcher only has 4 visual tabs (Home/Tray/Calendar/Weather), but "Home" alone corresponds to 3 distinct `IslandPresentation` cases depending on playback state (`.homeEmpty`, `.homeLastPlayed`, `.nowPlayingExpanded(_, healthy:)`). If the unification only covers 4 cases (one per visual tab, picking e.g. only `.homeEmpty` for "Home"), then any of the 12 pairwise transitions landing on Home while media IS playing (a very common real-world case) will still hit the OLD, un-fixed code path.
**Why it happens:** The phase description and CONTEXT.md refer to "4 tabs," which maps naturally to `SelectedView`'s 4 cases, but `IslandPresentation` (the actual `switch`'s subject) has 3 sub-cases for Home alone.
**How to avoid:** Confirm all 6 cases where `showsSwitcherRow(for:)` returns `true` (`IslandResolver.swift:109-114`: `.homeLastPlayed, .homeEmpty, .calendarExpanded, .weatherExpanded, .trayExpanded, .nowPlayingExpanded`) are routed through the single unified call site — not just 4.
**Warning signs:** On-device testing a Home↔X transition looks fixed while media is paused/never-played, but still flickers while a song is actively playing.

### Pitfall 3: Assuming the AppKit "three-site rule" needs a change
**What goes wrong:** Spending plan/execution effort modifying `NotchWindowController.positionAndShow()` or `visibleContentZone()` when it isn't needed, based on a surface-level reading of the "three-site rule" doc comments.
**Why it happens:** The codebase's own comments (e.g. `NotchPillView.swift:896-909`, `NotchWindowController.swift:1366-1371`) repeatedly warn that any GEOMETRY VALUE change (a case's width/height) must be mirrored at 3 sites. This phase changes HOW those values are computed/structured in Swift, not WHAT the values are — the per-case width/height mapping is preserved exactly.
**How to avoid:** Confirm during planning that the restructuring is a pure refactor of `NotchPillView.swift`'s internal SwiftUI structure with byte-identical width/height outputs per case; no `NotchWindowController.swift` edits are required by this fix.
**Warning signs:** A task in the plan proposes editing `NotchWindowController.swift` — that's a signal the width/height mapping is being changed, not just restructured, and needs explicit justification.

### Pitfall 4: `Group` around per-case content confused with the outer switch
**What goes wrong:** `weatherFullView`/`trayFullView` already use an inner `Group { if ... }` for THEIR OWN sub-state branching (e.g., Weather populated vs. unavailable, Tray empty vs. has-items). This is fine to leave as-is — it's nested *inside* the (now-unified) content, not at the `blobShape` call-site level, so it doesn't reintroduce the structural-identity bug for the OUTER shape. Do not conflate "any switch/if anywhere in the tree" with "the bug" — only the switch that gates the `blobShape`/`matchedGeometryEffect` call site itself matters for SWITCH-01/02.
**How to avoid:** Keep existing inner `Group{if}` sub-state branches (Weather populated/unavailable, Tray empty/has-items) exactly as they are; only relocate the OUTER `blobShape` call.

## Code Examples

### Existing spring-wrapped tap handler (D-01/D-02 already correct — no change needed)
```swift
// Source: Islet/Notch/NotchWindowController.swift:1605-1619 (existing code, unchanged)
private func handleSwitcherSelect(_ view: SelectedView) {
    withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
        viewSwitcherState.selectedView = view
        if view == .calendar {
            calendarViewState.selectedDay = Date()
            calendarViewState.visibleMonth = Date()
            calendarViewState.monthEvents = nil
        }
        renderPresentation()
    }
    syncClickThrough()
    if view == .calendar {
        refreshCalendarMonth()
    }
}
// springResponse: Double = 0.6, springDamping: Double = 0.62 (NotchWindowController.swift:392-393)
```

### Existing "compute value, don't branch View" precedent to mirror
```swift
// Source: Islet/Notch/NotchPillView.swift:888-895 (existing code — the pattern to replicate
// one level deeper, inside presentationSwitch, per Pattern 1 above)
.frame(width: isTrayPresentation ? Self.traySize.width : (isCalendarPresentation ? Self.calendarWidth : (isOnboardingPresentation ? Self.onboardingSize.width : Self.expandedSize.width)),
       height: isTrayPresentation
           ? Self.trayContentHeight + Self.switcherRowHeight
           : (isOnboardingPresentation
               ? Self.onboardingSize.height
               : (showsSwitcherRow ? Self.switcherContentHeight : Self.expandedSize.height)
                   + (showsSwitcherRow ? Self.switcherRowHeight : 0)),
       alignment: .top)
```

### matchedGeometryEffect ordering convention (must not be disturbed)
```swift
// Source: Islet/Notch/NotchPillView.swift:1905-1914 (existing blobShape internals, unchanged)
return shape
    .fill(islandFill)
    .matchedGeometryEffect(id: "island", in: ns)   // MUST precede .frame
    .frame(width: baseWidth, height: totalHeight)
```

## State of the Art

Not applicable — no library/framework version changes. The relevant SwiftUI APIs (`matchedGeometryEffect`, `@ViewBuilder` switch, `withAnimation(.spring)`) are stable and unchanged across the macOS 14/15/26 range this project already targets.

**Deprecated/outdated:** None relevant to this phase.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|----------------|
| A1 | The 6-case unification sketch (`tabWidth`/`tabHeight` computed properties + single `blobShape` call) is offered as a concrete sketch, not a mandated exact API — the planner/executor may choose slightly different property names, an enum-keyed lookup table, or a switch expression instead of if/else chains, as long as the single-call-site + content-only-switch structure holds | Architecture Patterns | Low — the sketch is illustrative; the underlying mechanism (one call site, computed values, content-only inner switch) is what fixes the bug, not the exact code shape |
| A2 | No SwiftUI-internal behavior change across macOS 14/15/26 affects how `matchedGeometryEffect` handles structural identity — this is treated as stable/unchanged platform behavior based on training knowledge plus the WWDC21 session (which predates this project's macOS 15/26 targets but describes a foundational, unchanged SwiftUI diffing mechanism, not a version-specific feature) | Summary, Architecture Patterns | Low — if wrong, the on-device D-03 pairwise sweep (already mandated) would surface it immediately; no silent failure mode |

## Open Questions (RESOLVED)

1. **(RESOLVED) Should the inner content-only switch get its own `.transition(.opacity)` per case for a smoother content cross-fade?**
   - What we know: The locked success criteria (ROADMAP + D-01/D-02/D-03) only require the OUTER island shape to morph continuously without disappearing/rebuilding and without the z-order glitch. They do not explicitly require the INNER content (e.g., Calendar's month grid vs. Weather's icon+temp) to cross-fade smoothly rather than simply popping in once the outer frame reaches its new size.
   - What's unclear: Whether a hard content pop (no inner transition) will read as visually acceptable once the outer shape/switcherRow bugs are fixed, or whether it will look like a lesser, secondary glitch worth polishing in the same phase.
   - RESOLVED: Land the outer-shape fix first (satisfies the locked, testable success criteria), then judge the inner content pop during the D-03 on-device pairwise sweep. Add `.transition(.opacity)` to the inner switch's branches as a fast, low-risk follow-up ONLY if the sweep flags it — do not build it speculatively. The plan (45-01) does not add this speculatively.

2. **(RESOLVED) Does the unified call site correctly preserve `mediaExpanded`'s dual call sites (`.nowPlayingExpanded(_, true)` and `.homeLastPlayed`, which both call the same `mediaExpanded(_:art:)` function with different synthesized arguments)?**
   - What we know: Both cases already share the SAME `mediaExpanded(_:art:)` function today (this sharing is NOT part of the bug — both cases already reduce to a call to one function; the bug is that the `blobShape(...)` call INSIDE `mediaExpanded` is still one of the 6 branch-specific invocations).
   - What's unclear: Whether the planner should keep `mediaExpanded(_:art:)` as a content-only function (returning just the inner VStack, with its `blobShape` wrapper stripped and moved to the new shared call site) or restructure further.
   - RESOLVED: Strip `blobShape(...)` out of `mediaExpanded(_:art:)`, `mediaUnavailable`, `homeEmptyState`, `calendarFullView`, `weatherFullView`, `trayFullView` — each becomes a plain content-returning function/property — and add exactly one new `blobShape` call site (a new `tabContentView` computed property) that both computes `tabWidth`/`tabHeight` and dispatches to these now-content-only functions inside its trailing closure. Plan 45-01 implements exactly this.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (existing `IsletTests` target) |
| Config file | `project.yml` (XcodeGen-managed target; no separate test-runner config) |
| Quick run command | `xcodebuild -scheme Islet -destination 'platform=macOS' build` (build-only gate — see caveat below) |
| Full suite command | Manual `Cmd-U` in Xcode (GUI) |

**Caveat (project memory, `xcodebuild-test-headless-hang`):** `xcodebuild test` hangs on this project — the test target hosts the full `Islet.app`, which boots the real `NSPanel`/`MediaRemote`/`IOBluetooth` stack even under test. Use `xcodebuild build` (or `build-for-testing`) as the automated gate; route actual test EXECUTION to a manual `Cmd-U` pass in Xcode, per this project's established convention.

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|---------------------|--------------|
| SWITCH-01 | Per-case `width`/`height` mapping stays byte-identical to today's values after the refactor (regression lock on the geometry, not the animation itself — animation continuity is not unit-testable without ViewInspector/snapshot infra, neither of which this project uses) | unit | `xcodebuild build` (compile gate) then manual `Cmd-U` running a new `NotchPillViewTests` case asserting `tabWidth`/`tabHeight`-equivalent values per `IslandPresentation` case | ❌ Wave 0 — new test to be written during this phase, mirroring `NotchPillViewTests.swift`'s existing `@MainActor` XCTest pattern |
| SWITCH-01 (animation itself) | One continuous spring morph, no disappear/rebuild flicker | manual-only | — (justification: SwiftUI view-identity/animation continuity during a live `matchedGeometryEffect` transition is not inspectable via XCTest in this project — no ViewInspector/snapshot-testing dependency exists, and D-03 already mandates a full on-device sweep) | — |
| SWITCH-02 | No large→small z-order glitch (island rendering behind switcher buttons) | manual-only | — (same justification as above; z-order during a live remove/insert-vs-update animation is a rendering-time concern, not a static/unit-testable property) | — |
| D-03 (12 pairwise transitions) | Full on-device pairwise walk, both directions | manual (mandatory, locked) | Xcode GUI run on-device, walking Home↔Tray, Home↔Calendar, Home↔Weather, Tray↔Calendar, Tray↔Weather, Calendar↔Weather (12 total) | — |

### Sampling Rate
- **Per task commit:** `xcodebuild build` (compile gate) + any new pure-logic unit test added for the width/height mapping
- **Per wave merge:** Manual `Cmd-U` full XCTest suite run in Xcode
- **Phase gate:** Full on-device D-03 pairwise sweep (all 12 transitions, both directions) before `/gsd:verify-work` — this is a LOCKED user decision, not the ROADMAP's softer "or representative sample" fallback

### Wave 0 Gaps
- [ ] A new unit test (or test additions to `IsletTests/NotchPillViewTests.swift`) asserting the per-case width/height mapping is preserved post-refactor — mirrors the existing `testShelfStripVisibleIsAlwaysFalse` pattern (direct `NotchPillView` instantiation, `@MainActor`, asserting an `internal` (not `private`) computed property). If the refactor's `tabWidth`/`tabHeight` (or equivalent) properties are `private`, they will need the same `private → internal` visibility bump this project has already precedented for `shelfStripVisible` (Phase 31) and `EqualizerBars.makeProfiles()` — for testability only, no behavior change.

*(No other gaps — existing XCTest target/`IsletTests` infrastructure and `handleSwitcherSelect`'s spring-wrapping already have their own passing regression coverage via `IslandResolverTests.swift`, which is untouched by this phase.)*

## Security Domain

Not applicable in any meaningful sense — this phase is a pure internal SwiftUI rendering/animation refactor with no new data flows, no new user input surface, no authentication/session/access-control changes, and no cryptography. No ASVS category applies.

| ASVS Category | Applies | Standard Control |
|----------------|---------|--------------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | no | — (tab selection is a closed enum, `SelectedView`, already exhaustively handled by the existing resolver — no new external input) |
| V6 Cryptography | no | — |

## Sources

### Primary (HIGH confidence)
- Apple Developer Documentation — `matchedGeometryEffect(id:in:properties:anchor:isSource:)` — confirms the API contract (shared id+namespace required for a valid match)
- Apple WWDC21 "Demystify SwiftUI" session — the authoritative source for SwiftUI's structural-vs-explicit identity model and why switch/if branch changes trigger remove+insert rather than update; also the source for the `AnyView`-avoidance guidance
- Direct code read: `Islet/Notch/NotchPillView.swift` (lines 40-90, 700-1050, 1210-1270, 1420-1530, 1860-1970, 2775-2905, 3235-3465), `Islet/Notch/NotchWindowController.swift` (lines 360-1060, 1340-1620), `Islet/Notch/ViewSwitcherState.swift`, `Islet/Notch/IslandResolver.swift` (lines 61-115) — root cause, exact call sites, exact constant values, exact three-site-rule geometry, exact spring parameters
- `IsletTests/NotchPillViewTests.swift`, `IsletTests/IslandResolverTests.swift` — existing test patterns and precedent for the `private → internal` testability bump

### Secondary (MEDIUM confidence)
- objc.io "Transitions in SwiftUI" (Chris Eidhof/objc.io, well-regarded independent SwiftUI reference) — corroborates the WWDC21 identity model and the "unify view types across branches" fix pattern with concrete code framing

### Tertiary (LOW confidence)
- None — every claim above was corroborated by either an official Apple source or direct code read in this session.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new dependencies; existing APIs already used elsewhere in this exact file
- Architecture: HIGH — root cause and fix mechanism confirmed via direct code read (all 6 call sites, all constant values, the three-site-rule geometry, the spring wiring) plus an official Apple source (WWDC21) for the general SwiftUI identity mechanism
- Pitfalls: HIGH — Pitfall 2 (the 6-vs-4-case scope trap) was discovered via direct code read of `showsSwitcherRow(for:)`, not inferred

**Research date:** 2026-07-19
**Valid until:** No expiry driver — this is internal-codebase-grounded research, not dependent on external library versions; valid as long as `NotchPillView.swift`'s `presentationSwitch`/`blobShape` structure is not independently changed by other work before this phase executes.
