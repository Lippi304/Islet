---
phase: 20-shelf-view
plan: 01
subsystem: ui
tags: [swiftui, notch-view, shelf, island-resolver]

# Dependency graph
requires:
  - phase: 19-shelf-data-model
    provides: ShelfItem (Foundation-only value struct) consumed read-only
provides:
  - ShelfViewState — plain @Published mirror of ShelfCoordinator.logic.items (NowPlayingState ownership contract)
  - shouldOpenShelfItem(fileExists:) — pure D-04 missing-file gate
  - ShelfItemView — leaf shelf row item (icon + filename + scoped trash)
  - NotchPillView.shelfRowHeight (56pt) — single source of truth for the shelf row's height
  - blobShape(...) extended with shelfItems:, conditionally taller by shelfRowHeight
  - shelfRow(_:) — the horizontally-scrolling shelf strip composer, wired into expandedIsland/mediaExpanded/mediaUnavailable
  - SHELF-09 regression test proving the shelf-composing branches are structurally unreachable during a Charging/Device transient
affects: [20-02-notch-window-controller-wiring]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Plain @Published view-state mirror (no methods, controller-only writer) — same shape as NowPlayingState/BasicOutfitState/IslandPresentationState"
    - "Conditionally-taller blobShape: one continuous NotchShape whose height grows by a fixed row height only when optional content is non-empty, appended via one VStack under a single matchedGeometryEffect (no second shape, no cross-fade)"
    - "D-05 free collapse-on-tap: no gesture added to new content — the single ancestor .onTapGesture on the outer blob shape already covers any new empty space"

key-files:
  created:
    - Islet/Shelf/ShelfViewState.swift
    - Islet/Notch/ShelfItemView.swift
  modified:
    - Islet/Notch/NotchPillView.swift
    - Islet/Notch/NotchWindowController.swift (deviation — see below)
    - IsletTests/IslandResolverTests.swift

key-decisions:
  - "ShelfViewState has zero methods beyond the pure shouldOpenShelfItem gate — Plan 20-02's controller is the only writer to .items, mirroring NowPlayingState exactly"
  - "blobShape grows taller only when shelfItems is non-empty, uniformly passed by all 3 expanded-content callers (D-02) — no per-branch special-casing"
  - "No gesture attached to the shelfRow container itself; D-05 (tap-empty-space-to-collapse) falls out for free via blobShape's existing ancestor .onTapGesture"

patterns-established:
  - "Shelf row composition: blobShape(..., shelfItems:) { content } — content stays byte-for-byte unchanged in its own fixed-height box, shelf row appends below via VStack(spacing: 0)"

requirements-completed: [SHELF-03, SHELF-04, SHELF-05, SHELF-07, SHELF-09]

# Metrics
duration: ~7min
completed: 2026-07-09
---

# Phase 20 Plan 01: Shelf View Rendering Summary

**Shelf strip renders inside the expanded island (file-type icons, per-item trash, delete-all trash) as a conditionally-taller extension of the existing blobShape, with a regression test proving SHELF-09's transient-outranks-expanded gating needed zero new resolver code.**

## Performance

- **Duration:** ~7 min (build-verified wall time between first and last task commit)
- **Completed:** 2026-07-09
- **Tasks:** 3/3 completed
- **Files modified:** 5 (2 created, 3 modified)

## Accomplishments

- `ShelfViewState` (published mirror) and `ShelfItemView` (leaf row item: icon + truncated filename + scoped trash) created and compiling
- `NotchPillView.blobShape` extended so the island grows taller by exactly `shelfRowHeight` (56pt) only when the shelf has items — uniformly across `expandedIsland`/`mediaExpanded`/`mediaUnavailable`, with no per-branch special-casing (D-02)
- `shelfRow(_:)` renders a horizontally-scrolling strip with per-item trash + one far-right delete-all trash icon; D-05 (tap-empty-space collapses) falls out for free from the existing ancestor `.onTapGesture`
- New `testShelfComposingBranchesUnreachableDuringTransient` proves SHELF-09's "falls out for free" claim: a standing Charging/Device transient always outranks `isExpanded`, so the shelf-composing branches are structurally unreachable during a splash — zero new production code in `IslandResolver.swift`
- `xcodebuild build`/`build-for-testing` succeeded after every task

## Task Commits

1. **Task 1: ShelfViewState + ShelfItemView** - `51c40ce` (feat) + `c244859` (chore: Xcode project regeneration)
2. **Task 2: Extend NotchPillView — shelfRowHeight, shelf-aware blobShape, shelfRow, wire 3 callers + 8 #Previews** - `011d118` (feat)
3. **Task 3: SHELF-09 regression test** - `e4907ed` (test)

