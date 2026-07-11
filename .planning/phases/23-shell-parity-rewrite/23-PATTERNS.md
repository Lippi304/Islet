# Phase 23: Shell Parity Rewrite - Pattern Map

**Mapped:** 2026-07-11
**Files analyzed:** 3 (2 rewritten in place + 1 test file updated); 1 optional extraction file
**Analogs found:** 3 / 3 (self-analog for the two rewritten files; DeviceCoordinator for the optional extraction)

## Scope note (read first)

This phase is a **behavior-preserving, in-place rewrite** of two files that already exist. Unlike
a typical new-feature phase, the "closest analog" for `NotchPanel.swift` and
`NotchWindowController.swift` is **the file's own current implementation** — every excerpt below
is quoted verbatim from the current source and is the literal target the rewrite must reproduce
(minus the D-01 drag scaffold). Do not look elsewhere in the codebase for how to structure these
two files; the current versions ARE the pattern.

The one genuinely *external* analog is for the **optional** license-gating extraction (Claude's
Discretion item in CONTEXT.md/RESEARCH.md): if `pendingLockoutHide` separates cleanly during the
rewrite, `DeviceCoordinator.swift` (Phase 16) is the extraction template to follow.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `Islet/Notch/NotchPanel.swift` | component (AppKit window shell) | event-driven | itself (current source, minus D-01 lines) | exact (self) |
| `Islet/Notch/NotchWindowController.swift` | controller (AppKit glue) | event-driven | itself (current source) | exact (self) |
| `IsletTests/NotchPanelTests.swift` | test | request-response (unit assertions) | itself (current source) | exact (self) |
| *(optional, discretion)* `Islet/Notch/LicenseGatingCoordinator.swift` or similar | service/coordinator | event-driven | `Islet/Notch/DeviceCoordinator.swift` + `Islet/Notch/ActivityCoordinator.swift` | role-match (Phase 16 extraction precedent) |

## Pattern Assignments

### `Islet/Notch/NotchPanel.swift` (component, event-driven)

**Analog:** itself — current 62-line file, read in full.

**Full current source (the exact target, minus D-01 deletions):**
```swift
// Source: Islet/Notch/NotchPanel.swift:1-62 (current, full file)
import AppKit

final class NotchPanel: NSPanel {   // DELETE ", NSDraggingDestination" conformance (D-01)
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel], // D-07
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
        // DELETE: registerForDraggedTypes([.fileURL]) — Phase 22 spike, D-01 scaffold
    }
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    // DELETE all 4 stub methods below (D-01):
    //   draggingEntered(_:) -> NSDragOperation
    //   draggingUpdated(_:) -> NSDragOperation
    //   draggingExited(_:)
    //   performDragOperation(_:) -> Bool
}
```

**Deletion boundary (exact, current line numbers):**
- Line 9: `final class NotchPanel: NSPanel, NSDraggingDestination {` → drop `, NSDraggingDestination`
- Line 33: `registerForDraggedTypes([.fileURL])` → delete entire line
- Lines 39-61: the SPIKE comment block + all 4 `NSDraggingDestination` method stubs → delete entirely
- Everything else (lines 1-38 excluding line 33, and lines 62) is preserved byte-for-byte.

**What must NOT change:** styleMask, `ignoresMouseEvents` starting `true`, `.statusBar` level,
`collectionBehavior`, `canBecomeKey`/`canBecomeMain` overrides, `isReleasedWhenClosed = false`.

---

### `IsletTests/NotchPanelTests.swift` (test, request-response)

**Analog:** itself — current 58-line file, read in full. All 6 existing test methods
(`testPanelIsNonActivating`, `testPanelNeverBecomesKeyOrMain`, `testPanelLevelIsStatusBar`,
`testPanelJoinsAllSpacesAboveFullscreenAux`, `testPanelStartsClickThrough`,
`testPanelIsTransparentWithoutShadow`) are unaffected by the D-01 removal and must keep passing
unchanged.

