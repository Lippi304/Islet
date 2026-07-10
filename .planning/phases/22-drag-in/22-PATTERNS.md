# Phase 22: Drag-In - Pattern Map

**Mapped:** 2026-07-10
**Files analyzed:** 4 (2 modified production files, 1 likely-modified test file, 1 new/extended test file)
**Analogs found:** 4 / 4 (all analogs are the SAME two files this phase modifies plus their siblings — this phase is additive to an existing, well-established single-arbiter architecture, not a new subsystem)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|--------------------|------|-----------|-----------------|----------------|
| `Islet/Notch/NotchPanel.swift` (add `registerForDraggedTypes` + `NSDraggingDestination` overrides) | config/window-shell (AppKit `NSPanel` subclass) | event-driven (OS drag-session callbacks) | itself — extend the existing `init` (see below) | exact (same file, additive) |
| `Islet/Notch/NotchWindowController.swift` (add `handleDragEntered`/`handleDragExited`/`handleDragPerform`) | controller (AppKit glue / single-arbiter state owner) | event-driven → CRUD (drop → `ShelfItem` append) | itself — `handleHoverEnter`/`handleHoverExit`/`handleClick`/`beginShelfItemDrag`/`endShelfItemDrag` (same file) | exact (same file, same established pattern family) |
| `IsletTests/NotchPanelTests.swift` (add drag-type-registration assertion) | test | request-response (pure property assertions on a constructed panel) | itself — existing `testPanelStartsClickThrough` style | exact |
| `IsletTests/NotchWindowControllerTests.swift` or a new pure-seam test file for URL-extraction/edge-detection helpers | test | transform (pure function unit tests) | `IsletTests/ShelfLogicTests.swift` (fixture-free pure-logic convention) + `IsletTests/ShelfCoordinatorTests.swift`/`ShelfFileStoreTests.swift` (real-disk-I/O convention, `setUp`/`tearDown` fixture dir) | role-match (no `NotchWindowController` unit-test file currently exists — `InteractionStateTests.swift` is the closest existing analog for testing pure state-machine transitions) |

**No new files are structurally required** — RESEARCH.md's own "Recommended Project Structure" confirms this phase fits entirely inside the two existing files above. If the planner extracts a pure URL-extraction/edge-detection helper (Wave 0 gap in RESEARCH.md), that helper is a new small type but still lands as an addition to the existing `Islet/Shelf/` or `Islet/Notch/` directories, not a new subsystem directory.

---

## Pattern Assignments

### `Islet/Notch/NotchPanel.swift` (config/window-shell, event-driven)

**Analog:** itself (`Islet/Notch/NotchPanel.swift`, full file, 37 lines — already read in full above)

**Current full-file pattern to extend (imports + init + property overrides):**
```swift
import AppKit

final class NotchPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        isMovableByWindowBackground = false
        isReleasedWhenClosed = false
        ignoresMouseEvents = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
    }
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
```

