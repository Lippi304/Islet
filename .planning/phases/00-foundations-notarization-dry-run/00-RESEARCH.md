# Phase 0: Foundations & Notarization Dry Run - Research

**Researched:** 2026-06-26
**Domain:** Native macOS app foundations — menu-bar agent (SwiftUI/AppKit), launch-at-login (SMAppService), code-signing/notarization/stapling toolchain, local Gatekeeper demonstration
**Confidence:** HIGH (toolchain verified on this machine; APIs cross-verified against Apple docs + 2025/2026 community sources)

## Summary

Phase 0 builds a feature-less but runnable **menu-bar-only agent** named "Islet" and proves the entire release toolchain on a hello-world build. There is no island, overlay, or activity yet — only the app shell (status item + minimal SwiftUI Settings window), the `SMAppService` launch-at-login plumbing, and a re-runnable `sign → notarize → staple` script with clearly-marked placeholders. The real notarization run is deliberately deferred to Phase 6 (Apple Developer account is deferred per D-01); this phase only *prepares* it so the script runs unchanged once credentials exist.

**Critical environment finding (HIGH, changes the plan):** This machine runs **macOS 26.0 (Tahoe), Xcode 26.6, Swift 6.3.3** — not the macOS 14-15 / Xcode 16 assumed in CONTEXT.md/CLAUDE.md. The deployment *floor* of macOS 14.0 (D-06) is still correct and unaffected, but two things change: (1) the SwiftUI `Settings` scene + `SettingsLink`/`openSettings` approach for opening preferences from a menu-bar item is **broken/unreliable on macOS 26** — the Tahoe-correct pattern is a regular `Window` scene opened via `openWindow(id:)` after `NSApp.activate(ignoringOtherApps:)`; and (2) Swift 6.3 toolchain defaults to Swift 6 language mode, so the **Swift 5 language mode** toggle (per CLAUDE.md, to avoid strict-concurrency errors) must be set explicitly. Hardened Runtime is on by default in modern Xcode templates.

**Primary recommendation:** Create a SwiftUI App-lifecycle project, set `INFOPLIST_KEY_LSUIElement = YES`, `SWIFT_VERSION = 5`, `MACOSX_DEPLOYMENT_TARGET = 14.0`, bundle id `com.lippi304.islet`, display name "Islet". Use an `NSStatusItem` built in an `NSApplicationDelegateAdaptor` AppDelegate (full control over the NSMenu) plus a `Window(id: "settings")` scene; open it from the menu with `NSApp.activate(ignoringOtherApps:)` then `openWindow`. Wire the Launch-at-Login toggle to `SMAppService.mainApp`. Write a single commented `scripts/release.sh` doing archive → export → codesign (`--options runtime --timestamp`) → DMG (`hdiutil` or `create-dmg`) → `notarytool submit --wait` → `stapler staple`, with `notarytool`/Developer-ID parts gated behind clearly-marked placeholder variables. Demonstrate Gatekeeper locally by setting `com.apple.quarantine` and running `spctl --assess`.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Apple Developer Program account ($99/yr) is **deferred** — NOT acquired during Phase 0. Purchased only when publish-ready.
- **D-02:** Phase 0 "done" = (a) locally signed build runs as a menu-bar agent; (b) a `.dmg` artifact is built; (c) full `sign → notarize → staple` flow captured as a **repeatable, commented shell script** with clearly-marked placeholders for Developer ID identity + Apple ID / notary credentials; (d) Gatekeeper block-behavior demonstrated locally. Real `notarytool submit` + `stapler staple` + clean-second-Mac open are a **documented carry-over executed at Phase 6**.
- **D-03:** Local dev signing uses **ad-hoc / "Sign to Run Locally"** (`codesign -s -`). No paid Developer ID cert now.
- **D-04:** **No second Mac available.** Gatekeeper verified on this Mac by setting `com.apple.quarantine` + running `spctl` assessment; document the expected "unidentified developer" block on the un-notarized build and what notarization will change.
- **D-05:** Distribution artifact format = **`.dmg`**, built in Phase 0 even though notarization runs later.
- **D-06:** Deployment floor = **macOS 14.0 (Sonoma)**. `SMAppService` requires 13+ — satisfied.
- **D-07:** Working display name = **"Islet"** (changeable later).
- **D-08:** Bundle identifier = **`com.lippi304.islet`** (lowercase). Stable — launch-at-login registration depends on it; must not change casually.
- **D-09:** Build a **minimal Settings window now** (SwiftUI) containing the Launch-at-Login toggle + a version/build label. Foundation Phase 6 (APP-03) extends.
- **D-10:** Menu-bar dropdown = **"Settings…"** (opens the settings window) + **"Quit Islet"**.
- **D-11:** Menu-bar status item icon = a simple **monochrome SF Symbol as a template image** (capsule / notch-like), easily swappable later.

### Claude's Discretion
- Launch-at-login via `SMAppService` (project standard per CLAUDE.md); registration/error handling details.
- The exact SF Symbol name.
- App & version number scheme.
- Repo location of the build script (e.g. `scripts/`).
- The Xcode-artifact `.gitignore`.
- The hardened-runtime flag (`--options runtime`) placement inside the script.
- The minimal entitlements (un-sandboxed per CLAUDE.md).
- The placeholder `.app` icon.

