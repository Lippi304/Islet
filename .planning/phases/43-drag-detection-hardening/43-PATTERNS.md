# Phase 43: Drag Detection Hardening - Pattern Map

**Mapped:** 2026-07-19
**Files analyzed:** 4 (1 modified-heavily, 2 read-only reference, 1 test file to extend)
**Analogs found:** 4 / 4 (all patterns exist IN the same files being modified — this phase hardens existing logic, it does not introduce a new architectural shape)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|--------------------|------|-----------|-----------------|----------------|
| `Islet/Notch/NotchWindowController.swift` (`recheckDragAcceptRegion()`, `handleDragApproachTick()`) | controller (AppKit event-monitor glue) | event-driven | `handlePointer(at:)`'s `pointerInZone` edge-tracking (same file, lines 1253-1267) | exact — same file, same edge-tracked-boolean idiom already used twice |
| `Islet/Notch/DragDropSupport.swift` (possible new pure helper, e.g. `isGenuineFileDrag`) | utility (pure function) | transform | `isWithinDragAcceptRegion` / `shouldAcceptDrop` (same file, lines 17-19, 27-30) | exact — same file, same "pure top-level function for testability" convention |
| `IsletTests/DragApproachGeometryTests.swift` (new test methods for the new gate) | test | transform | Existing test methods in the same file (lines 10-32) | exact — same file, same fixture-free one-method-per-behavior convention |
| `Islet/Notch/NotchInteractionState.swift` | model (pure state machine) | transform | N/A — read-only reference, not expected to change (D-NA: `.dragEntered` is deliberately geometry-agnostic; gate belongs at call site per its own comment) | reference-only |

## Pattern Assignments

### `Islet/Notch/NotchWindowController.swift` — `recheckDragAcceptRegion()` / `handleDragApproachTick()` (controller, event-driven)

**Analog:** same file, `handlePointer(at:)`'s `pointerInZone` edge-tracking shape (lines 1253-1267), and the file's own prior edge-tracked flag `isDragApproaching` (lines 1096-1143).

**Current state — properties** (lines 321-330):
```swift
private var dragApproachMonitor: Any?
private var dragEndMonitor: Any?
private var dragPasteboardChangeCount = NSPasteboard(name: .drag).changeCount

// Phase 24 / SHELF-01 / SHELF-02 — the drag-approach edge-tracked flag, mirroring
// pointerInZone's own edge-tracking discipline immediately below: armed on a genuine
// pasteboard-changeCount-confirmed drag entering the accept region, disarmed
// unconditionally at every .leftMouseUp (handleDragApproachEnd's literal first action) so
// a geometrically-ambiguous Escape-cancel can never leave the island stuck expanded.
private var isDragApproaching = false
```
Note the comment already CLAIMS "pasteboard-changeCount-confirmed" — this is the bug: the code below never actually gates on it.

**Root-cause current implementation** (lines 1062-1143):
```swift
private func handleDragApproachTick() {
    let pasteboard = NSPasteboard(name: .drag)
    let count = pasteboard.changeCount
    if count != dragPasteboardChangeCount {
        dragPasteboardChangeCount = count
    }
    recheckDragAcceptRegion()
    // ... quick-action hover hit-test, unrelated to the gate ...
}

private func recheckDragAcceptRegion() {
    let point = NSEvent.mouseLocation
    let geometryInside = isWithinDragAcceptRegion(point, zone: expandedZone, maxY: dragLandingMaxY)
    if geometryInside && !isDragApproaching && !interaction.isExpanded {
        isDragApproaching = true
        graceWorkItem?.cancel()
        graceWorkItem = nil
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
            interaction.phase = nextState(interaction.phase, .dragEntered)
            let urls = fileURLs(from: NSPasteboard(name: .drag))
            if !urls.isEmpty {
                var items: [ShelfItem] = []
                for url in urls {
                    let id = UUID()
                    guard let localURL = try? ShelfFileStore.makeSessionCopy(of: url, id: id) else { continue }
                    items.append(ShelfItem(id: id, originalURL: url, localURL: localURL, filename: url.lastPathComponent, addedAt: Date()))
                }
                if !items.isEmpty { pendingDrop = PendingDrop(items: items) }
            }
            renderPresentation()
        }
        if dropInterceptTap == nil {
            dropInterceptTap = DropInterceptTap(
                shouldSwallow: { [weak self] in self?.isDragApproaching ?? false },
                onIntercept: { [weak self] in self?.handleDragApproachEnd() }
            )
        }
        dropInterceptTap?.start()
    } else if !geometryInside && isDragApproaching {
        isDragApproaching = false
        withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
            discardPendingDrop()
            renderPresentation()
        }
    }
}
```

