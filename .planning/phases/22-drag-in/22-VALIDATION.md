---
phase: 22
slug: drag-in
status: ready
nyquist_compliant: true
wave_0_complete: true
created: 2026-07-10
---

# Phase 22 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

**Status note:** Updated during revision iteration 2 (2026-07-10, hot-zone/Mission-Control fallback
replan). Plans 22-01/22-02/22-03 cover Wave 0 (URL extraction, folder round-trip, D-04 accept gate,
and -- revised in this iteration -- D-02b/D-02c's expandedZone + landing-margin spatial gate,
replacing the original tiny-hotZone D-02 that 22-01's on-device spike found blocked by macOS's own
Mission Control top-edge trigger). `status`/`nyquist_compliant`/`wave_0_complete` are flipped
accordingly; see Wave 0 Requirements and Validation Sign-Off below for what remains manual-only by
design.

**Critical caveat for this phase specifically:** the core SHELF-01/SHELF-02 behavior (does a
drag actually reach the click-through panel, and is it correctly scoped to the revised
expandedZone-minus-landing-margin region) is fundamentally **not unit-testable** — it requires the
real Window Server drag-delivery pathway, which no XCTest harness exercises. Automated tests can
only cover the PURE seams (URL extraction from a real test-owned `NSPasteboard`, the D-01
`.dragEntered` state transition, the D-04 `shouldAcceptDrop` gate, folder-vs-file `ShelfItem`
construction). Whether the drop arrives at all, and whether it is correctly scoped to the wider
always-reserved panel footprint minus the thin top landing-margin band (D-02b/D-02c) rather than
either the old tiny collapsed pill or the panel's entire unbounded frame, is exclusively a
manual/on-device verification item — this is why the Recommended Spike (see RESEARCH.md) was
sequenced as the literal first task of Wave 1, and why 22-03 Task 3's UAT includes an explicit
D-02b/D-02c boundary check.

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
- **Before `/gsd:verify-work`:** Full manual on-device UAT (drag single file, multiple files, a folder, starting from OUTSIDE the panel's reserved footprint, PLUS the D-02b/D-02c landing-margin boundary check) + Cmd-U green — this phase cannot be verification-complete without human hands-on testing
- **Max feedback latency:** ~60 seconds (build gate) — WARNING acknowledged (checker `nyquist_compliance`): this is a pre-existing, project-wide convention shared by Phases 19-21, not introduced by this phase; no action taken

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 22-01-01/02 | 22-01 | 1 | SHELF-01/SHELF-02 (Spike) | — | Empirically confirms whether `draggingEntered`/`performDragOperation` fire on `NotchPanel` while `ignoresMouseEvents = true`, dragging from outside the hot-zone | manual (on-device) | N/A — manual, per project memory `xcodebuild-test-headless-hang` | N/A — spike | ✅ complete (A1 CONFIRMED; hot-zone/Mission-Control follow-on finding routed to discuss-phase, resolved as D-02b/D-02c below) |
| 22-02-02 | 22-02 | 2 | SHELF-01 | — | `fileURLs(from:)` produces one URL per pasteboard item (including a folder URL, never enumerated) | unit (pure function) | Cmd-U `DragDropSupportTests` | ✅ | ⬜ pending |
| 22-02-01 | 22-02 | 2 | SHELF-01 (D-01) | — | `nextState(.collapsed/.hovering, .dragEntered)` transitions to `.expanded`, mirroring `.clicked` | unit (pure function) | Cmd-U `InteractionStateTests` | ✅ | ⬜ pending |
| 22-02-02 | 22-02 | 2 | SHELF-01 (folder) | — | `ShelfFileStore.makeSessionCopy` correctly round-trips a directory URL | unit | Cmd-U `ShelfFileStoreTests` (`testMakeSessionCopyHandlesDirectoryURL`) | ✅ | ⬜ pending |
| 22-02-02 | 22-02 | 2 | Success Criterion #4 (D-04) | — | `shouldAcceptDrop(isExpanded:urls:)` rejects while expanded and rejects an empty/non-file payload | unit (pure function) | Cmd-U `DragDropSupportTests` | ✅ | ⬜ pending |
| 22-03-02 | 22-03 | 3 | Success Criterion #1 | — | Real file/multi-file/folder drag from Finder lands in the shelf after auto-expand | manual (requires real Finder drag source) | manual on-device (Task 3 steps 2/4/5) | N/A — manual | ⬜ pending |
| 22-03-02 | 22-03 | 3 | D-02b/D-02c (expandedZone + landing-margin spatial gate) | T-22-03-04 | A drag located in the thin band flush against the physical top edge (inside the landing-margin exclusion) triggers neither auto-expand nor a landed drop; the SAME file moved down past the landing margin (still within the panel's reserved expandedZone footprint) DOES auto-expand and accept; a drag entirely outside expandedZone also rejects | manual (requires a real registered `NSDraggingDestination` window and real pointer geometry, not simulable via XCTest) | manual on-device (Task 3 step 3, revised in this iteration) | N/A — manual | ⬜ pending |
| 22-03-02 | 22-03 | 3 | Success Criterion #2 | — | Hot/targeted visual feedback (reused hover-bounce) shows before release, at the same moment as the wider auto-expand trigger | manual (visual) | manual on-device (Task 3 step 6) | N/A — manual | ⬜ pending |
| 22-03-02 | 22-03 | 3 | Success Criterion #3 | — | `.mouseMoved` tracking/hover-collapse state machine is not frozen by a drag-in session; island still collapses normally afterward; ordinary hover/click (small hotZone, unchanged per D-07) is unaffected | manual (live pointer/timer integration, not unit-testable — mirrors Phase 21's `endShelfItemDrag` precedent) | manual on-device (Task 3 step 7) | N/A — manual | ⬜ pending |
| 22-03-02 | 22-03 | 3 | Success Criterion #4 (D-04) | T-22-03-04 | Drop is rejected/no-op while island is already expanded; ordinary click-through unaffected outside a drag | manual + unit (gate condition combines `!interaction.isExpanded` with the D-02b/D-02c `isWithinDragAcceptRegion` check) | Cmd-U + manual on-device (Task 3 step 8) | ✅ (unit half) | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] Unit test for URL-extraction helper (`fileURLs(from:)`, folder = one item) — `IsletTests/DragDropSupportTests.swift` (22-02)
- [ ] Unit test for one-shot drag-enter/exit edge-detection pure function — NOT built as a separate pure function; satisfied architecturally instead (22-03 Task 1 deliberately does not override `draggingUpdated`, so AppKit itself only ever calls `draggingEntered` once per hover session — see Pitfall 2 in RESEARCH.md). Left unchecked because there is no standalone testable seam for this, by design, not an oversight.
- [x] Folder round-trip test added to `ShelfFileStoreTests.swift` (`testMakeSessionCopyHandlesDirectoryURL`, 22-02)
- [x] Unit test for the `!interaction.isExpanded` / non-empty-payload accept-gate (D-04) — `shouldAcceptDrop` tests in `DragDropSupportTests.swift` (22-02)
- [x] No new test framework/config needed — `IsletTests` target already exists and builds

Note: D-02b/D-02c's expandedZone + landing-margin spatial gate (revised in this iteration,
superseding the original tiny-hotZone D-02) has no dedicated Wave 0 unit test —
`globalDragLocation(from:)`/`isWithinDragAcceptRegion(...)` require a real `NotchPanel`/
`NSDraggingInfo` and real screen geometry, which is the same class of not-unit-testable integration
this phase's core risk already is. It is covered exclusively by 22-03 Task 3's on-device UAT (step 3).

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|--------------------|
| Drag delivery survives `ignoresMouseEvents = true` (the spike) | SHELF-01/SHELF-02 | Requires the real Window Server drag pathway; no XCTest harness simulates an OS drag session | Build+run on-device (Cmd-R, not `xcodebuild test`). With the pointer starting OUTSIDE the panel's reserved footprint, drag a Finder file toward the collapsed pill; confirm `draggingEntered`/`performDragOperation` fire (log/breakpoint). Already completed in 22-01 (A1 CONFIRMED); not re-run here. |
| Real file/multi-file/folder lands in shelf | Success Criterion #1 | Requires an actual Finder drag source | Drag one file, then multiple files, then a folder from Finder onto the panel's reserved area (past the landing margin); confirm each becomes a shelf item in drop order |
| D-02b/D-02c expandedZone + landing-margin spatial gate | D-02b, D-02c, Success Criterion #1 | Requires a real registered `NSDraggingDestination` window and real screen-coordinate geometry -- `isWithinDragAcceptRegion()` cannot be exercised without an actual `NotchPanel`/`NSDraggingInfo` pair | Drag a file into the thin band flush against the physical top screen edge (the landing-margin exclusion); confirm no auto-expand and no drop lands. Then move the SAME file down into the panel's reserved area below that band (still well short of the old tiny pill); confirm it now auto-expands and accepts normally. Then drag entirely outside the panel's reserved footprint; confirm it still rejects there too. |
| Hot/targeted visual feedback before release | Success Criterion #2 | Live visual/animation behavior, not unit-testable | Hover a dragged file over the accept region without releasing; confirm the existing hover-bounce spring plays at the same moment the wider auto-expand fires |
| Hover/collapse state machine survives a drag-in session | Success Criterion #3 | Live hover/timer/pointer-position integration inside `NotchWindowController` — no automated harness exists for this system (same as Phases 2/6/9/20/21) | Drag a file into the accept region, then drag it back off without dropping; confirm the island collapses normally afterward (no frozen/stuck state), and that ordinary (non-drag) hover/click against the small, unchanged hotZone still works exactly as before |
| Drop rejected while already expanded | Success Criterion #4 (D-04) | Requires a live expanded-state UI to attempt a drop against | Expand the island (e.g., Now Playing or open shelf), then attempt a Finder drag onto it; confirm no drop occurs and ordinary click-through still works for non-drag pointer movement afterward |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies (manual-only tasks carry an explicit `MISSING -- manual ... (22-VALIDATION.md)` marker with documented rationale, per the phase's own not-unit-testable caveat)
- [x] Sampling continuity: no 3 consecutive tasks without automated verify (22-01 Task1 auto / Task2 manual; 22-02 Task1+Task2 auto; 22-03 Task1+Task2 auto / Task3 manual -- never more than 1 manual task in a row)
- [ ] Wave 0 covers all MISSING references — one intentional gap remains (drag-enter/exit edge-detection has no standalone pure-function test, by architectural design; see Wave 0 Requirements note above)
- [x] No watch-mode flags
- [ ] Feedback latency < 60s (build gate) — WARNING acknowledged, not addressed: pre-existing project-wide ~30-60s convention, not introduced by this phase
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
