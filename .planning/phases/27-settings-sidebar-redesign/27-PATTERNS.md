# Phase 27: Settings Sidebar Redesign - Pattern Map

**Mapped:** 2026-07-12
**Files analyzed:** 5 (4 modified, 1 new; optional 4-way split of SettingsView.swift noted but not counted separately)
**Analogs found:** 5 / 5 (all analogs are the SAME files pre-change — this phase extends existing in-file pipelines, it does not introduce a new architectural pattern from elsewhere in the codebase)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|-----------------|---------------|
| `Islet/SettingsView.swift` | component (SwiftUI View, preferences form) | CRUD (`@AppStorage` read/write) + request-response (License activation callback) | itself, pre-change (`Islet/SettingsView.swift` current `TabView` body) | exact — same file, restructured `TabView`→`NavigationSplitView`, all sub-patterns (License switch, hoisted `@State`, swatch picker) reused verbatim |
| `Islet/ActivitySettings.swift` | config / model (shared `@AppStorage` key namespace + `EnvironmentKey`s) | CRUD | itself, pre-change (`Islet/ActivitySettings.swift` current `accentIndexKey`/`ActivityAccentKey`) | exact — new keys/enum/env-keys follow the identical declaration idiom already in the file |
| `Islet/Notch/NotchPillView.swift` (4 fill sites: `collapsedFill`, `blobShape`, `wingsShape`, `mediaWingsOrToast`; 3 accent-read sites: `wings(for:)`, `mediaWingsRow`, `deviceWings(for:)`) | component (SwiftUI render) | transform (persisted pref → `ShapeStyle`/`Color` branch) | itself, pre-change (Phase 25's single `islandMaterial` constant + Phase 6's single `activityAccent` `@Environment`) | exact — same 4+3 call sites, extended from 1-branch to 2-branch (material) and from 1-key to 3-key (accent) |
| `Islet/Notch/NotchWindowController.swift` (`makeRootView`, `applyAccentIfChanged`, `appliedAccentIndex`, panel-creation read at line ~787) | controller (AppKit/SwiftUI bridge) | event-driven (`UserDefaults.didChangeNotification` → re-host) | itself, pre-change (existing D-11 accent re-host pipeline) | exact — same observer → compare-cached → re-host mechanism, extended to cover material style + 3 accents instead of 1 |
| `IsletTests/ActivitySettingsTests.swift` (new) | test | unit (pure logic, no I/O) | `IsletTests/LicenseStateTests.swift` | role-match — closest existing precedent for a pure-logic XCTest with no real UserDefaults/Keychain I/O; no `ActivitySettingsTests.swift` or any `ActivitySettings`-referencing test exists today (confirmed via grep) |

## Pattern Assignments

### `Islet/SettingsView.swift` (component, CRUD + request-response)

**Analog:** itself, current version (`Islet/SettingsView.swift` lines 1-262)

