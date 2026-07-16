# Phase 35: Liquid Glass Material - Pattern Map

**Mapped:** 2026-07-16
**Files analyzed:** 4 (1 new, 3 modified)
**Analogs found:** 3 / 4 (the new `.metal` shader file has no in-repo analog — first shader in the project)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|-----------------|---------------|
| `Islet/Notch/LiquidGlassShader.metal` (new) | utility (Metal shader) | transform (pixel-level distortion) | none in-repo | no analog — see below |
| `Islet/ActivitySettings.swift` (modify) | config/model (enum + AppStorage key) | CRUD (add enum case) | itself — `MaterialStyle` enum, `WeatherStyle` enum | exact (extend existing enum precedent) |
| `Islet/Notch/NotchPillView.swift` (modify) | component (SwiftUI shape/material) | transform (fill composition) | itself — `islandFill` / `gradientMaterial` / `solidBlackMaterial` | exact (extend existing switch) |
| `Islet/SettingsView.swift` (modify — picker + window background) | component (SwiftUI settings form + window chrome) | request-response (live-updating preference) | itself — `systemSection` Picker; `NavigationSplitView` body for background modifier | exact (picker) / role-match (window background, no existing analog for a window-level material modifier) |

## Pattern Assignments

### `Islet/ActivitySettings.swift` (config/model, CRUD — add `.liquidGlass` case)

**Analog:** the file's own `MaterialStyle` enum (this IS the seam to extend, not an external analog)

**Current enum + key** (`Islet/ActivitySettings.swift:43-46`):
```swift
enum MaterialStyle: String, CaseIterable {
    case gradient, solidBlack
}
static let materialStyleKey = "theming.materialStyle"
```

**Pattern to apply:** add a third case, add doc comment referencing D-05/D-06 (mirrors the existing `// Phase 27 / VISUAL-03:` comment convention immediately above), no other structural change — `CaseIterable` conformance means the Settings picker's `ForEach`-free manual `Picker` (see SettingsView pattern below) just needs a third `Text(...).tag(...)` line, nothing here auto-generates UI.

**Default-value change (D-06):** the type is read via `@AppStorage(...) var materialStyle: ActivitySettings.MaterialStyle = .gradient` in **two** places that both need the literal default flipped to `.liquidGlass`:
- `Islet/SettingsView.swift:48`
- `Islet/ActivitySettings.swift:109` (`IslandMaterialStyleKey.defaultValue`, `EnvironmentKey` used as the environment-plumbing fallback before the controller wires the real `@AppStorage` value — see `Islet/ActivitySettings.swift:108-110`)

**Environment plumbing** (`Islet/ActivitySettings.swift:108-129`) — `IslandMaterialStyleKey` / `.islandMaterialStyle` environment value needs no structural change, only its `defaultValue` updated per D-06; `NotchPillView` already reads it via `@Environment(\.islandMaterialStyle) private var materialStyle` (`NotchPillView.swift:137`).

---

### `Islet/Notch/NotchPillView.swift` (component, transform — extend `islandFill`, add shader modifier at the 4 fill sites)

**Analog:** the file's own `islandFill` computed property and its 4 existing call sites — this is the single seam ROADMAP Success Criterion #2 requires reusing, not a pattern borrowed from elsewhere.

**Imports** (`NotchPillView.swift:1-2`):
```swift
import SwiftUI
import AppKit   // Phase 33 / WEATHER-02 (D-08) — NSColor.blended(withFraction:of:) for temperatureColor
```
No new import needed for `.distortionEffect()` — it's a stock SwiftUI `Shape`/`View` modifier (`ShaderLibrary` access needs no extra import beyond SwiftUI on macOS 14+). If the shader is defined in a separate `.metal` file, no Swift-side `import Metal` is required either — SwiftUI resolves `ShaderLibrary.default.myShader(...)` against compiled `.metal` sources in the target automatically.

