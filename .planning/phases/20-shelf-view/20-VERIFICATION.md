---
phase: 20-shelf-view
verified: 2026-07-10T01:44:00Z
status: human_needed
score: 6/6 must-haves verified
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 5/6
  gaps_closed:
    - "The panel-sizing math introduced to reserve shelf space does not regress the documented click-through invariant when the shelf is empty"
  gaps_remaining: []
  regressions: []
deferred: []
human_verification:
  - test: "On-device: expand the island with the shelf empty (default Release state) and click/drag an item in the app or window directly beneath the notch, in the reserved-but-invisible band ~144-200pt down from the notch"
    expected: "Per Pitfall 3/D-07, the click passes through to the app underneath — visibleContentZone() no longer includes this band when shelfViewState.items is empty, and pointerInZone can no longer OR-defeat that scoping while expanded"
    why_human: "Requires a running app instance and physical click testing on notch hardware; the code path is unambiguous from the two-round CR-01 fix trace but the actual NSPanel/AppKit hit-testing behavior at runtime is outside static analysis"
  - test: "On-device with DEBUG hand-seed: expand island with items, hover down toward the transport controls, then move further down into the shelf row/trash icons — confirm both the transport controls and the shelf row remain fully clickable (visibleContentZone() must not over-narrow when the shelf is non-empty)"
    expected: "All visible content (transport controls + shelf row + per-item/delete-all trash icons) stays interactive throughout"
    why_human: "Dynamic pointer-tracking behavior across zone boundaries; cannot be confirmed by static analysis alone"
  - test: "On-device with DEBUG hand-seed: delete a shelf item / clear-all, observe the shelf row's fade and the island's height change"
    expected: "The shelf row fades and the blob height change animate with the controller's standard spring (WR-01 fix via resyncShelfViewState), no instant snap, and no clipping/snap of the shrinking blob against the statically-sized panel"
    why_human: "Visual smoothness/feel judgment, not a hard functional break"
  - test: "Cmd-U in Xcode: run IslandResolverTests and ShelfViewStateTests (full suite, incl. any new assertions touching this phase)"
    expected: "All tests pass"
    why_human: "xcodebuild test cannot run headlessly in this environment per documented project memory (xcodebuild-test-headless-hang) — hosts full Islet.app with NSPanel/MediaRemote/IOBluetooth boot"
---

# Phase 20: Shelf View Verification Report

**Phase Goal:** With hand-seeded shelf state, the expanded island renders a full shelf strip — icons, per-item and delete-all removal, click-to-open, and correct gating alongside Charging/Device splashes — proving the view and panel-sizing math before any live drag risk is introduced.
**Verified:** 2026-07-10T01:44:00Z
**Status:** human_needed
**Re-verification:** Yes — after gap closure (20-03-PLAN.md / 20-03-SUMMARY.md, commits 09dc463, d5346e5, 8e3fa64, 0a52803)

## Goal Achievement

### Re-verification Summary

The prior verification (2026-07-10T00:50:00Z) failed Truth 6 (CR-01): `positionAndShow` unconditionally reserved 56pt of panel height for the shelf row, and `syncClickThrough()` made the ENTIRE panel rect interactive whenever expanded — creating a permanent invisible click-swallowing band under the expanded island whenever the shelf was empty (the default Release state).

Gap-closure plan 20-03 was executed in two corrective rounds:

1. **Round 1 (commits `09dc463`, `d5346e5`):** Added `visibleContentZone()` — a narrower rect mirroring `NotchPillView.blobShape`'s own `hasShelf ? shelfRowHeight : 0` conditional — and rewrote `syncClickThrough()` to gate expanded-state interactivity on it. Also extracted `resyncShelfViewState(animated:)` to fix WR-01 (unanimated shelf mutations) and WR-02 (triplicated resync line).
2. **Adversarial code review of round 1** found the fix incomplete: the expanded branch read `pointerInZone || (visibleContentZone()?.contains(lastPointerLocation) ?? false)`. Because `pointerInZone` tracks the broad `expandedZone` (the padded panel-union keep-open region) and stays `true` for the entire natural hover→expand→move-toward-app-underneath path, the OR let the broad flag defeat the narrow scoping for virtually the whole real-world interaction — CR-01 remained open in practice despite the new helper existing.
3. **Round 2 fix (commit `8e3fa64`):** Removed `pointerInZone` from the expanded branch entirely. Confirmed by direct read of the current code (`NotchWindowController.swift:760-774`): the expanded branch is now `interactive = visibleContentZone()?.contains(lastPointerLocation) ?? false` with no OR-fallback. Only the narrow, item-count-conditional zone can grant interactivity while expanded.
4. **Doc-comment cleanup (commit `0a52803`):** Fixed a stale comment that still described the old OR semantics.