**The gate to add:** the arm condition `geometryInside && !isDragApproaching && !interaction.isExpanded` currently has no genuine-drag-content check. `dragPasteboardChangeCount` is tracked but never compared *at the arm site* against a "changeCount seen when this specific gesture started" baseline — it only detects "did the systemwide pasteboard change since last tick", which stays true/stale across ordinary clicks. The fix belongs entirely inside this arm branch (or as a new pure helper in `DragDropSupport.swift` that this branch calls) — do not touch `nextState`/`InteractionPhase` (see reference file below).

**Edge-tracking idiom to mirror exactly** (`handlePointer(at:)`, lines 1261-1267 — the pattern this codebase always uses for enter/exit booleans):
```swift
if inside && !pointerInZone {
    pointerInZone = true
    handleHoverEnter()          // cancels the pending grace collapse inside
} else if !inside && pointerInZone {
    pointerInZone = false
    handleHoverExit()
}
```

**Monitor wiring pattern** (`start(isFirstLaunch:)`, lines 487-492 — unchanged, reference only, no new monitors expected):
```swift
dragApproachMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged]) { [weak self] _ in
    self?.handleDragApproachTick()
}
dragEndMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] _ in
    self?.handleDragApproachEnd()
}
```

**Teardown pattern** (`deinit`, lines 2393-2395 — unchanged, reference only):
```swift
if let m = dragApproachMonitor { NSEvent.removeMonitor(m) }
if let m = dragEndMonitor { NSEvent.removeMonitor(m) }
```

---

### `Islet/Notch/DragDropSupport.swift` (utility, transform) — candidate new pure helper

**Analog:** `isWithinDragAcceptRegion` and `shouldAcceptDrop` in the same file — this file's established convention for ANY new gating logic that is pure enough to extract (per CONTEXT.md `## Established patterns`).

**Existing pure-function style to copy** (lines 1-30):
```swift
import AppKit

// Phase 22 / SHELF-01 / SHELF-02 — the two pure, AppKit-glue-free seams 22-RESEARCH.md's Wave 0
// flags as this phase's genuinely testable surface. ...

func fileURLs(from pasteboard: NSPasteboard) -> [URL] {
    (pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL]) ?? []
}

func shouldAcceptDrop(isExpanded: Bool, urls: [URL]) -> Bool {
    !isExpanded && !urls.isEmpty
}

func isWithinDragAcceptRegion(_ point: CGPoint, zone: CGRect?, maxY: CGFloat?) -> Bool {
    guard let zone, let maxY else { return false }
    return zone.contains(point) && point.y <= maxY
}
```

If a new gate needs to be extracted as a pure function (e.g. "did the pasteboard changeCount seen at gesture-start differ from the count at arm-time"), it should be a free top-level function in this file, doc-commented with the same "Phase N / TICKET — why pure/testable" convention, taking plain value types (`Int` counts, not `NSPasteboard` directly) so it can be unit-tested without AppKit fixtures — mirroring `isWithinDragAcceptRegion`'s `CGPoint`/`CGRect?` signature rather than passing the live pasteboard object in.

**Note:** whether the fix is expressible as a pure function at all is genuinely uncertain — the "genuine drag" signal may require comparing changeCount *at the moment the specific left-mouse-down/drag gesture began* vs. *now*, which needs a per-gesture baseline stored as controller state (like `dragPasteboardChangeCount` already is), not just two passed-in ints. If the gate can only be expressed correctly with that stateful baseline, keep it inline in `recheckDragAcceptRegion()`/`handleDragApproachTick()` rather than forcing an artificial pure extraction — CONTEXT.md's Claude's Discretion note explicitly leaves the mechanism open.

---

### `IsletTests/DragApproachGeometryTests.swift` (test, transform)