**Material base + branch pattern** (`NotchPillView.swift:242-268`):
```swift
private static let gradientMaterial = LinearGradient(
    stops: [
        .init(color: .black, location: 0.0),
        .init(color: .black, location: 0.65),
        .init(color: .black.opacity(0.5), location: 1.0),
    ],
    startPoint: .top,
    endPoint: .bottom
)
private static let solidBlackMaterial = Color.black
private var islandFill: AnyShapeStyle {
    switch materialStyle {
    case .gradient: return AnyShapeStyle(Self.gradientMaterial)
    case .solidBlack: return AnyShapeStyle(Self.solidBlackMaterial)
    }
}
```
**Pattern to apply:** D-02 requires `gradientMaterial`'s stops to stay the base fill for the new `.liquidGlass` case too — do NOT add a 4th unrelated `AnyShapeStyle`. Per the UI-SPEC render order (`35-UI-SPEC.md` "Render order: gradientMaterial fill → .distortionEffect() → frost overlay → foreground content"), the distortion/frost is a *modifier stack applied at the fill call sites*, not an alternate `ShapeStyle` value swapped into `islandFill`'s switch. Two structurally valid options consistent with Success Criterion #2 (no new sibling view):
1. Keep `islandFill` returning `AnyShapeStyle(Self.gradientMaterial)` for `.liquidGlass` too (same as `.gradient`), and add the `.distortionEffect()` + frost overlay as additional modifiers chained directly after `.fill(islandFill)` at each of the 4 sites, gated on `materialStyle == .liquidGlass`.
2. Factor a small `@ViewBuilder` helper (e.g. `private func islandFillLayer(shape: some Shape) -> some View`) that internally does `shape.fill(islandFill)` then conditionally chains the shader/frost, called from all 4 sites in place of the bare `.fill(islandFill)`.
Either satisfies "same shape node, no new sibling view" — planner's call per CONTEXT.md Claude's Discretion precedent (this file already uses that kind of shared-helper factoring, see `wingsShape(content:)` and `blobShape(...)` below).

**The 4 existing fill + matchedGeometryEffect call sites (exact copy targets):**
1. `collapsedIsland` — `NotchPillView.swift:582-593` (uses `collapsedFill`, which DEBUG-overrides to red, else falls through to `islandFill` — see `NotchPillView.swift:2057-2063`)
2. `blobShape<Content>` — `NotchPillView.swift:1531-1539` (expanded island)
3. `wingsShape<Content>` — `NotchPillView.swift:1666-1673` (charging/device wings)
4. `mediaWingsOrToast` — `NotchPillView.swift:1733-1740` (now-playing wings/toast)

