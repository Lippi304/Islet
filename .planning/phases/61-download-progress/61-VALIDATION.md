---
phase: 61
slug: download-progress
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-23
---

# Phase 61 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest [VERIFIED: `IsletTests/*.swift`] |
| **Config file** | `Islet.xcodeproj` test target (no separate config file) |
| **Quick run command** | `xcodebuild build -project Islet.xcodeproj -scheme Islet` (compile-check only — full suite has a known hang, see Manual-Only section) |
| **Full suite command** | `xcodebuild test -project Islet.xcodeproj -scheme Islet` — known to hang in non-interactive/sandboxed agent sessions; route to manual Cmd-U per `.planning/PROJECT.md:425` |
| **Estimated runtime** | ~10s (build) / manual Cmd-U for full suite |

---

## Sampling Rate

- **After every task commit:** `xcodebuild build -project Islet.xcodeproj -scheme Islet`
- **After every plan wave:** `xcodebuild test -project Islet.xcodeproj -scheme Islet -only-testing:IsletTests/DownloadActivityTests -only-testing:IsletTests/DownloadCoordinatorTests -only-testing:IsletTests/IslandResolverTests` (scoped to avoid the full-suite Bluetooth hang)
- **Before `/gsd:verify-work`:** Scoped suite above must be green, PLUS the on-device manual checkpoint (real file dropped into `~/Downloads`) must be observed
- **Max feedback latency:** ~15 seconds (scoped test run)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 61-01-xx | 01 | 0 | DL-01 | — | Temp-file creation matching a known suffix maps to `.inProgress`; non-matching files produce no activity (D-08) | unit | `xcodebuild test -only-testing:IsletTests/DownloadActivityTests` | ❌ W0 | ⬜ pending |
| 61-01-xx | 01 | 0 | DL-02 | — | Rename-to-final-name maps to `.done(filename:)`; a deleted (never-renamed) temp file produces no activity (D-15) | unit | `xcodebuild test -only-testing:IsletTests/DownloadActivityTests` | ❌ W0 | ⬜ pending |
| 61-01-xx | 01 | 0 | DL-02 | — | Two concurrent downloads: newest replaces the shown head, older's `.done` still fires later (D-05/D-06) | unit | `xcodebuild test -only-testing:IsletTests/DownloadCoordinatorTests` | ❌ W0 | ⬜ pending |
| 61-0x-xx | TBD | TBD | DL-01 | — | `.downloadProgress` ranks 5 in `resolve(...)` (above capsLock/updateAvailable, below osd), collapsed-only (D-01/D-03) | unit | `xcodebuild test -only-testing:IsletTests/IslandResolverTests` | ✅ (extend existing file) | ⬜ pending |
| 61-0x-xx | TBD | TBD | DL-01/DL-02 | — | Live FSEvents behavior against a real `~/Downloads` (create/rename/cancel a real file) | manual | on-device checkpoint (drop a real file, observe HUD timing) | n/a | ⬜ pending |

*Task IDs are placeholders — the planner assigns final plan/task numbers; this table's rows must be reconciled against the actual plan output.*

---

## Wave 0 Requirements

- [ ] `IsletTests/DownloadActivityTests.swift` — covers DL-01/DL-02's pure mapping logic (temp-suffix detection, done-state filename extraction, D-15 cancel-silently-drops)
- [ ] `IsletTests/DownloadCoordinatorTests.swift` — covers D-05/D-06 per-file identity tracking, mirrors `DeviceCoordinatorTests.swift`'s structure
- [ ] Extend `IsletTests/IslandResolverTests.swift` — add rank-5 collapsed-only assertions for `.downloadProgress`, verify capsLock/updateAvailable's rank shift to 6/7 doesn't break existing tests
- [ ] No new framework/config install needed — XCTest target already exists and covers this phase's test shape

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Live download HUD timing + FSEvents rename correlation | DL-01, DL-02 | FSEvents timing/correlation behavior requires a real filesystem, real browser temp-file lifecycle, and real timing — cannot be simulated in unit tests. Mirrors `CapsLockMonitor`'s Accessibility-gate manual verification precedent. | Drop a real file into `~/Downloads` via Safari/Chrome/Firefox; observe collapsed-island HUD appears within a couple seconds, transitions to "done" on rename, and clears on its own. Repeat with two rapid downloads to confirm no double-fire. |
| Full XCTest suite (`xcodebuild test`) | All | Known to hang in non-interactive/sandboxed agent sessions per `.planning/PROJECT.md:425` | Run manually via Cmd-U in Xcode before final phase sign-off |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s (scoped run) / manual gate for on-device FSEvents behavior
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
