# Stack Research

**Domain:** Native macOS notch / "Dynamic Island" overlay utility (now-playing, charging & device activities, file shelf, HUDs, timer)
**Researched:** 2026-06-26
**Confidence:** HIGH on the core stack (Swift/SwiftUI/AppKit, window approach, distribution path); MEDIUM-HIGH on MediaRemote (private API, fast-moving), Bluetooth, and charging detection.

---

## TL;DR for a first-time builder

Build a **menu-bar (LSUIElement / "agent") app in Swift + SwiftUI**, hosted inside a **borderless, non-activating `NSPanel`** that floats at `.statusBar`/`.mainMenu` window level across all Spaces and over full-screen apps. Animate the island's expand/collapse with **SwiftUI `spring` animations + `matchedGeometryEffect`**. Read Now Playing through the **`mediaremote-adapter`** dual-process bridge (the only thing that still works on macOS 15.4+). Detect charging with **IOKit `IOPSCopyPowerSourcesInfo`** and AirPods/Bluetooth with **`IOBluetooth` connect/disconnect notifications**. Ship via **direct download, code-signed with a Developer ID + notarized with `notarytool`** — never the Mac App Store, because MediaRemote is a private framework.

The single highest-risk dependency is **MediaRemote access** (private, Apple keeps tightening it). Everything else is stable, documented Apple framework territory.

---

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| **Swift** | 6.x (Xcode 16+ default; you can use Swift 5 *language mode* to dodge strict-concurrency errors) | App language | The native, first-party language. For a beginner, use the **Swift 5 language mode** toggle in build settings at first — Swift 6's strict concurrency checking throws confusing compile errors that will slow you down. Move to Swift 6 mode later. |
| **SwiftUI** | Ships with macOS 14/15 SDK | All island UI, animations, layout | Far gentler for a beginner than AppKit: declarative, live previews, and its `spring`/`matchedGeometryEffect` animations are *exactly* the Dynamic-Island morph effect. This is what TheBoringNotch uses. Build ~95% of the visible app here. |
| **AppKit** | Ships with macOS SDK | The overlay *window* only (`NSPanel`), menu-bar item (`NSStatusItem`), global hover/event handling, IOKit/IOBluetooth glue | SwiftUI cannot create a borderless, non-activating, all-Spaces overlay window by itself. You drop into AppKit *only* for the window shell and a few system hooks, then host SwiftUI inside it via `NSHostingView`. Keep AppKit surface area small. |
| **Xcode** | 16+ | IDE, build, sign, run, debug | Already installed. Use the GUI for signing/run; use `xcodebuild`/`notarytool` from Terminal only for the release build. |

**Minimum deployment target: macOS 14.0 (Sonoma).**
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

