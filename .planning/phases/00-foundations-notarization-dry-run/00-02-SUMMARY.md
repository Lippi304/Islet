---
phase: 00-foundations-notarization-dry-run
plan: 02
subsystem: app-shell
tags: [smappservice, launch-at-login, servicemanagement, settingsview, swiftui-form, menubar-agent]

# Dependency graph
requires:
  - phase: 00-foundations-notarization-dry-run
    provides: "Plan 01 SettingsView placeholder + Window(id:\"settings\") scene + AppDelegate; this plan replaces the SettingsView body and hardens the AppDelegate"
provides:
  - "Islet/LaunchAtLogin.swift — helper over SMAppService.mainApp (status-driven register/unregister, .requiresApproval handling)"
  - "Islet/SettingsView.swift — Form with a Launch-at-Login toggle + version label (1.0 (1)), re-syncing from system state"
  - "AppDelegate: agent survives last-window-close; Settings window suppressed at launch"
affects: [00-04 (archives this finished app into a DMG), phase-6 (APP-03 extends the settings UI with activity toggles + theme)]

# Tech tracking
tech-stack:
  added: []  # ServiceManagement is a system framework (auto-linked)
  patterns:
    - "Launch-at-login via SMAppService.mainApp — registers the app itself, no helper bundle / no LaunchAgent plist; keyed to bundle id com.lippi304.islet"
    - "System status is the single source of truth: read SMAppService.mainApp.status on appear + on window refocus (appearsActive); never persist a local @AppStorage flag (Pitfall 3)"
    - "Toggle reverts to the real system state on register/unregister failure"
    - "Menu-bar agent survives last-window-close (applicationShouldTerminateAfterLastWindowClosed=false); Settings window hidden at launch (orderOut + isReleasedWhenClosed=false)"

key-files:
  created:
    - "Islet/LaunchAtLogin.swift"
  modified:
    - "Islet/SettingsView.swift (placeholder -> Form with toggle + version label)"
    - "Islet/AppDelegate.swift (terminate-on-last-window-close fix + launch-time window suppression)"
    - "project.yml (MARKETING_VERSION=1.0, CURRENT_PROJECT_VERSION=1 so the version label reads 1.0 (1))"
    - "Islet.xcodeproj (regenerated)"

key-decisions:
  - "SMAppService.mainApp (project standard) — NOT SMLoginItemSetEnabled (deprecated) and NOT an @AppStorage flag (would desync, Pitfall 3)"
  - "App staged to /Applications for the SMAppService test — registration is reliable only from a stable, signed location, not DerivedData (Assumptions Log A1)"
  - "Set MARKETING_VERSION/CURRENT_PROJECT_VERSION because GENERATE_INFOPLIST_FILE produced no CFBundle*Version keys, which would have shown '? (?)' in the label"

patterns-established:
  - "Always read login-item state from the system; revert UI on failure"
  - "Menu-bar agents must set applicationShouldTerminateAfterLastWindowClosed=false"

requirements-completed: [APP-02]

# Metrics
duration: ~30min
completed: 2026-06-26
---

# Phase 00 Plan 02: Launch-at-Login toggle + version label Summary

**The Settings window now has a working "Launch Islet at login" toggle wired to SMAppService.mainApp (status-driven, reverts on failure) and a version label reading 1.0 (1) — and the menu-bar agent now behaves correctly: closing/hiding the Settings window no longer quits it, and the window no longer auto-opens on launch.**

