# Phase 52: Top-Edge Switcher Layout & Placement Config - Pattern Map

**Mapped:** 2026-07-21
**Files analyzed:** 6 (4 modified source files, 2 modified test files — no new files)
**Analogs found:** 6 / 6 (all patterns exist in-place; this phase extends existing files, it does not create new ones)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `Islet/Notch/ViewSwitcherState.swift` (modify) | model | CRUD (state holder) | `ActivitySettings.WeatherStyle`/`MaterialStyle` (`Islet/ActivitySettings.swift:49-51,60-62`) | exact (String-backed enum for `@AppStorage`) |
| `Islet/ActivitySettings.swift` (modify) | config | CRUD (keys + default) | same file's existing `weatherStyleKey`/`WeatherStyle` block | exact |
| `Islet/SettingsView.swift` (modify) | component/provider | request-response (form → `@AppStorage`) | `weatherSection`/`fullscreenSection` (`Islet/SettingsView.swift:303-331`) + `SidebarSection` enum (`:81-109`) | exact |
| `Islet/Notch/NotchPillView.swift` (modify) | component | event-driven (render + tap → state) | `switcherRow`/`blobShape`/`navCircleButton` (same file, this phase's actual target) | exact (self-analog, in-place extension) |
| `IsletTests/NotchPillViewTests.swift` (modify) | test | request-response (assertion) | `testTabWidthHeightMatchesKnownPerCaseValues` (same file, lines 46-106) | exact |
| `IsletTests/NotchGeometryTests.swift` (modify, maybe) | test | request-response (assertion) | `testNotchSizeWidthFormulaAndHeight` (same file, lines 28-39) | exact |

No brand-new files are needed for this phase — RESEARCH.md's own "Recommended Project Structure" confirms this is a pure in-place extension of 4 existing source files plus their existing test files.

## Pattern Assignments

### `Islet/Notch/ViewSwitcherState.swift` (model)

**Analog:** `Islet/ActivitySettings.swift:49-51` (`WeatherStyle`) and `:60-62` (`MaterialStyle`)

**Current state** (`ViewSwitcherState.swift:9-14`):
```swift
enum SelectedView: Equatable {
    case home
    case tray
    case calendar
    case weather
}
```

**Target pattern to copy** (`ActivitySettings.swift:49-51`):
```swift
enum WeatherStyle: String, CaseIterable {
    case medium, large
}
static let weatherStyleKey = "weather.style"
```

**Change:** add `: String` (and `CaseIterable` per RESEARCH.md's Code Examples section) so `SelectedView` becomes `@AppStorage`-compatible — purely additive, one line, no existing `.rawValue`/pattern-match call site to break (confirmed: `SelectedView` is currently compared only via `==`).

**Read-fallback pattern to mirror at every new read site** (Security Domain / V5, `NotchWindowController.swift:1474`-style convention): `SelectedView(rawValue: stored) ?? .home` — never force-unwrap a `UserDefaults` string.

---

### `Islet/ActivitySettings.swift` (config)

**Analog:** same file's existing `weatherStyleKey`/`WeatherStyle` block (lines 46-52) and `materialStyleKey` block (54-63)

**Imports pattern** (lines 1): `import SwiftUI` (already present — `Color` is used in this file, no new import needed).

**Core pattern to copy** (lines 46-52):
```swift
// Phase 33 / WEATHER-01/02 — String-backed enum key (replaces the removed
// weatherExtendedKey Bool). Corrupted/unknown UserDefaults values parse to nil; every
// read site applies `?? .medium` (D-04) so Medium is always the safe floor.
enum WeatherStyle: String, CaseIterable {
    case medium, large
}
static let weatherStyleKey = "weather.style"
```

**Apply as:** a `SwitcherLayout: String, CaseIterable` enum (`.pill`, `.topEdge`) + `switcherLayoutKey`, plus 4 slot keys (`switcher.slot.leftOuter` etc., `SelectedView`-typed) — same one-key-per-value convention as `weatherStyleKey`, not a single encoded array (Don't Hand-Roll table, RESEARCH.md line 226).

---

### `Islet/SettingsView.swift` (component/provider)

**Analog A — `SidebarSection` enum extension:** `SettingsView.swift:81-109`
```swift
private enum SidebarSection: String, CaseIterable, Identifiable {
    case activities, appearance, fullscreen, weather, diagnostics, workspace, about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .activities: return "Activities"
        // ...
        }
    }

    var icon: String {
        switch self {
        case .activities: return "bolt"
        // ...
        }
    }
}
```
**Apply as:** add `case switcher` with `title: "Switcher"` and an SF Symbol icon (Claude's Discretion per CONTEXT.md) to both switches, following the exact same shape.

**Analog B — a simple `Form`-per-section body:** `fullscreenSection` (`SettingsView.swift:303-312`)
```swift
private var fullscreenSection: some View {
    ScrollView(.vertical) {
        Form {
            Section("Fullscreen") {
                Toggle("Hide notch in fullscreen", isOn: $hideInFullscreen)
            }
        }
        .padding(20)
    }
}
```
**Analog C — segmented Picker on an `@AppStorage`-backed enum:** `weatherSection` (`SettingsView.swift:318-331`)
```swift
private var weatherSection: some View {
    ScrollView(.vertical) {
        Form {
            Section("Weather") {
                Picker("Weather Style", selection: $weatherStyle) {
                    Text("Medium").tag(WeatherStyle.medium)
                    Text("Large").tag(WeatherStyle.large)
                }
                .pickerStyle(.segmented)
            }
        }
        .padding(20)
    }
}
```
**Apply as:** the new `switcherSection` — a segmented `Picker` for layout (Pill/Top Edge) + 4 `Picker(.menu)` dropdowns (per D-02), each `Text(...).tag(SelectedView.home)` etc. Gate visibility per D-08 using Pattern below.

**Analog D — `@AppStorage` declaration convention:** `SettingsView.swift:63,73`
```swift
@AppStorage(ActivitySettings.weatherStyleKey) private var weatherStyle: ActivitySettings.WeatherStyle = .medium
```
**Apply as:** `@AppStorage(ActivitySettings.switcherLayoutKey) private var switcherLayout: ActivitySettings.SwitcherLayout = .pill` + 4 slot `@AppStorage` vars, defaults per SWITCH-04 (Home+Tray left, Calendar+Weather right).

**Analog E — `.onAppear`/`.onChange(of: appearsActive)` refresh hook for a computed, non-`@Published` signal:** `SettingsView.swift:169-178`
```swift
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
**Apply as:** add `hasNotchDisplay = ...` refresh calls in both hooks, per RESEARCH.md Pattern 2 (`selectTargetScreen(from: NSScreen.screens.map { $0.descriptor })?.hasNotch ?? false`) — D-08's gate, no controller plumbing.

---

### `Islet/Notch/NotchPillView.swift` (component — the phase's primary target)

**Analog — `navCircleButton` (reuse verbatim per D-04/D-05):** `NotchPillView.swift:1897-1908`
```swift
private func navCircleButton(systemName: String, filled: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Image(systemName: systemName)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(filled ? Color.black : Color.white)
            .frame(width: Self.navCircleDiameter, height: Self.navCircleDiameter)
            .background(Circle().fill(filled ? Color.white : Color.clear))
            .overlay(Circle().strokeBorder(Color.white.opacity(filled ? 0 : 0.4), lineWidth: 1.5))
            .contentShape(Circle())
    }
    .buttonStyle(.plain)
}
```
`navCircleDiameter` constant: `NotchPillView.swift:1895` = `36`. `cameraClearance` constant: `NotchPillView.swift:609` = `42` (Pitfall 3's tight-fit concern).

**Analog — current hardcoded `switcherRow` (D-03's reorder target):** `NotchPillView.swift:2041-2057`
```swift
private var switcherRow: some View {
    HStack(spacing: 8) {
        navCircleButton(systemName: "house.fill",
                         filled: viewSwitcherState.selectedView == .home,
                         action: { onSwitcherSelect(.home) })
        navCircleButton(systemName: "tray.fill",
                         filled: viewSwitcherState.selectedView == .tray,
                         action: { onSwitcherSelect(.tray) })
        navCircleButton(systemName: "calendar",
                         filled: viewSwitcherState.selectedView == .calendar,
                         action: { onSwitcherSelect(.calendar) })
        navCircleButton(systemName: "cloud.sun.fill",
                         filled: viewSwitcherState.selectedView == .weather,
                         action: { onSwitcherSelect(.weather) })
    }
    .frame(height: Self.switcherRowHeight)
}
```
**Apply as:** replace the 4 hardcoded calls with a `ForEach` over `orderedSlotIcons` (RESEARCH.md Pattern 1, lines 156-183) — always exactly 4 children, so Phase 45's structural-identity/`matchedGeometryEffect` morph rule is preserved (no `AnyView`, no conditional child count). The SAME `orderedSlotIcons` + `icon(for:)` helper feeds the new top-edge row.

**Analog — `blobShape` height math (Pitfall 1's exact regression risk):** `NotchPillView.swift:1973-2032`
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
    let hasShelf = shelfVisible
    let baseWidth = width ?? Self.expandedSize.width
    let baseHeight = height ?? (showSwitcher ? Self.switcherContentHeight : Self.expandedSize.height)
    let totalHeight = baseHeight
        + (showSwitcher ? Self.switcherRowHeight : 0)
        + (hasShelf ? Self.shelfRowHeight : 0)
    let shape = NotchShape(topCornerRadius: topCornerRadius, bottomCornerRadius: bottomCornerRadius)
    return shape
        .fill(islandFill)
        .matchedGeometryEffect(id: "island", in: ns)
        .frame(width: baseWidth, height: totalHeight)
        .overlay(liquidGlassEffectLayer(shape: shape, size: CGSize(width: baseWidth, height: totalHeight), parameters: .expanded))
        .overlay(alignment: .top) {
            VStack(spacing: 0) {
                content()
                    .frame(width: baseWidth, height: baseHeight, alignment: alignment)
                if showSwitcher {
                    switcherRow
                }
                if hasShelf {
                    shelfRow(shelfItems)
                        .transition(.opacity)
                }
            }
            .frame(width: baseWidth, height: totalHeight, alignment: .top)
            .clipShape(shape)
        }
        .onTapGesture { onClick() }
}
```
**Apply as (Pitfall 1's fix, DO NOT repurpose `showSwitcher`):** add a second Bool — e.g. `reservesSwitcherHeight` — that keeps `baseHeight` on the `switcherContentHeight` branch regardless of layout mode; make the `+switcherRowHeight` term (and the `if showSwitcher { switcherRow }` render) conditional on "pill layout AND showSwitcher" specifically, not on the new flag. The top-edge row itself renders OUTSIDE this `VStack`'s reserved switcher-row slot (see RESEARCH.md's architecture diagram), positioned in the `cameraClearance` band instead.

**Matching outer `.frame` that MUST move in lockstep (Pitfall 1's second half):** `NotchPillView.swift:993-999`
```swift
.frame(width: isTrayPresentation ? Self.traySize.width : (isCalendarPresentation ? Self.calendarWidth : (isOnboardingPresentation ? Self.onboardingSize.width : Self.expandedSize.width)),
       height: isTrayPresentation
           ? Self.trayContentHeight + Self.switcherRowHeight
           : (isOnboardingPresentation
               ? Self.onboardingSize.height
               : (showsSwitcherRow ? Self.switcherContentHeight : Self.expandedSize.height)
                   + (showsSwitcherRow ? Self.switcherRowHeight : 0)),
       alignment: .top)
```
This duplicates `blobShape`'s exact ternary — any new flag added to `blobShape` needs the identical split applied here, in the SAME plan step (RESEARCH.md's own explicit warning).

**Analog — `tabWidth`/`tabHeight` computed properties (internal, test-visible):** `NotchPillView.swift:94-109`
```swift
var tabWidth: CGFloat {
    switch presentation {
    case .calendarExpanded: return Self.calendarWidth
    case .trayExpanded: return Self.traySize.width
    default: return Self.expandedSize.width
    }
}

var tabHeight: CGFloat {
    switch presentation {
    case .calendarExpanded: return Self.calendarContentHeight
    case .trayExpanded: return Self.trayContentHeight
    case .weatherExpanded: return weatherStyle == .large ? Self.weatherLargeContentHeight : Self.weatherMediumContentHeight
    default: return Self.homeContentHeight + (presentationState.outputPanelOpen ? Self.outputPanelExtraHeight : 0)
    }
}
```
Kept `internal` (not `private`) specifically so `NotchPillViewTests.swift` can assert directly — same convention must extend to any new top-edge-mode geometry values (e.g. a `topEdgeSwitcherHeight` shrink amount) if SC#5's regression lock is to stay testable per RESEARCH.md's Validation Architecture.

**Analog — single shared `blobShape` call site (Phase 45's morph-fix precedent, must not fork):** `NotchPillView.swift:893-921` (`tabContentView`)
```swift
private var tabContentView: some View {
    blobShape(topCornerRadius: 24, bottomCornerRadius: 32, alignment: .top,
              width: tabWidth, height: tabHeight, shelfItems: shelfViewState.items,
              shelfVisible: shelfStripVisible, showSwitcher: true) {
        switch presentation {
        case .nowPlayingExpanded(let p, true):
            mediaContent(p, art: nowPlaying.artwork)
        // ... 5 more cases ...
        default:
            EmptyView()
        }
    }
}
```
**Apply as:** the ONE call site that both passes the new height flag and conditionally renders the top-edge row — do not add a second `blobShape` call for top-edge mode (that would reintroduce the exact disappear/rebuild flicker Phase 45 fixed, per CONTEXT.md's explicit warning).

**Anti-pattern to avoid (from RESEARCH.md, confirmed against source):** `.offset(x:y:)`/`.position(x:y:)` for the top-edge row — empirically broken in this shape/content stack (Phase 39 lesson). Use `HStack(spacing: 0)` with `Color.clear.frame(width:)` spacers instead, sized via `notchSize(...).width` (`NotchGeometry.swift:27-37`), never `auxLeftWidth + auxRightWidth` directly (Pitfall 2).

---

### `Islet/Notch/NotchGeometry.swift` / `DisplayResolver.swift` / `NSScreen+Notch.swift` (read-only reuse, no modification expected)

**Pure functions to call directly, unmodified** (`NotchGeometry.swift:12-37`):
```swift
func hasNotch(safeAreaTop: CGFloat, auxLeftWidth: CGFloat?, auxRightWidth: CGFloat?) -> Bool {
    safeAreaTop > 0 && auxLeftWidth != nil && auxRightWidth != nil
}

func notchSize(screenWidth: CGFloat,
               safeAreaTop: CGFloat,
               auxLeftWidth: CGFloat?,
               auxRightWidth: CGFloat?,
               widthFudge: CGFloat = 4) -> CGSize? {
    guard hasNotch(safeAreaTop: safeAreaTop, auxLeftWidth: auxLeftWidth, auxRightWidth: auxRightWidth),
          let left = auxLeftWidth, let right = auxRightWidth else { return nil }
    let width = screenWidth - left - right + widthFudge
    guard width > 0 else { return nil }
    return CGSize(width: width, height: safeAreaTop)
}
```

**`selectTargetScreen`/`ScreenDescriptor.hasNotch`** (`DisplayResolver.swift:16-40`):
```swift
extension ScreenDescriptor {
    var hasNotch: Bool {
        Islet.hasNotch(safeAreaTop: safeAreaTop, auxLeftWidth: auxLeftWidth, auxRightWidth: auxRightWidth)
    }
}
func selectTargetScreen(from screens: [ScreenDescriptor]) -> ScreenDescriptor? {
    screens.first { $0.isBuiltin && $0.hasNotch }
}
```

**Live NSScreen bridge** (`NSScreen+Notch.swift:27-36`, `descriptor` computed property) and the existing live-call precedent (`NotchWindowController.swift:835-837`):
```swift
private func currentBuiltin() -> ScreenDescriptor? {
    NSScreen.screens.map { $0.descriptor }.first { $0.isBuiltin }
}
```
**Apply as:** both `SettingsView` (D-08 gate) and `NotchPillView` (cutout-gap width) call `selectTargetScreen(from: NSScreen.screens.map { $0.descriptor })` directly — no `@Published` bridge, per RESEARCH.md's Alternatives Considered (zero existing precedent for pushing screen geometry into SwiftUI content via a controller-owned object).

---

## Shared Patterns

### `@AppStorage` app-owned preference convention
**Source:** `Islet/ActivitySettings.swift` (whole-file convention) + `SettingsView.swift:28-76`
**Apply to:** `SwitcherLayout` enum + `switcherLayoutKey`, 4 slot keys — one `@AppStorage` value per key, `String`-backed enum, never a single encoded array. Corrupted/unknown values fall back via `?? .default` at every read site (Security Domain V5).

### `SidebarSection`/`Form`-per-section Settings structure (Phase 51 precedent, D-07)
**Source:** `SettingsView.swift:81-109` (enum) + `:303-331` (two example sections)
**Apply to:** the new `.switcher` case + `switcherSection` view — identical shape to `fullscreenSection`/`weatherSection`.

### Structural-identity / morph-safety rule (Phase 45 precedent)
**Source:** `NotchPillView.swift:869-884` (`presentationSwitch`'s comment on why 6 cases route through ONE `tabContentView`)
**Apply to:** any change to `switcherRow`, `blobShape`, or the pill/top-edge conditional — must keep exactly one continuously-identified subtree per render (no `AnyView`, no varying child count in a `ForEach`/`HStack`, no second `blobShape` call site for the alternate layout).

### Pure-geometry-function reuse, no controller plumbing (D-08)
**Source:** `NotchGeometry.swift`, `DisplayResolver.swift`, `NSScreen+Notch.swift`, `NotchWindowController.swift:835-837`
**Apply to:** `hasNotch`/cutout-width computation in both `SettingsView` and `NotchPillView`, refreshed via the existing `.onAppear`/`.onChange(of: appearsActive)` hook pattern (`SettingsView.swift:169-178`).

### Locked-value regression test pattern
**Source:** `IsletTests/NotchPillViewTests.swift:46-106` (`testTabWidthHeightMatchesKnownPerCaseValues`) and its `UserDefaults.standard` save/restore-via-`defer` idiom (lines 86-95)
**Apply to:** a new top-edge-mode `tabHeight`/`tabWidth` case, plus new tests for `orderedSlotIcons` default/override behavior (SWITCH-04) and the cutout-gap-width formula (Pitfall 2), mirroring `IsletTests/NotchGeometryTests.swift:28-39`'s hand-built-input style for any extracted pure function.

## No Analog Found

None — every file this phase touches already has an in-file or same-codebase precedent to extend (this is an additive-to-existing-files phase per RESEARCH.md's "Recommended Project Structure": no new files).

## Metadata

**Analog search scope:** `Islet/`, `Islet/Notch/`, `IsletTests/` (all files named in RESEARCH.md's Sources section, verified directly)
**Files scanned:** `ViewSwitcherState.swift`, `ActivitySettings.swift`, `SettingsView.swift`, `NotchPillView.swift`, `NotchGeometry.swift`, `IslandResolver.swift`, `DisplayResolver.swift`, `NSScreen+Notch.swift`, `NotchWindowController.swift` (targeted), `NotchPillViewTests.swift`, `NotchGeometryTests.swift`
**Pattern extraction date:** 2026-07-21
