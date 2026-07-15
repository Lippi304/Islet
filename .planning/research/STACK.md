# Stack Research — v1.6 (Liquid Glass & System HUD Suite)

**Domain:** Native macOS notch-overlay utility (Islet) — stack additions for 5 new v1.6 capabilities
**Researched:** 2026-07-15
**Confidence:** MEDIUM overall (HIGH for Sparkle/SwiftUI composition, MEDIUM for Liquid Glass, LOW-MEDIUM for HUD suppression and Focus detection — both private/undocumented-API territory, consistent with the MediaRemote precedent already accepted in this project)

This is **not** a greenfield stack doc — it covers only what's new for v1.6. Nothing here replaces or touches the existing validated stack (SwiftUI/AppKit shell, mediaremote-adapter, IOKit power, IOBluetooth, WeatherKit/EventKit). See `CLAUDE.md` for that baseline.

## Recommended Stack

### 1. Liquid Glass material

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|------------------|
| **`NSGlassEffectView` (AppKit) / `.glassEffect()` (SwiftUI)** | macOS **26.0+ only** (`API_AVAILABLE(macos(26.0))`) | Apple's real "Liquid Glass" material — lensing/refraction, not blur | This is the actual system material Apple ships in Tahoe. `.glassEffect(_:in:)` takes a `Glass` value (`.regular`, `.clear`, `.identity`), a shape (defaults `.capsule`), `tint()`/`interactive()` chaining. Glass views can't sample other glass — group multiple glass elements in a `GlassEffectContainer`. **Requires raising the deployment target from 15.0 to 26.0.** |
| **Custom materials composition (fallback)** | macOS 15.0+ (current target) | Glass *look* without the real API | If the user's supplied reference code is NOT built on `.glassEffect()`, the established community technique (verified via the Klarity writeup) is layered `.ultraThinMaterial`/`.regularMaterial` + `RoundedRectangle`/`Capsule` gradient **stroke borders** (bright→subtle edge gradient, not surface blur) + tuned shadow layering. Border treatment matters more than surface blur for a convincing "glass" read — human perception reads material at edges. |

**Decision this phase needs (flag for `/gsd:discuss-phase`):** does the user's reference code use `.glassEffect()`/`NSGlassEffectView`? If yes → raise deployment target 15.0→26.0 (this project already has precedent for exactly this move in Phase 26, and the dev machine is already Tahoe; this is a single-user hobby app with no App Store/back-compat constraint). If no (a materials/gradient composition) → no target change needed, ship on the current 15.0 floor.

**Integration point:** replaces the existing `islandMaterial` (black-to-transparent gradient, `NotchPillView.swift`/`NotchWindowController.swift`) — same seam, swap the fill/material value, not a structural rewrite. Keep it a single shared material definition as today so pill/expanded/wings stay visually consistent (matches the VISUAL-01 precedent from Phase 25).

