# Phase 3: Charging Activity - Research

**Researched:** 2026-06-27
**Domain:** IOKit power-source events (public API) → transient SwiftUI "activity" splash, integrated into the existing focus-safe NSPanel + interaction state machine
**Confidence:** HIGH (the riskiest piece — IOKit signatures and the Swift bridging idiom — was compile-verified against the installed SDK; all IOPSKeys values and SF Symbol names read directly from disk)

## Summary

Phase 3 wires the first real live activity. Plug/unplug events arrive through the **public IOKit power-source notification API** (`IOPSNotificationCreateRunLoopSource`) — there is no polling timer, no entitlement, and no TCC prompt. A pure function maps a raw power reading to a small presentation enum (`charging` / `full` / `onBattery` + `Int` percent), kept unit-testable in the Phase-1/2 TDD style. A new programmatic **activity** model on `NotchWindowController` (recommended: a separate `@Published` model, NOT a new `InteractionPhase` case) drives a new **wings/Alcove sideways layout** in `NotchPillView`, distinct from the existing downward morph. The ~3s auto-dismiss reuses the proven one-shot `graceWorkItem` `DispatchWorkItem` pattern, and the splash routes through the single `updateVisibility()` so it inherits fullscreen-hide and clamshell-hide for free.

The single highest-risk correctness item — how the IOKit C functions import into Swift — was **resolved by compiling against the SDK on this machine**: every `IOPSCopy*`/`IOPSCreate*`/`IOPSGet*` function imports as `Unmanaged<...>?`, so the code MUST use `.takeRetainedValue()` on the Copy/Create calls and `.takeUnretainedValue()` on `IOPSGetPowerSourceDescription`. A naive call without those crashes or leaks. This eliminates the most common bug in community examples (several of which incorrectly use `.takeRetainedValue()` on the Get function).

