# Phase 59: Settings-Redesign - Pattern Map

**Mapped:** 2026-07-23
**Files analyzed:** 6
**Analogs found:** 5 exact/role-match / 6 (1 net-new component with no direct analog, closest partial matches identified)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|-----------------|----------------|
| `Islet/ActivityCard.swift` (NEW) | component | request-response (renders `ActivityCardData` + emits `Binding<Bool>`/closure) | `Islet/SettingsView.swift` — `permissionRow(kind:label:icon:reason:status:)` (lines 468-490) + `focusPermissionExplanationView`/`osdPermissionExplanationView` (lines 570-630) | partial (no card/grid component exists anywhere; closest is this icon+label+secondary-text row + the popover pattern) |
| `Islet/SettingsView.swift` (MODIFIED — `activitiesSection` rebuilt) | component (SwiftUI View, section body) | CRUD (`@AppStorage` read/write via `Toggle`) | itself — current `activitiesSection` (lines 262-348), plus `permissionsSection` (lines 428-456) for the "VStack of custom rows inside ScrollView+Form" shape | exact (same file, same section, direct precedent) |
| `Islet/ActivitySettings.swift` (MODIFIED — +8 keys) | config/model (key namespace) | CRUD (UserDefaults key constants) | itself — existing key declarations block (lines 14-33) | exact |
| `Islet/Notch/IslandResolver.swift` (MODIFIED — doc-comment table only) | model/service (pure resolver, doc-only change) | transform (no functional change) | itself — `IslandPresentation` enum rank comments (lines 61-77) + file-header comment block (lines 1-33) | exact |
| `IsletTests/ActivitySettingsTests.swift` (MODIFIED — +tests) | test | CRUD (key/default assertions) | itself — `testNewKeyNames` (lines 32-37), `testFocusKeyName` (77-79), `testMigrationSeedsAllThreeKeysFromLegacyAccentIndex` (51-60) | exact |
| `IsletTests/ActivityCardTests.swift` (NEW, optional — card-array ordering/count assertions) | test | CRUD | `IsletTests/SettingsViewTests.swift` (full file, 33 lines) — plain `XCTestCase` testing a pure static func | role-match |

## Pattern Assignments

### `Islet/ActivityCard.swift` (component, request-response) — NEW FILE, no direct analog

**Analog 1 — icon+label+secondary-text row shape:** `Islet/SettingsView.swift:468-490`
```swift
private func permissionRow(kind: PermissionKind, label: String, icon: String,
                            reason: String, status: PermissionStatus) -> some View {
    Button {
        handlePermissionTap(kind: kind, status: status)
    } label: {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 13))
                Text(reason)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            statusView(for: status)
        }
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(status == .granted)
}
```
Copy the icon + `VStack(title, secondary description)` + trailing-control layout shape (`HStack` with `Spacer()` before the trailing control). `ActivityCard` swaps `statusView(for:)` for `Toggle(isOn:)` + optional "Neu" badge + optional options-chevron, and wraps the whole thing in `RoundedRectangle(cornerRadius: 10)` per UI-SPEC's Card Component Contract instead of a plain `Button`.

**Analog 2 — options-popover reuse (D-08/D-09/D-10):** `Islet/SettingsView.swift:298-337` (existing Focus/OSD toggle + popover wiring, to be relocated into the card)
```swift
Toggle("Focus Mode HUD", isOn: $focusEnabled)
    .onChange(of: focusEnabled) { _, on in
        if on && !FocusModeMonitor.isAuthorized {
            showFocusPermissionExplanation = true
        }
    }
    .popover(isPresented: $showFocusPermissionExplanation) {
        focusPermissionExplanationView
    }
```
`ActivityCard` should accept `onOptionsTap: (() -> Void)?` (nil for 13/15 cards) — do NOT build a generic `.popover(item:)` router; the popover itself stays exactly where it is today (`focusPermissionExplanationView`/`osdPermissionExplanationView`, lines 570-630, unmodified), just triggered from the card's new chevron instead of a `Form` row's trailing hint text.

**Data model shape (from RESEARCH.md Pattern 1, already codebase-consistent style):**
```swift
@AppStorage(ActivitySettings.chargingKey)   private var chargingEnabled = true
@AppStorage(ActivitySettings.capsLockKey)   private var capsLockEnabled = false  // NEW, v1.10, default OFF

private var systemHUDCards: [ActivityCardData] {
    [
        ActivityCardData(id: "charging", title: "Charging", description: "…",
                          icon: "bolt.fill", isOn: $chargingEnabled, isNew: false, onOptionsTap: nil),
        // …
    ]
}
```