### Deferred Ideas (OUT OF SCOPE)
- **Real notarization + clean-second-Mac Gatekeeper test** (Phase 0 success criterion #3) → executed at **Phase 6 release**, once the Apple Developer account is purchased. Not new scope — the Phase 0 criterion deliberately carried forward because the paid account is deferred.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| APP-01 | App runs as menu-bar / background agent with no Dock icon, with a menu to open settings and quit | `INFOPLIST_KEY_LSUIElement = YES` hides Dock icon; `NSStatusItem` in an AppDelegate builds the menu ("Settings…", "Quit Islet"); `NSApp.terminate(nil)` for quit. See *Architecture Patterns* §1-2. |
| APP-02 | User can enable "launch at login" from settings | `SMAppService.mainApp.register()`/`unregister()` + `.status` read; SwiftUI Toggle wiring with external-change reflection. See *Architecture Patterns* §3. |
| APP-04 | App ships as a Developer-ID signed + notarized + stapled download that opens on a clean Mac without Gatekeeper warnings | `codesign --options runtime --timestamp` → DMG → `notarytool submit --wait` → `stapler staple`, captured as a script with placeholders (real run deferred to Phase 6 per D-01/D-02). Local Gatekeeper demo via quarantine + `spctl`. See *Architecture Patterns* §4-5 and *Code Examples*. |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

These have the same authority as locked decisions — plans must not contradict them:

- **Native Swift + SwiftUI** for ~95% of UI; **AppKit only** for the window shell, `NSStatusItem`, event hooks. Keep AppKit surface small. (Phase 0 uses AppKit only for the status item + the window-activation glue.)
- **Swift 5 language mode** at the start (Build Settings `SWIFT_VERSION = 5`) — Swift 6 strict concurrency floods a beginner with `Sendable`/actor errors. Migrate later.
- **macOS deployment target = 14.0**; `LSUIElement` (Application is agent) = YES; no Dock icon / app menu.
- **Un-sandboxed**, hardened-runtime, notarized (App-Store-incompatible by design — MediaRemote + perl spawning in later phases). Do **not** enable App Sandbox.
- **`xcrun notarytool`** (NOT deprecated `altool`); `--options runtime` (hardened runtime) is mandatory for notarization.
- **Launch-at-login via `SMAppService`** (ServiceManagement) — the project standard. Not the deprecated `SMLoginItemSetEnabled` / `LaunchAtLogin` legacy helpers.
- **First-time programmer:** surface exact Xcode settings, exact API/CLI invocations, common beginner pitfalls; explain important code alongside it.

## Standard Stack

This phase is almost entirely **first-party Apple frameworks + command-line tools** — no third-party Swift packages are needed in Phase 0 (mediaremote-adapter, DynamicNotchKit, Sparkle all belong to later phases).

### Core
| Component | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| Swift | 5 language mode (on Swift 6.3.3 toolchain) | App language | Per CLAUDE.md; Swift 5 mode avoids strict-concurrency compile errors for a beginner `[VERIFIED: swift --version on this machine = 6.3.3]` `[CITED: CLAUDE.md "What NOT to Use"]` |
| SwiftUI | macOS 14 SDK | Settings window UI, app lifecycle (`@main App`) | Declarative, gentlest for a beginner `[CITED: CLAUDE.md]` |
| AppKit | macOS SDK | `NSStatusItem`, `NSMenu`, `NSApp.activate`, `NSApplicationDelegateAdaptor` | SwiftUI's `MenuBarExtra` cannot fully model a custom NSMenu + reliable Settings open on macOS 26; drop to AppKit for the status item `[VERIFIED: macOS 26 Settings-from-menubar pitfall, see Common Pitfalls]` |
| ServiceManagement (`SMAppService`) | macOS 13+ | Launch-at-login for the main app | First-party replacement for deprecated `SMLoginItemSetEnabled` `[CITED: developer.apple.com/documentation/servicemanagement/smappservice]` |

### Supporting (command-line tools — all verified present on this machine)
| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| `xcodebuild` | Xcode 26.6 | Scripted archive + export for the release build | In `scripts/release.sh` `[VERIFIED: xcodebuild -version = 26.6, build 17F113]` |
| `codesign` | system (`/usr/bin/codesign`) | Sign `.app` (ad-hoc now, Developer ID later) | Both local dev (`-s -`) and release (`--options runtime --timestamp`) `[VERIFIED: which codesign]` |
| `hdiutil` | system | Build the `.dmg` from the `.app` (no extra install) | Default DMG builder — zero dependencies `[VERIFIED: ships with macOS]` |
| `xcrun notarytool` | Xcode 26.6 | Submit to Apple Notary service | Release script (real run deferred, placeholders now) `[VERIFIED: xcrun notarytool --help works]` |
| `xcrun stapler` | Xcode 26.6 | Attach the notarization ticket to the DMG/app | After notarization (deferred) `[VERIFIED: xcrun stapler --help works]` |
| `spctl` | system (`/usr/sbin/spctl`) | Local Gatekeeper assessment | Demonstrate the un-notarized block (D-04) `[VERIFIED: which spctl]` |
| `xattr` | system | Set/inspect `com.apple.quarantine` | Local Gatekeeper demo (D-04) `[VERIFIED: ships with macOS]` |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `hdiutil` for the DMG | `create-dmg` v1.2.3 (`brew install create-dmg`) | `create-dmg` gives a prettier DMG (icon layout, Applications drop-link, built-in `--codesign`/`--notarize`) but is **not installed** on this machine `[VERIFIED: which create-dmg → not found]`. `hdiutil` has zero dependencies and is enough for a hello-world artifact. Recommend `hdiutil` for Phase 0; note `create-dmg` as a Phase-6 polish option. `[VERIFIED: github.com/create-dmg/create-dmg release v1.2.3, 2025-11-18]` |
| `NSStatusItem` (AppKit) for the menu bar | SwiftUI `MenuBarExtra` (macOS 13+) | `MenuBarExtra` is simpler but: (a) reliably opening the SwiftUI `Settings` scene from it is **broken on macOS 26** (see Pitfall 1); (b) it gives less control over a classic dropdown NSMenu. D-10/D-11 want a plain dropdown + template image — `NSStatusItem` is the safer, fully-controllable choice. `[VERIFIED: multiple 2025/2026 sources on MenuBarExtra+Settings breakage]` |
| `SMAppService` | `sindresorhus/LaunchAtLogin`, deprecated `SMLoginItemSetEnabled` | Legacy helpers add a dependency or use deprecated API. `SMAppService.mainApp` needs no helper bundle and is the project standard. `[CITED: CLAUDE.md; theevilbit.github.io/posts/smappservice]` |

**Installation:** No `npm`/SPM packages for Phase 0. Optional: `brew install create-dmg` if a polished DMG is wanted now (otherwise `hdiutil`, already present).

**Version verification (run before finalizing the plan):**
```bash
xcodebuild -version            # → Xcode 26.6 (17F113)  [VERIFIED]
swift --version                # → 6.3.3                [VERIFIED]
sw_vers                        # → macOS 27.0 / build 26A5368g  [VERIFIED — Tahoe/26 era]
xcrun notarytool --version
xcrun stapler --help
which create-dmg || echo "use hdiutil"
```
> Note: `sw_vers` reports `ProductVersion 27.0` on this build while the marketing/SDK generation is **macOS 26 "Tahoe"** (Swift target `macosx28.0`). Treat all "macOS 26 Tahoe" community findings as applying to this machine. The macOS 14.0 deployment floor is independent of the host OS.

## Architecture Patterns

### Recommended Project Structure
```
Islet/                          # repo root (already a git repo)
├── Islet.xcodeproj/            # Xcode project (created in Phase 0)
├── Islet/                      # app source target
│   ├── IsletApp.swift          # @main App: Window(id:"settings") + AppDelegate adaptor
│   ├── AppDelegate.swift       # NSStatusItem + NSMenu (Settings…, Quit Islet)
│   ├── SettingsView.swift      # SwiftUI: Launch-at-Login toggle + version label
│   ├── LaunchAtLogin.swift     # @Observable wrapper over SMAppService.mainApp
│   ├── Islet.entitlements      # minimal, un-sandboxed (hardened runtime only)
│   └── Assets.xcassets/        # placeholder AppIcon
├── scripts/
│   └── release.sh              # commented sign→dmg→notarize→staple with placeholders
└── .gitignore                  # ignore build/, DerivedData/, *.xcuserstate, dist/
```

### Pattern 1: Menu-bar-only agent (hide Dock icon)
**What:** Mark the app as an agent so it has no Dock icon and no app menu.
**When to use:** APP-01 requires it.
**How:** Set the build setting (modern Xcode generates Info.plist — no file by default):
- `INFOPLIST_KEY_LSUIElement = YES` (shows in Xcode's Info pane as "Application is agent (UIElement)"). `[VERIFIED: sarunw.com + nilcoalescing — INFOPLIST_KEY_LSUIElement maps to the generated plist]`
- This is the equivalent of the old `LSUIElement = YES` Info.plist key. With `GENERATE_INFOPLIST_FILE = YES` (the default for new projects), each Info.plist key has an `INFOPLIST_KEY_*` build-setting form. `[CITED: developer.apple.com/documentation/BundleResources/managing-your-app-s-information-property-list]`

### Pattern 2: NSStatusItem menu in a SwiftUI-lifecycle app
**What:** A status-bar item with a template SF Symbol and a dropdown menu, created from an AppDelegate.
**When to use:** APP-01, D-10, D-11.
**Why AppDelegate (not pure SwiftUI):** SwiftUI `@main App` alone can't create a classic `NSStatusItem` dropdown; bridge via `NSApplicationDelegateAdaptor`. Keep this AppKit surface tiny (per CLAUDE.md).
**Example:**
```swift
// Source: nilcoalescing.com/blog/BuildAMacOSMenuBarUtilityInSwiftUI +
//         sjhooper/TahoeMenuDemo (macOS 26 working pattern) + Apple NSStatusItem docs
import SwiftUI
import AppKit

@main
struct IsletApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // A normal Window scene — NOT the SwiftUI `Settings` scene.
        // The Settings scene + SettingsLink/openSettings is unreliable from a
        // menu-bar item on macOS 26 (see Common Pitfalls). A plain Window
        // opened via openWindow(id:) after NSApp.activate is the robust path.
        Window("Islet Settings", id: "settings") {
            SettingsView()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            // D-11: monochrome SF Symbol as a TEMPLATE image (auto light/dark tint).
            let image = NSImage(systemSymbolName: "capsule.fill",
                                accessibilityDescription: "Islet")
            image?.isTemplate = true          // <- the key line for a template image
            button.image = image
        }

        let menu = NSMenu()
        menu.addItem(withTitle: "Settings…",
                     action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Islet",
                     action: #selector(quit), keyEquivalent: "q")
        for item in menu.items { item.target = self }
        statusItem.menu = menu
    }

    @objc private func openSettings() {
        // macOS 26-correct: activate first, THEN open the window, or it appears
        // behind other apps / silently no-ops.
        NSApp.activate(ignoringOtherApps: true)
        // Open the SwiftUI Window scene by id. Use the SwiftUI environment
        // openWindow from a hosting view, OR drive it via a small bridge.
        NSApp.sendAction(Selector(("openSettingsWindowFromMenu")), to: nil, from: nil)
        // Simplest robust approach: see note below — call openWindow(id:"settings")
        // from a stored reference, or post a Notification a SwiftUI view observes.
    }

    @objc private func quit() {
        NSApp.terminate(nil)   // D-10: "Quit Islet"
    }
}
```
**Opening the Window scene cleanly:** SwiftUI's `openWindow` action lives in the SwiftUI environment, not in AppKit. Two clean options for the planner to pick:
1. **Notification bridge** — AppDelegate posts a `Notification`; a tiny always-present SwiftUI view (e.g. a 1×1 `Window` or a view inside the settings scene's `commands`) calls `@Environment(\.openWindow) openWindow; openWindow(id:"settings")` on receipt. `[VERIFIED: steipete.me hidden-window pattern]`
2. **Direct NSWindow lookup** — after `openWindow`, the AppDelegate calls `NSApp.windows.first { $0.identifier?.rawValue == "settings" }?.makeKeyAndOrderFront(nil)`.
The **TahoeMenuDemo** repo demonstrates the canonical macOS-26 sequence: `NSApp.activate(ignoringOtherApps: true)` then `openWindow(id: "settings")` from a SwiftUI button. `[CITED: github.com/sjhooper/TahoeMenuDemo]`

### Pattern 3: Launch-at-Login via SMAppService bound to a SwiftUI Toggle
**What:** Register/unregister the main app as a login item, reading live status so the UI reflects external changes (user toggling in System Settings).
**When to use:** APP-02, D-09.
**Key rule:** Read state from `SMAppService.mainApp.status` — never persist the toggle locally, because the user can remove the login item in System Settings at any time. `[CITED: nilcoalescing.com/blog/LaunchAtLoginSetting]`
**Example:**
```swift
// Source: nilcoalescing.com/blog/LaunchAtLoginSetting (2025) + Apple SMAppService docs
import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @State private var launchAtLogin = (SMAppService.mainApp.status == .enabled)
    @Environment(\.appearsActive) private var appearsActive   // refocus → re-sync

    var body: some View {
        Form {
            Toggle("Launch Islet at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, on in
                    do {
                        if on { try SMAppService.mainApp.register() }
                        else  { try SMAppService.mainApp.unregister() }
                    } catch {
                        // Revert UI to the true system state on failure.
                        launchAtLogin = (SMAppService.mainApp.status == .enabled)
                        // If .requiresApproval, optionally:
                        // SMAppService.openSystemSettingsLoginItems()
                    }
                }

            LabeledContent("Version") {
                Text(Self.versionString)   // D-09: version/build label
            }
        }
        .onAppear { syncFromSystem() }
        .onChange(of: appearsActive) { _, active in if active { syncFromSystem() } }
        .padding(20)
        .frame(width: 360)
    }

    private func syncFromSystem() {
        launchAtLogin = (SMAppService.mainApp.status == .enabled)
    }

    static var versionString: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(v) (\(b))"
    }
}
```
**Status enum cases** to know: `.enabled`, `.notRegistered`, `.notFound`, `.requiresApproval`. `.requiresApproval` means registration succeeded but the user must approve in System Settings → General → Login Items; you may call `SMAppService.openSystemSettingsLoginItems()` to take them there. `[CITED: developer.apple.com/documentation/servicemanagement/smappservice/status-swift.enum/requiresapproval]`
**No helper config needed for `mainApp`:** registering the *main app itself* as a login item requires **no** separate helper bundle, no extra Info.plist `SMLoginItemSetEnabled`/`BTMOptions`, and no LaunchAgent plist. Those are only for `loginItem(identifier:)`/`agent(plistName:)`/`daemon(plistName:)`. `[CITED: theevilbit.github.io/posts/smappservice]`
**Beginner caveat:** `SMAppService` registration is keyed to the bundle id (D-08) and **only behaves correctly for a properly-signed app installed in a stable location** (e.g. /Applications). During raw Xcode "Run", login-item registration may be flaky or register the DerivedData build path. Verify the toggle against a built `.app` run from a fixed location, and document this for the user. `[ASSUMED — see Assumptions Log A1]`

### Pattern 4: Re-runnable release script (sign → dmg → notarize → staple)
**What:** One commented `scripts/release.sh` that runs the whole pipeline, with the Developer-ID / notary parts behind clearly-marked placeholder variables so it runs **unchanged** once D-01 credentials exist.
**When to use:** APP-04, D-02 (success criterion #4).
**Structure (the planner turns each step into a task):**
1. `xcodebuild -scheme Islet -configuration Release archive -archivePath build/Islet.xcarchive`
2. Export the `.app` from the archive (or read it out of the archive's `Products/Applications/`).
3. `codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID" Islet.app` (hardened runtime mandatory for notarization). For the local dry-run with no cert, the script can detect the placeholder and fall back to ad-hoc `codesign -s -` (D-03).
4. Build the DMG: `hdiutil create -volname "Islet" -srcfolder build/export -ov -format UDZO dist/Islet.dmg`. **Use `ditto`, not `cp -r`,** if staging the app into a folder first — `cp -r` corrupts framework symlinks. `[CITED: gist.github.com/rsms ...]`
5. `codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID" dist/Islet.dmg` (sign the DMG too).
6. **(Deferred / placeholder)** `xcrun notarytool submit dist/Islet.dmg --keychain-profile "$NOTARY_PROFILE" --wait`
7. **(Deferred / placeholder)** `xcrun stapler staple dist/Islet.dmg`
8. **(Deferred / placeholder)** verify: `spctl --assess -vvv --type install dist/Islet.dmg`

**Placeholders to mark prominently** (these are the only things the user fills in at Phase 6):
- `DEVELOPER_ID="Developer ID Application: Your Name (TEAMID)"` — the signing identity.
- `NOTARY_PROFILE="islet-notary"` — created once via `xcrun notarytool store-credentials "islet-notary" --apple-id "you@example.com" --team-id "TEAMID"` (prompts for an app-specific password). `[CITED: scriptingosx.com/2021/07/notarize-a-command-line-tool-with-notarytool]`
- `APPLE_ID`, `TEAM_ID` (only needed if using `--apple-id/--team-id/--password` inline instead of the stored keychain profile).

**Hardened runtime + entitlements (un-sandboxed):** Hardened Runtime (`--options runtime`) is required by notarization and is **on by default** in modern Xcode templates (`ENABLE_HARDENED_RUNTIME = YES`). Do NOT enable App Sandbox. Phase 0 needs **no special entitlements** — an empty/minimal `Islet.entitlements` (or none) is correct for a hello-world un-sandboxed app. (MediaRemote/IOKit-related entitlements arrive in later phases.) `[CITED: CLAUDE.md "App sandboxing — avoid"; ENABLE_HARDENED_RUNTIME default verified via Apple notarization docs]`

### Pattern 5: Local Gatekeeper demonstration (no second Mac — D-04)
**What:** Show that the un-notarized, ad-hoc-signed build is blocked once it carries the quarantine attribute, and document what notarization changes.
**How (the demo the user runs):**
```bash
# 1. Simulate "downloaded from the internet" by adding the quarantine attribute:
xattr -w com.apple.quarantine \
  "0081;$(printf '%x' $(date +%s));Islet;00000000-0000-0000-0000-000000000000" \
  dist/Islet.dmg
# (or set it on Islet.app)

# 2. Inspect that the attribute is present:
xattr -p com.apple.quarantine dist/Islet.dmg

# 3. Ask Gatekeeper what verdict it would render:
spctl --assess --type install -vvv dist/Islet.dmg     # for the DMG
spctl --assess --type execute -vvv build/export/Islet.app   # for the .app
```
**Expected output for the un-notarized ad-hoc build:** `rejected` with `source=no usable signature` / `source=Unnotarized Developer ID` / "unidentified developer". An ad-hoc signature is explicitly not a Gatekeeper-acceptable signature. `[VERIFIED: HackTricks Gatekeeper + ss64 spctl + Apple dev forum 729336 — ad-hoc/unnotarized → spctl rejected]`
**What notarization changes (document, not run now):** after a real Developer-ID sign + `notarytool` + `stapler staple`, `spctl --assess` returns `accepted source=Notarized Developer ID`, and a double-click on a quarantined copy opens with no Gatekeeper warning. The stapled ticket also makes this work offline. `[CITED: HackTricks Gatekeeper; Apple notarization docs]`
**Beginner-honest caveat:** Gatekeeper's quarantine evaluation happens on first GUI launch; the most faithful local repro is double-clicking the quarantined `.app`/`.dmg` (you'll get the block dialog), while `spctl --assess` gives the headless verdict. `spctl` global enable/disable was locked down in recent macOS, but `--assess` (read-only verdict) still works. `[VERIFIED: ss64 spctl; macOS 15+ removed `spctl --master-disable` GUI path]`

### Anti-Patterns to Avoid
- **Using the SwiftUI `Settings {}` scene + `SettingsLink`/`openSettings` to open preferences from the status-bar menu** — unreliable on macOS 14-15 from a menu-bar app and reportedly broken on macOS 26. Use a regular `Window(id:)` + `openWindow` + `NSApp.activate` instead. (Pitfall 1.)
- **Persisting the launch-at-login toggle in `@AppStorage`/UserDefaults as the source of truth** — it desyncs from System Settings. Read `SMAppService.mainApp.status`.
- **Enabling App Sandbox** — breaks later MediaRemote/IOKit work and is App-Store-only anyway. Ship un-sandboxed.
- **Using `altool` for notarization** — deprecated/removed; use `xcrun notarytool`.
- **`cp -r` to stage the `.app` into the DMG folder** — corrupts framework symlinks; use `ditto`.
- **Leaving Swift in Swift 6 language mode** — the 6.3 toolchain defaults to it; a beginner gets strict-concurrency errors. Set `SWIFT_VERSION = 5`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Launch at login | A custom LaunchAgent plist + `launchctl` shell-out, or `SMLoginItemSetEnabled` helper | `SMAppService.mainApp` | First-party, no helper bundle, handles approval state + System-Settings sync `[CITED: Apple docs]` |
| Notarization upload | A custom curl uploader to Apple's API | `xcrun notarytool submit --wait` | Apple's tool handles auth, polling, retries; altool is dead `[CITED: scriptingosx]` |
| Attaching the notarization ticket | Manual ticket fetch | `xcrun stapler staple` | One command; also enables offline Gatekeeper pass `[CITED: Apple docs]` |
| DMG creation | A bespoke disk-image builder | `hdiutil create` (or `create-dmg` for polish) | `hdiutil` ships with macOS; `create-dmg` adds layout/codesign/notarize flags `[VERIFIED]` |
| Gatekeeper verdict | Parsing logs / re-implementing assessment | `spctl --assess -vvv` | The supported way to see Gatekeeper's verdict `[VERIFIED: ss64]` |
| Status-bar template icon tinting | Manual light/dark image swapping | `NSImage.isTemplate = true` + SF Symbol | macOS auto-tints template images for menu bar `[VERIFIED: Apple NSImage docs]` |

**Key insight:** Phase 0 is "wiring up Apple's plumbing correctly," not building anything novel. Every hard part already has a first-party tool. The only real risk is using the *wrong* (deprecated or version-mismatched) one.

## Common Pitfalls

### Pitfall 1: Settings window won't open (or opens behind) from the menu-bar item on macOS 26
**What goes wrong:** Clicking "Settings…" does nothing, or the window appears behind other apps without focus.
**Why it happens:** Menu-bar agents use `.accessory`/`.prohibited` activation policy and are not the "active" app. The SwiftUI `Settings` scene + `SettingsLink`/`openSettings` rely on an active SwiftUI window context that a background agent lacks. Apple removed the old `showSettingsWindow:` selector in macOS 14; `openSettings` works on macOS 15 but **fails on macOS 26**. `[VERIFIED: steipete.me 2025; Apple dev forum 731628; mjtsai.com]`
**How to avoid:** Use a regular `Window(id: "settings")` scene (not `Settings {}`), and from the menu call `NSApp.activate(ignoringOtherApps: true)` **before** `openWindow(id: "settings")`. The `sjhooper/TahoeMenuDemo` repo is the working macOS-26 reference. `[CITED: github.com/sjhooper/TahoeMenuDemo]`
**Warning signs:** Window never appears; appears behind; works in Xcode-run but not in the built agent.

### Pitfall 2: Swift 6 strict-concurrency errors flood the build
**What goes wrong:** Confusing `Sendable`/actor-isolation / main-actor errors unrelated to the feature.
**Why it happens:** Xcode 26's Swift 6.3 toolchain defaults new projects to Swift 6 language mode.
**How to avoid:** Set `SWIFT_VERSION = 5` (Build Settings → "Swift Language Version" → 5). Migrate to 6 later. `[CITED: CLAUDE.md]`
**Warning signs:** Build errors mentioning `Sendable`, `@MainActor`, "actor-isolated".

### Pitfall 3: Launch-at-login toggle "lies" / desyncs
**What goes wrong:** The toggle shows ON but the app doesn't launch (or vice-versa) after the user changed it in System Settings.
**Why it happens:** Local state was treated as the source of truth.
**How to avoid:** Always re-read `SMAppService.mainApp.status` on `onAppear` and when the window regains focus (`appearsActive`); revert the toggle if `register()` throws. `[CITED: nilcoalescing.com]`
**Warning signs:** Toggle state differs from System Settings → Login Items.

### Pitfall 4: Notarization later fails on a build that wasn't hardened
**What goes wrong:** `notarytool` rejects the build for missing hardened runtime / secure timestamp / unsigned nested code.
**Why it happens:** Hardened Runtime not enabled, or `--timestamp` omitted, or DMG not signed.
**How to avoid (set up now so Phase 6 just works):** Keep `ENABLE_HARDENED_RUNTIME = YES` (default), sign with `--options runtime --timestamp`, sign the DMG itself, and stage with `ditto`. `[CITED: Apple notarization docs; rsms gist]`
**Warning signs (at Phase 6):** `notarytool log` shows "The executable does not have the hardened runtime enabled."

### Pitfall 5: `LSUIElement` set but app still shows a Dock icon
**What goes wrong:** Dock icon appears despite expecting an agent.
**Why it happens:** Key set in the wrong place, or temporarily flipped to `.regular` activation policy (e.g. to show a window) and not restored.
**How to avoid:** Set `INFOPLIST_KEY_LSUIElement = YES` in Build Settings (modern generated-plist projects). If you ever switch activation policy to bring a window forward, restore `.accessory` afterward — though with the `Window`+`NSApp.activate` pattern above you generally don't need to flip the policy at all. `[VERIFIED: sarunw; Apple BundleResources docs]`

### Pitfall 6: First-time-programmer Xcode project setup mistakes
**What goes wrong:** Wrong interface (Storyboard instead of SwiftUI), wrong bundle id casing, deployment target left at the host OS.
**How to avoid:** New Project → macOS → App; Interface = **SwiftUI**, Language = **Swift**; then in target settings set Bundle Identifier = `com.lippi304.islet` (exact, lowercase — D-08), Display Name = `Islet` (D-07), Deployment Target = **macOS 14.0** (D-06), Swift Language Version = **5**, "Application is agent (UIElement)" = **YES**. `[CITED: CLAUDE.md Installation/setup section]`

## Code Examples

### Store notary credentials once (Phase 6 — placeholder now)
```bash
# Source: scriptingosx.com/2021/07/notarize-a-command-line-tool-with-notarytool
# Run ONCE after the Apple Developer account exists. Prompts for an
# app-specific password (appleid.apple.com → Sign-In & Security).
xcrun notarytool store-credentials "islet-notary" \
  --apple-id "you@example.com" \
  --team-id  "TEAMID1234"
```

### Submit + staple (Phase 6 — placeholder now)
```bash
# Source: scriptingosx.com + Apple docs
xcrun notarytool submit dist/Islet.dmg \
  --keychain-profile "islet-notary" \
  --wait
xcrun stapler staple dist/Islet.dmg
spctl --assess -vvv --type install dist/Islet.dmg   # expect: accepted, Notarized Developer ID
```

### Build the DMG with hdiutil (runs now, no account needed)
```bash
# Source: developer.apple.com forums + rsms gist (use ditto, not cp -r)
rm -rf build/dmgroot && mkdir -p build/dmgroot
ditto build/export/Islet.app build/dmgroot/Islet.app
hdiutil create -volname "Islet" \
  -srcfolder build/dmgroot \
  -ov -format UDZO \
  dist/Islet.dmg
```

### Ad-hoc sign for local dev (D-03 — runs now)
```bash
# Source: Apple codesign docs; "Sign to Run Locally" == ad-hoc identity "-"
codesign --force --deep --sign - build/export/Islet.app
codesign --verify --verbose build/export/Islet.app
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `SMLoginItemSetEnabled` + login-item helper bundle | `SMAppService.mainApp.register()` | macOS 13 (Ventura) | No helper bundle needed; project standard `[CITED: theevilbit]` |
| `altool` for notarization | `xcrun notarytool` | Xcode 13 / 2021 (altool removed Nov 2023) | Must use notarytool `[CITED: scriptingosx]` |
| `NSApp.sendAction(showSettingsWindow:)` to open prefs | `SettingsLink` / `openSettings` (macOS 14-15), **then** plain `Window`+`openWindow`+`NSApp.activate` on macOS 26 | macOS 14 removed the selector; macOS 26 broke `openSettings` from menu bar | Open a `Window` scene, not the `Settings` scene `[VERIFIED: steipete.me, mjtsai]` |
| `Info.plist` file in project | `GENERATE_INFOPLIST_FILE = YES` + `INFOPLIST_KEY_*` build settings | Xcode 13+ | Set `LSUIElement`/bundle id/display name as build settings `[VERIFIED: sarunw]` |
| `cp -r` to stage app for DMG | `ditto` | long-standing | Preserves framework symlinks `[CITED: rsms gist]` |

**Deprecated/outdated:**
- `altool` — removed; use `notarytool`.
- `SMLoginItemSetEnabled` — deprecated; use `SMAppService`.
- `spctl --master-disable` (global Gatekeeper off) — removed from the GUI path in recent macOS; not needed here (we use read-only `--assess`).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `SMAppService.mainApp` login-item registration behaves correctly only for a signed app run from a stable location (not reliably from a raw Xcode DerivedData "Run") | Pattern 3 caveat | If wrong: toggle "works" in Xcode and the planner skips a "test from a built .app in /Applications" verification step — but this is the safe assumption; worst case is an extra, harmless verification step. Low risk. |
| A2 | On this host, `sw_vers` reporting `27.0` corresponds to the macOS 26 "Tahoe" generation for which the menu-bar Settings breakage is documented | Summary / Pitfall 1 | If wrong (host behaves like 15): the `Window`+`openWindow` pattern still works fine — it's the robust superset. Low risk; the recommendation holds either way. |

## Open Questions (RESOLVED)

1. **Exact "open window" wiring (Notification bridge vs. NSWindow lookup)** — RESOLVED: Notification-bridge wiring (per Plan 01).
   - What we know: both work on macOS 26; TahoeMenuDemo uses `openWindow(id:)` from a SwiftUI button after `NSApp.activate`.
   - What's unclear: cleanest way to call `openWindow` from an AppKit AppDelegate selector (SwiftUI's `openWindow` is environment-scoped).
   - Recommendation: planner picks the Notification-bridge variant (AppDelegate posts notification → a SwiftUI view with `@Environment(\.openWindow)` opens it). Documented in Pattern 2. **Resolved in Plan 01 Task 2: the AppDelegate posts `.openIsletSettings`; a `OpenSettingsOnNotification` view modifier on the settings-window content calls `openWindow(id:"settings")` after `NSApp.activate`, with an `NSApp.windows` lookup as a first-launch fallback.**

2. **Whether to install `create-dmg` now or stay on `hdiutil`** — RESOLVED: `hdiutil` for Phase 0 (per Plan 03).
   - What we know: `hdiutil` is present and sufficient; `create-dmg` (not installed) gives a prettier DMG with built-in codesign/notarize flags.
   - Recommendation: use `hdiutil` for Phase 0 (zero deps, matches D-05's "build a .dmg" minimally); note `create-dmg` as an easy Phase-6 upgrade. User can confirm preference at plan-check. **Resolved in Plan 03 Task 2: the release script uses `hdiutil create … -format UDZO`; `create-dmg` is left as a documented Phase-6 polish option.**

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode | Build, archive, sign | ✓ | 26.6 (17F113) | — |
| Swift toolchain | Compile (Swift 5 mode) | ✓ | 6.3.3 | — |
| `xcodebuild` | Scripted release build | ✓ | bundled w/ Xcode 26.6 | — |
| `codesign` | Sign app/dmg | ✓ | system | — |
| `xcrun notarytool` | Notarize (deferred run) | ✓ | bundled w/ Xcode 26.6 | — |
| `xcrun stapler` | Staple ticket (deferred run) | ✓ | bundled | — |
| `spctl` | Local Gatekeeper assessment | ✓ | system | — |
| `xattr` | Set `com.apple.quarantine` | ✓ | system | — |
| `hdiutil` | Build the `.dmg` | ✓ | system | — |
| `create-dmg` | (optional) prettier DMG | ✗ | — | `hdiutil` (use this) |
| Apple Developer ID cert + account | Real notarization (Phase 6) | ✗ | — | **Deferred by design (D-01)** — script uses placeholders; ad-hoc `codesign -s -` for local dev (D-03) |
| Second Mac | Clean Gatekeeper open test | ✗ | — | **Deferred by design (D-04)** — local quarantine + `spctl --assess` demo instead |

**Missing dependencies with no fallback:** None that block Phase 0. (The Developer ID account and second Mac are *intentionally* deferred to Phase 6 per D-01/D-04 — not blockers.)

**Missing dependencies with fallback:**
- `create-dmg` → use `hdiutil` (recommended for Phase 0 anyway).
- Apple Developer ID → ad-hoc signing now; the script's signing/notarization steps are placeholdered to run unchanged later.

## Validation Architecture

> nyquist_validation = true in config → section included.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | None applicable for unit testing in Phase 0 — success criteria are behavioral/system-level (app launches as agent, toggle persists, script runs, `spctl` verdict). A Swift unit-test target (XCTest, bundled with Xcode) is optional but adds little here. |
| Config file | none — see Wave 0 |
| Quick run command | `xcodebuild -scheme Islet -configuration Debug build` (compiles cleanly) |
| Full suite command | `bash scripts/release.sh --dry-run` (whole pipeline up to the deferred notarize step) + the Gatekeeper demo commands |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated / Manual Command | File Exists? |
|--------|----------|-----------|----------------------------|--------------|
| APP-01 | Builds & runs as menu-bar agent, no Dock icon | smoke (build) + manual (visual) | `xcodebuild -scheme Islet build` then run; confirm no Dock icon, menu shows "Settings…"/"Quit Islet", Settings opens, Quit terminates | ❌ Wave 0 (project not created yet) |
| APP-02 | Launch-at-login toggle registers/unregisters and reflects system state | manual (system-level) | Toggle ON → check System Settings → Login Items shows Islet; log out/in → app starts; toggle OFF → it stops. Verify against a built `.app` in a fixed location (Pattern 3 caveat) | ❌ Wave 0 |
| APP-04 (script) | Full sign→dmg→(notarize)→staple captured as a re-runnable script with placeholders | integration (script executes to the deferred boundary) | `bash scripts/release.sh` produces a signed `dist/Islet.dmg`; notarize/staple steps are placeholdered and skipped with a clear message | ❌ Wave 0 |
| APP-04 (Gatekeeper) | Un-notarized build is blocked under quarantine; what notarization changes is documented | manual (verdict check) | `xattr -w com.apple.quarantine ... dist/Islet.dmg` then `spctl --assess --type install -vvv dist/Islet.dmg` → expect `rejected` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `xcodebuild -scheme Islet build` (must compile, no Swift-6-mode errors).
- **Per wave merge:** Run the app; confirm agent behavior + toggle; run `scripts/release.sh` to the deferred boundary.
- **Phase gate:** All four Phase-0 success criteria demonstrated (criterion #3's *real* notarized clean-Mac open is the documented Phase-6 carry-over, not a Phase-0 gate).

### Wave 0 Gaps
- [ ] `Islet.xcodeproj` + SwiftUI app target — none exists yet (fresh repo).
- [ ] `scripts/release.sh` — the re-runnable pipeline with placeholders.
- [ ] `.gitignore` for Xcode artifacts (`build/`, `DerivedData/`, `dist/`, `*.xcuserstate`).
- [ ] (Optional) An XCTest target only if any pure-logic helper (e.g. `versionString`) is worth unit-testing — likely overkill for Phase 0.
- [ ] Framework install: none required (all CLI tools present; `create-dmg` optional).

## Security Domain

> security_enforcement not present in config → treated as enabled. Phase 0 is a hello-world shell with no input handling, no network, no auth, no data storage — most ASVS categories are N/A. The security-relevant surface is the **distribution/integrity chain** (signing, hardened runtime, notarization) and the deliberate **un-sandboxed** posture.

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | No auth in app; notary auth is Apple's (app-specific password in keychain) |
| V3 Session Management | no | N/A |
| V4 Access Control | no | N/A |
| V5 Input Validation | no | No user/file/network input in Phase 0 |
| V6 Cryptography | no (use, not implement) | Code signing/notarization handled entirely by Apple tooling — never hand-roll |
| V10 Malicious Code / Integrity | yes | Hardened Runtime (`--options runtime`), secure timestamp (`--timestamp`), Developer-ID sign + notarize + staple (deferred run); ad-hoc only for local dev |
| V14 Configuration | yes | Un-sandboxed by necessity (documented in CLAUDE.md); no secrets in repo — notary credentials live only in the keychain profile, never committed |

### Known Threat Patterns for this stack
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Tampered/unsigned binary delivered to users | Tampering | Developer-ID sign + notarize + staple; Gatekeeper enforces (demoed locally now) |
| Notary credentials leaked into the repo / script | Information Disclosure | Store via `notarytool store-credentials` (keychain); script references a profile *name* only; placeholders for Apple ID/Team ID; `.gitignore` any local secrets |
| Un-sandboxed app over-privileged | Elevation of Privilege | Phase-0 scope is empty — no entitlements granted; keep entitlements minimal in later phases. Accepted tradeoff: sandbox is incompatible with MediaRemote (CLAUDE.md). |

## Sources

### Primary (HIGH confidence)
- Local toolchain probe — `xcodebuild -version` (26.6/17F113), `swift --version` (6.3.3), `sw_vers` (macOS 27.0/26A5368g), `xcrun notarytool/stapler --help`, `which codesign/spctl`, `which create-dmg` (absent). [VERIFIED this session]
- developer.apple.com/documentation/servicemanagement/smappservice — SMAppService API, status enum, `requiresApproval`, `openSystemSettingsLoginItems()`.
- developer.apple.com/documentation/BundleResources/managing-your-app-s-information-property-list — generated Info.plist / `INFOPLIST_KEY_*`.
- developer.apple.com — notarization + notarytool docs (hardened runtime requirement).

### Secondary (MEDIUM-HIGH confidence — cross-verified)
- nilcoalescing.com/blog/LaunchAtLoginSetting — SMAppService + SwiftUI Toggle, status-driven, `appearsActive` re-sync (2025).
- nilcoalescing.com/blog/BuildAMacOSMenuBarUtilityInSwiftUI — menu-bar app, LSUIElement, quit button.
- steipete.me/posts/2025/showing-settings-from-macos-menu-bar-items — Settings-from-menu-bar breakage on 14/15/26 + workarounds (2025).
- github.com/sjhooper/TahoeMenuDemo — working macOS 26 menu-bar window-open pattern (`NSApp.activate` + `openWindow(id:)`).
- scriptingosx.com/2021/07/notarize-a-command-line-tool-with-notarytool — notarytool store-credentials/submit/stapler.
- theevilbit.github.io/posts/smappservice — SMAppService kinds; mainApp needs no helper bundle.
- github.com/create-dmg/create-dmg — v1.2.3 (2025-11-18), install + codesign/notarize options.
- sarunw.com — `INFOPLIST_KEY_*` mapping; Apple dev forum 731628 — SettingsLink from MenuBarExtra issue.

### Tertiary (LOW confidence — flagged)
- HackTricks Gatekeeper page + ss64 spctl + Apple dev forum 729336 — ad-hoc/unnotarized → `spctl` `rejected` (consistent across sources; treat exact wording of `spctl` output as indicative, confirm on the actual built artifact during execution).

## Metadata

**Confidence breakdown:**
- Standard stack (Apple-first-party + CLI): HIGH — all tools verified present on the machine; APIs are documented Apple frameworks.
- Architecture (LSUIElement / NSStatusItem / SMAppService / release script): HIGH for the APIs; the macOS-26 Settings-window pattern is MEDIUM-HIGH (verified against multiple 2025/2026 sources + a working demo repo, but exact wiring is a planner choice).
- Pitfalls: HIGH — the macOS-26 Settings breakage and Swift-6-mode trap are corroborated by multiple current sources and the host-version probe.
- Gatekeeper exact `spctl` output strings: MEDIUM — confirm on the real artifact at execution time.

**Research date:** 2026-06-26
**Valid until:** ~2026-07-26 for the toolchain/CLI flags (stable); ~2026-07-10 for the macOS-26 Settings-window pattern (fast-moving — re-verify if the host OS updates).