_Note: no TDD tasks in this plan; each task is a single commit (Task 1 has an additional Xcode-project-regeneration commit for the new file references)._

## Files Created/Modified

- `Islet/Shelf/ShelfViewState.swift` - Plain `@Published var items: [ShelfItem]` holder + top-level `shouldOpenShelfItem(fileExists:)` pure gate
- `Islet/Notch/ShelfItemView.swift` - Leaf view: 28×28 `NSWorkspace.shared.icon(forFile:)` + truncated filename caption + scoped `.overlay` trash `Button`
- `Islet/Notch/NotchPillView.swift` - `shelfRowHeight` constant, `shelfViewState`/3 shelf closures, `blobShape` extended with `shelfItems:`, new `shelfRow(_:)`, 3 callers wired, 8 `#Preview`s updated
- `Islet/Notch/NotchWindowController.swift` - minimal `shelfViewState` stored property + `makeRootView` wiring (deviation, see below)
- `IsletTests/IslandResolverTests.swift` - `testShelfComposingBranchesUnreachableDuringTransient`

## Decisions Made

- `ShelfViewState` deliberately carries zero mutating methods — matches `NowPlayingState`'s "controller is the only writer" contract exactly, so Plan 20-02's `NotchWindowController` is the sole place that ever assigns `.items`.
- All 3 expanded-content branches pass the identical `shelfViewState.items` into `blobShape` (D-02) rather than each branch deciding independently whether to show a shelf — keeps the "no branch special-cased" invariant literally true in the diff.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Wired a placeholder `shelfViewState` into `NotchWindowController.makeRootView`**
- **Found during:** Task 2 (Extend NotchPillView)
- **Issue:** The plan's Task 1/2 instructions specify `shelfViewState: ShelfViewState` as a non-defaulted `NotchPillView` property (mirroring `nowPlaying`/`presentationState`/`outfit`'s "always owns and injects a real instance" convention). This is correct per the plan, but it also means `NotchWindowController.makeRootView` — an existing, live call site of `NotchPillView.init` outside this plan's declared `files_modified` — no longer compiles (missing argument). The plan explicitly scopes the *real* `ShelfCoordinator` wiring to Plan 20-02 ("`NotchWindowController` wiring ... is Plan 20-02's job"), so a full fix was out of scope here, but the mandatory build gate (`xcodebuild build … | grep BUILD SUCCEEDED`) after every task requires the whole target to compile now.
- **Fix:** Added `private let shelfViewState = ShelfViewState()` as a stored property on `NotchWindowController`, following the exact same pattern as the adjacent `presentationState`/`outfitState` properties, and passed `shelfViewState: shelfViewState` into the existing `makeRootView` call. This is an empty, unwired placeholder — no `ShelfCoordinator`, no D-04 missing-file guard, no panel-height reservation, no hand-seeding. Plan 20-02 replaces/extends this property with real `ShelfCoordinator`-driven mutations exactly as originally scoped.
- **Files modified:** `Islet/Notch/NotchWindowController.swift`
- **Verification:** `xcodebuild build -scheme Islet -configuration Debug` → `BUILD SUCCEEDED`
- **Committed in:** `011d118` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** No scope creep — the placeholder holds zero shelf-mutation logic; Plan 20-02 proceeds exactly as originally scoped (own the real `ShelfCoordinator`, add the D-04 guard, panel-height reservation, hand-seeding) against this same property.

## Known Stubs

- `NotchWindowController.shelfViewState` is a permanently-empty `ShelfViewState()` until Plan 20-02 wires a real `ShelfCoordinator` to mutate it — by design (see Deviations above), not a gap in this plan's own scope. The shelf row therefore never renders in the running app yet (`items` is always `[]`); `#Preview`s exercise the rendering logic directly with hand-seeded `ShelfViewState` instances (not added in this plan — no preview seeds non-empty items, since Task 2's acceptance criteria only requires the 8 existing previews to keep compiling).

## Issues Encountered

None beyond the deviation above.

## Next Phase Readiness

- `NotchPillView.shelfRowHeight` (56pt) is the single source of truth Plan 20-02's panel-sizing math must read from — do not re-derive.
- Plan 20-02 replaces `NotchWindowController.shelfViewState`'s placeholder wiring with a real `ShelfCoordinator`, the D-04 missing-file guard (`shouldOpenShelfItem`), panel-height reservation, and hand-seeding.

## Self-Check: PASSED

All 5 modified/created files confirmed present on disk; all 4 task commit hashes (51c40ce, c244859, 011d118, e4907ed) confirmed in git log.