---

### `Islet/SettingsView.swift` (`activitiesSection` rebuild, component, CRUD)

**Analog:** itself, `activitiesSection` (lines 262-348) — current flat `Form`/`Section("Activities")` shape being replaced, and `permissionsSection` (lines 428-456) — the closest existing precedent for "custom-rendered rows (not `Toggle` inline) inside `ScrollView(.vertical) { Form { ... } }`".

**Current activitiesSection (to be replaced), full pattern incl. permission-gated toggle + popover + hint text:**
```swift
private var activitiesSection: some View {
    ScrollView(.vertical) {
        Form {
            Toggle("Launch Islet at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, on in /* … */ }

            Section("Activities") {
                Toggle("Charging", isOn: $chargingEnabled)
                // …
                Toggle("Focus Mode HUD", isOn: $focusEnabled)
                    .onChange(of: focusEnabled) { _, on in
                        if on && !FocusModeMonitor.isAuthorized {
                            showFocusPermissionExplanation = true
                        }
                    }
                    .popover(isPresented: $showFocusPermissionExplanation) {
                        focusPermissionExplanationView
                    }
                Toggle("Automatically Check for Updates", isOn: $autoUpdateCheckEnabled)
            }
        }
        .padding(20)
    }
}
```

**`permissionsSection`'s "custom row list, not inline Toggle" shape (closest precedent for a non-`Form`-row component list inside the same `ScrollView`):**
```swift
private var permissionsSection: some View {
    ScrollView(.vertical) {
        Form {
            Section("Permissions") {
                Text("\(grantedPermissionCount) of 5 granted")
                    .font(.system(size: 15, weight: .semibold))
                VStack(spacing: 8) {
                    permissionRow(kind: .location, label: "Location", icon: "location.fill",
                                  reason: "Power live weather in your glance", status: locationStatus)
                    // … 4 more rows
                }
            }
        }
        .padding(20)
    }
}
```
The new grid keeps the SAME single `ScrollView(.vertical)` wrapper (Pitfall 3 / UI-SPEC Verification Notes: exactly ONE `ScrollView` for the whole section — plain-toggle block + all 3 category `LazyVGrid`s together, never a nested second scroll region), but drops the outer `Form` for the grid portion (RESEARCH.md Anti-Patterns: `Form` row chrome fights the card design) — only the top "Launch at login"/"Automatically Check for Updates" block keeps `Form`.

**Error handling pattern (Launch-at-login, unrelated to grid but stays untouched in the same section):** `SettingsView.swift:265-284` — `do/catch` around `LaunchAtLogin.set(on)`, reverting `@State` on failure. No change needed here; just relocate verbatim to the top of the rebuilt section per D-05/UI-SPEC "Non-card items" placement.

---

### `Islet/ActivitySettings.swift` (+8 keys, config/model, CRUD)

**Analog:** itself, existing key-declaration block (lines 14-33)
```swift
static let chargingKey   = "activity.charging"
static let nowPlayingKey = "activity.nowPlaying"
static let songChangeToastKey = "activity.songChangeToast"
static let deviceKey     = "activity.device"
static let calendarCountdownKey = "activity.calendarCountdown"
static let focusKey = "activity.focus"          // defaults false — the ONE existing off-by-default key
static let osdSuppressionKey = "activity.osdSuppression"  // also defaults false
static let autoUpdateCheckKey = "activity.autoUpdateCheck"
```
Add the 8 new keys in the same flat `static let` style, exact strings locked by `59-UI-SPEC.md`'s "New Persisted Keys" table (`activity.capsLock`, `activity.downloadProgress`, `activity.menuBarOverflow`, `activity.timer`, `activity.meetingHUD`, `activity.quickNotes`, `activity.quickActions`, `activity.codingProgress`). Every new key's `@AppStorage` declaration (in `SettingsView.swift`) MUST read `= false` — 5 of 7 existing keys default `true`, so do not copy those as a template (Pitfall 1).

