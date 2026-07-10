---
phase: 21-drag-out
verified: 2026-07-10T03:56:00Z
status: human_needed
score: 6/6 must-haves verified in code
overrides_applied: 0
---

# Phase 21: Drag-Out Verification Report

**Phase Goal:** Users can drag a file already staged in the shelf back out to Finder or any other app, using the item's own local copy — validated before the higher-risk drag-in work.
**Verified:** 2026-07-10T03:56:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | User can drag a shelf item out of the strip onto Finder/another app and the real file lands there (SC#1) | ✓ VERIFIED (code) / human confirmation pending | `ShelfItemView.swift:27-32` `.onDrag` returns `NSItemProvider(contentsOf: item.localURL)`. Actual OS-level drop behavior cannot be verified by grep — requires on-device drag test (plan's own `<verification>` item 3). |
| 2 | Dragging a shelf item whose backing file vanished is a silent no-op — no crash, no drop, item stays inert (D-02, SC#2) | ✓ VERIFIED (code) / human confirmation pending | `shouldBeginShelfItemDrag(fileExists:)` gates the closure; on `false` returns empty `NSItemProvider()`, `onDragStarted()` never called. Reviewer's IN-01 notes the drag *ghost* still visually starts (SwiftUI has no failable `.onDrag`) — functionally correct (no payload, no crash) but on-device confirmation is the plan's own item 4. |
| 3 | Shelf item stays in the shelf after a successful drag-out — drag never removes it (D-01, copy semantics) | ✓ VERIFIED | Grepped `beginShelfItemDrag`/`endShelfItemDrag`/`ShelfItemView.swift`/`NotchPillView.swift` bodies for `ShelfCoordinator` — zero references. No remove/clear call anywhere in the drag path. |
| 4 | Starting a drag pins the island open; resumes normal hover/grace-collapse promptly on drag end (best-effort `.leftMouseUp` signal) or, failing that, after a 20s safety net — never stuck open for the full 20s on an ordinary drag (D-03, SC#3) | ✓ VERIFIED (code, incl. WR-01 fix) / human confirmation pending | `beginShelfItemDrag()` (NotchWindowController.swift:1261-1276) cancels `graceWorkItem`, arms `dragPinSafetyNetWorkItem` (20s) and a `.leftMouseUp` global monitor. `handleHoverExit`'s `graceWorkItem` body guards on `!isDraggingShelfItem` (line 797). `endShelfItemDrag()` (1283-1294) is idempotent and — per the WR-01 fix committed at `96e0a3d` — re-samples the live pointer via `handlePointer(at: NSEvent.mouseLocation)` instead of trusting the stale `pointerInZone` flag, so a drop outside the hot zone correctly re-triggers `handleHoverExit()`. Timing "feel" (prompt vs. full 20s) needs on-device confirmation (plan item 2). |
| 5 | Existing tap-to-open and delete-button gestures continue to work unchanged after the drag gesture is added (Finding-15 precedent) | ✓ VERIFIED | `ShelfItemView.swift` — `.onTapGesture { onTap() }` (line 26) and the delete `Button` inside `.overlay` (lines 33-43) are unmodified; `.onDrag` (line 27) is a sibling modifier, not nested in/around either. |
| 6 | The drag preview is the default system preview (file's own icon via NSItemProvider/onDrag out of the box) — no custom rendering added (D-04) | ✓ VERIFIED | `ShelfItemView.swift:31` returns `NSItemProvider(contentsOf: item.localURL) ?? NSItemProvider()` — no custom drag-preview view, no `itemProvider` subclass, no `NSViewRepresentable` preview wrapper anywhere in the diff. |

**Score:** 6/6 truths structurally verified in code. All 6 require or benefit from on-device confirmation for the actual OS drag-and-drop feel — these are exactly the items the plan itself designates manual-only (see Human Verification below), consistent with this project's established convention (Phases 2/6/9/20) that hover/grace-collapse/click-through/drag behavior has no automated harness.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `Islet/Shelf/ShelfViewState.swift` | `shouldBeginShelfItemDrag(fileExists:)` pure gate | ✓ VERIFIED | Line 19: `func shouldBeginShelfItemDrag(fileExists: Bool) -> Bool { fileExists }`, identical shape to `shouldOpenShelfItem`. |
| `IsletTests/ShelfViewStateTests.swift` | `testShouldBeginShelfItemDragGate` unit coverage | ✓ VERIFIED | Lines 79-82: asserts both `true`/`false` branches. |
| `Islet/Notch/ShelfItemView.swift` | `.onDrag` drag-source wiring via `NSItemProvider(contentsOf:)` | ✓ VERIFIED | Lines 27-32, sibling to `.onTapGesture`, gated via `shouldBeginShelfItemDrag`. |
| `Islet/Notch/NotchPillView.swift` | `onShelfItemDragStarted` closure threaded through `shelfRow` | ✓ VERIFIED | Line 92 declares the closure; line 302 forwards it into `ShelfItemView(...)`. |
| `Islet/Notch/NotchWindowController.swift` | `isDraggingShelfItem` pin + `beginShelfItemDrag`/`endShelfItemDrag` + `dragPinSafetyNetWorkItem` + `dragReleaseMonitor` + `handleHoverExit` guard | ✓ VERIFIED | Properties at 216-219; methods at 1261-1294; guard at line 797; `makeRootView` wiring at 959; `deinit` cleanup at 1336-1337. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `ShelfItemView.swift` | `ShelfViewState.swift` | `.onDrag` closure calls `shouldBeginShelfItemDrag(fileExists:)` before constructing the provider | ✓ WIRED | Line 29. |
| `NotchPillView.swift` | `ShelfItemView.swift` | `shelfRow` forwards `onDragStarted: { onShelfItemDragStarted() }` | ✓ WIRED | Line 302. |
| `NotchWindowController.swift` | `NotchPillView.swift` | `makeRootView` forwards `onShelfItemDragStarted: { [weak self] in self?.beginShelfItemDrag() }` | ✓ WIRED | Line 959. |
| `NotchWindowController.swift handleHoverExit` | `isDraggingShelfItem` | `graceWorkItem` closure guards on the drag-pin flag | ✓ WIRED | Line 797: `guard !self.isDraggingShelfItem else { return }`. |
| `NotchWindowController.swift dragReleaseMonitor` | `endShelfItemDrag()` | `.leftMouseUp` global monitor callback | ✓ WIRED | Lines 1271-1275. |
| `NotchWindowController.swift syncClickThrough()` | (must have ZERO diff, CR-01 anti-regression) | — | ✓ VERIFIED | `awk` extraction of the function body: 0 occurrences of `isDraggingShelfItem`/`dragReleaseMonitor`. Expanded branch still pure `visibleContentZone()?.contains(...)`. |

### Post-Review Fix Verification (WR-01)

The code review (`21-REVIEW.md`) found `endShelfItemDrag()` trusted a stale `pointerInZone` flag (frozen during an OS drag session because `.mouseMoved` doesn't fire mid-drag) instead of re-sampling the pointer, which could leave the island stuck open after a drag ended outside the hot zone. Confirmed the claimed fix is actually present in the current code (not just claimed in SUMMARY.md):
- Commit `96e0a3d` (`fix(21): re-sync pointer state in endShelfItemDrag (WR-01)`) exists in `git log`.
- `NotchWindowController.swift:1290-1293` now calls `handlePointer(at: NSEvent.mouseLocation)` instead of the old `if !pointerInZone { handleHoverExit() }` stale-flag check.
- `handlePointer(at:)` (lines 671-702) re-derives `inside`/`pointerInZone` from the live point and calls `handleHoverExit()` on the enter/exit edge — the fix closes the gap described in WR-01.
- `xcodebuild build -scheme Islet -configuration Debug` → `BUILD SUCCEEDED` (re-run independently by this verifier, not taken from SUMMARY.md claim).

### Behavioral Spot-Checks / Automated Gates

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Full app build (post-WR-01 fix) | `xcodebuild build -scheme Islet -destination 'platform=macOS' -configuration Debug` | `** BUILD SUCCEEDED **` | ✓ PASS |
| Test target compiles | `xcodebuild build-for-testing -scheme Islet -configuration Debug` | `** TEST BUILD SUCCEEDED **` | ✓ PASS |
| No debt markers in phase-modified files | `grep -n "TBD\|FIXME\|XXX\|TODO\|HACK\|PLACEHOLDER"` across all 5 modified files | None found (unrelated "placeholder" comments predate this phase, e.g. album-art nil fallback, DEBUG seed filenames) | ✓ PASS |
| D-01 regression check (no `ShelfCoordinator.remove`/`.clear` in drag path) | grep across `beginShelfItemDrag`/`endShelfItemDrag`/`ShelfItemView.swift`/`NotchPillView.swift` bodies | 0 occurrences of `ShelfCoordinator` | ✓ PASS |

Per project memory (`xcodebuild-test-headless-hang`), `xcodebuild test` was NOT run headlessly by this verifier — consistent with the plan's own designation of Cmd-U test execution as manual-only.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| SHELF-06 | 21-01-PLAN.md | User can drag a shelf item back out to Finder or any other app | ✓ SATISFIED (code) | `.onDrag` drag source + drag-pin lifecycle verified above. Final on-device Success Criterion #1/#2 confirmation is the remaining human-verify item. |

No orphaned requirements — REQUIREMENTS.md maps only SHELF-06 to Phase 21, and it appears in the plan's `requirements:` frontmatter. Note: REQUIREMENTS.md's checkbox for SHELF-06 and its Traceability table row (`Phase 21 | Pending`) are still unchecked/stale at time of this verification — expected, since the housekeeping "mark ROADMAP/REQUIREMENTS complete" step runs after verification passes (project memory: `gsd-phase-complete-roadmap-gaps`), not before.

### Anti-Patterns Found

None. No debt markers (TBD/FIXME/XXX/TODO/HACK), no stub returns, no empty handlers, no hardcoded-empty state feeding rendering, in any of the 5 phase-modified files.

Two INFO-level findings from the code review remain open (not blockers per the review's own classification, and not must-haves in the plan's frontmatter):
- **IN-01**: the `shouldBeginShelfItemDrag` doc-comment says "silent no-op drag" but SwiftUI's `.onDrag` always starts a visible drag ghost even when an empty `NSItemProvider()` is returned (API constraint, not a code defect). Comment-wording issue only.
- **IN-02**: the thread `.onDrag`'s item-provider closure runs on is unverified; `beginShelfItemDrag()` touches `@MainActor` state and AppKit APIs without an explicit main-thread hop. No crash/build evidence of a problem, but unverified without on-device testing.

Neither blocks the phase goal — D-01/D-02/D-03/D-04 are all satisfied in the code as written; these are follow-up polish/verification items.

### Human Verification Required

These are the plan's own `<verification>` section items (manual-only per this project's established convention — no automated harness exists for hover/grace-collapse/click-through/drag-and-drop behavior, consistent with Phases 2/6/9/20), plus one review-flagged item:

### 1. Cmd-U Test Pass Confirmation

**Test:** Run Cmd-U in Xcode.
**Expected:** All `ShelfViewStateTests` (including the new `testShouldBeginShelfItemDragGate`) and the unchanged `ShelfCoordinatorTests` pass green.
**Why human:** `xcodebuild test` hangs headlessly in this project (test target boots the full `Islet.app`, which starts `NSPanel`/MediaRemote/IOBluetooth) — documented project memory `xcodebuild-test-headless-hang`. `build-for-testing` (compilation-only) was run instead as the automated gate.

### 2. D-03 Early-Release Timing

**Test:** Slowly drag a shelf item toward the Desktop and drop it. Confirm the island stays open for the entire drag, then returns to normal hover/grace-collapse behavior promptly after the drop (within roughly the usual grace delay, not a 20s wait).
**Expected:** The `.leftMouseUp` `dragReleaseMonitor` fires and calls `endShelfItemDrag()` promptly — the island does not sit open for the full 20s safety-net duration on an ordinary drag.
**Why human:** Real-time pointer/drag-session timing feel cannot be verified via static code inspection; this is exactly the WR-01 regression risk area (pointer freshness during an OS drag session).

### 3. Success Criterion #1 — File Lands on Desktop, Item Stays in Shelf

**Test:** Drop a dragged shelf item on the Desktop.
**Expected:** The real file appears on the Desktop, and the item is STILL present in the shelf strip afterward (D-01 copy semantics).
**Why human:** Actual OS-level file materialization on drop is an integration behavior between `NSItemProvider`/Finder/the OS drag pipeline — not observable via grep or a headless build.

### 4. Success Criterion #2 — Missing Backing File Degrades Gracefully

**Test:** Externally delete a shelf item's backing temp file (lives under `$TMPDIR/IsletShelf/<uuid>/`), then attempt to drag that item.
**Expected:** No crash, nothing lands on Finder (a brief phantom drag-ghost that evaporates is acceptable per D-02, per IN-01's SwiftUI API-constraint note).
**Why human:** Requires manipulating the filesystem mid-interaction and observing on-screen drag-ghost behavior in real time.

### Gaps Summary

No code-level gaps. All must-have truths, artifacts, and key links are present, substantive, and wired; the WR-01 post-review fix is confirmed committed and present in the current code (not just claimed in SUMMARY.md); the build succeeds with the fix applied; D-01/D-04/CR-01 anti-regression checks all pass. The phase is blocked from a `passed` status only by the plan's own designated manual on-device verification items (4 items above), which is the expected/required path for this project's drag-and-hover-behavior class of features — not a defect.

---

_Verified: 2026-07-10T03:56:00Z_
_Verifier: Claude (gsd-verifier)_
