# Phase 52: Top-Edge Switcher Layout & Placement Config - Research

**Researched:** 2026-07-21
**Domain:** Native macOS SwiftUI — view geometry/layout, `@AppStorage`-driven config, notch-aware positioning
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Fully independent per-icon assignment — each of the 4 icons (Home, Tray, Calendar, Weather) can be placed in any of the 4 slots (left-outer, left-inner, right-inner, right-outer), not just a swap of two fixed pairs. (Superseded an initial "fixed-pair swap" answer once the dropdown-count clarification made the actual intent clear.)
- **D-02:** The Settings control is 4 dropdown pickers, one per slot, each offering all 4 icons.
- **D-03:** Placement reassignment applies to BOTH layouts — reassigning which icon goes in which slot also reorders the existing pill-below-island switcher's left-to-right icon order to match. This is a scope expansion onto the already-shipped, Phase-45-morph-fixed `switcherRow` — flag for research/planning as touching stable code, not just adding new code.
- **D-04:** Top-edge icons reuse the existing `navCircleButton` component verbatim (same filled-circle visual, same component) — no new icon treatment. Verify on-device that it physically fits the thinner top-edge strip; if it doesn't, that's a plan-time/UAT finding, not a pre-decided fallback.
- **D-05:** The active tab shows the same filled/highlighted state in top-edge mode as it does in the pill today, using `navCircleButton`'s existing `filled:` parameter — no new selection-state logic needed.
- **D-06:** When top-edge mode is active, the pill-below-island row is fully removed (not shown, not replaced) — the island's total height shrinks by the pill row's height, content area keeps its current height/size. This is the literal reading of the roadmap's "instead of" framing.
- **D-07:** The layout toggle (pill vs. top-edge) and the 4 placement dropdowns live together in a new dedicated "Switcher" section in Settings' sidebar — following Phase 51's just-established per-feature-section pattern rather than folding into an existing section (e.g. Appearance).
- **D-08:** On a display without a physical camera notch (external monitor, older MacBook), the top-edge layout option — including the new "Switcher" Settings section itself, per D-07 — is hidden entirely rather than shown in a degraded/centered form. The app already computes `hasNotch` (via `auxLeftWidth`/`auxRightWidth` off `NSScreen`, see `NotchGeometry.swift`) — reuse that existing signal to gate visibility.

### Claude's Discretion

- Exact SF Symbol / visual treatment for the new "Switcher" Settings section's sidebar icon.
- Whether `hasNotch` gating hides just the top-edge toggle/dropdowns within the Switcher section, or the entire section — implementation detail; the observable requirement (D-08) is that the option isn't reachable on non-notch displays.
- Any internal state/model needed to represent "which icon is in which of the 4 slots" (e.g. a `[SelectedView]` ordered array vs. 4 discrete `@AppStorage` slot values) — implementation detail for planning.
- Whether the existing pill's reordering (D-03) requires restructuring `switcherRow`'s hardcoded 4-button HStack into something iteration-driven, or can stay a hardcoded switch on slot assignment — implementation detail, must not regress Phase 45's continuous-view-identity morph fix.

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope. No pending todos matched this phase's domain (`.planning/todos/pending/` contains only calendar-grid, click-through, and Quick-Action-gating items — all unrelated to switcher layout/placement).
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SWITCH-03 | User can choose an alternate compact switcher layout in Settings — 4 small icons at the top edge of the expanded island (2 left of the camera notch, 2 right) instead of the default pill below the island | `blobShape`/`tabHeight` height-math split (Pitfall 1), `navCircleButton` reuse (D-04/D-05), notch-cutout-gap formula via `notchSize(...)` (Pitfall 2), `hasNotch`-gated Settings section without new controller plumbing (Pattern 2) |
| SWITCH-04 | User can configure which icons appear on the left vs. right side of the top-edge layout (default: Home+Tray left, Calendar+Weather right) | `SelectedView: String` `@AppStorage` compatibility (Pitfall 4), data-driven `switcherRow`/top-edge row ordering shared from one state source (Pattern 1, D-03), 4-dropdown `Picker(.menu)` Settings pattern (D-02, D-07) |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

