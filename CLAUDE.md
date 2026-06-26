<!-- GSD:project-start source:PROJECT.md -->
## Project

**Notch — Dynamic Island for Mac**

A native macOS app that turns the MacBook's notch into an interactive "Dynamic Island" — the same idea Apple ships on the iPhone, brought to the Mac. A black, rounded island sits around the camera/notch and expands on hover/click to show live activities: now-playing media controls, a charging/device-connected animation, a drag-and-drop file shelf, system HUDs, and a timer.

It is for Mac users who love the iPhone Dynamic Island and want it on their MacBook without paying for the existing closed-source apps (Alcove, DynamicLake). Built by a first-time programmer with the goal of a polished, possibly sellable product down the line.

**Core Value:** The notch becomes a beautiful, reliable "island" that shows now-playing media and reacts when you plug in the charger or connect a device — it must feel native, smooth, and as polished as the iPhone Dynamic Island. If everything else is cut, that core island experience must work.

### Constraints

- **Tech stack**: Native macOS — Swift + SwiftUI/AppKit — Web/Electron can't cleanly do a borderless notch overlay, MediaRemote integration, or HUD replacement; both reference apps are native
- **Platform**: macOS on Apple-silicon notch MacBooks only (v1) — narrows scope and avoids non-notch edge cases
- **API**: Now Playing depends on the private MediaRemote framework — works but blocks Mac App Store; plan for direct notarized distribution
- **Builder skill**: First-time programmer — phases must include a setup/foundations ramp; explanations accompany the important code; avoid unnecessary complexity
- **Distribution**: Direct download, code-signed + notarized — requires an Apple Developer account ($99/yr) before any public release (not needed for local development)
- **Budget**: Hobby/personal budget — no paid services assumed beyond the eventual Developer account
<!-- GSD:project-end -->

<!-- GSD:stack-start source:research/STACK.md -->
## Technology Stack

