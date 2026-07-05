---
phase: 12
slug: real-polar-sh-license-integration
status: draft
nyquist_compliant: false
wave_0_complete: false
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
| **Quick run command** | `xcodebuild build -scheme Islet -destination 'platform=macOS'` (build gate — `xcodebuild test` hangs in this project) |
| **Full suite command** | Manual `Cmd-U` in Xcode (test run routed to manual, per project memory) |
| **Estimated runtime** | ~60 seconds (build) |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild build -scheme Islet -destination 'platform=macOS'`
- **After every plan wave:** Build gate green + author unit tests against injected fakes
- **Before `/gsd:verify-work`:** Build green (Debug + Release) + manual `Cmd-U` green + on-device paste-key verification
- **Max feedback latency:** ~60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| TBD | TBD | TBD | LIC-01 / LIC-02 | T-11-02 | Entitlement never a trivially-flippable bool | unit + manual | `xcodebuild build` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky. Planner fills concrete rows.*

---

## Wave 0 Requirements

- [ ] Unit-test seams: injectable `HTTPSession` fake + `LicenseStore` (Keychain) fake so validate + cache logic is testable without network or Keychain.

*Populated concretely by the planner.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Buy Now → real Polar checkout in browser | LIC-01 | External browser + live checkout page | Open Settings, click Buy Now, confirm landing on Polar.sh €7.99 checkout |
| Paste real key → online validate → success | LIC-02 | Real credential supplied live; real network round-trip | Paste purchased key in Settings → Activate; confirm success state |
| Offline-after-first-validation | LIC-02 / SC3 | Requires airplane-mode toggle on device | Validate once online, enable airplane mode, relaunch app, confirm still entitled |

*Real license key is supplied by the user live at on-device verification (never recorded in planning docs).*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