**Primary recommendation:** Add three pure-logic seams (a `PowerReading` input struct, a `ChargingActivity` output enum, and a `powerActivity(from:)` mapping function) + a thin `PowerSourceMonitor` IOKit wrapper that hops its callback to main and publishes a `ChargingActivity?` on a `ChargingActivityState` `ObservableObject`. Render it as a sideways wings layout in `NotchPillView` using a variable-value `battery.100percent` / `battery.100percent.bolt` SF Symbol. Drive show/auto-dismiss through `NotchWindowController` using the existing `graceWorkItem` template and `updateVisibility()`.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01 (CHG-01):** Wings / Alcove layout. The charging activity renders **beside the physical notch** — content flanks the camera bridge left + right — NOT the Phase-2 downward morph. The pill grows **wider and stays flat**. New layout/geometry direction; sets the skeleton for Phase 4 (Now Playing: album art left, controls/title right).
- **D-02 (CHG-01):** Programmatic, transient presentation. The splash appears **by itself** on the plug/unplug event — independent of Phase-2 click-to-expand. It is a **new presentation type ("activity")** alongside the user-driven hover/expand. (Exact relationship to `InteractionPhase` = Claude's discretion.)
- **D-03 (CHG-01):** Right side = a **filling battery glyph + numeric %**. Battery icon that fills to the current level, with the percentage number alongside.
- **D-04 (CHG-01/CHG-02):** **One consistent battery glyph encodes the state**, switching between: **bolt = actively charging** → **full / green at 100%** → **plain battery (no bolt) on unplug ("on battery")**. A single glyph that changes — NOT three separate per-state mini-scenes.
- **D-05 (CHG-01):** Charging/status symbol on the **left** of the notch as the starting layout (status symbol left, battery + % right). Exact wing placement/sizing = discretion + on-device tuning.
- **D-06 (CHG-01):** Info shown = **percentage only**. NO time-to-full, NO adapter wattage in v1 (→ v2).
- **D-07 (CHG-01):** **Lively appearance** — wings **slide out** sideways from the notch, the battery **fills once**, with a **brief glow/pulse** at the bolt (Alcove feel). Start from the Phase-2 spring vocabulary (response ≈ 0.35, dampingFraction ≈ 0.65); exact springs/durations are on-device tuning.
- **D-08 (CHG-01):** **One-shot appear + one-shot collapse — no looping/pulsing while standing.** Carries Phase-1 D-08 (idle-static) and the idle-CPU-~0% criterion. The only motion is the entrance, the optional one-time fill/glow, and the exit.
- **D-09 (CHG-01):** **Auto-dismiss after ~3 seconds**, then collapse. Implemented as a **single scheduled collapse** (`DispatchWorkItem`, mirroring `graceWorkItem`), NOT a recurring timer.
- **D-10 (CHG-01):** **Hover pauses the auto-dismiss**; once the pointer leaves, the ~3s resumes. **Click is informational only** — no special expansion or detail panel in v1.
- **D-11 (CHG-01):** **Charging splash takes brief precedence** if the user has the island open (user-expanded) when they plug in — show the feedback, then return to the ambient state. (General multi-activity resolver is Phase 6.)
- **Locked by ROADMAP success criteria (not negotiated):** Event-driven via `IOPSNotificationCreateRunLoopSource`; **no long-lived polling timer**; idle CPU ~0%. Distinguishes actively-charging from plugged-in-but-full (D-04) and behaves **sanely on a Mac with no readable charging state** (desktop / no battery → graceful no-op, no splash, no crash). **Hidden in true fullscreen** — Phase-2 D-09 still applies; route visibility through the single `updateVisibility()`.

### Claude's Discretion
- **The "activity" abstraction / mechanism** — a new activity case/state vs a separate `@Published` activity model on the controller. **Recommendation: charging-specific with a clean seam, NOT a general resolver** (Phase 6). No speculative abstraction (per CLAUDE.md). *(This research recommends the separate `@Published` model — see Architecture Pattern 2.)*
- **IOKit wiring** — `IOPSCopyPowerSourcesInfo` / `IOPSCopyPowerSourcesList`, `kIOPSIsChargingKey` / `kIOPSCurrentCapacityKey` / `kIOPSMaxCapacityKey`, `IOPSCopyExternalPowerAdapterDetails`, run-loop-source setup, and hopping the callback to the main thread. *(Fully resolved in Standard Stack + Code Examples below.)*
- **Exact wings geometry** (per-side width, gap to the camera bridge, how the panel frame spans across the notch), exact SF Symbols, and colors (e.g. green at full).
- **Spring/duration tuning**, glow intensity, and whether 100% shows a subtle checkmark.
- **A pure-logic seam** (TDD like Phase 1/2): a pure function mapping power-state → activity-presentation (`charging` / `full` / `onBattery` + `%`), unit-testable, with the IOKit/AppKit wiring verified on-device. *(Designed below — Architecture Pattern 1.)*

### Deferred Ideas (OUT OF SCOPE)
- **Time-to-full / adapter wattage** in the splash → v2 / later (D-06).
- **Click-to-open battery detail panel** → not v1; click stays informational (D-10).
- **General multi-activity priority resolver** (charging + media + device coexistence) → **Phase 6 (COORD-01)**. Phase 3 handles only charging-vs-user-interaction (D-11).
- **Per-state mini-scenes** (separate animations per state) → dropped in favor of the single consistent glyph (D-04).
- **Low-battery warning / battery HUD** → out of scope (later milestone; not even in the v2 HUD list).
- **Settings toggle** to enable/disable the charging activity + accent/theme → Phase 6 (APP-03).
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| **CHG-01** | Plugging in the power cable shows a charging animation plus battery percentage in the island for a few seconds, then collapses | IOKit notification source (Code Example 2) fires on plug-in → `powerActivity(from:)` returns `.charging(percent:)` or `.full(percent:)` (Pattern 1) → wings layout renders the filling `battery.*.bolt` glyph + % (Pattern 3) → `graceWorkItem`-style one-shot collapse after ~3s (Pattern 4 / D-09) |
| **CHG-02** | Unplugging shows a brief "on battery" indication | The SAME notification fires on unplug (state flips to `kIOPSBatteryPowerValue`) → `powerActivity(from:)` returns `.onBattery(percent:)` → same wings layout, plain (no-bolt) battery glyph (D-04) → same ~3s collapse |
| **COORD-01** | *(Phase 6 — referenced as the anchor for the deferred resolver)* | Out of scope here. Phase 3 implements ONLY charging-vs-user-interaction precedence (D-11). Keep the activity model charging-specific so the Phase-6 resolver can wrap it without a rewrite. |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

These are authoritative directives extracted from `CLAUDE.md` and the phase brief. The plan MUST NOT contradict them.

- **Swift 5 language mode** (not Swift 6 strict concurrency). `project.yml` sets `SWIFT_VERSION: "5.0"`. *(All Code Examples below were compile-verified in `-swift-version 5`.)*
- **Un-sandboxed** (`ENABLE_APP_SANDBOX: NO`). The IOKit power APIs work without a sandbox exception — but note that even sandboxed apps can read power sources; no entitlement is needed either way.
- **macOS 14.0 deployment floor** (`MACOSX_DEPLOYMENT_TARGET: "14.0"`). All IOPS APIs and the `battery.100percent` / `battery.100percent.bolt` SF Symbols are available at this floor (verified below).
- **No private framework for power** — Phase 3 deliberately uses the **public** IOKit power-source API (this is why charging is built before the MediaRemote-dependent Now Playing).
- **Use Apple's IOKit directly** — no third-party Bluetooth/power library (CLAUDE.md: "the surface you need is tiny").
- **Animation:** drive from a single state inside `withAnimation(.spring(response:dampingFraction:))`; use `matchedGeometryEffect` + shared `@Namespace`; **avoid Core Animation / hand-rolled CALayer**.
- **XcodeGen:** `project.yml` auto-discovers `Islet/**/*.swift`. After adding any new source file under `Islet/`, run `xcodegen generate`. New test files under `IsletTests/` are likewise auto-discovered. No manual `.xcodeproj` edits.
- **TDD seam:** pure logic (geometry, the power→presentation predicate) is unit-tested; the IOKit + AppKit/SwiftUI wiring is verified on-device.
- **Single show/hide site:** `updateVisibility()` is the SOLE `orderFront`/`orderOut` site (Pitfall in NotchWindowController). The splash MUST route through it — do not add a second show/hide call.
- **Code quality (global CLAUDE.md):** change only what must change; no speculative abstractions; no "cleanup" of unrelated code; security first.

## Toolchain Reality (verified on this machine)

[VERIFIED: `sw_vers` / `xcodebuild -version` / `swift --version` / `xcrun --show-sdk-version`]

| Component | Value | Implication |
|-----------|-------|-------------|
| macOS | **27.0 (Tahoe), build 26A5368g** | CLAUDE.md says 14/15; reality is newer. Power APIs unaffected; just be aware deprecation warnings could appear (none observed for IOPS). |
| Xcode | **26.6 (17F113)** | Builds fine. |
| Swift | **6.3.3 toolchain** in **Swift 5 language mode** | Confirmed: probe compiled clean with `-swift-version 5`. |
| macOS SDK | **MacOSX26.5.sdk** | IOKit headers + IOPSKeys read directly from here (highest confidence). |
| XcodeGen | **2.45.3** at `/opt/homebrew/bin/xcodegen` | Run `xcodegen generate` after adding sources. |
| Deployment floor | **macOS 14.0** | All required APIs + symbols available. |

## Standard Stack

No third-party libraries. Everything is Apple system frameworks (CLAUDE.md mandate).

### Core
| Framework / Module | Purpose | Why Standard |
|---------|---------|--------------|
| `import IOKit.ps` | Power-source state + the live plug/unplug notification | [VERIFIED: SDK header present at `…/IOKit.framework/Headers/ps/IOPowerSources.h`] The single public, entitlement-free API for charging state. CLAUDE.md "Power / charging detection". |
| `SwiftUI` | The wings activity view | [VERIFIED: existing `NotchPillView`] Already the UI layer. |
| `AppKit` (`NSPanel`, `NSHostingView`) | The overlay window the activity renders into | [VERIFIED: existing `NotchPanel` / `NotchWindowController`] Reused unchanged. |
| `Combine` / `ObservableObject` | Publish `ChargingActivity?` into SwiftUI | [VERIFIED: existing `NotchInteractionState` uses `ObservableObject`] Same pattern as Phase 2. |

### IOKit power-source functions (signatures verified from the SDK header)

[VERIFIED: `grep` of `MacOSX26.5.sdk/.../ps/IOPowerSources.h` + `ps/IOPSKeys.h`, and a `swiftc -typecheck` probe]

| C signature (from header) | Swift import (compiler-confirmed) | Ownership |
|---------------------------|-----------------------------------|-----------|
| `CFTypeRef IOPSCopyPowerSourcesInfo(void)` | `IOPSCopyPowerSourcesInfo() -> Unmanaged<CFTypeRef>?` | **Copy → `.takeRetainedValue()`** |
| `CFArrayRef IOPSCopyPowerSourcesList(CFTypeRef blob)` | `IOPSCopyPowerSourcesList(_:) -> Unmanaged<CFArray>?` | **Copy → `.takeRetainedValue()`**, then `as? [CFTypeRef]` |
| `CFDictionaryRef IOPSGetPowerSourceDescription(CFTypeRef blob, CFTypeRef ps)` | `IOPSGetPowerSourceDescription(_:_:) -> Unmanaged<CFDictionary>?` | **Get → `.takeUnretainedValue()`** (do NOT retain), then `as? [String: Any]` |
| `CFDictionaryRef IOPSCopyExternalPowerAdapterDetails(void)` | `… -> Unmanaged<CFDictionary>?` | **Copy → `.takeRetainedValue()`** |
| `CFRunLoopSourceRef IOPSNotificationCreateRunLoopSource(IOPowerSourceCallbackType callback, void *context)` | `… -> Unmanaged<CFRunLoopSource>?` | **Create → `.takeRetainedValue()`** |
| `typedef void (*IOPowerSourceCallbackType)(void *context)` | `IOPowerSourceCallbackType = @convention(c) (UnsafeMutableRawPointer?) -> Void` | C function pointer; capture nothing — pass `self` via the `context` pointer |

⚠️ **The whole correctness of the IOKit layer hinges on the row above.** Every function imports as `Unmanaged<...>?`. `IOPSCopyPowerSourcesInfo()` is NOT a plain managed value — calling it without `.takeRetainedValue()` is a compile error; using `.takeRetainedValue()` on the **Get** function (a common copy-paste bug seen in forum answers) over-releases and crashes. [VERIFIED: compile probe — the naive `let blob: CFTypeRef = IOPSCopyPowerSourcesInfo()` failed with *"value of type `Unmanaged<CFTypeRef>` expected to be instance of class"*; the `.takeRetainedValue()` / `.takeUnretainedValue()` version typechecked with exit 0.]

### IOPSKeys string values (verified verbatim from the SDK header)

[VERIFIED: `grep '#define' MacOSX26.5.sdk/.../ps/IOPSKeys.h`]

| Constant | Literal value | Swift value type to read |
|----------|---------------|--------------------------|
| `kIOPSPowerSourceStateKey` | `"Power Source State"` | `String` — equals `kIOPSACPowerValue` or `kIOPSBatteryPowerValue` |
| `kIOPSACPowerValue` | `"AC Power"` | `String` (the value above when plugged in) |
| `kIOPSBatteryPowerValue` | `"Battery Power"` | `String` (the value above when on battery) |
| `kIOPSIsChargingKey` | `"Is Charging"` | `Bool` |
| `kIOPSIsChargedKey` | `"Is Charged"` | `Bool` (true at full while on AC) |
| `kIOPSCurrentCapacityKey` | `"Current Capacity"` | `Int` (already a percentage 0–100 for the internal battery) |
| `kIOPSMaxCapacityKey` | `"Max Capacity"` | `Int` (≈100 for the internal battery; divide for safety) |
| `kIOPSTypeKey` | `"Type"` | `String` — equals `kIOPSInternalBatteryType` for the laptop battery |
| `kIOPSInternalBatteryType` | `"InternalBattery"` | `String` |

> Note: for the **internal** battery, `kIOPSCurrentCapacityKey` is already 0–100 (a percentage), and `kIOPSMaxCapacityKey` ≈ 100. Compute percent as `round(100 * current / max)` to be robust against any source that reports mAh, but for the internal battery `current` alone is the percent. [CITED: Apple Dev Forums thread 712711 + munki power.swift — both read `kIOPSCurrentCapacityKey` directly as the percent for the internal battery.]

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `IOPSNotificationCreateRunLoopSource` (event) | A `Timer` polling `IOPSCopyPowerSourcesInfo` | ❌ Violates the locked "no long-lived polling timer / idle CPU ~0%" criterion. Do not use. |
| `IOPSGetPowerSourceDescription` per-source loop | `IOPSCopyExternalPowerAdapterDetails()` alone | Adapter-details only answers "is a charger attached" (its non-nil-ness). It does NOT give charging-vs-full or battery %. Use the per-source description for the real state; the adapter call is an optional quick "AC present" cross-check. |
| Variable-value `battery.100percent` SF Symbol | Custom `RoundedRectangle` fill | Custom shape gives pixel control but re-implements what the SF Symbol does for free, and won't match the system battery look. **Recommend the SF Symbol** (simplest, native, D-03/D-04 satisfied). Custom shape only if on-device tuning shows the symbol fill is too coarse. |
| New `@Published` activity model on controller | New `InteractionPhase` case | A new case forces every `nextState` transition to consider charging (combinatorial blow-up) and couples a programmatic event to a user-driven machine. **Recommend the separate model** (Pattern 2). |

**Installation:** None. Add `import IOKit.ps` to the new monitor file. No SPM packages, no `xcodegen` dependency changes — only new `.swift` files under `Islet/` and `IsletTests/`, then `xcodegen generate`.

## Architecture Patterns

### Recommended new files
```
Islet/Notch/
├── PowerActivity.swift          # PURE: PowerReading struct + ChargingActivity enum + powerActivity(from:) — unit-tested
├── PowerSourceMonitor.swift     # THIN IOKit glue: notification source, reads power, hops to main, publishes
├── ChargingActivityState.swift  # ObservableObject: @Published var activity: ChargingActivity? (drives the view)
└── (extend) NotchPillView.swift # new sideways "wings" layout branch
└── (extend) NotchWindowController.swift  # owns the monitor + the ~3s collapse + routes via updateVisibility()
└── (optionally extend) NotchGeometry.swift  # pure wings-frame math if the panel must widen

IsletTests/
└── PowerActivityTests.swift     # RED→GREEN for powerActivity(from:)
└── (extend) NotchGeometryTests.swift  # if wings-frame math is added
```
Mirror the existing seam split exactly: `PowerActivity.swift` is the pure, fixture-testable seam (like `NotchGeometry.swift` / `NotchInteractionState.swift`); `PowerSourceMonitor.swift` is the thin system wrapper (like `NSScreen+Notch.swift` / `FullscreenSpaceProbe.swift`), NOT unit-tested.

### Pattern 1: The pure power→presentation seam (TDD, like Phase 1/2)
**What:** A plain input struct + output enum + total mapping function, with no IOKit and no AppKit, so the state classification is verified by the agent in milliseconds.
**When to use:** Always — it is the locked "pure-logic seam" discretion item and the Wave-0 RED→GREEN target.
**Exact types the planner should write tests against:**
```swift
// PowerActivity.swift — PURE. No IOKit import here.

// The minimal raw reading lifted out of the IOPS dictionary by PowerSourceMonitor.
// Plain values so tests construct it by hand (mirrors ScreenDescriptor's role).
struct PowerReading: Equatable {
    let isPresent: Bool      // false → no readable battery (desktop / empty source list)
    let isOnAC: Bool         // kIOPSPowerSourceStateKey == "AC Power"
    let isCharging: Bool     // kIOPSIsChargingKey
    let isCharged: Bool      // kIOPSIsChargedKey (true at full on AC)
    let percent: Int         // 0...100, clamped
}

// The presentation the splash renders (D-04: one glyph, three states).
enum ChargingActivity: Equatable {
    case charging(percent: Int)   // on AC, actively charging → bolt glyph
    case full(percent: Int)       // on AC, charged/100% → full (green) glyph, no bolt
    case onBattery(percent: Int)  // unplugged → plain battery glyph (CHG-02)
}

// TOTAL pure mapping. nil == "no splash" (no readable battery → graceful no-op).
func powerActivity(from r: PowerReading) -> ChargingActivity? {
    guard r.isPresent else { return nil }          // desktop / no battery → no-op (locked criterion)
    let p = min(max(r.percent, 0), 100)
    if r.isOnAC {
        if r.isCharging { return .charging(percent: p) }   // D-04 bolt
        return .full(percent: p)                           // charged / plugged-but-full (D-04)
    }
    return .onBattery(percent: p)                          // CHG-02
}
```
**Test matrix (the planner writes these RED first):**
- present + AC + charging + 47% → `.charging(47)`
- present + AC + charged + 100% → `.full(100)`
- present + AC + not charging + not charged + 100% → `.full(100)` (plugged-but-full, the "distinguish charging from full" criterion)
- present + battery + 63% → `.onBattery(63)` (CHG-02)
- **not present** (desktop) → `nil` (graceful no-op — locked criterion)
- percent clamping: `-5` → 0, `150` → 100 (defensive)
- transition realism: AC-charging → battery (the unplug event) yields a different enum case (drives CHG-02 splash)

### Pattern 2: Activity as a separate `@Published` model, NOT an `InteractionPhase` case (RECOMMENDED)
**What:** A new `ChargingActivityState: ObservableObject` with `@Published var activity: ChargingActivity?`. The existing `NotchInteractionState` (collapsed/hovering/expanded) is left untouched. `NotchPillView` observes BOTH.
**Why (analysis of the current code):** `nextState(_:_:)` in `NotchInteractionState.swift` is a total, exhaustively-tested 3-state user-interaction machine. Charging is **programmatic and orthogonal** — it is not driven by pointer events and must not participate in grace-collapse choreography. Folding it into `InteractionPhase` would (a) multiply every `(phase, event)` case, (b) break the clean Phase-2 tests, and (c) couple a hardware event to a user-gesture machine. A parallel `@Published` model is the minimal, non-speculative seam (matches the global CLAUDE.md "no speculative abstractions" rule and the CONTEXT recommendation "charging-specific with a clean seam, NOT a general resolver").
**Precedence (D-11) — how the two models compose in the view:**
```
if let activity = chargingActivity {      // D-11: charging briefly wins, even if user-expanded
    wingsLayout(for: activity)            // new sideways branch
} else if interaction.isExpanded {        // existing Phase-2 downward expand
    expandedIsland
} else {
    collapsedIsland
}
```
The controller decides *when* `chargingActivity` is non-nil (set on the power event, cleared by the ~3s collapse). The view just renders the precedence. This keeps D-11 as a one-line `if` ordering, with no resolver.
**When to use:** This phase. The Phase-6 resolver (COORD-01) will later wrap multiple such models — but do not build that abstraction now.

### Pattern 3: Wings / sideways layout in SwiftUI (D-01/D-03/D-05)
**What:** A flat, wide layout: a status/charging symbol on the **left**, a variable-value battery glyph + % on the **right**, flanking the camera bridge — distinct from the existing downward `expandedIsland`.
**Glyph (D-03/D-04):** Use a variable-value SF Symbol — it fills to the percentage for free and the system look matches the menu-bar battery.
```swift
// Charging → bolt variant; full/on-battery → plain variant. variableValue fills the glyph.
let symbol = isCharging ? "battery.100percent.bolt" : "battery.100percent"
Image(systemName: symbol, variableValue: Double(percent) / 100.0)
    .symbolRenderingMode(.hierarchical)
    .foregroundStyle(percent >= 100 ? Color.green : Color.white)   // D-04 green at full (discretion)
Text("\(percent)%")
    .font(.system(size: 13, weight: .semibold, design: .rounded))
    .monospacedDigit()
    .foregroundStyle(.white)
```
[VERIFIED: `battery.100percent` (year 2023 → macOS 14) and `battery.100percent.bolt` (2023 → macOS 14) both exist in the installed SF Symbols catalog — read from `…/SFSymbols.framework/.../CoreGlyphs.bundle/.../name_availability.plist`.] [CITED: sarunw.com — `Image(systemName:variableValue:)` fills the symbol proportionally; introduced SF Symbols 4 / 2022.]
**Spring vocabulary (D-07):** reuse the existing controller seeds — `response: 0.35, dampingFraction: 0.65` (single-sourced in `NotchWindowController`). The slide-out is a width + opacity transition wrapped in `withAnimation(.spring(...))` at the state mutation (the view drives no animation itself — D-08, same discipline as `NotchPillView` today).
**`matchedGeometryEffect`:** keep the single black blob on the existing `id: "island"` shared namespace so the pill morphs from collapsed into the wings shape (no cross-fade), consistent with Phase 2.

### Pattern 4: Panel sizing for wings (the window-frame implication)
**What the current code does:** `NotchWindowController.positionAndShow(on:)` sizes the panel to `expandedNotchFrame(collapsed:expandedSize:)` UP FRONT (the extra area is transparent), so the SwiftUI morph never clips. `expandedSize = 360×72` and grows **downward** (y = collapsed.maxY − height).
**Why wings need attention:** the wings extend **sideways**, so the panel must be **wide** enough to host both wings + the notch gap. `360` may already be wide enough for a status symbol + battery + %, but it grows downward, not centered horizontally for a flat strip. **Recommendation:**
- Keep sizing the panel to a single up-front frame (Pitfall 4 — never resize mid-animation), but introduce a **wings frame** that is wider and flatter, centered on the collapsed pill's `midX` and pinned to the top edge. Add a pure `wingsFrame(collapsed:wingsSize:)` to `NotchGeometry.swift` (same contract as `expandedNotchFrame` — center on midX, pin to `collapsed.maxY`), unit-tested like the existing frame functions.
- Because the panel is shown once at the largest needed frame and content is transparent outside the drawn shape, the simplest correct approach is: **size the panel to the union of the expanded (downward) and wings (sideways) frames** so both Phase-2 expand and the Phase-3 wings fit without a runtime panel resize. The planner should pick the wings size on-device (discretion) and feed it through `wingsFrame`.
**Anti-pattern:** resizing the panel `setFrame` in response to the activity at runtime — it races the morph and the Phase-2 hot-zone math. Size once, draw within.

### Pattern 5: Auto-dismiss reusing the `graceWorkItem` template (D-09/D-10)
**What:** The existing `graceWorkItem: DispatchWorkItem?` + `DispatchQueue.main.asyncAfter` is the exact one-shot collapse template. Add a parallel `dismissWorkItem: DispatchWorkItem?` for the ~3s activity collapse.
**How (mirrors `handleHoverExit`):**
```swift
private var dismissWorkItem: DispatchWorkItem?
private let activityDuration: TimeInterval = 3.0   // D-09, single tuning seed

private func scheduleActivityDismiss() {
    dismissWorkItem?.cancel()
    let work = DispatchWorkItem { [weak self] in
        guard let self else { return }
        withAnimation(.spring(response: self.springResponse, dampingFraction: self.springDamping)) {
            self.chargingState.activity = nil      // collapse the wings
        }
        self.updateVisibility()                    // re-evaluate the single show/hide site
    }
    dismissWorkItem = work
    DispatchQueue.main.asyncAfter(deadline: .now() + activityDuration, execute: work)
}
```
**Hover pauses it (D-10):** in `handleHoverEnter()`, also `dismissWorkItem?.cancel()`; in `handleHoverExit()` (or when the pointer leaves while an activity is standing), call `scheduleActivityDismiss()` again so the ~3s resumes. Click is informational (D-10) — do NOT route `.clicked` into the activity model; leave the existing click→expand untouched while an activity stands, or simply ignore it (discretion, but no detail panel).
**Why not a Timer:** a one-shot `DispatchWorkItem` schedules a single wake-up and then idles — zero CPU while standing (D-08 + the idle-CPU-~0% criterion). A repeating `Timer` would violate it.

### Pattern 6: Show/hide through the single `updateVisibility()` (locked — fullscreen/clamshell inheritance)
**What:** The splash must NOT introduce a second `orderFront`/`orderOut`. The activity becoming non-nil must funnel through `updateVisibility()`, which already ANDs `hasTarget` (clamshell) with `!(hideInFullscreen && isFullscreen)`.
**How:** When the power event sets `chargingState.activity`, call `updateVisibility()`. The panel is already shown whenever there's a target and not fullscreen; the activity only changes the *content*, not whether the window exists. The key correctness point: **the splash inherits fullscreen-hide automatically** because the panel's visibility is decided solely by `updateVisibility()` and the SwiftUI content (wings vs collapsed) is decided by the published activity. If fullscreen is active, the panel is `orderOut` regardless of the activity → the splash cannot appear in fullscreen (locked criterion / Phase-2 D-09).
**Subtlety:** if a plug event arrives *while in fullscreen*, set the activity (so the model is correct) but `updateVisibility()` keeps the panel hidden; when fullscreen exits, the `activeSpaceDidChange`/`didActivateApplication` observers already call `updateVisibility()` → the panel returns. Decide (discretion) whether a plug-during-fullscreen splash should still be showing post-exit or have already auto-dismissed; simplest: the ~3s timer runs regardless, so a plug deep in fullscreen simply won't be seen — acceptable for v1.

### Anti-Patterns to Avoid
- **Polling `IOPSCopyPowerSourcesInfo` on a Timer** — violates the no-polling/idle-CPU criterion. Use only the notification source.
- **`.takeRetainedValue()` on `IOPSGetPowerSourceDescription`** — it's a *Get* (borrowed); retaining it over-releases → crash. Use `.takeUnretainedValue()`.
- **Folding charging into `InteractionPhase`** — couples a programmatic event to the user-gesture machine and breaks the Phase-2 test invariants.
- **A second `orderFront`/`orderOut` site for the splash** — races the clamshell + fullscreen observers (the documented Pitfall 5 in `NotchWindowController`). Route through `updateVisibility()`.
- **Resizing the panel at runtime for the wings** — races the morph + the hot-zone math. Size once to the union frame.
- **Capturing `self` in the C callback** — `IOPowerSourceCallbackType` is `@convention(c)`; it cannot capture. Pass the instance via the `void *context` pointer (`Unmanaged.passUnretained(...).toOpaque()`), recover it inside, and **hop to the main thread** before touching `@Published`/AppKit.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Detect plug/unplug live | A polling loop / NSTimer reading power each tick | `IOPSNotificationCreateRunLoopSource` | The OS posts exactly on change → zero idle CPU; polling is both wasteful and laggy. |
| Battery percentage | Parsing `pmset`/`ioreg` text output | `kIOPSCurrentCapacityKey` from the source description | Text scraping is brittle and slow; the dictionary value is canonical. |
| A battery glyph that fills to % | A custom `RoundedRectangle` mask animating a fill | `Image(systemName: "battery.100percent", variableValue: pct/100)` | The SF Symbol fills proportionally, matches the system battery look, and handles bolt/full variants — verified available at the macOS-14 floor. |
| The ~3s one-shot collapse | A repeating `Timer` you stop/restart | A one-shot `DispatchWorkItem` (the existing `graceWorkItem` pattern) | One-shot = single wake then idle (D-08 / idle-CPU); repeating timer keeps the CPU warm. |
| "Is a charger attached?" | Watching IORegistry power-adapter nodes manually | `kIOPSPowerSourceStateKey == kIOPSACPowerValue` (or `IOPSCopyExternalPowerAdapterDetails() != nil` as a cross-check) | The source state is the supported, documented signal. |

**Key insight:** the entire power surface this phase needs is ~40 lines of IOKit glue + a pure mapping function. The risk is not volume — it's the three subtle bridging facts (Unmanaged ownership, `@convention(c)` no-capture, main-thread hop). Get those right (Code Examples below) and the rest is trivial.

## Common Pitfalls

### Pitfall 1: Wrong Unmanaged unwrapping (crash or compile error)
**What goes wrong:** Calling `IOPSCopyPowerSourcesInfo()` directly (compile error — it's `Unmanaged<CFTypeRef>?`), or calling `.takeRetainedValue()` on `IOPSGetPowerSourceDescription` (runtime over-release crash).
**Why it happens:** The C header shows plain `CFTypeRef` returns; Swift's CF importer wraps them as `Unmanaged` and the Copy/Get distinction is invisible without reading the function name. Several public forum snippets get the Get call wrong.
**How to avoid:** Copy/Create → `.takeRetainedValue()`. Get → `.takeUnretainedValue()`. [VERIFIED by compile probe — see Code Example 1, which typechecked at exit 0 in Swift 5 mode.]
**Warning signs:** `EXC_BAD_ACCESS` shortly after the first power read; or a `value of type 'Unmanaged<...>' expected to be instance of class` compile error.

### Pitfall 2: Callback can't capture `self`; touching `@Published` off-main
**What goes wrong:** Trying to write `{ [weak self] _ in self?.update() }` as the C callback fails to compile (a `@convention(c)` function can't capture context), and even when you pass `self` via the context pointer, the callback may run on whatever thread the run loop source is attached to — mutating a `@Published`/AppKit from there is undefined.
**Why it happens:** `IOPowerSourceCallbackType` is a bare C function pointer.
**How to avoid:** Pass the instance through `void *context` (`Unmanaged.passUnretained(self).toOpaque()`), recover with `Unmanaged.fromOpaque(_).takeUnretainedValue()`, then `DispatchQueue.main.async { ... }` (or add the source to `CFRunLoopGetMain()` with `.commonModes` so it already runs on main, and still keep mutations on main). The CONTEXT explicitly requires the main-thread hop. [CITED: Apple Dev Forums 712711 / munki power.swift pattern.]
**Warning signs:** UI updates from a background thread, intermittent SwiftUI "Publishing changes from background threads is not allowed" purple runtime warnings.

### Pitfall 3: Desktop / no battery not handled → wrong or crashing splash
**What goes wrong:** On a Mac with no internal battery, `IOPSCopyPowerSourcesList` is **empty** — the per-source loop never runs, and naive code might assume a reading and show a bogus splash or force-unwrap.
**Why it happens:** The locked criterion "behaves sanely on a Mac with no charging state."
**How to avoid:** `powerActivity(from:)` returns `nil` when `isPresent == false`; `PowerSourceMonitor` sets `isPresent = false` when the source list is empty or no `InternalBattery` source is found → no splash, no crash. Unit-test the `nil` path. [VERIFIED: header doc + forum confirm the empty-list case for desktops.]
**Warning signs:** Crash on a Mac mini / iMac; a splash appearing with 0% on a desktop.

### Pitfall 4: Notification fires with no *meaningful* change (debounce/idempotency)
**What goes wrong:** `IOPSNotificationCreateRunLoopSource` can fire on capacity ticks (e.g. 46%→47%) and other power changes, not only plug/unplug. Naively re-showing the splash on every fire would make it flicker/re-appear constantly.
**Why it happens:** The notification is "power source info changed," broader than "cable toggled."
**How to avoid:** Track the last `ChargingActivity` *category* (charging/full/onBattery, ignoring the percent number). Only **trigger a new splash** when the category transitions (e.g. onBattery→charging = plug-in; charging/full→onBattery = unplug). A pure-percent tick while already charging should update the % in a standing splash but not restart the timer (or be ignored). This also keeps idle CPU low. The planner should make the "should this fire a splash?" decision a small pure function over (previous category, new category) — another testable seam.
**Warning signs:** The splash re-triggering every few seconds while plugged in.

### Pitfall 5: Splash leaking into fullscreen
**What goes wrong:** Adding a direct `panel.orderFrontRegardless()` when the activity appears bypasses the fullscreen gate and pops the splash over a fullscreen video.
**Why it happens:** Convenience — showing the panel directly seems simpler.
**How to avoid:** Never show the panel from the power path. Set the `@Published` activity, then call `updateVisibility()`; the panel's existence stays governed by the single gated decision (Pattern 6). [VERIFIED: existing `updateVisibility()` already ANDs the fullscreen signal.]
**Warning signs:** A charging splash visible during a fullscreen movie (violates locked criterion + Phase-2 D-09).

## Code Examples

> All snippets below were **compile-verified** against `MacOSX26.5.sdk` with `swiftc -swift-version 5 -typecheck` (exit 0). They are the canonical idiom for the planner.

### Example 1: Read the current power state into a `PowerReading`
```swift
// PowerSourceMonitor.swift (thin IOKit glue — NOT unit-tested; the pure mapping is)
import IOKit.ps
import CoreFoundation

func readCurrentPower() -> PowerReading {
    // Copy → owned → takeRetainedValue. Imported as Unmanaged<CFTypeRef>? → optional-chain.
    guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
          let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef]
    else {
        return PowerReading(isPresent: false, isOnAC: false, isCharging: false, isCharged: false, percent: 0)
    }
    for ps in sources {
        // Get → NOT owned → takeUnretainedValue.
        guard let d = IOPSGetPowerSourceDescription(blob, ps)?.takeUnretainedValue() as? [String: Any]
        else { continue }
        // Internal laptop battery only (ignore UPS etc.).
        guard (d[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType else { continue }

        let state    = d[kIOPSPowerSourceStateKey] as? String
        let isOnAC   = (state == kIOPSACPowerValue)
        let charging = d[kIOPSIsChargingKey] as? Bool ?? false
        let charged  = d[kIOPSIsChargedKey] as? Bool ?? false
        let cur      = d[kIOPSCurrentCapacityKey] as? Int ?? 0
        let mx       = d[kIOPSMaxCapacityKey] as? Int ?? 100
        let pct      = mx > 0 ? Int((Double(cur) / Double(mx) * 100).rounded()) : cur
        return PowerReading(isPresent: true, isOnAC: isOnAC, isCharging: charging, isCharged: charged, percent: pct)
    }
    return PowerReading(isPresent: false, isOnAC: false, isCharging: false, isCharged: false, percent: 0)
}
```

### Example 2: Register the live plug/unplug notification (no polling)
```swift
// PowerSourceMonitor.swift — the event source. @MainActor-friendly: add to the MAIN run loop.
import IOKit.ps
import CoreFoundation

@MainActor
final class PowerSourceMonitor {
    private var runLoopSource: CFRunLoopSource?
    private let onChange: (PowerReading) -> Void   // controller hops state in here (already on main)

    init(onChange: @escaping (PowerReading) -> Void) { self.onChange = onChange }

    func start() {
        // The C callback cannot capture self → pass self via the context pointer.
        let context = Unmanaged.passUnretained(self).toOpaque()
        let callback: IOPowerSourceCallbackType = { ctx in
            guard let ctx = ctx else { return }
            let monitor = Unmanaged<PowerSourceMonitor>.fromOpaque(ctx).takeUnretainedValue()
            // Source is on the main run loop, but hop explicitly to be safe re: @Published/AppKit.
            DispatchQueue.main.async {
                monitor.onChange(readCurrentPower())
            }
        }
        guard let src = IOPSNotificationCreateRunLoopSource(callback, context)?.takeRetainedValue() else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        runLoopSource = src
        // Emit the initial state once so the UI is correct at launch (no splash unless a change).
        onChange(readCurrentPower())
    }

    func stop() {
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
            runLoopSource = nil
        }
    }

    deinit {
        // CFRunLoopSource holds the context pointer; remove it. (deinit can't be @MainActor;
        // remove in stop() from the controller's deinit instead — see integration note.)
    }
}
```
> Integration note: because `deinit` can't be `@MainActor` in Swift 5 mode, have `NotchWindowController.deinit` call `monitor.stop()` (the controller is `@MainActor` and owns the monitor for the app lifetime, so teardown only happens at quit — leak risk is nil, but `stop()` keeps it tidy and mirrors the existing observer-removal discipline in `NotchWindowController.deinit`).

### Example 3: The pure mapping (the Wave-0 test target)
See Pattern 1 — `PowerReading` / `ChargingActivity` / `powerActivity(from:)`. That function is the RED→GREEN seam; no IOKit import in that file.

### Example 4: Wings view branch (sketch — exact geometry is on-device tuning)
```swift
// In NotchPillView: observe a ChargingActivityState alongside the interaction state.
@ObservedObject var charging: ChargingActivityState

private func wings(for activity: ChargingActivity) -> some View {
    let (symbol, pct, tint): (String, Int, Color) = {
        switch activity {
        case .charging(let p): return ("battery.100percent.bolt", p, .white)
        case .full(let p):     return ("battery.100percent",      p, .green)   // D-04 full
        case .onBattery(let p):return ("battery.100percent",      p, .white)   // CHG-02 plain
        }
    }()
    return HStack {
        Image(systemName: "bolt.fill")              // D-05 status symbol left (discretion)
            .foregroundStyle(.yellow)
        Spacer().frame(width: notchGap)             // gap for the physical camera bridge
        Image(systemName: symbol, variableValue: Double(pct) / 100.0)  // D-03 filling glyph
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(tint)
        Text("\(pct)%").monospacedDigit().foregroundStyle(.white)
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Per-state battery symbols (`battery.0`, `battery.25`, … from 2019) | One `battery.100percent` + `variableValue` fill | SF Symbols 4 (2022) / 5 (2023) | A single glyph fills to any % — directly satisfies D-04 "one consistent glyph." Both `battery.100percent` and `.bolt` available at the macOS-14 floor. |
| `pmset`/`ioreg` text scraping | IOKit `IOPS*` dictionary API | Long-standing | The dictionary API is the supported path; no parsing. |
| Polling battery on a timer | `IOPSNotificationCreateRunLoopSource` | Long-standing | Event-driven, zero idle CPU (locked criterion). |

**Deprecated/outdated:** Nothing relevant deprecated in the SDK headers for IOPS on macOS 26.5 (no `API_DEPRECATED` on the functions used). The old `battery.100` (2019, no `.percent`) names still exist but `battery.100percent` is the modern variable-value name — prefer it.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | For the internal battery, `kIOPSCurrentCapacityKey` is already a 0–100 percentage (so `current/max*100` ≈ `current`). | Standard Stack / Code Example 1 | LOW — the `current/max*100` formula in the code is robust either way (handles mAh-style sources too). Confirm the displayed % matches the menu bar on-device. |
| A2 | The notification source attached to `CFRunLoopGetMain()` delivers its callback on the main thread; the explicit `DispatchQueue.main.async` is belt-and-suspenders. | Code Example 2 / Pitfall 2 | LOW — the explicit main hop makes correctness independent of this assumption. |
| A3 | Green-at-full and the exact bolt/status SF Symbols are acceptable to the user (CONTEXT marks colors + exact symbols as discretion). | Pattern 3 / Example 4 | LOW — explicitly discretion + on-device tuning per D-05/D-07. |
| A4 | A panel sized to the union of the downward-expanded and sideways-wings frames hosts both without a runtime resize. | Pattern 4 | MEDIUM — depends on the wings size chosen on-device. The planner should confirm the chosen wings width fits and the Phase-2 expand still looks right within the same panel. Verify visually. |
| A5 | Plug/unplug should be detected by a *category transition* (not every notification fire) to avoid splash flicker. | Pitfall 4 | LOW-MEDIUM — this is a design recommendation, not a hard requirement; the planner may choose a simpler "fire on any AC-state edge." Either way, debounce is needed. |

## Open Questions

1. **Exact wings dimensions + camera-bridge gap.**
   - What we know: must flank the notch left+right, flat, status symbol left, battery+% right (D-01/D-03/D-05).
   - What's unclear: per-side width, the gap that clears the physical camera bridge, total panel width.
   - Recommendation: pick seeds in the plan (e.g. start from the existing 360 width, flat ~38–44 height), expose them as single-source constants like the Phase-2 tuning seeds, and tune on-device. Add a pure `wingsFrame(...)` to `NotchGeometry.swift` so the math stays testable.

2. **Splash behavior for a plug event during fullscreen.**
   - What we know: the splash must not appear in fullscreen; `updateVisibility()` gates it.
   - What's unclear: whether a plug-during-fullscreen should "queue" and show on exit, or simply be missed.
   - Recommendation (v1, simplest): let the ~3s timer run regardless → a deep-fullscreen plug is simply not seen. Acceptable; document it. (The Phase-6 resolver can revisit.)

3. **Should `kIOPSIsChargedKey` vs `!isCharging` define "full"?**
   - What we know: D-04 wants charging vs plugged-but-full distinguished.
   - What's unclear: at exactly 100% some Macs report `isCharging == false` without `isCharged == true` briefly.
   - Recommendation: treat `isOnAC && !isCharging` as `.full` (covers both charged and "plugged but not actively charging"), and optionally show green only when `percent >= 100`. Covered by the pure tests.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `IOKit.ps` (IOPowerSources) | CHG-01/CHG-02 power events | ✓ | SDK MacOSX26.5 | — |
| `battery.100percent` SF Symbol | D-03 filling glyph | ✓ | macOS 14 (year 2023) | `battery.100` (2019) or custom RoundedRectangle |
| `battery.100percent.bolt` SF Symbol | D-04 charging variant | ✓ | macOS 14 (year 2023) | `battery.100.bolt` (2020) or `bolt.fill` overlay |
| `Image(systemName:variableValue:)` | D-03 proportional fill | ✓ | macOS 13+ (SF Symbols 4) | discrete `battery.0/25/50/75/100percent` by bucket |
| XcodeGen | regenerate project after new sources | ✓ | 2.45.3 | `xcodegen generate` |
| A Mac with a battery | on-device verification of the real splash | ✓ (build machine is a notch MacBook) | — | The pure tests + the desktop/no-battery `nil` path cover the no-battery case in CI |

**Missing dependencies with no fallback:** None.
**Missing dependencies with fallback:** None required — all primary paths are available at the macOS-14 floor.

**No entitlement / TCC:** [VERIFIED: SDK header shows no `API_AVAILABLE`-gated entitlement and no privacy-usage key requirement on the IOPS functions; CITED: Apple Dev Forums 128048/712711 report no permission prompt.] Reading power sources and registering the notification require **no entitlement and trigger no TCC prompt**, sandboxed or not. The app is un-sandboxed regardless.

## Validation Architecture

> `workflow.nyquist_validation` is `true` in `.planning/config.json` → this section applies.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (existing `IsletTests` target, `bundle.unit-test`, hosted in Islet.app) |
| Config file | `project.yml` (XcodeGen) → `IsletTests` target; scheme `Islet` runs it on `test` |
| Quick run command | `xcodebuild test -scheme Islet -only-testing:IsletTests/PowerActivityTests -destination 'platform=macOS'` |
| Full suite command | `xcodebuild test -scheme Islet -destination 'platform=macOS'` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CHG-01 | `powerActivity` returns `.charging(p)` on AC+charging | unit | `xcodebuild test -scheme Islet -only-testing:IsletTests/PowerActivityTests/testChargingMapsToCharging` | ❌ Wave 0 |
| CHG-01 | distinguishes charging from plugged-but-full (`.full`) | unit | `…/testOnACNotChargingMapsToFull` | ❌ Wave 0 |
| CHG-01 | `nil` (no splash) when no battery present (desktop) | unit | `…/testNoBatteryMapsToNil` | ❌ Wave 0 |
| CHG-01 | percent clamped to 0…100 | unit | `…/testPercentClamped` | ❌ Wave 0 |
| CHG-02 | `.onBattery(p)` on unplug | unit | `…/testOnBatteryMapsToOnBattery` | ❌ Wave 0 |
| CHG-01/02 | category-transition fires a splash; pure % tick does not | unit | `…/testTransitionTriggersSplash` (if the debounce predicate is made pure) | ❌ Wave 0 |
| CHG-01 | wings frame centers on midX + pins to top (if `wingsFrame` added) | unit | `IsletTests/NotchGeometryTests/testWingsFrame*` | ❌ Wave 0 (extend) |
| CHG-01/02 | the real splash appears/animates/auto-dismisses on plug/unplug; not in fullscreen; no-op on no-battery | manual (on-device) | — (IOKit + AppKit + SwiftUI wiring; UAT) | manual — justified: real hardware power events + window compositing can't be unit-tested |

### Sampling Rate
- **Per task commit:** `xcodebuild test -scheme Islet -only-testing:IsletTests/PowerActivityTests -destination 'platform=macOS'`
- **Per wave merge:** `xcodebuild test -scheme Islet -destination 'platform=macOS'` (full suite green)
- **Phase gate:** Full suite green + on-device UAT (plug/unplug splash, full vs charging, on-battery, desktop no-op, fullscreen no-show) before `/gsd-verify-work`.

### Wave 0 Gaps
- [ ] `IsletTests/PowerActivityTests.swift` — covers CHG-01/CHG-02 (the `powerActivity(from:)` matrix + the no-battery `nil` path)
- [ ] `Islet/Notch/PowerActivity.swift` — the pure seam under test (`PowerReading` / `ChargingActivity` / `powerActivity(from:)`)
- [ ] (If wings-frame math is added) extend `IsletTests/NotchGeometryTests.swift` + `Islet/Notch/NotchGeometry.swift` with `wingsFrame(...)`
- [ ] (If the splash-debounce predicate is made pure) a small `shouldTriggerSplash(previous:next:)` function + tests
- [ ] Framework install: none — `IsletTests` already exists and runs.

## Runtime State Inventory

> Phase 3 is greenfield feature code (no rename/refactor/migration). This section is included only to confirm no hidden runtime state is touched.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — no databases, no persisted keys. (Settings toggle for the activity is Phase 6.) | None |
| Live service config | None — no external services. | None |
| OS-registered state | None — the IOKit notification source is created at runtime in `start()` and removed at teardown; nothing persisted in the OS. | None |
| Secrets/env vars | None. | None |
| Build artifacts | New `.swift` files under `Islet/` + `IsletTests/` → run `xcodegen generate` to regenerate `Islet.xcodeproj`. | `xcodegen generate` after adding sources (verified workflow) |

## Sources

### Primary (HIGH confidence)
- **Installed macOS SDK** `MacOSX26.5.sdk/.../IOKit.framework/Headers/ps/IOPowerSources.h` + `ps/IOPSKeys.h` — function signatures + exact IOPSKeys string values (read directly via `grep`).
- **`swiftc -swift-version 5 -typecheck` probe** against that SDK — confirmed every IOPS function imports as `Unmanaged<...>?` and the `.takeRetainedValue()`/`.takeUnretainedValue()` idiom compiles (exit 0).
- **Installed SF Symbols catalog** `SFSymbols.framework/.../CoreGlyphs.bundle/.../name_availability.plist` — `battery.100percent` (2023) and `battery.100percent.bolt` (2023) available at the macOS-14 floor.
- **Existing codebase** — `NotchWindowController.swift` (`updateVisibility`, `graceWorkItem`, observers, deinit discipline), `NotchInteractionState.swift` (the 3-state machine to leave untouched), `NotchPillView.swift` (`matchedGeometryEffect`, spring discipline), `NotchGeometry.swift` (pure-frame seam to extend), `FullscreenSpaceProbe.swift` / `NSScreen+Notch.swift` (thin-system-wrapper precedent), `project.yml` (Swift 5, macOS 14, XcodeGen, test target).
- **CLAUDE.md** — "Power / charging detection", "Animation approach", "What NOT to Use" (no polling, no CALayer), Swift-5/un-sandboxed/macOS-14 constraints.

### Secondary (MEDIUM confidence)
- [Apple Dev Forums 712711 — Battery level with IOPSCopyPowerSources](https://developer.apple.com/forums/thread/712711) — the `takeRetained`/`takeUnretained` split + `kIOPSCurrentCapacityKey` as percent (corroborates the compile probe).
- [Apple Dev Forums 128048 — How to see if Mac is charging in Swift](https://developer.apple.com/forums/thread/128048) — adapter-vs-charging distinction; no permission prompt; empty list on desktops.
- [munki power.swift](https://github.com/munki/munki/blob/main/code/apps/Managed%20Software%20Center/Managed%20Software%20Center/power.swift) — real-world Swift IOPS reading using `takeRetainedValue()` / `takeUnretainedValue()`.
- [sarunw.com — Variable Color / variableValue in SF Symbols](https://sarunw.com/posts/sf-symbols-variable-color/) — `Image(systemName:variableValue:)` proportional fill.

### Tertiary (LOW confidence)
- [appsloveworld — Mac get battery/charging status](https://www.appsloveworld.com/objective-c/100/22/mac-get-battery-charging-status-plugged-in-or-not) — Objective-C reference for the notification pattern (superseded by the compiled Swift idiom above; one of the sources that mis-uses `.takeRetainedValue()` on the Get function — flagged in Pitfall 1).

## Metadata

**Confidence breakdown:**
- IOKit wiring (signatures, ownership, keys, callback): **HIGH** — read from the installed SDK headers and confirmed by a compiling probe in Swift 5 mode.
- Pure seam design (PowerReading/ChargingActivity/powerActivity): **HIGH** — mirrors the existing, well-established Phase-1/2 seam pattern; pure and trivially testable.
- Activity-vs-InteractionPhase recommendation: **HIGH** — grounded in reading the actual `nextState`/controller code; matches CONTEXT's explicit recommendation.
- Wings layout + panel sizing: **MEDIUM** — SF Symbol availability verified; exact dimensions/gap are on-device tuning (Open Questions 1, A4).
- Splash debounce / category-transition design: **MEDIUM** — sound recommendation, not a hard requirement (A5).
- No-entitlement / no-TCC claim: **HIGH** — no gating in the SDK header + corroborating forum reports; app is un-sandboxed regardless.

**Research date:** 2026-06-27
**Valid until:** 2026-07-27 (stable APIs; re-verify SF Symbol availability + IOPS signatures only if the Xcode/SDK is upgraded).