**Analog:** the file's own existing test methods (lines 10-32) for `isWithinDragAcceptRegion`.

**Convention to copy** (lines 1-13):
```swift
import XCTest
import AppKit
@testable import Islet

// Phase 24 / SHELF-01 / SHELF-02 — unit coverage for isWithinDragAcceptRegion's pure geometry
// math (Wave 0 gap closure per 24-VALIDATION.md). Mirrors DragDropSupportTests.swift's
// fixture-free convention: one test method per behavior, no setUp/tearDown, no mocking.
final class DragApproachGeometryTests: XCTestCase {

    func testPointInsideZoneAtOrBelowMaxYReturnsTrue() {
        let zone = CGRect(x: 0, y: 0, width: 200, height: 100)
        XCTAssertTrue(isWithinDragAcceptRegion(CGPoint(x: 100, y: 50), zone: zone, maxY: 90))
    }
    ...
```
If a new pure helper is added to `DragDropSupport.swift`, add its tests to this same file (or a same-shape sibling if the planner decides the gate lives elsewhere) as new `func test...()` methods — no setUp/tearDown, no mocks, fixture-free, one behavior per method, matching the existing 10 methods exactly.

---

### `Islet/Notch/NotchInteractionState.swift` (model, transform) — reference only, not expected to change

**Why no changes expected here:** the `.dragEntered` transition is deliberately geometry/content-agnostic by design — its own comment says so:
```swift
// Phase 22 / SHELF-01 (D-01/D-05): drag-enter auto-expands, same target as .clicked -- the
// CALLER (22-03) gates WHICH geometry triggers this event (D-02b/D-02c), this transition itself
// is geometry-agnostic
case (.hovering,  .dragEntered):    return .expanded
case (.collapsed, .dragEntered):    return .expanded
```
CONTEXT.md confirms this: "the caller (`recheckDragAcceptRegion`) is the only place that can add a genuine-drag gate." Do not add a new `InteractionEvent` case or touch `nextState` — the fix is 100% in the caller.

---

## Shared Patterns

### Edge-tracked boolean lifecycle (apply to any new gate state)
**Source:** `isDragApproaching` (declared line 330, used lines 1099-1142) and `pointerInZone` (declared line 337, used lines 1261-1267) in `NotchWindowController.swift`.
**Rule:** armed on a rising edge inside the "geometry inside" branch; disarmed unconditionally on the corresponding exit event (`.leftMouseUp` for drag, geometry-exit for pointer) so an ambiguous/interrupted gesture (Escape-cancel, window switch) can never leave state stuck. Mirror this shape exactly for any new "genuine drag confirmed" flag rather than inventing a different reset lifecycle.

### Pure/testable seam convention
**Source:** `Islet/Notch/DragDropSupport.swift` (whole file) + `IsletTests/DragApproachGeometryTests.swift` (whole file).
**Rule:** any logic that is pure geometry/value-arithmetic (no `NSEvent`/`NSPasteboard` object plumbing) belongs as a free top-level function in `DragDropSupport.swift`, unit-tested via `@testable import Islet` with fixture-free one-method-per-behavior tests. Logic that inherently needs live AppKit state (the running pasteboard, timers, `@Published` phase) stays inline in `NotchWindowController.swift`.

### Comment/doc convention
**Source:** every touched file in this phase.
**Rule:** every non-trivial block is preceded by a `// Phase N / TICKET-ID (D-xx) — why` comment explaining the decision reference, not just what the code does. Any new code in this phase should cite `Phase 43 / DRAG-01` and the relevant `D-0x` decision from `43-CONTEXT.md`.

## No Analog Found

None — this phase modifies existing files only; no net-new files are being created, so every touch point already has direct in-file precedent to follow.

## Metadata

**Analog search scope:** `Islet/Notch/NotchWindowController.swift`, `Islet/Notch/NotchInteractionState.swift`, `Islet/Notch/DragDropSupport.swift`, `IsletTests/DragApproachGeometryTests.swift`
**Files scanned:** 4 (all named explicitly in CONTEXT.md's `<code_context>`; no broader codebase search needed since the bug and its fix are fully localized to these files per the root-cause analysis)
**Pattern extraction date:** 2026-07-19
