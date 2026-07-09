---
phase: 20-shelf-view
reviewed: 2026-07-10T00:00:00Z
depth: standard
files_reviewed: 6
files_reviewed_list:
  - Islet/Notch/NotchPillView.swift
  - Islet/Notch/NotchWindowController.swift
  - Islet/Notch/ShelfItemView.swift
  - Islet/Shelf/ShelfViewState.swift
  - IsletTests/IslandResolverTests.swift
  - IsletTests/ShelfViewStateTests.swift
findings:
  critical: 1
  warning: 2
  info: 2
  total: 5
status: issues_found
---

# Phase 20: Code Review Report

**Reviewed:** 2026-07-10T00:00:00Z
**Depth:** standard
**Files Reviewed:** 6
**Status:** issues_found

## Summary

Reviewed the shelf-view UI layer (`NotchPillView`, `ShelfItemView`, `ShelfViewState`), the controller wiring in `NotchWindowController`, and the associated test files. The pure-value / resolver seam and the view-layer composition of the shelf row generally follow the codebase's established conventions well (single source of truth for `shelfRowHeight`, deferred deletion via `ShelfCoordinator`, untrusted-filename truncation). However, the panel-sizing change made to accommodate the shelf row introduces a real regression to the app's documented click-through guarantee (D-07 / Pitfall 3): the interactive click-swallowing region grows by a fixed 56pt for every user, even when the shelf is completely empty (which is the default state, since Phase 22's actual drag-in hasn't shipped yet). There is also a consistency gap: shelf mutations (delete/clear) are not wrapped in the `withAnimation` spring the rest of the file uses uniformly for every other `@Published` mutation, so the shelf row's `.transition(.opacity)` will not actually animate.

## Critical Issues

### CR-01: Shelf-row panel reservation unconditionally grows the click-swallowing region, even with an empty shelf

**File:** `Islet/Notch/NotchWindowController.swift:613-615`
**Issue:** `positionAndShow` now always sizes the expanded panel frame `expandedSize.height + NotchPillView.shelfRowHeight` (144 + 56 = 200), regardless of whether `shelfViewState.items` is empty:

```swift
let expandedFrame = expandedNotchFrame(collapsed: collapsedFrame,
                                       expandedSize: CGSize(width: expandedSize.width,
                                                             height: expandedSize.height + NotchPillView.shelfRowHeight))
```

`expandedZone` (line 628) is derived from this same `panelFrame`, and `syncClickThrough()` (line 719-722) sets `panel.ignoresMouseEvents = false` for the **entire panel rectangle** whenever `interaction.isExpanded` is true — not just the pixels the visible black blob actually occupies:

```swift
private func syncClickThrough() {
    let interactive = pointerInZone || interaction.isExpanded
    panel?.ignoresMouseEvents = !interactive
}
```