**No migration function needed** — `migrateLegacyAccentIfNeeded()` (lines 124-137) is cited in CONTEXT.md only as the discretion-precedent pattern; per RESEARCH.md's Don't-Hand-Roll table this phase needs NO migration code at all (brand-new keys, absent-key ⇒ default literal is Swift's own free behavior). Do not add a `migrateXIfNeeded()` for the 8 new keys.

---

### `Islet/Notch/IslandResolver.swift` (doc-comment table, model/service, transform-only)

**Analog:** itself — existing rank-comment convention on `IslandPresentation` (lines 61-77) and `ActiveTransient` (lines 81-85), plus the file-header comment block (lines 1-33) documenting precedence history/decisions inline.
```swift
enum IslandPresentation: Equatable {
    case onboarding(OnboardingStep)                        // Phase 26 D-09: highest priority -- forced flow, never pre-empted
    case idle
    case charging(ChargingActivity)                        // D-02 rank 1 transient
    case device(DeviceActivity)                            // D-02 rank 2 transient
    case focus(FocusActivity)                              // Phase 38 / HUD-05: rank 3 transient, collapsed-only (D-07)
    case osd(OSDActivity)                                  // Phase 39 / HUD-03/HUD-04: rank 4 transient, collapsed-only (D-11) …
    case nowPlayingWings(NowPlayingPresentation)           // D-02 rank 3 ambient (collapsed glance)
    case calendarCountdown(CalendarCountdownActivity)      // Phase 41 / HUD-08: ambient tier, D-01 always wins over nowPlayingWings
    // …
}
```
Copy this exact "named rank in a trailing `//` comment, not a raw int" convention for the new SC5 doc block (per CONTEXT.md's discretion note: "ranks are named comments, not raw ints — new v1.10 cases slot in between existing named ranks, not renumbered"). Place the new SC5 table as a comment block near this enum (UI-SPEC locks the location: colocated in this file, not a separate `.planning/` doc), documenting the CURRENT 4 tiers (0 onboarding, 1 `ActiveTransient` queue charging>device>focus>osd, 2 `isExpanded` branch, 3 non-expanded ambient) plus each of the 8 new activities with a `// rank TBD — confirm in that activity's own phase discussion` flag. Zero new `IslandPresentation`/`ActiveTransient` cases this phase — comment-only diff.

---

### `IsletTests/ActivitySettingsTests.swift` (+tests, test, CRUD)

**Analog — key-name assertion style:** `IsletTests/ActivitySettingsTests.swift:32-37, 77-79`
```swift
func testNewKeyNames() {
    XCTAssertEqual(ActivitySettings.materialStyleKey, "theming.materialStyle")
    XCTAssertEqual(ActivitySettings.nowPlayingAccentKey, "accent.nowPlaying")
    // …
}

func testFocusKeyName() {
    XCTAssertEqual(ActivitySettings.focusKey, "activity.focus")
}
```
Mirror this shape for the 8 new key-name assertions (covers UI-SPEC's locked key strings).

**Analog — pre-seeded `UserDefaults(suiteName:)` domain pattern (needed for SETTINGS-05 SC4's "not a fresh install" test):** `IsletTests/ActivitySettingsTests.swift:51-60`
```swift
func testMigrationSeedsAllThreeKeysFromLegacyAccentIndex() {
    let defaults = UserDefaults(suiteName: "ActivitySettingsTests-\(UUID().uuidString)")!
    defaults.set(3, forKey: ActivitySettings.accentIndexKey)

    ActivitySettings.migrateLegacyAccentIfNeeded(defaults: defaults)

    XCTAssertEqual(defaults.integer(forKey: ActivitySettings.nowPlayingAccentKey), 3)
    // …
}
```
Adapt this exact `UserDefaults(suiteName: "…-\(UUID().uuidString)")` isolation pattern for the new pre-seeded-domain test: `defaults.set(false, forKey: ActivitySettings.chargingKey)` (simulating a pre-upgrade user who turned Charging off) then assert the value read back is `false`, not the code's compiled-in `true` default — this is the one genuinely new test shape (RESEARCH.md Wave 0 Gaps), no direct precedent covers reading a seeded value through an `@AppStorage`-derived `Binding` specifically, but the `UserDefaults(suiteName:)` isolation + `defaults.set/get` shape is identical to this existing test.

**Default-value assertion for new keys (Pitfall 1 guard):**
```swift
// New pattern, composed from existing pieces above:
func testCapsLockKeyDefaultsFalse() {
    let defaults = UserDefaults(suiteName: "ActivitySettingsTests-\(UUID().uuidString)")!
    XCTAssertEqual(defaults.bool(forKey: ActivitySettings.capsLockKey), false)
}
```

---

### `IsletTests/ActivityCardTests.swift` (NEW, optional, test)

**Analog:** `IsletTests/SettingsViewTests.swift` (full file, 33 lines) — plain `XCTestCase` exercising a pure static func on `SettingsView.SidebarSection`:
```swift
final class SettingsViewTests: XCTestCase {
    func testVisibleSectionsIncludesSwitcherWhenHasNotchIsTrue() {
        let sections = SettingsView.SidebarSection.visibleSections(hasNotch: true)
        XCTAssertEqual(sections.count, SettingsView.SidebarSection.allCases.count)
        XCTAssertTrue(sections.contains(.switcher))
    }
}
```
If the card arrays (`systemHUDCards`/`mediaCards`/`productivityCards`) are exposed as testable (internal, not private — mirroring `SidebarSection`'s existing private→internal testability bump precedent, `SettingsView.swift:92-95` comment) computed properties, write count/ordering assertions in this same plain-`XCTestCase` style. If they stay `@AppStorage`-instance-bound and awkward to unit test directly, this file is optional — SETTINGS-04's grid-render requirement can fall to the manual on-device UAT checklist instead (RESEARCH.md's own Test Map already allows this).

---

## Shared Patterns

### `@AppStorage` static-property + key-namespace convention
**Source:** `Islet/ActivitySettings.swift:14-33` + `Islet/SettingsView.swift:29-64`
**Apply to:** `ActivityCard.swift`, `SettingsView.swift`, `ActivitySettings.swift`
```swift
@AppStorage(ActivitySettings.chargingKey) private var chargingEnabled = true
```
Never a dynamic string-keyed `@AppStorage` inside a `ForEach`/data array — every toggle (existing and new) stays an individually-declared property; the card array wraps each one's `$binding` at `body`-build time.

### Single-`ScrollView` overflow convention
**Source:** `Islet/SettingsView.swift:262-348` (current `activitiesSection`), reconfirmed by every other section (`fullscreenSection`, `permissionsSection`, `diagnosticsSection`) — always exactly one `ScrollView(.vertical) { Form { ... } }` or `ScrollView(.vertical) { VStack { ... } }` per section body.
**Apply to:** rebuilt `activitiesSection` — one `ScrollView` wraps the plain-toggle block AND all 3 category grids together, never a second nested scroll region (Pitfall 3, Phase 51 precedent).

### Named-rank comment convention (not raw ints)
**Source:** `Islet/Notch/IslandResolver.swift:61-77`
**Apply to:** the new SC5 doc-comment table in the same file — `// D-02 rank 1 transient`-style trailing comments, new v1.10 activities slotted in between existing named ranks with an explicit `rank TBD` flag where unconfirmed.

### `UserDefaults(suiteName: "…-\(UUID().uuidString)")` test-isolation pattern
**Source:** `IsletTests/ActivitySettingsTests.swift:41-49, 51-60, 62-73`
**Apply to:** all new tests in `ActivitySettingsTests.swift` (and `ActivityCardTests.swift` if written) — every test gets its own isolated `UserDefaults` suite, never touches `.standard`.

### Popover-per-toggle, no generic router
**Source:** `Islet/SettingsView.swift:298-337` (Focus) / `316-337` (OSD), views at lines 570-630
**Apply to:** `ActivityCard.swift`'s `onOptionsTap` closure param — reuse the exact existing `@State` bools (`showFocusPermissionExplanation`, `showOSDPermissionExplanation`) and popover views unmodified; do not build a keyed/item-based popover router for 2 of 15 cards.

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `Islet/ActivityCard.swift` (the `LazyVGrid`/card-grid container itself, as opposed to the row-shape excerpt above) | component | request-response | No `LazyVGrid`/`GridItem` usage and no `Card`/badge component exists anywhere in this codebase (confirmed in RESEARCH.md's own Reusable Assets section) — the grid layout and "Neu" badge are genuinely net-new SwiftUI, built directly from Apple's `LazyVGrid` API (RESEARCH.md Code Examples) rather than an in-codebase analog. |

## Metadata

**Analog search scope:** `Islet/SettingsView.swift`, `Islet/ActivitySettings.swift`, `Islet/Notch/IslandResolver.swift`, `IsletTests/ActivitySettingsTests.swift`, `IsletTests/SettingsViewTests.swift` (all read in full — largest file 859 lines, no file exceeded the 2,000-line targeted-read threshold)
**Files scanned:** 5 full-file reads + phase CONTEXT.md/RESEARCH.md/UI-SPEC.md
**Pattern extraction date:** 2026-07-23
