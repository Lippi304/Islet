# Phase 27: Settings Sidebar Redesign - Research

**Researched:** 2026-07-12
**Domain:** SwiftUI `NavigationSplitView` restructure of an existing macOS Settings window + new local-preference theming controls threaded into an existing `@Environment`-injection rendering pipeline
**Confidence:** HIGH (all core findings verified by reading the actual files this phase modifies; only window-sizing numbers and migration-mechanism specifics are estimates)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Section-to-control mapping**
- **D-01 (LOCKED):** **General** section = the 4 activity toggles (Charging, Now Playing, Song-Change Toast, Devices) + Launch-at-login + the Fullscreen toggle ("Hide notch in fullscreen") + Diagnostics ("Save Diagnostic Report…" button). This is a deliberate catch-all — user explicitly chose to consolidate rather than invent a 5th "Activities" section not named in the ROADMAP's 4-section list.
- **D-02 (LOCKED):** **About/License** section = the existing adaptive License block (trial countdown / expired / licensed states, license-key entry, Buy Now button, status line) + the Version label. Matches the section name literally — nothing else moves here.
- **D-03 (LOCKED):** **Workspace (Shelf)** section is built as a real sidebar entry even though no shelf-specific settings exist today. It shows placeholder content (e.g., "No shelf settings yet") to literally satisfy ROADMAP Success Criterion #1. Exact placeholder copy is Claude's discretion.
- **D-04 (LOCKED):** **System (Theming)** section = the existing Accent picker (today's single global accent — see D-06 for how it changes) + NEW: material-style preset picker + per-element accent pickers.

**Theming — material/surface style (VISUAL-03, part 1)**
- **D-05 (LOCKED):** Exactly **2 presets**: "Gradient" (Phase 25's existing black-to-transparent vertical gradient, VISUAL-01 — stays the default) and "Solid Black" (a flat `Color.black` fill, i.e. the pre-Phase-25 look). No third "Glossy" preset. Picker mechanism is Claude's/planner's discretion.
- **D-06:** Selecting a preset must apply to all 3 shell-chrome fill sites Phase 25 touched (`collapsedIsland`, `blobShape`, `wingsShape`, `mediaWingsOrToast` in `NotchPillView.swift`) — consistent across collapsed pill, expanded island, and wings.

**Theming — per-element accent colors (VISUAL-03, part 2)**
- **D-07 (LOCKED):** The single global `accentIndexKey` accent picker is replaced by **3 independent pickers** — one each for Now Playing (equalizer bars), Charging (glyph), Device (battery icon) — each drawing from the same existing curated 6-swatch palette (`ActivitySettings.palette`). No "linked/uniform mode" toggle requested.
- **D-08:** Requires 3 new `@AppStorage` keys (one per element) replacing the single `accentIndexKey`, and updating `ActivitySettings.accent(for:)`/`activityAccent` environment plumbing to be per-element rather than single-value — exact naming/migration approach is Claude's/planner's discretion, but MUST avoid a silent visual regression for existing users on upgrade.

**App icon variants — explicitly descoped**
- **D-09 (LOCKED):** No alternate app-icon assets exist anywhere in the repo. Building "alternate app icon variants" would mean either the user supplying real designed icon files, or Claude generating placeholder tinted variants — user rejected both for this phase and chose to **cut the app-icon part of Success Criterion #4 from Phase 27 entirely**, deferring it to backlog/a future phase.
- **D-10 (Follow-up required, not yet applied):** Before/at planning, `REQUIREMENTS.md`'s VISUAL-03 wording and `ROADMAP.md`'s Phase 27 Success Criterion #4 need a follow-up edit to drop "choose among alternate app icon variants," and a note should be added to the Deferred/Backlog tracking. This CONTEXT.md does not edit those files itself.

### Claude's Discretion
- Exact SwiftUI mechanism for material-style preset picker and per-element accent pickers (segmented control vs. list vs. swatch grid) — visual layout is a planning/UI-phase decision.
- Settings window sizing — today's `SettingsView` is a fixed `.frame(width: 360, height: 280)`; a `NavigationSplitView` sidebar layout will very likely need a wider/taller frame. Exact dimensions are implementation/on-device-tuning judgment.
- Whether the `NavigationSplitView` uses a fixed always-visible sidebar or a collapsible one — technical choice, not discussed with the user.
- Exact placeholder copy for the empty Workspace (Shelf) section (D-03).
- Exact migration/seeding approach for the 3 new per-element accent keys (D-08) — must not visually regress existing users, but the specific UserDefaults read/write sequence is implementation detail.
- Whether "Solid Black" preset (D-05) needs its own bottom-corner-radius handling or reuses Phase 25's existing shape values unchanged — confirm during planning/research if Phase 25's `NotchShape` corner-radius values were coupled to the gradient in any way. **Resolved by this research: no coupling exists — see Open Questions §1.**

### Deferred Ideas (OUT OF SCOPE)
- **Alternate app icon variants** — no icon assets exist yet; user explicitly deferred this to backlog/a future phase (D-09/D-10) rather than build placeholders now. When picked up later, needs either user-supplied icon files or a proper icon-design pass — not a Claude-generated placeholder.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-------------------|
| SETTINGS-01 | The Settings window is restructured from a single tabbed form into a sidebar-categorized layout with sections General, Workspace (Shelf), System (Theming), and About/License — existing toggles and the accent-color picker preserved, no functional regression | Architecture Patterns Pattern 1 (state-hoisting to avoid stale-state regression), Pitfall 1 (detail-view staleness), Pitfall 4 (window sizing), full exact-line mapping of every control's current location in `SettingsView.swift` |
| VISUAL-03 | A new Theming section in Settings lets the user customize the shell's material/surface style and per-element accent colors (app-icon-variant portion descoped per D-09/D-10) | Architecture Patterns Pattern 2 (`AnyShapeStyle` for material style), Pattern 3 (3 verified `NotchPillView` accent call sites + 2 verified `NotchWindowController` read sites), Open Question 1 (corner-radius decoupling, resolved), Open Question 2 (migration/seeding options), Security Domain (clamp-to-default parsing) |
</phase_requirements>

## Summary

This phase is a pure in-app SwiftUI/AppKit restructuring task with **zero new external dependencies**. `Islet/SettingsView.swift` currently renders a 3-tab `TabView` (General / Appearance / Activities); it must become a 4-section `NavigationSplitView` (General / Workspace / System / About) while preserving every control and adding a Theming sub-feature (2-preset material style + 3 independent per-element accent pickers). The codebase already has a clean, consistent pattern for "app-owned preference → live-applied to the notch shell": `@AppStorage` in `SettingsView` → `UserDefaults.didChangeNotification` → `NotchWindowController.handleSettingsChanged()`/`applyAccentIfChanged()` → re-host `NotchPillView` with new `@Environment` values. The Theming section must extend this exact pipeline, not invent a new one.

Two concrete, code-verified landmines exist that are not obvious from reading CONTEXT.md alone: (1) the single `@Environment(\.activityAccent)` key is read at **exactly 3 call sites** in `NotchPillView.swift` (charging wings' `BatteryIndicator`, media wings' `EqualizerBars`, device wings' glyph `foregroundStyle`) — these map 1:1 to D-07's 3 new per-element keys, so the refactor is mechanical once found; (2) the existing `collapsedFill` computed property's `#if DEBUG / #else` branch returning `some ShapeStyle` **will not compile** as a pattern for the new *runtime* Gradient/Solid-Black toggle — Swift's opaque-return-type rule only tolerates the DEBUG branch because exactly one branch survives per build configuration. The new toggle needs `AnyShapeStyle` type erasure at all 4 fill sites instead.

**Primary recommendation:** Hoist `launchAtLogin`/`licenseStatus` `@State` to the top-level `SettingsView` (not into per-section subviews) and pass them down as bindings/params — this trivially satisfies Success Criterion 3 (no stale state on section switch) by construction, reusing the existing `.onAppear`/`.onChange(of: appearsActive)` refresh untouched. For Theming, add one new `@AppStorage` material-style key + 3 new per-element accent keys to `ActivitySettings.swift`, replace the single `activityAccent` `EnvironmentKey` with 3 keys (or a small struct), and extend `NotchWindowController`'s existing accent re-host mechanism to also re-inject material style — do not build a second live-apply pipeline.

## Architectural Responsibility Map

This is a single-process native macOS app; "tiers" below map to this app's existing layering (View / Controller / Local Storage) rather than a client-server split.

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Sidebar navigation + section selection state | SwiftUI View (`SettingsView`) | — | Pure UI-layer concern; `NavigationSplitView` owns selection binding |
| License / login-item / diagnostics state (existing) | SwiftUI View (`SettingsView`, hoisted `@State`) | Existing services (`LicenseState`, `LaunchAtLogin`) | Already works this way today; must not be re-architected, only relocated in the view tree |
| Activity toggles, fullscreen toggle (existing) | `@AppStorage` (Local Storage) | View (`Toggle` bindings) | Unchanged from today — app-owned prefs, `@AppStorage` is source of truth (established pattern) |
| Material-style preference (new) | `@AppStorage` (Local Storage) | `NotchWindowController` (re-host) → `NotchPillView` (render) | Persistence lives in Settings; live-apply to the shell rides the existing defaults-observer → re-host pipeline, not a new one |
| Per-element accent colors (new, 3x) | `@AppStorage` (Local Storage) | `NotchWindowController` (re-host) → `NotchPillView` (render, 3 call sites) | Same pipeline as material style; replaces the single existing `accentIndexKey`/`activityAccent` wiring |
| App icon variants | OUT OF SCOPE (D-09/D-10) | — | No assets exist; explicitly descoped this phase |

## Standard Stack

### Core
No new libraries. This phase uses only first-party frameworks already linked in the project.

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI `NavigationSplitView` | Ships with macOS SDK (available since macOS 13; project's deployment target is macOS 15.0 per `project.yml`/STATE.md — **note: the project-level CLAUDE.md tech doc still says "14.0 recommended," but Phase 26 bumped the real deployment target to 15.0 for `.defaultLaunchBehavior(.suppressed)`; treat 15.0 as current truth**) | The sidebar-categorized Settings layout (SETTINGS-01) | Apple's current (post-2022) macOS multi-column navigation primitive; supersedes the older `NavigationView`-with-`.listStyle(.sidebar)` pattern |
| `AnyShapeStyle` | Ships with SwiftUI (available since ~macOS 13 / Xcode 13) | Type-erase the Gradient vs. Solid-Black fill branch (VISUAL-03 part 1) | Required whenever a `ShapeStyle`-returning property must switch between two different concrete `ShapeStyle` types at runtime — a plain `some ShapeStyle` return cannot do this (see Pitfall 2) |

### Supporting
None — `@AppStorage`, `EnvironmentKey`, `UserDefaults.didChangeNotification` are all already in use in this exact codebase for the identical purpose (accent persistence + live-apply).

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `NavigationSplitView` | Hand-rolled `HSplitView` (AppKit) + custom selection enum | More code, no built-in keyboard nav / VoiceOver support NavigationSplitView gives for free; no reason to hand-roll this |
| `AnyShapeStyle` erasure | Two separate `Shape.fill()` call sites gated by `if/else` at the *View* level (not inside a shared computed property) | Works but duplicates the `NotchShape()...matchedGeometryEffect...frame...onTapGesture` boilerplate at all 4 fill sites instead of once; `AnyShapeStyle` keeps the existing single-property-per-site structure intact |
| 3 separate `EnvironmentKey`s for accent | One `EnvironmentKey` holding a `[ActivityElement: Color]` dictionary | Either works; 3 discrete keys most directly mirrors the existing single-key precedent (`activityAccent`) and keeps each of the 3 `NotchPillView` read sites a simple one-line `@Environment` property, no dictionary lookup/key-not-found handling needed |

**Installation:** None — no `npm install`/SPM package additions for this phase.

## Package Legitimacy Audit

**Not applicable.** This phase introduces zero external packages (no new Swift Package Manager dependencies). The existing `MediaRemoteAdapter` SPM dependency (pinned by commit revision in `project.yml`) is untouched by this phase's scope.

## Architecture Patterns

### System Architecture Diagram

```
User clicks sidebar row (General / Workspace / System / About)
        │
        ▼
SettingsView (@State selection: SidebarSection)
        │  selection drives NavigationSplitView's detail column
        ▼
Detail subview for the selected section
   ├─ General:   Toggle bindings → existing @AppStorage keys (unchanged)
   ├─ Workspace: static placeholder Text (D-03, no persistence)
   ├─ System:    material-style picker + 3 accent pickers → NEW @AppStorage keys
   └─ About:     licenseStatus/launchAtLogin — HOISTED @State from SettingsView top level,
                 passed down as bindings — NOT re-fetched per-section (avoids staleness)
        │
        ▼ (Theming section only — any @AppStorage write)
UserDefaults.didChangeNotification fires
        │
        ▼
NotchWindowController.defaultsObserver → handleSettingsChanged() / applyAccentIfChanged()
   (EXISTING mechanism — extend, do not duplicate)
        │  re-reads the new keys, compares against cached "applied" values
        ▼
NotchWindowController.makeRootView(...)
   .environment(\.nowPlayingAccent, ...) .environment(\.chargingAccent, ...)
   .environment(\.deviceAccent, ...)     .environment(\.islandMaterialStyle, ...)
        │  re-hosts NSHostingView with fresh Environment values
        ▼
NotchPillView reads @Environment at its 4 fill sites + 3 accent-consuming sites
   collapsedFill / blobShape / wingsShape / mediaWingsOrToast → AnyShapeStyle(gradient|solidBlack)
   wings(for:) BatteryIndicator / mediaWingsRow EqualizerBars / deviceWings glyph → per-element accent
        │
        ▼
Notch shell re-renders with new theme — no app restart, no window re-open needed
```

### Recommended Project Structure
No new files are strictly required — `SettingsView.swift` can grow in place with private subviews/computed properties, matching this codebase's existing convention (`NotchPillView.swift` is 1400+ lines of private helper views in one file). If splitting for readability, the natural seam is one file per sidebar section:
```
Islet/
├── SettingsView.swift          # NavigationSplitView shell, sidebar List, hoisted @State (launchAtLogin, licenseStatus)
├── Settings/                   # optional — only if splitting improves readability
│   ├── GeneralSectionView.swift
│   ├── WorkspaceSectionView.swift
│   ├── ThemingSectionView.swift   # System (Theming)
│   └── AboutLicenseSectionView.swift
├── ActivitySettings.swift      # extended: +1 material-style key, +3 accent keys, +1 new EnvironmentKey (or 3)
└── Notch/NotchPillView.swift   # 4 fill sites + 3 accent-read sites updated
```

### Pattern 1: Hoisted top-level state avoids NavigationSplitView detail staleness
**What:** Keep `launchAtLogin`/`licenseStatus` as `@State` on the top-level `SettingsView` (as today), refreshed via the existing `.onAppear` + `.onChange(of: appearsActive)`. Pass them into whichever detail subview is currently selected as `Binding`/plain values — never re-declare `@State private var licenseStatus = LicenseState.shared.status` *inside* a per-section subview.
**When to use:** Any time a `NavigationSplitView`'s detail closure is a `switch` over an enum — SwiftUI constructs a **new instance** of the matching case's view every time the case changes, so state declared inside that case view starts fresh (correct for transient UI state, WRONG for state that must reflect live system truth like license/login-item status, since re-construction alone doesn't re-run the expensive system read unless you also re-add an `.onAppear`).
**Example:**
```swift
// Source: pattern derived from existing SettingsView.swift lines 6-13, 148-157
struct SettingsView: View {
    @State private var selection: SidebarSection? = .general
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var licenseStatus = LicenseState.shared.status
    @Environment(\.appearsActive) private var appearsActive

    var body: some View {
        NavigationSplitView {
            List(SidebarSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.icon)
            }
        } detail: {
            switch selection {
            case .general:   GeneralSectionView(launchAtLogin: $launchAtLogin, ...)
            case .workspace: WorkspaceSectionView()
            case .system:    ThemingSectionView()
            case .about:     AboutLicenseSectionView(licenseStatus: licenseStatus, ...)
            case nil:        GeneralSectionView(launchAtLogin: $launchAtLogin, ...) // never actually nil, default selection above
            }
        }
        .onAppear { launchAtLogin = LaunchAtLogin.isEnabled; licenseStatus = LicenseState.shared.status }
        .onChange(of: appearsActive) { _, active in
            if active { launchAtLogin = LaunchAtLogin.isEnabled; licenseStatus = LicenseState.shared.status }
        }
    }
}
```

### Pattern 2: `AnyShapeStyle` for the runtime Gradient/Solid-Black branch
**What:** Every one of the 4 existing fill sites (`collapsedFill`, and the `Self.islandMaterial` reference inside `blobShape`, `wingsShape`, `mediaWingsOrToast`) must branch between `LinearGradient` and `Color.black` based on the persisted material-style preference, erased to `AnyShapeStyle` so the branch type-checks.
**When to use:** Any SwiftUI property/function that returns `some ShapeStyle` (or is used directly in `.fill(...)`) and needs to pick between two different concrete `ShapeStyle` conformers at runtime, not at compile time.
**Example:**
```swift
// Source: verified via WebSearch (swiftwithmajid.com/2021/11/17, zachwaugh.com — AnyShapeStyle type erasure)
// and Apple Developer Documentation (developer.apple.com/documentation/swiftui/anyshapestyle)
private static let gradientMaterial = LinearGradient(/* existing Phase 25 stops, unchanged */)
private static let solidBlackMaterial = Color.black

private var islandFill: AnyShapeStyle {
    switch materialStyle {          // @Environment(\.islandMaterialStyle) private var materialStyle
    case .gradient:   return AnyShapeStyle(Self.gradientMaterial)
    case .solidBlack: return AnyShapeStyle(Self.solidBlackMaterial)
    }
}
// then: NotchShape(...).fill(islandFill)   — replaces every `.fill(Self.islandMaterial)` call site
```
The existing `collapsedFill`'s `#if DEBUG` pattern (returns `Color.red.opacity(0.6)` in DEBUG, `Self.islandMaterial` in RELEASE) continues to compile today *only* because exactly one branch is ever compiled into a given build — that trick does not extend to a runtime user preference; `AnyShapeStyle` is required for the new branch specifically (the DEBUG tint branch itself can stay as-is, or also be wrapped for consistency).

### Pattern 3: Per-element `EnvironmentKey`s replace the single `activityAccent` key
**What:** `ActivitySettings.swift`'s single `ActivityAccentKey`/`activityAccent` (lines 42-53) becomes 3 keys. `NotchPillView.swift`'s exactly 3 read sites are updated to read the matching key instead of the shared `accent`.
**Verified call sites (grepped, not assumed):**
- `NotchPillView.swift:717` — `BatteryIndicator(level: percent, accent: accent)` inside `wings(for:)` → becomes `chargingAccent`
- `NotchPillView.swift:775` — `EqualizerBars(isPlaying: isPlaying, tint: accent)` inside `mediaWingsRow` → becomes `nowPlayingAccent`
- `NotchPillView.swift:826` — `.foregroundStyle(accent.opacity(iconOpacity))` inside `deviceWings(for:)` → becomes `deviceAccent`

Note `deviceWings`'s battery indicator (`BatteryIndicator(level: battery)`, line 842, no `accent:` argument) is deliberately **not** tinted by any accent today (renders green/amber/red battery colors regardless) — do not add an accent parameter there; only the glyph on the left wing is accent-tinted for devices.

**Injection sites to update (both must change together or accents desync):**
- `NotchWindowController.swift:1261` — `.environment(\.activityAccent, ActivitySettings.accent(for: accentIndex))` inside `makeRootView(accentIndex:)`
- `NotchWindowController.swift:787` and `:1360` — both do `let index = UserDefaults.standard.integer(forKey: ActivitySettings.accentIndexKey)`; both must be updated to read all 3 new keys
- `NotchWindowController.swift:143,1361` — `appliedAccentIndex: Int?` (single cached value used to skip redundant re-hosts) must become 3 cached values (or a small struct) so `applyAccentIfChanged()`'s `guard index != appliedAccentIndex` correctly detects a change in *any* of the 3 accents

### Anti-Patterns to Avoid
- **Reading `@AppStorage` directly inside `NotchPillView`:** The view currently has zero `@AppStorage` usage (verified by grep) — every persisted preference reaches it via `@Environment` injected by the controller. Breaking this convention for the new material-style/accent keys would create two different data-flow patterns in the same file for no benefit; keep everything flowing through `NotchWindowController.makeRootView(...)`.
- **Re-deriving license/login-item state per sidebar section:** Would risk exactly the "stale state on section switch" bug Success Criterion 3 explicitly calls out, if a section's `.onAppear` is forgotten or a section is shown without SwiftUI reconstructing it (e.g., if a future refactor keeps all 4 sections alive with `.opacity()`/`ZStack` instead of a `switch`).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|--------------|-----|
| Sidebar navigation + keyboard up/down selection | Custom `NSOutlineView`/hand-rolled selection index | `NavigationSplitView` + `List(selection:)` | Free keyboard navigation, VoiceOver, and native macOS sidebar chrome (translucent material) that a hand-rolled `HSplitView` would need to reimplement |
| Swatch color picker UI | A new color-grid component for the 3 Theming accent pickers | The existing curated palette rendering already in `SettingsView.swift` (`ForEach(ActivitySettings.palette.indices...)` circles with a selection ring, lines 107-119) | This exact UI already exists and works; the only change needed is calling it 3 times against 3 different `@AppStorage` bindings, not building a second picker component |
| Conditional shape-fill switching | An `if/else` duplicating the entire `NotchShape()...matchedGeometryEffect...frame` chain per material style at each of the 4 sites | `AnyShapeStyle` type erasure (Pattern 2) | Keeps each fill site a single `.fill(islandFill)` call; duplicating the whole shape chain 2x at 4 sites (8 total) is a much larger, more error-prone diff |

**Key insight:** Every piece of new UI in this phase (sidebar list, theming pickers) has a near-identical precedent already shipped in this same codebase (`SettingsView`'s existing accent swatches, `TabView`'s existing tab structure). The work is relocation + extension, not net-new component design.

## Common Pitfalls

### Pitfall 1: Detail-view state loss on section switch (directly threatens Success Criterion 3)
**What goes wrong:** License/login-item `@State` declared inside a per-section subview instead of hoisted to `SettingsView` shows stale (or default/zero) values the first render after switching back to that section, until some later refresh fires.
**Why it happens:** SwiftUI's `switch` inside a `NavigationSplitView` detail closure constructs a fresh `View` value on every case change; any `@State` inside that case starts at its declared initial value, not the value it held last time that case was visible, unless an `.onAppear` explicitly re-syncs it (and even then there's a one-frame flash of the stale/default value before `.onAppear` runs).
**How to avoid:** Hoist `launchAtLogin`/`licenseStatus` to `SettingsView` (Pattern 1) — they are then never reconstructed by a section switch at all, only by the window's own `.onAppear`/refocus, exactly as today.
**Warning signs:** On-device UAT: rapidly click between General/About and back — if the license countdown or login-item toggle ever visibly flickers to a wrong/default value for a frame, this pitfall has been hit.

### Pitfall 2: `some ShapeStyle` opaque return type cannot branch types at runtime
**What goes wrong:** Writing `private var islandFill: some ShapeStyle { switch style { case .gradient: return Self.gradientMaterial; case .solidBlack: return Color.black } }` fails to compile ("function declares an opaque return type... but the return statements... have conflicting underlying types").
**Why it happens:** `some ShapeStyle` commits the function to exactly one concrete type for the entire compiled binary; `LinearGradient` and `Color` are different concrete types. The existing `#if DEBUG` branch in `collapsedFill` looks similar but only compiles one branch per build configuration, so the compiler never sees two live return types simultaneously.
**How to avoid:** Return `AnyShapeStyle` explicitly (Pattern 2), not `some ShapeStyle`, for any property that branches on the new material-style preference.
**Warning signs:** A Swift compiler error mentioning "opaque return type" the moment the material-style branch is added — Xcode's error will name the exact function.

### Pitfall 3: Missing one of the two raw `UserDefaults` read call sites when migrating the accent key
**What goes wrong:** Updating `makeRootView`'s `.environment(\.activityAccent, ...)` call but forgetting `NotchWindowController.swift:787` (initial panel creation) or `:1360` (`applyAccentIfChanged`) leaves one code path still reading the old single `accentIndexKey`, so accents can desync between first-show and live-update.
**Why it happens:** The accent index is read from raw `UserDefaults.standard.integer(forKey:)` in **two separate places** in `NotchWindowController.swift` (not routed through a single accessor), an easy site to miss without grepping first.
**How to avoid:** Grep `ActivitySettings.accentIndexKey` across the whole target before starting the edit (both this research and a pre-edit grep in planning/execution should surface exactly these 2 sites, plus the 1 in `Diagnostics.swift:69` which is a diagnostic-report string, not a rendering path, and can keep reading whichever single index the report chooses to summarize).
**Warning signs:** Accent looks right immediately after changing it in Settings (live re-host path) but reverts to the old accent after quitting and relaunching the app (or vice-versa) — a sure sign one of the two read sites was missed.

### Pitfall 4: NavigationSplitView window sizing regression
**What goes wrong:** The existing `.frame(width: 360, height: 280)` is far too narrow once a sidebar column is added; naively keeping it (or removing it entirely) can produce a squeezed sidebar, a squeezed detail pane, or (since `.windowResizability(.contentSize)` in `IsletApp.swift` makes the window auto-size to the SwiftUI content's *intrinsic* size) an oddly-sized window if `NavigationSplitView`'s intrinsic size resolution is ambiguous.
**Why it happens:** `NavigationSplitView` needs both a sidebar-column width and a detail-column width/height to have a well-defined intrinsic size; simply keeping the old single `.frame()` at the outermost level does not automatically distribute space sensibly between the two columns.
**How to avoid:** Set an explicit `.navigationSplitViewColumnWidth(min:ideal:max:)` (or plain `.frame(width:)`) on the sidebar `List`, give the detail column a sensible `.frame(minWidth:idealWidth:)`, and keep one outer `.frame(width:height:)` sized generously (starting estimate ~520×380, larger than today's 360×280 — confirm on-device per CONTEXT.md's "Claude's Discretion" note). This is explicitly flagged in CONTEXT.md as needing on-device tuning, consistent with this project's established pattern (Phases 18/20/21/23/25/26 all tuned dimensions after first implementation).
**Warning signs:** Sidebar and detail overlapping, sidebar collapsing to icon-only unexpectedly, or the window opening at an unexpectedly tiny/huge size.

## Code Examples

### Sidebar section enum + NavigationSplitView skeleton
```swift
// Source: pattern synthesized from Apple's NavigationSplitView documentation
// (developer.apple.com/documentation/swiftui/navigationsplitview) + existing SettingsView.swift structure
enum SidebarSection: String, CaseIterable, Identifiable {
    case general, workspace, system, about
    var id: String { rawValue }
    var title: String {
        switch self {
        case .general:   return "General"
        case .workspace: return "Workspace"
        case .system:    return "System"
        case .about:     return "About"
        }
    }
    var icon: String {
        switch self {
        case .general:   return "gearshape"
        case .workspace: return "tray"
        case .system:    return "paintbrush"
        case .about:     return "info.circle"
        }
    }
}
```

### New `ActivitySettings.swift` keys (additive, alongside the existing `accentIndexKey` — kept for migration read, see Open Questions)
```swift
// Source: pattern mirrors the file's existing key-declaration convention (lines 15-27)
static let materialStyleKey = "theming.materialStyle"      // MaterialStyle.rawValue, default "gradient"
static let nowPlayingAccentKey = "accent.nowPlaying"
static let chargingAccentKey   = "accent.charging"
static let deviceAccentKey     = "accent.device"

enum MaterialStyle: String, CaseIterable {
    case gradient, solidBlack
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|---------------|--------|
| `NavigationView` + `.listStyle(.sidebar)` for macOS sidebar layouts | `NavigationSplitView` | WWDC 2022 (iOS 16/macOS 13) | `NavigationView`-based sidebar patterns found in older tutorials/StackOverflow answers are deprecated; this project should use `NavigationSplitView` exclusively, matching its macOS-15.0 deployment target |
| This app's own single global `accentIndexKey` | Per-element accent keys (this phase, D-07) | This phase | Not an ecosystem-wide change — a project-local architecture decision this research documents the mechanics of |

**Deprecated/outdated:** `NavigationView` is soft-deprecated by Apple in favor of `NavigationStack`/`NavigationSplitView`; do not introduce any new `NavigationView` usage in this phase.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|----------------|
| A1 | Recommended starting window size ~520×380 for the `NavigationSplitView` layout | Pitfall 4 / Recommended Project Structure | Low — CONTEXT.md already flags this as needing on-device tuning; a wrong starting guess just costs one extra UAT iteration, matching this project's established sizing-iteration pattern |
| A2 | Recommended migration approach (a one-time explicit seed of the 3 new accent keys from the old `accentIndexKey`, run once at launch) is one reasonable implementation, not the only one | Pattern 3 / Open Questions | Low — CONTEXT.md D-08 explicitly leaves the exact seeding mechanism to planner/implementation discretion; flagged as a decision point below, not asserted as the only correct approach |
| A3 | Sidebar icon choices (`gearshape`, `tray`, `paintbrush`, `info.circle`) are illustrative SF Symbol names, not verified against the actual rendered icon set | Code Examples | Low — cosmetic only; any valid SF Symbol name works, wrong choice is a one-line fix during UAT (mirrors this project's own Pitfall-7 precedent for device glyph SF Symbol names) |

## Open Questions

1. **Does "Solid Black" need its own corner-radius handling? (CONTEXT.md explicitly asks this)**
   - What we know: `NotchShape`'s `topCornerRadius`/`bottomCornerRadius` are plain `CGFloat` initializer parameters, completely independent of the `.fill(...)` argument passed to the shape at each of the 4 call sites (verified by reading `NotchShape.swift` and all 4 `NotchPillView.swift` fill sites directly).
   - What's unclear: Nothing — this is resolved, not open.
   - **Answer (HIGH confidence, code-verified): No coupling exists.** The Solid-Black preset can reuse every existing `NotchShape(topCornerRadius:bottomCornerRadius:)` call unchanged; only the `.fill(...)` argument needs the new `AnyShapeStyle` branch (Pattern 2). This resolves the CONTEXT.md discretion note — no shape-layer changes are needed for D-05.

2. **Exact 3-key accent migration/seeding mechanism (D-08, explicitly left to planner discretion)**
   - What we know: The old single `accentIndexKey` must not silently reset any existing user's accent look on upgrade. Two viable mechanisms exist: (a) give each new `@AppStorage` accent key a computed default expression that reads the old key at declaration time (`= UserDefaults.standard.integer(forKey: ActivitySettings.accentIndexKey)`), relying on `integer(forKey:)`'s `0` fallback matching `defaultAccentIndex`; (b) a one-time explicit migration function (checked via `UserDefaults.standard.object(forKey:) == nil`) run once at app launch that writes all 3 new keys from the old value.
   - What's unclear: Option (a) requires the *exact same* fallback expression to be duplicated at every read site (both `SettingsView`'s `@AppStorage` declarations and `NotchWindowController`'s 2 raw `UserDefaults` reads) — a mismatch would reintroduce Pitfall 3. Option (b) is more centralized/robust but is one more moving piece (a migration function that must run exactly once, before either read site fires).
   - Recommendation: Prefer option (b) — a single explicit migration function called early in `AppDelegate`'s launch sequence (alongside the existing `LicenseState.shared` pre-seed noted in that file) — for the same reason this codebase already centralizes other one-time state (e.g., `onboardingCompletedKey`'s grandfathering logic per STATE.md). This keeps all 3 new keys' "first ever read" behavior in one place instead of duplicated default-expressions.

3. **REQUIREMENTS.md / ROADMAP.md wording still says "alternate app icon variants" (D-10, not yet applied)**
   - What we know: `.planning/REQUIREMENTS.md` line 26 (VISUAL-03) and `.planning/ROADMAP.md`'s Phase 27 Success Criterion #4 both still list app-icon-variant selection as in-scope text, even though D-09/D-10 formally descope it.
   - What's unclear: Nothing technical — this is a documentation-sync task, not a research gap.
   - Recommendation: The planner (or a `/gsd:quick` follow-up) should edit both files to drop the app-icon clause before or during Phase 27 planning, per D-10's explicit instruction, mirroring the identical pattern already used for Phase 25's own VISUAL-03 descope note.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest, `IsletTests` target (28 existing test files, e.g. `LicenseStateTests.swift`, `InteractionStateTests.swift`) |
| Config file | `project.yml` (XcodeGen) generates `Islet.xcodeproj`; no separate test-runner config |
| Quick run command | `xcodebuild build -project Islet.xcodeproj -scheme Islet -configuration Debug` (build-only gate — see below, do NOT use `xcodebuild test`) |
| Full suite command | Manual: open `Islet.xcodeproj` in Xcode, Cmd-U (`IsletTests` scheme) |

**Project-specific constraint (from prior-session memory, load-bearing — do not deviate):** `xcodebuild test` **hangs** in this repo because the test target hosts the full `Islet.app`, which boots the real `NSPanel`/MediaRemote/IOBluetooth stack — there is no headless test mode. The established gate for this project is `xcodebuild build` (compiles + catches type errors, including the `AnyShapeStyle`-class of error from Pitfall 2) as the automated checkpoint; actual XCTest execution is always manual, via Cmd-U in Xcode. Any plan for this phase must route its "run tests" verification step through `xcodebuild build`, not `xcodebuild test`, and flag genuine XCTest execution as a manual/Cmd-U checkpoint.

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|---------------------|-------------|
| SETTINGS-01 | Sidebar restructure, every existing control present + functional per section | manual-only | on-device UAT (no XCTest coverage exists or is planned for `SettingsView`'s view hierarchy — this codebase has zero View-level SwiftUI tests, only pure-logic/model tests) | N/A — manual by design |
| SETTINGS-01 | License/login-item state stays synced across section switches (Criterion 3) | manual-only | on-device UAT — rapid section-switching click-through (see Pitfall 1's "Warning signs") | N/A — manual by design |
| VISUAL-03 | Material-style + per-element accent persistence, clamping, migration/seeding logic | unit | `xcodebuild build` (compile gate) + `IsletTests/ActivitySettingsTests.swift::test*` via Cmd-U | ❌ Wave 0 — file does not exist yet |
| VISUAL-03 | Material-style/accent live-apply to the notch shell (rendering) | manual-only | on-device UAT — change each Theming control, observe the collapsed pill / expanded island / all 3 wing glances update live | N/A — manual by design |

### Sampling Rate
- **Per task commit:** `xcodebuild build -project Islet.xcodeproj -scheme Islet -configuration Debug`
- **Per wave merge:** Same build command (Release configuration too, per the project's established Release-parity discipline — see prior-session memory on Release-only library-validation crashes) + manual Cmd-U for any new `ActivitySettingsTests.swift` cases
- **Phase gate:** Full on-device UAT pass covering all 4 sidebar sections + both theming controls before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `IsletTests/ActivitySettingsTests.swift` — new file; covers `MaterialStyle` rawValue parsing/clamping (mirroring the existing `accent(for:)` out-of-range-clamp test discipline) and the 3-key accent migration/seeding logic (Open Question 2)
- [ ] No new fixtures/conftest-equivalent needed — this codebase's existing `FakeLicenseManager`-style plain fakes (no test framework beyond XCTest itself) are sufficient precedent
- [ ] Framework install: none — XCTest is already fully wired

## Security Domain

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|----------------|---------|-------------------|
| V2 Authentication | No | Unrelated — no auth surface touched by this phase |
| V3 Session Management | No | Unrelated |
| V4 Access Control | No | Unrelated — single-user local app, no access-control boundary |
| V5 Input Validation | Yes | New `MaterialStyle(rawValue:)` parsing from `UserDefaults` MUST fall back to `.gradient` on any unrecognized/corrupted string, mirroring the existing `ActivitySettings.accent(for:)` clamp-to-default discipline (`palette.indices.contains(index) ? ... : palette[defaultAccentIndex]`, already annotated in the codebase as a T-06-07/T-06-11 tamper-resilience pattern). The 3 new accent indices must use the exact same `accent(for:)` clamping function, not a new unchecked lookup. |
| V6 Cryptography | No | Unrelated — no secrets/crypto touched; local UserDefaults preferences only, same trust boundary as the existing accent index |

### Known Threat Patterns for this stack
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|------------------------|
| Corrupted/out-of-range `UserDefaults` value for a new preference key (e.g. a stale key from a future removed preset, or manual `defaults write` tampering) | Tampering | Clamp-to-default on every read, exactly as the existing `accent(for:)` already does — apply identically to the new `MaterialStyle` parsing and all 3 new accent indices; never force-unwrap or index without a bounds/rawValue check |

## Sources

### Primary (HIGH confidence)
- Direct codebase reads: `Islet/SettingsView.swift`, `Islet/ActivitySettings.swift`, `Islet/IsletApp.swift`, `Islet/Notch/NotchPillView.swift` (lines 1-969, 1070-1100, 1234), `Islet/Notch/NotchShape.swift`, `Islet/Notch/NotchWindowController.swift` (lines 770-810, 1230-1270, 1350-1370, plus grep of all `accentIndexKey`/`appliedAccentIndex`/`defaultsObserver`/`hideInFullscreen` occurrences), `project.yml`, `.planning/config.json`, `IsletTests/LicenseStateTests.swift` — every call site and pitfall in this document traces to an actual read/grep, not training-data recall.
- Apple Developer Documentation — `developer.apple.com/documentation/swiftui/navigationsplitview`, `developer.apple.com/documentation/swiftui/anyshapestyle`

### Secondary (MEDIUM confidence)
- WebSearch, cross-verified against Apple docs — NavigationSplitView selection-binding pitfalls (danielsaidi.com, kiloloco.com, swiftwithmajid.com), `AnyShapeStyle` conditional-fill usage pattern (swiftwithmajid.com/2021/11/17, zachwaugh.com)

### Tertiary (LOW confidence)
- None — every finding in this research was either verified directly against this codebase's source or cross-checked against Apple's official documentation.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new dependencies, both `NavigationSplitView` and `AnyShapeStyle` are stable, multi-year-old first-party SwiftUI APIs
- Architecture: HIGH — the existing accent-injection pipeline and all call sites were read directly from source, not inferred
- Pitfalls: HIGH — Pitfalls 1-3 are derived from actually tracing the existing code paths (2 raw `UserDefaults` read sites, 3 accent-consumption sites, the `#if DEBUG` opaque-type precedent); Pitfall 4 (window sizing) is a reasonable prediction flagged as needing on-device confirmation, consistent with CONTEXT.md's own framing

**Research date:** 2026-07-12
**Valid until:** 60 days (stable first-party SwiftUI APIs + a slow-moving internal codebase; re-verify call-site line numbers if Phase 25/26 code shifts significantly before Phase 27 executes)
