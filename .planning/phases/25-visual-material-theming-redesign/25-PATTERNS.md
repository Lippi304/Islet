# Phase 25: Visual/Material Theming Redesign - Pattern Map

**Mapped:** 2026-07-11
**Files analyzed:** 3 (all modified in-place, zero new files)
**Analogs found:** 3 / 3 (self-analog — every edit site's closest pattern is a sibling call site in the same file)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|-----------------|----------------|
| `Islet/Notch/NotchPillView.swift` (4 fill sites: `collapsedIsland`, `blobShape`, `wingsShape`, `mediaWingsOrToast`) | component (SwiftUI View, declarative fill/shape) | transform (props → rendered shape) | itself — 3 of the 4 sites already share near-identical `NotchShape().fill(Color.black).matchedGeometryEffect(...).frame(...)` skeletons | exact (self-consistent, no external analog needed) |
| `Islet/Notch/NotchPillView.swift` (bottomCornerRadius literals at `expandedIsland`/`mediaExpanded`/`mediaUnavailable`) | component (shape parameterization) | transform | itself — 3 call sites already pass the same `topCornerRadius: 6, bottomCornerRadius: 20` pair into `blobShape(...)` | exact |
| `Islet/Notch/NotchWindowController.swift` (`springResponse`/`springDamping` constants, lines 264-265) | controller (AppKit window/animation glue) | event-driven (pointer/click → state mutation → animated re-render) | itself — single source of truth already read by 13 `withAnimation(.spring(...))` call sites | exact |
| `Islet/Notch/NotchShape.swift` | component (custom `Shape`, pure geometry) | transform | not modified this phase (D-09 confirmed no change) — included for context only | n/a (unchanged) |

No cross-file or cross-codebase analog search was needed: CONTEXT.md/RESEARCH.md/UI-SPEC.md all confirm this phase edits values inside 3 already-identified files, with zero new files, new types, or new architecture. The "pattern to copy from" is each file's own existing internal convention.

## Pattern Assignments

### `Islet/Notch/NotchPillView.swift` — gradient fill (component, transform)

**Analog:** the file's own 4 existing fill sites (they must all read identically per D-02's "one shared material")

**Imports** (line 1):
```swift
import SwiftUI
```
No new imports needed — `LinearGradient` is part of `SwiftUI`, already imported.

**Site 1 — `collapsedIsland` (lines 211-225), fill via `collapsedFill` computed var (lines 728-734):**
```swift
private var collapsedIsland: some View {
    let size = interaction.collapsedNotchSize ?? Self.collapsedSize
    return NotchShape()
        .fill(collapsedFill)
        .matchedGeometryEffect(id: "island", in: ns)
        .frame(width: size.width, height: size.height)
        .scaleEffect(interaction.isHovering && !interaction.isExpanded ? 1.06 : 1.0)
        .offset(y: devOffset)
        .onTapGesture { onClick() }
}
...
private var collapsedFill: Color {
    #if DEBUG
    return Color.red.opacity(0.6)
    #else
    return Color.black          // ← THIS branch becomes the shared gradient
    #endif
}
```
**Pattern to copy:** `collapsedFill`'s return type is `Color`; changing it to return the shared `LinearGradient` requires either (a) widening `collapsedFill`'s return type to `some ShapeStyle` (Swift allows opaque-return-type `if/else` across `Color`/`LinearGradient` only if both branches conform to the same declared type — `Color` and `LinearGradient` both conform to `ShapeStyle`, so `some ShapeStyle` works), or (b) keeping `collapsedFill: Color` for the `#if DEBUG` red tint and applying the gradient as a *separate* `.fill()` only in the `#else` path via an inlined conditional in `collapsedIsland` itself. UI-SPEC.md's Verification Notes (line 112) explicitly says: "keep the `#if DEBUG` red tint" — the DEBUG branch is unaffected, only the `#else` branch's `Color.black` becomes the gradient.

**Site 2 — `blobShape<Content>` helper (lines 270-295), the SHARED skeleton for `expandedIsland`/`mediaExpanded`/`mediaUnavailable`:**
```swift
private func blobShape<Content: View>(topCornerRadius: CGFloat,
                                       bottomCornerRadius: CGFloat,
                                       alignment: Alignment = .center,
                                       shelfItems: [ShelfItem],
                                       @ViewBuilder content: () -> Content) -> some View {
    let hasShelf = !shelfItems.isEmpty
    let height = Self.expandedSize.height + (hasShelf ? Self.shelfRowHeight : 0)
    return NotchShape(topCornerRadius: topCornerRadius, bottomCornerRadius: bottomCornerRadius)
        .fill(Color.black)                          // ← swap to shared gradient
        .matchedGeometryEffect(id: "island", in: ns)
        .frame(width: Self.expandedSize.width, height: height)
        .overlay(alignment: .top) { ... }
        .onTapGesture { onClick() }
}
```
This is the single edit point for 3 of the 4 fill sites at once (`expandedIsland` line 236, `mediaExpanded` line 651, `mediaUnavailable` line 716 all route through this one helper) — no per-caller duplication needed.

