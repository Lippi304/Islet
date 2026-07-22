---
phase: 56
slug: encrypted-persistence
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-07-22
---

# Phase 56 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (existing, `IsletTests` bundle target) |
| **Config file** | `project.yml` (`IsletTests` target, `type: bundle.unit-test`, hosted in `Islet` app for `@testable import`) |
| **Quick run command** | `xcodebuild test -scheme Islet -only-testing:IsletTests/ClipboardFileStoreTests` |
| **Full suite command** | `xcodebuild test -scheme Islet` |
| **Estimated runtime** | ~30 seconds (quick), ~3-5 minutes (full suite) |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild test -scheme Islet -only-testing:IsletTests/ClipboardFileStoreTests`
- **After every plan wave:** Run `xcodebuild test -scheme Islet`
- **Before `/gsd:verify-work`:** Full suite must be green, plus one on-device kill-and-restart checkpoint for SC#4 (cannot be captured by XCTest — requires a real separate process launch against already-persisted disk state)
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 56-01-XX | TBD | 1 | CLIP-04 | — | Save then reload against same injectable root reproduces same items/order (SC#1) | unit | `xcodebuild test -scheme Islet -only-testing:IsletTests/ClipboardFileStoreTests` | ❌ W0 | ⬜ pending |
| 56-01-XX | TBD | 1 | PRIV-02 | T-56-01 | On-disk index+image files show no readable plaintext when inspected raw (SC#2) | unit | `xcodebuild test -scheme Islet -only-testing:IsletTests/ClipboardFileStoreTests` | ❌ W0 | ⬜ pending |
| 56-01-XX | TBD | 1 | PRIV-02 | T-56-02 | Delete target validated under storage root before removal, mirrors `ShelfFileStore` (SC#3) | unit | `xcodebuild test -scheme Islet -only-testing:IsletTests/ClipboardFileStoreTests` | ❌ W0 | ⬜ pending |
| 56-01-XX | TBD | 1 | CLIP-04 | — | Full kill-and-restart against real persisted data reloads same history (SC#4) | manual/on-device | N/A — requires actual process restart, not automatable in XCTest | ❌ W0 (on-device checkpoint) | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `IsletTests/ClipboardFileStoreTests.swift` — covers CLIP-04 (SC#1 round-trip) and PRIV-02 (SC#2 plaintext-absence, SC#3 delete-path hardening), following `ShelfFileStoreTests.swift`'s setUp/tearDown fixturesDir convention (intentional deviation from the fixture-free convention — real disk I/O needs a throwaway root)
- [ ] `IsletTests/KeychainClipboardKeyStoreTests.swift` — optional but recommended: covers key generate-if-absent and read-back consistency; if omitted, `ClipboardFileStoreTests` implicitly covers this via the round-trip test needing a working key store

*Framework install: none — `IsletTests` target and scheme already exist and are wired for `xcodebuild test -scheme Islet`.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Full kill-and-restart reloads persisted history (SC#4) | CLIP-04 | Requires a real separate process launch against already-persisted disk state — not automatable in-process under XCTest | Run the app, generate clipboard history, force-quit, relaunch, confirm history is intact via `ClipboardFileStore` load against the real Application Support root |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