## Accomplishments
- Added `LaunchAtLogin.swift`: a small enum over `SMAppService.mainApp` — `isEnabled` (reads `.status == .enabled`), `set(_:)` (register/unregister, throws so the caller can revert), `requiresApproval`, and `openLoginItemsSettings()`.
- Rebuilt `SettingsView.swift` as a `Form` with the `Toggle("Launch Islet at login")` (drives register/unregister, opens System-Settings Login Items on `.requiresApproval`, reverts on error) and a `LabeledContent("Version")` showing `1.0 (1)`. Re-reads system state `.onAppear` and when the window's app becomes active again (`appearsActive`) so it never desyncs (Pitfall 3).
- Fixed two agent-behavior bugs surfaced while implementing this plan (see Deviations).
- Verified: `xcodebuild build` → **BUILD SUCCEEDED**; app staged to `/Applications/Islet.app` (ad-hoc, com.lippi304.islet); version label confirmed `1.0 (1)`.
- Human checkpoint (Task 3): user **approved** — toggle opens, registers/unregisters in System Settings → Login Items, version label correct, closing the Settings window keeps the agent alive, and the window no longer auto-opens at launch.

## Task Commits
1. **Tasks 1+2 (LaunchAtLogin helper + SettingsView Form) + agent-behavior fixes** — `9861e41` (feat). Committed together because the regenerated `Islet.xcodeproj` (new LaunchAtLogin file ref + version settings) spans both tasks.

## Deviations from Plan

**1. [Agent-behavior fix] applicationShouldTerminateAfterLastWindowClosed = false**
- **Found during:** Launch testing after adding launch-time window suppression — the app exited immediately on launch.
- **Root cause:** A SwiftUI app quits when its last window closes. This was a latent 00-01 bug too: closing the Settings window with the red button would have quit the whole menu-bar agent.
- **Fix:** Implemented `applicationShouldTerminateAfterLastWindowClosed` returning `false` in AppDelegate. Only "Quit Islet" terminates the app now.
- **Files:** Islet/AppDelegate.swift. **Verified:** app stays running with the window hidden; user confirmed red-button close keeps the agent alive.

**2. [00-01 carry-over fix] Suppress the Settings window at launch**
- **Reason:** Promised in 00-01 — a menu-bar agent must not pop its Settings window on every launch (especially once Launch-at-Login is on). The SwiftUI `Window(id:)` scene opens its window at launch.
- **Fix:** In AppDelegate, hide the settings window right after launch (`orderOut`), mark it non-restorable and `isReleasedWhenClosed = false` so it stays alive and "Settings…" re-shows it instantly via `makeKeyAndOrderFront`.
- **Files:** Islet/AppDelegate.swift. **Verified:** app launches with no visible window (proven: before the terminate fix it quit on the last-window-close) and user confirmed Settings… re-opens it.

**3. [Missing version keys] Set MARKETING_VERSION / CURRENT_PROJECT_VERSION**
- **Reason:** The synthesized Info.plist had no CFBundleShortVersionString/CFBundleVersion, so the version label read "? (?)".
- **Fix:** Added `MARKETING_VERSION: "1.0"` and `CURRENT_PROJECT_VERSION: "1"` to project.yml → label now reads "1.0 (1)".
- **Files:** project.yml, Islet.xcodeproj (regenerated).

**Total deviations:** 3 (2 agent-behavior fixes, 1 metadata) — all directly in service of APP-02 / correct agent behavior; no scope creep.

## User Setup Required
None for the dry run. For the optional full login-cycle test the app must run from a stable location (/Applications), already staged.

## Next Phase Readiness
- The finished menu-bar agent (Plans 01+02) is ready for Plan 04 to archive into `dist/Islet.dmg` via `scripts/release.sh` and run the local Gatekeeper demo.

## Self-Check: PASSED

- FOUND: Islet/LaunchAtLogin.swift (register/unregister/status, imports ServiceManagement, no SMLoginItemSetEnabled/@AppStorage)
- FOUND: Islet/SettingsView.swift (Toggle, CFBundleShortVersionString, LaunchAtLogin., onAppear+appearsActive, no @AppStorage)
- VERIFIED: xcodebuild build → BUILD SUCCEEDED; version label 1.0 (1)
- FOUND commit: 9861e41

---
*Phase: 00-foundations-notarization-dry-run*
*Completed: 2026-06-26*
