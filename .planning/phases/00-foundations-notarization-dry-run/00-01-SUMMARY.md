---
phase: 00-foundations-notarization-dry-run
plan: 01
subsystem: app-shell
tags: [swiftui, appkit, nsstatusitem, menubar-agent, lsuielement, xcodegen, swift5, appdelegate]

# Dependency graph
requires: []
provides:
  - "Islet.xcodeproj — valid macOS app project (Swift 5 mode, macOS 14.0 floor, LSUIElement agent, bundle id com.lippi304.islet, hardened runtime, un-sandboxed)"
  - "Islet/IsletApp.swift — @main App with NSApplicationDelegateAdaptor + Window(id:\"settings\") scene + Notification bridge"
  - "Islet/AppDelegate.swift — NSStatusItem dropdown (Settings…, Quit Islet) with a template SF Symbol"
  - "Islet/SettingsView.swift — placeholder window content (Plan 02 fills it with the Launch-at-Login toggle)"
  - "project.yml — xcodegen source of truth; regenerate the project with `xcodegen generate`"
  - "Shared scheme Islet (xcshareddata) so `xcodebuild -scheme Islet` resolves headlessly"
affects: [00-02 (replaces SettingsView body, adds LaunchAtLogin.swift), 00-04 (archives the scheme into a DMG), all later phases (build on this app shell)]

# Tech tracking
tech-stack:
  added:
    - "xcodegen (Homebrew, /opt/homebrew/bin/xcodegen) — used to generate Islet.xcodeproj from project.yml"
  patterns:
    - "Menu-bar-only agent (LSUIElement=YES) — no Dock icon; the only AppKit surface is an AppDelegate owning an NSStatusItem"
    - "macOS-26-correct settings window: a real Window(id:\"settings\") scene + Notification bridge, NOT the broken SwiftUI Settings scene"
    - "Template SF Symbol (isTemplate=true) auto-tints in light/dark menu bars"
    - "project.yml (xcodegen) as project source of truth; folder-based sources auto-include new .swift files on regenerate"

key-files:
  created:
    - "Islet.xcodeproj/ (generated)"
    - "Islet/IsletApp.swift"
    - "Islet/AppDelegate.swift"
    - "Islet/SettingsView.swift"
    - "Islet/Assets.xcassets/ (placeholder AppIcon set)"
    - "project.yml"
  modified: []

key-decisions:
  - "Project created via xcodegen (project.yml) instead of the Xcode GUI — at the user's explicit request; the generated .xcodeproj is a normal, valid Xcode project (verified BUILD SUCCEEDED)"
  - "Swift 5 LANGUAGE MODE pinned (SWIFT_VERSION=5.0) to avoid the Xcode 26 Swift-6 strict-concurrency error flood (RESEARCH Pitfall 2)"
  - "Settings UI uses a plain Window(id:) scene + Notification bridge, not the SwiftUI Settings scene (broken from a menu-bar agent on macOS 26 — RESEARCH Pitfall 1)"
  - "AppDelegate openSettings uses BOTH the notification→openWindow bridge AND an NSApp.windows makeKeyAndOrderFront fallback for reliable front-most presentation"

patterns-established:
  - "Keep AppKit surface tiny: one AppDelegate for the status item; everything else is SwiftUI"
  - "Regenerate the project with `xcodegen generate` after adding/removing source files"

requirements-completed: [APP-01]

# Metrics
duration: ~25min
completed: 2026-06-26
---

# Phase 00 Plan 01: Islet menu-bar agent app shell Summary

**Islet now exists as a runnable menu-bar-only background agent: no Dock icon, a monochrome SF-Symbol status item with a "Settings…" / "Quit Islet" dropdown, and a (placeholder) Settings window — built in Swift 5 mode against the macOS 14.0 floor with bundle id com.lippi304.islet.**