**Current structure to preserve verbatim (relocate, do not rewrite):**
- License adaptive `switch` block — lines 48-65 (trial/trialExpired/licensed) → moves into new About/License section unchanged.
- `buyNowButton` / `licenseEntry` / `statusLine` / `activate()` / `saveDiagnosticReport()` / `versionString` — lines 164-262, all private helpers, unchanged, just referenced from whichever new section view needs them.
- Swatch-circle picker (D-07's reuse target, called 3x in Theming) — lines 107-119:
```swift
LabeledContent("Accent") {
    HStack(spacing: 10) {
        ForEach(ActivitySettings.palette.indices, id: \.self) { i in
            Circle()
                .fill(ActivitySettings.palette[i])
                .frame(width: 22, height: 22)
                .overlay(
                    Circle().strokeBorder(.primary, lineWidth: accentIndex == i ? 2 : 0)
                )
                .onTapGesture { accentIndex = i }
        }
    }
}
```
UI-SPEC.md's `swatchRow(selection:)` helper (§System/Theming) is this exact block factored into a reusable private function taking a `Binding<Int>`, called 3x — do not build a second picker.

**`@AppStorage` declaration idiom** (lines 28-38, extend with new keys the same way):
```swift
@AppStorage(ActivitySettings.chargingKey)   private var chargingEnabled = true
@AppStorage(ActivitySettings.nowPlayingKey) private var nowPlayingEnabled = true
@AppStorage(ActivitySettings.accentIndexKey) private var accentIndex = ActivitySettings.defaultAccentIndex
```

**Hoisted-state + refresh-on-refocus pattern (Pitfall 1 — MUST survive the restructure):**
```swift
// lines 5-13
@State private var launchAtLogin = LaunchAtLogin.isEnabled
@Environment(\.appearsActive) private var appearsActive
@State private var licenseStatus = LicenseState.shared.status
...
// lines 148-157
.onAppear {
    launchAtLogin = LaunchAtLogin.isEnabled
    licenseStatus = LicenseState.shared.status
}
.onChange(of: appearsActive) { _, active in
    if active {
        launchAtLogin = LaunchAtLogin.isEnabled
        licenseStatus = LicenseState.shared.status
    }
}
```
Keep `launchAtLogin`/`licenseStatus` declared on the top-level `SettingsView`, pass down as params/bindings to whichever section subview is selected — never re-declare inside a per-section `switch` case (this is the load-bearing fix for Success Criterion 3 / RESEARCH Pitfall 1).

**Window frame** (line 159, `.frame(width: 360, height: 280)`) → replace with the outer `NavigationSplitView`'s `.frame(width: 520, height: 380)` per UI-SPEC.md Layout Contract (starting point, on-device tunable).

**New skeleton to add (no prior analog in this codebase — first `NavigationSplitView` usage, confirmed via grep):**
```swift
// UI-SPEC.md §Sidebar Structure + RESEARCH.md Pattern 1
enum SidebarSection: String, CaseIterable, Identifiable {
    case general, workspace, system, about
    var id: String { rawValue }
    var title: String { /* "General" / "Workspace" / "System" / "About" */ }
    var icon: String { /* "gearshape" / "tray" / "paintbrush" / "info.circle" */ }
}

struct SettingsView: View {
    @State private var selection: SidebarSection? = .general
    // ...existing hoisted @State/@AppStorage unchanged...
    var body: some View {
        NavigationSplitView {
            List(SidebarSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.icon)
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
        } detail: {
            switch selection {
            case .general:   GeneralSectionView(...)
            case .workspace: WorkspaceSectionView()
            case .system:    ThemingSectionView(...)
            case .about, nil: AboutLicenseSectionView(...)
            }
        }
        .onAppear { /* existing refresh */ }
        .onChange(of: appearsActive) { /* existing refresh */ }
        .frame(width: 520, height: 380)
    }
}
```

**New Theming controls (exact code, from `27-UI-SPEC.md` §System/Theming — copy verbatim):**
```swift
Section("Appearance Style") {
    Picker("Style", selection: $materialStyle) {
        Text("Gradient").tag(MaterialStyle.gradient)
        Text("Solid Black").tag(MaterialStyle.solidBlack)
    }
    .pickerStyle(.segmented)
}

Section("Accent Colors") {
    LabeledContent("Now Playing") { swatchRow(selection: $nowPlayingAccentIndex) }
    LabeledContent("Charging")    { swatchRow(selection: $chargingAccentIndex) }
    LabeledContent("Device")     { swatchRow(selection: $deviceAccentIndex) }
}
```

**New Workspace placeholder (exact code, from UI-SPEC.md — no `Form`/`Section` wrapper):**
```swift
VStack(spacing: 8) {
    Image(systemName: "tray").font(.system(size: 28)).foregroundStyle(.secondary)
    Text("Nothing to configure yet").font(.headline)
    Text("The Shelf works automatically — no settings needed right now.").font(.subheadline)
}
.frame(maxWidth: .infinity, maxHeight: .infinity)
```

---

### `Islet/ActivitySettings.swift` (config/model, CRUD)

**Analog:** itself, current version (`Islet/ActivitySettings.swift`, all 53 lines — small file, read in full)

**Key-declaration idiom to extend** (lines 15-27):
```swift
static let chargingKey   = "activity.charging"
static let nowPlayingKey = "activity.nowPlaying"
static let accentIndexKey = "accentIndex"   // KEEP — read once by migration, see Shared Patterns
```
Add alongside (naming per RESEARCH.md Code Examples, matches this idiom):
```swift
static let materialStyleKey    = "theming.materialStyle"
static let nowPlayingAccentKey = "accent.nowPlaying"
static let chargingAccentKey   = "accent.charging"
static let deviceAccentKey     = "accent.device"

enum MaterialStyle: String, CaseIterable {
    case gradient, solidBlack
}
```

**Clamp-to-default idiom to reuse for the 3 new accent indices AND `MaterialStyle` parsing** (lines 34-39 — security-relevant, V5 per RESEARCH.md):
```swift
static func accent(for index: Int) -> Color {
    palette.indices.contains(index) ? palette[index] : palette[defaultAccentIndex]
}
```
`MaterialStyle(rawValue:)` parsing from `UserDefaults` must fall back to `.gradient` on any unrecognized string, same discipline — do not force-unwrap or add a new unchecked lookup.

**`EnvironmentKey` idiom to replicate 3x (or wrap in a small struct)** (lines 42-53):
```swift
private struct ActivityAccentKey: EnvironmentKey { static let defaultValue: Color = .white }
extension EnvironmentValues {
    var activityAccent: Color {
        get { self[ActivityAccentKey.self] }
        set { self[ActivityAccentKey.self] = newValue }
    }
}
```
Replace with 3 keys (`nowPlayingAccent`/`chargingAccent`/`deviceAccent`), each defaulting to `.white`, following this exact private-struct + computed-property idiom — plus one more `EnvironmentKey` for `islandMaterialStyle` (default `.gradient`) consumed by `NotchPillView`'s 4 fill sites.

---

### `Islet/Notch/NotchPillView.swift` (component, transform — 4 fill sites + 3 accent-read sites)

**Analog:** itself, current version — the existing single-branch `islandMaterial` constant (Phase 25) and single `activityAccent` `@Environment` (Phase 6) are the direct predecessors being extended, not replaced with a new pattern.

**Current single-value material (lines 159-173), extend into a 2-branch `AnyShapeStyle`:**
```swift
private static let islandMaterial = LinearGradient(
    stops: [
        .init(color: .black, location: 0.0),
        .init(color: .black, location: 0.65),
        .init(color: .black.opacity(0.5), location: 1.0),
    ],
    startPoint: .top, endPoint: .bottom
)
```
New pattern (RESEARCH.md Pattern 2 — MUST use `AnyShapeStyle`, `some ShapeStyle` cannot branch types at runtime, Pitfall 2):
```swift
private static let gradientMaterial = islandMaterial   // unchanged constant, renamed reference
private static let solidBlackMaterial = Color.black

private var islandFill: AnyShapeStyle {
    switch materialStyle {   // @Environment(\.islandMaterialStyle) private var materialStyle
    case .gradient:   return AnyShapeStyle(Self.gradientMaterial)
    case .solidBlack: return AnyShapeStyle(Self.solidBlackMaterial)
    }
}
```

**Exact 4 fill-site call sites to update (verified, current code):**
```swift
// collapsedIsland, line 283
.fill(collapsedFill)
// collapsedFill itself, lines 1079-1085 — DEBUG branch stays, RELEASE branch becomes AnyShapeStyle
private var collapsedFill: some ShapeStyle {
    #if DEBUG
    return Color.red.opacity(0.6)
    #else
    return Self.islandMaterial
    #endif
}

// blobShape, line 629
.fill(Self.islandMaterial)

// wingsShape, line 685
.fill(Self.islandMaterial)

// mediaWingsOrToast, line 748
.fill(Self.islandMaterial)
```
Each `.fill(Self.islandMaterial)` becomes `.fill(islandFill)`; `collapsedFill`'s return type must change from `some ShapeStyle` to `AnyShapeStyle` (its RELEASE branch already returns `Self.islandMaterial`, which becomes `islandFill`).

**Exact 3 accent-read call sites to update (verified, current code):**
```swift
// line 76 — single @Environment declared once, becomes 3
@Environment(\.activityAccent) private var accent

// line 717 — wings(for: ChargingActivity) → chargingAccent
BatteryIndicator(level: percent, accent: accent)

// line 775 — mediaWingsRow → nowPlayingAccent
EqualizerBars(isPlaying: isPlaying, tint: accent)

// line 826 — deviceWings(for:) → deviceAccent
.foregroundStyle(accent.opacity(iconOpacity))
```
`deviceWings`'s `BatteryIndicator(level: battery)` at line 842 takes **no** `accent:` argument today — do not add one (RESEARCH.md Pattern 3 note, only the glyph is accent-tinted for devices).

---

### `Islet/Notch/NotchWindowController.swift` (controller, event-driven)

**Analog:** itself, current version — the existing D-11 single-accent re-host pipeline (`makeRootView`/`applyAccentIfChanged`/`appliedAccentIndex`) is the direct predecessor to extend to 4 values (material style + 3 accents).

**Cached-value guard idiom (line 143), extend from 1 `Int?` to a small struct/tuple of 4 values:**
```swift
private var appliedAccentIndex: Int?
```

**Initial panel-creation read (lines 784-789), extend to read all 4 new keys alongside:**
```swift
let index = UserDefaults.standard.integer(forKey: ActivitySettings.accentIndexKey)
appliedAccentIndex = index
panel.contentView = NSHostingView(rootView: makeRootView(accentIndex: index))
```

**`makeRootView` environment injection (lines 1239-1262), extend the trailing `.environment(...)` chain:**
```swift
private func makeRootView(accentIndex: Int) -> some View {
    NotchPillView(interaction: interaction, /* ...existing params unchanged... */)
        .environment(\.activityAccent, ActivitySettings.accent(for: accentIndex))
}
```
Becomes (conceptually — exact param naming is implementation discretion):
```swift
.environment(\.nowPlayingAccent, ActivitySettings.accent(for: nowPlayingIndex))
.environment(\.chargingAccent,   ActivitySettings.accent(for: chargingIndex))
.environment(\.deviceAccent,     ActivitySettings.accent(for: deviceIndex))
.environment(\.islandMaterialStyle, materialStyle)
```

**Live re-apply on defaults change (lines 1359-1364), extend the guard + read + re-host, SAME shape:**
```swift
private func applyAccentIfChanged() {
    let index = UserDefaults.standard.integer(forKey: ActivitySettings.accentIndexKey)
    guard index != appliedAccentIndex else { return }
    appliedAccentIndex = index
    if let panel { panel.contentView = NSHostingView(rootView: makeRootView(accentIndex: index)) }
}
```
This function is called from `handleSettingsChanged()` (line 1309) — the existing `UserDefaults.didChangeNotification` observer (line 444-447) already fires this on ANY defaults write; do not add a second observer, extend this one function's read/compare/re-host to cover all 4 new keys (Pitfall 3 — BOTH the line-787 initial read AND the line-1360 live-apply read must be updated together, or accents desync between first-show and live-update).

---

### `IsletTests/ActivitySettingsTests.swift` (test, unit — new file)

**Analog:** `IsletTests/LicenseStateTests.swift` (pure-logic XCTest, fakes, no real I/O — closest style precedent; no direct `ActivitySettings` test exists today)

**Structure to mirror** (`IsletTests/LicenseStateTests.swift` lines 1-16):
```swift
import XCTest
@testable import Islet

final class ActivitySettingsTests: XCTestCase {
    func testAccentClampsOutOfRangeIndexToDefault() {
        XCTAssertEqual(ActivitySettings.accent(for: 999), ActivitySettings.palette[ActivitySettings.defaultAccentIndex])
    }
    func testMaterialStyleFallsBackToGradientOnUnrecognizedRawValue() {
        XCTAssertEqual(ActivitySettings.MaterialStyle(rawValue: "corrupted") ?? .gradient, .gradient)
    }
    // + migration/seeding test per Open Question 2's chosen mechanism (D-08)
}
```
No fakes/mocks needed here (unlike `LicenseStateTests.swift`'s `FakeLicenseManager`/`FakeTrialManager`) — `ActivitySettings`'s functions under test are pure value transforms with no injected dependency.

---

## Shared Patterns

### `@AppStorage` as source of truth for app-owned prefs
**Source:** `Islet/ActivitySettings.swift` header comment (lines 3-12) + every `@AppStorage` declaration in `SettingsView.swift` lines 28-38
**Apply to:** All new keys (`materialStyleKey`, 3 accent keys) — same idiom, no new persistence mechanism.

### UserDefaults-observer → compare-cached → re-host pipeline
**Source:** `Islet/Notch/NotchWindowController.swift` lines 143-149 (`appliedAccentIndex`/`defaultsObserver`), 1268-1364 (`handleSettingsChanged`/`applyAccentIfChanged`)
**Apply to:** Material style + all 3 new accents — extend the existing single pipeline, never build a second `UserDefaults.didChangeNotification` observer or a second re-host trigger.

### Clamp-to-default on every read (security — V5, Tampering)
**Source:** `Islet/ActivitySettings.swift` lines 37-39 (`accent(for:)`)
**Apply to:** `MaterialStyle(rawValue:)` parsing and all 3 new accent index reads — never force-unwrap or index without a bounds/rawValue-fallback check, exact same discipline as the existing `accentIndexKey` clamp.

### Hoisted `@State` for system-truth values shown across sidebar sections
**Source:** `Islet/SettingsView.swift` lines 5-13, 148-157 (`launchAtLogin`/`licenseStatus` + `.onAppear`/`.onChange(of: appearsActive)`)
**Apply to:** `SettingsView.swift`'s new `NavigationSplitView` shell — keep these declared at the top level, pass down to section subviews, never re-declare inside a `switch` case (Pitfall 1 / Success Criterion 3).

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `SettingsView.swift`'s `NavigationSplitView` shell itself (the sidebar `List` + detail `switch`) | component | request-response (selection state) | No `NavigationSplitView` usage exists anywhere else in this codebase (confirmed via grep) — this is this project's first sidebar-navigation surface. Use RESEARCH.md's Pattern 1 code example and UI-SPEC.md's Sidebar Structure table as the primary reference instead of an in-repo analog. |
| `AnyShapeStyle` runtime type-erasure branch (`islandFill`) | transform | n/a | No prior `AnyShapeStyle` usage exists in this codebase — Phase 25's `#if DEBUG` branch looks similar but is compile-time, not runtime (Pitfall 2). Use RESEARCH.md Pattern 2's code example as the reference. |

## Metadata

**Analog search scope:** `Islet/` (all `.swift` files), `IsletTests/` (all `.swift` files) — grepped for `NavigationSplitView`, `AnyShapeStyle`, `ActivitySettings`, `activityAccent`, `accentIndexKey`, `appliedAccentIndex`, `islandMaterial`, `collapsedFill`/`blobShape`/`wingsShape`/`mediaWingsOrToast`, `makeRootView`/`applyAccentIfChanged`/`defaultsObserver`
**Files scanned:** `Islet/SettingsView.swift`, `Islet/ActivitySettings.swift`, `Islet/Notch/NotchShape.swift`, `Islet/IsletApp.swift`, `Islet/Notch/NotchPillView.swift` (targeted ranges), `Islet/Notch/NotchWindowController.swift` (targeted ranges), `Islet/Diagnostics.swift` (grep only), `IsletTests/LicenseStateTests.swift`, plus `27-CONTEXT.md`, `27-RESEARCH.md`, `27-UI-SPEC.md`
**Pattern extraction date:** 2026-07-12