- **Tech stack:** Native Swift + SwiftUI/AppKit only — no Electron/web, no new third-party UI package. This phase already complies: zero new dependencies, everything reuses in-repo SwiftUI/AppKit primitives.
- **Platform:** Apple-silicon notch MacBooks only (v1) — consistent with D-08's non-notch hide-entirely behavior (no degraded fallback UI to build for external monitors).
- **Builder skill (first-time programmer):** Explanations should accompany non-obvious code; avoid unnecessary complexity. This phase's recommended approach (reuse existing pure functions, avoid new controller plumbing, minimal additive `SelectedView: String` change) follows this directly — see Don't Hand-Roll and Architecture Patterns below.
- **Animation approach:** Continue using `matchedGeometryEffect` + spring animations for the island morph (Phase 45's existing convention) — do not introduce Core Animation/`CALayer` for the top-edge row.

## Summary

This phase adds an opt-in alternate switcher layout (4 icons flanking the camera cutout, top-edge) plus a user-configurable icon→slot mapping that drives BOTH the new top-edge layout and the existing pill. Everything needed already exists in the codebase as verified, reusable primitives: `navCircleButton`, `blobShape`'s `showSwitcher`/`switcherContentHeight`/`switcherRowHeight` machinery, the pure `hasNotch`/`notchSize`/`selectTargetScreen` geometry functions, and Phase 51's `SidebarSection`/`Form`-per-section Settings pattern. No new dependencies, no new architecture layer — this is a config/layout feature built entirely from existing seams.

Two load-bearing findings from reading the actual source (not just CONTEXT.md/UI-SPEC's description of it):

1. **`blobShape`'s height math conflates "show the pill row" with "reserve switcher-sized content height."** `baseHeight = height ?? (showSwitcher ? switcherContentHeight : expandedSize.height)` and `totalHeight = baseHeight + (showSwitcher ? switcherRowHeight : 0) + ...`. D-06 requires content height to STAY at `switcherContentHeight` (196) while the pill row's `+switcherRowHeight` (44) goes away — naively flipping `showSwitcher` to `false` in top-edge mode breaks `baseHeight` too (falls back to 144, a regression). This needs a second, independent flag, not a repurposed one. Same care needed for `tabHeight`'s outer `.frame` (NotchPillView.swift:993-999), which duplicates this exact ternary and MUST move in lockstep with `blobShape`'s internal calculation or the outer window frame and inner content box diverge.

2. **No new controller-to-view plumbing is actually required for the `hasNotch` gate (D-08).** CONTEXT.md/UI-SPEC both flag this as an open integration question ("needs a path to reach SwiftUI content"). Reading `NotchWindowController.swift:835-836` and `NSScreen+Notch.swift` shows `currentBuiltin()` is just `NSScreen.screens.map { $0.descriptor }.first { $0.isBuiltin }` — a cheap, synchronous, pure computation with zero controller-owned state. Both `NotchPillView` (already `import AppKit`) and `SettingsView` (currently a bare `SettingsView()` with no injected dependencies, `IsletApp.swift:56`) can call `selectTargetScreen(from: NSScreen.screens.map { $0.descriptor })` directly and get `hasNotch`/`auxLeftWidth`/`auxRightWidth` themselves — no `@Published` bridge, no new init parameter threading through `makeRootView`. This is the simplest correct answer per this project's own pure-function-first convention (ISL-01/ISL-06).

**Primary recommendation:** Reuse `navCircleButton` verbatim for the top-edge row; add a second `showSwitcherRow`-style content-height-only flag to `blobShape`/`tabHeight` (do not repurpose `showSwitcher`); compute `hasNotch`/cutout width via the existing pure `DisplayResolver`/`NotchGeometry` functions independently in both `NotchPillView` and `SettingsView` (no controller plumbing); give `SelectedView` a `String` raw value so it works directly as an `@AppStorage` type for the 4 slot pickers, instead of inventing a parallel enum.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Top-edge icon row rendering/positioning | SwiftUI View (`NotchPillView`) | — | Pure presentation; reuses `navCircleButton`, no new view primitive |
| Layout mode toggle (pill vs. top-edge) | `@AppStorage` (app-owned pref) | `NotchPillView` (reads it to branch render) | This app has no server/backend tier — `@AppStorage`/`UserDefaults` IS the persistence tier, per `ActivitySettings`' established convention |
| Icon→slot placement mapping | `@AppStorage` (4 keys) | `NotchPillView.switcherRow` + new top-edge row (both read it) | Single shared state feeding two renderers, per D-03 |
| Settings UI (toggle + 4 dropdowns) | SwiftUI View (`SettingsView`) | — | New `.switcher` `SidebarSection` case, Phase-51 `Form`-per-section pattern |
| Notch/camera-cutout geometry (`hasNotch`, cutout width) | Pure function layer (`NotchGeometry.swift`, `DisplayResolver.swift`) | `NSScreen+Notch.swift` (live bridge) | Already exists, already unit-tested, already the single source of truth — do not reimplement |
| Window/panel sizing (`expandedNotchFrame`, `tabHeight`/`tabWidth`) | `NotchWindowController` + `NotchPillView` computed properties | — | Existing seam; top-edge mode changes the height math inputs, not the seam itself |

## Standard Stack

No new libraries. This phase is 100% native SwiftUI/Foundation/AppKit, reusing existing in-repo primitives.

### Core (existing, reused)
| Component | Location | Purpose | Why reuse |
|-----------|----------|---------|-----------|
| `navCircleButton(systemName:filled:action:)` | `NotchPillView.swift:1897` | Circular icon button, filled/unfilled selection states | D-04/D-05 lock this verbatim; already gives the top-edge row correct active-state styling for free |
| `blobShape(...)` | `NotchPillView.swift:1973` | Shared shape/frame/content-box skeleton for every switcher-row presentation | Single source of truth for island sizing; must be extended carefully (see Pitfall 1), not forked |
| `hasNotch(safeAreaTop:auxLeftWidth:auxRightWidth:)` | `NotchGeometry.swift:12` | Pure notch-presence test | D-08's exact required signal; already unit-tested (`NotchGeometryTests.swift`) |
| `notchSize(screenWidth:safeAreaTop:auxLeftWidth:auxRightWidth:widthFudge:)` | `NotchGeometry.swift:27` | Pure physical cutout width | The correct source for the top-edge row's center clear-gap width (see Code Examples) |
| `selectTargetScreen(from:)` / `ScreenDescriptor` / `NSScreen.descriptor` | `DisplayResolver.swift`, `NSScreen+Notch.swift` | Resolve the one built-in notched display | Reused independently by both `NotchPillView` and `SettingsView`, no controller plumbing needed |
| `SidebarSection` enum + `Form`-per-section pattern | `SettingsView.swift:81-109`, `:318-331` | Settings navigation structure | Phase 51's just-established precedent (D-07 explicitly follows it) |

### Alternatives Considered
| Instead of | Could use | Tradeoff |
|------------|-----------|----------|
| Extending `SelectedView` with `: String` raw value for `@AppStorage` | A new parallel `SwitcherSlotIcon: String` enum + manual `SelectedView` mapping | Parallel enum avoids touching the Phase-28/45 type, but creates two enums that must stay in sync forever, and needs conversion functions at every read site. Adding `: String` to `SelectedView` is one line, additive, no behavior change (no existing code pattern-matches on `.rawValue`) — smaller surface area. |
| Independent `hasNotch` computation in both `NotchPillView`/`SettingsView` | A new `@Published` "screen geometry" object owned by `NotchWindowController`, injected into both views | The `@Published` bridge is more "correct" for a live-updating multi-window app in the abstract, but this codebase has ZERO existing precedent for pushing screen geometry into SwiftUI content (only `NotchWindowController` itself reads `ScreenDescriptor`, for window positioning). Given `NSScreen.screens` is cheap and synchronous, and both views already have `.onAppear`/`.onChange(of: appearsActive)` hooks (`SettingsView.swift:169-178`) to refresh a `@State` copy, duplicating the (already-pure, already-tested) computation is simpler and requires zero controller changes. |

**Installation:** None — no new packages.

## Package Legitimacy Audit

Not applicable — this phase adds zero external dependencies. Skipping the slopcheck/registry gate entirely (native SwiftUI/Foundation/AppKit only, no `Package.swift`/CocoaPods changes).

## Architecture Patterns

### System Architecture Diagram

```
┌─────────────────────────── Settings Window (SettingsView.swift) ───────────────────────────┐
│                                                                                                │
│  .switcher SidebarSection (new, D-07)                                                        │
│    ├─ Layout Picker(.segmented): Pill / Top Edge  ──────┐                                    │
│    └─ 4x Picker(.menu): Left Outer/Inner, Right Inner/Outer  │                                │
│         (each offers Home/Tray/Calendar/Weather)         │                                    │
│                                                            ▼                                    │
│  Gated by: hasNotch(safeAreaTop:auxLeftWidth:auxRightWidth:)  ← computed independently,        │
│  via NSScreen.screens.map{$0.descriptor} + selectTargetScreen(from:)  (D-08, no plumbing)      │
│                                                            │                                    │
└────────────────────────────────────────────────┬──────────┼────────────────────────────────────┘
                                                   │          │
                                    @AppStorage (UserDefaults, app-owned source of truth)
                                    switcher.layout, switcher.slot.{leftOuter,leftInner,
                                    rightInner,rightOuter}
                                                   │          │
                                                   ▼          ▼
┌───────────────────────── Notch Panel (NotchPillView.swift) ─────────────────────────────────┐
│                                                                                                │
│  tabContentView → blobShape(showSwitcher:, showTopEdgeIcons:[NEW])                           │
│    content()                                                                                  │
│    if switcherLayout == .pill { switcherRow }         ← reads slot @AppStorage for ORDER     │
│    else { /* top-edge row rendered OUTSIDE the pill's                                        │
│             +switcherRowHeight box, inside cameraClearance band, see Pitfall 1 */ }           │
│                                                                                                │
│  Top-edge row: HStack(spacing:0) {                                                            │
│    [2 navCircleButton, spacing 8]  Color.clear.frame(width: notchSize(...).width)             │
│    [2 navCircleButton, spacing 8]                                                             │
│  }  ← reads same 4 slot @AppStorage values for icon+position                                  │
│                                                                                                │
└────────────────────────────────────────────────────────────────────────────────────────────┘
```

### Recommended Project Structure

No new files needed. Modify in place:
```
Islet/
├── ActivitySettings.swift       # + SwitcherLayout enum, switcherLayoutKey, 4 slot keys
├── SettingsView.swift            # + .switcher SidebarSection case, switcherSection view
├── Notch/
│   ├── ViewSwitcherState.swift   # SelectedView: Equatable → SelectedView: String, Equatable
│   └── NotchPillView.swift       # switcherRow → data-driven order; + topEdgeSwitcherRow;
│                                  #   blobShape/tabHeight extended with 2nd height flag
```

### Pattern 1: Data-driven `switcherRow` (D-03 reorder, without breaking Phase 45's morph fix)

**What:** Replace the 4 hardcoded `navCircleButton` calls with a `ForEach` over an always-exactly-4-element ordered array derived from the slot `@AppStorage` values.

**When to use:** Both the pill's `switcherRow` and the new top-edge row need the SAME ordered `[SelectedView]` — extract one shared computed property.

**Example:**
```swift
// Source: derived from NotchPillView.swift:2041-2057 (switcherRow) — pattern only, not
// verbatim existing code.
private var orderedSlotIcons: [SelectedView] {
    [slotLeftOuter, slotLeftInner, slotRightInner, slotRightOuter] // read from @AppStorage
}

private func icon(for view: SelectedView) -> (systemName: String, action: () -> Void) {
    switch view {
    case .home:     return ("house.fill",   { onSwitcherSelect(.home) })
    case .tray:     return ("tray.fill",    { onSwitcherSelect(.tray) })
    case .calendar: return ("calendar",     { onSwitcherSelect(.calendar) })
    case .weather:  return ("cloud.sun.fill", { onSwitcherSelect(.weather) })
    }
}

private var switcherRow: some View {
    HStack(spacing: 8) {
        ForEach(orderedSlotIcons, id: \.self) { view in
            let mapping = icon(for: view)
            navCircleButton(systemName: mapping.systemName,
                             filled: viewSwitcherState.selectedView == view,
                             action: mapping.action)
        }
    }
    .frame(height: Self.switcherRowHeight)
}
```
Safe for Phase 45's structural-identity rule because the `ForEach` always produces exactly 4 children (same as the hardcoded version) — no conditional insertion/removal of subtree branches, no `AnyView`. `SelectedView` needs `Hashable` (falls out of `Equatable` + the new `String` raw value) for `id: \.self`.

### Pattern 2: Independent `hasNotch`/cutout-geometry read (no controller plumbing, D-08)

**What:** Both `SettingsView` and `NotchPillView` call the existing pure functions directly.
**Example:**
```swift
// Source: pattern derived from NotchWindowController.swift:835-836 (currentBuiltin()) +
// DisplayResolver.swift:38 (selectTargetScreen) + NSScreen+Notch.swift:27 (descriptor).
// SettingsView.swift — refresh alongside the existing onAppear/onChange(appearsActive) hooks.
@State private var hasNotchDisplay: Bool = false

private func refreshNotchAvailability() {
    let target = selectTargetScreen(from: NSScreen.screens.map { $0.descriptor })
    hasNotchDisplay = target?.hasNotch ?? false
}
// call refreshNotchAvailability() in .onAppear and .onChange(of: appearsActive), same
// sites that already refresh launchAtLogin/licenseStatus (SettingsView.swift:169-178).
```
```swift
// NotchPillView.swift — computed property, re-evaluated each render (cheap, synchronous).
private var cutoutClearWidth: CGFloat {
    guard let target = selectTargetScreen(from: NSScreen.screens.map { $0.descriptor }) else { return 0 }
    return notchSize(screenWidth: target.frame.width,
                      safeAreaTop: target.safeAreaTop,
                      auxLeftWidth: target.auxLeftWidth,
                      auxRightWidth: target.auxRightWidth)?.width ?? 0
}
```

### Anti-Patterns to Avoid
- **Repurposing `showSwitcher` for the top-edge mode:** `showSwitcher: false` also drops `baseHeight` from `switcherContentHeight` (196) to `expandedSize.height` (144) — a silent content-area shrink that contradicts D-06 ("content area keeps its current height/size"). Add a second flag (e.g. `showSwitcherRow: Bool` separate from an implicit `reservesSwitcherHeight` that stays true in both layouts).
- **Using `auxLeftWidth + auxRightWidth` directly as the center clear-gap width inside the 420pt-wide panel:** those are screen-relative strip widths beside the notch on the FULL display, not the notch's own width. The correct value is `notchSize(...).width` (screen width minus both strips, i.e. the actual camera cutout width) — UI-SPEC's pseudocode already hints at this ("auxRightWidth-derived cutout gap") but a literal reading of `auxLeftWidth + auxRightWidth` would reserve entirely the wrong (much larger) amount of space.
- **`.offset(x:y:)` / `.position(x:y:)` for the top-edge row:** empirically broken in this codebase's shape/content stack per Phase 39's documented lesson (GeometryReader misreports origin/size). Use `HStack(spacing: 0)` with `Color.clear.frame(width:)` spacers, per UI-SPEC.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Notch/camera presence detection | A new heuristic reading `NSScreen.safeAreaInsets` or `auxiliaryTopLeftArea` ad hoc | `hasNotch(safeAreaTop:auxLeftWidth:auxRightWidth:)` (`NotchGeometry.swift:12`) | Already handles the "one strip alone is not a notch" edge case and is unit-tested (3 cases in `NotchGeometryTests.swift`) |
| Cutout width for center-gap sizing | Guessing a fixed pt value (e.g. hardcode 200pt) | `notchSize(...)` — computes the real per-device width including `widthFudge` | Notch width varies across MacBook models; a hardcoded value would look wrong or clip on some hardware |
| Icon selection button visual | A second circular-button component for the top-edge row | `navCircleButton` verbatim (D-04) | Locked decision; zero new visual surface to maintain |
| Icon-order persistence | A custom `[String]`-encoded array in `UserDefaults` | 4 independent `@AppStorage` keys (one per slot), `SelectedView`-typed | Matches this codebase's `weatherStyle`/`materialStyle` single-value-per-key convention exactly; simpler diffing/no manual array encode/decode |

**Key insight:** Every piece this phase needs (notch geometry, icon button, settings-section scaffolding, `@AppStorage` convention) already has one canonical implementation in this codebase. The entire phase should read as "wire existing primitives together with new state," not "build new primitives."

## Common Pitfalls

### Pitfall 1: `blobShape`'s height math silently regresses content height when reusing `showSwitcher: false`
**What goes wrong:** Content area shrinks from 196pt to 144pt in top-edge mode, contradicting D-06 and visually breaking every existing Home/Tray/Calendar/Weather full view when top-edge mode is active.
**Why it happens:** `baseHeight` and `totalHeight` are both derived from the single `showSwitcher` Bool (`NotchPillView.swift:1990-1992`); it conflates "does this presentation reserve switcher-sized content" with "is the pill row itself shown."
**How to avoid:** Add a second flag that keeps `baseHeight` on the `switcherContentHeight` branch regardless of layout mode, and only makes the `+switcherRowHeight` addition conditional on "pill layout AND showSwitcher." Mirror this exact split in `tabHeight`'s outer `.frame` calculation (`NotchPillView.swift:993-999`) — it duplicates the same ternary and must move in lockstep or the window frame and the inner content box will disagree.
**Warning signs:** Home/Weather/Calendar/Tray full views visibly shrink or reflow when the layout toggle flips, even though D-06 says only the pill row should be affected.

### Pitfall 2: Confusing screen-relative strip widths with the panel-relative cutout gap
**What goes wrong:** Top-edge icons render too far apart (huge empty gap) or clip into the cutout, because the center spacer used the wrong width source.
**Why it happens:** `auxLeftWidth`/`auxRightWidth` are the widths of the strips BESIDE the notch on the full physical screen — not the notch's own width, and not scaled to the 420pt-wide expanded panel's coordinate space.
**How to avoid:** Use `notchSize(screenWidth:safeAreaTop:auxLeftWidth:auxRightWidth:).width` — the formula already computes `screenWidth - left - right + widthFudge`, i.e. the actual camera cutout width, which is the correct value to reserve as blank space in the center of the top-edge `HStack`.
**Warning signs:** On-device the icon-to-cutout gap looks visually wrong (too wide/narrow) compared to the real camera housing, especially across different MacBook models with different notch widths.

### Pitfall 3: 36pt `navCircleButton` inside the 42pt `cameraClearance` band is a tight fit
**What goes wrong:** Icon circles may visually touch/clip the top/bottom edges of their available band, or (worse) get clipped by `blobShape`'s own `.clipShape(shape)` if positioned even slightly outside the intended box.
**Why it happens:** `cameraClearance` (42pt) minus `navCircleDiameter` (36pt) leaves only ~3pt of vertical margin (~1.5pt top/bottom if centered) — see UI-SPEC's own flagged risk.
**How to avoid:** Per D-04, verify on-device before assuming a fix is needed; do NOT preemptively shrink `navCircleButton`'s diameter for the top-edge row only (that would violate D-04's "verbatim, no new treatment" decision and create an inconsistent visual between the two layouts). If it doesn't fit, this is a plan-time/UAT finding requiring a discussion round, not a silent workaround.
**Warning signs:** Icon circles appear clipped top/bottom, or `blobShape`'s rounded-corner mask cuts into the outer two icons (left-outer/right-outer sit closest to `NotchShape`'s `topCornerRadius`, the tightest corner).

