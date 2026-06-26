---
phase: 0
slug: foundations-notarization-dry-run
status: approved
nyquist_compliant: true
wave_0_complete: true
created: 2026-06-26
---

# Phase 0 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Transcribed from 00-RESEARCH.md § "Validation Architecture". Phase 0 is a
> native macOS app shell with NO unit-test framework — verification is
> behavioral/system-level (xcodebuild build + CLI assertions + 3 human-verify
> checkpoints + a manual login-cycle test).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | None — behavioral/system-level verification (`xcodebuild` build + CLI assertions). No XCTest target: Phase 0 success criteria are behavioral (app launches as agent, toggle registers a login item, release script runs, `spctl` verdict) — there is no pure-logic unit worth a test target. |
| **Config file** | none — no test target created (see Wave 0 Requirements) |
| **Quick run command** | `xcodebuild -scheme Islet -configuration Debug build` (must compile cleanly in Swift 5 mode, no strict-concurrency errors) |
| **Full suite command** | `xcodebuild -scheme Islet -configuration Debug build` **plus** `bash scripts/release.sh` (runs the whole pipeline to the deferred notarize boundary, ad-hoc signs, builds `dist/Islet.dmg`, prints the SKIP message) **plus** the Gatekeeper demo (`xattr -w com.apple.quarantine …` then `spctl --assess --type install -vvv dist/Islet.dmg`) |
| **Estimated runtime** | ~10s clean Debug build (quick); ~60–120s for the full Release archive + DMG build + Gatekeeper assertions (full suite, dominated by `xcodebuild archive`) |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild -scheme Islet -configuration Debug build` (must compile, no Swift-6-mode errors).
- **After every plan wave:** Run the app and confirm agent behavior + toggle; run `bash scripts/release.sh` to the deferred boundary.
- **Before `/gsd-verify-work`:** Quick build green; release script produces `dist/Islet.dmg` with the SKIP message; Gatekeeper demo recorded.
- **Max feedback latency:** ~120 seconds (the full-suite Release archive is the longest leg).

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 0-01-01 | 01 | 1 | APP-01 | T-00-01 / T-00-02 | Un-sandboxed shell grants no entitlements; bundle id fixed/lowercase | smoke (build) | `xcodebuild -scheme Islet -configuration Debug build` (runs only AFTER human GUI project creation + shared scheme — see Manual-Only) | ❌ W0 | ⬜ pending |
| 0-01-02 | 01 | 1 | APP-01 | T-00-02 | Menu actions are local-only; no external input trusted | smoke (build) | `xcodebuild -scheme Islet -configuration Debug build` | ❌ W0 | ⬜ pending |
| 0-01-03 | 01 | 1 | APP-01 | — | Visual/functional agent behavior (no Dock icon, menu works, quit works) | **manual** (human-verify) | MANUAL — checkpoint:human-verify | n/a | ⬜ pending |
| 0-02-01 | 02 | 2 | APP-02 | T-00-04 | Login-item state read from `SMAppService.mainApp.status`, never a local flag | smoke (build) | `xcodebuild -scheme Islet -configuration Debug build` | ❌ W0 | ⬜ pending |
| 0-02-02 | 02 | 2 | APP-02 | T-00-04 | Toggle reverts to true system state on failure; no `@AppStorage` source of truth | smoke (build) | `xcodebuild -scheme Islet -configuration Debug build` | ❌ W0 | ⬜ pending |
| 0-02-03 | 02 | 2 | APP-02 | T-00-05 | Registers only `mainApp`; `.requiresApproval` routes through user consent | **manual** (login cycle) | MANUAL — checkpoint:human-verify + logout/login | n/a | ⬜ pending |
| 0-03-01 | 03 | 1 | APP-04 | T-00-06 | Build artifacts git-ignored; no secrets committed | static (grep) | `grep -q "DerivedData/" .gitignore && grep -q "dist/" .gitignore && grep -q "build/" .gitignore && echo OK` | ❌ W0 | ⬜ pending |
| 0-03-02 | 03 | 1 | APP-04 | T-00-06 / T-00-07 / T-00-08 | Notary profile referenced by name only; no plaintext secret; hardened-runtime sign; loud SKIP for the un-notarized artifact | static (syntax + grep) | `bash -n scripts/release.sh && grep -q "xcrun notarytool submit" scripts/release.sh && grep -q "xcrun stapler staple" scripts/release.sh && grep -qE "codesign .*--options runtime" scripts/release.sh && grep -q "hdiutil create" scripts/release.sh && grep -q "__DEVELOPER_ID__" scripts/release.sh && echo OK` | ❌ W0 | ⬜ pending |
| 0-03-03 | 03 | 1 | APP-04 | T-00-06 | RELEASE.md documents placeholders + keychain profile; no real credentials | static (grep) | `test -f docs/RELEASE.md && grep -q "notarytool" docs/RELEASE.md && grep -q "DEVELOPER_ID" docs/RELEASE.md && grep -q "NOTARY_PROFILE" docs/RELEASE.md && echo OK` | ❌ W0 | ⬜ pending |
| 0-04-01 | 04 | 3 | APP-04 | T-00-07 / T-00-08 | Script ad-hoc signs and cleanly SKIPS notarize/staple (no accidental un-notarized "release") | integration (script run) | `bash scripts/release.sh 2>&1 \| tee /tmp/islet_release.log \| grep -q "SKIPPING notarize" && test -f dist/Islet.dmg && echo OK` | ❌ W0 | ⬜ pending |
| 0-04-02 | 04 | 3 | APP-04 | T-00-09 | Gatekeeper REJECTS the ad-hoc/quarantined build (protective control proven) | integration (verdict) | `test -f docs/GATEKEEPER-DEMO.md && grep -q "spctl --assess" docs/GATEKEEPER-DEMO.md && grep -qi "quarantine" docs/GATEKEEPER-DEMO.md && grep -qi "rejected\|reject" docs/GATEKEEPER-DEMO.md && echo OK` | ❌ W0 | ⬜ pending |
| 0-04-03 | 04 | 3 | APP-04 | T-00-09 / T-00-10 | Artifact built + Gatekeeper block confirmed; Phase-6 carry-over documented | **manual** (human-verify) | MANUAL — checkpoint:human-verify | n/a | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*
*"❌ W0" = the artifact does not exist until Wave 0 bootstrap (fresh repo); the automated command can only pass after Wave 0 creates the Xcode project / scripts.*

---

## Wave 0 Requirements

These bootstrap artifacts do not exist in the fresh repo and MUST be created before the per-task automated commands above can pass. They are produced by the phase's own Wave-1 plans (01 and 03), so Wave 0 is satisfied within the phase rather than by a separate pre-wave:

- [x] `Islet.xcodeproj` + SwiftUI app target **with a SHARED scheme named `Islet`** — created by Plan 01 Task 1 (human GUI creation + "share the scheme" so `xcodebuild -scheme Islet` resolves). Covers all `xcodebuild -scheme Islet build` commands in the map.
- [x] `scripts/release.sh` — the re-runnable sign→dmg→notarize→staple pipeline with placeholders + ad-hoc fallback — created by Plan 03 Task 2.
- [x] `.gitignore` for Xcode artifacts (`build/`, `DerivedData/`, `dist/`, `*.xcuserstate`) — created by Plan 03 Task 1.
- [ ] XCTest target — **NOT created** (intentional): Phase 0 has no pure-logic unit worth a test target; `versionString` is trivial and covered by the build + manual verification. No framework install required (all CLI tools verified present; `create-dmg` optional, `hdiutil` used instead).

*All MISSING/`❌ W0` references in the map are covered by Plan 01 (Xcode project + shared scheme) and Plan 03 (scripts + .gitignore). No external Wave-0 gap remains.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Xcode project must be created via GUI before the automated build can run | APP-01 | A fresh repo has no `Islet.xcodeproj` and no scheme; `xcodebuild -scheme Islet` cannot resolve until a human completes File → New → Project (SwiftUI/Swift) and marks the scheme Shared. The `<automated>` build verify in Plan 01 Task 1 therefore runs ONLY after this GUI step + "share the scheme". | In Xcode: File → New → Project → macOS → App → Product Name `Islet`, Interface SwiftUI, Language Swift, save at repo root, uncheck "Create Git repository". Then Product → Scheme → Manage Schemes → check "Shared" for `Islet`. Then the automated `xcodebuild -scheme Islet -configuration Debug build` resolves and runs. (Mirrors Plan 04 Task 1's scheme-sharing note.) |
| Menu-bar agent behaves correctly (no Dock icon, menu opens settings, Quit terminates) | APP-01 | Visual + functional check — no headless command can confirm "no Dock icon appears", "menu item opens the window front-most", or "icon disappears on quit". | Plan 01 Task 3 (`checkpoint:human-verify`): build + run; confirm no Dock icon; status-bar capsule icon present; dropdown shows "Settings…" / "Quit Islet"; Settings opens a front-most window; Quit terminates (icon disappears). |
| Launch-at-login actually starts the app across a real login cycle | APP-02 | `SMAppService` registration is only reliable for a signed app run from a stable location (RESEARCH Assumptions Log A1), and a logout/login cycle cannot be automated cleanly. Genuinely manual. | Plan 02 Task 3 (`checkpoint:human-verify` + login cycle): copy `Islet.app` to `/Applications`, run it, toggle Launch-at-Login ON, confirm it appears in System Settings → Login Items, **log out and back in**, confirm Islet's menu-bar icon auto-appears; toggle OFF and confirm removal; flip it in System Settings and confirm the toggle re-syncs (no desync). |
| Full release dry-run + Gatekeeper block demonstrated end-to-end | APP-04 | Final human gate confirming the produced DMG, the printed SKIP message, and (most faithfully) the double-click Gatekeeper block dialog — a GUI-launch behavior `spctl` only approximates headlessly. | Plan 04 Task 3 (`checkpoint:human-verify`): confirm `dist/Islet.dmg` exists; review `docs/GATEKEEPER-DEMO.md` for the actual `spctl --assess` rejection; optionally double-click the quarantined DMG to see the "unidentified developer" dialog; confirm the script printed "SKIPPING notarize + staple"; confirm it matches the D-02 done-definition. |

*Note: the 3 `checkpoint:human-verify` tasks (0-01-03, 0-02-03, 0-04-03) plus the logout/login leg inside 0-02-03 are the genuinely manual verifications. Everything else has an `<automated>` command (build or CLI assertion).*

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or are explicitly manual-only (the 3 human-verify checkpoints + the login-cycle leg) with documented reasons
- [x] Sampling continuity: no 3 consecutive tasks without automated verify (each plan's auto tasks carry a build/CLI command; the lone human-verify task per plan follows automated tasks)
- [x] Wave 0 covers all MISSING references (Xcode project + shared scheme via Plan 01; scripts/.gitignore via Plan 03); no external Wave-0 gap
- [x] No watch-mode flags (all commands are one-shot: `xcodebuild … build`, `bash …`, `grep`, `spctl --assess`)
- [x] Feedback latency < 120s (quick build ~10s; full suite ~60–120s, dominated by Release archive)
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-06-26
