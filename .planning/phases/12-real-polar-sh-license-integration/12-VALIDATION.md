---
phase: 12
slug: real-polar-sh-license-integration
status: planned
nyquist_compliant: true
wave_0_complete: true
created: 2026-07-05
---

# Phase 12 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (hosted in Islet.app) |
| **Config file** | Islet.xcodeproj (IsletTests target) |
| **Quick run command** | `xcodegen generate && xcodebuild build -scheme Islet -destination 'platform=macOS' -configuration Debug` (build gate — `xcodebuild test` HANGS in this project) |
| **Full suite command** | Manual `Cmd-U` in Xcode (test run routed to manual, per project memory 2380/2401) |
| **Estimated runtime** | ~60 seconds (build) |

---

## Sampling Rate

- **After every task commit:** Run `xcodegen generate && xcodebuild build -scheme Islet -destination 'platform=macOS' -configuration Debug`
- **After every plan wave:** Build gate green + author unit tests against injected fakes
- **Before `/gsd:verify-work`:** Build green (Debug + Release) + manual `Cmd-U` green + on-device paste-key verification (12-04)
- **Max feedback latency:** ~60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 12-01-T1 | 12-01 | 1 | LIC-02 | T-12-01 | Entitlement persisted as Codable LicenseRecord in Keychain, never a bool/UserDefaults | source + unit | `grep com.lippi304.islet.license` + build | ✅ authored | ⬜ pending |
| 12-01-T2 | 12-01 | 1 | LIC-02 | T-12-04 | Read-once in-memory cache — no Keychain read on hot path | unit + build | `xcodebuild build` (LicenseManagerTests via Cmd-U) | ✅ authored | ⬜ pending |
| 12-02-T1 | 12-02 | 1 | LIC-02 | T-12-02, T-12-03, T-12-05 | Token-less TLS validate; key never logged; org_id only non-secret shipped | source + unit | `grep customer-portal + org_id + main.async` + build | ✅ authored | ⬜ pending |
| 12-02-T2 | 12-02 | 1 | LIC-02 | T-12-04 | 5xx/URLError → .unreachable (never .invalidKey); body == {key, organization_id} | unit + build | `xcodebuild build` (PolarLicenseServiceTests via Cmd-U) | ✅ authored | ⬜ pending |
| 12-03-T1 | 12-03 | 2 | LIC-02 | T-12-06 | Persisted branch reads cached LicenseManager, not live Keychain | source + build | `grep LicenseManager.shared.isLicensed` + ordering + build | ✅ authored | ⬜ pending |
| 12-03-T2 | 12-03 | 2 | LIC-02 | T-12-01, T-12-04 | Swap to PolarLicenseService; persist granted record; .unreachable/.invalidKey split + Retry | source + build | `grep PolarLicenseService() + recordValidation + case .unreachable + Retry` + build | ✅ authored | ⬜ pending |
| 12-04-T1 | 12-04 | 3 | LIC-01/LIC-02 | T-12-07 | Debug + Release both BUILD SUCCEEDED (Release-only crash history) | build | `xcodebuild build` Debug + Release | ✅ authored | ⬜ pending |
| 12-04-T2 | 12-04 | 3 | LIC-01/LIC-02 | T-12-04 | On-device: Buy Now, real-key success, invalid vs unreachable+Retry, offline relaunch | manual on-device | Cmd-U green + human checkpoint | manual | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky. Updated during execution.*

---

## Wave 0 Requirements

Satisfied inline in Wave 1 (seams + fakes are created alongside the implementation they test):

- [x] Injectable `HTTPSession` fake (`FakeHTTPSession` in `IsletTests/PolarLicenseServiceTests.swift`, 12-02) — validate logic testable without network.
- [x] Injectable `LicenseStore` fake (`FakeLicenseStore` in `IsletTests/LicenseManagerTests.swift`, 12-01) — cache/persistence testable without real Keychain.
- [x] `LicenseStore` protocol seam + read-once-cached `LicenseManager` (12-01, mirrors `KeychainStore`/`TrialManager`).
- [x] `HTTPSession` protocol seam + `URLSessionHTTP` default (12-02).

Every automated `<verify>` in Waves 1-2 is `xcodebuild build` (the CI gate); the XCTest RUN is the manual Cmd-U at the 12-04 human checkpoint (headless `xcodebuild test` hangs — documented). No task chain has 3 consecutive tasks without an automated verify.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Buy Now → real Polar checkout in browser | LIC-01 | External browser + live checkout page | Open Settings, click Buy Now, confirm landing on Polar.sh €7.99 checkout |
| Paste real key → online validate → success | LIC-02 | Real credential supplied live; real network round-trip | Paste purchased key in Settings → Activate; confirm "✓ License activated" |
| Invalid key → "not recognized" | LIC-02 | Distinguish from unreachable state | Paste garbage key → confirm .invalidKey message (not unreachable) |
| Offline activate → "server not reachable" + Retry | LIC-02 / SC4 | Airplane-mode toggle on device | Airplane mode → Activate → confirm unreachable message + Retry button |
| Offline-after-first-validation | LIC-02 / SC3 | Requires airplane-mode toggle on device | Validate once online, quit, enable airplane mode, relaunch, confirm still entitled with no re-prompt |
| Unit-test suite run | LIC-02 | `xcodebuild test` hangs in this project | Xcode → Cmd-U → confirm Licensing suites green |

*Real license key is supplied by the user live at on-device verification (never recorded in planning docs).*

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references (seams + fakes authored in Wave 1)
- [x] No watch-mode flags
- [x] Feedback latency < 60s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** planned — ready for execution