**New assertion to ADD** (per RESEARCH.md Wave 0 Gaps — covers Success Criterion #4 at the unit
level):
```swift
// Follows the exact style of the existing 6 tests in this file (XCTAssertFalse + explanatory string)
func testPanelHasNoDraggingDestinationResidue() {
    let panel = makePanel()
    XCTAssertFalse(panel is NSDraggingDestination,
                   "D-01: the Phase-22 drag scaffold must be fully removed from NotchPanel.")
}
```

---

### `Islet/Notch/NotchWindowController.swift` (controller, event-driven)

**Analog:** itself — current 1,378-line file. Every `// MARK:`-bounded section below is the exact
target for the corresponding rewritten section. Verified function boundaries (current line numbers,
via `grep -n "func \|MARK:"`):

```
1        import AppKit / SwiftUI / CoreLocation
29-30    @MainActor final class NotchWindowController { ... property declarations ...
277      func start()
380      scheduleTrialExpiryCheck()
388      MARK: Phase 6 monitor lifecycle
399-462  startPowerMonitor / startNowPlayingMonitor / startBluetoothMonitor / startOutfitRefresh
462-479  refreshWeather / refreshCalendar / currentBuiltin
483      MARK: single arbiter (resolver) + render
490-542  currentPresentation / renderPresentation / presentTransientChange
542      updateVisibility()          <- Pattern 5, THE show/hide arbiter
601      positionAndShow(on:)        <- panel creation, CGSSpace join, orderFrontRegardless
671      handlePointer(at:)          <- global-monitor hit-test entry point
709      visibleContentZone()        <- CR-01's narrowed hit-test rect
721      handleHoverEnter()
770      syncClickThrough()          <- Pattern 2, THE click-through arbiter
788      handleHoverExit()
832      handleClick()                <- Pattern 5/D-13 natural-transition recheck sites
873      handlePower(_:)
916-946  scheduleActivityDismiss / syncActivityModels
951      makeRootView / handleSettingsChanged / flushTransients / applyAccentIfChanged
1078     handleNowPlaying / scheduleMediaDismiss / scheduleToastDismiss / handleAdapterTerminated
1222     MARK: Phase 20 shelf item handlers
1328     deinit
```

**Imports / class header** (lines 1-100, current):
```swift
// Source: Islet/Notch/NotchWindowController.swift:1-100
import AppKit
import SwiftUI
import CoreLocation

@MainActor
final class NotchWindowController {
    private var panel: NotchPanel?
    private var observer: NSObjectProtocol?
    private let notchSpace = CGSSpace(level: 2147483647)   // FS-01, Phase 9
    private var spaceObserver: NSObjectProtocol?
    private var appActivateObserver: NSObjectProtocol?
    private var hideInFullscreen: Bool { activityEnabled(ActivitySettings.hideInFullscreenKey) }
    private let licenseState = LicenseState.shared
    private var pendingLockoutHide = false   // D-13 — the Claude's-Discretion extraction candidate
    private let interaction = NotchInteractionState()
    private let chargingState = ChargingActivityState()
    private let presentationState = IslandPresentationState()
    private let shelfViewState = ShelfViewState()
    private let shelfCoordinator = ShelfCoordinator()
    // ... outfit/weather/calendar fields follow, all @MainActor, all launch-scoped ...
}
```

