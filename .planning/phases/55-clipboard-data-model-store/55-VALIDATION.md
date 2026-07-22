---
phase: 55
slug: clipboard-data-model-store
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-22
---

# Phase 55 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (bundled with Xcode 16+) — confirmed via `import XCTest` in every existing test file, zero Swift Testing usage anywhere in `IsletTests/` |
| **Config file** | `project.yml`'s `IsletTests` target (lines ~197-228) — `TEST_HOST`/`BUNDLE_LOADER` point at the built `Islet.app` binary, `@testable import Islet` used throughout |
| **Quick run command** | `xcodebuild test -project Islet.xcodeproj -scheme Islet -only-testing:IsletTests/ClipboardStoreTests` |
| **Full suite command** | `xcodebuild test -project Islet.xcodeproj -scheme Islet` |
| **Estimated runtime** | ~5-10 seconds (quick), full suite unchanged from current baseline — pure in-memory logic, no device/UI dependency |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild test -project Islet.xcodeproj -scheme Islet -only-testing:IsletTests/ClipboardStoreTests`
- **After every plan wave:** Run `xcodebuild test -project Islet.xcodeproj -scheme Islet`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** ~10 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 55-01-01 | 01 | 1 | SC-1 (pure types, unit-tested) | — | `ClipboardItem`/`ClipboardStore` exist, no AppKit/NSPasteboard imports | unit | `xcodebuild test ... -only-testing:IsletTests/ClipboardStoreTests` + build-log import grep | ❌ W0 | ⬜ pending |
| 55-01-02 | 01 | 1 | SC-2 (cap + FIFO eviction) | — | Appending past 30 items evicts the oldest | unit | `testAppendEvictsOldestPastCap` | ❌ W0 | ⬜ pending |
| 55-01-03 | 01 | 1 | SC-3 (clear empties store) | — | `clear()` removes every item in one call | unit | `testClearEmptiesStore` | ❌ W0 | ⬜ pending |
| 55-01-04 | 01 | 1 | SC-4 (independent axis) | — | Zero imports of `IslandResolver`/`TransientQueue`/`NotchWindowController` in `Islet/Clipboard/*.swift` | static check | `grep -L "IslandResolver\|TransientQueue\|NotchWindowController" Islet/Clipboard/*.swift` (expect all files listed) | ❌ W0 | ⬜ pending |
| 55-01-05 | 01 | 1 | D-02 (dedupe-and-move-to-top) | — | Re-adding identical text/image content moves existing entry to top, refreshes timestamp | unit | `testAppendDuplicateTextMovesToTopWithRefreshedTimestamp` / equivalent image test | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `Islet/Clipboard/ClipboardItem.swift` — new source file (prerequisite the test file needs to compile)
- [ ] `Islet/Clipboard/ClipboardStore.swift` — new source file, same as above
- [ ] `IsletTests/ClipboardStoreTests.swift` — covers SC-1/2/3/4 and D-02 (new test file)
- [ ] No new shared fixtures/conftest-equivalent needed — this codebase's convention (per `ShelfLogicTests.swift`) is a fresh `var store = ClipboardStore()` per test method, no `setUp()`/shared state

---

## Manual-Only Verifications

*None — all phase behaviors have automated verification. No on-device UAT checkpoint needed for this phase (no UI surface exists yet; mirrors Phase 19's Plan 1, which also had no UAT gate).*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 10s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
