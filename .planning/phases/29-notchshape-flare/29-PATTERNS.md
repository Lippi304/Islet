# Phase 29: NotchShape Flare - Pattern Map

**Mapped:** 2026-07-13
**Files analyzed:** 2 (both modified in place, no new files)
**Analogs found:** 2 / 2 — both analogs are sibling code in the SAME files being modified (this phase adds one parameter to an existing, already-established pattern rather than introducing a new one)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|--------------------|------|-----------|-----------------|---------------|
| `Islet/Notch/NotchShape.swift` | component (SwiftUI `Shape`) | transform (pure geometry → `Path`) | itself — existing `topCornerRadius`/`bottomCornerRadius` properties, same file | exact (self-pattern) |
| `Islet/Notch/NotchPillView.swift` — `blobShape()` (~line 1074) | component (SwiftUI view builder helper) | transform (params → rendered shape) | `wingsShape()` in same file (~line 1173) — identical `NotchShape(...)` construction pattern | exact (self-pattern) |
| `Islet/Notch/NotchPillView.swift` — `wingsShape()` (~line 1173) | component (SwiftUI view builder helper) | transform (params → rendered shape) | `blobShape()` in same file (~line 1074) | exact (self-pattern) |

No files are created. No controller/service/model/middleware files are touched — this phase is scoped to a `Shape` struct and two of its call sites, confirmed by both CONTEXT.md and UI-SPEC.md ("pure rendering-value change... zero new UI text/colors/typography/spacing").

## Pattern Assignments

### `Islet/Notch/NotchShape.swift` (component, transform)

**Analog:** the file's own existing `topCornerRadius`/`bottomCornerRadius` stored properties and their use in `path(in:)` — this is a same-file, same-struct extension, not a cross-file pattern borrow.

**Current full struct** (lines 1-33, already read in full — small file, no re-read needed):
```swift
struct NotchShape: Shape {
    // Plain CGFloat stored properties → SwiftUI's Shape animation INTERPOLATES these
    // across the Phase-2 collapsed↔expanded morph (ISL-04).
    var topCornerRadius: CGFloat = 6
    var bottomCornerRadius: CGFloat = 14
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.minX + topCornerRadius, y: rect.minY + topCornerRadius),
                       control: CGPoint(x: rect.minX + topCornerRadius, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + topCornerRadius, y: rect.maxY - bottomCornerRadius))
        p.addQuadCurve(to: CGPoint(x: rect.minX + topCornerRadius + bottomCornerRadius, y: rect.maxY),
                       control: CGPoint(x: rect.minX + topCornerRadius, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - topCornerRadius - bottomCornerRadius, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - topCornerRadius, y: rect.maxY - bottomCornerRadius),
                       control: CGPoint(x: rect.maxX - topCornerRadius, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - topCornerRadius, y: rect.minY + topCornerRadius))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY),
                       control: CGPoint(x: rect.maxX - topCornerRadius, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        return p
    }
}
```

