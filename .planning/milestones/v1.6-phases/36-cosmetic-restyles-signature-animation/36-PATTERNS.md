# Phase 36: Cosmetic Restyles & Signature Animation - Pattern Map

**Mapped:** 2026-07-16
**Files analyzed:** 6 (all modifications inside/around one existing file, plus one new font/build touchpoint and one Settings row)
**Analogs found:** 6 / 6 (all in-repo; no external analog needed — all three restyles are edits to existing structures in the same file)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|--------------------|------|-----------|-----------------|----------------|
| `Islet/Notch/NotchPillView.swift` → `wings(for:)` (charging HUD) | component | request-response (state→view) | same file, `deviceWings(for:)` (already the sibling wing) | exact (same file, same pattern family) |
| `Islet/Notch/NotchPillView.swift` → `deviceWings(for:)` / `deviceTrailing` (Bluetooth HUD) | component | request-response (state→view) | same file, `wings(for:)` (sibling wing) | exact |
| `Islet/Notch/NotchPillView.swift` → `EqualizerBars` struct | component | event-driven (clock-driven animation) | same struct, previous version (self-analog) + `ProgressBar` (shares `TimelineView(.animation(paused:))` gate) | exact |
| `Islet/Notch/NotchPillView.swift` → `onboardingWelcomeStep` + NEW signature-stroke view | component | transform (text → per-glyph Path → animated stroke) | `Islet/Notch/BatteryIndicator.swift` (standalone small reusable `View` struct, self-contained drawing logic) + `EqualizerBars` (per-element animated geometry) | role-match (genuinely new code, no exact prior analog for glyph-path stroke reveal) |
| `project.yml` (font resource + Info.plist font-registration) | config | batch (build-time resource registration) | same file's existing `INFOPLIST_KEY_*` / `packages:` entries | role-match |
| `Islet/SettingsView.swift` → `aboutSection` (Skiper UI credit row) | component | CRUD (static display row) | same file, `LabeledContent("Version")` row in `aboutSection` | exact |
| `IsletTests/EqualizerBarsTests.swift` (new reroll-logic test) | test | transform | same file, existing `testMakeProfilesReturnsBarCountProfiles` / `testMakeProfilesValuesAreWithinExpectedRanges` | exact |

## Pattern Assignments

### `wings(for:)` — Charging HUD restyle (HUD-02)

**Analog:** `deviceWings(for:)` in the same file (they are deliberately parallel siblings — see D-01 "chrome reskin of the existing split-wing structure")

**Current code to restyle** (`Islet/Notch/NotchPillView.swift` lines 1919-1938):
```swift
private func wings(for activity: ChargingActivity) -> some View {
    let isCharging: Bool
    let percent: Int
    switch activity {
    case .charging(let p): isCharging = true;  percent = p
    case .full(let p):     isCharging = false; percent = p
    case .onBattery(let p):isCharging = false; percent = p
    }
    return wingsShape {
        HStack(spacing: 0) {
            Image(systemName: "bolt.fill")                       // D-05 status symbol LEFT (charging cue)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(isCharging ? Color.green : Color.white.opacity(0.6))
                .padding(.leading, 12)
            Spacer()                                             // clears the physical camera bridge
            BatteryIndicator(level: percent, accent: chargingAccent)     // RIGHT — same indicator as the device glance
                .padding(.trailing, 14)
        }
    }
}
```

**Restyle target (per UI-SPEC "Left wing" table):** insert a conditional `Text("Charging")` at `HStack(spacing: 4)` next to the bolt icon, shown only when `isCharging == true`; bolt icon gains explicit `.font(.system(size: 13, weight: .semibold))`. Right wing (`BatteryIndicator`) is unchanged verbatim — do not touch.

**Shared wrapper (do not modify, just call into):** `wingsShape` (lines 1895-1912) — the flat-strip shape + `matchedGeometryEffect` + `liquidGlassEffectLayer` + `onTapGesture` wrapper both wings already share. Reuse verbatim.

---

### `deviceWings(for:)` / `deviceTrailing` — Bluetooth HUD restyle (HUD-01)

**Analog:** `wings(for:)` (sibling, restyled in parallel — same left/right pattern)

