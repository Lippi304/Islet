---
phase: 61
slug: download-progress
status: draft
nyquist_compliant: true
wave_0_complete: true
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
| 61-01-T1 | 01 | 1 | DL-01 | T-61-01 | Temp-file creation matching a known suffix maps to `.inProgress`; non-matching files produce no activity (D-08) | unit | `xcodebuild test -only-testing:IsletTests/DownloadActivityTests` | ❌ W0 (created by 61-01) | ⬜ pending |
| 61-01-T2 | 01 | 1 | DL-01 | — | `.downloadProgress` ranks 5 in `resolve(...)` (above capsLock/updateAvailable, below osd), collapsed-only (D-01/D-03), sub-state-aware `isPersistent` (D-02/D-13), cross-inner-case `updateHead` arm | unit | `xcodebuild test -only-testing:IsletTests/IslandResolverTests` | ✅ (extend existing file) | ⬜ pending |
| 61-02-T1 | 02 | 2 | DL-02 | T-61-03, T-61-04 | Rename-to-final-name maps to `.done(filename:)`; a deleted (never-renamed) temp file produces no activity (D-15); two concurrent downloads: newest stays shown, older's `.done` still fires later via enqueue-vs-replaceHead branch (D-05/D-06); `reset()` clears the in-flight table | unit | `xcodebuild test -only-testing:IsletTests/DownloadCoordinatorTests` | ❌ W0 (created by 61-02) | ⬜ pending |
| 61-03-T1 | 03 | 2 | DL-01/DL-02 | T-61-06 | `downloadWings(for:)` renders both states per 61-UI-SPEC.md; untrusted filename truncated (`.lineLimit(1)` + `.truncationMode(.middle)`); `presentationSwitch` exhaustive | build (no unit test — pure SwiftUI rendering) | `xcodebuild -configuration Debug build` | n/a (view code, not unit-testable in isolation) | ⬜ pending |
| 61-04-T1 | 04 | 3 | DL-01/DL-02 | T-61-08, T-61-09, T-61-10 | `DownloadMonitor` watches only `~/Downloads`, filters nested Safari-bundle writes (Pitfall 1), correlates rename pairs via file ID across batches (Pitfall 2/3) | build (FSEvents C API — no unit test, exercised live in 61-05) | `xcodebuild -configuration Debug build` | n/a (system-glue file, verified on-device) | ⬜ pending |
| 61-04-T2 | 04 | 3 | DL-01/DL-02 | — | `NotchWindowController` owns/starts/stops `DownloadMonitor`; `downloadCoordinator` constructed with Focus-preempt-aware `enqueue` + OSD-style `replaceHead`; every exhaustive switch (`TransientCategory`, `flushTransients`, `syncActivityModels`) covers `.downloadProgress`; `deinit` tears the monitor down | build (wiring/glue — no dedicated unit test) | `xcodebuild -configuration Debug build` | n/a | ⬜ pending |
| 61-05-T1 | 05 | 4 | DL-01/DL-02 | — | Debug + Release builds green; scoped unit suite (DownloadActivityTests, DownloadCoordinatorTests, IslandResolverTests) green | build+unit | `xcodebuild test -only-testing:IsletTests/DownloadActivityTests -only-testing:IsletTests/DownloadCoordinatorTests -only-testing:IsletTests/IslandResolverTests` | ✅ (all created/extended by 01/02) | ⬜ pending |
| 61-05-T2 | 05 | 4 | DL-01/DL-02 | T-61-12 | Live FSEvents behavior against a real `~/Downloads` (create/rename/cancel a real file, concurrent downloads, Safari bundle filtering, D-04 manual-expand-cuts-splash, D-01 priority, Settings gating) | manual | on-device checkpoint (11-step checklist, drop real files, observe HUD timing) | n/a | ⬜ pending |

---

## Wave 0 Requirements

- [x] `IsletTests/DownloadActivityTests.swift` — covers DL-01/DL-02's pure mapping logic (temp-suffix detection, done-state filename extraction, D-15 cancel-silently-drops) — created by Plan 61-01 Task 1 (RED-then-GREEN, 8 test methods)
- [x] `IsletTests/DownloadCoordinatorTests.swift` — covers D-05/D-06 per-file identity tracking, mirrors `DeviceCoordinatorTests.swift`'s structure — created by Plan 61-02 Task 1 (RED-then-GREEN, 10 test methods including `reset()`)
- [x] Extend `IsletTests/IslandResolverTests.swift` — add rank-5 collapsed-only assertions for `.downloadProgress`, verify capsLock/updateAvailable's rank shift to 6/7 doesn't break existing tests — created by Plan 61-01 Task 2 (RED-then-GREEN, 3 new + 1 extended test methods)
- [x] No new framework/config install needed — XCTest target already exists and covers this phase's test shape

All Wave 0 gaps are closed by the plan set itself (Plan 61-01/61-02's own `tdd="true"` tasks write the missing test files as part of RED→GREEN, rather than needing a separate Wave 0 scaffold plan) — no dedicated Wave 0 plan was required.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Live download HUD timing + FSEvents rename correlation | DL-01, DL-02 | FSEvents timing/correlation behavior requires a real filesystem, real browser temp-file lifecycle, and real timing — cannot be simulated in unit tests. Mirrors `CapsLockMonitor`'s Accessibility-gate manual verification precedent. | Drop a real file into `~/Downloads` via Safari/Chrome/Firefox; observe collapsed-island HUD appears within a couple seconds, transitions to "done" on rename, and clears on its own. Repeat with two rapid downloads to confirm no double-fire. Covered by Plan 61-05 Task 2's 11-step checklist. |
| Full XCTest suite (`xcodebuild test`) | All | Known to hang in non-interactive/sandboxed agent sessions per `.planning/PROJECT.md:425` | Run manually via Cmd-U in Xcode before final phase sign-off. All per-task `<automated>` verify commands in this phase's plans are `xcodebuild build` (compile-check only) for this same accepted reason — see RESEARCH.md Pitfall 5. |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies — every task's `<verify><automated>` is `xcodebuild build` (compile-check, per Pitfall 5's accepted constraint); the TDD tasks (61-01-T1/T2, 61-02-T1) additionally specify a Cmd+U `<test_command>` in `acceptance_criteria` for the actual new unit tests.
- [x] Sampling continuity: no 3 consecutive tasks without automated verify — all 7 tasks across the 5 plans carry an `<automated>` build verify.
- [x] Wave 0 covers all MISSING references — all 3 previously-missing test files/extensions are created inline by Plan 61-01 Task 1/Task 2 and Plan 61-02 Task 1's own `tdd="true"` RED→GREEN cycles; no separate Wave 0 plan needed.
- [x] No watch-mode flags
- [x] Feedback latency < 15s (scoped run) / manual gate for on-device FSEvents behavior — Plan 61-05 Task 2 is the manual gate.
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** reconciled against the actual 5-plan/7-task output (revision iteration 1) — automated coverage matches what Plans 61-01 through 61-05 actually deliver; the on-device checkpoint (Plan 61-05 Task 2) remains the phase-gate blocker per RESEARCH.md's own MEDIUM-confidence flag on FSEvents rename correlation (Assumption A3).
