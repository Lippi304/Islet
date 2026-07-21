# Phase 51: Settings Reorganization & Scroll Fix - Pattern Map

**Mapped:** 2026-07-21
**Files analyzed:** 1 (single-file restructuring, no new files)
**Analogs found:** 1 / 1 (self-referential — new sections are extractions of existing `Section` blocks in the same file)

This phase touches exactly one file: `Islet/SettingsView.swift`. There is no other file in the repo to pull patterns from for the sidebar/detail-pane structure — the analog for every new piece is an existing piece of this same file. The only *external* analog needed is for the scroll-fix mechanism itself (Section 2 below), since `SettingsView.swift` currently has no `ScrollView` at all.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|--------------------|------|-----------|-----------------|----------------|
| `Islet/SettingsView.swift` (modified in place) | component (SwiftUI View) | request-response (user toggles state → `@AppStorage`/`@State` write) | itself (Phase 27 sections within the same file) | exact — same file, same conventions, just re-sliced |

No files are created. No new subsystem, model, service, or controller is touched — `@AppStorage` keys, `ActivitySettings`, `LaunchAtLogin`, `LicenseState`, etc. are all read as-is with zero signature changes.

## Pattern Assignments

### `SettingsView.swift` — `SidebarSection` enum (role: config/enum, data flow: N/A)

**Analog:** itself, lines 80-102 (current 4-case enum)

**Current pattern to extend** (lines 80-102):
```swift
private enum SidebarSection: String, CaseIterable, Identifiable {
    case general, workspace, system, about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .workspace: return "Workspace"
        case .system: return "System"
        case .about: return "About"
        }
    }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .workspace: return "tray"
        case .system: return "paintbrush"
        case .about: return "info.circle"
        }
    }
}
@State private var selection: SidebarSection? = .general
```

**Target shape** (per CONTEXT.md D-01–D-06): replace `.general`/`.system` with 5 new cases, keep `.workspace`/`.about`, reorder per D-06:
```swift
private enum SidebarSection: String, CaseIterable, Identifiable {
    case activities, appearance, fullscreen, weather, diagnostics, workspace, about
    // title/icon switches follow the SAME shape, same order (D-06):
    // Activities → "bolt" (or similar, Claude's discretion D-04)
    // Appearance → "paintbrush" (carried over from .system, D-01/D-04)
    // Fullscreen → "arrow.up.left.and.arrow.down.right" (Claude's discretion)
    // Weather → "cloud.sun" (Claude's discretion)
    // Diagnostics → "stethoscope" or "wrench" (Claude's discretion)
    // Workspace → "tray" (unchanged)
    // About → "info.circle" (unchanged)
}
@State private var selection: SidebarSection? = .activities  // was .general — new default landing tab
```
Also update the `switch selection` dispatch (lines 134-146) and its `.none` fallback (currently `generalSection`, must become `activitiesSection` or whichever case leads).

---

### `SettingsView.swift` — sidebar `Button`-based list (role: component, data flow: request-response)

**Analog:** itself, lines 106-132 — **DO NOT CHANGE THIS MECHANISM.**

**Pattern to preserve verbatim** (lines 106-132):
```swift
VStack(alignment: .leading, spacing: 2) {
    ForEach(SidebarSection.allCases) { section in
        Button {
            selection = section
        } label: {
            Label(section.title, systemImage: section.icon)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(selection == section ? Color.accentColor.opacity(0.25) : .clear)
                )
        }
        .buttonStyle(.plain)
    }
    Spacer()
}
.padding(8)
.navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
```
The inline comment at lines 107-112 explains WHY: `List(selection:)` was tried 3 times on this setup and never registered clicks (Plan 27-04). Since `SidebarSection.allCases` drives the `ForEach` automatically, adding cases to the enum is enough — no changes needed to this block itself. Just don't reintroduce `List(selection:)`.

---

### `SettingsView.swift` — new detail-pane sections (role: component, data flow: CRUD — reads/writes `@AppStorage`)

**Analog:** itself — each new section is a **direct extraction** of an existing `Section("...")` block currently nested inside `generalSection` (lines 194-302), promoted to its own top-level computed `var ...Section: some View`.

**Source `Section` blocks and their target destination:**

| New section | Extract from `generalSection`, lines | Contains |
|---|---|---|
| `activitiesSection` | 196-215 (Launch at Login, per D-02) + 219-275 (`Section("Activities")`) | Launch-at-login toggle + 8 activity toggles + Focus/OSD permission popovers + hint texts |
| `fullscreenSection` | 279-281 (`Section("Fullscreen")`) | Hide-notch-in-fullscreen toggle |
| `weatherSection` | 287-293 (`Section("Weather")`) | Weather style segmented picker |
| `diagnosticsSection` | 297-299 (`Section("Diagnostics")`) | Save Diagnostic Report button |
| `appearanceSection` | 428-446 (`systemSection`, renamed per D-01) | Appearance Style picker + Accent Colors swatch rows |

**Core `Form { }.padding(20)` wrapper pattern to replicate per new section** (shape taken from `systemSection`, lines 428-446 — the smallest clean example):
```swift
private var appearanceSection: some View {   // renamed from systemSection, D-01
    Form {
        Section("Appearance Style") {
            Picker("Style", selection: $materialStyle) {
                Text("Gradient").tag(MaterialStyle.gradient)
                Text("Solid Black").tag(MaterialStyle.solidBlack)
                Text("Liquid Glass").tag(MaterialStyle.liquidGlass)
            }
            .pickerStyle(.segmented)
        }
        Section("Accent Colors") {
            LabeledContent("Now Playing") { swatchRow(selection: $nowPlayingAccentIndex) }
            LabeledContent("Charging") { swatchRow(selection: $chargingAccentIndex) }
            LabeledContent("Device") { swatchRow(selection: $deviceAccentIndex) }
        }
    }
    .padding(20)
}
```
`swatchRow(selection:)` (lines 452-464) stays a shared private helper — no changes, still called from the same place.

