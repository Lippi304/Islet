---
phase: 00-foundations-notarization-dry-run
reviewed: 2026-06-26T00:00:00Z
depth: standard
files_reviewed: 7
files_reviewed_list:
  - Islet/IsletApp.swift
  - Islet/AppDelegate.swift
  - Islet/SettingsView.swift
  - Islet/LaunchAtLogin.swift
  - scripts/release.sh
  - project.yml
  - .gitignore
findings:
  critical: 0
  high: 1
  medium: 3
  low: 3
  total: 7
status: resolved
resolution: "HR-01, MR-01, MR-02, MR-03 fixed in commit 5ab9ea2 (rebuilt + release.sh re-run, all green). 3 low findings accepted as defensive/intentional."
---

# Phase 00: Code Review Report

**Reviewed:** 2026-06-26
**Depth:** standard
**Files Reviewed:** 7
**Status:** issues_found

## Summary

Solid, well-commented Phase-0 foundation. The `LaunchAtLogin` wrapper is correct (system-as-source-of-truth, throws on failure, never persists a private flag). `release.sh` is genuinely safe: `set -euo pipefail`, no real secrets, placeholder-gated notarize, `ditto`/`hdiutil` used correctly, all expansions quoted, and no injection surface (no user/network input reaches a command). The intentional un-sandboxed + ad-hoc-signing decisions (D-03) are correct for this phase and are not flagged.

The findings are mostly robustness gaps in the AppKit↔SwiftUI window lifecycle — the one area where this design is genuinely fragile. The HIGH item is a real launch-time race that can let the Settings window flash on screen at every login, which directly contradicts the stated goal of a silent menu-bar agent. None are security or data-loss issues.

## High

### HR-01: Launch-time window-hide is a race that can flash the Settings window on every login

**File:** `Islet/AppDelegate.swift:36-47`, `Islet/IsletApp.swift:23`
**Issue:** Hiding the Settings window relies on a single `DispatchQueue.main.async` in `applicationDidFinishLaunching` calling `orderOut`. But a SwiftUI `Window(id:)` scene is not guaranteed to have instantiated its `NSWindow` by the time that async block runs — window creation for the scene can happen on a later run-loop pass. If `NSApp.windows` contains no `identifier == "settings"` window yet, `hideSettingsWindowOnLaunch()` matches nothing, the loop is a silent no-op, and the window subsequently appears. For an `LSUIElement` agent registered as a login item, that means a Settings window flashing up at every login — the exact behavior the code comments say it must prevent. The runtime `orderOut` hack is also racing SwiftUI's own window presentation, so even when it works it can produce a visible flash.
**Fix:** Prefer the declarative API over the runtime hack. On macOS 15+ use the scene modifier so the window is never presented at launch in the first place:
```swift
Window("Islet Settings", id: "settings") { … }
    .defaultLaunchBehavior(.suppressed)   // macOS 15+: don't open at launch
```
If the 14.0 floor must be kept (where `.suppressed` is unavailable), make the hide robust instead of one-shot: retry until the window exists, and only stop once it has been ordered out at least once. For example, re-dispatch `hideSettingsWindowOnLaunch()` for a few run-loop passes (or observe `NSWindow.didBecomeKeyNotification` / use a short timer) until a `"settings"` window was found and hidden, rather than assuming it exists on the first async tick.

## Medium

### MR-01: `codesign --deep` is deprecated and silently mis-signs nested code

**File:** `scripts/release.sh:73`
**Issue:** The ad-hoc branch uses `codesign --force --deep --sign -`. `--deep` is deprecated by Apple and is explicitly not recommended for producing a correctly signed app — it does not apply per-binary entitlements and is documented as a "fallback only" mechanism. Once this app embeds frameworks (the planned `MediaRemoteAdapter.framework`, Sparkle), `--deep` signing is exactly the pattern that produces apps that pass `codesign --verify` locally but fail notarization or Gatekeeper. Establishing it now bakes in a habit that will break a later phase, and the Developer-ID branch (line 76) correctly does NOT use `--deep`, so the two branches are already inconsistent.
**Fix:** Drop `--deep` and sign inside-out (sign embedded frameworks/dylibs first, then the app bundle last). For Phase 0 with no embedded code yet, simply removing `--deep` is sufficient:
```bash
codesign --force --sign - "${APP_PATH}"
```
Add per-framework signing in the phase that introduces the first embedded framework.

