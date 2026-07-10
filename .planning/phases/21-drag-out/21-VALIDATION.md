---
phase: 21
slug: drag-out
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-10
---

# Phase 21 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

**Status note:** `status: draft` / `nyquist_compliant: false` / `wave_0_complete: false` and the
unchecked Sign-Off checklist below reflect that this file was authored at PLANNING time — Wave 0
items are planned here, not yet executed. This matches Phase 20's own VALIDATION.md convention
(`.planning/phases/20-shelf-view/20-VALIDATION.md`): sign-off finalizes post-execution, once the
Wave 0 test cases actually exist and the Cmd-U/manual checks in this file have been run. This is
not a gap — it is the expected pre-execution state for this project.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (existing, `IsletTests/` target) |
| **Config file** | none — see Wave 0 |
| **Quick run command** | `xcodebuild build-for-testing -scheme Islet -configuration Debug` (compiles the test target — does NOT execute; `xcodebuild test` hangs headlessly, see project memory `xcodebuild-test-headless-hang`) |
| **Full suite command** | Manual **Cmd-U in Xcode** — tests host the full `Islet.app` (NSPanel/MediaRemote/IOBluetooth boot), same pre-existing constraint as Phase 20 |
| **Estimated runtime** | ~30-60s build gate; manual Cmd-U pass is untimed |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild build -scheme Islet -configuration Debug` (build gate only)
- **After every plan wave:** Manual Cmd-U full suite + the 3 manual on-device checks below (D-03, Criterion #1, Criterion #2)
- **Before `/gsd:verify-work`:** All 3 manual checks confirmed + Cmd-U green
- **Max feedback latency:** ~60 seconds (build gate)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 21-01-xx | TBD | TBD | SHELF-06 (D-02) | — | `shouldBeginShelfItemDrag(fileExists:)` returns false when file missing, true otherwise | unit | Cmd-U `ShelfViewStateTests` | ❌ W0 | ⬜ pending |
| 21-01-xx | TBD | TBD | SHELF-06 (D-01) | — | A successful drag-out never calls `ShelfCoordinator.remove`/`clear` — item still present after drag | unit (behavioral, no coordinator mutation in drag path) + code-review grep | Cmd-U `ShelfCoordinatorTests` (unchanged = regression proof) | ✅ existing | ⬜ pending |
| 21-01-xx | TBD | TBD | SHELF-06 (D-03) | — | Drag-start suppresses grace-collapse; drag-end (or safety-net) resumes it | manual (live hover/timer/pointer integration, not unit-testable — mirrors existing hover/grace-collapse precedent) | manual on-device | N/A — manual | ⬜ pending |
| 21-01-xx | TBD | TBD | SHELF-06 (Success Criterion #1) | — | Real file lands on Finder desktop after drag-out | manual (requires real Finder drop target) | manual on-device | N/A — manual | ⬜ pending |
| 21-01-xx | TBD | TBD | SHELF-06 (Success Criterion #2) | — | Missing backing file → graceful no-op, no crash | manual (TOCTOU-adjacent, on-device only) | manual on-device | N/A — manual | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Add `testShouldBeginShelfItemDrag` cases to `IsletTests/ShelfViewStateTests.swift` (mirrors existing `shouldOpenShelfItem` test convention in that file)
- [ ] No new test framework/config needed — `IsletTests` target already exists and builds

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Drag-start suppresses grace-collapse; resumes cleanly after drop | SHELF-06 (D-03) | Live hover/timer/pointer-position integration inside `NotchWindowController` — no automated harness exists for the hover/grace-collapse system (same as Phases 2/6/9/20) | Slowly drag a shelf item; confirm panel stays open throughout the drag, then returns to normal hover/grace-collapse behavior within the grace delay after drop |
| Real file lands in Finder after drag-out | SHELF-06 (Success Criterion #1) | Requires an actual Finder drop target | Drag a shelf item to the Desktop; confirm the real file appears there |
| Missing backing file → graceful no-op, no crash | SHELF-06 (Success Criterion #2) | On-device file-system race/timing, not practically unit-testable | Externally delete an item's temp file, then attempt to drag it; confirm no crash and no drop occurs |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s (build gate)
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
