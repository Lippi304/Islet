---
phase: 20
slug: shelf-view
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-09
---

# Phase 20 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (existing, `IsletTests/` target) |
| **Config file** | `project.yml` (XcodeGen-generated `.xcodeproj`, no separate XCTest config) |
| **Quick run command** | `xcodebuild build-for-testing -scheme Islet -configuration Debug` (compiles the test target — does NOT execute) |
| **Full suite command** | Manual **Cmd-U in Xcode** — `xcodebuild test` hangs headlessly because tests host the full `Islet.app` (NSPanel/MediaRemote/IOBluetooth boot). Pre-existing, documented constraint. |
| **Estimated runtime** | ~30-60s build gate; manual Cmd-U pass is untimed |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild build -scheme Islet -configuration Debug` (build gate only)
- **After every plan wave:** Manual Cmd-U in Xcode GUI
- **Before `/gsd:verify-work`:** Full manual Cmd-U pass + on-device UAT (drag-free, hand-seeded shelf state)
- **Max feedback latency:** ~60 seconds (build gate)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 20-01-xx | TBD | TBD | SHELF-03 | — | Shelf row appears/scrolls with unbounded items when expanded + non-empty | manual (SwiftUI view, no pure logic to extract) | — (visual, Cmd-U / on-device) | N/A — view-level | ⬜ pending |
| 20-01-xx | TBD | TBD | SHELF-04 | — | Per-item trash removes just that item | unit (`ShelfViewState` sync after `ShelfCoordinator.remove`) | Cmd-U `ShelfViewStateTests` | ❌ W0 | ⬜ pending |
| 20-01-xx | TBD | TBD | SHELF-05 | — | Delete-all clears every item | unit (`ShelfViewState` sync after `ShelfCoordinator.clear`) | Cmd-U `ShelfViewStateTests` | ❌ W0 | ⬜ pending |
| 20-01-xx | TBD | TBD | SHELF-07 | T-20-01 | Click-to-open opens file; missing-file click is a silent no-op (D-04) | unit (pure `fileExists`-guarded open decision, mirroring "pure gate, controller applies it" shape) | Cmd-U new controller-decision test file | ❌ W0 | ⬜ pending |
| 20-01-xx | TBD | TBD | SHELF-09 | — | Shelf hidden during Charging/Device splash | unit — extend existing `resolve(...)` pure function coverage | Cmd-U, extend `IslandResolverTests.swift` | ✅ (existing file, new case only) | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `IsletTests/ShelfViewStateTests.swift` — new file, covers SHELF-04/SHELF-05 (published-mirror sync after coordinator mutations)
- [ ] A small pure helper + its test covering SHELF-07's fileExists-guard decision (new test file, or extend an existing controller-decision test file if one already exists — check before creating)
- [ ] One new test case appended to existing `IsletTests/IslandResolverTests.swift` for SHELF-09 (no new resolver production code required)
- [ ] Framework install: none — `IsletTests` target already exists and builds

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Shelf strip renders, scrolls horizontally, shows correct file-type icons | SHELF-03 | SwiftUI view rendering — no pure logic to unit test | Hand-seed shelf state with several items (mixed file types), expand island, visually confirm scroll strip + icons in Xcode GUI or on-device |
| Panel/window resizes correctly to fit shelf row without clipping | SHELF-03, D-01 | Live window geometry — not exercised by unit tests | Expand island with shelf items present across all three branches (`mediaExpanded`, `expandedIdle`, `mediaUnavailable`); confirm no clipping |
| Shelf strip visually hides/reappears in sync with Charging/Device splash | SHELF-09 | Visual timing of transient overlay vs. shelf row | Trigger a Charging or Device splash while shelf has items; confirm shelf strip disappears during splash and reappears after |
| Tapping empty shelf-strip space collapses the island (D-05) | — (D-05, informational) | Gesture-region behavior on-device | Tap blank space within the shelf strip (not on an item or trash icon); confirm island collapses |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s (build gate)
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