### MR-02: `xcodebuild archive` may need an explicit destination and can hang on signing prompts

**File:** `scripts/release.sh:51-52`
**Issue:** `xcodebuild -scheme … -configuration Release archive` omits `-destination` and any provisioning flags. With `CODE_SIGN_STYLE: Automatic` (project.yml:20) and no Team, archive on a CI-less machine can stall on an interactive signing/account prompt or pick an unintended destination, which defeats the "re-runnable, unattended" goal. Because the script runs under `set -e`, a non-fatal-but-stuck archive will block silently rather than fail loudly.
**Fix:** Pin the platform and disable interactive provisioning:
```bash
xcodebuild -scheme "${SCHEME}" -configuration Release \
  -destination 'generic/platform=macOS' \
  -allowProvisioningUpdates \
  archive -archivePath "${ARCHIVE_PATH}"
```

### MR-03: `requiresApproval` is only checked after a `register()` success, missing the common case

**File:** `Islet/SettingsView.swift:13-16`, `Islet/LaunchAtLogin.swift:21-28`
**Issue:** After `set(on)` succeeds, the code checks `LaunchAtLogin.requiresApproval` to deep-link the user to Login Items settings. But the realistic flow is: `register()` itself succeeds while the system status becomes `.requiresApproval` (user must approve in System Settings before it actually runs at login). In that case `set(_:)` returns `isEnabled` which is `false` (status is `.requiresApproval`, not `.enabled`), so the toggle visually flips back OFF even though registration succeeded and is merely pending approval — confusing UX. The `requiresApproval` deep-link still fires, but the toggle state now contradicts it.
**Fix:** Treat `.requiresApproval` as "on (pending)" for the toggle, or surface a distinct pending state. Minimal fix — reflect pending-approval as enabled in the UI:
```swift
launchAtLogin = try LaunchAtLogin.set(on)
if LaunchAtLogin.requiresApproval {
    launchAtLogin = true            // pending approval still counts as "on"
    LaunchAtLogin.openLoginItemsSettings()
}
```

## Low

### LR-01: Force-unwrapped `statusItem` is fragile if accessed before launch

**File:** `Islet/AppDelegate.swift:5`
**Issue:** `private var statusItem: NSStatusItem!` is an implicitly-unwrapped optional. It is assigned in `applicationDidFinishLaunching`, so today it is safe, but any future access from another path (e.g. an early notification handler) before launch completes would crash. Low risk given current call sites.
**Fix:** Make it a plain optional `NSStatusItem?` and guard at use sites, or document the launch-only invariant. Not urgent.

### LR-02: `openSettings()` double-fronts the window (notification + direct fallback)

**File:** `Islet/AppDelegate.swift:52-57`
**Issue:** `openSettings` both posts `.openIsletSettings` (which calls `openWindow` + `NSApp.activate`) AND directly calls `makeKeyAndOrderFront` on the first matching window. On first open before the SwiftUI window exists, the direct fallback finds nothing (`first { … }` returns nil, harmlessly) and `openWindow` does the real work; on subsequent opens both paths fire and one is redundant. Harmless but indicates the two mechanisms aren't cleanly factored — a future reader may not know which is authoritative.
**Fix:** Pick one source of truth. Since `openWindow(id:)` reliably re-shows an existing `Window` scene, the direct `makeKeyAndOrderFront` fallback can be dropped once HR-01's launch race is fixed.

### LR-03: `versionString` returns "? (?)" silently when Info.plist keys are missing

**File:** `Islet/SettingsView.swift:40-44`
**Issue:** Missing `CFBundleShortVersionString`/`CFBundleVersion` collapse to `"?"`. With `GENERATE_INFOPLIST_FILE: YES` and `MARKETING_VERSION`/`CURRENT_PROJECT_VERSION` set in project.yml these are always present, so this is purely defensive. The fallback is reasonable; flagging only so the silent `"?"` is a known, intentional choice rather than an oversight.
**Fix:** None required. Optionally assert in debug builds if a key is missing to catch a future Info.plist regression.

---

_Reviewed: 2026-06-26_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
