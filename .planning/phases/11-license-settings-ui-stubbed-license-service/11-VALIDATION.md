---
phase: 11
slug: license-settings-ui-stubbed-license-service
status: approved
nyquist_compliant: true
wave_0_complete: false
created: 2026-07-05
---

# Phase 11 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (bundled with Xcode 26.6) |
| **Config file** | `project.yml` (`IsletTests` target; `xcodegen generate` → `.xcodeproj`) |
| **Quick run command** | `xcodebuild test -scheme Islet -only-testing:IsletTests/LicenseServiceTests` |
| **Full suite command** | `xcodebuild test -scheme Islet` |
| **Estimated runtime** | ~60–120 seconds (full suite; single-test target ~15–30s) |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild test -scheme Islet -only-testing:IsletTests/LicenseServiceTests` (service tasks) or `xcodebuild build -scheme Islet` (SwiftUI glue tasks with no unit target)
- **After every plan wave:** Run `xcodebuild test -scheme Islet` (full suite)
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** ~120 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 11-01-01 | 01 | 0 | D-05 | T-11-01 (magic key) | `activate("ISLET-DEMO-OK")` → `.success`; any other non-empty key → `.failure(.invalidKey)`; input trimmed and treated as opaque `==`-compared string | unit | `xcodebuild test -scheme Islet -only-testing:IsletTests/LicenseServiceTests` | ❌ W0 | ⬜ pending |
| 11-01-02 | 01 | 0 | D-06 | — | Completion delivered asynchronously (~1s) on the main thread | unit (XCTestExpectation + `Thread.isMainThread`) | `xcodebuild test -scheme Islet -only-testing:IsletTests/LicenseServiceTests` | ❌ W0 | ⬜ pending |
| 11-02-01 | 02 | 1 | TRIAL-03 | — | `LicenseState.status → .trial(daysRemaining:)` clamped day count renders in days-remaining line | build (glue; unit already covered by `TrialLogicTests`) | `xcodebuild build -scheme Islet` | ✅ existing | ⬜ pending |
| 11-02-02 | 02 | 1 | D-01/D-04/D-07 | — | Adaptive License section + inline validation status line + Buy Now compile and wire to `LicenseService` | build | `xcodebuild build -scheme Islet` | ✅ N/A (view glue) | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `IsletTests/LicenseServiceTests.swift` — covers D-05 (key→Result mapping: magic key succeeds, non-magic non-empty fails, whitespace trimmed) + D-06 (async completion ~1s, delivered on main thread). Mirrors `IsletTests/TrialManagerTests.swift` / `IsletTests/PowerActivityTests.swift` style; use `XCTestExpectation` for the async completion.
- [ ] Framework install: none — `IsletTests` target + `xcodebuild test -scheme Islet` already wired (`project.yml` lines 66–99).

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Activate → validating → success flips `LicenseState.sessionActivated` and the locked island re-appears live via `updateVisibility()` (no restart) | Discretion (live unlock) | Interaction + window-visibility timing; mirrors Phase 10's manual `10-02-02` stub-flip precedent. `LicenseState` is a `private init()` singleton so the `.licensed` short-circuit isn't unit-reachable without relaxing `init()` to internal. | Run DEBUG build. In an expired/trial state, open Settings → paste `ISLET-DEMO-OK` → Activate → observe `⟳ Validating…` ~1s → `✓ License activated`, section switches to `Licensed ✓`, island re-appears without restart. |
| Adaptive section swaps layout across `.trial` / `.trialExpired` / `.licensed` | D-01 | Visual layout across three enum states; drive with DEBUG stub-flips (`forceExpired` / `forceLicensed`) + magic key | Toggle each DEBUG override / activate; confirm each layout matches UI-SPEC (days line + Buy Now + field for trial/expired; `Licensed ✓` only, Buy Now + field hidden, for licensed). |
| Buy Now opens `https://getislet.app` in the default browser | D-07 | External app handoff (`NSWorkspace.open`) not unit-observable | Click "Buy Islet — €7.99"; confirm default browser opens the placeholder URL. |
| Entitlement does NOT survive relaunch (in-memory only) | Pitfall 1 | Process-lifetime behavior | Activate with magic key, quit + relaunch; confirm app is back in trial/expired state (island locked). |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 120s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-07-05 (plan-checker Dimension 8 PASS; `wave_0_complete` flips after execution)