**Site 3 — `wingsShape<Content>` helper (lines 332-344), shared by `wings(for:)` and `deviceWings(for:)`:**
```swift
private func wingsShape<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    NotchShape(topCornerRadius: 6, bottomCornerRadius: 6)
        .fill(Color.black)                          // ← swap to shared gradient
        .matchedGeometryEffect(id: "island", in: ns)
        .frame(width: Self.wingsSize.width, height: Self.wingsSize.height)
        .overlay(content().frame(width: Self.wingsSize.width, height: Self.wingsSize.height))
        .onTapGesture { onClick() }
}
```

**Site 4 — `mediaWingsOrToast(_:)` (lines 393-412), the ONE site that builds its own `NotchShape` directly (bottom radius varies with toast presence, so it can't route through `wingsShape`):**
```swift
@ViewBuilder
private func mediaWingsOrToast(_ p: NowPlayingPresentation) -> some View {
    let toast = nowPlaying.songChangeToast
    let height = Self.wingsSize.height + (toast != nil ? Self.toastExtraHeight : 0)
    NotchShape(topCornerRadius: 6, bottomCornerRadius: toast != nil ? 16 : 6)
        .fill(Color.black)                          // ← swap to shared gradient
        .matchedGeometryEffect(id: "island", in: ns)
        .frame(width: Self.wingsSize.width, height: height)
        .overlay(alignment: .top) { ... }
        .onTapGesture { onClick() }
}
```

**Recommended shared definition** (add once, e.g. as a `private static let` near `collapsedSize`/`expandedSize`/`wingsSize`, lines 107-134, following that file's own established "size seed as `static let`" convention):
```swift
// Following the same static-let-single-source-of-truth convention as collapsedSize/
// expandedSize/wingsSize above — ONE gradient definition read by all 4 fill sites (D-02).
private static let islandMaterial = LinearGradient(
    stops: [
        .init(color: .black, location: 0.0),
        .init(color: .black, location: 0.65),           // D-02: long solid stretch, tune on-device (0.6-0.7 band)
        .init(color: .black.opacity(0.5), location: 1.0) // D-02: ~50% floor, never .clear
    ],
    startPoint: .top,
    endPoint: .bottom
)
```
Then every `.fill(Color.black)` becomes `.fill(Self.islandMaterial)` (the helpers already use `Self.` for `expandedSize`/`wingsSize`, so this matches the file's existing static-member-access convention exactly — e.g. line 276 `Self.expandedSize.height`, line 336 `Self.wingsSize.width`).

**Corner radius numeric edit** — 3 call sites, all pass the literal directly as an argument (no shared constant to edit once, unlike the gradient):
```swift
// Line 236 (expandedIsland):
blobShape(topCornerRadius: 6, bottomCornerRadius: 20, shelfItems: shelfViewState.items) { ... }
// Line 651 (mediaExpanded):
blobShape(topCornerRadius: 6, bottomCornerRadius: 20, alignment: .top, shelfItems: shelfViewState.items) { ... }
// Line 716 (mediaUnavailable):
blobShape(topCornerRadius: 6, bottomCornerRadius: 20, shelfItems: shelfViewState.items) { ... }
```
D-08 raises all three `bottomCornerRadius: 20` → `32` (starting point, UI-SPEC.md line 57). All 3 sites must be edited in lock-step to avoid the 3 expanded-blob variants (idle/media/unavailable) drifting to different roundness — they are currently identical (`6/20`) and must stay identical (`6/32`).

**Error handling / validation:** Not applicable — this is a pure rendering-value change; no new user input, no new error paths (RESEARCH.md Security Domain: "not applicable").

---

### `Islet/Notch/NotchWindowController.swift` — spring constants (controller, event-driven)

**Analog:** the file's own single declaration site, already the sole source read by all 13 call sites

**Current declaration (lines 260-265):**
```swift
// The spring applied at every phase mutation (ISL-04 / D-07). Snappy with a slight
// bounce. The two seeds live here so Plan 05 tunes the feel in ONE place; each mutation
// site spells out `withAnimation(.spring(response:dampingFraction:))` so the animation
// is provably attached AT the state change (the view itself drives no animation, D-08).
private let springResponse: Double = 0.35
private let springDamping: Double = 0.65
```

**Representative call site (lines 518-533, `presentTransientChange()`; identical shape repeats 12 more times at lines 519/747/789/799/834/921/1010/1019/1107/1179/1199/1212/1242):**
```swift
private func presentTransientChange() {
    withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
        if nowPlayingState.songChangeToast != nil {
            toastDismissWorkItem?.cancel()
            nowPlayingState.songChangeToast = nil
        }
        renderPresentation()
    }
    updateVisibility()
    scheduleActivityDismiss()
}
```

**Edit:** change ONLY the 2 declarations (lines 264-265) to the UI-SPEC.md starting values — no call site touched, matching RESEARCH.md Pattern 2 and UI-SPEC.md's explicit "retune only these two declarations, touch no call site":
```swift
private let springResponse: Double = 0.6    // was 0.35 — slower per D-05
private let springDamping: Double = 0.62    // was 0.65 — more visible overshoot per D-06
```

**Adjacent constant to watch, NOT edit (line 258):**
```swift
// D-03 grace delay (within the 0.3–0.5s window). One place for Plan 05 to tune.
private let graceDelay: TimeInterval = 0.4
```
RESEARCH.md Pitfall 4 / Open Question 1 and UI-SPEC.md's "Watch item": test rapid hover-enter/exit/re-enter on-device after retuning the spring; `graceDelay` is out of this phase's scope but flag as a follow-up (not a silent fix) if a double-morph artifact appears.

**Error handling:** Not applicable — no new error path; this is a numeric constant change consumed by existing, already-correct `withAnimation` call sites.

---

### `Islet/Notch/NotchShape.swift` — no changes this phase (D-09 confirmed)

**Analog:** N/A — file is read-only context for this phase, not an edit target, per the locked D-09 decision (top-corner mechanism already correct) and UI-SPEC.md line 115 ("No changes to NotchShape.swift's path math (D-09) unless the animatableData watch-item is triggered on-device").

**Current state (lines 9-33), included for the contingency path only:**
```swift
struct NotchShape: Shape {
    var topCornerRadius: CGFloat = 6
    var bottomCornerRadius: CGFloat = 14
    func path(in rect: CGRect) -> Path {
        // quad-curve path math — unchanged this phase
    }
}
```
No `animatableData` conformance exists today (verified: zero `animatableData`/`AnimatablePair`/`VectorArithmetic` references in the file or codebase). **Contingency only** (RESEARCH.md Pitfall 1, UI-SPEC.md Watch item): if D-08's larger bottom-radius delta (20→32 vs. wings' unchanged 6) produces a visible on-device "snap" during the morph, the fix is adding:
```swift
var animatableData: AnimatablePair<CGFloat, CGFloat> {
    get { AnimatablePair(topCornerRadius, bottomCornerRadius) }
    set { topCornerRadius = newValue.first; bottomCornerRadius = newValue.second }
}
```
This is a contained 3-line addition to the existing struct, not a new shape mechanism — do not build this speculatively; only add if on-device UAT during D-08 tuning shows a visible pop.

---

## Shared Patterns

### Single-source-of-truth static constant (this codebase's established convention)
**Source:** `NotchPillView.swift` lines 107-152 (`collapsedSize`, `expandedSize`, `wingsSize`, `toastExtraHeight`, `shelfRowHeight` — all `static let`, all referenced via `Self.` at every call site) and `NotchWindowController.swift` lines 264-265 (`springResponse`/`springDamping`, same pattern for animation constants).
**Apply to:** The new `islandMaterial` gradient — define it once as a `static let` following the exact same convention (comment block explaining rationale, `Self.` access at every fill site), rather than inlining the `LinearGradient(...)` literal 4 times.

### View drives no animation itself (D-08, established since Phase 1)
**Source:** `NotchPillView.swift` file header comment (lines 11-15) — "This is the VIEW LAYER only. It drives NO animation itself... Plan 03's controller wraps the state mutation in a spring animation."
**Apply to:** The gradient fill itself needs no animation wrapper in the view (SwiftUI already animates shape/frame changes per-frame via the controller's spring); only `NotchWindowController`'s constants change for VISUAL-02. Do not add any `.animation()` modifier to the new gradient — it would violate this established boundary.

### Relative UnitPoint gradient stops (RESEARCH.md Pattern 1, first-time-introduced this phase)
**Source:** Not yet in the codebase (first gradient in the app) — apply Apple's documented `LinearGradient`/`ShapeStyle` `UnitPoint`-relative-to-bounding-box behavior.
**Apply to:** All 4 fill sites — use `.top`/`.bottom` (relative), never absolute pixel `UnitPoint(x:y:)` values, so ONE shared gradient definition reads correctly at collapsed (38pt), wings (32pt), and expanded (144pt) heights with zero per-shape special-casing.

## No Analog Found

None. All 3 files are pre-existing, already-read-in-full, and this phase's entire scope (per CONTEXT.md/RESEARCH.md/UI-SPEC.md, unanimous) is confirmed to be a values-and-fill-style change with zero new files, zero new types, and zero new architectural patterns. RESEARCH.md's own "Don't Hand-Roll" table explicitly rules out any custom `Shape`/`CAGradientLayer`/`Animatable`-keyframe alternative — the two first-party APIs (`LinearGradient` as `ShapeStyle`, `Animation.spring`) are drop-in replacements for the existing `Color.black`/constant values.

## Metadata

**Analog search scope:** `Islet/Notch/` (3 files: `NotchPillView.swift`, `NotchShape.swift`, `NotchWindowController.swift`) — scope fully bounded by CONTEXT.md's "Existing Code this phase modifies" section; no broader codebase search was warranted since this phase touches zero new files.
**Files scanned:** 3 (all read in full or via targeted grep+offset reads; `NotchWindowController.swift` is 1378 lines — grepped for `springResponse`/`springDamping`/`withAnimation` call sites first, then targeted `Read` at lines 250-289 and 510-539, all other call sites confirmed present via grep line numbers without needing separate reads since they are byte-identical to the shown pattern).
**Pattern extraction date:** 2026-07-11
