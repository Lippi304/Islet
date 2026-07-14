---
phase: 31-shelf-consolidation-to-tray-only
reviewed: 2026-07-14T02:48:33Z
depth: standard
files_reviewed: 3
files_reviewed_list:
  - IsletTests/NotchPillViewTests.swift
  - Islet/Notch/NotchPillView.swift
  - Islet.xcodeproj/project.pbxproj
findings:
  critical: 1
  warning: 0
  info: 2
  total: 3
status: issues_found
---

# Phase 31: Code Review Report

**Reviewed:** 2026-07-14T02:48:33Z
**Depth:** standard
**Files Reviewed:** 3
**Status:** issues_found

## Summary

This phase's actual code delta (the `diff_base` supplied in config resolves to an orphaned
checkpoint commit with no parent, so scope was determined instead from the real phase-31 commit,
`ce6417d "test(31-01): lock shelfStripVisible=false with a regression test"`) is small and
low-risk: `NotchPillView.shelfStripVisible` was bumped from `private` to `internal` so a new
test file can assert it directly, and `IsletTests/NotchPillViewTests.swift` was added along with
its `project.pbxproj` registration.

The access-modifier change and the pbxproj registration are both mechanically correct (new file
is registered under the `IsletTests` target's own `Sources` build phase, group placement is
alphabetically consistent, `PBXBuildFile`/`PBXFileReference` UUIDs are unique and properly wired).

The one real problem is the new test itself: it does not actually exercise the regression it
claims to guard against, because it constructs an empty `ShelfViewState`. Since `shelfStripVisible`
is a hard-coded `{ false }` literal that no longer reads any state at all, the intended regression
— someone reverting the getter to read `shelfViewState.isVisible` again — would still pass this
test, because `ShelfViewState().isVisible` (`!items.isEmpty`) is *also* `false` for an empty shelf.
The test only proves the literal is currently `false`; it does not prove the Tray-only gating
behavior it is named for.

## Critical Issues

### CR-01: Regression test does not actually cover the regression it claims to lock down

**File:** `IsletTests/NotchPillViewTests.swift:14-29`
**Issue:**
The test's docstring and assertion message both claim this test "locks TRAY-01's Tray-only shelf
gate shipped by quick task 260714-3k6" and will catch a silent regression. But the test builds a
fresh, empty `ShelfViewState()`:

```swift
shelfViewState: ShelfViewState(),
```

`shelfStripVisible` (`Islet/Notch/NotchPillView.swift:62`) is currently a hard-coded
`{ false }` with zero dependency on `shelfViewState`. The exact regression this test is supposed
to prevent — a future edit reverting the getter to its pre-quick-task form,
`var shelfStripVisible: Bool { shelfViewState.isVisible }` — would **still make this test pass**,
because `ShelfViewState.isVisible` (`Islet/Shelf/ShelfViewState.swift:21`) is `!items.isEmpty`,
and the test's shelf has zero items, so `isVisible` evaluates to `false` regardless of which
implementation is live. The test cannot distinguish "hard-coded false" from "false because the
shelf happens to be empty," so it gives false confidence: it will pass both before and after the
exact regression it was written to catch.

**Fix:** Populate the injected `ShelfViewState` with at least one item so `isVisible` would be
`true` under the old (reverted) implementation, and assert `shelfStripVisible` stays `false`
anyway:

```swift
func testShelfStripVisibleIsAlwaysFalse() {
    let state = NotchInteractionState()
    let shelf = ShelfViewState()
    // Non-empty shelf so `ShelfViewState.isVisible` would be true if `shelfStripVisible`
    // ever regresses back to reading it — an empty shelf can't distinguish "hard-coded
    // false" from "false because the shelf is empty".
    shelf.items = [ShelfItem(id: UUID(), originalURL: URL(fileURLWithPath: "/tmp/a.txt"),
                              localURL: URL(fileURLWithPath: "/tmp/a.txt"),
                              filename: "a.txt", addedAt: Date())]
    let view = NotchPillView(interaction: state,
                              nowPlaying: NowPlayingState(),
                              presentationState: IslandPresentationState(.idle),
                              outfit: BasicOutfitState(),
                              shelfViewState: shelf,
                              onboardingState: OnboardingViewState(),
                              viewSwitcherState: ViewSwitcherState(),
                              calendarViewState: CalendarViewState())
    XCTAssertTrue(shelf.isVisible, "test setup sanity check — shelf must be non-empty")
    XCTAssertFalse(view.shelfStripVisible,
                    "shelfStripVisible must stay false even with a non-empty shelf — the additive shelf-strip reveal is Tray-only (TRAY-01).")
}
```

## Info

### IN-01: Redundant no-op assignment in the test

**File:** `IsletTests/NotchPillViewTests.swift:16`
**Issue:** `state.phase = .collapsed` sets the property to its own declared default
(`Islet/Notch/NotchInteractionState.swift:34`: `@Published var phase: InteractionPhase =
.collapsed`). Since `shelfStripVisible` doesn't read `interaction` at all, the line is a no-op
that implies the test's outcome depends on the collapsed phase, when it does not.
**Fix:** Remove the line, or if the intent is to document "this must hold in the collapsed
phase too," extend the test to also assert it under `.expanded`/`.hovering` phases instead of
leaving one unused assignment.

### IN-02: Access modifier widened module-wide solely for one test

**File:** `Islet/Notch/NotchPillView.swift:62`
**Issue:** `shelfStripVisible` moved from `private` to `internal`, making it callable from any
file in the `Islet` target (not just under `@testable import` from the test target). This
matches an existing precedent in the codebase (`EqualizerBars.makeProfiles()`) and is a
reasonable, deliberate tradeoff — noted here only as a minor encapsulation cost worth being
aware of if this pattern keeps being repeated across the file for every future test-only need.
**Fix:** None required; no action needed beyond awareness.

---

_Reviewed: 2026-07-14T02:48:33Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