**Current code to restyle** (lines 2036-2074):
```swift
private func deviceWings(for activity: DeviceActivity) -> some View {
    let glyph: DeviceGlyph
    let isConnected: Bool
    let battery: Int?
    switch activity {
    case .connected(_, let g, let b): glyph = g; isConnected = true;  battery = b
    case .disconnected(_, let g):     glyph = g; isConnected = false; battery = nil
    }
    let iconOpacity = isConnected ? 1.0 : 0.5   // D-03: disconnected dims the icon
    return wingsShape {
        HStack(spacing: 0) {
            Image(systemName: deviceSymbol(for: glyph))   // LEFT wing — device glyph (D-02)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(deviceAccent.opacity(iconOpacity))
                .padding(.leading, 12)
            Spacer()                                      // clears the physical camera bridge
            deviceTrailing(isConnected: isConnected, battery: battery)   // RIGHT wing
                .padding(.trailing, 14)
        }
    }
}

@ViewBuilder
private func deviceTrailing(isConnected: Bool, battery: Int?) -> some View {
    if isConnected, let battery {
        BatteryIndicator(level: battery)
    } else {
        Image(systemName: isConnected ? "checkmark" : "xmark")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(isConnected ? deviceAccent : Color.white.opacity(0.5))
    }
}
```

**Restyle target:** left wing gains conditional `Text("Connected")` (only when `isConnected == true`) at `HStack(spacing: 4)`, same treatment as charging. `deviceTrailing`'s `isConnected && battery == nil` branch swaps the `checkmark` `Image` for a fixed-green ring: `Circle().strokeBorder(Color.green, lineWidth: 1.5).frame(width: 14, height: 14)`. The `isConnected && battery != nil` branch (`BatteryIndicator`) and the `!isConnected` (`xmark`, dimmed) branch are unchanged verbatim.

**Fixed-green-ring precedent to model the new `Circle()` case after:** `BatteryIndicator.swift`'s own `RoundedRectangle(cornerRadius: corner).stroke(Color.white.opacity(0.5), lineWidth: 1)` outline layer (lines ~40-42) — same "stroke-only outline shape at a fixed size" idiom, just swap `RoundedRectangle`→`Circle`, fixed color, no fill.

---

### `EqualizerBars` — new bar geometry + periodic-reroll-and-spring motion (EQ-01)

**Analog:** the struct's own current implementation (self-analog for what to keep) + `ProgressBar` (shares the `TimelineView(.animation(paused:))` idle-CPU gate discipline that must survive)

**Current full struct** (`Islet/Notch/NotchPillView.swift` lines 2330-2391):
```swift
struct EqualizerBars: View {
    let isPlaying: Bool                 // D-04: the SINGLE gate
    var tint: Color = .white
    private static let barCount = 5     // discretion: 3–5

    @State private var profiles: [(low: CGFloat, high: CGFloat, period: Double, phase: Double)] = EqualizerBars.makeProfiles()

    private let boxHeight: CGFloat = 16

    // internal (not private): EqualizerBarsTests.swift calls this directly to sanity-check
    // the extracted factory — `private` is file-scoped and would not compile from another
    // file even under @testable import.
    static func makeProfiles() -> [(low: CGFloat, high: CGFloat, period: Double, phase: Double)] {
        (0..<barCount).map { _ in
            (low: CGFloat.random(in: 3...6),
             high: CGFloat.random(in: 10...16),
             period: Double.random(in: 0.55...1.05),
             phase: Double.random(in: 0...1))
        }
    }

    var body: some View {
        TimelineView(.animation(paused: !isPlaying)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<Self.barCount, id: \.self) { i in
                    Capsule()
                        .fill(tint)
                        .frame(width: 2.5, height: height(i, at: t))
                }
            }
            .frame(height: boxHeight)
        }
    }

    private func height(_ i: Int, at t: TimeInterval) -> CGFloat {
        let p = profiles[i]
        guard isPlaying else { return p.low }
        let frac = sin((t / p.period + p.phase) * 2 * .pi) * 0.5 + 0.5   // 0...1
        return p.low + (p.high - p.low) * frac
    }
}
```

**Idle-CPU gate precedent (D-08, non-negotiable — the pattern to preserve exactly):** `ProgressBar` (lines 2400-2453) applies the SAME `TimelineView(.animation(paused: !(...)))` gate to a different clock (elapsed-time-driven, not sine-driven) — proof this gate composes with any per-frame computation, not just the sine formula. Model the periodic-reroll's "stop entirely while `!isPlaying`" behavior on this same `paused:` boolean, not a separate `Timer`.

**Rewrite target (per UI-SPEC Equalizer Motion Contract):**
- `Capsule().frame(width: 2.5, ...)` → `width: 1`
- `HStack(spacing: 2)` → `spacing: 4`
- `tint: Color = .white` stays the default; **drop `tint: nowPlayingAccent` at both call sites** (lines 2001 and 2191) so the struct's own default takes over — do not pass an accent argument at all.
- Replace `makeProfiles()`'s `(low, high, period, phase)` per-bar model with a periodic-reroll target-height model — keep the `internal` (not `private`) access level on whatever replaces `makeProfiles()`, per the `EqualizerBarsTests.swift` testability precedent below.
- Paused state: ALL bars snap to the SAME fixed 4pt height (not per-bar low/high anymore).

