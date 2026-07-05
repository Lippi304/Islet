---
quick_id: 260705-mzj
type: execute
status: launch-fix-verified-visual-eyeball-pending
subsystem: build-signing
tags: [entitlements, hardened-runtime, library-validation, release-build, signing]
requires:
  - Islet target embedding MediaRemoteAdapter.framework (Embed & Sign)
provides:
  - Release-configuration build that passes Library Validation for the embedded framework
affects:
  - Phase 13 notarization (same entitlement required for distribution)
tech-stack:
  added: []
  patterns:
    - "Hardened-Runtime library-validation opt-out via a dedicated .entitlements plist wired through project.yml"
key-files:
  created:
    - Islet/Islet.entitlements
  modified:
    - project.yml
    - Islet.xcodeproj/project.pbxproj
decisions:
  - "Add ONLY com.apple.security.cs.disable-library-validation — minimal surface; no sandbox keys, no speculative entitlements"
  - "Keep ENABLE_HARDENED_RUNTIME: YES (needed for notarization) and ENABLE_APP_SANDBOX: NO (intentionally un-sandboxed)"
  - "Wire CODE_SIGN_ENTITLEMENTS into the Islet target settings.base only, NOT top-level (avoids applying to IsletTests)"
metrics:
  duration: ~4m
  completed: 2026-07-05
---

# Quick Task 260705-mzj: Release-Build Crash Fix (disable-library-validation) Summary

Added a single `com.apple.security.cs.disable-library-validation` entitlement so the embedded ad-hoc-signed `MediaRemoteAdapter.framework` passes dyld Library Validation under Hardened Runtime, unblocking the previously-crashing Release build.

## What Was Done (Task 1 — complete)

1. Created `Islet/Islet.entitlements` — a standard XML plist `<dict>` with EXACTLY one key: `com.apple.security.cs.disable-library-validation` = `<true/>`.
2. Wired it into the `Islet` target's `settings.base` in `project.yml` via `CODE_SIGN_ENTITLEMENTS: Islet/Islet.entitlements` (target-scoped, not top-level — IsletTests untouched). `ENABLE_HARDENED_RUNTIME: YES` and `ENABLE_APP_SANDBOX: NO` left unchanged.
3. Ran `xcodegen generate`; regenerated `Islet.xcodeproj/project.pbxproj` now carries the `CODE_SIGN_ENTITLEMENTS` reference (grep count = 2, Debug + Release configs).
4. Ran the mandatory Release gate: `xcodebuild build -scheme Islet -destination 'platform=macOS' -configuration Release` → **BUILD SUCCEEDED**.
5. Proof: `codesign -d --entitlements -` on the built `Release/Islet.app` lists `com.apple.security.cs.disable-library-validation`.

Commit: `cc63c00` — `fix(260705-mzj): add disable-library-validation entitlement for Release build` (Islet/Islet.entitlements + project.yml + Islet.xcodeproj/project.pbxproj, atomic).

## Verification Status

- [x] Release build: BUILD SUCCEEDED
- [x] Entitlement present in source (`Islet/Islet.entitlements`)
- [x] Entitlement present in built app (`codesign -d --entitlements -`)
- [x] `Islet.xcodeproj` regenerated and references the entitlements
- [x] **Release launch crash FIXED — objectively verified by the orchestrator**: the freshly built `Release/Islet.app` was launched standalone and stayed running cleanly (process state `SN`, no dyld error), whereas the pre-fix binary exited within seconds on the `different Team IDs` dyld error. The launch-crash half of the checkpoint is proven.
- [ ] Visual eyeball only (user): menu-bar icon renders + idle-notch merges/expands (folds in deferred 260705-l4i). Cosmetic-only; does not gate the signing fix, which is merged (`8e06a1b`).

## Deviations from Plan

None — plan executed exactly as written.

## Task 2 — CHECKPOINT: HUMAN VERIFY REQUIRED (blocking)

On-device Release launch cannot be verified by the executor. Awaiting human confirmation:

Do this in Xcode (GUI only — not Terminal):

1. Open `Islet.xcodeproj` in Xcode (double-click it in Finder inside the repo root).
2. Product → Scheme → Edit Scheme… → select "Run" in the left column → set "Build Configuration" to **Release** → Close.
3. Press Cmd-R to build & launch the Release build.
4. Confirm (a) LAUNCH: the Islet menu-bar icon appears in the top-right menu bar AND the app keeps running (no crash / no "Islet quit unexpectedly" dialog).
5. Confirm (b) IDLE-MERGE (folds in deferred quick task 260705-l4i): the black idle island at the notch merges invisibly with the hardware notch (no visible seam), and moving the pointer over it expands the island smoothly.
6. IMPORTANT — revert afterward: Product → Scheme → Edit Scheme… → Run → set "Build Configuration" back to **Debug** → Close.

Resume signal: Type "approved" if the menu-bar icon appears, the app stays running, and the idle island merges + expands correctly. Otherwise describe exactly what happened (crash dialog text, missing icon, visible notch seam, or hover not expanding).

## Self-Check: PASSED

- FOUND: Islet/Islet.entitlements
- FOUND: commit cc63c00