**`activitiesSection` extraction detail** — this is the one non-trivial move since it merges Launch-at-Login (currently the top-level control before any `Section`, lines 196-215) into the `Section("Activities")` block per D-02. All the `.onChange`/`.popover` wiring travels with the `Toggle` it's attached to — no logic changes, purely relocation:
```swift
private var activitiesSection: some View {
    Form {
        Toggle("Launch Islet at login", isOn: $launchAtLogin)
            .onChange(of: launchAtLogin) { _, on in /* unchanged, lines 197-215 */ }

        Section("Activities") {
            Toggle("Charging", isOn: $chargingEnabled)
            // ...unchanged, lines 220-274 verbatim...
        }
    }
    .padding(20)
}
```
Since this is the tallest section (D-05 calls it out as needing scroll), wrap its `Form` in the `ScrollView` pattern below.

---

### `SettingsView.swift` — scroll-fix mechanism (role: component, data flow: N/A — layout only)

**Analog (external, cross-file):** `Islet/Notch/NotchPillView.swift:1260-1261` — the codebase's one existing `ScrollView(.vertical) { VStack {...} }` pattern for content that may overflow a fixed box:
```swift
// NotchPillView.swift:1260-1261
private func dayEventsList(_ dayEvents: [EventInput]) -> some View {
    ScrollView(.vertical) {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(...) { ... }
        }
    }
}
```

**Root cause of today's bug (for research/planning reference):** `Form` inside `NavigationSplitView`'s detail pane does NOT auto-scroll its content when the pane is height-constrained by a fixed outer `.frame` (line 189, `.frame(width: 520, height: 380)`) the way a `List` or `ScrollView` would — SwiftUI's `Form` on macOS lays out at its intrinsic height and clips silently when its container refuses to grow. The existing single `generalSection`'s `Form` (5 `Section`s stacked) is now tall enough that Weather/Diagnostics fall below the visible 380pt height with no scroll affordance.

**Fix pattern to apply** — wrap each new section's `Form` in an explicit `ScrollView(.vertical)`, following the `NotchPillView` convention:
```swift
private var activitiesSection: some View {
    ScrollView(.vertical) {
        Form {
            Toggle("Launch Islet at login", isOn: $launchAtLogin) /* ... */
            Section("Activities") { /* 8 toggles, unchanged */ }
        }
        .padding(20)
    }
}
```
Per D-05, only `activitiesSection` needs this in practice (tallest, 8 toggles + Launch-at-Login + conditional hint text) — `fullscreenSection`/`weatherSection`/`diagnosticsSection` are short enough to fit the 380pt frame without scrolling. Applying `ScrollView` uniformly to all 5 new sections is still the lazier/safer choice (one wrapper pattern everywhere, no per-section judgment calls, no visual difference when content already fits) — planner's call on whether to apply it universally or only to Activities.

---

## Shared Patterns

### Fixed window frame + Liquid Glass background (unaffected by section split)
**Source:** `SettingsView.swift:171-189`
**Apply to:** No changes needed — this lives at the `NavigationSplitView` level, outside the per-section `switch`, and applies uniformly regardless of which section is selected.
```swift
.background {
    if materialStyle == .liquidGlass {
        ZStack {
            LinearGradient(stops: [...], startPoint: .top, endPoint: .bottom)
            Color.clear.background(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
        }
    }
}
.frame(width: 520, height: 380)
```

### `@AppStorage`-backed state, declared at struct scope
**Source:** `SettingsView.swift:28-76`
**Apply to:** All 5 new sections — no state relocation needed, every `@AppStorage`/`@State` var stays declared once at `SettingsView` struct scope (lines 6-77) regardless of which computed `var ...Section` reads/writes it. Moving a `Toggle`/`Picker` to a new section is a pure UI relocation, zero state-ownership change.

### `Form { }.padding(20)` per-section wrapper
**Source:** `SettingsView.swift` — `workspaceSection` (373-384, no Form, placeholder-only), `aboutSection` (388-424), `systemSection`/`appearanceSection` (428-446)
**Apply to:** All 5 new sections use `Form { ... }.padding(20)` (optionally wrapped in `ScrollView`, see above) — matches the existing `aboutSection`/`systemSection` shape exactly, so no new layout idiom is introduced.

## No Analog Found

None. Every piece of every new section already exists verbatim in `SettingsView.swift` today (per CONTEXT.md's own note: "the split is mostly promoting existing `Section` blocks to their own top-level `SidebarSection` detail views, not writing new UI from scratch"). The single external analog needed (`ScrollView` wrapping) was found in `NotchPillView.swift:1260-1261`.

## Metadata

**Analog search scope:** `Islet/` (single-file phase; `NotchPillView.swift` grepped for `ScrollView` precedent)
**Files scanned:** `Islet/SettingsView.swift` (568 lines, full read), `Islet/Notch/NotchPillView.swift` (targeted grep + 30-line read at scroll-pattern location)
**Pattern extraction date:** 2026-07-21
