---
phase: 21-drag-out
reviewed: 2026-07-10T00:00:00Z
depth: standard
files_reviewed: 5
files_reviewed_list:
  - Islet/Shelf/ShelfViewState.swift
  - IsletTests/ShelfViewStateTests.swift
  - Islet/Notch/ShelfItemView.swift
  - Islet/Notch/NotchPillView.swift
  - Islet/Notch/NotchWindowController.swift
findings:
  critical: 0
  warning: 1
  info: 2
  total: 3
status: issues_found
---

# Phase 21: Code Review Report

**Reviewed:** 2026-07-10T00:00:00Z
**Depth:** standard
**Files Reviewed:** 5
**Status:** issues_found

## Summary

Reviewed the SHELF-06 drag-out feature: the pure `shouldBeginShelfItemDrag` gate + its test
(`ShelfViewState.swift` / `ShelfViewStateTests.swift`), the `.onDrag` drag source
(`ShelfItemView.swift`), the closure threading (`NotchPillView.swift`), and the drag-pin
lifecycle (`beginShelfItemDrag`/`endShelfItemDrag`/`dragPinSafetyNetWorkItem`/
`dragReleaseMonitor` in `NotchWindowController.swift`).

Diffed `NotchWindowController.swift` against the pre-phase-21 commit (`0a52803`) to confirm
`syncClickThrough()` (the CR-01 regression site named in the task) is **byte-for-byte
unmodified** — the expanded branch still reads pure `visibleContentZone()?.contains(
lastPointerLocation)`, never OR'd with `pointerInZone`. No CR-01 regression.

`beginShelfItemDrag`/`endShelfItemDrag` are idempotent (`isDraggingShelfItem` guard),
`dragReleaseMonitor` is guarded against double-registration, and `deinit` tears down both the
safety-net work item and the release monitor — no retain cycles (`[weak self]` throughout) and
no monitor leaks on controller deallocation.

One real correctness gap found in the drag-pin lifecycle: `endShelfItemDrag()` decides whether
to resume the collapse countdown using the possibly-stale `pointerInZone` flag instead of the
pointer's actual current position, because the global `.mouseMoved` monitor that normally keeps
`pointerInZone` in sync does not fire while an OS-level drag session is in flight. See WR-01
below.

## Warnings

### WR-01: `endShelfItemDrag` trusts a stale `pointerInZone` instead of re-sampling the pointer

**File:** `Islet/Notch/NotchWindowController.swift:1283-1291` (interacts with `pointerInZone` at
`:226` and `handlePointer` at `:671-702`)

**Issue:** `pointerInZone` is only kept current by the global `.mouseMoved` monitor inside
`handlePointer(at:)` (wired in `start()` at `:324-326`). During an active OS drag-and-drop
session (the kind `ShelfItemView`'s `.onDrag` starts), pointer motion is delivered as
`.leftMouseDragged`/drag-session events, not `.mouseMoved` — so `handlePointer` stops receiving
ticks for the whole duration of the drag, and `pointerInZone` freezes at whatever value it held
when the drag began (almost always `true`, since the user had to be hovering the shelf item to
start dragging it).

`endShelfItemDrag()` (fired by either the `.leftMouseUp` `dragReleaseMonitor` or the 20s safety
net) then checks:
```swift
if !pointerInZone { handleHoverExit() }
```
Because `pointerInZone` is stale-`true`, this condition is false even though the pointer has
physically moved away (e.g. dropped onto a Finder window or the Desktop) — so `handleHoverExit()`
is never called, no grace-collapse timer is scheduled, and the expanded island stays open
indefinitely until some unrelated future `.mouseMoved` tick happens to fire and finally detects
the real exit. In the worst case (user releases the drag and doesn't touch the trackpad again
right away) the island sits open covering extra screen space with no scheduled path back to
collapsed.

Note the `.leftMouseUp` event the release monitor already receives carries the pointer location,
but it's discarded (`{ [weak self] _ in self?.endShelfItemDrag() }`), so there's no cheap way to
re-derive freshness from that event as currently wired either.

**Fix:** Re-sample the live pointer position when ending the drag instead of trusting the frozen
flag — reuse the existing `handlePointer` entry point, which both updates `pointerInZone`/
`lastPointerLocation` from ground truth and correctly triggers `handleHoverExit()` if the pointer
is now outside the zone:
```swift
private func endShelfItemDrag() {
    guard isDraggingShelfItem else { return }
    isDraggingShelfItem = false
    dragPinSafetyNetWorkItem?.cancel()
    dragPinSafetyNetWorkItem = nil
    if let m = dragReleaseMonitor { NSEvent.removeMonitor(m) }
    dragReleaseMonitor = nil
    handlePointer(at: NSEvent.mouseLocation)   // re-sync from the CURRENT position, not the stale flag
}
```

## Info

### IN-01: "silent no-op" drag comment doesn't match actual `.onDrag` behavior for a missing file

**File:** `Islet/Notch/ShelfItemView.swift:27-32`

**Issue:** The comment on `shouldBeginShelfItemDrag` (`Islet/Shelf/ShelfViewState.swift:16-19`)
describes a vanished backing file as "a silent no-op drag." In practice, when the gate fails the
closure still returns a real (empty) `NSItemProvider()`:
```swift
guard shouldBeginShelfItemDrag(fileExists: exists) else { return NSItemProvider() }
```
SwiftUI's `.onDrag(_:)` always starts a real system drag session once a non-nil provider is
returned — it has no "don't start a drag at all" signal — so the user still sees the default
drag ghost/snapshot begin, even though `onDragStarted()` was never called and no real payload is
attached. This is a SwiftUI API constraint (there is no failable/optional `.onDrag`), not
something fixable with a one-line change, but the comment overstates what actually happens on
screen; worth tightening the wording (e.g. "no payload is attached and the pin is never armed"
rather than "silent no-op").

**Fix:** Adjust the comment to describe the real behavior, or verify on-device whether an empty
`NSItemProvider()` actually shows a visible ghost image on this macOS version; no code change
required otherwise.

### IN-02: unverified thread on which `.onDrag`'s item-provider closure runs

**File:** `Islet/Notch/ShelfItemView.swift:27-32`, `Islet/Notch/NotchWindowController.swift:1261-1276`

**Issue:** `onDragStarted()` ultimately calls `beginShelfItemDrag()` on the `@MainActor`
`NotchWindowController`, which touches AppKit (`NSEvent.addGlobalMonitorForEvents`) and mutates
plain (non-atomic) stored properties (`isDraggingShelfItem`, `dragPinSafetyNetWorkItem`,
`dragReleaseMonitor`). SwiftUI does not document a hard main-thread guarantee for the
`.onDrag(_:)` item-provider closure on macOS (some releases have been reported to invoke it off
the main thread while generating the initial drag snapshot). All the other AppKit-touching entry
points in this controller (`handlePointer`, the tap/click handlers, the monitor callbacks) are
either driven by AppKit event delivery (guaranteed main thread) or explicitly hop via
`DispatchQueue.main`/`[weak self]` closures registered on `.main` queues — this is the one new
entry point whose thread origin isn't verified.

**Fix:** Worth an on-device check (matches this codebase's existing on-device-UAT convention for
similar pointer/thread questions). If it's ever observed off-main, wrap the forwarding closure:
```swift
onShelfItemDragStarted: { [weak self] in
    DispatchQueue.main.async { self?.beginShelfItemDrag() }
}
```

---

_Reviewed: 2026-07-10T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
