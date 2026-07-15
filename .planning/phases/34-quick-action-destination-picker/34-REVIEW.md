---
phase: 34-quick-action-destination-picker
reviewed: 2026-07-15T19:39:00Z
depth: standard
files_reviewed: 5
files_reviewed_list:
  - Islet/Notch/DragDropSupport.swift
  - IsletTests/DragApproachGeometryTests.swift
  - Islet/Notch/IslandPresentationState.swift
  - Islet/Notch/NotchPillView.swift
  - Islet/Notch/NotchWindowController.swift
findings:
  critical: 1
  warning: 3
  info: 2
  total: 6
status: issues_found
---

# Phase 34: Code Review Report

**Reviewed:** 2026-07-15T19:39:00Z
**Depth:** standard
**Files Reviewed:** 5
**Status:** issues_found

## Summary

Reviewed the post-UAT drag-target Quick Action picker revision: the pure `computeQuickActionButtonFrames(card:)` geometry helper and its tests, the new `hoveredQuickActionButtonIndex` published carrier, the buttons-only 117pt picker view, and the `NotchWindowController` wiring that moves `pendingDrop` population to drag-ENTER time and routes destination selection through release-point hit-testing.

The pure geometry function and its test coverage are solid — `computeQuickActionButtonFrames` is well-isolated and the tests exercise the documented invariants. The most significant defect is in `NotchWindowController.recheckDragAcceptRegion()`: moving `pendingDrop` population to the drag-*entered* edge means a synchronous, blocking `FileManager.copyItem` call (via `ShelfFileStore.makeSessionCopy`) now fires on the main thread merely from a pointer crossing into the accept region during a live OS drag — not from an actual drop — and repeats on every boundary re-crossing with no debounce. For anything but a trivially small file this can visibly hang the app (and stutter the live drag) from a gesture the user never intended to complete. Three further warnings cover a disabled-button hit-test gap, a stale-hover-state discipline break, and a magic-number duplication between the pure geometry helper and the (unconstrained) SwiftUI button-row layout.

## Critical Issues

### CR-01: Synchronous file copy runs on drag-hover, not just on drop, with no debounce

**File:** `Islet/Notch/NotchWindowController.swift:951-965`
**Issue:** `recheckDragAcceptRegion()`'s rising edge (entering the accept region while dragging) now unconditionally session-copies every dragged file:

```swift
withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
    interaction.phase = nextState(interaction.phase, .dragEntered)
    let urls = fileURLs(from: NSPasteboard(name: .drag))
    if !urls.isEmpty {
        var items: [ShelfItem] = []
        for url in urls {
            let id = UUID()
            guard let localURL = try? ShelfFileStore.makeSessionCopy(of: url, id: id) else { continue }
            ...
```

`ShelfFileStore.makeSessionCopy` calls `FileManager.default.copyItem(at:to:)` synchronously (`Islet/Shelf/ShelfFileStore.swift:33`). `recheckDragAcceptRegion()` is invoked from `handleDragApproachTick()`, which is wired to a global `.leftMouseDragged` monitor on the main run loop (`NotchWindowController.swift:433-435`). The net effect: merely dragging a file *near* the notch (crossing into `expandedZone`, without ever releasing there) now performs a blocking disk copy on the main thread. For a large file this is a visible UI hang during a live system drag gesture, not just a slow "drop" — a behavioral regression, since the prior architecture only touched disk at actual release. Because the accept-region entry/exit is edge-tracked with no debounce, a pointer that oscillates across the region boundary (easy to do near a small notch hot-zone) repeats copy-then-delete (`discardPendingDrop()` on the matching exit edge, `NotchWindowController.swift:977-987`) on every crossing.

**Fix:** Don't materialize the session copy at drag-enter time. Either (a) keep `pendingDrop` lightweight at entry (store the raw source `URL`s only, enough to render/hover the picker) and defer the actual `makeSessionCopy` calls to the moment a destination button is actually chosen in `handleDragApproachEnd()`, or (b) if the copy must happen eagerly to guard against Finder relocating the source, dispatch it off the main thread and asynchronously populate `pendingDrop`/`renderPresentation()` on completion:

```swift
let urls = fileURLs(from: NSPasteboard(name: .drag))
guard !urls.isEmpty else { return }
DispatchQueue.global(qos: .userInitiated).async { [weak self] in
    var items: [ShelfItem] = []
    for url in urls {
        let id = UUID()
        guard let localURL = try? ShelfFileStore.makeSessionCopy(of: url, id: id) else { continue }
        items.append(ShelfItem(id: id, originalURL: url, localURL: localURL, filename: url.lastPathComponent, addedAt: Date()))
    }
    guard !items.isEmpty else { return }
    DispatchQueue.main.async {
        guard let self, self.isDragApproaching else { return }   // re-check: may have exited already
        withAnimation(...) { self.pendingDrop = PendingDrop(items: items); self.renderPresentation() }
    }
}
```

## Warnings

### WR-01: AirDrop/Mail "disabled" state is cosmetic only — not enforced by the controller's hit test

**File:** `Islet/Notch/NotchWindowController.swift:1006-1013`, `Islet/Notch/NotchPillView.swift:187-188, 1089-1091`
**Issue:** `quickActionButton(... enabled: airDropAvailable ...)` only dims the button and is never consulted anywhere else — the view no longer wraps a real `Button(action:)` (that wrapper, and its implicit `.disabled()` gate, was removed by this revision in favor of pure controller-side hit-testing: see the comment at `NotchPillView.swift:1096-1100`). But `handleDragApproachEnd()`'s release-point switch (and `handleDragApproachTick()`'s hover computation) route to `handleQuickActionAirDrop()`/`handleQuickActionMail()` purely by button *index*, with no equivalent `airDropAvailable`/`mailAvailable` check:

```swift
if let hit = quickActionButtonFrames.firstIndex(where: { $0.contains(point) }) {
    switch hit {
    case 0: handleQuickActionDrop()
    case 1: handleQuickActionAirDrop()
    case 2: handleQuickActionMail()
    default: break
    }
}
```

Today this is unreachable only because `airDropAvailable`/`mailAvailable` are hardcoded `true` with no code path that ever flips them (per the documented D-09 fallback, currently unused). If that fallback is ever wired up, a user could still drop on (and see hover-highlight on) a visually "disabled" button and trigger the known-broken AirDrop/Mail path, since the safety net that a real disabled `Button` would have provided is gone.
**Fix:** Thread `airDropAvailable`/`mailAvailable` (or an equivalent controller-side flag) into `handleDragApproachEnd()`'s switch and into the hover computation in `handleDragApproachTick()`, e.g. `case 1 where airDropAvailable: handleQuickActionAirDrop()`, and skip highlighting a disabled index during hover hit-testing.

### WR-02: `discardPendingDrop()` doesn't clear the published hover index — single-choke-point discipline broken

**File:** `Islet/Notch/NotchWindowController.swift:1080-1086`
**Issue:** `discardPendingDrop()` clears `pendingDrop` and deletes session copies but leaves `presentationState.hoveredQuickActionButtonIndex` untouched. It's called from three "abandon" sites (`recheckDragAcceptRegion()`'s exit edge at line 984, `handleHoverExit()`'s grace-elapsed collapse at line 1273, `handleClick()`'s toggle-shut branch at line 1331) — none of which reset the hover index. Only `handleDragApproachEnd()` (line 1021) separately resets it after a successful button hit or the D-13 discard-on-release path. This is inconsistent with this file's own established discipline elsewhere (e.g. `pointerInZone`/`hotZone`/`expandedZone` are always reset together at their single hide site). In the common re-entry path the stale value self-heals within the same `handleDragApproachTick()` call before SwiftUI re-renders, but any future code path that renders `.quickActionPicker` without first passing through a fresh `.leftMouseDragged` tick would flash a stale highlighted button.
**Fix:** Move `presentationState.hoveredQuickActionButtonIndex = nil` into `discardPendingDrop()` itself so every abandon path clears it by construction:

```swift
private func discardPendingDrop() {
    guard pendingDrop != nil else { return }
    for item in pendingDrop?.items ?? [] {
        ShelfFileStore.deleteSessionCopy(at: item.localURL)
    }
    pendingDrop = nil
    presentationState.hoveredQuickActionButtonIndex = nil
}
```

### WR-03: `buttonRowHeight` is a duplicated magic number with no shared source of truth

**File:** `Islet/Notch/DragDropSupport.swift:44`, `Islet/Notch/NotchPillView.swift:1085-1117`
**Issue:** `computeQuickActionButtonFrames(card:)` hardcodes `buttonRowHeight: CGFloat = 59` (justified only by a comment: "icon 22 + gap 8 + label ~13 + vPadding 2x8"). The actual SwiftUI button row (`quickActionButtonRow()` → `quickActionButton(...)`) never constrains its height to 59pt explicitly — it's an *implicit* result of icon frame + VStack spacing + label font metrics + padding, computed independently in a different file. Nothing ties these two numbers together: if the label font size, icon size, spacing, or vertical padding is ever tuned in `NotchPillView.swift` (or if the user has the "Bold Text" accessibility setting on, changing font metrics), the geometry helper's hit-test rectangles silently drift from where the buttons actually render, producing click/hover misses with no compiler or test signal (the existing `DragApproachGeometryTests.swift` only tests the pure function's internal arithmetic, not agreement with the real view).
**Fix:** Either give the button row an explicit `.frame(height: ...)` sourced from the same constant `computeQuickActionButtonFrames` uses (e.g. hoist `59` into a shared `NotchPillView.quickActionButtonRowHeight` constant referenced by both files), or add an on-device/snapshot check that the rendered row height matches the assumed constant.

## Info

### IN-01: `dragPasteboardChangeCount` is written but never read

**File:** `Islet/Notch/NotchWindowController.swift:276, 908-912`
**Issue:** `handleDragApproachTick()` updates `dragPasteboardChangeCount` on every tick ("purely to keep dragPasteboardChangeCount current" per the comment), but nothing in the codebase reads this property afterward — it's dead write-only state. (Predates this phase's changes but sits inside the reviewed file.)
**Fix:** Either remove the unused tracking, or restore whatever conditional it was meant to gate (if intentionally scaffolded for a future check, leave a `// TODO` explaining what should consume it).

### IN-02: `computeQuickActionButtonFrames` tests don't assert the middle button's frame

**File:** `IsletTests/DragApproachGeometryTests.swift:38-76`
**Issue:** Coverage checks frame count, equal widths, the first frame's left/top position, and the last frame's right edge, but never directly asserts the middle (index 1, "AirDrop") button's `minX`/frame — a transposition bug in the `map` index math (e.g. swapping button 1 and 2) would not be caught by any current test.
**Fix:** Add an assertion for `frames[1].minX` (e.g. `card.minX + 16 + colWidth + gap`) mirroring `testFirstFrameStartsAtHorizontalInset`.

---

_Reviewed: 2026-07-15T19:39:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