### 2. Volume & Brightness HUD replacement (suppress native OSD)

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|------------------|
| **`CGEventTap` on `NX_SYSDEFINED` events** | Core Graphics, all current macOS | Intercept volume/brightness hardware keys *before* the system's `OSDUIHelper` shows its HUD | Media/aux keys (volume up/down/mute, brightness up/down) arrive as `NX_SYSDEFINED` events (subtype 8) at the HID event tap, packed as `(nxKeyCode << 16) \| (keyState << 8)` in `data1`. Installing a **`.cghidEventTap`** at **`.headInsertEventTap`** lets the app see and **consume** the event (return `nil`/swallow) before WindowServer routes it onward — this is the actual mechanism, not a documented API, but it's the standard technique used by SlimHUD/VolumeGlass-class tools. |
| **Input Monitoring permission (`kTCCServiceListenEvent`)** | TCC, macOS 10.15+ | Required entitlement/permission for the event tap to see key events | Lighter-weight than full Accessibility — user grants once via System Settings → Privacy & Security → Input Monitoring. Add the request/prompt flow the same way Bluetooth/Calendar/Weather permissions are already handled in this app. |
| **`AudioObjectSetPropertyData` + `kAudioHardwareServiceDeviceProperty_VirtualMainVolume`** (AudioToolbox/CoreAudio) | Public, documented | Actually change system volume once the native OSD is suppressed | Public, documented CoreAudio property — no private API needed for volume itself, only for suppressing the OSD. Apply to the default output device (`kAudioHardwarePropertyDefaultOutputDevice`). |
| **`DisplayServices.framework` (private) — `DisplayServicesSetBrightness`/`DisplayServicesCanChangeBrightness`** | Private, Apple Silicon | Actually change built-in display brightness | The public/older `CoreDisplay_Display_SetUserBrightness` path does **not** work reliably on Apple Silicon. `DisplayServices` (private, undocumented, `dlopen`'d — same isolation pattern as the MediaRemote bridge) is the confirmed working path on M-series Macs. |

**Critical caveats (flag for phase research, not just planning):**
- **No documented way to suppress `OSDUIHelper` directly.** The only launchctl/SIP-disable approach is destructive and doesn't survive SIP re-enable — do not pursue it. The viable path is **prevention** (consume the key event before it reaches the system), not suppression-after-the-fact.
- Event taps are **silently disabled by macOS** on `tapDisabledByTimeout`, `tapDisabledByUserInput`, and around sleep/wake — the tap callback must detect these and immediately re-enable (`CGEvent.tapEnable`), and this should be wired to `NSWorkspace.didWakeNotification` too.
- Both `DisplayServices` calls and the raw `NX_SYSDEFINED` decode are **undocumented/private, same risk class as MediaRemote** — isolate behind a single `SystemHUDController`/`VolumeBrightnessMonitor` protocol seam (mirrors the existing `NowPlayingMonitor` pattern) so a future macOS break is a one-file swap, not a scattered fix.
- **Recommend a research/spike phase before committing to full replacement** — this is explicitly one of the two items the milestone context already flagged as MediaRemote-precedent-level risk. A same-shape fallback (show the Islet HUD *alongside* rather than *replacing* the system OSD) should be the documented Plan B if the event-consumption approach proves unreliable on-device.

### 3. Focus Mode / Do Not Disturb detection

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|------------------|
| **`INFocusStatusCenter` (Intents framework) + Communication Notifications capability** | Public, documented, macOS 12+ | The only public, forward-compatible way to observe Focus state | Requires adding the **Communication Notifications** capability in Xcode Signing & Capabilities (adds an entitlement), then the **user must separately grant** the app "Focus Status" sharing in System Settings → Focus → Focus Status → Allowed Apps. Gives a **boolean `isFocused`** only — not which Focus mode is active, not richer detail. |
| ~~Reading `~/Library/DoNotDisturb/DB/Assertions.json`~~ | — | ~~Private JSON file, historically used by community tools~~ | **Do not use.** Confirmed via multiple independent reports that this file/format is **broken on macOS 26 (Tahoe)** — the exact OS this project's dev machine already runs. It worked through Sequoia (15.x) by polling the JSON on an interval, but the data is no longer populated there on Tahoe. This is a dead end for this project's actual target OS, not a hypothetical future risk. |

**Recommendation:** ship Focus detection as **boolean-only** via `INFocusStatusCenter`, gated behind an explicit, documented setup step (same UX pattern as Bluetooth/Calendar/Weather: a permission the user grants once, silently degrading to "no Focus HUD" if not granted — consistent with this project's existing "degrade silently on permission denial" convention from WeatherKit/EventKit). Do **not** attempt to show *which* Focus mode is active (Personal/Work/Gaming/etc.) — no reliable, non-broken source exists for that on the current target OS. This narrows Focus-mode HUD scope going into planning — flag as a scope constraint, not just a technical unknown.

### 4. Sparkle auto-update

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|------------------|
| **Sparkle** | **2.9.4** (latest tagged release, published 2026-07-03 — actively maintained) | Auto-update framework for direct-distributed, notarized, non-App-Store macOS apps | The de-facto standard for exactly this app shape; confirms fit with `CLAUDE.md`'s existing recommendation. |
| Install via **Swift Package Manager** | `https://github.com/sparkle-project/Sparkle` | Dependency management | SPM avoids adding CocoaPods/Carthage tooling the project doesn't otherwise use — consistent with how `mediaremote-adapter` was already added. |
| `SPUStandardUpdaterController` | Sparkle 2.x public API | Convenience controller wrapping `SPUUpdater` + `SPUUserDriver` | Simplest integration surface — no need to hand-roll the updater UI or update-check scheduling. |

**Integration specifics for this app shape:**
- **LSUIElement compatibility confirmed**: Sparkle 2.x explicitly handles agent apps — it focuses the (Dock-icon-less) app before showing the update alert, so no extra work needed for the "no Dock icon" constraint.
- **Hardened Runtime / notarization**: this project already carries a `disable-library-validation` entitlement in `project.yml` (added for the embedded `MediaRemoteAdapter.framework` under Hardened Runtime — see memory `release-library-validation-crash`). Sparkle's embedded `.framework` needs the **same** re-signing treatment (`codesign` doesn't recurse into embedded frameworks) — reuse the existing release-script pattern in `scripts/release.sh`, don't invent a new one.
- **EdDSA (ed25519) signing** is mandatory: generate a keypair with Sparkle's bundled `generate_keys` tool, put the public key in `Info.plist` (`SUPublicEDKey`), sign every published update artifact (dmg/zip) with the private key before publishing. Store the private key outside the repo (Keychain or local file, never committed).
- **Appcast hosting**: needs a static XML feed (`SUFeedURL` in `Info.plist`) — GitHub Releases + a generated `appcast.xml` (Sparkle ships a `generate_appcast` tool) is the standard zero-cost hosting choice for a hobby-budget project, fits the existing "no paid services" constraint.
- The **Update-available HUD** (v1.6 scope) is just a thin UI wired to `SPUUpdaterDelegate` callbacks (e.g. `updater(_:didFindValidUpdate:)`) driving a new `IslandActivity` case through the existing `IslandResolver`/`TransientQueue` — no new architecture needed there, this is a new activity source feeding the existing arbiter.

### 5. Dual-activity display (main pill + secondary bubble)

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|------------------|
| **SwiftUI `ZStack` + `.overlay(alignment:)`** | Ships with SwiftUI (already in use) | Anchor a small secondary "bubble" to the main pill's corner/edge | No new library — this is pure composition of primitives already used elsewhere in the app (`NotchPillView`). |
| **Shared `@Namespace` + `matchedGeometryEffect`** | Ships with SwiftUI (already in use, per the existing pill↔expanded morph) | Give the secondary bubble its own morph identity independent of the main pill's | Reuse the exact technique already validated in Phase 2/25 rather than inventing a second animation system — apply a *second* `matchedGeometryEffect` id namespaced per-activity-type so the bubble can independently appear/disappear/morph without perturbing the main pill's existing geometry effect. |
| **`Text(timerInterval:)` / `Text(_:style: .timer)`** | Ships with SwiftUI | Live-updating countdown text (Calendar countdown HUD: "starting in 42m") | Native SwiftUI auto-updates this text on its own timer internally — no manual `Timer`/`TimelineView` polling loop needed for a minutes-precision countdown display. Only reach for `TimelineView` if a custom (non-text) animating countdown visual is needed later. |

**Nothing new to add here** — this is squarely covered by SwiftUI composition already proven in this codebase. The only real design question (main pill vs. bubble sizing/placement, which two activities can co-occur) is an architecture/UX decision, not a stack decision — covered in this milestone's architecture research, not here.

## Installation

```bash
# Sparkle (SPM — add via Xcode: File > Add Package Dependencies)
# URL: https://github.com/sparkle-project/Sparkle
# Version: 2.9.4 or later 2.x
# Target > General > Frameworks: set Sparkle.framework to "Embed & Sign"

# Generate Sparkle EdDSA keypair (one-time, run from the downloaded Sparkle release's bin/ or SPM build artifacts)
./generate_keys

# No new packages needed for: Liquid Glass (system framework, gated by deployment target),
# Volume/Brightness HUD (CoreGraphics/AudioToolbox/private DisplayServices — all system-linked),
# Focus detection (Intents framework, system-linked), Dual-activity display (SwiftUI only).
```

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|--------------------------|
| `.glassEffect()`/`NSGlassEffectView` (if reference code uses it) | Custom materials/gradient-border composition | Use the custom composition if the user's supplied reference code doesn't target macOS 26, or if avoiding the deployment-target bump is preferred for now |
| `CGEventTap` event-consumption for HUD replacement | Alongside-display (show Islet's HUD without suppressing the system one) | Fall back to alongside-display if the event-tap approach proves unreliable/flaky on-device during the research spike — matches this project's established pattern of a documented Plan B (see FS-01's 5-wave conditional chain) |
| `INFocusStatusCenter` (boolean only) | Reading `~/Library/DoNotDisturb/DB/Assertions.json` | Never — confirmed broken on the project's actual target OS (Tahoe/26). Do not implement this path even as a fallback. |
| Sparkle 2.9.4 via SPM | Manual "check GitHub releases" flow | Only if the user explicitly wants to defer real auto-updates further — Sparkle is otherwise a clean, low-risk addition with no architectural conflict |
| SwiftUI `ZStack`/`overlay`/second `matchedGeometryEffect` for dual-activity | A new bespoke "docking/badge" layout library | Never — would be a new dependency for something SwiftUI's own primitives already cover, contradicts this project's minimal-dependency history (DynamicNotchKit was even passed over in v1.0 in favor of a hand-rolled `NSPanel`) |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|--------------|
| `launchctl unload com.apple.OSDUIHelper.plist` / disabling SIP | Destructive, doesn't survive SIP re-enable, not viable for a distributed app users would run | `CGEventTap` consumption of `NX_SYSDEFINED` before the native HUD fires |
| `CoreDisplay_Display_SetUserBrightness` alone | Doesn't reliably work / doesn't report success on Apple Silicon | `DisplayServices.framework` private calls (`DisplayServicesSetBrightness`) |
| `~/Library/DoNotDisturb/DB/Assertions.json` polling | Confirmed broken on macOS 26 (Tahoe) — this project's actual target OS | `INFocusStatusCenter` (boolean-only, accept the scope reduction) |
| A third-party glass/blur SwiftUI package | SwiftUI + AppKit materials already cover this; no gap a library fills | `.glassEffect()` (26+) or materials/gradient composition (15+) |
| Rolling a custom notification/observer abstraction for Sparkle | `SPUUpdaterDelegate` already gives exactly the callbacks needed | Wire `SPUStandardUpdaterController`/`SPUUpdaterDelegate` directly into a new `IslandActivity` case |
| A new layout/badge library for the dual-activity bubble | Pure SwiftUI composition (already the project's whole UI approach) fully covers this | `ZStack` + `.overlay(alignment:)` + a second `matchedGeometryEffect` namespace |

## Stack Patterns by Variant

**If the user's Liquid Glass reference code targets `.glassEffect()`/`NSGlassEffectView`:**
- Raise `MACOSX_DEPLOYMENT_TARGET` 15.0 → 26.0 in `project.yml` (all 5 entries, mirroring the Phase 26 precedent).
- Because there is no back-compat requirement (hobby project, direct distribution, dev hardware already Tahoe) and the project already crossed this exact bridge once for `.defaultLaunchBehavior(.suppressed)`.

**If it targets a materials/gradient composition instead:**
- No deployment target change; ship on the current 15.0 floor.
- Because the visual result is achievable without the real system API, and holding the lower floor costs nothing here.

**For Volume/Brightness HUD:**
- Spike first (single throwaway prototype: can the event tap reliably suppress the native OSD on the dev Mac, does Input Monitoring permission behave as expected, does the tap survive sleep/wake) before committing to full replacement in the roadmap.
- Because this is explicitly flagged (by the milestone context itself) as MediaRemote-precedent-level risk — the project's own established pattern (Phase 8/9's FS-01 conditional-escalation chain) is exactly the right shape to reuse here.

## Version Compatibility

| Component | Compatible With | Notes |
|-----------|------------------|-------|
| `.glassEffect()` / `NSGlassEffectView` | macOS 26.0+ only | `API_AVAILABLE(macos(26.0))` — hard floor, no back-compat shim exists from Apple |
| `DisplayServices.framework` private calls | Apple Silicon, current macOS | Confirmed working path on M-series; the older `CoreDisplay` path is Intel-era and unreliable on Apple Silicon |
| `INFocusStatusCenter` | macOS 12+ | Stable, public, unaffected by the Tahoe Assertions.json breakage |
| Sparkle 2.9.4 | Xcode 16+, SPM | No known conflicts with this project's existing SPM dependency (`mediaremote-adapter`) |
| `CGEventTap` `NX_SYSDEFINED` interception | All current macOS versions | Mechanism itself is stable across versions; **taps get silently disabled by the OS** on timeout/user-input/sleep-wake regardless of macOS version — always was and remains a runtime-lifecycle risk, not a version risk |

## Sources

- Apple Developer Documentation — `developer.apple.com/documentation/appkit/nsglasseffectview` — `NSGlassEffectView` availability confirmed macOS 26.0+ (HIGH)
- Microsoft Learn .NET/macOS API mirror — `learn.microsoft.com/en-us/dotnet/api/appkit.nsglasseffectview` — corroborates the `API_AVAILABLE(macos(26.0))` annotation (MEDIUM-HIGH, independent corroboration)
- DEV Community — "Liquid Glass in Swift: Official Best Practices for iOS 26 & macOS Tahoe" — `.glassEffect()` API shape (`Glass`, `GlassEffectContainer`, `tint()`/`interactive()`) (MEDIUM)
- Klarity Blog — "How I Built Glassmorphism on macOS 14 While Apple Requires macOS 26" — materials/gradient-border fallback technique for pre-26 targets (MEDIUM, single source, but internally consistent with known SwiftUI primitives)
- SlimHUD GitHub discussion #23 (`AlexPerathoner/SlimHUD`) — confirms no documented OSD-suppression API exists; launchctl/SIP approach and key-interception approach both documented by maintainers (MEDIUM-HIGH, direct from an open-source HUD-replacement tool's own maintainers)
- `danielraffel.me` — "CGEvent Taps and Code Signing: The Silent Disable Race" — event tap lifecycle risk (timeout/user-input/sleep-wake disable) (MEDIUM)
- WebSearch synthesis on `NX_SYSDEFINED`/media-key event tap technique (`.cghidEventTap`, `.headInsertEventTap`, `data1` bitfield decode) — MEDIUM, multiple independent open-source implementations agree on the mechanism, no single canonical doc (this is inherently undocumented territory)
- `alexdelorenzo.dev` — "Reverse Engineering CoreDisplay API" + `github.com/alexdelorenzo/brightness` — CoreDisplay vs. DisplayServices, Apple Silicon caveat (MEDIUM)
- Apple Developer Documentation — `kAudioHardwareServiceDeviceProperty_VirtualMainVolume` — public, documented CoreAudio volume control (HIGH)
- `github.com/felixrieseberg/macos-notification-state`, `github.com/Macjutsu/super` discussion #237/issue #155 — confirms `~/Library/DoNotDisturb/DB/Assertions.json` approach is broken specifically on macOS 26 Tahoe, recommends `SetFocusFilterIntent`/AppIntents as the replacement (MEDIUM-HIGH, multiple independent community reports converging on the same conclusion)
- Apple Developer Documentation — "Handling Communication Notifications and Focus Status Updates" (`developer.apple.com/documentation/usernotifications/...`) — `INFocusStatusCenter` existence and Communication Notifications entitlement requirement (HIGH on existence, MEDIUM on exact runtime behavior since full API docs weren't directly fetchable)
- GitHub API (`api.github.com/repos/sparkle-project/Sparkle/releases/latest`) — confirmed current release **2.9.4**, published 2026-07-03 (HIGH, direct from source)
- `sparkle-project.org/documentation/` and `github.com/sparkle-project/Sparkle` — SPM support, `SPUUpdater`/`SPUUserDriver`/`SPUStandardUpdaterController`, LSUIElement handling, Hardened-Runtime/library-validation notes, EdDSA signing requirement (HIGH, official docs)
- Droppy (`getdroppy.app`, `github.com/1of1Adam/Droppy`) — confirms the reference competitor app does ship exactly this class of HUD replacement (volume/brightness/AirPods), validating feasibility in principle without exposing Droppy's own private-API internals (MEDIUM, product-level confirmation not implementation detail)

---
*Stack research for: Islet v1.6 (Liquid Glass & System HUD Suite) — new capabilities only*
*Researched: 2026-07-15*