> Reference implementations to read (don't depend on, but study): **TheBoringNotch** (`TheBoredTeam/boring.notch`, SwiftUI, macOS 14+, uses mediaremote-adapter) and **NotchDrop** (`Lakr233/NotchDrop`) for the file-shelf feature later.

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

---

## Installation / setup (what the user actually does)

```text
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
```

There is **no `npm install`** here — macOS native uses Swift Package Manager inside Xcode (a few clicks), not a JavaScript package manager.

---

## The borderless notch-overlay window (the hard part, made concrete)

This is the heart of the app and where SwiftUI alone won't do. Recommended recipe (HIGH confidence — this is the documented community pattern and what notch apps use):

1. **Subclass `NSPanel`** (not `NSWindow`) with style mask `[.borderless, .nonactivatingPanel]`.
   - `.nonactivatingPanel` = clicking the island does **not** steal focus from the app you're using. Essential for a HUD/island.
2. Configure the panel:
   - `isOpaque = false`, `backgroundColor = .clear` (the black rounded island is drawn by SwiftUI, not the window).
   - `hasShadow = false`, `isMovable = false`, `ignoresMouseEvents` toggled per state.
   - `level = .statusBar` (or `.mainMenu` / `.screenSaver`) so it sits **above** normal windows and at/over the menu-bar/notch region.
   - `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]` so it appears on every Space and over full-screen apps and doesn't slide with Spaces.
3. **Position it over the notch**: read `NSScreen.main` (the built-in display), use `screen.frame` plus `screen.safeAreaInsets`/`auxiliaryTopLeftArea`/`auxiliaryTopRightArea` to find the notch width and center the panel on the notch. `safeAreaInsets.top > 0` is a reliable "this screen has a notch" signal.
4. **Host SwiftUI inside**: `panel.contentView = NSHostingView(rootView: IslandRootView())`.
5. **Hover/click detection**: SwiftUI `.onHover` works for the visible island; add an AppKit local/global `NSEvent` monitor or a slightly larger transparent hit area to catch the hover *before* expansion if needed.

**Shortcut:** DynamicNotchKit implements much of steps 1–4 already. Reasonable beginner path: prototype with DynamicNotchKit to *see it working fast*, then, if its transient-notification model doesn't fit the always-visible island, lift these settings into your own `NSPanel`.

---

## Now Playing — the MediaRemote reality (read this carefully)

**Verdict: use `mediaremote-adapter`. Do not call MediaRemote directly. Accept that this is a private API and the reason you're not on the App Store.** (Confidence: MEDIUM — accurate as of mid-2026, but this area changes with macOS releases.)

What changed and why it matters:
- The classic approach — `dlopen` MediaRemote.framework and call `MRMediaRemoteGetNowPlayingInfo` / register for now-playing notifications — **broke in macOS 15.4 (and 15.3 beta)**. Apple now restricts loading MediaRemote to Apple system apps (`com.apple.*`) and a few entitled binaries. Direct calls return `nil`. Tools like `nowplaying-cli` stopped working on 15.4.
- **`mediaremote-adapter`** (`ungive/mediaremote-adapter`, BSD-3, actively maintained into 2026) restores full access by a **dual-process trick**: it invokes the system `/usr/bin/perl` (which carries an Apple bundle id entitled to MediaRemote), dynamically loads a helper framework there, and streams now-playing JSON back to your app over stdout. Playback commands (play/pause/next/prev/seek) flow back the same way. The Swift wrapper `ejbills/mediaremote-adapter` gives you `getTrackInfo {…}`, `play()`, `pause()`, `nextTrack()`, `setTime(seconds:)`.

Risks to flag for the roadmap (these belong in PITFALLS too):
- **Apple can break this again** in a future macOS. Mitigation: isolate all now-playing code behind one Swift protocol/service so swapping the implementation is a one-file change.
- **App Store is impossible** with this (private framework + spawning perl). This confirms the project's existing decision: **direct + notarized only.**
- **Notarization is fine** even though it's a private framework — notarization is an automated malware scan, *not* the App Store human review. Apps like Alcove ship notarized using exactly this category of technique.
- **Artwork latency**: album art (`artworkData`) can lag a beat after metadata — design the UI to fill art in asynchronously.

---

## Power / charging detection

Use **IOKit power sources** (Confidence: HIGH):
- Quick "is the charger plugged in?" → `IOPSCopyExternalPowerAdapterDetails()` non-nil, or check `kIOPSPowerSourceStateKey`.
- Full state (charging?, battery %, time remaining) → `IOPSCopyPowerSourcesInfo()` + `IOPSCopyPowerSourcesList()`, then read `kIOPSIsChargingKey`, `kIOPSCurrentCapacityKey`, `kIOPSMaxCapacityKey`.
- **Live updates** (to trigger the charging animation the moment the cable connects) → `IOPSNotificationCreateRunLoopSource` with a callback, added to the main run loop. This is the event hook the "plugged in" live-activity needs.

`NSProcessInfo`/`ProcessInfo.thermalState` and low-power-mode flags exist but **don't** give charging/connected state — use IOKit. (Confidence: HIGH)

---

## Bluetooth / AirPods connect events

Use **`IOBluetooth`** (Confidence: MEDIUM-HIGH):
- Register app-wide for connections: `IOBluetoothDevice.register(forConnectNotifications:selector:)`, and per-device `device.register(forDisconnectNotification:selector:)` for disconnects. These fire when AirPods/headphones connect or drop.
- For AirPods specifically you'll match by device name/class.
- **Caveat:** `IOBluetooth` is a *legacy* framework (Apple steers new BLE work to **Core Bluetooth**), but Core Bluetooth is designed for talking to BLE peripherals you act as a *central* for — it is **not** the right tool for "did a paired audio device connect to the system?". For classic connect/disconnect-of-paired-devices events, **IOBluetooth is still the correct and working choice on current macOS.** Keep an eye on deprecation in future releases.
- An app-level Bluetooth entitlement may be required when sandboxed; since you are **not** sandboxing (private MediaRemote rules that out anyway), this is low-friction.

---

## Animation approach (the Dynamic-Island feel)

All in **SwiftUI** (Confidence: HIGH — this is the standard technique and exactly what produces the iPhone island morph):
- Drive expand/collapse from a single `@State`/`@Published` `isExpanded` (and an enum for the activity kind).
- Wrap state changes in `withAnimation(.spring(response:dampingFraction:))` — a snappy spring is what makes it feel "Apple".
- Use **`matchedGeometryEffect`** with a shared `@Namespace` so elements (album art, the rounded black blob) appear to *morph* between compact and expanded layouts rather than cross-fade. This is the single most important trick for the "liquid" island look.
- The black rounded shape is just a `RoundedRectangle`/`Capsule` whose corner radius and frame animate; match the notch's real corner radius for seamlessness.
- Avoid Core Animation / hand-rolled `CALayer` animations — unnecessary complexity for a beginner when SwiftUI gives this for free.

---

## Build / sign / notarize / distribute toolchain

Direct, notarized distribution (Confidence: HIGH on the process). **No Developer account needed until you distribute** — local dev runs with automatic "sign to run locally."

When ready to ship to others:
1. **Apple Developer Program** — $99/yr. Create a **Developer ID Application** certificate (Xcode > Settings > Accounts > Manage Certificates > +).
2. **Hardened Runtime ON** + needed entitlements; sign:
   `codesign --force --options runtime --timestamp --sign "Developer ID Application: <Name> (<TeamID>)" --entitlements App.entitlements MyApp.app`
   (sign embedded frameworks like `MediaRemoteAdapter.framework` first / use `--deep` carefully, or sign inside-out).
3. **Package**: zip or, better, a `.dmg` (`create-dmg`).
4. **Notarize**: `xcrun notarytool submit MyApp.dmg --apple-id <id> --team-id <TeamID> --password <app-specific-password> --wait`. (Store creds once with `notarytool store-credentials` to avoid passing them each time.)
5. **Staple**: `xcrun stapler staple MyApp.dmg` so it launches offline without Gatekeeper warnings.

`notarytool` (Xcode 13+) is the current tool; **`altool` is deprecated** — don't use it.

---

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| SwiftUI for UI | Pure AppKit (`NSView`/Core Animation) | Only if you hit a SwiftUI wall on a specific custom effect. Far steeper for a beginner — not for v1. |
| Roll your own `NSPanel` for the persistent island | **DynamicNotchKit** | Use DynamicNotchKit if your island is mostly transient notifications/HUDs, or to prototype fast. Switch to custom `NSPanel` for an always-visible compact island it doesn't natively model. |
| `mediaremote-adapter` | AppleScript/JXA "now playing" scripts; `nowplaying-cli` | Fallback only — scripts are slower, app-specific (don't cover all players), and brittle. `nowplaying-cli` is broken on 15.4+. Adapter is strictly better. |
| IOBluetooth for connect events | Core Bluetooth | Core Bluetooth only if you genuinely act as a BLE central to a custom peripheral — not for system paired-device connect events. |
| macOS 14.0 target | macOS 15.0 target | Choose 15.0 if you only care about newest SwiftUI APIs and your own machine; choose 13.0 only if you must support very old hardware (you don't — notch Macs are recent). |
| Sparkle for updates | Manual "download new version" / Homebrew cask | Manual is fine for a first private release; add Sparkle before a public launch. |

---

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

---

## Stack Patterns by Variant

**If you want the fastest possible "it appears at the notch" win (recommended first step):**
- Use **DynamicNotchKit** to render a SwiftUI view from the notch and confirm hover/expand works.
- Because it removes the trickiest window code while you learn, then you can graduate to a custom `NSPanel`.

**If the island must be *always visible* in its compact form (the Alcove look):**
- Write a custom `NSPanel` (borderless, non-activating, `.statusBar` level, all-Spaces) holding an `NSHostingView`.
- Because DynamicNotchKit centers on transient `expand()`/`hide()` events rather than a persistent compact pill.

**If Now Playing breaks after a macOS update:**
- Keep all now-playing behind one `NowPlayingService` protocol.
- Because the MediaRemote bridge is the most likely thing Apple disrupts; isolation makes the fix a one-file swap.

---

## Version Compatibility

| Component | Compatible With | Notes |
|-----------|------------------|-------|
| SwiftUI `matchedGeometryEffect` + modern springs | macOS 14+ | Solid on 14/15; rationale for the 14.0 floor. |
| `mediaremote-adapter` bridge | macOS through 15.4, 15.5+, and macOS 26 betas | The whole point of the adapter is forward-compat across the 15.4 break; still verify after each major macOS update. |
| DynamicNotchKit 1.1.0 | macOS 13+ | You target 14+, so fine. |
| `notarytool` | Xcode 13+ (you have 16) | Use it; not `altool`. |
| IOBluetooth connect/disconnect APIs | Current macOS | Functional but legacy — watch for future deprecation. |
| Swift 6 toolchain w/ Swift 5 language mode | Xcode 16 | Lets a beginner avoid strict concurrency while staying on the current compiler. |

---

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

---
*Stack research for: native macOS notch / Dynamic Island utility*
*Researched: 2026-06-26*

---
---

# Stack Research Addendum: Trial + Licensing (Polar.sh) + Real Notarization

**Domain:** Trial/licensing + payments (Polar.sh) + real notarized distribution — additions for the "Islet" monetization milestone
**Researched:** 2026-07-05
**Confidence:** MEDIUM-HIGH (Polar.sh API shape verified against current docs; Keychain/notarytool patterns verified against man pages and well-corroborated secondary sources; a couple of official Apple doc pages didn't render via fetch tooling this pass — flagged inline)

This addendum covers ONLY the five new-feature additions for this milestone (trial, one-time purchase via Polar.sh, license validation/caching, trial-expiry lockout, real notarization). It does not re-research the core notch/overlay/MediaRemote/IOKit/IOBluetooth/Settings stack above, which is already validated and unchanged.

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| **URLSession + async/await** (Foundation, ships with Swift 5/6 toolchain) | Built-in | All HTTP calls to Polar.sh's REST API (checkout link open, license-key activate/validate) | Polar.sh has **no official Swift/Apple-platform SDK** (verified — only `@polar-sh/sdk` for Node/JS and a PHP SDK exist; the only Swift package under the "Polar" name on GitHub is the unrelated Polar Electro fitness BLE SDK). The API itself is a plain JSON REST API, small surface (2 endpoints you actually need), so `URLSession.shared.data(for:)` + `Codable` structs is a complete, dependency-free client. Matches the project's "no unnecessary complexity for a first-time programmer" constraint. |
| **Security framework (Keychain Services)** | Ships with macOS SDK | Persist trial-start date + validated license state locally, tamper-resistant-enough and reinstall-resistant | `kSecClassGenericPassword` items survive app deletion/reinstall (unlike `UserDefaults`, which is trivially wiped or hand-edited in a plist), which is exactly the property you want for both trial-abuse resistance and "stay licensed after reinstall." No sandboxing entitlement is required to use it (see notes below). |
| **`xcrun notarytool`** (ships with Xcode 13+; project's build machine is on Xcode 26.6) | Current | Replace the placeholder/dry-run notarization steps in `scripts/release.sh` with real submission | Already the tool the project chose (correctly — `altool` is removed). What's new this milestone is real credentials (Developer ID cert + API key or Apple ID app-specific password) now that a paid Developer account exists. No tool change needed, only wiring real auth. |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| **None (Foundation `Codable` + `URLSession` only)** | Built-in | Decode Polar's JSON responses (`ValidatedLicenseKey`, activation object) | Use plain `struct ...: Codable` models for the request/response shapes below. Do not add Alamofire or similar — the call volume (a handful of requests total, ever) doesn't justify a networking dependency. |
| **(Optional, not required) `kishikawakatsumi/KeychainAccess`** | 4.2.x | Thin Swift wrapper over raw `SecItemAdd`/`SecItemCopyMatching` C API | Only add this if writing the ~40-line Keychain wrapper by hand feels like too much ceremony for the builder. Functionally equivalent to a hand-rolled wrapper; recommendation below is to hand-roll it (one more dependency isn't worth it for one small struct), but it's a reasonable escape hatch if the raw `Security` C API proves confusing. |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| **`xcrun notarytool store-credentials`** | Store real notarization credentials once, outside of `release.sh` / source control | Run manually once per machine: either API-key based (`--key <p8 path> --key-id <id> --issuer <issuer>` for a **Team** key, or the same *without* `--issuer` for an **Individual** key — Individual keys are Xcode 26+ only and error 401 if you pass `--issuer`) or Apple-ID based (`--apple-id <id> --team-id <team> --password <app-specific-password>`). Saves to the login keychain under a profile name that `release.sh` references via `--keychain-profile`. Never put the raw key file or password in the repo. |
| **App Store Connect API key (recommended over Apple ID)** | Auth for `notarytool` | Apple's own guidance favors API keys over Apple-ID + app-specific password (no 2FA prompt dependency, works headlessly in CI later). Generate a key with the "Developer" role (not "Admin") in App Store Connect → Users and Access → Integrations → Notary/API keys. Download the `.p8` once — Apple will not let you re-download it. |
| **Developer ID Application certificate** | Code signing before notarization | Confirm this exists in Keychain Access / `security find-identity -v -p codesigning` before wiring real notarization — this is the one prerequisite the dry-run couldn't exercise. A Developer ID **Installer** cert is only needed if you ship a `.pkg`; since the pipeline already uses `hdiutil` to build a `.dmg`, you don't need the Installer cert. |

## Installation

```bash
# No package manager changes required for Polar.sh integration —
# URLSession + Codable + Security are all part of Foundation/the macOS SDK.

# Optional convenience wrapper (only if hand-rolling Keychain access feels too raw):
# File > Add Package Dependencies… -> https://github.com/kishikawakatsumi/KeychainAccess.git

# notarytool credential storage (run once, per dev machine, NOT in a script/repo):
xcrun notarytool store-credentials "islet-notary" \
  --key "/path/to/AuthKey_XXXXXXXXXX.p8" \
  --key-id XXXXXXXXXX \
  --issuer YYYYYYYY-YYYY-YYYY-YYYY-YYYYYYYYYYYY   # omit --issuer entirely if using an Individual API key (Xcode 26+)

# scripts/release.sh then references it by profile name, e.g.:
xcrun notarytool submit "Islet.dmg" --keychain-profile "islet-notary" --wait
xcrun stapler staple "Islet.dmg"
```

## Polar.sh Integration Details (verified against current docs, 2026)

### 1. Checkout — use a Checkout Link, not the authenticated Checkout Sessions API

Polar has two ways to start a purchase:

- **Checkout Links** (dashboard-generated, public, long-lived URL, e.g. `https://polar.sh/checkout/<id>`) — **no authentication required to create or use**. This is the right fit here: create one Checkout Link for the €7.99 one-time-purchase product in the Polar dashboard, and have the app simply `NSWorkspace.shared.open(url)` it in the default browser. Optional query params (`customer_email`, `customer_name`, `locale`, `theme`, `reference_id`) let you prefill the checkout page.
- **Checkout Sessions API** (`POST /v1/checkouts`) requires an **authenticated, secret** organization API token. **Do not call this from the shipped app** — any secret bearer token embedded in a distributed binary can be extracted (strings/binary inspection) and abused to mint free checkouts or access your organization's API. This is the single most important "don't" for this milestone.

After purchase, Polar emails the license key to the buyer and shows it on their Polar customer portal — the app doesn't need to fetch or generate it; the user pastes it into a Settings/"Enter License Key" field.

### 2. License key validation/activation — public, unauthenticated, desktop-safe endpoints

Both endpoints Polar explicitly documents as safe to call directly from a native/desktop client (no secret key involved):

**Activate** (call once, when the user first enters a key on a device):
```
POST https://api.polar.sh/v1/customer-portal/license-keys/activate
Body: { "key": "<pasted-key>", "organization_id": "<your-org-uuid>", "label": "<device label, e.g. hostname>" }
→ 200: { id: <activation_id>, license_key_id, label, license_key: { status, limit_activations, usage, limit_usage, expires_at, ... } }
```
Only needed if your license-key benefit has "device activations" enabled in the Polar dashboard (recommended — set a generous limit, e.g. 3-5, so a user re-buying a Mac or reinstalling isn't blocked). Store the returned `activation_id` — it strengthens later validation and lets you show "this key is used on N devices."

**Validate** (call once when the key is entered, per the milestone's explicit design — see note below):
```
POST https://api.polar.sh/v1/customer-portal/license-keys/validate
Body: { "key": "<pasted-key>", "organization_id": "<your-org-uuid>", "activation_id": "<from activate, optional>" }
→ 200: ValidatedLicenseKey { status: granted|revoked|disabled, expires_at, limit_activations, usage, limit_usage, ... }
→ 404: key not found   → 422: validation error
```
Both endpoints explicitly state: *"This endpoint doesn't require authentication and can be safely used on a public client, like a desktop application or a mobile app."* — confirming Polar designed this feature for exactly this use case (native/desktop apps), not just web SaaS.

**Confidence:** HIGH on endpoint shape and no-auth-for-desktop guarantee (directly quoted from current Polar docs, `polar.sh/docs/api-reference/customer-portal/license-keys/{validate,activate}`, fetched 2026-07-05). MEDIUM on activation-limit UX defaults — verify current dashboard defaults when setting up the license-key benefit, as dashboard UI details weren't independently confirmed beyond docs text.

### 3. Webhooks — not needed for this milestone

Polar supports webhooks (`checkout.updated`, benefit-grant events, etc.), but those exist for **server-side** integrations that need to react to purchases asynchronously (e.g. provisioning a SaaS account). This app has no backend server and no account system — the client-side validate/activate flow above is the complete, sufficient integration. **Do not build a webhook receiver / server component for this milestone** — it would be unused complexity; the roadmap should explicitly scope this out.

### 4. Local trial + license caching (Keychain)

Recommended shape — a single Keychain item holding a small JSON blob, not multiple loose values:

```swift
struct LicenseState: Codable {
    var firstLaunchDate: Date
    var status: String        // "trial" | "licensed" | "expired" | "revoked"
    var licenseKeyDisplay: String?   // Polar's masked `display_key`, never the raw key, for UI
    var activationID: String?
    var lastValidatedAt: Date?
}
```

- `kSecClass`: `kSecClassGenericPassword`
- `kSecAttrService`: your bundle identifier (e.g. `com.yourname.islet`)
- `kSecAttrAccount`: a fixed constant, e.g. `"license-state"`
- `kSecAttrAccessible`: **`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`** — "AfterFirstUnlock" (not "WhenUnlocked") so a menu-bar app that might be relaunched via a login item before the user has actively unlocked/interacted still finds its state; "ThisDeviceOnly" so the item is **not** synced via iCloud Keychain to the user's other Macs (you don't want one purchased license silently "just working" on a second machine via iCloud sync — activation limits on the Polar side plus this local flag are the two layers of enforcement).
- Store `firstLaunchDate` in the *same* Keychain item on first run. Reading it back on every launch (rather than trusting `UserDefaults` or a plain file) is what makes the 3-day trial resistant to the obvious bypass (delete app → reinstall → fresh trial): the Keychain item outlives app deletion.

**Non-sandboxed considerations (this app is intentionally not sandboxed, per existing project decision for the MediaRemote/perl bridge):** Keychain access on macOS is scoped by code signature (Team ID + a keychain-access-group derived from your app ID), **not** by the App Sandbox. Because you are not sandboxed, you do **not** need the `com.apple.security.application-groups` or sandboxed-keychain-sharing entitlements that a sandboxed app would need — a plain `SecItemAdd`/`SecItemCopyMatching`/`SecItemUpdate` call from your (consistently signed) app works with zero extra entitlements. This is a case where *not* sandboxing simplifies things further, not just a tradeoff. (MEDIUM confidence — Apple's own "Storing Keys in the Keychain" doc page didn't render via fetch tooling in this research pass; corroborated by multiple independent Keychain-usage writeups and is consistent with long-standing macOS Keychain ACL behavior. Worth a 10-minute manual smoke test during implementation: add an item, quit, relaunch, confirm no prompt/entitlement error appears.)

**Honest limitation:** this is "tamper-resistant-enough," not DRM. A technically sophisticated user can still open Keychain Access.app and delete the item, or use `security delete-generic-password`, resetting their trial. Full anti-piracy hardening (code obfuscation, jailbreak-style integrity checks) is out of scope for an indie utility at this budget/skill level and would be a poor time investment — Polar's server-side `status: revoked/disabled` plus this local cache is the right amount of friction.

### 5. Full lock on trial expiry

This is pure app logic (no new library): on every launch, read the cached `LicenseState`, compute `trial_end = firstLaunchDate + 3 days`. If `status != "licensed"` and `now > trial_end`, show a blocking "trial expired, enter license key" view and skip initializing the notch overlay/activities entirely (don't just hide UI — actually gate the app's core init path, matching the milestone's "no functionality" requirement). Re-entering a key re-runs activate+validate and flips `status` to `"licensed"` on success, un-gating the app without a relaunch.

## Real Notarization Toolchain — what changes vs. the existing dry-run

The dry-run already proved the mechanical steps (archive → sign → `hdiutil` → notarize-placeholder → staple-placeholder). What's genuinely new now that a paid account exists:

1. **Enroll in the Apple Developer Program** ($99/yr — already accounted for in project constraints) and confirm team is active in App Store Connect / developer.apple.com/account.
2. **Generate a Developer ID Application certificate** (Xcode → Settings → Accounts → Manage Certificates → "+" → Developer ID Application, or via developer.apple.com/account/resources/certificates). Verify locally with `security find-identity -v -p codesigning` — you want to see `"Developer ID Application: <Your Name> (<TEAMID>)"` in the list, not just an ad-hoc/self-signed identity. No Developer ID Installer cert needed (you distribute via `.dmg`, not `.pkg`).
3. **Create an API key for notarytool** in App Store Connect (Users and Access → Integrations → "Notary" or general API keys) with the **Developer** role — this is Apple's recommended auth method over Apple ID + app-specific password (no interactive 2FA/keychain prompt dependency, works unattended). Download the `.p8` file immediately (one-time download) and store it outside the repo (e.g. `~/.appstoreconnect/private_keys/`).
4. **`xcrun notarytool store-credentials`** once per dev machine, saving the profile to the login keychain (see Installation above). `release.sh` then only ever references `--keychain-profile "islet-notary"` — no secrets touch the script or git history.
5. **Update `scripts/release.sh`**: replace the SKIP-gated placeholder branch with the real `notarytool submit "$DMG_PATH" --keychain-profile "islet-notary" --wait` call, check its exit status / JSON output for `status: Accepted`, then `xcrun stapler staple "$DMG_PATH"`. Consider `--timeout` on `--wait` (Apple's notary service typically completes in under a few minutes, but can occasionally take much longer during outages) so CI/local runs don't hang indefinitely; on timeout, fall back to `notarytool log <submission-id>` to inspect failures rather than re-submitting blindly.
6. **Hardened runtime**: already required for notarization and should already be enabled in the archive build (`codesign --options runtime`) since the dry-run pipeline exists — no new entitlement is needed specifically *for* Polar/licensing, since all networking goes through standard `URLSession` (no extra network entitlements needed for a non-sandboxed app) and Keychain access needs no entitlement either (see above). Confirm no entitlement regressions from adding these features (there shouldn't be any).

**2026-era gotcha, verified:** if you generate an **Individual** API key (tied to your personal Apple ID rather than a Team) — available as an option starting Xcode 26 — you must **omit** `--issuer` entirely when calling `store-credentials`/`submit`; passing an issuer ID with an Individual key causes a 401 Unauthorized. Team-scoped API keys still require `--issuer`. Since the project's build machine is on Xcode 26.6 (per existing project memory), this distinction is directly relevant — decide which key type you generated in App Store Connect and match the flag usage accordingly. (MEDIUM-HIGH confidence — corroborated by the `@electron/notarize` README, which documents this against Apple's own notarytool behavior, and by Apple developer forum reports of the same 401; Apple's own TN3147 migration page didn't render via fetch tooling in this pass, so treat as MEDIUM-HIGH rather than HIGH and re-check the actual error message during implementation if a 401 appears.)

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| Polar.sh Checkout Links (static, no-auth) | Polar Checkout Sessions API (authenticated) | Only if you later build a real backend server that can hold the secret org API token server-side (e.g. for dynamic per-user pricing/discounts computed server-side). Not needed here. |
| Raw `Security` framework Keychain wrapper (hand-rolled) | `KeychainAccess` (kishikawakatsumi) | If the raw `SecItemAdd`/`kSec...` dictionary-based C API feels too unfamiliar during implementation — it's a fine, well-maintained, MIT-licensed convenience wrapper, just an extra dependency for something Foundation already exposes. |
| `notarytool` with App Store Connect API key auth | `notarytool` with Apple ID + app-specific password | If you don't want to manage a `.p8` key file, or the API key generation flow is confusing for a first-time setup — Apple ID auth still works, just prompts more and is slightly more fragile for unattended/CI use later. |
| Cache validated license state in Keychain | Cache in a local file / `UserDefaults` with light obfuscation | Never for the license flag itself (trivially editable). A local file *is* fine as a secondary/UI-only cache of non-sensitive display data (e.g. showing "licensed" badge instantly without a Keychain read), but the source of truth must stay in Keychain. |
| Validate once on key entry, trust cache afterward (per milestone spec) | Periodic best-effort re-validation (e.g. silently re-check online once every N days when network is available, falling back to cache on failure) | Consider this as a fast-follow enhancement, not this milestone — it lets you revoke a refunded/chargeback license without the user ever re-entering it, while still fully preserving offline-first behavior (revalidation is opportunistic, not required for the app to keep working). Flagged as an open question for the roadmap, not a hard requirement of this milestone's stated design. |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|--------------|
| Polar's Checkout Sessions API (authenticated) called directly from the shipped app | Requires embedding a secret organization API token in a distributed binary — extractable via `strings`/disassembly, letting anyone forge checkouts or hit your account's API quota/data | Dashboard-generated Checkout Link (public, no secret, long-lived URL) opened via `NSWorkspace.shared.open` |
| A custom backend server / webhook receiver for licensing | This is a menu-bar utility with no account system; Polar's activate/validate endpoints are explicitly designed to be called unauthenticated from desktop/mobile clients — a server adds hosting cost, complexity, and a new failure mode for zero benefit here | Direct client-side calls to `/v1/customer-portal/license-keys/{activate,validate}` |
| `UserDefaults` (or a plain plist/JSON file) as the sole store for trial-start date or license status | Trivially resettable by editing/deleting a plist — defeats the entire trial-abuse-resistance goal | `kSecClassGenericPassword` Keychain item, which survives app deletion/reinstall |
| Adding Alamofire or another networking library for ~2 API calls total | Unjustified dependency weight/complexity for a call volume this small; `URLSession` + `Codable` already does everything needed | Plain `URLSession.shared.data(for:)` with `async/await` |
| `altool` for notarization | Deprecated/removed by Apple; not usable in current Xcode | `xcrun notarytool submit --wait` |
| Storing notarization credentials (`.p8` key or app-specific password) inside `scripts/release.sh` or committed to git | Leaks Apple Developer credentials into version control/history | `xcrun notarytool store-credentials` once per machine into the login keychain; reference by `--keychain-profile` name only |
| Adding App Sandbox entitlements to enable Keychain access | Unnecessary — the app is intentionally non-sandboxed already (for the MediaRemote/perl bridge), and Keychain access needs zero sandbox entitlements for a non-sandboxed, consistently-signed app | Plain `Security` framework calls, no new entitlements |
| Rolling custom DRM/anti-tamper/obfuscation for the license check | Disproportionate engineering cost for an indie utility at this budget; real determined crackers bypass it anyway | Keychain-backed local cache + Polar's server-side `revoked`/`disabled` status is the appropriate amount of protection |

## Stack Patterns by Variant

**If you want stronger cross-reinstall trial enforcement later:**
- Add a secondary, independent signal (e.g. the creation date of a marker file in `~/Library/Application Support/<bundle-id>/`, compared against the Keychain-stored `firstLaunchDate` — if they disagree by more than a small tolerance, treat as tampered) as defense-in-depth.
- Because a single Keychain item is already good enough for v1 (delete+reinstall no longer resets the trial) — only add the second signal if you observe real abuse.

**If you later add a second product/tier (e.g. a "Pro" add-on) on Polar:**
- Use `product_id` as a query param on the same Checkout Link (Polar supports multiple products per link) rather than creating a whole second link or backend.
- Because Polar's Checkout Links already support multi-product selection natively — no code change needed, just dashboard configuration and a `benefit_id` check in the validate response.

## Version Compatibility

| Component | Compatible With | Notes |
|-----------|------------------|-------|
| Polar.sh REST API `v1` (`api.polar.sh/v1/...`) | Any Swift/Foundation version (plain HTTPS/JSON) | No SDK version to pin; verify `organization_id` and product/benefit IDs are for the correct (Production, not Sandbox) Polar organization before shipping — Polar has separate production and sandbox environments with different base behavior/rate limits (Production: 500 req/min; Sandbox: 100 req/min — irrelevant at this app's call volume, but confirms you must point at the production API host, not a sandbox one, for real purchases). |
| `xcrun notarytool` | Xcode 13+ (project is on Xcode 26.6) | Individual API key support (vs. only Team keys) is new as of Xcode 26 — matches this project's build machine per existing project memory (`build-machine-macos26-toolchain.md`). |
| Keychain `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` | All current macOS versions, sandboxed or not | No SDK/OS version constraint; behavior is stable and long-standing. |
| Non-sandboxed app + Keychain Services | Current macOS (project already ships un-sandboxed) | Confirmed no new entitlement needed; consistent with the project's existing non-sandboxing decision made for the MediaRemote bridge. |

## Sources

- `https://polar.sh/docs/api-reference/customer-portal/license-keys/validate` — fetched directly 2026-07-05; confirmed request/response shape, no-auth-for-desktop-clients statement. HIGH confidence.
- `https://polar.sh/docs/api-reference/customer-portal/license-keys/activate` — fetched directly 2026-07-05; confirmed activation limits, label/meta/conditions fields, no-auth statement. HIGH confidence.
- `https://polar.sh/docs/features/benefits/license-keys` — fetched 2026-07-05; confirmed end-to-end desktop-app workflow description, expiration/usage-limit features. MEDIUM-HIGH confidence.
- `https://polar.sh/docs/features/checkout/links` — fetched 2026-07-05; confirmed Checkout Links are public/no-auth/long-lived vs. authenticated Checkout Sessions API, plus query param list. HIGH confidence.
- WebSearch: "Polar.sh Swift SDK official" — confirmed no official Swift/Apple SDK exists for the billing platform (only Node.js `@polar-sh/sdk` and a PHP SDK; unrelated Polar Electro fitness BLE SDK is a false-positive naming collision). MEDIUM-HIGH confidence (absence-of-evidence claim, corroborated across multiple search results and the `polarsource` GitHub org listing).
- `https://keith.github.io/xcode-man-pages/notarytool.1.html` — fetched 2026-07-05; confirmed `--key`/`--key-id`/`--issuer`, `--apple-id`/`--team-id`/`--password`, `--keychain-profile`, `store-credentials`, `--wait`/`--timeout` flag semantics. HIGH confidence (official man page mirror).
- WebSearch corroborated by `@electron/notarize` README — confirmed Xcode 26+ Individual API key must omit `--issuer` or receives 401. MEDIUM-HIGH confidence (Apple's own TN3147 page did not render via fetch tooling this pass; recommend spot-checking during implementation).
- WebSearch: Keychain `kSecClassGenericPassword` usage patterns (AdvancedSwift, Apple Developer Forums threads) — confirmed generic-password class, service/account/accessible attribute usage for local secret storage on macOS. MEDIUM confidence (Apple's canonical "Storing Keys in the Keychain" doc page did not render via fetch tooling this pass — no full official-doc corroboration obtained; recommend a short manual smoke test in-repo during implementation).
- WebSearch: "Swift URLSession JSON POST async await" (multiple 2026-dated blog sources: oneuptime.com, avanderlee.com, swiftsenpai.com) — confirmed `URLSession.shared.data(for:)` + `Codable` + `async/await` is the current idiomatic, dependency-free pattern. HIGH confidence (converging, current sources; no Context7 entry exists for Foundation itself).

---
*Stack research for: Trial + Polar.sh licensing + real notarization additions to Islet (existing macOS notch app)*
*Researched: 2026-07-05*