**Pattern to copy for `topFlareWidth`:**
- Add `var topFlareWidth: CGFloat = 0` as a third plain stored property, directly beneath `bottomCornerRadius` — same declaration style (no `private`, no `didSet`, no computed logic), so it participates in `Shape`'s default per-property interpolation exactly like the other two (UI-SPEC "Animation behavior" section — do NOT add `animatableData` pre-emptively; only the Watch Item triggers that).
- Path-math shape of the change: the top edge currently runs as a single top-left-corner quad-curve → straight top line (implicit, since `move`+first `addQuadCurve` already start the top-left corner) → top-right quad-curve, i.e. the top is flush between the two 6pt corners. To introduce the flare, the top-left and top-right quad-curves need to widen OUTWARD (beyond `rect.minX`/`rect.maxX`) by `topFlareWidth` before curving down into the existing `topCornerRadius` — e.g. the control/end points for the two top quad-curves shift their x-coordinate outward by `topFlareWidth`, and an additional curve segment is inserted to bring the edge back in to meet the existing `topCornerRadius` transition. Exact control-point placement is the executor's on-device-tuned geometry (D-02); the pattern constraint from this file is: **keep it a `Path` built from `move`/`addLine`/`addQuadCurve` calls only** — no new drawing primitives (no `addArc`, `addCurve`/cubic Bezier) since the rest of the shape uses quad-curves exclusively and mixing curve types would visually mismatch the corner language.
- Comment convention: this file uses doc-comments above the struct explaining WHY each property exists and its animation contract (see lines 3-13) — follow the same comment density for `topFlareWidth` (one short comment tying it to SHAPE-01 / D-05's "fixed absolute value" behavior), not a comment per line.

---

### `Islet/Notch/NotchPillView.swift` — `blobShape()` and `wingsShape()` (component, transform)

**Analog:** each function is the other's analog — both already share the identical `NotchShape(...) → .fill → .matchedGeometryEffect → .frame → .overlay → .onTapGesture` construction chain (confirmed in code_context D-04/Integration Points and directly in the read source).

**`blobShape()` current construction** (`NotchPillView.swift` lines 1074-1111, already in context):
```swift
private func blobShape<Content: View>(topCornerRadius: CGFloat,
                                       bottomCornerRadius: CGFloat,
                                       alignment: Alignment = .center,
                                       width: CGFloat? = nil,
                                       height: CGFloat? = nil,
                                       shelfItems: [ShelfItem],
                                       shelfVisible: Bool,
                                       showSwitcher: Bool = false,
                                       @ViewBuilder content: () -> Content) -> some View {
    ...
    return NotchShape(topCornerRadius: topCornerRadius, bottomCornerRadius: bottomCornerRadius)
        .fill(islandFill)
        .matchedGeometryEffect(id: "island", in: ns)
        .frame(width: baseWidth, height: totalHeight)
        .overlay(alignment: .top) { ... }
        .onTapGesture { onClick() }
}
```

**`wingsShape()` current construction** (`NotchPillView.swift` lines 1173-1185, already in context):
```swift
private func wingsShape<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    NotchShape(topCornerRadius: 6, bottomCornerRadius: 6)   // flatter than the downward blob
        .fill(islandFill)
        .matchedGeometryEffect(id: "island", in: ns)
        .frame(width: Self.wingsSize.width, height: Self.wingsSize.height)
        .overlay(
            content()
                .frame(width: Self.wingsSize.width, height: Self.wingsSize.height)
        )
        .onTapGesture { onClick() }
}
```

**Pattern to copy — both edits are one-line additions to the existing `NotchShape(...)` constructor call, no signature/structural change to either function:**
```swift
// blobShape(): line 1089
return NotchShape(topCornerRadius: topCornerRadius, bottomCornerRadius: bottomCornerRadius, topFlareWidth: 10)

// wingsShape(): line 1174
NotchShape(topCornerRadius: 6, bottomCornerRadius: 6, topFlareWidth: 10)   // flatter than the downward blob
```
Because `NotchShape` uses default-valued stored properties (memberwise init), passing `topFlareWidth: 10` as a third labeled argument requires no change to `NotchShape`'s init signature beyond adding the property itself. Everything else in both functions (fill, matchedGeometryEffect id, frame sizing, overlay, tap gesture) is explicitly UNCHANGED — do not touch those lines.

**Call sites that pass `topCornerRadius`/`bottomCornerRadius` into `blobShape()`** (per code_context, lines ~440, 474, 658, 724, 772, 1492, 1561) do NOT need edits themselves — the flare is injected once, inside `blobShape()`'s own body, not by its callers. Verify this remains true by grepping call sites during planning; none of them construct `NotchShape` directly.

---

## Excluded Sites — DO NOT MODIFY (verify zero-diff)

### `collapsedIsland` (`NotchPillView.swift` lines 409-423)
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
```
Calls plain `NotchShape()` — all three properties (`topCornerRadius`, `bottomCornerRadius`, new `topFlareWidth`) fall back to their defaults (`6`, `14`, `0`). Since `topFlareWidth` defaults to `0`, this call site is already correct as-is and must NOT be edited (Success Criterion #2 — pixel-identical collapsed pill, verify via `git diff` showing zero changes to this function).

### `mediaWingsOrToast(_:)` (`NotchPillView.swift` lines 1234-1253)
```swift
NotchShape(topCornerRadius: 6, bottomCornerRadius: toast != nil ? 16 : 6)
    .fill(islandFill)
    .matchedGeometryEffect(id: "island", in: ns)
    .frame(width: Self.wingsSize.width, height: height)
    .overlay(alignment: .top) { ... }
    .onTapGesture { onClick() }
```
Makes its own standalone inline `NotchShape(...)` call — NOT routed through `wingsShape()`. Per D-03/D-04, simply omit the `topFlareWidth` argument (defaults to `0`) — do not add it even at `0`. Verify zero-diff on this function too.

---

## Shared Patterns

### `NotchShape` construction across all sites
**Source:** `Islet/Notch/NotchShape.swift` (single struct, one canonical shape for every collapsed/expanded/wings state)
**Apply to:** `blobShape()`, `wingsShape()` only (per D-03/D-04 exclusion list above)
```swift
NotchShape(topCornerRadius: <value>, bottomCornerRadius: <value>, topFlareWidth: 10)
```
The memberwise-init + default-value pattern means every existing call site not touched by this phase (`collapsedIsland`, `mediaWingsOrToast`) continues to compile and render unchanged automatically — no cascading edits required elsewhere in the codebase. Confirmed via grep: only 4 `NotchShape(` construction sites exist in the entire codebase (lines 413, 1089, 1174, 1237 of `NotchPillView.swift`), all four accounted for above.

### `matchedGeometryEffect` morph contract
**Source:** all four `NotchShape(...)` call sites share `.matchedGeometryEffect(id: "island", in: ns)` immediately after `.fill(...)`
**Apply to:** no change needed — `topFlareWidth` being a plain `CGFloat` (not wrapped in `animatableData`) rides the same interpolation SwiftUI already performs for `topCornerRadius`/`bottomCornerRadius` across this shared id. This is the mechanism UI-SPEC's "Animation behavior" section is relying on — no additional code needed to satisfy Success Criterion #3 under the default expectation.

---

## Open Item Requiring Planner Attention (not a pattern, a scoping flag)

**Panel-frame reservation** — UI-SPEC's "Open geometry question" is confirmed live by direct inspection, not just theoretical:

- `Islet/Notch/NotchGeometry.swift` (`expandedNotchFrame`/`wingsFrame`, lines 68-83) sizes the window frame to exactly `expandedSize` (360×144, `NotchPillView.swift` line 194) / `wingsSize` (290×32, line 206) — no horizontal margin/padding is added for a shape that paints outside its own rect.
- `Islet/Notch/NotchWindowController.swift` (~lines 786-812) unions `expandedFrame`/`wings`/`onboardingFrame` into `panelFrame` and calls `panel.setFrame(panelFrame, display: true)` — the `NSPanel`'s content view is exactly this size. SwiftUI `Shape` drawing is clipped to its ancestor view's bounds by default (no `.clipped()` needed to cause clipping — the window's own `NSHostingView` bounds already act as the boundary), so a `topFlareWidth` of 10pt drawn beyond `rect.minX`/`rect.maxX` will likely be clipped by the panel edge unless the panel frame itself grows.
- **Scope this explicitly in the plan**: either (a) confirm on-device that existing `widthFudge`/frame padding already tolerates a 10pt bulge (check `notchSize`'s `widthFudge: CGFloat = 4` default in `NotchGeometry.swift` line 31 — likely insufficient alone for a symmetric 10pt-per-side flare), or (b) add a small horizontal inset to `panelFrame`'s width in `NotchWindowController.swift` sized to `topFlareWidth`. This is a `NotchWindowController`/`NotchGeometry` change, separate from the `NotchShape.swift`/`blobShape()`/`wingsShape()` edits above — the planner should create a distinct plan step for it if on-device testing shows clipping.

## No Analog Found

None — every file in scope has an exact in-file/sibling-function analog (see above). This phase is additive-parameter, not new-pattern, work.

## Metadata

**Analog search scope:** `Islet/Notch/NotchShape.swift`, `Islet/Notch/NotchPillView.swift`, `Islet/Notch/NotchGeometry.swift`, `Islet/Notch/NotchWindowController.swift`
**Files scanned:** 4 (2 modified, 2 read for the panel-frame scoping flag only — not modified by the core flare work)
**Pattern extraction date:** 2026-07-13
