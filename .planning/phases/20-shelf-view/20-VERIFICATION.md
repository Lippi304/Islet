---
phase: 20-shelf-view
verified: 2026-07-10T00:50:00Z
status: gaps_found
score: 5/6 must-haves verified
overrides_applied: 0
gaps:
  - truth: "The panel-sizing math introduced by this phase does not regress the documented click-through invariant (clicks outside the visible pill always pass through) when the shelf is empty"
    status: failed
    reason: >
      NotchWindowController.positionAndShow (lines 613-615) unconditionally adds
      NotchPillView.shelfRowHeight (56pt) to the expanded panel frame regardless of whether
      shelfViewState.items is empty. syncClickThrough() (lines 719-722) sets
      panel.ignoresMouseEvents = false for the ENTIRE panel rectangle whenever
      interaction.isExpanded is true, not just the pixels the visible blobShape actually
      occupies. NotchPillView.blobShape correctly only grows the VISIBLE black shape
      conditionally on !shelfItems.isEmpty (line 267), but the panel/hit-region sizing was
      never conditioned to match. Result: every time a user expands the island, a permanent
      invisible 56pt-tall band beneath the visible content swallows clicks intended for
      whatever is underneath it -- even when the shelf has zero items, which is the ONLY
      possible state in a Release build today (the DEBUG hand-seed that populates the shelf
      is compiled out of Release; Phase 22's real drag-in has not shipped). This directly
      contradicts the class's own documented invariant (Pitfall 3 / D-07, in
      syncClickThrough's own doc comment) and is squarely inside this phase's own stated
      goal ("proving the view AND PANEL-SIZING MATH before any live drag risk is
      introduced") -- the panel-sizing math has not been proven correct, it has been shown
      to regress a core interaction guarantee for every real user.
    artifacts:
      - path: "Islet/Notch/NotchWindowController.swift"
        issue: "positionAndShow (~613-615) reserves shelfRowHeight unconditionally; syncClickThrough (~719-722) applies ignoresMouseEvents=false to the full panel rect on any expand, not scoped to the visible blob height"
    missing:
      - "Condition the panel height reservation (or the click-through hit-test) on shelfViewState.items.isEmpty so an empty shelf never grows the interactive/click-swallowing region beyond the visible 144pt-tall blob"
      - "Re-run positionAndShow (or otherwise update the reserved frame) whenever the shelf transitions between empty and non-empty, since the reservation can no longer be a static one-time computation once it depends on item count"
deferred: []
human_verification:
  - test: "On-device: expand the island with the shelf empty (default Release state) and click/drag an item in the app or window directly beneath the notch, in the invisible band ~144-200pt down from the notch"
    expected: "Per Pitfall 3/D-07, the click should pass through to the app underneath since no visible content occupies that band"
    why_human: "Requires a running app instance and physical click testing on notch hardware; cannot be confirmed by static analysis alone (though the code path is unambiguous from CR-01)"
  - test: "On-device with DEBUG hand-seed: expand island, observe the shelf row's appear/resize transition when deleting an item or clicking delete-all"
    expected: "Per WR-01 (code review), the shelf row fade / island resize will SNAP instantly rather than animate with the app's spring, since handleShelfItemDelete/handleShelfClearAll do not wrap the shelfViewState.items mutation in withAnimation"
    why_human: "Visual smoothness/feel judgment, not a hard functional break; flagged for awareness alongside CR-01"
  - test: "Cmd-U in Xcode: run IslandResolverTests (incl. testShelfComposingBranchesUnreachableDuringTransient) and ShelfViewStateTests"
    expected: "All tests pass, per project memory (xcodebuild test hangs headlessly hosting the full Islet.app; build-for-testing is the automated gate, Cmd-U is the manual pass confirmation)"
    why_human: "xcodebuild test cannot run headlessly in this environment per documented project memory (xcodebuild-test-headless-hang)"
---

# Phase 20: Shelf View Verification Report

**Phase Goal:** With hand-seeded shelf state, the expanded island renders a full shelf strip — icons, per-item and delete-all removal, click-to-open, and correct gating alongside Charging/Device splashes — proving the view and panel-sizing math before any live drag risk is introduced.
**Verified:** 2026-07-10T00:50:00Z
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Shelf strip appears below expanded content whenever it has items, showing file-type icons, scrolling horizontally with unbounded capacity, uniformly across Now Playing / idle glance / unavailable | VERIFIED | `NotchPillView.blobShape` (lines 261-286) conditionally grows height by `shelfRowHeight` only when `!shelfItems.isEmpty`; `shelfRow(_:)` (292-312) uses `ScrollView(.horizontal)` + `ForEach` (unbounded); all 3 expanded-content callers (`expandedIsland` L227, `mediaExpanded` L641, `mediaUnavailable` L706) pass the identical `shelfItems: shelfViewState.items` — no per-branch special-casing |
| 2 | Each shelf item has its own small trash icon; clicking it removes just that item, with real disk deletion | VERIFIED | `ShelfItemView` (ShelfItemView.swift) renders a scoped `.overlay` `Button(action: onDelete)`, sibling to (not nested in) the item's own `.onTapGesture`; `NotchWindowController.handleShelfItemDelete` (L1161-1164) calls the locked Phase-19 `ShelfCoordinator.remove(id:)` (real session-temp file deletion via `ShelfFileStore`) then resyncs `shelfViewState.items` |
| 3 | A single delete-all trash icon at the strip's far right clears every item instantly, no confirmation dialog | VERIFIED | `shelfRow(_:)` appends one far-right `Button(action: onShelfClearAll)` (L300-306) after the `ForEach`; `handleShelfClearAll` (L1168-1171) calls `ShelfCoordinator.clear()` directly — no alert/sheet/dialog present anywhere in the call chain |
| 4 | Clicking a shelf item opens it in its default app; a vanished local copy is a silent no-op (D-04) | VERIFIED | `handleShelfItemTap` (L1154-1157): `guard shouldOpenShelfItem(fileExists: FileManager.default.fileExists(atPath: item.localURL.path)) else { return }` precedes `NSWorkspace.shared.open(item.localURL)` textually — guard-before-side-effect confirmed; `shouldOpenShelfItem` is a pure 1-line function (`ShelfViewState.swift` L14) covered by `ShelfViewStateTests.testShouldOpenShelfItemGate` |
| 5 | Shelf strip is hidden during a Charging or Device splash, reappears once the splash dismisses | VERIFIED | Structural: `wings(for:)`/`deviceWings(for:)`/`mediaWingsOrToast` never call `blobShape`/`shelfRow` (confirmed unchanged by this phase); `IslandResolverTests.testShelfComposingBranchesUnreachableDuringTransient` proves a standing Charging/Device transient always outranks `isExpanded` in `IslandResolver.resolve`, so the shelf-composing branches are unreachable during a splash with zero new resolver production code |
| 6 | The panel-sizing math introduced to reserve shelf space does not regress the documented click-through invariant when the shelf is empty | **FAILED** | See gap below — code review finding CR-01, confirmed by direct code read: `positionAndShow` (NotchWindowController.swift L613-615) unconditionally reserves 56pt regardless of item count; `syncClickThrough` (L719-722) makes the FULL panel rect interactive whenever expanded, not just the visible blob — a permanent invisible click-swallowing band exists under the expanded island in the shelf's default (empty) state |

**Score:** 5/6 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `Islet/Shelf/ShelfViewState.swift` | `ShelfViewState` published mirror + `shouldOpenShelfItem` gate | VERIFIED | Exactly one `@Published var items`, no other stored property/method; top-level pure gate function present |
| `Islet/Notch/ShelfItemView.swift` | Leaf row: icon + filename + scoped trash | VERIFIED | `NSWorkspace.shared.icon(forFile:)`, `.lineLimit(1)` + `.truncationMode(.middle)`, trash `Button` in `.overlay`, never nested in the tap-gesture chain |
| `Islet/Notch/NotchPillView.swift` | `shelfRowHeight`, shelf-aware `blobShape`, `shelfRow(_:)`, 3 callers wired, 8 previews updated | VERIFIED | All confirmed by grep + direct read; `static let shelfRowHeight: CGFloat = 56` present exactly once |
| `Islet/Notch/NotchWindowController.swift` | `shelfCoordinator`/`shelfViewState` ownership, 3 handlers, panel-sizing extension, DEBUG hand-seed | VERIFIED (wiring) / **FAILED (panel-sizing side effect)** | Ownership, handler wiring, and DEBUG seed all present and correct; the panel-sizing extension itself introduces the CR-01 regression (see Truth 6) |
| `IsletTests/IslandResolverTests.swift` | SHELF-09 regression test | VERIFIED | `testShelfComposingBranchesUnreachableDuringTransient` present, asserts against both charging and device transients with `isExpanded: true` |
| `IsletTests/ShelfViewStateTests.swift` | Resync contract + D-04 gate coverage | VERIFIED | `ShelfViewStateTests: XCTestCase` with `testAppendThenResyncReflectsInViewState`, `testRemoveThenResyncReflectsInViewState`, `testClearThenResyncReflectsInViewState`, `testShouldOpenShelfItemGate` all present |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| `expandedIsland`/`mediaExpanded`/`mediaUnavailable` | `NotchPillView.shelfRow(_:)` | `blobShape`'s conditional `VStack` | WIRED | All 3 callers confirmed passing `shelfItems: shelfViewState.items`; `shelfRow` appended below content inside the same `VStack`/`NotchShape` |
| `NotchPillView.shelfRow` | `ShelfItemView` | `ForEach(items, id: \.id)` | WIRED | Confirmed at NotchPillView.swift L295-299 |
| `NotchWindowController.handleShelfItemDelete`/`handleShelfClearAll` | `ShelfCoordinator.remove`/`clear` | direct call + resync | WIRED | Confirmed at L1161-1171; resync line present in both |
| `NotchWindowController.positionAndShow` | `NotchPillView.shelfRowHeight` | `expandedFrame` height addition | WIRED but **UNCONDITIONAL** | Confirmed at L613-615 — wired correctly as a single-source-of-truth constant read, but the unconditional application is the root of the CR-01 gap |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Debug build compiles with full shelf wiring | `xcodebuild build -scheme Islet -configuration Debug` | `** BUILD SUCCEEDED **` | PASS |
| Test target compiles (incl. new shelf tests) | `xcodebuild build-for-testing -scheme Islet -configuration Debug` | `** TEST BUILD SUCCEEDED **` | PASS |
| Actual test run (pass/fail of assertions) | `xcodebuild test` | not run — hangs headlessly per project memory (hosts full `Islet.app` w/ NSPanel/MediaRemote/IOBluetooth) | SKIP — routed to human verification (Cmd-U) |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| SHELF-03 | 20-01 | Shelf strip appended below expanded content whenever it has content, scrolls horizontally, unbounded capacity | SATISFIED | `blobShape`/`shelfRow` — see Truth 1 |
| SHELF-04 | 20-01, 20-02 | Each shelf item shows file-type icon + own small trash icon for individual removal | SATISFIED | `ShelfItemView` + `handleShelfItemDelete` — see Truth 2 |
| SHELF-05 | 20-02 | Single delete-all trash icon clears entire shelf at once | SATISFIED | `shelfRow`'s far-right `Button` + `handleShelfClearAll` — see Truth 3 |
| SHELF-07 | 20-02 | Clicking a shelf item opens it in its default application | SATISFIED | `handleShelfItemTap` + `shouldOpenShelfItem` guard — see Truth 4 |
| SHELF-09 | 20-01 | Shelf suppressed while Charging/Device splash actively showing, reappears once dismissed | SATISFIED | Structural resolver precedence + regression test — see Truth 5 |

Note: `.planning/REQUIREMENTS.md` still marks all 5 of these IDs as `Pending`/unchecked (lines 14-20, 55-61) despite the implementation evidence above — this is a documentation-sync gap (the checkboxes were not updated as part of phase completion), not a code gap. Recommend updating REQUIREMENTS.md's checkboxes/status column to Complete for SHELF-03/04/05/07/09 now that this verification confirms the underlying code.

No orphaned requirements found — REQUIREMENTS.md maps exactly SHELF-03/04/05/07/09 to Phase 20, matching both plans' `requirements:` frontmatter combined.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `Islet/Notch/NotchWindowController.swift` | 613-615, 719-722 | Unconditional panel-height reservation + full-panel-rect click-through toggle | 🛑 Blocker | CR-01 — permanent invisible click-swallowing band under the expanded island whenever the shelf is empty (the only state possible in Release today) |
| `Islet/Notch/NotchWindowController.swift` | 1161-1171 | Shelf mutations (`handleShelfItemDelete`/`handleShelfClearAll`) not wrapped in `withAnimation`, unlike every other `@Published` mutation in this controller | ⚠️ Warning | Shelf row's `.transition(.opacity)` and the blob's height change will snap instantly rather than animate — inconsistent with the rest of the app's spring-driven feel (WR-01 in code review) |
| `Islet/Notch/NotchWindowController.swift` | 1163, 1170, 1194 | `shelfViewState.items = shelfCoordinator.logic.items` duplicated verbatim across 3 handlers | ℹ️ Info | Maintainability only — no functional impact today (WR-02 in code review) |
| `Islet/Notch/ShelfItemView.swift` | 14-16 | `.resizable()` + fixed `.frame` with no `.aspectRatio` | ℹ️ Info | Could distort a non-square icon; low risk (IN-01 in code review) |

No TBD/FIXME/XXX debt markers found in any file modified by this phase.

### Human Verification Required

See frontmatter `human_verification` section — 3 items: on-device click-through confirmation of CR-01, on-device animation-smoothness confirmation of WR-01, and Cmd-U confirmation of the 2 new/extended test files' actual pass/fail (build-for-testing only confirms compilation, not assertion outcomes).

### Gaps Summary

The view layer (Plan 20-01) and the interaction wiring (Plan 20-02, minus panel-sizing) are solid: every SUMMARY.md claim about rendering, per-item/delete-all removal, click-to-open with the D-04 guard, and SHELF-09's structural gating checks out against the actual code, with no stubs, no unwired closures, and a passing build/test-build gate.

The one blocking gap is real and was flagged in the phase's own code review (CR-01, `20-REVIEW.md`) but was not fixed before this phase was marked complete: the panel-sizing change this phase introduced to avoid a live NSPanel resize does so by unconditionally reserving 56pt of interactive space, and the click-through toggle (`syncClickThrough`) does not distinguish "the visible blob's actual footprint" from "the full reserved panel rect." Since the shelf is empty by default in every Release build today (the DEBUG hand-seed that would exercise a non-empty shelf is compiled out of Release, and Phase 22's real drag-in hasn't shipped), this is not a rare edge case — it is the app's current permanent behavior for every user who ever expands the island: an invisible 56pt band beneath the visible content swallows clicks meant for whatever sits underneath. This directly contradicts the controller's own documented invariant (Pitfall 3/D-07: "clicks OUTSIDE the pill always pass through") and falls squarely within this phase's own goal text ("proving the view and panel-sizing math before any live drag risk is introduced") — the panel-sizing math has been shown to regress a core interaction guarantee, not proven correct.

Recommend closing this gap (condition the reservation/hit-test on `shelfViewState.items.isEmpty`, or hit-test against the actual visible blob rect) before proceeding to Phase 21/22, since both later phases build directly on this same panel-sizing foundation and would inherit the regression.

---

_Verified: 2026-07-10T00:50:00Z_
_Verifier: Claude (gsd-verifier)_
