---
phase: 32
slug: tray-widening
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-07-14
---

# Phase 32 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (existing `IsletTests` target) |
| **Config file** | `project.yml` (XcodeGen) — `IsletTests` target, shared `Islet` scheme |
| **Quick run command** | `xcodebuild build -scheme Islet -destination 'platform=macOS'` (build-only gate — `xcodebuild test` hangs headless, see project memory `xcodebuild-test-headless-hang`) |
| **Full suite command** | Manual Cmd-U in Xcode |
| **Estimated runtime** | ~30s build / manual for full suite |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild build -scheme Islet -destination 'platform=macOS'`
- **After every plan wave:** Manual Cmd-U full `IsletTests` run, PLUS on-device hover→expand→move-down trace for click-through (CR-01/CR-02 precedent — cannot be automated)
- **Before `/gsd:verify-work`:** Full suite green (Cmd-U) + on-device trace passed
- **Max feedback latency:** ~30 seconds (build gate); manual full-suite/on-device checks gate the wave/phase boundary, not each task

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 32-01-xx | TBD | 0 | TRAY-05 (geometry math) | — | N/A | unit | `xcodebuild build -scheme Islet -destination 'platform=macOS'` | ❌ W0 — extend `NotchGeometryTests.swift` | ⬜ pending |
| 32-0x-xx | TBD | 1 | TRAY-05 (`blobShape` height-override fix) | — | N/A | manual-only (SwiftUI view internals not assertable without ViewInspector) | manual | n/a | ⬜ pending |
| 32-0x-xx | TBD | 1 | TRAY-05 (Tray-only width, no leak to other tabs) | — | N/A | manual-only (SwiftUI view-tree assertion limits; low-value unit test) | manual | n/a | ⬜ pending |
| 32-0x-xx | TBD | 1+ | TRAY-05 success criterion 4 (click-through) | — | N/A | manual-only (CR-01/CR-02 precedent — live global mouse-event monitor) | manual | n/a | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `NotchGeometryTests.swift` — extend with a Tray-sized `expandedNotchFrame`/`topPinnedFrame` centering case (mirrors existing `testExpandedNotchFrameCentersOnMidXAndPinsTop`, lines 117-134)

*No new test framework/config needed — `IsletTests` target and shared scheme already fully wired.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `blobShape` height override takes effect when `showSwitcher: true` | TRAY-05 | SwiftUI view internals not directly assertable without ViewInspector (not a project dependency — not adding for one assertion) | Open Tray tab on-device, confirm Tray height matches the new shrink-to-fit target, not the old fixed `switcherContentHeight` |
| Tray widens visibly, more tiles side-by-side, no scrolling for typical file counts | TRAY-05 criteria 1-2 | Visual layout confirmation | Drag several files into the shelf, open Tray, confirm wider layout and larger tiles vs. previous build |
| Existing Tray interactions unchanged (trash, delete-all, click-to-open, drag-out) | TRAY-05 criterion 3 | Interactive behaviors requiring live UI | Exercise each interaction on-device in the new wider layout, confirm no regressions |
| Click-through hit-testing matches new geometry exactly | TRAY-05 criterion 4 | `visibleContentZone()`'s consumer is a live global mouse-event monitor — CR-01/CR-02 regression class empirically not caught by unit tests alone in this codebase's history | Full on-device hover→expand→move-down trace per CR-01 precedent (project memory `cr01-clickthrough-or-defeat-gotcha`) — confirm expanded branch stays pure `visibleContentZone()`, no OR'd `pointerInZone` |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s (build gate)
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
