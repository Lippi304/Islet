# Stack Research

**Domain:** Native macOS notch-overlay app — v1.5 feature additions (Home declutter, Tray-only file-drop consolidation w/ Quick Action picker, widget-style Weather + forecast, NotchShape top-edge flare)
**Researched:** 2026-07-13
**Confidence:** MEDIUM-HIGH (Apple frameworks already linked in this project; the one genuinely new integration risk — presenting share UI from a permanently-`canBecomeKey == false` panel — has no single authoritative Apple doc confirming behavior, flagged accordingly)

> Superseded scope note: this file previously held v1.4's window-shell/onboarding/settings/theming/calendar research. That stack is now shipped and documented in `PROJECT.md`/`CLAUDE.md`. This file is rescoped to v1.5's five target features only (Home declutter, Tray-only Quick Action drop picker, wider Tray grid, widget-style Weather + forecast, NotchShape top-edge flare).

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| **`NSSharingService`** (direct calls, NOT `NSSharingServicePicker`) | AppKit, ships with macOS SDK (stable since 10.8) | Perform AirDrop / Mail-compose from the Quick Action picker | `.perform(withItems:)` opens AirDrop's or Mail.app's own system window — a separate process/window that becomes key on its own terms. This avoids ever needing Islet's own panel to become key or host a system popover. See "What NOT to Use" for why the picker CLASS is explicitly avoided. |
| **`WeatherKit.WeatherService.weather(for:including:)`** | WeatherKit, ships with macOS 13+ SDK (already linked, Phase 14) | Adds `.daily` forecast data to the existing current-conditions fetch | The codebase already calls `service.weather(for: location)` (no `including:`), which — per Apple's WeatherKit API — returns the FULL `Weather` bundle (current + minute + hourly + **daily** + alerts) in a single network call. `dailyForecast` is technically already being fetched and silently discarded today. Switching to `weather(for: location, including: .current, .daily)` is the leaner, explicit form — still exactly ONE network call against the WeatherKit quota, but skips parsing/transporting hourly/minute data Islet doesn't use. |
| **SwiftUI `Shape` + explicit `animatableData`** | Ships with SwiftUI (macOS 15 SDK, project's deployment target) | The flare-only-on-expanded silhouette transition | `NotchShape`'s existing 2-parameter (`topCornerRadius`/`bottomCornerRadius`) design does NOT actually get free interpolation from "plain stored CGFloat properties" — confirmed against current SwiftUI docs/community sources: a custom `Shape` without an explicit `animatableData` override defaults to `EmptyAnimatableData`, and its parameters **snap**, not interpolate. The existing code's morph looks smooth on-device because the corner-radius jump is masked by the simultaneous, much larger frame-size animation driven by `matchedGeometryEffect`/spring. A new flare parameter that must visibly grow only in the expanded state is a much more prominent geometry change — do NOT repeat the "plain property" pattern for it; add a real `animatableData` (e.g. `AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>>` combining all three radii/flare values) so the flare genuinely interpolates during the spring instead of popping in/out. |
| **SwiftUI `LazyVGrid`/`GridItem(.adaptive(minimum:))`** | Ships with SwiftUI | Widened Tray with larger file icons | Pure native layout — no new API needed. `GridItem(.adaptive(minimum:))` auto-flows icon columns as the (already per-view-variable, per Phase 28's `.trayExpanded`) expanded width grows, without hardcoding a column count. This is the idiomatic SwiftUI primitive for icon grids; nothing else in AppKit/SwiftUI does this job better for a beginner. |

### Supporting Libraries

_None._ Every capability needed for v1.5 (AirDrop, Mail, forecast, flare, wider grid, Home decluttering) is covered by Apple frameworks already linked in the project (AppKit, WeatherKit, SwiftUI). No new SPM package is justified — adding one here would fight this project's own "keep AppKit/3rd-party surface area small" convention for no benefit.

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| **Xcode 16+ (already in use)** | Build/run/debug the above | No new target, capability checkbox, or entitlement beyond what Phase 14 (WeatherKit) and the existing un-sandboxed signing already provide. `NSSharingService` needs no entitlement when un-sandboxed (Islet already ships un-sandboxed — MediaRemote rules sandboxing out anyway). |

## Installation

```bash
# No new packages. Everything above is an already-linked Apple framework
# (AppKit, WeatherKit, SwiftUI) — nothing to add via SPM/CocoaPods/Homebrew.
```

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| `NSSharingService(named:).perform(withItems:)` called directly per destination | `NSSharingServicePicker.show(relativeTo:of:preferredEdge:)` (the system share-sheet popover) | Only if Islet's panel design changes to allow `canBecomeKey == true` in some future rework. Today `NotchPanel.canBecomeKey`/`canBecomeMain` are hard-coded `false` (D-07, "never take focus") — see Integration Risk below. The Droppy reference UI is also a *custom* destination picker (Drop/AirDrop/Mail icons), not the generic macOS share sheet, so building a SwiftUI picker + calling `NSSharingService` directly matches the target design better, not just the safer one. |
| `weather(for: location, including: .current, .daily)` | Leave the existing unscoped `weather(for: location)` call as-is and just start reading `weather.dailyForecast` off it | Fully valid, zero-risk option if minimizing the diff matters more than trimming payload size — the data is already there today. Switch to `including:` only if the extra hourly/minute payload is ever shown to matter (it currently doesn't visibly affect anything measurable). |
| Explicit `animatableData` on `NotchShape` for the new flare parameter | Two separate `NotchShape` instances (flared vs. flat) cross-matched via `matchedGeometryEffect`, mirroring how collapsed↔expanded already morphs at the *frame* level | Valid if the flare should feel like a distinct "growing wing" rather than a continuously-interpolating edge — closer to how the existing charging/device wings splash animates in. Costs an extra view identity to manage; the `animatableData` route keeps `NotchShape` a single reusable shape, consistent with the file's existing single-shape design. |
| `LazyVGrid` with `GridItem(.adaptive(minimum:))` | `HStack` in a `ScrollView` (today's shelf-strip pattern, single row) | Keep `HStack`/`ScrollView` if "wider Tray" ends up meaning only a longer single row, not a true multi-row grid. Re-check the Droppy Tray reference screenshot before committing — if it shows one wide row of bigger icons, `ShelfCoordinator`/the existing Tray view need no structural grid change at all, just larger icon/frame constants. |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| **`NSSharingServicePicker`** (the popover class) | Islet's `NotchPanel` permanently overrides `canBecomeKey`/`canBecomeMain` to `false` (D-07) — a deliberate, load-bearing decision so hover/click never activates the app. Community sources (a documented AppKit bug where `nonactivatingPanel`'s WindowServer-level "prevents activation" tag can desync from AppKit's own state, plus a known LSUIElement pattern: "popovers send an activation event the agent app must explicitly swallow") both point at real risk that the system picker either fails to appear, dismisses immediately, or forces an unwanted activation — directly contradicting Islet's "never steals focus" pillar and its documented history (Phase 22/23/24) of exactly this class of click-through/focus bug being invisible on paper and only surfacing on-device. | A custom SwiftUI Quick Action row hosted inside the existing panel content (same interaction model as today's Tray/Calendar buttons, which already work fine despite `canBecomeKey == false` via the existing local `ignoresMouseEvents` toggle), calling `NSSharingService(named:).perform(withItems:)` directly per destination. |
| **WidgetKit** | "iOS-widget-style" in the v1.5 goal describes a VISUAL style (compact card, H/L, forecast strip) to replicate inside the existing SwiftUI view — not an actual WidgetKit extension. Adding a real WidgetKit target would mean a new extension target, an App Group for data sharing, and a Timeline provider — a large, unrequested architecture change for a purely cosmetic ask. | Plain SwiftUI views inside the existing Weather tab, styled to resemble an iOS widget card. |
| **A second/separate WeatherKit call for forecast** (e.g., an extra `weather(for:)` fetch just for daily data) | Doubles quota usage and network round-trips for data the single existing call can already carry. PROJECT.md's phrasing ("requires a new WeatherKit forecast API call") is directionally right (new *code path*/data type) but should not be read as "a second network request" — it's one call with a wider `including:` set. | `weather(for: location, including: .current, .daily)` (or simply read `.dailyForecast` off the existing full-bundle response). |
| **Core Bluetooth, third-party grid/layout libraries, DynamicNotchKit** | Not implicated by any v1.5 target feature — no new device-connection, transient-notification, or non-notch-window need was introduced this milestone. | N/A — nothing to add. |

## Stack Patterns by Variant

**If the Droppy Tray reference turns out to be a true multi-row grid (not just a wider single row):**
- Use `LazyVGrid(columns: [GridItem(.adaptive(minimum: <largerIconSize>))])`
- Because it auto-wraps to however many columns fit the (per-tab-variable) expanded width without a hardcoded column count.

**If on-device testing shows `NSSharingService.perform(withItems:)` still causes any Islet activation/focus flicker despite bypassing the picker:**
- Accept a brief, intentional activation ONLY for this explicit user-initiated action, rather than pre-emptively engineering around it
- Because the "never steals focus" pillar was written for *passive* interactions (hover, glance) — an explicit share action legitimately handing off to Mail.app/AirDrop is a different category from an ambient hover-triggered activation, and should be validated on-device (matching this project's established pattern of resolving focus/click-through questions empirically, not just by static reasoning) rather than blocked in planning.

## Version Compatibility

| Package A | Compatible With | Notes |
|-----------|-----------------|-------|
| `WeatherKit.WeatherQuery.daily` / `.daily(startDate:endDate:)` | macOS 13+ (project targets 15.0) | No version gap — already well within the project's raised macOS 15.0 floor (Phase 26). |
| `NSSharingService.Name.sendViaAirDrop` / `.composeEmail` | AppKit, stable since 10.8/10.10 | No version risk; long-stable, fully public/documented API — unlike the private-MediaRemote class of breakage this project has hit before (the macOS 15.4 `nowplaying-cli`/direct-MediaRemote lockdown), `NSSharingService` is not at risk of an Apple-side access restriction. |
| `Shape.animatableData` / `AnimatablePair` | SwiftUI, all supported versions | No version risk; the gap here is a design-pattern gap in the existing code, not an OS-version gap. |

## Integration Notes (existing code this milestone touches)

- **`Islet/Notch/NotchPanel.swift`** — `canBecomeKey`/`canBecomeMain` are hard-coded `false` (D-07). This is the file that makes `NSSharingServicePicker` risky and motivates the direct-`NSSharingService` recommendation above. Do not touch this file's activation overrides to accommodate sharing — build around them, per this project's established convention of keeping the non-activating contract absolute.
- **`Islet/Notch/DropInterceptTap.swift`** — `onIntercept` currently invokes shelf-landing directly (`handleDragApproachEnd()` → `ShelfCoordinator.append`). For the Quick Action picker, this closure's target becomes "show the Quick Action picker," with `ShelfCoordinator.append(...)` (unchanged) invoked only if the user picks "Drop." AirDrop/Mail route to the new `NSSharingService` calls instead. No change needed inside `DropInterceptTap` itself — the swallow/relocate-and-release CGEventTap mechanics are unaffected regardless of which destination the user ultimately picks.
- **`Islet/Shelf/ShelfCoordinator.swift`** — `append(_:)` is the existing, already-hardened landing seam (duplicate-rejection cleanup, session-copy lifecycle). Reuse verbatim for the "Drop" destination; do not fork or duplicate this logic for the picker.
- **`Islet/Weather/WeatherService.swift`** — `WeatherKitService.fetchCurrent` currently discards everything but `currentWeather`. Extend the protocol/struct (e.g. a new `dailyForecast: [DayWeather]`-bearing field or a second method sharing the same `weather(for:including:)` call) rather than adding a parallel fetch path — keeps the "one seam, one file swap if WeatherKit changes" convention (D-01/D-06) intact.
- **`Islet/Notch/NotchShape.swift`** — currently 2 plain stored `CGFloat` properties, no `animatableData` override (confirmed by direct read). The flare parameter should be added as a 3rd value threaded through the same `animatableData` mechanism recommended above, defaulting to 0 for every existing call site (`NotchPillView.swift` lines ~413, ~1174, ~1237, the collapsed/idle/toast shapes) so the collapsed/idle silhouette is provably unchanged by construction, with only the expanded-blob call site (line ~1089) passing a non-zero flare value.

## Sources

- Apple Developer Documentation — `NSSharingService`, `NSSharingServicePicker`, `nonactivatingPanel` style mask, `WeatherQuery`/`dailyForecast` pages (HIGH — official, though some pages returned title-only via automated fetch; corroborated by WebSearch snippets and training knowledge)
- `philz.blog/nspanel-nonactivating-style-mask-flag` — documents a real AppKit bug where `nonactivatingPanel`'s WindowServer "prevents activation" tag desyncs from AppKit's style-mask state when changed post-init (MEDIUM-HIGH, single detailed technical source, directly relevant even though Islet never toggles this flag post-init)
- `gist.github.com/Wevah/2588578` ("Prevent clicks in a popover from activating an LSUIElement app") — confirms popovers in LSUIElement/agent apps are a known activation-event source requiring explicit suppression (MEDIUM, single community source, but consistent with this project's own documented Phase 22-24 focus/click-through history)
- WebSearch aggregate on WeatherKit quota/rate limits ("500,000 calls/month per membership, no fixed rate limit besides anti-abuse") and `weather(for:including:)` semantics (MEDIUM-HIGH, multiple independent sources agree, consistent with Apple's WeatherKit product page)
- WebSearch aggregate on `DayWeather.highTemperature`/`.lowTemperature` (`Measurement<UnitTemperature>`) (MEDIUM-HIGH, multiple sources agree)
- WebSearch aggregate confirming custom SwiftUI `Shape` without explicit `animatableData` defaults to `EmptyAnimatableData` (no free interpolation of custom stored properties) (HIGH — multiple independent tutorial/reference sources, including Hacking with Swift and Swift with Majid, agree unanimously)
- Direct codebase reads: `Islet/Notch/NotchPanel.swift` (canBecomeKey/canBecomeMain hard-false, D-07), `Islet/Weather/WeatherService.swift` (current unscoped `weather(for:)` call), `Islet/Notch/NotchShape.swift` (no existing `animatableData`), `Islet/Notch/DropInterceptTap.swift` and `Islet/Shelf/ShelfCoordinator.swift` (existing drag-in/shelf-append integration points) (HIGH — ground truth)

---
*Stack research for: Islet v1.5 (Home Focus & Widget Redesign)*
*Researched: 2026-07-13*
