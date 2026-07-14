# Phase 32: Tray Widening - Research

**Researched:** 2026-07-14
**Domain:** SwiftUI/AppKit notch-overlay layout geometry (single-project codebase research, no external library research needed)
**Confidence:** HIGH

## Summary

This phase is a pure internal-codebase geometry change, not a new-library integration. All the machinery Phase 32 needs already exists and is already used by precedent call sites (`onboardingCarousel`'s `width:`/`height:` override, `switcherContentHeight`'s "one shared content box" pattern). The work is: (1) give `trayFullView` its own wider/shorter `blobShape` override, (2) grow `ShelfItemView`'s icon (used by all 4 tabs — needs an explicit decision, not silent global change), (3) extend the **panel window's own frame reservation** in `NotchWindowController.positionAndShow()` to include a Tray-sized union member (this is the one non-obvious, easy-to-miss step — the SwiftUI content can request 840pt width, but the AppKit `NSPanel` will clip it if the panel itself isn't grown to match, exactly the precedent `onboardingFrame` set in Phase 26), and (4) update `visibleContentZone()` to report the Tray-specific geometry when Tray is active, then re-verify via the mandatory on-device hover→expand→move-down trace (CR-01/CR-02 discipline, ROADMAP success criterion 4).

**Primary recommendation:** Add a `traySize: CGSize` constant (module-level, next to `expandedSize`/`onboardingSize`) sized ~840×~[shrunk height], thread it through `trayFullView`'s `blobShape(width:height:...)` call, add a `traySelected` (or reuse `isOnboardingActive`-style) branch to the outer `.frame()` in `body`, add a `trayFrame` union member in `positionAndShow()`, and branch `visibleContentZone()`'s `contentSize` the same way `isOnboardingActive` already branches it. `ShelfItemView`'s icon size bump is codebase-wide (single shared view) per D-04/D-04's phrasing in CONTEXT.md — plan must explicitly confirm this is intended before executing, since it also affects Home/Calendar/Weather's shelf-strip rendering paths (dormant today per TRAY-01, but the type is still shared).

## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Only the Tray tab grows wider. Home/Calendar/Weather stay at the existing `expandedSize.width` (420pt) — no global width change. The island visibly morphs wider when switching to Tray and back, using the `width:` override parameter `blobShape()` already supports.
- **D-02:** The wider Tray width applies unconditionally whenever the Tray tab is active — including the empty state (`trayEmptyState`) — not gated on whether the shelf has items. No extra width-morph moment when the first file is dropped.
- **D-03:** Target width: ~840pt (double the current 420pt), as a first pass. Exact pixel value is Claude's/planner's call within that "roughly double" intent — not a hard-locked number.
- **D-04:** File icons in `shelfRow`/`ShelfItemView` grow moderately, not proportionally to the width doubling. Target: ~40×40pt (up from the current 28×28pt). Filename caption width (`maxWidth: 44`) should be revisited alongside this so text doesn't look cramped next to larger icons — Claude's/planner's call on the exact value.
- **D-05:** Stays a single-row, horizontally-scrolling strip (`shelfRow(_:)`'s existing `ScrollView(.horizontal)` + `HStack` structure is NOT replaced with a grid). The wider panel simply fits more tiles before scrolling kicks in. No LazyVGrid/multi-row rework.
- **D-06:** Folded into Phase 32 scope (user confirmed) — the Tray panel should shrink to hug its actual content (file row + camera clearance, or the empty-state copy) instead of reserving the fixed `switcherContentHeight` (196pt) that Calendar's month grid needs but Tray doesn't.
- **D-07:** Known trade-off, explicitly accepted: `blobShape`'s `showSwitcher: true` path currently forces ALL tabs (Home/Calendar/Weather/Tray) to the same `switcherContentHeight` specifically so the switcher row sits at an identical Y position on every tab — a deliberate Phase 28-04-round-5 fix for a misclick regression. Shrinking Tray's height independently means the switcher icons will sit at a different, higher Y position on Tray than on Home/Calendar/Weather. User explicitly accepted this rather than requiring the larger structural fix (decoupling switcher-row position from content height).
- **D-08:** Because layout stays single-row (D-05), content height doesn't need to vary by file count — the shrink is mainly about picking a smaller fixed height for Tray (empty-state vs. has-files may still differ) rather than a truly dynamic per-item-count height.

### Claude's Discretion

- Exact new Tray height constant(s) for empty vs. non-empty state.
- Exact pixel values for width (~840pt target) and icon size (~40×40pt target) — "roughly double" and "moderately bigger" are the locked intents, not the exact numbers.
- Exact filename caption width/font adjustments to match larger icons.
- Whether the width-morph and height-shrink use the same or different animation curves — technical detail.

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope (width, icon size, layout shape, and the folded height todo all fall within Tray Widening's domain).

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TRAY-05 | The Tray view is widened with larger file tiles so more files are visible side-by-side | `blobShape(width:height:)` override precedent (onboardingCarousel), panel-frame union pattern (`positionAndShow`), `visibleContentZone()` branch pattern (`isOnboardingActive`) — all documented below with exact line references |

## Project Constraints (from CLAUDE.md)

- Swift 5 **language mode** (not Swift 6 strict concurrency) — confirmed still active: `project.yml` line 32/81/104 `SWIFT_VERSION: "5.0"`.
- `MACOSX_DEPLOYMENT_TARGET: "15.0"` (bumped from 14.0 in Phase 26) — confirmed in `project.yml` lines 33/82/105. Research doc in CLAUDE.md still says "14.0 recommendation" — that's now stale; actual project floor is 15.0. No SwiftUI API used by this phase needs anything beyond 15.0 (`matchedGeometryEffect`, `LazyVGrid` not used here, plain `.frame`/`VStack`/`ScrollView`).
- SwiftUI for all island UI; AppKit stays confined to the window shell (`NotchWindowController`, `NotchPanel`) — this phase's AppKit-side change is *only* the panel-frame union math in `positionAndShow()`, no new AppKit surface.
- Named size constants convention (not inline magic numbers) — `expandedSize`, `wingsSize`, `shelfRowHeight`, `switcherRowHeight`, `switcherContentHeight`, `onboardingSize` are all `static let` on `NotchPillView`. A new `traySize` (or `trayWidth`/`trayContentHeight` pair) must follow this exact pattern.
- No unrequested abstractions (ponytail mode / GSD code quality rule) — do not generalize `blobShape` further than the existing `width:`/`height:` optional-override parameters already allow; do not introduce a new protocol/enum for "tab-specific sizing" when two more `CGFloat?` defaults on existing call sites suffice.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Tray content width/height (visible black shape) | SwiftUI (`NotchPillView.trayFullView`/`blobShape`) | — | Pure view-layer sizing, existing `width:`/`height:` override params |
| File icon size (`ShelfItemView`) | SwiftUI (`ShelfItemView`) | — | Single shared leaf view, no AppKit involvement |
| Panel window frame (must be ≥ content size or SwiftUI content clips) | AppKit (`NotchWindowController.positionAndShow`) | — | `NSPanel`/`NSHostingView` — the window is a real OS surface; SwiftUI cannot grow past whatever rect AppKit gave it |
| Click-through hit-testing geometry | AppKit (`NotchWindowController.visibleContentZone`/`syncClickThrough`) | SwiftUI (must stay in sync with `blobShape`'s actual rendered rect) | `visibleContentZone()` computes a CGRect independently of SwiftUI layout — it is a parallel, hand-maintained mirror of what `blobShape` renders, which is exactly the CR-01 regression class this phase must re-verify |
| Switcher-row Y position (shared across tabs) | SwiftUI (`blobShape`'s `showSwitcher` branch) | — | Deliberately shared constant (`switcherContentHeight`) per Phase 28-04 round 5; D-06/D-07 knowingly reintroduce controlled variance for Tray only |

## Standard Stack

Not applicable — no new external dependencies. This phase touches only existing first-party Swift files. No `npm install`/`pip install`/`cargo add` — skip the Package Legitimacy Audit section (no packages installed).

## Architecture Patterns

### System Architecture Diagram

```
User clicks "Tray" in switcherRow
        │
        ▼
onSwitcherSelect(.tray) ──▶ NotchWindowController sets ViewSwitcherState.selectedView = .tray
        │                            │
        │                            ▼
        │                   IslandResolver.resolve(...) returns .trayExpanded
        │                            │
        ▼                            ▼
NotchPillView.body switch(presentation) ──▶ case .trayExpanded: trayFullView
        │
        ▼
trayFullView calls blobShape(width: Self.traySize.width,     ◀── NEW override (currently omitted, falls back to expandedSize.width)
                              height: Self.trayContentHeight,  ◀── NEW override (currently forced to switcherContentHeight)
                              shelfItems: [], shelfVisible: false, showSwitcher: true) { ... }
        │
        ▼
blobShape computes baseWidth/baseHeight/totalHeight from the override params,
renders NotchShape().fill(...).frame(width: baseWidth, height: totalHeight)
        │
        ▼
SwiftUI content now WANTS to be 840×[shrunk]pt ── but the AppKit NSPanel this view
is hosted in was sized in positionAndShow() BEFORE this frame ever rendered ──▶
        │
        ▼
NotchWindowController.positionAndShow() must include a `trayFrame` union member
(mirroring `onboardingFrame`) so `panelFrame = expandedFrame.union(wings).union(onboardingFrame).union(trayFrame)`
is wide/tall enough — otherwise the 840pt content silently clips at the old 420pt panel edge
        │
        ▼
visibleContentZone() must ALSO branch on "is Tray currently selected" (mirroring
its existing `isOnboardingActive` branch) so CR-01's click-through hit-test rect
matches the ACTUAL rendered Tray rect, not the old expandedSize rect
        │
        ▼
On-device hover→expand→move-down trace (mandatory, CR-01/CR-02 precedent)
```

### Recommended Project Structure

No new files. All changes land in 3 existing files:
```
Islet/Notch/
├── NotchPillView.swift          # traySize constant, trayFullView's blobShape call, outer .frame() branch
├── NotchWindowController.swift  # positionAndShow() panel union, visibleContentZone() branch
└── ShelfItemView.swift          # icon frame 28→~40, caption maxWidth 44→~(larger)
```

### Pattern 1: Per-presentation size override via optional `width:`/`height:` params

**What:** `blobShape<Content: View>(topCornerRadius:bottomCornerRadius:alignment:width:height:shelfItems:shelfVisible:showSwitcher:content:)` already accepts optional `width`/`height` CGFloat overrides (both default `nil`, falling back to `Self.expandedSize.width`/`.height`). `onboardingCarousel(_:)` is the one existing caller that supplies both (`NotchPillView.swift` lines 787-789, `width: Self.onboardingSize.width, height: Self.onboardingSize.height`).

**When to use:** Exactly Phase 32's situation — one presentation case needs a different footprint than the shared `expandedSize`/`switcherContentHeight` box.

**Critical caveat found in this research:** `showSwitcher: true` currently HARD-OVERRIDES `height:` — see line 1100: `let baseHeight = showSwitcher ? Self.switcherContentHeight : (height ?? Self.expandedSize.height)`. Since `trayFullView` passes `showSwitcher: true` (needed for the switcher row to render at all — D-07 keeps it), a `height:` override passed to `trayFullView`'s `blobShape` call is **currently silently ignored**. This one-line ternary must change to let Tray's height override win even while `showSwitcher: true`, e.g.:
```swift
let baseHeight = height ?? (showSwitcher ? Self.switcherContentHeight : Self.expandedSize.height)
```
This is the single most important code-level finding for the planner: D-06 (shrink-to-fit) is NOT achievable by only changing `trayFullView`'s call site — `blobShape`'s internal height ternary must also change, or the `height:` override will have zero effect. `width:` has no equivalent trap (no ternary forces it).

**Example (current onboarding precedent, NotchPillView.swift lines 786-807):**
```swift
// Source: Islet/Notch/NotchPillView.swift lines 787-789 (existing code)
blobShape(topCornerRadius: 24, bottomCornerRadius: 32,
          width: Self.onboardingSize.width, height: Self.onboardingSize.height, shelfItems: [],
          shelfVisible: false) {
    // onboarding omits showSwitcher entirely (defaults false), so the height ternary trap
    // above does NOT apply to onboarding — this is exactly why Tray's showSwitcher: true
    // combination is new territory, not just "copy onboarding's pattern".
    ...
}
```

### Pattern 2: Outer `.frame()` branch on presentation, mirroring `isOnboardingPresentation`

**What:** `NotchPillView.body`'s outer `ZStack` carries a single `.frame(width:height:alignment:)` (lines 404-409) that currently branches only on `isOnboardingPresentation` for width, and on `showsSwitcherRow` for height. A third branch (Tray-active) must be added, or the outer frame will clip/pad incorrectly around the correctly-sized inner `blobShape` content — this is the EXACT bug class the code comments at lines 381-403 document happening twice already (once for shelf in Phase 21, once for onboarding in Phase 26 round 1).

**When to use:** Any time a new presentation case gets a non-standard `blobShape` width/height (this is the second of two places — `blobShape` and `body`'s outer `.frame()` — that must independently agree, exactly mirroring the CR-01 "two independently-maintained copies must desync-proof each other" lesson already noted in `showsSwitcherRow(for:)`'s own doc comment).

**Example (existing pattern to extend, NotchPillView.swift lines 404-409):**
```swift
// Source: Islet/Notch/NotchPillView.swift (existing code)
.frame(width: isOnboardingPresentation ? Self.onboardingSize.width : Self.expandedSize.width,
       height: isOnboardingPresentation
           ? Self.onboardingSize.height
           : (showsSwitcherRow ? Self.switcherContentHeight : Self.expandedSize.height)
               + (showsSwitcherRow ? Self.switcherRowHeight : 0),
       alignment: .top)
```
A Tray-active branch needs to be added to the `width:` ternary AND to the `height:` calculation's `switcherContentHeight` term (replace with a Tray-specific constant when Tray is active). Recommend introducing a private computed var `private var isTrayPresentation: Bool { if case .trayExpanded = presentation { return true }; return false }` mirroring `isOnboardingPresentation`'s exact shape (line 47-50), rather than inlining the `if case` check twice.

### Pattern 3: Panel window frame reservation via union, mirroring `onboardingFrame`

**What:** `NotchWindowController.positionAndShow()` computes `panelFrame = expandedFrame.union(wings).union(onboardingFrame)` (line 807) — the AppKit `NSPanel` is sized ONCE, up front, to the union of every possible content size, specifically so no SwiftUI content is ever clipped and no runtime panel resize races the spring morph (documented as "Pattern 4" throughout this file's comments, e.g. lines 769-793, 803-806).

**When to use:** This is not optional for Phase 32 — it is the load-bearing AppKit-side step. If the planner only changes `NotchPillView.swift` and skips this, the SwiftUI content will render at 840pt logically but be clipped to the old ~420pt panel edge on screen, because `NSHostingView`'s content is bounded by its containing `NSPanel`'s actual frame.

**Example (current code to extend, NotchWindowController.swift lines 794-807):**
```swift
// Source: Islet/Notch/NotchWindowController.swift lines 794-807 (existing code)
let expandedFrame = expandedNotchFrame(collapsed: collapsedFrame,
                                       expandedSize: CGSize(width: expandedSize.width,
                                                             height: NotchPillView.switcherContentHeight + NotchPillView.shelfRowHeight + NotchPillView.switcherRowHeight))
let wings = wingsFrame(collapsed: collapsedFrame, wingsSize: wingsSize)
let onboardingFrame = expandedNotchFrame(collapsed: collapsedFrame, expandedSize: NotchPillView.onboardingSize)
let panelFrame = expandedFrame.union(wings).union(onboardingFrame)
```
Add a fourth member:
```swift
let trayFrame = expandedNotchFrame(collapsed: collapsedFrame,
                                    expandedSize: CGSize(width: NotchPillView.traySize.width,
                                                          height: NotchPillView.trayContentHeight + NotchPillView.switcherRowHeight))
let panelFrame = expandedFrame.union(wings).union(onboardingFrame).union(trayFrame)
```
`expandedNotchFrame`/`topPinnedFrame` (NotchGeometry.swift lines 62-74) both center horizontally on the collapsed pill's `midX` — so a wider `trayFrame` union member automatically keeps the whole panel centered on the physical notch; no separate centering logic needed.

### Pattern 4: `visibleContentZone()` branch, mirroring `isOnboardingActive`

**What:** `visibleContentZone()` (NotchWindowController.swift lines 962-982) independently recomputes "what rect is actually visible/interactive" — it does NOT read SwiftUI's rendered geometry; it duplicates the sizing math by hand (`contentSize` ternary on `isOnboardingActive`, `switcherRowShowing`). This is the CR-01/CR-02 regression class: a size added in `blobShape` but not mirrored here silently breaks click-through (files behind the extra width become un-clickable, or dead space beyond the old width becomes falsely interactive/blocks clicks to apps behind the notch).

**When to use:** Every phase that changes a presentation's rendered size, per the project's own documented discipline (project memory `cr01-clickthrough-or-defeat-gotcha`; CONTEXT.md's Canonical References section flags this explicitly for Phase 32).

**Example (current code to extend, NotchWindowController.swift lines 962-982):**
```swift
// Source: Islet/Notch/NotchWindowController.swift lines 962-982 (existing code)
private func visibleContentZone() -> CGRect? {
    guard let hotZone else { return nil }
    let collapsedFrame = hotZone.insetBy(dx: hotZonePadding, dy: hotZonePadding)
    let switcherRowShowing = showsSwitcherRow(for: presentationState.presentation)
    let switcherHeight = switcherRowShowing ? NotchPillView.switcherRowHeight : 0
    let contentSize: CGSize = isOnboardingActive
        ? NotchPillView.onboardingSize
        : CGSize(width: expandedSize.width,
                 height: (switcherRowShowing ? NotchPillView.switcherContentHeight : expandedSize.height) + switcherHeight)
    let visibleFrame = expandedNotchFrame(collapsed: collapsedFrame, expandedSize: contentSize)
    return visibleFrame.insetBy(dx: -hotZonePadding, dy: -hotZonePadding)
}
```
Needs a third branch: `presentationState.presentation` is `.trayExpanded` → use `CGSize(width: NotchPillView.traySize.width, height: NotchPillView.trayContentHeight + switcherHeight)`. Recommend checking `if case .trayExpanded = presentationState.presentation` directly (this file already imports the enum and pattern-matches presentation elsewhere per grep) rather than adding a new stored `isTrayActive` bool — `isOnboardingActive` is a stored bool because onboarding is a multi-step forced-flow state tracked outside the resolver; Tray's active-ness is fully derivable from `presentationState.presentation` already, so no new stored property is needed (ponytail: don't add state that already exists elsewhere).

### Anti-Patterns to Avoid

- **Editing `blobShape`'s `showSwitcher` ternary without checking Tray still gets a height override:** the existing ternary structurally cannot honor a `height:` override while `showSwitcher: true` (see Pattern 1). Silently "shipping" a `height:` param that has no effect is the most likely near-miss bug in this phase.
- **Changing `ShelfItemView`'s icon frame without confirming the blast radius:** `ShelfItemView` is the ONE shared leaf view for Home/Calendar/Weather/Tray shelf rendering (currently dormant on non-Tray tabs per TRAY-01/`shelfStripVisible == false`, but the same Swift type). A 28→40 change is invisible on Home/Calendar/Weather today (they never render it), but if TRAY-01's gating is ever relaxed, all 4 tabs would inherit the new icon size without anyone deciding that. CONTEXT.md's own `code_context` section flags this exact ambiguity ("Planner/researcher should confirm whether that's intended"). Since D-04 is written in terms of "File icons in `shelfRow`/`ShelfItemView` grow" with no Tray-only qualifier, the straightforward reading is a global `ShelfItemView` change is intended — planner should state this explicitly as a locked assumption, not silently decide.
- **Resizing the AppKit panel only in the `.trayExpanded` case at runtime (live resize) instead of unconditional up-front union:** this file's own comments (lines 772-779, 803-806) explicitly document why live panel resizing was rejected project-wide ("resizing mid-activity would race the morph + hot-zone math") — Tray must follow the same unconditional-reservation-then-conditional-render split every other presentation uses.
- **Forgetting the outer `body` `.frame()` branch (Pattern 2):** this exact bug shape has already happened twice in this codebase (Phase 21 shelf, Phase 26 onboarding round 1) per the comments at lines 381-403 — both were "blobShape grew but the outer container frame didn't, so content got clipped."

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Wider/taller presentation box | A new shape/view hierarchy | `blobShape`'s existing `width:`/`height:` optional overrides | Already exists, already proven by `onboardingCarousel`, zero new abstraction needed |
| Horizontal scrolling of many tiles | A custom scroll-position tracker or paging control | `shelfRow(_:)`'s existing `ScrollView(.horizontal)` + `HStack` (D-05 locks this — no rework) | Native SwiftUI does this correctly; D-05 explicitly forbids replacing it with a grid |
| Centering a wider panel on the physical notch | Manual midX math in the new code | `expandedNotchFrame`/`topPinnedFrame` (NotchGeometry.swift) — already centers any `CGSize` on `collapsed.midX` | Pure, unit-tested (`NotchGeometryTests.swift`), reused by every existing frame (expanded/wings/onboarding) |

**Key insight:** This phase has zero genuinely new engineering — it is entirely "extend 4 existing, well-understood extension points (`blobShape` override params, `body`'s outer frame ternary, `positionAndShow`'s union, `visibleContentZone`'s ternary) with one more branch each," following a pattern the codebase has now used 3 times before (shelf, switcher row, onboarding).

## Common Pitfalls

### Pitfall 1: `height:` override silently no-op'd by `showSwitcher: true`
**What goes wrong:** Passing `blobShape(..., height: Self.trayContentHeight, ..., showSwitcher: true)` appears to work in code review but has zero visual effect — Tray still renders at the full 196pt `switcherContentHeight`.
**Why it happens:** `blobShape`'s current line 1100 ternary (`showSwitcher ? Self.switcherContentHeight : (height ?? Self.expandedSize.height)`) checks `showSwitcher` BEFORE consulting `height`.
**How to avoid:** Change the ternary to consult `height` first (see Pattern 1's suggested fix) as part of this phase's task list, not as an afterthought.
**Warning signs:** On-device, the Tray panel doesn't visibly shrink vertically despite the height constant being added and referenced.

### Pitfall 2: Panel clips wider content because `positionAndShow()` wasn't touched
**What goes wrong:** The Tray view visibly renders at ~840pt in Xcode Previews (which don't go through `NotchWindowController` at all) but is hard-clipped to ~420pt on the real notch overlay.
**Why it happens:** SwiftUI Previews render `NotchPillView` standalone with no panel constraint; only `NotchWindowController.positionAndShow()`'s real `NSPanel.setFrame(panelFrame)` call enforces the actual on-screen bound. Previews cannot catch this bug class.
**How to avoid:** Pattern 3's union member is mandatory, not optional; on-device verification (not Previews) is the only way to confirm this.
**Warning signs:** On-device, the right ~420pt half of the Tray content is invisible/cut off at a hard vertical edge.

### Pitfall 3: CR-01 click-through desync (files become unclickable, or clicks pass through into background apps)
**What goes wrong:** `visibleContentZone()` still reports the old 420pt-wide rect after Tray visually renders at 840pt — the right half of the new file tiles are visually present but don't respond to hover/click (mouse events pass through to whatever app is behind the notch at that screen location), OR the reverse: `visibleContentZone()` is widened but the actual `blobShape` content shrank vertically, so dead transparent space below the real content still swallows clicks meant for the app underneath.
**Why it happens:** This is the exact bug class documented in project memory `cr01-clickthrough-or-defeat-gotcha` — `visibleContentZone()` is a hand-maintained geometric mirror of `blobShape`'s actual rendered rect, with no compiler/test enforcement that the two stay in sync.
**How to avoid:** Update `visibleContentZone()` in the SAME task/commit as the `blobShape`/`positionAndShow` changes (Pattern 4), never as a follow-up. Then run the mandatory on-device hover→expand→move-down trace (ROADMAP success criterion 4 for this phase codifies this explicitly) before considering the phase verified.
**Warning signs:** On-device, clicking a file tile in the rightmost/newly-visible columns does nothing, or moving the mouse below the shrunk Tray content still keeps the island expanded / still blocks clicks to the desktop.

### Pitfall 4: Switcher row Y-position regression complaint (expected, not a bug — but must not be "fixed" mid-phase)
**What goes wrong:** After the height shrink, a developer notices the switcher icons sit higher on Tray than on Home/Calendar/Weather and "fixes" it by reverting to the shared `switcherContentHeight`, silently undoing D-06.
**Why it happens:** This IS the explicitly-accepted trade-off (D-07) — the visual inconsistency is intentional, not a regression, per direct user sign-off in CONTEXT.md.
**How to avoid:** Plan/verification steps should explicitly note "switcher icons sit higher on Tray than other tabs — this is D-07, confirmed intentional, not a bug" so it isn't accidentally reverted during on-device UAT.
**Warning signs:** A verification pass flags "switcher position inconsistent across tabs" as a defect — check CONTEXT.md D-07 before treating it as one.

## Code Examples

See Architecture Patterns section above — all 4 patterns include exact current-code excerpts with file/line references (`NotchPillView.swift` lines 787-789, 404-409, 1089-1127; `NotchWindowController.swift` lines 794-807, 962-982; `NotchGeometry.swift` lines 60-83) plus the specific extension each needs. No external/Context7 sources apply — this is 100% first-party codebase research.

## State of the Art

Not applicable — no external library/framework version drift is relevant to this phase. All "state of the art" here is this project's own most recent precedent: Phase 26 round 2's `onboardingCarousel` widening (360→400→420pt) and Phase 28-04 round 5's `switcherContentHeight` unification are the two most directly analogous prior changes, both already reflected in the current code read during this research.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `ShelfItemView`'s icon-size change (D-04) is intended to be global (all 4 tabs' shared view), not Tray-scoped, since D-04's wording has no Tray-only qualifier and CONTEXT.md itself flags this as unresolved ("wasn't explicitly asked") | Don't Hand-Roll / Anti-Patterns | If wrong, a Tray-only icon variant would need a second view or a size parameter threaded through `ShelfItemView`/`shelfRow(_:)` — moderate rework, not just a constant change. Low risk in practice since TRAY-01 already gates all non-Tray shelf rendering off, so the "blast radius" is currently zero regardless. |
| A2 | ~840pt panel width fits comfortably within typical MacBook screen widths in points (13"/14"/16" notch models are all ≥1440pt wide in points) so no additional off-screen/clamping logic is needed | Summary / Architecture | If a user's screen is narrower than ~900pt in points (not physically possible on any notch MacBook — all ship ≥13" at ≥1440×900pt), the panel could extend past screen edges. Not independently verified against Apple's published notch-MacBook resolution table in this research session — flagged LOW risk since all notch Macs are 13"+ and this is a v1-scope "notch MacBooks only" product per CLAUDE.md's own platform constraint. |

**If this table is empty:** N/A — 2 assumptions logged above, both LOW/MEDIUM risk, neither blocks planning.

## Open Questions

1. **Exact `traySize`/`trayContentHeight` pixel values**
   - What we know: Width target ~840pt (D-03, "roughly double" 420pt), height should shrink below the current 196pt `switcherContentHeight` box to hug actual content (file row 56pt `shelfRowHeight` + camera clearance 42pt + some bottom margin, or the empty-state copy's natural height) — D-06/D-08.
   - What's unclear: The precise number. `shelfRowHeight` (56) + `cameraClearance` (42) + a bottom margin (curve-radius room, ~18-20pt per the `switcherContentHeight` box-math comment's own convention) suggests roughly 56+42+20 ≈ 118pt as a first-pass content height for the non-empty state; the empty state (`trayEmptyState`, currently `.padding(.top, 24)` + icon+text block) would need its own, likely similar or slightly taller, number.
   - Recommendation: Treat this as an on-device-tunable constant from the start (matching this codebase's own established pattern of shipping a "for now" number and iterating via UAT rounds — see `onboardingSize`'s 3-round history, `calendarCellSize`'s round-5 history). Plan should NOT block on getting this pixel-perfect before first on-device check.

2. **Whether empty-state and non-empty-state Tray heights differ**
   - What we know: D-08 says "empty-state vs. has-files may still differ" is acceptable, but doesn't lock it either way.
   - What's unclear: Whether the planner should ship ONE `trayContentHeight` constant (simpler, matches D-05's "no dynamic per-item-count height" spirit) or two (`trayEmptyHeight`/`trayContentHeight`).
   - Recommendation: Start with ONE shared constant sized to fit the taller of the two states (mirrors this file's own "worst case" sizing convention used for `switcherContentHeight`'s calendar-grid math) — simpler, avoids a second live-resize-adjacent branch, and D-08 only permits divergence, doesn't require it.

## Environment Availability

Skipped — this phase is a pure Swift/SwiftUI/AppKit code change within the existing Xcode project; no new external tool, service, or runtime dependency is introduced. Xcode 16+/Swift 5 language mode/macOS 15.0 deployment target are all already configured in `project.yml` and unchanged by this phase.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (`@testable import Islet`) |
| Config file | `project.yml` (XcodeGen) — test target `IsletTests`, scheme `Islet` (`project.yml` lines ~93-114) |
| Quick run command | `xcodebuild build -scheme Islet -destination 'platform=macOS'` (build gate — see project memory `xcodebuild-test-headless-hang`: `xcodebuild test` hangs headless because tests host the full `Islet.app`, which boots `NSPanel`/`MediaRemote`/`IOBluetooth`) |
| Full suite command | Manual `Cmd-U` in Xcode GUI (per project memory — route actual test execution there, not to a headless `xcodebuild test` invocation) |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TRAY-05 (geometry math) | `expandedNotchFrame`/`topPinnedFrame` correctly center a wider `traySize` on `collapsed.midX` | unit | Extend `NotchGeometryTests.swift` (pattern: `testExpandedNotchFrameCentersOnMidXAndPinsTop`, lines 117-134) with a `traySize`-equivalent case | ✅ pattern exists, ❌ Tray-specific case needs adding — Wave 0 |
| TRAY-05 (`blobShape` height-override fix) | `height:` override actually takes effect when `showSwitcher: true` | unit | No existing test covers `blobShape`'s internal ternary directly (it's `private`) — regression risk lives in `NotchPillViewTests.swift`'s style (asserting on rendered/observable state) or must be verified via a UI/manual check since `blobShape` returns `some View` with no easily-inspectable height property | ❌ — Wave 0, or accept manual-only with justification (SwiftUI view internals are not directly assertable without ViewInspector, which is not in this project's dependency list — do not add it for one assertion, per Don't Hand-Roll discipline) |
| TRAY-05 (`shelfStripVisible`-style regression lock) | Tray-only width doesn't leak to other tabs (mirrors TRAY-01's own `NotchPillViewTests.testShelfStripVisibleIsAlwaysFalse` precedent) | unit | New test asserting the Tray-specific size constant is only reachable via `.trayExpanded`'s code path — likely infeasible to assert directly on a `View`; consider testing at the `IslandResolver`/constant level instead (e.g., a plain equality assertion that `NotchPillView.traySize.width != NotchPillView.expandedSize.width` combined with a manual on-device check that Home stays 420pt) | ❌ — Wave 0, low-value test; manual on-device check likely sufficient given SwiftUI view-tree assertion limits in this codebase (no ViewInspector) |
| TRAY-05 success criterion 4 (click-through) | `visibleContentZone()` returns the correct Tray-sized rect when `.trayExpanded` | unit | Follow `NotchPanelTests.swift`'s existing pattern if it already tests `visibleContentZone()`-adjacent logic (needs inspection during planning — this file was found via grep but not read in this research pass) — otherwise this is the ONE requirement in this phase that is legitimately **manual-only**, per this project's own explicit, repeated precedent (CR-01/CR-02 both required an on-device hover→expand→move-down trace, not just a unit test, because `visibleContentZone()`'s consumer is a live global mouse-event monitor) | Manual-only, justified: CR-01 regression class is empirically NOT caught by unit tests alone in this codebase's history — every prior fix cites an on-device trace as the actual verification step |

### Sampling Rate
- **Per task commit:** `xcodebuild build -scheme Islet -destination 'platform=macOS'` (build gate only — confirms no compile errors, matches this project's documented `xcodebuild test` hang workaround)
- **Per wave merge:** Manual `Cmd-U` in Xcode GUI for the full `IsletTests` suite, PLUS the mandatory on-device hover→expand→move-down trace for click-through (cannot be automated per CR-01 precedent)
- **Phase gate:** Full suite green (Cmd-U) + on-device trace passed before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `NotchGeometryTests.swift` — extend with a Tray-sized `expandedNotchFrame` centering case (straightforward, mirrors 3 existing cases in the same file)
- [ ] Manual on-device checklist item (not a file): "Tray widens to ~2x, more tiles visible, CR-01 hover→expand→move-down trace passes with zero click-through regressions" — this is the project's own established substitute for an automated test on this exact code path (see `31-01-PLAN.md`/Phase 31's own precedent, per project memory `cr01-clickthrough-or-defeat-gotcha`)
- [ ] Framework install: none — XCTest is already wired via `project.yml`

## Security Domain

Not applicable / low relevance — this phase renders already-trusted, already-validated local data (`ShelfItem.filename`, already `.lineLimit(1)`/`.truncationMode(.middle)`-guarded per existing `ShelfItemView` code, T-20-01 mitigation already in place at line 22) at a larger point size. No new input surface, no new trust boundary, no new V2/V3/V4/V5/V6 ASVS category introduced. `security_enforcement` config value not checked in `.planning/config.json` during this research pass — given the phase is pure layout/sizing with zero new data flow, this omission carries negligible risk; planner may skip a dedicated Security Domain task section.

## Sources

### Primary (HIGH confidence — direct codebase inspection)
- `Islet/Notch/NotchPillView.swift` (2002 lines, read in full across 2 passes) — `blobShape()` (line 1089), `trayFullView` (line 738), `body`'s outer frame (line 404), `switcherContentHeight`/`shelfRowHeight`/`switcherRowHeight`/`onboardingSize` constants (lines 258-330), `onboardingCarousel` precedent (line 786)
- `Islet/Notch/NotchWindowController.swift` (relevant sections read: lines 260-360, 740-1000) — `positionAndShow()` (line 749), `visibleContentZone()` (line 962), `handlePointer`/`syncClickThrough` call sites
- `Islet/Notch/NotchGeometry.swift` (read in full, 84 lines) — `topPinnedFrame`/`expandedNotchFrame`/`wingsFrame`
- `Islet/Notch/IslandResolver.swift` (read lines 1-140) — `IslandPresentation.trayExpanded` case, `showsSwitcherRow(for:)` shared function, `resolve(...)` precedence
- `Islet/Notch/ShelfItemView.swift` (read in full, 47 lines) — icon `.frame(width: 28, height: 28)` line 17, caption `.frame(maxWidth: 44)` line 23
- `IsletTests/NotchPillViewTests.swift` (read in full) — `shelfStripVisible` regression-lock precedent for how this codebase tests presentation-gating logic
- `IsletTests/NotchGeometryTests.swift` (grep'd for test names) — existing `expandedNotchFrame`/`wingsFrame` centering test pattern to extend
- `project.yml` (grep'd) — confirmed `SWIFT_VERSION: "5.0"`, `MACOSX_DEPLOYMENT_TARGET: "15.0"`, XCTest wiring
- `.planning/phases/32-tray-widening/32-CONTEXT.md`, `.planning/REQUIREMENTS.md`, `.planning/STATE.md` — user decisions, requirement wording, project history

### Secondary (MEDIUM confidence)
- None used — no WebSearch/Context7 lookups were needed for this phase; it is entirely internal-codebase geometry, no new framework API.

### Tertiary (LOW confidence)
- None.

## Metadata

**Confidence breakdown:**
- Standard stack: N/A — no new stack, HIGH confidence there is nothing to add
- Architecture: HIGH — every pattern cited is read directly from current source with exact line numbers, cross-checked against 3 prior analogous changes (shelf/switcher/onboarding) in the same file's own comments
- Pitfalls: HIGH — Pitfall 1 (`showSwitcher` height-override trap) and Pitfall 3 (CR-01 desync) are both derived from reading the actual current ternary logic and this project's own documented regression history (project memory `cr01-clickthrough-or-defeat-gotcha`), not speculation

**Research date:** 2026-07-14
**Valid until:** Indefinite for the architectural patterns (stable, first-party code, no external dependency drift) — re-verify only if Phase 33/34 touch the same `blobShape`/`positionAndShow`/`visibleContentZone` trio before Phase 32 executes (per REQUIREMENTS.md traceability, Phase 32 is sequenced immediately after Phase 31 and before Phase 33, so this is low risk).
