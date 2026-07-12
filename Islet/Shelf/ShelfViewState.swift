import Foundation

// Phase 20 / SHELF-03 — the SEPARATE @Published view-layer mirror of ShelfCoordinator.logic.items,
// mirroring NowPlayingState's ownership contract exactly: a plain published holder, no methods, no
// timers. Plan 20-02's NotchWindowController owns the real ShelfCoordinator and is the ONLY writer —
// it sets `.items` directly after every ShelfCoordinator mutation (append/remove/clear).
final class ShelfViewState: ObservableObject {
    @Published var items: [ShelfItem] = []

    // Phase 28 / CALVIEW-04, Pitfall 3 (CR-01 click-through regression class) — the controller
    // (Plan 04) sets this true while Tray is the selected switcher view, force-revealing an
    // otherwise-empty shelf strip. `isVisible` is the ONE source of truth every shelf-visibility
    // check must read (blobShape, the body's outer .frame, and NotchWindowController's
    // visibleContentZone()) — never patch one call site with an inline OR while leaving siblings
    // on the old `.items.isEmpty` check (see project memory cr01-clickthrough-or-defeat-gotcha).
    @Published var forcedByTray = false
    var isVisible: Bool { !items.isEmpty || forcedByTray }
}

// Phase 20 / SHELF-04 / D-04 — the missing-file-click gate as an explicit, testable pure seam,
// mirroring songChangeToastGate/nowPlayingHealthGate in Islet/Notch/IslandResolver.swift. Plan
// 20-02's NotchWindowController.handleShelfItemTap calls this before NSWorkspace.shared.open.
func shouldOpenShelfItem(fileExists: Bool) -> Bool { fileExists }

// Phase 21 / SHELF-06 / D-02 — the missing-file-drag gate, identical shape to
// shouldOpenShelfItem. ShelfItemView's .onDrag closure calls this before constructing
// NSItemProvider(contentsOf:); a vanished backing file is a silent no-op drag.
func shouldBeginShelfItemDrag(fileExists: Bool) -> Bool { fileExists }
