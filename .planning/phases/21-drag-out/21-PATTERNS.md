# Phase 21: Drag-Out - Pattern Map

**Mapped:** 2026-07-10
**Files analyzed:** 4 (3 modified, 1 test file modified — no new files, greenfield capability inside existing files)
**Analogs found:** 4 / 4 (all analogs are the SAME files' own established sibling patterns — this is an additive-to-existing-file phase, not a new-file phase, so "closest analog" means "the nearest existing pattern within/adjacent to the file being modified")

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|-----------------|---------------|
| `Islet/Notch/ShelfItemView.swift` | component (SwiftUI leaf view) | event-driven (gesture → closure reach-back) | same file's existing `.onTapGesture { onTap() }` + `Button(action: onDelete)` (Finding-15 scoped-gesture pattern) | exact — same file, same shape, new sibling gesture |
| `Islet/Shelf/ShelfViewState.swift` | utility (pure gate function) | transform (bool in → bool out) | same file's `shouldOpenShelfItem(fileExists:)` (line 14) | exact — literally the same shape, new sibling function |
| `Islet/Notch/NotchWindowController.swift` | controller (AppKit window/state owner) | event-driven (drag-lifecycle pin + one-shot timer) | same file's `pendingLockoutHide` deferred-reapply idiom (lines 537-550) + `scheduleMediaDismiss`/`scheduleToastDismiss` one-shot `DispatchWorkItem` idiom (lines 1150-1184) | exact — both idioms already exist in this exact file for this exact class of problem |
| `IsletTests/ShelfViewStateTests.swift` | test | transform (pure-function assertions) | same file's `testShouldOpenShelfItemGate()` (lines 74-77) | exact — same file, same shape |

## Pattern Assignments

### `Islet/Shelf/ShelfViewState.swift` (utility, transform) — ADD `shouldBeginShelfItemDrag`

**Analog:** same file, `shouldOpenShelfItem(fileExists:)`

**Exact existing pattern to copy** (`Islet/Shelf/ShelfViewState.swift` line 14):
```swift
// Phase 20 / SHELF-04 / D-04 — the missing-file-click gate as an explicit, testable pure seam,
// mirroring songChangeToastGate/nowPlayingHealthGate in Islet/Notch/IslandResolver.swift. Plan
// 20-02's NotchWindowController.handleShelfItemTap calls this before NSWorkspace.shared.open.
func shouldOpenShelfItem(fileExists: Bool) -> Bool { fileExists }
```

**New function, same shape** (append directly below, same file):
```swift
// Phase 21 / SHELF-06 / D-02 — the missing-file-drag gate, identical shape to
// shouldOpenShelfItem above. Called from ShelfItemView's .onDrag closure before constructing
// NSItemProvider(contentsOf:).
func shouldBeginShelfItemDrag(fileExists: Bool) -> Bool { fileExists }
```

Do NOT create a second file or a struct/protocol for this — it is a one-line sibling function, exactly matching the existing convention of one pure gate function per shelf interaction.

---

### `Islet/Notch/ShelfItemView.swift` (component, event-driven) — ADD `.onDrag`

**Analog:** same file's existing `.onTapGesture` + sibling `Button(action: onDelete)` overlay

**Exact existing pattern** (`Islet/Notch/ShelfItemView.swift` lines 7-38, full file — already read in full, small file):
```swift
struct ShelfItemView: View {
    let item: ShelfItem
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 2) {   // UI-SPEC icon-gap
            Image(nsImage: NSWorkspace.shared.icon(forFile: item.localURL.path))
                .resizable()
                .frame(width: 28, height: 28)   // matches transportButton's 28x28 touch size
            Text(item.filename)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)   // V5 mitigation (T-20-01): item.filename is untrusted
                .frame(maxWidth: 44)
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }   // D-04 own scoped gesture — click-to-open
        .overlay(alignment: .topTrailing) {
            // Finding-15/D-05 precedent: a SIBLING overlay, never nested inside the tap-gesture
            // region the ancestor .onTapGesture could shadow.
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(item.filename)")
        }
        .accessibilityLabel("Open \(item.filename)")
    }
}
```

**Required diff shape** (add `onDragStarted` param + `.onDrag` modifier, sibling to the existing `.onTapGesture`, per RESEARCH.md's Code Examples section — already validated against this exact file):
```swift
struct ShelfItemView: View {
    let item: ShelfItem
    let onTap: () -> Void
    let onDelete: () -> Void
    let onDragStarted: () -> Void   // NEW — reach-back to NotchWindowController.beginShelfItemDrag()

    var body: some View {
        VStack(spacing: 2) { /* unchanged */ }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .onDrag {
            let exists = FileManager.default.fileExists(atPath: item.localURL.path)
            guard shouldBeginShelfItemDrag(fileExists: exists) else {
                return NSItemProvider()   // D-02 silent no-op
            }
            onDragStarted()
            return NSItemProvider(contentsOf: item.localURL) ?? NSItemProvider()
        }
        .overlay(alignment: .topTrailing) { /* unchanged Button(action: onDelete) */ }
        .accessibilityLabel("Open \(item.filename)")
    }
}
```

**Wiring at call site** (`Islet/Notch/NotchPillView.swift` lines 296-298 — closure-injection convention, add third closure the same way `onTap`/`onDelete` are already injected):
```swift
ShelfItemView(item: item,
              onTap: { onShelfItemTap(item) },
              onDelete: { onShelfItemDelete(item.id) })
```
New: add `onDragStarted: { onShelfItemDragStarted() }` (or `{ [captured] in ... }` matching existing style) as a third parameter, plumbed the same way `onShelfItemTap`/`onShelfItemDelete` are declared as `var` closures on `NotchPillView` (lines 87-88) and forwarded from `NotchWindowController.makeRootView` (lines 943-944).

---

### `Islet/Notch/NotchWindowController.swift` (controller, event-driven) — ADD drag-pin state + `beginShelfItemDrag`/`endShelfItemDrag`

**Analog 1 — deferred-reapply idiom:** `pendingLockoutHide` (lines 537-550)
```swift
// Phase 10 / D-13 — idle-state guard: a license-driven hide must never abruptly yank the
// island out from under an active hover/expansion. If the pointer is in the hot-zone or
// the island is expanded, defer the hide (set pendingLockoutHide) and leave panel/hotZone/
// expandedZone/pointerInZone completely untouched this call — the deferred hide is applied
// at the next natural transition (handleHoverExit's grace-elapsed collapse or a
// handleClick toggle-shut, both of which re-invoke updateVisibility()).
let midInteraction = pointerInZone || interaction.isExpanded
if !licenseState.isEntitled && midInteraction {
    pendingLockoutHide = true
    return
}
if pendingLockoutHide {
    pendingLockoutHide = false
}
```
This is the exact pattern D-03 mirrors: defer a state transition while mid-interaction, re-apply it at the next natural transition point.

**Analog 2 — one-shot `DispatchWorkItem` idiom:** `scheduleMediaDismiss`/`scheduleToastDismiss` (lines 1150-1184)
```swift
// D-06 / D-07 — schedule the one-shot media dismiss. Mirrors scheduleActivityDismiss
// exactly: cancel any pending item, create a SINGLE DispatchWorkItem that clears the media
// glance inside the spring then re-runs the single visibility gate, and asyncAfter it. One
// wake-up then idle — NO recurring timer (idle CPU ~0%).
private func scheduleMediaDismiss(after seconds: TimeInterval) {
    mediaDismissWorkItem?.cancel()
    let work = DispatchWorkItem { [weak self] in
        guard let self else { return }
        withAnimation(.spring(response: self.springResponse, dampingFraction: self.springDamping)) {
            self.nowPlayingState.presentation = .none
            self.nowPlayingState.artwork = nil
            self.nowPlayingState.position = nil
            self.renderPresentation()
        }
        self.updateVisibility()
    }
    mediaDismissWorkItem = work
    DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
}
```

**Analog 3 — the collapse-scheduling site itself the pin must gate:** `handleHoverExit` (lines 778-814), specifically the `graceWorkItem` body:
```swift
private func handleHoverExit() {
    withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
        interaction.phase = nextState(interaction.phase, .pointerExited)
    }

    let work = DispatchWorkItem { [weak self] in
        guard let self else { return }
        // Only collapse if the pointer is STILL outside (re-entry would have cancelled).
        withAnimation(.spring(response: self.springResponse, dampingFraction: self.springDamping)) {
            self.interaction.phase = nextState(self.interaction.phase, .graceElapsed)
            self.renderPresentation()
        }
        self.updateVisibility()
        self.syncClickThrough()
    }
    graceWorkItem = work
    DispatchQueue.main.asyncAfter(deadline: .now() + graceDelay, execute: work)
    // ... existing charging/media dismiss resume logic unchanged
}
```

**Required additions** (per RESEARCH.md Pattern 2 and Open Questions (RESOLVED) #1 — already validated against this exact file's conventions, `dragPinSafetyNetWorkItem` alongside the other 4 `DispatchWorkItem` optionals at lines 168/174/179/190/209, and `dragReleaseMonitor` mirroring the existing `mouseMonitor` global-monitor idiom at line 314):
```swift
// New stored properties, alongside pointerInZone/graceWorkItem (near line 209/216):
private var isDraggingShelfItem = false
private var dragPinSafetyNetWorkItem: DispatchWorkItem?
private let dragPinSafetyNetDuration: TimeInterval = 20.0
private var dragReleaseMonitor: Any?   // best-effort early-release signal, armed only during a drag

// Reach-back target for ShelfItemView's onDragStarted closure (wired in makeRootView,
// mirrors the onShelfItemTap: { [weak self] item in self?.handleShelfItemTap(item) } style
// at line 943):
private func beginShelfItemDrag() {
    isDraggingShelfItem = true
    graceWorkItem?.cancel()
    graceWorkItem = nil
    dragPinSafetyNetWorkItem?.cancel()
    let safetyNet = DispatchWorkItem { [weak self] in self?.endShelfItemDrag() }
    dragPinSafetyNetWorkItem = safetyNet
    DispatchQueue.main.asyncAfter(deadline: .now() + dragPinSafetyNetDuration, execute: safetyNet)

    // Best-effort early release (D-03): mirrors Pattern 1's .mouseMoved global monitor exactly,
    // but for .leftMouseUp, and armed/disarmed per-drag rather than for the app's lifetime.
    if dragReleaseMonitor == nil {
        dragReleaseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] _ in
            self?.endShelfItemDrag()
        }
    }
}

private func endShelfItemDrag() {
    guard isDraggingShelfItem else { return }   // idempotent — safety-net + early signal may both fire
    isDraggingShelfItem = false
    dragPinSafetyNetWorkItem?.cancel()
    dragPinSafetyNetWorkItem = nil
    if let m = dragReleaseMonitor {
        NSEvent.removeMonitor(m)
        dragReleaseMonitor = nil
    }
    if !pointerInZone {
        handleHoverExit()
    }
}

// Inside handleHoverExit's existing graceWorkItem body (line 783), add ONE guard at the top:
let work = DispatchWorkItem { [weak self] in
    guard let self else { return }
    guard !self.isDraggingShelfItem else { return }   // D-03: drag in flight, defer collapse
    // ...unchanged existing collapse logic...
}
```

**Explicit anti-pattern (DO NOT):** Do not add `isDraggingShelfItem` or `dragReleaseMonitor` to `syncClickThrough()` (lines 760-774). That function's expanded branch must stay pure `visibleContentZone()?.contains(lastPointerLocation) ?? false` — the CR-01 regression (project memory `cr01-clickthrough-or-defeat-gotcha`) was caused by exactly this class of OR-in. Grep for `isDraggingShelfItem`/`dragReleaseMonitor` near `syncClickThrough`/`visibleContentZone` should return nothing.

---

### `IsletTests/ShelfViewStateTests.swift` (test, transform) — ADD `testShouldBeginShelfItemDrag`

**Analog:** same file, `testShouldOpenShelfItemGate()` (lines 74-77)
```swift
func testShouldOpenShelfItemGate() {
    XCTAssertTrue(shouldOpenShelfItem(fileExists: true))
    XCTAssertFalse(shouldOpenShelfItem(fileExists: false))
}
```

**New test, same shape** (append directly below, same file):
```swift
func testShouldBeginShelfItemDragGate() {
    XCTAssertTrue(shouldBeginShelfItemDrag(fileExists: true))
    XCTAssertFalse(shouldBeginShelfItemDrag(fileExists: false))
}
```

## Shared Patterns

### Closure-injection / reach-back wiring
**Source:** `Islet/Notch/NotchWindowController.swift` lines 937-945 (`makeRootView`), `Islet/Notch/NotchPillView.swift` lines 87-88, 296-298
**Apply to:** `ShelfItemView.swift`'s new `onDragStarted` param, `NotchPillView`'s new `onShelfItemDragStarted` var, and the controller's `beginShelfItemDrag()` reach-back target.
```swift
// NotchPillView var declarations (mirror onShelfItemTap/onShelfItemDelete):
var onShelfItemDragStarted: () -> Void = { }

// NotchPillView call-site forwarding (mirror lines 296-298):
ShelfItemView(item: item,
              onTap: { onShelfItemTap(item) },
              onDelete: { onShelfItemDelete(item.id) },
              onDragStarted: { onShelfItemDragStarted() })

// NotchWindowController.makeRootView forwarding (mirror line 943):
onShelfItemDragStarted: { [weak self] in self?.beginShelfItemDrag() },
```

### One-shot `DispatchWorkItem` idiom (never a recurring `Timer`)
**Source:** `Islet/Notch/NotchWindowController.swift` — 4 existing uses: `dismissWorkItem` (~176-179), `graceWorkItem` (209, used at 783-800), `mediaDismissWorkItem` (166-168, used at 1150-1167), `toastDismissWorkItem` (172-174, used at 1170-1184)
**Apply to:** `dragPinSafetyNetWorkItem` — cancel-then-recreate-then-asyncAfter, one wake-up then idle, idempotent guard at the top of the work closure.

### Pure boolean gate before OS side-effect
**Source:** `Islet/Shelf/ShelfViewState.swift` line 14 (`shouldOpenShelfItem`), consumed at `Islet/Notch/NotchWindowController.swift` line 1207 (`handleShelfItemTap`)
```swift
private func handleShelfItemTap(_ item: ShelfItem) {
    guard shouldOpenShelfItem(fileExists: FileManager.default.fileExists(atPath: item.localURL.path)) else { return }
    NSWorkspace.shared.open(item.localURL)
}
```
**Apply to:** the `.onDrag` closure in `ShelfItemView.swift` — same shape, `FileManager.default.fileExists` check immediately followed by the pure gate, immediately followed by the side effect (constructing `NSItemProvider` instead of `NSWorkspace.shared.open`).

### Deferred-reapply-at-next-natural-transition idiom
**Source:** `pendingLockoutHide` in `updateVisibility()`, lines 537-550
**Apply to:** `isDraggingShelfItem` in `handleHoverExit`'s `graceWorkItem` — same shape: set a flag mid-interaction, guard the state-changing action on it, clear it and let the NEXT natural transition (here: `endShelfItemDrag()` re-invoking `handleHoverExit()`) apply the deferred effect.

## No Analog Found

None — every file in scope has an exact same-file or same-immediate-neighbor analog. RESEARCH.md independently confirms this is "genuinely greenfield for drag APIs" only at the level of the `.onDrag`/`NSItemProvider` mechanism itself (no prior drag code exists anywhere in the codebase), but every SURROUNDING pattern (gesture wiring, pure gate functions, one-shot work items, deferred-reapply) has a direct, current, same-file precedent — there is nothing here that needs an external/cross-codebase analog.

## Metadata

**Analog search scope:** `Islet/Notch/`, `Islet/Shelf/`, `IsletTests/` — the 3 production files + 1 test file named explicitly in RESEARCH.md's "Recommended Project Structure" and `code_context`/`Reusable Assets`, plus their direct call sites (`NotchPillView.swift`) discovered via grep for the closure-wiring convention.
**Files scanned:** `ShelfItemView.swift` (39 lines, full read), `ShelfViewState.swift` (14 lines, full read), `ShelfViewStateTests.swift` (78 lines, full read), `NotchWindowController.swift` (1315 lines — targeted grep + 4 non-overlapping ranged reads: 505-594, 660-819, 925-984, 1148-1227), `NotchPillView.swift` (targeted grep only, lines 87-88/296-298 confirmed).
**Pattern extraction date:** 2026-07-10
