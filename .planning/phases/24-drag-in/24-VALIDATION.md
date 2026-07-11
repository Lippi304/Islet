---
phase: 24
slug: drag-in
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-07-11
---

# Phase 24 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (existing `IsletTests` target) |
| **Config file** | `project.yml` (XcodeGen) — scheme `Islet`, test target already wired |
| **Quick run command** | `xcodebuild -project Islet.xcodeproj -scheme Islet -configuration Debug build` (BUILD gate only) |
| **Full suite command** | Manual Cmd-U in Xcode GUI — `xcodebuild test` hangs headlessly in this environment (project memory `xcodebuild-test-headless-hang`) |
| **Estimated runtime** | ~30s build gate; manual Cmd-U + on-device drag pass untimed |

**Critical caveat (unchanged from Phase 22):** the core SHELF-01/SHELF-02 behavior (does a drag actually get detected and land) is fundamentally **not unit-testable** — it requires a real Window Server drag session, which no XCTest harness exercises. Automated tests only cover the PURE seams (URL extraction, already covered by `DragDropSupportTests.swift`; the new `isWithinDragAcceptRegion` geometry math, if extracted as a pure function). The actual "does the drag get detected, does the drop land" question is exclusively a manual/on-device verification item — this is the spike itself (D-05/D-06).

---

## Sampling Rate

- **After every task commit:** `xcodebuild -project Islet.xcodeproj -scheme Islet -configuration Debug build`
- **After every plan wave:** Same build gate + manual Cmd-U for any new/changed pure-seam unit tests + a manual on-device drag verification pass
- **Before `/gsd:verify-work`:** Full manual on-device UAT (drag single file, multiple files, a folder, an Escape-cancel) — this phase cannot be verification-complete without human hands-on testing
- **Max feedback latency:** ~30s (build gate); on-device passes are untimed manual checkpoints

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 24-01-* | 01 | 0/1 | SHELF-01 | V5 | Reject non-file-URL pasteboard payloads at the drop boundary (`shouldAcceptDrop`) | unit | `xcodebuild test -only-testing:IsletTests/DragDropSupportTests` (via Cmd-U) | ✅ `DragDropSupportTests.swift` exists | ⬜ pending |
| 24-01-* | 01 | 1 | SHELF-01 | — | Spike: `DragApproachDetector` global monitor fires reliably on-device for an inbound Finder drag | manual-only | N/A — no automated harness simulates a real OS drag session | ❌ W0 gap — this task IS the spike | ⬜ pending |
| 24-02-* | 02 | 2 | SHELF-02 | — | Hot/targeted feedback shows before release; `isWithinDragAcceptRegion` geometry math correct | unit + manual | New unit test for `isWithinDragAcceptRegion` pure function; manual Cmd-R visual check | ❌ W0 gap — new pure-function test needed once the geometry helper exists | ⬜ pending |
| 24-0N-* | 0N | N | SHELF-01/02 | — | Stuck-pin prevention: `handleDragApproachEnd()` unconditionally clears drag state | manual-only | Manual on-device Escape-cancel + repeated-trial check | ❌ manual-only | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `IsletTests/DragApproachGeometryTests.swift` (or equivalent) — pure-function unit test for `isWithinDragAcceptRegion(_:)`'s geometry math (expandedZone + landing-margin), testable without any real drag session
- [ ] The on-device spike task itself (D-05) has no automated harness — it is Wave 0/1's manual verification gate before building full accept/shelf-landing logic on top of it

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| DragApproachDetector fires reliably on a real inbound Finder drag | SHELF-01 | Requires a real Window Server drag session; no XCTest harness can simulate `NSEvent.addGlobalMonitorForEvents` delivery during an external drag | Drag a single file from Finder toward the collapsed island in the built app; confirm detector logs/fires before drop |
| Hot/targeted feedback visible while dragging, before release | SHELF-02 | Requires visual on-screen observation of the pill's hover-bounce animation during a live drag | While dragging a file over the pill (before release), visually confirm hover-bounce/scale animation triggers |
| Multi-file and folder drops land correctly in the shelf, in drop order | SHELF-01 | Requires a real multi-item Finder drag and visual shelf inspection | Drag 3 files + 1 folder together onto the collapsed pill; confirm all 4 land in the shelf in drop order |
| Repeated on-device reliability (Success Criterion #3) | SHELF-01 | Statistical reliability claim cannot be unit-tested; requires repeated human trials | Repeat the single-file drag 5+ times in one session; confirm no crash, no frozen hover/click-through state |
| Escape-cancelled drag does not leave the island stuck expanded | SHELF-01/D-07 | Requires simulating a drag-then-cancel gesture and observing panel state | Start a drag over the pill, press Escape before releasing; confirm the island returns to normal (not stuck) |
| Ordinary hover/click/click-through unaffected by new detector | SC #4 | Requires manual interaction with the running app post-implementation | Click, hover, and click-through the island normally (no drag involved); confirm no regression vs. pre-Phase-24 behavior |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s (build gate)
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