All 4 share the identical fragment:
```swift
.fill(islandFill)
.matchedGeometryEffect(id: "island", in: ns)
.frame(width: ..., height: ...)
```
**Hard-won ordering rule already encoded at every site** (do not violate — this is the just-fixed regression from D-07's prerequisite bugfix, commit `1:40a "Island Expand Animation Regression Fixed"`): `.matchedGeometryEffect` MUST precede `.frame`. Any new shader modifier must be inserted either between `.fill(...)` and `.matchedGeometryEffect(...)`, or after `.frame(...)`, — never in a way that moves `.frame` ahead of `.matchedGeometryEffect`.

**Size-driven distortion strength (D-04):** `collapsedIsland` reads `interaction.collapsedNotchSize ?? Self.collapsedSize` (`NotchPillView.swift:581`) — the same source is available for a size-driven shader-parameter branch. Simpler alternative consistent with "Claude's Discretion": each of the 4 call sites already know statically whether they're the collapsed pill (site 1) vs. expanded/wings (sites 2-4), so a binary switch keyed on which call site it is (not a runtime size read) is the cheaper option and satisfies D-04's "visibly different intensity" requirement without new state plumbing.

**Corner radius source (`borderRadius` shader param, UI-SPEC hard constraint):** `NotchShape` (`Islet/Notch/NotchShape.swift:9-15`) exposes `topCornerRadius`/`bottomCornerRadius` as stored properties, already passed explicitly by 3 of the 4 call sites (`blobShape(topCornerRadius:bottomCornerRadius:...)`, `wingsShape` hardcodes `12`/`6`, `mediaWingsOrToast` hardcodes `6`/`toast != nil ? 16 : 6`). The shader must read the SAME values passed to `NotchShape(...)` at each site — never a hardcoded constant duplicated elsewhere.

**Silent-degradation error handling (Copywriting Contract: "if `.distortionEffect()` is unavailable at runtime, degrade silently to `gradientMaterial`"):** no explicit try/catch pattern exists for this in the codebase (SwiftUI shaders don't throw) — the established silent-degradation precedent to mirror is Weather/Calendar permission handling. Grep target for planner: `grep -n "denied\|authorizationStatus" Islet/**/*.swift` if a concrete code excerpt is needed; not required for this shader since `.distortionEffect()` has no runtime-unavailable failure mode on macOS 14+ (compile-time API, not a permission gate) — treat this UI-SPEC line as a defensive note, not a code path to build.

---

### `Islet/Notch/LiquidGlassShader.metal` (new — no in-repo analog)

**No analog found.** This is the first Metal shader / `.distortionEffect()` usage in the project (confirmed via `grep -rn "distortionEffect\|colorEffect\|layerEffect\|ShaderLibrary\|Metal"` across `Islet/` — zero matches, zero existing `.metal` files).

**Build integration (confirmed, not a pattern gap):** `project.yml` uses folder-based `sources:` globbing from `Islet/` (`project.yml:4, 44`) — a new `Islet/Notch/LiquidGlassShader.metal` file is picked up automatically on `xcodegen generate`, same as any new `.swift` file; no manual Xcode project surgery needed.

**Reference technique to port (from `reference-GlassSurface.md`, already read in full by planner per CONTEXT.md canonical_refs):**
- The `feImage` displacement map generation (SVG rect: black background, red/blue linear gradients per-axis, center brightness rect blurred) maps to a Metal `[[stitchable]]` function computing a synthetic per-pixel displacement value analytically (no image asset) — distance-from-edge based, using `borderWidth`/`brightness`/`blur` as tunable inputs, matching the props table at `reference-GlassSurface.md:271-280`.
- The 3 independently-offset `feDisplacementMap` R/G/B passes recombined via `feBlend screen` map to running the `.distortionEffect()` shader (or 3 stacked calls) with `distortionScale + redOffset/greenOffset/blueOffset` as per-channel scale inputs — see `reference-GlassSurface.md:119-131` for the exact scale-per-channel formula (`ref.current.setAttribute('scale', (distortionScale + offset).toString())`).
- Numeric starting points (already pre-scaled for Islet's dimensions, NOT the web 200-400pt defaults) are in `35-UI-SPEC.md` "Material / Shader Contract" table (`35-UI-SPEC.md:76-89`) — copy that table verbatim as the shader's initial parameter set, tune on-device per the UAT gate.

---

### `Islet/SettingsView.swift` (component, request-response — Theming picker + window background)

**Analog (picker):** `systemSection`'s existing `Style` Picker, `SettingsView.swift:252-260`
```swift
Section("Appearance Style") {
    Picker("Style", selection: $materialStyle) {
        Text("Gradient").tag(MaterialStyle.gradient)
        Text("Solid Black").tag(MaterialStyle.solidBlack)
    }
    .pickerStyle(.segmented)
}
```
**Pattern to apply:** add a third line `Text("Liquid Glass").tag(MaterialStyle.liquidGlass)` inside the same `Picker` — matches the Copywriting Contract's "plain two-word label, no icon, no subtitle" convention exactly. No other change to this Picker block; `@AppStorage` (`SettingsView.swift:48`) already round-trips any `MaterialStyle` case automatically (`RawRepresentable where RawValue == String` — `SettingsView.swift:45-47` comment confirms this is already relied on, "no manual Binding needed").

**Default value flip (D-06):** `SettingsView.swift:48`:
```swift
@AppStorage(ActivitySettings.materialStyleKey) private var materialStyle: ActivitySettings.MaterialStyle = .gradient
```
change trailing default to `.liquidGlass`.

**Analog (window background — D-08/D-09, calmer variant):** no exact in-repo analog exists (no prior "window background material" work) — closest structural reference is the `body`'s outer `NavigationSplitView { ... }.frame(...)` chain at `SettingsView.swift:80-138`, which is the correct attachment point: a `.background(...)` modifier chained onto the `NavigationSplitView` (or a `.background` on the whole `body` before `.frame`), NOT a new wrapper view (mirrors the "same node, no new sibling" spirit of the island-shell constraint, even though Success Criterion #2 technically only names the island shell).

**Concrete pattern to build (per UI-SPEC "Settings window background" table, `35-UI-SPEC.md:98-108`):**
```swift
.background(
    ZStack {
        LinearGradient(  // same direction as Self.gradientMaterial in NotchPillView, calmer alpha curve
            stops: [ /* lighter/lower-opacity stops than NotchPillView's gradientMaterial */ ],
            startPoint: .top, endPoint: .bottom
        )
        Color.clear.background(.ultraThinMaterial)  // frost, no .distortionEffect()
        RoundedRectangle(cornerRadius: /* window corner radius, if any */)
            .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)  // rim-light per D-09
    }
)
```
No distortion shader reference here — D-09 explicitly excludes `.distortionEffect()` from this surface.

## Shared Patterns

### `islandFill` single-seam material switch
**Source:** `Islet/Notch/NotchPillView.swift:263-268`
**Apply to:** all 4 island-shell fill call sites — the ONE place that must learn about `.liquidGlass`; do not duplicate the switch logic at each call site.

### matchedGeometryEffect-before-frame ordering
**Source:** every one of the 4 fill sites (`NotchPillView.swift:582-593`, `1531-1539`, `1666-1673`, `1733-1740`), each carrying an explicit "Bugfix (island-expand-diagonal-bounce...)" comment
**Apply to:** any new modifier inserted into these chains — inserting a shader/frost modifier must not reorder `.matchedGeometryEffect` after `.frame`, or the just-fixed D-07 prerequisite regression returns.

### AppStorage-is-source-of-truth + fully-qualified default annotation
**Source:** `SettingsView.swift:43-51` comment block ("SwiftUI's native `@AppStorage` overload for any `RawRepresentable where RawValue == String`...")
**Apply to:** no new `@AppStorage` property is needed for this phase (reuses `materialStyleKey`), but the default-value literal change at both declaration sites (`SettingsView.swift:48`, `ActivitySettings.swift:109`) must stay in sync — this project has no single-source default constant, both sites are independently hardcoded today (existing pattern, not introduced by this phase).

### Silent degradation on unsupported/failed state
**Source:** established project convention (Weather/Calendar permission denial, referenced in UI-SPEC Copywriting Contract) — no single canonical code excerpt in this phase's touched files; grep `Islet/Weather*.swift` or `Islet/Calendar*.swift` if planner wants a concrete precedent excerpt.
**Apply to:** N/A for the shader itself (no runtime failure mode) — only relevant if planner decides a defensive `#available`-style guard is worth adding around `.distortionEffect()` despite the macOS 14+ floor already covering it.

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `Islet/Notch/LiquidGlassShader.metal` | utility (Metal shader) | transform | First shader in the project — zero prior `.metal`/`ShaderLibrary`/`.distortionEffect()` usage anywhere in `Islet/`. Port directly from `reference-GlassSurface.md`'s SVG filter graph per the porting notes already captured there (no additional codebase search will surface a closer match). |
| Settings window background material | component (window chrome) | transform | No prior "window-level background material" work exists (`SettingsView.swift`'s `NavigationSplitView` has never carried a `.background` modifier) — closest available reference is `NotchPillView`'s `gradientMaterial` constant, ported at reduced/calmer strength per D-09, not copied from an existing Settings-window pattern. |

## Metadata

**Analog search scope:** `Islet/Notch/NotchPillView.swift`, `Islet/ActivitySettings.swift`, `Islet/SettingsView.swift`, `Islet/Notch/NotchShape.swift`, `Islet/IsletApp.swift`, `project.yml`; grep sweep of all `Islet/**/*.swift` for shader/Metal keywords (zero hits).
**Files scanned:** 6 read directly (2 fully, 4 targeted-range), plus a project-wide grep sweep.
**Pattern extraction date:** 2026-07-16