### Pitfall 4: `@AppStorage` requires `RawRepresentable where RawValue == String` (or a handful of primitive types) — `SelectedView` doesn't have one yet
**What goes wrong:** Code that tries `@AppStorage(key) var slotLeftOuter: SelectedView = .home` fails to compile — `SelectedView` is currently a plain `Equatable` enum with no raw value.
**Why it happens:** `ViewSwitcherState.swift:9-14` defines `enum SelectedView: Equatable` — sufficient for its original single-source-of-truth role (compared with `==`), never previously needed to round-trip through `UserDefaults`.
**How to avoid:** Add `: String` to `SelectedView`'s declaration (`enum SelectedView: String, Equatable { case home, tray, calendar, weather }`) — additive, no behavior change, mirrors `WeatherStyle`/`MaterialStyle`'s exact existing pattern (`ActivitySettings.swift:49-51`, `:60-62`). This is the smallest correct fix; do not introduce a second, parallel enum just to avoid a one-line change to Phase 28/45's type (see Alternatives Considered).
**Warning signs:** Build failure on the 4 slot `@AppStorage` declarations if this step is skipped.

### Pitfall 5: Duplicate icon assignment across slots is unaddressed by CONTEXT.md
**What goes wrong:** If the user assigns e.g. "Home" to both Left Outer and Right Inner, both the pill and top-edge row would render two identical Home buttons, and any code that assumes 1:1 icon↔slot (e.g. deriving `filled:` per position) still behaves correctly (each button still independently reflects `selectedView == .home`), but the UX reads as broken/duplicated.
**Why it happens:** Each of the 4 `Picker`s is an independent `@AppStorage` value (D-02's literal "4 dropdown pickers" instruction) — nothing enforces the 4 values are a permutation.
**How to avoid:** This is flagged as Claude's Discretion territory in UI-SPEC, not decided. Recommend surfacing as an explicit Open Question for the planner/discuss-phase rather than silently either allowing or blocking duplicates.
**Warning signs:** N/A pre-emptively — this is a design decision gap, not a code bug.

## Code Examples

### Reserving the cutout gap correctly (verified formula, not the UI-SPEC's shorthand)
```swift
// Source: NotchGeometry.swift:27-37 (notchSize), read directly from this codebase.
// width = screenWidth - auxLeftWidth - auxRightWidth + widthFudge(4)
// This is the value to reserve as Color.clear.frame(width:) in the top-edge HStack's
// center — NOT auxLeftWidth + auxRightWidth (that sums the STRIPS beside the notch,
// not the notch itself).
```

### `SelectedView` made `@AppStorage`-compatible (additive, mirrors existing convention)
```swift
// Source: ViewSwitcherState.swift:9-14, extended per ActivitySettings.swift:49-51's
// existing WeatherStyle: String, CaseIterable pattern.
enum SelectedView: String, Equatable, CaseIterable {
    case home, tray, calendar, weather
}
```

## State of the Art

Not applicable — this is a self-contained native macOS app with no external framework version drift to track. All reused primitives were written within this same codebase in the last ~1 month (Phase 28/32/45).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Recommending `SelectedView: String` extension (rather than a parallel enum) is the right tradeoff | Pitfall 4 / Alternatives Considered | Low — purely additive, easy to revert; worst case the planner chooses the parallel-enum path instead, costing a slightly larger diff |
| A2 | `notchSize(...).width` (not `auxLeftWidth + auxRightWidth`) is the correct center-gap value | Pattern 2 / Pitfall 2 | Medium if wrong — derived directly from reading `NotchGeometry.swift`'s own formula, not guessed; but the exact on-screen visual result (whether it "looks right" against the physical camera housing) can only be confirmed on real hardware per D-04's own instruction |
| A3 | Independent `hasNotch`/`selectTargetScreen` computation in both views (no controller plumbing) is sufficient — no live-update edge case (e.g. mid-session external-monitor-only reconfig while Settings is open) needs special handling beyond the existing `.onAppear`/`.onChange(of: appearsActive)` refresh points | Pattern 2 | Low — this mirrors `licenseStatus`/`launchAtLogin`'s existing refresh convention exactly; if a live external-display-unplug-while-Settings-open scenario matters, the existing `didChangeScreenParametersNotification` observer pattern (`NotchWindowController.swift:466-474`) could be added to `SettingsView` too, but no existing SwiftUI view in this codebase does that today |

**None of these are compliance/security/retention claims** — all are internal architecture tradeoffs derived directly from reading the actual source files, not training-data guesses about SwiftUI/macOS APIs in general.

## Open Questions (RESOLVED)

1. **Duplicate icon assignment across the 4 slots (Pitfall 5)** — RESOLVED
   - What we know: D-02 specifies 4 independent dropdowns; nothing in CONTEXT.md constrains them to a permutation.
   - What's unclear: Whether duplicates should be silently allowed, silently prevented (e.g. picking an icon already used elsewhere swaps it with the slot losing it), or surfaced as a Settings-level validation error.
   - Recommendation: Flag for the planner to make an explicit call (simplest: allow duplicates, no validation — matches this codebase's general "trust the user's Settings input" convention, e.g. no validation exists on any other Picker/Toggle in `SettingsView.swift` today).
   - Resolution: Plans 52-01/52-03 adopted the recommendation as-is — duplicates are allowed, no validation added, consistent with the existing no-Picker-validation convention.

2. **Second `blobShape` flag naming/shape (Pitfall 1)** — RESOLVED
   - What we know: `showSwitcher` must NOT be repurposed; a second signal is needed so `baseHeight` stays on the `switcherContentHeight` branch in top-edge mode while `totalHeight`'s `+switcherRowHeight` term becomes conditional on pill-layout-only.
   - What's unclear: Exact parameter shape — a new `Bool` parameter to `blobShape` (e.g. `reservesSwitcherHeight: Bool = false`, defaulting to `showSwitcher`'s old value for every existing call site) vs. computing it inline from `switcherLayout` at the one call site (`tabContentView`) that needs it.
   - Recommendation: Planner's implementation-detail call; either is a small, contained change — the key constraint is `tabHeight`'s outer `.frame` (NotchPillView.swift:993-999) must be updated in the SAME plan step as `blobShape`'s internal calc, since the two currently duplicate the same ternary and drift risk is real (confirmed by reading both call sites).
   - Resolution: Plan 52-02 Task 2 adds a `switcherLayout`-driven parameter to `blobShape` and updates the outer `.frame` ternary and `visibleContentZone()` in the same task — the three-site fix.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode / xcodebuild | Build + test (`xcodebuild test -scheme Islet`) | ✓ | Xcode 26.6 (Build 17F113) | — |

No other external dependencies — pure Swift/SwiftUI/Foundation/AppKit changes to existing files.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest, `@testable import Islet` |
| Config file | `project.yml` (xcodegen) — `IsletTests` target, shared `Islet` scheme with `test` action |
| Quick run command | `xcodebuild test -scheme Islet -only-testing:IsletTests/NotchPillViewTests` (this project has a documented `xcodebuild test` headless-hang precedent per STATE.md — a manual Cmd-U pass in Xcode is the established fallback/confirmation step) |
| Full suite command | `xcodebuild test -scheme Islet` (or Cmd-U in Xcode) |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SWITCH-03 | `tabHeight`/`tabWidth` in top-edge mode reserve `switcherContentHeight` for content but NOT `+switcherRowHeight` for the (now-absent) pill row | unit | `xcodebuild test -scheme Islet -only-testing:IsletTests/NotchPillViewTests` | ❌ Wave 0 — extend `testTabWidthHeightMatchesKnownPerCaseValues`-style locked-values test with a top-edge-mode case |
| SWITCH-03 | `hasNotch` gates Settings `.switcher` section visibility (D-08) | unit | Reuses existing `hasNotch(...)` pure-function tests already in `NotchGeometryTests.swift`; new test needed only for the SettingsView-side filter logic if extracted into a testable pure function | ❌ Wave 0 — if the filter is a plain `SidebarSection.allCases.filter { ... }` inline in the View body, it is not independently unit-testable without extracting the predicate; recommend extracting `visibleSidebarSections(hasNotch:) -> [SidebarSection]` as a pure function, mirroring this codebase's `showsSwitcherRow(for:)` precedent (`IslandResolver.swift:109`) |
| SWITCH-04 | Default slot assignment is Home+Tray left, Calendar+Weather right | unit | New test asserting `@AppStorage` default values / the default `orderedSlotIcons` array | ❌ Wave 0 |
| SWITCH-04 | Reassigning a slot updates BOTH `switcherRow`'s pill order and the top-edge row's position (D-03) from one shared state | unit | New test constructing `NotchPillView` with overridden slot `UserDefaults` values (mirrors `testTabWidthHeightMatchesKnownPerCaseValues`'s existing `UserDefaults.standard` override-and-restore pattern for `weatherStyleKey`) and asserting `orderedSlotIcons` reflects the override | ❌ Wave 0 |
| SWITCH-04 | Cutout-gap width uses `notchSize(...).width`, not `auxLeftWidth + auxRightWidth` (Pitfall 2) | unit | If extracted as a small pure function (e.g. `topEdgeCutoutGap(descriptor:) -> CGFloat`), directly testable with hand-built `ScreenDescriptor` values, mirroring `DisplayResolverTests.swift`'s existing construction pattern | ❌ Wave 0 |
| SWITCH-03 (SC#5) | Existing pill mode shows no regression | regression | `testShelfStripVisibleIsAlwaysFalse` + `testTabWidthHeightMatchesKnownPerCaseValues` (existing, `NotchPillViewTests.swift`) must still pass unmodified for pill-mode default | ✅ existing |

### Sampling Rate
- **Per task commit:** `xcodebuild test -scheme Islet -only-testing:IsletTests/NotchPillViewTests -only-testing:IsletTests/NotchGeometryTests` (fast, targeted)
- **Per wave merge:** `xcodebuild test -scheme Islet` (full suite) or Cmd-U in Xcode per this project's documented headless-test-hang workaround
- **Phase gate:** Full suite green (or Cmd-U-confirmed) before `/gsd:verify-work`, PLUS an on-device UAT checkpoint for the two purely-visual/hardware-dependent findings this research could not verify from source alone: (1) whether 36pt `navCircleButton` visually fits inside the 42pt `cameraClearance` band on real notched hardware (Pitfall 3, D-04), and (2) whether the computed cutout-gap width visually clears the real camera housing across the user's actual MacBook model (Pitfall 2)

### Wave 0 Gaps
- [ ] Extend `IsletTests/NotchPillViewTests.swift` with a top-edge-mode `tabHeight`/`tabWidth` locked-value case (Pitfall 1 regression lock)
- [ ] New pure function `orderedSlotIcons(...)` (or equivalent) + test for default values and override behavior (SWITCH-04)
- [ ] New pure function for cutout-gap-width derivation (or inline in `NotchPillView` if the planner judges extraction unnecessary) + test (Pitfall 2)
- [ ] If `SidebarSection` visibility filtering is extracted as a pure function (recommended, mirrors `showsSwitcherRow(for:)`), add its test to a new or existing test file
- Framework install: none — `XCTest`/`IsletTests` target already fully configured

## Security Domain

No `security_enforcement` flag found in `.planning/config.json` — treated as enabled per default, but this phase has essentially no attack surface: all new state is local `@AppStorage`/`UserDefaults` (app-owned preferences, same trust tier as `weatherStyle`/`materialStyle`), no network calls, no new file I/O, no new permission grants, no user-supplied strings rendered unsanitized (the 4 slot values are `Picker`-constrained to the 4 known `SelectedView` cases, not free text).

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-------------------|
| V2 Authentication | No | No auth surface in this phase |
| V3 Session Management | No | N/A |
| V4 Access Control | No | N/A |
| V5 Input Validation | Marginal | `SelectedView(rawValue:)` decoding from `UserDefaults` must fall back safely on a corrupted/unknown stored string — mirror the existing `WeatherStyle`/`MaterialStyle` `?? .default` convention (`ActivitySettings.swift`'s established pattern, e.g. `NotchWindowController.swift:1474`) rather than force-unwrapping |
| V6 Cryptography | No | N/A |

### Known Threat Patterns for this stack
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Corrupted/tampered `UserDefaults` value for a slot key (e.g. manual `defaults write`) causing a decode failure | Tampering (low severity — local-only, no privilege boundary crossed) | `SelectedView(rawValue: stored) ?? .home` fallback at every read site, matching this codebase's existing convention for every other `String`-backed `@AppStorage` enum |

## Sources

### Primary (HIGH confidence — read directly from this codebase in this session)
- `Islet/Notch/NotchPillView.swift` — `navCircleButton` (1897), `switcherRow` (2041), `blobShape` (1973), `presentationSwitch`/`tabContentView` (854-921), `cameraClearance`/`switcherRowHeight`/`switcherContentHeight`/`expandedSize` constants (599-651, 273)
- `Islet/Notch/NotchGeometry.swift` — `hasNotch`, `notchSize`, `notchFrame`, `expandedNotchFrame`
- `Islet/Notch/NSScreen+Notch.swift` — `NSScreen.descriptor` bridge
- `Islet/Notch/DisplayResolver.swift` — `ScreenDescriptor`, `selectTargetScreen`
- `Islet/Notch/NotchWindowController.swift` — `currentBuiltin()` (835), `makeRootView(theme:)` (2134), `didChangeScreenParametersNotification` observer (466-474)
- `Islet/Notch/ViewSwitcherState.swift` — `SelectedView` enum, `ViewSwitcherState`
- `Islet/Notch/IslandResolver.swift` — `IslandPresentation`, `showsSwitcherRow(for:)` (109)
- `Islet/ActivitySettings.swift` — `WeatherStyle`/`MaterialStyle` `@AppStorage` key conventions
- `Islet/SettingsView.swift` — `SidebarSection` enum (81-109), section-rendering `ForEach` (121-135), `weatherSection`/`activitiesSection`/`fullscreenSection` Phase-51 pattern examples (209-331)
- `IsletTests/NotchPillViewTests.swift` — existing locked-value test pattern for `tabWidth`/`tabHeight`
- `IsletTests/NotchGeometryTests.swift` — `hasNotch` unit test pattern
- `project.yml` — test target/scheme configuration
- `xcodebuild -version` (session Bash call) — confirmed Xcode 26.6 present

### Secondary (MEDIUM confidence)
- None — no external web sources were needed; this phase is entirely internal-codebase research.

### Tertiary (LOW confidence)
- None.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — zero new dependencies, every primitive read directly from source
- Architecture: HIGH — `blobShape`/`tabHeight` height-math interaction (Pitfall 1) and the notch-gap-width formula (Pitfall 2) were derived by reading the actual constant definitions and call sites, not assumed
- Pitfalls: HIGH for code-level pitfalls (1, 2, 4 — all verified against source); MEDIUM for Pitfall 3 (36pt-in-42pt fit) since final confirmation requires real hardware, exactly as D-04/UI-SPEC already flag

**Research date:** 2026-07-21
**Valid until:** No expiry driver — this is a closed, internal-codebase research pass with no external library version dependency. Valid until the underlying `NotchPillView.swift`/`SettingsView.swift` source changes materially (e.g. another phase touching `blobShape` or `SidebarSection` before this phase executes).