## TL;DR for a first-time builder
## Recommended Stack
### Core Technologies
| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| **Swift** | 6.x (Xcode 16+ default; you can use Swift 5 *language mode* to dodge strict-concurrency errors) | App language | The native, first-party language. For a beginner, use the **Swift 5 language mode** toggle in build settings at first — Swift 6's strict concurrency checking throws confusing compile errors that will slow you down. Move to Swift 6 mode later. |
| **SwiftUI** | Ships with macOS 14/15 SDK | All island UI, animations, layout | Far gentler for a beginner than AppKit: declarative, live previews, and its `spring`/`matchedGeometryEffect` animations are *exactly* the Dynamic-Island morph effect. This is what TheBoringNotch uses. Build ~95% of the visible app here. |
| **AppKit** | Ships with macOS SDK | The overlay *window* only (`NSPanel`), menu-bar item (`NSStatusItem`), global hover/event handling, IOKit/IOBluetooth glue | SwiftUI cannot create a borderless, non-activating, all-Spaces overlay window by itself. You drop into AppKit *only* for the window shell and a few system hooks, then host SwiftUI inside it via `NSHostingView`. Keep AppKit surface area small. |
| **Xcode** | 16+ | IDE, build, sign, run, debug | Already installed. Use the GUI for signing/run; use `xcodebuild`/`notarytool` from Terminal only for the release build. |
- Rationale: SwiftUI is meaningfully better and less buggy on 14+, `matchedGeometryEffect` and modern `Animation` APIs are solid, and notch hardware only exists on machines that easily run 14/15.
- Consider **macOS 15.0 (Sequoia)** instead if you want the newest SwiftUI niceties and don't mind excluding users still on Sonoma. For v1 targeting your own notch MacBook, either is fine. **Recommendation: 14.0** for the slightly wider audience at near-zero cost.
- Note: DynamicNotchKit advertises 13+, but you don't need to support 13 yourself.
### Supporting Libraries
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| **mediaremote-adapter** (`ungive/mediaremote-adapter`, with the Swift wrapper `ejbills/mediaremote-adapter`) | adapter v0.7.x (2026), BSD-3 | Now Playing info + play/pause/next/prev/seek on **macOS 15.4+** | **Required** for the Now Playing feature. This is the canonical modern solution — TheBoringNotch credits it. Add the Swift package, set `MediaRemoteAdapter.framework` to **Embed & Sign**. See the MediaRemote section for the why. |
| **DynamicNotchKit** (`MrKai77/DynamicNotchKit`) | 1.1.0 (Apr 2026), MIT, macOS 13+ | Pre-built notch overlay window + SwiftUI hosting + non-notch fallback | **Optional accelerator.** Great for *transient notifications/popovers* from the notch and saves you the tricky window code. BUT it is oriented at transient `expand()`/`hide()` events, **not** a persistent always-visible compact island. Use it to learn the technique and possibly for HUD-style toasts; expect to write your own `NSPanel` for the always-on collapsed island. Decide in the planning phase. |
| **Sparkle** (`sparkle-project/Sparkle`) | 2.x | Auto-update for direct-distributed apps | Add when you start shipping to real users. The standard, EdDSA-signed updater for non-App-Store macOS apps (TheBoringNotch uses an updater of this kind). Not needed for local dev. |
| **(no third-party Bluetooth/power library)** | — | — | Use Apple's IOKit + IOBluetooth directly; the surface you need is tiny and adding a dependency isn't worth it. |
### Apple frameworks you'll link directly
| Framework | Purpose | Notes / Confidence |
|-----------|---------|--------------------|
| **SwiftUI** | UI + animation | HIGH |
| **AppKit** | `NSPanel`, `NSStatusItem`, `NSHostingView`, event monitors | HIGH |
| **IOKit (IOPowerSources / IOPSKeys)** | Charging state, battery %, AC-connected | HIGH — `IOPSCopyPowerSourcesInfo` + `IOPSNotificationCreateRunLoopSource` for live updates |
| **IOBluetooth** | AirPods/headphone connect & disconnect events | MEDIUM-HIGH — legacy but functional; has the connect/disconnect notification API you need |
| **MediaRemote** (private, via adapter) | Now Playing | MEDIUM — works only through the adapter bridge on 15.4+ |
| **Combine** (optional) | React to state streams (now-playing, power, BT) into SwiftUI | MEDIUM — `@Published`/`ObservableObject` is enough; Combine optional |
### Development Tools
| Tool | Purpose | Notes |
|------|---------|-------|
| **Xcode 16+** | Build, run, debug, sign during dev | For *development*, just run on your own Mac — no Developer account needed. Signing = "Sign to Run Locally" / automatic. |
| **`xcodebuild`** | Scripted release builds | `xcodebuild -scheme … archive` to produce a `.app` for distribution. |
| **`codesign`** | Sign the app with Developer ID | `--options runtime` (hardened runtime) is mandatory for notarization. |
| **`xcrun notarytool`** | Submit to Apple Notary Service | Replaces the old `altool`. `notarytool submit --wait` then `xcrun stapler staple`. |
| **`create-dmg`** (optional, Homebrew) | Package a nice `.dmg` for download | Notarize the `.dmg`, then staple it. |
## Installation / setup (what the user actually does)
# 1. In Xcode: File > New > Project > macOS > App
#    - Interface: SwiftUI
#    - Language: Swift
#    - Set the target's "Swift Language Version" to 5 for now (Build Settings).
#    - Set "macOS Deployment Target" = 14.0.
#    - In Info.plist add  Application is agent (UIElement) = YES   (LSUIElement)
#      so there's no Dock icon / app menu — it's a background notch utility.
# 2. Add the Now Playing bridge via Swift Package Manager:
#    File > Add Package Dependencies…  ->  https://github.com/ejbills/mediaremote-adapter.git
#    Then: target > General > Frameworks > set MediaRemoteAdapter.framework to "Embed & Sign".
# 3. (Optional) Add DynamicNotchKit the same way:
#    https://github.com/MrKai77/DynamicNotchKit   (use 1.1.0+)
# 4. (Later, for releases) Add Sparkle:
#    https://github.com/sparkle-project/Sparkle
## The borderless notch-overlay window (the hard part, made concrete)
## Now Playing — the MediaRemote reality (read this carefully)
- The classic approach — `dlopen` MediaRemote.framework and call `MRMediaRemoteGetNowPlayingInfo` / register for now-playing notifications — **broke in macOS 15.4 (and 15.3 beta)**. Apple now restricts loading MediaRemote to Apple system apps (`com.apple.*`) and a few entitled binaries. Direct calls return `nil`. Tools like `nowplaying-cli` stopped working on 15.4.
- **`mediaremote-adapter`** (`ungive/mediaremote-adapter`, BSD-3, actively maintained into 2026) restores full access by a **dual-process trick**: it invokes the system `/usr/bin/perl` (which carries an Apple bundle id entitled to MediaRemote), dynamically loads a helper framework there, and streams now-playing JSON back to your app over stdout. Playback commands (play/pause/next/prev/seek) flow back the same way. The Swift wrapper `ejbills/mediaremote-adapter` gives you `getTrackInfo {…}`, `play()`, `pause()`, `nextTrack()`, `setTime(seconds:)`.
- **Apple can break this again** in a future macOS. Mitigation: isolate all now-playing code behind one Swift protocol/service so swapping the implementation is a one-file change.
- **App Store is impossible** with this (private framework + spawning perl). This confirms the project's existing decision: **direct + notarized only.**
- **Notarization is fine** even though it's a private framework — notarization is an automated malware scan, *not* the App Store human review. Apps like Alcove ship notarized using exactly this category of technique.
- **Artwork latency**: album art (`artworkData`) can lag a beat after metadata — design the UI to fill art in asynchronously.
## Power / charging detection
- Quick "is the charger plugged in?" → `IOPSCopyExternalPowerAdapterDetails()` non-nil, or check `kIOPSPowerSourceStateKey`.
- Full state (charging?, battery %, time remaining) → `IOPSCopyPowerSourcesInfo()` + `IOPSCopyPowerSourcesList()`, then read `kIOPSIsChargingKey`, `kIOPSCurrentCapacityKey`, `kIOPSMaxCapacityKey`.
- **Live updates** (to trigger the charging animation the moment the cable connects) → `IOPSNotificationCreateRunLoopSource` with a callback, added to the main run loop. This is the event hook the "plugged in" live-activity needs.
## Bluetooth / AirPods connect events
- Register app-wide for connections: `IOBluetoothDevice.register(forConnectNotifications:selector:)`, and per-device `device.register(forDisconnectNotification:selector:)` for disconnects. These fire when AirPods/headphones connect or drop.
- For AirPods specifically you'll match by device name/class.
- **Caveat:** `IOBluetooth` is a *legacy* framework (Apple steers new BLE work to **Core Bluetooth**), but Core Bluetooth is designed for talking to BLE peripherals you act as a *central* for — it is **not** the right tool for "did a paired audio device connect to the system?". For classic connect/disconnect-of-paired-devices events, **IOBluetooth is still the correct and working choice on current macOS.** Keep an eye on deprecation in future releases.
- An app-level Bluetooth entitlement may be required when sandboxed; since you are **not** sandboxing (private MediaRemote rules that out anyway), this is low-friction.
## Animation approach (the Dynamic-Island feel)
- Drive expand/collapse from a single `@State`/`@Published` `isExpanded` (and an enum for the activity kind).
- Wrap state changes in `withAnimation(.spring(response:dampingFraction:))` — a snappy spring is what makes it feel "Apple".
- Use **`matchedGeometryEffect`** with a shared `@Namespace` so elements (album art, the rounded black blob) appear to *morph* between compact and expanded layouts rather than cross-fade. This is the single most important trick for the "liquid" island look.
- The black rounded shape is just a `RoundedRectangle`/`Capsule` whose corner radius and frame animate; match the notch's real corner radius for seamlessness.
- Avoid Core Animation / hand-rolled `CALayer` animations — unnecessary complexity for a beginner when SwiftUI gives this for free.
## Build / sign / notarize / distribute toolchain
## Alternatives Considered
| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| SwiftUI for UI | Pure AppKit (`NSView`/Core Animation) | Only if you hit a SwiftUI wall on a specific custom effect. Far steeper for a beginner — not for v1. |
| Roll your own `NSPanel` for the persistent island | **DynamicNotchKit** | Use DynamicNotchKit if your island is mostly transient notifications/HUDs, or to prototype fast. Switch to custom `NSPanel` for an always-visible compact island it doesn't natively model. |
| `mediaremote-adapter` | AppleScript/JXA "now playing" scripts; `nowplaying-cli` | Fallback only — scripts are slower, app-specific (don't cover all players), and brittle. `nowplaying-cli` is broken on 15.4+. Adapter is strictly better. |
| IOBluetooth for connect events | Core Bluetooth | Core Bluetooth only if you genuinely act as a BLE central to a custom peripheral — not for system paired-device connect events. |
| macOS 14.0 target | macOS 15.0 target | Choose 15.0 if you only care about newest SwiftUI APIs and your own machine; choose 13.0 only if you must support very old hardware (you don't — notch Macs are recent). |
| Sparkle for updates | Manual "download new version" / Homebrew cask | Manual is fine for a first private release; add Sparkle before a public launch. |
## What NOT to Use
| Avoid | Why | Use Instead |
|-------|-----|-------------|
| **Electron / web / Tauri** | Cannot make a true borderless notch overlay across Spaces, can't bridge MediaRemote, can't replace system HUDs cleanly. Both reference apps are native. | Swift + SwiftUI/AppKit |
| **Mac App Store distribution** | MediaRemote is a private framework and you spawn a helper process — guaranteed rejection. | Direct download, **notarized** |
| **Direct `dlopen` of MediaRemote.framework / `MRMediaRemoteGetNowPlayingInfo`** | **Broken on macOS 15.4+** for non-Apple apps; returns nil. | `mediaremote-adapter` bridge |
| **`nowplaying-cli`** as a backend | Stopped working on 15.4+. | `mediaremote-adapter` |
| **`altool`** for notarization | Deprecated/removed. | `xcrun notarytool` |
| **App sandboxing** | Incompatible with the MediaRemote bridge (spawning perl) and some IOKit/IOBluetooth access. | Ship un-sandboxed, hardened-runtime, notarized (App-Store-incompatible anyway). |
| **Swift 6 strict-concurrency mode (at the very start)** | Floods a beginner with `Sendable`/actor-isolation compile errors unrelated to the actual feature. | Start in **Swift 5 language mode**, migrate later. |
| **Core Bluetooth for "did AirPods connect"** | Wrong abstraction; it's for being a BLE central, not observing system paired devices. | IOBluetooth connect/disconnect notifications |
| **Combine-heavy architecture from day one** | Extra concepts for a beginner. | Plain `ObservableObject` + `@Published`; add Combine only where it clearly helps. |
## Stack Patterns by Variant
- Use **DynamicNotchKit** to render a SwiftUI view from the notch and confirm hover/expand works.
- Because it removes the trickiest window code while you learn, then you can graduate to a custom `NSPanel`.
- Write a custom `NSPanel` (borderless, non-activating, `.statusBar` level, all-Spaces) holding an `NSHostingView`.
- Because DynamicNotchKit centers on transient `expand()`/`hide()` events rather than a persistent compact pill.
- Keep all now-playing behind one `NowPlayingService` protocol.
- Because the MediaRemote bridge is the most likely thing Apple disrupts; isolation makes the fix a one-file swap.
## Version Compatibility
| Component | Compatible With | Notes |
|-----------|-----------------|-------|
| SwiftUI `matchedGeometryEffect` + modern springs | macOS 14+ | Solid on 14/15; rationale for the 14.0 floor. |
| `mediaremote-adapter` bridge | macOS through 15.4, 15.5+, and macOS 26 betas | The whole point of the adapter is forward-compat across the 15.4 break; still verify after each major macOS update. |
| DynamicNotchKit 1.1.0 | macOS 13+ | You target 14+, so fine. |
| `notarytool` | Xcode 13+ (you have 16) | Use it; not `altool`. |
| IOBluetooth connect/disconnect APIs | Current macOS | Functional but legacy — watch for future deprecation. |
| Swift 6 toolchain w/ Swift 5 language mode | Xcode 16 | Lets a beginner avoid strict concurrency while staying on the current compiler. |
## Sources
- TheBoringNotch — `github.com/TheBoredTeam/boring.notch` — SwiftUI, macOS 14+, uses mediaremote-adapter, NotchDrop-inspired shelf. (HIGH — primary open-source reference)
- mediaremote-adapter — `github.com/ungive/mediaremote-adapter` (BSD-3, v0.7.x, May 2026) and Swift wrapper `github.com/ejbills/mediaremote-adapter`. (HIGH on existence/approach; MEDIUM on long-term stability)
- LyricFever issue #94 & nowplaying-cli issue #28 — confirm MediaRemote direct access broke on macOS 15.3/15.4. (MEDIUM-HIGH, multiple corroborating community reports)
- The Apple Wiki "Dev:MediaRemote.framework" — framework background. (MEDIUM)
- DynamicNotchKit — `github.com/MrKai77/DynamicNotchKit`, v1.1.0 (Apr 2026), MIT, macOS 13+. (HIGH)
- Apple Developer — `developer.apple.com/documentation/security/notarizing-macos-software-before-distribution`, `notarytool` docs, Xcode 16.2 release notes. (HIGH)
- Apple Developer — `nonactivatingPanel` style mask; IOBluetooth / IOBluetoothDevice docs. (HIGH for window mask; MEDIUM-HIGH for IOBluetooth)
- Apple Developer Forums thread 128048 — IOKit `IOPSCopyPowerSourcesInfo` / external power adapter detection for charging state. (MEDIUM-HIGH)
- SwiftUI floating-panel / NSPanel pattern articles (Itsuki, fazm.ai, gaitatzis) — borderless non-activating overlay recipe with `collectionBehavior` all-Spaces. (MEDIUM, multiple sources agree)
- matchedGeometryEffect + Dynamic Island animation tutorials (Design+Code, Better Programming) — confirm the spring + matched-geometry approach. (MEDIUM-HIGH)
- BluetoothConnector — `github.com/lapfelix/BluetoothConnector` — real IOBluetooth usage on macOS. (MEDIUM)
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

Conventions not yet established. Will populate as patterns emerge during development.
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

Architecture not yet mapped. Follow existing patterns found in the codebase.
<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->
## Project Skills

No project skills found. Add skills to any of: `.claude/skills/`, `.agents/skills/`, `.cursor/skills/`, or `.github/skills/` with a `SKILL.md` index file.
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->



<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