**Call sites to update** (drop `tint:` argument):
```swift
// Line 2001 (mediaWingsRow, collapsed wing):
EqualizerBars(isPlaying: isPlaying, tint: nowPlayingAccent)  // → EqualizerBars(isPlaying: isPlaying)

// Line 2191 (mediaExpanded):
EqualizerBars(isPlaying: isPlaying, tint: nowPlayingAccent)   // → EqualizerBars(isPlaying: isPlaying)
```

**Test precedent to extend** (`IsletTests/EqualizerBarsTests.swift`, full current file):
```swift
import XCTest
@testable import Islet

final class EqualizerBarsTests: XCTestCase {
    func testMakeProfilesReturnsBarCountProfiles() {
        let profiles = EqualizerBars.makeProfiles()
        XCTAssertEqual(profiles.count, 5, "makeProfiles() must return exactly EqualizerBars.barCount profiles.")
    }

    func testMakeProfilesValuesAreWithinExpectedRanges() {
        let profiles = EqualizerBars.makeProfiles()
        for profile in profiles {
            XCTAssertTrue((3...6).contains(profile.low), "...")
            XCTAssertTrue((10...16).contains(profile.high), "...")
            XCTAssertTrue((0.55...1.05).contains(profile.period), "...")
            XCTAssertTrue((0...1).contains(profile.phase), "...")
        }
    }
}
```
Follow this exact shape for the new reroll-generation function's test: assert bar count, assert each target height falls in `4...14`, keep the new factory function `internal` (not `private`) so this test file can call it directly under `@testable import` — same reasoning documented inline in the test file's own header comment.

---

### `onboardingWelcomeStep` + NEW signature-stroke view (ONBOARD-04)

**Analog for the surrounding step (edit, not replace):** the step itself, `Islet/Notch/NotchPillView.swift` lines 1480-1491 (current, to be partially replaced):
```swift
private var onboardingWelcomeStep: some View {
    VStack(alignment: .center, spacing: 8) {
        Text("Meet Islet")
            .font(.system(size: 20, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
        Text("Your notch, upgraded. Now Playing, charging, and a drag-and-drop shelf — always one glance away.")
            .font(.system(size: 12, weight: .regular, design: .rounded))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
}
```
Only the first `Text("Meet Islet")` line is replaced by the new signature view; the body `Text` below (identical string, styling, position) is untouched verbatim (D-13).