**Pattern 5 — the single show/hide arbiter** (`updateVisibility()`, must carry over with zero
logical diff — this is also where D-13's `pendingLockoutHide` guard lives):
```swift
// Source: Islet/Notch/NotchWindowController.swift:542-597
private func updateVisibility() {
    let wasVisible = isCurrentlyVisible
    let midInteraction = pointerInZone || interaction.isExpanded
    if !licenseState.isEntitled && midInteraction {
        pendingLockoutHide = true
        return
    }
    if pendingLockoutHide { pendingLockoutHide = false }

    let descriptors = NSScreen.screens.map { $0.descriptor }
    let target = selectTargetScreen(from: descriptors)
    let fullscreen = isBuiltinDisplayInFullscreenSpace(builtinUUID: currentBuiltin()?.uuid)

    if shouldShow(hasTarget: target != nil, hideInFullscreen: hideInFullscreen,
                  isFullscreen: fullscreen, isLicensed: licenseState.isEntitled),
       let target {
        isCurrentlyVisible = true
        positionAndShow(on: target)
        if !wasVisible { refreshWeather(); refreshCalendar() }
    } else {
        panel?.orderOut(nil)                 // THE only hide call in the file
        hotZone = nil
        expandedZone = nil
        pointerInZone = false
        isCurrentlyVisible = false
    }
}
```

**Pattern 3/FS-01 — panel creation + additive CGSSpace join** (`positionAndShow(on:)`, the
sequence order is load-bearing per Pitfall 2's open question — preserve frame-set →
`NSHostingView` assign → `CGSSpace` join → `orderFrontRegardless` exactly):
```swift
// Source: Islet/Notch/NotchWindowController.swift:649-666
let panel = self.panel ?? NotchPanel(contentRect: panelFrame)
if self.panel == nil {
    let index = UserDefaults.standard.integer(forKey: ActivitySettings.accentIndexKey)
    appliedAccentIndex = index
    panel.contentView = NSHostingView(rootView: makeRootView(accentIndex: index))
    self.panel = panel
    notchSpace.windows.insert(panel)          // FS-01, joined ONCE at creation
}
if panel.frame != panelFrame {
    panel.setFrame(panelFrame, display: true)
}
panel.orderFrontRegardless()                  // focus-safe show, D-07
```

**Pattern 2 — the single click-through arbiter** (`syncClickThrough()`, CR-01-hardened — the
single highest-risk function in the rewrite; diff line-for-line, never re-derive from comments):
```swift
// Source: Islet/Notch/NotchWindowController.swift:770-784
private func syncClickThrough() {
    let interactive: Bool
    if interaction.isExpanded {
        // CR-01: pure visibleContentZone() check. NEVER OR pointerInZone in here.
        interactive = visibleContentZone()?.contains(lastPointerLocation) ?? false
    } else {
        interactive = pointerInZone
    }
    panel?.ignoresMouseEvents = !interactive
}
```

**CR-01 narrowed hit-test rect** (`visibleContentZone()`):
```swift
// Source: Islet/Notch/NotchWindowController.swift:709-717
private func visibleContentZone() -> CGRect? {
    guard let hotZone else { return nil }
    let collapsedFrame = hotZone.insetBy(dx: hotZonePadding, dy: hotZonePadding)
    let shelfHeight = shelfViewState.items.isEmpty ? 0 : NotchPillView.shelfRowHeight
    let visibleFrame = expandedNotchFrame(collapsed: collapsedFrame,
                                          expandedSize: CGSize(width: expandedSize.width,
                                                                height: expandedSize.height + shelfHeight))
    return visibleFrame.insetBy(dx: -hotZonePadding, dy: -hotZonePadding)
}
```

**Pattern 1 — global-monitor hit-test entry point** (`handlePointer(at:)`, no coordinate
conversion — both `point` and the zones are global bottom-left):
```swift
// Source: Islet/Notch/NotchWindowController.swift:671-702
private func handlePointer(at point: CGPoint) {
    lastPointerLocation = point
    let activeZone = interaction.isExpanded ? (expandedZone ?? hotZone) : hotZone
    guard let zone = activeZone else { return }
    let inside = zone.contains(point)
    if inside && !pointerInZone {
        pointerInZone = true
        handleHoverEnter()
    } else if !inside && pointerInZone {
        pointerInZone = false
        handleHoverExit()
    }
    if interaction.isExpanded { syncClickThrough() }
}
```

**Pattern 7 — one-shot `DispatchWorkItem` grace-collapse idiom** (`handleHoverExit()`, also the
other D-13 natural-transition recheck site):
```swift
// Source: Islet/Notch/NotchWindowController.swift:788-813
private func handleHoverExit() {
    withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
        interaction.phase = nextState(interaction.phase, .pointerExited)
    }
    let work = DispatchWorkItem { [weak self] in
        guard let self else { return }
        guard !self.isDraggingShelfItem else { return }
        withAnimation(.spring(response: self.springResponse, dampingFraction: self.springDamping)) {
            self.interaction.phase = nextState(self.interaction.phase, .graceElapsed)
            self.renderPresentation()
        }
        self.updateVisibility()      // D-13 natural-transition recheck #1
        self.syncClickThrough()      // Pitfall 3: restore click-through deterministically
    }
    graceWorkItem = work
    DispatchQueue.main.asyncAfter(deadline: .now() + graceDelay, execute: work)
}
```

**D-02/D-13 click handler** (`handleClick()`, the ONLY path to `.expanded`, and D-13's second
natural-transition recheck site):
```swift
// Source: Islet/Notch/NotchWindowController.swift:832-867
private func handleClick() {
    let wasExpanded = interaction.isExpanded
    withAnimation(.spring(response: springResponse, dampingFraction: springDamping)) {
        interaction.phase = nextState(interaction.phase, .clicked)
        // ... toast-dismiss / prune-missing-files side effects, unchanged ...
        renderPresentation()
    }
    if !interaction.isExpanded {
        updateVisibility()           // D-13 natural-transition recheck #2
    }
    syncClickThrough()               // WR-02: re-derive click-through on every click
}
```

**Teardown discipline** (`deinit`, mirrors the owner-driven-teardown convention across every
OS-registered resource — CGSSpace removal is the one FS-01-specific line):
```swift
// Source: Islet/Notch/NotchWindowController.swift:1328-1378
deinit {
    if let o = observer { NotificationCenter.default.removeObserver(o) }
    let wc = NSWorkspace.shared.notificationCenter
    if let o = spaceObserver { wc.removeObserver(o) }
    if let o = appActivateObserver { wc.removeObserver(o) }
    if let o = defaultsObserver { NotificationCenter.default.removeObserver(o) }
    if let m = mouseMonitor { NSEvent.removeMonitor(m) }
    graceWorkItem?.cancel()
    // ... shelf-drag safety net, power/bluetooth/nowPlaying monitor .stop(), work-item cancels ...
    if let panel { notchSpace.windows.remove(panel) }   // FS-01 teardown
    trialExpiryWorkItem?.cancel()
    outfitRefreshTimer?.invalidate()
}
```

---

### *(Optional, Claude's Discretion)* License-gating extraction

**Analog:** `Islet/Notch/DeviceCoordinator.swift` (262 lines) + `Islet/Notch/ActivityCoordinator.swift`
(29-line protocol) — the Phase 16 precedent for pulling bookkeeping out of
`NotchWindowController` behind a narrow protocol.

**Only take this path if `pendingLockoutHide`'s two call sites separate cleanly** (RESEARCH.md
Open Question 2 explicitly says not to force it). If taken, the template is:

**Protocol shape** (`ActivityCoordinator.swift`, full file — narrow, sized to exactly what's
needed, not pre-sketched for future coordinators):
```swift
// Source: Islet/Notch/ActivityCoordinator.swift:1-29 (full file)
import Foundation

@MainActor
protocol ActivityCoordinator {
    associatedtype Reading
    func handle(_ reading: Reading)
    func activityPromoted()
}
```

**Construction/wiring idiom** (`DeviceCoordinator.init`, lines 84-96 — closures, NOT a stored
controller reference, because the reach-back needs `[weak self]` semantics and the coordinator
must not hold a strong reference to the controller):
```swift
// Source: Islet/Notch/DeviceCoordinator.swift:76-96
private let queueHead: () -> ActiveTransient?
private let enqueue: (ActiveTransient) -> Bool
private let updateHead: (ActiveTransient) -> Void
private let presentTransientChange: () -> Void
private let renderPresentation: () -> Void
private let batteryForAddress: (String) -> Int?

init(queueHead: @escaping () -> ActiveTransient?,
     enqueue: @escaping (ActiveTransient) -> Bool,
     updateHead: @escaping (ActiveTransient) -> Void,
     presentTransientChange: @escaping () -> Void,
     renderPresentation: @escaping () -> Void,
     batteryForAddress: @escaping (String) -> Int?) {
    self.queueHead = queueHead
    // ...
}
```

