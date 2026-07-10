---
phase: 22
slug: drag-in
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-10
---

# Phase 22 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

**Status note:** `status: draft` / `nyquist_compliant: false` / `wave_0_complete: false` and the
unchecked Sign-Off checklist below reflect that this file was authored at PLANNING time — Wave 0
items are planned here, not yet executed. Matches Phase 20/21's own VALIDATION.md convention.

**Critical caveat for this phase specifically:** the core SHELF-01/SHELF-02 behavior (does a
drag actually reach the click-through panel) is fundamentally **not unit-testable** — it requires
the real Window Server drag-delivery pathway, which no XCTest harness exercises. Automated tests
can only cover the PURE seams (URL extraction from a mock `NSDraggingInfo`, one-shot
drag-enter/exit edge detection, folder-vs-file `ShelfItem` construction). Whether the drop
arrives at all is exclusively a manual/on-device verification item — this is why the Recommended
Spike (see RESEARCH.md) is sequenced as the literal first task of Wave 1.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (existing, `IsletTests/` target) |
| **Config file** | `project.yml` (XcodeGen) — scheme `Islet`, test target already wired |
| **Quick run command** | `xcodebuild -project Islet.xcodeproj -scheme Islet -configuration Debug build` (compiles/builds only — does NOT execute; `xcodebuild test` hangs headlessly, see project memory `xcodebuild-test-headless-hang`) |
| **Full suite command** | Manual **Cmd-U in Xcode** — tests host the full `Islet.app` boot (NSPanel/MediaRemote/IOBluetooth), same pre-existing constraint as Phases 20/21 |
| **Estimated runtime** | ~30-60s build gate; manual Cmd-U pass is untimed |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild -project Islet.xcodeproj -scheme Islet -configuration Debug build` (build gate only)
- **After every plan wave:** Manual Cmd-U for new/changed pure-seam unit tests + a manual on-device drag verification pass
- **Before `/gsd:verify-work`:** Full manual on-device UAT (drag single file, multiple files, a folder, starting from OUTSIDE the hot-zone) + Cmd-U green — this phase cannot be verification-complete without human hands-on testing
- **Max feedback latency:** ~60 seconds (build gate)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 22-01-xx | TBD | 1 | SHELF-01/SHELF-02 (Spike) | — | Empirically confirms whether `draggingEntered`/`performDragOperation` fire on `NotchPanel` while `ignoresMouseEvents = true`, dragging from outside the hot-zone | manual (on-device) | N/A — manual, per project memory `xcodebuild-test-headless-hang` | N/A — spike | ⬜ pending |
| 22-01-xx | TBD | TBD | SHELF-01 | — | `[URL]` → `[ShelfItem]` extraction helper produces one item per URL (including a folder URL, never enumerated), in drop order | unit (pure function) | Cmd-U new test in `IsletTests` | ❌ W0 | ⬜ pending |
| 22-01-xx | TBD | TBD | SHELF-02 | — | One-shot drag-enter/exit edge-detection helper fires exactly once per hover session, not per `draggingUpdated` tick | unit (pure function, mirrors `pointerInZone` WR-01 pattern) | Cmd-U new test in `IsletTests` | ❌ W0 | ⬜ pending |
| 22-01-xx | TBD | TBD | SHELF-01 (folder) | — | `ShelfFileStore.makeSessionCopy` correctly round-trips a directory URL | unit | Cmd-U `ShelfFileStoreTests` (new case) | ❌ W0 | ⬜ pending |
| 22-01-xx | TBD | TBD | Success Criterion #1 | — | Real file/multi-file/folder drag from Finder lands in the shelf after auto-expand | manual (requires real Finder drag source) | manual on-device | N/A — manual | ⬜ pending |
| 22-01-xx | TBD | TBD | Success Criterion #2 | — | Hot/targeted visual feedback (reused hover-bounce) shows before release | manual (visual) | manual on-device | N/A — manual | ⬜ pending |
| 22-01-xx | TBD | TBD | Success Criterion #3 | — | `.mouseMoved` tracking/hover-collapse state machine is not frozen by a drag-in session; island still collapses normally afterward | manual (live pointer/timer integration, not unit-testable — mirrors Phase 21's `endShelfItemDrag` precedent) | manual on-device | N/A — manual | ⬜ pending |
| 22-01-xx | TBD | TBD | Success Criterion #4 (D-04) | — | Drop is rejected/no-op while island is already expanded; ordinary click-through unaffected outside a drag | manual + unit (gate condition is a pure `!interaction.isExpanded` check) | Cmd-U + manual on-device | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Unit test for URL-extraction helper (`[URL]` → `[ShelfItem]`, folder = one item) in `IsletTests`
- [ ] Unit test for one-shot drag-enter/exit edge-detection pure function
- [ ] Folder round-trip test added to `ShelfFileStoreTests.swift` (`makeSessionCopy` on a directory URL)
- [ ] Unit test for the `!interaction.isExpanded` accept-gate (D-04)
- [ ] No new test framework/config needed — `IsletTests` target already exists and builds

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|--------------------|
| Drag delivery survives `ignoresMouseEvents = true` (the spike) | SHELF-01/SHELF-02 | Requires the real Window Server drag pathway; no XCTest harness simulates an OS drag session | Build+run on-device (Cmd-R, not `xcodebuild test`). With the pointer starting OUTSIDE the hot-zone, drag a Finder file onto the collapsed pill; confirm `draggingEntered`/`performDragOperation` fire (log/breakpoint) |
| Real file/multi-file/folder lands in shelf | Success Criterion #1 | Requires an actual Finder drag source | Drag one file, then multiple files, then a folder from Finder onto the collapsed pill; confirm each becomes a shelf item in drop order |
| Hot/targeted visual feedback before release | Success Criterion #2 | Live visual/animation behavior, not unit-testable | Hover a dragged file over the pill without releasing; confirm the existing hover-bounce spring plays |
| Hover/collapse state machine survives a drag-in session | Success Criterion #3 | Live hover/timer/pointer-position integration inside `NotchWindowController` — no automated harness exists for this system (same as Phases 2/6/9/20/21) | Drag a file onto the pill, then drag it back off without dropping; confirm the island collapses normally afterward (no frozen/stuck state) |
| Drop rejected while already expanded | Success Criterion #4 (D-04) | Requires a live expanded-state UI to attempt a drop against | Expand the island (e.g., Now Playing or open shelf), then attempt a Finder drag onto it; confirm no drop occurs and ordinary click-through still works for non-drag pointer movement afterward |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s (build gate)
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