I independently re-read the current file (not the SUMMARY's narrative) and confirm the code matches this account exactly — see Truth 6 below.

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Shelf strip appears below expanded content whenever it has items, showing file-type icons, scrolling horizontally with unbounded capacity, uniformly across Now Playing / idle glance / unavailable | VERIFIED (regression check) | `NotchPillView.swift` untouched by any 20-03 commit (`git show --stat` on 09dc463/d5346e5/8e3fa64/0a52803 shows only `NotchWindowController.swift` modified); `blobShape` (L261-286), `shelfRow` (L292-312) unchanged from prior verification |
| 2 | Each shelf item has its own small trash icon; clicking it removes just that item, with real disk deletion | VERIFIED (regression check) | `ShelfItemView.swift` untouched by 20-03; `handleShelfItemDelete` (L1232-1235) still calls `shelfCoordinator.remove(id:)` then now `resyncShelfViewState()` (previously a direct assignment) — functionally identical resync, now also animated and click-through-refreshed |
| 3 | A single delete-all trash icon at the strip's far right clears every item instantly, no confirmation dialog | VERIFIED (regression check) | `handleShelfClearAll` (L1239-1242) calls `shelfCoordinator.clear()` then `resyncShelfViewState()`; no alert/sheet/dialog introduced |
| 4 | Clicking a shelf item opens it in its default app; a vanished local copy is a silent no-op (D-04) | VERIFIED (regression check) | `handleShelfItemTap` (L1206-1209) unchanged by 20-03; guard-before-side-effect intact |
| 5 | Shelf strip is hidden during a Charging or Device splash, reappears once the splash dismisses | VERIFIED (regression check) | `IslandResolverTests.testShelfComposingBranchesUnreachableDuringTransient` present and unmodified (L45); resolver code untouched by 20-03 |
| 6 | The panel-sizing math introduced to reserve shelf space does not regress the documented click-through invariant when the shelf is empty | **VERIFIED** | `positionAndShow` (L591-657) still unconditionally reserves `expandedSize.height + NotchPillView.shelfRowHeight` (confirmed intentional/permanent per the updated doc comment, L611-621) — but `syncClickThrough()` (L760-774) now reads, while expanded: `interactive = visibleContentZone()?.contains(lastPointerLocation) ?? false` — no `pointerInZone` OR-fallback anywhere in that branch. `visibleContentZone()` (L699-707) computes `let shelfHeight = shelfViewState.items.isEmpty ? 0 : NotchPillView.shelfRowHeight`, mirroring `NotchPillView.blobShape`'s `hasShelf` conditional exactly. `handlePointer(at:)` (L661-692) stores `lastPointerLocation` on every tick and calls `syncClickThrough()` whenever expanded, so the hit-test is live, not just recomputed at zone-crossing edges. Traced the exact repro scenario from the prior gap (hover→expand→move down toward the app underneath with an empty shelf): pointer enters `expandedZone` → `pointerInZone = true` → but since the expanded branch no longer consults `pointerInZone` at all, `interactive` depends solely on whether the pointer is still inside the 144pt-tall `visibleContentZone()` (shelfHeight=0 when empty) — once the pointer crosses below that boundary, `interactive` becomes `false` and `panel.ignoresMouseEvents = true`, so the click passes through. CR-01 is closed at the code level. |

**Score:** 6/6 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `Islet/Shelf/ShelfViewState.swift` | `ShelfViewState` published mirror + `shouldOpenShelfItem` gate | VERIFIED (unchanged) | Not touched by 20-03 |
| `Islet/Notch/ShelfItemView.swift` | Leaf row: icon + filename + scoped trash | VERIFIED (unchanged) | Not touched by 20-03 |
| `Islet/Notch/NotchPillView.swift` | `shelfRowHeight`, shelf-aware `blobShape`, `shelfRow(_:)` | VERIFIED (unchanged) | Not touched by 20-03; `shelfRowHeight` constant read by the new `visibleContentZone()` as the single source of truth |
| `Islet/Notch/NotchWindowController.swift` | `visibleContentZone()`, corrected `syncClickThrough()`, `resyncShelfViewState(animated:)` | VERIFIED | `visibleContentZone()` (L699-707) exists exactly once; `syncClickThrough()` (L760-774) branches on `interaction.isExpanded` and consults only `visibleContentZone()?.contains(lastPointerLocation)` when expanded (no OR with `pointerInZone`); `resyncShelfViewState(animated:)` (L1218-1228) is the single resync call site used by `handleShelfItemDelete`, `handleShelfClearAll`, and `seedDebugShelfItems` |
| `IsletTests/IslandResolverTests.swift` | SHELF-09 regression test | VERIFIED (unchanged) | Not touched by 20-03 |
| `IsletTests/ShelfViewStateTests.swift` | Resync contract + D-04 gate coverage | VERIFIED (unchanged) | Not touched by 20-03 |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| `NotchWindowController.syncClickThrough` | `shelfViewState.items.isEmpty` | `visibleContentZone()`'s `shelfHeight` computation | WIRED | Confirmed at L702: `let shelfHeight = shelfViewState.items.isEmpty ? 0 : NotchPillView.shelfRowHeight` — matches `NotchPillView.blobShape`'s `hasShelf` conditional exactly |
| `handleShelfItemDelete` / `handleShelfClearAll` / `seedDebugShelfItems` | `syncClickThrough()` | `resyncShelfViewState(animated:)` | WIRED | Confirmed at L1218-1228: `resyncShelfViewState` calls `syncClickThrough()` unconditionally after the (animated or direct) assignment — the hit-test re-evaluates the new item count immediately, without waiting for the next pointer tick |
| `handlePointer(at:)` | `syncClickThrough()` | direct call while expanded, plus `lastPointerLocation` store | WIRED | Confirmed at L664 (`lastPointerLocation = point`, first line) and L689-691 (`if interaction.isExpanded { syncClickThrough() }`, after the existing enter/exit edge detection) |
| `NotchWindowController.positionAndShow` | `NotchPillView.shelfRowHeight` | `expandedFrame` height addition (unconditional, by design) | WIRED (intentional, documented as permanent) | Confirmed unchanged at L622-624; doc comment (L611-621) now explicitly states this is intentional/permanent and points readers to `visibleContentZone()`/`syncClickThrough()` for the actual click-through fix — resolves the prior verification's confusion about whether this needed to become conditional |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|---------------------|--------|
| `syncClickThrough()` | `shelfViewState.items.isEmpty` (via `visibleContentZone()`) | `shelfCoordinator.logic.items` synced through `resyncShelfViewState` on every real mutation (delete/clear/debug-seed) | Yes — reads live `@Published` state, not a static/hardcoded value | FLOWING |
| `handlePointer(at:)` | `lastPointerLocation` | Raw global `.mouseMoved` event coordinates, stored every tick | Yes | FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Debug build compiles with the CR-01 fix + resync helper | `xcodegen generate && xcodebuild -project Islet.xcodeproj -scheme Islet -configuration Debug build` | `** BUILD SUCCEEDED **` | PASS |
| `syncClickThrough()` contains no `pointerInZone` reference in the expanded branch | `grep -n` on the current function body (L760-774) | Confirmed: expanded branch is `visibleContentZone()?.contains(lastPointerLocation) ?? false` only; `pointerInZone` appears solely in the collapsed `else` branch | PASS |
| Actual test run (pass/fail of assertions) | `xcodebuild test` | not run — hangs headlessly per project memory (hosts full `Islet.app` w/ NSPanel/MediaRemote/IOBluetooth) | SKIP — routed to human verification (Cmd-U) |

### Requirements Coverage

No change from prior verification — SHELF-03/04/05/07/09 remain SATISFIED (see prior report body); this re-verification only re-confirms none of that evidence regressed. `.planning/REQUIREMENTS.md` now shows local uncommitted edits in the working tree (outside the scope of this code-level re-verification); recommend confirming those reflect Complete status for SHELF-03/04/05/07/09 before the next phase.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| — | — | No TBD/FIXME/XXX/TODO/HACK/PLACEHOLDER markers found in `NotchWindowController.swift` | — | Clean |

The two prior non-blocking Warnings (WR-01 unanimated mutation, WR-02 triplicated resync) were fixed by this same gap-closure plan as a side effect (`resyncShelfViewState(animated:)`) and are no longer present. The prior review's stale doc-comment issue was fixed in commit `0a52803`. Remaining known gap (non-blocking, explicitly accepted by the two-round adversarial review): no automated test coverage exists for `syncClickThrough()`/`visibleContentZone()`'s hit-test logic itself — `IslandResolverTests`/`ShelfViewStateTests` do not exercise this AppKit-level pointer/zone code. This is a coverage gap, not a functional one; flagged as `ℹ️ Info`, not a blocker, since the logic was verified by direct code trace across two adversarial review rounds.

### Human Verification Required

See frontmatter `human_verification` — 4 items: on-device empty-shelf click-through confirmation (the core CR-01 repro), on-device non-empty-shelf interactivity confirmation (regression guard against over-narrowing), on-device animation-smoothness confirmation of the WR-01 fix, and Cmd-U confirmation of the full test suite's actual pass/fail (build-for-testing only confirms compilation, not assertion outcomes — this project's `xcodebuild test` hangs headlessly per documented project memory and must be run manually via Cmd-U in Xcode).