Before this phase, the expanded panel's click-catching rectangle matched the 144pt-tall visible content. Now it is unconditionally 56pt taller, so there is a permanent, invisible band beneath the expanded island that swallows every click intended for whatever app/window sits underneath it — for every user who expands the island, whether or not they have ever used the shelf. This directly contradicts the class's own documented invariant: "clicks OUTSIDE the pill always pass through" (Pitfall 3 / D-07, see the file header and `syncClickThrough`'s own doc comment). NotchPillView's visible black shape (`blobShape`) correctly only grows into that space conditionally on `!shelfItems.isEmpty` — the panel/hit-region sizing was not conditioned to match, so the reservation strategy chosen to avoid a live window resize leaks into user-facing click-blocking behavior.

**Fix:** Gate the extra reservation on whether the shelf actually has items, and resize the panel when the shelf transitions between empty and non-empty (mirroring how other one-shot resizes already happen in `positionAndShow` via `panel.setFrame`), e.g.:

```swift
let shelfHeight = shelfViewState.items.isEmpty ? 0 : NotchPillView.shelfRowHeight
let expandedFrame = expandedNotchFrame(collapsed: collapsedFrame,
                                       expandedSize: CGSize(width: expandedSize.width,
                                                             height: expandedSize.height + shelfHeight))
```
and call `positionAndShow`/re-resolve the frame from `handleShelfItemDelete`/`handleShelfClearAll`/`seedDebugShelfItems`/append path whenever the empty↔non-empty edge is crossed. Alternatively, keep the panel reservation but make `ignoresMouseEvents` hit-test against the actual visible blob rect (computed the same way `NotchPillView.blobShape` computes its height) rather than the full static panel rectangle.

## Warnings

### WR-01: Shelf delete/clear mutations are not wrapped in `withAnimation`, so the shelf row's fade transition never animates

**File:** `Islet/Notch/NotchWindowController.swift:1161-1171`
**Issue:** Every other `@Published` mutation in this controller (charging, device, now-playing, presentation, accent) is wrapped in `withAnimation(.spring(response: springResponse, dampingFraction: springDamping))` so the SwiftUI transition/`matchedGeometryEffect` actually animates. The two live shelf-mutation handlers do not follow that pattern:

```swift
private func handleShelfItemDelete(_ id: UUID) {
    shelfCoordinator.remove(id: id)
    shelfViewState.items = shelfCoordinator.logic.items
}

private func handleShelfClearAll() {
    shelfCoordinator.clear()
    shelfViewState.items = shelfCoordinator.logic.items
}
```

`NotchPillView.blobShape` attaches `.transition(.opacity)` to the shelf row (`if hasShelf { shelfRow(shelfItems).transition(.opacity) }`) and resizes the enclosing `NotchShape`'s height when `hasShelf` flips. Both effects require the state change to occur inside an animation transaction to actually animate; without `withAnimation`, the shelf row will appear/disappear and the blob will resize/shrink instantly (a visual snap), inconsistent with the rest of the app's spring-driven feel.

**Fix:**
```swift
private func handleShelfItemDelete(_ id: UUID) {
    shelfCoordinator.remove(id: id)
    withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
        shelfViewState.items = shelfCoordinator.logic.items
    }
}
```
(same for `handleShelfClearAll`).

### WR-02: Duplicated resync line across three handlers

**File:** `Islet/Notch/NotchWindowController.swift:1163, 1170, 1194`
**Issue:** `shelfViewState.items = shelfCoordinator.logic.items` is repeated verbatim in `handleShelfItemDelete`, `handleShelfClearAll`, and `seedDebugShelfItems`. Combined with WR-01's fix, three call sites would each need to remember to wrap the assignment in `withAnimation` — an easy place for a future edit to drift and reintroduce the missing-animation bug for only one of the three paths.
**Fix:** Extract a single `private func resyncShelfViewState(animated: Bool = true)` helper that both performs the assignment and (conditionally, for the DEBUG seed path) wraps it in the spring, and call it from all three sites.

## Info

### IN-01: Shelf icon `Image` is stretched without preserving aspect ratio

**File:** `Islet/Notch/ShelfItemView.swift:14-16`
**Issue:**
```swift
Image(nsImage: NSWorkspace.shared.icon(forFile: item.localURL.path))
    .resizable()
    .frame(width: 28, height: 28)
```
`.resizable()` + `.frame` with no `.aspectRatio(contentMode:)` stretches the icon to exactly 28x28, distorting it if `NSWorkspace.shared.icon(forFile:)` ever returns a non-square image (uncommon but not guaranteed for every file type/extension). Low risk today, but a one-line defensive fix.
**Fix:** Add `.aspectRatio(contentMode: .fit)` between `.resizable()` and `.frame(...)`.

### IN-02: `blobShape`'s `shelfItems` parameter is threaded through 3 call sites with identical `shelfItems: shelfViewState.items` arguments

**File:** `Islet/Notch/NotchPillView.swift:227, 641, 706`
**Issue:** `expandedIsland`, `mediaExpanded`, and `mediaUnavailable` each pass `shelfItems: shelfViewState.items` to `blobShape` individually. Since `blobShape` is a method on the same type that already has `shelfViewState` as a stored property, the parameter is redundant — `blobShape` could read `shelfViewState.items` directly instead of requiring every caller to pass it, removing three duplicated argument sites and a class of "forgot to pass shelfItems at a new call site" defect.
**Fix:** Drop the `shelfItems` parameter from `blobShape` and read `self.shelfViewState.items` inside it directly.

---

_Reviewed: 2026-07-10T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
