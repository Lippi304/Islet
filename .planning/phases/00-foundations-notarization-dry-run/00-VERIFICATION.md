---
phase: 00-foundations-notarization-dry-run
verified: 2026-06-26T00:00:00Z
status: passed
score: 5/5 must-haves verified
overrides_applied: 0
re_verification:
  previous_status: none
  note: "Initial verification — no prior VERIFICATION.md"
deferred:
  - truth: "A signed → notarized → stapled build opens on a SECOND clean Mac with no Gatekeeper warning (ROADMAP SC#3, real-notarization portion)"
    addressed_in: "Phase 6"
    evidence: "Phase 6 success criteria: 'The Now Playing launch-time health check is re-verified and the production build is signed, notarized, and stapled, opening cleanly on a second Mac.' Deferral documented in 00-CONTEXT.md D-01 (no Apple Developer account yet), D-04 (no second Mac), D-02 (Phase-6 carry-over). The Phase-0 portion of SC#3 (dmg produced + local Gatekeeper BLOCK demonstrated) IS done and verified below."
---

# Phase 0: Foundations & Notarization Dry Run Verification Report

**Phase Goal:** A runnable menu-bar background agent (no Dock icon) whose entire sign→notarize→staple toolchain has been proven end-to-end on a hello-world build before any feature exists.
**Verified:** 2026-06-26
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | App runs as a menu-bar agent with no Dock icon; menu opens settings and quits | ✓ VERIFIED | Built `/Applications/Islet.app/Contents/Info.plist` → `LSUIElement=true`, `CFBundleIdentifier=com.lippi304.islet`. `AppDelegate.swift:10` `NSStatusBar.system.statusItem`; `:15` `capsule.fill` template SF Symbol (`isTemplate=true`); `:23,:26` menu items "Settings…" / "Quit Islet"; `:72` `NSApp.terminate(nil)`; `:79` `applicationShouldTerminateAfterLastWindowClosed → false`. Window opened via notification bridge (`IsletApp.swift:23,37`), NOT the broken SwiftUI `Settings{}` scene. Human-approved (00-01 Task 3). |
| 2 | User can toggle "launch at login"; app starts/stops on next login | ✓ VERIFIED | `LaunchAtLogin.swift` wraps `SMAppService.mainApp.{register,unregister,status}` (4 occurrences), status-driven (no `@AppStorage`, no `SMLoginItemSetEnabled`). `SettingsView.swift:9` `Toggle("Launch Islet at login")` wired through the helper; re-syncs `.onAppear` + on `appearsActive`; `.requiresApproval` treated as pending-ON (REVIEW MR-03 fixed at `:13–19`). Reverts to system state on failure. Human-approved login-cycle (00-02 Task 3). |
| 3 | Sign→dmg pipeline runs and produces dist/Islet.dmg ad-hoc; notarize/staple skip cleanly | ✓ VERIFIED | `scripts/release.sh` `bash -n` OK. Ad-hoc branch `codesign --force --sign -` (no `--deep` in any real command — REVIEW MR-01 fixed); `-destination 'generic/platform=macOS' -allowProvisioningUpdates` added (MR-02 fixed). `hdiutil create … UDZO` builds the DMG; placeholder gate prints "SKIPPING notarize + staple". 64KB `dist/Islet.dmg` produced (00-04 SUMMARY); staged app `Signature=adhoc`. Human-approved (00-04 Task 3). |
| 4 | The Gatekeeper BLOCK is demonstrated LOCALLY (Phase-0 portion of SC#3) | ✓ VERIFIED | `docs/GATEKEEPER-DEMO.md` records real machine output: `dist/Islet.dmg: rejected` / `source=no usable signature` / exit 3, and `build/export/Islet.app: rejected` / exit 3, via `xattr com.apple.quarantine` + `spctl --assess`. References D-04 (no second Mac) and documents what real notarization will change at Phase 6. |
| 5 | The whole sign/notarize/staple flow is captured as a repeatable script (SC#4) | ✓ VERIFIED | Single commented `scripts/release.sh` (executable, 100755). Two clearly-marked placeholders `__DEVELOPER_ID__` / `__NOTARY_PROFILE__` gate the Developer-ID + notary steps; script runs UNCHANGED at Phase 6 once filled. No `altool`, no plaintext secrets (keychain profile NAME only). `docs/RELEASE.md` explains the dry run, the two placeholders, `notarytool store-credentials`, and what notarization changes. |

**Score:** 5/5 truths verified

### Deferred Items

Items not yet met but explicitly addressed in a later milestone phase. Per 00-CONTEXT.md scope note and the orchestrator instruction, the deferred real-notarization carry-over is NOT a Phase-0 gap.

| # | Item | Addressed In | Evidence |
|---|------|-------------|----------|
| 1 | Real signed → notarized → stapled build opening on a SECOND clean Mac with no Gatekeeper warning (real-notarization portion of ROADMAP SC#3) | Phase 6 | Phase 6 SC#3: "the production build is signed, notarized, and stapled, opening cleanly on a second Mac." Deferral documented in CONTEXT D-01 (no Developer account), D-04 (no second Mac), D-02 (carry-over). Phase-0 portion (dmg built + local block demo) is done and verified above (truths 3 & 4). |

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `Islet.xcodeproj/project.pbxproj` | Swift 5, macOS 14.0, LSUIElement, bundle id com.lippi304.islet, hardened runtime, no sandbox | ✓ VERIFIED | grep confirms `com.lippi304.islet`, `SWIFT_VERSION = 5`, `MACOSX_DEPLOYMENT_TARGET = 14.0`, `INFOPLIST_KEY_LSUIElement = YES`, `ENABLE_HARDENED_RUNTIME = YES`, no `ENABLE_APP_SANDBOX = YES`. Generated from `project.yml` (xcodegen). Shared scheme present. |
| `Islet/IsletApp.swift` | @main App + NSApplicationDelegateAdaptor + Window(id:"settings") + notification bridge | ✓ VERIFIED | `NSApplicationDelegateAdaptor`, `Window("Islet Settings", id: "settings")`, `OpenSettingsOnNotification` modifier; no `Settings {` scene. |
| `Islet/AppDelegate.swift` | NSStatusItem + NSMenu + template symbol + quit + agent-survival | ✓ VERIFIED | All patterns present; HR-01 launch-flash race fixed via bounded retry loop in `hideSettingsWindowOnLaunch` (`:46–58`). |
| `Islet/LaunchAtLogin.swift` | SMAppService.mainApp wrapper, status-driven | ✓ VERIFIED | register/unregister/status/requiresApproval/openLoginItemsSettings; imports ServiceManagement. |
| `Islet/SettingsView.swift` | Form with launch-at-login Toggle + version LabeledContent | ✓ VERIFIED | Toggle wired through helper; version from real Info.plist keys (MARKETING_VERSION 1.0 / CURRENT_PROJECT_VERSION 1). |
| `scripts/release.sh` | archive→sign→dmg→notarize→staple, placeholder-gated, ad-hoc fallback | ✓ VERIFIED | Valid bash; `notarytool submit`, `stapler staple`, `codesign --options runtime --timestamp`, `hdiutil create`, `ditto` staging (no `cp -r`), `--sign -` fallback, placeholders, no `altool`, no secrets, executable. |
| `.gitignore` | ignore build/, DerivedData/, dist/, *.xcuserstate | ✓ VERIFIED | `git check-ignore` confirms build/, dist/, dist/Islet.dmg all ignored (00-03 inline-comment bug fixed in 00-04). |
| `docs/RELEASE.md` | beginner guide + Phase-6 placeholders | ✓ VERIFIED | Covers dry run, both placeholders, store-credentials, app-specific password, no-secrets note. |
| `docs/GATEKEEPER-DEMO.md` | recorded local spctl block + notarization-change | ✓ VERIFIED | Four commands + real captured `rejected`/exit 3 output + Phase-6 interpretation + D-04 reference. |
| `dist/Islet.dmg` | Phase-0 distributable (git-ignored runtime artifact) | ✓ VERIFIED | Produced at runtime (64KB, ad-hoc); git-ignored, not committed (by design). |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| AppDelegate.swift | NSStatusBar | statusItem(withLength:) | ✓ WIRED | `:10` `NSStatusBar.system.statusItem(withLength:)`. (gsd-tools flagged false-negative from frontmatter regex escaping — confirmed present by direct grep.) |
| AppDelegate.swift | NSApp.terminate | Quit menu action | ✓ WIRED | `:72` `NSApp.terminate(nil)`. (gsd-tools false-negative — confirmed present.) |
| SettingsView.swift | SMAppService.mainApp | toggle change + status read, via LaunchAtLogin helper | ✓ WIRED | SettingsView → `LaunchAtLogin.set/isEnabled/requiresApproval` → `SMAppService.mainApp.{register,unregister,status}` (helper, 4 occurrences). Clean indirection; wiring real. (gsd-tools false-negative — it expected a direct call in SettingsView.) |
| SettingsView.swift | Bundle.main version keys | version label | ✓ WIRED | `CFBundleShortVersionString` / `CFBundleVersion` read; backed by real plist keys. |
| release.sh | codesign --options runtime | hardened-runtime signing | ✓ WIRED | `:80`, `:105`. |
| release.sh | hdiutil create | DMG build | ✓ WIRED | `:96`. |
| release.sh | notarytool submit / stapler staple | placeholder-gated | ✓ WIRED | `:127`, `:130`. |
| release.sh | dist/Islet.dmg | DMG build run end-to-end | ✓ WIRED | `DMG_PATH` derived + produced. (gsd-tools false-negative on `Islet\.dmg` regex.) |
| com.apple.quarantine | spctl --assess verdict | local Gatekeeper assessment | ✓ WIRED | Demonstrated + recorded in GATEKEEPER-DEMO.md (7× `spctl --assess`). (gsd-tools "source file not found" — the "from" is an OS attribute, not a file; verified manually.) |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| SettingsView (version label) | `versionString` | `Bundle.main.infoDictionary` CFBundleShortVersionString/CFBundleVersion | Yes — built Info.plist contains 1.0 / 1 (MARKETING_VERSION / CURRENT_PROJECT_VERSION set in project.yml) | ✓ FLOWING |
| SettingsView (toggle) | `launchAtLogin` | `SMAppService.mainApp.status` via LaunchAtLogin.isEnabled (read on appear + refocus) | Yes — live system login-item state, never a persisted local flag | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Project builds in Swift 5 mode | `xcodebuild -scheme Islet -configuration Debug build` | `** BUILD SUCCEEDED **` | ✓ PASS |
| Release script is valid bash | `bash -n scripts/release.sh` | exit 0 | ✓ PASS |
| Build artifacts git-ignored | `git check-ignore build/ dist/ dist/Islet.dmg` | all ignored | ✓ PASS |
| Staged app is the agent | PlistBuddy `LSUIElement` / `CFBundleIdentifier` on /Applications/Islet.app | `true` / `com.lippi304.islet` | ✓ PASS |
| Staged app is ad-hoc signed | `codesign -dvv /Applications/Islet.app` | `Signature=adhoc` | ✓ PASS |
| Menu-bar appearance / menu / quit / login-cycle | GUI interaction | Human-approved during execution (00-01/00-02/00-04 Task 3) | ✓ PASS (human-confirmed) |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| APP-01 | 00-01 | Menu-bar/background agent, no Dock icon, menu to open settings + quit | ✓ SATISFIED | Truth 1 — LSUIElement agent, status menu, quit wired; human-approved. |
| APP-02 | 00-02 | User can enable "launch at login" from settings | ✓ SATISFIED | Truth 2 — SMAppService toggle, status-driven; human-approved login cycle. |
| APP-04 | 00-03, 00-04 | Developer-ID signed + notarized + stapled download opening cleanly on a clean Mac | ✓ SATISFIED (Phase-0 portion) | Truths 3–5 — repeatable script + dmg + local Gatekeeper block; real notarize/clean-Mac open deferred to Phase 6 per D-01/D-02/D-04. REQUIREMENTS.md already marks APP-04 Complete. |

No orphaned requirements: REQUIREMENTS.md maps exactly APP-01, APP-02, APP-04 to Phase 0; every ID is claimed by a plan.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| scripts/release.sh | 74 | `--deep` token | ℹ️ Info | Appears ONLY in an explanatory comment ("no `--deep` — it is deprecated…"); the four real `codesign` invocations correctly omit it. Not a defect — REVIEW MR-01 is fixed. |
| — | — | TODO/FIXME/stub markers in Islet/*.swift | ℹ️ None | grep found no stub markers, no placeholder bodies, no empty handlers. |

### Human Verification Required

None outstanding. All GUI/system behaviors (menu-bar icon appears, menu opens settings, quit terminates, no Dock icon, launch-at-login registers and starts the app across a login cycle, Gatekeeper block) were verified by the user during execution and recorded as "approved" in the 00-01, 00-02, and 00-04 blocking checkpoints.

### Gaps Summary

No gaps. All five observable truths are verified against the actual codebase, the project builds (`BUILD SUCCEEDED`), all artifacts are substantive and correctly wired, and the data backing the dynamic version/toggle UI flows from real system sources. The REVIEW's HIGH (HR-01 window-flash race) and the three MEDIUM findings (MR-01 `--deep`, MR-02 archive flags, MR-03 requiresApproval UX) are all confirmed fixed in the actual source. The gitignore inline-comment bug from 00-03 was caught and repaired in 00-04 (`git check-ignore` confirms effectiveness).

The only ROADMAP item not literally satisfied — SC#3's real notarization + clean-second-Mac open — is INTENTIONALLY deferred to Phase 6 (no Apple Developer account D-01, no second Mac D-04, carry-over D-02), and Phase 6 SC#3 explicitly re-verifies it. The Phase-0 portion of SC#3 (dmg produced ad-hoc + local Gatekeeper BLOCK demonstrated and recorded) is complete. Per the phase scope note, this deferral is not a gap.

Note: gsd-tools `verify artifacts`/`verify key-links` reported several false negatives caused by double-backslash regex escaping in the PLAN frontmatter and by patterns it expected directly in SettingsView that actually live (correctly) in the LaunchAtLogin helper. Each flagged pattern was confirmed present in the real source by direct grep; none are real gaps.

---

_Verified: 2026-06-26_
_Verifier: Claude (gsd-verifier)_