**Analog for the NEW standalone animated view (no exact prior analog — this is genuinely new code, per UI-SPEC's own note):** structure the new signature-stroke view as its own small `View` struct, following the two closest precedents in this codebase for "a small, self-contained, reusable drawing/animation View struct":

1. `Islet/Notch/BatteryIndicator.swift` (full file, reproduced above under Bluetooth analog) — the precedent for "one small standalone `View` struct in its own file, taking simple value parameters (`level`, `accent`), doing its own `Shape`/`Path`-based drawing with no external dependencies." Model the new file's shape (e.g. `Islet/Notch/SignatureHeading.swift`) on this: one file, one struct, plain stored properties, a computed `body`.
2. `EqualizerBars` (this file) — the precedent for "a `View` struct driving its own per-element animation via `@State` + `TimelineView`/`.animation(value:)`," and specifically the comment-driven discipline of explaining WHY each animation mechanism was chosen (see its extensive inline comments on `@State`'s initial-value-once-per-identity behavior). Apply the same comment discipline to the new glyph-stroke-reveal mechanism (Core Text `CTFontCreatePathForGlyph` → `Path` → `.trim(from:to:)`), since it is the least precedented mechanism in this phase.

**Round-numbered comment convention to follow** (established in this exact function's own history, lines 1474-1479):
```swift
// Step 1 — Welcome. Copywriting Contract: exact strings, verbatim. Round 2 (Droppy
// comparison) — heading/body now centered (was `.leading`); ...
```
Any new restyle round in this file follows this "Round N (reason)" comment convention — apply it to the new signature-view integration point.

---

## Shared Patterns

### `wingsShape` — shared flat-strip chrome wrapper
**Source:** `Islet/Notch/NotchPillView.swift` lines 1895-1912
**Apply to:** both `wings(for:)` and `deviceWings(for:)` — reuse verbatim, do not replace or duplicate. Both HUD restyles are chrome content changes INSIDE this wrapper's `content()` closure only.
```swift
private func wingsShape<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    let shape = NotchShape(topCornerRadius: 12, bottomCornerRadius: 6)
    return shape
        .fill(islandFill)
        .matchedGeometryEffect(id: "island", in: ns)
        .frame(width: Self.wingsSize.width, height: Self.wingsSize.height)
        .overlay(liquidGlassEffectLayer(shape: shape, size: Self.wingsSize, parameters: .expanded))
        .overlay(content().frame(width: Self.wingsSize.width, height: Self.wingsSize.height))
        .onTapGesture { onClick() }
}
```

### Idle-CPU gate — `TimelineView(.animation(paused:))`
**Source:** `EqualizerBars` (current, lines 2369-2380) and `ProgressBar` (lines 2406-2444) — twice-precedented pattern
**Apply to:** the new `EqualizerBars` reroll mechanism (D-08, non-negotiable). Whatever periodic-reroll timing mechanism replaces the sine formula, it must sit INSIDE (or be gated by) the same `TimelineView(.animation(paused: !isPlaying))` — no separate always-running `Timer`.

### Fixed (non-accent) color for meaning-carrying state
**Source:** `wings(for:)`'s bolt icon (`isCharging ? Color.green : Color.white.opacity(0.6)`, line 1931) and `BatteryIndicator`'s low-battery amber/red thresholds (`Islet/Notch/BatteryIndicator.swift` lines 22-26)
**Apply to:** the new Bluetooth-connected green ring (right wing) and the ONBOARD-04 signature's fixed `Color.orange` — both are literal, never `deviceAccent`/`nowPlayingAccent`/`chargingAccent`-tinted, consistent with this existing convention.

### Settings About/Credits row
**Source:** `Islet/SettingsView.swift` `aboutSection` (lines 249-278), specifically the `LabeledContent("Version")` row pattern:
```swift
private var aboutSection: some View {
    Form {
        Section("License") { /* ... */ }
        LabeledContent("Version") {
            Text(Self.versionString)
        }
    }
    .padding(20)
}
```
**Apply to:** the Skiper UI attribution line (locked credit text: `"Equalizer bar animation inspired by Skiper UI (skiper25.com)"`). Add either a new `LabeledContent`-style row or a small `Section("Credits")` inside this same `Form`, following the existing `Section(...)`/`LabeledContent(...)` idiom — do not introduce a new list/UI primitive.

### Build-config resource registration (new font)
**Source:** `project.yml`'s existing `INFOPLIST_KEY_*` entries under `targets.Islet.settings.base` (e.g. `INFOPLIST_KEY_NSBluetoothAlwaysUsageDescription`) and the `packages:` block for pinned external resources
**Apply to:** registering `Dancing-Script-Bold.ttf` as an app-provided font. No prior font-registration precedent exists in this codebase (confirmed — zero `ATSApplicationFontsPath`/`UIAppFonts`/`.ttf`/`.otf` hits repo-wide), so this is genuinely new build-config surface, not a restyle of an existing entry. Add the font file under `Islet/` (auto-discovered per `project.yml`'s own header comment: "Source files are discovered from the `Islet/` folder"), then add an `INFOPLIST_KEY_ATSApplicationFontsPath` (or equivalent) entry alongside the other `INFOPLIST_KEY_*` lines, following the same inline-comment-per-key convention already used throughout that settings block (each existing key has a "why" comment above it — do the same for the new one).

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| New signature-stroke `View` struct (e.g. `Islet/Notch/SignatureHeading.swift`) — the per-glyph `CTFontCreatePathForGlyph` → `Path` → `.trim(from:to:)` stroke-reveal mechanism itself | component | transform (text → vector paths → animated stroke) | No prior code in this repo extracts glyph vector paths or does `.trim`-based path-reveal animation — `EqualizerBars`/`ProgressBar`/`BatteryIndicator` are the closest structural analogs (self-contained `View` struct, animation-gated) but none does Core Text glyph extraction. Planner should reference `reference-signature-component.md` (the ported source) for the animation contract and treat this as new code following the file/struct-organization conventions listed above. |

## Metadata

**Analog search scope:** `Islet/Notch/NotchPillView.swift` (primary — all three restyle sites + shared wrappers `wingsShape`, `EqualizerBars`, `ProgressBar`), `Islet/Notch/BatteryIndicator.swift` (standalone small-View-struct precedent), `Islet/SettingsView.swift` (About/Credits row precedent), `IsletTests/EqualizerBarsTests.swift` (test precedent), `project.yml` (build-config precedent).
**Files scanned:** 5
**Pattern extraction date:** 2026-07-16
