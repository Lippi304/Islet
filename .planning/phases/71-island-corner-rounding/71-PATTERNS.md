# Phase 71: Island Corner Rounding - Pattern Map

**Mapped:** 2026-07-30
**Files analyzed:** 3 modified files (no new files — this phase is pure edits to existing files)
**Analogs found:** 3 / 3 (each file's analog is itself — this is a mechanical extension of an existing in-file pattern, not a new-file-vs-existing-file mapping)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|--------------------|------|-----------|-----------------|----------------|
| `Islet/Notch/NotchPillView.swift` (`wingsShape()` call site, ~line 3041) | component (SwiftUI View helper, shape instantiation) | transform (pure geometry constant edit) | Itself — `blobShape()`'s own `NotchShape(topCornerRadius: 24, bottomCornerRadius: 32)` call site and `collapsedIsland`'s default-radii call site, same file | exact (same function family, same `NotchShape` constructor, only literals differ) |
| `Islet/Notch/NotchPillView.swift` (new `wingCornerRadiusNudge` computed property + `@AppStorage` decl, ~lines 181-218) | store / provider (persisted UI-tuning state) | request-response (read-triggered by SwiftUI body re-render) | `wingMarginNudge` / `wingGapNudge` (same file, lines 205-218) | exact — 5th instance of an already-4x-replicated pattern |
| `Islet/ActivitySettings.swift` (new `debugWingCornerRadiusNudgeKey`, ~lines 109-117) | config (persistence key constant) | CRUD (key definition, no logic) | `debugWingMarginNudgeKey` / `debugWingGapNudgeKey` (same file, lines 113-116) | exact |
| `Islet/AppDelegate.swift` (new menu items + `@objc` actions + Reset/Print updates, ~lines 522-537, 598-625) | controller (AppKit menu action wiring) | event-driven (NSMenuItem action → UserDefaults mutation) | Margin axis's own menu items/actions (same file, lines 527-532, 602-607, 613, 622-624) | exact — Margin is explicitly the multi-tier template D-05 says to mirror |
| `IsletTests/NotchShapeTests.swift` (new radius/path validity tests) | test | request-response (pure function assertions) | `testLargerTopCornerRadiusProducesAClosedNonEmptyPath` (same file, lines 47-53) | exact |
| `IsletTests/ActivitySettingsTests.swift` (new key-name test) | test | CRUD (literal-string assertion) | `testNewV110KeyNames` (same file, lines 121-129) | exact |

No files are created in this phase — every touch point is an edit inside an existing file, following an existing in-file convention 4-5x over already. There is no cross-codebase analog search needed beyond "the sibling axis two lines up."

## Pattern Assignments

### `Islet/Notch/NotchPillView.swift` — `wingsShape()` call site (SHAPE-02)

**Analog:** the same function, current code (`NotchPillView.swift:3034-3041`)

**Current core pattern** (lines 3034-3041):
```swift
private func wingsShape<Content: View>(
    leftWidth: CGFloat = Self.wingsSize.width / 2,
    rightWidth: CGFloat = Self.wingsSize.width / 2,
    depthScale: CGFloat = 1.0,
    onTap: (() -> Void)? = nil,
    @ViewBuilder content: () -> Content
) -> some View {
    let shape = NotchShape(topCornerRadius: 12, bottomCornerRadius: 6)   // flatter than the downward blob; smaller radius than blobShape's 24 — wings' 32pt-tall strip can't fit a 24pt top radius alongside a 6pt bottom radius without squeezing the wall to almost nothing
    let size = CGSize(width: leftWidth + rightWidth, height: Self.wingsSize.height * depthScale)
    return shape
        .fill(islandFill)
        .matchedGeometryEffect(id: "island", in: ns)
        .frame(width: size.width, height: size.height)
        ...
```

**Required edit:** replace the literal `NotchShape(topCornerRadius: 12, bottomCornerRadius: 6)` with `NotchShape(topCornerRadius: BASE_TOP + wingCornerRadiusNudge, bottomCornerRadius: BASE_BOTTOM + wingCornerRadiusNudge)`, where `BASE_TOP`/`BASE_BOTTOM` are the planner/executor-chosen starting values (D-02, e.g. the research's suggested 16/10 starting point — not locked). Everything downstream of `shape` (`.fill`, `matchedGeometryEffect`, `liquidGlassEffectLayer`) reads `shape.topCornerRadius`/`shape.bottomCornerRadius` generically — zero other code in this function changes.

**Sibling analogs for radius-literal conventions** (do NOT touch, reference only):
- `blobShape()` — `NotchShape(topCornerRadius: 24, bottomCornerRadius: 32)` (idle/expanded, out of scope per D-01 domain)
- `collapsedIsland` — default `NotchShape()` radii (6/14 from `NotchShape.swift`), out of scope per SC#2

**Depth-scale interaction (Pitfall 1 — must respect):** `size` at line 3042 multiplies height by `depthScale`, but the radii passed to `NotchShape` are NOT multiplied by `depthScale`. `resolvedWingDepthScale` (line 2905) clamps to `0.8...1.5`; worst case rendered height is `32 * 0.8 = 25.6pt`. `NotchShape.path(in:)` requires `topCornerRadius + bottomCornerRadius <= rect.height` (see `NotchShape.swift` pattern below) — new BASE_TOP + BASE_BOTTOM + max nudge must stay well under 25.6, not just under the nominal 32.

---

### `Islet/Notch/NotchPillView.swift` — `mediaWingsOrToast()` / `resumePreviewWings()` (D-06, in scope per CONTEXT.md)

**Analog:** the same two functions, current code

**`mediaWingsOrToast()` current literal** (line 3215):
```swift
let shape = NotchShape(topCornerRadius: 6, bottomCornerRadius: toast != nil ? 16 : 6)
```
Full function context (lines 3205-3247) — `shape` feeds `.fill`, `matchedGeometryEffect`, `liquidGlassEffectLayer` exactly like `wingsShape()`. This function does NOT call `wingsShape()` and has its own independent `NotchShape` instantiation, confirmed by direct read.

**`resumePreviewWings()` current literal** (line 3281):
```swift
private func resumePreviewWings(_ track: LastPlayedTrack) -> some View {
    let shape = NotchShape(topCornerRadius: 6, bottomCornerRadius: 6)
    return shape
        .fill(islandFill)
        .matchedGeometryEffect(id: "island", in: ns)
        .frame(width: Self.wingsSize.width, height: Self.wingsSize.height)
        .overlay(liquidGlassEffectLayer(shape: shape, size: Self.wingsSize, parameters: .expanded))
        ...
```

**Required edit per D-06:** bump both call sites' literals to the same `BASE_TOP`/`BASE_BOTTOM` baked-in values chosen for `wingsShape()` (NOT the `@AppStorage` nudge variable — D-06 says these two track the same baked-in numbers, no separate DEBUG tuner axis). `mediaWingsOrToast`'s toast-active bottom radius (`toast != nil ? 16 : 6`) needs a decision on whether the toast variant also shifts, or only the base `6`/`6` non-toast pair — planner's call, not specified by CONTEXT.md.

---

### `Islet/Notch/NotchPillView.swift` — new `wingCornerRadiusNudge` (SHAPE-03)

**Analog:** `wingMarginNudge` (lines 205-211) and the full nudge-property block (lines 181-218)

**Storage declaration pattern** (lines 181-186):
```swift
#if DEBUG
@AppStorage(ActivitySettings.debugWingLeadingNudgeKey) private var debugWingLeadingNudge: Double = 0
@AppStorage(ActivitySettings.debugWingTrailingNudgeKey) private var debugWingTrailingNudge: Double = 0
@AppStorage(ActivitySettings.debugWingMarginNudgeKey) private var debugWingMarginNudge: Double = 0
@AppStorage(ActivitySettings.debugWingGapNudgeKey) private var debugWingGapNudge: Double = 0
#endif
```
Add a 5th line: `@AppStorage(ActivitySettings.debugWingCornerRadiusNudgeKey) private var debugWingCornerRadiusNudge: Double = 0`

**Always-compiled read-point pattern** (lines 188-211, `wingMarginNudge` shown as the exact template):
```swift
// Always-compiled read points so every wing function can call these unconditionally.
// Release branch always returns 0 -> `+ wingLeadingNudge` etc. is a no-op `+ 0` literal
// in Release builds, zero behavior change.
private var wingMarginNudge: CGFloat {
    #if DEBUG
    return CGFloat(debugWingMarginNudge)
    #else
    return 0
    #endif
}
```
Add a matching `private var wingCornerRadiusNudge: CGFloat { #if DEBUG return CGFloat(debugWingCornerRadiusNudge) #else return 0 #endif }` block near line 218.

---

### `Islet/ActivitySettings.swift` — new `debugWingCornerRadiusNudgeKey` (SHAPE-03)

**Analog:** `debugWingMarginNudgeKey` / `debugWingGapNudgeKey` (lines 113-116)

**Current pattern** (lines 109-117):
```swift
// Quick task 260728-wg7 — DEBUG-only "Wing Tuner" live-nudge keys for the collapsed-state
// HUD wings. Dev-tool keys only, never Release-facing — gated so they cannot appear in a
// Release `defaults` dump.
#if DEBUG
static let debugWingLeadingNudgeKey = "debug.wingTuner.leadingNudge"
static let debugWingTrailingNudgeKey = "debug.wingTuner.trailingNudge"
static let debugWingMarginNudgeKey = "debug.wingTuner.marginNudge"
static let debugWingGapNudgeKey = "debug.wingTuner.gapNudge"
#endif
```
Add: `static let debugWingCornerRadiusNudgeKey = "debug.wingTuner.cornerRadiusNudge"` inside the same `#if DEBUG` block, same naming convention (`debug.wingTuner.<axis>Nudge`).

---

### `Islet/AppDelegate.swift` — new menu items + `@objc` actions (SHAPE-03)

**Analog:** Margin axis (the explicit multi-tier template per D-05) — lines 527-532 (menu items), 602-607 (actions), 613/622-624 (Reset/Print)

**Menu construction pattern** (lines 522-538, Margin's 6-button multi-tier shown as template):
```swift
let wingTunerMenu = NSMenu()
wingTunerMenu.addItem(withTitle: "Leading -2", action: #selector(debugWingLeadingMinus), keyEquivalent: "")
wingTunerMenu.addItem(withTitle: "Leading +2", action: #selector(debugWingLeadingPlus), keyEquivalent: "")
wingTunerMenu.addItem(withTitle: "Trailing -2", action: #selector(debugWingTrailingMinus), keyEquivalent: "")
wingTunerMenu.addItem(withTitle: "Trailing +2", action: #selector(debugWingTrailingPlus), keyEquivalent: "")
wingTunerMenu.addItem(withTitle: "Margin -20", action: #selector(debugWingMarginMinus20), keyEquivalent: "")
wingTunerMenu.addItem(withTitle: "Margin -10", action: #selector(debugWingMarginMinus10), keyEquivalent: "")
wingTunerMenu.addItem(withTitle: "Margin -5", action: #selector(debugWingMarginMinus), keyEquivalent: "")
wingTunerMenu.addItem(withTitle: "Margin +5", action: #selector(debugWingMarginPlus), keyEquivalent: "")
wingTunerMenu.addItem(withTitle: "Margin +10", action: #selector(debugWingMarginPlus10), keyEquivalent: "")
wingTunerMenu.addItem(withTitle: "Margin +20", action: #selector(debugWingMarginPlus20), keyEquivalent: "")
wingTunerMenu.addItem(withTitle: "Gap -1", action: #selector(debugWingGapMinus), keyEquivalent: "")
wingTunerMenu.addItem(withTitle: "Gap +1", action: #selector(debugWingGapPlus), keyEquivalent: "")
wingTunerMenu.addItem(.separator())
wingTunerMenu.addItem(withTitle: "Reset Wing Tuner", action: #selector(debugWingTunerReset), keyEquivalent: "")
wingTunerMenu.addItem(withTitle: "Print Wing Tuner Values", action: #selector(debugWingTunerPrint), keyEquivalent: "")
for item in wingTunerMenu.items { item.target = self }
```
Insert 4 new items (per D-05: ±1/±5 only, no ±10/±20 — small usable range) before the `.separator()` line: `Corner Radius -5`, `Corner Radius -1`, `Corner Radius +1`, `Corner Radius +5`.

**Shared adjust helper + action pattern** (lines 593-609, one-line-body style):
```swift
private func adjustWingNudge(_ key: String, by delta: Double) {
    let current = UserDefaults.standard.double(forKey: key)
    UserDefaults.standard.set(current + delta, forKey: key)
}

@objc private func debugWingMarginMinus20() { adjustWingNudge(ActivitySettings.debugWingMarginNudgeKey, by: -20) }
@objc private func debugWingMarginMinus10() { adjustWingNudge(ActivitySettings.debugWingMarginNudgeKey, by: -10) }
@objc private func debugWingMarginMinus() { adjustWingNudge(ActivitySettings.debugWingMarginNudgeKey, by: -5) }
@objc private func debugWingMarginPlus() { adjustWingNudge(ActivitySettings.debugWingMarginNudgeKey, by: 5) }
```
Add 4 new one-liners reusing the existing `adjustWingNudge` helper (no new helper needed):
```swift
@objc private func debugWingCornerRadiusMinus5() { adjustWingNudge(ActivitySettings.debugWingCornerRadiusNudgeKey, by: -5) }
@objc private func debugWingCornerRadiusMinus1() { adjustWingNudge(ActivitySettings.debugWingCornerRadiusNudgeKey, by: -1) }
@objc private func debugWingCornerRadiusPlus1() { adjustWingNudge(ActivitySettings.debugWingCornerRadiusNudgeKey, by: 1) }
@objc private func debugWingCornerRadiusPlus5() { adjustWingNudge(ActivitySettings.debugWingCornerRadiusNudgeKey, by: 5) }
```

**Reset/Print pattern (Pitfall 3 — must update, easy to forget)** (lines 611-625):
```swift
@MainActor @objc private func debugWingTunerReset() {
    UserDefaults.standard.set(0.0, forKey: ActivitySettings.debugWingLeadingNudgeKey)
    UserDefaults.standard.set(0.0, forKey: ActivitySettings.debugWingTrailingNudgeKey)
    UserDefaults.standard.set(0.0, forKey: ActivitySettings.debugWingMarginNudgeKey)
    UserDefaults.standard.set(0.0, forKey: ActivitySettings.debugWingGapNudgeKey)
    notchController?.debugClearAllPreviews()
}

@objc private func debugWingTunerPrint() {
    let leading = UserDefaults.standard.double(forKey: ActivitySettings.debugWingLeadingNudgeKey)
    let trailing = UserDefaults.standard.double(forKey: ActivitySettings.debugWingTrailingNudgeKey)
    let margin = UserDefaults.standard.double(forKey: ActivitySettings.debugWingMarginNudgeKey)
    let gap = UserDefaults.standard.double(forKey: ActivitySettings.debugWingGapNudgeKey)
    print("[WingTuner] leadingNudge=\(leading) trailingNudge=\(trailing) marginNudge=\(margin) gapNudge=\(gap) — ...")
}
```
Both functions hardcode exactly 4 keys today — add a 5th `UserDefaults.standard.set(0.0, forKey: ActivitySettings.debugWingCornerRadiusNudgeKey)` line to Reset, and a 5th `let cornerRadius = ...` + append `cornerRadiusNudge=\(cornerRadius)` to Print's interpolated string. This is a distinct checklist item, not implied by "add the menu items."

---

### `IsletTests/NotchShapeTests.swift` — new radius/path-validity tests (SHAPE-02 regression guard)

**Analog:** `testLargerTopCornerRadiusProducesAClosedNonEmptyPath` (lines 47-53), `testCustomRadiiProduceAClosedNonEmptyPath` (lines 31-39)

**Pattern to extend** (verbatim structure):
```swift
func testLargerTopCornerRadiusProducesAClosedNonEmptyPath() {
    let path = NotchShape(topCornerRadius: 24, bottomCornerRadius: 32).path(in: CGRect(x: 0, y: 0, width: 360, height: 144))
    let cgBounds = path.cgPath.boundingBox
    XCTAssertFalse(path.cgPath.isEmpty, "Larger-radius pill path must be non-empty.")
    XCTAssertGreaterThan(cgBounds.width, 0, "The closed path needs a positive-width bounding box.")
    XCTAssertGreaterThan(cgBounds.height, 0, "The closed path needs a positive-height bounding box.")
}
```
Add two new tests following this exact shape: (1) new base radii at the nominal wings rect `CGRect(x:0,y:0,width:290,height:32)`, (2) same radii at the depth-scale-floor rect `CGRect(x:0,y:0,width:290,height:25.6)` (Pitfall 1's regression guard — `topCornerRadius + bottomCornerRadius <= height` must hold at the floor, not just nominal).

---

### `IsletTests/ActivitySettingsTests.swift` — new key-name test (SHAPE-03)

**Analog:** `testNewV110KeyNames` (lines 121-129), `testSwitcherKeyNames` (lines 111-117) — literal-string key assertions

**Pattern to extend** (verbatim structure):
```swift
func testNewV110KeyNames() {
    XCTAssertEqual(ActivitySettings.capsLockKey, "activity.capsLock")
    XCTAssertEqual(ActivitySettings.downloadProgressKey, "activity.downloadProgress")
    ...
}
```
Add: `func testWingCornerRadiusNudgeKeyName() { XCTAssertEqual(ActivitySettings.debugWingCornerRadiusNudgeKey, "debug.wingTuner.cornerRadiusNudge") }` — note this key is `#if DEBUG`-gated in `ActivitySettings.swift`, and this test file itself has no visible `#if DEBUG` guard around other tests, but since `IsletTests` runs against a DEBUG-configured test target this compiles fine (consistent with the existing 4-axis keys having no test coverage today — this is a net-new test, not a modification of an existing one).

---

## Shared Patterns

### The Wing Tuner 3-file wiring (single cross-cutting pattern for all of SHAPE-03)
**Source:** `Islet/ActivitySettings.swift:109-117` → `Islet/Notch/NotchPillView.swift:181-218` → `Islet/AppDelegate.swift:499-541, 590-625`
**Apply to:** the one new Corner Radius axis, mechanically — key constant → `@AppStorage` + computed read point → menu items + `@objc` actions + Reset/Print. No new mechanism; this is a straight 5th-axis extension of an already-4x-replicated pattern.

### `NotchShape`'s generic radius consumption (no changes needed here)
**Source:** `Islet/Notch/NotchShape.swift` (full file, 33 lines)
```swift
struct NotchShape: Shape {
    var topCornerRadius: CGFloat = 6
    var bottomCornerRadius: CGFloat = 14
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.minX + topCornerRadius, y: rect.minY + topCornerRadius),
                       control: CGPoint(x: rect.minX + topCornerRadius, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + topCornerRadius, y: rect.maxY - bottomCornerRadius))
        ... (symmetric quad-curve/line construction for all 4 corners)
    }
}
```
**Apply to:** confirms zero shape-code changes are needed for SHAPE-02 — only the literal values passed at each call site change. The critical invariant every new literal/nudge combination must satisfy: `topCornerRadius + bottomCornerRadius <= rect.height` at the smallest rect this shape is ever asked to fill (25.6pt for wings at depth-scale floor 0.8×, not the nominal 32pt) — else the path's `addLine` between the two quad-curve corners inverts and self-intersects.

### Error handling / validation
Not applicable — this phase has no error paths, no user input parsing, no async/await, no throwing functions. The DEBUG menu buttons are fixed `NSMenuItem`s with hardcoded deltas (no free-text entry), and `UserDefaults.standard.double(forKey:)` never throws (returns `0.0` for a missing/wrong-type key, matching the existing 4 axes' own lack of explicit validation — this project's established convention is "no clamp, trust the dev using the dev tool").

## No Analog Found

None. Every touched file/location has a directly adjacent, currently-working analog in the same file (the other 4 Wing Tuner axes, the other `NotchShape` call sites, the other key-name/path tests) — this phase requires zero new architectural patterns.

## Metadata

**Analog search scope:** `Islet/Notch/NotchPillView.swift`, `Islet/Notch/NotchShape.swift`, `Islet/ActivitySettings.swift`, `Islet/AppDelegate.swift`, `IsletTests/NotchShapeTests.swift`, `IsletTests/ActivitySettingsTests.swift` (all 6 files directly named in CONTEXT.md's `canonical_refs` and RESEARCH.md's Sources)
**Files scanned:** 6 (all read in full or via targeted non-overlapping line-range reads; `NotchPillView.swift` at 5383 lines was read only at its 5 relevant ranges — 181-218, 3034-3091, 3205-3247, 3269-3308 — not in full)
**Pattern extraction date:** 2026-07-30