**Convention to follow when adding drag-destination registration:**
- Add `registerForDraggedTypes([.fileURL])` as ONE MORE LINE inside the existing `init`, alongside the other one-shot configuration (mirrors how every other panel property — `level`, `collectionBehavior`, `ignoresMouseEvents` — is set once here and commented with its rationale/decision-ID inline, per this file's own header comment convention: "configured ONCE in `init`").
- Per RESEARCH.md Pattern 1: implement `draggingEntered`/`draggingUpdated`/`draggingExited`/`performDragOperation` as thin overrides that forward to a weak closure/delegate reference the controller sets — do NOT put controller state (hover/expand/shelf logic) inside `NotchPanel` itself. This file's entire existing convention is "small AppKit window shell, zero business logic" (see its header: "everything visible is SwiftUI hosted inside it"); the drag callbacks must preserve that by forwarding out, exactly like nothing else currently lives in this class beyond construction + the two `canBecomeKey/Main` overrides.
- Comment style to match: every property line in the existing `init` has an inline `//` comment naming the decision/phase it traces to (`D-07`, `ISL-02`, `Pitfall 3`) — new drag-registration lines should follow the same annotation convention, referencing this phase's decision IDs (D-01–D-04) and the CONTEXT.md discretion items.

---

### `Islet/Notch/NotchWindowController.swift` (controller, event-driven → CRUD)

**Analog:** itself — `handleHoverEnter()`/`handleHoverExit()`/`syncClickThrough()`/`handleClick()`/`beginShelfItemDrag()`/`endShelfItemDrag()`/`resyncShelfViewState()` (all in the same file; line numbers below refer to the CURRENT file before this phase's edits)

**Imports pattern** (lines 1-3, unchanged — no new imports needed, `AppKit`/`SwiftUI`/`CoreLocation` already present):
```swift
import AppKit
import SwiftUI
import CoreLocation
```

**Property-declaration convention to follow for new drag-in state** (lines 211-226, the EXACT sibling pattern for Phase 21's outbound-drag pin — model any new `isDragHovering`/inbound-drag-pin state on this shape):
```swift
// Phase 21 / SHELF-06 / D-03 — the shelf-item drag pin: while true, handleHoverExit's
// graceWorkItem defers the collapse. Released via BOTH a best-effort early signal
// (dragReleaseMonitor, a .leftMouseUp global monitor mirroring mouseMonitor's .mouseMoved
// idiom, armed only for the duration of an active drag) AND a guaranteed 20s safety net
// (dragPinSafetyNetWorkItem) so the pin can never outlive a real drag gesture indefinitely.
private var isDraggingShelfItem = false
private var dragPinSafetyNetWorkItem: DispatchWorkItem?
private let dragPinSafetyNetDuration: TimeInterval = 20.0
private var dragReleaseMonitor: Any?

// WR-01: the pointer-in-hot-zone edge, tracked from RAW geometry — NOT derived from
// `interaction.isHovering` ...
private var pointerInZone = false
```
→ A new `isDragHovering`-style flag (Pitfall 2's edge-detect requirement) should sit right next to `pointerInZone`, with the SAME "tracked from raw geometry / edge, not derived from phase" comment discipline (WR-01 precedent).

**Core drag-enter/exit/perform pattern — model directly on `handleHoverEnter`/`handleHoverExit`/`syncClickThrough`** (lines 719-827):
```swift
// D-01 hover-ENTER: haptic + a `.pointerEntered` bounce, NO expand. Make the panel
// hit-testable so the follow-up click can land, and cancel any pending collapse.
private func handleHoverEnter() {
    NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
    graceWorkItem?.cancel()
    graceWorkItem = nil
    dismissWorkItem?.cancel()
    mediaDismissWorkItem?.cancel()
    withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
        interaction.phase = nextState(interaction.phase, .pointerEntered)
    }
    syncClickThrough()
}

// WR-02 (Pitfall 3 / D-07): the SINGLE place that decides `ignoresMouseEvents`.
private func syncClickThrough() {
    let interactive: Bool
    if interaction.isExpanded {
        interactive = visibleContentZone()?.contains(lastPointerLocation) ?? false
    } else {
        interactive = pointerInZone
    }
    panel?.ignoresMouseEvents = !interactive
}

private func handleHoverExit() {
    withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
        interaction.phase = nextState(interaction.phase, .pointerExited)
    }
    let work = DispatchWorkItem { [weak self] in
        guard let self else { return }
        guard !self.isDraggingShelfItem else { return }   // <- model isDragHovering's own guard here
        withAnimation(.spring(response: self.springResponse, dampingFraction: self.springDamping)) {
            self.interaction.phase = nextState(self.interaction.phase, .graceElapsed)
            self.renderPresentation()
        }
        self.updateVisibility()
        self.syncClickThrough()
    }
    graceWorkItem = work
    DispatchQueue.main.asyncAfter(deadline: .now() + graceDelay, execute: work)
}
```
**Direct implication for `handleDragEntered`:** it should mirror `handleClick()`'s expand-transition shape (line 832-867) — `nextState(interaction.phase, .clicked)`-equivalent inside `withAnimation`, call `renderPresentation()`, then `syncClickThrough()` at the end — NOT duplicate hover's bounce-only transition, since D-01 requires an actual auto-EXPAND on drag-enter (not just a hover bounce). D-03's hot-feedback (bounce) is a SEPARATE, already-existing effect from `handleHoverEnter` — CONTEXT.md's D-03 says drag-hover reuses the hover bounce, but D-01 additionally requires an expand, so `handleDragEntered` likely composes both: the existing bounce affordance PLUS a `.clicked`-equivalent expand transition.

**`performDragOperation` / URL-extraction + shelf-append pattern — model on `resyncShelfViewState`/`handleShelfItemDelete`/the DEBUG seed function** (lines 1239-1249, 1307-1325):
```swift
private func resyncShelfViewState(animated: Bool = true) {
    let newItems = shelfCoordinator.logic.items
    if animated {
        withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
            shelfViewState.items = newItems
        }
    } else {
        shelfViewState.items = newItems
    }
    syncClickThrough()
}

#if DEBUG
private func seedDebugShelfItems() {
    // ... for each source URL:
    let id = UUID()
    guard let localURL = try? ShelfFileStore.makeSessionCopy(of: source, id: id) else { continue }
    let item = ShelfItem(id: id, originalURL: source, localURL: localURL, filename: seed.name, addedAt: Date())
    shelfCoordinator.append(item)
    // ...
    resyncShelfViewState(animated: false)
}
#endif
```
→ `handleDragPerform(_:)` is a NON-DEBUG production version of exactly this same append loop: extract `[URL]` from `NSDraggingInfo.draggingPasteboard`, for each URL call `ShelfFileStore.makeSessionCopy` + construct a `ShelfItem` + `shelfCoordinator.append(item)`, then call `resyncShelfViewState()` ONCE after the loop (matches the seed function's one-resync-after-all-appends shape, and Phase 19 D-06's drop-order-append convention).

**Drag-pin lifecycle pattern (route new inbound-drag state through the SAME grace/pin mechanism as outbound) — model on `beginShelfItemDrag`/`endShelfItemDrag`** (lines 1268-1301):
```swift
private func beginShelfItemDrag() {
    isDraggingShelfItem = true
    graceWorkItem?.cancel()
    graceWorkItem = nil
    dragPinSafetyNetWorkItem?.cancel()
    let safetyNet = DispatchWorkItem { [weak self] in self?.endShelfItemDrag() }
    dragPinSafetyNetWorkItem = safetyNet
    DispatchQueue.main.asyncAfter(deadline: .now() + dragPinSafetyNetDuration, execute: safetyNet)
    if dragReleaseMonitor == nil {
        dragReleaseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] _ in
            self?.endShelfItemDrag()
        }
    }
}

private func endShelfItemDrag() {
    guard isDraggingShelfItem else { return }
    isDraggingShelfItem = false
    dragPinSafetyNetWorkItem?.cancel()
    dragPinSafetyNetWorkItem = nil
    if let m = dragReleaseMonitor { NSEvent.removeMonitor(m) }
    dragReleaseMonitor = nil
    // WR-01: pointerInZone is only kept fresh by the .mouseMoved monitor, which doesn't fire
    // during an OS drag session — re-sample the live pointer instead of trusting the frozen flag.
    handlePointer(at: NSEvent.mouseLocation)
}
```
→ Pitfall 3 in RESEARCH.md explicitly says the SAME `handlePointer(at: NSEvent.mouseLocation)` re-sample-on-drag-end call is required for the inbound drag too (`draggingEnded`/`performDragOperation` completion) — copy this exact idiom, do not invent a new one.

**Error handling / rejection pattern (non-file payload, expanded-state gate) — model on `handleShelfItemTap`'s guard-based no-op**:
```swift
private func handleShelfItemTap(_ item: ShelfItem) {
    guard shouldOpenShelfItem(fileExists: FileManager.default.fileExists(atPath: item.localURL.path)) else { return }
    NSWorkspace.shared.open(item.localURL)
}
```
→ `handleDragPerform`/`draggingEntered` should use the same "guard, silent return, no error dialog" shape for: (a) D-04's collapsed-only gate (`guard !interaction.isExpanded else { return false }` inside `performDragOperation`, mirroring Pitfall 5's guidance), and (b) non-file `NSItemProvider` payloads (guard the extracted `[URL]` array is non-empty, else reject) — consistent with this codebase's established "no dialogs, no thrown errors, just a silent no-op" convention seen throughout (Phase 19 D-01/D-02 duplicate handling, Phase 20 D-04 missing-file handling).

---

### `IsletTests/NotchPanelTests.swift` (test, request-response / pure property assertions)

**Analog:** itself, full file (58 lines, already read above)

**Pattern to extend:**
```swift
@MainActor
final class NotchPanelTests: XCTestCase {
    private func makePanel() -> NotchPanel {
        NotchPanel(contentRect: NSRect(x: 0, y: 0, width: 200, height: 32))
    }

    func testPanelStartsClickThrough() {
        let panel = makePanel()
        XCTAssertTrue(panel.ignoresMouseEvents, "...")
    }
}
```
→ Add `testPanelRegistersForFileURLDraggedTypes()` in the exact same shape: construct via `makePanel()`, assert on the new registered-types state (AppKit doesn't expose `registeredDraggedTypes` directly as a queryable array pre-macOS-additions in older SDKs — planner should verify via `NSPasteboard`/whatever accessor RESEARCH.md's spike confirms, or fall back to a behavioral test via a mock `NSDraggingInfo` calling `draggingEntered` directly and asserting the returned `NSDragOperation`).

---

### Pure-seam test file (new or extended) — URL-extraction + edge-detection helpers

**Analog A (fixture-free pure-logic convention):** `IsletTests/ShelfLogicTests.swift` (lines 1-26 read above) — one test method per behavior, fresh value type per test, no `setUp`/`tearDown`, no mocking framework:
```swift
final class ShelfLogicTests: XCTestCase {
    func testAppendAddsToEndInDropOrder() {
        var logic = ShelfLogic()
        let a = ShelfItem(id: UUID(), originalURL: URL(fileURLWithPath: "/a.pdf"),
                           localURL: URL(fileURLWithPath: "/tmp/a.pdf"), filename: "a.pdf",
                           addedAt: Date(timeIntervalSinceReferenceDate: 0))
        XCTAssertTrue(logic.append(a))
        XCTAssertEqual(logic.items.map(\.filename), ["a.pdf"])
    }
}
```

**Analog B (real-disk-I/O convention with fixture dir):** `IsletTests/ShelfCoordinatorTests.swift` / `ShelfFileStoreTests.swift` (both read above) — `setUp()`/`tearDown()` create/remove a throwaway `NSTemporaryDirectory()`-rooted fixture dir per test case, used whenever the test needs a REAL on-disk file (e.g. the RESEARCH.md Wave-0-gap folder-round-trip test for `makeSessionCopy` on a directory URL):
```swift
override func setUp() {
    super.setUp()
    fixturesDir = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("ShelfFileStoreTestsFixtures-\(UUID())", isDirectory: true)
    try? FileManager.default.createDirectory(at: fixturesDir, withIntermediateDirectories: true)
}
override func tearDown() {
    try? FileManager.default.removeItem(at: fixturesDir)
    fixturesDir = nil
    super.tearDown()
}
```
→ Use Analog A's shape for the pure URL→`ShelfItem`-mapping helper and the one-shot edge-detection helper (no disk I/O, no fixture dir needed). Use Analog B's shape ONLY for the folder-round-trip `makeSessionCopy` test (real `FileManager.copyItem` on a directory).

---

## Shared Patterns

### Single-arbiter click-through gate (`syncClickThrough`)
**Source:** `Islet/Notch/NotchWindowController.swift` lines 756-784 (WR-02 / CR-01 comment block + implementation)
**Apply to:** ALL new drag-related state mutations. Per CONTEXT.md's explicit carry-forward of the CR-01 gotcha and RESEARCH.md Pattern 3/Anti-Patterns: no new code may set `panel?.ignoresMouseEvents` directly, and the expanded-state branch of `syncClickThrough()` must stay a pure `visibleContentZone()?.contains(lastPointerLocation)` check — never OR'd with `pointerInZone` or a new `isDragHovering` flag. Any new "is a drag in progress" bookkeeping is READ by `syncClickThrough()`/`handleHoverExit()`'s grace closure the same way `isDraggingShelfItem` already is, never as an independent writer of the mouse-events flag.
```swift
private func syncClickThrough() {
    let interactive: Bool
    if interaction.isExpanded {
        interactive = visibleContentZone()?.contains(lastPointerLocation) ?? false
    } else {
        interactive = pointerInZone
    }
    panel?.ignoresMouseEvents = !interactive
}
```

### Post-drag pointer re-sample (frozen `.mouseMoved` monitor during an OS drag session)
**Source:** `Islet/Notch/NotchWindowController.swift` `endShelfItemDrag()`, lines 1290-1301
**Apply to:** Any new inbound-drag-end handler (`performDragOperation`/`concludeDragOperation`/SwiftUI `isTargeted` `true→false` edge). Must call `handlePointer(at: NSEvent.mouseLocation)` explicitly, exactly like `endShelfItemDrag()` does, because the global `.mouseMoved` monitor does not fire during a modal AppKit drag-tracking loop (confirmed by this codebase's own existing comment, reused directly by RESEARCH.md Pitfall 3).

### Shelf append + resync (one append call per dropped item, one resync after)
**Source:** `Islet/Shelf/ShelfCoordinator.swift` `append(_:)` (lines 28-35) + `Islet/Notch/NotchWindowController.swift` `resyncShelfViewState()` (lines 1239-1249) + the DEBUG seed loop (lines 1307-1325)
**Apply to:** `handleDragPerform`. Never re-implement dedup (`ShelfCoordinator.append` already silently no-ops a duplicate `originalURL`, deleting the orphaned session copy itself) or the session-copy contract (`ShelfFileStore.makeSessionCopy`) — call the existing seams, then a single `resyncShelfViewState()` after the loop.

### Silent no-op rejection (no dialogs, no thrown errors surfaced to the user)
**Source:** Established throughout — `ShelfCoordinator.append`'s duplicate rejection, `handleShelfItemTap`'s missing-file guard, Phase 19/20/21 CONTEXT.md decisions
**Apply to:** Non-file drag payloads, expanded-state drop attempts (D-04), and charging/device-splash-active drops (CONTEXT.md discretion item) — all should `guard ... else { return false }` / silently no-op, consistent with every prior edge-case precedent in this codebase.

---

## No Analog Found

None — this phase is purely additive to two files with a rich, well-established existing pattern family (hover/click/drag-out state machine already covers every shape this phase's drag-in state machine needs). The ONE genuinely novel piece — `NSDraggingDestination` registration/callbacks itself — has zero prior-art analog in this codebase (confirmed by RESEARCH.md's own grep: zero matches for `NSDraggingDestination`/`registerForDraggedTypes`/`draggingEntered`/`performDragOperation`), so for that piece specifically, follow RESEARCH.md's `## Code Examples` and `## Architecture Patterns` sections (Apple-doc-sourced) rather than an in-repo analog. This is expected and already flagged in RESEARCH.md's own "Established Patterns" section ("No existing drag-DESTINATION code anywhere").

## Metadata

**Analog search scope:** `Islet/Notch/`, `Islet/Shelf/`, `IsletTests/` (full directory listing + targeted greps for `NSDraggingDestination`/`registerForDraggedTypes`/`func `/property declarations)
**Files scanned:** `NotchPanel.swift` (full), `NotchWindowController.swift` (targeted: imports, properties lines 200-280, `handlePointer`/`handleHoverEnter`/`syncClickThrough`/`handleHoverExit`/`handleClick` lines 671-876, `handleShelfItemTap`–`seedDebugShelfItems` lines 1227-1326), `ShelfCoordinator.swift` (full), `ShelfFileStore.swift` (full), `ShelfItemView.swift` (full), `ShelfItem.swift` (full), `NotchPillView.swift` (grep only, structural), `NotchPanelTests.swift` (full), `ShelfCoordinatorTests.swift` (full), `ShelfLogicTests.swift` (partial), `ShelfFileStoreTests.swift` (partial)
**Pattern extraction date:** 2026-07-10