**Construction site convention** — constructed at `start()` time (NOT at property-declaration
time), because the closures need to capture `self` after all other properties exist:
```swift
// Pattern per DeviceCoordinator's wiring in NotchWindowController.start() (Phase 16-02) —
// if extracting license-gating, follow the same "constructed in start(), not declared inline" shape.
```

**Teardown convention** — expose a `nonisolated func cancelPendingWork()` if the coordinator holds
any `DispatchWorkItem`, called from the controller's `deinit` (see `DeviceCoordinator.swift:121-123`
and the `deviceCoordinator?.cancelPendingWork()` call at `NotchWindowController.swift:1356`).

**Corresponding test precedent:** `IsletTests/DeviceCoordinatorTests.swift` — if extracted, a
sibling `LicenseGatingCoordinatorTests.swift` (or similar) should unit-test the extracted logic in
isolation the same way, per RESEARCH.md's "DeviceCoordinatorTests.swift unit-tests 8 of them"
convention.

## Shared Patterns

### Single-arbiter discipline (the phase's #1 invariant)
**Source:** `Islet/Notch/NotchWindowController.swift:770-784` (`syncClickThrough()`) and
`:542-597` (`updateVisibility()`)
**Apply to:** Both rewritten files — every mutation site that touches `ignoresMouseEvents` must
route through `syncClickThrough()`; every show/hide decision must route through `updateVisibility()`.
No second writer of either may be introduced anywhere in the rewrite.

### One-shot `DispatchWorkItem`, never a recurring `Timer`
**Source:** `graceWorkItem` in `handleHoverExit()` (`:788-813`), mirrored by
`dismissWorkItem`/`mediaDismissWorkItem`/`trialExpiryWorkItem`/`dragPinSafetyNetWorkItem`
elsewhere in the same file.
**Apply to:** Any new or preserved deferred-work field in the rewritten controller.

### Global-coordinate invariant (no conversion)
**Source:** `handlePointer(at:)` (`:671-702`) — `NSEvent.mouseLocation` and `hotZone`/`expandedZone`
are both global, bottom-left, unflipped; `NotchGeometry.swift`'s own documented convention.
**Apply to:** Any geometry comparison touched during the rewrite (Pitfall 4 in RESEARCH.md).

### Fail-safe discipline on private-API reads
**Source:** `FullscreenSpaceProbe.swift` (out of scope, zero-diff) — nil/parse-failure returns
`false` (prefer show over wrong-hide).
**Apply to:** Any CGS call site the rewritten `updateVisibility()`/`positionAndShow()` touches —
preserve the same fail-open discipline, do not add a new failure path that defaults to hiding.

## No Analog Found

None — every file in scope for this phase either analogizes to itself (in-place rewrite) or to
`DeviceCoordinator.swift`/`ActivityCoordinator.swift` (the one optional extraction).

## Metadata

**Analog search scope:** `Islet/Notch/`, `IsletTests/` (the only directories touched by ARCH-01)
**Files scanned:** `NotchPanel.swift`, `NotchWindowController.swift`, `IsletTests/NotchPanelTests.swift`,
`DeviceCoordinator.swift`, `ActivityCoordinator.swift` — all read in full or via targeted
non-overlapping ranges this session; `NotchGeometry.swift`, `NotchInteractionState.swift`,
`DragDropSupport.swift`, `CGSSpace.swift`, `FullscreenSpaceProbe.swift` confirmed out-of-scope
(zero-diff) per CONTEXT.md/RESEARCH.md and not re-read here (already fully read by the research
agent this session).
**Pattern extraction date:** 2026-07-11