## Accomplishments
- Generated `Islet.xcodeproj` (via xcodegen) with all foundation build settings locked in: Swift 5 language mode, macOS 14.0 deployment floor, `LSUIElement=YES` (menu-bar agent, no Dock icon), bundle id `com.lippi304.islet`, hardened runtime ON, App Sandbox OFF.
- Wrote `IsletApp.swift` (@main App + NSApplicationDelegateAdaptor + `Window("Islet Settings", id:"settings")` + Notification bridge), `AppDelegate.swift` (NSStatusItem + NSMenu with a `capsule.fill` template symbol, Settings… / Quit Islet), and a placeholder `SettingsView.swift`.
- Verified the build headlessly: `xcodebuild -scheme Islet -configuration Debug build` → **BUILD SUCCEEDED**; built app's synthesized Info.plist shows `LSUIElement=true` and `CFBundleIdentifier=com.lippi304.islet`.
- Human visual check (Task 3 checkpoint): user confirmed the menu-bar icon appears, the dropdown works, the Settings window opens, and Quit terminates the app — **approved**.

## Task Commits
1. **Tasks 1+2 (project scaffold + menu-bar code)** — `7cfed4c` (feat). Tasks 1 and 2 are an interdependent bootstrap (the project references the source files; neither builds in isolation), so they were committed together as one atomic, buildable commit.

## Files Created/Modified
- `Islet.xcodeproj/` — generated Xcode project (+ shared scheme).
- `Islet/IsletApp.swift`, `Islet/AppDelegate.swift`, `Islet/SettingsView.swift` — the app shell.
- `Islet/Assets.xcassets/` — placeholder AppIcon set (no art yet; swappable later).
- `project.yml` — xcodegen recipe (project source of truth).

## Deviations from Plan

**1. Project created via xcodegen instead of the Xcode GUI**
- **Reason:** The user explicitly asked Claude to create the project for them rather than do the GUI steps. The plan mandated GUI creation for the canonical layout + a valid project file.
- **How the plan's intent was preserved:** xcodegen produces a normal, fully-valid `Islet.xcodeproj` with the exact canonical layout (`./Islet.xcodeproj` + `./Islet/`) and a shared scheme. All of Task 1's acceptance criteria were verified by grep on `project.pbxproj` and by `xcodebuild build` → BUILD SUCCEEDED.
- **Trade-off:** project.yml is now the source of truth; future file additions go through `xcodegen generate` (or Xcode directly — folder-based sources keep both in sync on regenerate). Documented in project.yml's header comment.

## Known Items / Carry-over
- **Settings window auto-presents on app launch.** The SwiftUI `Window(id:)` scene shows its window at launch (and macOS state-restoration can reopen it). For a menu-bar agent this is undesirable once Launch-at-Login is enabled (it would pop the Settings window on every login). **To be resolved in Plan 02**, where SettingsView is reworked and the "opens only when the user picks Settings…" behavior can be implemented and verified with the user. Not a Plan-01 acceptance failure (all 00-01 success criteria are met).

## User Setup Required
None. The app runs locally (ad-hoc "Sign to Run Locally"). No Apple Developer account needed at this phase.

## Next Phase Readiness
- Plan 02 replaces the `SettingsView` placeholder body with the Launch-at-Login toggle + version label and adds `LaunchAtLogin.swift`; the `Window(id:"settings")` binding and bundle id stay unchanged.
- Plan 04 can archive the shared `Islet` scheme into a DMG once Plan 02 finishes.

## Self-Check: PASSED

- FOUND: Islet.xcodeproj/project.pbxproj
- FOUND: Islet/IsletApp.swift, Islet/AppDelegate.swift, Islet/SettingsView.swift
- FOUND: project.yml
- FOUND: Islet.xcodeproj/xcshareddata/xcschemes/Islet.xcscheme
- VERIFIED: xcodebuild build → BUILD SUCCEEDED; LSUIElement=true; bundle id com.lippi304.islet
- FOUND commit: 7cfed4c

---
*Phase: 00-foundations-notarization-dry-run*
*Completed: 2026-06-26*