### Gaps Summary

No code-level gaps remain. Truth 6 (CR-01) — the only failing truth in the prior verification — is now VERIFIED: `syncClickThrough()`'s expanded-state interactivity decision depends solely on `visibleContentZone()`, which is itself conditioned on `shelfViewState.items.isEmpty` and mirrors `NotchPillView.blobShape`'s own visible-height conditional. The `pointerInZone` OR-defeat that survived round 1 of the gap-closure plan (and would have left the natural hover→expand→move-down path still swallowing clicks in practice) was found and removed in round 2 (commit `8e3fa64`). No live panel resize was introduced in the process — `positionAndShow`'s static max-reservation sizing is untouched, so the animation-race hazard the plan checker flagged in an earlier plan revision was correctly avoided. The build succeeds. All 5 truths from the original verification were re-checked and remain intact — none of the 20-03 commits touched any file outside `NotchWindowController.swift`.

Status is `human_needed` rather than `passed` solely because the on-device click-through repro and the Cmd-U test run — both explicitly called out as requiring physical interaction / an environment where `xcodebuild test` doesn't hang — remain outside what static code analysis can confirm. This is the same category of human-verification item present in the original (passing) truths 1-5 all along; it does not indicate any remaining code defect.

---

_Verified: 2026-07-10T01:44:00Z_
_Verifier: Claude (gsd-verifier)_
